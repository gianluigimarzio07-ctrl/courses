--[[
    ESX su AUREA — oggetto ESX lato server

    Questo è quello che uno script ESX riceve quando fa

        ESX = exports['es_extended']:getSharedObject()

    ed è anche il motivo per cui la risorsa si chiama es_extended: quella
    export cerca una risorsa con quel nome esatto.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Accesso ai giocatori
-- ---------------------------------------------------------------------------
function ESX.GetPlayerFromId(src)
    local p = AUREA.GetPlayer(src)
    if not p then return nil end
    return ESX.CostruisciXPlayer(src)
end

function ESX.GetPlayerFromIdentifier(identificatore)
    -- In AUREA l'identità del personaggio è il citizenid: è la cosa che
    -- corrisponde davvero all'identifier ESX, perché segue il personaggio
    -- e non l'account.
    local p = AUREA.GetPlayerByCitizenId(identificatore)
    if p then return ESX.CostruisciXPlayer(p.source) end

    -- Accettiamo anche la licenza, che è come ESX identifica di solito
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.license == identificatore
            or ('license:%s'):format(altro.license) == identificatore then
            return ESX.CostruisciXPlayer(altro.source)
        end
    end
    return nil
end

--- Le source dei giocatori in gioco.
function ESX.GetPlayers()
    local out = {}
    for src in pairs(AUREA.Giocatori) do out[#out + 1] = src end
    return out
end

function ESX.GetNumPlayers()
    local n = 0
    for _ in pairs(AUREA.Giocatori) do n = n + 1 end
    return n
end

--- ESX.GetExtendedPlayers('job', 'police') e simili.
function ESX.GetExtendedPlayers(chiave, valore)
    local out = {}

    for src, p in pairs(AUREA.Giocatori) do
        local x = ESX.CostruisciXPlayer(src)
        local ammesso

        if chiave == nil then
            ammesso = true
        elseif chiave == 'job' then
            ammesso = p.lavoro.nome == valore
        elseif chiave == 'group' then
            ammesso = ESXC.GruppoESX(p.gruppo) == valore
        elseif chiave == 'onDuty' then
            ammesso = p.lavoro.servizio == (valore and true or false)
        else
            ammesso = x[chiave] == valore
        end

        if ammesso then out[#out + 1] = x end
    end

    return out
end

function ESX.GetPlayerFromName(nome)
    local cercato = tostring(nome):lower()
    for src, p in pairs(AUREA.Giocatori) do
        if p:NomeCompleto():lower():find(cercato, 1, true) then
            return ESX.CostruisciXPlayer(src)
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Lavori
-- ---------------------------------------------------------------------------
function ESX.GetJobs()
    local out = {}

    for nome, l in pairs(AUREA.Lavori) do
        local gradi = {}
        for n, gr in pairs(l.gradi) do
            gradi[tostring(n)] = {
                job_name = nome,
                grade = n,
                name = tostring(n),
                label = gr.etichetta,
                salary = math.floor(ESXC.AEuro(gr.stipendio or 0)),
                skin_male = {}, skin_female = {},
            }
        end
        out[nome] = { name = nome, label = l.etichetta, grades = gradi }
    end

    return out
end

function ESX.DoesJobExist(nome, grado)
    local l = AUREA.Lavori[nome]
    if not l then return false end
    if grado == nil then return true end
    return l.gradi[tonumber(grado)] ~= nil
end

-- ---------------------------------------------------------------------------
--  Callback
--
--  ESX.RegisterServerCallback si appoggia al sistema di AUREA, così le due
--  famiglie di callback vivono nello stesso registro e non si pestano i
--  piedi sui nomi.
--
--  L'unica differenza di forma: in ESX l'handler riceve (source, cb, ...),
--  in AUREA riceve (src, rispondi, ...). Sono la stessa cosa in ordine
--  diverso di nome, quindi si passa dritto.
-- ---------------------------------------------------------------------------
function ESX.RegisterServerCallback(nome, handler)
    AUREA.Callback.Registra(nome, function(src, rispondi, ...)
        handler(src, rispondi, ...)
    end)
end

--- ESX 1.10 la chiama così.
ESX.RegisterCallback = ESX.RegisterServerCallback

--- Callback verso il client (ESX.TriggerClientCallback).
local callbackClient = {}
local prossimoCallbackClient = 1

function ESX.TriggerClientCallback(src, nome, cb, ...)
    local id = prossimoCallbackClient
    prossimoCallbackClient = prossimoCallbackClient + 1
    callbackClient[id] = cb
    TriggerClientEvent('esx:tcb', src, nome, id, ...)
end

RegisterNetEvent('esx:tcbRisposta', function(id, ...)
    local cb = callbackClient[id]
    if not cb then return end
    callbackClient[id] = nil
    cb(...)
end)

-- ---------------------------------------------------------------------------
--  Oggetti usabili
--
--  ESX.RegisterUsableItem si innesta nel registro d'uso di aurea_inventory:
--  è lo stesso posto in cui si registra un uso AUREA, quindi non ci sono
--  due catene di gestori che si contendono lo stesso oggetto.
-- ---------------------------------------------------------------------------
local usabiliESX = {}

function ESX.RegisterUsableItem(nome, handler)
    usabiliESX[nome] = handler

    exports.aurea_inventory:RegistraUso(nome, function(giocatore, riga)
        handler(giocatore.source, riga.metadata, riga)
        -- ESX si aspetta che sia lo script a togliere l'oggetto: qui non
        -- si consuma da soli, altrimenti sparirebbe due volte.
        return false
    end)
end

function ESX.UseItem(src, nome, ...)
    local handler = usabiliESX[nome]
    if not handler then
        return print(('[es_extended] UseItem("%s"): nessun gestore registrato.'):format(tostring(nome)))
    end
    handler(src, ...)
end

function ESX.GetUsableItems()
    local out = {}
    for nome in pairs(usabiliESX) do out[nome] = true end
    return out
end

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
function ESX.RegisterCommand(nome, gruppo, handler, ammessoDaConsole, suggerimento)
    local nomi = type(nome) == 'table' and nome or { nome }

    for _, n in ipairs(nomi) do
        local descrizione = (suggerimento and suggerimento.help) or ('Comando %s'):format(n)
        local argomenti = {}

        for _, a in ipairs((suggerimento and suggerimento.arguments) or {}) do
            argomenti[#argomenti + 1] = { name = a.name, help = a.help }
        end

        AUREA.Comando(n, ESXC.GruppoAurea(type(gruppo) == 'table' and gruppo[1] or gruppo),
            descrizione, argomenti,
            function(src, args, raw)
                if src == 0 and ammessoDaConsole == false then
                    return print(('[es_extended] /%s non è ammesso da console.'):format(n))
                end

                local x = src > 0 and ESX.GetPlayerFromId(src) or nil
                local nominati = {}

                -- ESX passa gli argomenti già convertiti secondo il tipo
                -- dichiarato nel suggerimento.
                for i, a in ipairs((suggerimento and suggerimento.arguments) or {}) do
                    local grezzo = args[i]
                    if a.type == 'number' then
                        nominati[a.name] = tonumber(grezzo)
                    elseif a.type == 'player' or a.type == 'playerId' then
                        nominati[a.name] = grezzo and ESX.GetPlayerFromId(tonumber(grezzo)) or nil
                    elseif a.type == 'item' then
                        nominati[a.name] = ESX.Items[grezzo] and grezzo or nil
                    elseif a.type == 'weapon' then
                        nominati[a.name] = grezzo and tostring(grezzo):upper() or nil
                    else
                        nominati[a.name] = grezzo
                    end
                end

                handler(x or src, nominati, function(messaggio)
                    if src > 0 then
                        TriggerClientEvent('esx:showNotification', src, messaggio)
                    else
                        print(('[es_extended] %s'):format(messaggio))
                    end
                end, args, raw)
            end)
    end
end

-- ---------------------------------------------------------------------------
--  Notifiche di comodo
-- ---------------------------------------------------------------------------
function ESX.ShowNotification(src, messaggio, lampeggia, durata)
    TriggerClientEvent('esx:showNotification', src, messaggio, lampeggia, durata)
end

function ESX.ShowAdvancedNotification(src, titolo, sottotitolo, messaggio, icona, tipo)
    TriggerClientEvent('esx:showAdvancedNotification', src, titolo, sottotitolo, messaggio, icona, tipo)
end

function ESX.ShowHelpNotification(src, messaggio, lampeggia, sonoro, durata)
    TriggerClientEvent('esx:showHelpNotification', src, messaggio, lampeggia, sonoro, durata)
end

-- ---------------------------------------------------------------------------
--  Salvataggio
-- ---------------------------------------------------------------------------
function ESX.SavePlayer(x, cb)
    local p = x and AUREA.GetPlayer(x.source)
    if p then p:Salva() end
    if cb then cb() end
end

function ESX.SavePlayers(cb)
    for _, p in pairs(AUREA.Giocatori) do
        pcall(function() p:Salva() end)
    end
    if cb then cb() end
end

-- ---------------------------------------------------------------------------
--  Pickup
--
--  In AUREA gli oggetti a terra sono mucchi con regole proprie (scadono,
--  hanno un peso, si possono perquisire). I pickup ESX diventano quelli.
-- ---------------------------------------------------------------------------
function ESX.CreatePickup(tipo, nome, quantita, etichetta, src, componenti, tinta)
    if not ESXC.Compat.pickupComeMucchi then
        return ESX.NonImplementato('ESX.CreatePickup')
    end

    if tipo ~= 'item_standard' then
        return ESX.NonImplementato(('ESX.CreatePickup(%s)'):format(tostring(tipo)),
            'Solo item_standard diventa un mucchio a terra.')
    end

    local x = src and ESX.GetPlayerFromId(src)
    if not x then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    exports.aurea_inventory:Deposita(coord, nome, quantita)
end

-- ---------------------------------------------------------------------------
--  OneSync
-- ---------------------------------------------------------------------------
ESX.OneSync = {}

function ESX.OneSync.GetPlayersInArea(coord, distanza, ignora)
    local centro = vector3(coord.x, coord.y, coord.z)
    local esclusi = {}
    for _, v in ipairs(ignora or {}) do esclusi[tonumber(v)] = true end

    local out = {}
    for src in pairs(AUREA.Giocatori) do
        if not esclusi[src] then
            local c = GetEntityCoords(GetPlayerPed(src))
            if #(centro - c) <= distanza then out[#out + 1] = src end
        end
    end
    return out
end

function ESX.OneSync.GetClosestPlayer(coord, ignora)
    local centro = vector3(coord.x, coord.y, coord.z)
    local esclusi = {}
    for _, v in ipairs(ignora or {}) do esclusi[tonumber(v)] = true end

    local migliore, distanza = -1, math.huge
    for src in pairs(AUREA.Giocatori) do
        if not esclusi[src] then
            local d = #(centro - GetEntityCoords(GetPlayerPed(src)))
            if d < distanza then migliore, distanza = src, d end
        end
    end

    return migliore, distanza == math.huge and -1 or distanza
end

function ESX.OneSync.SpawnVehicle(modello, coord, direzione, proprieta, cb)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello
    local veicolo = CreateVehicle(hash, coord.x, coord.y, coord.z, direzione or 0.0, true, true)

    local scadenza = GetGameTimer() + 5000
    while not DoesEntityExist(veicolo) and GetGameTimer() < scadenza do Wait(0) end
    if not DoesEntityExist(veicolo) then
        if cb then cb(nil) end
        return nil
    end

    local rete = NetworkGetNetworkIdFromEntity(veicolo)
    if proprieta and next(proprieta) then
        TriggerClientEvent('esx:applicaProprietaVeicolo', -1, rete, proprieta)
    end

    if cb then cb(rete) end
    return rete
end

function ESX.OneSync.SpawnObject(modello, coord, cb)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello
    local oggetto = CreateObject(hash, coord.x, coord.y, coord.z, true, true, false)
    if cb then cb(NetworkGetNetworkIdFromEntity(oggetto)) end
    return NetworkGetNetworkIdFromEntity(oggetto)
end

function ESX.OneSync.SpawnPed(modello, coord, direzione, cb)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello
    local ped = CreatePed(0, hash, coord.x, coord.y, coord.z, direzione or 0.0, true, true)
    if cb then cb(NetworkGetNetworkIdFromEntity(ped)) end
    return NetworkGetNetworkIdFromEntity(ped)
end

function ESX.OneSync.DeleteEntity(rete)
    local entita = NetworkGetEntityFromNetworkId(rete)
    if DoesEntityExist(entita) then DeleteEntity(entita) end
end

-- ---------------------------------------------------------------------------
--  Configurazione
--
--  Qualche script legge ESX.GetConfig() per sapere come è impostato il
--  server. Si risponde con i valori veri di AUREA, tradotti.
-- ---------------------------------------------------------------------------
function ESX.GetConfig()
    return {
        Locale = 'it',
        Multichar = true,
        Accounts = {
            money = { label = 'Contanti', round = 0 },
            bank = { label = 'Conto corrente', round = 0 },
            black_money = { label = 'Contanti non tracciati', round = 0 },
        },
        DefaultSpawn = AUREA.Config.Avvio.posizione,
        StartingAccountMoney = {
            money = math.floor(ESXC.AEuro(AUREA.Config.Avvio.contanti)),
            bank = math.floor(ESXC.AEuro(AUREA.Config.Avvio.banca)),
        },
        MaxWeight = 0,
        PaycheckInterval = 0,     -- la paga la eroga aurea_core, non ESX
        EnableDebug = false,
        EnableSocietyPayouts = false,
        AdminGroups = { admin = true, superadmin = true },
        DisableWeaponWheel = false,
        DisableHealthRegeneration = true,
        -- Non standard, ma dice a chi legge dove si trova davvero
        Framework = 'AUREA',
        Ponte = 'es_extended su AUREA',
    }
end

-- ---------------------------------------------------------------------------
--  Consegna dell'oggetto condiviso
-- ---------------------------------------------------------------------------
exports('getSharedObject', function() return ESX end)

AddEventHandler('esx:getSharedObject', function(cb)
    if cb then cb(ESX) end
end)

--- Alcune risorse usano ancora questa forma.
exports('getSharedObjectAsync', function(cb)
    if cb then cb(ESX) end
    return ESX
end)

CreateThread(function()
    Wait(1200)
    print(('[es_extended] Ponte ESX su AUREA attivo — %d lavori, %d oggetti, %d giocatori in gioco.')
        :format(ESX.Table.SizeOf(AUREA.Lavori), ESX.Table.SizeOf(ESX.Items), ESX.GetNumPlayers()))
end)
