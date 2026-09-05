--[[
    AUREA · Terzo occhio (server)

    Qui c'è solo quello che il client non può decidere da solo: la richiesta
    di documenti fra due giocatori, che deve verificare la prossimità.
]]

RegisterNetEvent('tgt:chiediDocumenti', function(bersaglioSrc)
    local src = source
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not altro or g.source == altro.source then return end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(altro.source)))
    if d > 4.0 then return end

    TriggerClientEvent('tgt:documentiRichiesti', altro.source, g:NomeCompleto(), src)
end)
