--[[
    AUREA · Autoscuola (client)

    L'esame pratico è il pezzo che conta: il client guarda come guidi e
    segnala gli errori al server, che li somma. Non decide lui l'esito.
]]

local U = AUREA.Util
local esame = nil       -- { veicolo, percorso, tappa, scadenza, punti, soglia }

CreateThread(function()
    local s = ASC.Sede
    local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
    SetBlipSprite(b, s.blip.sprite)
    SetBlipColour(b, s.blip.colore)
    SetBlipScale(b, s.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('autoscuola', s.coord, 3.0, {
        { etichetta = 'Sportello autoscuola', icona = '🚸', azione = function() sportello() end },
    })
end)

function sportello()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('asc:sportello')
        if not dati then return end

        local voci = {}
        for _, c in ipairs(dati.categorie) do
            local stato
            if c.posseduta then stato = 'già conseguita'
            elseif c.bloccata then stato = c.bloccata
            elseif c.teoriaValida then stato = ('teoria valida ancora %d min'):format(c.minutiResiduiTeoria)
            else stato = 'da iniziare' end

            voci[#voci + 1] = {
                id = c.id, icona = '🪪', titolo = c.nome,
                descrizione = ('%s · teoria %s, guida %s')
                    :format(c.descrizione, U.Euro(c.costoTeoria), U.Euro(c.costoPratica)),
                valore = stato,
                disattivata = c.posseduta or c.bloccata ~= nil,
            }
        end

        local categoria = exports.aurea_ui:Menu({
            titolo = ASC.Sede.nome,
            sottotitolo = 'Prima la teoria, poi la guida. Si può essere bocciati.',
            voci = voci,
        })
        if not categoria then return end

        local c
        for _, x in ipairs(dati.categorie) do if x.id == categoria then c = x end end
        if not c then return end

        local scelta = exports.aurea_ui:Menu({
            titolo = c.nome,
            voci = {
                { id = 'teoria', icona = '📘', titolo = 'Esame di teoria',
                  descrizione = 'Quiz sul Codice della Strada, in aula.',
                  valore = U.Euro(c.costoTeoria) },
                { id = 'pratica', icona = '🚗', titolo = 'Esame di guida',
                  descrizione = c.teoriaValida and 'Percorso su strada.'
                      or 'Serve prima la teoria superata.',
                  valore = U.Euro(c.costoPratica),
                  disattivata = not c.teoriaValida },
            },
        })
        if not scelta then return end

        if scelta == 'teoria' then return teoria(categoria) end
        pratica(categoria)
    end)
end

-- ---------------------------------------------------------------------------
--  Teoria
-- ---------------------------------------------------------------------------
function teoria(categoria)
    CreateThread(function()
        local prova, errore = AUREA.Callback.Attendi('asc:teoria', categoria)
        if not prova then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📘', titolo = 'Teoria', testo = tostring(errore), durata = 12000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '📘', durata = 12000,
            titolo = ('Esame di teoria — %s'):format(prova.nome),
            testo = ('%d domande, %d errori ammessi. Non si torna indietro.')
                :format(#prova.domande, prova.erroriAmmessi),
        })

        local risposte = {}

        for n, d in ipairs(prova.domande) do
            local voci = {}
            for k, r in ipairs(d.risposte) do
                voci[k] = { id = tostring(k), icona = ('%d.'):format(k), titolo = r }
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = ('Domanda %d di %d'):format(n, #prova.domande),
                sottotitolo = d.testo,
                voci = voci,
            })

            -- Chiudere il menu vale come risposta sbagliata: l'esame non si sospende
            risposte[n] = tonumber(scelta) or 0
        end

        local esito = AUREA.Callback.Attendi('asc:consegnaTeoria', risposte)
        if not esito then return end

        exports.aurea_ui:Notifica({
            tipo = esito.passato and 'successo' or 'errore',
            icona = '📘', durata = 16000,
            titolo = esito.passato and 'Idoneo' or 'Respinto',
            testo = esito.messaggio,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Pratica
-- ---------------------------------------------------------------------------
function pratica(categoria)
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('asc:pratica', categoria)
        if not dati then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚗', titolo = 'Esame di guida',
                testo = tostring(errore), durata = 12000,
            })
        end

        local hash = GetHashKey(dati.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local v = CreateVehicle(hash, dati.partenza.x, dati.partenza.y, dati.partenza.z,
            dati.partenza.w, true, false)
        SetVehicleNumberPlateText(v, 'SCUOLA')
        SetModelAsNoLongerNeeded(hash)
        TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)

        esame = {
            veicolo = v, percorso = dati.percorso, tappa = 1,
            scadenza = GetGameTimer() + dati.durata * 1000,
            punti = 0, soglia = dati.soglia,
            blip = nil, ultimaSegnalazione = 0,
        }
        segnaTappa()

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🚗', durata = 16000,
            titolo = 'Esame di guida iniziato',
            testo = 'Segui i punti sulla mappa, rispetta i limiti e non toccare niente.',
        })
    end)
end

function segnaTappa()
    if not esame then return end
    if esame.blip then RemoveBlip(esame.blip) end

    local t = esame.percorso[esame.tappa]
    if not t then return end

    esame.blip = AddBlipForCoord(t.coord.x, t.coord.y, t.coord.z)
    SetBlipSprite(esame.blip, 1)
    SetBlipColour(esame.blip, 5)
    SetBlipRoute(esame.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(t.nome)
    EndTextCommandSetBlipName(esame.blip)
end

CreateThread(function()
    while true do
        local attesa = 700

        if esame then
            attesa = 200
            local ped = PlayerPedId()
            local v = esame.veicolo

            if not DoesEntityExist(v) or GetVehiclePedIsIn(ped, false) ~= v then
                -- Scendere dall'auto durante l'esame lo chiude
                concludi(false)
            else
                local coord = GetEntityCoords(v)
                local t = esame.percorso[esame.tappa]
                local residuo = math.max(0, math.floor((esame.scadenza - GetGameTimer()) / 1000))

                -- Limite del tratto
                local kmh = GetEntitySpeed(v) * 3.6
                if t and kmh > t.limite + 5 and (GetGameTimer() - esame.ultimaSegnalazione) > 6000 then
                    esame.ultimaSegnalazione = GetGameTimer()
                    TriggerServerEvent('asc:errore', 'eccessoVelocita')
                end

                -- Urti
                if HasEntityCollidedWithAnything(v) and (GetGameTimer() - esame.ultimaSegnalazione) > 3000 then
                    esame.ultimaSegnalazione = GetGameTimer()
                    TriggerServerEvent('asc:errore', 'collisione')
                end

                if t then
                    AUREA.Testo3D(coord.x, coord.y, coord.z + 1.4,
                        ('%s · limite %d · %ds · penalità %d/%d')
                            :format(t.nome, t.limite, residuo, esame.punti, esame.soglia), 0.36)

                    if #(coord - t.coord) < ASC.Pratica.raggioPunto then
                        esame.tappa = esame.tappa + 1
                        if esame.tappa > #esame.percorso then
                            concludi(true)
                        else
                            segnaTappa()
                            exports.aurea_ui:Notifica({
                                tipo = 'info', icona = '📍', durata = 5000,
                                titolo = 'Tappa superata',
                                testo = esame.percorso[esame.tappa].nome,
                            })
                        end
                    end
                end

                if residuo <= 0 then concludi(false) end
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('asc:penalita', function(tipo, costo, totale)
    if not esame then return end
    esame.punti = totale

    local nomi = {
        eccessoVelocita = 'Superato il limite',
        collisione = 'Urto',
        contromano = 'Contromano',
        sensoVietato = 'Senso vietato',
        fuoriPercorso = 'Fuori percorso',
    }

    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '⚠', durata = 6000,
        titolo = nomi[tipo] or 'Errore',
        testo = ('+%d penalità (totale %d su %d)'):format(costo, totale, esame.soglia),
    })
end)

function concludi(completato)
    local sessione = esame
    esame = nil
    if not sessione then return end

    if sessione.blip then RemoveBlip(sessione.blip) end
    if DoesEntityExist(sessione.veicolo) then
        local ped = PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == sessione.veicolo then
            TaskLeaveVehicle(ped, sessione.veicolo, 16)
            Wait(1200)
        end
        SetEntityAsMissionEntity(sessione.veicolo, true, true)
        DeleteVehicle(sessione.veicolo)
    end

    CreateThread(function()
        local esito = AUREA.Callback.Attendi('asc:concludiPratica', completato)
        if not esito then return end

        exports.aurea_ui:Notifica({
            tipo = esito.passato and 'successo' or 'errore',
            icona = '🪪', durata = 18000,
            titolo = esito.passato and 'Patente conseguita' or 'Esame non superato',
            testo = esito.messaggio,
        })
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() or not esame then return end
    if esame.blip then RemoveBlip(esame.blip) end
    if DoesEntityExist(esame.veicolo) then DeleteVehicle(esame.veicolo) end
end)
