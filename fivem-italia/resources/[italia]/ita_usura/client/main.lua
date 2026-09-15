--[[
    AUREA · Usura (client)

    Chi propone scrive i numeri, chi riceve li legge già giudicati. La
    riga che dice "questo è usura" arriva dal server e non si può
    nascondere: è l'unica protezione che il debitore ha prima di firmare.
]]

local proposta = nil

RegisterNetEvent('usu:proposta', function(p)
    proposta = p
    exports.aurea_ui:Notifica({
        tipo = p.giudizio == 'usurario' and 'errore' or 'avviso',
        icona = '💸', durata = 25000,
        titolo = ('Proposta di prestito da %s'):format(p.creditore),
        testo = ('%s subito, %s da restituire in %d rate da %s.\nTAEG %s — %s\n\nApri /prestito per rispondere.')
            :format(p.capitale, p.totale, p.rate, p.rata, p.taeg, p.spiegazione),
    })
end)

local function vicini(titolo)
    local elenco, ped = {}, PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= USU.Distanza.stipula then
            elenco[#elenco + 1] = { id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)) }
        end
    end
    if #elenco == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💸', titolo = titolo,
            testo = 'Non c\'è nessuno abbastanza vicino.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, voci = elenco })
end

local function presta()
    CreateThread(function()
        local chi = vicini('A chi presti')
        if not chi then return end

        local r = exports.aurea_ui:Dialogo('Condizioni del prestito', {
            { etichetta = 'Quanto gli dai, in euro', tipo = 'number', min = 1, obbligatorio = true },
            { etichetta = 'Quanto deve restituire, in euro', tipo = 'number', min = 1, obbligatorio = true },
            { etichetta = 'In quante rate', tipo = 'number',
              valore = USU.Prestito.rateMinime,
              min = USU.Prestito.rateMinime, max = USU.Prestito.rateMassime, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('usu:proponi',
            tonumber(chi), tonumber(r[1]), tonumber(r[2]), tonumber(r[3]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💸',
            titolo = 'Prestito', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

RegisterCommand('prestito', function()
    CreateThread(function()
        if proposta then
            local scelta = exports.aurea_ui:Menu({
                titolo = ('Prestito da %s'):format(proposta.creditore),
                sottotitolo = proposta.spiegazione,
                voci = {
                    { id = 'x', disattivata = true, icona = '📄', titolo = 'Condizioni',
                      descrizione = ('%s subito · %s in %d rate da %s, una ogni %d minuti · TAEG %s')
                          :format(proposta.capitale, proposta.totale, proposta.rate,
                                  proposta.rata, proposta.minuti, proposta.taeg) },
                    { id = 'si', icona = '✔', titolo = 'Accetto' },
                    { id = 'no', icona = '✖', titolo = 'Rifiuto' },
                },
            })
            if not scelta or scelta == 'x' then return end
            proposta = nil

            local ok, messaggio = AUREA.Callback.Attendi('usu:accetta', scelta == 'si')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💸',
                titolo = 'Prestito', testo = tostring(messaggio), durata = 22000 })
        end

        local debiti, crediti = AUREA.Callback.Attendi('usu:miei')
        debiti, crediti = debiti or {}, crediti or {}

        local voci = {}
        for _, p in ipairs(debiti) do
            voci[#voci + 1] = {
                id = 'd' .. p.id, icona = p.usurario == 1 and '⚠' or '💸',
                titolo = ('Devi %s a %s'):format(AUREA.Util.Euro(p.residuo), p.nome_creditore or '—'),
                descrizione = ('Rate pagate %d di %d · saltate %d · TAEG %.1f%%%s')
                    :format(p.rate_pagate, p.rate, p.rate_saltate, p.taeg * 100,
                            p.usurario == 1 and ' · USURARIO' or ''),
            }
        end
        for _, p in ipairs(crediti) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📈',
                titolo = ('%s ti deve %s'):format(p.nome_debitore or '—', AUREA.Util.Euro(p.residuo)),
                descrizione = ('Rate pagate %d di %d · saltate %d'):format(p.rate_pagate, p.rate, p.rate_saltate),
            }
        end

        voci[#voci + 1] = { id = 'presta', icona = '🤝', titolo = 'Presta a qualcuno',
            descrizione = 'Faccia a faccia, in contanti. Il tasso lo fai tu.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Prestiti fra privati',
            sottotitolo = ('Soglia d\'usura: %.1f%%'):format(USU.TassoSoglia() * 100),
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end
        if scelta == 'presta' then return presta() end

        local id = tonumber(scelta:sub(2))
        local come = exports.aurea_ui:Menu({
            titolo = 'Quanto versi',
            voci = {
                { id = 'rata', icona = '💶', titolo = 'La rata' },
                { id = 'tutto', icona = '💰', titolo = 'Tutto il residuo' },
            },
        })
        if not come then return end

        local ok, messaggio = AUREA.Callback.Attendi('usu:paga', id, come == 'tutto')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💸',
            titolo = 'Prestito', testo = tostring(messaggio), durata = 16000,
        })
    end)
end, false)
