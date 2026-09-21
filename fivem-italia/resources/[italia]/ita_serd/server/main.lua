--[[
    AUREA · Ser.D. (server)

    Il conteggio delle segnalazioni precedenti è l'unica cosa che conta
    qui dentro: dalla seconda in poi cambia tutto. Per questo la
    segnalazione si registra sempre, anche quando non produce niente.

    E il programma terapeutico non si può barare, perché non basta
    presentarsi: serve venire più volte, a distanza, e ogni volta il
    test deve essere negativo.
]]

local U = AUREA.Util

local function operatore(g)
    return g and g.lavoro.nome == SERD.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro('colloquio')
end

local function inSede(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - SERD.Sede.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  La segnalazione al Prefetto
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:serd:segnalazione', function(citizenid, dosi, agente)
    if type(citizenid) ~= 'string' then return end
    dosi = math.floor(tonumber(dosi) or 0)

    -- Sopra la soglia non è uso personale: è materia penale, e di
    -- quella si occupa ita_droga. Qui non si fa niente.
    if dosi <= 0 or dosi > SERD.UsoPersonale.dosiMassime then return end

    local precedenti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM serd_segnalazioni WHERE citizenid = ?', { citizenid }) or 0

    local sospensione = 0
    if precedenti == 1 then
        sospensione = SERD.Sanzioni.giorniPatente
    elseif precedenti >= 2 then
        sospensione = SERD.Sanzioni.giorniPatenteRecidiva
    end

    local id = MySQL.insert.await([[
        INSERT INTO serd_segnalazioni
            (citizenid, sostanza, quantita, segnalata_da, precedenti, patente_sospesa)
        VALUES (?, 'sostanze stupefacenti', ?, ?, ?, ?)
    ]], { citizenid, dosi, agente, precedenti, sospensione })

    if precedenti == 0 then
        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Prefettura',
            ('Segnalazione ex art. 75 D.P.R. 309/1990: detenzione per uso personale.\nÈ il primo caso, quindi solo un formale invito. Presentati al Ser.D. entro %d minuti: se aderisci a un programma, il procedimento si chiude.')
                :format(SERD.Sanzioni.minutiPerPresentarsi))
    else
        -- Dalla seconda in poi le sanzioni si applicano
        pcall(function()
            exports.ita_codicestrada:PatenteSospendi(citizenid, sospensione,
                'art. 75 D.P.R. 309/1990 — detenzione per uso personale')
        end)
        AUREA.Denaro.SottraiOffline(citizenid, 'banca', SERD.Sanzioni.pecuniaria,
            'sanzione amministrativa art. 75 D.P.R. 309/1990', true)
        TriggerEvent('aurea:fisco:incasso', 'sanzioni_amministrative',
            SERD.Sanzioni.pecuniaria, citizenid)

        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Prefettura',
            ('Segnalazione ex art. 75: è la %d° volta.\nPatente sospesa per %d giorni e sanzione di %s.\nAl Ser.D. puoi chiedere un programma: se lo concludi, tutto questo cade.')
                :format(precedenti + 1, sospensione, U.Euro(SERD.Sanzioni.pecuniaria)))
    end

    exports.aurea_ui:NotificaLavoro(SERD.Lavoro, {
        tipo = 'info', icona = '🏥', durata = 14000,
        titolo = 'Nuova segnalazione dal Prefetto',
        testo = ('Un soggetto è stato segnalato per uso personale. Precedenti: %d.')
            :format(precedenti),
    }, true)

    AUREA.Log('giustizia', 'info', nil,
        ('art. 75 su %s: %d dosi, %d precedenti'):format(citizenid, dosi, precedenti))
end)

-- ---------------------------------------------------------------------------
--  La posizione del soggetto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('serd:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local segnalazioni = MySQL.query.await([[
        SELECT id, quantita, precedenti, stato, patente_sospesa,
               TIMESTAMPDIFF(MINUTE, quando, NOW()) AS minutiFa
        FROM serd_segnalazioni
        WHERE citizenid = ? AND stato IN ('convocato','in_programma')
        ORDER BY quando DESC
    ]], { g.citizenid }) or {}

    local programma = MySQL.single.await([[
        SELECT id, sessioni, sessioni_richieste,
               TIMESTAMPDIFF(MINUTE, iniziato_il, NOW()) AS minutiDa
        FROM serd_programmi WHERE citizenid = ? AND esito = 'in_corso'
    ]], { g.citizenid })

    -- Chi lavora qui vede la coda
    local coda = {}
    if operatore(g) then
        coda = MySQL.query.await([[
            SELECT s.id, s.quantita, s.precedenti, s.stato,
                   CONCAT(p.nome, ' ', p.cognome) AS nominativo,
                   TIMESTAMPDIFF(MINUTE, s.quando, NOW()) AS minutiFa
            FROM serd_segnalazioni s
            LEFT JOIN personaggi p ON p.citizenid = s.citizenid
            WHERE s.stato IN ('convocato','in_programma')
            ORDER BY s.quando ASC LIMIT 20
        ]]) or {}
    end

    -- Quando matura il prossimo colloquio
    if programma then
        programma.attesa = math.max(0,
            (programma.sessioni * SERD.Programma.minutiFraSessioni) - (programma.minutiDa or 0))
    end

    rispondi({
        segnalazioni = segnalazioni,
        programma = programma,
        coda = coda,
        operatore = operatore(g),
        sessioniRichieste = SERD.Programma.sessioni,
        minutiFra = SERD.Programma.minutiFraSessioni,
    })
end)

-- ---------------------------------------------------------------------------
--  Aderire al programma
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('serd:aderisci', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'Al programma ci si iscrive al Ser.D.') end

    local aperta = MySQL.single.await([[
        SELECT id FROM serd_segnalazioni WHERE citizenid = ? AND stato = 'convocato'
        ORDER BY quando DESC LIMIT 1
    ]], { g.citizenid })
    if not aperta then
        return rispondi(false, 'Non risulta nessuna segnalazione aperta a tuo carico.')
    end

    local gia = MySQL.scalar.await(
        'SELECT id FROM serd_programmi WHERE citizenid = ? AND esito = ?', { g.citizenid, 'in_corso' })
    if gia then return rispondi(false, 'Hai già un programma in corso.') end

    MySQL.insert.await([[
        INSERT INTO serd_programmi (citizenid, segnalazione_id, sessioni_richieste)
        VALUES (?, ?, ?)
    ]], { g.citizenid, aperta.id, SERD.Programma.sessioni })

    MySQL.update.await('UPDATE serd_segnalazioni SET stato = ? WHERE id = ?',
        { 'in_programma', aperta.id })

    AUREA.Log('giustizia', 'info', g, 'ha aderito a un programma terapeutico')

    rispondi(true, ('Programma aperto: servono %d colloqui, a distanza di almeno %d minuti l\'uno dall\'altro.\nSe lo concludi, il procedimento si chiude e le sanzioni cadono.')
        :format(SERD.Programma.sessioni, SERD.Programma.minutiFraSessioni))
end)

-- ---------------------------------------------------------------------------
--  Il colloquio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('serd:colloquio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'I colloqui si fanno al Ser.D.') end

    local p = MySQL.single.await([[
        SELECT id, sessioni, sessioni_richieste, segnalazione_id,
               TIMESTAMPDIFF(MINUTE, iniziato_il, NOW()) AS minutiDa
        FROM serd_programmi WHERE citizenid = ? AND esito = 'in_corso'
    ]], { g.citizenid })
    if not p then return rispondi(false, 'Non hai un programma in corso.') end

    -- I colloqui non si fanno tutti di fila: ogni sessione matura dopo
    -- un intervallo dall'inizio del programma. Non serve una colonna in
    -- più, basta contare: la sessione n-esima è disponibile dopo
    -- n intervalli.
    local maturaA = p.sessioni * SERD.Programma.minutiFraSessioni
    if (p.minutiDa or 0) < maturaA then
        return rispondi(false, ('Il prossimo colloquio si può fare fra %d minuti. Un programma non si fa in un pomeriggio.')
            :format(maturaA - (p.minutiDa or 0)))
    end

    -- Serve un operatore in sede: un colloquio senza nessuno dall'altra
    -- parte non è un colloquio.
    local presente
    for _, o in pairs(AUREA.GetGiocatoriPerLavoro(SERD.Lavoro, true) or {}) do
        if inSede(o.source) then presente = o break end
    end
    if not presente then
        return rispondi(false, 'Non c\'è nessun operatore in servizio: il colloquio si fa in due.')
    end

    -- Il test: chi è ancora positivo non ha interrotto, e la sessione
    -- non vale. Più sessioni si fanno, meno è probabile.
    local soglia = math.max(5, SERD.Test.probabilitaPositivo
        - (p.sessioni * SERD.Test.riduzionePerSessione))

    if math.random(100) <= soglia then
        return rispondi(true, {
            positivo = true,
            sessioni = p.sessioni,
            richieste = p.sessioni_richieste,
        })
    end

    local fatte = p.sessioni + 1
    MySQL.update.await('UPDATE serd_programmi SET sessioni = ? WHERE id = ?', { fatte, p.id })

    presente:Aggiungi('banca', SERD.Programma.compensoOperatore, 'colloquio terapeutico')
    g:VariaStato('stress', SERD.Programma.beneficioStress)

    local concluso = fatte >= p.sessioni_richieste
    if concluso then
        MySQL.update.await(
            'UPDATE serd_programmi SET esito = ?, concluso_il = NOW() WHERE id = ?',
            { 'concluso', p.id })

        if SERD.Programma.chiudeSegnalazione and p.segnalazione_id then
            MySQL.update.await(
                'UPDATE serd_segnalazioni SET stato = ?, chiusa_il = NOW() WHERE id = ?',
                { 'archiviata', p.segnalazione_id })

            -- Art. 75 c. 3: concluso il programma, le sanzioni cadono.
            -- La sospensione si toglie azzerando il termine: non esiste
            -- un export per revocarla, perché fino a oggi nel server
            -- non c'era niente che potesse revocarla.
            MySQL.update.await('UPDATE patenti SET sospesa_fino = NULL WHERE citizenid = ?',
                { g.citizenid })

            TriggerEvent('aurea:telefono:messaggioSistema', g.citizenid, 'Prefettura',
                'Programma terapeutico concluso: il procedimento ex art. 75 è archiviato e la sospensione della patente è revocata.')
        end

        AUREA.Log('giustizia', 'info', g, 'ha concluso il programma terapeutico')
    end

    rispondi(true, {
        positivo = false,
        sessioni = fatte,
        richieste = p.sessioni_richieste,
        concluso = concluso,
        operatore = presente:NomeCompleto(),
    })
end)

-- ---------------------------------------------------------------------------
--  Chi non si presenta
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(180000)

        local scadute = MySQL.query.await([[
            SELECT id, citizenid, precedenti FROM serd_segnalazioni
            WHERE stato = 'convocato'
              AND TIMESTAMPDIFF(MINUTE, quando, NOW()) > ?
        ]], { SERD.Sanzioni.minutiPerPresentarsi }) or {}

        for _, s in ipairs(scadute) do
            MySQL.update.await(
                'UPDATE serd_segnalazioni SET stato = ?, chiusa_il = NOW() WHERE id = ?',
                { 'sanzionata', s.id })

            -- Chi non si presenta alla convocazione perde il beneficio:
            -- le sanzioni restano e non si possono più far cadere.
            if s.precedenti == 0 then
                AUREA.Denaro.SottraiOffline(s.citizenid, 'banca', SERD.Sanzioni.pecuniaria,
                    'mancata presentazione alla convocazione del Prefetto', true)
                TriggerEvent('aurea:fisco:incasso', 'sanzioni_amministrative',
                    SERD.Sanzioni.pecuniaria, s.citizenid)

                TriggerEvent('aurea:telefono:messaggioSistema', s.citizenid, 'Prefettura',
                    ('Non ti sei presentato entro il termine: l\'invito decade e la sanzione di %s si applica comunque.')
                        :format(U.Euro(SERD.Sanzioni.pecuniaria)))
            end
        end
    end
end)
