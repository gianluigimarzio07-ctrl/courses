--[[
    AUREA · Agenzia delle Entrate-Riscossione (client)

    Uno sportello dove si fa una cosa sola: decidere come pagare qualcosa
    che devi già. Non c'è un tasto per contestare, perché la contestazione
    si fa altrove — in Prefettura se è un verbale, all'Agenzia delle
    Entrate se è un tributo. Qui si è già oltre.
]]

local U = AUREA.Util

local function posizione()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('ris:posizione')
        if not s then return end

        if #s.ruoli == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '📕',
                titolo = 'Riscossione', testo = 'Non risultano cartelle a tuo carico.', durata = 12000 })
        end

        local voci = {}
        for _, r in ipairs(s.ruoli) do
            local stato
            if r.stato == 'rateizzata' then
                stato = r.prossimaRata
                    and ('Rata %d di %s fra %d minuti%s'):format(
                        r.prossimaRata.numero, U.Euro(r.prossimaRata.importo),
                        math.max(0, r.prossimaRata.minuti or 0),
                        (r.rateSaltate or 0) > 0 and (' · %d rate saltate'):format(r.rateSaltate) or '')
                    or 'Rateizzata'
            elseif r.stato == 'esecutiva' then
                stato = 'ESECUTIVA — possono agire su conto, stipendio e veicoli'
            else
                stato = ('Da pagare entro %d minuti'):format(math.max(0, r.minutiResidui or 0))
            end

            voci[#voci + 1] = {
                id = tostring(r.id),
                icona = r.stato == 'esecutiva' and '⛔' or '📕',
                titolo = ('Cartella n. %d — %s'):format(r.id, r.descrizione),
                descrizione = ('%s\n%s'):format(U.Euro(r.dovuto), stato),
            }
        end

        for _, m in ipairs(s.misure) do
            local nomi = {
                preavviso_fermo = 'Preavviso di fermo',
                fermo = 'Fermo amministrativo',
                ipoteca = 'Ipoteca',
                pignoramento_conto = 'Pignoramento del conto',
                pignoramento_stipendio = 'Pignoramento dello stipendio',
            }
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '⛔',
                titolo = nomi[m.tipo] or m.tipo,
                descrizione = ('%s · %s'):format(tostring(m.bersaglio or '—'), U.Euro(m.importo or 0)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = RIS.Sportello.nome,
            sottotitolo = ('Debito complessivo: %s'):format(U.Euro(s.totale or 0)),
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local id = tonumber(scelta)
        local ruolo
        for _, r in ipairs(s.ruoli) do if r.id == id then ruolo = r break end end
        if not ruolo then return end

        local azioni = {}
        if ruolo.stato == 'rateizzata' then
            azioni[#azioni + 1] = { id = 'rata', icona = '💶', titolo = 'Paga la prossima rata',
                descrizione = ruolo.prossimaRata and U.Euro(ruolo.prossimaRata.importo) or '—' }
        else
            azioni[#azioni + 1] = { id = 'rateizza', icona = '🗓', titolo = 'Chiedi la rateizzazione',
                descrizione = ('Fino a %d rate, interessi %d%%. Dopo %d rate non pagate si decade, e non si concede più.')
                    :format(RIS.Rateizzazione.rateMassime,
                            math.floor(RIS.Rateizzazione.interessi * 100),
                            RIS.Rateizzazione.rateDecadenza) }
        end
        azioni[#azioni + 1] = { id = 'paga', icona = '✅', titolo = 'Paga tutto',
            descrizione = ('%s. Le misure collegate cadono subito.'):format(U.Euro(ruolo.dovuto)) }

        local azione = exports.aurea_ui:Menu({
            titolo = ('Cartella n. %d'):format(ruolo.id),
            sottotitolo = ruolo.descrizione, voci = azioni })
        if not azione then return end

        if azione == 'paga' then
            local ok, messaggio = AUREA.Callback.Attendi('ris:paga', ruolo.id)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📕',
                titolo = 'Riscossione', testo = tostring(messaggio), durata = 16000 })
        end

        if azione == 'rata' then
            local ok, messaggio = AUREA.Callback.Attendi('ris:pagaRata', ruolo.id)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💶',
                titolo = 'Rateizzazione', testo = tostring(messaggio), durata = 16000 })
        end

        if azione == 'rateizza' then
            local r = exports.aurea_ui:Dialogo('Domanda di rateizzazione', {
                { etichetta = ('Numero di rate (2-%d)'):format(RIS.Rateizzazione.rateMassime),
                  tipo = 'number', obbligatorio = true },
            })
            if not r or not r[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('ris:rateizza', ruolo.id, tonumber(r[1]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🗓',
                titolo = 'Rateizzazione', testo = tostring(messaggio), durata = 22000 })
        end
    end)
end

RegisterCommand('cartelle', posizione, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(RIS.Sportello.coord)
    SetBlipSprite(b, RIS.Sportello.blip.sprite)
    SetBlipColour(b, RIS.Sportello.blip.colore)
    SetBlipScale(b, RIS.Sportello.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Agenzia Entrate-Riscossione')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('ris_sportello', RIS.Sportello.coord, RIS.Sportello.raggio, {
        { etichetta = 'Sportello della riscossione', icona = '📕', azione = posizione },
    })
end)
