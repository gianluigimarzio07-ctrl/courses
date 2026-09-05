--[[
    AUREA · Regolamento (client)
]]

RegisterCommand('regolamento', function()
    CreateThread(function()
        local sezioni = AUREA.Callback.Attendi('reg:sezioni')
        if not sezioni then return end

        local voci = {}
        for _, s in ipairs(sezioni) do
            voci[#voci + 1] = {
                id = s.id, icona = s.icona, titolo = s.titolo,
                descrizione = ('%d punti'):format(#s.voci),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Regolamento',
            sottotitolo = 'Poche regole, e tutte con una ragione dietro',
            voci = voci,
        })
        if not scelta then return end

        local s
        for _, x in ipairs(sezioni) do if x.id == scelta then s = x end end
        if not s then return end

        local righe = {}
        for n, testo in ipairs(s.voci) do
            righe[#righe + 1] = { id = '_' .. n, icona = tostring(n) .. '.',
                                  titolo = testo, disattivata = true }
        end

        exports.aurea_ui:Menu({ titolo = s.titolo, sottotitolo = 'Regolamento', voci = righe })
    end)
end, false)

RegisterNetEvent('reg:tutorial', function(passi)
    CreateThread(function()
        for n, p in ipairs(passi) do
            local voci = {
                { id = '_t', icona = '›', titolo = p.testo, disattivata = true },
                { id = 'avanti', icona = '→',
                  titolo = n < #passi and 'Avanti' or 'Ho capito, cominciamo' },
            }
            if n < #passi then
                voci[#voci + 1] = { id = 'salta', icona = '⏭', titolo = 'Salta il tutorial' }
            end

            local scelta = exports.aurea_ui:Menu({
                titolo = p.titolo,
                sottotitolo = ('%d di %d'):format(n, #passi),
                voci = voci,
            })
            if scelta == 'salta' or not scelta then break end
        end

        AUREA.Callback.Attendi('reg:tutorialVisto')

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🌱', durata = 15000,
            titolo = 'Buon gioco',
            testo = 'Con /regolamento rileggi le regole, con /ticket chiedi aiuto.',
        })
    end)
end)
