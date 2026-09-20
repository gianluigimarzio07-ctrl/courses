--[[
    AUREA · Beni culturali (client)

    Il metal detector cerca, la cazzuola scava, e quello che viene fuori
    non si sa quanto vale finché qualcuno non lo perizia. Il client non
    lo sa e non lo mostra: lo scopre solo chi consegna.
]]

local U = AUREA.Util

local ultimoSegnale = nil

-- ---------------------------------------------------------------------------
--  Cercare
-- ---------------------------------------------------------------------------
local function cerca()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({
            etichetta = 'Ricerca con il metal detector',
            durata = BC.Scavo.durataRicerca, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('bc:cerca')
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🔍',
                titolo = 'Metal detector', testo = tostring(esito), durata = 10000 })
        end

        ultimoSegnale = esito.sito

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🔍',
            titolo = 'Segnale netto',
            testo = ('%s.\n%s\nScava qui.'):format(esito.nome,
                esito.autorizzato and 'Lo scavo è autorizzato.'
                    or (esito.vincolato and 'Il sito è vincolato: senza autorizzazione è reato.' or '')),
            durata = 14000,
        })
    end)
end

local function scava()
    CreateThread(function()
        if not ultimoSegnale then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⛏',
                titolo = 'Scavo', testo = 'Prima trova un segnale col metal detector.' })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Scavo', durata = BC.Scavo.durataScavo, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('bc:scava', ultimoSegnale)
        ultimoSegnale = nil

        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⛏',
                titolo = 'Scavo', testo = tostring(esito), durata = 12000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🏺',
            titolo = esito.nome,
            testo = ('Reperto %s da %s.\n\n%s')
                :format(esito.codice, esito.sito,
                        esito.autorizzato
                            and 'Scavo autorizzato: va consegnato in Soprintendenza.'
                            or ('Hai %d minuti per denunciarlo in Soprintendenza. Dopo, detenerlo è reato.')
                                :format(esito.minuti)),
            durata = 22000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  La Soprintendenza
-- ---------------------------------------------------------------------------
local function reperti()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('bc:mieiReperti') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏺',
                titolo = 'Soprintendenza', testo = 'Non detieni nessun reperto.', durata = 10000 })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(r.id),
                icona = r.scaduto and '⛔' or '🏺',
                titolo = ('%s — %s'):format(r.nome, r.codice),
                descrizione = ('%s\n%s'):format(r.nomeSito,
                    r.scaduto and 'TERMINE SCADUTO: la detenzione è illecita, il premio non spetta più.'
                        or ('Restano %d minuti per denunciarlo.'):format(r.minutiResidui)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Denuncia di rinvenimento',
            sottotitolo = 'Art. 90 del Codice dei beni culturali',
            voci = voci,
        })
        if not scelta then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Consegna e perizia',
            durata = 15000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('bc:denuncia', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏺',
            titolo = 'Soprintendenza', testo = tostring(messaggio), durata = 24000 })
    end)
end

local function siti()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('bc:siti')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏺',
                titolo = 'Soprintendenza', testo = 'Riservato ai funzionari in servizio.' })
        end

        local voci = {}
        for _, s in ipairs(righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = s.prelievi >= s.massimo and '⛔' or '🗺',
                titolo = s.nome,
                descrizione = ('Prelievi %d su %d\nAl museo: %d · dispersi o mai consegnati: %d')
                    :format(s.prelievi, s.massimo, s.museo, s.dispersi),
            }
        end

        exports.aurea_ui:Menu({ titolo = 'Stato dei siti',
            sottotitolo = 'Quello che manca è quello che è finito altrove', voci = voci })
    end)
end

local function sede()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = BC.Sede.nome,
            sottotitolo = 'Denunce di rinvenimento, autorizzazioni, tutela',
            voci = {
                { id = 'reperti', icona = '🏺', titolo = 'Denuncia un rinvenimento',
                  descrizione = 'Entro il termine spetta un premio. Dopo, no.' },
                { id = 'siti', icona = '🗺', titolo = 'Stato dei siti',
                  descrizione = 'Riservato ai funzionari.' },
            },
        })
        if scelta == 'reperti' then return reperti() end
        if scelta == 'siti' then return siti() end
    end)
end

-- ---------------------------------------------------------------------------
--  Controllo
-- ---------------------------------------------------------------------------
local function controlla()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Controllo per beni culturali', {
            { etichetta = 'ID della persona', tipo = 'number', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, esito = AUREA.Callback.Attendi('bc:controlla', tonumber(r[1]))
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏺',
                titolo = 'Controllo', testo = tostring(esito), durata = 12000 })
        end

        if esito.reperti == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏺',
                titolo = 'Controllo', testo = ('%s non detiene reperti.'):format(esito.nome),
                durata = 10000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🏺', titolo = 'Sequestro',
            testo = ('%s: %d reperti sequestrati, perizia %s.%s')
                :format(esito.nome, esito.sequestrati, U.Euro(esito.valore),
                        esito.illeciti > 0 and '\nFascicolo aperto: art. 518-bis c.p.' or ''),
            durata = 20000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Il mercato
-- ---------------------------------------------------------------------------
local function mercato()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('bc:mieiReperti') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '💰',
                titolo = 'Non compra aria', testo = 'Non hai niente da mostrargli.' })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(r.id), icona = '🏺',
                titolo = ('%s — %s'):format(r.nome, r.codice),
                descrizione = ('Da %s. Non chiede da dove viene.'):format(r.nomeSito),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Un tizio che non fa domande',
            sottotitolo = 'Paga più dello Stato. Molto di più.',
            voci = voci,
        })
        if not scelta then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Trattativa',
            durata = 12000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('bc:vendi', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💰',
            titolo = 'Cessione', testo = tostring(messaggio), durata = 20000 })
    end)
end

RegisterCommand('soprintendenza', sede, false)
RegisterCommand('controlloreperti', controlla, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(BC.Sede.coord)
    SetBlipSprite(b, BC.Sede.blip.sprite)
    SetBlipColour(b, BC.Sede.blip.colore)
    SetBlipScale(b, BC.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Soprintendenza')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('bc_sede', BC.Sede.coord, BC.Sede.raggio, {
        { etichetta = 'Sportello della Soprintendenza', icona = '🏺', azione = sede },
    })

    exports.aurea_target:AggiungiZona('bc_mercato', BC.Mercato.coord, BC.Mercato.raggio, {
        { etichetta = 'Mostragli quello che hai', icona = '💰', azione = mercato },
    })

    -- Le zone di scavo: il metal detector e la cazzuola si usano lì
    for _, s in ipairs(BC.Siti) do
        exports.aurea_target:AggiungiZona('bc_sito_' .. s.id, s.coord, s.raggio, {
            { etichetta = 'Passa il metal detector', icona = '🔍',
              oggetto = BC.Scavo.attrezzo, azione = cerca },
            { etichetta = 'Scava', icona = '⛏',
              oggetto = BC.Scavo.attrezzoScavo, azione = scava },
        })
    end
end)
