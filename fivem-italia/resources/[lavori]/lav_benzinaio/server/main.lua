--[[
    AUREA · Rifornimento distributori (server)

    Il livello dei serbatoi vive qui e lo leggono anche i rifornimenti
    dei privati: se il serbatoio è vuoto, la pompa non eroga per nessuno.
]]

local U = AUREA.Util
local serbatoi = {}     -- [id] = litri
local cisterne = {}     -- [src] = litri caricati

CreateThread(function()
    for _, d in ipairs(BEN.Distributori) do
        local salvato = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?',
            { 'carburante_' .. d.id })
        serbatoi[d.id] = tonumber(salvato) or BEN.Serbatoi.capienza
    end
end)

local function salva(id)
    MySQL.query([[
        INSERT INTO economia_stato (chiave, valore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { 'carburante_' .. id, tostring(math.floor(serbatoi[id] or 0)) })
end

--- Il distributore più vicino a una coordinata, con quanto gli resta.
exports('Serbatoio', function(x, y, z)
    local coord = vector3(x, y, z)
    for _, d in ipairs(BEN.Distributori) do
        if #(coord - d.coord) < 25.0 then
            return d.id, math.floor(serbatoi[d.id] or 0), BEN.Serbatoi.capienza
        end
    end
    return nil, 0, 0
end)

--- Chi eroga scala dal serbatoio. Restituisce quanto è stato davvero
--- possibile erogare.
exports('Preleva', function(idDistributore, litri)
    local disponibile = serbatoi[idDistributore]
    if not disponibile then return 0 end

    local erogati = math.min(math.floor(litri or 0), math.floor(disponibile))
    if erogati <= 0 then return 0 end

    serbatoi[idDistributore] = disponibile - erogati
    salva(idDistributore)
    return erogati
end)

-- ---------------------------------------------------------------------------
--  Turno
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ben:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local out = {}
    for _, d in ipairs(BEN.Distributori) do
        local litri = math.floor(serbatoi[d.id] or 0)
        out[#out + 1] = {
            id = d.id, nome = d.nome,
            coord = { x = d.coord.x, y = d.coord.y, z = d.coord.z },
            litri = litri,
            capienza = BEN.Serbatoi.capienza,
            percentuale = math.floor((litri / BEN.Serbatoi.capienza) * 100),
            inRiserva = litri < BEN.Serbatoi.capienza * BEN.Serbatoi.sogliaAllarme,
        }
    end
    table.sort(out, function(a, b) return a.litri < b.litri end)

    rispondi({
        distributori = out,
        cisterna = cisterne[src] or 0,
        capienzaCisterna = BEN.Cisterna.capienza,
        pagaAlLitro = BEN.Cisterna.pagaAlLitro,
        mezzi = BEN.Raffineria.mezzi, modello = BEN.Raffineria.modello,
        eBenzinaio = g.lavoro.nome == BEN.Lavoro,
    })
end)

AUREA.Callback.Registra('ben:carica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= BEN.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - BEN.Raffineria.carico) > 15.0 then
        return rispondi(false, 'Devi essere alla piazzola di carico.')
    end

    if (cisterne[src] or 0) >= BEN.Cisterna.capienza then
        return rispondi(false, 'La cisterna è già piena.')
    end

    rispondi(true, BEN.Cisterna.durataCarico)
end)

AUREA.Callback.Registra('ben:concludiCarico', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    cisterne[src] = BEN.Cisterna.capienza
    rispondi(true, ('Cisterna piena: %d litri.'):format(BEN.Cisterna.capienza))
end)

AUREA.Callback.Registra('ben:rifornisci', function(src, rispondi, idDistributore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= BEN.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end

    local d = BEN.GetDistributore(idDistributore)
    if not d then return rispondi(false, 'Distributore sconosciuto.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - d.coord) > BEN.Cisterna.distanzaScarico then
        return rispondi(false, 'Non sei al distributore.')
    end

    local aBordo = cisterne[src] or 0
    if aBordo <= 0 then return rispondi(false, 'La cisterna è vuota: torna alla raffineria.') end

    local mancanti = BEN.Serbatoi.capienza - (serbatoi[idDistributore] or 0)
    if mancanti < 500 then return rispondi(false, 'Questo distributore è già pieno.') end

    rispondi(true, { durata = BEN.Cisterna.durataScarico, litri = math.min(aBordo, mancanti) })
end)

AUREA.Callback.Registra('ben:concludiScarico', function(src, rispondi, idDistributore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local d = BEN.GetDistributore(idDistributore)
    if not d then return rispondi(false) end

    local aBordo = cisterne[src] or 0
    local mancanti = BEN.Serbatoi.capienza - (serbatoi[idDistributore] or 0)
    local versati = math.min(aBordo, mancanti)
    if versati <= 0 then return rispondi(false, 'Niente da versare.') end

    serbatoi[idDistributore] = (serbatoi[idDistributore] or 0) + versati
    cisterne[src] = aBordo - versati
    salva(idDistributore)

    local paga = versati * BEN.Cisterna.pagaAlLitro
    local ritenuta = math.floor(paga * 0.20)
    g:Aggiungi('banca', paga - ritenuta, 'rifornimento distributore')
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    rispondi(true, ('%d litri versati in %s. Netti %s. In cisterna restano %d litri.')
        :format(versati, d.nome, U.Euro(paga - ritenuta), cisterne[src]))
end)

--- I serbatoi calano anche da soli: c'è chi fa benzina quando non guardi.
CreateThread(function()
    while true do
        Wait(3600000)
        for id, litri in pairs(serbatoi) do
            serbatoi[id] = math.max(0, litri - BEN.Serbatoi.caloOrario)
            salva(id)
        end

        -- Chi è in servizio viene avvisato di quelli in riserva
        for _, d in ipairs(BEN.Distributori) do
            if (serbatoi[d.id] or 0) < BEN.Serbatoi.capienza * BEN.Serbatoi.sogliaAllarme then
                exports.aurea_ui:NotificaLavoro(BEN.Lavoro, {
                    tipo = 'avviso', icona = '⛽', durata = 14000,
                    titolo = 'Distributore in riserva',
                    testo = ('%s è sotto il %d%%.'):format(d.nome,
                        math.floor(BEN.Serbatoi.sogliaAllarme * 100)),
                }, true)
            end
        end
    end
end)

AddEventHandler('playerDropped', function() cisterne[source] = nil end)
