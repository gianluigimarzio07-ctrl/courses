--[[
    AUREA · Telefono (client)
]]

local aperto = false

local function apri()
    if aperto then return end
    if not AUREA.PG then return end
    if not exports.aurea_inventory:Ha('telefono', 1) then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📱', titolo = 'Nessun telefono', testo = 'Non hai uno smartphone con te.' })
    end
    if IsEntityDead(PlayerPedId()) then return end

    CreateThread(function()
        local dati = AUREA.Callback.Attendi('tel:apertura')
        if not dati then return end

        aperto = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            azione = 'apri',
            pg = dati.pg,
            badge = dati.badge,
            ora = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        })

        AUREA.Anima('cellphone@', 'cellphone_text_read_base', -1, 49)
    end)
end

local function chiudi()
    if not aperto then return end
    aperto = false
    SetNuiFocus(false, false)
    SendNUIMessage({ azione = 'chiudi' })
    ClearPedTasks(PlayerPedId())
end

RegisterCommand('telefono', function()
    if aperto then chiudi() else apri() end
end, false)
RegisterKeyMapping('telefono', 'Apri il telefono', 'keyboard', 'F1')

RegisterNetEvent('tel:apri', apri)

-- ---------------------------------------------------------------------------
--  Callback NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('chiudi', function(_, cb)
    chiudi()
    cb({ ok = true })
end)

local function inoltra(nome, endpoint)
    RegisterNUICallback(endpoint, function(dati, cb)
        local risposta = AUREA.Callback.Attendi(nome, dati)
        cb(risposta or {})
    end)
end

inoltra('tel:contatti', 'contatti')
inoltra('tel:salvaContatto', 'salvaContatto')
inoltra('tel:conversazioni', 'conversazioni')
inoltra('tel:messaggi', 'messaggi')
inoltra('tel:inviaMessaggio', 'inviaMessaggio')
inoltra('tel:banca', 'banca')
inoltra('tel:fisco', 'fisco')
inoltra('tel:annunci', 'annunci')
inoltra('tel:pubblicaAnnuncio', 'pubblicaAnnuncio')

--- Il telefono usa i dialoghi del toolkit condiviso: il focus resta coerente.
RegisterNUICallback('dialogo', function(dati, cb)
    CreateThread(function()
        SetNuiFocus(false, false)
        local valori = exports.aurea_ui:Dialogo(dati.titolo, dati.campi)
        SetNuiFocus(true, true)
        cb({ valori = valori })
    end)
end)

RegisterNUICallback('chiamaEmergenza', function(dati, cb)
    cb({ ok = true })
    chiudi()

    CreateThread(function()
        Wait(300)
        if dati.numero == '112' then
            TriggerEvent('nue:apriChiamata')
        else
            -- gli altri numeri arrivano comunque alla centrale unica,
            -- con l'ente già preselezionato
            TriggerEvent('nue:apriChiamata')
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Notifiche in arrivo
-- ---------------------------------------------------------------------------
RegisterNetEvent('tel:messaggioRicevuto', function(mittente, testo)
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '💬', durata = 9000,
        titolo = ('Messaggio da %s'):format(mittente),
        testo = testo,
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

RegisterNetEvent('tel:badge', function(badge)
    SendNUIMessage({ azione = 'badge', badge = badge })
end)

-- Aggiornamento dell'orologio mentre il telefono è aperto
CreateThread(function()
    while true do
        Wait(15000)
        if aperto then
            SendNUIMessage({ azione = 'ora', ora = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) })
        end
    end
end)

-- Il telefono si chiude se si perde conoscenza
CreateThread(function()
    while true do
        Wait(1000)
        if aperto and IsEntityDead(PlayerPedId()) then chiudi() end
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
