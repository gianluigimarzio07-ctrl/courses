--[[
    AUREA · Pesca professionale (server)

    Le quote sono un bene comune: stanno qui, una sola copia, e ogni
    calata le consuma per tutti. È la cosa che rende questo modulo
    diverso da una miniera — quello che peschi tu, non lo pesca un altro.

    Il pescato invece è privato finché non lo dichiari. Chi lo porta al
    mercato ittico paga la commissione e consuma quota; chi lo vende al
    ricettatore prende meno e non consuma niente, perché per il registro
    quel pesce non è mai uscito dall'acqua.
]]

local U = AUREA.Util

local quote = {}        -- [specie] = consumata nel periodo
local finePeriodo = 0
local calate = {}       -- [citizenid] = numero di calate su questa rete

-- ---------------------------------------------------------------------------
--  Periodo e quote
-- ---------------------------------------------------------------------------
local function caricaQuote()
    quote = {}
    for id in pairs(PES.Specie) do quote[id] = 0 end

    for _, r in ipairs(MySQL.query.await('SELECT * FROM pesca_quote') or {}) do
        quote[r.specie] = r.consumata or 0
    end
    finePeriodo = os.time() + PES.Periodo.minuti * 60
end

local function salvaQuota(specie)
    MySQL.query([[
        INSERT INTO pesca_quote (specie, consumata) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE consumata = VALUES(consumata)
    ]], { specie, math.floor(quote[specie] or 0) })
end

CreateThread(function() Wait(3000) caricaQuote() end)

CreateThread(function()
    while true do
        Wait(60000)
        if finePeriodo > 0 and os.time() >= finePeriodo then
            for id in pairs(quote) do
                quote[id] = 0
                salvaQuota(id)
            end
            finePeriodo = os.time() + PES.Periodo.minuti * 60

            exports.aurea_ui:NotificaLavoro(PES.Lavoro, {
                tipo = 'info', icona = '🐟', durata = 14000,
                titolo = 'Nuovo periodo di pesca',
                testo = 'Le quote sono state ricaricate e i prezzi sono tornati alti.',
            }, false)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Chi pesca
-- ---------------------------------------------------------------------------
local function pescatore(g, permesso)
    if not g or g.lavoro.nome ~= PES.Lavoro then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

local function haLicenza(citizenid)
    return MySQL.scalar.await(
        'SELECT id FROM pesca_licenze WHERE citizenid = ? AND revocata = 0 AND scade_il > NOW()',
        { citizenid }) ~= nil
end

exports('HaLicenzaPesca', haLicenza)

local function zonaSotto(coord)
    for _, z in ipairs(PES.Zone) do
        if #(vector2(coord.x, coord.y) - vector2(z.coord.x, z.coord.y)) <= z.raggio then return z end
    end
end

-- ---------------------------------------------------------------------------
--  Licenza
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pes:licenza', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - PES.Porto.coord) > 8.0 then
        return rispondi(false, 'La licenza si rilascia in capitaneria, al mercato.')
    end

    if PES.Licenza.richiedePatenteNautica then
        local ok, ha = pcall(function()
            return exports.ita_nautica:PatenteNautica(g.citizenid)
        end)
        if ok and not ha then
            return rispondi(false, 'Serve la patente nautica: un peschereccio è pur sempre un\'unità da condurre.')
        end
    end

    if not g:Sottrai('banca', PES.Licenza.costo, 'licenza di pesca professionale') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(PES.Licenza.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'concessioni', PES.Licenza.costo, g.citizenid)

    MySQL.query.await([[
        INSERT INTO pesca_licenze (citizenid, scade_il)
        VALUES (?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE revocata = 0, rilasciata_il = NOW(), scade_il = VALUES(scade_il)
    ]], { g.citizenid, PES.Licenza.validitaMinuti })

    rispondi(true, ('Licenza rilasciata. Vale %d minuti.'):format(PES.Licenza.validitaMinuti))
end)

-- ---------------------------------------------------------------------------
--  La calata
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pes:cala', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not pescatore(g, 'cala') then return rispondi(false, 'Non sei imbarcato su un peschereccio.') end
    if not haLicenza(g.citizenid) then
        return rispondi(false, 'Senza licenza non si cala. E se ti fermano, è un\'altra cosa ancora.')
    end

    local ped = GetPlayerPed(src)
    local coord = GetEntityCoords(ped)
    local z = zonaSotto(coord)
    if not z then return rispondi(false, 'Qui non c\'è niente da pescare.') end

    local v = GetVehiclePedIsIn(ped, false)
    if v == 0 then return rispondi(false, 'La rete si cala dalla barca.') end

    if not exports.aurea_inventory:Ha(g.citizenid, PES.Calata.rete, 1) then
        return rispondi(false, 'Serve una rete.')
    end

    calate[g.citizenid] = (calate[g.citizenid] or 0) + 1
    if calate[g.citizenid] > PES.Calata.calatePerRete then
        return rispondi(false, 'La rete è sfilacciata: va rammendata prima di ricalarla.')
    end

    -- Cosa viene su: le specie della zona, pesate sulla quota residua.
    -- Dove si è già pescato molto, si pesca meno: è il mare, non un forziere.
    local pescato = {}
    for _, specieId in ipairs(z.specie) do
        local s = PES.GetSpecie(specieId)
        local residua = math.max(0, 1 - (quote[specieId] or 0) / s.quota)
        if math.random() < 0.45 + residua * 0.4 then
            local quanti = math.max(1, math.floor(
                math.random(s.resa[1], s.resa[2]) * z.moltiplicatore * (0.4 + residua * 0.6) + 0.5))
            if exports.aurea_inventory:Aggiungi(g.citizenid, s.item, quanti) then
                pescato[#pescato + 1] = ('%d × %s'):format(quanti, s.nome)
            end
        end
    end

    if #pescato == 0 then
        return rispondi(true, 'Rete vuota. Capita, e capita più spesso dove hanno già pescato tutti.')
    end

    rispondi(true, ('%s\n%s'):format(z.nome, table.concat(pescato, ', ')))
end)

AUREA.Callback.Registra('pes:rammenda', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    calate[g.citizenid] = 0
    rispondi(true, 'Rete rammendata. Regge altre calate.')
end)

-- ---------------------------------------------------------------------------
--  Mercato ittico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pes:listino', function(src, rispondi)
    local fuori = {}
    for id, s in pairs(PES.Specie) do
        local consumata = quote[id] or 0
        fuori[#fuori + 1] = {
            id = id, nome = s.nome, item = s.item,
            prezzo = PES.Prezzo(id, consumata),
            base = s.prezzoBase,
            quota = s.quota, consumata = math.floor(consumata),
        }
    end
    table.sort(fuori, function(a, b) return a.prezzo > b.prezzo end)
    rispondi(fuori, math.max(0, math.ceil((finePeriodo - os.time()) / 60)))
end)

AUREA.Callback.Registra('pes:vendi', function(src, rispondi, specieId, inNero)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = PES.GetSpecie(specieId)
    if not s then return rispondi(false, 'Specie sconosciuta.') end

    local dove = inNero and PES.Mercato.ricettatore or PES.Porto.coord
    if #(GetEntityCoords(GetPlayerPed(src)) - dove) > 8.0 then
        return rispondi(false, inNero and 'Non sei al posto giusto.' or 'Devi essere al mercato ittico.')
    end

    local quanti = exports.aurea_inventory:Quantita(g.citizenid, s.item) or 0
    if quanti <= 0 then return rispondi(false, ('Non hai %s.'):format(s.nome)) end

    local prezzo = PES.Prezzo(specieId, quote[specieId] or 0)

    if inNero then
        -- Il nero non consuma quota: per il registro quel pesce non è mai
        -- uscito dall'acqua. È il motivo per cui conviene a chi ha finito.
        local incasso = math.floor(prezzo * quanti * PES.Mercato.quotaNero)
        exports.aurea_inventory:Rimuovi(g.citizenid, s.item, quanti)
        g:Aggiungi('contanti', incasso, 'vendita fuori mercato')

        MySQL.insert('INSERT INTO pesca_sbarchi (citizenid, specie, quantita, incasso, dichiarato) VALUES (?, ?, ?, ?, 0)',
            { g.citizenid, specieId, quanti, incasso })

        TriggerEvent('aurea:famiglie:calore', g.citizenid, 2, 'pesca non dichiarata')
        AUREA.Log('economia', 'avviso', g, ('ha venduto %d %s fuori mercato'):format(quanti, s.nome))

        return rispondi(true, ('%d × %s per %s in contanti.\nNon risulta da nessuna parte — e infatti non consuma quota.')
            :format(quanti, s.nome, U.Euro(incasso)))
    end

    if not haLicenza(g.citizenid) then
        return rispondi(false, 'Il mercato compra solo da chi ha la licenza.')
    end

    local lordo = prezzo * quanti
    local commissione = math.floor(lordo * PES.Mercato.commissione)
    local netto = lordo - commissione

    -- Il fuori quota si può dichiarare, ma costa
    local residua = math.max(0, s.quota - (quote[specieId] or 0))
    local extra = math.max(0, quanti - residua)

    exports.aurea_inventory:Rimuovi(g.citizenid, s.item, quanti)
    g:Aggiungi('banca', netto, ('vendita al mercato ittico — %s'):format(s.nome))
    TriggerEvent('aurea:fisco:incasso', 'iva_alimentari', commissione, g.citizenid)

    quote[specieId] = (quote[specieId] or 0) + quanti
    salvaQuota(specieId)

    MySQL.insert('INSERT INTO pesca_sbarchi (citizenid, specie, quantita, incasso, dichiarato) VALUES (?, ?, ?, ?, 1)',
        { g.citizenid, specieId, quanti, netto })

    local avviso = ''
    if extra > 0 then
        local sanzione = PES.Controlli.sanzioneFuoriQuota
            + (s.sanzioneExtraQuota or 0) * extra
        exports.ita_fisco:IscriviTributo(g.citizenid, 'sanzione',
            ('cattura oltre quota — %s'):format(s.nome), sanzione, 7)
        avviso = ('\n\n%d capi oltre la quota: sanzione %s.'):format(extra, U.Euro(sanzione))

        for _, l in ipairs(PES.Controlli.lavoriAmmessi) do
            exports.aurea_ui:NotificaLavoro(l, {
                tipo = 'avviso', icona = '🐟', durata = 16000,
                titolo = 'Sbarco oltre quota',
                testo = ('%s ha dichiarato %d %s con quota esaurita.')
                    :format(g:NomeCompleto(), quanti, s.nome),
            }, true)
        end
    end

    rispondi(true, ('%d × %s a %s l\'uno.\nLordo %s, commissione %s, netto %s.%s')
        :format(quanti, s.nome, U.Euro(prezzo), U.Euro(lordo), U.Euro(commissione), U.Euro(netto), avviso))
end)

-- ---------------------------------------------------------------------------
--  Controllo in mare
-- ---------------------------------------------------------------------------
AUREA.Comando('controllopesca', 'utente', 'Controlla un peschereccio', {
    { name = 'id', help = 'ID del conducente' },
}, function(src, args, _, g)
    local ammesso = false
    for _, l in ipairs(PES.Controlli.lavoriAmmessi) do
        if g and g.lavoro.nome == l and g.lavoro.servizio then ammesso = true end
    end
    if not ammesso then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🐟', titolo = 'Non autorizzato',
            testo = 'Il controllo lo fa la Capitaneria in servizio.' })
    end

    local b = AUREA.GetPlayer(tonumber(args[1]))
    if not b then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🐟', titolo = 'Nessuno', testo = 'ID non trovato.' })
    end

    local licenza = haLicenza(b.citizenid)
    local aBordo, totale = {}, 0
    for id, s in pairs(PES.Specie) do
        local q = exports.aurea_inventory:Quantita(b.citizenid, s.item) or 0
        if q > 0 then
            aBordo[#aBordo + 1] = ('%d × %s'):format(q, s.nome)
            totale = totale + q
        end
    end

    if licenza then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🐟', durata = 18000,
            titolo = ('Controllo — %s'):format(b:NomeCompleto()),
            testo = ('Licenza regolare.\nA bordo: %s')
                :format(#aBordo > 0 and table.concat(aBordo, ', ') or 'niente'),
        })
    end

    exports.ita_fisco:IscriviTributo(b.citizenid, 'sanzione',
        'esercizio della pesca professionale senza licenza', PES.Controlli.sanzioneSenzaLicenza, 7)

    if totale > 0 then
        for id, s in pairs(PES.Specie) do
            local q = exports.aurea_inventory:Quantita(b.citizenid, s.item) or 0
            if q > 0 then exports.aurea_inventory:Rimuovi(b.citizenid, s.item, q) end
        end
    end

    AUREA.Log('giustizia', 'info', g, ('ha sanzionato %s per pesca senza licenza'):format(b:NomeCompleto()))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '🐟', durata = 20000,
        titolo = ('Controllo — %s'):format(b:NomeCompleto()),
        testo = ('Nessuna licenza.\nSanzione %s · pescato sequestrato (%d capi).')
            :format(U.Euro(PES.Controlli.sanzioneSenzaLicenza), totale),
    })
end)

print('[AUREA] pesca professionale: quote e mercato ittico attivi')
