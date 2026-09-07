--[[
    ESX su AUREA — oggetto ESX lato client

    Stessa idea del server: ESX.PlayerData non è una copia dei dati del
    personaggio, è la stessa tabella AUREA.PG tradotta nei nomi che gli
    script ESX si aspettano. Quando AUREA aggiorna il personaggio, qui si
    ricompone e riparte l'evento ESX corrispondente.
]]

-- ---------------------------------------------------------------------------
--  Callback verso il server
--
--  La forma è identica a quella di AUREA, quindi è un rinvio diretto.
-- ---------------------------------------------------------------------------
function ESX.TriggerServerCallback(nome, cb, ...)
    AUREA.Callback.Chiama(nome, cb, ...)
end

--- Versione bloccante, per chi la preferisce (ESX 1.10 la espone così).
function ESX.AwaitServerCallback(nome, ...)
    return AUREA.Callback.Attendi(nome, ...)
end

--- Callback dal server verso il client.
local callbackClient = {}

function ESX.RegisterClientCallback(nome, fn)
    callbackClient[nome] = fn
end

RegisterNetEvent('esx:tcb', function(nome, id, ...)
    local fn = callbackClient[nome]
    if not fn then return TriggerServerEvent('esx:tcbRisposta', id) end
    fn(function(...) TriggerServerEvent('esx:tcbRisposta', id, ...) end, ...)
end)

-- ---------------------------------------------------------------------------
--  Dati del giocatore
-- ---------------------------------------------------------------------------

--- Ricompone ESX.PlayerData a partire da AUREA.PG.
function ESX.RicomponiPlayerData()
    local pg = AUREA.PG
    if not pg then
        ESX.PlayerData = {}
        ESX.PlayerLoaded = false
        return
    end

    local lavoro = AUREA.Lavori[pg.lavoro.nome] or AUREA.Lavori['disoccupato']
    local grado = lavoro.gradi[pg.lavoro.grado] or lavoro.gradi[0]

    ESX.PlayerData = {
        identifier = pg.citizenid,
        firstName = pg.nome,
        lastName = pg.cognome,
        name = ('%s %s'):format(pg.nome, pg.cognome),
        dateofbirth = pg.dataNascita,
        sex = pg.sesso,
        height = 180,
        group = ESXC.GruppoESX(pg.gruppo or 'utente'),
        money = ESXC.AEuro(pg.denaro.contanti),
        maxWeight = 0,
        metadata = pg.metadata or {},

        job = {
            name = pg.lavoro.nome,
            label = lavoro.etichetta,
            grade = pg.lavoro.grado,
            grade_name = tostring(pg.lavoro.grado),
            grade_label = grado.etichetta,
            grade_salary = math.floor(ESXC.AEuro(grado.stipendio or 0)),
            skin_male = {}, skin_female = {},
            onDuty = pg.lavoro.servizio,
        },

        accounts = {
            { name = 'money', label = 'Contanti', money = ESXC.AEuro(pg.denaro.contanti), round = 0 },
            { name = 'bank', label = 'Conto corrente', money = ESXC.AEuro(pg.denaro.banca), round = 0 },
            { name = 'black_money', label = 'Contanti non tracciati', money = 0, round = 0 },
        },

        inventory = ESX.PlayerData.inventory or {},
        loadout = ESX.PlayerData.loadout or {},

        -- Non standard: in un server italiano queste due servono spesso
        codiceFiscale = pg.cf,
        telefono = pg.telefono,
    }
end

function ESX.GetPlayerData()
    return ESX.PlayerData
end

function ESX.IsPlayerLoaded()
    return ESX.PlayerLoaded
end

function ESX.SetPlayerData(chiave, valore)
    ESX.PlayerData[chiave] = valore
end

-- ---------------------------------------------------------------------------
--  Notifiche
--
--  Tutte e tre le forme ESX finiscono nella UI di AUREA. Le stringhe ESX
--  contengono i codici colore di GTA (~r~, ~b~, ~s~): si ripuliscono,
--  altrimenti nella UI si vedrebbero come testo.
-- ---------------------------------------------------------------------------
local function ripulisci(testo)
    if type(testo) ~= 'string' then return tostring(testo or '') end
    return (testo:gsub('~%w~', ''):gsub('~%w_%w~', ''))
end

--- Il colore GTA dice già il tono: rosso male, verde bene, giallo attenzione.
local function tonoDa(testo)
    if type(testo) ~= 'string' then return 'info' end
    if testo:find('~r~') then return 'errore' end
    if testo:find('~g~') then return 'successo' end
    if testo:find('~y~') or testo:find('~o~') then return 'avviso' end
    return 'info'
end

function ESX.ShowNotification(messaggio, lampeggia, durata)
    exports.aurea_ui:Notifica({
        tipo = tonoDa(messaggio),
        icona = ESXC.Notifiche.icona,
        testo = ripulisci(messaggio),
        durata = durata or ESXC.Notifiche.durata,
    })
end

function ESX.ShowAdvancedNotification(titolo, sottotitolo, messaggio, icona, tipo)
    exports.aurea_ui:Notifica({
        tipo = tipo == 1 and 'errore' or (tipo == 2 and 'avviso' or 'info'),
        icona = ESXC.Notifiche.icona,
        titolo = ripulisci(titolo),
        testo = ('%s%s'):format(
            sottotitolo and sottotitolo ~= '' and (ripulisci(sottotitolo) .. ' — ') or '',
            ripulisci(messaggio)),
        durata = ESXC.Notifiche.avanzataDurata,
    })
end

--- L'help notification di GTA è quel riquadro in alto a sinistra: qui
--- diventa il prompt di AUREA, che è la cosa che gli somiglia di più.
function ESX.ShowHelpNotification(messaggio, lampeggia, sonoro, durata)
    exports.aurea_ui:Prompt(true, ripulisci(messaggio), 'E')

    ESX.SetTimeout(durata or 3000, function()
        exports.aurea_ui:Prompt(false)
    end)
end

function ESX.TextUI(messaggio, tipo)
    exports.aurea_ui:Prompt(true, ripulisci(messaggio), nil)
end

function ESX.HideUI()
    exports.aurea_ui:Prompt(false)
end

function ESX.ShowInventory()
    exports.aurea_inventory:Apri()
end

-- ---------------------------------------------------------------------------
--  Streaming
-- ---------------------------------------------------------------------------
ESX.Streaming = {}

function ESX.Streaming.RequestModel(modello, cb)
    local hash = type(modello) == 'string' and GetHashKey(modello) or modello
    if not IsModelValid(hash) then
        if cb then cb(false) end
        return false
    end

    if HasModelLoaded(hash) then
        if cb then cb(true) end
        return true
    end

    RequestModel(hash)
    local scadenza = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(0) end

    local ok = HasModelLoaded(hash)
    if cb then cb(ok) end
    return ok
end

function ESX.Streaming.RequestAnimDict(dizionario, cb)
    if HasAnimDictLoaded(dizionario) then
        if cb then cb(true) end
        return true
    end

    RequestAnimDict(dizionario)
    local scadenza = GetGameTimer() + 10000
    while not HasAnimDictLoaded(dizionario) and GetGameTimer() < scadenza do Wait(0) end

    local ok = HasAnimDictLoaded(dizionario)
    if cb then cb(ok) end
    return ok
end

function ESX.Streaming.RequestAnimSet(insieme, cb)
    RequestAnimSet(insieme)
    local scadenza = GetGameTimer() + 10000
    while not HasAnimSetLoaded(insieme) and GetGameTimer() < scadenza do Wait(0) end
    if cb then cb(HasAnimSetLoaded(insieme)) end
end

function ESX.Streaming.RequestNamedPtfxAsset(risorsa, cb)
    RequestNamedPtfxAsset(risorsa)
    local scadenza = GetGameTimer() + 10000
    while not HasNamedPtfxAssetLoaded(risorsa) and GetGameTimer() < scadenza do Wait(0) end
    if cb then cb(HasNamedPtfxAssetLoaded(risorsa)) end
end

function ESX.Streaming.RequestWeaponAsset(arma, cb)
    local hash = type(arma) == 'string' and GetHashKey(arma) or arma
    RequestWeaponAsset(hash, 31, 0)
    local scadenza = GetGameTimer() + 10000
    while not HasWeaponAssetLoaded(hash) and GetGameTimer() < scadenza do Wait(0) end
    if cb then cb(HasWeaponAssetLoaded(hash)) end
end

-- ---------------------------------------------------------------------------
--  Scaleform
-- ---------------------------------------------------------------------------
ESX.Scaleform = {}

function ESX.Scaleform.ShowFreemodeMessage(titolo, messaggio, durata)
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '📰',
        titolo = ripulisci(titolo), testo = ripulisci(messaggio),
        durata = durata or 8000,
    })
end

function ESX.Scaleform.ShowBreakingNews(titolo, messaggio, durata)
    ESX.Scaleform.ShowFreemodeMessage(titolo, messaggio, durata)
end

-- ---------------------------------------------------------------------------
--  Consegna dell'oggetto condiviso
-- ---------------------------------------------------------------------------
exports('getSharedObject', function() return ESX end)

AddEventHandler('esx:getSharedObject', function(cb)
    if cb then cb(ESX) end
end)
