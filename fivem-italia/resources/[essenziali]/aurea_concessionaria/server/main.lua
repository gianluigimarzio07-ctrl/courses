--[[
    AUREA · Concessionaria (server)
]]

local U = AUREA.Util
local prove = {}        -- [src] = { modello, sede, avviata, cauzione }
local proposte = {}     -- [destinatario] = { da, targa, prezzo, momento }

local function sedeDi(src, id)
    for _, s in ipairs(CON.Sedi) do
        if s.id == id then
            local coord = GetEntityCoords(GetPlayerPed(src))
            if #(coord - s.coord) < 6.0 then return s end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Listino
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:listino', function(src, rispondi, idSede)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local sede = sedeDi(src, idSede)
    if not sede then return rispondi(nil, 'Non sei in concessionaria.') end

    local out = {}
    for _, v in ipairs(CON.Listino) do
        if U.Contiene(sede.categorie, v.categoria) then
            local totale, iva, oneri = CON.Totale(v.prezzo)
            out[#out + 1] = {
                modello = v.modello, nome = v.nome, categoria = v.categoria,
                kw = v.kw, prezzo = v.prezzo, iva = iva, oneri = oneri, totale = totale,
            }
        end
    end
    table.sort(out, function(a, b) return a.prezzo < b.prezzo end)

    rispondi({
        sede = sede.nome,
        veicoli = out,
        saldo = select(2, AUREA.Denaro.Saldo(g.citizenid)),
        prova = CON.Prova,
    })
end)

-- ---------------------------------------------------------------------------
--  Prova su strada
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:prova', function(src, rispondi, idSede, modello)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if prove[src] then return rispondi(false, 'Hai già una prova in corso.') end

    local sede = sedeDi(src, idSede)
    if not sede then return rispondi(false, 'Non sei in concessionaria.') end

    local v = CON.GetVeicolo(modello)
    if not v or not U.Contiene(sede.categorie, v.categoria) then
        return rispondi(false, 'Questo mezzo non è disponibile qui.')
    end

    if not g:SottraiOvunque(CON.Prova.cauzione, 'cauzione prova su strada') then
        return rispondi(false, ('Serve una cauzione di %s.'):format(U.Euro(CON.Prova.cauzione)))
    end

    prove[src] = {
        modello = modello, sede = sede.id, avviata = os.time(),
        cauzione = CON.Prova.cauzione,
    }

    rispondi(true, {
        modello = modello,
        spawn = { x = sede.prova.x, y = sede.prova.y, z = sede.prova.z, w = sede.prova.w },
        durata = CON.Prova.durata,
        raggio = CON.Prova.raggio,
        centro = { x = sede.coord.x, y = sede.coord.y, z = sede.coord.z },
    })
end)

AUREA.Callback.Registra('con:concludiProva', function(src, rispondi, danni, fuoriZona)
    local g = AUREA.GetPlayer(src)
    local p = prove[src]
    if not g or not p then return rispondi(false, 'Nessuna prova in corso.') end
    prove[src] = nil

    danni = math.max(0, math.min(1, tonumber(danni) or 0))

    local trattenuta = 0
    if fuoriZona then
        trattenuta = p.cauzione
    elseif danni > CON.Prova.sogliaDanni then
        trattenuta = math.floor(p.cauzione * danni)
    end

    local restituita = p.cauzione - trattenuta
    if restituita > 0 then g:Aggiungi('banca', restituita, 'restituzione cauzione') end
    if trattenuta > 0 then
        TriggerEvent('aurea:fisco:incasso', 'iva_concessionaria', trattenuta, g.citizenid)
    end

    rispondi(true, fuoriZona
        and 'Sei uscito dal percorso concordato: la cauzione è trattenuta per intero.'
        or (trattenuta > 0
            and ('Il mezzo è tornato ammaccato: trattenuti %s sulla cauzione.'):format(U.Euro(trattenuta))
            or 'Cauzione restituita per intero.'))
end)

-- ---------------------------------------------------------------------------
--  Acquisto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:acquista', function(src, rispondi, idSede, modello)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local sede = sedeDi(src, idSede)
    if not sede then return rispondi(false, 'Non sei in concessionaria.') end

    local v = CON.GetVeicolo(modello)
    if not v or not U.Contiene(sede.categorie, v.categoria) then
        return rispondi(false, 'Questo mezzo non è disponibile qui.')
    end

    local aliquota = exports.ita_fisco:AliquotaItem(nil) or 22
    local totale, iva, oneri = CON.Totale(v.prezzo, aliquota)

    -- Un'auto si paga dal conto, non con le banconote in tasca
    if not AUREA.Denaro.SottraiOffline(g.citizenid, 'banca', totale, ('acquisto %s'):format(v.nome)) then
        return rispondi(false, ('Servono %s sul conto (%s + IVA %s + oneri %s).')
            :format(U.Euro(totale), U.Euro(v.prezzo), U.Euro(iva), U.Euro(oneri)))
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_concessionaria', iva, g.citizenid)
    TriggerEvent('aurea:fisco:incasso', 'ipt_veicoli', oneri, g.citizenid)

    local targa = exports.ita_veicoli:Immatricola(g.citizenid, modello, {
        categoria = v.categoria,
        garage = 'centrale',
    })

    if not targa then
        AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', totale, 'rimborso: immatricolazione fallita')
        return rispondi(false, 'L\'immatricolazione non è andata a buon fine. Sei stato rimborsato.')
    end

    AUREA.Log('veicoli', 'info', g, ('ha acquistato %s (%s) per %s'):format(v.nome, targa, U.Euro(totale)))

    rispondi(true, {
        targa = targa,
        nome = v.nome,
        consegna = { x = sede.consegna.x, y = sede.consegna.y, z = sede.consegna.z, w = sede.consegna.w },
        modello = modello,
        messaggio = ('%s immatricolata: targa %s. Bollo e primo tagliando compresi.')
            :format(v.nome, targa),
    })
end)

-- ---------------------------------------------------------------------------
--  Usato fra privati
--
--  Il passaggio di proprietà è un atto: servono due persone, un prezzo e
--  gli oneri. Non si regalano veicoli per aggirare le imposte.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:mieiInVendita', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT targa, modello, categoria, km, motore, carrozzeria, stato
        FROM veicoli WHERE citizenid = ? AND stato IN ('garage','fuori')
    ]], { g.citizenid }) or {}

    for _, r in ipairs(righe) do
        r.usura = math.floor(100 - ((tonumber(r.motore) or 1000) / 10))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('con:proponiVendita', function(src, rispondi, bersaglioSrc, targa, prezzo)
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not altro or g.source == altro.source then return rispondi(false, 'Persona non trovata.') end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(altro.source)))
    if d > CON.Usato.distanza then return rispondi(false, 'Dovete essere vicini.') end

    prezzo = math.floor(tonumber(prezzo) or 0)
    if prezzo < CON.Usato.prezzoMinimo then
        return rispondi(false, ('Il prezzo dichiarato non può essere sotto %s: sarebbe una vendita simulata.')
            :format(U.Euro(CON.Usato.prezzoMinimo)))
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local v = MySQL.single.await('SELECT modello, citizenid, stato FROM veicoli WHERE targa = ?', { targa })
    if not v or v.citizenid ~= g.citizenid then return rispondi(false, 'Non è intestato a te.') end
    if v.stato == 'sequestrato' or v.stato == 'demolito' then
        return rispondi(false, 'Su questo mezzo grava un vincolo: non è trasferibile.')
    end

    proposte[altro.source] = { da = src, targa = targa, prezzo = prezzo, momento = os.time() }

    TriggerClientEvent('con:propostaRicevuta', altro.source, {
        venditore = g:NomeCompleto(),
        targa = targa, modello = v.modello, prezzo = prezzo,
        oneri = CON.Usato.ipt + CON.Usato.diritti,
    })

    rispondi(true, ('Proposta inviata a %s.'):format(altro:NomeCompleto()))
end)

AUREA.Callback.Registra('con:rispondiVendita', function(src, rispondi, accetta)
    local p = proposte[src]
    if not p then return rispondi(false, 'Nessuna proposta in sospeso.') end
    proposte[src] = nil

    if (os.time() - p.momento) > 90 then return rispondi(false, 'La proposta è scaduta.') end

    local acquirente = AUREA.GetPlayer(src)
    local venditore = AUREA.GetPlayer(p.da)
    if not acquirente or not venditore then return rispondi(false, 'L\'altra parte non è più in linea.') end

    if not accetta then
        TriggerClientEvent('aurea:ui:notifica', venditore.source, {
            tipo = 'info', icona = '🚗', titolo = 'Proposta rifiutata',
            testo = ('%s non è interessato.'):format(acquirente:NomeCompleto()), durata = 9000,
        })
        return rispondi(true, 'Hai rifiutato.')
    end

    -- Il veicolo deve essere ancora suo: nel frattempo poteva venderlo
    local v = MySQL.single.await('SELECT modello, citizenid FROM veicoli WHERE targa = ?', { p.targa })
    if not v or v.citizenid ~= venditore.citizenid then
        return rispondi(false, 'Il veicolo non risulta più intestato al venditore.')
    end

    local oneri = CON.Usato.ipt + CON.Usato.diritti
    local dovuto = p.prezzo + oneri

    if not AUREA.Denaro.SottraiOffline(acquirente.citizenid, 'banca', dovuto, ('acquisto %s'):format(p.targa)) then
        return rispondi(false, ('Servono %s sul conto (%s + oneri %s).')
            :format(U.Euro(dovuto), U.Euro(p.prezzo), U.Euro(oneri)))
    end

    AUREA.Denaro.AggiungiOffline(venditore.citizenid, 'banca', p.prezzo, ('vendita %s'):format(p.targa))
    TriggerEvent('aurea:fisco:incasso', 'ipt_veicoli', oneri, acquirente.citizenid)

    MySQL.update.await('UPDATE veicoli SET citizenid = ?, garage = \'centrale\', stato = \'garage\' WHERE targa = ?',
        { acquirente.citizenid, p.targa })

    TriggerEvent('aurea:inventario:aggiungi', acquirente.citizenid, 'libretto', 1, {
        targa = p.targa, modello = v.modello, intestatario = acquirente:NomeCompleto(),
    })

    TriggerClientEvent('aurea:ui:notifica', venditore.source, {
        tipo = 'successo', icona = '🚗', durata = 13000,
        titolo = 'Passaggio di proprietà concluso',
        testo = ('%s è ora di %s. Accreditati %s.')
            :format(p.targa, acquirente:NomeCompleto(), U.Euro(p.prezzo)),
    })

    AUREA.Log('veicoli', 'info', venditore,
        ('passaggio di proprietà di %s a %s per %s'):format(p.targa, acquirente.citizenid, U.Euro(p.prezzo)))

    rispondi(true, ('Il veicolo è tuo. Targa %s, pagati %s.'):format(p.targa, U.Euro(dovuto)))
end)

AddEventHandler('playerDropped', function()
    prove[source] = nil
    proposte[source] = nil
end)
