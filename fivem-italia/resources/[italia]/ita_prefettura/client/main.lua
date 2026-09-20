--[[
    AUREA · Prefettura (client)

    Uno sportello e un ufficio dietro. Il cittadino deposita, il
    funzionario istruisce. Nessuna delle due cose decide niente qui:
    la decisione, i termini e l'importo dell'ingiunzione stanno tutti
    sul server.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Depositare un ricorso
-- ---------------------------------------------------------------------------
local function ricorri()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('pref:impugnabili') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '📄',
                titolo = 'Prefettura',
                testo = ('Non hai verbali impugnabili. Si ricorre entro %d giorni dalla notifica.')
                    :format(PREF.Ricorso.giorniPerRicorrere), durata = 12000 })
        end

        local voci = {}
        for _, m in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(m.id),
                icona = '🚗',
                titolo = ('%s — %s'):format(m.articolo, U.Euro(m.importo)),
                descrizione = ('%s\n%s · restano %d giorni per ricorrere')
                    :format(m.descrizione, m.luogo or '—', m.giorniRimasti or 0),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Verbali impugnabili',
            sottotitolo = 'Si sceglie una strada sola: o il Prefetto o il Giudice di Pace',
            voci = voci,
        })
        if not scelta then return end

        local multaId = tonumber(scelta)
        local verbale
        for _, m in ipairs(righe) do if m.id == multaId then verbale = m break end end
        if not verbale then return end

        -- La sede
        local sede = exports.aurea_ui:Menu({
            titolo = 'Dove ricorrere',
            sottotitolo = 'Le due strade sono alternative e non si torna indietro',
            voci = {
                { id = 'prefetto', icona = '🏛', titolo = 'Ricorso al Prefetto',
                  descrizione = ('Gratis. Ma se lo rigetta, l\'ordinanza-ingiunzione è di %s invece di %s (art. 204 CdS).\nSe non decide entro il termine, il ricorso si intende accolto.')
                      :format(U.Euro(verbale.ingiunzione), U.Euro(verbale.importo)) },
                { id = 'giudice_pace', icona = '⚖', titolo = 'Ricorso al Giudice di Pace',
                  descrizione = ('Contributo unificato %s. Se accoglie annulla; se rigetta può comunque ridurre la sanzione.')
                      :format(U.Euro(PREF.Ricorso.contributoUnificato)) },
            },
        })
        if not sede then return end

        -- Il motivo
        local vociMotivo = {}
        for _, m in ipairs(PREF.Ricorso.motivi) do
            vociMotivo[#vociMotivo + 1] = {
                id = m.id, icona = '✎', titolo = m.nome, descrizione = m.descrizione,
            }
        end

        local motivo = exports.aurea_ui:Menu({
            titolo = 'Motivo del ricorso',
            sottotitolo = 'Finisce nel fascicolo. Chi istruisce lo legge.',
            voci = vociMotivo,
        })
        if not motivo then return end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Deposito del ricorso', durata = 8000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('pref:ricorri', multaId, sede, motivo)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📄',
            titolo = 'Prefettura', testo = tostring(messaggio), durata = 22000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Istruttoria (lato ufficio)
-- ---------------------------------------------------------------------------
local function coda()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('pref:coda')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📄',
                titolo = 'Prefettura', testo = 'Non sei in servizio, o non hai la competenza.' })
        end
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '📄',
                titolo = 'Prefettura', testo = 'Nessun ricorso in istruttoria.' })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(r.id),
                icona = r.minutiResidui <= 15 and '⏳' or '📄',
                titolo = ('%s — %s'):format(r.ricorrente or '—', r.motivo),
                descrizione = ('%s · %s · %s\nRilevato da: %s\n%d minuti al silenzio-accoglimento')
                    :format(r.articolo, U.Euro(r.importo_originario), r.luogo or '—',
                            r.origine or '—', r.minutiResidui or 0),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ricorsi in istruttoria',
            sottotitolo = 'Quelli che scadono si accolgono da soli',
            voci = voci,
        })
        if not scelta then return end

        local id = tonumber(scelta)
        local r
        for _, x in ipairs(righe) do if x.id == id then r = x break end end
        if not r then return end

        local decisione = exports.aurea_ui:Menu({
            titolo = ('Ricorso di %s'):format(r.ricorrente or '—'),
            sottotitolo = r.motivo,
            voci = {
                { id = 'accogli', icona = '✅', titolo = 'Accogliere il ricorso',
                  descrizione = 'Il verbale è annullato e i punti tornano.' },
                { id = 'rigetta', icona = '⛔', titolo = 'Rigettare il ricorso',
                  descrizione = r.sede == 'prefetto'
                      and ('Ordinanza-ingiunzione di %s.'):format(U.Euro(r.ingiunzione))
                      or 'Sanzione confermata e ridotta al minimo.' },
            },
        })
        if not decisione then return end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Redazione del provvedimento', durata = 10000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('pref:decidi', id, decisione == 'accogli')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📄',
            titolo = 'Prefettura', testo = tostring(messaggio), durata = 14000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Elenco prefettizio
-- ---------------------------------------------------------------------------
local function elenco()
    CreateThread(function()
        local r, costo = AUREA.Callback.Attendi('pref:elencoStato')

        local descrizione
        if not r then
            descrizione = ('Non risulti iscritto. Istruttoria %s, validità %d giorni.')
                :format(U.Euro(costo or 0), PREF.Elenco.giorniValidita)
        elseif r.sospeso == 1 then
            descrizione = ('SOSPESO — %s'):format(r.motivo_sospensione or 'provvedimento del Prefetto')
        else
            descrizione = ('Iscritto, valido fino al %s.'):format(r.scadenzaIT or '—')
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Elenco addetti ai servizi di controllo',
            sottotitolo = 'Senza iscrizione, sulla porta di un locale non ci si sta',
            voci = {
                { id = 'stato', icona = 'ℹ', titolo = 'La tua posizione',
                  descrizione = descrizione, disattivata = true },
                { id = 'iscrivi', icona = '📝',
                  titolo = r and 'Rinnova l\'iscrizione' or 'Chiedi l\'iscrizione',
                  descrizione = ('Istruttoria %s. Vengono controllati i precedenti: alcuni reati sono ostativi.')
                      :format(U.Euro(costo or 0)) },
            },
        })
        if scelta ~= 'iscrivi' then return end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Istruttoria della domanda',
            durata = PREF.Elenco.secondiIstruttoria * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('pref:elencoIscrivi')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📝',
            titolo = 'Elenco prefettizio', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Lo sportello
-- ---------------------------------------------------------------------------
local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = PREF.Sede.nome,
            sottotitolo = 'Ricorsi, provvedimenti, elenco degli addetti ai servizi di controllo',
            voci = {
                { id = 'ricorri', icona = '📄', titolo = 'Ricorrere contro un verbale',
                  descrizione = ('Entro %d giorni. Al Prefetto è gratis, e costa il doppio se va male.')
                      :format(PREF.Ricorso.giorniPerRicorrere) },
                { id = 'elenco', icona = '📝', titolo = 'Elenco addetti ai servizi di controllo',
                  descrizione = 'L\'iscrizione che serve per fare il filtro in un locale.' },
                { id = 'coda', icona = '🗂', titolo = 'Istruttoria dei ricorsi',
                  descrizione = 'Riservato al personale della Prefettura in servizio.' },
            },
        })
        if scelta == 'ricorri' then return ricorri() end
        if scelta == 'elenco' then return elenco() end
        if scelta == 'coda' then return coda() end
    end)
end

RegisterCommand('prefettura', sportello, false)
RegisterCommand('ricorsi', coda, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(PREF.Sede.coord)
    SetBlipSprite(b, PREF.Sede.blip.sprite)
    SetBlipColour(b, PREF.Sede.blip.colore)
    SetBlipScale(b, PREF.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Prefettura')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('pref_sede', PREF.Sede.coord, PREF.Sede.raggio, {
        { etichetta = 'Sportello della Prefettura', icona = '📄', azione = sportello },
    })
end)
