--[[
    AUREA · 112 NUE (client)
    Chiamata del cittadino e quadro operativo per gli enti.
]]

local blipInterventi = {}      -- [id] = blip
local interventoSeguito = nil

-- ---------------------------------------------------------------------------
--  Blip delle centrali operative
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, c in ipairs(NUE.Centrali) do
        local ente = NUE.Enti[c.ente]
        local blip = AddBlipForCoord(c.coord.x, c.coord.y, c.coord.z)
        SetBlipSprite(blip, ente.blip)
        SetBlipColour(blip, ente.colore)
        SetBlipScale(blip, 0.8)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(c.nome)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------------------
--  Chiamata del cittadino
-- ---------------------------------------------------------------------------
RegisterNetEvent('nue:apriChiamata', function()
    CreateThread(function()
        -- Passo 1: natura dell'emergenza, raggruppata come fa un operatore reale
        local gruppi = {
            { id = 'sanitaria', icona = '🚑', titolo = 'Emergenza sanitaria', descrizione = 'Malori, traumi, feriti, intossicazioni.' },
            { id = 'sicurezza', icona = '🚔', titolo = 'Sicurezza e ordine pubblico', descrizione = 'Reati in corso, aggressioni, persone sospette.' },
            { id = 'tecnica',   icona = '🚒', titolo = 'Soccorso tecnico urgente', descrizione = 'Incendi, crolli, fughe di gas, persone bloccate.' },
            { id = 'economica', icona = '💼', titolo = 'Illeciti economici', descrizione = 'Contraffazione, abusivismo, denaro sospetto.' },
        }

        local gruppo = exports.aurea_ui:Menu({
            titolo = '112 · Numero Unico Emergenze',
            sottotitolo = 'Operatore in linea. Di che emergenza si tratta?',
            voci = gruppi,
        })
        if not gruppo then return end

        local mappaGruppi = {
            sanitaria = { 'malore', 'trauma', 'ferita_arma', 'incidente', 'incidente_grave', 'intossicazione' },
            sicurezza = { 'rissa', 'furto', 'rapina', 'spari', 'sospetto', 'disturbo', 'sequestro' },
            tecnica   = { 'incendio', 'fuga_gas', 'persona_bloccata', 'crollo' },
            economica = { 'contraffazione', 'riciclaggio' },
        }

        local voci = {}
        for _, id in ipairs(mappaGruppi[gruppo] or {}) do
            local t = NUE.GetTipologia(id)
            if t then
                local p = NUE.Priorita[t.priorita]
                voci[#voci + 1] = {
                    id = t.id, icona = NUE.Enti[t.ente] and NUE.Enti[t.ente].icona or '🆘',
                    titolo = t.etichetta,
                    descrizione = p.descrizione,
                    valore = p.etichetta,
                }
            end
        end

        local tipologia = exports.aurea_ui:Menu({
            titolo = 'Descrivi l\'emergenza',
            sottotitolo = 'L\'operatore assegnerà il codice di priorità',
            voci = voci,
        })
        if not tipologia then return end

        local indirizzo = AUREA.Indirizzo()
        local valori = exports.aurea_ui:Dialogo('Dettagli per la centrale', {
            { etichetta = 'Cosa sta succedendo?', tipo = 'textarea',
              segnaposto = 'Descrivi la situazione, quante persone sono coinvolte, se ci sono armi...' },
            { etichetta = 'Luogo (verificato dal GPS)', tipo = 'text', valore = indirizzo },
        })
        if not valori then return end

        -- L'animazione della telefonata
        AUREA.Anima('cellphone@', 'cellphone_call_listen_base', 8000, 49)

        local ok, messaggio = AUREA.Callback.Attendi('nue:chiama', tipologia, valori[1], nil, valori[2])
        ClearPedTasks(PlayerPedId())

        exports.aurea_ui:Notifica({
            tipo = ok and 'info' or 'errore',
            icona = '📞', durata = 13000,
            titolo = ok and 'Centrale Operativa 112' or 'Chiamata non registrata',
            testo = messaggio,
        })
    end)
end)

-- ---------------------------------------------------------------------------
--  Ricezione di un intervento (personale in servizio)
-- ---------------------------------------------------------------------------
RegisterNetEvent('nue:intervento', function(i)
    local p = NUE.Priorita[i.priorita]

    exports.aurea_ui:Notifica({
        tipo = i.priorita == 'rosso' and 'errore' or (i.priorita == 'giallo' and 'avviso' or 'polizia'),
        icona = '📻',
        durata = i.priorita == 'rosso' and 16000 or 11000,
        titolo = ('%s · %s'):format(i.codice, p.etichetta),
        testo = ('%s\n%s%s'):format(
            i.tipologia,
            i.indirizzo or 'luogo da accertare',
            (i.descrizione and i.descrizione ~= '') and ('\n« ' .. i.descrizione .. ' »') or ''),
    })

    if i.priorita == 'rosso' then
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    else
        PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    end

    -- Blip temporaneo sul luogo
    if i.coord then
        local blip = AddBlipForCoord(i.coord.x, i.coord.y, i.coord.z)
        SetBlipSprite(blip, 161)
        SetBlipColour(blip, p.colore)
        SetBlipScale(blip, 0.9)
        SetBlipFlashes(blip, i.priorita == 'rosso')
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('%s — %s'):format(i.codice, i.tipologia))
        EndTextCommandSetBlipName(blip)

        blipInterventi[i.id] = blip

        SetTimeout(NUE.Regole.scadenzaMinuti * 60000, function()
            if blipInterventi[i.id] then
                RemoveBlip(blipInterventi[i.id])
                blipInterventi[i.id] = nil
            end
        end)
    end
end)

RegisterNetEvent('nue:interventoChiuso', function(id)
    if blipInterventi[id] then
        RemoveBlip(blipInterventi[id])
        blipInterventi[id] = nil
    end
    if interventoSeguito == id then
        interventoSeguito = nil
        SetWaypointOff()
    end
end)

-- ---------------------------------------------------------------------------
--  Quadro operativo
-- ---------------------------------------------------------------------------
RegisterNetEvent('nue:apriQuadro', function()
    CreateThread(function()
        local interventi = AUREA.Callback.Attendi('nue:interventiAperti') or {}

        if #interventi == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '📻',
                titolo = 'Nessun intervento aperto', testo = 'La situazione è tranquilla.',
            })
        end

        local voci = {}
        for _, i in ipairs(interventi) do
            local p = NUE.Priorita[i.priorita]
            local stato = i.stato == 'attesa' and 'in attesa'
                or i.stato == 'assegnata' and ('assegnato a %d unità'):format(#i.assegnata_a)
                or 'unità sul posto'

            voci[#voci + 1] = {
                id = i.id,
                icona = i.priorita == 'rosso' and '🔴' or i.priorita == 'giallo' and '🟡'
                    or i.priorita == 'verde' and '🟢' or '⚪',
                titolo = ('%s — %s'):format(i.codice, i.tipologia),
                descrizione = ('%s · %s · aperto da %d min'):format(i.indirizzo or '?', stato, i.minuti or 0),
                valore = p.etichetta,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Quadro interventi',
            sottotitolo = 'Ordinati per codice di priorità',
            voci = voci,
        })
        if not scelta then return end

        local intervento
        for _, i in ipairs(interventi) do
            if i.id == scelta then intervento = i break end
        end
        if not intervento then return end

        local azione = exports.aurea_ui:Menu({
            titolo = intervento.codice,
            sottotitolo = ('%s — %s'):format(intervento.tipologia, intervento.indirizzo or '?'),
            voci = {
                { id = 'assegna', icona = '🚨', titolo = 'Prendi in carico', descrizione = 'Ti assegni all\'intervento e ricevi il GPS.' },
                { id = 'gps',     icona = '📍', titolo = 'Imposta il navigatore', descrizione = 'Segna il luogo sulla mappa.' },
                { id = 'posto',   icona = '✅', titolo = 'Comunica arrivo sul posto', descrizione = 'Devi essere entro 60 metri.' },
                { id = 'chiudi',  icona = '📕', titolo = 'Chiudi l\'intervento', descrizione = 'Registra l\'esito in centrale.' },
                { id = 'falsa',   icona = '⚖',  titolo = 'Chiudi come falsa chiamata', descrizione = 'Verbale al chiamante per procurato allarme.' },
                { id = 'nota',    icona = '📝', titolo = 'Dettagli della chiamata',
                  descrizione = intervento.descrizione ~= '' and intervento.descrizione or 'Nessuna descrizione fornita.' },
            },
        })
        if not azione then return end

        if azione == 'assegna' then
            local ok, messaggio, coord = AUREA.Callback.Attendi('nue:assegna', intervento.id)
            if ok and (coord or intervento.coord) then
                local c = coord or intervento.coord
                SetNewWaypoint(c.x, c.y)
                interventoSeguito = intervento.id
            end
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '📻', titolo = ok and 'Presa in carico' or 'Assegnazione rifiutata',
                testo = messaggio, durata = 8000,
            })

        elseif azione == 'gps' then
            if intervento.coord then
                SetNewWaypoint(intervento.coord.x, intervento.coord.y)
                exports.aurea_ui:Notifica({ tipo = 'info', icona = '📍', titolo = 'Navigatore impostato', testo = intervento.indirizzo or '' })
            end

        elseif azione == 'posto' then
            local ok, messaggio = AUREA.Callback.Attendi('nue:inPosto', intervento.id)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '✅', titolo = ok and 'Arrivo comunicato' or 'Comunicazione rifiutata',
                testo = messaggio, durata = 7000,
            })

        elseif azione == 'chiudi' or azione == 'falsa' then
            local valori = exports.aurea_ui:Dialogo('Chiusura intervento', {
                { etichetta = 'Esito da registrare in centrale', tipo = 'textarea',
                  segnaposto = 'Es. Soggetto trasportato in ospedale, nessun ulteriore intervento necessario.' },
            })
            if not valori then return end

            local ok, messaggio = AUREA.Callback.Attendi('nue:chiudi', intervento.id, valori[1], azione == 'falsa')
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '📕', titolo = ok and 'Intervento chiuso' or 'Chiusura rifiutata',
                testo = messaggio, durata = 8000,
            })

        elseif azione == 'nota' then
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📝', durata = 14000,
                titolo = ('%s — dettagli'):format(intervento.codice),
                testo = ('%s\nLuogo: %s\nStato: %s'):format(
                    intervento.descrizione ~= '' and intervento.descrizione or 'Nessuna descrizione.',
                    intervento.indirizzo or '?', intervento.stato),
            })
        end
    end)
end)

-- Scorciatoia da tastiera per il personale in servizio
RegisterCommand('quadro112', function()
    if not AUREA.PG then return end
    if not AUREA.EInServizio() then
        return exports.aurea_ui:Notifica({
            tipo = 'errore', titolo = 'Fuori servizio',
            testo = 'Il quadro interventi è accessibile solo durante il turno.',
        })
    end
    TriggerEvent('nue:apriQuadro')
end, false)
RegisterKeyMapping('quadro112', 'Apri il quadro interventi 112', 'keyboard', 'F6')

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, blip in pairs(blipInterventi) do RemoveBlip(blip) end
end)
