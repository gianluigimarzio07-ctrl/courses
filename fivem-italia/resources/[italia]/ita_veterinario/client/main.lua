--[[
    AUREA · Ambulatorio veterinario (client)

    Una sala d'attesa. Sullo schermo c'è quello che il server sa dei tuoi
    animali, e non è sempre una bella lettura.
]]

local U = AUREA.Util

local function ambulatorio()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('vet:miei')
        if not s then return end

        if #s.animali == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🐕',
                titolo = 'Ambulatorio', testo = 'Non hai animali in custodia.', durata = 10000 })
        end

        local voci = {}
        for _, a in ipairs(s.animali) do
            local stato
            if a.maltrattato then
                stato = 'GRAVE: denutrizione e incuria. Un veterinario ha l\'obbligo di segnalarlo.'
            elseif a.malato then
                stato = 'Sta male: va visitato.'
            else
                stato = 'In buone condizioni.'
            end

            voci[#voci + 1] = {
                id = ('visita:%d'):format(a.id),
                icona = a.maltrattato and '⛔' or (a.malato and '⚠' or '🐕'),
                titolo = ('%s — %s'):format(a.nome, a.razza),
                descrizione = ('Fame %d · affetto %d\n%s\n%s\nVisita: %s')
                    :format(a.fame, a.affetto, stato,
                            a.inRegola and 'Vaccinazioni in regola.'
                                        or 'Non in regola: manca l\'antirabbica valida.',
                            U.Euro(s.costoVisita)),
            }

            for _, v in ipairs(s.vaccini) do
                voci[#voci + 1] = {
                    id = ('vac:%d:%s'):format(a.id, v.id),
                    icona = '💉',
                    titolo = ('%s — %s'):format(v.nome, a.nome),
                    descrizione = ('%s\n%s · %d giorni%s')
                        :format(v.descrizione, U.Euro(v.costo), v.giorni,
                                v.obbligatorio and ' · obbligatoria' or ''),
                }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = VET.Ambulatorio.nome,
            sottotitolo = 'Visite e vaccinazioni',
            voci = voci,
        })
        if not scelta then return end

        local idVisita = scelta:match('^visita:(%d+)$')
        if idVisita then
            if not exports.aurea_ui:Progresso({ etichetta = 'Visita',
                durata = VET.Visita.durataSecondi * 1000, annullabile = true }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('vet:visita', tonumber(idVisita))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🩺',
                titolo = 'Ambulatorio', testo = tostring(messaggio), durata = 18000 })
        end

        local idAnimale, tipo = scelta:match('^vac:(%d+):(%a+)$')
        if idAnimale then
            if not exports.aurea_ui:Progresso({ etichetta = 'Somministrazione',
                durata = 12000, annullabile = true }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('vet:vaccina', tonumber(idAnimale), tipo)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💉',
                titolo = 'Vaccinazione', testo = tostring(messaggio), durata = 16000 })
        end
    end)
end

local function accerta()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Accertamento sugli animali', {
            { etichetta = 'ID della persona', tipo = 'number', obbligatorio = true },
        })
        if not r or not r[1] then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Controllo delle condizioni',
            durata = 18000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('vet:accerta', tonumber(r[1]))
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🐕',
                titolo = 'Accertamento', testo = tostring(esito), durata = 12000 })
        end

        if (esito.animali or 0) == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🐕',
                titolo = 'Accertamento',
                testo = ('%s non ha animali in custodia.'):format(esito.nome), durata = 10000 })
        end

        if (esito.maltrattati or 0) == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🐕',
                titolo = 'Accertamento',
                testo = ('%s: %d animali, tutti in condizioni accettabili.')
                    :format(esito.nome, esito.animali), durata = 12000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '⛔',
            titolo = 'Maltrattamento accertato',
            testo = ('%s — %d animali su %d in gravi condizioni:\n%s\n\nSequestrati. Fascicolo art. 544-ter c.p. e sanzione %s.')
                :format(esito.nome, esito.maltrattati, esito.animali,
                        table.concat(esito.nomi or {}, ', '), U.Euro(esito.sanzione or 0)),
            durata = 24000 })
    end)
end

RegisterCommand('veterinario', ambulatorio, false)
RegisterCommand('controlloanimali', accerta, false)

AddEventHandler('aurea:client:caricato', function()
    exports.aurea_target:AggiungiZona('vet_ambulatorio',
        VET.Ambulatorio.coord, VET.Ambulatorio.raggio, {
        { etichetta = 'Ambulatorio veterinario', icona = '🩺', azione = ambulatorio },
        { etichetta = 'Accerta le condizioni di un animale', icona = '⛔',
          lavori = VET.Maltrattamento.lavoriAbilitati, inServizio = true, azione = accerta },
    })
end)
