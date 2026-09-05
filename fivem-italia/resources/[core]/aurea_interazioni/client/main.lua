--[[
    AUREA · Interazioni (client)
]]

local U = AUREA.Util
local ammanettato = false
local trascinatoDa = nil
local richiesta = nil

RegisterKeyMapping('interazioni', 'Menu interazioni', 'keyboard', INT.Tasto)

--- Le altre risorse chiedono qui se sono legato: serve al menu di pausa
--- per allungare l'attesa di uscita a chi sta scappando da una situazione.
exports('SonoAmmanettato', function() return ammanettato end)
exports('SonoTrascinato', function() return trascinatoDa ~= nil end)

RegisterCommand('interazioni', function()
    if ammanettato then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🔗', titolo = 'Hai le manette',
            testo = 'Con i polsi legati non puoi fare granché.',
        })
    end
    apri()
end, false)

function apri()
    CreateThread(function()
        local bersaglio = piuVicino(5.0)

        local voci = {}
        for _, a in ipairs(INT.SuDiSe) do
            voci[#voci + 1] = { id = 'io:' .. a.id, icona = a.icona, titolo = a.nome,
                                descrizione = a.descrizione }
        end

        if bersaglio then
            for _, a in ipairs(INT.SuAltri) do
                local ammesso = true
                if a.lavori and not AUREA.HaLavoro(table.unpack(a.lavori)) then ammesso = false end
                if a.inServizio and not AUREA.EInServizio() then ammesso = false end

                if ammesso then
                    voci[#voci + 1] = {
                        id = 'tu:' .. a.id, icona = a.icona, titolo = a.nome,
                        descrizione = a.richiedeConsenso and 'L\'altra persona può rifiutare.' or nil,
                    }
                end
            end
        else
            voci[#voci + 1] = { id = '_v', icona = '·', titolo = 'Nessuno vicino a te',
                                descrizione = 'Le azioni su altri richiedono qualcuno a portata.',
                                disattivata = true }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Interazioni', sottotitolo = 'Quello che si subisce si può rifiutare',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local su = scelta:match('^io:(.+)$')
        if su then return suDiSe(su) end

        local azione = scelta:match('^tu:(.+)$')
        if azione and bersaglio then
            local ok, messaggio = AUREA.Callback.Attendi('int:azione', azione, bersaglio)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🤝',
                titolo = 'Interazione', testo = messaggio, durata = 10000,
            })
        end
    end)
end

--- Le posture sono emote: si delegano alla risorsa che le conosce.
function suDiSe(id)
    exports.aurea_emote:Esegui(id)
end

function piuVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio
    for _, altro in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(altro)
        if p ~= ped then
            local d = #(coord - GetEntityCoords(p))
            if d < distanza then migliore, distanza = GetPlayerServerId(altro), d end
        end
    end
    return migliore
end

-- ---------------------------------------------------------------------------
--  Consenso
-- ---------------------------------------------------------------------------
RegisterNetEvent('int:richiesta', function(idAzione, nome, nomeAzione)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = ('%s: %s'):format(nome, nomeAzione),
            sottotitolo = 'Puoi rifiutare senza dover spiegare niente',
            voci = {
                { id = 'si', icona = '✅', titolo = 'Accetta' },
                { id = 'no', icona = '🚫', titolo = 'Rifiuta' },
            },
        })

        AUREA.Callback.Attendi('int:rispondi', scelta == 'si')
    end)
end)

-- ---------------------------------------------------------------------------
--  Manette e accompagnamento
-- ---------------------------------------------------------------------------
RegisterNetEvent('int:ammanettato', function(stato)
    ammanettato = stato
    local ped = PlayerPedId()

    if stato then
        AUREA.Anima('mp_arresting', 'idle', -1, 49)
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(PlayerId(), true)
        SetPedCanPlayGestureAnims(ped, false)

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🔗', durata = 12000,
            titolo = 'Sei ammanettato',
            testo = 'Non puoi correre, guidare o usare le mani.',
        })
    else
        ClearPedTasks(ped)
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(PlayerId(), false)
        SetPedCanPlayGestureAnims(ped, true)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🔓', titolo = 'Manette tolte', durata = 8000,
        })
    end
end)

RegisterNetEvent('int:trascinato', function(stato, daSrc)
    if stato and daSrc then
        trascinatoDa = GetPlayerFromServerId(daSrc)
    else
        trascinatoDa = nil
        DetachEntity(PlayerPedId(), true, false)
    end
end)

CreateThread(function()
    while true do
        local attesa = 500

        if ammanettato then
            attesa = 0
            local ped = PlayerPedId()
            DisableControlAction(0, 21, true)   -- corsa
            DisableControlAction(0, 22, true)   -- salto
            DisableControlAction(0, 24, true)   -- attacco
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 23, true)   -- entrare in veicolo
            DisableControlAction(0, 75, true)   -- uscire dal veicolo

            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                AUREA.Anima('mp_arresting', 'idle', -1, 49)
            end
        end

        if trascinatoDa then
            attesa = 0
            local ped = PlayerPedId()
            local tiraPed = GetPlayerPed(trascinatoDa)

            if DoesEntityExist(tiraPed) and not IsEntityAttachedToEntity(ped, tiraPed) then
                AttachEntityToEntity(ped, tiraPed, 11816, 0.0, 0.45, 0.0, 0.0, 0.0, 0.0,
                    false, false, false, false, 2, true)
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('int:inVeicolo', function(daSrc)
    local ped = PlayerPedId()
    local agente = GetPlayerPed(GetPlayerFromServerId(daSrc))
    if not DoesEntityExist(agente) then return end

    local coord = GetEntityCoords(agente)
    local v = GetClosestVehicle(coord.x, coord.y, coord.z, 8.0, 0, 71)
    if v == 0 then return end

    DetachEntity(ped, true, false)
    for posto = 0, GetVehicleMaxNumberOfPassengers(v) - 1 do
        if IsVehicleSeatFree(v, posto) then
            TaskWarpPedIntoVehicle(ped, v, posto)
            break
        end
    end
end)

RegisterNetEvent('int:daVeicolo', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    end
end)

RegisterNetEvent('int:apriPerquisizione', function(bersaglioSrc)
    exports.aurea_inventory:Apri({ tipo = 'persona', bersaglio = bersaglioSrc })
end)

RegisterNetEvent('int:mostraDocumenti', function(daSrc, nome)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🪪', durata = 13000,
        titolo = ('%s ti chiede i documenti'):format(nome),
        testo = 'Aprili dall\'inventario e usali per mostrarglieli, oppure rifiuta.',
    })
end)

RegisterNetEvent('int:emote', function(nome)
    exports.aurea_emote:Esegui(nome)
end)
