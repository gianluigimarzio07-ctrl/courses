--[[
    AUREA · Agenzia scommesse (client)
]]

local U = AUREA.Util

CreateThread(function()
    for n, a in ipairs(SCO.Agenzie) do
        local b = AddBlipForCoord(a.coord.x, a.coord.y, a.coord.z)
        SetBlipSprite(b, SCO.Blip.sprite)
        SetBlipColour(b, SCO.Blip.colore)
        SetBlipScale(b, SCO.Blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(a.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('scommesse_' .. n, a.coord, 2.5, {
            { etichetta = 'Scommesse', icona = '🎫', azione = function() apri() end },
        })
    end
end)

function apri()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('sco:eventi')
        if not dati then return end

        local voci = {
            { id = 'nuovo', icona = '➕', titolo = 'Apri un evento',
              descrizione = ('Cauzione %s, restituita quando dichiari l\'esito.')
                  :format(U.Euro(dati.regole.cauzioneEvento)) },
        }

        if #dati.eventi == 0 then
            voci[#voci + 1] = { id = '_v', icona = '—', titolo = 'Nessun evento aperto',
                                disattivata = true }
        end

        for _, e in ipairs(dati.eventi) do
            voci[#voci + 1] = {
                id = 'e:' .. e.id,
                icona = e.stato == 'aperto' and '🟢' or '🔴',
                titolo = e.titolo,
                descrizione = ('Aperto da %s · monte %s%s')
                    :format(e.organizzatore, U.Euro(e.monte),
                            e.mia and (' · tu: %s su "%s"'):format(U.Euro(e.mia.importo), e.mia.esito) or ''),
                valore = e.stato == 'aperto' and 'si punta' or 'chiuso',
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ricevitoria',
            sottotitolo = 'Le quote le muove il denaro puntato, non un listino',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'nuovo' then return nuovoEvento() end

        local id = tonumber(scelta:match('^e:(%d+)$'))
        if id then
            for _, e in ipairs(dati.eventi) do
                if e.id == id then return dettaglio(e) end
            end
        end
    end)
end

function dettaglio(e)
    CreateThread(function()
        local voci = {}
        for _, esito in ipairs(e.esiti) do
            voci[#voci + 1] = {
                id = 'p:' .. esito.nome, icona = '🎯', titolo = esito.nome,
                descrizione = ('Puntato %s'):format(U.Euro(esito.puntato)),
                valore = ('quota %.2f'):format(esito.quota),
                disattivata = e.stato ~= 'aperto' or e.mia ~= nil,
            }
        end

        voci[#voci + 1] = { id = 'dichiara', icona = '🏁', titolo = 'Dichiara l\'esito',
                            descrizione = 'Solo chi ha aperto l\'evento, o lo staff.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = e.titolo,
            sottotitolo = e.mia
                and ('Hai già giocato %s su "%s"'):format(U.Euro(e.mia.importo), e.mia.esito)
                or ('Monte totale %s'):format(U.Euro(e.monte)),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'dichiara' then
            local elenco = {}
            for _, esito in ipairs(e.esiti) do
                elenco[#elenco + 1] = { id = esito.nome, icona = '🏁', titolo = esito.nome }
            end
            local vincente = exports.aurea_ui:Menu({
                titolo = 'Chi ha vinto?',
                sottotitolo = 'La dichiarazione è definitiva e paga tutti', voci = elenco,
            })
            if not vincente then return end

            local ok, messaggio = AUREA.Callback.Attendi('sco:dichiara', e.id, vincente)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🏁',
                titolo = 'Esito', testo = messaggio, durata = 14000,
            })
        end

        local esito = scelta:match('^p:(.+)$')
        if not esito then return end

        local r = exports.aurea_ui:Dialogo('Quanto punti?', {
            { etichetta = 'Importo in centesimi', tipo = 'number',
              valore = SCO.Regole.puntataMinima,
              min = SCO.Regole.puntataMinima, max = SCO.Regole.puntataMassima,
              obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('sco:punta', e.id, esito, r[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎫',
            titolo = 'Giocata', testo = messaggio, durata = 13000,
        })
    end)
end

function nuovoEvento()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Nuovo evento', {
            { etichetta = 'Su cosa si scommette', tipo = 'text',
              segnaposto = 'Es. Corsa Vespucci–Aeroporto di stasera', obbligatorio = true },
            { etichetta = 'Esiti possibili, separati da virgola', tipo = 'text',
              segnaposto = 'Es. Rossi, Bianchi, Verdi', obbligatorio = true },
        })
        if not r or not r[1] or not r[2] then return end

        local esiti = {}
        for pezzo in tostring(r[2]):gmatch('[^,]+') do
            local n = pezzo:gsub('^%s+', ''):gsub('%s+$', '')
            if #n > 0 then esiti[#esiti + 1] = n end
        end

        local ok, messaggio = AUREA.Callback.Attendi('sco:apri', r[1], esiti)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎫',
            titolo = 'Evento', testo = messaggio, durata = 13000,
        })
    end)
end

RegisterCommand('scommesse', function() apri() end, false)
