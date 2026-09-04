--[[
    AUREA · Protezioni (client)

    Il client non è una fonte attendibile: quello che si fa qui serve a
    rendere scomodo il barare, non a impedirlo. Le decisioni restano al server.
]]

-- ---------------------------------------------------------------------------
--  Elenco delle risorse caricate
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(20000)
    while true do
        local elenco = {}
        for i = 0, GetNumResources() - 1 do
            local nome = GetResourceByFindIndex(i)
            if nome and GetResourceState(nome) == 'started' then
                elenco[#elenco + 1] = nome
            end
        end
        TriggerServerEvent('aurea:anticheat:risorse', elenco)
        Wait(300000)
    end
end)

-- ---------------------------------------------------------------------------
--  Disattivazione dei comportamenti nativi indesiderati
-- ---------------------------------------------------------------------------
CreateThread(function()
    -- Niente ricompense di GTA, niente eventi ambientali casuali
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    DistantCopCarSirens(false)

    -- I NPC non aggrediscono e non chiamano la polizia
    SetPlayerWantedLevelMultiplier(PlayerId(), 0.0)
    SetMaxWantedLevel(0)

    -- Gli automatismi che spawnano veicoli o pedoni speciali
    SetVehicleModelIsSuppressed(`taxi`, false)

    while true do
        Wait(1000)
        -- Nessuna rigenerazione automatica della salute
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
        -- Niente cadute istantanee di armi dai NPC
        DisablePlayerVehicleRewards(PlayerId())
    end
end)

-- ---------------------------------------------------------------------------
--  Blocco dei tasti che aprono i menu di cheat più comuni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 243, true)   -- ~ (console dei trainer)
        DisableControlAction(0, 288, true)   -- F1: gestito dal telefono
        DisableControlAction(0, 289, true)   -- F2
        DisableControlAction(0, 170, true)   -- F3
        DisableControlAction(0, 167, true)   -- F6: gestito dal 112
    end
end)
