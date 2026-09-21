--[[
    AUREA · Rimozione e depositeria (client)

    Due punti: la strada, dove si aggancia, e il piazzale, dove si
    riscatta. In mezzo c'è un contatore che gira e che nessuno vede
    girare — e infatti quando lo si guarda è sempre più alto di quanto
    ci si aspettava.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Agganciare
-- ---------------------------------------------------------------------------
local function rimuovi()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)

        local veicolo = GetClosestVehicle(coord.x, coord.y, coord.z,
            CAR.Mezzo.distanzaAggancio, 0, 71)
        if veicolo == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚛',
                titolo = 'Rimozione', testo = 'Non c\'è nessun veicolo abbastanza vicino.' })
        end

        local targa = (GetVehicleNumberPlateText(veicolo) or ''):gsub('%s+$', '')

        local voci = {}
        for _, m in ipairs(CAR.Motivi) do
            voci[#voci + 1] = {
                id = m.id, icona = '🚫', titolo = m.nome,
                descrizione = ('%s\nAl verbale si aggiunge la rimozione.'):format(m.descrizione),
            }
        end

        local motivo = exports.aurea_ui:Menu({
            titolo = ('Rimozione forzata — %s'):format(targa),
            sottotitolo = 'Art. 159 CdS: la rimozione non sostituisce la sanzione',
            voci = voci,
        })
        if not motivo then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Aggancio e caricamento',
            durata = 22000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('car:rimuovi', targa, motivo)
        if ok then
            -- Il veicolo sparisce dalla strada: adesso sta in depositeria
            if DoesEntityExist(veicolo) then
                SetEntityAsMissionEntity(veicolo, true, true)
                DeleteVehicle(veicolo)
            end
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚛',
            titolo = 'Rimozione', testo = tostring(messaggio), durata = 18000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Il piazzale
-- ---------------------------------------------------------------------------
local function piazzale()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('car:deposito')
        if not s then return end

        local voci = {}

        for _, r in ipairs(s.miei) do
            voci[#voci + 1] = {
                id = tostring(r.id), icona = '🚗',
                titolo = ('%s — %s'):format(r.targa, U.Euro(r.dovuto)),
                descrizione = ('%s\nRimozione %s + custodia %s per %d giorni.\nMancano %d giorni all\'alienazione.')
                    :format(r.motivo, U.Euro(r.costo_rimozione), U.Euro(r.custodia),
                            r.giorni, r.giorniAllAlienazione),
            }
        end

        if #s.miei == 0 then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '✅',
                titolo = 'Non hai veicoli in custodia',
                descrizione = 'Che è il modo più economico di stare in depositeria.' }
        end

        for _, r in ipairs(s.piazzale) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📋',
                titolo = ('%s — %s'):format(r.targa, r.intestatario or 'intestatario ignoto'),
                descrizione = ('%s · %d giorni · %s'):format(r.motivo, r.giorni, U.Euro(r.dovuto)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = CAR.Deposito.nome,
            sottotitolo = s.operatore and 'Piazzale e riscatti' or 'Riscatto dei veicoli rimossi',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Pratica di riscatto',
            durata = 10000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('car:riscatta', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚛',
            titolo = 'Depositeria', testo = tostring(messaggio), durata = 20000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Il carro attrezzi
-- ---------------------------------------------------------------------------
local function prendiMezzo()
    CreateThread(function()
        local modello = GetHashKey(CAR.Mezzo.modello)
        RequestModel(modello)
        local scadenza = GetGameTimer() + 8000
        while not HasModelLoaded(modello) and GetGameTimer() < scadenza do Wait(50) end
        if not HasModelLoaded(modello) then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚛',
                titolo = 'Rimessa', testo = 'Il mezzo non è disponibile adesso.' })
        end

        local p = CAR.Mezzo.spawn
        local v = CreateVehicle(modello, p.x, p.y, p.z, p.w, true, false)
        SetVehicleNumberPlateText(v, 'RIMOZ' .. math.random(10, 99))
        SetModelAsNoLongerNeeded(modello)
        TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)

        exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🚛',
            titolo = 'Carro attrezzi', testo = 'Mezzo in servizio. Usa /rimuovi accanto al veicolo.' })
    end)
end

RegisterCommand('rimuovi', rimuovi, false)
RegisterCommand('depositeria', piazzale, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(CAR.Deposito.coord)
    SetBlipSprite(b, CAR.Deposito.blip.sprite)
    SetBlipColour(b, CAR.Deposito.blip.colore)
    SetBlipScale(b, CAR.Deposito.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Depositeria')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('car_sportello', CAR.Deposito.coord, CAR.Deposito.raggio, {
        { etichetta = 'Sportello della depositeria', icona = '🚛', azione = piazzale },
    })

    exports.aurea_target:AggiungiZona('car_rimessa', CAR.Deposito.ingresso, 2.6, {
        { etichetta = 'Prendi il carro attrezzi', icona = '🔧',
          lavoro = CAR.Lavoro, inServizio = true, azione = prendiMezzo },
    })
end)
