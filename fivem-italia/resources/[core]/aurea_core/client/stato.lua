--[[
    AUREA · Effetti locali dello stato del personaggio
    Fame, sete, stress e alcolemia hanno conseguenze visibili sul ped.
]]

local ultimoAlcol = 0

RegisterNetEvent('aurea:stato:danno', function(quantita)
    local ped = PlayerPedId()
    local salute = GetEntityHealth(ped)
    if salute > 101 then
        SetEntityHealth(ped, math.max(101, salute - quantita))
    end
end)

-- Effetti visivi e fisici
CreateThread(function()
    while true do
        local attesa = 1000
        local pg = AUREA.PG

        if pg and pg.stato then
            local ped = PlayerPedId()
            local s = pg.stato

            -- Alcolemia: camminata ubriaca e sfocatura progressive
            local alcol = s.alcol or 0
            if alcol ~= ultimoAlcol then
                ultimoAlcol = alcol
                if alcol >= 0.5 then
                    RequestAnimSet('move_m@drunk@verydrunk')
                    while not HasAnimSetLoaded('move_m@drunk@verydrunk') do Wait(10) end
                    SetPedMovementClipset(ped, 'move_m@drunk@verydrunk', 1.0)
                    SetTimecycleModifier('spectator5')
                    SetTimecycleModifierStrength(math.min(1.0, alcol / 2.0))
                    ShakeGameplayCam('DRUNK_SHAKE', math.min(1.0, alcol / 2.5))
                else
                    ResetPedMovementClipset(ped, 0.0)
                    ClearTimecycleModifier()
                    StopGameplayCamShaking(true)
                end
            end

            -- Stanchezza da fame/sete: corsa più lenta
            local esausto = (s.fame or 100) < 15 or (s.sete or 100) < 15
            SetPlayerSprint(PlayerId(), not esausto)
            if esausto then
                SetPedMoveRateOverride(ped, 0.82)
                attesa = 500
            end

            -- Stress elevato: tremore della mira e respiro affannoso
            if (s.stress or 0) > 70 then
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ((s.stress - 70) / 30) * 0.09)
                attesa = 500
            end
        end

        Wait(attesa)
    end
end)

-- Consumo: quando si usa un item con effetto, il server aggiorna lo stato e
-- il client riproduce l'animazione corrispondente.
RegisterNetEvent('aurea:stato:consuma', function(tipo)
    local ped = PlayerPedId()
    if tipo == 'bevanda' then
        AUREA.Anima('mp_player_intdrink', 'loop_bottle', 3000, 49)
    elseif tipo == 'cibo' then
        AUREA.Anima('mp_player_inteat@burger', 'mp_player_int_eat_burger', 3500, 49)
    end
    Wait(3500)
    ClearPedTasks(ped)
end)
