--[[
    AUREA · Sindacato (client)

    Una bacheca con sopra le vertenze aperte. Il tasto che conta è
    "aderisci", ed è l'unico che il delegato non può premere al posto
    tuo.
]]

local U = AUREA.Util

local function camera()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('sind:stato')
        if not s then return end

        local voci = {}

        if not s.iscritto then
            for _, sg in ipairs(s.sigle) do
                voci[#voci + 1] = {
                    id = 'iscr:' .. sg.id, icona = '🪪',
                    titolo = ('Iscriviti — %s'):format(sg.nome),
                    descrizione = ('Quota %s. Senza iscrizione non si aderisce a niente.')
                        :format(U.Euro(s.quota)),
                }
            end
        else
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🪪',
                titolo = ('Iscritto — %s'):format(s.iscritto.sigla:upper()),
                descrizione = 'Puoi aderire alle vertenze del tuo mestiere.',
            }
        end

        if s.delegato then
            voci[#voci + 1] = { id = 'apri', icona = '📣', titolo = 'Apri una vertenza',
                descrizione = 'Contro un mestiere, non contro una persona.' }
        end

        for _, v in ipairs(s.vertenze) do
            local azione = 'x'
            local nota

            if v.stato == 'sciopero' then
                nota = ('SCIOPERO IN CORSO — %d aderenti'):format(v.adesioni)
                if s.puoScioperare then azione = 'x' end
            elseif v.aderito > 0 then
                nota = ('Hai aderito. Siete in %d.'):format(v.adesioni)
                if s.puoScioperare and v.adesioni >= s.soglie.sciopero then
                    azione = 'procl:' .. tostring(v.id)
                    nota = nota .. '\nPuoi proclamare lo sciopero.'
                end
            elseif v.mio then
                azione = 'ader:' .. tostring(v.id)
                nota = ('Siete in %d. Servono %d per lo sciopero, %d per l\'accordo.')
                    :format(v.adesioni, s.soglie.sciopero, s.soglie.accordo)
            else
                nota = ('Non è il tuo mestiere. Adesioni: %d.'):format(v.adesioni)
                if s.puoScioperare and v.adesioni >= s.soglie.sciopero then
                    azione = 'procl:' .. tostring(v.id)
                    nota = nota .. '\nPuoi proclamare lo sciopero.'
                end
            end

            voci[#voci + 1] = {
                id = azione, disattivata = azione == 'x',
                icona = v.stato == 'sciopero' and '✊' or '📣',
                titolo = ('%s — %s'):format(v.etichettaLavoro, v.nomeOggetto),
                descrizione = ('%s\n%s\nAperta da %s · scade fra %d minuti')
                    :format(v.richiesta, nota, v.promotore or '—', math.max(0, v.minuti or 0)),
            }
        end

        if #s.vertenze == 0 then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '📣',
                titolo = 'Nessuna vertenza aperta',
                descrizione = 'Il che vuol dire tutto o niente, a seconda di come la vedi.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = SIND.Camera.nome,
            sottotitolo = 'Un delegato da solo non è niente',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local sigla = scelta:match('^iscr:(%a+)$')
        if sigla then
            local ok, messaggio = AUREA.Callback.Attendi('sind:iscrivi', sigla)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🪪',
                titolo = 'Sindacato', testo = tostring(messaggio), durata = 14000 })
        end

        local idAder = scelta:match('^ader:(%d+)$')
        if idAder then
            local ok, messaggio = AUREA.Callback.Attendi('sind:aderisci', tonumber(idAder))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '✊',
                titolo = 'Adesione', testo = tostring(messaggio), durata = 16000 })
        end

        local idProcl = scelta:match('^procl:(%d+)$')
        if idProcl then
            local ok, messaggio = AUREA.Callback.Attendi('sind:proclama', tonumber(idProcl))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '✊',
                titolo = 'Sciopero', testo = tostring(messaggio), durata = 20000 })
        end

        if scelta == 'apri' then
            local vociOgg = {}
            for _, o in ipairs(s.oggetti) do
                vociOgg[#vociOgg + 1] = {
                    id = o.id, icona = '📣', titolo = o.nome,
                    descrizione = ('%s\nArretrati in caso di accordo: %s')
                        :format(o.descrizione, U.Euro(o.arretrati)),
                }
            end

            local oggetto = exports.aurea_ui:Menu({
                titolo = 'Su che cosa', sottotitolo = 'Quattro materie, come nella realtà',
                voci = vociOgg })
            if not oggetto then return end

            local r = exports.aurea_ui:Dialogo('Apertura della vertenza', {
                { etichetta = 'Mestiere (es. edile, ristoratore, meccanico)',
                  tipo = 'text', obbligatorio = true },
                { etichetta = 'La richiesta, in una riga', tipo = 'text', obbligatorio = true },
            })
            if not r or not r[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('sind:apri', r[1], oggetto, r[2])
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📣',
                titolo = 'Vertenza', testo = tostring(messaggio), durata = 20000 })
        end
    end)
end

RegisterCommand('sindacato', camera, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SIND.Camera.coord)
    SetBlipSprite(b, SIND.Camera.blip.sprite)
    SetBlipColour(b, SIND.Camera.blip.colore)
    SetBlipScale(b, SIND.Camera.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Camera del lavoro')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('sind_camera', SIND.Camera.coord, SIND.Camera.raggio, {
        { etichetta = 'Camera del lavoro', icona = '✊', azione = camera },
    })
end)
