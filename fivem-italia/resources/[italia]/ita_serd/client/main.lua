--[[
    AUREA · Ser.D. (client)

    Uno sportello che non minaccia niente. È l'unico posto del server in
    cui presentarsi conviene, e la schermata lo dice senza girarci
    intorno.
]]

local U = AUREA.Util

local function sede()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('serd:posizione')
        if not s then return end

        local voci = {}

        for _, seg in ipairs(s.segnalazioni) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = seg.precedenti == 0 and 'ℹ' or '⚠',
                titolo = ('Segnalazione art. 75 — %s')
                    :format(seg.stato == 'in_programma' and 'in programma' or 'convocato'),
                descrizione = ('%d dosi · %d precedenti%s\n%d minuti fa')
                    :format(seg.quantita, seg.precedenti,
                            (seg.patente_sospesa or 0) > 0
                                and ('\nPatente sospesa %d giorni'):format(seg.patente_sospesa)
                                or '',
                            seg.minutiFa or 0),
            }
        end

        if s.programma then
            local p = s.programma
            voci[#voci + 1] = {
                id = (p.attesa or 0) > 0 and 'x' or 'colloquio',
                disattivata = (p.attesa or 0) > 0,
                icona = '🗣',
                titolo = ('Colloquio %d di %d'):format(p.sessioni + 1, p.sessioni_richieste),
                descrizione = (p.attesa or 0) > 0
                    and ('Il prossimo matura fra %d minuti. Un programma non si fa in un pomeriggio.')
                        :format(p.attesa)
                    or 'Serve un operatore in sede. Comincia con un test: se sei ancora positivo, non conta.',
            }
        elseif #s.segnalazioni > 0 then
            voci[#voci + 1] = {
                id = 'aderisci', icona = '🤝', titolo = 'Aderisci a un programma terapeutico',
                descrizione = ('%d colloqui, almeno %d minuti l\'uno dall\'altro.\nSe lo concludi, il procedimento si archivia e la patente torna.')
                    :format(s.sessioniRichieste, s.minutiFra),
            }
        else
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '✅',
                titolo = 'Nessuna segnalazione a tuo carico',
                descrizione = 'Il Ser.D. resta aperto lo stesso.',
            }
        end

        for _, c in ipairs(s.coda) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📋',
                titolo = ('%s — %s'):format(c.nominativo or '—',
                    c.stato == 'in_programma' and 'in programma' or 'convocato'),
                descrizione = ('%d dosi · %d precedenti · %d minuti fa')
                    :format(c.quantita, c.precedenti, c.minutiFa or 0),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = SERD.Sede.nome,
            sottotitolo = 'Qui non si punisce nessuno, e proprio per questo funziona',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if scelta == 'aderisci' then
            local ok, messaggio = AUREA.Callback.Attendi('serd:aderisci')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🤝',
                titolo = 'Ser.D.', testo = tostring(messaggio), durata = 20000 })
        end

        if not exports.aurea_ui:Progresso({ etichetta = 'Colloquio',
            durata = SERD.Programma.durataSecondi * 1000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('serd:colloquio')
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🗣',
                titolo = 'Ser.D.', testo = tostring(esito), durata = 14000 })
        end

        if esito.positivo then
            return exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '🧪',
                titolo = 'Test positivo',
                testo = ('Il colloquio non conta: sei ancora positivo.\nSiamo a %d su %d. Torna quando hai smesso davvero.')
                    :format(esito.sessioni, esito.richieste),
                durata = 18000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🗣',
            titolo = esito.concluso and 'Programma concluso' or 'Colloquio registrato',
            testo = esito.concluso
                and 'Il procedimento ex art. 75 è archiviato. La sospensione della patente è revocata.'
                or ('%d colloqui su %d, con %s.'):format(esito.sessioni, esito.richieste, esito.operatore),
            durata = 20000 })
    end)
end

RegisterCommand('serd', sede, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SERD.Sede.coord)
    SetBlipSprite(b, SERD.Sede.blip.sprite)
    SetBlipColour(b, SERD.Sede.blip.colore)
    SetBlipScale(b, SERD.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Ser.D.')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('serd_sede', SERD.Sede.coord, SERD.Sede.raggio, {
        { etichetta = 'Ser.D.', icona = '🏥', azione = sede },
    })
end)
