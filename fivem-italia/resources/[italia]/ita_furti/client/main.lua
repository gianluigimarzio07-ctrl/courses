--[[
    AUREA · Furti su veicolo (client)
]]

local U = AUREA.Util
local occupato = false
local blipAntifurto = {}    -- [targa] = blip
local commessaCorrente = nil

-- ---------------------------------------------------------------------------
--  Blip dell'autodemolizione
-- ---------------------------------------------------------------------------
CreateThread(function()
    local d = FUR.Demolizione
    local blip = AddBlipForCoord(d.coord.x, d.coord.y, d.coord.z)
    SetBlipSprite(blip, 446)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(d.nome)
    EndTextCommandSetBlipName(blip)
end)

-- ---------------------------------------------------------------------------
--  Effrazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 800
        local ped = PlayerPedId()

        if not occupato and not IsPedInAnyVehicle(ped, false) then
            local veicolo = veicoloDavanti()

            if veicolo and GetVehicleDoorLockStatus(veicolo) >= 2 then
                attesa = 0
                exports.aurea_ui:Prompt(true, 'Forza la serratura', 'H')
                if IsControlJustReleased(0, 74) then
                    exports.aurea_ui:Prompt(false)
                    scassina(veicolo)
                end
            else
                exports.aurea_ui:Prompt(false)
            end
        end

        Wait(attesa)
    end
end)

function veicoloDavanti()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local avanti = coord + GetEntityForwardVector(ped) * 2.5

    local raggio = StartShapeTestCapsule(coord.x, coord.y, coord.z,
        avanti.x, avanti.y, avanti.z, 1.2, 10, ped, 7)
    local _, colpito, _, _, entita = GetShapeTestResult(raggio)

    if colpito == 1 and IsEntityAVehicle(entita) then return entita end

    -- Ripiego: il veicolo più vicino entro due metri
    local vicino = GetClosestVehicle(coord.x, coord.y, coord.z, 2.5, 0, 71)
    if vicino ~= 0 and DoesEntityExist(vicino) then return vicino end
    return nil
end

function scassina(veicolo)
    CreateThread(function()
        occupato = true

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()
        local classe = GetVehicleClass(veicolo)
        local conducente = GetPedInVehicleSeat(veicolo, -1)
        local conducenteABordo = conducente ~= 0 and IsPedAPlayer(conducente)

        local riuscita, dati = AUREA.Callback.Attendi('fur:apri', targa, classe, conducenteABordo)
        if type(dati) ~= 'table' then
            occupato = false
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔧', titolo = 'Non ci provi nemmeno',
                testo = tostring(dati), durata = 9000,
            })
        end

        local completata = exports.aurea_ui:Progresso({
            etichetta = ('Apertura con %s — %s'):format(dati.attrezzo, dati.nomeFascia),
            durata = dati.durataApertura,
            annullabile = true,
            anim = { dizionario = 'veh@break_in@0h@p_m_one@', nome = 'low_force_entry_ds' },
            blocca = { movimento = true },
        })
        if not completata then occupato = false return end

        if not riuscita then
            occupato = false
            if dati.segni then avvisaTestimoni(veicolo) end
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔧',
                titolo = dati.rotto and 'L\'attrezzo si è spezzato' or 'La serratura ha tenuto',
                testo = dati.rotto and 'Ti serve un attrezzo nuovo.' or 'Riprova, se hai ancora tempo.',
                durata = 10000,
            })
        end

        SetVehicleDoorsLocked(veicolo, 1)
        SetVehicleDoorOpen(veicolo, 0, false, false)

        -- L'allarme delle vetture di pregio
        if dati.allarme then
            SetVehicleAlarm(veicolo, true)
            StartVehicleAlarm(veicolo)
            TriggerServerEvent('fur:allarme', targa)

            exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '🚨', durata = 10000,
                titolo = 'È scattato l\'allarme',
                testo = 'Muoviti: qualcuno lo sta già sentendo.',
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🔓', durata = 9000,
            titolo = 'Portiera aperta',
            testo = dati.bloccoMotore
                and 'Ha il blocco motore: senza centralina non parte.'
                or 'Ora vanno ponticellati i cavi.',
        })

        occupato = false
        avvia(veicolo, dati, targa, conducenteABordo)
    end)
end

--- Ponticellare i cavi. È il passaggio che tiene fermo il ladro
--- abbastanza a lungo perché una volante possa arrivare.
function avvia(veicolo, dati, targa, conducenteABordo)
    CreateThread(function()
        -- Bisogna essere al posto di guida
        local scadenza = GetGameTimer() + 30000
        while GetPedInVehicleSeat(veicolo, -1) ~= PlayerPedId() do
            if GetGameTimer() > scadenza then return end
            exports.aurea_ui:Prompt(true, 'Mettiti al posto di guida', '')
            Wait(200)
        end
        exports.aurea_ui:Prompt(false)

        if dati.bloccoMotore and not dati.haCentralina then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔒', durata = 13000,
                titolo = 'Blocco motore',
                testo = 'La centralina non riconosce la chiave. Serve una centralina clonata.',
            })
        end

        occupato = true
        SetVehicleEngineOn(veicolo, false, true, true)

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Avviamento a ponte...',
            durata = dati.durataAvviamento,
            annullabile = true,
            anim = { dizionario = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', nome = 'machinic_loop_mechandplayer' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('fur:consumato', targa, conducenteABordo)
        if not ok then return end

        SetVehicleEngineOn(veicolo, true, true, false)
        SetVehicleNeedsToBeHotwired(veicolo, false)
        SetVehicleAlarm(veicolo, false)

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚗', titolo = 'Motore acceso',
            testo = messaggio, durata = 12000,
        })
    end)
end

function avvisaTestimoni(veicolo)
    if math.random(100) > FUR.Allarme.probabilitaTestimone then return end
    local coord = GetEntityCoords(veicolo)
    TriggerServerEvent('fur:testimone', { x = coord.x, y = coord.y, z = coord.z })
end

-- ---------------------------------------------------------------------------
--  Antifurto: installazione e inseguimento
-- ---------------------------------------------------------------------------
RegisterCommand('antifurto', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or veicoloDavanti()
        if not veicolo then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📡', titolo = 'Nessun veicolo',
                testo = 'Sali a bordo o mettiti davanti al mezzo.',
            })
        end

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Installazione dell\'antifurto...', durata = 14000, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('fur:installaAntifurto', targa)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📡',
            titolo = 'Antifurto satellitare', testo = messaggio, durata = 12000,
        })
    end)
end, false)

RegisterNetEvent('fur:seguiAntifurto', function(targa, coord)
    if blipAntifurto[targa] then RemoveBlip(blipAntifurto[targa]) end

    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Veicolo rubato · %s'):format(targa))
    EndTextCommandSetBlipName(blip)

    blipAntifurto[targa] = blip
end)

RegisterNetEvent('fur:antifurtoPerso', function(targa)
    if blipAntifurto[targa] then
        RemoveBlip(blipAntifurto[targa])
        blipAntifurto[targa] = nil
    end
end)

--- Staccare l'antifurto dal mezzo appena rubato.
RegisterCommand('staccaantifurto', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or veicoloDavanti()
        if not veicolo then return end

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Ricerca del cablaggio...',
            durata = FUR.Antifurto.durataDisattivazione, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('fur:staccaAntifurto', targa)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '✂',
            titolo = 'Antifurto', testo = messaggio, durata = 11000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Targhe
-- ---------------------------------------------------------------------------
RegisterCommand('cambiotarga', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or veicoloDavanti()
        if not veicolo then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔩', titolo = 'Nessun veicolo davanti a te',
            })
        end

        local attuale = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Sostituzione delle targhe...', durata = FUR.Targhe.durata, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local ok, risultato = AUREA.Callback.Attendi('fur:cambiaTarga', attuale)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔩', titolo = 'Targa', testo = risultato, durata = 10000,
            })
        end

        SetVehicleNumberPlateText(veicolo, risultato)
        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🔩', durata = 13000,
            titolo = 'Targa sostituita',
            testo = ('Adesso è %s. Il telaio però resta quello di prima.'):format(risultato),
        })
    end)
end, false)

--- Controllo del telaio, per le forze dell'ordine.
RegisterCommand('controllotelaio', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or veicoloDavanti()
        if not veicolo then return end

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Verifica del numero di telaio...', durata = 9000, annullabile = true,
            blocca = { movimento = true },
        })
        if not completato then return end

        local esito, messaggio = AUREA.Callback.Attendi('fur:controlloTelaio', targa)
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔍', titolo = 'Controllo', testo = messaggio, durata = 9000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = esito.pulito and 'successo' or 'errore', icona = '🔍', durata = 16000,
            titolo = esito.pulito and 'Nessuna anomalia' or 'Veicolo provento di furto',
            testo = esito.pulito and messaggio
                or ('%s Intestatario originario: %s%s. Sottratto %d minuti fa.'):format(
                    messaggio, esito.intestatario,
                    esito.targaOriginale and (', targa %s'):format(esito.targaOriginale) or '',
                    esito.da),
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Autodemolizione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) and not occupato
           and FUR.AllaDemolizione(GetEntityCoords(ped)) then
            attesa = 0
            exports.aurea_ui:Prompt(true, ('%s — smonta il mezzo'):format(FUR.Demolizione.nome), 'G')
            if IsControlJustReleased(0, 47) then
                exports.aurea_ui:Prompt(false)
                demolisci()
            end
        end

        Wait(attesa)
    end
end)

function demolisci()
    CreateThread(function()
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)
        if veicolo == 0 then return end

        local commessa = AUREA.Callback.Attendi('fur:commessa')

        local sottotitolo = 'Nessuna commessa in corso: si paga il prezzo di listino.'
        if commessa then
            sottotitolo = ('Commessa: %d %s (%d/%d consegnate) — pagate ×%.1f, scade fra %d min')
                :format(commessa.richiesti, commessa.testo, commessa.consegnati,
                        commessa.richiesti, commessa.moltiplicatore, commessa.minutiResidui)
        end

        local conferma = exports.aurea_ui:Menu({
            titolo = FUR.Demolizione.nome,
            sottotitolo = sottotitolo,
            voci = {
                { id = 'si', icona = '🔧', titolo = 'Smonta il veicolo',
                  descrizione = 'Non torna indietro. Se è di qualcuno, è ricettazione.' },
                { id = 'no', icona = '↩', titolo = 'Lascia perdere' },
            },
        })
        if conferma ~= 'si' then return end

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper()
        local classe = GetVehicleClass(veicolo)
        local danni = 1.0 - (GetVehicleBodyHealth(veicolo) / 1000.0)

        local avviata, durata = AUREA.Callback.Attendi('fur:demolisci', targa, classe, danni)
        if not avviata then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔧', titolo = 'Piazzale', testo = durata, durata = 10000,
            })
        end

        occupato = true
        SetEntityAsMissionEntity(veicolo, true, true)

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Smontaggio in corso...', durata = durata, annullabile = true,
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then
            return exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '🔧', titolo = 'Smontaggio interrotto',
                testo = 'Il mezzo è ancora lì, e adesso è un problema tuo.', durata = 10000,
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('fur:concludiDemolizione')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🔧',
            titolo = ok and 'Mezzo smontato' or 'Smontaggio fallito',
            testo = messaggio, durata = 15000,
        })
    end)
end

RegisterNetEvent('fur:veicoloDemolito', function()
    local ped = PlayerPedId()
    local veicolo = GetVehiclePedIsIn(ped, false)
    if veicolo == 0 then
        local c = GetEntityCoords(ped)
        veicolo = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 71)
    end
    if veicolo ~= 0 and DoesEntityExist(veicolo) then
        TaskLeaveVehicle(ped, veicolo, 16)
        Wait(1200)
        SetEntityAsMissionEntity(veicolo, true, true)
        DeleteVehicle(veicolo)
    end
end)

-- ---------------------------------------------------------------------------
--  Commessa
-- ---------------------------------------------------------------------------
RegisterNetEvent('fur:commessa', function(dati)
    commessaCorrente = dati
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🔧', durata = 14000,
        titolo = 'Nuova commessa all\'autodemolizione',
        testo = ('Servono %d %s. Chi le porta viene pagato il doppio.')
            :format(dati.richiesti, dati.testo),
    })
end)

RegisterCommand('commessa', function()
    CreateThread(function()
        local c = AUREA.Callback.Attendi('fur:commessa')
        if not c then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🔧', titolo = 'Autodemolizione',
                testo = 'Nessuna commessa in corso.',
            })
        end

        exports.aurea_ui:Menu({
            titolo = 'Commessa in corso',
            sottotitolo = FUR.Demolizione.nome,
            voci = {
                { id = '_a', icona = '🚗', titolo = ('%d %s'):format(c.richiesti, c.testo),
                  descrizione = ('Fascia richiesta: %s'):format(c.fascia),
                  valore = ('%d/%d'):format(c.consegnati, c.richiesti), disattivata = true },
                { id = '_b', icona = '💰', titolo = ('Pagate ×%.1f'):format(c.moltiplicatore),
                  descrizione = 'Fuori commessa si prende il prezzo di listino.', disattivata = true },
                { id = '_c', icona = '⏱', titolo = ('Scade fra %d minuti'):format(c.minutiResidui),
                  disattivata = true },
            },
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, blip in pairs(blipAntifurto) do RemoveBlip(blip) end
end)
