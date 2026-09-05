--[[
    AUREA · Nucleo client
    Stato locale del personaggio e utilità condivise fra le risorse client.
]]

AUREA = AUREA or {}
AUREA.PG = nil               -- pacchetto dati del personaggio
AUREA.Caricato = false

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Sincronizzazione dal server
-- ---------------------------------------------------------------------------

RegisterNetEvent('aurea:giocatore:caricato', function(pacchetto, aspetto)
    AUREA.PG = pacchetto
    AUREA.Caricato = true
    TriggerEvent('aurea:client:caricato', pacchetto, aspetto)
end)

RegisterNetEvent('aurea:giocatore:aggiorna', function(pacchetto)
    AUREA.PG = pacchetto
    TriggerEvent('aurea:client:aggiornato', pacchetto)
end)

RegisterNetEvent('aurea:denaro:aggiorna', function(denaro)
    if not AUREA.PG then return end
    AUREA.PG.denaro = denaro
    TriggerEvent('aurea:client:denaro', denaro)
end)

RegisterNetEvent('aurea:stato:aggiorna', function(stato)
    if not AUREA.PG then return end
    AUREA.PG.stato = stato
    TriggerEvent('aurea:client:stato', stato)
end)

RegisterNetEvent('aurea:metadata:aggiorna', function(chiave, valore)
    if not AUREA.PG then return end
    AUREA.PG.metadata[chiave] = valore
    TriggerEvent('aurea:client:metadata', chiave, valore)
end)

-- ---------------------------------------------------------------------------
--  API client
-- ---------------------------------------------------------------------------

function AUREA.GetPG()
    return AUREA.PG
end

function AUREA.EInServizio()
    return AUREA.PG ~= nil and AUREA.PG.lavoro.servizio == true
end

function AUREA.HaLavoro(...)
    if not AUREA.PG then return false end
    for _, nome in ipairs({ ... }) do
        if AUREA.PG.lavoro.nome == nome then return true end
    end
    return false
end

exports('GetPG', AUREA.GetPG)
exports('EInServizio', AUREA.EInServizio)
exports('HaLavoro', AUREA.HaLavoro)

--- La tabella del framework, per le altre risorse.
--- Passa per riferimento fra risorse Lua: chi la riceve ha i metodi
--- dell'oggetto Giocatore e la tabella viva dei connessi, non una copia.
--- Si aggancia con '@aurea_core/bridge/aurea.lua'.
exports('Aurea', function() return AUREA end)


-- ---------------------------------------------------------------------------
--  Utilità grafiche riusabili
-- ---------------------------------------------------------------------------

--- Testo 3D nel mondo di gioco.
function AUREA.Testo3D(x, y, z, testo, scala)
    local suSchermo, sx, sy = World3dToScreen2d(x, y, z)
    if not suSchermo then return end
    local cam = GetGameplayCamCoords()
    local distanza = #(cam - vector3(x, y, z))
    local fattore = (1 / distanza) * 2 * (1 / GetGameplayCamFov()) * 100

    SetTextScale(0.0, (scala or 0.35) * fattore)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(testo)
    DrawText(sx, sy)

    local larghezza = (#testo / 370) + 0.01
    DrawRect(sx, sy + 0.0125, larghezza, 0.03, 12, 12, 14, 140)
end

--- Nome della strada/quartiere alla posizione indicata, in italiano.
local QUARTIERI = {
    ['AIRP'] = 'Aeroporto Internazionale', ['ALAMO'] = 'Lago Alamo', ['ALTA'] = 'Alta',
    ['BANNING'] = 'Banning', ['BEACH'] = 'Vespucci Beach', ['BURTON'] = 'Burton',
    ['CHAMH'] = 'Chamberlain Hills', ['CHIL'] = 'Vinewood Hills', ['CYPRE'] = 'Cypress Flats',
    ['DAVIS'] = 'Davis', ['DELBE'] = 'Del Perro Beach', ['DELPE'] = 'Del Perro',
    ['DELSOL'] = 'La Puerta', ['DOWNT'] = 'Centro', ['DTVINE'] = 'Downtown Vinewood',
    ['EAST_V'] = 'East Vinewood', ['ELYSIAN'] = 'Elysian Island', ['GALFISH'] = 'Galilee',
    ['GOLF'] = 'Golf Club', ['GRAPES'] = 'Grapeseed', ['HARMO'] = 'Harmony',
    ['HAWICK'] = 'Hawick', ['HORS'] = 'Vinewood Racetrack', ['LEGSQU'] = 'Legion Square',
    ['LOSPUER'] = 'La Puerta', ['MIRR'] = 'Mirror Park', ['MORN'] = 'Morningwood',
    ['MOVIE'] = 'Richards Majestic', ['MURRI'] = 'Monte Chiliad', ['PALCOV'] = 'Paleto Cove',
    ['PALETO'] = 'Paleto Bay', ['PBLUFF'] = 'Pacific Bluffs', ['PBOX'] = 'Pillbox Hill',
    ['PORT'] = 'Porto di Los Santos', ['RANCHO'] = 'Rancho', ['RGLEN'] = 'Richman Glen',
    ['RICHM'] = 'Richman', ['ROCKF'] = 'Rockford Hills', ['SANAND'] = 'San Andreas',
    ['SANDY'] = 'Sandy Shores', ['SKID'] = 'Mission Row', ['SLAB'] = 'Stab City',
    ['STAD'] = 'Stadio', ['STRAW'] = 'Strawberry', ['TEXTI'] = 'Textile City',
    ['VCANA'] = 'Vespucci Canals', ['VESP'] = 'Vespucci', ['VINE'] = 'Vinewood',
    ['WVINE'] = 'West Vinewood',
}

function AUREA.Indirizzo(coord)
    coord = coord or GetEntityCoords(PlayerPedId())
    local strada, incrocio = GetStreetNameAtCoord(coord.x, coord.y, coord.z)
    local nomeStrada = GetStreetNameFromHashKey(strada)
    local zona = GetNameOfZone(coord.x, coord.y, coord.z)
    local quartiere = QUARTIERI[zona] or GetLabelText(zona)

    if incrocio and incrocio ~= 0 then
        local nomeIncrocio = GetStreetNameFromHashKey(incrocio)
        if nomeIncrocio and nomeIncrocio ~= '' then
            return ('%s ang. %s, %s'):format(nomeStrada, nomeIncrocio, quartiere)
        end
    end
    return ('%s, %s'):format(nomeStrada, quartiere)
end

exports('Indirizzo', AUREA.Indirizzo)
exports('Testo3D', AUREA.Testo3D)

-- ---------------------------------------------------------------------------
--  Animazione con attesa del dizionario
-- ---------------------------------------------------------------------------
function AUREA.CaricaAnim(dizionario)
    if HasAnimDictLoaded(dizionario) then return true end
    RequestAnimDict(dizionario)
    local scadenza = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dizionario) do
        if GetGameTimer() > scadenza then return false end
        Wait(10)
    end
    return true
end

function AUREA.Anima(dizionario, nome, durata, flag)
    CreateThread(function()
        if not AUREA.CaricaAnim(dizionario) then return end
        TaskPlayAnim(PlayerPedId(), dizionario, nome, 3.0, -3.0, durata or -1, flag or 49, 0, false, false, false)
    end)
end

exports('Anima', AUREA.Anima)

-- ---------------------------------------------------------------------------
--  Teletrasporto amministrativo
-- ---------------------------------------------------------------------------
RegisterNetEvent('aurea:admin:teletrasporta', function(coord)
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    local entita = veicolo ~= 0 and veicolo or ped
    SetEntityCoords(entita, coord.x, coord.y, coord.z + 1.0, false, false, false, false)
end)

RegisterNetEvent('aurea:admin:teletrasportaMarker', function()
    local marker = GetFirstBlipInfoId(8)
    if not DoesBlipExist(marker) then
        return TriggerEvent('aurea:ui:notifica', { tipo = 'errore', titolo = 'Nessun marker', testo = 'Imposta un punto sulla mappa.' })
    end
    local coord = GetBlipInfoIdCoord(marker)
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    local entita = veicolo ~= 0 and veicolo or ped

    for z = 0, 1000, 25 do
        SetEntityCoords(entita, coord.x, coord.y, z + 0.0, false, false, false, false)
        Wait(20)
        local trovato, suolo = GetGroundZFor_3dCoord(coord.x, coord.y, z + 0.0, false)
        if trovato then
            SetEntityCoords(entita, coord.x, coord.y, suolo + 1.0, false, false, false, false)
            break
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Impostazioni ambientali di base (le sovrascrive ita_ambiente)
-- ---------------------------------------------------------------------------
CreateThread(function()
    SetDefaultVehicleNumberPlateTextPattern(-1, 'AA111AA')  -- targa italiana
    while true do
        Wait(1000)
        -- niente wanted level di GTA: il "ricercato" è gestito dal casellario
        local player = PlayerId()
        if GetPlayerWantedLevel(player) ~= 0 then
            SetPlayerWantedLevel(player, 0, false)
            SetPlayerWantedLevelNow(player, false)
        end
    end
end)
