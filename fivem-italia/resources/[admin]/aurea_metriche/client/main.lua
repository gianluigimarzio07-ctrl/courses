--[[
    AUREA · Metriche (client)
]]

local U = AUREA.Util

RegisterCommand('metriche', function()
    CreateThread(function()
        local d = AUREA.Callback.Attendi('met:pannello')
        if not d then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '⚙', titolo = 'Metriche',
                testo = 'Non sei autorizzato.',
            })
        end

        local allarmeMassa = d.massa > d.soglie.massaMonetaria

        local voci = {
            { id = '_g', icona = '👥',
              titolo = ('%d connessi · %d in servizio'):format(d.giocatori, d.inServizio),
              descrizione = #d.lavori > 0
                  and ('Più diffuso: %s (%d)'):format(d.lavori[1].nome, d.lavori[1].quanti)
                  or 'Nessuno in partita.',
              disattivata = true },

            { id = '_m', icona = allarmeMassa and '🔴' or '💶',
              titolo = ('Massa monetaria: %s'):format(U.Euro(d.massa)),
              descrizione = d.tendenza
                  and ('Variazione stimata: %s l\'ora'):format(U.Euro(d.tendenza.alOra))
                  or 'Servono più campioni per una tendenza.',
              valore = allarmeMassa and 'oltre soglia' or 'nella norma',
              disattivata = true },

            { id = '_e', icona = '🏛',
              titolo = ('Erario: %s'):format(U.Euro(d.erario)),
              descrizione = d.erario < 0
                  and 'In rosso: lo Stato sta erogando più di quanto incassa.'
                  or 'In attivo.',
              disattivata = true },

            { id = '_p', icona = '📊',
              titolo = ('%d veicoli · %d immobili · %d imprese')
                  :format(d.veicoli, d.immobili, d.imprese),
              disattivata = true },

            { id = 'lavori', icona = '💼', titolo = 'Distribuzione dei lavori' },
            { id = 'storico', icona = '📈', titolo = ('Andamento (%d campioni)'):format(d.campioni) },
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Metriche del server',
            sottotitolo = 'Serve a vedere i problemi prima che li vedano i giocatori',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'lavori' then
            local righe = {}
            for _, l in ipairs(d.lavori) do
                righe[#righe + 1] = { id = '_' .. #righe, icona = '·',
                                      titolo = l.nome, valore = tostring(l.quanti),
                                      disattivata = true }
            end
            return exports.aurea_ui:Menu({
                titolo = 'Chi sta facendo cosa', voci = righe,
            })
        end

        local storico = AUREA.Callback.Attendi('met:storico')
        if not storico or #storico == 0 then return end

        local righe = {}
        for n = #storico, math.max(1, #storico - 20), -1 do
            local c = storico[n]
            righe[#righe + 1] = {
                id = '_s' .. n, icona = '·',
                titolo = ('%s — %d connessi'):format(c.ora, c.giocatori),
                descrizione = ('Massa %s · erario %s'):format(U.Euro(c.massa), U.Euro(c.erario)),
                disattivata = true,
            }
        end

        exports.aurea_ui:Menu({
            titolo = 'Andamento', sottotitolo = 'Dal più recente', voci = righe,
        })
    end)
end, false)
