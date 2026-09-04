--[[
    AUREA · Lavori (client) — Centro per l'Impiego, turni, officina
]]

local U = AUREA.Util

CreateThread(function()
    local c = LAV.CentroImpiego
    local blip = AddBlipForCoord(c.coord.x, c.coord.y, c.coord.z)
    SetBlipSprite(blip, c.blip.sprite)
    SetBlipColour(blip, c.blip.colore)
    SetBlipScale(blip, c.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(c.nome)
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - LAV.CentroImpiego.coord) < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, LAV.CentroImpiego.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuImpiego()
            end
        else
            local punto = LAV.PuntoTurno(AUREA.PG and AUREA.PG.lavoro.nome or '')
            if punto and #(coord - punto.coord) < 2.4 then
                attesa = 0
                exports.aurea_ui:Prompt(true, punto.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuTurno(punto)
                end
            else
                exports.aurea_ui:Prompt(false)
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Centro per l'Impiego
-- ---------------------------------------------------------------------------
function menuImpiego()
    local offerte = AUREA.Callback.Attendi('lav:disponibili') or {}

    local voci = {}
    for _, o in ipairs(offerte) do
        voci[#voci + 1] = {
            id = o.nome,
            icona = o.attuale and '✅' or '💼',
            titolo = o.etichetta,
            descrizione = ('Posizione iniziale: %s'):format(o.mansione),
            valore = ('%s / ciclo'):format(U.Euro(o.stipendio)),
            disattivata = o.attuale,
        }
    end

    if AUREA.PG and AUREA.PG.lavoro.nome ~= 'disoccupato' then
        voci[#voci + 1] = { id = '__dimissioni', icona = '📤', titolo = 'Rassegna le dimissioni',
            descrizione = 'Tornerai disoccupato e riceverai il sussidio.' }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = LAV.CentroImpiego.nome,
        sottotitolo = 'Offerte disponibili senza colloquio',
        voci = voci,
    })
    if not scelta then return end

    local ok, messaggio
    if scelta == '__dimissioni' then
        ok, messaggio = AUREA.Callback.Attendi('lav:dimissioni')
    else
        ok, messaggio = AUREA.Callback.Attendi('lav:assumi', scelta)
    end

    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        icona = '💼', titolo = ok and 'Contratto aggiornato' or 'Operazione rifiutata',
        testo = messaggio, durata = 8000,
    })
end

-- ---------------------------------------------------------------------------
--  Turno di lavoro
-- ---------------------------------------------------------------------------
function menuTurno(punto)
    local lavoro = AUREA.PG.lavoro.nome

    local voci = {}
    if punto.veicolo then
        voci[#voci + 1] = { id = 'mezzo', icona = '🚐', titolo = 'Preleva il mezzo di servizio',
            descrizione = 'Ti serve per svolgere gli incarichi.' }
    end

    if lavoro == 'corriere' then
        voci[#voci + 1] = { id = 'consegna', icona = '📦', titolo = 'Ritira un carico',
            descrizione = 'Consegna entro il tempo previsto per il bonus puntualità.' }
    elseif lavoro == 'tassista' then
        voci[#voci + 1] = { id = 'corsa', icona = '🚕', titolo = 'Metti il taxi in servizio',
            descrizione = 'La centrale ti assegna una corsa.' }
    elseif lavoro == 'meccanico' then
        voci[#voci + 1] = { id = 'ripara', icona = '🔧', titolo = 'Ripara il veicolo davanti a te',
            descrizione = 'Ripristina motore e carrozzeria.' }
    end

    voci[#voci + 1] = { id = 'fine', icona = '🏁', titolo = 'Riponi il mezzo e chiudi il turno' }

    local scelta = exports.aurea_ui:Menu({
        titolo = punto.nome,
        sottotitolo = AUREA.PG.lavoroEtichetta,
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'mezzo' then
        prelevaMezzo(punto)
    elseif scelta == 'consegna' then
        TriggerEvent('lav:avviaConsegna')
    elseif scelta == 'corsa' then
        TriggerEvent('lav:avviaCorsa')
    elseif scelta == 'ripara' then
        riparaVicino()
    elseif scelta == 'fine' then
        TriggerEvent('lav:chiudiTurno')
    end
end

function prelevaMezzo(punto)
    local hash = GetHashKey(punto.veicolo)
    RequestModel(hash)
    local scadenza = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(10) end
    if not HasModelLoaded(hash) then return end

    local s = punto.spawn
    local veicolo = CreateVehicle(hash, s.x, s.y, s.z, s.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleNumberPlateText(veicolo, 'SERV' .. math.random(100, 999))
    SetVehicleFuelLevel(veicolo, 100.0)
    SetPedIntoVehicle(PlayerPedId(), veicolo, -1)

    LocalPlayer.state:set('mezzoServizio', VehToNet(veicolo), false)

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🚐', titolo = 'Mezzo assegnato',
        testo = 'Riportalo qui a fine turno: i danni incidono sul compenso.',
    })
end

function riparaVicino()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetClosestVehicle(coord.x, coord.y, coord.z, 6.0, 0, 71)

        if veicolo == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessun veicolo', testo = 'Avvicinati a un veicolo.' })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Riparazione in corso...',
            durata = LAV.Regole.duratsRiparazione,
            annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('lav:riparazione', GetVehicleNumberPlateText(veicolo))
        if ok then
            SetVehicleFixed(veicolo)
            SetVehicleDeformationFixed(veicolo)
            SetVehicleEngineHealth(veicolo, 1000.0)
            SetVehicleBodyHealth(veicolo, 1000.0)
            SetVehicleDirtLevel(veicolo, 0.0)
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🔧', titolo = ok and 'Veicolo riparato' or 'Riparazione rifiutata',
            testo = messaggio, durata = 8000,
        })
    end)
end

--- Usa il kit di riparazione dall'inventario.
RegisterNetEvent('vei:usaKitRiparazione', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetClosestVehicle(coord.x, coord.y, coord.z, 5.0, 0, 71)
        if veicolo == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessun veicolo', testo = 'Avvicinati a un veicolo.' })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Riparazione di fortuna...',
            durata = 18000, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        if not completato then return end

        -- Un kit non riporta il veicolo a nuovo, lo rende solo guidabile
        SetVehicleEngineHealth(veicolo, math.min(750.0, GetVehicleEngineHealth(veicolo) + 400.0))
        SetVehicleBodyHealth(veicolo, math.min(750.0, GetVehicleBodyHealth(veicolo) + 300.0))
        SetVehicleUndriveable(veicolo, false)
        SetVehicleEngineOn(veicolo, true, true, false)

        TriggerServerEvent('lav:consumaKit')
        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🧰', titolo = 'Riparazione provvisoria',
            testo = 'Il veicolo è guidabile. Portalo in officina per un intervento completo.',
        })
    end)
end)

--- La tanica rifornisce il veicolo vicino.
RegisterNetEvent('vei:usaTanica', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetClosestVehicle(coord.x, coord.y, coord.z, 5.0, 0, 71)
        if veicolo == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessun veicolo', testo = 'Avvicinati a un veicolo.' })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Travaso dalla tanica...',
            durata = 9000, annullabile = true, blocca = { movimento = true },
        })
        if not completato then return end

        SetVehicleFuelLevel(veicolo, math.min(100.0, GetVehicleFuelLevel(veicolo) + 32.0))
        SetVehicleUndriveable(veicolo, false)
        TriggerServerEvent('lav:consumaTanica')
        exports.aurea_ui:Notifica({ tipo = 'successo', icona = '⛽', titolo = 'Rifornito', testo = 'Circa 20 litri travasati.' })
    end)
end)
