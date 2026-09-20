--[[
    AUREA · Condominio (client)

    Una bacheca all'ingresso del palazzo. Da lì si fa tutto: si censisce
    la propria unità, si vota, si paga, e se sei l'amministratore si
    ingiunge.
]]

local U = AUREA.Util

local function bacheca(codice)
    CreateThread(function()
        local s = AUREA.Callback.Attendi('con:stato', codice)
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏢',
                titolo = 'Condominio', testo = 'Non riesco a leggere lo stato del condominio.' })
        end

        local voci = {}

        voci[#voci + 1] = {
            id = 'x', disattivata = true, icona = '🏢',
            titolo = s.nome,
            descrizione = ('Fondo: %s · decoro %d/100 (valore degli appartamenti %+d%%)\nTuoi millesimi: %d su %d\nAmministratore: %s')
                :format(U.Euro(s.fondo), s.decoro,
                        math.floor((s.moltiplicatore - 1) * 100),
                        s.mieiMillesimi, CON.Millesimi.totale,
                        s.amministratore and (s.sonoAmministratore and 'tu' or 'nominato') or 'nessuno'),
        }

        for _, c in ipairs(s.candidati) do
            voci[#voci + 1] = {
                id = 'iscrivi:' .. tostring(c.id), icona = '➕',
                titolo = ('Censisci %s'):format(c.nome),
                descrizione = ('Rendita catastale %s: i millesimi si calcolano da lì.')
                    :format(U.Euro(c.rendita_catastale or 0)),
            }
        end

        if s.mieiMillesimi > 0 and not s.sonoAmministratore then
            voci[#voci + 1] = {
                id = 'nomina', icona = '★',
                titolo = s.amministratore and 'Revoca e prendi l\'amministrazione'
                                          or 'Prendi l\'amministrazione',
                descrizione = s.amministratore
                    and ('Servono %d millesimi. Ne hai %d.')
                        :format(CON.Maggioranze.straordinaria.millesimiMinimi, s.mieiMillesimi)
                    or ('Compenso %s a periodo, dal fondo.'):format(U.Euro(s.compenso)),
            }
        end

        if s.sonoAmministratore then
            voci[#voci + 1] = { id = 'proponi', icona = '📋', titolo = 'Proponi una spesa',
                descrizione = 'Ordinaria: un terzo dei millesimi. Straordinaria: cinquecento.' }
        end

        for _, sp in ipairs(s.spese) do
            if sp.stato == 'proposta' then
                voci[#voci + 1] = {
                    id = sp.votata == 0 and ('vota:' .. tostring(sp.id)) or 'x',
                    disattivata = sp.votata ~= 0 or s.mieiMillesimi <= 0,
                    icona = '🗳',
                    titolo = ('%s — %s'):format(sp.descrizione, U.Euro(sp.importo)),
                    descrizione = ('%s · favorevoli %d / contrari %d (servono %d)\n%s')
                        :format(sp.tipo, sp.millesimi_favorevoli, sp.millesimi_contrari,
                                CON.Maggioranze[sp.tipo].millesimiMinimi,
                                sp.votata ~= 0 and 'Hai già votato.'
                                    or ('Aperta da %d minuti su %d.'):format(sp.minuti or 0,
                                        CON.Maggioranze.minutiVotazione)),
                }
            end
        end

        for _, q in ipairs(s.quote) do
            voci[#voci + 1] = {
                id = 'paga:' .. tostring(q.id), icona = '💶',
                titolo = ('Quota — %s'):format(q.descrizione),
                descrizione = ('%s · %s'):format(U.Euro(q.importo),
                    (q.minutiResidui or 0) > 0
                        and ('restano %d minuti'):format(q.minutiResidui)
                        or 'SCADUTA: l\'amministratore può ingiungere'),
            }
        end

        for _, m in ipairs(s.morosi) do
            voci[#voci + 1] = {
                id = m.ingiunta == 1 and 'x' or ('ingiungi:' .. tostring(m.id)),
                disattivata = m.ingiunta == 1,
                icona = '⚖',
                titolo = ('Moroso: %s'):format(m.nominativo or '—'),
                descrizione = ('%s per "%s", in ritardo di %d minuti.\n%s')
                    :format(U.Euro(m.importo), m.descrizione, m.ritardo or 0,
                            m.ingiunta == 1 and 'Già eseguito.'
                                or ('Decreto ingiuntivo: prelievo immediato + %s di spese legali.')
                                    :format(U.Euro(CON.Morosita.speseLegali))),
            }
        end

        if #s.unita > 0 then
            local righe = {}
            for _, u in ipairs(s.unita) do
                righe[#righe + 1] = ('%s — %s (%d)')
                    :format(u.immobile, u.proprietario or 'senza proprietario', u.millesimi)
            end
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '📜',
                titolo = ('Tabella millesimale (%d unità)'):format(#s.unita),
                descrizione = table.concat(righe, '\n') }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Bacheca condominiale',
            sottotitolo = 'Si vota a millesimi, non a testa',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local azione, arg = scelta:match('^(%a+):(.+)$')
        azione = azione or scelta

        if azione == 'iscrivi' then
            local ok, messaggio = AUREA.Callback.Attendi('con:iscrivi', codice, tonumber(arg))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🏢',
                titolo = 'Tabella millesimale', testo = tostring(messaggio), durata = 18000 })
        end

        if azione == 'nomina' then
            local ok, messaggio = AUREA.Callback.Attendi('con:nomina', codice)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '★',
                titolo = 'Amministrazione', testo = tostring(messaggio), durata = 18000 })
        end

        if azione == 'paga' then
            local ok, messaggio = AUREA.Callback.Attendi('con:pagaQuota', tonumber(arg))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💶',
                titolo = 'Quota condominiale', testo = tostring(messaggio), durata = 16000 })
        end

        if azione == 'ingiungi' then
            local ok, messaggio = AUREA.Callback.Attendi('con:ingiungi', tonumber(arg))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '⚖',
                titolo = 'Decreto ingiuntivo', testo = tostring(messaggio), durata = 18000 })
        end

        if azione == 'vota' then
            local voto = exports.aurea_ui:Menu({
                titolo = 'Assemblea',
                sottotitolo = ('Voti con %d millesimi'):format(s.mieiMillesimi),
                voci = {
                    { id = 'si', icona = '✅', titolo = 'Favorevole',
                      descrizione = 'Se passa, la tua quota la paghi anche tu.' },
                    { id = 'no', icona = '⛔', titolo = 'Contrario',
                      descrizione = 'Se passa comunque, la quota la paghi uguale.' },
                },
            })
            if not voto then return end

            local ok, messaggio = AUREA.Callback.Attendi('con:vota', tonumber(arg), voto == 'si')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🗳',
                titolo = 'Assemblea', testo = tostring(messaggio), durata = 18000 })
        end

        if azione == 'proponi' then
            local vociSpesa = {}
            for _, v in ipairs(CON.Spese.voci) do
                vociSpesa[#vociSpesa + 1] = {
                    id = v.id, icona = v.tipo == 'straordinaria' and '🔨' or '🧹',
                    titolo = v.nome,
                    descrizione = ('%s · alza il decoro di %d punti')
                        :format(v.tipo, v.decoro),
                }
            end

            local voce = exports.aurea_ui:Menu({
                titolo = 'Che spesa proporre', sottotitolo = s.nome, voci = vociSpesa })
            if not voce then return end

            local r = exports.aurea_ui:Dialogo('Importo della spesa', {
                { etichetta = ('Importo in centesimi (%d-%d)')
                    :format(CON.Spese.importoMinimo, CON.Spese.importoMassimo),
                  tipo = 'number', obbligatorio = true },
            })
            if not r or not r[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('con:proponi', codice, voce, tonumber(r[1]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📋',
                titolo = 'Convocazione', testo = tostring(messaggio), durata = 20000 })
        end
    end)
end

RegisterCommand('condominio', function()
    CreateThread(function()
        local coord = GetEntityCoords(PlayerPedId())
        local c = CON.CondominioVicino(coord)
        if not c then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🏢',
                titolo = 'Condominio', testo = 'Non sei vicino a nessun condominio censito.' })
        end
        bacheca(c.codice)
    end)
end, false)

AddEventHandler('aurea:client:caricato', function()
    for _, c in ipairs(CON.Condomini) do
        local b = AddBlipForCoord(c.coord)
        SetBlipSprite(b, c.blip.sprite)
        SetBlipColour(b, c.blip.colore)
        SetBlipScale(b, c.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(c.nome)
        EndTextCommandSetBlipName(b)

        local codice = c.codice
        exports.aurea_target:AggiungiZona('con_' .. codice, c.coord, 2.4, {
            { etichetta = 'Bacheca condominiale', icona = '🏢',
              azione = function() bacheca(codice) end },
        })
    end
end)
