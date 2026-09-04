--[[
    AUREA · Missioni di lavoro (client)
    Consegne per il corriere e corse per il tassista.
]]

local U = AUREA.Util
local missione = nil
local blipMissione = nil
local passeggero = nil

local function pulisci()
    if blipMissione then RemoveBlip(blipMissione) blipMissione = nil end
    if passeggero and DoesEntityExist(passeggero) then DeleteEntity(passeggero) end
    passeggero = nil
    missione = nil
    SetWaypointOff()
end

local function segnaDestinazione(coord, etichetta, colore)
    if blipMissione then RemoveBlip(blipMissione) end
    blipMissione = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(blipMissione, 1)
    SetBlipColour(blipMissione, colore or 5)
    SetBlipScale(blipMissione, 0.9)
    SetBlipRoute(blipMissione, true)
    SetBlipRouteColour(blipMissione, colore or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(etichetta)
    EndTextCommandSetBlipName(blipMissione)
end

-- ---------------------------------------------------------------------------
--  Corriere
-- ---------------------------------------------------------------------------
AddEventHandler('lav:avviaConsegna', function()
    CreateThread(function()
        if missione then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Incarico già attivo', testo = 'Completa quello in corso.' })
        end

        local coord = GetEntityCoords(PlayerPedId())
        local dati, errore = AUREA.Callback.Attendi('lav:iniziaMissione', 'consegna', 1500)
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Incarico non assegnato', testo = errore or 'Riprova.' })
        end

        local caricato = exports.aurea_ui:Progresso({
            etichetta = 'Carico del pacco sul mezzo...',
            durata = 5000, annullabile = true,
            anim = { dizionario = 'anim@heists@box_carry@', nome = 'idle' },
            blocca = { movimento = true },
        })
        if not caricato then
            AUREA.Callback.Attendi('lav:annullaMissione')
            return
        end

        missione = { tipo = 'consegna', dati = dati, inizio = GetGameTimer() }
        segnaDestinazione(dati.coord, ('Consegna · %s'):format(dati.nome), 5)

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '📦', durata = 11000,
            titolo = ('Consegna a %s'):format(dati.nome),
            testo = ('Compenso %s. Hai %d minuti per il bonus puntualità.'):format(
                U.Euro(dati.compenso), math.ceil(dati.secondi / 60)),
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Tassista
-- ---------------------------------------------------------------------------
AddEventHandler('lav:avviaCorsa', function()
    CreateThread(function()
        if missione then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Corsa già attiva', testo = 'Completa quella in corso.' })
        end

        local dati, errore = AUREA.Callback.Attendi('lav:iniziaMissione', 'taxi', 2000)
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuna corsa', testo = errore or 'Riprova fra poco.' })
        end

        missione = { tipo = 'taxi', dati = dati, fase = 'raccolta' }
        segnaDestinazione(dati.partenza.coord, ('Cliente · %s'):format(dati.partenza.nome), 3)

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🚕', durata = 11000,
            titolo = 'Corsa assegnata',
            testo = ('Cliente a %s, destinazione %s. Tariffa stimata %s per %.1f km.'):format(
                dati.partenza.nome, dati.arrivo.nome, U.Euro(dati.compenso), dati.km),
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Ciclo della missione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000

        if missione then
            attesa = 300
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)

            if missione.tipo == 'consegna' then
                local d = #(coord - vector3(missione.dati.coord.x, missione.dati.coord.y, missione.dati.coord.z))

                if d < 30.0 then
                    DrawMarker(1, missione.dati.coord.x, missione.dati.coord.y, missione.dati.coord.z - 0.9,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.9, 31, 157, 85, 110, false, false, 2, false, nil, nil, false)
                end

                if d < 3.0 then
                    exports.aurea_ui:Prompt(true, 'Consegna il pacco', 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        concludiConsegna()
                    end
                end

            elseif missione.tipo == 'taxi' then
                if missione.fase == 'raccolta' then
                    local p = missione.dati.partenza.coord
                    local d = #(coord - vector3(p.x, p.y, p.z))

                    if d < 30.0 then
                        DrawMarker(1, p.x, p.y, p.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            2.2, 2.2, 0.9, 61, 138, 253, 110, false, false, 2, false, nil, nil, false)
                    end

                    if d < 6.0 then
                        local veicolo = GetVehiclePedIsIn(ped, false)
                        if veicolo ~= 0 then
                            exports.aurea_ui:Prompt(true, 'Fai salire il cliente', 'E')
                            if IsControlJustReleased(0, 38) then
                                exports.aurea_ui:Prompt(false)
                                caricaPasseggero(veicolo, p)
                            end
                        else
                            exports.aurea_ui:Prompt(true, 'Serve il taxi per caricare il cliente', 'E')
                        end
                    end

                elseif missione.fase == 'trasporto' then
                    local a = missione.dati.arrivo.coord
                    local d = #(coord - vector3(a.x, a.y, a.z))

                    if d < 30.0 then
                        DrawMarker(1, a.x, a.y, a.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            2.6, 2.6, 0.9, 31, 157, 85, 110, false, false, 2, false, nil, nil, false)
                    end

                    if d < 6.0 and GetEntitySpeed(GetVehiclePedIsIn(ped, false)) < 1.0 then
                        exports.aurea_ui:Prompt(true, 'Fai scendere il cliente', 'E')
                        if IsControlJustReleased(0, 38) then
                            exports.aurea_ui:Prompt(false)
                            concludiCorsa()
                        end
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

function concludiConsegna()
    CreateThread(function()
        local scaricato = exports.aurea_ui:Progresso({
            etichetta = 'Consegna del pacco...',
            durata = 4500, annullabile = true,
            anim = { dizionario = 'anim@heists@box_carry@', nome = 'idle' },
            blocca = { movimento = true },
        })
        if not scaricato then return end

        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)
        local danni = veicolo ~= 0 and (1000 - GetVehicleBodyHealth(veicolo)) or 0

        local ok, messaggio = AUREA.Callback.Attendi('lav:concludiMissione', danni)
        pulisci()

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📦', titolo = ok and 'Consegna completata' or 'Consegna non registrata',
            testo = messaggio, durata = 9000,
        })
    end)
end

function caricaPasseggero(veicolo, coord)
    CreateThread(function()
        local modelli = { `a_m_y_business_01`, `a_f_y_business_02`, `a_m_m_business_01`, `a_f_m_business_02`, `a_m_y_hipster_01` }
        local hash = modelli[math.random(#modelli)]
        RequestModel(hash)
        local scadenza = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end
        if not HasModelLoaded(hash) then return end

        passeggero = CreatePed(4, hash, coord.x, coord.y, coord.z, 0.0, false, true)
        SetModelAsNoLongerNeeded(hash)
        SetEntityInvincible(passeggero, true)
        SetBlockingOfNonTemporaryEvents(passeggero, true)

        local posti = GetVehicleMaxNumberOfPassengers(veicolo)
        TaskEnterVehicle(passeggero, veicolo, 12000, posti > 1 and 2 or 0, 1.5, 1, 0)

        missione.fase = 'trasporto'
        segnaDestinazione(missione.dati.arrivo.coord, ('Destinazione · %s'):format(missione.dati.arrivo.nome), 2)

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🚕',
            titolo = 'Cliente a bordo',
            testo = ('Destinazione: %s. Guida con prudenza.'):format(missione.dati.arrivo.nome),
        })
    end)
end

function concludiCorsa()
    CreateThread(function()
        if passeggero and DoesEntityExist(passeggero) then
            TaskLeaveVehicle(passeggero, GetVehiclePedIsIn(PlayerPedId(), false), 0)
            Wait(2200)
            TaskWanderStandard(passeggero, 10.0, 10)
            SetPedAsNoLongerNeeded(passeggero)
            passeggero = nil
        end

        local ok, messaggio = AUREA.Callback.Attendi('lav:concludiMissione', 0)
        pulisci()

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🚕', titolo = ok and 'Corsa conclusa' or 'Corsa non registrata',
            testo = messaggio, durata = 9000,
        })
    end)
end

AddEventHandler('lav:chiudiTurno', function()
    CreateThread(function()
        if missione then AUREA.Callback.Attendi('lav:annullaMissione') end
        pulisci()

        local netId = LocalPlayer.state.mezzoServizio
        if netId then
            local veicolo = NetToVeh(netId)
            if veicolo ~= 0 and DoesEntityExist(veicolo) then DeleteEntity(veicolo) end
            LocalPlayer.state:set('mezzoServizio', nil, false)
        end

        exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏁', titolo = 'Turno chiuso', testo = 'Buon riposo.' })
    end)
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then pulisci() end
end)
