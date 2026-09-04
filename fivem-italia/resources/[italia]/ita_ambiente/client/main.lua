--[[
    AUREA · Ambiente (client)
]]

local meteoCorrente = 'CLEAR'
local atmosfera = nil
local blipEvento = nil

-- ---------------------------------------------------------------------------
--  Sincronizzazione dell'ora
-- ---------------------------------------------------------------------------
RegisterNetEvent('amb:sincronizza', function(dati)
    NetworkOverrideClockTime(dati.ore, dati.minuti, 0)
    if dati.meteo and dati.meteo ~= meteoCorrente then
        applicaMeteo(dati.meteo, 20)
    end
end)

-- L'orologio locale scorre fra una sincronizzazione e l'altra
CreateThread(function()
    while true do
        Wait(math.floor(60000 / AMB.Tempo.scala))
        local ore, minuti = GetClockHours(), GetClockMinutes() + 1
        if minuti >= 60 then minuti = 0 ore = (ore + 1) % 24 end
        NetworkOverrideClockTime(ore, minuti, 0)
    end
end)

-- ---------------------------------------------------------------------------
--  Meteo
-- ---------------------------------------------------------------------------
function applicaMeteo(meteo, secondiTransizione)
    meteoCorrente = meteo

    SetWeatherTypeOvertimePersist(meteo, secondiTransizione + 0.0)

    -- La pioggia rende la strada scivolosa: si riduce l'aderenza
    local bagnato = (meteo == 'RAIN' or meteo == 'THUNDER') and 0.65
        or (meteo == 'CLEARING') and 0.35 or 0.0
    SetRainLevel(bagnato > 0 and 1.0 or 0.0)
    SetWetnessLevel(bagnato)

    if meteo == 'THUNDER' then
        SetForceVehicleTrails(true)
    end
end

RegisterNetEvent('amb:meteo', function(meteo, secondi)
    applicaMeteo(meteo, secondi or 45)

    local etichette = {
        EXTRASUNNY = 'Sereno e caldo', CLEAR = 'Sereno', CLOUDS = 'Nuvoloso',
        OVERCAST = 'Coperto', RAIN = 'Pioggia', THUNDER = 'Temporale',
        FOGGY = 'Nebbia', SMOG = 'Foschia',
    }

    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🌤', durata = 6000,
        titolo = 'Cambio delle condizioni',
        testo = etichette[meteo] or meteo,
    })
end)

-- Guida sul bagnato: la tenuta di strada peggiora davvero
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            local suBagnato = meteoCorrente == 'RAIN' or meteoCorrente == 'THUNDER'
            SetVehicleReduceGrip(veicolo, suBagnato)
            if suBagnato and SetVehicleGripLevel then
                SetVehicleGripLevel(veicolo, 0.85)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Atmosfera: festività e periodi
-- ---------------------------------------------------------------------------
RegisterNetEvent('amb:atmosfera', function(dati)
    atmosfera = dati.effetto

    if dati.effetto == 'natale' then
        -- Luminarie: la città si accende prima
        SetArtificialLightsState(false)
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🎄', durata = 12000,
            titolo = dati.nome or 'Periodo natalizio',
            testo = 'Le luminarie sono accese in tutta la città.',
        })
    elseif dati.effetto == 'esodo' then
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🏖', durata = 12000,
            titolo = dati.nome or 'Esodo estivo',
            testo = 'Molti sono partiti: la città è più vuota del solito.',
        })
    end
end)

-- L'esodo di agosto svuota davvero le strade
CreateThread(function()
    while true do
        Wait(5000)
        if atmosfera == 'esodo' then
            SetPedDensityMultiplierThisFrame(0.35)
            SetVehicleDensityMultiplierThisFrame(0.30)
            SetRandomVehicleDensityMultiplierThisFrame(0.30)
            SetParkedVehicleDensityMultiplierThisFrame(0.5)
        elseif atmosfera == 'festa' or atmosfera == 'natale' then
            SetPedDensityMultiplierThisFrame(1.3)
            SetVehicleDensityMultiplierThisFrame(0.8)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Eventi dinamici
-- ---------------------------------------------------------------------------
RegisterNetEvent('amb:evento', function(evento)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '📣', durata = 15000,
        titolo = evento.nome,
        testo = ('%s\nDurata prevista: %d minuti.'):format(evento.descrizione, evento.minuti),
    })

    if evento.coord then
        if blipEvento then RemoveBlip(blipEvento) end
        blipEvento = AddBlipForCoord(evento.coord.x, evento.coord.y, evento.coord.z)
        SetBlipSprite(blipEvento, 496)
        SetBlipColour(blipEvento, 5)
        SetBlipScale(blipEvento, 0.9)
        SetBlipFlashes(blipEvento, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(evento.nome)
        EndTextCommandSetBlipName(blipEvento)
    end

    -- Il blackout spegne davvero le luci
    if evento.effetto and evento.effetto.tipo == 'blackout' then
        SetArtificialLightsState(true)
        SetArtificialLightsStateAffectsVehicles(false)
    end
end)

RegisterNetEvent('amb:eventoConcluso', function()
    if blipEvento then RemoveBlip(blipEvento) blipEvento = nil end
    SetArtificialLightsState(false)
end)

-- ---------------------------------------------------------------------------
--  Stato iniziale
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(2000)
        local stato = AUREA.Callback.Attendi('amb:stato')
        if not stato then return end

        NetworkOverrideClockTime(stato.ore, stato.minuti, 0)
        applicaMeteo(stato.meteo, 0)
        atmosfera = stato.atmosfera

        if stato.evento then
            TriggerEvent('amb:evento', {
                nome = stato.evento.nome, descrizione = stato.evento.descrizione,
                minuti = 0, coord = stato.evento.coord,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '📅', durata = 9000,
            titolo = ('%s a Los Santos'):format(stato.stagioneEtichetta),
            testo = ('%s%s'):format(
                stato.atmosferaNome and (stato.atmosferaNome .. '. ') or '',
                ('Alba alle %02d:%02d, tramonto alle %02d:%02d.'):format(
                    math.floor(stato.alba), math.floor((stato.alba % 1) * 60),
                    math.floor(stato.tramonto), math.floor((stato.tramonto % 1) * 60))),
        })
    end)
end)

RegisterCommand('tempo', function()
    CreateThread(function()
        local stato = AUREA.Callback.Attendi('amb:stato')
        if not stato then return end

        local etichette = {
            EXTRASUNNY = 'sereno e caldo', CLEAR = 'sereno', CLOUDS = 'nuvoloso',
            OVERCAST = 'coperto', RAIN = 'piovoso', THUNDER = 'temporalesco',
            FOGGY = 'nebbioso', SMOG = 'con foschia',
        }

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🌤', durata = 11000,
            titolo = ('%02d:%02d · %s'):format(stato.ore, stato.minuti, stato.stagioneEtichetta),
            testo = ('Cielo %s.%s%s'):format(
                etichette[stato.meteo] or stato.meteo,
                stato.atmosferaNome and ('\n' .. stato.atmosferaNome .. '.') or '',
                stato.evento and ('\nIn corso: ' .. stato.evento.nome .. '.') or ''),
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then
        if blipEvento then RemoveBlip(blipEvento) end
        SetArtificialLightsState(false)
    end
end)
