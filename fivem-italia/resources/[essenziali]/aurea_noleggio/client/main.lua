--[[
    AUREA · Autonoleggio (client)
]]

local U = AUREA.Util

CreateThread(function()
    for n, p in ipairs(NOL.Punti) do
        local b = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
        SetBlipSprite(b, NOL.Blip.sprite)
        SetBlipColour(b, NOL.Blip.colore)
        SetBlipScale(b, NOL.Blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(p.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('noleggio_' .. n, p.coord, 3.0, {
            { etichetta = 'Autonoleggio', icona = '🔑', azione = function() apri() end },
        })
    end
end)

function apri()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('nol:flotta')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Noleggio', testo = errore })
        end

        local voci = {}

        if dati.attivo then
            voci[#voci + 1] = {
                id = 'riconsegna', icona = '↩',
                titolo = ('Riconsegna %s (%s)'):format(dati.attivo.nome, dati.attivo.targa),
                descrizione = dati.attivo.scaduto
                    and 'Sei fuori orario: la penale si somma alla trattenuta.'
                    or ('Ti restano %d minuti.'):format(dati.attivo.minuti),
            }
        else
            for _, v in ipairs(dati.flotta) do
                voci[#voci + 1] = {
                    id = v.modello, icona = '🚗', titolo = v.nome,
                    descrizione = ('Cauzione %s, restituita se lo riporti intero.')
                        :format(U.Euro(v.cauzione)),
                    valore = ('%s/ora'):format(U.Euro(v.tariffaOraria)),
                }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = dati.punto,
            sottotitolo = 'Serve la patente B. Si paga dal conto corrente.',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'riconsegna' then return riconsegna() end

        local r = exports.aurea_ui:Dialogo('Per quante ore?', {
            { etichetta = ('Ore (da %d a %d)'):format(dati.regole.oreMinime, dati.regole.oreMassime),
              tipo = 'number', valore = 2,
              min = dati.regole.oreMinime, max = dati.regole.oreMassime, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, esito = AUREA.Callback.Attendi('nol:noleggia', scelta, r[1])
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔑', titolo = 'Noleggio',
                testo = tostring(esito), durata = 13000,
            })
        end

        local hash = GetHashKey(esito.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local v = CreateVehicle(hash, esito.spawn.x, esito.spawn.y, esito.spawn.z, esito.spawn.w, true, false)
        SetVehicleNumberPlateText(v, esito.targa)
        SetModelAsNoLongerNeeded(hash)
        TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🔑', titolo = 'Noleggio attivo',
            testo = esito.messaggio, durata = 15000,
        })
    end)
end

function riconsegna()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local v = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false)
            or GetClosestVehicle(coord.x, coord.y, coord.z, 10.0, 0, 71)

        local danni = 0.0
        if v and v ~= 0 and DoesEntityExist(v) then
            danni = 1.0 - (GetVehicleBodyHealth(v) / 1000.0)
        end

        local ok, messaggio = AUREA.Callback.Attendi('nol:riconsegna', danni)

        if ok and v and v ~= 0 and DoesEntityExist(v) then
            if GetVehiclePedIsIn(ped, false) == v then
                TaskLeaveVehicle(ped, v, 16)
                Wait(1500)
            end
            SetEntityAsMissionEntity(v, true, true)
            DeleteVehicle(v)
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🔑',
            titolo = 'Riconsegna', testo = messaggio, durata = 14000,
        })
    end)
end
