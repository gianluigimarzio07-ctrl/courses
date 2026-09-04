--[[
    AUREA · Media (client)
]]

local U = AUREA.Util
local inOnda = nil          -- fascia della diretta

-- ---------------------------------------------------------------------------
--  Blip: redazione ed edicole
-- ---------------------------------------------------------------------------
CreateThread(function()
    local blip = AddBlipForCoord(MED.Testata.sede.coord.x, MED.Testata.sede.coord.y, MED.Testata.sede.coord.z)
    SetBlipSprite(blip, MED.Testata.blip.sprite)
    SetBlipColour(blip, MED.Testata.blip.colore)
    SetBlipScale(blip, MED.Testata.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(MED.Testata.nome)
    EndTextCommandSetBlipName(blip)

    for _, e in ipairs(MED.Edicole) do
        local b = AddBlipForCoord(e.coord.x, e.coord.y, e.coord.z)
        SetBlipSprite(b, 184)
        SetBlipColour(b, 46)
        SetBlipScale(b, 0.55)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(e.nome)
        EndTextCommandSetBlipName(b)
    end
end)

-- ---------------------------------------------------------------------------
--  Punti di interazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        local edicola = MED.EdicolaVicina(coord, 2.2)
        if edicola then
            attesa = 0
            exports.aurea_ui:Prompt(true, ('%s — %s'):format(edicola.nome, U.Euro(MED.Copia.prezzo)), 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                compraCopia()
            end

        elseif #(coord - MED.Testata.sede.coord) < 2.4 then
            attesa = 0
            exports.aurea_ui:Prompt(true, 'Redazione', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                apriRedazione()
            end

        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

function compraCopia()
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('med:compra')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📰',
            titolo = MED.Testata.nome, testo = messaggio, durata = 9000,
        })
        if ok then leggiGiornale() end
    end)
end

-- ---------------------------------------------------------------------------
--  Lettura
-- ---------------------------------------------------------------------------
function leggiGiornale()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('med:edizione')
        if not dati then return end

        local voci = {}

        if #dati.articoli == 0 then
            voci[#voci + 1] = { id = '_vuoto', icona = '📰', titolo = 'Nessuna edizione in circolazione',
                                descrizione = 'La redazione non ha ancora mandato in stampa.', disattivata = true }
        end

        for _, a in ipairs(dati.articoli) do
            voci[#voci + 1] = {
                id = 'art:' .. a.id,
                icona = a.tipo == 'rettifica' and '✍' or a.icona,
                titolo = a.titolo,
                descrizione = (a.occhiello ~= '' and a.occhiello .. ' — ' or '')
                    .. ('%s, di %s'):format(a.sezioneNome, a.firma),
                valore = a.quando,
            }
        end

        for _, i in ipairs(dati.inserzioni) do
            voci[#voci + 1] = {
                id = '_ins' .. i.id, icona = '📢',
                titolo = ('Inserzione — %s'):format(i.inserzionista),
                descrizione = i.testo, disattivata = true,
            }
        end

        voci[#voci + 1] = { id = 'archivio', icona = '🗂', titolo = 'Archivio',
                            descrizione = 'Tutti gli arretrati, per sezione.' }
        voci[#voci + 1] = { id = 'inserzione', icona = '📢', titolo = 'Compra uno spazio pubblicitario',
                            descrizione = 'La tua attività, in prima pagina.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = dati.testata,
            sottotitolo = dati.sottotitolo,
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'archivio' then return apriArchivio() end
        if scelta == 'inserzione' then return compraInserzione() end

        local id = scelta:match('^art:(%d+)$')
        if id then apriArticolo(tonumber(id)) end
    end)
end

function apriArchivio()
    CreateThread(function()
        local sezioni = { { id = '', icona = '📰', titolo = 'Tutte le sezioni' } }
        for _, s in ipairs(MED.Sezioni) do
            sezioni[#sezioni + 1] = { id = s.id, icona = s.icona, titolo = s.nome }
        end

        local sezione = exports.aurea_ui:Menu({
            titolo = 'Archivio', sottotitolo = 'Scegli la sezione', voci = sezioni,
        })
        if sezione == nil then return end

        local righe = AUREA.Callback.Attendi('med:archivio', sezione)
        if not righe or #righe == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🗂', titolo = 'Archivio', testo = 'Nessun pezzo in questa sezione.',
            })
        end

        local voci = {}
        for _, a in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(a.id), icona = '📄', titolo = a.titolo,
                descrizione = ('di %s'):format(a.firma), valore = a.quando,
            }
        end

        local scelta = exports.aurea_ui:Menu({ titolo = 'Arretrati', voci = voci })
        if scelta then apriArticolo(tonumber(scelta)) end
    end)
end

function apriArticolo(id)
    CreateThread(function()
        local a = AUREA.Callback.Attendi('med:articolo', id)
        if not a then return end

        -- Il corpo del pezzo si legge a blocchi, come un ritaglio
        local blocchi = {}
        for riga in tostring(a.testo):gmatch('[^\n]+') do
            blocchi[#blocchi + 1] = riga
        end
        if #blocchi == 0 then blocchi[1] = a.testo end

        local voci = {}
        if a.occhiello and a.occhiello ~= '' then
            voci[#voci + 1] = { id = '_occ', icona = '›', titolo = a.occhiello, disattivata = true }
        end
        for n, riga in ipairs(blocchi) do
            voci[#voci + 1] = { id = '_r' .. n, icona = '·', titolo = riga, disattivata = true }
        end
        voci[#voci + 1] = { id = '_firma', icona = '✒', titolo = ('di %s'):format(a.firma),
                            descrizione = a.quando, disattivata = true }

        if a.tipo ~= 'rettifica' then
            voci[#voci + 1] = { id = 'rettifica', icona = '✍', titolo = 'Chiedi la rettifica',
                                descrizione = 'Art. 8 legge 47/1948: hai diritto alla tua versione dei fatti.' }
            voci[#voci + 1] = { id = 'querela', icona = '⚖', titolo = 'Sporgi querela per diffamazione',
                                descrizione = 'Art. 595 c.p. — apre un fascicolo a carico di chi ha firmato.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = a.titolo, sottotitolo = MED.Testata.nome, voci = voci,
        })
        if not scelta then return end

        if scelta == 'rettifica' then
            local risposta = exports.aurea_ui:Dialogo('Richiesta di rettifica', {
                { etichetta = 'La tua versione dei fatti', tipo = 'textarea',
                  segnaposto = 'Come sono andate davvero le cose', obbligatorio = true },
            })
            if not risposta or not risposta[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('med:chiediRettifica', id, risposta[1])
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '✍',
                titolo = 'Rettifica', testo = messaggio, durata = 12000,
            })

        elseif scelta == 'querela' then
            local conferma = exports.aurea_ui:Menu({
                titolo = 'Querela per diffamazione a mezzo stampa',
                sottotitolo = 'Se il pezzo era fondato, la querela ti si ritorce contro nel processo',
                voci = {
                    { id = 'si', icona = '⚖', titolo = 'Deposita la querela' },
                    { id = 'no', icona = '↩', titolo = 'Lascia perdere' },
                },
            })
            if conferma ~= 'si' then return end

            local ok, messaggio = AUREA.Callback.Attendi('med:querela', id)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '⚖',
                titolo = 'Querela', testo = messaggio, durata = 14000,
            })
        end
    end)
end

function compraInserzione()
    CreateThread(function()
        local formati = AUREA.Callback.Attendi('med:formati')
        if not formati then return end

        local voci = {}
        for _, f in ipairs(formati) do
            voci[#voci + 1] = {
                id = f.id, icona = '📢', titolo = f.nome,
                descrizione = ('Resta in edizione per %d uscite.'):format(f.edizioni),
                valore = U.Euro(f.costo),
            }
        end

        local formato = exports.aurea_ui:Menu({
            titolo = 'Spazi pubblicitari', sottotitolo = MED.Testata.nome, voci = voci,
        })
        if not formato then return end

        local risposta = exports.aurea_ui:Dialogo('Testo dell\'inserzione', {
            { etichetta = 'Cosa vuoi far sapere', tipo = 'textarea',
              segnaposto = 'Es. Officina Rossi — tagliandi e revisioni, via Vespucci 12', obbligatorio = true },
        })
        if not risposta or not risposta[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:inserzione', formato, risposta[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📢',
            titolo = 'Inserzione', testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Redazione
-- ---------------------------------------------------------------------------
function apriRedazione()
    CreateThread(function()
        local bilancio = AUREA.Callback.Attendi('med:bilancio')
        if not bilancio then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📰', titolo = 'Redazione',
                testo = 'Si entra solo con il tesserino dell\'ordine.',
            })
        end

        local voci = {
            { id = '_cassa', icona = '🏦', titolo = ('Cassa della testata: %s'):format(U.Euro(bilancio.cassa)),
              descrizione = ('%d pezzi in edizione · %d querele · %d rettifiche omesse')
                  :format(bilancio.pezzi, bilancio.querele, bilancio.rettificheOmesse),
              disattivata = true },
            { id = 'scrivi', icona = '✒', titolo = 'Scrivi un pezzo',
              descrizione = 'Titolo, occhiello e corpo. La firma è la tua.' },
            { id = 'rettifiche', icona = '✍', titolo = 'Richieste di rettifica',
              descrizione = 'Vanno pubblicate entro un\'ora, altrimenti si paga.' },
            { id = 'leggi', icona = '📰', titolo = 'Rileggi l\'edizione' },
        }

        if bilancio.eDirezione then
            voci[#voci + 1] = { id = 'diretta', icona = '📡', titolo = 'Apri un collegamento in diretta',
                                descrizione = 'Serve un operatore della redazione accanto a te.' }
            voci[#voci + 1] = { id = 'chiudi', icona = '⏹', titolo = 'Chiudi il collegamento' }
            voci[#voci + 1] = { id = 'ritira', icona = '🗑', titolo = 'Ritira un pezzo dall\'edizione' }
            voci[#voci + 1] = { id = 'tesserino', icona = '🪪', titolo = 'Rilascia il tesserino',
                                descrizione = 'A chi ti sta accanto.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = MED.Testata.nome, sottotitolo = 'Redazione', voci = voci,
        })
        if not scelta then return end

        if scelta == 'scrivi' then return scriviPezzo() end
        if scelta == 'leggi' then return leggiGiornale() end
        if scelta == 'rettifiche' then return gestisciRettifiche() end
        if scelta == 'diretta' then return apriDiretta() end
        if scelta == 'tesserino' then return rilasciaTesserino() end

        if scelta == 'chiudi' then
            local ok, messaggio = AUREA.Callback.Attendi('med:chiudiDiretta')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'info', icona = '📡',
                titolo = 'Diretta', testo = messaggio, durata = 9000,
            })
        end

        if scelta == 'ritira' then
            local risposta = exports.aurea_ui:Dialogo('Ritiro di un pezzo', {
                { etichetta = 'Numero dell\'articolo', tipo = 'number', valore = 1, min = 1, obbligatorio = true },
                { etichetta = 'Motivo', tipo = 'text', segnaposto = 'Es. notizia non verificata', obbligatorio = true },
            })
            if not risposta or not risposta[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('med:ritira', risposta[1], risposta[2])
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🗑',
                titolo = 'Direzione', testo = messaggio, durata = 10000,
            })
        end
    end)
end

function scriviPezzo()
    CreateThread(function()
        local sezioni = {}
        for _, s in ipairs(MED.Sezioni) do
            sezioni[#sezioni + 1] = { id = s.id, icona = s.icona, titolo = s.nome }
        end

        local sezione = exports.aurea_ui:Menu({
            titolo = 'In che sezione va?', sottotitolo = 'Il taglio cambia il peso del pezzo', voci = sezioni,
        })
        if not sezione then return end

        local risposta = exports.aurea_ui:Dialogo('Nuovo pezzo', {
            { etichetta = 'Titolo', tipo = 'text', segnaposto = 'Il titolo di prima pagina', obbligatorio = true },
            { etichetta = 'Occhiello', tipo = 'text', segnaposto = 'La riga sopra il titolo' },
            { etichetta = 'Corpo dell\'articolo', tipo = 'textarea',
              segnaposto = 'Chi, cosa, quando, dove, perché', obbligatorio = true },
        })
        if not risposta or not risposta[1] or not risposta[3] then return end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Chiusura del pezzo...',
            durata = 6000, annullabile = true,
            anim = { dizionario = 'anim@heists@prison_heiststation@cop_reactions', nome = 'cop_b_idle' },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:pubblica', {
            sezione = sezione, titolo = risposta[1], occhiello = risposta[2] or '', testo = risposta[3],
        })

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📰',
            titolo = ok and 'In stampa' or 'Pezzo respinto', testo = messaggio, durata = 13000,
        })
    end)
end

function gestisciRettifiche()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('med:rettifiche')
        if not righe or #righe == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '✍', titolo = 'Rettifiche',
                testo = 'Nessuna richiesta in attesa.',
            })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(r.id), icona = '✍',
                titolo = ('%s — su "%s"'):format(r.nome_richiedente, r.titolo),
                descrizione = r.testo,
                valore = r.minutiResidui > 0 and ('%d min'):format(r.minutiResidui) or 'scaduta',
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Richieste di rettifica',
            sottotitolo = 'Non pubblicarle costa alla testata',
            voci = voci,
        })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:pubblicaRettifica', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '✍',
            titolo = 'Rettifica', testo = messaggio, durata = 11000,
        })
    end)
end

function apriDiretta()
    CreateThread(function()
        local operatore = giornalistaVicino(MED.Diretta.distanzaOperatore)
        if MED.Diretta.richiedeOperatore and not operatore then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📡', titolo = 'Serve un operatore',
                testo = 'Un collega della redazione deve reggere la telecamera.',
            })
        end

        local risposta = exports.aurea_ui:Dialogo('Collegamento in diretta', {
            { etichetta = 'Titolo del collegamento', tipo = 'text',
              segnaposto = 'Es. Il punto sulle elezioni comunali', obbligatorio = true },
        })
        if not risposta or not risposta[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:avviaDiretta', risposta[1], operatore)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📡',
            titolo = 'Diretta', testo = messaggio, durata = 11000,
        })
    end)
end

function rilasciaTesserino()
    CreateThread(function()
        local bersaglio = giocatoreVicino(3.0)
        if not bersaglio then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🪪', titolo = 'Nessuno accanto a te',
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('med:tesserino', bersaglio)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🪪',
            titolo = 'Ordine dei giornalisti', testo = messaggio, durata = 10000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Fascia della diretta
-- ---------------------------------------------------------------------------
RegisterNetEvent('med:direttaIniziata', function(dati)
    inOnda = dati
end)

RegisterNetEvent('med:direttaChiusa', function(motivo)
    inOnda = nil
    if motivo then
        exports.aurea_ui:Notifica({ tipo = 'info', icona = '📡', titolo = 'Fine del collegamento', testo = motivo })
    end
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(5000)
        local stato = AUREA.Callback.Attendi('med:statoDiretta')
        if stato then inOnda = stato end
    end)
end)

CreateThread(function()
    while true do
        if inOnda then
            local c = inOnda.colore or { 172, 26, 26 }

            -- Barra rossa in basso, come una diretta televisiva
            DrawRect(0.5, 0.938, 1.0, 0.062, 0, 0, 0, 190)
            DrawRect(0.5, 0.972, 1.0, 0.006, c[1], c[2], c[3], 235)
            DrawRect(0.062, 0.938, 0.115, 0.048, c[1], c[2], c[3], 235)

            testo(0.062, 0.922, 0.42, '● DIRETTA', 255, 255, 255, 255, true)
            testo(0.132, 0.918, 0.50, inOnda.titolo or '', 255, 255, 255, 255, false)
            testo(0.132, 0.948, 0.34, ('%s — %s'):format(inOnda.testata or '', inOnda.conduttore or ''),
                  205, 205, 205, 255, false)

            Wait(0)
        else
            Wait(600)
        end
    end
end)

function testo(x, y, scala, contenuto, r, g, b, a, centrato)
    SetTextFont(4)
    SetTextScale(scala, scala)
    SetTextColour(r, g, b, a)
    SetTextCentre(centrato or false)
    SetTextDropShadow()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(contenuto)
    EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('med:nuovaEdizione', function(dati)
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = dati.icona or '📰', durata = 13000,
        titolo = ('%s — %s'):format(MED.Testata.nome, dati.sezione),
        testo = ('%s (di %s)'):format(dati.titolo, dati.firma),
    })
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
RegisterNetEvent('med:apriEdizione', function() leggiGiornale() end)

RegisterCommand('giornale', function() leggiGiornale() end, false)
RegisterCommand('redazione', function() apriRedazione() end, false)

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanzaMigliore = nil, raggio

    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped then
            local d = #(coord - GetEntityCoords(altroPed))
            if d < distanzaMigliore then
                migliore, distanzaMigliore = GetPlayerServerId(altro), d
            end
        end
    end
    return migliore
end

--- L'operatore lo sceglie il server: qui si passa solo il più vicino.
function giornalistaVicino(raggio)
    return giocatoreVicino(raggio)
end
