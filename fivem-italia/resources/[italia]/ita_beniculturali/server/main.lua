--[[
    AUREA · Beni culturali (server)

    Il valore del reperto lo decide il server e non si vede finché non è
    periziato: chi scava non sa che cosa ha in mano, e questo è metà del
    gioco. Se il valore fosse noto al momento dello scavo, nessuno
    denuncerebbe mai niente.

    Il termine dell'art. 90 corre da quando il reperto esce da terra, e
    corre da solo: non serve che qualcuno lo controlli. Scaduto quello,
    la detenzione diventa illecita e basta un controllo qualunque.
]]

local U = AUREA.Util
local ultimoScavo = {}      -- [citizenid] = timestamp

local function funzionario(g, permesso)
    return g and g.lavoro.nome == BC.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'scavo')
end

local function inSede(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - BC.Sede.coord) <= 8.0
end

local function autorizzato(citizenid, sito)
    local r = MySQL.scalar.await([[
        SELECT id FROM beniculturali_autorizzazioni
        WHERE citizenid = ? AND sito = ? AND revocata = 0 AND scadenza > NOW()
    ]], { citizenid, sito })
    return r ~= nil
end

exports('SitoIn', function(coord)
    local s = BC.SitoIn(coord)
    return s and s.id or nil, s and s.vincolato or false
end)

exports('Autorizzato', autorizzato)

-- ---------------------------------------------------------------------------
--  La ricerca col metal detector
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:cerca', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario or not inventario:Ha(BC.Scavo.attrezzo, 1) then
        return rispondi(false, 'Senza metal detector non si cerca niente.')
    end

    local sito = BC.SitoIn(GetEntityCoords(GetPlayerPed(src)))
    if not sito then
        return rispondi(false, 'Qui non c\'è niente sotto: nessun sito censito.')
    end

    if (ultimoScavo[g.citizenid] or 0) > os.time() then
        return rispondi(false, 'Hai appena scavato: aspetta.')
    end

    local prelievi = MySQL.scalar.await('SELECT prelievi FROM siti_scavati WHERE sito = ?',
        { sito.id }) or 0
    if prelievi >= sito.prelieviMassimi then
        return rispondi(false, ('%s è esaurito: è stato saccheggiato fino in fondo.')
            :format(sito.nome))
    end

    if math.random(100) > BC.Scavo.probabilitaSegnale then
        return rispondi(false, 'Nessun segnale utile. Provare più in là.')
    end

    if math.random(100) <= BC.Scavo.probabilitaFerraglia then
        return rispondi(false, 'Segnale forte, ma è ferraglia moderna. Si ricopre e si va oltre.')
    end

    rispondi(true, {
        sito = sito.id, nome = sito.nome, vincolato = sito.vincolato,
        autorizzato = autorizzato(g.citizenid, sito.id),
    })
end)

-- ---------------------------------------------------------------------------
--  Lo scavo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:scava', function(src, rispondi, idSito)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local sito = BC.GetSito(idSito)
    if not sito then return rispondi(false, 'Sito inesistente.') end

    -- Che sia davvero lì, e non un id inviato a caso
    if #(GetEntityCoords(GetPlayerPed(src)) - sito.coord) > sito.raggio then
        AUREA.Log('anticheat', 'allarme', g, ('scavo dichiarato su %s da fuori sito'):format(sito.id))
        return rispondi(false, 'Non sei nel sito.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario or not inventario:Ha(BC.Scavo.attrezzoScavo, 1) then
        return rispondi(false, 'Serve una cazzuola da scavo.')
    end

    local prelievi = MySQL.scalar.await('SELECT prelievi FROM siti_scavati WHERE sito = ?',
        { sito.id }) or 0
    if prelievi >= sito.prelieviMassimi then
        return rispondi(false, 'Non c\'è più niente da tirare fuori qui.')
    end

    ultimoScavo[g.citizenid] = os.time() + BC.Scavo.minutiFraScavi * 60

    local conAutorizzazione = autorizzato(g.citizenid, sito.id)
    local nome = sito.reperti[math.random(#sito.reperti)]
    local valore = math.random(sito.valoreMin, sito.valoreMax)
    local codice = ('%s-%s'):format(sito.id:upper():sub(1, 3), U.Random(5))

    local id = MySQL.insert.await([[
        INSERT INTO beniculturali_reperti (codice, nome, sito, valore, stato, detentore, autorizzato)
        VALUES (?, ?, ?, ?, 'detenuto', ?, ?)
    ]], { codice, nome, sito.id, valore, g.citizenid, conAutorizzazione and 1 or 0 })

    MySQL.query.await([[
        INSERT INTO siti_scavati (sito, prelievi, ultimo) VALUES (?, 1, NOW())
        ON DUPLICATE KEY UPDATE prelievi = prelievi + 1, ultimo = NOW()
    ]], { sito.id })

    exports.aurea_inventory:Aggiungi(g.citizenid, 'reperto_archeologico', 1, {
        codice = codice, nome = nome, sito = sito.id,
    })

    -- Scavare senza autorizzazione in un sito vincolato è già reato di
    -- per sé: art. 518-terdecies. Non serve che il reperto sia prezioso.
    if sito.vincolato and not conAutorizzazione then
        if math.random(100) <= BC.Scavo.probabilitaSegnalazione then
            TriggerEvent('aurea:112:allerta', 'scavo_clandestino',
                { x = sito.coord.x, y = sito.coord.y, z = sito.coord.z },
                ('Segnalata attività di scavo notturno presso %s.'):format(sito.nome),
                'segnalazione anonima')
        end
    end

    AUREA.Log('giustizia', conAutorizzazione and 'info' or 'avviso', g,
        ('reperto %s da %s (%s)'):format(codice, sito.nome,
            conAutorizzazione and 'scavo autorizzato' or 'scavo clandestino'))

    rispondi(true, {
        codice = codice, nome = nome, sito = sito.nome,
        autorizzato = conAutorizzazione,
        minuti = BC.Denuncia.minutiPerDenunciare,
        id = id,
    })
end)

-- ---------------------------------------------------------------------------
--  Denuncia del ritrovamento (art. 90)
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:mieiReperti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, codice, nome, sito, stato, autorizzato,
               TIMESTAMPDIFF(MINUTE, trovato_il, NOW()) AS minuti
        FROM beniculturali_reperti
        WHERE detentore = ? AND stato IN ('detenuto','dichiarato')
        ORDER BY trovato_il ASC
    ]], { g.citizenid }) or {}

    for _, r in ipairs(righe) do
        r.nomeSito = (BC.GetSito(r.sito) or {}).nome or r.sito
        r.scaduto = (r.minuti or 0) > BC.Denuncia.minutiPerDenunciare
        r.minutiResidui = math.max(0, BC.Denuncia.minutiPerDenunciare - (r.minuti or 0))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('bc:denuncia', function(src, rispondi, idReperto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'La denuncia si presenta in Soprintendenza.') end

    local r = MySQL.single.await([[
        SELECT id, codice, nome, valore, autorizzato, sito,
               TIMESTAMPDIFF(MINUTE, trovato_il, NOW()) AS minuti
        FROM beniculturali_reperti
        WHERE id = ? AND detentore = ? AND stato = 'detenuto'
    ]], { tonumber(idReperto), g.citizenid })
    if not r then return rispondi(false, 'Reperto non trovato fra quelli che detieni.') end

    -- L'inventario toglie un pezzo; quale reperto sia lo dice la riga nel
    -- database, che è l'unica cosa che conta davvero.
    if not exports.aurea_inventory:Rimuovi(g.citizenid, 'reperto_archeologico', 1) then
        return rispondi(false, 'Non hai il reperto con te.')
    end

    MySQL.update.await(
        'UPDATE beniculturali_reperti SET stato = \'museo\', detentore = NULL WHERE id = ?', { r.id })

    local tardiva = (r.minuti or 0) > BC.Denuncia.minutiPerDenunciare
    local premio = 0

    if r.autorizzato == 1 then
        -- Chi scava per la Soprintendenza non è un ritrovatore fortuito
        premio = math.floor(r.valore * BC.Denuncia.premioAutorizzato)
    elseif tardiva then
        premio = 0
    elseif BC.Denuncia.premioSoloSeFortuito then
        -- Fortuito è chi non stava cercando. Qui un metal detector in mano
        -- c'era, quindi il premio pieno non spetta: spetta quello ridotto.
        premio = math.floor(r.valore * BC.Denuncia.premioAutorizzato)
    else
        premio = math.floor(r.valore * BC.Denuncia.premio)
    end

    if premio > 0 then
        g:Aggiungi('banca', premio, ('premio di rinvenimento — %s'):format(r.nome))
        TriggerEvent('aurea:fisco:erogazione', 'premio_rinvenimento', premio, g.citizenid)
    end

    -- La denuncia tardiva non è gratis: il reperto era detenuto oltre il
    -- termine, e questo resta agli atti.
    if tardiva then
        exports.ita_giustizia:ApriFascicolo(g.citizenid, BC.Reati.detenzione,
            'Soprintendenza',
            ('Detenzione oltre il termine di denuncia del reperto %s'):format(r.codice))
    end

    exports.aurea_ui:NotificaLavoro(BC.Lavoro, {
        tipo = 'info', icona = '🏺', durata = 14000,
        titolo = 'Consegna di reperto',
        testo = ('%s ha consegnato %s (%s).'):format(g:NomeCompleto(), r.nome, r.codice),
    }, false)

    AUREA.Log('economia', 'info', g, ('consegnato il reperto %s, perizia %s, premio %s')
        :format(r.codice, U.Euro(r.valore), U.Euro(premio)))

    rispondi(true, ('%s consegnato.\nValore di perizia: %s.\nPremio: %s.%s')
        :format(r.nome, U.Euro(r.valore), U.Euro(premio),
                tardiva and '\n\nLa denuncia è tardiva: il premio non spetta e resta un fascicolo aperto.'
                        or ''))
end)

-- ---------------------------------------------------------------------------
--  Autorizzazione allo scavo
-- ---------------------------------------------------------------------------
AUREA.Comando('autorizzascavo', 'utente', 'Autorizza uno scavo archeologico (Soprintendenza)', {
    { name = 'id', help = 'ID della persona' },
    { name = 'sito', help = 'id del sito' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'scavo') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🏺', titolo = 'Soprintendenza',
            testo = 'Riservato ai funzionari in servizio.' })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local sito = BC.GetSito(args[2])
    if not bersaglio or not sito then
        local ids = {}
        for _, s in ipairs(BC.Siti) do ids[#ids + 1] = s.id end
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🏺', titolo = 'Uso',
            testo = ('/autorizzascavo <id> <%s>'):format(table.concat(ids, '|')) })
    end

    MySQL.insert.await([[
        INSERT INTO beniculturali_autorizzazioni (citizenid, sito, rilasciata_da, scadenza)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { bersaglio.citizenid, sito.id, g.citizenid, BC.Autorizzazione.minutiValidita })

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'successo', icona = '🏺', durata = 16000,
        titolo = 'Autorizzazione allo scavo',
        testo = ('Puoi scavare a %s per %d minuti. Tutto quello che trovi va consegnato.')
            :format(sito.nome, BC.Autorizzazione.minutiValidita) })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🏺', titolo = 'Autorizzazione rilasciata',
        testo = ('%s può scavare a %s.'):format(bersaglio:NomeCompleto(), sito.nome) })

    AUREA.Log('economia', 'info', g, ('autorizzato %s allo scavo su %s')
        :format(bersaglio.citizenid, sito.id))
end)

-- ---------------------------------------------------------------------------
--  Controllo e sequestro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:controlla', function(src, rispondi, sorgente)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio or not AUREA.EForzaOrdine(g.lavoro.nome) then
        return rispondi(false, 'Il controllo lo fanno le forze dell\'ordine in servizio.')
    end

    local bersaglio = AUREA.GetPlayer(tonumber(sorgente))
    if not bersaglio then return rispondi(false, 'La persona non è collegata.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(bersaglio.source))) > 4.0 then
        return rispondi(false, 'È troppo lontano.')
    end

    local righe = MySQL.query.await([[
        SELECT id, codice, nome, valore, autorizzato, sito,
               TIMESTAMPDIFF(MINUTE, trovato_il, NOW()) AS minuti
        FROM beniculturali_reperti
        WHERE detentore = ? AND stato = 'detenuto'
    ]], { bersaglio.citizenid }) or {}

    if #righe == 0 then
        return rispondi(true, { nome = bersaglio:NomeCompleto(), reperti = 0 })
    end

    local sequestrati, valore, illeciti = 0, 0, 0
    for _, r in ipairs(righe) do
        -- Un reperto autorizzato e ancora nei termini non si sequestra:
        -- sta andando in Soprintendenza, ed è quello che deve fare.
        local fuoriTermine = (r.minuti or 0) > BC.Denuncia.minutiPerDenunciare
        if fuoriTermine or r.autorizzato == 0 then
            MySQL.update.await(
                'UPDATE beniculturali_reperti SET stato = \'sequestrato\', detentore = NULL WHERE id = ?',
                { r.id })
            exports.aurea_inventory:Rimuovi(bersaglio.citizenid, 'reperto_archeologico', 1)
            sequestrati = sequestrati + 1
            valore = valore + r.valore
            if fuoriTermine or r.autorizzato == 0 then illeciti = illeciti + 1 end
        end
    end

    if illeciti > 0 then
        exports.ita_giustizia:ApriFascicolo(bersaglio.citizenid, BC.Reati.detenzione,
            g:NomeCompleto(),
            ('Detenzione illecita di %d reperti archeologici, perizia complessiva %s')
                :format(illeciti, U.Euro(valore)))
        exports.ita_giustizia:ApriFascicolo(bersaglio.citizenid, BC.Reati.scavo,
            g:NomeCompleto(), 'Attività illecite di ricerca e scavo archeologico')
    end

    exports.aurea_ui:NotificaLavoro(BC.Lavoro, {
        tipo = 'avviso', icona = '🏺', durata = 16000,
        titolo = 'Sequestro di reperti',
        testo = ('%d reperti sequestrati a %s, perizia %s.')
            :format(sequestrati, bersaglio:NomeCompleto(), U.Euro(valore)),
    }, false)

    AUREA.Log('giustizia', 'avviso', g, ('sequestrati %d reperti a %s (%s)')
        :format(sequestrati, bersaglio.citizenid, U.Euro(valore)))

    rispondi(true, {
        nome = bersaglio:NomeCompleto(), reperti = #righe,
        sequestrati = sequestrati, valore = valore, illeciti = illeciti,
    })
end)

-- ---------------------------------------------------------------------------
--  Il mercato clandestino
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:vendi', function(src, rispondi, idReperto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - BC.Mercato.coord) > 6.0 then
        return rispondi(false, 'Non sei dove si tratta.')
    end

    if BC.Mercato.richiedeOrganizzazione then
        local ok, tag = pcall(function()
            return exports.ita_famiglie:OrganizzazioneDi(g.citizenid)
        end)
        if not ok or not tag or tag == 'nessuna' then
            return rispondi(false, 'Non compra da chi non conosce. Serve una presentazione.')
        end
    end

    local r = MySQL.single.await([[
        SELECT id, codice, nome, valore FROM beniculturali_reperti
        WHERE id = ? AND detentore = ? AND stato = 'detenuto'
    ]], { tonumber(idReperto), g.citizenid })
    if not r then return rispondi(false, 'Non risulta fra quelli che detieni.') end

    if not exports.aurea_inventory:Rimuovi(g.citizenid, 'reperto_archeologico', 1) then
        return rispondi(false, 'Non ce l\'hai con te.')
    end

    local prezzo = math.floor(r.valore * BC.Mercato.quota)
    g:Aggiungi('contanti', prezzo, 'cessione di reperto')

    MySQL.update.await(
        'UPDATE beniculturali_reperti SET stato = \'esportato\', detentore = NULL WHERE id = ?', { r.id })

    -- Ogni tanto qualcosa rimane indietro
    if math.random(100) <= BC.Mercato.probabilitaTraccia then
        exports.ita_giustizia:ApriFascicolo(g.citizenid, BC.Reati.ricettazione,
            'accertamenti sul mercato antiquario',
            ('Cessione del reperto %s — %s'):format(r.codice, r.nome))
        exports.aurea_ui:NotificaEnte('carabinieri', {
            tipo = 'avviso', icona = '🏺', durata = 16000,
            titolo = 'Traffico di beni culturali',
            testo = ('Segnalata la cessione del reperto %s sul mercato antiquario.'):format(r.codice),
        }, true)
    end

    AUREA.Log('giustizia', 'avviso', g, ('ceduto il reperto %s per %s'):format(r.codice, U.Euro(prezzo)))

    rispondi(true, ('%s. Nessuna domanda, nessuna ricevuta.\nAllo Stato ne avresti presi %s.')
        :format(U.Euro(prezzo), U.Euro(math.floor(r.valore * BC.Denuncia.premioAutorizzato))))
end)

-- ---------------------------------------------------------------------------
--  L'inventario dei siti, per la Soprintendenza
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bc:siti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'perizia') then return rispondi(nil) end

    local out = {}
    for _, s in ipairs(BC.Siti) do
        local prelievi = MySQL.scalar.await('SELECT prelievi FROM siti_scavati WHERE sito = ?',
            { s.id }) or 0
        local dispersi = MySQL.scalar.await([[
            SELECT COUNT(*) FROM beniculturali_reperti
            WHERE sito = ? AND stato IN ('detenuto','esportato')
        ]], { s.id }) or 0
        local museo = MySQL.scalar.await(
            'SELECT COUNT(*) FROM beniculturali_reperti WHERE sito = ? AND stato = ?',
            { s.id, 'museo' }) or 0

        out[#out + 1] = {
            id = s.id, nome = s.nome, prelievi = prelievi,
            massimo = s.prelieviMassimi, dispersi = dispersi, museo = museo,
        }
    end
    rispondi(out)
end)
