--[[
    AUREA · Detenzione (server)
    La pena scorre solo mentre il condannato è in gioco e dentro il perimetro.
]]

Detenzione = {}

local U = AUREA.Util
local attive = {}      -- [citizenid] = { id, totali, scontati, ultimoTick }

--- Avvia l'esecuzione della pena.
function Detenzione.Avvia(giocatore, minuti, motivo, agente)
    local id = MySQL.insert.await([[
        INSERT INTO detenzioni (citizenid, minuti_totali, motivo, regime)
        VALUES (?, ?, ?, ?)
    ]], { giocatore.citizenid, minuti, motivo, minuti > 150 and 'alta_sicurezza' or 'ordinario' })

    attive[giocatore.citizenid] = {
        id = id, totali = minuti, scontati = 0, ultimoTick = os.time(),
    }

    giocatore:Set('detenuto', true, true)
    giocatore.metadata.detenuto = true

    MySQL.update('UPDATE casellario SET stato = \'condannato\', chiuso_il = NOW() WHERE citizenid = ? AND stato = \'indagato\'',
        { giocatore.citizenid })

    TriggerClientEvent('giu:incarcerato', giocatore.source, {
        minuti = minuti, motivo = motivo, agente = agente,
    })

    -- L'ufficio matricola prende in carico il detenuto: effetti personali
    -- in deposito, contanti sul peculio
    TriggerEvent('aurea:carcere:ingresso', giocatore.citizenid, minuti, motivo)

    AUREA.Log('giustizia', 'avviso', giocatore, ('detenzione di %d minuti: %s'):format(minuti, motivo))
end

--- Rilascio a fine pena (o per provvedimento).
function Detenzione.Rilascia(citizenid, motivo)
    local stato = attive[citizenid]
    if stato then
        MySQL.update('UPDATE detenzioni SET attiva = 0, fine = NOW(), minuti_scontati = ? WHERE id = ?',
            { stato.scontati, stato.id })
        attive[citizenid] = nil
    else
        MySQL.update('UPDATE detenzioni SET attiva = 0, fine = NOW() WHERE citizenid = ? AND attiva = 1', { citizenid })
    end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        g:Set('detenuto', false, true)
        g.metadata.detenuto = false
        g:Set('ricercato', 0, true)
        TriggerClientEvent('giu:scarcerato', g.source, motivo or 'fine pena')
    end

    -- Restituzione degli effetti personali e chiusura del peculio
    TriggerEvent('aurea:carcere:uscita', citizenid, motivo or 'fine pena')

    AUREA.Log('giustizia', 'info', nil, ('%s scarcerato (%s)'):format(citizenid, motivo or 'fine pena'))
end

exports('Incarcera', function(citizenid, minuti, motivo)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then Detenzione.Avvia(g, minuti, motivo, 'provvedimento') end
end)
exports('Rilascia', Detenzione.Rilascia)

--- Stato corrente della detenzione.
function Detenzione.Stato(citizenid)
    local s = attive[citizenid]
    if not s then return nil end
    return { totali = s.totali, scontati = s.scontati, residui = math.max(0, s.totali - s.scontati) }
end

exports('StatoDetenzione', Detenzione.Stato)

-- ---------------------------------------------------------------------------
--  Ripresa al rientro in gioco
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    local riga = MySQL.single.await(
        'SELECT id, minuti_totali, minuti_scontati, motivo FROM detenzioni WHERE citizenid = ? AND attiva = 1', { g.citizenid })
    if not riga then return end

    attive[g.citizenid] = {
        id = riga.id, totali = riga.minuti_totali,
        scontati = riga.minuti_scontati, ultimoTick = os.time(),
    }
    g:Set('detenuto', true, true)
    g.metadata.detenuto = true

    TriggerClientEvent('giu:incarcerato', src, {
        minuti = riga.minuti_totali - riga.minuti_scontati,
        motivo = riga.motivo, ripresa = true,
    })
end)

-- ---------------------------------------------------------------------------
--  Scorrere della pena
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)

        for citizenid, stato in pairs(attive) do
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            if g then
                -- la pena scorre solo se il detenuto è dentro il perimetro
                local coord = GetEntityCoords(GetPlayerPed(g.source))
                local dentro = #(coord - GIU.Carcere.perimetro.centro) <= GIU.Carcere.perimetro.raggio

                if dentro then
                    stato.scontati = stato.scontati + 1
                    MySQL.update('UPDATE detenzioni SET minuti_scontati = ? WHERE id = ?', { stato.scontati, stato.id })

                    local residui = stato.totali - stato.scontati
                    TriggerClientEvent('giu:aggiornaPena', g.source, residui, stato.totali)

                    if residui <= 0 then
                        Detenzione.Rilascia(citizenid, 'fine pena')
                    end
                else
                    -- fuori dal perimetro: evasione
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'errore', icona = '🚨', durata = 10000,
                        titolo = 'Sei fuori dal perimetro',
                        testo = 'La pena non scorre. Rientra subito o scatterà una nuova imputazione.',
                    })

                    stato.avvisi = (stato.avvisi or 0) + 1
                    if stato.avvisi >= 3 then
                        stato.avvisi = 0
                        stato.totali = stato.totali + GIU.Regole.penaEvasione
                        MySQL.update('UPDATE detenzioni SET minuti_totali = ? WHERE id = ?', { stato.totali, stato.id })
                        exports.ita_giustizia:ApriFascicolo(citizenid, '385', 'direzione dell\'istituto', 'Allontanamento dall\'istituto')

                        exports.aurea_ui:NotificaLavoro('carabinieri', {
                            tipo = 'errore', icona = '🚨', durata = 15000,
                            titolo = 'EVASIONE IN CORSO',
                            testo = ('%s si è allontanato dalla Casa Circondariale.'):format(g:NomeCompleto()),
                        }, true)

                        TriggerClientEvent('aurea:ui:notifica', g.source, {
                            tipo = 'errore', icona = '⚖', durata = 13000,
                            titolo = 'Evasione contestata',
                            testo = ('Pena aumentata di %d minuti ai sensi dell\'art. 385 c.p.'):format(GIU.Regole.penaEvasione),
                        })
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Attività trattamentali e cauzione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('giu:attivita', function(src, rispondi, idAttivita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local stato = attive[g.citizenid]
    if not stato then return rispondi(false, 'Non risulti detenuto.') end

    local attivita
    for _, a in ipairs(GIU.Attivita) do
        if a.id == idAttivita then attivita = a break end
    end
    if not attivita then return rispondi(false, 'Attività non riconosciuta.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - attivita.coord) > 6.0 then return rispondi(false, 'Non sei nel luogo dell\'attività.') end

    -- Il lavoro non può azzerare la pena: si sconta al massimo una quota
    local massimo = math.floor(stato.totali * GIU.Regole.massimoRiduzione)
    local giaScontatiConLavoro = stato.daLavoro or 0
    if giaScontatiConLavoro >= massimo then
        return rispondi(false, 'Hai già ottenuto la massima riduzione consentita per buona condotta.')
    end

    local sconto = math.min(attivita.sconto, massimo - giaScontatiConLavoro)
    stato.daLavoro = giaScontatiConLavoro + sconto
    stato.scontati = stato.scontati + sconto
    MySQL.update('UPDATE detenzioni SET minuti_scontati = ? WHERE id = ?', { stato.scontati, stato.id })

    local residui = math.max(0, stato.totali - stato.scontati)
    TriggerClientEvent('giu:aggiornaPena', src, residui, stato.totali)

    if residui <= 0 then Detenzione.Rilascia(g.citizenid, 'fine pena con liberazione anticipata') end

    rispondi(true, ('%s: %d minuti di pena scontati. Residui %d.'):format(attivita.nome, sconto, residui))
end)

AUREA.Callback.Registra('giu:cauzione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local stato = attive[g.citizenid]
    if not stato then return rispondi(false, 'Non risulti detenuto.') end

    -- La cauzione non è ammessa per i reati gravi né dopo un'evasione
    local gravita = MySQL.scalar.await([[
        SELECT MAX(gravita) FROM casellario WHERE citizenid = ? AND stato = 'condannato'
          AND chiuso_il > DATE_SUB(NOW(), INTERVAL 2 HOUR)
    ]], { g.citizenid }) or 1

    if gravita > GIU.Regole.cauzioneMassimaGravita then
        return rispondi(false, 'La gravità dei reati contestati non ammette la liberazione su cauzione.')
    end

    local residui = math.max(0, stato.totali - stato.scontati)
    local importo = residui * GIU.Regole.cauzionePerMinuto

    if not g:SottraiOvunque(importo, 'cauzione') then
        return rispondi(false, ('La cauzione ammonta a %s.'):format(U.Euro(importo)))
    end

    TriggerEvent('aurea:fisco:incasso', 'cauzioni', importo, g.citizenid)
    Detenzione.Rilascia(g.citizenid, 'liberazione su cauzione')

    rispondi(true, ('Liberato su cauzione per %s. I precedenti restano iscritti.'):format(U.Euro(importo)))
end)

AUREA.Callback.Registra('giu:statoDetenzione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local stato = Detenzione.Stato(g.citizenid)
    if not stato then return rispondi(nil) end

    local gravita = MySQL.scalar.await([[
        SELECT MAX(gravita) FROM casellario WHERE citizenid = ? AND stato = 'condannato'
          AND chiuso_il > DATE_SUB(NOW(), INTERVAL 2 HOUR)
    ]], { g.citizenid }) or 1

    stato.cauzionePossibile = gravita <= GIU.Regole.cauzioneMassimaGravita
    stato.cauzione = stato.residui * GIU.Regole.cauzionePerMinuto
    rispondi(stato)
end)

-- ---------------------------------------------------------------------------
--  Patteggiamento con l'assistenza di un avvocato
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('giu:patteggia', function(src, rispondi, avvocatoSrc)
    local g = AUREA.GetPlayer(src)
    local avvocato = AUREA.GetPlayer(tonumber(avvocatoSrc))
    if not g or not avvocato then return rispondi(false, 'Serve un avvocato presente.') end
    if not avvocato:HaPermessoLavoro('patteggiamento') then
        return rispondi(false, 'Il legale non ha titolo per il patteggiamento.')
    end

    local stato = attive[g.citizenid]
    if not stato then return rispondi(false, 'Non risulti detenuto.') end

    if not g:SottraiOvunque(GIU.Tribunale.onorarioAvvocato, 'onorario legale') then
        return rispondi(false, ('L\'onorario è di %s.'):format(U.Euro(GIU.Tribunale.onorarioAvvocato)))
    end
    avvocato:Aggiungi('banca', GIU.Tribunale.onorarioAvvocato, ('patrocinio di %s'):format(g:NomeCompleto()))

    local residui = math.max(0, stato.totali - stato.scontati)
    local riduzione = math.floor(residui * GIU.Tribunale.scontoPatteggiamento)
    stato.totali = stato.totali - riduzione
    MySQL.update('UPDATE detenzioni SET minuti_totali = ? WHERE id = ?', { stato.totali, stato.id })

    local nuoviResidui = math.max(0, stato.totali - stato.scontati)
    TriggerClientEvent('giu:aggiornaPena', src, nuoviResidui, stato.totali)
    if nuoviResidui <= 0 then Detenzione.Rilascia(g.citizenid, 'patteggiamento') end

    rispondi(true, ('Patteggiamento accolto: pena ridotta di %d minuti. Residui %d.'):format(riduzione, nuoviResidui))
end)

AddEventHandler('aurea:giocatore:scaricato', function(_, g)
    local stato = attive[g.citizenid]
    if stato then
        MySQL.update('UPDATE detenzioni SET minuti_scontati = ? WHERE id = ?', { stato.scontati, stato.id })
        attive[g.citizenid] = nil
    end
end)
