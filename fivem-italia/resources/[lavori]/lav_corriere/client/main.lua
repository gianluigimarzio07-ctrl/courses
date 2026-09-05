--[[
    AUREA · Corriere (client)
]]

local U = AUREA.Util
local giro = nil        -- { pacchi, indice, blip, pacco }
local occupato = false

CreateThread(function()
    local d = COR.Deposito
    local b = AddBlipForCoord(d.coord.x, d.coord.y, d.coord.z)
    SetBlipSprite(b, d.blip.sprite)
    SetBlipColour(b, d.blip.colore)
    SetBlipScale(b, d.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(d.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('corriere', d.coord, 5.0, {
        { etichetta = 'Carica un giro di consegne', icona = '📦',
          lavoro = COR.Lavoro, azione = function() carica() end },
    })
end)

function carica()
    CreateThread(function()
        local ok, dati = AUREA.Callback.Attendi('cor:carica')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📦', titolo = 'Deposito', testo = tostring(dati), durata = 11000,
            })
        end

        -- Il furgone
        local posto = dati.mezzi[math.random(#dati.mezzi)]
        local hash = GetHashKey(dati.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if HasModelLoaded(hash) then
            local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
            SetVehicleNumberPlateText(v, 'CORRIERE')
            SetModelAsNoLongerNeeded(hash)
            TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
        end

        giro = { pacchi = dati.pacchi, indice = 1 }
        segnaProssimo()

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '📦', durata = 14000,
            titolo = ('%d consegne caricate'):format(#dati.pacchi),
            testo = 'Scendi dal furgone davanti all\'indirizzo e porta il pacco a mano.',
        })
    end)
end

function segnaProssimo()
    if not giro then return end
    if giro.blip then RemoveBlip(giro.blip) end

    local p = giro.pacchi[giro.indice]
    if not p then return end

    giro.blip = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
    SetBlipSprite(giro.blip, 1)
    SetBlipColour(giro.blip, 5)
    SetBlipRoute(giro.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(p.indirizzo)
    EndTextCommandSetBlipName(giro.blip)
end

CreateThread(function()
    while true do
        local attesa = 900

        if giro and not occupato then
            local p = giro.pacchi[giro.indice]
            if p then
                local ped = PlayerPedId()
                local coord = GetEntityCoords(ped)
                local pos = vector3(p.coord.x, p.coord.y, p.coord.z)

                if #(coord - pos) < COR.Consegne.distanzaPorta and not IsPedInAnyVehicle(ped, false) then
                    attesa = 0
                    exports.aurea_ui:Prompt(true, ('Consegna a %s'):format(p.indirizzo), 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        consegna(p)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

function consegna(p)
    CreateThread(function()
        occupato = true

        -- Il pacco si porta in mano
        local ped = PlayerPedId()
        local modello = GetHashKey(COR.Consegne.prop)
        RequestModel(modello)
        local n = 0
        while not HasModelLoaded(modello) and n < 60 do Wait(20) n = n + 1 end

        local pacco = nil
        if HasModelLoaded(modello) then
            pacco = CreateObject(modello, GetEntityCoords(ped), true, true, false)
            AttachEntityToEntity(pacco, ped, GetPedBoneIndex(ped, 60309),
                0.05, 0.0, -0.15, 0.0, 270.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(modello)
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Consegna a %s...'):format(p.indirizzo),
            durata = COR.Consegne.durataConsegna, annullabile = true,
            anim = { dizionario = 'anim@heists@box_carry@', nome = 'idle' },
        })

        if pacco and DoesEntityExist(pacco) then DeleteObject(pacco) end
        occupato = false
        if not completato then return end

        -- Il destinatario è qui di persona?
        local diretta = false
        if p.destinatario then
            local coord = GetEntityCoords(PlayerPedId())
            for _, altro in ipairs(GetActivePlayers()) do
                local altroPed = GetPlayerPed(altro)
                if altroPed ~= PlayerPedId() and #(coord - GetEntityCoords(altroPed)) < 5.0 then
                    diretta = true
                    break
                end
            end
        end

        local ok, esito = AUREA.Callback.Attendi('cor:consegna', diretta)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📦', titolo = 'Consegna',
                testo = tostring(esito), durata = 10000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '📦', durata = 9000,
            titolo = ('%d di %d consegnati'):format(esito.consegnati, esito.totale),
            testo = ('%s%s'):format(U.Euro(esito.paga),
                esito.aMano and ' — consegnato a mano, bonus incluso' or ''),
        })

        if esito.finito then
            if giro and giro.blip then RemoveBlip(giro.blip) end
            giro = nil
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '✅', titolo = 'Giro completato',
                testo = 'Torna in deposito per un altro carico.', durata = 11000,
            })
        else
            giro.indice = giro.indice + 1
            segnaProssimo()
        end
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and giro and giro.blip then RemoveBlip(giro.blip) end
end)
