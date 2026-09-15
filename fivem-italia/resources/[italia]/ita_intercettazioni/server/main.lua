--[[
    AUREA · Intercettazioni (server)

    Il brogliaccio si scrive qui e non esce da qui se non a chi ha il
    decreto. Il client non riceve mai una conversazione che non gli
    spetta: chiede, e il server decide cosa mandargli.

    Il dettaglio che regge tutto: si registra solo da quando il decreto
    esiste. Non c'è nessuna query che vada a pescare nel passato, perché
    il passato non è stato intercettato — e un modulo che lo facesse
    renderebbe il decreto una formalità.
]]

local U = AUREA.Util

local attive = {}       -- [numero] = { id, stato, richiedente, scade, ... }

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
local function pg(g)
    return g and INT.EPoliziaGiudiziaria(g.lavoro.nome) and g.lavoro.servizio
end

local function magistrato(g)
    return g and g.lavoro.nome == INT.Magistratura
end

local function numeroDi(citizenid)
    return MySQL.scalar.await('SELECT telefono FROM personaggi WHERE citizenid = ?', { citizenid })
end

local function intestatario(numero)
    return MySQL.single.await(
        'SELECT citizenid, nome, cognome FROM personaggi WHERE telefono = ? LIMIT 1', { numero })
end

local function contaAttive()
    local n = 0
    for _, d in pairs(attive) do
        if INT.Stati[d.stato].ascolta then n = n + 1 end
    end
    return n
end

--- Avvisa i magistrati in servizio che c'è qualcosa da decidere.
local function avvisaMagistratura(notifica)
    exports.aurea_ui:NotificaLavoro(INT.Magistratura, notifica, false)
end

-- ---------------------------------------------------------------------------
--  Registrazione: l'unico punto in cui il brogliaccio si riempie
-- ---------------------------------------------------------------------------
local function annota(numero, tipo, controparte, contenuto, secondi)
    local d = attive[numero]
    if not d or not INT.Stati[d.stato].ascolta then return end

    MySQL.insert('INSERT INTO int_brogliaccio (decreto_id, tipo, mittente, destinatario, contenuto, secondi) VALUES (?, ?, ?, ?, ?, ?)',
        { d.id, tipo, numero, controparte, contenuto, secondi or 0 })

    d.pezzi = (d.pezzi or 0) + 1

    -- Chi ha chiesto il decreto viene avvisato che c'è traffico: è la
    -- ragione per cui si sta in ascolto invece di rileggere dopo.
    local richiedente = AUREA.GetPlayerByCitizenId(d.richiedente)
    if richiedente then
        TriggerClientEvent('aurea:ui:notifica', richiedente.source, {
            tipo = 'info', icona = '🎧', durata = 9000,
            titolo = ('Traffico su %s'):format(numero),
            testo = tipo == 'sms' and ('SMS con %s'):format(controparte)
                or ('Chiamata con %s (%ds)'):format(controparte, secondi or 0),
        })
    end
end

--- Le due prese del telefono. Il telefono non sa che esistiamo.
AddEventHandler('aurea:telefono:chiamata', function(mittente, destinatario, esito, secondi)
    annota(mittente, 'chiamata', destinatario, ('Chiamata %s'):format(esito), secondi)
    annota(destinatario, 'chiamata', mittente, ('Chiamata %s (ricevuta)'):format(esito), secondi)
end)

AddEventHandler('aurea:telefono:sms', function(mittente, destinatario, testo)
    annota(mittente, 'sms', destinatario, testo, 0)
    annota(destinatario, 'sms', mittente, testo, 0)
end)

-- ---------------------------------------------------------------------------
--  Richiesta di decreto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('int:chiedi', function(src, rispondi, numero, codiceReato, motivazione, urgenza)
    local g = AUREA.GetPlayer(src)
    if not pg(g) then return rispondi(false, 'La richiesta la avanza la polizia giudiziaria in servizio.') end

    numero = tostring(numero or ''):gsub('%D', '')
    if #numero < 6 then return rispondi(false, 'Numero non valido.') end
    if attive[numero] and INT.Stati[attive[numero].stato].ascolta then
        return rispondi(false, 'Su quell\'utenza c\'è già un decreto in corso.')
    end
    if contaAttive() >= INT.Decreto.contemporaneeMassime then
        return rispondi(false, ('La sala regge %d ascolti insieme e sono tutti occupati.')
            :format(INT.Decreto.contemporaneeMassime))
    end

    local persona = intestatario(numero)
    if not persona then return rispondi(false, 'Utenza non intestata a nessuno.') end

    if not INT.Ammesso(codiceReato) then
        return rispondi(false, 'Per quel reato non si intercetta: la legge chiede una soglia di gravità.')
    end

    -- Gravi indizi: un fascicolo aperto a carico del bersaglio
    local ok, precedenti = pcall(function()
        return exports.ita_giustizia:Precedenti(persona.citizenid, true)
    end)
    local indizio = false
    for _, p in ipairs(ok and precedenti or {}) do
        if p.gravita >= INT.Presupposti.gravitaMinima then indizio = true end
    end
    if not indizio then
        return rispondi(false, 'Non risultano gravi indizi a carico dell\'intestatario: nessun fascicolo aperto per reato grave.')
    end

    motivazione = tostring(motivazione or ''):sub(1, 400)
    if #motivazione < 15 then
        return rispondi(false, 'La richiesta va motivata. Scrivi perché l\'ascolto è indispensabile.')
    end

    local giudiciInLinea = #AUREA.GetGiocatoriPerLavoro(INT.Magistratura, false)
    local stato = (urgenza or giudiciInLinea == 0) and 'urgenza' or 'richiesto'

    local id = MySQL.insert.await([[
        INSERT INTO int_decreti
            (numero, bersaglio, reato, motivazione, richiedente, richiedente_nome, stato, scade_il, convalida_entro)
        VALUES (?, ?, ?, ?, ?, ?, ?,
                DATE_ADD(NOW(), INTERVAL ? MINUTE),
                CASE WHEN ? = 'urgenza' THEN DATE_ADD(NOW(), INTERVAL ? MINUTE) ELSE NULL END)
    ]], { numero, persona.citizenid, codiceReato, motivazione, g.citizenid, g:NomeCompleto(),
          stato, INT.Decreto.durataMinuti, stato, INT.Decreto.convalidaMinuti })

    attive[numero] = {
        id = id, numero = numero, bersaglio = persona.citizenid,
        nomeBersaglio = ('%s %s'):format(persona.nome, persona.cognome),
        reato = codiceReato, stato = stato, motivazione = motivazione,
        richiedente = g.citizenid, nomeRichiedente = g:NomeCompleto(),
        scade = os.time() + INT.Decreto.durataMinuti * 60,
        convalidaEntro = stato == 'urgenza' and (os.time() + INT.Decreto.convalidaMinuti * 60) or nil,
        proroghe = 0, pezzi = 0,
    }

    TriggerEvent('aurea:fisco:erogazione', 'intercettazioni', INT.Decreto.costoErario, nil)

    if stato == 'urgenza' then
        avvisaMagistratura({
            tipo = 'avviso', icona = '⚠', durata = 22000,
            titolo = 'Decreto d\'urgenza da convalidare',
            testo = ('%s ha disposto l\'ascolto dell\'utenza %s (%s).\nHai %d minuti per convalidare con /decreti, altrimenti è inutilizzabile.')
                :format(g:NomeCompleto(), numero, AUREA.Reati[codiceReato].nome, INT.Decreto.convalidaMinuti),
        })
        AUREA.Log('giustizia', 'avviso', g,
            ('ha disposto l\'ascolto d\'urgenza dell\'utenza %s'):format(numero))
        return rispondi(true, ('Ascolto attivato in urgenza su %s.\n\nATTENZIONE: senza convalida entro %d minuti tutto quello che raccogli è INUTILIZZABILE. Trova un giudice.')
            :format(numero, INT.Decreto.convalidaMinuti))
    end

    avvisaMagistratura({
        tipo = 'info', icona = '⚖', durata = 20000,
        titolo = 'Richiesta di intercettazione',
        testo = ('%s chiede l\'ascolto dell\'utenza %s per %s. Esaminala con /decreti.')
            :format(g:NomeCompleto(), numero, AUREA.Reati[codiceReato].nome),
    })

    AUREA.Log('giustizia', 'info', g, ('ha chiesto un decreto sull\'utenza %s'):format(numero))
    rispondi(true, ('Richiesta trasmessa al giudice per l\'utenza %s. L\'ascolto parte solo con il decreto.')
        :format(numero))
end)

-- ---------------------------------------------------------------------------
--  Il giudice decide
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('int:pendenti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not magistrato(g) then return rispondi({}) end

    local fuori = {}
    for _, d in pairs(attive) do
        if d.stato == 'richiesto' or d.stato == 'urgenza' then
            local r = AUREA.Reati[d.reato]
            fuori[#fuori + 1] = {
                id = d.id, numero = d.numero, bersaglio = d.nomeBersaglio,
                reato = r and r.nome or d.reato, articolo = r and r.articolo or '',
                richiedente = d.nomeRichiedente, stato = d.stato,
                motivazione = d.motivazione,
                minutiConvalida = d.convalidaEntro
                    and math.max(0, math.ceil((d.convalidaEntro - os.time()) / 60)) or nil,
            }
        end
    end
    rispondi(fuori)
end)

AUREA.Callback.Registra('int:decidi', function(src, rispondi, id, concesso)
    local g = AUREA.GetPlayer(src)
    if not magistrato(g) then return rispondi(false, 'Solo la magistratura.') end

    local d
    for _, x in pairs(attive) do if x.id == id then d = x end end
    if not d then return rispondi(false, 'Decreto non trovato.') end
    if d.stato ~= 'richiesto' and d.stato ~= 'urgenza' then
        return rispondi(false, 'Su questo decreto è già stato deciso.')
    end

    local eraUrgenza = d.stato == 'urgenza'
    d.stato = concesso and (eraUrgenza and 'convalidato' or 'autorizzato') or 'respinto'
    d.convalidaEntro = nil

    MySQL.update('UPDATE int_decreti SET stato = ?, giudice = ?, deciso_il = NOW() WHERE id = ?',
        { d.stato, g:NomeCompleto(), d.id })

    if not concesso then attive[d.numero] = nil end

    local richiedente = AUREA.GetPlayerByCitizenId(d.richiedente)
    if richiedente then
        TriggerClientEvent('aurea:ui:notifica', richiedente.source, {
            tipo = concesso and 'successo' or 'errore', icona = '⚖', durata = 20000,
            titolo = INT.Stati[d.stato].nome,
            testo = concesso
                and ('Utenza %s: ascolto legittimo%s.'):format(d.numero,
                    eraUrgenza and ', il materiale raccolto è ora utilizzabile' or '')
                or ('Utenza %s: il giudice ha respinto. L\'ascolto è chiuso.'):format(d.numero),
        })
    end

    AUREA.Log('giustizia', 'info', g,
        ('ha %s il decreto %d sull\'utenza %s'):format(concesso and 'concesso' or 'respinto', d.id, d.numero))

    rispondi(true, concesso
        and ('Decreto %s per l\'utenza %s.'):format(eraUrgenza and 'convalidato' or 'emesso', d.numero)
        or ('Richiesta respinta per l\'utenza %s.'):format(d.numero))
end)

-- ---------------------------------------------------------------------------
--  Il brogliaccio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('int:brogliaccio', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not pg(g) and not magistrato(g) then return rispondi(nil) end

    if #(GetEntityCoords(GetPlayerPed(src)) - INT.Sala.coord) > 6.0 then
        return rispondi(nil, 'Il brogliaccio si legge in sala d\'ascolto.')
    end

    local d = MySQL.single.await('SELECT * FROM int_decreti WHERE id = ?', { id })
    if not d then return rispondi(nil, 'Decreto non trovato.') end

    -- Chi non ha chiesto quel decreto non lo legge: passare il contenuto
    -- a un collega non titolare è già art. 326 c.p.
    if not magistrato(g) and d.richiedente ~= g.citizenid then
        return rispondi(nil, 'Non sei il titolare del procedimento.')
    end

    local righe = MySQL.query.await([[
        SELECT tipo, mittente, destinatario, contenuto, secondi, momento
        FROM int_brogliaccio WHERE decreto_id = ? ORDER BY id DESC LIMIT 60
    ]], { id }) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.momento or 0) / 1000))
    end

    rispondi({
        numero = d.numero, stato = d.stato,
        utilizzabile = INT.Stati[d.stato] and INT.Stati[d.stato].utilizzabile or false,
        righe = righe,
    })
end)

AUREA.Callback.Registra('int:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not pg(g) and not magistrato(g) then return rispondi({}) end

    local righe = MySQL.query.await(([[
        SELECT id, numero, bersaglio, reato, stato, richiedente_nome
        FROM int_decreti
        WHERE %s stato <> 'respinto'
        ORDER BY id DESC LIMIT 30
    ]]):format(magistrato(g) and '' or 'richiedente = ? AND'),
        magistrato(g) and {} or { g.citizenid }) or {}

    for _, r in ipairs(righe) do
        local rr = AUREA.Reati[r.reato]
        r.nomeReato = rr and rr.nome or r.reato
        r.viva = attive[r.numero] ~= nil and attive[r.numero].id == r.id
        r.pezzi = MySQL.scalar.await('SELECT COUNT(*) FROM int_brogliaccio WHERE decreto_id = ?', { r.id }) or 0
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Scadenze: la convalida che non arriva, il decreto che finisce
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        local adesso = os.time()

        for numero, d in pairs(attive) do
            if d.convalidaEntro and adesso >= d.convalidaEntro then
                d.stato = 'inutilizzabile'
                d.convalidaEntro = nil
                MySQL.update('UPDATE int_decreti SET stato = ? WHERE id = ?', { 'inutilizzabile', d.id })
                attive[numero] = nil

                local r = AUREA.GetPlayerByCitizenId(d.richiedente)
                if r then
                    TriggerClientEvent('aurea:ui:notifica', r.source, {
                        tipo = 'errore', icona = '🗑', durata = 24000,
                        titolo = 'Intercettazione inutilizzabile',
                        testo = ('Utenza %s: nessun giudice ha convalidato il decreto d\'urgenza entro il termine.\nQuello che hai raccolto non si può usare. Sai delle cose, ma non le puoi provare.')
                            :format(numero),
                    })
                end
                AUREA.Log('giustizia', 'avviso', nil,
                    ('Decreto %d su %s: inutilizzabile per mancata convalida'):format(d.id, numero))

            elseif adesso >= d.scade then
                d.stato = 'scaduto'
                MySQL.update('UPDATE int_decreti SET stato = ? WHERE id = ?', { 'scaduto', d.id })
                attive[numero] = nil

                local r = AUREA.GetPlayerByCitizenId(d.richiedente)
                if r then
                    TriggerClientEvent('aurea:ui:notifica', r.source, {
                        tipo = 'info', icona = '⏱', durata = 16000,
                        titolo = 'Decreto scaduto',
                        testo = ('Utenza %s: l\'ascolto è terminato. Chiedi una proroga se serve ancora.')
                            :format(numero),
                    })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Export: chi è sotto ascolto, per chi ha diritto di saperlo
-- ---------------------------------------------------------------------------
exports('SottoAscolto', function(numero)
    local d = attive[tostring(numero or '')]
    return d ~= nil and INT.Stati[d.stato].ascolta
end)

print('[AUREA] intercettazioni: sala d\'ascolto pronta')
