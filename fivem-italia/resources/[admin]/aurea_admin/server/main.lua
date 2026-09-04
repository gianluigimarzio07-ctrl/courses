--[[
    AUREA · Amministrazione (server)
]]

local U = AUREA.Util
local inServizioStaff = {}      -- [src] = true
local segnalazioni = {}         -- coda delle richieste di assistenza
local contatoreSegnalazioni = 0

-- ---------------------------------------------------------------------------
--  Sanzioni
-- ---------------------------------------------------------------------------
local function registraSanzione(license, citizenid, tipo, motivo, staff, minuti)
    local fine = nil
    if minuti and minuti > 0 then fine = U.DataOraPiuOre(minuti / 60) end

    return MySQL.insert.await([[
        INSERT INTO sanzioni_admin (license, citizenid, tipo, motivo, staff, fine)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { license, citizenid, tipo, motivo, staff, fine })
end

AUREA.Comando('ban', 'admin', 'Sanziona un giocatore con un ban', {
    { name = 'id', help = 'ID sessione' },
    { name = 'minuti', help = 'Durata in minuti (0 = permanente)' },
    { name = 'motivo', help = 'Motivazione' },
}, function(src, args, _, staff)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local minuti = tonumber(args[2])
    local motivo = table.concat(args, ' ', 3)

    if not bersaglio or not minuti or #motivo < 4 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = '/ban <id> <minuti|0> <motivo>',
        })
    end

    -- Non si sanziona chi ha un grado pari o superiore
    if AUREA.HaGruppo(bersaglio.source, 'admin') and src ~= 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non consentito', testo = 'Non puoi sanzionare un membro dello staff di pari grado.',
        })
    end

    local nomeStaff = staff and staff:NomeCompleto() or 'console'
    local id = registraSanzione(bersaglio.license, bersaglio.citizenid,
        minuti > 0 and 'ban' or 'ban_permanente', motivo, nomeStaff, minuti)

    AUREA.Log('staff', 'allarme', bersaglio, ('BAN #%d da %s: %s (%s)'):format(
        id, nomeStaff, motivo, minuti > 0 and (minuti .. ' minuti') or 'permanente'))

    DropPlayer(bersaglio.source, ('Sanzione #%d\nMotivo: %s\n%s'):format(
        id, motivo, minuti > 0 and ('Scadenza: ' .. U.DataOraIT(os.time() + minuti * 60)) or 'Provvedimento permanente.'))

    if src ~= 0 then
        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', titolo = 'Sanzione registrata', testo = ('#%d — %s'):format(id, motivo),
        })
    end
end)

AUREA.Comando('kick', 'moderatore', 'Espelle un giocatore dalla sessione', {
    { name = 'id', help = 'ID sessione' },
    { name = 'motivo', help = 'Motivazione' },
}, function(src, args, _, staff)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local motivo = table.concat(args, ' ', 2)

    if not bersaglio or #motivo < 4 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = '/kick <id> <motivo>',
        })
    end

    local nomeStaff = staff and staff:NomeCompleto() or 'console'
    registraSanzione(bersaglio.license, bersaglio.citizenid, 'kick', motivo, nomeStaff, 0)
    AUREA.Log('staff', 'avviso', bersaglio, ('KICK da %s: %s'):format(nomeStaff, motivo))

    DropPlayer(bersaglio.source, ('Sei stato allontanato dalla sessione.\nMotivo: %s'):format(motivo))
end)

AUREA.Comando('avvertimento', 'supporto', 'Registra un avvertimento', {
    { name = 'id', help = 'ID sessione' },
    { name = 'motivo', help = 'Motivazione' },
}, function(src, args, _, staff)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local motivo = table.concat(args, ' ', 2)

    if not bersaglio or #motivo < 4 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = '/avvertimento <id> <motivo>',
        })
    end

    local nomeStaff = staff and staff:NomeCompleto() or 'console'
    registraSanzione(bersaglio.license, bersaglio.citizenid, 'avvertimento', motivo, nomeStaff, 0)

    local quanti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM sanzioni_admin WHERE license = ? AND tipo = \'avvertimento\'', { bersaglio.license }) or 1

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'errore', icona = '⚠', durata = 16000,
        titolo = ('Avvertimento formale (%d)'):format(quanti),
        testo = motivo,
    })
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Avvertimento registrato',
        testo = ('%s ha ora %d avvertimenti.'):format(bersaglio:NomeCompleto(), quanti),
    })

    AUREA.Log('staff', 'avviso', bersaglio, ('avvertimento da %s: %s'):format(nomeStaff, motivo))
end)

AUREA.Comando('sbanna', 'gestore', 'Revoca le sanzioni attive di una licenza', {
    { name = 'license', help = 'Identificatore license' },
}, function(src, args, _, staff)
    local license = args[1]
    if not license then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/sbanna <license>' })
    end

    local revocate = MySQL.update.await(
        'UPDATE sanzioni_admin SET attiva = 0 WHERE license = ? AND attiva = 1 AND tipo LIKE \'ban%\'', { license })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = revocate > 0 and 'successo' or 'avviso',
        titolo = 'Revoca sanzioni',
        testo = ('%d provvedimenti revocati.'):format(revocate or 0),
    })
    AUREA.Log('staff', 'avviso', src, ('ha revocato %d sanzioni su %s'):format(revocate or 0, license))
end)

AUREA.Comando('precedentistaff', 'moderatore', 'Storico delle sanzioni di un giocatore', {
    { name = 'id', help = 'ID sessione' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/precedentistaff <id>' })
    end

    local righe = MySQL.query.await([[
        SELECT tipo, motivo, staff, inizio FROM sanzioni_admin
        WHERE license = ? ORDER BY id DESC LIMIT 10
    ]], { bersaglio.license }) or {}

    local elenco = {}
    for _, r in ipairs(righe) do
        elenco[#elenco + 1] = ('%s — %s (%s, %s)'):format(
            r.tipo:upper(), r.motivo, r.staff, U.DataOraIT(math.floor((r.inizio or 0) / 1000)))
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = #elenco > 0 and 'avviso' or 'successo',
        icona = '📁', durata = 18000,
        titolo = ('Precedenti staff — %s'):format(bersaglio:NomeCompleto()),
        testo = #elenco > 0 and table.concat(elenco, '\n') or 'Nessun precedente registrato.',
    })
end)

-- ---------------------------------------------------------------------------
--  Segnalazioni dei giocatori
-- ---------------------------------------------------------------------------
AUREA.Comando('report', 'utente', 'Segnala un problema allo staff', {
    { name = 'testo', help = 'Descrizione della segnalazione' },
}, function(src, args, raw, g)
    if not g then return end

    local testo = table.concat(args, ' ')
    if #testo < 10 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Segnalazione troppo breve', testo = 'Descrivi il problema in modo comprensibile.',
        })
    end

    contatoreSegnalazioni = contatoreSegnalazioni + 1
    local id = contatoreSegnalazioni

    segnalazioni[id] = {
        id = id, src = src, citizenid = g.citizenid,
        nome = g:NomeCompleto(), testo = testo:sub(1, 400),
        aperta = os.time(), presaInCarico = nil,
    }

    AUREA.Log('staff', 'info', g, ('segnalazione #%d: %s'):format(id, testo))

    local staffOnline = 0
    for altroSrc in pairs(AUREA.Giocatori) do
        if AUREA.HaGruppo(altroSrc, 'supporto') then
            staffOnline = staffOnline + 1
            TriggerClientEvent('aurea:ui:notifica', altroSrc, {
                tipo = 'avviso', icona = '🛟', durata = 15000,
                titolo = ('Segnalazione #%d — %s'):format(id, g:NomeCompleto()),
                testo = ('%s\n\n/prendi %d per prenderla in carico.'):format(testo, id),
            })
        end
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🛟', durata = 11000,
        titolo = ('Segnalazione #%d inviata'):format(id),
        testo = staffOnline > 0
            and ('%d membri dello staff sono online.'):format(staffOnline)
            or 'Nessuno staff online al momento: apri un ticket sul Discord.',
    })
end)

AUREA.Comando('segnalazioni', 'supporto', 'Elenca le segnalazioni aperte', {}, function(src)
    local elenco = {}
    for id, s in pairs(segnalazioni) do
        if not s.presaInCarico then
            elenco[#elenco + 1] = ('#%d %s: %s'):format(id, s.nome, s.testo:sub(1, 60))
        end
    end
    table.sort(elenco)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '🛟', durata = 18000,
        titolo = ('%d segnalazioni aperte'):format(#elenco),
        testo = #elenco > 0 and table.concat(elenco, '\n') or 'Nessuna segnalazione in coda.',
    })
end)

AUREA.Comando('prendi', 'supporto', 'Prende in carico una segnalazione', {
    { name = 'id', help = 'Numero della segnalazione' },
}, function(src, args, _, staff)
    local id = tonumber(args[1])
    local s = id and segnalazioni[id]
    if not s then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non trovata', testo = 'Segnalazione inesistente o già chiusa.' })
    end
    if s.presaInCarico then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'avviso', titolo = 'Già in carico', testo = s.presaInCarico })
    end

    local nomeStaff = staff and staff:NomeCompleto() or 'console'
    s.presaInCarico = nomeStaff

    if AUREA.GetPlayer(s.src) then
        TriggerClientEvent('aurea:ui:notifica', s.src, {
            tipo = 'successo', icona = '🛟', durata = 12000,
            titolo = ('Segnalazione #%d presa in carico'):format(id),
            testo = ('%s se ne sta occupando.'):format(nomeStaff),
        })
        local coord = GetEntityCoords(GetPlayerPed(s.src))
        TriggerClientEvent('aurea:admin:teletrasporta', src, { x = coord.x, y = coord.y, z = coord.z })
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = ('Segnalazione #%d'):format(id),
        testo = ('Sei stato portato da %s.'):format(s.nome),
    })
end)

AUREA.Comando('chiudi', 'supporto', 'Chiude una segnalazione', {
    { name = 'id', help = 'Numero della segnalazione' },
}, function(src, args)
    local id = tonumber(args[1])
    if not id or not segnalazioni[id] then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non trovata', testo = '/chiudi <id>' })
    end

    local s = segnalazioni[id]
    segnalazioni[id] = nil

    if AUREA.GetPlayer(s.src) then
        TriggerClientEvent('aurea:ui:notifica', s.src, {
            tipo = 'info', icona = '🛟', titolo = ('Segnalazione #%d chiusa'):format(id),
            testo = 'Grazie per la collaborazione.',
        })
    end
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Chiusa', testo = ('Segnalazione #%d'):format(id) })
end)

-- ---------------------------------------------------------------------------
--  Modalità servizio staff
-- ---------------------------------------------------------------------------
AUREA.Comando('staff', 'supporto', 'Attiva o disattiva la modalità staff', {}, function(src, _, _, g)
    inServizioStaff[src] = not inServizioStaff[src]

    TriggerClientEvent('aurea:admin:modalitaStaff', src, inServizioStaff[src])
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = inServizioStaff[src] and 'successo' or 'info',
        icona = '🛡',
        titolo = inServizioStaff[src] and 'Modalità staff attiva' or 'Modalità staff disattivata',
        testo = inServizioStaff[src]
            and 'Invulnerabilità e strumenti abilitati. Non interferire con il roleplay.'
            or 'Sei tornato un cittadino qualunque.',
    })

    AUREA.Log('staff', 'info', g, ('modalità staff %s'):format(inServizioStaff[src] and 'attivata' or 'disattivata'))
end)

exports('InServizioStaff', function(src) return inServizioStaff[src] == true end)

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
AUREA.Comando('revive', 'moderatore', 'Rianima un giocatore', {
    { name = 'id', help = 'ID sessione (vuoto = te stesso)' },
}, function(src, args)
    local bersaglio = tonumber(args[1]) or src
    if not AUREA.GetPlayer(bersaglio) then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non trovato', testo = 'ID non valido.' })
    end

    TriggerClientEvent('aurea:admin:rianima', bersaglio)
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Rianimato', testo = ('ID %d'):format(bersaglio) })
    AUREA.Log('staff', 'info', src, ('ha rianimato il giocatore %d'):format(bersaglio))
end)

AUREA.Comando('annuncio', 'moderatore', 'Messaggio a tutto il server', {
    { name = 'testo', help = 'Testo dell\'annuncio' },
}, function(src, args, _, g)
    local testo = table.concat(args, ' ')
    if #testo < 3 then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/annuncio <testo>' })
    end

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'avviso', icona = '📢', durata = 15000,
        titolo = 'Comunicazione dello staff', testo = testo,
    })
    AUREA.Log('staff', 'info', g, ('annuncio: %s'):format(testo))
end)

AUREA.Comando('setgruppo', 'fondatore', 'Assegna un gruppo staff', {
    { name = 'id', help = 'ID sessione' },
    { name = 'gruppo', help = 'utente, supporto, moderatore, admin, gestore' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local gruppo = args[2]
    local C = AUREA.Config

    if not bersaglio or not C.Gruppi[gruppo] then
        local elenco = {}
        for nome in pairs(C.Gruppi) do elenco[#elenco + 1] = nome end
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = ('/setgruppo <id> <%s>'):format(table.concat(elenco, '|')),
        })
    end

    MySQL.update.await('UPDATE account SET gruppo = ? WHERE id = ?', { gruppo, bersaglio.accountId })
    bersaglio.gruppo = gruppo
    bersaglio:Sincronizza()

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Gruppo aggiornato', testo = ('%s → %s'):format(bersaglio:NomeCompleto(), gruppo),
    })
    AUREA.Log('staff', 'allarme', src, ('ha assegnato il gruppo %s a %s'):format(gruppo, bersaglio.citizenid))
end)

AddEventHandler('playerDropped', function()
    inServizioStaff[source] = nil
    for id, s in pairs(segnalazioni) do
        if s.src == source then segnalazioni[id] = nil end
    end
end)
