--[[
    AUREA · Garage (client)
]]

local U = AUREA.Util

CreateThread(function()
    for _, g in ipairs(GAR.Garage) do
        if g.blip then
            local blip = AddBlipForCoord(g.accesso.x, g.accesso.y, g.accesso.z)
            SetBlipSprite(blip, 357)
            SetBlipColour(blip, 3)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(g.nome)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Interazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local vicino = nil

        for _, g in ipairs(GAR.Garage) do
            if #(coord - g.accesso) < 12.0 then
                DrawMarker(36, g.accesso.x, g.accesso.y, g.accesso.z + 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.6, 0.6, 0.6, 31, 157, 85, 150, false, false, 2, true, nil, nil, false)
                attesa = 0
                if #(coord - g.accesso) < 2.4 then vicino = g end
            end
        end

        if vicino then
            local inVeicolo = GetVehiclePedIsIn(ped, false) ~= 0
            exports.aurea_ui:Prompt(true, inVeicolo and ('Ricovera in %s'):format(vicino.nome) or vicino.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                if inVeicolo then ricovera(vicino) else menuGarage(vicino) end
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Prelievo
-- ---------------------------------------------------------------------------
function menuGarage(garage)
    local veicoli = AUREA.Callback.Attendi('gar:elenco', garage.id) or {}

    if #veicoli == 0 then
        return exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🅿',
            titolo = garage.nome,
            testo = garage.soloDissequestro and 'Nessun tuo veicolo in custodia.' or 'Non hai veicoli ricoverati qui.',
        })
    end

    local voci = {}
    for _, v in ipairs(veicoli) do
        local problemi = {}
        if v.bolloScaduto then problemi[#problemi + 1] = 'bollo' end
        if v.revisioneScaduta then problemi[#problemi + 1] = 'revisione' end
        if not v.assicurato then problemi[#problemi + 1] = 'RCA' end

        voci[#voci + 1] = {
            id = v.targa,
            icona = v.giaFuori and '🚦' or (#problemi > 0 and '⚠' or '🚗'),
            titolo = ('%s — %s'):format(v.targa, v.nome),
            descrizione = ('Carburante %d%% · motore %d%% · %d km%s'):format(
                math.floor(v.carburante or 0),
                math.floor((v.motore or 1000) / 10),
                v.km or 0,
                #problemi > 0 and (' · irregolare: ' .. table.concat(problemi, ', ')) or ''),
            valore = v.giaFuori and 'in circolazione' or 'disponibile',
            disattivata = v.giaFuori,
        }
    end

    local targa = exports.aurea_ui:Menu({
        titolo = garage.nome,
        sottotitolo = ('%d veicoli ricoverati'):format(#veicoli),
        voci = voci,
    })
    if not targa then return end

    local ok, avviso, dati = AUREA.Callback.Attendi('gar:preleva', targa, garage.id)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Prelievo rifiutato', testo = avviso, durata = 9000 })
    end

    generaVeicolo(garage, dati)
    if avviso then
        exports.aurea_ui:Notifica({ tipo = 'avviso', icona = '⚠', titolo = 'Veicolo non in regola', testo = avviso, durata = 12000 })
    end
end

--- Trova un'uscita libera e vi materializza il veicolo.
function generaVeicolo(garage, dati)
    local uscita
    for _, u in ipairs(garage.uscite) do
        if IsPositionOccupied(u.x, u.y, u.z, 2.6, false, true, false, false, false, 0, false) == false then
            uscita = u break
        end
    end
    if not uscita then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Uscita occupata',
            testo = 'Libera lo spazio davanti al garage e riprova.',
        })
    end

    local hash = GetHashKey(dati.modello)
    RequestModel(hash)
    local scadenza = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end
    if not HasModelLoaded(hash) then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Modello non disponibile', testo = dati.modello })
    end

    local veicolo = CreateVehicle(hash, uscita.x, uscita.y, uscita.z, uscita.w, true, false)
    SetModelAsNoLongerNeeded(hash)

    SetVehicleNumberPlateText(veicolo, dati.targa)
    SetVehicleFuelLevel(veicolo, dati.carburante + 0.0)
    SetVehicleEngineHealth(veicolo, dati.motore + 0.0)
    SetVehicleBodyHealth(veicolo, dati.carrozzeria + 0.0)
    SetVehicleDirtLevel(veicolo, 4.0)
    SetVehicleHasBeenOwnedByPlayer(veicolo, true)
    SetVehicleDoorsLocked(veicolo, 1)

    if dati.proprieta then applicaProprieta(veicolo, dati.proprieta) end

    SetPedIntoVehicle(PlayerPedId(), veicolo, -1)
    SetVehicleEngineOn(veicolo, true, true, false)

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🔑',
        titolo = 'Veicolo prelevato', testo = ('%s pronto all\'uscita.'):format(dati.targa),
    })
end

function applicaProprieta(veicolo, p)
    if p.colorePrimario then SetVehicleColours(veicolo, p.colorePrimario, p.coloreSecondario or p.colorePrimario) end
    if p.coloreCerchi then SetVehicleExtraColours(veicolo, p.colorePerla or 0, p.coloreCerchi) end
    if p.livrea then SetVehicleLivery(veicolo, p.livrea) end
    if p.finestrini then SetVehicleWindowTint(veicolo, p.finestrini) end
    if p.mod then
        SetVehicleModKit(veicolo, 0)
        for indice, valore in pairs(p.mod) do
            SetVehicleMod(veicolo, tonumber(indice), valore, false)
        end
    end
    if p.turbo then ToggleVehicleMod(veicolo, 18, true) end
end

--- Legge le personalizzazioni per il salvataggio.
function leggiProprieta(veicolo)
    local mod = {}
    for i = 0, 48 do
        local valore = GetVehicleMod(veicolo, i)
        if valore ~= -1 then mod[tostring(i)] = valore end
    end
    local primario, secondario = GetVehicleColours(veicolo)
    local perla, cerchi = GetVehicleExtraColours(veicolo)

    return {
        colorePrimario = primario, coloreSecondario = secondario,
        colorePerla = perla, coloreCerchi = cerchi,
        finestrini = GetVehicleWindowTint(veicolo),
        livrea = GetVehicleLivery(veicolo),
        turbo = IsToggleModOn(veicolo, 18),
        mod = mod,
    }
end

-- ---------------------------------------------------------------------------
--  Ricovero
-- ---------------------------------------------------------------------------
function ricovera(garage)
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    if veicolo == 0 then return end

    if GetPedInVehicleSeat(veicolo, -1) ~= ped then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Non sei alla guida', testo = 'Solo il conducente può ricoverare il veicolo.' })
    end

    local ok, messaggio = AUREA.Callback.Attendi('gar:ricovera', {
        targa = GetVehicleNumberPlateText(veicolo),
        garage = garage.id,
        carburante = GetVehicleFuelLevel(veicolo),
        motore = GetVehicleEngineHealth(veicolo),
        carrozzeria = GetVehicleBodyHealth(veicolo),
        km = LocalPlayer.state.kmVeicolo or 0,
    })

    if ok then
        -- si salvano anche le personalizzazioni correnti
        TriggerServerEvent('gar:salvaProprieta', GetVehicleNumberPlateText(veicolo), leggiProprieta(veicolo))
        local passeggeri = GetVehicleNumberOfPassengers(veicolo)
        for s = -1, passeggeri do
            local occupante = GetPedInVehicleSeat(veicolo, s)
            if occupante ~= 0 then TaskLeaveVehicle(occupante, veicolo, 0) end
        end
        Wait(900)
        DeleteVehicle(veicolo)
    end

    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        icona = '🅿', titolo = ok and 'Veicolo ricoverato' or 'Ricovero rifiutato',
        testo = messaggio, durata = 8000,
    })
end
