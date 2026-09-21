--[[
    AUREA · Calcio (client)

    Un botteghino e una bacheca con la classifica. Il campionato va
    avanti che tu ci sia o no, ed è quello che lo rende credibile.
]]

local U = AUREA.Util

local function stadio()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('cal:stadio')
        if not s then return end

        local voci = {}

        if s.partita then
            local p = s.partita
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '⚽',
                titolo = ('%s — %s contro %s')
                    :format(p.stato == 'in_corso' and 'IN CORSO' or 'Prossima partita',
                            p.nomeCasa, p.nomeOspite),
                descrizione = ('%d spettatori su %d%s')
                    :format(p.spettatori or 0, s.prezzi.capienza,
                            p.stato == 'in_corso'
                                and ('\nParziale: %d - %d'):format(p.gol_casa, p.gol_ospite) or ''),
            }
        end

        if not s.tifoso then
            for _, sq in ipairs(s.squadre) do
                voci[#voci + 1] = {
                    id = 'tessera:' .. sq.codice, icona = '🪪',
                    titolo = ('Tessera del tifoso — %s'):format(sq.nome),
                    descrizione = ('%s. Serve per entrare, e dice di che parte stai.')
                        :format(U.Euro(s.prezzi.tessera)),
                }
            end
        else
            local mia = nil
            for _, sq in ipairs(s.squadre) do
                if sq.codice == s.tifoso.squadra then mia = sq.nome end
            end
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🪪',
                titolo = ('Tessera %s — %s'):format(s.tifoso.tessera, mia or s.tifoso.squadra),
                descrizione = ('%d ingressi.'):format(s.tifoso.ingressi or 0),
            }

            if s.partita then
                voci[#voci + 1] = { id = 'curva', icona = '🎫', titolo = 'Biglietto in curva',
                    descrizione = ('%s. Dove si canta, e dove ogni tanto succede.')
                        :format(U.Euro(s.prezzi.curva)) }
                voci[#voci + 1] = { id = 'tribuna', icona = '🎫', titolo = 'Biglietto in tribuna',
                    descrizione = ('%s. Si vede meglio e si urla di meno.')
                        :format(U.Euro(s.prezzi.tribuna)) }
            end
        end

        local righe = {}
        for i, c in ipairs(s.classifica) do
            righe[#righe + 1] = ('%d. %s — %d punti (%dG %dV %dN %dP, %d:%d)')
                :format(i, c.nome, c.punti, c.giocate, c.vinte, c.pari, c.perse,
                        c.gol_fatti, c.gol_subiti)
        end
        voci[#voci + 1] = {
            id = 'x', disattivata = true, icona = '📊',
            titolo = 'Classifica', descrizione = table.concat(righe, '\n'),
        }

        if #s.ultime > 0 then
            local risultati = {}
            for _, p in ipairs(s.ultime) do
                risultati[#risultati + 1] = ('%s %d - %d %s   (%d spettatori%s)')
                    :format(p.nomeCasa, p.gol_casa, p.gol_ospite, p.nomeOspite,
                            p.spettatori or 0,
                            (p.incidenti or 0) > 0 and (', %d denunciati'):format(p.incidenti) or '')
            end
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📋',
                titolo = 'Ultimi risultati', descrizione = table.concat(risultati, '\n'),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = CAL.Stadio.nome,
            sottotitolo = 'Il campionato va avanti anche senza di te',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local squadra = scelta:match('^tessera:(.+)$')
        if squadra then
            local ok, messaggio = AUREA.Callback.Attendi('cal:tessera', squadra)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🪪',
                titolo = 'Tessera del tifoso', testo = tostring(messaggio), durata = 16000 })
        end

        local ok, messaggio = AUREA.Callback.Attendi('cal:biglietto', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎫',
            titolo = 'Botteghino', testo = tostring(messaggio), durata = 16000 })
    end)
end

RegisterCommand('stadio', stadio, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(CAL.Stadio.coord)
    SetBlipSprite(b, CAL.Stadio.blip.sprite)
    SetBlipColour(b, CAL.Stadio.blip.colore)
    SetBlipScale(b, CAL.Stadio.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Stadio comunale')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('cal_botteghino', CAL.Stadio.ingresso, CAL.Stadio.raggio, {
        { etichetta = 'Botteghino dello stadio', icona = '🎫', azione = stadio },
    })
end)
