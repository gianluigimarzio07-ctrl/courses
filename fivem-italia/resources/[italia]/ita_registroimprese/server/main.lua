--[[
    AUREA · Registro delle Imprese (server)

    Non si creano imprese qui: si prendono quelle che esistono già in
    `imprese` (le apre ita_fisco) e ci si aggiunge quello che la Camera
    di Commercio tiene — il REA, i soci, il diritto annuale.

    La visura è pubblica per scelta, non per distrazione. In un server in
    cui si può intestare un'attività a un prestanome, il modo per
    scoprirlo deve esistere ed essere alla portata di chiunque.
]]

local U = AUREA.Util

local function addetto(g)
    return g and g.lavoro.nome == REG.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(REG.Permesso)
end

local function alloSportello(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - REG.Sportello.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Lettura
-- ---------------------------------------------------------------------------
local function posizioneRegistro(impresaId)
    return MySQL.single.await('SELECT * FROM registro_rea WHERE impresa_id = ?', { impresaId })
end

--- Un'impresa iscritta e in regola. Lo chiedono ita_edilizia prima di
--- aprire un cantiere e ita_immobiliare prima di far mediare qualcuno.
local function iscrittaERegolare(citizenid)
    local r = MySQL.single.await([[
        SELECT r.rea, r.stato, i.ragione_sociale
        FROM imprese i
        JOIN registro_rea r ON r.impresa_id = i.id
        WHERE i.titolare = ? AND i.attiva = 1
        ORDER BY r.iscritta_il ASC LIMIT 1
    ]], { citizenid })

    if not r then return false, 'l\'impresa non risulta iscritta al Registro delle Imprese' end
    if r.stato == 'sospesa' then
        return false, ('%s è sospesa dal Registro per omesso diritto annuale'):format(r.ragione_sociale)
    end
    if r.stato == 'cessata' then
        return false, ('%s risulta cessata'):format(r.ragione_sociale)
    end
    return true, r.rea
end

exports('IscrittaAlRegistro', iscrittaERegolare)

exports('ReaDi', function(impresaId)
    local r = posizioneRegistro(impresaId)
    return r and r.rea or nil
end)

-- ---------------------------------------------------------------------------
--  Le proprie imprese, con lo stato camerale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('reg:mieImprese', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT i.id, i.piva, i.ragione_sociale, i.forma, i.settore, i.sede,
               i.fatturato_anno, i.attiva,
               r.rea, r.stato AS stato_registro
        FROM imprese i
        LEFT JOIN registro_rea r ON r.impresa_id = i.id
        WHERE i.titolare = ? AND i.attiva = 1
    ]], { g.citizenid }) or {}

    for _, i in ipairs(righe) do
        i.dirittoDovuto = MySQL.single.await([[
            SELECT id, periodo, importo,
                   TIMESTAMPDIFF(MINUTE, emesso_il, NOW()) AS minutiFa
            FROM registro_diritto_annuale
            WHERE impresa_id = ? AND pagato = 0 ORDER BY id ASC LIMIT 1
        ]], { i.id })
        i.iscrizione = REG.Iscrizione.costo
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Iscrizione al Registro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('reg:iscrivi', function(src, rispondi, impresaId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'L\'iscrizione si deposita allo sportello.') end

    local i = MySQL.single.await(
        'SELECT id, titolare, ragione_sociale, forma, attiva FROM imprese WHERE id = ?',
        { tonumber(impresaId) })
    if not i then return rispondi(false, 'Impresa non trovata.') end
    if i.titolare ~= g.citizenid then return rispondi(false, 'Non sei il titolare.') end
    if i.attiva ~= 1 then return rispondi(false, 'L\'impresa non è attiva.') end

    if posizioneRegistro(i.id) then
        return rispondi(false, 'L\'impresa risulta già iscritta.')
    end

    if not g:SottraiOvunque(REG.Iscrizione.costo, 'diritti di segreteria e bollo') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(REG.Iscrizione.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_camerali', REG.Iscrizione.costo, g.citizenid)

    local rea = ('%s-%s'):format(U.Random(2, 'ABCDEFGHILMNOPQRSTUVZ'), U.Random(6, '0123456789'))
    MySQL.insert.await('INSERT INTO registro_rea (impresa_id, rea) VALUES (?, ?)', { i.id, rea })

    -- Il titolare è il primo socio, al cento per cento, finché non
    -- decide diversamente.
    MySQL.query.await([[
        INSERT INTO registro_soci (impresa_id, citizenid, quota, amministratore)
        VALUES (?, ?, 100, 1)
        ON DUPLICATE KEY UPDATE quota = 100, amministratore = 1
    ]], { i.id, g.citizenid })

    AUREA.Log('economia', 'info', g, ('%s iscritta al Registro Imprese, REA %s')
        :format(i.ragione_sociale, rea))

    rispondi(true, ('%s è iscritta al Registro delle Imprese.\nNumero REA: %s.\nDa adesso la visura è pubblica.')
        :format(i.ragione_sociale, rea))
end)

-- ---------------------------------------------------------------------------
--  Visura camerale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('reg:visura', function(src, rispondi, chiave)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil, 'Sessione non valida.') end

    chiave = tostring(chiave or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #chiave < 2 then return rispondi(nil, 'Serve almeno un pezzo di nome, la P.IVA o il REA.') end

    if not g:SottraiOvunque(REG.Visura.costo, 'visura camerale') then
        return rispondi(nil, ('Servono %s per la visura.'):format(U.Euro(REG.Visura.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_camerali', REG.Visura.costo, g.citizenid)

    local righe = MySQL.query.await([[
        SELECT i.id, i.piva, i.ragione_sociale, i.forma, i.settore, i.sede,
               i.fatturato_anno, i.regime,
               r.rea, r.stato AS stato_registro, r.iscritta_il,
               CONCAT(p.nome, ' ', p.cognome) AS titolare
        FROM imprese i
        JOIN registro_rea r ON r.impresa_id = i.id
        LEFT JOIN personaggi p ON p.citizenid = i.titolare
        WHERE i.ragione_sociale LIKE ? OR i.piva = ? OR r.rea = ?
        LIMIT 8
    ]], { '%' .. chiave .. '%', chiave, chiave:upper() }) or {}

    for _, r in ipairs(righe) do
        r.iscrittaIT = U.DataIT(math.floor((r.iscritta_il or 0) / 1000))
        r.soci = MySQL.query.await([[
            SELECT s.quota, s.amministratore, CONCAT(p.nome, ' ', p.cognome) AS nominativo
            FROM registro_soci s
            LEFT JOIN personaggi p ON p.citizenid = s.citizenid
            WHERE s.impresa_id = ? ORDER BY s.quota DESC
        ]], { r.id }) or {}
        r.dipendenti = MySQL.scalar.await(
            'SELECT COUNT(*) FROM impresa_dipendenti WHERE impresa_id = ?', { r.id }) or 0
    end

    if #righe == 0 then
        return rispondi(nil, 'Nessuna impresa iscritta corrisponde. Il costo della visura non si restituisce.')
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Compagine sociale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('reg:soci', function(src, rispondi, impresaId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local i = MySQL.single.await('SELECT id, titolare, ragione_sociale FROM imprese WHERE id = ?',
        { tonumber(impresaId) })
    if not i or i.titolare ~= g.citizenid then return rispondi(nil) end

    local soci = MySQL.query.await([[
        SELECT s.id, s.citizenid, s.quota, s.amministratore,
               CONCAT(p.nome, ' ', p.cognome) AS nominativo
        FROM registro_soci s
        LEFT JOIN personaggi p ON p.citizenid = s.citizenid
        WHERE s.impresa_id = ? ORDER BY s.quota DESC
    ]], { i.id }) or {}

    local totale = 0
    for _, s in ipairs(soci) do totale = totale + s.quota end

    rispondi({ impresa = i.ragione_sociale, soci = soci, totale = totale,
               costo = REG.Soci.costoDeposito })
end)

AUREA.Callback.Registra('reg:depositaSocio', function(src, rispondi, impresaId, sorgenteSocio, quota)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'L\'atto si deposita allo sportello.') end

    local i = MySQL.single.await('SELECT id, titolare, ragione_sociale, forma FROM imprese WHERE id = ?',
        { tonumber(impresaId) })
    if not i or i.titolare ~= g.citizenid then return rispondi(false, 'Non sei il titolare.') end
    if not posizioneRegistro(i.id) then return rispondi(false, 'L\'impresa non è iscritta al Registro.') end

    local socio = AUREA.GetPlayer(tonumber(sorgenteSocio))
    if not socio then return rispondi(false, 'La persona non è collegata.') end
    if socio.citizenid == g.citizenid then return rispondi(false, 'Sei già socio di te stesso.') end

    quota = math.floor(tonumber(quota) or 0)
    if quota < 1 or quota > 99 then return rispondi(false, 'La quota va da 1 a 99.') end

    local quanti = MySQL.scalar.await('SELECT COUNT(*) FROM registro_soci WHERE impresa_id = ?', { i.id }) or 0
    if quanti >= REG.Soci.massimo then
        return rispondi(false, ('Non si possono depositare più di %d soci.'):format(REG.Soci.massimo))
    end

    -- La quota si toglie al titolare: non si crea capitale dal nulla
    local quotaTitolare = MySQL.scalar.await(
        'SELECT quota FROM registro_soci WHERE impresa_id = ? AND citizenid = ?',
        { i.id, g.citizenid }) or 0
    if quotaTitolare <= quota then
        return rispondi(false, ('Hai il %d%%: non puoi cederne %d%%.'):format(quotaTitolare, quota))
    end

    if not g:SottraiOvunque(REG.Soci.costoDeposito, 'deposito dell\'atto') then
        return rispondi(false, ('Servono %s per il deposito.'):format(U.Euro(REG.Soci.costoDeposito)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_camerali', REG.Soci.costoDeposito, g.citizenid)

    MySQL.update.await('UPDATE registro_soci SET quota = quota - ? WHERE impresa_id = ? AND citizenid = ?',
        { quota, i.id, g.citizenid })
    MySQL.query.await([[
        INSERT INTO registro_soci (impresa_id, citizenid, quota, amministratore)
        VALUES (?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE quota = quota + VALUES(quota)
    ]], { i.id, socio.citizenid, quota })

    TriggerClientEvent('aurea:ui:notifica', socio.source, {
        tipo = 'successo', icona = '🏢', durata = 16000,
        titolo = 'Ingresso in società',
        testo = ('%s ti ha ceduto il %d%% di %s. Risulta nella visura, e la visura la legge chiunque.')
            :format(g:NomeCompleto(), quota, i.ragione_sociale),
    })

    AUREA.Log('economia', 'info', g, ('ceduto il %d%% di %s a %s')
        :format(quota, i.ragione_sociale, socio.citizenid))

    rispondi(true, ('Atto depositato: %s è socio al %d%%.'):format(socio:NomeCompleto(), quota))
end)

-- ---------------------------------------------------------------------------
--  Diritto annuale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('reg:pagaDiritto', function(src, rispondi, dirittoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local d = MySQL.single.await([[
        SELECT d.id, d.importo, d.periodo, d.impresa_id, i.titolare, i.ragione_sociale
        FROM registro_diritto_annuale d
        JOIN imprese i ON i.id = d.impresa_id
        WHERE d.id = ? AND d.pagato = 0
    ]], { tonumber(dirittoId) })
    if not d then return rispondi(false, 'Avviso non trovato o già pagato.') end
    if d.titolare ~= g.citizenid then return rispondi(false, 'Non è la tua impresa.') end

    if not g:SottraiOvunque(d.importo, ('diritto annuale %s'):format(d.periodo)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(d.importo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_camerali', d.importo, g.citizenid)

    MySQL.update.await('UPDATE registro_diritto_annuale SET pagato = 1 WHERE id = ?', { d.id })

    -- Pagato l'arretrato, la sospensione cade
    local altri = MySQL.scalar.await(
        'SELECT COUNT(*) FROM registro_diritto_annuale WHERE impresa_id = ? AND pagato = 0',
        { d.impresa_id }) or 0
    if altri == 0 then
        MySQL.update.await(
            'UPDATE registro_rea SET stato = \'attiva\' WHERE impresa_id = ? AND stato = \'sospesa\'',
            { d.impresa_id })
    end

    rispondi(true, ('Diritto annuale %s versato per %s.%s')
        :format(d.periodo, d.ragione_sociale,
                altri == 0 and ' L\'impresa torna attiva nel Registro.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Emissione periodica del diritto annuale e sospensioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(REG.DirittoAnnuale.minutiPeriodo * 60000)

        local periodo = os.date('%Y-%m-%d %H:%M')
        local imprese = MySQL.query.await([[
            SELECT i.id, i.titolare, i.ragione_sociale, i.forma, i.fatturato_anno
            FROM imprese i
            JOIN registro_rea r ON r.impresa_id = i.id
            WHERE i.attiva = 1 AND r.stato != 'cessata'
        ]]) or {}

        for _, i in ipairs(imprese) do
            local importo = REG.Importo(i.forma, i.fatturato_anno)
            MySQL.query.await([[
                INSERT IGNORE INTO registro_diritto_annuale (impresa_id, periodo, importo)
                VALUES (?, ?, ?)
            ]], { i.id, periodo, importo })

            TriggerEvent('aurea:telefono:messaggioSistema', i.titolare, 'CCIAA',
                ('Diritto annuale %s per %s: %s. Da pagare entro %d minuti, poi l\'impresa è sospesa dal Registro.')
                    :format(periodo, i.ragione_sociale, U.Euro(importo),
                            REG.DirittoAnnuale.minutiPerPagare))
        end

        if #imprese > 0 then
            AUREA.Log('economia', 'info', nil,
                ('diritto annuale emesso per %d imprese'):format(#imprese))
        end
    end
end)

CreateThread(function()
    while true do
        Wait(300000)

        local morose = MySQL.query.await([[
            SELECT DISTINCT d.impresa_id, i.titolare, i.ragione_sociale
            FROM registro_diritto_annuale d
            JOIN imprese i ON i.id = d.impresa_id
            JOIN registro_rea r ON r.impresa_id = d.impresa_id
            WHERE d.pagato = 0
              AND TIMESTAMPDIFF(MINUTE, d.emesso_il, NOW()) > ?
              AND r.stato = 'attiva'
        ]], { REG.DirittoAnnuale.minutiPerPagare }) or {}

        for _, m in ipairs(morose) do
            MySQL.update.await('UPDATE registro_rea SET stato = \'sospesa\' WHERE impresa_id = ?',
                { m.impresa_id })

            TriggerEvent('aurea:telefono:messaggioSistema', m.titolare, 'CCIAA',
                ('%s è sospesa dal Registro delle Imprese per omesso versamento del diritto annuale. Niente cantieri e niente mediazioni finché non paghi.')
                    :format(m.ragione_sociale))

            AUREA.Log('economia', 'avviso', nil,
                ('%s sospesa dal Registro Imprese'):format(m.ragione_sociale))
        end
    end
end)
