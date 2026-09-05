--[[
    AUREA · Supporto (client)
]]

local U = AUREA.Util

RegisterCommand('ticket', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('sup:miei')
        if not dati then return end

        local voci = { { id = 'nuovo', icona = '➕', titolo = 'Apri un ticket' } }
        for _, t in ipairs(dati.ticket) do
            local c = SUP.GetCategoria(t.categoria)
            voci[#voci + 1] = {
                id = tostring(t.id), icona = c and c.icona or '❓',
                titolo = ('#%d — %s'):format(t.id, t.titolo),
                descrizione = t.presa_da and ('In carico a %s'):format(t.presa_da)
                    or 'In attesa che qualcuno lo prenda.',
                valore = t.stato,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Supporto', sottotitolo = 'Quello che scrivi resta agli atti', voci = voci,
        })
        if not scelta then return end

        if scelta == 'nuovo' then return nuovo(dati.categorie) end
        apriTicket(tonumber(scelta))
    end)
end, false)

function nuovo(categorie)
    CreateThread(function()
        local voci = {}
        for _, c in ipairs(categorie) do
            voci[#voci + 1] = { id = c.id, icona = c.icona, titolo = c.nome }
        end

        local categoria = exports.aurea_ui:Menu({
            titolo = 'Di cosa si tratta?', voci = voci,
        })
        if not categoria then return end

        local r = exports.aurea_ui:Dialogo('Nuovo ticket', {
            { etichetta = 'Titolo', tipo = 'text', segnaposto = 'In due parole', obbligatorio = true },
            { etichetta = 'Racconta cosa è successo', tipo = 'textarea',
              segnaposto = 'Chi, cosa, quando, dove. Più sei preciso, prima si risolve.',
              obbligatorio = true },
        })
        if not r or not r[1] or not r[2] then return end

        local ok, messaggio = AUREA.Callback.Attendi('sup:apri', categoria, r[1], r[2])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💬',
            titolo = 'Supporto', testo = messaggio, durata = 13000,
        })
    end)
end

function apriTicket(id)
    CreateThread(function()
        local t, errore = AUREA.Callback.Attendi('sup:leggi', id)
        if not t then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Ticket', testo = errore })
        end

        local voci = {}
        for _, m in ipairs(t.messaggi) do
            voci[#voci + 1] = {
                id = '_m' .. #voci, icona = m.staff == 1 and '🛡' or '👤',
                titolo = m.autore, descrizione = m.testo, valore = m.quando,
                disattivata = true,
            }
        end

        if t.stato ~= 'chiuso' then
            voci[#voci + 1] = { id = 'rispondi', icona = '✍', titolo = 'Rispondi' }
        end

        if t.staff then
            if t.stato == 'aperto' then
                voci[#voci + 1] = { id = 'prendi', icona = '🛡', titolo = 'Prendi in carico' }
            end
            if t.stato ~= 'chiuso' then
                voci[#voci + 1] = { id = 'chiudi', icona = '✅', titolo = 'Chiudi il ticket' }
            end
            if t.posizione then
                voci[#voci + 1] = { id = 'vai', icona = '📍', titolo = 'Raggiungi il punto della segnalazione' }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('#%d — %s'):format(t.id, t.titolo),
            sottotitolo = t.presaDa and ('In carico a %s'):format(t.presaDa) or t.stato,
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'rispondi' then
            local r = exports.aurea_ui:Dialogo('Risposta', {
                { etichetta = 'Messaggio', tipo = 'textarea', obbligatorio = true },
            })
            if not r or not r[1] then return end
            local ok, messaggio = AUREA.Callback.Attendi('sup:rispondi', id, r[1])
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💬',
                titolo = 'Ticket', testo = messaggio, durata = 9000,
            })
        end

        if scelta == 'prendi' then
            local ok, posizione = AUREA.Callback.Attendi('sup:prendi', id)
            if ok and type(posizione) == 'table' then
                SetNewWaypoint(posizione.x, posizione.y)
            end
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🛡',
                titolo = 'Ticket', testo = ok and 'Preso in carico. Punto segnato sulla mappa.'
                    or tostring(posizione), durata = 11000,
            })
        end

        if scelta == 'chiudi' then
            local r = exports.aurea_ui:Dialogo('Chiusura', {
                { etichetta = 'Nota finale per il giocatore', tipo = 'textarea' },
            })
            local ok, messaggio = AUREA.Callback.Attendi('sup:chiudi', id, r and r[1] or '')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '✅',
                titolo = 'Ticket', testo = messaggio, durata = 10000,
            })
        end

        if scelta == 'vai' and t.posizione then
            SetNewWaypoint(t.posizione.x, t.posizione.y)
            exports.aurea_ui:Notifica({ tipo = 'info', icona = '📍',
                titolo = 'Segnato sulla mappa' })
        end
    end)
end

RegisterCommand('ticketaperti', function()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('sup:aperti')
        if not elenco or #elenco == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🛡', titolo = 'Supporto', testo = 'Nessun ticket aperto.',
            })
        end

        local voci = {}
        for _, t in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(t.id), icona = t.icona,
                titolo = ('#%d — %s'):format(t.id, t.titolo),
                descrizione = ('%s · %s%s'):format(t.nome, t.nomeCategoria,
                    t.presa_da and (' · in carico a %s'):format(t.presa_da) or ''),
                valore = ('%d min'):format(t.minuti),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ticket aperti', sottotitolo = 'Ordinati per urgenza e attesa', voci = voci,
        })
        if scelta then apriTicket(tonumber(scelta)) end
    end)
end, false)
