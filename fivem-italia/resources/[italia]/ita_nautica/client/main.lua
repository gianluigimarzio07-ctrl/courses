--[[
    AUREA · Nautica (client)

    Misura la distanza dalla costa, avvisa quando si passa una soglia che
    cambia le regole, e mette in mano gli strumenti: esame, noleggio,
    controllo, razzo.
]]

local migliaAttuali = 0
local fasciaAttuale = nil
local inAcqua = false
local avvisataPatente = false

-- ---------------------------------------------------------------------------
--  Dove sono
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(3000)
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local inBarca = IsPedInAnyBoat(ped)
        local nuotando = IsPedSwimming(ped) and not inBarca

        if inBarca or nuotando then
            migliaAttuali = NAU.MigliaDallaCosta(coord)
            local fascia = NAU.FasciaPer(migliaAttuali)

            -- Il passaggio di fascia si dice una volta sola
            if fascia ~= fasciaAttuale then
                fasciaAttuale = fascia
                exports.aurea_ui:Notifica({
                    tipo = fascia.richiedePatente and 'avviso' or 'info',
                    icona = '⚓', durata = 9000,
                    titolo = fascia.nome,
                    testo = ('Dotazioni richieste: %s.'):format(
                        table.concat((function()
                            local out = {}
                            for _, d in ipairs(fascia.dotazioni) do
                                out[#out + 1] = (AUREA.Item[d] and AUREA.Item[d].etichetta) or d
                            end
                            return out
                        end)(), ', ')),
                })
            end

            -- Il titolo abilitativo
            if inBarca then
                local veicolo = GetVehiclePedIsIn(ped, false)
                local modello

                for _, n in ipairs(NAU.Noleggio.listino) do
                    if GetEntityModel(veicolo) == GetHashKey(n.modello) then modello = n break end
                end

                local serve, motivo = NAU.ServePatente(
                    modello and modello.modello or '', migliaAttuali,
                    modello and modello.cavalli or nil)

                if serve and not avvisataPatente then
                    avvisataPatente = true
                    local stato = AUREA.Callback.Attendi('nau:statoPatente')
                    if stato and not stato.haPatente then
                        exports.aurea_ui:Notifica({
                            tipo = 'errore', icona = '⚓', durata = 15000,
                            titolo = 'Stai navigando senza titolo',
                            testo = ('Qui la patente nautica serve (%s). Se ti fermano è %s.')
                                :format(motivo, AUREA.Util.Euro(NAU.Controlli.sanzioneSenzaPatente)),
                        })
                    end
                elseif not serve then
                    avvisataPatente = false
                end
            end

            -- In acqua e lontano dalla costa: il server deve saperlo
            if nuotando ~= inAcqua then
                inAcqua = nuotando
                TriggerServerEvent('nau:inAcqua', inAcqua, migliaAttuali)
            elseif nuotando then
                TriggerServerEvent('nau:inAcqua', true, migliaAttuali)
            end
        else
            if inAcqua then
                inAcqua = false
                TriggerServerEvent('nau:inAcqua', false)
            end
            fasciaAttuale = nil
            avvisataPatente = false
        end
    end
end)

--- Il contamiglia, quando sei in mare.
CreateThread(function()
    while true do
        if fasciaAttuale then
            Wait(0)
            SetTextFont(4)
            SetTextScale(0.0, 0.40)
            SetTextColour(200, 220, 235, 200)
            SetTextDropShadow()
            SetTextWrap(0.0, 0.97)
            SetTextRightJustify(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(
                ('⚓ %.1f miglia dalla costa — %s'):format(migliaAttuali, fasciaAttuale.nome))
            EndTextCommandDisplayText(0.97, 0.90)
        else
            Wait(700)
        end
    end
end)

RegisterNetEvent('nau:sfinimento', function(danno)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - danno))
    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🌊', durata = 8000,
        titolo = 'Ti stai esaurendo',
        testo = 'Sei troppo lontano dalla costa. Spara un razzo, se ce l\'hai.',
    })
end)

RegisterNetEvent('nau:recuperato', function()
    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '⚓', titolo = 'A bordo', durata = 8000,
    })
end)

--- Il segnale di soccorso, per chi lo riceve.
RegisterNetEvent('nau:segnale', function(dati)
    local blip = AddBlipForCoord(dati.x, dati.y, dati.z)
    SetBlipSprite(blip, 303)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.1)
    SetBlipFlashes(blip, true)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Soccorso — %s'):format(dati.nome))
    EndTextCommandSetBlipName(blip)

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🧨', durata = 25000,
        titolo = 'Razzo avvistato',
        testo = ('%s a %.1f miglia. Rotta impostata.'):format(dati.nome, dati.miglia),
    })

    SetTimeout(600000, function() if DoesBlipExist(blip) then RemoveBlip(blip) end end)
end)

-- ---------------------------------------------------------------------------
--  Esame
-- ---------------------------------------------------------------------------
local function esame()
    local stato = AUREA.Callback.Attendi('nau:statoPatente')
    if not stato then return end

    if stato.haPatente then
        return exports.aurea_ui:Notifica({
            tipo = 'info', icona = '⚓', durata = 11000,
            titolo = 'Patente nautica',
            testo = ('Ne hai già una valida fino al %s.'):format(tostring(stato.scadenza)),
        })
    end

    local conferma = exports.aurea_ui:Menu({
        titolo = 'Esame per la patente nautica',
        sottotitolo = ('Diritti d\'esame %s · rilascio %s se lo superi')
            :format(AUREA.Util.Euro(stato.costoEsame), AUREA.Util.Euro(stato.costoRilascio)),
        voci = {
            { id = 'si', icona = '📝', titolo = 'Sostieni l\'esame',
              descrizione = ('%d domande, al massimo %d errori.')
                  :format(NAU.Patente.domandeEsame, NAU.Patente.erroriAmmessi) },
            { id = 'no', icona = '↩', titolo = 'Un\'altra volta' },
        },
    })
    if conferma ~= 'si' then return end

    local prova, motivo = AUREA.Callback.Attendi('nau:avviaEsame')
    if not prova then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📝', testo = motivo, durata = 11000 })
    end

    local risposte = {}

    for _, d in ipairs(prova.domande) do
        local voci = {}
        for i, o in ipairs(d.opzioni) do
            voci[#voci + 1] = { id = tostring(i), icona = '▸', titolo = o }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Domanda %d di %d'):format(d.numero, #prova.domande),
            sottotitolo = d.domanda,
            voci = voci,
        })

        -- Chi chiude il menu lascia la domanda in bianco: vale come errore
        risposte[d.numero] = scelta and tonumber(scelta) or 0
    end

    local esito = AUREA.Callback.Attendi('nau:consegnaEsame', risposte)
    if not esito then return end

    if esito.promosso then
        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '⚓', durata = 18000,
            titolo = 'Patente nautica conseguita',
            testo = ('%d errori su %d ammessi. Entro 12 miglia puoi navigare.')
                :format(esito.errori, esito.ammessi),
        })
    else
        local voci = {}
        for _, d in ipairs(esito.dettaglio or {}) do
            voci[#voci + 1] = {
                id = 'x', icona = '❌', titolo = d.domanda,
                descrizione = d.nota, disattivata = true,
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', icona = '❌', titolo = 'Esame non superato', disattivata = true }
        end

        exports.aurea_ui:Menu({
            titolo = 'Esame non superato',
            sottotitolo = ('%d errori, ne erano ammessi %d. Ecco dove hai sbagliato.')
                :format(esito.errori, esito.ammessi),
            voci = voci,
        })
    end
end

-- ---------------------------------------------------------------------------
--  Noleggio
-- ---------------------------------------------------------------------------

--- Fa comparire l'unità al pontile.
local function faiComparire(modello, pontile)
    local hash = GetHashKey(modello)
    RequestModel(hash)

    local scadenza = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < scadenza do Wait(0) end
    if not HasModelLoaded(hash) then return end

    local barca = CreateVehicle(hash, pontile.x, pontile.y, pontile.z, pontile.w or 0.0, true, false)
    SetVehicleHasBeenOwnedByPlayer(barca, true)
    SetVehicleNeedsToBeHotwired(barca, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleNumberPlateText(barca, 'NOL' .. math.random(100, 999))
end

local function noleggio(porto)
    local listino, motivo, extra = AUREA.Callback.Attendi('nau:listino', porto.id)
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚓', testo = motivo })
    end

    if extra and extra.inCorso then
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Noleggio in corso',
            sottotitolo = 'Hai già un\'unità fuori.',
            voci = { { id = 'riconsegna', icona = '↩', titolo = 'Riconsegna l\'unità',
                       descrizione = 'Portala all\'ormeggio e conferma qui.' } },
        })
        if scelta ~= 'riconsegna' then return end

        -- I danni si leggono dalla barca più vicina, se c'è
        local danni = 0
        local coord = GetEntityCoords(PlayerPedId())
        for _, v in ipairs(GetGamePool('CVehicle')) do
            if IsThisModelABoat(GetEntityModel(v)) and #(coord - GetEntityCoords(v)) < 25.0 then
                danni = math.floor((1000.0 - GetVehicleBodyHealth(v)) / 10.0)
                break
            end
        end

        local ok, messaggio = AUREA.Callback.Attendi('nau:riconsegna', porto.id, danni)
        return exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚓',
            titolo = ok and 'Riconsegnata' or 'Non riconsegnata',
            testo = messaggio, durata = 14000,
        })
    end

    local voci = {}
    for _, n in ipairs(listino or {}) do
        voci[#voci + 1] = {
            id = n.modello, icona = '🛥',
            titolo = n.nome,
            descrizione = ('%s l\'ora · %d CV%s'):format(
                AUREA.Util.Euro(n.oraria), n.cavalli,
                n.patente and (n.disponibile and ' · richiede patente' or ' · SERVE LA PATENTE') or ''),
            disattivata = not n.disponibile,
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = porto.nome,
        sottotitolo = ('Cauzione %s · %s')
            :format(AUREA.Util.Euro(extra and extra.cauzione or 0),
                    (extra and extra.haPatente) and 'patente nautica valida' or 'nessuna patente nautica'),
        voci = voci,
    })
    if not scelta then return end

    local ok, pontile, messaggio = AUREA.Callback.Attendi('nau:noleggia', porto.id, scelta)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🛥', testo = pontile, durata = 13000 })
    end

    faiComparire(scelta, pontile)
    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🛥', titolo = 'Unità pronta al pontile',
        testo = messaggio, durata = 14000,
    })
end

-- ---------------------------------------------------------------------------
--  Ormeggi
-- ---------------------------------------------------------------------------
local function ormeggi(porto)
    local righe = AUREA.Callback.Attendi('nau:ormeggi', porto.id)

    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = 'r', icona = '⚓',
            titolo = ('%s — %s'):format(r.targa, r.modello),
            descrizione = ('Ormeggiata al porto "%s", canone fino al %s'):format(r.porto, tostring(r.scadenza)),
            disattivata = true,
        }
    end

    table.insert(voci, { id = 'nuovo', icona = '➕', titolo = 'Paga un ormeggio',
                         descrizione = ('Canone mensile %s'):format(AUREA.Util.Euro(porto.canoneMensile)) })

    local scelta = exports.aurea_ui:Menu({
        titolo = ('Ormeggi — %s'):format(porto.nome), voci = voci,
    })
    if scelta ~= 'nuovo' then return end

    local risposte = exports.aurea_ui:Dialogo('Ormeggio', {
        { etichetta = 'Targa dell\'unità', tipo = 'text', obbligatorio = true },
    })
    if not risposte then return end

    local ok, messaggio = AUREA.Callback.Attendi('nau:ormeggia', porto.id, tostring(risposte[1]))
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '⚓', testo = messaggio, durata = 12000,
    })
end

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
RegisterCommand('razzo', function()
    if not exports.aurea_ui:Progresso({
        etichetta = 'Preparazione del razzo...', durata = 5000, blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('nau:razzo')

    if ok then
        -- Il razzo si vede: una luce rossa che sale
        local coord = GetEntityCoords(PlayerPedId())
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('exp_grd_flare', coord.x, coord.y, coord.z + 2.0,
            0.0, 0.0, 0.0, 2.0, false, false, false)
    end

    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🧨',
        titolo = ok and 'Razzo sparato' or 'Non sparato',
        testo = messaggio, durata = 14000,
    })
end, false)

local function personaVicina(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio or 12.0

    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

RegisterCommand('controllonautico', function()
    local b = personaVicina(12.0)
    if not b then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚓', testo = 'Nessuna unità da controllare.' })
    end

    -- Il modello di quello che sta guidando lo legge il client, ma il
    -- server controlla comunque i titoli e le dotazioni nel proprio stato
    local modello = ''
    local ped = GetPlayerPed(GetPlayerFromServerId(b))
    if IsPedInAnyVehicle(ped, false) then
        local v = GetVehiclePedIsIn(ped, false)
        for _, n in ipairs(NAU.Noleggio.listino) do
            if GetEntityModel(v) == GetHashKey(n.modello) then modello = n.modello break end
        end
    end

    local miglia = NAU.MigliaDallaCosta(GetEntityCoords(ped))

    local ok, messaggio = AUREA.Callback.Attendi('nau:controlla', b, modello, miglia)
    exports.aurea_ui:Notifica({
        tipo = ok and 'avviso' or 'errore', icona = '⚓',
        titolo = 'Controllo nautico', testo = messaggio, durata = 20000,
    })
end, false)

RegisterCommand('recupera', function()
    local b = personaVicina(NAU.Soccorso.raggioRecupero)
    if not b then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚓', testo = 'Nessuno da recuperare qui.' })
    end

    if not exports.aurea_ui:Progresso({
        etichetta = 'Recupero in mare...', durata = 8000, blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('nau:recupera', b)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '⚓',
        titolo = 'Soccorso in mare', testo = messaggio, durata = 13000,
    })
end, false)

-- ---------------------------------------------------------------------------
--  Punti sulla mappa
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, p in ipairs(NAU.Porti) do
        local blip = AddBlipForCoord(p.capitaneria)
        SetBlipSprite(blip, p.blip.sprite)
        SetBlipColour(blip, p.blip.colore)
        SetBlipScale(blip, p.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(p.nome)
        EndTextCommandSetBlipName(blip)

        exports.aurea_target:AggiungiZona('nau_cap_' .. p.id, p.capitaneria, 3.0, {
            { etichetta = 'Noleggio unità da diporto', icona = '🛥',
              azione = function() noleggio(p) end },
            { etichetta = 'Esame per la patente nautica', icona = '📝', azione = esame },
            { etichetta = 'Ormeggi', icona = '⚓', azione = function() ormeggi(p) end },
        })
    end
end)
