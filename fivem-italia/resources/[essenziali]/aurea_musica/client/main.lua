--[[
    AUREA · Musica (client)

    Il suono lo riproduce la NUI: qui si decide solo che volume dare in
    base alla distanza, e si tiene il prop dello stereo a terra.
]]

local attivi = {}       -- [id] = { coord, volume, prop }

local function distanzaVolume(s)
    local coord = GetEntityCoords(PlayerPedId())
    local pos = vector3(s.coord.x, s.coord.y, s.coord.z)

    -- Se è un'autoradio agganciata a un veicolo, si segue il veicolo
    if s.rete then
        local ent = NetworkGetEntityFromNetworkId(s.rete)
        if ent and ent ~= 0 and DoesEntityExist(ent) then pos = GetEntityCoords(ent) end
    end

    local d = #(coord - pos)
    local raggio = MUS.Sorgenti[s.tipo] and MUS.Sorgenti[s.tipo].raggio or 25.0
    if d > raggio then return 0.0 end

    -- Attenuazione lineare: al bordo si sente appena
    return (s.volume / 100) * (1.0 - (d / raggio))
end

CreateThread(function()
    while true do
        for id, s in pairs(attivi) do
            SendNUIMessage({ azione = 'volume', id = id, volume = distanzaVolume(s) })
        end
        Wait(700)
    end
end)

RegisterNetEvent('mus:accendi', function(s, trascorsi)
    attivi[s.id] = s

    SendNUIMessage({
        azione = 'riproduci', id = s.id, url = s.url,
        volume = distanzaVolume(s), da = trascorsi or s.trascorsi or 0,
    })

    if s.tipo == 'boombox' then creaProp(s) end
end)

RegisterNetEvent('mus:spegni', function(id)
    local s = attivi[id]
    if s and s.prop and DoesEntityExist(s.prop) then DeleteObject(s.prop) end
    attivi[id] = nil
    SendNUIMessage({ azione = 'ferma', id = id })
end)

RegisterNetEvent('mus:volume', function(id, volume)
    if attivi[id] then
        attivi[id].volume = volume
        SendNUIMessage({ azione = 'volume', id = id, volume = distanzaVolume(attivi[id]) })
    end
end)

function creaProp(s)
    local modello = GetHashKey(MUS.Sorgenti.boombox.modello)
    RequestModel(modello)
    local n = 0
    while not HasModelLoaded(modello) and n < 80 do Wait(20) n = n + 1 end
    if not HasModelLoaded(modello) then return end

    local p = CreateObject(modello, s.coord.x, s.coord.y, s.coord.z - 0.9, false, false, false)
    PlaceObjectOnGroundProperly(p)
    FreezeEntityPosition(p, true)
    SetModelAsNoLongerNeeded(modello)
    s.prop = p
end

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(5000)
        for _, s in ipairs(AUREA.Callback.Attendi('mus:attivi') or {}) do
            TriggerEvent('mus:accendi', s, s.trascorsi)
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
RegisterCommand('musica', function()
    CreateThread(function()
        local voci = {}
        for _, b in ipairs(MUS.Playlist) do
            voci[#voci + 1] = { id = 'p:' .. b.url, icona = '🎵', titolo = b.nome }
        end
        voci[#voci + 1] = { id = 'url', icona = '🔗', titolo = 'Incolla un collegamento',
                            descrizione = table.concat(MUS.DominiAmmessi, ', ') }
        voci[#voci + 1] = { id = 'volume', icona = '🔊', titolo = 'Cambia volume',
                            descrizione = 'Sullo stereo che stai già facendo suonare' }
        voci[#voci + 1] = { id = 'stop', icona = '⏹', titolo = 'Spegni il tuo stereo' }

        local ped = PlayerPedId()
        local inAuto = IsPedInAnyVehicle(ped, false)

        local scelta = exports.aurea_ui:Menu({
            titolo = inAuto and 'Autoradio' or 'Stereo portatile',
            sottotitolo = 'Si sente solo chi è nel raggio, e si sente da dove sei',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'volume' then
            local r = exports.aurea_ui:Dialogo('Volume', {
                { etichetta = 'Volume (0-100)', tipo = 'number',
                  valore = MUS.Regole.volumePredefinito,
                  min = 0, max = MUS.Regole.volumeMassimo, obbligatorio = true },
            })
            if not r or not r[1] then return end

            -- Non sappiamo quale stereo sia nostro: proviamo su quelli che
            -- sentiamo e il server rifiuta quelli di altri.
            for id in pairs(attivi) do
                if AUREA.Callback.Attendi('mus:volume', id, tonumber(r[1])) then
                    return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🔊',
                        titolo = 'Musica', testo = ('Volume portato a %s.'):format(math.floor(tonumber(r[1]) or 0)) })
                end
            end
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔊',
                titolo = 'Musica', testo = 'Non stai facendo suonare nessuno stereo qui.' })
        end

        if scelta == 'stop' then
            for id, s in pairs(attivi) do
                local ok, messaggio = AUREA.Callback.Attendi('mus:spegni', id)
                if ok then
                    return exports.aurea_ui:Notifica({ tipo = 'info', icona = '⏹',
                        titolo = 'Musica', testo = messaggio })
                end
            end
            return
        end

        local url = scelta:match('^p:(.+)$')
        local volume = MUS.Regole.volumePredefinito
        if scelta == 'url' then
            local r = exports.aurea_ui:Dialogo('Collegamento', {
                { etichetta = 'URL del brano', tipo = 'text',
                  segnaposto = 'https://www.youtube.com/watch?v=...', obbligatorio = true },
                { etichetta = 'Volume (0-100)', tipo = 'number',
                  valore = MUS.Regole.volumePredefinito, min = 0, max = MUS.Regole.volumeMassimo },
            })
            if not r or not r[1] then return end
            url = r[1]
            -- il volume chiesto qui va usato: prima veniva ignorato
            volume = tonumber(r[2]) or volume
        end
        if not url then return end

        local rete = nil
        if inAuto then
            local v = GetVehiclePedIsIn(ped, false)
            rete = VehToNet(v)
        end

        local ok, esito = AUREA.Callback.Attendi('mus:accendi', {
            url = url, tipo = inAuto and 'autoradio' or 'boombox',
            volume = volume, rete = rete,
        })

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎵',
            titolo = 'Musica',
            testo = ok and 'Sta suonando. Chi è vicino la sente.' or tostring(esito),
            durata = 11000,
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, s in pairs(attivi) do
        if s.prop and DoesEntityExist(s.prop) then DeleteObject(s.prop) end
    end
end)
