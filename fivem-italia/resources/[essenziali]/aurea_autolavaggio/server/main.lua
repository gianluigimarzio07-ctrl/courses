--[[
    AUREA · Autolavaggio (server)
]]

local U = AUREA.Util

AUREA.Callback.Registra('lav:lava', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local impianto = LAV.ImpiantoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not impianto then return rispondi(false, 'Non sei a un autolavaggio.') end

    if not g:SottraiOvunque(impianto.prezzo, ('lavaggio · %s'):format(impianto.nome)) then
        return rispondi(false, ('Il lavaggio costa %s.'):format(U.Euro(impianto.prezzo)))
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(impianto.prezzo * 0.22), g.citizenid)
    rispondi(true, LAV.Lavaggio.durata)
end)
