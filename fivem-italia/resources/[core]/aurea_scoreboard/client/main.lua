--[[
    AUREA · Elenco dei collegati (client)
]]

RegisterCommand('collegati', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('score:elenco')
        if not dati then return end

        local voci = {}

        -- Enti in servizio: l'informazione che serve davvero in gioco
        for _, e in ipairs(dati.enti) do
            if e.inServizio > 0 then
                voci[#voci + 1] = {
                    id = 'ente:' .. e.etichetta, icona = e.icona,
                    titolo = e.etichetta,
                    descrizione = ('%d in servizio'):format(e.inServizio),
                    disattivata = true,
                }
            end
        end

        if #voci == 0 then
            voci[#voci + 1] = {
                id = 'nessuno', icona = '💤',
                titolo = 'Nessun ente in servizio',
                descrizione = 'Il 112 potrebbe non ricevere risposta.',
                disattivata = true,
            }
        end

        -- L'elenco nominativo è riservato allo staff
        if dati.eStaff then
            for _, p in ipairs(dati.giocatori) do
                voci[#voci + 1] = {
                    id = p.id, icona = p.proprio and '🟢' or '👤',
                    titolo = ('[%d] %s'):format(p.id, p.nome or 'sconosciuto'),
                    disattivata = true,
                }
            end
        end

        exports.aurea_ui:Menu({
            titolo = ('Collegati: %d/%d'):format(dati.collegati, dati.massimo),
            sottotitolo = dati.eStaff
                and ('Il tuo ID di sessione è %d'):format(dati.tuoId)
                or ('Il tuo ID di sessione è %d · i nomi non sono pubblici'):format(dati.tuoId),
            voci = voci,
        })
    end)
end, false)
RegisterKeyMapping('collegati', 'Mostra i collegati e gli enti in servizio', 'keyboard', 'F10')
