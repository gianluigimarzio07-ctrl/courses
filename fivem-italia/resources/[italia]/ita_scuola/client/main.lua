--[[
    AUREA · Università (client)
]]

--- Il quiz: stessa forma per l'esame di corso e per l'esame di Stato.
local function sostieni(prova)
    local risposte = {}

    for _, d in ipairs(prova.domande) do
        local voci = {}
        for i, o in ipairs(d.opzioni) do
            voci[#voci + 1] = { id = tostring(i), icona = '▸', titolo = o }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('%s — domanda %d di %d'):format(prova.materia, d.numero, #prova.domande),
            sottotitolo = d.domanda,
            voci = voci,
        })

        -- Chiudere il menu lascia la domanda in bianco, e vale come errore
        risposte[d.numero] = scelta and tonumber(scelta) or 0
    end

    return risposte
end

local function esitoBocciatura(esito)
    local voci = {}
    for _, d in ipairs(esito.sbagliate or {}) do
        voci[#voci + 1] = { id = 'x', icona = '❌', titolo = d, disattivata = true }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '❌', titolo = 'Prova non superata', disattivata = true }
    end

    exports.aurea_ui:Menu({
        titolo = 'Non superato',
        sottotitolo = ('%d errori. Prossimo appello fra %d minuti.')
            :format(esito.errori, esito.minuti or 0),
        voci = voci,
    })
end

-- ---------------------------------------------------------------------------
--  Segreteria
-- ---------------------------------------------------------------------------
local function segreteria(sede)
    local corsi, obbligatorio = AUREA.Callback.Attendi('scu:situazione', sede.id)

    local voci = {}
    for _, c in ipairs(corsi or {}) do
        local stato
        if c.abilitato then
            stato = 'Abilitato all\'esercizio'
        elseif c.laureato then
            stato = c.esameDiStato and 'Laureato — manca l\'esame di Stato' or 'Laureato'
        elseif c.iscritto then
            stato = ('Iscritto — %d esami su %d'):format(c.fatti, c.totali)
        else
            stato = ('Non iscritto — tasse %s'):format(AUREA.Util.Euro(c.tasse))
        end

        local abilita = ''
        if #c.abilita > 0 and obbligatorio then
            local nomi = {}
            for _, l in ipairs(c.abilita) do
                nomi[#nomi + 1] = (AUREA.Lavori[l] and AUREA.Lavori[l].etichetta) or l
            end
            abilita = ('\nAbilita a: %s'):format(table.concat(nomi, ', '))
        end

        voci[#voci + 1] = {
            id = c.id,
            icona = c.abilitato and '🎖' or (c.laureato and '🎓' or (c.iscritto and '📚' or '📖')),
            titolo = c.nome,
            descrizione = stato .. abilita,
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = sede.nome,
        sottotitolo = obbligatorio
            and 'I titoli sono richiesti per essere assunti nelle professioni'
            or 'I titoli sono facoltativi su questo server',
        voci = voci,
    })
    if not scelta then return end

    local corso
    for _, c in ipairs(corsi) do if c.id == scelta then corso = c end end
    if not corso then return end

    -- Non iscritto: si offre l'iscrizione
    if not corso.iscritto and not corso.laureato then
        local conferma = exports.aurea_ui:Menu({
            titolo = corso.nome,
            sottotitolo = ('Tasse %s · %d esami · %s a esame')
                :format(AUREA.Util.Euro(corso.tasse), corso.totali,
                        AUREA.Util.Euro(corso.tassaEsame)),
            voci = {
                { id = 'si', icona = '✍', titolo = 'Iscriviti' },
                { id = 'no', icona = '↩', titolo = 'Ci penso' },
            },
        })
        if conferma ~= 'si' then return end

        local ok, messaggio = AUREA.Callback.Attendi('scu:iscrivi', corso.id)
        return exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎓',
            titolo = ok and 'Iscrizione registrata' or 'Non iscritto',
            testo = messaggio, durata = 13000,
        })
    end

    -- Laureato ma non abilitato: l'esame di Stato
    if corso.laureato and corso.esameDiStato and not corso.abilitato then
        return exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🎖', durata = 13000,
            titolo = 'Manca l\'abilitazione',
            testo = ('L\'esame di Stato si sostiene al %s.')
                :format(SCU.GetSede(SCU.EsameDiStato.sede).nome),
        })
    end

    -- Iscritto: il libretto
    local elenco = {}
    for _, e in ipairs(corso.esami) do
        elenco[#elenco + 1] = {
            id = e.id, icona = e.superato and '✅' or '📄',
            titolo = e.nome,
            descrizione = e.superato and 'Superato' or 'Da sostenere in aula',
            disattivata = true,
        }
    end

    exports.aurea_ui:Menu({
        titolo = ('Libretto — %s'):format(corso.nome),
        sottotitolo = corso.prossimoAppello
            and ('Prossimo appello: %s'):format(tostring(corso.prossimoAppello))
            or 'Gli esami si sostengono in aula',
        voci = elenco,
    })
end

-- ---------------------------------------------------------------------------
--  Aula
-- ---------------------------------------------------------------------------
local function aula(sede)
    local corsi = AUREA.Callback.Attendi('scu:situazione', sede.id)

    -- All'aula degli Ordini si sostiene solo l'esame di Stato: i corsi
    -- della sede sono vuoti, quindi si guardano tutti quelli che ho
    if sede.id == SCU.EsameDiStato.sede then
        local tutti = AUREA.Callback.Attendi('scu:situazione', 'ateneo')
        local voci = {}

        for _, c in ipairs(tutti or {}) do
            if c.esameDiStato and c.laureato and not c.abilitato then
                voci[#voci + 1] = {
                    id = c.id, icona = '🎖', titolo = ('Esame di Stato — %s'):format(c.nome),
                    descrizione = ('Tassa %s · %d domande, al massimo %d errori')
                        :format(AUREA.Util.Euro(SCU.EsameDiStato.tassa),
                                SCU.EsameDiStato.domande, SCU.EsameDiStato.erroriAmmessi),
                }
            end
        end

        if #voci == 0 then
            voci[1] = { id = 'x', icona = '🎖',
                        titolo = 'Nessun esame di Stato disponibile',
                        descrizione = 'Serve prima la laurea in un corso che lo prevede.',
                        disattivata = true }
        end

        local scelta = exports.aurea_ui:Menu({ titolo = sede.nome, voci = voci })
        if not scelta or scelta == 'x' then return end

        local prova, motivo = AUREA.Callback.Attendi('scu:avviaStato', scelta)
        if not prova then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🎖', testo = motivo, durata = 13000 })
        end

        local esito = AUREA.Callback.Attendi('scu:consegnaStato', sostieni(prova))
        if not esito then return end

        if esito.promosso then
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '🎖', durata = 20000,
                titolo = 'Abilitato all\'esercizio della professione',
                testo = ('%s. Adesso puoi essere assunto.'):format(esito.titolo),
            })
        else
            esitoBocciatura(esito)
        end
        return
    end

    -- Aula universitaria: gli esami del corso
    local voci = {}
    for _, c in ipairs(corsi or {}) do
        if c.iscritto then
            for _, e in ipairs(c.esami) do
                if not e.superato then
                    voci[#voci + 1] = {
                        id = ('%s|%s'):format(c.id, e.id),
                        icona = '📄', titolo = e.nome,
                        descrizione = ('%s · tassa %s'):format(c.nome, AUREA.Util.Euro(c.tassaEsame)),
                    }
                end
            end
        end
    end

    if #voci == 0 then
        voci[1] = { id = 'x', icona = '📚',
                    titolo = 'Nessun esame da sostenere',
                    descrizione = 'Iscriviti in segreteria, oppure li hai finiti tutti.',
                    disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = ('%s — aula'):format(sede.nome),
        sottotitolo = 'Fra un appello e l\'altro passa del tempo',
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    local idCorso, idMateria = scelta:match('^(.-)|(.+)$')

    local prova, motivo = AUREA.Callback.Attendi('scu:avviaEsame', idCorso, idMateria)
    if not prova then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📄', testo = motivo, durata = 13000 })
    end

    local esito = AUREA.Callback.Attendi('scu:consegnaEsame', sostieni(prova))
    if not esito then return end

    if not esito.promosso then
        return esitoBocciatura(esito)
    end

    if esito.laureato then
        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🎓', durata = 22000,
            titolo = 'Laurea conseguita',
            testo = esito.esameDiStato
                and ('%s. Per esercitare serve ancora l\'esame di Stato.'):format(esito.titolo)
                or ('%s. Puoi farti assumere.'):format(esito.titolo),
        })
    else
        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '📄', durata = 14000,
            titolo = ('%s superato'):format(esito.materia),
            testo = ('Ne mancano %d. Prossimo appello fra %d minuti.')
                :format(esito.mancanti, esito.minuti),
        })
    end
end

-- ---------------------------------------------------------------------------
--  Il proprio libretto, ovunque ci si trovi
-- ---------------------------------------------------------------------------
RegisterCommand('titoli', function()
    local righe = AUREA.Callback.Attendi('scu:titoli')

    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = 'r', icona = r.abilitato == 1 and '🎖' or '🎓',
            titolo = r.titolo,
            descrizione = r.abilitato == 1 and 'Abilitato all\'esercizio' or 'Titolo conseguito',
            disattivata = true,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🎓', titolo = 'Nessun titolo di studio', disattivata = true }
    end

    exports.aurea_ui:Menu({ titolo = 'I tuoi titoli', voci = voci })
end, false)

-- ---------------------------------------------------------------------------
--  Punti sulla mappa
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, s in ipairs(SCU.Sedi) do
        local blip = AddBlipForCoord(s.segreteria)
        SetBlipSprite(blip, s.blip.sprite)
        SetBlipColour(blip, s.blip.colore)
        SetBlipScale(blip, s.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.nome)
        EndTextCommandSetBlipName(blip)

        exports.aurea_target:AggiungiZona('scu_seg_' .. s.id, s.segreteria, 3.0, {
            { etichetta = 'Segreteria studenti', icona = '🎓',
              azione = function() segreteria(s) end },
        })

        exports.aurea_target:AggiungiZona('scu_aula_' .. s.id, s.aula, 3.5, {
            { etichetta = s.id == SCU.EsameDiStato.sede and 'Esame di Stato' or 'Sostieni un esame',
              icona = '📄', azione = function() aula(s) end },
        })
    end
end)
