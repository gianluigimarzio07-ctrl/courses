--[[
    AUREA · Soccorso stradale (client)
]]

local U = AUREA.Util
local trainato = nil        -- { veicolo, carro, agganciatoIn }
local chiamataPresa = nil   -- { id, blip, partenza }
local occupato = false

-- ---------------------------------------------------------------------------
--  Sede
-- ---------------------------------------------------------------------------
CreateThread(function()
    local s = SOC.Sede
    local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
    SetBlipSprite(b, s.blip.sprite)
    SetBlipColour(b, s.blip.colore)
    SetBlipScale(b, s.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('soccorso', s.coord, 3.0, {
        { etichetta = 'Chiamate in attesa', icona = '📞',
          lavoro = SOC.Lavoro, inServizio = true,
          azione = function() elencoChiamate() end },
        { etichetta = 'Prendi un carro attrezzi', icona = '🚛',
          lavoro = SOC.Lavoro, inServizio = true,
          azione = function() prendiCarro() end },
    })
end)

-- ---------------------------------------------------------------------------
--  Chi ha bisogno: chiama
-- ---------------------------------------------------------------------------
RegisterCommand('soccorso', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
        if veicolo == 0 then
            local c = GetEntityCoords(ped)
            veicolo = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 71)
        end

        local targa = veicolo ~= 0 and GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper() or ''

        local guasto = exports.aurea_ui:Menu({
            titolo = 'Soccorso stradale',
            sottotitolo = targa ~= '' and ('Veicolo %s'):format(targa) or 'Nessun veicolo rilevato',
            voci = {
                { id = 'Guasto al motore', icona = '🔧', titolo = 'Guasto al motore' },
                { id = 'Rimasto senza carburante', icona = '⛽', titolo = 'Rimasto senza carburante' },
                { id = 'Pneumatico a terra', icona = '🛞', titolo = 'Pneumatico a terra' },
                { id = 'Incidente', icona = '💥', titolo = 'Incidente' },
                { id = 'Il mezzo non parte', icona = '🔋', titolo = 'Il mezzo non parte' },
            },
        })
        if not guasto then return end

        local ok, messaggio = AUREA.Callback.Attendi('soc:chiama', targa, guasto)
        exports.aurea_ui:Notifica({
            tipo = ok and 'info' or 'errore', icona = '🚛',
            titolo = 'Soccorso stradale', testo = messaggio, durata = 15000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Chi risponde
-- ---------------------------------------------------------------------------
RegisterNetEvent('soc:nuovaChiamata', function(c)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🚛', durata = 15000,
        titolo = 'Richiesta di soccorso',
        testo = ('%s — %s%s. Apri l\'elenco con /interventi.')
            :format(c.nome, c.guasto, c.targa ~= '' and (' (%s)'):format(c.targa) or ''),
    })
end)

RegisterCommand('interventi', function() elencoChiamate() end, false)

function elencoChiamate()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('soc:chiamate')
        if not elenco or #elenco == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🚛', titolo = 'Soccorso',
                testo = 'Nessuna chiamata in attesa.',
            })
        end

        local voci = {}
        for _, c in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(c.id), icona = c.presa and '🔒' or '📞',
                titolo = ('%s — %s'):format(c.nome, c.guasto),
                descrizione = c.presa and ('Presa da %s'):format(c.presa)
                    or (c.targa ~= '' and ('Veicolo %s'):format(c.targa) or 'Nessuna targa indicata'),
                valore = ('%d min fa'):format(c.minuti),
                disattivata = c.presa ~= nil,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Chiamate in attesa',
            sottotitolo = 'Chi non riceve risposta finisce col carro comunale',
            voci = voci,
        })
        if not scelta then return end

        local ok, coord = AUREA.Callback.Attendi('soc:prendi', tonumber(scelta))
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚛', titolo = 'Chiamata', testo = tostring(coord), durata = 9000,
            })
        end

        if chiamataPresa and chiamataPresa.blip then RemoveBlip(chiamataPresa.blip) end

        local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
        SetBlipSprite(blip, 380)
        SetBlipColour(blip, 47)
        SetBlipRoute(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Intervento di soccorso')
        EndTextCommandSetBlipName(blip)

        chiamataPresa = { id = tonumber(scelta), blip = blip,
                          partenza = vector3(coord.x, coord.y, coord.z) }

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚛', titolo = 'Intervento assegnato',
            testo = 'Posizione segnata sulla mappa.', durata = 11000,
        })
    end)
end

function prendiCarro()
    CreateThread(function()
        local posto = SOC.Sede.mezzi[math.random(#SOC.Sede.mezzi)]
        local hash = GetHashKey(SOC.Sede.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
        SetVehicleNumberPlateText(v, 'SOCCORSO')
        SetModelAsNoLongerNeeded(hash)
        TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚛', titolo = 'Carro attrezzi',
            testo = 'Usa il terzo occhio sul mezzo in avaria per agganciarlo.', durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Aggancio e traino
-- ---------------------------------------------------------------------------
CreateThread(function()
    exports.aurea_target:AggiungiModello({ SOC.Sede.modello }, {
        { etichetta = 'Sgancia il mezzo', icona = '⬇',
          lavoro = SOC.Lavoro,
          condizione = function() return trainato ~= nil end,
          azione = function() sgancia() end },
    })
end)

CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()

        if AUREA.HaLavoro(SOC.Lavoro) and AUREA.EInServizio() and not occupato and not trainato then
            local coord = GetEntityCoords(ped)
            local carro = GetClosestVehicle(coord.x, coord.y, coord.z, 12.0, GetHashKey(SOC.Sede.modello), 70)

            if carro ~= 0 and not IsPedInAnyVehicle(ped, false) then
                local bersaglio = GetClosestVehicle(coord.x, coord.y, coord.z, SOC.Traino.distanzaAggancio, 0, 71)
                if bersaglio ~= 0 and bersaglio ~= carro then
                    attesa = 0
                    exports.aurea_ui:Prompt(true, 'Aggancia il mezzo al pianale', 'G')
                    if IsControlJustReleased(0, 47) then
                        exports.aurea_ui:Prompt(false)
                        aggancia(carro, bersaglio)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

function aggancia(carro, bersaglio)
    CreateThread(function()
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Aggancio al pianale...', durata = SOC.Traino.durataAggancio,
            annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        AttachEntityToEntity(bersaglio, carro, 20,
            0.0, -1.5, SOC.Traino.altezzaPianale, 0.0, 0.0, 0.0,
            false, false, false, false, 20, true)

        trainato = { veicolo = bersaglio, carro = carro,
                     targa = GetVehicleNumberPlateText(bersaglio):gsub('%s+', ''):upper() }

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚛', titolo = 'Mezzo agganciato',
            testo = ('Portalo in officina. Targa %s.'):format(trainato.targa), durata = 12000,
        })
    end)
end

function sgancia()
    CreateThread(function()
        if not trainato then return end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Sgancio dal pianale...', durata = SOC.Traino.durataSgancio,
            annullabile = true, blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        if DoesEntityExist(trainato.veicolo) then
            DetachEntity(trainato.veicolo, true, true)
            SetVehicleOnGroundProperly(trainato.veicolo)
        end

        local coord = GetEntityCoords(PlayerPedId())
        local inOfficina = #(coord - SOC.Sede.officina) < 25.0

        if inOfficina and chiamataPresa then
            local km = math.floor(#(chiamataPresa.partenza - SOC.Sede.officina) / 1000)
            local ok, messaggio = AUREA.Callback.Attendi('soc:concludiTraino', chiamataPresa.id, km)

            if chiamataPresa.blip then RemoveBlip(chiamataPresa.blip) end
            chiamataPresa = nil

            if DoesEntityExist(trainato.veicolo) then
                SetEntityAsMissionEntity(trainato.veicolo, true, true)
                DeleteVehicle(trainato.veicolo)
            end

            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🚛',
                titolo = 'Traino', testo = messaggio, durata = 14000,
            })
        else
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🚛', titolo = 'Mezzo sganciato',
                testo = inOfficina and 'Nessuna chiamata collegata a questo traino.'
                    or 'Sei fuori dall\'officina: il traino non conta come concluso.',
                durata = 11000,
            })
        end

        trainato = nil
    end)
end

-- ---------------------------------------------------------------------------
--  Interventi sul posto
-- ---------------------------------------------------------------------------
RegisterCommand('riparasulposto', function()
    CreateThread(function()
        local voci = {}
        for id, i in pairs(SOC.Interventi) do
            voci[#voci + 1] = {
                id = id, icona = i.icona, titolo = i.nome,
                descrizione = ('Serve %s.'):format(AUREA.Item[i.oggetto].etichetta),
                valore = U.Euro(i.prezzo),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Intervento sul posto',
            sottotitolo = 'Il cliente paga a lavoro finito', voci = voci,
        })
        if not scelta then return end

        local cliente = giocatoreVicino(12.0)

        local ok, dati = AUREA.Callback.Attendi('soc:intervento', scelta, cliente)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔧', titolo = 'Intervento', testo = tostring(dati), durata = 10000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = dati.nome, durata = dati.durata, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        applica(dati.effetto, dati.salute)

        local fatto, messaggio = AUREA.Callback.Attendi('soc:concludiIntervento', scelta, cliente)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🔧',
            titolo = 'Intervento', testo = messaggio, durata = 13000,
        })
    end)
end, false)

function applica(effetto, salute)
    local coord = GetEntityCoords(PlayerPedId())
    local v = GetClosestVehicle(coord.x, coord.y, coord.z, 8.0, 0, 71)
    if v == 0 then return end

    if effetto == 'carburante' then
        SetVehicleFuelLevel(v, 55.0)
        DecorSetFloat(v, 'AUREA_CARBURANTE', 55.0)
    elseif effetto == 'gomme' then
        for r = 0, 5 do SetVehicleTyreFixed(v, r) end
    elseif effetto == 'motore' then
        SetVehicleEngineHealth(v, math.max(GetVehicleEngineHealth(v), 500.0))
        SetVehicleEngineOn(v, true, true, false)
    elseif effetto == 'completo' then
        local q = (salute or 0.65) * 1000.0
        SetVehicleEngineHealth(v, q)
        SetVehicleBodyHealth(v, q)
        SetVehiclePetrolTankHealth(v, q)
        SetVehicleFixed(v)
        SetVehicleEngineHealth(v, q)
        SetVehicleBodyHealth(v, q)
    end
end

function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio
    for _, altro in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(altro)
        if p ~= ped then
            local d = #(coord - GetEntityCoords(p))
            if d < distanza then migliore, distanza = GetPlayerServerId(altro), d end
        end
    end
    return migliore
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and chiamataPresa and chiamataPresa.blip then
        RemoveBlip(chiamataPresa.blip)
    end
end)
