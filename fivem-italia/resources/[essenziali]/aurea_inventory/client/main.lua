--[[
    AUREA · Inventario (client)
]]

local aperto = false
local mioInventario = nil
local mucchi = {}          -- [id] = { coord }

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
local function apri(richiesta)
    if aperto then return end
    if IsPedDeadOrDying(PlayerPedId(), true) then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Non ora', testo = 'Non puoi aprire l\'inventario in questo stato.' })
    end

    local dati = AUREA.Callback.Attendi('inv:apri', richiesta)
    if not dati then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Inventario non disponibile', testo = 'Riprova fra un istante.' })
    end

    aperto = true
    mioInventario = dati.primario
    SetNuiFocus(true, true)
    SendNUIMessage({
        azione = 'apri',
        primario = dati.primario,
        secondario = dati.secondario,
        etichettaSecondaria = dati.etichettaSecondaria,
    })
end

exports('Apri', apri)

RegisterCommand('inventario', function()
    if aperto then return end
    CreateThread(function()
        -- il bagagliaio si apre se si è dietro a un veicolo vicino
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo == 0 then
            veicolo = GetClosestVehicle(coord.x, coord.y, coord.z, 4.0, 0, 71)
            if veicolo ~= 0 then
                local retro = GetOffsetFromEntityInWorldCoords(veicolo, 0.0, -2.4, 0.0)
                if #(coord - retro) > 2.0 then veicolo = 0 end
            end
        end

        -- un mucchio a terra ha la precedenza
        for id, m in pairs(mucchi) do
            if #(coord - m.coord) < 1.6 then
                return apri({ tipo = 'terra', id = id, etichetta = 'Oggetti a terra' })
            end
        end

        if veicolo ~= 0 then
            local classe = GetVehicleClass(veicolo)
            -- moto e sportive hanno poco spazio, i furgoni molto
            local capienza = (classe == 8) and 5 or (classe == 17 or classe == 6) and 12
                or (classe == 10 or classe == 11 or classe == 12) and 45 or 25
            local pesoMax = capienza * 2500

            local c = GetEntityCoords(veicolo)
            return apri({
                tipo = 'veicolo',
                targa = GetVehicleNumberPlateText(veicolo),
                capienza = capienza, pesoMax = pesoMax,
                coord = { x = c.x, y = c.y, z = c.z },
                etichetta = ('Bagagliaio · %s'):format(GetVehicleNumberPlateText(veicolo)),
            })
        end

        apri(nil)
    end)
end, false)
RegisterKeyMapping('inventario', 'Apri l\'inventario', 'keyboard', 'TAB')

RegisterNetEvent('inv:apriContenitore', function(slot)
    CreateThread(function()
        apri({ tipo = 'contenitore', slot = slot, etichetta = 'Contenitore' })
    end)
end)

--- Apertura di un contenitore gestito da un'altra risorsa (cassaforte, deposito).
RegisterNetEvent('inv:apriEsterno', function(id, opzioni)
    CreateThread(function()
        apri({
            tipo = 'esterno', id = id,
            capienza = opzioni and opzioni.capienza,
            pesoMax = opzioni and opzioni.pesoMax,
            tipoContenitore = opzioni and opzioni.tipo,
            etichetta = opzioni and opzioni.etichetta or 'Deposito',
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Callback NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('chiudi', function(_, cb)
    aperto = false
    SetNuiFocus(false, false)
    TriggerServerEvent('inv:chiudi')
    cb({ ok = true })
end)

RegisterNUICallback('sposta', function(dati, cb)
    local ok, motivo, pacchetti = AUREA.Callback.Attendi('inv:sposta', dati)
    if not ok and motivo then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Spostamento non riuscito', testo = motivo, durata = 4000 })
    end
    if pacchetti then
        mioInventario = pacchetti.primario
        SendNUIMessage({ azione = 'aggiorna', primario = pacchetti.primario, secondario = pacchetti.secondario })
    end
    cb({ ok = ok })
end)

RegisterNUICallback('usa', function(dati, cb)
    local ok, motivo = AUREA.Callback.Attendi('inv:usa', dati.slot)
    if not ok and motivo then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Non utilizzabile', testo = motivo, durata = 4000 })
    end
    cb({ ok = ok })
end)

RegisterNUICallback('getta', function(dati, cb)
    local ok, motivo = AUREA.Callback.Attendi('inv:getta', dati.slot, dati.quantita)
    if not ok and motivo then
        exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Impossibile gettare', testo = motivo, durata = 4000 })
    else
        AUREA.Anima('pickup_object', 'putdown_low', 1200, 48)
    end
    cb({ ok = ok })
end)

-- ---------------------------------------------------------------------------
--  Aggiornamenti dal server
-- ---------------------------------------------------------------------------
RegisterNetEvent('inv:aggiorna', function(pacchetto)
    mioInventario = pacchetto
    if aperto then
        SendNUIMessage({ azione = 'aggiorna', primario = pacchetto })
    end
end)

RegisterNetEvent('inv:variazione', function(v)
    exports.aurea_ui:Notifica({
        tipo = v.verso == 'entrata' and 'successo' or 'info',
        icona = v.verso == 'entrata' and '＋' or '－',
        titolo = ('%s %dx %s'):format(v.verso == 'entrata' and 'Ricevuto' or 'Rimosso', v.quantita, v.etichetta),
        durata = 3200,
    })
end)

--- Espone l'inventario alle altre risorse client (per condizioni rapide).
exports('Ha', function(nome, quantita)
    if not mioInventario then return false end
    local totale = 0
    for _, i in ipairs(mioInventario.item) do
        if i.nome == nome then totale = totale + i.quantita end
    end
    return totale >= (quantita or 1)
end)

--- Le righe di un oggetto, metadata comprese: serve a chi deve mostrare
--- un elenco (i reperti della Scientifica, le ricette del banco da lavoro)
--- senza fare un giro sul server per compilare un menu.
exports('Righe', function(nome)
    local out = {}
    if not mioInventario then return out end
    for _, i in ipairs(mioInventario.item) do
        if i.nome == nome then out[#out + 1] = i end
    end
    return out
end)

-- ---------------------------------------------------------------------------
--  Oggetti a terra
-- ---------------------------------------------------------------------------
RegisterNetEvent('inv:mucchioCreato', function(id, coord)
    mucchi[id] = { coord = vector3(coord.x, coord.y, coord.z) }
end)

RegisterNetEvent('inv:mucchioRimosso', function(id)
    mucchi[id] = nil
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(2500)
        local elenco = AUREA.Callback.Attendi('inv:mucchi') or {}
        for _, m in ipairs(elenco) do
            mucchi[m.id] = { coord = vector3(m.coord.x, m.coord.y, m.coord.z) }
        end
    end)
end)

-- Marcatore e prompt sui mucchi vicini
CreateThread(function()
    while true do
        local attesa = 800
        local coord = GetEntityCoords(PlayerPedId())
        local vicino = false

        for _, m in pairs(mucchi) do
            local d = #(coord - m.coord)
            if d < 12.0 then
                attesa = 0
                DrawMarker(2, m.coord.x, m.coord.y, m.coord.z + 0.18, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                    0.22, 0.22, 0.16, 212, 175, 55, 170, false, false, 2, true, nil, nil, false)
                if d < 1.6 then vicino = true end
            end
        end

        if vicino and not aperto then
            exports.aurea_ui:Prompt(true, 'Oggetti a terra', 'TAB')
        end

        Wait(attesa)
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
