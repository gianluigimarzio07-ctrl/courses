--[[
    AUREA · Selezione personaggio (client)
    Gestisce camera, ped di anteprima e passaggio in gioco.
]]

local camera = nil
local pedAnteprima = nil
local inSelezione = false

-- Set cinematografico: terrazza panoramica su Los Santos
local SET = {
    ped    = vector4(-1035.0, -2735.0, 20.2, 150.0),
    camera = vector3(-1032.4, -2732.3, 21.4),
}

local STAGIONI = {
    [12] = 'Inverno', [1] = 'Inverno', [2] = 'Inverno',
    [3] = 'Primavera', [4] = 'Primavera', [5] = 'Primavera',
    [6] = 'Estate', [7] = 'Estate', [8] = 'Estate',
    [9] = 'Autunno', [10] = 'Autunno', [11] = 'Autunno',
}

-- ---------------------------------------------------------------------------
--  Scena
-- ---------------------------------------------------------------------------
local function preparaScena()
    local ped = PlayerPedId()

    SetEntityCoords(ped, SET.ped.x, SET.ped.y, SET.ped.z, false, false, false, false)
    SetEntityHeading(ped, SET.ped.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)

    if not camera then
        camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
            SET.camera.x, SET.camera.y, SET.camera.z, 0.0, 0.0, 150.0, 42.0, false, 0)
        SetCamActive(camera, true)
        RenderScriptCams(true, false, 1, true, true)
    end

    -- Mattino sereno: la scena deve restare leggibile
    NetworkOverrideClockTime(9, 15, 0)
    SetWeatherTypeNowPersist('EXTRASUNNY')

    DoScreenFadeIn(600)
    DisplayRadar(false)
    TriggerEvent('aurea:hud:mostra', false)
end

local function chiudiScena()
    if camera then
        RenderScriptCams(false, true, 900, true, true)
        DestroyCam(camera, false)
        camera = nil
    end
    if pedAnteprima and DoesEntityExist(pedAnteprima) then
        DeleteEntity(pedAnteprima)
        pedAnteprima = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)

    NetworkClearClockTimeOverride()
    SetNuiFocus(false, false)
    inSelezione = false
    DisplayRadar(true)
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
local function apriSelezione()
    inSelezione = true
    DoScreenFadeOut(0)
    Wait(500)

    preparaScena()

    local dati = AUREA.Callback.Attendi('core:personaggi')
    SetNuiFocus(true, true)
    SendNUIMessage({
        azione = 'apri',
        personaggi = dati.personaggi or {},
        slot = dati.slot or 2,
        stagione = ('%s · %s'):format(STAGIONI[tonumber(os.date('%m'))] or '', os.date('%d/%m/%Y')),
    })
end

AddEventHandler('playerSpawned', function()
    if inSelezione or AUREA.Caricato then return end
    CreateThread(apriSelezione)
end)

CreateThread(function()
    -- Se lo spawnmanager non emette playerSpawned, si parte comunque
    Wait(2500)
    if not inSelezione and not AUREA.Caricato then apriSelezione() end
end)

-- ---------------------------------------------------------------------------
--  Callback NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('ricarica', function(_, cb)
    local dati = AUREA.Callback.Attendi('core:personaggi')
    cb({ personaggi = dati.personaggi or {}, slot = dati.slot or 2 })
end)

RegisterNUICallback('crea', function(dati, cb)
    local risposta = AUREA.Callback.Attendi('core:creaPersonaggio', dati)
    cb(risposta or { ok = false, errore = 'Il server non ha risposto.' })

    if risposta and risposta.ok then
        Wait(200)
        CreateThread(function() entraInGioco(risposta.citizenid) end)
    end
end)

RegisterNUICallback('elimina', function(dati, cb)
    local ok = AUREA.Callback.Attendi('core:eliminaPersonaggio', dati.citizenid)
    cb({ ok = ok })
end)

RegisterNUICallback('seleziona', function(dati, cb)
    cb({ ok = true })
    CreateThread(function() entraInGioco(dati.citizenid) end)
end)

RegisterNUICallback('anteprimaCamera', function(_, cb)
    -- leggera zoomata sul volto durante la compilazione dei dati
    if camera then
        local nuova = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
            SET.camera.x, SET.camera.y, SET.camera.z + 0.25, 0.0, 0.0, 150.0, 34.0, false, 0)
        SetCamActiveWithInterp(nuova, camera, 900, 1, 1)
        Wait(950)
        DestroyCam(camera, false)
        camera = nuova
    end
    cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
--  Ingresso in gioco
-- ---------------------------------------------------------------------------
function entraInGioco(citizenid)
    SetNuiFocus(false, false)
    SendNUIMessage({ azione = 'chiudi' })
    DoScreenFadeOut(700)
    Wait(750)

    local risultato = AUREA.Callback.Attendi('core:selezionaPersonaggio', citizenid)
    if not risultato then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Caricamento fallito', testo = 'Riprova o riavvia il gioco.' })
        DoScreenFadeIn(500)
        return apriSelezione()
    end

    local pos = risultato.posizione
    local ped = PlayerPedId()

    -- Modello base in attesa dell'editor aspetto
    local modello = risultato.pacchetto.sesso == 'F' and `mp_f_freemode_01` or `mp_m_freemode_01`
    RequestModel(modello)
    local scadenza = GetGameTimer() + 6000
    while not HasModelLoaded(modello) and GetGameTimer() < scadenza do Wait(10) end
    if HasModelLoaded(modello) then
        SetPlayerModel(PlayerId(), modello)
        SetModelAsNoLongerNeeded(modello)
        ped = PlayerPedId()
        SetPedDefaultComponentVariation(ped)
    end

    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.h or 0.0)

    chiudiScena()

    -- Ripristina lo stato vitale dal salvataggio
    local stato = risultato.pacchetto.stato or {}
    SetEntityHealth(ped, math.max(101, math.floor(stato.salute or 200)))
    SetPedArmour(ped, math.floor(stato.armatura or 0))

    TriggerEvent('aurea:hud:mostra', true)
    TriggerEvent('aurea:spawn:completato', risultato.pacchetto)

    Wait(400)
    DoScreenFadeIn(900)

    exports.aurea_ui:Notifica({
        tipo = 'successo',
        titolo = ('Bentornato, %s'):format(risultato.pacchetto.nome),
        testo = ('Codice cittadino %s · %s'):format(risultato.pacchetto.citizenid, risultato.pacchetto.lavoroEtichetta),
        durata = 7000,
    })
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then chiudiScena() end
end)
