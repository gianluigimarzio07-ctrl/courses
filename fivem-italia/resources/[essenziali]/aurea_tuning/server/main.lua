--[[
    AUREA · Elaborazione (server)
]]

local U = AUREA.Util

--- Legge le proprietà del veicolo dal registro.
local function proprieta(targa)
    local v = MySQL.single.await('SELECT citizenid, proprieta FROM veicoli WHERE targa = ?', { targa })
    if not v then return nil end
    return v.proprieta and json.decode(v.proprieta) or {}, v.citizenid
end

local function salvaProprieta(targa, p)
    MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(p), targa })
end

-- ---------------------------------------------------------------------------
--  Preventivo e lavorazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tun:statoVeicolo', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local p, intestatario = proprieta(targa)
    if not p then return rispondi(nil, 'Veicolo non immatricolato.') end

    rispondi({
        targa = targa,
        tuo = intestatario == g.citizenid,
        modifiche = p.modifiche or {},
        omologato = p.omologato ~= false,
        fuoriNorma = p.fuoriNorma == true,
        eMeccanico = g.lavoro.nome == 'meccanico' and g:HaPermessoLavoro('tuning'),
    })
end)

AUREA.Callback.Registra('tun:applica', function(src, rispondi, targa, modifiche, clandestina)
    local g = AUREA.GetPlayer(src)
    if not g or type(modifiche) ~= 'table' then return rispondi(false, 'Richiesta non valida.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local p, intestatario = proprieta(targa)
    if not p then return rispondi(false, 'Veicolo non immatricolato.') end

    -- Serve essere intestatari o avere le chiavi
    if intestatario ~= g.citizenid and not U.Contiene(p.chiavi or {}, g.citizenid) then
        return rispondi(false, 'Non hai titolo per far lavorare questo veicolo.')
    end

    -- Il prezzo lo ricostruisce il server dal listino
    local totale = 0
    local applicate = {}

    for id, valore in pairs(modifiche) do
        local estetica = TUN.GetEstetica(id)
        local meccanica = TUN.GetMeccanica(id)
        local voce = estetica or meccanica
        if voce then
            -- si paga solo ciò che cambia davvero
            local attuale = (p.modifiche or {})[id]
            if attuale ~= valore then
                totale = totale + voce.prezzo
                applicate[id] = valore
            end
        end
    end

    if next(applicate) == nil then return rispondi(false, 'Non hai scelto nessuna modifica.') end

    totale = math.floor(totale * (1 + TUN.Regole.manodopera))
    if clandestina then totale = math.floor(totale * TUN.Clandestina.ricarico) end
    if g.lavoro.nome == 'meccanico' and g:HaPermessoLavoro('tuning') and not clandestina then
        totale = math.floor(totale * (1 - TUN.Regole.scontoMeccanico))
    end

    if not g:SottraiOvunque(totale, ('elaborazione %s'):format(targa)) then
        return rispondi(false, ('Il preventivo è di %s.'):format(U.Euro(totale)))
    end

    -- Le modifiche entrano nelle proprietà del veicolo
    p.modifiche = p.modifiche or {}
    for id, valore in pairs(applicate) do p.modifiche[id] = valore end

    -- Chi lavora in nero non rilascia certificazioni
    local richiede = TUN.RichiedeOmologazione(p.modifiche)
    if richiede then
        p.omologato = false
        p.fuoriNorma = true
    end
    if clandestina then
        p.clandestino = true
        p.omologato = false
        p.fuoriNorma = richiede
    end

    salvaProprieta(targa, p)

    if not clandestina then
        TriggerEvent('aurea:fisco:incasso', 'iva', math.floor(totale * 0.18), g.citizenid)
    end

    AUREA.Log('veicoli', 'info', g, ('elaborazione su %s per %s%s'):format(
        targa, U.Euro(totale), clandestina and ' (officina non autorizzata)' or ''))

    local avviso = nil
    if p.fuoriNorma then
        avviso = 'Le modifiche meccaniche vanno annotate sulla carta di circolazione: passa dalla Motorizzazione. Finché non lo fai il veicolo è fuori norma (art. 78 CdS).'
    end

    rispondi(true, ('Lavoro eseguito per %s.'):format(U.Euro(totale)), avviso, p.modifiche)
end)

-- ---------------------------------------------------------------------------
--  Omologazione presso la Motorizzazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tun:omologa', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local p, intestatario = proprieta(targa)
    if not p then return rispondi(false, 'Veicolo non immatricolato.') end
    if intestatario ~= g.citizenid then return rispondi(false, 'Solo l\'intestatario può presentare la pratica.') end

    if p.omologato ~= false then return rispondi(false, 'Il veicolo è già in regola.') end

    -- Un veicolo passato per un'officina non autorizzata non ha le carte dei pezzi
    if p.clandestino then
        return rispondi(false, 'I componenti montati non hanno certificazione: la pratica non è ricevibile. Ti serve un\'officina autorizzata che rifaccia il lavoro.')
    end

    -- Alcune modifiche non sono omologabili in nessun caso
    local modifiche = p.modifiche or {}
    if (modifiche.finestrini or 0) > TUN.Regole.vetriMassimiOmologati then
        return rispondi(false, 'L\'oscuramento dei vetri anteriori supera i limiti di legge: va rimosso prima del collaudo.')
    end
    if type(modifiche.sospensioni) == 'number' and modifiche.sospensioni > TUN.Regole.assettoMassimoOmologato then
        return rispondi(false, 'L\'assetto è troppo ribassato per essere omologato: alza il veicolo e ripresentati.')
    end

    if not g:SottraiOvunque(TUN.Motorizzazione.costoPratica, ('omologazione %s'):format(targa)) then
        return rispondi(false, ('La pratica costa %s.'):format(U.Euro(TUN.Motorizzazione.costoPratica)))
    end

    p.omologato = true
    p.fuoriNorma = false
    salvaProprieta(targa, p)

    TriggerEvent('aurea:fisco:incasso', 'motorizzazione', TUN.Motorizzazione.costoPratica, g.citizenid)

    -- La carta di circolazione viene aggiornata
    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'libretto', 1, {
        targa = targa, modello = 'aggiornato', annotazioni = 'Modifiche omologate',
        classe = 'da collaudo',
    })

    rispondi(true, ('Modifiche annotate sulla carta di circolazione. Costo %s.'):format(
        U.Euro(TUN.Motorizzazione.costoPratica)))
end)

-- ---------------------------------------------------------------------------
--  Controllo su strada
-- ---------------------------------------------------------------------------
AUREA.Comando('controllomodifiche', 'utente', 'Verifica se un veicolo è regolarmente omologato', {
    { name = 'targa', help = 'Targa del veicolo' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('mdt') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato alle forze dell\'ordine.',
        })
    end

    local targa = (args[1] or ''):upper():gsub('%s+', '')
    local p, intestatario = proprieta(targa)
    if not p then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Targa sconosciuta', testo = targa,
        })
    end

    local elenco = {}
    for id in pairs(p.modifiche or {}) do
        local voce = TUN.GetMeccanica(id)
        if voce then elenco[#elenco + 1] = voce.nome end
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = p.fuoriNorma and 'errore' or 'successo',
        icona = '🔧', durata = 14000,
        titolo = ('%s — modifiche'):format(targa),
        testo = ('%s\nModifiche meccaniche: %s\n%s'):format(
            p.fuoriNorma and 'VEICOLO FUORI NORMA (art. 78 CdS)' or 'Veicolo regolarmente omologato',
            #elenco > 0 and table.concat(elenco, ', ') or 'nessuna',
            p.clandestino and 'Componenti privi di certificazione.' or ''),
    })
end)

AUREA.Comando('verbalemodifiche', 'utente', 'Sanziona un veicolo fuori norma', {
    { name = 'targa', help = 'Targa del veicolo' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('multa') or not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Serve il servizio attivo.',
        })
    end

    local targa = (args[1] or ''):upper():gsub('%s+', '')
    local p, intestatario = proprieta(targa)
    if not p then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Targa sconosciuta', testo = targa })
    end

    if not p.fuoriNorma then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', titolo = 'Veicolo regolare', testo = 'Nessuna modifica da contestare.',
        })
    end

    exports.ita_codicestrada:EmettiVerbale({
        citizenid = intestatario,
        targa = targa,
        articolo = 'art. 78 CdS',
        descrizione = 'Circolazione con modifiche non annotate sulla carta di circolazione',
        importo = TUN.Regole.sanzioneImporto,
        punti = 0,
        origine = 'agente',
        agente = g:NomeCompleto(),
        luogo = 'controllo su strada',
    })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '📄', titolo = 'Verbale elevato',
        testo = ('%s — art. 78 CdS, %s'):format(targa, U.Euro(TUN.Regole.sanzioneImporto)),
    })
end)
