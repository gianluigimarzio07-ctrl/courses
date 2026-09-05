--[[
    AUREA · Autolavaggio (client)

    Lo sporco lo tiene il client perché è una proprietà del veicolo in
    scena, non del personaggio: il server incassa e basta.
]]

local sporco = 0.0
local ultimoConteggio = GetGameTimer()

CreateThread(function()
    for _, i in ipairs(LAV.Impianti) do
        local b = AddBlipForCoord(i.coord.x, i.coord.y, i.coord.z)
        SetBlipSprite(b, 100)
        SetBlipColour(b, 3)
        SetBlipScale(b, 0.6)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(i.nome)
        EndTextCommandSetBlipName(b)
    end
end)

--- Guidare sporca. Il fango si accumula sul veicolo su cui si sta.
CreateThread(function()
    while true do
        Wait(20000)
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(v, -1) == ped and GetEntitySpeed(v) > 3.0 then
                sporco = math.min(LAV.Lavaggio.massimo, sporco + LAV.Lavaggio.sporcoAlMinuto / 3)
                SetVehicleDirtLevel(v, sporco)
            end
        end
    end
end)

CreateThread(function()
    while true do
        local attesa = 1200
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local coord = GetEntityCoords(ped)
            local impianto = LAV.ImpiantoVicino(coord)

            if impianto then
                attesa = 0
                exports.aurea_ui:Prompt(true,
                    ('%s — %s'):format(impianto.nome, AUREA.Util.Euro(impianto.prezzo)), 'E')

                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    lava()
                end
            end
        end

        Wait(attesa)
    end
end)

function lava()
    CreateThread(function()
        local ok, esito = AUREA.Callback.Attendi('lav:lava')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚿', titolo = 'Autolavaggio',
                testo = tostring(esito), durata = 9000,
            })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Lavaggio in corso...', durata = esito, annullabile = false,
        })
        if not completato then return end

        local v = GetVehiclePedIsIn(PlayerPedId(), false)
        if v ~= 0 then
            sporco = 0.0
            SetVehicleDirtLevel(v, 0.0)
            WashDecalsFromVehicle(v, 1.0)
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '✨', titolo = 'Come nuovo',
            testo = 'Il mezzo è pulito.', durata = 8000,
        })
    end)
end
