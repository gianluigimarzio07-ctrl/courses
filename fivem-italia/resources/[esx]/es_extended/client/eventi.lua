--[[
    ESX su AUREA — eventi lato client

    Tiene ESX.PlayerData allineato ad AUREA.PG e riemette gli eventi ESX nel
    momento in cui gli script se li aspettano.
]]

-- ---------------------------------------------------------------------------
--  Ingresso in gioco
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:playerLoaded', function(dati, saltaSpawn)
    ESX.PlayerData = dati or {}
    ESX.PlayerLoaded = true
end)

--- La verità è AUREA.PG: quando quella cambia, si ricompone.
AddEventHandler('aurea:client:caricato', function()
    ESX.RicomponiPlayerData()
    ESX.PlayerLoaded = true
end)

AddEventHandler('aurea:client:aggiornato', function()
    ESX.RicomponiPlayerData()
end)

AddEventHandler('aurea:client:denaro', function()
    ESX.RicomponiPlayerData()
end)

AddEventHandler('aurea:client:metadata', function()
    ESX.RicomponiPlayerData()
end)

-- ---------------------------------------------------------------------------
--  Lavoro
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:setJob', function(lavoro)
    ESX.PlayerData.job = lavoro
end)

-- ---------------------------------------------------------------------------
--  Denaro
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:setAccountMoney', function(conto)
    if not conto then return end

    for i, c in ipairs(ESX.PlayerData.accounts or {}) do
        if c.name == conto.name then
            ESX.PlayerData.accounts[i] = conto
            if conto.name == 'money' then ESX.PlayerData.money = conto.money end
            return
        end
    end

    ESX.PlayerData.accounts = ESX.PlayerData.accounts or {}
    ESX.PlayerData.accounts[#ESX.PlayerData.accounts + 1] = conto
end)

-- ---------------------------------------------------------------------------
--  Inventario
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:addInventoryItem', function(nome, quantita, silenzioso)
    -- aurea_inventory manda già la sua notifica: qui si aggiorna solo la
    -- copia locale che gli script ESX leggono.
    for _, i in ipairs(ESX.PlayerData.inventory or {}) do
        if i.name == nome then i.count = (i.count or 0) + (quantita or 1) return end
    end

    ESX.PlayerData.inventory = ESX.PlayerData.inventory or {}
    ESX.PlayerData.inventory[#ESX.PlayerData.inventory + 1] = {
        name = nome,
        label = ESX.GetItemLabel(nome),
        count = quantita or 1,
        weight = (ESX.Items[nome] and ESX.Items[nome].weight) or 0,
        usable = (ESX.Items[nome] and ESX.Items[nome].usabile) or false,
        canRemove = true,
    }
end)

RegisterNetEvent('esx:removeInventoryItem', function(nome, quantita)
    for i, riga in ipairs(ESX.PlayerData.inventory or {}) do
        if riga.name == nome then
            riga.count = math.max(0, (riga.count or 0) - (quantita or 1))
            if riga.count == 0 then table.remove(ESX.PlayerData.inventory, i) end
            return
        end
    end
end)

RegisterNetEvent('esx:setMaxWeight', function(peso)
    ESX.PlayerData.maxWeight = peso
end)

--- Quando aurea_inventory manda l'inventario vero, si ricostruisce quello
--- ESX da lì: è la fonte, e va sempre preferita alle somme incrementali.
RegisterNetEvent('inv:aggiorna', function(pacchetto)
    if type(pacchetto) ~= 'table' then return end

    local somma, ordine = {}, {}
    for _, riga in ipairs(pacchetto.item or {}) do
        if not somma[riga.nome] then
            somma[riga.nome] = {
                name = riga.nome, label = riga.etichetta, count = 0,
                weight = riga.peso or 0, usable = riga.usabile or false,
                canRemove = true, metadata = riga.metadata, slot = riga.slot,
            }
            ordine[#ordine + 1] = somma[riga.nome]
        end
        somma[riga.nome].count = somma[riga.nome].count + riga.quantita
    end

    ESX.PlayerData.inventory = ordine
end)

-- ---------------------------------------------------------------------------
--  Notifiche
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:showNotification', function(messaggio, lampeggia, durata)
    ESX.ShowNotification(messaggio, lampeggia, durata)
end)

RegisterNetEvent('esx:showAdvancedNotification', function(titolo, sottotitolo, messaggio, icona, tipo)
    ESX.ShowAdvancedNotification(titolo, sottotitolo, messaggio, icona, tipo)
end)

RegisterNetEvent('esx:showHelpNotification', function(messaggio, lampeggia, sonoro, durata)
    ESX.ShowHelpNotification(messaggio, lampeggia, sonoro, durata)
end)

-- ---------------------------------------------------------------------------
--  Teletrasporto e veicoli
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:teleport', function(coord)
    ESX.Game.Teleport(PlayerPedId(), coord)
end)

RegisterNetEvent('esx:spawnVehicle', function(modello, coord, direzione)
    ESX.Game.SpawnVehicle(modello, coord or GetEntityCoords(PlayerPedId()), direzione or 0.0,
        function(veicolo)
            if veicolo then
                TaskWarpPedIntoVehicle(PlayerPedId(), veicolo, -1)
            end
        end)
end)

RegisterNetEvent('esx:applicaProprietaVeicolo', function(reteId, proprieta)
    local scadenza = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(reteId) and GetGameTimer() < scadenza do Wait(0) end
    if not NetworkDoesEntityExistWithNetworkId(reteId) then return end

    local veicolo = NetworkGetEntityFromNetworkId(reteId)
    ESX.Game.SetVehicleProperties(veicolo, proprieta)
end)

-- ---------------------------------------------------------------------------
--  Uscita
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:onPlayerLogout', function()
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}
    ESX.UI.Menu.CloseAll()
end)

-- ---------------------------------------------------------------------------
--  Uso degli oggetti dall'inventario AUREA
--
--  Se uno script ESX ha registrato un uso con ESX.RegisterUsableItem, la
--  chiamata è già arrivata al server tramite il registro di
--  aurea_inventory. Qui si copre solo il caso opposto: uno script client
--  che emette esx:useItem di sua iniziativa.
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:useItem', function(nome)
    TriggerServerEvent('esx:useItem', nome)
end)
