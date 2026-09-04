--[[
    AUREA · HUD client
    Alimenta la NUI con lo stato del personaggio, del veicolo e dell'ambiente.
]]

local visibile = false
local cintureAllacciate = false
local ultimoVeicolo = 0

-- Limiti di velocità per contesto (km/h) come da Codice della Strada
local LIMITI = {
    urbano       = { valore = 50,  nota = 'Centro abitato' },
    extraurbano  = { valore = 90,  nota = 'Strada extraurbana' },
    scorrimento  = { valore = 110, nota = 'Strada di scorrimento' },
    autostrada   = { valore = 130, nota = 'Autostrada' },
    ztl          = { valore = 30,  nota = 'Zona 30' },
}

-- ---------------------------------------------------------------------------
--  Determinazione del limite in base alla zona e al tipo di strada
-- ---------------------------------------------------------------------------
local ZONE_AUTOSTRADA = {
    ['DESRT'] = true, ['SANAND'] = true, ['GRAPES'] = true, ['HARMO'] = true,
    ['PALFOR'] = true, ['MTCHIL'] = true, ['ZANCUDO'] = true,
}

local ZONE_URBANE = {
    ['DOWNT'] = true, ['LEGSQU'] = true, ['PBOX'] = true, ['TEXTI'] = true,
    ['SKID'] = true, ['MISSION'] = true, ['STRAW'] = true, ['DAVIS'] = true,
    ['RANCHO'] = true, ['CHAMH'] = true, ['VESP'] = true, ['VCANA'] = true,
    ['DELPE'] = true, ['MORN'] = true, ['ROCKF'] = true, ['RICHM'] = true,
    ['HAWICK'] = true, ['VINE'] = true, ['WVINE'] = true, ['DTVINE'] = true,
    ['MIRR'] = true, ['EAST_V'] = true, ['BURTON'] = true, ['ALTA'] = true,
}

--- Restituisce { valore, nota } per la posizione corrente.
function AUREA.LimiteVelocita(coord)
    local zona = GetNameOfZone(coord.x, coord.y, coord.z)

    -- ita_codicestrada può imporre un limite di zona (cantieri, ZTL, scuole)
    local imposto = LocalPlayer.state.limiteImposto
    if imposto then return { valore = imposto.valore, nota = imposto.nota } end

    if ZONE_URBANE[zona] then return LIMITI.urbano end
    if ZONE_AUTOSTRADA[zona] then
        -- sulle strade minori del deserto vale il limite extraurbano
        local suStrada = IsPointOnRoad(coord.x, coord.y, coord.z, 0)
        return suStrada and LIMITI.autostrada or LIMITI.extraurbano
    end
    return LIMITI.extraurbano
end

exports('LimiteVelocita', AUREA.LimiteVelocita)

-- ---------------------------------------------------------------------------
--  Orologio di gioco
-- ---------------------------------------------------------------------------
local function oraDiGioco()
    return ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
end

-- ---------------------------------------------------------------------------
--  Ciclo stato + portafoglio  (2 Hz è sufficiente)
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        if visibile and AUREA.PG then
            local ped = PlayerPedId()
            local stato = AUREA.PG.stato or {}
            local sottAcqua = IsPedSwimmingUnderWater(ped)

            SendNUIMessage({
                azione = 'stato',
                visibile = true,
                salute = math.max(0, ((GetEntityHealth(ped) - 100) / 100) * 100),
                armatura = GetPedArmour(ped),
                fame = stato.fame or 100,
                sete = stato.sete or 100,
                stress = stato.stress or 0,
                subacqueo = sottAcqua,
                ossigeno = sottAcqua and (GetPlayerUnderwaterTimeRemaining(PlayerId()) / 10) * 100 or 100,
            })

            SendNUIMessage({
                azione = 'portafoglio',
                visibile = true,
                contanti = AUREA.PG.denaro.contanti,
                banca = AUREA.PG.denaro.banca,
                lavoro = AUREA.PG.lavoroEtichetta,
                ora = oraDiGioco(),
            })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Ciclo cruscotto (ogni frame quando si è alla guida)
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 400
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if visibile and veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            attesa = 100

            if veicolo ~= ultimoVeicolo then
                ultimoVeicolo = veicolo
                cintureAllacciate = false
            end

            local kmh = GetEntitySpeed(veicolo) * 3.6
            local coord = GetEntityCoords(ped)
            local limite = AUREA.LimiteVelocita(coord)
            local eccesso = kmh > (limite.valore + 5)

            SendNUIMessage({
                azione = 'cruscotto',
                visibile = true,
                kmh = kmh,
                velocitaMax = GetVehicleEstimatedMaxSpeed(veicolo) * 3.6,
                marcia = GetIsVehicleEngineRunning(veicolo)
                    and (GetVehicleCurrentGear(veicolo) == 0 and 'R' or tostring(GetVehicleCurrentGear(veicolo)))
                    or 'N',
                carburante = GetVehicleFuelLevel(veicolo),
                motore = (GetVehicleEngineHealth(veicolo) / 1000) * 100,
                cinture = cintureAllacciate,
                fari = select(2, GetVehicleLightsState(veicolo)) == 1,
                limite = limite.valore,
                limiteNota = limite.nota,
                eccesso = eccesso,
            })

            -- Senza cintura, una frenata violenta proietta fuori dall'abitacolo
            if not cintureAllacciate and kmh > 60 then
                local velocita = GetEntitySpeed(veicolo)
                Wait(80)
                if GetEntitySpeed(veicolo) < velocita - 12.0 then
                    SetEntityCoords(ped, coord.x, coord.y, coord.z - 0.47, true, false, false, false)
                    SetEntityVelocity(ped, GetEntityVelocity(veicolo))
                    Wait(1)
                    SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
                    ApplyDamageToPed(ped, 22, false)
                end
            end
        elseif ultimoVeicolo ~= 0 then
            ultimoVeicolo = 0
            SendNUIMessage({ azione = 'cruscotto', visibile = false })
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Cintura di sicurezza (tasto B)
-- ---------------------------------------------------------------------------
RegisterCommand('cintura', function()
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    if veicolo == 0 then return end

    cintureAllacciate = not cintureAllacciate
    SetPedConfigFlag(ped, 32, not cintureAllacciate)   -- impedisce l'espulsione dal parabrezza
    PlaySoundFrontend(-1, cintureAllacciate and 'Faster_Click' or 'Menu_Back', 'RESPAWN_ONLINE_SOUNDSET', true)

    exports.aurea_ui:Notifica({
        tipo = cintureAllacciate and 'successo' or 'avviso',
        titolo = cintureAllacciate and 'Cintura allacciata' or 'Cintura slacciata',
        testo = cintureAllacciate and 'Buon viaggio.' or 'Art. 172 CdS: sanzione 83,00 € e 5 punti.',
        durata = 2600,
    })
end, false)
RegisterKeyMapping('cintura', 'Allaccia / slaccia la cintura', 'keyboard', 'B')

--- Espone lo stato della cintura a chi deve sanzionare (pattuglie, autovelox).
exports('CinturaAllacciata', function() return cintureAllacciate end)

-- ---------------------------------------------------------------------------
--  ZTL e patente: alimentate da ita_codicestrada
-- ---------------------------------------------------------------------------
RegisterNetEvent('aurea:hud:ztl', function(dati)
    SendNUIMessage({ azione = 'ztl', dentro = dati.dentro, nome = dati.nome, attiva = dati.attiva, autorizzato = dati.autorizzato })
end)
AddEventHandler('aurea:hud:ztl', function() end)

RegisterNetEvent('aurea:hud:patente', function(punti)
    SendNUIMessage({ azione = 'patente', visibile = punti ~= nil, punti = punti })
end)

-- ---------------------------------------------------------------------------
--  Visibilità
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    visibile = true
    DisplayRadar(true)
end)

RegisterNetEvent('aurea:hud:mostra', function(mostra)
    visibile = mostra and true or false
    if not visibile then SendNUIMessage({ azione = 'nascondiTutto' }) end
    DisplayRadar(visibile)
end)

RegisterCommand('hud', function()
    visibile = not visibile
    if not visibile then SendNUIMessage({ azione = 'nascondiTutto' }) end
    DisplayRadar(visibile)
end, false)

-- Nasconde i componenti nativi ridondanti di GTA
CreateThread(function()
    while true do
        Wait(0)
        HideHudComponentThisFrame(1)    -- wanted stars
        HideHudComponentThisFrame(2)    -- weapon icon
        HideHudComponentThisFrame(3)    -- cash
        HideHudComponentThisFrame(4)    -- mp cash
        HideHudComponentThisFrame(13)   -- cash change
        HideHudComponentThisFrame(17)
        HideHudComponentThisFrame(20)
        HideHudComponentThisFrame(21)
        HideHudComponentThisFrame(22)
    end
end)
