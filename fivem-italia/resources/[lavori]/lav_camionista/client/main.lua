--[[
    AUREA · Camionista (client)
]]

local U = AUREA.Util
local viaggio = nil     -- { blip, integrita, motrice, rimorchio }
local ultimaVelocita = 0.0

CreateThread(function()
    local d = CAM.Deposito
    local b = AddBlipForCoord(d.coord.x, d.coord.y, d.coord.z)
    SetBlipSprite(b, d.blip.sprite)
    SetBlipColour(b, d.blip.colore)
    SetBlipScale(b, d.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(d.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('camionista', d.coord, 4.0, {
        { etichetta = 'Bolle di trasporto', icona = '🚛',
          lavoro = CAM.Lavoro, azione = function() apri() end },
    })
end)

function apri()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('cam:destinazioni')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Deposito', testo = errore })
        end

        local voci = {
            { id = '_l', icona = '📊',
              titolo = ('Livello %d · %d viaggi'):format(dati.livello, dati.viaggi),
              descrizione = ('Ancora %d viaggi per il livello successivo.'):format(dati.prossimo),
              disattivata = true },
            { id = 'mezzo', icona = '🚚', titolo = 'Prendi motrice e rimorchio' },
        }

        for _, d in ipairs(dati.destinazioni) do
            voci[#voci + 1] = {
                id = d.id, icona = '📍', titolo = d.nome,
                descrizione = d.aperta and ('Difficoltà %d'):format(d.difficolta)
                    or ('Serve il livello %d'):format(d.difficolta),
                valore = U.Euro(d.paga),
                disattivata = not d.aperta,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = CAM.Deposito.nome,
            sottotitolo = 'La paga scala con l\'integrità del carico all\'arrivo',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'mezzo' then return prendiMezzo(dati) end
        parti(scelta)
    end)
end

function prendiMezzo(dati)
    CreateThread(function()
        local posto = dati.mezzi[math.random(#dati.mezzi)]
        local hash = GetHashKey(dati.motrice)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local motrice = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
        SetVehicleNumberPlateText(motrice, 'TRASP')
        SetModelAsNoLongerNeeded(hash)

        local rimorchioPosto = dati.rimorchi[1]
        local hashR = GetHashKey(dati.rimorchio)
        RequestModel(hashR)
        n = 0
        while not HasModelLoaded(hashR) and n < 150 do Wait(20) n = n + 1 end

        if HasModelLoaded(hashR) then
            local rimorchio = CreateVehicle(hashR, rimorchioPosto.x, rimorchioPosto.y,
                rimorchioPosto.z, rimorchioPosto.w, true, false)
            SetModelAsNoLongerNeeded(hashR)
            AttachVehicleToTrailer(motrice, rimorchio, 1.0)
        end

        TaskWarpPedIntoVehicle(PlayerPedId(), motrice, -1)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚚', titolo = 'Mezzo pronto',
            testo = 'Scegli una destinazione e parti.', durata = 10000,
        })
    end)
end

function parti(id)
    CreateThread(function()
        local ok, dati = AUREA.Callback.Attendi('cam:parti', id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚛', titolo = 'Bolla', testo = tostring(dati), durata = 11000,
            })
        end

        if viaggio and viaggio.blip then RemoveBlip(viaggio.blip) end

        local blip = AddBlipForCoord(dati.coord.x, dati.coord.y, dati.coord.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 5)
        SetBlipRoute(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(dati.nome)
        EndTextCommandSetBlipName(blip)

        viaggio = { blip = blip, integrita = 100, soglia = dati.soglia,
                    destinazione = vector3(dati.coord.x, dati.coord.y, dati.coord.z) }

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🚛', durata = 15000,
            titolo = ('Bolla per %s'):format(dati.nome),
            testo = ('Paga %s a carico integro. Guida piano: urti e frenate brusche rovinano la merce.')
                :format(U.Euro(dati.paga)),
        })
    end)
end

--- Sorveglianza della guida: urti e frenate contano.
CreateThread(function()
    while true do
        local attesa = 700

        if viaggio then
            attesa = 250
            local ped = PlayerPedId()
            local v = GetVehiclePedIsIn(ped, false)

            if v ~= 0 then
                local kmh = GetEntitySpeed(v) * 3.6

                if HasEntityCollidedWithAnything(v) then
                    TriggerServerEvent('cam:danneggia', 'urto')
                    Wait(2500)
                elseif ultimaVelocita - kmh > 28 then
                    -- Frenata brusca: il carico si sposta
                    TriggerServerEvent('cam:danneggia', 'frenata')
                    Wait(1800)
                end
                ultimaVelocita = kmh

                local coord = GetEntityCoords(v)
                AUREA.Testo3D(coord.x, coord.y, coord.z + 2.4,
                    ('CARICO %d%%  ·  soglia %d%%'):format(viaggio.integrita, viaggio.soglia), 0.4)

                if #(coord - viaggio.destinazione) < 30.0 then
                    exports.aurea_ui:Prompt(true, 'Consegna il carico', 'G')
                    if IsControlJustReleased(0, 47) then
                        exports.aurea_ui:Prompt(false)
                        consegna()
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('cam:integrita', function(valore)
    if not viaggio then return end
    viaggio.integrita = valore

    if valore < viaggio.soglia then
        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '📦', durata = 9000,
            titolo = 'Il carico è compromesso',
            testo = ('Integrità al %d%%: sotto il %d%% te lo rifiutano.'):format(valore, viaggio.soglia),
        })
    end
end)

function consegna()
    CreateThread(function()
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Scarico della merce...', durata = 14000, annullabile = true,
            blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('cam:consegna')

        if viaggio and viaggio.blip then RemoveBlip(viaggio.blip) end
        viaggio = nil

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚛',
            titolo = ok and 'Consegna accettata' or 'Consegna rifiutata',
            testo = messaggio, durata = 15000,
        })
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and viaggio and viaggio.blip then RemoveBlip(viaggio.blip) end
end)
