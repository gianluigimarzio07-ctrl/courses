--[[
    ESX su AUREA — l'oggetto xPlayer

    Un xPlayer qui non contiene dati: è una facciata sul Giocatore AUREA.
    Tutte le letture guardano il Giocatore vero, tutte le scritture passano
    dai suoi metodi. Questo è il punto di tutta la risorsa.

    La conseguenza pratica è che non esiste desincronizzazione possibile.
    Uno script ESX che fa xPlayer.addMoney(500) e uno script AUREA che
    legge g:Saldo('contanti') vedono lo stesso numero nello stesso istante,
    perché è lo stesso numero. Non ci sono due copie da tenere allineate,
    non c'è un thread di sincronizzazione, non c'è una finestra in cui i
    due valori divergono.

    Il prezzo è che alcune cose che in ESX sono campi qui devono essere
    proprietà calcolate: xPlayer.job, xPlayer.accounts, xPlayer.inventory.
    Si risolve con un metatable __index che le costruisce al volo.
]]

local Xplayer = {}
Xplayer.__index = function(self, chiave)
    -- Prima i metodi
    local m = Xplayer[chiave]
    if m ~= nil then return m end

    -- Poi le proprietà calcolate, lette dal Giocatore vero
    local costruttore = rawget(Xplayer, '_proprieta')[chiave]
    if costruttore then return costruttore(self) end

    return nil
end

local xplayers = {}     -- [source] = xPlayer

-- ---------------------------------------------------------------------------
--  Accesso al Giocatore AUREA sottostante
-- ---------------------------------------------------------------------------
local function g(self)
    return AUREA.GetPlayer(self.source)
end

-- ---------------------------------------------------------------------------
--  Proprietà calcolate
-- ---------------------------------------------------------------------------
Xplayer._proprieta = {}

Xplayer._proprieta.identifier = function(self)
    local p = g(self); return p and p.citizenid or nil
end

Xplayer._proprieta.name = function(self)
    local p = g(self); return p and p:NomeCompleto() or 'Sconosciuto'
end

Xplayer._proprieta.group = function(self)
    local p = g(self); return ESXC.GruppoESX(p and p.gruppo or 'utente')
end

Xplayer._proprieta.job = function(self)
    return self:getJob()
end

Xplayer._proprieta.accounts = function(self)
    return self:getAccounts()
end

Xplayer._proprieta.inventory = function(self)
    return self:getInventory()
end

Xplayer._proprieta.loadout = function(self)
    return self:getLoadout()
end

Xplayer._proprieta.coords = function(self)
    return self:getCoords()
end

Xplayer._proprieta.maxWeight = function(self)
    return self:getMaxWeight()
end

--- ESX 1.10 tiene le variabili libere in xPlayer.variables.
Xplayer._proprieta.variables = function(self)
    local p = g(self)
    return p and p.metadata or {}
end

-- ---------------------------------------------------------------------------
--  Identità
-- ---------------------------------------------------------------------------
function Xplayer:getIdentifier()
    local p = g(self); return p and p.citizenid or nil
end

function Xplayer:getName()
    local p = g(self); return p and p:NomeCompleto() or 'Sconosciuto'
end

--- In AUREA il nome è l'anagrafe: non si cambia da uno script, si cambia
--- in Comune. Lo diciamo invece di far finta.
function Xplayer:setName()
    return ESX.NonImplementato('xPlayer.setName',
        'In AUREA il nome sta in anagrafe: si cambia da ita_comune, non da script.')
end

function Xplayer:getGroup()
    local p = g(self); return ESXC.GruppoESX(p and p.gruppo or 'utente')
end

function Xplayer:setGroup(gruppo)
    local p = g(self)
    if not p then return false end
    p.gruppo = ESXC.GruppoAurea(gruppo)
    MySQL.update('UPDATE account SET gruppo = ? WHERE id = ?', { p.gruppo, p.accountId })
    p:Sincronizza()
    return true
end

function Xplayer:getCoords(vettore)
    local ped = GetPlayerPed(self.source)
    local c = GetEntityCoords(ped)
    if vettore then return c end
    return { x = c.x, y = c.y, z = c.z, heading = GetEntityHeading(ped) }
end

function Xplayer:setCoords(coord)
    local x = coord.x or coord[1]
    local y = coord.y or coord[2]
    local z = coord.z or coord[3]
    local h = coord.heading or coord.w or coord[4] or 0.0
    TriggerClientEvent('esx:teleport', self.source, { x = x, y = y, z = z, heading = h })
end

function Xplayer:kick(motivo)
    DropPlayer(self.source, motivo or 'Espulso.')
end

function Xplayer:triggerEvent(evento, ...)
    TriggerClientEvent(evento, self.source, ...)
end

-- ---------------------------------------------------------------------------
--  Denaro
--
--  ESX parla in euro, AUREA in centesimi. La conversione sta tutta qui e
--  in config.lua: nessun altro punto della risorsa moltiplica per cento.
-- ---------------------------------------------------------------------------
function Xplayer:getMoney()
    local p = g(self)
    return p and ESXC.AEuro(p:Saldo('contanti')) or 0
end

function Xplayer:addMoney(euro, motivo)
    return self:addAccountMoney('money', euro, motivo)
end

function Xplayer:removeMoney(euro, motivo)
    return self:removeAccountMoney('money', euro, motivo)
end

function Xplayer:setMoney(euro, motivo)
    return self:setAccountMoney('money', euro, motivo)
end

--- Il saldo del nero, ricavato dalle banconote in tasca.
local function saldoNero(p)
    local inv = exports.aurea_inventory:Inventario(p.citizenid)
    if not inv then return 0 end
    return inv:Quantita(ESXC.Nero.oggetto) * ESXC.Nero.valoreUnita
end

function Xplayer:getAccount(nome)
    local p = g(self)
    if not p then return nil end

    if nome == 'black_money' then
        return { name = 'black_money', label = 'Contanti non tracciati',
                 money = ESXC.AEuro(saldoNero(p)), round = 0 }
    end

    local conto = ESXC.ContoAurea(nome)
    if not conto then return nil end

    return {
        name = nome,
        label = nome == 'bank' and 'Conto corrente' or 'Contanti',
        money = ESXC.AEuro(p:Saldo(conto)),
        round = 0,
    }
end

function Xplayer:getAccounts(minimale)
    local p = g(self)
    if not p then return {} end

    if minimale then
        return {
            money = ESXC.AEuro(p:Saldo('contanti')),
            bank = ESXC.AEuro(p:Saldo('banca')),
            black_money = ESXC.AEuro(saldoNero(p)),
        }
    end

    return {
        self:getAccount('money'),
        self:getAccount('bank'),
        self:getAccount('black_money'),
    }
end

function Xplayer:addAccountMoney(nome, euro, motivo)
    local p = g(self)
    if not p then return false end

    local centesimi = ESXC.ACentesimi(euro)
    if centesimi <= 0 then return false end

    if nome == 'black_money' then
        local unita = math.floor(centesimi / ESXC.Nero.valoreUnita)
        if unita <= 0 then
            if ESXC.Nero.avvisaArrotondamento then
                print(('[es_extended] addAccountMoney(black_money, %s) sotto il taglio di una banconota (%s): non aggiunto.')
                    :format(tostring(euro), AUREA.Util.Euro(ESXC.Nero.valoreUnita)))
            end
            return false
        end
        local inv = exports.aurea_inventory:Inventario(p.citizenid)
        if not inv:Aggiungi(ESXC.Nero.oggetto, unita) then return false end
        TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
        return true
    end

    local conto = ESXC.ContoAurea(nome)
    if not conto then return false end

    local ok = p:Aggiungi(conto, centesimi, motivo or 'ESX')
    if ok then
        TriggerClientEvent('esx:setAccountMoney', self.source, self:getAccount(nome))
    end
    return ok
end

function Xplayer:removeAccountMoney(nome, euro, motivo)
    local p = g(self)
    if not p then return false end

    local centesimi = ESXC.ACentesimi(euro)
    if centesimi <= 0 then return false end

    if nome == 'black_money' then
        local unita = math.floor(centesimi / ESXC.Nero.valoreUnita)
        if unita <= 0 then return false end
        local inv = exports.aurea_inventory:Inventario(p.citizenid)
        if not inv:Ha(ESXC.Nero.oggetto, unita) then return false end
        inv:Rimuovi(ESXC.Nero.oggetto, unita)
        TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
        return true
    end

    local conto = ESXC.ContoAurea(nome)
    if not conto then return false end

    local ok = p:Sottrai(conto, centesimi, motivo or 'ESX')
    if ok then
        TriggerClientEvent('esx:setAccountMoney', self.source, self:getAccount(nome))
    end
    return ok
end

--- ESX permette di piazzare un saldo assoluto. In AUREA non esiste un
--- "imposta il saldo" perché ogni movimento deve avere una causale e
--- finire nel registro: qui si calcola la differenza e si fa il movimento
--- corrispondente, così la traccia resta.
function Xplayer:setAccountMoney(nome, euro, motivo)
    local attuale = self:getAccount(nome)
    if not attuale then return false end

    local delta = ESXC.ACentesimi(euro) - ESXC.ACentesimi(attuale.money)
    if delta == 0 then return true end

    if delta > 0 then
        return self:addAccountMoney(nome, ESXC.AEuro(delta), motivo or 'rettifica ESX')
    end
    return self:removeAccountMoney(nome, ESXC.AEuro(-delta), motivo or 'rettifica ESX')
end

-- ---------------------------------------------------------------------------
--  Lavoro
-- ---------------------------------------------------------------------------
function Xplayer:getJob()
    local p = g(self)
    if not p then return { name = 'unemployed', grade = 0 } end

    local lavoro = AUREA.GetLavoro(p.lavoro.nome)
    local grado = AUREA.GetGrado(p.lavoro.nome, p.lavoro.grado)

    return {
        name = p.lavoro.nome,
        label = lavoro.etichetta,
        grade = p.lavoro.grado,
        grade_name = tostring(p.lavoro.grado),
        grade_label = grado.etichetta,
        grade_salary = math.floor(ESXC.AEuro(grado.stipendio or 0)),
        skin_male = {},
        skin_female = {},
        -- Non standard ma indispensabile: in AUREA "in servizio" è un
        -- concetto vero e mezzo server ci ragiona sopra.
        onDuty = p.lavoro.servizio,
    }
end

function Xplayer:setJob(nome, grado)
    local p = g(self)
    if not p then return false end

    if not AUREA.Lavori[nome] then
        print(('[es_extended] setJob("%s"): il lavoro non esiste nel catalogo AUREA. '
            .. 'Aggiungilo in aurea_core/shared/lavori.lua.'):format(tostring(nome)))
        return false
    end

    local ok = p:ImpostaLavoro(nome, tonumber(grado) or 0)
    if ok then
        TriggerClientEvent('esx:setJob', self.source, self:getJob())
        TriggerEvent('esx:setJob', self.source, self:getJob(), nil)
    end
    return ok
end

-- ---------------------------------------------------------------------------
--  Inventario
--
--  Passa tutto da aurea_inventory: gli slot, il peso e le metadata restano
--  quelli veri. Un oggetto unico con metadata (un'arma con la sua
--  matricola, un lotto con la sua purezza) resta tale anche visto da ESX,
--  che di metadata non sa niente ma non le distrugge.
-- ---------------------------------------------------------------------------
local function inventarioDi(p)
    return exports.aurea_inventory:Inventario(p.citizenid)
end

function Xplayer:getInventory(minimale)
    local p = g(self)
    if not p then return {} end

    local inv = inventarioDi(p)
    local pacchetto = inv:Pacchetto()

    if minimale then
        local out = {}
        for _, riga in ipairs(pacchetto.item or {}) do
            out[riga.nome] = (out[riga.nome] or 0) + riga.quantita
        end
        return out
    end

    -- Somma per nome: ESX ragiona per oggetto, non per slot
    local somma, ordine = {}, {}
    for _, riga in ipairs(pacchetto.item or {}) do
        if not somma[riga.nome] then
            somma[riga.nome] = {
                name = riga.nome,
                label = riga.etichetta,
                count = 0,
                weight = math.floor((riga.peso or 0) * ESXC.Inventario.fattorePeso),
                usable = riga.usabile or false,
                rare = 0,
                canRemove = true,
                -- Le metadata AUREA non hanno equivalente ESX: le passiamo
                -- come extra, chi le sa leggere le legge.
                metadata = riga.metadata,
                slot = riga.slot,
            }
            ordine[#ordine + 1] = somma[riga.nome]
        end
        somma[riga.nome].count = somma[riga.nome].count + riga.quantita
    end

    if ESXC.Inventario.includiAZero then
        for nome, dati in pairs(ESX.Items) do
            if not somma[nome] then
                ordine[#ordine + 1] = {
                    name = nome, label = dati.label, count = 0,
                    weight = dati.weight, usable = dati.usabile,
                    rare = dati.rare, canRemove = true,
                }
            end
        end
    end

    return ordine
end

function Xplayer:getInventoryItem(nome)
    local p = g(self)
    local dati = ESX.Items[nome]

    if not p or not dati then
        return { name = nome, label = nome, count = 0, weight = 0, usable = false, canRemove = true }
    end

    return {
        name = nome,
        label = dati.label,
        count = inventarioDi(p):Quantita(nome),
        weight = dati.weight,
        usable = dati.usabile,
        rare = dati.rare,
        canRemove = true,
    }
end

function Xplayer:addInventoryItem(nome, quantita, metadata)
    local p = g(self)
    if not p then return false end
    if not AUREA.Item[nome] then
        print(('[es_extended] addInventoryItem("%s"): oggetto non nel catalogo AUREA.'):format(tostring(nome)))
        return false
    end

    local inv = inventarioDi(p)
    local ok = inv:Aggiungi(nome, math.max(1, math.floor(tonumber(quantita) or 1)), metadata)
    if ok then
        TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
        TriggerClientEvent('esx:addInventoryItem', self.source, nome, quantita or 1)
    end
    return ok
end

function Xplayer:removeInventoryItem(nome, quantita, metadata)
    local p = g(self)
    if not p then return false end

    local inv = inventarioDi(p)
    local n = math.max(1, math.floor(tonumber(quantita) or 1))
    if not inv:Ha(nome, n) then return false end

    inv:Rimuovi(nome, n)
    TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
    TriggerClientEvent('esx:removeInventoryItem', self.source, nome, n)
    return true
end

--- ESX imposta la quantità assoluta. Si traduce in una differenza, come
--- per il denaro.
function Xplayer:setInventoryItem(nome, quantita)
    local p = g(self)
    if not p then return false end

    local attuale = inventarioDi(p):Quantita(nome)
    local voluta = math.max(0, math.floor(tonumber(quantita) or 0))

    if voluta > attuale then return self:addInventoryItem(nome, voluta - attuale) end
    if voluta < attuale then return self:removeInventoryItem(nome, attuale - voluta) end
    return true
end

function Xplayer:getWeight()
    local p = g(self)
    if not p then return 0 end
    return math.floor(inventarioDi(p):Peso() * ESXC.Inventario.fattorePeso)
end

function Xplayer:getMaxWeight()
    local p = g(self)
    if not p then return 0 end
    return math.floor((inventarioDi(p).pesoMax or 0) * ESXC.Inventario.fattorePeso)
end

function Xplayer:canCarryItem(nome, quantita)
    local p = g(self)
    local dati = AUREA.Item[nome]
    if not p or not dati then return false end

    local inv = inventarioDi(p)
    local peso = dati.peso * math.max(1, math.floor(tonumber(quantita) or 1))
    return (inv:Peso() + peso) <= inv.pesoMax and inv:SlotLibero() ~= nil
end

function Xplayer:canSwapItem(daNome, daQuantita, aNome, aQuantita)
    local p = g(self)
    if not p then return false end

    local inv = inventarioDi(p)
    if inv:Quantita(daNome) < daQuantita then return false end

    local esce = (AUREA.Item[daNome] and AUREA.Item[daNome].peso or 0) * daQuantita
    local entra = (AUREA.Item[aNome] and AUREA.Item[aNome].peso or 0) * aQuantita
    return (inv:Peso() - esce + entra) <= inv.pesoMax
end

function Xplayer:setMaxWeight(peso)
    local p = g(self)
    if not p then return false end
    local inv = inventarioDi(p)
    inv.pesoMax = math.floor(peso / ESXC.Inventario.fattorePeso)
    inv.sporco = true
    TriggerClientEvent('esx:setMaxWeight', self.source, peso)
    return true
end

-- ---------------------------------------------------------------------------
--  Armi
--
--  In AUREA un'arma è un oggetto d'inventario con la sua matricola, iscritta
--  al registro nazionale. L'API ESX delle armi è più povera: qui la si
--  serve senza rompere il registro, cioè creando armi vere.
-- ---------------------------------------------------------------------------
function Xplayer:getLoadout(minimale)
    local p = g(self)
    if not p then return {} end

    local out = {}
    for _, riga in ipairs(inventarioDi(p):Pacchetto().item or {}) do
        if riga.nome == 'arma' and riga.metadata and riga.metadata.arma then
            if minimale then
                out[riga.metadata.arma] = { ammo = riga.metadata.munizioni or 0 }
            else
                out[#out + 1] = {
                    name = riga.metadata.arma,
                    label = riga.metadata.nomeArma or riga.metadata.arma,
                    ammo = riga.metadata.munizioni or 0,
                    components = {},
                    tintIndex = 0,
                    -- non standard: qui un'arma ha un'identità
                    matricola = riga.metadata.matricola,
                }
            end
        end
    end
    return out
end

function Xplayer:hasWeapon(nomeArma)
    for _, a in ipairs(self:getLoadout()) do
        if a.name == nomeArma then return true end
    end
    return false
end

function Xplayer:getWeapon(nomeArma)
    for i, a in ipairs(self:getLoadout()) do
        if a.name == nomeArma then return i, a end
    end
    return nil, nil
end

function Xplayer:addWeapon(nomeArma, munizioni)
    local p = g(self)
    if not p then return false end

    -- Non si "dà un'arma" e basta: la si iscrive al registro. Se lo script
    -- ESX voleva un'arma pulita, quella clandestina è l'equivalente onesto.
    local ok = pcall(function()
        exports.aurea_armi:RegistraArma(p.citizenid, nomeArma, true)
    end)

    if not ok then
        print(('[es_extended] addWeapon("%s"): aurea_armi non ha risposto.'):format(tostring(nomeArma)))
        return false
    end

    if munizioni and munizioni > 0 then self:addWeaponAmmo(nomeArma, munizioni) end
    return true
end

function Xplayer:removeWeapon(nomeArma)
    local p = g(self)
    if not p then return false end

    local inv = inventarioDi(p)
    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if riga.nome == 'arma' and riga.metadata and riga.metadata.arma == nomeArma then
            inv:Rimuovi('arma', 1, riga.slot)
            TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
            return true
        end
    end
    return false
end

function Xplayer:addWeaponAmmo(nomeArma, quantita)
    local p = g(self)
    if not p then return false end

    local inv = inventarioDi(p)
    for _, riga in ipairs(inv.item) do
        if riga.nome == 'arma' and riga.metadata and riga.metadata.arma == nomeArma then
            riga.metadata.munizioni = (riga.metadata.munizioni or 0) + math.floor(quantita or 0)
            inv.sporco = true
            TriggerClientEvent('inv:aggiorna', self.source, inv:Pacchetto())
            return true
        end
    end
    return false
end

function Xplayer:removeWeaponAmmo(nomeArma, quantita)
    return self:addWeaponAmmo(nomeArma, -math.abs(quantita or 0))
end

function Xplayer:getWeaponComponent()
    return ESX.NonImplementato('xPlayer.getWeaponComponent', 'Le componenti arma non esistono in AUREA.')
end

function Xplayer:addWeaponComponent()
    return ESX.NonImplementato('xPlayer.addWeaponComponent')
end

function Xplayer:removeWeaponComponent()
    return ESX.NonImplementato('xPlayer.removeWeaponComponent')
end

-- ---------------------------------------------------------------------------
--  Metadata e variabili libere
-- ---------------------------------------------------------------------------
function Xplayer:set(chiave, valore)
    local p = g(self)
    if not p then return false end
    p:Set(chiave, valore, true)
    return true
end

function Xplayer:get(chiave)
    local p = g(self)
    return p and p:Get(chiave) or nil
end

--- ESX 1.10: metadata annidate.
function Xplayer:setMeta(chiave, valore, sottochiave)
    local p = g(self)
    if not p then return false end

    if sottochiave ~= nil then
        local t = p:Get(chiave)
        if type(t) ~= 'table' then t = {} end
        t[sottochiave] = valore
        p:Set(chiave, t, true)
        return true
    end

    p:Set(chiave, valore, true)
    return true
end

function Xplayer:getMeta(chiave, sottochiave)
    local p = g(self)
    if not p then return nil end

    local v = p:Get(chiave)
    if sottochiave ~= nil and type(v) == 'table' then return v[sottochiave] end
    return v
end

function Xplayer:clearMeta(chiave)
    local p = g(self)
    if not p then return false end
    p:Set(chiave, nil, true)
    return true
end

-- ---------------------------------------------------------------------------
--  Notifiche
-- ---------------------------------------------------------------------------
function Xplayer:showNotification(messaggio, lampeggia, durata)
    TriggerClientEvent('esx:showNotification', self.source, messaggio, lampeggia, durata)
end

function Xplayer:showAdvancedNotification(titolo, sottotitolo, messaggio, icona, tipo)
    TriggerClientEvent('esx:showAdvancedNotification', self.source,
        titolo, sottotitolo, messaggio, icona, tipo)
end

function Xplayer:showHelpNotification(messaggio, lampeggia, sonoro, durata)
    TriggerClientEvent('esx:showHelpNotification', self.source, messaggio, lampeggia, sonoro, durata)
end

-- ---------------------------------------------------------------------------
--  Registro
-- ---------------------------------------------------------------------------

--- Crea (o riusa) la facciata per una source.
function ESX.CostruisciXPlayer(src)
    src = tonumber(src)
    if not src then return nil end

    if xplayers[src] then return xplayers[src] end

    local x = setmetatable({ source = src, playerId = src }, Xplayer)
    xplayers[src] = x
    return x
end

function ESX.DimenticaXPlayer(src)
    xplayers[tonumber(src)] = nil
end

--- Serve a chi vuole aggiungere metodi propri a tutti gli xPlayer.
function ESX.EstendiXPlayer(nome, fn)
    Xplayer[nome] = fn
end
