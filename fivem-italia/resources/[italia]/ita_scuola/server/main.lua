--[[
    AUREA · Università (server)

    Le risposte giuste stanno solo qui. Al client vanno il testo della
    domanda e le alternative in ordine mescolato; la permutazione resta
    sul server, così l'indice che il client rimanda non dice niente a chi
    lo legge in transito.

    L'altra cosa che sta solo qui è la data del prossimo appello: se la
    tenesse il client, la sessione durerebbe quanto pare a lui.
]]

local U = AUREA.Util
local proveInCorso = {}     -- [src] = { corso, materia, domande, permutazioni }

-- ---------------------------------------------------------------------------
--  Carriera
-- ---------------------------------------------------------------------------
local function carriera(citizenid, corso)
    return MySQL.single.await(
        'SELECT * FROM carriere WHERE citizenid = ? AND corso = ? LIMIT 1',
        { citizenid, corso })
end

local function esamiSuperati(citizenid, corso)
    local righe = MySQL.query.await(
        'SELECT materia FROM esami_superati WHERE citizenid = ? AND corso = ?',
        { citizenid, corso }) or {}

    local set = {}
    for _, r in ipairs(righe) do set[r.materia] = true end
    return set
end

--- Il titolo c'è, ed è valido? Lo usano aurea_azienda e chi vuole.
local function haTitolo(citizenid, idCorso)
    local riga = MySQL.scalar.await(
        'SELECT id FROM titoli WHERE citizenid = ? AND corso = ? LIMIT 1',
        { citizenid, idCorso })
    return riga ~= nil
end

exports('HaTitolo', haTitolo)

--- Questo lavoro richiede un titolo, e la persona ce l'ha?
exports('AbilitatoAlLavoro', function(citizenid, lavoro)
    if not SCU.Obbligatorio then return true end

    local corso = SCU.CorsoPerLavoro(lavoro)
    if not corso then return true end

    if not haTitolo(citizenid, corso.id) then return false, corso.titolo end

    if corso.esameDiStato then
        local abilitato = MySQL.scalar.await(
            'SELECT id FROM titoli WHERE citizenid = ? AND corso = ? AND abilitato = 1 LIMIT 1',
            { citizenid, corso.id })
        if not abilitato then return false, 'l\'abilitazione (esame di Stato)' end
    end

    return true
end)

-- ---------------------------------------------------------------------------
--  Segreteria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('scu:situazione', function(src, rispondi, idSede)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}

    for _, c in ipairs(SCU.Corsi) do
        if c.sede == idSede then
            local iscritto = carriera(g.citizenid, c.id)
            local superati = esamiSuperati(g.citizenid, c.id)

            local fatti, elenco = 0, {}
            for _, materia in ipairs(c.esami) do
                local m = SCU.GetMateria(materia)
                local ok = superati[materia] == true
                if ok then fatti = fatti + 1 end
                elenco[#elenco + 1] = { id = materia, nome = m and m.nome or materia, superato = ok }
            end

            local titolo = haTitolo(g.citizenid, c.id)
            local abilitato = titolo and MySQL.scalar.await(
                'SELECT id FROM titoli WHERE citizenid = ? AND corso = ? AND abilitato = 1 LIMIT 1',
                { g.citizenid, c.id }) ~= nil or false

            out[#out + 1] = {
                id = c.id, nome = c.nome, titolo = c.titolo,
                tasse = c.tasse, tassaEsame = SCU.Regole.tassaEsame,
                iscritto = iscritto ~= nil,
                esami = elenco, fatti = fatti, totali = #c.esami,
                laureato = titolo,
                esameDiStato = c.esameDiStato or false,
                abilitato = abilitato,
                abilita = c.abilita,
                prossimoAppello = iscritto and iscritto.prossimo_appello or nil,
            }
        end
    end

    rispondi(out, SCU.Obbligatorio)
end)

AUREA.Callback.Registra('scu:iscrivi', function(src, rispondi, idCorso)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local c = SCU.GetCorso(idCorso)
    if not c then return rispondi(false, 'Corso inesistente.') end

    local sede = SCU.GetSede(c.sede)
    if #(GetEntityCoords(GetPlayerPed(src)) - sede.segreteria) > 6.0 then
        return rispondi(false, 'Devi essere in segreteria.')
    end

    if carriera(g.citizenid, idCorso) then return rispondi(false, 'Sei già iscritto.') end
    if haTitolo(g.citizenid, idCorso) then return rispondi(false, 'Sei già laureato in questo corso.') end

    if not g:SottraiOvunque(c.tasse, ('tasse universitarie — %s'):format(c.nome)) then
        return rispondi(false, ('Le tasse d\'iscrizione sono %s.'):format(U.Euro(c.tasse)))
    end
    TriggerEvent('aurea:fisco:incasso', 'tasse_universitarie', c.tasse, g.citizenid)

    MySQL.insert.await(
        'INSERT INTO carriere (citizenid, corso, iscritto_il) VALUES (?, ?, NOW())',
        { g.citizenid, idCorso })

    AUREA.Log('anagrafe', 'info', g, ('si è iscritto a %s'):format(c.nome))
    rispondi(true, ('Iscritto a %s. Hai %d esami davanti.'):format(c.nome, #c.esami))
end)

-- ---------------------------------------------------------------------------
--  Esami
-- ---------------------------------------------------------------------------

--- Prepara un pacchetto di domande e ne tiene la chiave qui.
local function preparaProva(src, elencoDomande, quante, erroriAmmessi)
    local indici = {}
    for n = 1, #elencoDomande do indici[n] = n end
    for n = #indici, 2, -1 do
        local j = math.random(n)
        indici[n], indici[j] = indici[j], indici[n]
    end

    local scelte, pubbliche, permutazioni = {}, {}, {}

    for n = 1, math.min(quante, #indici) do
        local q = elencoDomande[indici[n]]
        scelte[n] = q

        local ordine = {}
        for i = 1, #q.o do ordine[i] = i end
        for i = #ordine, 2, -1 do
            local j = math.random(i)
            ordine[i], ordine[j] = ordine[j], ordine[i]
        end
        permutazioni[n] = ordine

        local opzioni = {}
        for i, o in ipairs(ordine) do opzioni[i] = q.o[o] end

        pubbliche[n] = { numero = n, domanda = q.d, opzioni = opzioni }
    end

    return scelte, pubbliche, permutazioni, erroriAmmessi
end

local function correggi(prova, risposte)
    local errori, sbagliate = 0, {}

    for n, q in ipairs(prova.domande) do
        local scelta = tonumber((risposte or {})[n])
        local originale = scelta and prova.permutazioni[n][scelta] or nil
        if originale ~= q.g then
            errori = errori + 1
            sbagliate[#sbagliate + 1] = q.d
        end
    end

    return errori, sbagliate
end

AUREA.Callback.Registra('scu:avviaEsame', function(src, rispondi, idCorso, idMateria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c = SCU.GetCorso(idCorso)
    local m = SCU.GetMateria(idMateria)
    if not c or not m then return rispondi(nil, 'Esame inesistente.') end
    if not U.Contiene(c.esami, idMateria) then return rispondi(nil, 'Non è un esame di questo corso.') end

    local sede = SCU.GetSede(c.sede)
    if #(GetEntityCoords(GetPlayerPed(src)) - sede.aula) > 6.0 then
        return rispondi(nil, 'Gli esami si sostengono in aula.')
    end

    local iscrizione = carriera(g.citizenid, idCorso)
    if not iscrizione then return rispondi(nil, 'Non risulti iscritto.') end

    if esamiSuperati(g.citizenid, idCorso)[idMateria] then
        return rispondi(nil, 'Questo esame l\'hai già superato.')
    end

    -- La sessione: fra un appello e l'altro deve passare del tempo
    if iscrizione.prossimo_appello then
        local mancano = MySQL.scalar.await(
            'SELECT TIMESTAMPDIFF(MINUTE, NOW(), ?)', { iscrizione.prossimo_appello }) or 0
        if mancano > 0 then
            return rispondi(nil, ('Il prossimo appello è fra %d minuti.'):format(mancano))
        end
    end

    if not g:SottraiOvunque(SCU.Regole.tassaEsame, ('tassa d\'esame — %s'):format(m.nome)) then
        return rispondi(nil, ('La tassa d\'esame è %s.'):format(U.Euro(SCU.Regole.tassaEsame)))
    end
    TriggerEvent('aurea:fisco:incasso', 'tasse_universitarie', SCU.Regole.tassaEsame, g.citizenid)

    local domande, pubbliche, permutazioni = preparaProva(src, m.domande, SCU.Regole.domandePerEsame)
    proveInCorso[src] = {
        tipo = 'esame', corso = idCorso, materia = idMateria,
        domande = domande, permutazioni = permutazioni,
        erroriAmmessi = SCU.Regole.erroriAmmessi,
    }

    rispondi({ materia = m.nome, domande = pubbliche, erroriAmmessi = SCU.Regole.erroriAmmessi })
end)

AUREA.Callback.Registra('scu:consegnaEsame', function(src, rispondi, risposte)
    local g = AUREA.GetPlayer(src)
    local prova = proveInCorso[src]
    if not g or not prova or prova.tipo ~= 'esame' then return rispondi(nil, 'Nessun esame in corso.') end

    proveInCorso[src] = nil

    local errori, sbagliate = correggi(prova, risposte)
    local promosso = errori <= prova.erroriAmmessi
    local c = SCU.GetCorso(prova.corso)
    local m = SCU.GetMateria(prova.materia)

    local minuti = promosso and SCU.Regole.minutiFraEsami or SCU.Regole.minutiDopoBocciatura
    MySQL.update(
        'UPDATE carriere SET prossimo_appello = DATE_ADD(NOW(), INTERVAL ? MINUTE) WHERE citizenid = ? AND corso = ?',
        { minuti, g.citizenid, prova.corso })

    if not promosso then
        return rispondi({
            promosso = false, errori = errori, sbagliate = sbagliate,
            minuti = minuti, materia = m.nome,
        })
    end

    MySQL.query.await([[
        INSERT INTO esami_superati (citizenid, corso, materia, superato_il)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE superato_il = NOW()
    ]], { g.citizenid, prova.corso, prova.materia })

    -- Finiti tutti? Allora è laurea.
    local superati = esamiSuperati(g.citizenid, prova.corso)
    local mancanti = 0
    for _, materia in ipairs(c.esami) do
        if not superati[materia] then mancanti = mancanti + 1 end
    end

    local laureato = false
    if mancanti == 0 and not haTitolo(g.citizenid, prova.corso) then
        laureato = true

        MySQL.insert.await(
            'INSERT INTO titoli (citizenid, corso, titolo, conseguito_il) VALUES (?, ?, ?, NOW())',
            { g.citizenid, prova.corso, c.titolo })

        MySQL.update('DELETE FROM carriere WHERE citizenid = ? AND corso = ?', { g.citizenid, prova.corso })

        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        inv:Aggiungi('laurea', 1, {
            titolo = c.titolo,
            intestatario = g:NomeCompleto(),
            conseguita = U.DataIT(os.time()),
            ateneo = SCU.GetSede(c.sede).nome,
        })
        TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

        AUREA.Log('anagrafe', 'info', g, ('si è laureato: %s'):format(c.titolo))

        exports.aurea_ui:NotificaTutti({
            tipo = 'successo', icona = '🎓', durata = 12000,
            titolo = 'Nuova laurea',
            testo = ('%s ha conseguito la %s.'):format(g:NomeCompleto(), c.titolo),
        })
    end

    rispondi({
        promosso = true, errori = errori, materia = m.nome,
        mancanti = mancanti, laureato = laureato,
        titolo = c.titolo, esameDiStato = c.esameDiStato or false,
        minuti = minuti,
    })
end)

-- ---------------------------------------------------------------------------
--  Esame di Stato
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('scu:avviaStato', function(src, rispondi, idCorso)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c = SCU.GetCorso(idCorso)
    if not c or not c.esameDiStato then return rispondi(nil, 'Questo corso non prevede l\'esame di Stato.') end
    if not haTitolo(g.citizenid, idCorso) then return rispondi(nil, 'Serve prima la laurea.') end

    local gia = MySQL.scalar.await(
        'SELECT id FROM titoli WHERE citizenid = ? AND corso = ? AND abilitato = 1 LIMIT 1',
        { g.citizenid, idCorso })
    if gia then return rispondi(nil, 'Sei già abilitato.') end

    local sede = SCU.GetSede(SCU.EsameDiStato.sede)
    if #(GetEntityCoords(GetPlayerPed(src)) - sede.aula) > 6.0 then
        return rispondi(nil, ('L\'esame di Stato si sostiene al %s.'):format(sede.nome))
    end

    if not g:SottraiOvunque(SCU.EsameDiStato.tassa, 'tassa esame di Stato') then
        return rispondi(nil, ('La tassa è %s.'):format(U.Euro(SCU.EsameDiStato.tassa)))
    end
    TriggerEvent('aurea:fisco:incasso', 'tasse_universitarie', SCU.EsameDiStato.tassa, g.citizenid)

    -- Le domande vengono da tutte le materie del corso: è una prova
    -- d'insieme, non di una materia sola.
    local tutte = {}
    for _, materia in ipairs(c.esami) do
        for _, q in ipairs(SCU.GetMateria(materia).domande) do tutte[#tutte + 1] = q end
    end

    local domande, pubbliche, permutazioni = preparaProva(src, tutte, SCU.EsameDiStato.domande)
    proveInCorso[src] = {
        tipo = 'stato', corso = idCorso,
        domande = domande, permutazioni = permutazioni,
        erroriAmmessi = SCU.EsameDiStato.erroriAmmessi,
    }

    rispondi({
        materia = ('Esame di Stato — %s'):format(c.nome),
        domande = pubbliche,
        erroriAmmessi = SCU.EsameDiStato.erroriAmmessi,
    })
end)

AUREA.Callback.Registra('scu:consegnaStato', function(src, rispondi, risposte)
    local g = AUREA.GetPlayer(src)
    local prova = proveInCorso[src]
    if not g or not prova or prova.tipo ~= 'stato' then return rispondi(nil, 'Nessuna prova in corso.') end

    proveInCorso[src] = nil

    local errori, sbagliate = correggi(prova, risposte)
    local promosso = errori <= prova.erroriAmmessi
    local c = SCU.GetCorso(prova.corso)

    if not promosso then
        return rispondi({ promosso = false, errori = errori, sbagliate = sbagliate,
                          minuti = SCU.EsameDiStato.minutiRiprova })
    end

    MySQL.update('UPDATE titoli SET abilitato = 1, abilitato_il = NOW() WHERE citizenid = ? AND corso = ?',
        { g.citizenid, prova.corso })

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    inv:Aggiungi(SCU.EsameDiStato.item, 1, {
        albo = c.nome,
        intestatario = g:NomeCompleto(),
        iscrizione = U.DataIT(os.time()),
    })
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    AUREA.Log('anagrafe', 'info', g, ('si è abilitato: %s'):format(c.titolo))

    rispondi({ promosso = true, errori = errori, titolo = c.titolo, abilita = c.abilita })
end)

-- ---------------------------------------------------------------------------
--  Consultazione dei titoli
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('scu:titoli', function(src, rispondi, citizenid)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    -- Il proprio si vede sempre; quello altrui solo a chi assume
    local bersaglio = citizenid or g.citizenid
    if bersaglio ~= g.citizenid and not g:HaPermessoLavoro('assumi') then
        return rispondi({}, 'Solo chi assume può consultare i titoli altrui.')
    end

    local righe = MySQL.query.await([[
        SELECT corso, titolo, abilitato, conseguito_il FROM titoli
        WHERE citizenid = ? ORDER BY conseguito_il DESC
    ]], { bersaglio })

    rispondi(righe or {})
end)

AddEventHandler('aurea:giocatore:scaricato', function(src)
    proveInCorso[src] = nil
end)

-- ---------------------------------------------------------------------------
--  App sul telefono: il libretto universitario
--
--  Solo consultazione. Iscriversi e dare esami richiede di essere in
--  segreteria e in aula, e deve restare così: un titolo che si prende dal
--  divano non è un titolo.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'libretto',
    nome = 'Libretto',
    icona = '🎓',
    colore = 'linear-gradient(150deg,#7b52c9,#4b2f80)',
    ordine = 120,

    condizione = function(g)
        -- Compare solo a chi ha una carriera aperta o un titolo:
        -- a chi non ha mai messo piede in università non serve.
        local carriere = MySQL.scalar.await(
            'SELECT COUNT(*) FROM carriere WHERE citizenid = ?', { g.citizenid }) or 0
        local titoli = MySQL.scalar.await(
            'SELECT COUNT(*) FROM titoli WHERE citizenid = ?', { g.citizenid }) or 0
        return (carriere + titoli) > 0
    end,

    schermata = function(g)
        local voci = {}

        for _, t in ipairs(MySQL.query.await(
            'SELECT corso, titolo, abilitato FROM titoli WHERE citizenid = ?',
            { g.citizenid }) or {}) do
            local c = SCU.GetCorso(t.corso)
            voci[#voci + 1] = {
                icona = t.abilitato == 1 and '🎖' or '🎓',
                titolo = t.titolo,
                sottotitolo = t.abilitato == 1
                    and 'Abilitato all\'esercizio della professione'
                    or ((c and c.esameDiStato)
                        and 'Manca l\'esame di Stato per esercitare'
                        or 'Titolo conseguito'),
                tono = t.abilitato == 1 and 'verde' or nil,
                inerte = true,
            }
        end

        for _, riga in ipairs(MySQL.query.await(
            'SELECT corso, prossimo_appello FROM carriere WHERE citizenid = ?',
            { g.citizenid }) or {}) do
            local c = SCU.GetCorso(riga.corso)
            if c then
                local superati = {}
                for _, e in ipairs(MySQL.query.await(
                    'SELECT materia FROM esami_superati WHERE citizenid = ? AND corso = ?',
                    { g.citizenid, riga.corso }) or {}) do
                    superati[e.materia] = true
                end

                voci[#voci + 1] = {
                    icona = '📚', titolo = c.nome,
                    sottotitolo = riga.prossimo_appello
                        and ('Prossimo appello: %s'):format(tostring(riga.prossimo_appello))
                        or 'Puoi presentarti in aula quando vuoi',
                    valore = ('%d/%d'):format(
                        (function()
                            local n = 0
                            for _, materia in ipairs(c.esami) do
                                if superati[materia] then n = n + 1 end
                            end
                            return n
                        end)(), #c.esami),
                    inerte = true,
                }

                for _, materia in ipairs(c.esami) do
                    local m = SCU.GetMateria(materia)
                    voci[#voci + 1] = {
                        icona = superati[materia] and '✅' or '○',
                        titolo = m and m.nome or materia,
                        sottotitolo = superati[materia] and 'Superato' or 'Da sostenere',
                        inerte = true,
                    }
                end
            end
        end

        if #voci == 0 then
            voci[1] = { icona = '🎓', titolo = 'Nessuna carriera aperta', inerte = true }
        end

        return {
            tipo = 'lista',
            sottotitolo = 'Iscrizioni ed esami si fanno in ateneo',
            voci = voci,
        }
    end,
})
