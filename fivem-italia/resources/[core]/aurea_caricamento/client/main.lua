--[[
    AUREA · Schermata di caricamento (client)

    Il minuto in cui il gioco carica è l'unico in cui un giocatore nuovo
    legge davvero qualcosa. Invece di sprecarlo con un logo, qui gli si
    spiega dove sta entrando.
]]

CreateThread(function()
    -- La schermata resta finché la sessione non è pronta
    while not NetworkIsSessionStarted() do Wait(300) end
    Wait(2000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)
