--[[
    AUREA · Whitelist (server)

    Il controllo sta in playerConnecting, prima che il giocatore entri:
    è l'unico punto in cui si può fermare qualcuno senza averlo già
    caricato in partita.
]]

local U = AUREA.Util

local function licenseDi(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function candidatura(license)
    return MySQL.single.await('SELECT * FROM whitelist WHERE license = ?', { license })
end

AddEventHandler('playerConnecting', function(nome, rifiuta, differisci)
    if not WL.Attiva then return end

    local src = source
    differisci.defer()
    Wait(100)

    local license = licenseDi(src)
    if not license then
        return rifiuta('Non riesco a identificarti. Riavvia FiveM e riprova.')
    end

    differisci.update('Verifica della whitelist in corso...')

    local account = MySQL.single.await('SELECT gruppo, bannato FROM account WHERE license = ?', { license })

    if account and account.bannato == 1 then
        return rifiuta('Il tuo accesso è stato revocato.')
    end

    -- Lo staff entra sempre
    if account and U.Contiene(WL.Regole.gruppiEsenti, account.gruppo) then
        return differisci.done()
    end

    local c = candidatura(license)

    if c and c.stato == 'accolta' then
        return differisci.done()
    end

    if c and c.stato == 'in_esame' then
        return rifiuta(WL.Regole.messaggioAttesa)
    end

    if c and c.stato == 'respinta' then
        local giorni = (os.time() - math.floor((c.decisa_il or 0) / 1000)) / 86400
        if giorni < WL.Regole.giorniRiprova then
            return rifiuta(('%s Puoi ripresentarla fra %d giorni.')
                :format(WL.Regole.messaggioRespinto,
                        math.ceil(WL.Regole.giorniRiprova - giorni)))
        end
    end

    -- Nessuna candidatura: si entra in "sala d'aspetto" per compilarla
    MySQL.query.await([[
        INSERT INTO whitelist (license, nome_gioco, stato) VALUES (?, ?, 'da_compilare')
        ON DUPLICATE KEY UPDATE nome_gioco = VALUES(nome_gioco), stato = 'da_compilare'
    ]], { license, nome })

    differisci.done()
end)

--- Chi entra senza candidatura accolta viene bloccato in gioco finché
--- non compila il modulo.
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    if not WL.Attiva then return end
    if AUREA.HaGruppo(src, WL.Regole.gruppoRevisore) then return end

    local license = licenseDi(src)
    local c = license and candidatura(license)

    if not c or c.stato ~= 'accolta' then
        TriggerClientEvent('wl:compila', src, WL.Modulo)
    end
end)

AUREA.Callback.Registra('wl:invia', function(src, rispondi, risposte)
    local license = licenseDi(src)
    if not license then return rispondi(false, 'Identificazione non riuscita.') end

    local c = candidatura(license)
    if c and c.stato == 'in_esame' then return rispondi(false, 'Ne hai già una in esame.') end
    if c and c.stato == 'accolta' then return rispondi(false, 'Sei già in whitelist.') end

    -- Le risposte obbligatorie e la lunghezza minima si controllano qui
    local pulite = {}
    for _, d in ipairs(WL.Modulo) do
        local r = tostring(risposte and risposte[d.id] or ''):sub(1, 2000)
        if d.obbligatoria and #r == 0 then
            return rispondi(false, ('Manca la risposta: %s'):format(d.domanda))
        end
        if d.minimo and #r < d.minimo then
            return rispondi(false, ('"%s" è troppo breve: servono almeno %d caratteri, ne hai scritti %d.')
                :format(d.domanda, d.minimo, #r))
        end
        pulite[d.id] = r
    end

    MySQL.query.await([[
        INSERT INTO whitelist (license, nome_gioco, risposte, stato, inviata_il)
        VALUES (?, ?, ?, 'in_esame', NOW())
        ON DUPLICATE KEY UPDATE risposte = VALUES(risposte), stato = 'in_esame',
                                inviata_il = NOW(), decisa_il = NULL
    ]], { license, GetPlayerName(src), json.encode(pulite) })

    exports.aurea_ui:NotificaLavoro(nil, {
        tipo = 'info', icona = '📄', durata = 14000,
        titolo = 'Nuova candidatura',
        testo = ('%s ha inviato la sua. Vedi /candidature.'):format(GetPlayerName(src)),
    }, false)

    AUREA.Log('staff', 'info', nil, ('Candidatura inviata da %s'):format(GetPlayerName(src)))
    rispondi(true, 'Candidatura inviata. Riceverai l\'esito appena qualcuno la legge.')
end)

-- ---------------------------------------------------------------------------
--  Revisione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('wl:candidature', function(src, rispondi)
    if not AUREA.HaGruppo(src, WL.Regole.gruppoRevisore) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, license, nome_gioco, risposte, inviata_il
        FROM whitelist WHERE stato = 'in_esame' ORDER BY inviata_il ASC LIMIT 30
    ]]) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.inviata_il or 0) / 1000))
        local ok, dati = pcall(json.decode, r.risposte or '{}')
        r.dati = ok and dati or {}
        r.risposte = nil
    end

    rispondi({ candidature = righe, modulo = WL.Modulo })
end)

AUREA.Callback.Registra('wl:decidi', function(src, rispondi, id, accolta, motivo)
    local g = AUREA.GetPlayer(src)
    if not g or not AUREA.HaGruppo(src, WL.Regole.gruppoRevisore) then
        return rispondi(false, 'Non sei autorizzato.')
    end

    local c = MySQL.single.await('SELECT * FROM whitelist WHERE id = ? AND stato = \'in_esame\'', { id })
    if not c then return rispondi(false, 'Candidatura non trovata.') end

    MySQL.update.await([[
        UPDATE whitelist SET stato = ?, decisa_il = NOW(), decisa_da = ?, motivo = ? WHERE id = ?
    ]], { accolta and 'accolta' or 'respinta', g:NomeCompleto(),
          tostring(motivo or ''):sub(1, 300), id })

    -- Se è in linea, glielo si dice subito
    for altroSrc in pairs(AUREA.Giocatori) do
        if licenseDi(altroSrc) == c.license then
            TriggerClientEvent('wl:esito', altroSrc, accolta, motivo)
            if not accolta then
                CreateThread(function()
                    Wait(8000)
                    DropPlayer(altroSrc, WL.Regole.messaggioRespinto)
                end)
            end
            break
        end
    end

    AUREA.Log('staff', 'info', g, ('candidatura di %s: %s')
        :format(c.nome_gioco, accolta and 'accolta' or 'respinta'))

    rispondi(true, accolta and 'Candidatura accolta.' or 'Candidatura respinta.')
end)
