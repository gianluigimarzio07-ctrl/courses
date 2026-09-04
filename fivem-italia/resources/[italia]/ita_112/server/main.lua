--[[
    AUREA · Centrale Operativa 112 (server)
]]

local U = AUREA.Util
local ultimaChiamata = {}      -- [citizenid] = os.time()
local contatoreCodice = 0

-- ---------------------------------------------------------------------------
--  Creazione di un intervento
-- ---------------------------------------------------------------------------

--- Genera un codice intervento leggibile: 112-260904-0031
local function nuovoCodice()
    contatoreCodice = contatoreCodice + 1
    return ('112-%s-%04d'):format(os.date('%y%m%d'), contatoreCodice % 10000)
end

--- Apre un intervento e allerta gli enti competenti.
---@param dati table { tipologiaId, descrizione, coord, indirizzo, chiamante, numero, prioritaForzata }
---@return integer|nil id, string|nil codice
function NUE.Apri(dati)
    local tipologia = NUE.GetTipologia(dati.tipologiaId)
    if not tipologia then return nil end

    local enti = NUE.EntiPer(tipologia)
    local priorita = dati.prioritaForzata or tipologia.priorita
    local codice = nuovoCodice()

    local id = MySQL.insert.await([[
        INSERT INTO chiamate_112
            (codice, chiamante, numero, ente, priorita, tipologia, descrizione, coord, indirizzo)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        codice, dati.chiamante, dati.numero,
        #enti > 1 and 'multiplo' or enti[1],
        priorita, tipologia.etichetta, dati.descrizione,
        json.encode(dati.coord), dati.indirizzo,
    })

    -- Allerta di tutti gli operatori in servizio degli enti competenti
    local destinatari = 0
    for _, ente in ipairs(enti) do
        local operatori = AUREA.GetGiocatoriPerEnte(ente, true)
        for _, op in ipairs(operatori) do
            destinatari = destinatari + 1
            TriggerClientEvent('nue:intervento', op.source, {
                id = id,
                codice = codice,
                priorita = priorita,
                tipologia = tipologia.etichetta,
                descrizione = dati.descrizione,
                indirizzo = dati.indirizzo,
                coord = dati.coord,
                enti = enti,
            })
        end
    end

    AUREA.Log('giustizia', 'info', nil, ('112 %s — %s (%s) a %s [%d operatori allertati]'):format(
        codice, tipologia.etichetta, priorita, dati.indirizzo or '?', destinatari))

    return id, codice, destinatari
end

exports('ApriIntervento', NUE.Apri)

--- Interfaccia semplificata per gli altri moduli (spari, incendi, incidenti).
AddEventHandler('aurea:112:allerta', function(tipologiaId, coord, descrizione, indirizzo)
    NUE.Apri({
        tipologiaId = tipologiaId,
        descrizione = descrizione,
        coord = coord,
        indirizzo = indirizzo,
        chiamante = nil,
        numero = 'automatico',
    })
end)

-- ---------------------------------------------------------------------------
--  Chiamata da parte di un cittadino
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nue:chiama', function(src, rispondi, tipologiaId, descrizione, coord, indirizzo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local adesso = os.time()
    if (adesso - (ultimaChiamata[g.citizenid] or 0)) < NUE.Regole.intervalloChiamate then
        return rispondi(false, 'Hai già una chiamata in corso con la centrale. Attendi.')
    end
    ultimaChiamata[g.citizenid] = adesso

    local tipologia = NUE.GetTipologia(tipologiaId)
    if not tipologia then return rispondi(false, 'Tipologia non riconosciuta.') end

    -- la posizione la prende il server dal ped, non dal client
    local posizione = GetEntityCoords(GetPlayerPed(src))
    local id, codice, destinatari = NUE.Apri({
        tipologiaId = tipologiaId,
        descrizione = tostring(descrizione or ''):sub(1, 240),
        coord = { x = posizione.x, y = posizione.y, z = posizione.z },
        indirizzo = tostring(indirizzo or ''):sub(1, 120),
        chiamante = g.citizenid,
        numero = g.telefono,
    })

    if not id then return rispondi(false, 'La centrale non ha potuto registrare la chiamata.') end

    local attesa = NUE.Priorita[tipologia.priorita].attesa
    rispondi(true, ('Chiamata registrata con codice %s. %s. %s'):format(
        codice,
        NUE.Priorita[tipologia.priorita].etichetta,
        destinatari > 0
            and ('Sono state allertate %d pattuglie: resta sul posto.'):format(destinatari)
            or ('Nessun mezzo attualmente in servizio. Tempo di attesa stimato: %d minuti.'):format(math.ceil(attesa / 60))
    ))
end)

-- ---------------------------------------------------------------------------
--  Segnalazioni automatiche generate dal mondo di gioco
--  Non identificano mai il chiamante: la centrale riceve solo il luogo.
-- ---------------------------------------------------------------------------
local ultimaAutomatica = {}

RegisterNetEvent('nue:segnalazioneAutomatica', function(tipologiaId, coord, indirizzo, silenziata)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local tipologia = NUE.GetTipologia(tipologiaId)
    if not tipologia then return end

    -- anti-flood per giocatore e tipologia
    local chiave = ('%s:%s'):format(g.citizenid, tipologiaId)
    local adesso = os.time()
    if (adesso - (ultimaAutomatica[chiave] or 0)) < 60 then return end
    ultimaAutomatica[chiave] = adesso

    -- la posizione la determina il server
    local posizione = GetEntityCoords(GetPlayerPed(src))

    NUE.Apri({
        tipologiaId = tipologiaId,
        descrizione = silenziata
            and 'Segnalazione generica: rumore attutito, nessun testimone diretto.'
            or 'Segnalazione pervenuta da più utenti della zona.',
        coord = { x = posizione.x, y = posizione.y, z = posizione.z },
        indirizzo = tostring(indirizzo or ''):sub(1, 120),
        chiamante = nil,
        numero = 'segnalazione automatica',
    })
end)

-- ---------------------------------------------------------------------------
--  Gestione operativa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nue:interventiAperti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local l = AUREA.GetLavoro(g.lavoro.nome)
    if not l.ente then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, codice, ente, priorita, tipologia, descrizione, coord, indirizzo,
               stato, assegnata_a, aperta_il,
               TIMESTAMPDIFF(MINUTE, aperta_il, NOW()) AS minuti
        FROM chiamate_112
        WHERE stato IN ('attesa','assegnata','in_posto')
        ORDER BY FIELD(priorita,'rosso','giallo','verde','bianco'), aperta_il ASC
    ]]) or {}

    -- Mostra solo gli interventi di competenza del proprio ente
    local out = {}
    for _, r in ipairs(righe) do
        local competente = r.ente == l.ente or r.ente == 'multiplo'
        if competente then
            r.coord = r.coord and json.decode(r.coord) or nil
            r.assegnata_a = r.assegnata_a and json.decode(r.assegnata_a) or {}
            out[#out + 1] = r
        end
    end

    rispondi(out)
end)

AUREA.Callback.Registra('nue:assegna', function(src, rispondi, idIntervento)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio then return rispondi(false, 'Devi essere in servizio.') end

    local c = MySQL.single.await('SELECT * FROM chiamate_112 WHERE id = ? AND stato IN (\'attesa\',\'assegnata\')', { idIntervento })
    if not c then return rispondi(false, 'Intervento non più disponibile.') end

    local assegnati = c.assegnata_a and json.decode(c.assegnata_a) or {}
    if U.Contiene(assegnati, g.citizenid) then return rispondi(false, 'Sei già assegnato a questo intervento.') end

    -- limite di interventi contemporanei
    local aperti = MySQL.scalar.await([[
        SELECT COUNT(*) FROM chiamate_112
        WHERE stato IN ('assegnata','in_posto') AND assegnata_a LIKE ?
    ]], { '%' .. g.citizenid .. '%' }) or 0
    if aperti >= NUE.Regole.interventiPerOperatore then
        return rispondi(false, ('Hai già %d interventi assegnati. Chiudine uno.'):format(aperti))
    end

    assegnati[#assegnati + 1] = g.citizenid
    MySQL.update.await('UPDATE chiamate_112 SET stato = \'assegnata\', assegnata_a = ? WHERE id = ?',
        { json.encode(assegnati), idIntervento })

    -- il chiamante viene informato che il mezzo è partito
    if c.chiamante then
        local chiamante = AUREA.GetPlayerByCitizenId(c.chiamante)
        if chiamante then
            TriggerClientEvent('aurea:ui:notifica', chiamante.source, {
                tipo = 'info', icona = '📞', durata = 9000,
                titolo = ('Intervento %s'):format(c.codice),
                testo = 'La centrale ha assegnato un mezzo. Resta dove sei.',
            })
        end
    end

    -- gli altri operatori dello stesso ente vedono che è stato preso
    exports.aurea_ui:NotificaEnte(AUREA.GetLavoro(g.lavoro.nome).ente, {
        tipo = 'info', icona = '📻', durata = 6000,
        titolo = ('%s assegnato'):format(c.codice),
        testo = ('%s se ne occupa.'):format(g:NomeCompleto()),
    }, true)

    rispondi(true, ('Assegnato all\'intervento %s.'):format(c.codice), c.coord and json.decode(c.coord) or nil)
end)

AUREA.Callback.Registra('nue:inPosto', function(src, rispondi, idIntervento)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local c = MySQL.single.await('SELECT * FROM chiamate_112 WHERE id = ?', { idIntervento })
    if not c then return rispondi(false, 'Intervento non trovato.') end

    -- deve essere davvero sul posto
    local destinazione = c.coord and json.decode(c.coord) or nil
    if destinazione then
        local posizione = GetEntityCoords(GetPlayerPed(src))
        local distanza = #(posizione - vector3(destinazione.x, destinazione.y, destinazione.z))
        if distanza > NUE.Regole.raggioInPosto then
            return rispondi(false, ('Sei a %d metri dal luogo dell\'intervento.'):format(math.floor(distanza)))
        end
    end

    MySQL.update.await('UPDATE chiamate_112 SET stato = \'in_posto\' WHERE id = ?', { idIntervento })
    rispondi(true, 'Arrivo sul posto comunicato alla centrale.')
end)

AUREA.Callback.Registra('nue:chiudi', function(src, rispondi, idIntervento, esito, falsaChiamata)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio then return rispondi(false, 'Devi essere in servizio.') end

    local c = MySQL.single.await('SELECT * FROM chiamate_112 WHERE id = ?', { idIntervento })
    if not c or c.stato == 'chiusa' then return rispondi(false, 'Intervento già chiuso.') end

    MySQL.update.await([[
        UPDATE chiamate_112 SET stato = 'chiusa', chiusa_il = NOW(), esito = ? WHERE id = ?
    ]], { ('%s — %s'):format(g:NomeCompleto(), tostring(esito or 'nessuna nota'):sub(1, 240)), idIntervento })

    -- Procurato allarme: la falsa chiamata è un reato
    if falsaChiamata and c.chiamante then
        exports.ita_codicestrada:EmettiVerbale({
            citizenid = c.chiamante,
            articolo = 'art. 658 c.p.',
            descrizione = ('Procurato allarme presso l\'Autorità — chiamata %s'):format(c.codice),
            importo = NUE.Regole.sanzioneFalsaChiamata,
            punti = 0,
            origine = 'agente',
            agente = g:NomeCompleto(),
            luogo = c.indirizzo,
        })
        local chiamante = AUREA.GetPlayerByCitizenId(c.chiamante)
        if chiamante then
            TriggerClientEvent('aurea:ui:notifica', chiamante.source, {
                tipo = 'errore', icona = '⚖', durata = 12000,
                titolo = 'Procurato allarme',
                testo = 'La tua chiamata al 112 è risultata infondata: è stato elevato un verbale.',
            })
        end
    end

    TriggerClientEvent('nue:interventoChiuso', -1, idIntervento)
    rispondi(true, ('Intervento %s chiuso.'):format(c.codice))
end)

-- ---------------------------------------------------------------------------
--  Chiusura automatica degli interventi senza risposta
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5 * 60000)

        local scadute = MySQL.query.await([[
            SELECT id, codice, chiamante FROM chiamate_112
            WHERE stato = 'attesa' AND aperta_il < DATE_SUB(NOW(), INTERVAL ? MINUTE)
        ]], { NUE.Regole.scadenzaMinuti }) or {}

        for _, c in ipairs(scadute) do
            MySQL.update.await([[
                UPDATE chiamate_112 SET stato = 'annullata', chiusa_il = NOW(),
                       esito = 'Nessun mezzo disponibile entro i tempi previsti' WHERE id = ?
            ]], { c.id })

            if c.chiamante then
                local g = AUREA.GetPlayerByCitizenId(c.chiamante)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '📞', durata = 10000,
                        titolo = ('Intervento %s annullato'):format(c.codice),
                        testo = 'Nessun mezzo si è reso disponibile. Puoi richiamare il 112.',
                    })
                end
            end
            TriggerClientEvent('nue:interventoChiuso', -1, c.id)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local g = AUREA.GetPlayer(source)
    if g then ultimaChiamata[g.citizenid] = nil end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('112', 'utente', 'Chiama il Numero Unico Emergenze', {}, function(src)
    TriggerClientEvent('nue:apriChiamata', src)
end)

AUREA.Comando('interventi', 'utente', 'Apre il quadro degli interventi (personale in servizio)', {}, function(src, _, _, g)
    if not g then return end
    local l = AUREA.GetLavoro(g.lavoro.nome)
    if not l.ente then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale di soccorso e alle forze dell\'ordine.' })
    end
    TriggerClientEvent('nue:apriQuadro', src)
end)
