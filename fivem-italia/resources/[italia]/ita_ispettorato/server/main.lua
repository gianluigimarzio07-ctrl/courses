--[[
    AUREA · Ispettorato Nazionale del Lavoro (server)

    Il criterio dell'irregolarità è uno solo, ed è quello vero: la persona
    sta lavorando ma non risulta assunta da nessuna parte. Non è una
    valutazione discrezionale, è una differenza fra due elenchi — chi è
    in servizio qui e ora, e chi sta in `impresa_dipendenti`.

    Il titolare di un'impresa non è irregolare: è il titolare. Chi lavora
    in un ente pubblico nemmeno: lo Stato assume sé stesso.
]]

local U = AUREA.Util

local raffreddamenti = {}   -- [lavoro] = timestamp di riapertura
local sospese = {}          -- [lavoro] = { motivo, dal, id }

local function ispettore(g, permesso)
    return g and g.lavoro.nome == ISP.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'accesso_ispettivo')
end

-- ---------------------------------------------------------------------------
--  Le sospensioni
-- ---------------------------------------------------------------------------

--- Lo chiede aurea_core prima di far timbrare qualcuno.
exports('AttivitaSospesa', function(lavoro)
    local s = sospese[lavoro]
    if not s then return false end
    return true, s.motivo
end)

exports('Sospensioni', function()
    local out = {}
    for lavoro, s in pairs(sospese) do
        out[#out + 1] = { lavoro = lavoro, motivo = s.motivo, dal = s.dal }
    end
    return out
end)

local function sospendi(lavoro, motivo, ispettoreId)
    if sospese[lavoro] then return false end
    if not ISP.Sospendibile(lavoro) then return false end

    local id = MySQL.insert.await([[
        INSERT INTO ispettorato_sospensioni (lavoro, motivo, disposta_da, importo_revoca)
        VALUES (?, ?, ?, ?)
    ]], { lavoro, motivo, ispettoreId, ISP.Sospensione.importoRevoca })

    sospese[lavoro] = { motivo = motivo, dal = os.time(), id = id }

    -- Chi era in servizio smonta subito: il provvedimento è immediato.
    -- ImpostaServizio(false) non passa dal controllo sulla sospensione —
    -- quello vale solo per chi vuole montare.
    for _, g in pairs(AUREA.GetGiocatoriPerLavoro(lavoro, true) or {}) do
        g:ImpostaServizio(false)
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '⛔', durata = 22000,
            titolo = 'Attività sospesa',
            testo = ('Provvedimento dell\'Ispettorato: %s.\nNon si lavora finché non è revocato.')
                :format(motivo),
        })
    end

    exports.aurea_ui:NotificaTutti({
        tipo = 'avviso', icona = '⛔', durata = 16000,
        titolo = 'Provvedimento di sospensione',
        testo = ('%s: attività sospesa dall\'Ispettorato del Lavoro.')
            :format(AUREA.EtichettaLavoro(lavoro, 0)),
    })

    AUREA.Log('economia', 'avviso', nil, ('sospesa l\'attività %s: %s'):format(lavoro, motivo))
    return true, id
end

local function revoca(lavoro, motivo)
    local s = sospese[lavoro]
    if not s then return false end

    MySQL.update.await(
        'UPDATE ispettorato_sospensioni SET revocata = 1, revocata_il = NOW() WHERE id = ?', { s.id })
    sospese[lavoro] = nil

    exports.aurea_ui:NotificaLavoro(lavoro, {
        tipo = 'successo', icona = '✅', durata = 16000,
        titolo = 'Sospensione revocata',
        testo = motivo or 'Si può tornare in servizio.',
    }, false)

    AUREA.Log('economia', 'info', nil, ('revocata la sospensione su %s'):format(lavoro))
    return true
end

--- Le sospensioni non durano per sempre: se nessuno le revoca, decadono.
CreateThread(function()
    while true do
        Wait(60000)
        for lavoro, s in pairs(sospese) do
            if (os.time() - s.dal) >= ISP.Sospensione.minutiDecadenza * 60 then
                revoca(lavoro, 'Il provvedimento è decaduto per decorso del termine.')
            end
        end
    end
end)

-- All'avvio si riprendono quelle ancora aperte: un riavvio del server
-- non è una revoca.
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    local righe = MySQL.query.await([[
        SELECT id, lavoro, motivo, UNIX_TIMESTAMP(disposta_il) AS dal
        FROM ispettorato_sospensioni WHERE revocata = 0
    ]]) or {}
    for _, r in ipairs(righe) do
        sospese[r.lavoro] = { motivo = r.motivo, dal = r.dal or os.time(), id = r.id }
    end
    if #righe > 0 then
        print(('[AUREA] ispettorato: %d sospensioni ancora in corso'):format(#righe))
    end
end)

-- ---------------------------------------------------------------------------
--  L'accesso ispettivo
--
--  Si contano le persone in servizio nel raggio. Per ognuna si guarda se
--  risulta assunta: o è titolare di un'impresa, o sta in
--  `impresa_dipendenti`, o lavora per lo Stato. Se non è niente di tutto
--  questo, sta lavorando in nero.
-- ---------------------------------------------------------------------------
local function regolare(citizenid, lavoro)
    local l = AUREA.Lavori[lavoro]
    if l and l.tipo == 'istituzione' then return true end
    if l and l.tipo == 'forze_ordine' then return true end
    if l and l.tipo == 'soccorso' then return true end

    -- Titolare di un'impresa attiva
    local titolare = MySQL.scalar.await(
        'SELECT id FROM imprese WHERE titolare = ? AND attiva = 1', { citizenid })
    if titolare then return true end

    -- Assunto da qualcuno
    local assunto = MySQL.scalar.await([[
        SELECT d.id FROM impresa_dipendenti d
        JOIN imprese i ON i.id = d.impresa_id AND i.attiva = 1
        WHERE d.citizenid = ?
    ]], { citizenid })
    return assunto ~= nil
end

AUREA.Callback.Registra('isp:accesso', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not ispettore(g) then return rispondi(false, 'Serve essere ispettore in servizio.') end

    local coord = GetEntityCoords(GetPlayerPed(src))

    -- Che attività si sta ispezionando: quella più rappresentata qui
    -- intorno, escluso l'Ispettorato stesso.
    local conteggio, presenti = {}, {}
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.servizio and altro.lavoro.nome ~= ISP.Lavoro then
            if #(coord - GetEntityCoords(GetPlayerPed(altro.source))) <= ISP.Accesso.raggio then
                conteggio[altro.lavoro.nome] = (conteggio[altro.lavoro.nome] or 0) + 1
                presenti[#presenti + 1] = altro
            end
        end
    end

    local bersaglio, quanti = nil, 0
    for lavoro, n in pairs(conteggio) do
        if n > quanti then bersaglio, quanti = lavoro, n end
    end

    if not bersaglio then
        return rispondi(false, 'Qui non risulta nessuno al lavoro: non c\'è niente da ispezionare.')
    end

    if (raffreddamenti[bersaglio] or 0) > os.time() then
        return rispondi(false, ('Su %s c\'è già stato un accesso di recente.')
            :format(AUREA.EtichettaLavoro(bersaglio, 0)))
    end
    raffreddamenti[bersaglio] = os.time() + ISP.Accesso.minutiRaffreddamento * 60

    -- Il conteggio vero
    local inNero, nomi, sanzione = 0, {}, 0
    local retribuzioneBassa = 0

    for _, p in ipairs(presenti) do
        if p.lavoro.nome == bersaglio then
            if not regolare(p.citizenid, bersaglio) then
                inNero = inNero + 1
                nomi[#nomi + 1] = p:NomeCompleto()
                sanzione = sanzione + math.random(ISP.Accesso.maxisanzioneMin, ISP.Accesso.maxisanzioneMax)

                local grado = AUREA.GetGrado(p.lavoro.nome, p.lavoro.grado)
                if (grado.stipendio or 0) < ISP.Caporalato.sogliaRetribuzione then
                    retribuzioneBassa = retribuzioneBassa + 1
                end
            end
        end
    end

    local presentiLavoro = conteggio[bersaglio] or 0
    local esito = inNero > 0 and 'irregolare' or 'regolare'
    local sospensione = false

    -- Art. 14 D.Lgs. 81/2008
    if inNero > 0 and presentiLavoro >= ISP.Accesso.presentiMinimiPerSospensione
       and (inNero / presentiLavoro) >= ISP.Accesso.quotaSospensione
       and ISP.Sospendibile(bersaglio) then
        sospensione = sospendi(bersaglio,
            ('%d lavoratori su %d senza contratto'):format(inNero, presentiLavoro),
            g.citizenid)
        if sospensione then esito = 'sospensione' end
    end

    local verbale = ('Accesso ispettivo su %s. Presenti %d, irregolari %d.%s')
        :format(AUREA.EtichettaLavoro(bersaglio, 0), presentiLavoro, inNero,
                #nomi > 0 and (' Identificati: ' .. table.concat(nomi, ', ') .. '.') or '')

    MySQL.insert.await([[
        INSERT INTO ispettorato_accessi
            (lavoro, luogo, ispettore, presenti, in_nero, esito, sanzione, verbale)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { bersaglio, ('%.0f, %.0f'):format(coord.x, coord.y), g.citizenid,
          presentiLavoro, inNero, esito, sanzione, verbale })

    -- La maxisanzione la paga chi ha l'attività, cioè la cassa
    if sanzione > 0 then
        pcall(function()
            exports.aurea_azienda:PrelevaDaCassa(bersaglio, sanzione, 'maxisanzione per lavoro nero')
        end)
        TriggerEvent('aurea:fisco:incasso', 'sanzioni_lavoro', sanzione, nil)
    end

    -- Caporalato: qui non è più materia amministrativa
    if inNero >= ISP.Caporalato.irregolariMinimi
       and retribuzioneBassa >= math.ceil(inNero / 2) then
        for _, p in ipairs(presenti) do
            if p.lavoro.nome == bersaglio and p.lavoro.grado >= 2 then
                exports.ita_giustizia:ApriFascicolo(p.citizenid, ISP.Caporalato.articolo,
                    g:NomeCompleto(),
                    ('Intermediazione illecita e sfruttamento del lavoro: %d lavoratori irregolari sottopagati')
                        :format(inNero))
            end
        end

        exports.aurea_ui:NotificaEnte('guardia_finanza', {
            tipo = 'errore', icona = '⛓', durata = 20000,
            titolo = 'Ipotesi di caporalato',
            testo = ('%s — %d lavoratori irregolari, retribuzioni sotto soglia. Art. 603-bis c.p.')
                :format(AUREA.EtichettaLavoro(bersaglio, 0), inNero),
        }, true)
    end

    AUREA.Log('economia', inNero > 0 and 'avviso' or 'info', g, verbale)

    rispondi(true, {
        lavoro = AUREA.EtichettaLavoro(bersaglio, 0),
        presenti = presentiLavoro,
        inNero = inNero,
        nomi = nomi,
        sanzione = sanzione,
        sospensione = sospensione,
    })
end)

-- ---------------------------------------------------------------------------
--  Revoca del provvedimento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('isp:sospensioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for lavoro, s in pairs(sospese) do
        out[#out + 1] = {
            lavoro = lavoro,
            etichetta = AUREA.EtichettaLavoro(lavoro, 0),
            motivo = s.motivo,
            minuti = math.floor((os.time() - s.dal) / 60),
            importoRevoca = ISP.Sospensione.importoRevoca,
            -- Solo chi è di quel mestiere, o l'ispettore, può agire
            mia = g.lavoro.nome == lavoro,
        }
    end
    rispondi(out, ispettore(g, 'sospensione_attivita'))
end)

AUREA.Callback.Registra('isp:revoca', function(src, rispondi, lavoro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = sospese[lavoro]
    if not s then return rispondi(false, 'Su quell\'attività non risulta nessun provvedimento.') end

    -- L'ispettore la revoca d'ufficio; chiunque altro deve pagare la
    -- somma aggiuntiva, e deve essere di quel mestiere.
    if ispettore(g, 'sospensione_attivita') then
        revoca(lavoro, ('Revocata d\'ufficio da %s.'):format(g:NomeCompleto()))
        return rispondi(true, 'Provvedimento revocato.')
    end

    if g.lavoro.nome ~= lavoro then
        return rispondi(false, 'La revoca la chiede chi lavora lì, non un passante.')
    end

    local pagata = false
    pcall(function()
        pagata = exports.aurea_azienda:PrelevaDaCassa(lavoro, ISP.Sospensione.importoRevoca,
            'somma aggiuntiva per la revoca della sospensione') == true
    end)
    if not pagata then
        if not g:Sottrai('banca', ISP.Sospensione.importoRevoca, 'revoca della sospensione') then
            return rispondi(false, ('Servono %s, dalla cassa dell\'attività o di tasca tua.')
                :format(U.Euro(ISP.Sospensione.importoRevoca)))
        end
    end
    TriggerEvent('aurea:fisco:incasso', 'sanzioni_lavoro', ISP.Sospensione.importoRevoca, g.citizenid)

    revoca(lavoro, ('Somma aggiuntiva versata da %s: si riapre.'):format(g:NomeCompleto()))
    rispondi(true, ('Provvedimento revocato. Versati %s.'):format(U.Euro(ISP.Sospensione.importoRevoca)))
end)

-- ---------------------------------------------------------------------------
--  Il registro degli accessi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('isp:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not ispettore(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT a.lavoro, a.luogo, a.presenti, a.in_nero, a.esito, a.sanzione, a.verbale,
               CONCAT(p.nome, ' ', p.cognome) AS nome_ispettore,
               TIMESTAMPDIFF(MINUTE, a.quando, NOW()) AS minutiFa
        FROM ispettorato_accessi a
        LEFT JOIN personaggi p ON p.citizenid = a.ispettore
        ORDER BY a.quando DESC LIMIT 20
    ]]) or {}

    for _, r in ipairs(righe) do
        r.etichetta = AUREA.EtichettaLavoro(r.lavoro, 0)
    end
    rispondi(righe)
end)
