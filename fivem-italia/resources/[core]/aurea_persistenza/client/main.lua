--[[
    AUREA · Persistenza (client)

    Il client è l'unico che vede le entità: raccoglie dove stanno i
    veicoli intestati che ha intorno e li manda al server, e ricrea
    quelli che il server gli dice di ricreare.
]]

local ricreati = {}     -- [targa] = entità

--- Solo i veicoli con una targa nel formato italiano sono intestati:
--- gli altri sono di scena e non vanno salvati.
local function targaValida(t)
    return t:match('^%u%u%d%d%d%u%u$') ~= nil
end

RegisterNetEvent('per:raccogli', function()
    CreateThread(function()
        local elenco = {}
        local ped = PlayerPedId()
        local mio = GetEntityCoords(ped)

        for veicolo in EnumeraVeicoli() do
            if DoesEntityExist(veicolo) and NetworkGetEntityIsNetworked(veicolo) then
                local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()

                if targaValida(targa) then
                    local fermo = GetEntitySpeed(veicolo) <= PER.Veicoli.velocitaMassima
                    if fermo or not PER.Veicoli.salvaSoloFermi then
                        local c = GetEntityCoords(veicolo)
                        -- Si segnala solo quello che si ha vicino: chi è
                        -- lontano lo segnala qualcun altro
                        if #(mio - c) < 300.0 then
                            elenco[#elenco + 1] = {
                                targa = targa,
                                x = c.x, y = c.y, z = c.z, h = GetEntityHeading(veicolo),
                                carburante = GetVehicleFuelLevel(veicolo),
                                motore = GetVehicleEngineHealth(veicolo),
                                carrozzeria = GetVehicleBodyHealth(veicolo),
                            }
                        end
                    end
                end
            end
        end

        if #elenco > 0 then TriggerServerEvent('per:segnala', elenco) end
    end)
end)

RegisterNetEvent('per:ricrea', function(lotto)
    CreateThread(function()
        for _, v in ipairs(lotto or {}) do
            -- Se qualcuno l'ha già ricreato, non se ne fa un secondo
            if not esisteGia(v.targa) then
                local hash = GetHashKey(v.modello)
                RequestModel(hash)
                local n = 0
                while not HasModelLoaded(hash) and n < 100 do Wait(20) n = n + 1 end

                if HasModelLoaded(hash) then
                    local e = CreateVehicle(hash, v.x, v.y, v.z, v.h, true, false)
                    SetVehicleNumberPlateText(e, v.targa)
                    SetVehicleOnGroundProperly(e)
                    SetVehicleFuelLevel(e, v.carburante or 100.0)
                    SetVehicleEngineHealth(e, v.motore or 1000.0)
                    SetVehicleBodyHealth(e, v.carrozzeria or 1000.0)
                    SetVehicleDoorsLocked(e, 2)
                    SetEntityAsMissionEntity(e, true, true)
                    SetModelAsNoLongerNeeded(hash)

                    ricreati[v.targa] = e
                end
            end
            Wait(120)
        end
    end)
end)

function esisteGia(targa)
    for veicolo in EnumeraVeicoli() do
        if DoesEntityExist(veicolo)
           and GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper() == targa then
            return true
        end
    end
    return false
end

--- I relitti rimossi dal server spariscono anche dalla scena.
RegisterNetEvent('per:pulisci', function()
    CreateThread(function()
        for targa, e in pairs(ricreati) do
            if DoesEntityExist(e) then
                local dentro = false
                for posto = -1, 3 do
                    if GetPedInVehicleSeat(e, posto) ~= 0 then dentro = true break end
                end
                if not dentro then
                    SetEntityAsMissionEntity(e, true, true)
                    DeleteVehicle(e)
                    ricreati[targa] = nil
                end
            else
                ricreati[targa] = nil
            end
        end
    end)
end)

--- Iteratore sui veicoli in scena: l'API nativa non ne dà uno.
function EnumeraVeicoli()
    return coroutine.wrap(function()
        local handle, veicolo = FindFirstVehicle()
        local ok = true
        repeat
            coroutine.yield(veicolo)
            ok, veicolo = FindNextVehicle(handle)
        until not ok
        EndFindVehicle(handle)
    end)
end
