--[[
    ESX su AUREA — ESX.Game

    Sono le utilità di gioco che praticamente ogni script ESX usa: trova il
    veicolo più vicino, fai apparire una macchina, leggi le sue proprietà,
    teletrasporta. Non hanno niente a che vedere con il framework — sono
    solo funzioni sui native — quindi qui si reimplementano per intero e
    fedelmente, senza passare da AUREA.
]]

ESX.Game = {}

-- ---------------------------------------------------------------------------
--  Tempo e meteo
--
--  In AUREA li governa ita_ambiente, che li tiene sincronizzati per tutti.
--  Uno script ESX che li cambia da solo romperebbe quella sincronia: qui
--  si rifiuta e lo si dice, invece di lasciare due orologi diversi.
-- ---------------------------------------------------------------------------
function ESX.Game.SetWeather()
    return ESX.NonImplementato('ESX.Game.SetWeather',
        'Il meteo lo governa ita_ambiente per tutto il server.')
end

function ESX.Game.SetTime()
    return ESX.NonImplementato('ESX.Game.SetTime',
        'L\'orario lo governa ita_ambiente per tutto il server.')
end

-- ---------------------------------------------------------------------------
--  Entità
-- ---------------------------------------------------------------------------
function ESX.Game.GetPedMugshot(ped, trasparente)
    if not DoesEntityExist(ped) then return end
    local mugshot = trasparente and RegisterPedheadshotTransparent(ped) or RegisterPedheadshot(ped)

    local scadenza = GetGameTimer() + 5000
    while not IsPedheadshotReady(mugshot) and GetGameTimer() < scadenza do Wait(0) end

    return mugshot, GetPedheadshotTxdString(mugshot)
end

function ESX.Game.Teleport(entita, coord, cb)
    if not DoesEntityExist(entita) then
        if cb then cb() end
        return
    end

    RequestCollisionAtCoord(coord.x, coord.y, coord.z)
    SetEntityCoords(entita, coord.x, coord.y, coord.z, false, false, false, true)
    if coord.heading then SetEntityHeading(entita, coord.heading) end

    local scadenza = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(entita) and GetGameTimer() < scadenza do Wait(0) end

    if cb then cb() end
end

function ESX.Game.SpawnObject(modello, coord, cb, rete)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello

    ESX.Streaming.RequestModel(hash, function(ok)
        if not ok then
            if cb then cb(nil) end
            return
        end

        local oggetto = CreateObject(hash, coord.x, coord.y, coord.z, rete ~= false, false, true)
        SetModelAsNoLongerNeeded(hash)
        if cb then cb(oggetto) end
    end)
end

function ESX.Game.SpawnLocalObject(modello, coord, cb)
    ESX.Game.SpawnObject(modello, coord, cb, false)
end

function ESX.Game.DeleteObject(oggetto)
    SetEntityAsMissionEntity(oggetto, false, true)
    DeleteObject(oggetto)
end

function ESX.Game.SpawnVehicle(modello, coord, direzione, cb, rete)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello
    if not IsModelValid(hash) or not IsModelAVehicle(hash) then
        print(('[es_extended] SpawnVehicle: modello "%s" non valido.'):format(tostring(modello)))
        if cb then cb(nil) end
        return
    end

    ESX.Streaming.RequestModel(hash, function(ok)
        if not ok then
            if cb then cb(nil) end
            return
        end

        local veicolo = CreateVehicle(hash, coord.x, coord.y, coord.z, direzione or 0.0, rete ~= false, false)

        SetVehicleHasBeenOwnedByPlayer(veicolo, true)
        SetVehicleNeedsToBeHotwired(veicolo, false)
        SetVehRadioStation(veicolo, 'OFF')
        SetModelAsNoLongerNeeded(hash)

        if rete ~= false then
            local id = NetworkGetNetworkIdFromEntity(veicolo)
            SetNetworkIdCanMigrate(id, true)
            SetNetworkIdExistsOnAllMachines(id, true)
        end

        if cb then cb(veicolo) end
    end)
end

function ESX.Game.SpawnLocalVehicle(modello, coord, direzione, cb)
    ESX.Game.SpawnVehicle(modello, coord, direzione, cb, false)
end

function ESX.Game.DeleteVehicle(veicolo)
    SetEntityAsMissionEntity(veicolo, true, true)
    DeleteVehicle(veicolo)
end

function ESX.Game.IsVehicleEmpty(veicolo)
    return GetVehicleNumberOfPassengers(veicolo) == 0 and IsVehicleSeatFree(veicolo, -1)
end

function ESX.Game.IsSpawnPointClear(coord, raggio)
    local centro = vector3(coord.x, coord.y, coord.z)
    for _, v in ipairs(ESX.Game.GetVehicles()) do
        if #(centro - GetEntityCoords(v)) <= raggio then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
--  Elenchi
-- ---------------------------------------------------------------------------
function ESX.Game.GetObjects()
    local out = {}
    local handle, entita = FindFirstObject()
    local trovato

    repeat
        out[#out + 1] = entita
        trovato, entita = FindNextObject(handle)
    until not trovato

    EndFindObject(handle)
    return out
end

function ESX.Game.GetPeds(ignora)
    local esclusi = {}
    for _, p in ipairs(ignora or {}) do esclusi[p] = true end

    local out = {}
    local handle, entita = FindFirstPed()
    local trovato

    repeat
        if not esclusi[entita] then out[#out + 1] = entita end
        trovato, entita = FindNextPed(handle)
    until not trovato

    EndFindPed(handle)
    return out
end

function ESX.Game.GetVehicles()
    local out = {}
    local handle, entita = FindFirstVehicle()
    local trovato

    repeat
        out[#out + 1] = entita
        trovato, entita = FindNextVehicle(handle)
    until not trovato

    EndFindVehicle(handle)
    return out
end

function ESX.Game.GetPlayers(soloAltri, restituisciPed, restituisciId)
    local mio = PlayerPedId()
    local out = {}

    for _, id in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(id)
        if DoesEntityExist(ped) and not (soloAltri and ped == mio) then
            if restituisciId then
                out[#out + 1] = restituisciPed and { ped = ped, id = GetPlayerServerId(id) }
                    or GetPlayerServerId(id)
            else
                out[#out + 1] = restituisciPed and ped or id
            end
        end
    end

    return out
end

-- ---------------------------------------------------------------------------
--  Il più vicino
-- ---------------------------------------------------------------------------
local function piuVicino(entita, coord, distanzaMassima)
    local centro = coord and vector3(coord.x, coord.y, coord.z) or GetEntityCoords(PlayerPedId())
    local migliore, distanza = -1, distanzaMassima or math.huge

    for _, e in ipairs(entita) do
        local d = #(centro - GetEntityCoords(e))
        if d < distanza then migliore, distanza = e, d end
    end

    return migliore, migliore ~= -1 and distanza or -1
end

function ESX.Game.GetClosestObject(coord, modelli)
    local candidati = ESX.Game.GetObjects()
    if modelli then
        local ammessi = {}
        for _, m in ipairs(modelli) do
            ammessi[type(m) == 'string' and GetHashKey(m) or m] = true
        end
        candidati = ESX.Table.Filter(candidati, function(o) return ammessi[GetEntityModel(o)] end)
    end
    return piuVicino(candidati, coord)
end

function ESX.Game.GetClosestPed(coord, ignora)
    return piuVicino(ESX.Game.GetPeds(ignora), coord)
end

function ESX.Game.GetClosestVehicle(coord)
    return piuVicino(ESX.Game.GetVehicles(), coord)
end

function ESX.Game.GetClosestPlayer(coord)
    local centro = coord and vector3(coord.x, coord.y, coord.z) or GetEntityCoords(PlayerPedId())
    local mio = PlayerPedId()
    local migliore, distanza = -1, math.huge

    for _, id in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= mio and DoesEntityExist(ped) then
            local d = #(centro - GetEntityCoords(ped))
            if d < distanza then migliore, distanza = id, d end
        end
    end

    return migliore, migliore ~= -1 and distanza or -1
end

function ESX.Game.GetPlayersInArea(coord, raggio)
    local centro = vector3(coord.x, coord.y, coord.z)
    local out = {}

    for _, id in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(id)
        if DoesEntityExist(ped) and #(centro - GetEntityCoords(ped)) <= raggio then
            out[#out + 1] = id
        end
    end

    return out
end

function ESX.Game.GetVehiclesInArea(coord, raggio)
    local centro = vector3(coord.x, coord.y, coord.z)
    return ESX.Table.Filter(ESX.Game.GetVehicles(), function(v)
        return #(centro - GetEntityCoords(v)) <= raggio
    end)
end

function ESX.Game.GetVehicleInDirection()
    local ped = PlayerPedId()
    local da = GetEntityCoords(ped)
    local a = GetOffsetFromEntityInWorldCoords(ped, 0.0, 8.0, 0.0)

    local raggio = StartShapeTestRay(da.x, da.y, da.z, a.x, a.y, a.z, 10, ped, 0)
    local _, colpito, _, _, entita = GetShapeTestResult(raggio)

    if colpito == 1 and GetEntityType(entita) == 2 then return entita end
    return nil
end

-- ---------------------------------------------------------------------------
--  Proprietà dei veicoli
--
--  Sono la parte più copiata di ESX e la più delicata: se manca un campo,
--  un veicolo salvato torna diverso da com'era. Qui ci sono tutti.
-- ---------------------------------------------------------------------------
function ESX.Game.GetVehicleProperties(veicolo)
    if not DoesEntityExist(veicolo) then return nil end

    local colorePrimario, coloreSecondario = GetVehicleColours(veicolo)
    local pearlescente, coloreCerchi = GetVehicleExtraColours(veicolo)
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(veicolo)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(veicolo)
    local rn, gn, bn = GetVehicleNeonLightsColour(veicolo)
    local rf, gf, bf = GetVehicleTyreSmokeColor(veicolo)

    local extra = {}
    for i = 0, 20 do
        if DoesExtraExist(veicolo, i) then
            extra[tostring(i)] = IsVehicleExtraTurnedOn(veicolo, i) == 1
        end
    end

    local modifiche, modificheAttive = {}, {}
    for i = 0, 49 do
        modifiche[tostring(i)] = GetVehicleMod(veicolo, i)
        modificheAttive[tostring(i)] = GetVehicleModVariation(veicolo, i)
    end

    return {
        model = GetEntityModel(veicolo),
        plate = ESX.Math.Trim(GetVehicleNumberPlateText(veicolo)),
        plateIndex = GetVehicleNumberPlateTextIndex(veicolo),

        bodyHealth = ESX.Math.Round(GetVehicleBodyHealth(veicolo), 1),
        engineHealth = ESX.Math.Round(GetVehicleEngineHealth(veicolo), 1),
        tankHealth = ESX.Math.Round(GetVehiclePetrolTankHealth(veicolo), 1),
        fuelLevel = ESX.Math.Round(GetVehicleFuelLevel(veicolo), 1),
        dirtLevel = ESX.Math.Round(GetVehicleDirtLevel(veicolo), 1),

        color1 = colorePrimario,
        color2 = coloreSecondario,
        customPrimaryColor = GetIsVehiclePrimaryColourCustom(veicolo) and { r1, g1, b1 } or nil,
        customSecondaryColor = GetIsVehicleSecondaryColourCustom(veicolo) and { r2, g2, b2 } or nil,
        pearlescentColor = pearlescente,
        wheelColor = coloreCerchi,
        dashboardColor = GetVehicleDashboardColour(veicolo),
        interiorColor = GetVehicleInteriorColour(veicolo),

        wheels = GetVehicleWheelType(veicolo),
        windowTint = GetVehicleWindowTint(veicolo),
        xenonColor = GetVehicleXenonLightsColour(veicolo),

        neonEnabled = {
            IsVehicleNeonLightEnabled(veicolo, 0),
            IsVehicleNeonLightEnabled(veicolo, 1),
            IsVehicleNeonLightEnabled(veicolo, 2),
            IsVehicleNeonLightEnabled(veicolo, 3),
        },
        neonColor = { rn, gn, bn },
        tyreSmokeColor = { rf, gf, bf },

        extras = extra,
        mods = modifiche,
        modVariations = modificheAttive,
        modLivery = GetVehicleLivery(veicolo),
        modRoofLivery = GetVehicleRoofLivery(veicolo),
        modFrontWheels = GetVehicleMod(veicolo, 23),
        modBackWheels = GetVehicleMod(veicolo, 24),
        modCustomTiresF = GetVehicleModVariation(veicolo, 23),
        modCustomTiresR = GetVehicleModVariation(veicolo, 24),
        modSmokeEnabled = IsToggleModOn(veicolo, 20),
        modXenon = IsToggleModOn(veicolo, 22),
        modTurbo = IsToggleModOn(veicolo, 18),
    }
end

function ESX.Game.SetVehicleProperties(veicolo, p)
    if not DoesEntityExist(veicolo) or type(p) ~= 'table' then return end

    SetVehicleModKit(veicolo, 0)

    if p.plate then SetVehicleNumberPlateText(veicolo, p.plate) end
    if p.plateIndex then SetVehicleNumberPlateTextIndex(veicolo, p.plateIndex) end

    if p.bodyHealth then SetVehicleBodyHealth(veicolo, p.bodyHealth + 0.0) end
    if p.engineHealth then SetVehicleEngineHealth(veicolo, p.engineHealth + 0.0) end
    if p.tankHealth then SetVehiclePetrolTankHealth(veicolo, p.tankHealth + 0.0) end
    if p.fuelLevel then SetVehicleFuelLevel(veicolo, p.fuelLevel + 0.0) end
    if p.dirtLevel then SetVehicleDirtLevel(veicolo, p.dirtLevel + 0.0) end

    if p.color1 then
        local _, secondario = GetVehicleColours(veicolo)
        SetVehicleColours(veicolo, p.color1, p.color2 or secondario)
    end
    if p.customPrimaryColor then
        SetVehicleCustomPrimaryColour(veicolo, table.unpack(p.customPrimaryColor))
    end
    if p.customSecondaryColor then
        SetVehicleCustomSecondaryColour(veicolo, table.unpack(p.customSecondaryColor))
    end
    if p.pearlescentColor or p.wheelColor then
        local perla, cerchi = GetVehicleExtraColours(veicolo)
        SetVehicleExtraColours(veicolo, p.pearlescentColor or perla, p.wheelColor or cerchi)
    end
    if p.dashboardColor then SetVehicleDashboardColour(veicolo, p.dashboardColor) end
    if p.interiorColor then SetVehicleInteriorColour(veicolo, p.interiorColor) end

    if p.wheels then SetVehicleWheelType(veicolo, p.wheels) end
    if p.windowTint then SetVehicleWindowTint(veicolo, p.windowTint) end

    for id, acceso in pairs(p.extras or {}) do
        SetVehicleExtra(veicolo, tonumber(id), acceso and 0 or 1)
    end

    if p.neonEnabled then
        for i = 1, 4 do
            SetVehicleNeonLightEnabled(veicolo, i - 1, p.neonEnabled[i] and true or false)
        end
    end
    if p.neonColor then SetVehicleNeonLightsColour(veicolo, table.unpack(p.neonColor)) end
    if p.tyreSmokeColor then SetVehicleTyreSmokeColor(veicolo, table.unpack(p.tyreSmokeColor)) end

    for id, valore in pairs(p.mods or {}) do
        local n = tonumber(id)
        if n and valore and valore ~= -1 then
            SetVehicleMod(veicolo, n, valore, (p.modVariations or {})[id] or false)
        end
    end

    if p.modLivery then SetVehicleLivery(veicolo, p.modLivery) end
    if p.modRoofLivery then SetVehicleRoofLivery(veicolo, p.modRoofLivery) end
    if p.modFrontWheels then SetVehicleMod(veicolo, 23, p.modFrontWheels, p.modCustomTiresF or false) end
    if p.modBackWheels then SetVehicleMod(veicolo, 24, p.modBackWheels, p.modCustomTiresR or false) end

    if p.modSmokeEnabled ~= nil then ToggleVehicleMod(veicolo, 20, p.modSmokeEnabled and true or false) end
    if p.modXenon ~= nil then ToggleVehicleMod(veicolo, 22, p.modXenon and true or false) end
    if p.modTurbo ~= nil then ToggleVehicleMod(veicolo, 18, p.modTurbo and true or false) end
    if p.xenonColor then SetVehicleXenonLightsColour(veicolo, p.xenonColor) end
end

-- ---------------------------------------------------------------------------
--  ESX.Game.Utils
--
--  In ESX vero contiene una sola cosa, la telecamera davanti al ped, usata
--  dai menu di personalizzazione.
-- ---------------------------------------------------------------------------
ESX.Game.Utils = {}

function ESX.Game.Utils.DrawText3D(coord, testo, scala)
    AUREA.Testo3D(coord.x, coord.y, coord.z, testo, scala)
end
