--[[
    AUREA · Agenzia scommesse (server)
]]

local U = AUREA.Util

local function evento(id)
    return MySQL.single.await('SELECT * FROM scommesse_eventi WHERE id = ?', { id })
end

local function monte(id)
    local righe = MySQL.query.await([[
        SELECT esito, SUM(importo) AS totale, COUNT(*) AS quante
        FROM scommesse WHERE evento_id = ? GROUP BY esito
    ]], { id }) or {}

    local perEsito, totale, quante = {}, 0, 0
    for _, r in ipairs(righe) do
        perEsito[r.esito] = tonumber(r.totale) or 0
        totale = totale + perEsito[r.esito]
        quante = quante + (tonumber(r.quante) or 0)
    end
    return perEsito, totale, quante
end

-- ---------------------------------------------------------------------------
--  Consultazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sco:eventi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT e.*, p.nome, p.cognome
        FROM scommesse_eventi e
        LEFT JOIN personaggi p ON p.citizenid = e.organizzatore
        WHERE e.stato != 'pagato' ORDER BY e.id DESC LIMIT 20
    ]]) or {}

    local out = {}
    for _, e in ipairs(righe) do
        local perEsito, totale = monte(e.id)
        local esiti = {}
        for _, nome in ipairs(json.decode(e.esiti) or {}) do
            esiti[#esiti + 1] = {
                nome = nome,
                puntato = perEsito[nome] or 0,
                quota = SCO.Quota(totale, perEsito[nome] or 0),
            }
        end

        local mia = MySQL.single.await(
            'SELECT esito, importo FROM scommesse WHERE evento_id = ? AND citizenid = ?',
            { e.id, g.citizenid })

        out[#out + 1] = {
            id = e.id, titolo = e.titolo, stato = e.stato,
            organizzatore = e.nome and ('%s %s'):format(e.nome, e.cognome) or 'staff',
            esiti = esiti, monte = totale,
            vincente = e.esito_vincente,
            mia = mia and { esito = mia.esito, importo = tonumber(mia.importo) } or nil,
        }
    end

    rispondi({ eventi = out, regole = SCO.Regole })
end)

-- ---------------------------------------------------------------------------
--  Apertura di un evento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sco:apri', function(src, rispondi, titolo, esiti)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not SCO.AgenziaVicina(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Devi essere in ricevitoria.')
    end

    titolo = tostring(titolo or ''):sub(1, 90)
    if #titolo < 6 then return rispondi(false, 'Descrivi meglio l\'evento.') end

    local elenco = {}
    for _, e in ipairs(esiti or {}) do
        local n = tostring(e or ''):sub(1, 40)
        if #n >= 2 then elenco[#elenco + 1] = n end
    end
    if #elenco < 2 then return rispondi(false, 'Servono almeno due esiti possibili.') end
    if #elenco > 8 then return rispondi(false, 'Al massimo otto esiti.') end

    local esente = AUREA.HaGruppo(src, SCO.Organizzatori.gruppoEsente)
    if not esente then
        if not g:SottraiOvunque(SCO.Regole.cauzioneEvento, 'cauzione evento scommesse') then
            return rispondi(false, ('Serve una cauzione di %s, che torna quando dichiari l\'esito.')
                :format(U.Euro(SCO.Regole.cauzioneEvento)))
        end
    end

    local id = MySQL.insert.await([[
        INSERT INTO scommesse_eventi (organizzatore, titolo, esiti, cauzione, stato)
        VALUES (?, ?, ?, ?, 'aperto')
    ]], { g.citizenid, titolo, json.encode(elenco), esente and 0 or SCO.Regole.cauzioneEvento })

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '🎫', durata = 15000,
        titolo = 'Nuove scommesse aperte',
        testo = ('%s — %s. Si punta in ricevitoria.'):format(titolo, table.concat(elenco, ' / ')),
    })

    -- Un evento non resta aperto per sempre
    CreateThread(function()
        Wait(SCO.Regole.minutiMassimi * 60000)
        local e = evento(id)
        if e and e.stato == 'aperto' then
            MySQL.update('UPDATE scommesse_eventi SET stato = \'chiuso\' WHERE id = ?', { id })
        end
    end)

    rispondi(true, ('Evento aperto. Resta in raccolta per %d minuti.'):format(SCO.Regole.minutiMassimi))
end)

-- ---------------------------------------------------------------------------
--  Puntata
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sco:punta', function(src, rispondi, idEvento, esito, importo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not SCO.AgenziaVicina(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Devi essere in ricevitoria.')
    end

    local e = evento(idEvento)
    if not e or e.stato ~= 'aperto' then return rispondi(false, 'Le puntate su questo evento sono chiuse.') end
    if e.organizzatore == g.citizenid then
        return rispondi(false, 'Non puoi puntare su un evento che hai aperto tu.')
    end

    local ammessi = json.decode(e.esiti) or {}
    if not U.Contiene(ammessi, esito) then return rispondi(false, 'Esito non previsto.') end

    importo = math.floor(U.Clamp(tonumber(importo) or 0,
        SCO.Regole.puntataMinima, SCO.Regole.puntataMassima))

    local gia = MySQL.scalar.await('SELECT id FROM scommesse WHERE evento_id = ? AND citizenid = ?',
        { idEvento, g.citizenid })
    if gia then return rispondi(false, 'Hai già una giocata su questo evento.') end

    if not g:SottraiOvunque(importo, ('scommessa · %s'):format(e.titolo)) then
        return rispondi(false, ('Non hai %s.'):format(U.Euro(importo)))
    end

    MySQL.insert.await('INSERT INTO scommesse (evento_id, citizenid, esito, importo) VALUES (?, ?, ?, ?)',
        { idEvento, g.citizenid, esito, importo })

    local perEsito, totale = monte(idEvento)
    rispondi(true, ('Giocata registrata: %s su "%s". Quota attuale %.2f.')
        :format(U.Euro(importo), esito, SCO.Quota(totale, perEsito[esito] or 0)))
end)

-- ---------------------------------------------------------------------------
--  Esito e pagamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sco:dichiara', function(src, rispondi, idEvento, esito)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local e = evento(idEvento)
    if not e then return rispondi(false, 'Evento inesistente.') end
    if e.stato == 'pagato' then return rispondi(false, 'Già liquidato.') end

    local suo = e.organizzatore == g.citizenid
    if not suo and not AUREA.HaGruppo(src, SCO.Organizzatori.gruppoEsente) then
        return rispondi(false, 'Non sei tu ad aver aperto questo evento.')
    end

    local ammessi = json.decode(e.esiti) or {}
    if not U.Contiene(ammessi, esito) then return rispondi(false, 'Esito non previsto.') end

    local perEsito, totale, quante = monte(idEvento)

    -- Troppo poche giocate: si restituisce tutto e non se ne parla più
    if quante < SCO.Regole.scommesseMinimePerPagare then
        local righe = MySQL.query.await('SELECT citizenid, importo FROM scommesse WHERE evento_id = ?',
            { idEvento }) or {}
        for _, r in ipairs(righe) do
            AUREA.Denaro.AggiungiOffline(r.citizenid, 'banca', tonumber(r.importo), 'rimborso scommessa')
        end
        MySQL.update.await('UPDATE scommesse_eventi SET stato = \'pagato\', esito_vincente = ? WHERE id = ?',
            { esito, idEvento })
        if e.cauzione > 0 then
            AUREA.Denaro.AggiungiOffline(e.organizzatore, 'banca', tonumber(e.cauzione), 'restituzione cauzione')
        end
        return rispondi(true, 'Troppe poche giocate: rimborsate tutte.')
    end

    local monteVincente = perEsito[esito] or 0
    local netto = math.floor(totale * (1 - SCO.Regole.quotaAgenzia))
    local trattenuta = totale - netto

    local pagati = 0
    if monteVincente > 0 then
        local vincitori = MySQL.query.await(
            'SELECT citizenid, importo FROM scommesse WHERE evento_id = ? AND esito = ?',
            { idEvento, esito }) or {}

        for _, v in ipairs(vincitori) do
            local quota = tonumber(v.importo) / monteVincente
            local lordo = math.floor(netto * quota)
            local imposta = math.floor(math.max(0, lordo - tonumber(v.importo)) * SCO.Regole.aliquotaImposta)

            AUREA.Denaro.AggiungiOffline(v.citizenid, 'banca', lordo - imposta, 'vincita scommessa')
            TriggerEvent('aurea:fisco:incasso', 'imposta_vincite', imposta, v.citizenid)
            pagati = pagati + 1

            local vincitore = AUREA.GetPlayerByCitizenId(v.citizenid)
            if vincitore then
                TriggerClientEvent('aurea:ui:notifica', vincitore.source, {
                    tipo = 'successo', icona = '🎫', durata = 15000,
                    titolo = 'Hai vinto',
                    testo = ('%s — accreditati %s al netto dell\'imposta.'):format(e.titolo, U.Euro(lordo - imposta)),
                })
            end
        end
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_giochi', trattenuta, nil)

    if e.cauzione > 0 then
        AUREA.Denaro.AggiungiOffline(e.organizzatore, 'banca', tonumber(e.cauzione), 'restituzione cauzione')
    end

    MySQL.update.await('UPDATE scommesse_eventi SET stato = \'pagato\', esito_vincente = ? WHERE id = ?',
        { esito, idEvento })

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '🎫', durata = 15000,
        titolo = 'Esito dichiarato',
        testo = ('%s → %s. Pagati %d giocatori.'):format(e.titolo, esito, pagati),
    })

    AUREA.Log('economia', 'info', g, ('scommesse: evento %d chiuso su "%s", monte %s')
        :format(idEvento, esito, U.Euro(totale)))

    rispondi(true, ('Esito registrato. Pagati %d vincitori su un monte di %s.'):format(pagati, U.Euro(totale)))
end)
