--[[
    AUREA · Sinistri stradali (server)

    La firma è tutto. Un sinistro con due firme si chiude da solo in
    perizia; uno con una firma sola resta contestato, e contestato vuol
    dire che il perito deve andare a guardare e che nel frattempo non
    liquida nessuno.

    Il danno lo misura il server leggendo la carrozzeria del veicolo al
    momento della perizia. Non lo dichiara il danneggiato — e quando lo
    dichiara, serve solo a vedere di quanto ha mentito.
]]

local U = AUREA.Util
local ultimoSinistro = {}       -- [citizenid] = timestamp

local function perito(g, permesso)
    return g and g.lavoro.nome == SIN.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'perizia')
end

local function inAgenzia(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - SIN.Agenzia.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Apertura del sinistro
--
--  Lo apre il client di chi ha sbattuto, ma non decide niente: dice
--  solo che due targhe si sono incontrate. La velocità e la distanza
--  le ricontrolla il server.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sin:apri', function(src, rispondi, sorgenteAltro, targaMia, targaAltra)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if (ultimoSinistro[g.citizenid] or 0) > os.time() then
        return rispondi(false, 'Hai già aperto un sinistro da poco.')
    end

    targaMia = tostring(targaMia or ''):upper():gsub('%s+', '')
    if targaMia == '' then return rispondi(false, 'La tua targa non è leggibile.') end

    local altro = AUREA.GetPlayer(tonumber(sorgenteAltro))
    if altro then
        if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(altro.source)))
           > SIN.Rilevamento.distanza then
            return rispondi(false, 'L\'altro conducente è troppo lontano per una constatazione.')
        end
        if altro.citizenid == g.citizenid then
            return rispondi(false, 'Non puoi fare una constatazione con te stesso.')
        end
    end

    targaAltra = altro and tostring(targaAltra or ''):upper():gsub('%s+', '') or nil
    if targaAltra == '' then targaAltra = nil end

    ultimoSinistro[g.citizenid] = os.time() + SIN.Rilevamento.raffreddamentoSecondi

    local id = MySQL.insert.await([[
        INSERT INTO sinistri (targa_a, targa_b, citizenid_a, citizenid_b, luogo, firma_a)
        VALUES (?, ?, ?, ?, ?, 1)
    ]], { targaMia, targaAltra, g.citizenid, altro and altro.citizenid or nil,
          ('%.0f, %.0f'):format(GetEntityCoords(GetPlayerPed(src)).x,
                                GetEntityCoords(GetPlayerPed(src)).y) })

    if altro then
        TriggerClientEvent('aurea:ui:notifica', altro.source, {
            tipo = 'avviso', icona = '📋', durata = 22000,
            titolo = 'Constatazione amichevole',
            testo = ('%s ha compilato il modulo per il sinistro con %s.\nApri /sinistri per firmare: hai %d minuti, e senza la tua firma serve il perito.')
                :format(g:NomeCompleto(), targaMia, SIN.Rilevamento.minutiPerFirmare),
        })
    end

    AUREA.Log('veicoli', 'info', g, ('sinistro %d aperto fra %s e %s')
        :format(id, targaMia, targaAltra or 'nessuno'))

    rispondi(true, altro
        and ('Constatazione aperta, n. %d. Hai firmato tu: ora deve firmare %s.')
            :format(id, altro:NomeCompleto())
        or ('Sinistro n. %d registrato senza controparte. Vai in agenzia per la perizia.'):format(id))
end)

-- ---------------------------------------------------------------------------
--  I propri sinistri
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sin:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT s.*, TIMESTAMPDIFF(MINUTE, s.avvenuto_il, NOW()) AS minuti,
               CONCAT(pa.nome, ' ', pa.cognome) AS nome_a,
               CONCAT(pb.nome, ' ', pb.cognome) AS nome_b
        FROM sinistri s
        LEFT JOIN personaggi pa ON pa.citizenid = s.citizenid_a
        LEFT JOIN personaggi pb ON pb.citizenid = s.citizenid_b
        WHERE (s.citizenid_a = ? OR s.citizenid_b = ?)
          AND s.stato IN ('aperto','firmato','in_perizia','contestato')
        ORDER BY s.avvenuto_il DESC LIMIT 10
    ]], { g.citizenid, g.citizenid }) or {}

    for _, s in ipairs(righe) do
        s.sonoA = s.citizenid_a == g.citizenid
        s.miaFirma = s.sonoA and s.firma_a == 1 or (not s.sonoA and s.firma_b == 1)
        s.scaduto = (s.minuti or 0) > SIN.Rilevamento.minutiPerFirmare
    end
    rispondi(righe, SIN.Rilevamento.minutiPerFirmare)
end)

-- ---------------------------------------------------------------------------
--  Firmare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sin:firma', function(src, rispondi, id, responsabile)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(MINUTE, avvenuto_il, NOW()) AS minuti
        FROM sinistri WHERE id = ? AND stato IN ('aperto','contestato')
    ]], { tonumber(id) })
    if not s then return rispondi(false, 'Constatazione non più aperta.') end

    local sonoA = s.citizenid_a == g.citizenid
    local sonoB = s.citizenid_b == g.citizenid
    if not sonoA and not sonoB then return rispondi(false, 'Non sei parte di questo sinistro.') end

    if (s.minuti or 0) > SIN.Rilevamento.minutiPerFirmare then
        MySQL.update.await('UPDATE sinistri SET stato = ? WHERE id = ?', { 'contestato', s.id })
        return rispondi(false, ('Sono passati più di %d minuti: la constatazione amichevole non si può più firmare. Adesso serve il perito.')
            :format(SIN.Rilevamento.minutiPerFirmare))
    end

    local valida = false
    for _, r in ipairs(SIN.Responsabilita) do
        if r.id == responsabile then valida = true end
    end
    if not valida then return rispondi(false, 'Indicazione di responsabilità non valida.') end

    -- Se l'altro ha già firmato indicando un responsabile diverso, non
    -- è più amichevole: è una lite, e le liti le risolve il perito.
    local altraFirma = sonoA and s.firma_b == 1 or (sonoB and s.firma_a == 1)
    if altraFirma and s.responsabile ~= 'da_accertare' and s.responsabile ~= responsabile then
        MySQL.update.await('UPDATE sinistri SET stato = ? WHERE id = ?', { 'contestato', s.id })

        for _, cid in ipairs({ s.citizenid_a, s.citizenid_b }) do
            if cid then
                TriggerEvent('aurea:telefono:messaggioSistema', cid, 'Sinistri',
                    ('Constatazione n. %d: le due versioni non coincidono. Il sinistro è contestato e serve una perizia.')
                        :format(s.id))
            end
        end
        return rispondi(false, 'L\'altro conducente ha dichiarato il contrario: il sinistro è contestato.')
    end

    local colonna = sonoA and 'firma_a' or 'firma_b'
    MySQL.update.await(
        ('UPDATE sinistri SET %s = 1, responsabile = ? WHERE id = ?'):format(colonna),
        { responsabile, s.id })

    -- Con due firme la constatazione è perfetta
    local aggiornato = MySQL.single.await('SELECT firma_a, firma_b, citizenid_b FROM sinistri WHERE id = ?',
        { s.id })

    local completa = aggiornato.firma_a == 1
        and (aggiornato.citizenid_b == nil or aggiornato.firma_b == 1)

    if completa then
        MySQL.update.await('UPDATE sinistri SET stato = ? WHERE id = ?', { 'firmato', s.id })
        for _, cid in ipairs({ s.citizenid_a, s.citizenid_b }) do
            if cid then
                TriggerEvent('aurea:telefono:messaggioSistema', cid, 'Sinistri',
                    ('Constatazione n. %d firmata da entrambi. Portate i mezzi in agenzia per la perizia.')
                        :format(s.id))
            end
        end
        return rispondi(true, 'Constatazione firmata da entrambi. Adesso tocca al perito.')
    end

    rispondi(true, 'Hai firmato. Manca la firma dell\'altro conducente.')
end)

-- ---------------------------------------------------------------------------
--  La perizia
--
--  Il danno si legge dal veicolo, non da quello che dice il proprietario.
--  Se quello che dice il proprietario è molto più alto, quella
--  differenza è il reato.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sin:coda', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not perito(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT s.id, s.targa_a, s.targa_b, s.stato, s.responsabile, s.luogo,
               CONCAT(pa.nome, ' ', pa.cognome) AS nome_a,
               CONCAT(pb.nome, ' ', pb.cognome) AS nome_b,
               TIMESTAMPDIFF(MINUTE, s.avvenuto_il, NOW()) AS minuti
        FROM sinistri s
        LEFT JOIN personaggi pa ON pa.citizenid = s.citizenid_a
        LEFT JOIN personaggi pb ON pb.citizenid = s.citizenid_b
        WHERE s.stato IN ('firmato','contestato')
        ORDER BY s.avvenuto_il ASC LIMIT 20
    ]]) or {}
    rispondi(righe)
end)

--- Il danno reale di una targa, letto dal veicolo se il proprietario è
--- collegato, altrimenti dalla carrozzeria salvata.
local function dannoReale(targa)
    local v = MySQL.single.await('SELECT carrozzeria, modello FROM veicoli WHERE targa = ?', { targa })
    if not v then return 0, 0 end

    local danno = math.max(0, 1000 - (tonumber(v.carrozzeria) or 1000))
    local stima = math.floor(danno * SIN.Perizia.perPuntoDanno)

    local valore = 0
    pcall(function() valore = exports.ita_veicoli:ValoreVeicolo(targa) or 0 end)

    return stima, valore
end

AUREA.Callback.Registra('sin:perizia', function(src, rispondi, id, dichiaratoA, dichiaratoB)
    local g = AUREA.GetPlayer(src)
    if not perito(g) then return rispondi(false, 'La perizia la fa un perito in servizio.') end
    if not inAgenzia(src) then return rispondi(false, 'La perizia si chiude in agenzia.') end

    local s = MySQL.single.await(
        'SELECT * FROM sinistri WHERE id = ? AND stato IN (?, ?)',
        { tonumber(id), 'firmato', 'contestato' })
    if not s then return rispondi(false, 'Sinistro non periziabile.') end

    local stimaA, valoreA = dannoReale(s.targa_a)

    local stimaB, valoreB = 0, 0
    if s.targa_b then stimaB, valoreB = dannoReale(s.targa_b) end

    -- Antieconomico: oltre una certa quota del valore non si ripara
    local totaleA = (valoreA > 0 and stimaA > valoreA * SIN.Perizia.sogliaAntieconomico)
    local totaleB = (valoreB > 0 and stimaB > valoreB * SIN.Perizia.sogliaAntieconomico)

    -- La frode: il danneggiato ha dichiarato molto più del misurato
    local frode, chiHaGonfiato = false, nil
    local function controlla(dichiarato, stima, citizenid)
        dichiarato = math.floor(tonumber(dichiarato) or 0)
        if dichiarato <= 0 or not citizenid then return end
        if stima <= 0 then
            if dichiarato > 0 then frode, chiHaGonfiato = true, citizenid end
            return
        end
        if dichiarato > stima * (1 + SIN.Perizia.scartoAmmesso) then
            frode, chiHaGonfiato = true, citizenid
        end
    end
    controlla(dichiaratoA, stimaA, s.citizenid_a)
    controlla(dichiaratoB, stimaB, s.citizenid_b)

    MySQL.update.await([[
        UPDATE sinistri SET danni_a = ?, danni_b = ?, perito = ?, periziato_il = NOW(),
                            stato = 'in_perizia', frode = ?
        WHERE id = ?
    ]], { stimaA, stimaB, g.citizenid, frode and 1 or 0, s.id })

    if frode and chiHaGonfiato then
        exports.ita_giustizia:ApriFascicolo(chiHaGonfiato, SIN.Perizia.reatoFrode,
            g:NomeCompleto(),
            ('Danni dichiarati sensibilmente superiori a quelli accertati sul sinistro n. %d'):format(s.id))

        exports.aurea_ui:NotificaEnte('guardia_finanza', {
            tipo = 'avviso', icona = '📋', durata = 16000,
            titolo = 'Sospetta frode assicurativa',
            testo = ('Sinistro n. %d: danni dichiarati fuori scala rispetto alla perizia.'):format(s.id),
        }, true)
    end

    g:Aggiungi('banca', SIN.Perizia.compensoPerito, ('perizia sinistro %d'):format(s.id))
    pcall(function()
        exports.aurea_azienda:VersaInCassa(SIN.Lavoro,
            math.floor(SIN.Perizia.compensoPerito * 0.3), 'perizie')
    end)

    AUREA.Log('veicoli', frode and 'avviso' or 'info', g,
        ('perizia sul sinistro %d: %s e %s%s'):format(s.id, U.Euro(stimaA), U.Euro(stimaB),
            frode and ' — dichiarazione fuori scala' or ''))

    rispondi(true, {
        id = s.id,
        stimaA = stimaA, stimaB = stimaB,
        totaleA = totaleA, totaleB = totaleB,
        frode = frode,
        responsabile = s.responsabile,
    })
end)

-- ---------------------------------------------------------------------------
--  Liquidazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sin:liquida', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not perito(g, 'liquidazione') then
        return rispondi(false, 'Solo un perito capo può liquidare.')
    end
    if not inAgenzia(src) then return rispondi(false, 'La liquidazione si chiude in agenzia.') end

    local s = MySQL.single.await('SELECT * FROM sinistri WHERE id = ? AND stato = ?',
        { tonumber(id), 'in_perizia' })
    if not s then return rispondi(false, 'Sinistro non liquidabile.') end
    if s.responsabile == 'da_accertare' then
        return rispondi(false, 'La responsabilità non è stata accertata: non si liquida niente.')
    end

    --- Chi paga per una targa: la compagnia o il conducente.
    local function copertura(targa)
        local tipo = 'nessuna'
        pcall(function() tipo = exports.ita_veicoli:CoperturaDi(targa) or 'nessuna' end)
        return tipo
    end

    local righe = {}

    --- Liquida il danno di `danneggiato` a carico di `colpevole`.
    local function paga(targaColpevole, cidColpevole, cidDanneggiato, danno, quota)
        if not cidDanneggiato or danno <= 0 then return end

        local dovuto = math.max(0,
            math.floor(danno * SIN.Liquidazione.quotaRiconosciuta * quota) - SIN.Liquidazione.franchigia)
        if dovuto <= 0 then
            righe[#righe + 1] = 'Danno sotto la franchigia: nessuna liquidazione.'
            return
        end

        local tipo = copertura(targaColpevole)
        if tipo == 'nessuna' then
            -- Paga lui, e paga tutto: la quota riconosciuta e la
            -- franchigia sono cose della compagnia, non sue.
            local intero = math.floor(danno * SIN.Liquidazione.quotaNonAssicurato * quota)
            local preso = AUREA.Denaro.SottraiOffline(cidColpevole, 'banca', intero,
                ('risarcimento sinistro %d'):format(s.id), true)

            AUREA.Denaro.AggiungiOffline(cidDanneggiato, 'banca', intero,
                ('risarcimento sinistro %d'):format(s.id))

            righe[#righe + 1] = ('%s: nessuna RCA, paga di tasca sua %s%s')
                :format(targaColpevole, U.Euro(intero), preso and '' or ' (conto in rosso)')
        else
            AUREA.Denaro.AggiungiOffline(cidDanneggiato, 'banca', dovuto,
                ('liquidazione sinistro %d'):format(s.id))
            righe[#righe + 1] = ('%s: liquidati %s al netto di franchigia')
                :format(targaColpevole, U.Euro(dovuto))
        end

        local passi = s.responsabile == 'concorso'
            and SIN.Liquidazione.passiConcorso or SIN.Liquidazione.passiClasseMerito
        local nuova
        pcall(function()
            nuova = exports.ita_veicoli:PeggioraClasseMerito(targaColpevole, passi)
        end)
        if nuova then
            righe[#righe + 1] = ('%s: classe di merito ora %d'):format(targaColpevole, nuova)
        end
    end

    if s.responsabile == 'a' then
        paga(s.targa_a, s.citizenid_a, s.citizenid_b, s.danni_b, 1.0)
    elseif s.responsabile == 'b' then
        paga(s.targa_b, s.citizenid_b, s.citizenid_a, s.danni_a, 1.0)
    else
        paga(s.targa_a, s.citizenid_a, s.citizenid_b, s.danni_b, 0.5)
        paga(s.targa_b, s.citizenid_b, s.citizenid_a, s.danni_a, 0.5)
    end

    local liquidato = s.danni_a + s.danni_b
    MySQL.update.await(
        'UPDATE sinistri SET stato = ?, liquidato = ? WHERE id = ?',
        { 'liquidato', liquidato, s.id })

    for _, cid in ipairs({ s.citizenid_a, s.citizenid_b }) do
        if cid then
            TriggerEvent('aurea:telefono:messaggioSistema', cid, 'Sinistri',
                ('Sinistro n. %d liquidato.\n%s'):format(s.id, table.concat(righe, '\n')))
        end
    end

    AUREA.Log('veicoli', 'info', g, ('liquidato il sinistro %d'):format(s.id))
    rispondi(true, table.concat(righe, '\n'))
end)

-- ---------------------------------------------------------------------------
--  I sinistri vecchi si archiviano
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(300000)
        MySQL.update.await([[
            UPDATE sinistri SET stato = 'archiviato'
            WHERE stato IN ('aperto','contestato')
              AND TIMESTAMPDIFF(MINUTE, avvenuto_il, NOW()) > ?
        ]], { SIN.Rilevamento.minutiPerFirmare * 12 })
    end
end)
