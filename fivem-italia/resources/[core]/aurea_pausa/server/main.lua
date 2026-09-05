--[[
    AUREA · Menu di pausa (server)
]]

RegisterNetEvent('pau:esci', function()
    local src = source
    local g = AUREA.GetPlayer(src)

    if g then
        g:Salva()
        AUREA.Log('connessioni', 'debug', g, 'uscita volontaria dal menu di pausa')
    end

    DropPlayer(src, 'Alla prossima.')
end)
