--[[
    AUREA · Whitelist (client)
]]

local U = AUREA.Util

RegisterNetEvent('wl:compila', function(modulo)
    CreateThread(function()
        Wait(4000)

        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '📄', durata = 20000,
            titolo = 'Devi compilare la candidatura',
            testo = 'Rispondi al modulo per poter giocare. Puoi riaprirlo con /candidatura.',
        })

        compila(modulo)
    end)
end)

function compila(modulo)
    CreateThread(function()
        local risposte = {}

        for _, d in ipairs(modulo) do
            local r = exports.aurea_ui:Dialogo('Candidatura', {
                { etichetta = d.domanda, tipo = d.tipo,
                  segnaposto = d.minimo and ('Almeno %d caratteri'):format(d.minimo) or nil,
                  obbligatorio = d.obbligatoria },
            })
            if not r then
                return exports.aurea_ui:Notifica({
                    tipo = 'avviso', icona = '📄', titolo = 'Candidatura sospesa',
                    testo = 'Riprendila con /candidatura.', durata = 12000,
                })
            end
            risposte[d.id] = tostring(r[1] or '')
        end

        local ok, messaggio = AUREA.Callback.Attendi('wl:invia', risposte)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📄',
            titolo = 'Candidatura', testo = messaggio, durata = 18000,
        })
    end)
end

RegisterCommand('candidatura', function()
    compila(WL.Modulo)
end, false)

RegisterNetEvent('wl:esito', function(accolta, motivo)
    exports.aurea_ui:Notifica({
        tipo = accolta and 'successo' or 'errore', icona = '📄', durata = 20000,
        titolo = accolta and 'Candidatura accolta' or 'Candidatura respinta',
        testo = accolta and 'Benvenuto. Da adesso puoi giocare.'
            or (motivo and motivo ~= '' and motivo or 'Puoi riprovare fra qualche giorno.'),
    })
end)

-- ---------------------------------------------------------------------------
--  Revisione, per lo staff
-- ---------------------------------------------------------------------------
RegisterCommand('candidature', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('wl:candidature')
        if not dati or #dati.candidature == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📄', titolo = 'Candidature',
                testo = 'Nessuna candidatura in esame.',
            })
        end

        local voci = {}
        for _, c in ipairs(dati.candidature) do
            voci[#voci + 1] = {
                id = tostring(c.id), icona = '📄', titolo = c.nome_gioco,
                descrizione = (c.dati.personaggio or ''):sub(1, 90) .. '...',
                valore = c.quando,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Candidature in esame',
            sottotitolo = 'Leggi tutto prima di decidere', voci = voci,
        })
        if not scelta then return end

        local c
        for _, x in ipairs(dati.candidature) do if tostring(x.id) == scelta then c = x end end
        if not c then return end

        local righe = {}
        for _, d in ipairs(dati.modulo) do
            righe[#righe + 1] = { id = '_d' .. d.id, icona = '›', titolo = d.domanda, disattivata = true }
            local testo = c.dati[d.id] or '(nessuna risposta)'
            for pezzo in testo:gmatch('[^\n]+') do
                righe[#righe + 1] = { id = '_r' .. #righe, icona = ' ', titolo = pezzo, disattivata = true }
            end
        end

        righe[#righe + 1] = { id = 'accogli', icona = '✅', titolo = 'Accogli la candidatura' }
        righe[#righe + 1] = { id = 'respingi', icona = '🚫', titolo = 'Respingi' }

        local decisione = exports.aurea_ui:Menu({
            titolo = c.nome_gioco, sottotitolo = c.quando, voci = righe,
        })
        if not decisione or decisione:sub(1, 1) == '_' then return end

        local motivo = ''
        if decisione == 'respingi' then
            local r = exports.aurea_ui:Dialogo('Motivo del rifiuto', {
                { etichetta = 'Cosa dire al candidato', tipo = 'textarea',
                  segnaposto = 'Es. risposte troppo brevi sul regolamento' },
            })
            motivo = r and r[1] or ''
        end

        local ok, messaggio = AUREA.Callback.Attendi('wl:decidi', tonumber(c.id),
            decisione == 'accogli', motivo)

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📄',
            titolo = 'Decisione', testo = messaggio, durata = 11000,
        })
    end)
end, false)
