--[[
    AUREA su ESX (client)

    Il grosso non serve: aurea_core lato client si aggancia già a
    aurea:giocatore:caricato, che il server emette dopo esx:playerLoaded.
    Da lì in poi AUREA.PG esiste e le 78 risorse funzionano.

    Restano due cose che in questa modalità non fa nessuno, perché
    aurea_spawn è spento e ESX non le conosce: rimettere il personaggio
    dove l'aveva lasciato, e rimettergli la salute e l'armatura che aveva.
]]

local giaPosizionato = false

AddEventHandler('aurea:client:caricato', function(pacchetto)
    if giaPosizionato then return end
    giaPosizionato = true

    CreateThread(function()
        -- ESX ha appena fatto il suo spawn: si aspetta che finisca,
        -- altrimenti si litiga sulla posizione e vince lui.
        Wait(3000)

        local posizione = AUREA.Callback.Attendi('aesx:posizione')
        if posizione and posizione.x then
            local ped = PlayerPedId()
            RequestCollisionAtCoord(posizione.x, posizione.y, posizione.z)
            SetEntityCoords(ped, posizione.x, posizione.y, posizione.z, false, false, false, false)
            SetEntityHeading(ped, posizione.h or 0.0)

            local scadenza = GetGameTimer() + 6000
            while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < scadenza do Wait(0) end
        end

        local stato = pacchetto and pacchetto.stato
        if stato then
            local ped = PlayerPedId()
            if stato.salute and stato.salute > 100 then SetEntityHealth(ped, math.floor(stato.salute)) end
            if stato.armatura then SetPedArmour(ped, math.floor(stato.armatura)) end
        end

        ShutdownLoadingScreen()
        DoScreenFadeIn(800)
    end)
end)

AddEventHandler('aurea:client:scaricato', function()
    giaPosizionato = false
end)
