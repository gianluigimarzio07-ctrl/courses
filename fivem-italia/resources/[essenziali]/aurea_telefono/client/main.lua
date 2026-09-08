--[[
    AUREA · Telefono (client)

    Il client fa tre cose e nient'altro: apre e chiude lo schermo, inoltra
    le richieste della NUI al server, e disegna la chiamata in arrivo.

    Non sa quali app esistono, non sa cosa contengono e non decide chi può
    vederle. Riceve schermate già costruite e le passa alla NUI.
]]

local aperto = false
local chiamata = nil        -- { id, nome, numero, entrante, attiva }

-- ---------------------------------------------------------------------------
--  Apertura e chiusura
-- ---------------------------------------------------------------------------
local function puoUsarlo()
    if not AUREA.PG then return false, nil end

    if not exports.aurea_inventory:Ha(TEL.Oggetto, 1) then
        return false, 'Non hai uno smartphone con te.'
    end

    if TEL.Regole.vietatoDaIncoscienti and IsEntityDead(PlayerPedId()) then
        return false, nil
    end

    if TEL.Regole.vietatoDaAmmanettati then
        local ok, ammanettato = pcall(function()
            return exports.aurea_interazioni:SonoAmmanettato()
        end)
        if ok and ammanettato then return false, 'Con le manette ai polsi non ci arrivi.' end
    end

    return true
end

local function apri()
    if aperto then return end

    local ok, motivo = puoUsarlo()
    if not ok then
        if motivo then
            exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📱',
                titolo = 'Telefono', testo = motivo })
        end
        return
    end

    CreateThread(function()
        local dati = AUREA.Callback.Attendi('tel:apertura')
        if not dati then return end

        aperto = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            azione = 'apri',
            pg = dati.pg,
            app = dati.app,
            aspetto = dati.aspetto,
            ora = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        })

        AUREA.Anima(TEL.Regole.animazione.dizionario, TEL.Regole.animazione.nome, -1, 49)
    end)
end

local function chiudi()
    if not aperto then return end
    aperto = false
    SetNuiFocus(false, false)
    SendNUIMessage({ azione = 'chiudi' })

    -- L'animazione resta se si è in chiamata: il telefono è all'orecchio
    if not chiamata then ClearPedTasks(PlayerPedId()) end
end

RegisterCommand('telefono', function()
    if aperto then chiudi() else apri() end
end, false)
RegisterKeyMapping('telefono', 'Apri il telefono', 'keyboard', TEL.Tasto)

RegisterNetEvent('tel:apri', apri)

-- ---------------------------------------------------------------------------
--  Ponte con la NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('chiudi', function(_, cb)
    chiudi()
    cb({ ok = true })
end)

RegisterNUICallback('schermata', function(dati, cb)
    CreateThread(function()
        cb(AUREA.Callback.Attendi('tel:schermata', dati) or {})
    end)
end)

RegisterNUICallback('azione', function(dati, cb)
    CreateThread(function()
        local risposta = AUREA.Callback.Attendi('tel:azione', dati) or { ok = false }

        -- Un'app può chiedere di chiudere il telefono, di far partire un
        -- evento sul client o di riaprire tutto (cambio di tema)
        if risposta.chiudi then chiudi() end

        if risposta.eventoClient and risposta.eventoClient.nome then
            local nome, arg = risposta.eventoClient.nome, risposta.eventoClient.dati
            CreateThread(function()
                Wait(250)
                TriggerEvent(nome, arg)
            end)
        end

        if risposta.riapri then
            chiudi()
            Wait(120)
            apri()
        end

        cb(risposta)
    end)
end)

--- I dialoghi passano dal toolkit condiviso: così il focus della NUI resta
--- coerente e non ci si ritrova con due finestre che si contendono il
--- mouse.
RegisterNUICallback('dialogo', function(dati, cb)
    CreateThread(function()
        SetNuiFocus(false, false)
        local valori = exports.aurea_ui:Dialogo(dati.titolo, dati.campi)
        SetNuiFocus(true, true)
        cb({ valori = valori })
    end)
end)

-- ---------------------------------------------------------------------------
--  Chiamate
-- ---------------------------------------------------------------------------
RegisterNetEvent('tel:squillo', function(dati)
    chiamata = {
        id = dati.id, nome = dati.nome, numero = dati.numero,
        entrante = dati.entrante, attiva = false,
    }

    SendNUIMessage({ azione = 'chiamata', chiamata = chiamata })

    if dati.entrante then
        -- Lo schermo si accende da solo: una chiamata in arrivo si vede
        if not aperto then
            local ok = puoUsarlo()
            if ok then
                aperto = true
                SetNuiFocus(true, true)
                SendNUIMessage({ azione = 'soloChiamata' })
                AUREA.Anima(TEL.Regole.animazione.dizionario, TEL.Regole.animazione.nome, -1, 49)
            end
        end

        CreateThread(function()
            while chiamata and chiamata.entrante and not chiamata.attiva do
                PlaySoundFrontend(-1, 'Remote_Ring', 'Phone_SoundSet_Michael', true)
                Wait(2500)
            end
        end)
    end
end)

RegisterNetEvent('tel:chiamataAttiva', function(id)
    if not chiamata or chiamata.id ~= id then return end
    chiamata.attiva = true
    SendNUIMessage({ azione = 'chiamataAttiva' })

    AUREA.Anima('cellphone@', 'cellphone_call_listen_base', -1, 49)
end)

RegisterNetEvent('tel:chiamataChiusa', function(esito)
    chiamata = nil
    SendNUIMessage({ azione = 'chiamataChiusa' })
    ClearPedTasks(PlayerPedId())

    if esito == 'persa' then
        exports.aurea_ui:Notifica({ tipo = 'avviso', icona = '📞',
            titolo = 'Chiamata persa', durata = 7000 })
    elseif esito == 'rifiutata' then
        exports.aurea_ui:Notifica({ tipo = 'info', icona = '📞',
            titolo = 'Chiamata rifiutata', durata = 6000 })
    end
end)

RegisterNUICallback('rispondiChiamata', function(dati, cb)
    if chiamata then
        TriggerServerEvent('tel:rispondi', chiamata.id, dati.accetta == true)
    end
    cb({ ok = true })
end)

RegisterNUICallback('riaggancia', function(_, cb)
    if chiamata then TriggerServerEvent('tel:riaggancia', chiamata.id) end
    cb({ ok = true })
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

    if aperto then
        CreateThread(function()
            SendNUIMessage({ azione = 'badge', badge = AUREA.Callback.Attendi('tel:badge') or {} })
        end)
    end
end)

RegisterNetEvent('tel:notifica', function(dati)
    exports.aurea_ui:Notifica({
        tipo = dati.tipo or 'info', icona = dati.icona or '📱',
        titolo = dati.titolo, testo = dati.testo, durata = dati.durata or 9000,
    })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

-- ---------------------------------------------------------------------------
--  Tabulati, per la polizia giudiziaria
-- ---------------------------------------------------------------------------
RegisterNetEvent('tel:apriTabulati', function(numero)
    CreateThread(function()
        local righe, motivo, intestatario = AUREA.Callback.Attendi('tel:tabulati', numero)
        if motivo then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📇',
                testo = motivo, durata = 11000 })
        end

        local voci = {}
        for _, r in ipairs(righe or {}) do
            local uscente = r.mittente == numero
            voci[#voci + 1] = {
                id = 'r',
                icona = uscente and '↗' or '↙',
                titolo = uscente and r.destinatario or r.mittente,
                descrizione = ('%s · %s · %d secondi')
                    :format(uscente and 'uscente' or 'entrante', r.esito, r.secondi or 0),
                disattivata = true,
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', icona = '📇', titolo = 'Nessun traffico nel periodo', disattivata = true }
        end

        exports.aurea_ui:Menu({
            titolo = ('Tabulati — %s'):format(numero),
            sottotitolo = intestatario and ('Intestatario: %s'):format(intestatario)
                or 'Numero non intestato in anagrafe',
            voci = voci,
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Manutenzione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(15000)
        if aperto then
            SendNUIMessage({ azione = 'ora',
                ora = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) })
        end
    end
end)

--- Il telefono si chiude da solo se si perde conoscenza.
CreateThread(function()
    while true do
        Wait(1000)
        if aperto and IsEntityDead(PlayerPedId()) then
            chiudi()
            if chiamata then
                TriggerServerEvent('tel:riaggancia', chiamata.id)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
