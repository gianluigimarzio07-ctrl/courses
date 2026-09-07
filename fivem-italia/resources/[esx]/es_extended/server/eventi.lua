--[[
    ESX su AUREA — eventi lato server

    Traduce il ciclo di vita AUREA in quello ESX. Uno script ESX che
    aspetta esx:playerLoaded lo riceve nel momento giusto senza sapere
    niente di AUREA, e viceversa.

    Va detta una cosa sull'ordine. AUREA emette aurea:giocatore:caricato
    quando il personaggio è già costruito e completo. Noi ci agganciamo lì:
    quindi quando parte esx:playerLoaded, l'xPlayer è già del tutto valido,
    denaro e lavoro compresi. In ESX vero c'è una finestra in cui certe
    cose non ci sono ancora; qui no.
]]

-- ---------------------------------------------------------------------------
--  Entrata in gioco
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    local x = ESX.CostruisciXPlayer(src)

    -- Il pacchetto che ESX manda al client
    local dati = {
        identifier = g.citizenid,
        accounts = x:getAccounts(),
        inventory = x:getInventory(),
        job = x:getJob(),
        loadout = x:getLoadout(),
        firstName = g.nome,
        lastName = g.cognome,
        dateofbirth = g.dataNascita,
        sex = g.sesso,
        height = 180,
        group = x:getGroup(),
        money = x:getMoney(),
        maxWeight = x:getMaxWeight(),
        metadata = g.metadata,
        -- Non standard, ma è l'identità vera del personaggio e vale la
        -- pena che uno script ci possa arrivare.
        codiceFiscale = g.cf,
        telefono = g.telefono,
    }

    TriggerClientEvent('esx:playerLoaded', src, dati, false)
    TriggerEvent('esx:playerLoaded', src, x, false)
end)

-- ---------------------------------------------------------------------------
--  Uscita
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giocatore:scaricato', function(src, g)
    local x = ESX.CostruisciXPlayer(src)
    TriggerEvent('esx:playerDropped', src, x)
    TriggerEvent('esx:onPlayerLogout', src)
    ESX.DimenticaXPlayer(src)
end)

AddEventHandler('playerDropped', function()
    ESX.DimenticaXPlayer(source)
end)

-- ---------------------------------------------------------------------------
--  Lavoro e servizio
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:lavoro:cambiato', function(src)
    local x = ESX.GetPlayerFromId(src)
    if not x then return end
    TriggerClientEvent('esx:setJob', src, x:getJob())
end)

AddEventHandler('aurea:servizio:cambiato', function(src)
    local x = ESX.GetPlayerFromId(src)
    if not x then return end
    -- ESX non ha il servizio: lo si comunica dentro il job, dove i pochi
    -- script che lo usano se lo aspettano.
    TriggerClientEvent('esx:setJob', src, x:getJob())
end)

-- ---------------------------------------------------------------------------
--  Denaro
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:denaro:variato', function(src, conto)
    local x = ESX.GetPlayerFromId(src)
    if not x then return end

    local nomeESX = conto == 'contanti' and 'money' or (conto == 'banca' and 'bank' or nil)
    if not nomeESX then return end

    TriggerClientEvent('esx:setAccountMoney', src, x:getAccount(nomeESX))
end)

-- ---------------------------------------------------------------------------
--  Eventi in entrata: uno script ESX che chiede qualcosa al server
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:onPlayerJoined', function()
    -- In AUREA l'ingresso lo governa aurea_core con la selezione del
    -- personaggio: non c'è niente da fare qui, ma l'evento deve esistere
    -- perché qualche script lo emette.
end)

RegisterNetEvent('esx:useItem', function(nome)
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not x then return end
    if x:getInventoryItem(nome).count < 1 then return end
    ESX.UseItem(src, nome)
end)

RegisterNetEvent('esx:giveInventoryItem', function(destinatario, tipo, nome, quantita)
    local src = source
    local mittente = ESX.GetPlayerFromId(src)
    local ricevente = ESX.GetPlayerFromId(destinatario)
    if not mittente or not ricevente then return end

    local distanza = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(destinatario)))
    if distanza > 3.0 then return end

    if tipo == 'item_standard' then
        quantita = math.max(1, math.floor(tonumber(quantita) or 1))
        if not ricevente:canCarryItem(nome, quantita) then
            return mittente:showNotification('Non ha spazio per riceverlo.')
        end
        if mittente:removeInventoryItem(nome, quantita) then
            ricevente:addInventoryItem(nome, quantita)
        end

    elseif tipo == 'item_account' then
        local importo = tonumber(quantita) or 0
        if mittente:removeAccountMoney(nome, importo, 'consegna a mano') then
            ricevente:addAccountMoney(nome, importo, 'ricevuto a mano')
        end

    elseif tipo == 'item_weapon' then
        if mittente:removeWeapon(nome) then
            ricevente:addWeapon(nome, quantita or 0)
        end
    end
end)

RegisterNetEvent('esx:removeInventoryItem', function(tipo, nome, quantita)
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not x then return end

    if tipo == 'item_standard' then
        x:removeInventoryItem(nome, quantita)
    elseif tipo == 'item_account' then
        x:removeAccountMoney(nome, quantita, 'gettato')
    elseif tipo == 'item_weapon' then
        x:removeWeapon(nome)
    end
end)

-- ---------------------------------------------------------------------------
--  Export di comodo
--
--  Alcuni script preferiscono le export ai metodi.
-- ---------------------------------------------------------------------------
exports('GetPlayerFromId', function(src) return ESX.GetPlayerFromId(src) end)
exports('GetPlayerFromIdentifier', function(id) return ESX.GetPlayerFromIdentifier(id) end)
exports('GetPlayers', function() return ESX.GetPlayers() end)
exports('GetExtendedPlayers', function(k, v) return ESX.GetExtendedPlayers(k, v) end)
