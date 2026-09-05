--[[
    AUREA · Animali (client)
]]

local U = AUREA.Util
local animale = nil     -- ped in scena
local dati = nil
local comando = 'seguimi'

CreateThread(function()
    for _, p in ipairs({ ANI.Canile, ANI.Veterinario }) do
        local b = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
        SetBlipSprite(b, p.blip.sprite)
        SetBlipColour(b, p.blip.colore)
        SetBlipScale(b, p.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(p.nome)
        EndTextCommandSetBlipName(b)
    end

    exports.aurea_target:AggiungiZona('canile', ANI.Canile.coord, 3.0, {
        { etichetta = 'Adotta un animale', icona = '🐕', azione = function() adotta() end },
    })
end)

-- ---------------------------------------------------------------------------
--  Richiamo e comandi
-- ---------------------------------------------------------------------------
RegisterCommand('animale', function()
    CreateThread(function()
        dati = AUREA.Callback.Attendi('ani:mio')
        if not dati then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🐕', titolo = 'Nessun animale',
                testo = 'Al canile municipale ce ne sono che aspettano.',
            })
        end

        local voci = {
            { id = '_s', icona = '🐕',
              titolo = ('%s — %s'):format(dati.nome, dati.razzaNome),
              descrizione = ('Fame %d%% · Affetto %d%%%s')
                  :format(dati.fame, dati.affetto,
                          dati.microchip and ' · microchippato' or ' · SENZA MICROCHIP'),
              disattivata = true },
            { id = 'richiama', icona = '📣',
              titolo = animale and 'Rimettilo dentro' or 'Chiamalo' },
            { id = 'nutri', icona = '🥩', titolo = 'Dagli da mangiare',
              descrizione = 'Serve una confezione di crocchette.' },
            { id = 'coccola', icona = '❤', titolo = 'Fagli una carezza' },
        }

        for _, c in ipairs(ANI.Comandi) do
            local ammesso = dati.affetto >= c.affetto
                and (not (c.id == 'cerca' or c.id == 'guardia') or dati.guardia)
            voci[#voci + 1] = {
                id = 'cmd:' .. c.id, icona = c.icona, titolo = c.nome,
                descrizione = c.descrizione or (c.affetto > 0
                    and ('Serve affetto %d%%.'):format(c.affetto) or nil),
                valore = comando == c.id and 'attivo' or nil,
                disattivata = not ammesso or not animale,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = dati.nome,
            sottotitolo = 'Un animale trascurato scappa, e non torna',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'richiama' then return animale and rimetti() or chiama() end

        if scelta == 'nutri' then
            local ok, messaggio = AUREA.Callback.Attendi('ani:nutri')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🥩',
                titolo = 'Pasto', testo = messaggio, durata = 10000,
            })
        end

        if scelta == 'coccola' then
            exports.aurea_ui:Progresso({ etichetta = 'Carezze...', durata = 4000,
                anim = { dizionario = 'amb@world_human_bum_freeway@male@base', nome = 'base' } })
            local ok, messaggio = AUREA.Callback.Attendi('ani:coccola')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '❤',
                titolo = dati.nome, testo = messaggio, durata = 9000,
            })
        end

        local c = scelta:match('^cmd:(.+)$')
        if c then impostaComando(c) end
    end)
end, false)

function chiama()
    CreateThread(function()
        if not dati then return end

        local hash = GetHashKey(dati.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 120 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local ped = PlayerPedId()
        local coord = GetOffsetFromEntityInWorldCoords(ped, 1.2, 1.0, 0.0)

        animale = CreatePed(28, hash, coord.x, coord.y, coord.z, GetEntityHeading(ped), true, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityAsMissionEntity(animale, true, true)
        SetPedCanRagdoll(animale, false)
        SetEntityInvincible(animale, true)
        SetBlockingOfNonTemporaryEvents(animale, true)

        impostaComando('seguimi')

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🐕', titolo = dati.nome,
            testo = 'È con te. Dagli ordini da /animale.', durata = 9000,
        })
    end)
end

function rimetti()
    if animale and DoesEntityExist(animale) then DeletePed(animale) end
    animale = nil
    exports.aurea_ui:Notifica({ tipo = 'info', icona = '🐕', titolo = 'A casa',
        testo = 'L\'hai rimesso dentro.' })
end

function impostaComando(id)
    comando = id
    if not animale or not DoesEntityExist(animale) then return end

    ClearPedTasks(animale)

    if id == 'seguimi' then
        TaskFollowToOffsetOfEntity(animale, PlayerPedId(), 1.0, -1.0, 0.0,
            2.0 * (dati and dati.velocita or 1.0), -1, 2.0, true)
    elseif id == 'resta' then
        TaskStandStill(animale, -1)
    elseif id == 'siedi' then
        TaskStartScenarioInPlace(animale, 'WORLD_DOG_SITTING_GENERIC', 0, true)
    elseif id == 'cerca' then
        cerca()
    elseif id == 'guardia' then
        TaskStandStill(animale, -1)
        exports.aurea_ui:Notifica({ tipo = 'info', icona = '🛡',
            titolo = 'A guardia', testo = 'Ti avvisa se qualcuno si avvicina.' })
    end
end

function cerca()
    CreateThread(function()
        exports.aurea_ui:Progresso({ etichetta = 'Il cane fiuta in giro...', durata = 9000 })

        local esito, errore = AUREA.Callback.Attendi('ani:cerca')
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔍', titolo = 'Cerca', testo = tostring(errore),
            })
        end

        exports.aurea_ui:Notifica({
            tipo = esito.segnalazioni > 0 and 'avviso' or 'info', icona = '🔍',
            titolo = esito.segnalazioni > 0 and 'Il cane segnala' or 'Niente da segnalare',
            testo = esito.segnalazioni > 0
                and ('Fiuta qualcosa su %d persone qui intorno.'):format(esito.segnalazioni)
                or 'Nessuno qui intorno ha addosso niente di interessante.',
            durata = 12000,
        })
        impostaComando('seguimi')
    end)
end

--- Il cane a guardia avvisa quando qualcuno entra nel raggio.
CreateThread(function()
    while true do
        local attesa = 3000

        if animale and DoesEntityExist(animale) and comando == 'guardia' then
            local coord = GetEntityCoords(animale)
            for _, altro in ipairs(GetActivePlayers()) do
                local p = GetPlayerPed(altro)
                if p ~= PlayerPedId() and #(coord - GetEntityCoords(p)) < 12.0 then
                    PlayAmbientSpeech1(animale, 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE')
                    exports.aurea_ui:Notifica({
                        tipo = 'avviso', icona = '🛡', durata = 6000,
                        titolo = 'Il cane abbaia', testo = 'Qualcuno si sta avvicinando.',
                    })
                    attesa = 15000
                    break
                end
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('ani:fuggito', function()
    if animale and DoesEntityExist(animale) then DeletePed(animale) end
    animale = nil
    dati = nil
end)

function adotta()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('ani:razze')
        if not elenco then return end

        local voci = {}
        for _, r in ipairs(elenco.razze) do
            voci[#voci + 1] = {
                id = r.id, icona = '🐕', titolo = r.nome,
                descrizione = r.guardia and 'Addestrabile alla ricerca e alla guardia.'
                    or 'Compagnia.',
            }
        end

        local razza = exports.aurea_ui:Menu({
            titolo = ANI.Canile.nome,
            sottotitolo = ('Adozione, microchip e vaccini: %s'):format(U.Euro(elenco.costo)),
            voci = voci,
        })
        if not razza then return end

        local r = exports.aurea_ui:Dialogo('Come lo chiami?', {
            { etichetta = 'Nome', tipo = 'text', segnaposto = 'Es. Argo', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('ani:adotta', razza, r[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🐕',
            titolo = 'Canile', testo = messaggio, durata = 13000,
        })
    end)
end

RegisterCommand('controllaanimale', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local bersaglio, distanza = nil, 3.5
        for _, altro in ipairs(GetActivePlayers()) do
            local p = GetPlayerPed(altro)
            if p ~= ped then
                local d = #(coord - GetEntityCoords(p))
                if d < distanza then bersaglio, distanza = GetPlayerServerId(altro), d end
            end
        end
        if not bersaglio then return end

        local esito, messaggio = AUREA.Callback.Attendi('ani:controlla', bersaglio)
        exports.aurea_ui:Notifica({
            tipo = esito and (esito.regolare and 'successo' or 'errore') or 'info',
            icona = '🐕', titolo = 'Anagrafe canina', testo = messaggio, durata = 13000,
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and animale and DoesEntityExist(animale) then
        DeletePed(animale)
    end
end)
