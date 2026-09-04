--[[
    AUREA · Emote (client)
]]

local emoteAttiva = nil
local oggetti = {}          -- prop create per l'emote in corso
local andatura = 'normale'
local invitoInCorso = nil   -- { da, tipo, scadenza }

-- ---------------------------------------------------------------------------
--  Pulizia
-- ---------------------------------------------------------------------------
local function rimuoviOggetti()
    for _, o in ipairs(oggetti) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    oggetti = {}
end

local function annulla()
    rimuoviOggetti()
    emoteAttiva = nil
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if IsEntityAttachedToAnyPed(ped) then DetachEntity(ped, true, false) end
end

exports('Annulla', annulla)
exports('EmoteAttiva', function() return emoteAttiva end)

-- ---------------------------------------------------------------------------
--  Esecuzione di un'emote
-- ---------------------------------------------------------------------------
local function esegui(id)
    local e = EMO.Emote[id]
    if not e then return false end

    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Non ora', testo = 'Scendi dal veicolo.' })
        return false
    end
    if IsEntityDead(ped) then return false end

    -- Ripetere la stessa emote la annulla
    if emoteAttiva == id then
        annulla()
        return true
    end

    rimuoviOggetti()

    if not AUREA.CaricaAnim(e.dizionario) then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Animazione non disponibile', testo = e.nome })
        return false
    end

    -- 1 = ciclica, 49 = permette il movimento della parte superiore
    local flag = e.ciclica and 1 or 0
    TaskPlayAnim(ped, e.dizionario, e.anim, 3.0, -3.0, e.ciclica and -1 or 3000, flag, 0, false, false, false)

    -- Oggetto in mano
    if e.oggetto then
        local hash = GetHashKey(e.oggetto.modello)
        RequestModel(hash)
        local scadenza = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end

        if HasModelLoaded(hash) then
            local coord = GetEntityCoords(ped)
            local prop = CreateObject(hash, coord.x, coord.y, coord.z, true, true, false)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, e.oggetto.osso),
                e.oggetto.pos[1], e.oggetto.pos[2], e.oggetto.pos[3],
                e.oggetto.rot[1], e.oggetto.rot[2], e.oggetto.rot[3],
                true, true, false, true, 1, true)
            oggetti[#oggetti + 1] = prop
            SetModelAsNoLongerNeeded(hash)
        end
    end

    emoteAttiva = e.ciclica and id or nil

    if not e.ciclica then
        CreateThread(function()
            Wait(3200)
            rimuoviOggetti()
        end)
    end

    return true
end

exports('Esegui', esegui)

-- ---------------------------------------------------------------------------
--  Interruzione al movimento
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 500

        if emoteAttiva then
            attesa = 150
            local ped = PlayerPedId()

            -- Muoversi o salire in auto interrompe
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
                annulla()
            elseif GetEntitySpeed(ped) > 1.2 then
                annulla()
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Menu delle emote
-- ---------------------------------------------------------------------------
local function apriMenu()
    CreateThread(function()
        local voci = {}
        for _, c in ipairs(EMO.Categorie) do
            local quante = #EMO.PerCategoria(c.id)
            if quante > 0 then
                voci[#voci + 1] = {
                    id = c.id, icona = c.icona, titolo = c.nome,
                    descrizione = ('%d animazioni'):format(quante),
                }
            end
        end

        voci[#voci + 1] = { id = '__condivise', icona = '🤝', titolo = 'Azioni in due',
            descrizione = 'Richiedono il consenso dell\'altra persona.' }
        voci[#voci + 1] = { id = '__andature', icona = '🚶', titolo = 'Andatura',
            descrizione = ('Attuale: %s'):format(EMO.Andature[andatura].nome) }

        if emoteAttiva then
            table.insert(voci, 1, { id = '__annulla', icona = '✖', titolo = 'Interrompi l\'animazione',
                descrizione = EMO.Emote[emoteAttiva] and EMO.Emote[emoteAttiva].nome or nil })
        end

        local categoria = exports.aurea_ui:Menu({
            titolo = 'Animazioni',
            sottotitolo = 'Ripeti la stessa emote per interromperla',
            voci = voci,
        })
        if not categoria then return end

        if categoria == '__annulla' then return annulla() end
        if categoria == '__andature' then return menuAndature() end
        if categoria == '__condivise' then return menuCondivise() end

        local vociEmote = {}
        for _, e in ipairs(EMO.PerCategoria(categoria)) do
            vociEmote[#vociEmote + 1] = {
                id = e.id,
                icona = e.dati.oggetto and '🎭' or (e.dati.ciclica and '🔁' or '▶'),
                titolo = e.dati.nome,
                descrizione = e.dati.ciclica and 'Resta attiva finché non la interrompi.' or nil,
                valore = '/e ' .. e.id,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Animazioni',
            sottotitolo = 'Puoi richiamarle anche con /e <nome>',
            voci = vociEmote,
        })
        if scelta then esegui(scelta) end
    end)
end

function menuAndature()
    CreateThread(function()
        local voci = {}
        for id, a in pairs(EMO.Andature) do
            voci[#voci + 1] = {
                id = id, icona = andatura == id and '✅' or '🚶',
                titolo = a.nome, disattivata = andatura == id,
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Andatura',
            sottotitolo = 'Il modo in cui il tuo personaggio si muove',
            voci = voci,
        })
        if not scelta then return end

        impostaAndatura(scelta)
    end)
end

function impostaAndatura(id)
    local a = EMO.Andature[id]
    if not a then return end

    andatura = id
    local ped = PlayerPedId()

    if not a.set then
        ResetPedMovementClipset(ped, 0.0)
    else
        RequestAnimSet(a.set)
        local scadenza = GetGameTimer() + 3000
        while not HasAnimSetLoaded(a.set) and GetGameTimer() < scadenza do Wait(10) end
        if HasAnimSetLoaded(a.set) then SetPedMovementClipset(ped, a.set, 1.0) end
    end

    exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🚶', titolo = 'Andatura', testo = a.nome })
end

-- ---------------------------------------------------------------------------
--  Azioni condivise
-- ---------------------------------------------------------------------------
function menuCondivise()
    CreateThread(function()
        local voci = {}
        for id, c in pairs(EMO.Condivise) do
            voci[#voci + 1] = {
                id = id, icona = '🤝', titolo = c.nome,
                descrizione = ('Serve una persona entro %.1f metri.'):format(c.distanza),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Azioni in due',
            sottotitolo = 'L\'altra persona deve accettare',
            voci = voci,
        })
        if not scelta then return end

        local condivisa = EMO.Condivise[scelta]
        local bersaglio = giocatoreVicino(condivisa.distanza + 1.0)
        if not bersaglio then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.',
            })
        end

        TriggerServerEvent('emo:invita', bersaglio, scelta)
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🤝', titolo = 'Invito inviato', testo = 'Attendi che accetti.',
        })
    end)
end

function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < raggio then
            return GetPlayerServerId(altro)
        end
    end
    return nil
end

RegisterNetEvent('emo:invitoRicevuto', function(daSrc, nomeMittente, tipo)
    local c = EMO.Condivise[tipo]
    if not c then return end

    invitoInCorso = { da = daSrc, tipo = tipo, scadenza = GetGameTimer() + 12000 }

    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🤝', durata = 12000,
        titolo = ('%s propone: %s'):format(nomeMittente, c.nome),
        testo = 'Premi Y per accettare, N per rifiutare.',
    })
end)

CreateThread(function()
    while true do
        local attesa = 500

        if invitoInCorso then
            attesa = 0
            if GetGameTimer() > invitoInCorso.scadenza then
                invitoInCorso = nil
            elseif IsControlJustReleased(0, 246) then      -- Y
                TriggerServerEvent('emo:rispondi', invitoInCorso.da, invitoInCorso.tipo, true)
                invitoInCorso = nil
            elseif IsControlJustReleased(0, 306) then      -- N
                TriggerServerEvent('emo:rispondi', invitoInCorso.da, invitoInCorso.tipo, false)
                invitoInCorso = nil
                exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Invito rifiutato' })
            end
        end

        Wait(attesa)
    end
end)

--- Esecuzione sincronizzata: il server dice a ciascuno quale parte fare.
RegisterNetEvent('emo:condivisa', function(tipo, ruolo, altroSrc)
    local c = EMO.Condivise[tipo]
    if not c then return end

    local parte = c[ruolo]
    if not parte then return end

    CreateThread(function()
        local ped = PlayerPedId()
        if not AUREA.CaricaAnim(parte.dizionario) then return end

        -- Chi viene trasportato si aggancia a chi lo porta
        if c.attacca and ruolo == 'invitato' then
            local altro = GetPlayerFromServerId(altroSrc)
            if altro ~= -1 then
                AttachEntityToEntity(ped, GetPlayerPed(altro), 0, 0.27, 0.15, 0.63,
                    0.5, 0.5, 0.0, false, false, false, false, 2, false)
            end
        end

        TaskPlayAnim(ped, parte.dizionario, parte.anim, 3.0, -3.0,
            c.attacca and -1 or 4000, c.attacca and 1 or 0, 0, false, false, false)

        emoteAttiva = c.attacca and ('condivisa:' .. tipo) or nil

        if not c.attacca then
            Wait(4200)
            ClearPedTasks(ped)
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
RegisterCommand('emote', apriMenu, false)
RegisterKeyMapping('emote', 'Apri il menu delle animazioni', 'keyboard', 'F3')

RegisterCommand('e', function(_, args)
    local id = (args[1] or ''):lower()

    if id == '' or id == 'lista' then return apriMenu() end
    if id == 'stop' or id == 'fine' then return annulla() end

    if EMO.Emote[id] then
        esegui(id)
    else
        -- ricerca per nome parziale
        for chiave, e in pairs(EMO.Emote) do
            if chiave:find(id, 1, true) or e.nome:lower():find(id, 1, true) then
                return esegui(chiave)
            end
        end
        exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Animazione sconosciuta',
            testo = ('"%s" non esiste. Usa F3 per il menu.'):format(id),
        })
    end
end, false)

RegisterCommand('andatura', function(_, args)
    local id = (args[1] or ''):lower()
    if EMO.Andature[id] then impostaAndatura(id) else menuAndature() end
end, false)

RegisterCommand('mani', function() esegui('mani_alto') end, false)
RegisterKeyMapping('mani', 'Alza le mani', 'keyboard', 'X')

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then rimuoviOggetti() end
end)

-- Le ferite gravi impongono l'andatura zoppicante
AddEventHandler('aurea:client:stato', function(stato)
    if stato and (stato.salute or 200) < 130 and andatura == 'normale' then
        impostaAndatura('ferito')
    end
end)
