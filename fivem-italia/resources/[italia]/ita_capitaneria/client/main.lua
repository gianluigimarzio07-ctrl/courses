--[[
    AUREA · Capitaneria di Porto (client)

    Tre cose girano qui: i cerchi delle ordinanze sulla mappa, il
    controllo di chi ci entra dentro, e la griglia di ricerca che vede
    solo chi è in servizio in mare.

    Il controllo sulle ordinanze lo fa il client perché è lui che sa se
    stai nuotando, se hai il motore acceso e a che velocità vai — sono
    tutte cose che stanno nel ped e nel veicolo. Ma il client non decide
    niente: manda un `cap:violazione` con il nome dell'attività, e il
    server guarda se in quel punto c'era davvero un'ordinanza che la
    vietava. Se il client mente dicendo di essere altrove, il verbale non
    parte; se tace, parte lo stesso al prossimo giro.
]]

local U = AUREA.Util

local ordinanze = {}        -- [id] = pacchetto dal server
local blipOrdinanze = {}    -- [id] = { blip, area }
local ricerche = {}
local blipSettori = {}
local natantiFermati = {}   -- [targa] = true

local dentro = {}           -- [id] = true, per non ripetere l'avviso

-- ---------------------------------------------------------------------------
--  I cerchi sulla mappa
-- ---------------------------------------------------------------------------
local function pulisciBlipOrdinanze()
    for id, b in pairs(blipOrdinanze) do
        if DoesBlipExist(b.blip) then RemoveBlip(b.blip) end
        if b.area and DoesBlipExist(b.area) then RemoveBlip(b.area) end
        blipOrdinanze[id] = nil
    end
end

local function disegnaOrdinanze()
    pulisciBlipOrdinanze()
    for _, o in ipairs(ordinanze) do
        local centro = vector3(o.centro.x, o.centro.y, 0.0)

        local area = AddBlipForRadius(centro.x, centro.y, centro.z, o.raggio + 0.0)
        SetBlipColour(area, o.coloreBlip)
        SetBlipAlpha(area, 96)

        local b = AddBlipForCoord(centro)
        SetBlipSprite(b, 315)
        SetBlipColour(b, o.coloreBlip)
        SetBlipScale(b, 0.7)
        SetBlipAsShortRange(b, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(o.etichetta)
        EndTextCommandSetBlipName(b)

        blipOrdinanze[o.id] = { blip = b, area = area }
    end
end

RegisterNetEvent('cap:ordinanze', function(lista)
    ordinanze = lista or {}
    dentro = {}
    disegnaOrdinanze()
end)

RegisterNetEvent('cap:fermata', function(targa, fermata)
    natantiFermati[tostring(targa):upper()] = fermata or nil
end)

RegisterNetEvent('cap:recuperato', function(coord)
    -- Il recupero tira fuori dall'acqua chi è stato trovato: si finisce
    -- sul mezzo che lo ha raccolto, non a riva. A riva ci pensa il 118.
    local ped = PlayerPedId()
    SetEntityCoords(ped, coord.x, coord.y, coord.z + 1.0, false, false, false, false)
    ClearPedTasksImmediately(ped)
    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🆘', durata = 16000,
        titolo = 'Recuperato',
        testo = 'La Guardia Costiera ti ha tirato a bordo. Sei fuori dall\'acqua.',
    })
end)

-- ---------------------------------------------------------------------------
--  Chi entra dove non si può
--
--  Le attività che si possono violare sono quattro, e sono gli stessi
--  nomi che il config chiama `vieta`.
-- ---------------------------------------------------------------------------
local function attivitaCorrente(ped)
    local veicolo = GetVehiclePedIsIn(ped, false)

    if veicolo ~= 0 and IsEntityInWater(veicolo) then
        local nodi = GetEntitySpeed(veicolo) * 1.94384  -- m/s → nodi
        return 'navigazione', veicolo, nodi
    end
    if IsPedSwimming(ped) then
        return 'nuoto', nil, 0
    end
    return nil
end

CreateThread(function()
    while true do
        Wait(1500)

        if #ordinanze == 0 then
            Wait(3000)
        else
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)
            local attivita, veicolo, nodi = attivitaCorrente(ped)

            for _, o in ipairs(ordinanze) do
                local distanza = #(vector2(coord.x, coord.y)
                                 - vector2(o.centro.x, o.centro.y))

                if distanza <= o.raggio then
                    if not dentro[o.id] then
                        dentro[o.id] = true
                        exports.aurea_ui:Notifica({
                            tipo = 'avviso', icona = o.icona, durata = 14000,
                            titolo = o.etichetta,
                            testo = ('%s\nSei dentro l\'area. Esci.'):format(o.motivo),
                        })
                    end

                    if attivita then
                        local targa = veicolo and veicolo ~= 0
                            and (GetVehicleNumberPlateText(veicolo) or ''):gsub('%s+', '') or nil

                        -- La limitazione di velocità si viola solo andando
                        -- forte: starci dentro piano è lecito.
                        if o.tipo == 'velocita' then
                            if attivita == 'navigazione'
                               and nodi > (CAP.GetOrdinanza('velocita').nodiMassimi or 6) then
                                TriggerServerEvent('cap:violazione', 'velocita', targa)
                            end
                        else
                            local d = CAP.GetOrdinanza(o.tipo)
                            if d and d.vieta == attivita then
                                TriggerServerEvent('cap:violazione', attivita, targa)
                            end
                        end
                    end
                else
                    dentro[o.id] = nil
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Un natante sotto fermo non si muove
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(900)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped then
            local targa = (GetVehicleNumberPlateText(veicolo) or ''):gsub('%s+', ''):upper()
            if natantiFermati[targa] then
                SetVehicleEngineOn(veicolo, false, true, true)
                if GetEntitySpeed(veicolo) > 1.0 then
                    SetVehicleForwardSpeed(veicolo, 0.0)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  La griglia di ricerca
-- ---------------------------------------------------------------------------
local function pulisciSettori()
    for _, b in ipairs(blipSettori) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blipSettori = {}
end

local function disegnaSettori()
    pulisciSettori()
    for _, r in ipairs(ricerche) do
        for _, s in ipairs(r.settori) do
            local battuto = r.battuti[tostring(s.indice)] or r.battuti[s.indice]
            local b = AddBlipForRadius(s.x + 0.0, s.y + 0.0, 0.0, CAP.SAR.raggioSettore + 0.0)
            SetBlipColour(b, battuto and 2 or 5)
            SetBlipAlpha(b, battuto and 48 or 110)
            blipSettori[#blipSettori + 1] = b
        end
    end
end

RegisterNetEvent('cap:ricerche', function(lista)
    ricerche = lista or {}
    disegnaSettori()
end)

local function settoreSottoDiMe()
    local coord = GetEntityCoords(PlayerPedId())
    for _, r in ipairs(ricerche) do
        for _, s in ipairs(r.settori) do
            local battuto = r.battuti[tostring(s.indice)] or r.battuti[s.indice]
            if not battuto and #(vector2(coord.x, coord.y) - vector2(s.x, s.y)) <= CAP.SAR.raggioSettore then
                return r, s
            end
        end
    end
end

local function battiSettore()
    CreateThread(function()
        local r, s = settoreSottoDiMe()
        if not r then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🆘',
                titolo = 'Ricerca', testo = 'Non sei dentro un settore ancora da battere.', durata = 10000 })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = ('Settore %s — ricerca in corso'):format(CAP.NomeSettore(s.indice)),
            durata = CAP.SAR.secondiPerSettore * 1000,
            annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('cap:battuto', r.id, s.indice)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🆘',
            titolo = 'Ricerca e soccorso', testo = tostring(messaggio), durata = 16000 })
    end)
end

-- ---------------------------------------------------------------------------
--  L'ufficio
-- ---------------------------------------------------------------------------
local function menuOrdinanze()
    CreateThread(function()
        local attive = AUREA.Callback.Attendi('cap:ordinanzeAttive') or {}

        local voci = {
            { id = '+', icona = '✍', titolo = 'Emettere un\'ordinanza',
              descrizione = 'Chiude un tratto di mare. La firma un ufficiale.' },
        }
        for _, o in ipairs(attive) do
            voci[#voci + 1] = {
                id = tostring(o.id), icona = o.icona,
                titolo = ('%s — %d m'):format(o.etichetta, o.raggio),
                descrizione = ('%s\nFirmata da %s · scade fra %d minuti.\nSeleziona per revocare.')
                    :format(o.motivo, o.ufficiale or '—', o.minutiResidui),
            }
        end
        if #attive == 0 then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '⚓',
                titolo = 'Nessuna ordinanza in vigore' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ordinanze', sottotitolo = 'Provvedimenti sullo specchio acqueo', voci = voci })
        if not scelta or scelta == 'x' then return end

        if scelta ~= '+' then
            local ok, messaggio = AUREA.Callback.Attendi('cap:revoca', tonumber(scelta))
            return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                icona = '⚓', titolo = 'Ordinanze', testo = tostring(messaggio), durata = 12000 })
        end

        local tipi = {}
        for id, d in pairs(CAP.Ordinanze) do
            tipi[#tipi + 1] = { id = id, icona = d.icona, titolo = d.etichetta,
                                descrizione = ('%s\nSanzione %s.'):format(d.descrizione, U.Euro(d.sanzione)) }
        end
        table.sort(tipi, function(a, b) return a.titolo < b.titolo end)

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Che cosa si vieta', sottotitolo = 'L\'area è centrata su dove ti trovi adesso',
            voci = tipi })
        if not tipo then return end

        local raggi = {}
        for _, r in ipairs(CAP.Ordinanza.raggi) do
            raggi[#raggi + 1] = { id = tostring(r), icona = '📐', titolo = ('%d metri'):format(r) }
        end
        local raggio = exports.aurea_ui:Menu({ titolo = 'Raggio dell\'area', voci = raggi })
        if not raggio then return end

        local risposte = exports.aurea_ui:Dialogo('Motivazione dell\'ordinanza', {
            { etichetta = 'Perché', tipo = 'testo', obbligatorio = true,
              segnaposto = 'Mare forza 6 in rapido peggioramento' },
        })
        if not risposte or not risposte[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('cap:emetti', tipo, tonumber(raggio), risposte[1])
        exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '⚓',
            titolo = 'Ordinanze', testo = tostring(messaggio), durata = 14000 })
    end)
end

local function menuRicerche()
    CreateThread(function()
        local aperte = AUREA.Callback.Attendi('cap:ricercheAperte')
        if not aperte then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🆘',
                titolo = 'SAR', testo = 'Riservato a chi è in servizio in mare.', durata = 10000 })
        end

        local voci = {
            { id = '+', icona = '🆘', titolo = 'Aprire una ricerca',
              descrizione = 'La griglia si costruisce sul tuo punto, con la deriva stimata.' },
        }
        for _, r in ipairs(aperte) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🆘',
                titolo = r.motivo,
                descrizione = ('Settori battuti %d su %d · restano %d minuti.')
                    :format(r.quantiBattuti, r.totali, r.minutiResidui),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ricerca e soccorso', sottotitolo = 'Eventi SAR aperti', voci = voci })
        if scelta ~= '+' then return end

        local risposte = exports.aurea_ui:Dialogo('Apertura evento SAR', {
            { etichetta = 'Che cosa si cerca', tipo = 'testo', obbligatorio = true,
              segnaposto = 'Uomo in mare segnalato da un peschereccio' },
        })
        if not risposte or not risposte[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('cap:apriSAR', risposte[1])
        exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '🆘',
            titolo = 'SAR', testo = tostring(messaggio), durata = 14000 })
    end)
end

local function menuFermi()
    CreateThread(function()
        local risposte = exports.aurea_ui:Dialogo('Fermo amministrativo', {
            { etichetta = 'Targa dell\'unità', tipo = 'testo', obbligatorio = true,
              segnaposto = 'AB123CD' },
        })
        if not risposte or not risposte[1] then return end

        local ok, dati = AUREA.Callback.Attendi('cap:statoFermo', risposte[1])
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '⚓',
                titolo = 'Fermi', testo = tostring(dati), durata = 12000 })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Unità %s'):format(dati.targa),
            sottotitolo = 'Sotto fermo amministrativo',
            voci = {
                { id = 'x', disattivata = true, icona = '📄', titolo = 'Motivo',
                  descrizione = ('%s\nFermata da %d minuti.'):format(dati.motivo, dati.minuti) },
                { id = 'paga', icona = '💶', titolo = 'Pagare il dissequestro',
                  descrizione = ('%s. L\'unità torna a navigare subito.'):format(U.Euro(dati.importo)) },
            },
        })
        if scelta ~= 'paga' then return end

        local esito, messaggio = AUREA.Callback.Attendi('cap:dissequestra', dati.targa)
        exports.aurea_ui:Notifica({ tipo = esito and 'successo' or 'errore', icona = '⚓',
            titolo = 'Dissequestro', testo = tostring(messaggio), durata = 16000 })
    end)
end

local function ufficio(sede)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = sede.nome,
            sottotitolo = 'Guardia Costiera',
            voci = {
                { id = 'ordinanze', icona = '⚓', titolo = 'Ordinanze',
                  descrizione = 'I provvedimenti in vigore sullo specchio acqueo.' },
                { id = 'sar', icona = '🆘', titolo = 'Ricerca e soccorso',
                  descrizione = 'Gli eventi SAR aperti e la griglia dei settori.' },
                { id = 'fermi', icona = '🔒', titolo = 'Fermi amministrativi',
                  descrizione = 'Stato di un\'unità e pagamento del dissequestro.' },
            },
        })
        if scelta == 'ordinanze' then return menuOrdinanze() end
        if scelta == 'sar' then return menuRicerche() end
        if scelta == 'fermi' then return menuFermi() end
    end)
end

-- ---------------------------------------------------------------------------
--  Il controllo sottobordo
-- ---------------------------------------------------------------------------
local function controllo()
    CreateThread(function()
        local mio = PlayerPedId()
        local coord = GetEntityCoords(mio)

        -- Chi si controlla: il giocatore più vicino che sta su un natante
        local bersaglio, targa, minima = nil, nil, CAP.Controllo.raggio
        for _, p in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= mio and ped ~= 0 then
                local d = #(coord - GetEntityCoords(ped))
                if d < minima then
                    local v = GetVehiclePedIsIn(ped, false)
                    if v ~= 0 and IsEntityInWater(v) then
                        if GetEntitySpeed(v) * 3.6 > CAP.Controllo.velocitaMassima then
                            -- passa oltre: l'unità non è ferma
                        else
                            minima = d
                            bersaglio = GetPlayerServerId(p)
                            targa = (GetVehicleNumberPlateText(v) or ''):gsub('%s+', ''):upper()
                        end
                    end
                end
            end
        end

        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚓',
                titolo = 'Controllo', testo = 'Nessuna unità ferma sottobordo.', durata = 10000 })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = ('Controllo dell\'unità %s'):format(targa),
            durata = CAP.Controllo.secondiDurata * 1000,
            annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('cap:controlla', targa, bersaglio)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚓',
                titolo = 'Controllo', testo = tostring(esito), durata = 12000 })
        end

        local righe = {
            ('Conducente: %s'):format(esito.conducente),
            ('Patente nautica: %s'):format(esito.patente and 'in regola' or 'MANCANTE'),
            ('Dotazioni: %s'):format(esito.dotazioni and 'presenti' or 'MANCANTI'),
        }
        if #esito.rilievi > 0 then
            righe[#righe + 1] = ''
            righe[#righe + 1] = ('Rilievi: %s'):format(table.concat(esito.rilievi, ' · '))
            righe[#righe + 1] = ('Totale sanzioni: %s'):format(U.Euro(esito.totale))
        end
        if esito.fermato then
            righe[#righe + 1] = ''
            righe[#righe + 1] = 'FERMO AMMINISTRATIVO: l\'unità non lascia l\'ormeggio.'
        elseif esito.giaFermo then
            righe[#righe + 1] = ''
            righe[#righe + 1] = 'L\'unità risultava già sotto fermo.'
        end

        exports.aurea_ui:Notifica({
            tipo = #esito.rilievi == 0 and 'successo' or 'errore',
            icona = '⚓', titolo = ('Controllo unità %s'):format(esito.targa),
            testo = table.concat(righe, '\n'), durata = 26000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Comandi e zone
-- ---------------------------------------------------------------------------
RegisterCommand('capitaneria', function()
    ufficio(CAP.SedePrincipale())
end, false)

RegisterCommand('controllonatante', controllo, false)
RegisterCommand('battisettore', battiSettore, false)

AddEventHandler('aurea:client:caricato', function()
    for _, sede in ipairs(CAP.Sedi) do
        local b = AddBlipForCoord(sede.coord)
        SetBlipSprite(b, sede.blip.sprite)
        SetBlipColour(b, sede.blip.colore)
        SetBlipScale(b, sede.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Capitaneria di Porto')
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('cap_' .. sede.id, sede.coord, sede.raggio, {
            { etichetta = 'Capitaneria di Porto', icona = '⚓',
              azione = function() ufficio(sede) end },
        })
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    pulisciBlipOrdinanze()
    pulisciSettori()
end)
