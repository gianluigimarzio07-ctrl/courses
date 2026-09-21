--[[
    AUREA · C.A.F. (server)

    Il reddito non lo dichiara il contribuente: lo ricostruisce il
    server dalle ritenute già versate. È l'equivalente della
    dichiarazione precompilata, ed elimina in un colpo solo tutta la
    categoria di bugie che riguardano quanto hai guadagnato.

    Restano possibili le bugie sulle detrazioni — che è esattamente
    quello che succede nella realtà, ed è il motivo per cui il controllo
    formale guarda quelle e non il reddito.
]]

local U = AUREA.Util

local function operatore(g, permesso)
    return g and g.lavoro.nome == CAF.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'assistenza')
end

local function inSede(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - CAF.Sede.coord) <= 8.0
end

--- Il periodo d'imposta corrente: un'etichetta stabile che cambia ogni
--- CAF.Periodo.minutiDurata minuti.
local function periodoCorrente()
    return ('P%d'):format(math.floor(os.time() / (CAF.Periodo.minutiDurata * 60)))
end

-- ---------------------------------------------------------------------------
--  La precompilata
--
--  Tutto quello che segue è già nel database: qui si mette insieme.
-- ---------------------------------------------------------------------------
local function precompilata(citizenid, periodo)
    -- Il reddito si ricostruisce dalle ritenute IRPEF versate: se ti
    -- hanno trattenuto il 23% di qualcosa, quel qualcosa si ricava.
    local ritenute = MySQL.scalar.await([[
        SELECT COALESCE(SUM(importo), 0) FROM tributi
        WHERE citizenid = ? AND tipo = 'irpef'
          AND TIMESTAMPDIFF(MINUTE, creato_il, NOW()) <= ?
    ]], { citizenid, CAF.Periodo.minutiDurata }) or 0

    -- L'aliquota media applicata alla fonte è il 23-27%: si usa il 25%
    -- come stimatore, ed è esattamente il genere di approssimazione che
    -- la dichiarazione serve a correggere.
    local reddito = math.floor(ritenute / 0.25)

    local voci = {}

    -- Contributi previdenziali: deducibili al cento per cento
    local contributi = MySQL.scalar.await([[
        SELECT COALESCE(SUM(importo), 0) FROM tributi
        WHERE citizenid = ? AND tipo = 'inps'
          AND TIMESTAMPDIFF(MINUTE, creato_il, NOW()) <= ?
    ]], { citizenid, CAF.Periodo.minutiDurata }) or 0

    if contributi > 0 then
        voci[#voci + 1] = {
            tipo = 'previdenza',
            descrizione = 'Contributi previdenziali versati',
            spesa = contributi,
            detrazione = math.floor(contributi * CAF.Detrazioni.aliquote.previdenza),
            documentata = true,
        }
    end

    -- Interessi sul mutuo
    local mutuo = MySQL.scalar.await([[
        SELECT COALESCE(SUM(rata), 0) FROM mutui
        WHERE citizenid = ? AND stato IN ('attivo','pignorato')
    ]], { citizenid }) or 0

    if mutuo > 0 then
        local spesa = math.min(mutuo, CAF.Detrazioni.tetti.mutuo)
        voci[#voci + 1] = {
            tipo = 'mutuo',
            descrizione = 'Interessi passivi sul mutuo prima casa',
            spesa = spesa,
            detrazione = math.floor(spesa * CAF.Detrazioni.aliquote.mutuo),
            documentata = true,
        }
    end

    -- Spese condominiali straordinarie deliberate e pagate
    local condominio = MySQL.scalar.await([[
        SELECT COALESCE(SUM(q.importo), 0)
        FROM condominio_quote q
        JOIN condominio_spese s ON s.id = q.spesa_id
        WHERE q.citizenid = ? AND q.pagata = 1 AND s.tipo = 'straordinaria'
    ]], { citizenid }) or 0

    if condominio > 0 then
        local spesa = math.min(condominio, CAF.Detrazioni.tetti.condominio)
        voci[#voci + 1] = {
            tipo = 'condominio',
            descrizione = 'Spese condominiali straordinarie',
            spesa = spesa,
            detrazione = math.floor(spesa * CAF.Detrazioni.aliquote.condominio),
            documentata = true,
        }
    end

    return reddito, ritenute, voci
end

AUREA.Callback.Registra('caf:precompilata', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local periodo = periodoCorrente()

    local gia = MySQL.single.await([[
        SELECT id, reddito, ritenute, detrazioni, imposta, saldo, stato
        FROM dichiarazioni WHERE citizenid = ? AND periodo = ?
    ]], { g.citizenid, periodo })

    if gia then
        return rispondi({ gia = gia, periodo = periodo })
    end

    local reddito, ritenute, voci = precompilata(g.citizenid, periodo)

    local detrazioni = CAF.DetrazioneLavoro(reddito)
    for _, v in ipairs(voci) do detrazioni = detrazioni + v.detrazione end

    local imposta = math.max(0, CAF.Imposta(reddito) - detrazioni)
    local saldo = ritenute - imposta

    rispondi({
        periodo = periodo,
        reddito = reddito,
        ritenute = ritenute,
        detrazioneLavoro = CAF.DetrazioneLavoro(reddito),
        voci = voci,
        detrazioni = detrazioni,
        imposta = imposta,
        saldo = saldo,
        compenso = CAF.Periodo.compenso,
    })
end)

-- ---------------------------------------------------------------------------
--  Presentare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('caf:presenta', function(src, rispondi, extra)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'La dichiarazione si presenta al CAF.') end

    local periodo = periodoCorrente()
    local gia = MySQL.scalar.await(
        'SELECT id FROM dichiarazioni WHERE citizenid = ? AND periodo = ?', { g.citizenid, periodo })
    if gia then return rispondi(false, 'Per questo periodo hai già presentato.') end

    if not g:SottraiOvunque(CAF.Periodo.compenso, 'assistenza fiscale') then
        return rispondi(false, ('Il CAF chiede %s.'):format(U.Euro(CAF.Periodo.compenso)))
    end

    -- Chi presta assistenza, se c'è qualcuno in sede
    for _, o in pairs(AUREA.GetGiocatoriPerLavoro(CAF.Lavoro, true) or {}) do
        if inSede(o.source) then
            o:Aggiungi('banca', math.floor(CAF.Periodo.compenso * CAF.Periodo.quotaOperatore),
                'assistenza fiscale')
            break
        end
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(CAF.Lavoro,
            math.floor(CAF.Periodo.compenso * (1 - CAF.Periodo.quotaOperatore)), 'assistenza fiscale')
    end)

    local reddito, ritenute, voci = precompilata(g.citizenid, periodo)

    -- Le detrazioni aggiuntive che il contribuente dichiara di avere.
    -- Nessuno le controlla adesso: il visto di conformità guarda la
    -- forma, non le ricevute.
    local extraSpesa = math.max(0, math.min(
        math.floor(tonumber(extra) or 0), CAF.Detrazioni.tetti.mediche))

    if extraSpesa > 0 then
        voci[#voci + 1] = {
            tipo = 'mediche',
            descrizione = 'Spese sanitarie dichiarate dal contribuente',
            spesa = extraSpesa,
            detrazione = math.floor(extraSpesa * CAF.Detrazioni.aliquote.mediche),
            documentata = false,
        }
    end

    local detrazioni = CAF.DetrazioneLavoro(reddito)
    for _, v in ipairs(voci) do detrazioni = detrazioni + v.detrazione end

    local imposta = math.max(0, CAF.Imposta(reddito) - detrazioni)
    local saldo = ritenute - imposta

    local id = MySQL.insert.await([[
        INSERT INTO dichiarazioni (citizenid, periodo, reddito, ritenute, detrazioni, imposta, saldo, caf)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { g.citizenid, periodo, reddito, ritenute, detrazioni, imposta, saldo, g.citizenid })

    for _, v in ipairs(voci) do
        MySQL.insert.await([[
            INSERT INTO dichiarazione_detrazioni
                (dichiarazione_id, tipo, descrizione, spesa, detrazione, documentata)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], { id, v.tipo, v.descrizione, v.spesa, v.detrazione, v.documentata and 1 or 0 })
    end

    AUREA.Log('economia', 'info', g, ('dichiarazione %s: reddito %s, saldo %s')
        :format(periodo, U.Euro(reddito), U.Euro(saldo)))

    rispondi(true, ('Dichiarazione presentata per il periodo %s.\nReddito %s · imposta dovuta %s · già trattenuto %s.\n\n%s')
        :format(periodo, U.Euro(reddito), U.Euro(imposta), U.Euro(ritenute),
                saldo >= 0
                    and ('Ti spetta un rimborso di %s.'):format(U.Euro(saldo))
                    or ('Devi un saldo di %s.'):format(U.Euro(-saldo))),
        id)
end)

-- ---------------------------------------------------------------------------
--  Liquidazione
--
--  Il rimborso non arriva subito: arriva quando l'Agenzia liquida.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(120000)

        local righe = MySQL.query.await([[
            SELECT id, citizenid, periodo, saldo FROM dichiarazioni
            WHERE stato = 'presentata'
              AND TIMESTAMPDIFF(MINUTE, presentata_il, NOW()) >= 10
            LIMIT 20
        ]]) or {}

        for _, d in ipairs(righe) do
            MySQL.update.await(
                'UPDATE dichiarazioni SET stato = ?, liquidata_il = NOW() WHERE id = ?',
                { 'liquidata', d.id })

            if d.saldo > 0 then
                AUREA.Denaro.AggiungiOffline(d.citizenid, 'banca', d.saldo,
                    ('rimborso IRPEF %s'):format(d.periodo))
                TriggerEvent('aurea:fisco:erogazione', 'rimborsi_irpef', d.saldo, d.citizenid)

                TriggerEvent('aurea:telefono:messaggioSistema', d.citizenid, 'Ag. Entrate',
                    ('Dichiarazione %s liquidata: rimborso di %s accreditato.')
                        :format(d.periodo, U.Euro(d.saldo)))
            elseif d.saldo < 0 then
                pcall(function()
                    exports.ita_fisco:IscriviTributo(d.citizenid, 'irpef_saldo', d.periodo, -d.saldo, 20)
                end)
            end

            -- Il controllo formale: guarda le detrazioni, non il reddito
            if math.random(100) <= CAF.Controllo.probabilita then
                local nonDocumentate = MySQL.scalar.await([[
                    SELECT COALESCE(SUM(detrazione), 0) FROM dichiarazione_detrazioni
                    WHERE dichiarazione_id = ? AND documentata = 0
                ]], { d.id }) or 0

                if nonDocumentate > 0 then
                    local dovuto = nonDocumentate
                        + math.floor(nonDocumentate * CAF.Controllo.sanzione)

                    MySQL.update.await('UPDATE dichiarazioni SET stato = ? WHERE id = ?',
                        { 'accertata', d.id })

                    pcall(function()
                        exports.ita_fisco:IscriviTributo(d.citizenid, 'irpef_accertamento',
                            d.periodo, dovuto, 15)
                    end)

                    TriggerEvent('aurea:telefono:messaggioSistema', d.citizenid, 'Ag. Entrate',
                        ('Controllo formale sulla dichiarazione %s: detrazioni non documentate per %s. Dovuti %s, sanzione compresa.')
                            :format(d.periodo, U.Euro(nonDocumentate), U.Euro(dovuto)))

                    AUREA.Log('economia', 'avviso', nil,
                        ('accertamento su %s: detrazioni non documentate %s')
                            :format(d.citizenid, U.Euro(nonDocumentate)))
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App del telefono
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'dichiarazione',
    nome = '730',
    icona = '🧾',
    colore = 'linear-gradient(150deg,#5a7a6e,#26352f)',
    ordine = 144,

    schermata = function(g)
        local righe = MySQL.query.await([[
            SELECT periodo, reddito, ritenute, detrazioni, imposta, saldo, stato
            FROM dichiarazioni WHERE citizenid = ? ORDER BY presentata_il DESC LIMIT 8
        ]], { g.citizenid }) or {}

        local voci = {}
        for _, d in ipairs(righe) do
            local etichetta = d.saldo >= 0
                and ('A credito %s'):format(U.Euro(d.saldo))
                or ('A debito %s'):format(U.Euro(-d.saldo))

            voci[#voci + 1] = {
                icona = d.stato == 'accertata' and '⚠' or '🧾',
                titolo = ('Periodo %s — %s'):format(d.periodo, d.stato),
                sottotitolo = ('Reddito %s · imposta %s · trattenuto %s')
                    :format(U.Euro(d.reddito), U.Euro(d.imposta), U.Euro(d.ritenute)),
                valore = etichetta,
                tono = d.stato == 'accertata' and 'rosso' or (d.saldo >= 0 and 'verde' or nil),
                inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '🧾', titolo = 'Nessuna dichiarazione presentata',
                        sottotitolo = 'La ritenuta in busta paga è un acconto, non l\'imposta. Al CAF si fa il conto vero.',
                        inerte = true }
        end

        return { tipo = 'lista', sottotitolo = 'Dichiarazioni dei redditi', voci = voci }
    end,
})
