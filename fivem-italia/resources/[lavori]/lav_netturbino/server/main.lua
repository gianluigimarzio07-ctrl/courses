--[[
    AUREA · Nettezza urbana (server)
]]

local U = AUREA.Util
local turni = {}    -- [src] = { giro, punto, svuotati, avviato }

local function colleghiVicini(src)
    local coord = GetEntityCoords(GetPlayerPed(src))
    local quanti = 0
    for altroSrc, altro in pairs(AUREA.Giocatori) do
        if altroSrc ~= src and altro.lavoro.nome == NET.Lavoro and altro.lavoro.servizio then
            if #(coord - GetEntityCoords(GetPlayerPed(altroSrc))) < 25.0 then
                quanti = quanti + 1
            end
        end
    end
    return quanti
end

AUREA.Callback.Registra('net:giri', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if g.lavoro.nome ~= NET.Lavoro then return rispondi(nil, 'Non sei assunto in nettezza urbana.') end

    local out = {}
    for _, giro in ipairs(NET.Giri) do
        out[#out + 1] = {
            id = giro.id, nome = giro.nome, paga = giro.paga,
            cassonetti = #giro.punti,
            totale = giro.paga * #giro.punti,
        }
    end

    rispondi({
        giri = out,
        inCorso = turni[src] and turni[src].giro or nil,
        mezzi = NET.Deposito.mezzi, modello = NET.Deposito.modello,
        bonus = NET.Raccolta.bonusCollega,
    })
end)

AUREA.Callback.Registra('net:avvia', function(src, rispondi, idGiro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= NET.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end
    if turni[src] then return rispondi(false, 'Hai già un giro in corso.') end

    local giro = NET.GetGiro(idGiro)
    if not giro then return rispondi(false, 'Giro sconosciuto.') end

    turni[src] = { giro = idGiro, punto = 1, svuotati = 0, avviato = os.time() }

    local punti = {}
    for n, p in ipairs(giro.punti) do punti[n] = { x = p.x, y = p.y, z = p.z } end

    rispondi(true, { nome = giro.nome, punti = punti, paga = giro.paga })
end)

AUREA.Callback.Registra('net:svuota', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local t = turni[src]
    if not g or not t then return rispondi(false, 'Nessun giro in corso.') end

    local giro = NET.GetGiro(t.giro)
    local punto = giro and giro.punti[t.punto]
    if not punto then return rispondi(false, 'Giro concluso.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - punto) > NET.Raccolta.distanzaPunto + 2.0 then
        return rispondi(false, 'Non sei al cassonetto.')
    end

    t.punto = t.punto + 1
    t.svuotati = t.svuotati + 1

    -- Paga a cassonetto, con il bonus se si lavora in squadra
    local colleghi = colleghiVicini(src)
    local paga = math.floor(giro.paga * (1 + colleghi * NET.Raccolta.bonusCollega))
    g:Aggiungi('contanti', paga, 'raccolta rifiuti')

    -- Ogni tanto nei cassonetti c'è qualcosa che vale
    local recuperato = nil
    if math.random(100) <= NET.Raccolta.probabilitaRecupero then
        local item = NET.Raccolta.recuperabili[math.random(#NET.Raccolta.recuperabili)]
        local inventario = exports.aurea_inventory:Inventario(g.citizenid)
        local q = math.random(1, 3)
        if inventario:Aggiungi(item, q) then
            TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
            recuperato = ('%d× %s'):format(q, AUREA.Item[item].etichetta)
        end
    end

    local finito = t.punto > #giro.punti
    if finito then turni[src] = nil end

    rispondi(true, {
        finito = finito,
        svuotati = t.svuotati,
        totale = #giro.punti,
        paga = paga,
        colleghi = colleghi,
        recuperato = recuperato,
    })
end)

-- ---------------------------------------------------------------------------
--  Isola ecologica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('net:conferisci', function(src, rispondi, differenziato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - NET.Conferimento.coord) > 8.0 then
        return rispondi(false, 'Non sei all\'isola ecologica.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local totale, righe = 0, {}

    for item, prezzo in pairs(NET.Conferimento.prezzi) do
        local q = inventario:Quantita(item)
        if q > 0 then
            inventario:Rimuovi(item, q)
            local valore = prezzo * q
            if not differenziato then
                valore = math.floor(valore * NET.Conferimento.penalitaIndifferenziato)
            end
            totale = totale + valore
            righe[#righe + 1] = ('%d× %s'):format(q, AUREA.Item[item].etichetta)
        end
    end

    if totale == 0 then return rispondi(false, 'Non hai niente da conferire.') end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
    g:Aggiungi('contanti', totale, 'conferimento materiali')

    rispondi(true, ('%s → %s%s.'):format(table.concat(righe, ', '), U.Euro(totale),
        differenziato and '' or ' (dimezzato: non hai differenziato)'))
end)

AddEventHandler('playerDropped', function() turni[source] = nil end)
