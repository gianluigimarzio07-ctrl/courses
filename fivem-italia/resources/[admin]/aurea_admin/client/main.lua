--[[
    AUREA · Amministrazione (client)
]]

local modalitaStaff = false
local noclip = false
local velocitaNoclip = 1.0

RegisterNetEvent('aurea:admin:modalitaStaff', function(attiva)
    modalitaStaff = attiva
    local ped = PlayerPedId()

    SetEntityInvincible(ped, attiva)
    SetEntityVisible(ped, not attiva, false)
    SetLocalPlayerVisibleLocally(attiva)
    SetPlayerInvincible(PlayerId(), attiva)

    if not attiva and noclip then
        noclip = false
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
    end
end)

RegisterNetEvent('aurea:admin:rianima', function()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)

    NetworkResurrectLocalPlayer(coord.x, coord.y, coord.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)

    TriggerEvent('aurea:hud:mostra', true)
    exports.aurea_ui:Notifica({ tipo = 'successo', icona = '✚', titolo = 'Rianimato', testo = 'Sei stato rimesso in piedi dallo staff.' })
end)

-- ---------------------------------------------------------------------------
--  Noclip (solo in modalità staff)
-- ---------------------------------------------------------------------------
RegisterCommand('noclip', function()
    if not modalitaStaff then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Modalità staff necessaria', testo = 'Attivala con /staff.',
        })
    end

    noclip = not noclip
    local ped = PlayerPedId()
    local entita = GetVehiclePedIsIn(ped, false)
    if entita == 0 then entita = ped end

    FreezeEntityPosition(entita, noclip)
    SetEntityCollision(entita, not noclip, not noclip)
    SetEntityInvincible(entita, noclip)

    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🛡',
        titolo = noclip and 'Noclip attivo' or 'Noclip disattivato',
        testo = noclip and 'MAIUSC per accelerare, ALT per rallentare.' or nil,
    })
end, false)
RegisterKeyMapping('noclip', 'Attiva o disattiva il noclip (staff)', 'keyboard', 'F9')

CreateThread(function()
    while true do
        local attesa = 500

        if noclip then
            attesa = 0
            local ped = PlayerPedId()
            local entita = GetVehiclePedIsIn(ped, false)
            if entita == 0 then entita = ped end

            local coord = GetEntityCoords(entita)
            local camera = GetGameplayCamRot(2)
            local avanti = 0.0
            local laterale = 0.0

            velocitaNoclip = IsControlPressed(0, 21) and 4.0 or (IsControlPressed(0, 19) and 0.25 or 1.0)

            if IsControlPressed(0, 32) then avanti = velocitaNoclip end
            if IsControlPressed(0, 33) then avanti = -velocitaNoclip end
            if IsControlPressed(0, 34) then laterale = -velocitaNoclip end
            if IsControlPressed(0, 35) then laterale = velocitaNoclip end

            if avanti ~= 0.0 or laterale ~= 0.0 then
                local rad = math.rad(camera.z)
                local pitch = math.rad(camera.x)

                local nuovoX = coord.x - (math.sin(rad) * avanti) + (math.cos(rad) * laterale)
                local nuovoY = coord.y + (math.cos(rad) * avanti) + (math.sin(rad) * laterale)
                local nuovoZ = coord.z + (math.sin(pitch) * avanti)

                SetEntityCoordsNoOffset(entita, nuovoX, nuovoY, nuovoZ, true, true, true)
            end

            DisableControlAction(0, 21, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Informazioni rapide sul giocatore inquadrato
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 500

        if modalitaStaff then
            attesa = 0
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)

            for _, altro in ipairs(GetActivePlayers()) do
                local altroPed = GetPlayerPed(altro)
                if altroPed ~= ped then
                    local posizione = GetEntityCoords(altroPed)
                    if #(coord - posizione) < 25.0 then
                        AUREA.Testo3D(posizione.x, posizione.y, posizione.z + 1.05,
                            ('[%d] %s'):format(GetPlayerServerId(altro), GetPlayerName(altro)), 0.3)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

exports('ModalitaStaff', function() return modalitaStaff end)
