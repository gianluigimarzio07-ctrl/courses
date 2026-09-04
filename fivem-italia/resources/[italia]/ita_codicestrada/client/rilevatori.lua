--[[
    AUREA · Rilevatori di velocità (client)

    Il client individua il passaggio e segnala l'evento; la velocità che fa
    fede la legge il SERVER dall'entità di rete, così un client manomesso non
    può dichiarare 30 km/h mentre ne fa 200.
]]

local ultimoScatto = {}       -- [idPostazione] = timestamp
local tutorAperti = {}        -- [idTutor] = { ingresso = ms }

-- ---------------------------------------------------------------------------
--  Segnalazione delle postazioni sulla mappa (l'autovelox in Italia è segnalato)
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, av in ipairs(CDS.Autovelox) do
        local blip = AddBlipForCoord(av.coord.x, av.coord.y, av.coord.z)
        SetBlipSprite(blip, 184)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.55)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('Autovelox · %d km/h'):format(av.limite))
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------------------
--  Effetto flash quando la postazione scatta
-- ---------------------------------------------------------------------------
local function flash(coord)
    CreateThread(function()
        for _ = 1, 2 do
            DrawLightWithRange(coord.x, coord.y, coord.z + 3.0, 255, 255, 255, 22.0, 8.0)
            Wait(60)
            DrawLightWithRange(coord.x, coord.y, coord.z + 3.0, 255, 255, 255, 22.0, 3.0)
            Wait(80)
        end
        PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
    end)
end

-- ---------------------------------------------------------------------------
--  Differenza angolare fra la direzione del veicolo e quella della postazione
-- ---------------------------------------------------------------------------
local function differenzaAngolare(a, b)
    local d = math.abs((a - b) % 360.0)
    return d > 180.0 and (360.0 - d) or d
end

-- ---------------------------------------------------------------------------
--  Ciclo principale dei rilevatori
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            attesa = 200
            local coord = GetEntityCoords(veicolo)
            local direzione = GetEntityHeading(veicolo)
            local kmh = GetEntitySpeed(veicolo) * 3.6
            local ora = GetClockHours()

            -- ---- AUTOVELOX ------------------------------------------------
            for _, av in ipairs(CDS.Autovelox) do
                local distanza = #(coord - av.coord)
                if distanza < av.raggio then
                    local attivo = not av.fascia or CDS.InFascia({ av.fascia }, ora)
                    local allineato = differenzaAngolare(direzione, av.direzione) < 70.0
                    local scaduto = (GetGameTimer() - (ultimoScatto[av.id] or 0)) > (CDS.Regole.antiDuplicatoSecondi * 1000)

                    if attivo and allineato and scaduto and kmh > CDS.SogliaVelocita(av.limite) then
                        ultimoScatto[av.id] = GetGameTimer()
                        flash(av.coord)
                        TriggerServerEvent('cds:rilevamento', {
                            tipo = 'autovelox',
                            postazione = av.id,
                            nome = av.nome,
                            limite = av.limite,
                            netId = VehToNet(veicolo),
                            targa = GetVehicleNumberPlateText(veicolo),
                            coord = { x = coord.x, y = coord.y, z = coord.z },
                        })
                    end
                end
            end

            -- ---- TUTOR ----------------------------------------------------
            for _, t in ipairs(CDS.Tutor) do
                local dIngresso = #(coord - t.ingresso.coord)
                local dUscita = #(coord - t.uscita.coord)

                if dIngresso < t.ingresso.raggio and not tutorAperti[t.id] then
                    tutorAperti[t.id] = { ingresso = GetGameTimer() }
                    exports.aurea_ui:Notifica({
                        tipo = 'info', titolo = t.nome,
                        testo = ('Controllo della velocità media attivo. Limite %d km/h.'):format(t.limite),
                        durata = 4000, icona = '📷',
                    })

                elseif dUscita < t.uscita.raggio and tutorAperti[t.id] then
                    local trascorso = (GetGameTimer() - tutorAperti[t.id].ingresso) / 1000
                    tutorAperti[t.id] = nil

                    -- sotto i 10 secondi il tratto non è stato percorso davvero
                    if trascorso > 10 then
                        local media = (t.lunghezza / trascorso) * 3.6
                        if media > CDS.SogliaVelocita(t.limite) then
                            TriggerServerEvent('cds:rilevamento', {
                                tipo = 'tutor',
                                postazione = t.id,
                                nome = t.nome,
                                limite = t.limite,
                                mediaDichiarata = media,
                                secondi = trascorso,
                                lunghezza = t.lunghezza,
                                netId = VehToNet(veicolo),
                                targa = GetVehicleNumberPlateText(veicolo),
                                coord = { x = coord.x, y = coord.y, z = coord.z },
                            })
                        end
                    end
                end
            end
        else
            -- sceso dal veicolo: le tratte tutor aperte decadono
            if next(tutorAperti) then tutorAperti = {} end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  SEMAFORI SORVEGLIATI  ·  passaggio con il rosso
--
--  La fase deriva dall'orologio di gioco, che è sincronizzato su tutti i
--  client: quello che vedi tu è quello che ricalcola il server.
--  L'infrazione scatta quando il veicolo ATTRAVERSA l'incrocio (entra ed esce
--  dal raggio senza fermarsi) mentre la fase è rossa.
-- ---------------------------------------------------------------------------

--- Secondi trascorsi nel giorno di gioco corrente.
local function secondiDelGiorno()
    return GetClockHours() * 3600 + GetClockMinutes() * 60 + GetClockSeconds()
end

--- Espone la fase corrente: il cruscotto e le pattuglie possono mostrarla.
function CDS.FaseCorrente(id)
    return CDS.FaseSemaforo(id, secondiDelGiorno())
end

CreateThread(function()
    local dentroIncrocio = {}     -- [id] = { fase, entrato }

    while true do
        local attesa = 700
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            attesa = 150
            local coord = GetEntityCoords(veicolo)
            local kmh = GetEntitySpeed(veicolo) * 3.6

            for _, sem in ipairs(CDS.Semafori) do
                local distanza = #(coord - sem.coord)

                if distanza < sem.raggio then
                    if not dentroIncrocio[sem.id] then
                        -- si registra la fase al momento dell'ingresso nell'incrocio
                        dentroIncrocio[sem.id] = {
                            fase = CDS.FaseSemaforo(sem.id, secondiDelGiorno()),
                            entrato = GetGameTimer(),
                            velocitaIngresso = kmh,
                        }
                    end

                elseif dentroIncrocio[sem.id] then
                    local passaggio = dentroIncrocio[sem.id]
                    dentroIncrocio[sem.id] = nil

                    local fermatoAlSemaforo = (GetGameTimer() - passaggio.entrato) > 4000 or kmh < 8
                    local scaduto = (GetGameTimer() - (ultimoScatto[sem.id] or 0)) > (CDS.Regole.antiDuplicatoSecondi * 1000)

                    if passaggio.fase == 'rosso' and not fermatoAlSemaforo
                       and passaggio.velocitaIngresso > 18 and scaduto then
                        ultimoScatto[sem.id] = GetGameTimer()
                        flash(sem.coord)
                        TriggerServerEvent('cds:rilevamento', {
                            tipo = 'semaforo',
                            postazione = sem.id,
                            nome = sem.nome,
                            limite = 0,
                            secondiGioco = secondiDelGiorno(),
                            netId = VehToNet(veicolo),
                            targa = GetVehicleNumberPlateText(veicolo),
                            coord = { x = coord.x, y = coord.y, z = coord.z },
                        })
                    end
                end
            end
        elseif next(dentroIncrocio) then
            dentroIncrocio = {}
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Avviso di prossimità: il cartello arriva prima della postazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    local avvisati = {}
    while true do
        Wait(1500)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)
        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            local coord = GetEntityCoords(veicolo)
            for _, av in ipairs(CDS.Autovelox) do
                local d = #(coord - av.coord)
                if d < 160.0 and d > av.raggio and not avvisati[av.id] then
                    avvisati[av.id] = GetGameTimer()
                    LocalPlayer.state:set('limiteImposto', { valore = av.limite, nota = av.nome }, false)
                elseif d > 220.0 and avvisati[av.id] then
                    avvisati[av.id] = nil
                    LocalPlayer.state:set('limiteImposto', nil, false)
                end
            end
        end
    end
end)
