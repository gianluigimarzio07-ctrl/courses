--[[
    AUREA · UI client

    Export disponibili a tutte le risorse:
        exports.aurea_ui:Notifica({ tipo, titolo, testo, durata })
        exports.aurea_ui:Prompt(true, 'Apri il negozio', 'E')
        exports.aurea_ui:Progresso({ etichetta, durata, annullabile, anim, blocca })  -> boolean
        exports.aurea_ui:Menu({ titolo, sottotitolo, voci })                          -> id scelto | nil
        exports.aurea_ui:Dialogo('Titolo', { campi })                                 -> tabella valori | nil
        exports.aurea_ui:ChiudiMenu()
]]

local menuAperto, menuRisposta = false, nil
local dialogoAperto, dialogoRisposta = false, nil
local progressoInCorso, progressoAnnullato = false, false

-- ---------------------------------------------------------------------------
--  Notifiche
-- ---------------------------------------------------------------------------
local function Notifica(dati)
    if type(dati) == 'string' then dati = { testo = dati } end
    SendNUIMessage({
        azione = 'notifica',
        tipo = dati.tipo or 'info',
        titolo = dati.titolo,
        testo = dati.testo,
        durata = dati.durata or 5000,
        icona = dati.icona,
    })
end

exports('Notifica', Notifica)
RegisterNetEvent('aurea:ui:notifica', Notifica)
AddEventHandler('aurea:ui:notifica', function() end)  -- consente anche TriggerEvent locale

-- ---------------------------------------------------------------------------
--  Prompt di interazione
-- ---------------------------------------------------------------------------
local promptVisibile = false

local function Prompt(attivo, testo, tasto)
    if attivo == promptVisibile and not attivo then return end
    promptVisibile = attivo and true or false
    SendNUIMessage({ azione = 'prompt', attivo = promptVisibile, testo = testo, tasto = tasto })
end

exports('Prompt', Prompt)

-- ---------------------------------------------------------------------------
--  Barra di avanzamento
-- ---------------------------------------------------------------------------

--- Esegue un'azione a tempo. Bloccante: restituisce true se completata.
---@param opzioni table { etichetta, durata (ms), annullabile, anim = {dizionario, nome, flag}, blocca = {movimento, veicolo, mira} }
local function Progresso(opzioni)
    if progressoInCorso then return false end
    progressoInCorso = true
    progressoAnnullato = false

    local durata = opzioni.durata or 3000
    local ped = PlayerPedId()

    SendNUIMessage({
        azione = 'progresso', attivo = true,
        etichetta = opzioni.etichetta or 'Attendere...',
        durata = durata,
        annullabile = opzioni.annullabile ~= false,
    })

    if opzioni.anim then
        AUREA.Anima(opzioni.anim.dizionario, opzioni.anim.nome, durata, opzioni.anim.flag or 49)
    end

    local scadenza = GetGameTimer() + durata
    local tempoAnnulla = 0

    while GetGameTimer() < scadenza do
        Wait(0)

        local blocca = opzioni.blocca or {}
        if blocca.movimento then
            DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true) DisableControlAction(0, 22, true)
        end
        if blocca.veicolo then
            DisableControlAction(0, 71, true) DisableControlAction(0, 72, true)
            DisableControlAction(0, 63, true) DisableControlAction(0, 64, true)
        end
        if blocca.mira then
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 257, true) DisableControlAction(0, 263, true)
        end

        -- X tenuto premuto per 400 ms annulla
        if opzioni.annullabile ~= false then
            if IsControlPressed(0, 73) then
                tempoAnnulla = tempoAnnulla + GetFrameTime() * 1000
                if tempoAnnulla >= 400 then
                    progressoAnnullato = true
                    break
                end
            else
                tempoAnnulla = 0
            end
        end

        -- se il ped muore o entra in acqua l'azione salta
        if IsEntityDead(ped) then
            progressoAnnullato = true
            break
        end
    end

    SendNUIMessage({ azione = 'progresso', attivo = false })
    if opzioni.anim then ClearPedTasks(ped) end
    progressoInCorso = false

    return not progressoAnnullato
end

exports('Progresso', Progresso)

-- ---------------------------------------------------------------------------
--  Menu contestuale
-- ---------------------------------------------------------------------------

--- Apre un menu e attende la scelta. Restituisce l'id della voce o nil.
local function Menu(opzioni)
    if menuAperto then return nil end
    menuAperto = true
    menuRisposta = nil

    SetNuiFocus(true, true)
    SendNUIMessage({
        azione = 'menu',
        titolo = opzioni.titolo,
        sottotitolo = opzioni.sottotitolo,
        voci = opzioni.voci or {},
    })

    while menuAperto do Wait(0) end
    return menuRisposta
end

exports('Menu', Menu)

local function ChiudiMenu()
    if not menuAperto then return end
    menuAperto = false
    menuRisposta = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ azione = 'chiudiMenu' })
end

exports('ChiudiMenu', ChiudiMenu)

RegisterNUICallback('menuScelta', function(dati, cb)
    menuRisposta = dati.id
    menuAperto = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('menuChiuso', function(_, cb)
    menuRisposta = nil
    menuAperto = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
--  Dialogo di input
-- ---------------------------------------------------------------------------

--- Apre un form. Restituisce un array di valori nell'ordine dei campi, o nil.
---@param titolo string
---@param campi table[] { etichetta, tipo, segnaposto, valore, opzioni, obbligatorio }
local function Dialogo(titolo, campi)
    if dialogoAperto then return nil end
    dialogoAperto = true
    dialogoRisposta = nil

    SetNuiFocus(true, true)
    SendNUIMessage({ azione = 'dialogo', titolo = titolo, campi = campi })

    while dialogoAperto do Wait(0) end
    return dialogoRisposta
end

exports('Dialogo', Dialogo)

RegisterNUICallback('dialogoRisposta', function(dati, cb)
    dialogoRisposta = dati.valori
    dialogoAperto = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ---------------------------------------------------------------------------
--  Pulizia in caso di riavvio della risorsa
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

-- Se il giocatore muore mentre un menu è aperto, lo si chiude
CreateThread(function()
    while true do
        Wait(500)
        if (menuAperto or dialogoAperto) and IsEntityDead(PlayerPedId()) then
            ChiudiMenu()
            dialogoAperto = false
            SetNuiFocus(false, false)
        end
    end
end)
