--[[
    AUREA · Agenzia delle Entrate-Riscossione (server)

    Questa risorsa non genera debito: lo raccoglie. Tutto quello che
    tratta è già stato deciso da qualcun altro — un verbale finito a
    ruolo, un tributo diventato cartella, un contributo omesso.

    Il pezzo più importante è `QuotaPignorabile`, in fondo: la chiama
    aurea_core quando paga gli stipendi. È il pignoramento presso terzi,
    ed è l'unico punto del server in cui una risorsa dice a un'altra
    «questo stipendio non glielo dare tutto».
]]

local U = AUREA.Util

local function agente(g)
    return g and g.lavoro.nome == RIS.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(RIS.Permesso)
end

local function alloSportello(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - RIS.Sportello.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Lettura
-- ---------------------------------------------------------------------------
local function ruoliDi(citizenid, soloAperti)
    local condizione = soloAperti
        and " AND stato IN ('notificata','rateizzata','esecutiva')" or ''

    local righe = MySQL.query.await(([[
        SELECT id, origine, riferimento, descrizione, importo, aggio, incassato,
               stato, notificata_il, scadenza,
               TIMESTAMPDIFF(MINUTE, NOW(), scadenza) AS minutiResidui
        FROM riscossione_ruoli
        WHERE citizenid = ?%s
        ORDER BY notificata_il ASC
    ]]):format(condizione), { citizenid }) or {}

    for _, r in ipairs(righe) do
        r.dovuto = RIS.Dovuto(r)
    end
    return righe
end

local function debitoTotale(citizenid)
    local totale = 0
    for _, r in ipairs(ruoliDi(citizenid, true)) do
        totale = totale + r.dovuto
    end
    return totale
end

exports('DebitoARuolo', debitoTotale)
exports('RuoliDi', function(citizenid) return ruoliDi(citizenid, true) end)

--- Un veicolo sotto fermo non si muove: ci pensa già lo stato
--- 'sequestrato' sulla riga del veicolo. Questo export serve a sapere
--- che cosa pende su una targa — il fermo eseguito o il preavviso che
--- lo precede — e lo chiede aurea_garage per avvisare chi esce.
exports('MisuraSuVeicolo', function(targa)
    local m = MySQL.single.await([[
        SELECT tipo, importo FROM riscossione_misure
        WHERE bersaglio = ? AND revocata = 0
          AND tipo IN ('preavviso_fermo','fermo')
        ORDER BY disposta_il DESC LIMIT 1
    ]], { targa })
    if not m then return nil end
    return m.tipo, m.importo or 0
end)

-- ---------------------------------------------------------------------------
--  Iscrizione a ruolo
--
--  Nessuno qui decide che devi dei soldi: si guarda che cosa è già
--  scaduto altrove e lo si prende in carico.
-- ---------------------------------------------------------------------------
local function iscrivi(citizenid, origine, riferimento, descrizione, importo)
    importo = math.floor(tonumber(importo) or 0)
    if importo < RIS.Ruolo.sogliaMinima then return nil end

    local gia = MySQL.scalar.await([[
        SELECT id FROM riscossione_ruoli
        WHERE origine = ? AND riferimento = ? AND stato != 'sgravata'
    ]], { origine, riferimento })
    if gia then return nil end

    local aggio = math.floor(importo * RIS.Ruolo.aggio)
    local id = MySQL.insert.await([[
        INSERT INTO riscossione_ruoli
            (citizenid, origine, riferimento, descrizione, importo, aggio, scadenza)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))
    ]], { citizenid, origine, riferimento, descrizione, importo, aggio, RIS.Ruolo.giorniPerPagare })

    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Ag. Riscossione',
        ('Cartella di pagamento n. %d — %s. Dovuti %s, oneri compresi. Hai %d giorni, poi diventa esecutiva.')
            :format(id, descrizione, U.Euro(importo + aggio), RIS.Ruolo.giorniPerPagare))

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '📕', durata = 18000,
            titolo = ('Cartella di pagamento n. %d'):format(id),
            testo = ('%s — %s. Si può chiedere la rateizzazione allo sportello.')
                :format(descrizione, U.Euro(importo + aggio)),
        })
    end

    AUREA.Log('economia', 'avviso', nil, ('ruolo %d a carico di %s: %s (%s)')
        :format(id, citizenid, U.Euro(importo + aggio), descrizione))
    return id
end

exports('IscriviARuolo', iscrivi)

-- ---------------------------------------------------------------------------
--  La scansione: che cosa è diventato esigibile
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(RIS.Ruolo.minutiScansione * 60000)

        -- Verbali finiti a ruolo in ita_codicestrada
        local multe = MySQL.query.await([[
            SELECT m.id, m.citizenid, m.articolo, m.importo
            FROM multe m
            WHERE m.stato = 'ruolo'
              AND NOT EXISTS (
                  SELECT 1 FROM riscossione_ruoli r
                  WHERE r.origine = 'multa' AND r.riferimento = m.id AND r.stato != 'sgravata')
            LIMIT 40
        ]]) or {}
        for _, m in ipairs(multe) do
            iscrivi(m.citizenid, 'multa', m.id,
                ('Verbale %s'):format(m.articolo), m.importo)
        end

        -- Tributi diventati cartella in ita_fisco
        local tributi = MySQL.query.await([[
            SELECT t.id, t.citizenid, t.tipo, t.periodo, t.importo
            FROM tributi t
            WHERE t.stato = 'cartella'
              AND NOT EXISTS (
                  SELECT 1 FROM riscossione_ruoli r
                  WHERE r.origine = 'tributo' AND r.riferimento = t.id AND r.stato != 'sgravata')
            LIMIT 40
        ]]) or {}
        for _, t in ipairs(tributi) do
            iscrivi(t.citizenid, 'tributo', t.id,
                ('%s %s'):format(tostring(t.tipo):upper(), t.periodo or ''), t.importo)
        end

        -- Le cartelle scadute diventano esecutive: da lì in poi l'agente
        -- non chiede più, prende.
        MySQL.update.await([[
            UPDATE riscossione_ruoli SET stato = 'esecutiva'
            WHERE stato = 'notificata' AND scadenza <= NOW()
        ]])
    end
end)

-- ---------------------------------------------------------------------------
--  Pagare
-- ---------------------------------------------------------------------------
local function incassa(ruolo, importo, causale, citizenid)
    MySQL.update.await('UPDATE riscossione_ruoli SET incassato = incassato + ? WHERE id = ?',
        { importo, ruolo.id })

    -- L'aggio resta all'agente, il resto va all'erario
    local quotaAggio = math.floor(importo * RIS.Ruolo.aggio)
    TriggerEvent('aurea:fisco:incasso', 'riscossione', importo - quotaAggio, citizenid)
    pcall(function()
        exports.aurea_azienda:VersaInCassa(RIS.Lavoro, quotaAggio, 'oneri di riscossione')
    end)

    local residuo = RIS.Dovuto(ruolo) - importo
    if residuo <= 0 then
        MySQL.update.await('UPDATE riscossione_ruoli SET stato = ? WHERE id = ?', { 'pagata', ruolo.id })

        -- Pagato il ruolo, le misure cadono
        local misure = MySQL.query.await(
            'SELECT id, tipo, bersaglio FROM riscossione_misure WHERE ruolo_id = ? AND revocata = 0',
            { ruolo.id }) or {}
        for _, m in ipairs(misure) do
            if m.tipo == 'fermo' and m.bersaglio then
                MySQL.update.await(
                    'UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ? AND stato = \'sequestrato\'',
                    { m.bersaglio })
            end
        end
        MySQL.update.await(
            'UPDATE riscossione_misure SET revocata = 1, revocata_il = NOW() WHERE ruolo_id = ? AND revocata = 0',
            { ruolo.id })

        -- E il debito originario si chiude dove era nato
        if ruolo.origine == 'multa' then
            MySQL.update.await('UPDATE multe SET stato = ?, pagata_il = NOW() WHERE id = ?',
                { 'pagata', ruolo.riferimento })
        elseif ruolo.origine == 'tributo' then
            MySQL.update.await('UPDATE tributi SET stato = ? WHERE id = ?', { 'pagato', ruolo.riferimento })
        end
    end

    AUREA.Log('economia', 'info', nil, ('ruolo %d: incassati %s (%s)')
        :format(ruolo.id, U.Euro(importo), causale))
    return residuo
end

AUREA.Callback.Registra('ris:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local ruoli = ruoliDi(g.citizenid, true)
    local misure = MySQL.query.await([[
        SELECT tipo, bersaglio, importo, disposta_il FROM riscossione_misure
        WHERE citizenid = ? AND revocata = 0
    ]], { g.citizenid }) or {}

    for _, r in ipairs(ruoli) do
        if r.stato == 'rateizzata' then
            local rata = MySQL.single.await([[
                SELECT numero, importo, TIMESTAMPDIFF(MINUTE, NOW(), scadenza) AS minuti
                FROM riscossione_rate WHERE ruolo_id = ? AND pagata = 0
                ORDER BY numero ASC LIMIT 1
            ]], { r.id })
            r.prossimaRata = rata
            r.rateSaltate = MySQL.scalar.await([[
                SELECT COUNT(*) FROM riscossione_rate
                WHERE ruolo_id = ? AND pagata = 0 AND scadenza < NOW()
            ]], { r.id }) or 0
        end
    end

    rispondi({ ruoli = ruoli, misure = misure, totale = debitoTotale(g.citizenid) })
end)

AUREA.Callback.Registra('ris:paga', function(src, rispondi, ruoloId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local r = MySQL.single.await([[
        SELECT * FROM riscossione_ruoli WHERE id = ? AND citizenid = ?
          AND stato IN ('notificata','rateizzata','esecutiva')
    ]], { tonumber(ruoloId), g.citizenid })
    if not r then return rispondi(false, 'Cartella non trovata.') end

    local dovuto = RIS.Dovuto(r)
    if not g:SottraiOvunque(dovuto, ('cartella n. %d'):format(r.id)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(dovuto)))
    end

    incassa(r, dovuto, 'pagamento integrale', g.citizenid)
    rispondi(true, ('Cartella n. %d estinta. Le misure collegate sono revocate.'):format(r.id))
end)

-- ---------------------------------------------------------------------------
--  Rateizzazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ris:rateizza', function(src, rispondi, ruoloId, rate)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'La domanda si presenta allo sportello.') end

    rate = math.floor(tonumber(rate) or 0)
    if rate < 2 or rate > RIS.Rateizzazione.rateMassime then
        return rispondi(false, ('Le rate vanno da 2 a %d.'):format(RIS.Rateizzazione.rateMassime))
    end

    local r = MySQL.single.await([[
        SELECT * FROM riscossione_ruoli WHERE id = ? AND citizenid = ?
          AND stato IN ('notificata','esecutiva')
    ]], { tonumber(ruoloId), g.citizenid })
    if not r then return rispondi(false, 'Cartella non rateizzabile.') end

    local decaduto = MySQL.scalar.await([[
        SELECT COUNT(*) FROM riscossione_rate WHERE ruolo_id = ?
    ]], { r.id }) or 0
    if decaduto > 0 and not RIS.Rateizzazione.riammissione then
        return rispondi(false, 'Su questa cartella sei già decaduto dalla rateizzazione. Non si concede due volte.')
    end

    local dovuto = RIS.Dovuto(r)
    local base, resto, conInteressi = RIS.Piano(dovuto, rate)

    for n = 1, rate do
        MySQL.insert.await([[
            INSERT INTO riscossione_rate (ruolo_id, numero, importo, scadenza)
            VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ]], { r.id, n, base + (n == rate and resto or 0),
              RIS.Rateizzazione.minutiPerRata * n })
    end

    MySQL.update.await('UPDATE riscossione_ruoli SET stato = ? WHERE id = ?', { 'rateizzata', r.id })

    AUREA.Log('economia', 'info', g, ('rateizzazione su ruolo %d in %d rate'):format(r.id, rate))
    rispondi(true, ('Rateizzazione concessa: %d rate da %s (totale %s con interessi).\nAttenzione: dopo %d rate non pagate si decade, e non si rateizza più.')
        :format(rate, U.Euro(base), U.Euro(conInteressi), RIS.Rateizzazione.rateDecadenza))
end)

AUREA.Callback.Registra('ris:pagaRata', function(src, rispondi, ruoloId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local r = MySQL.single.await(
        'SELECT * FROM riscossione_ruoli WHERE id = ? AND citizenid = ? AND stato = ?',
        { tonumber(ruoloId), g.citizenid, 'rateizzata' })
    if not r then return rispondi(false, 'Nessuna rateizzazione in corso su questa cartella.') end

    local rata = MySQL.single.await([[
        SELECT id, numero, importo FROM riscossione_rate
        WHERE ruolo_id = ? AND pagata = 0 ORDER BY numero ASC LIMIT 1
    ]], { r.id })
    if not rata then return rispondi(false, 'Non risultano rate da pagare.') end

    if not g:SottraiOvunque(rata.importo, ('rata %d cartella %d'):format(rata.numero, r.id)) then
        return rispondi(false, ('Servono %s per la rata.'):format(U.Euro(rata.importo)))
    end

    MySQL.update.await('UPDATE riscossione_rate SET pagata = 1, pagata_il = NOW() WHERE id = ?', { rata.id })

    local residue = MySQL.scalar.await(
        'SELECT COUNT(*) FROM riscossione_rate WHERE ruolo_id = ? AND pagata = 0', { r.id }) or 0

    if residue == 0 then
        MySQL.update.await('UPDATE riscossione_ruoli SET stato = ?, incassato = importo + aggio WHERE id = ?',
            { 'pagata', r.id })
        MySQL.update.await(
            'UPDATE riscossione_misure SET revocata = 1, revocata_il = NOW() WHERE ruolo_id = ? AND revocata = 0',
            { r.id })
        if r.origine == 'multa' then
            MySQL.update.await('UPDATE multe SET stato = ?, pagata_il = NOW() WHERE id = ?',
                { 'pagata', r.riferimento })
        elseif r.origine == 'tributo' then
            MySQL.update.await('UPDATE tributi SET stato = ? WHERE id = ?', { 'pagato', r.riferimento })
        end
        return rispondi(true, ('Ultima rata pagata: la cartella n. %d è estinta.'):format(r.id))
    end

    MySQL.update.await('UPDATE riscossione_ruoli SET incassato = incassato + ? WHERE id = ?',
        { rata.importo, r.id })
    rispondi(true, ('Rata %d pagata. Ne restano %d.'):format(rata.numero, residue))
end)

-- ---------------------------------------------------------------------------
--  Decadenza dalla rateizzazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(180000)

        local candidati = MySQL.query.await([[
            SELECT r.id, r.citizenid, COUNT(t.id) AS saltate
            FROM riscossione_ruoli r
            JOIN riscossione_rate t ON t.ruolo_id = r.id AND t.pagata = 0 AND t.scadenza < NOW()
            WHERE r.stato = 'rateizzata'
            GROUP BY r.id
            HAVING saltate >= ?
        ]], { RIS.Rateizzazione.rateDecadenza }) or {}

        for _, c in ipairs(candidati) do
            MySQL.update.await('UPDATE riscossione_ruoli SET stato = ? WHERE id = ?', { 'esecutiva', c.id })

            TriggerEvent('aurea:telefono:messaggioSistema', c.citizenid, 'Ag. Riscossione',
                ('Cartella n. %d: sei decaduto dalla rateizzazione per %d rate non pagate (art. 19 D.P.R. 602/1973). Il ruolo torna esigibile per intero.')
                    :format(c.id, c.saltate))

            AUREA.Log('economia', 'avviso', nil, ('decadenza dalla rateizzazione sul ruolo %d'):format(c.id))
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Misure: preavviso di fermo, fermo, ipoteca, pignoramenti
-- ---------------------------------------------------------------------------
local function misuraAttiva(citizenid, tipo, bersaglio)
    return MySQL.scalar.await([[
        SELECT id FROM riscossione_misure
        WHERE citizenid = ? AND tipo = ? AND bersaglio = ? AND revocata = 0
    ]], { citizenid, tipo, bersaglio }) ~= nil
end

local function disponiFermo(citizenid, ruoloId, debito)
    -- Il veicolo meno prezioso fra quelli intestati: si ferma quello,
    -- non la macchina di rappresentanza. È come funziona davvero.
    local veicolo = MySQL.single.await([[
        SELECT targa FROM veicoli
        WHERE citizenid = ? AND stato IN ('garage','fuori')
        ORDER BY acquistato_il ASC LIMIT 1
    ]], { citizenid })
    if not veicolo then return false end
    if misuraAttiva(citizenid, 'preavviso_fermo', veicolo.targa)
       or misuraAttiva(citizenid, 'fermo', veicolo.targa) then return false end

    MySQL.insert.await([[
        INSERT INTO riscossione_misure (citizenid, ruolo_id, tipo, bersaglio, importo)
        VALUES (?, ?, 'preavviso_fermo', ?, ?)
    ]], { citizenid, ruoloId, veicolo.targa, debito })

    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Ag. Riscossione',
        ('Preavviso di fermo amministrativo sul veicolo %s. Hai %d minuti per pagare o rateizzare, poi il fermo è eseguito.')
            :format(veicolo.targa, RIS.Misure.preavvisoFermo.minutiPreavviso))

    AUREA.Log('economia', 'avviso', nil, ('preavviso di fermo su %s'):format(veicolo.targa))
    return true
end

local function eseguiFermo(misura)
    local ancoraDovuto = MySQL.single.await(
        'SELECT * FROM riscossione_ruoli WHERE id = ?', { misura.ruolo_id })
    if not ancoraDovuto or ancoraDovuto.stato == 'pagata' or ancoraDovuto.stato == 'sgravata'
       or ancoraDovuto.stato == 'rateizzata' then
        MySQL.update.await('UPDATE riscossione_misure SET revocata = 1, revocata_il = NOW() WHERE id = ?',
            { misura.id })
        return
    end

    MySQL.update.await('UPDATE riscossione_misure SET tipo = ? WHERE id = ?', { 'fermo', misura.id })
    MySQL.update.await([[
        UPDATE veicoli SET stato = 'sequestrato', garage = 'depositeria'
        WHERE targa = ? AND stato IN ('garage','fuori')
    ]], { misura.bersaglio })

    TriggerEvent('aurea:telefono:messaggioSistema', misura.citizenid, 'Ag. Riscossione',
        ('Fermo amministrativo eseguito sul veicolo %s. Non è più disponibile finché il ruolo non è estinto.')
            :format(misura.bersaglio))

    AUREA.Log('economia', 'avviso', nil, ('fermo amministrativo eseguito su %s'):format(misura.bersaglio))
end

local function pignoraConto(citizenid, ruoloId, debito)
    -- Saldo() risponde contanti e banca in quest'ordine: si aggredisce
    -- il conto, non le tasche. I contanti li prende un ufficiale
    -- giudiziario a casa, ed è un'altra storia.
    local _, saldo = AUREA.Denaro.Saldo(citizenid)
    saldo = saldo or 0
    local aggredibile = math.floor((saldo - RIS.Misure.pignoramentoConto.impignorabile)
                                   * RIS.Misure.pignoramentoConto.quotaMassima)
    if aggredibile <= 0 then return false end

    local preso = math.min(aggredibile, debito)
    if not AUREA.Denaro.SottraiOffline(citizenid, 'banca', preso, 'pignoramento presso terzi') then
        return false
    end

    MySQL.insert.await([[
        INSERT INTO riscossione_misure (citizenid, ruolo_id, tipo, bersaglio, importo)
        VALUES (?, ?, 'pignoramento_conto', 'conto corrente', ?)
    ]], { citizenid, ruoloId, preso })

    local ruolo = MySQL.single.await('SELECT * FROM riscossione_ruoli WHERE id = ?', { ruoloId })
    if ruolo then incassa(ruolo, preso, 'pignoramento del conto', citizenid) end

    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Ag. Riscossione',
        ('Pignoramento presso terzi eseguito sul conto: prelevati %s a valere sulla cartella n. %d.')
            :format(U.Euro(preso), ruoloId))

    AUREA.Log('economia', 'avviso', nil, ('pignoramento conto di %s: %s'):format(citizenid, U.Euro(preso)))
    return true
end

CreateThread(function()
    while true do
        Wait(RIS.Misure.preavvisoFermo.minutiPreavviso * 60000 / 3)

        -- I preavvisi maturati diventano fermi
        local maturati = MySQL.query.await([[
            SELECT id, citizenid, ruolo_id, bersaglio FROM riscossione_misure
            WHERE tipo = 'preavviso_fermo' AND revocata = 0
              AND TIMESTAMPDIFF(MINUTE, disposta_il, NOW()) >= ?
        ]], { RIS.Misure.preavvisoFermo.minutiPreavviso }) or {}
        for _, m in ipairs(maturati) do eseguiFermo(m) end

        -- I ruoli esecutivi meritano una misura, per importo crescente
        local esecutivi = MySQL.query.await([[
            SELECT id, citizenid, importo, aggio, incassato FROM riscossione_ruoli
            WHERE stato = 'esecutiva' LIMIT 30
        ]]) or {}

        for _, r in ipairs(esecutivi) do
            local debito = RIS.Dovuto(r)

            if debito >= RIS.Misure.pignoramentoConto.sogliaDebito then
                pignoraConto(r.citizenid, r.id, debito)
            elseif debito >= RIS.Misure.preavvisoFermo.sogliaDebito then
                disponiFermo(r.citizenid, r.id, debito)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Pignoramento dello stipendio (presso terzi)
--
--  Lo chiama aurea_core quando paga. Il datore di lavoro trattiene e
--  versa: al lavoratore arrivano quattro quinti, mai meno.
-- ---------------------------------------------------------------------------
exports('QuotaPignorabile', function(citizenid, netto)
    netto = math.floor(tonumber(netto) or 0)
    if netto <= 0 then return 0 end

    local ruolo = MySQL.single.await([[
        SELECT * FROM riscossione_ruoli
        WHERE citizenid = ? AND stato = 'esecutiva'
        ORDER BY notificata_il ASC LIMIT 1
    ]], { citizenid })
    if not ruolo then return 0 end

    local debito = RIS.Dovuto(ruolo)
    if debito < RIS.Misure.pignoramentoStipendio.sogliaDebito then return 0 end

    -- Art. 545 c.p.c.: il quinto, e non uno di più
    local quota = math.min(
        math.floor(netto * RIS.Misure.pignoramentoStipendio.quota),
        debito)
    if quota <= 0 then return 0 end

    MySQL.insert.await([[
        INSERT INTO riscossione_misure (citizenid, ruolo_id, tipo, bersaglio, importo)
        VALUES (?, ?, 'pignoramento_stipendio', 'busta paga', ?)
    ]], { citizenid, ruolo.id, quota })

    incassa(ruolo, quota, 'pignoramento dello stipendio', citizenid)

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'avviso', icona = '📕', durata = 14000,
            titolo = 'Trattenuta in busta paga',
            testo = ('%s pignorati sulla cartella n. %d. Il limite di legge è un quinto.')
                :format(U.Euro(quota), ruolo.id),
        })
    end

    return quota
end)

-- ---------------------------------------------------------------------------
--  Sgravio
--
--  Quando il debito non c'era, il ruolo si annulla. Lo fa l'agente, e
--  solo su richiesta di chi ha accertato: qui basta che lo decida un
--  funzionario, ma resta scritto chi.
-- ---------------------------------------------------------------------------
AUREA.Comando('sgravio', 'utente', 'Annulla un ruolo (Agenzia Riscossione)', {
    { name = 'ruolo', help = 'numero della cartella' },
    { name = 'motivo', help = 'motivo dello sgravio' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not agente(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📕', titolo = 'Riscossione',
            testo = 'Riservato ai funzionari della riscossione in servizio.' })
    end

    local id = tonumber(args[1])
    local motivo = table.concat(args, ' ', 2)
    if not id or motivo == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📕', titolo = 'Uso', testo = '/sgravio <cartella> <motivo>' })
    end

    local r = MySQL.single.await('SELECT * FROM riscossione_ruoli WHERE id = ?', { id })
    if not r then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📕', titolo = 'Riscossione', testo = 'Cartella inesistente.' })
    end

    MySQL.update.await('UPDATE riscossione_ruoli SET stato = ? WHERE id = ?', { 'sgravata', id })

    local misure = MySQL.query.await(
        'SELECT tipo, bersaglio FROM riscossione_misure WHERE ruolo_id = ? AND revocata = 0', { id }) or {}
    for _, m in ipairs(misure) do
        if m.tipo == 'fermo' and m.bersaglio then
            MySQL.update.await(
                'UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ? AND stato = \'sequestrato\'',
                { m.bersaglio })
        end
    end
    MySQL.update.await(
        'UPDATE riscossione_misure SET revocata = 1, revocata_il = NOW() WHERE ruolo_id = ? AND revocata = 0',
        { id })

    TriggerEvent('aurea:telefono:messaggioSistema', r.citizenid, 'Ag. Riscossione',
        ('Cartella n. %d sgravata. Motivo: %s.'):format(id, motivo))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '📕', titolo = 'Sgravio disposto',
        testo = ('Cartella n. %d annullata.'):format(id) })

    AUREA.Log('economia', 'info', g, ('sgravio sulla cartella %d (%s)'):format(id, motivo))
end)

-- ---------------------------------------------------------------------------
--  App del telefono
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'riscossione',
    nome = 'Cartelle',
    icona = '📕',
    colore = 'linear-gradient(150deg,#8f3b34,#4c1f1c)',
    ordine = 136,

    condizione = function(g)
        return (MySQL.scalar.await([[
            SELECT COUNT(*) FROM riscossione_ruoli
            WHERE citizenid = ? AND stato IN ('notificata','rateizzata','esecutiva')
        ]], { g.citizenid }) or 0) > 0
    end,

    badge = function(g)
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM riscossione_ruoli
            WHERE citizenid = ? AND stato = 'esecutiva'
        ]], { g.citizenid }) or 0
    end,

    schermata = function(g)
        local ruoli = ruoliDi(g.citizenid, true)
        local voci = {}

        for _, r in ipairs(ruoli) do
            local nota
            if r.stato == 'rateizzata' then
                nota = 'Rateizzata'
            elseif r.stato == 'esecutiva' then
                nota = 'Esecutiva: possono agire sul conto, sullo stipendio e sui veicoli'
            else
                nota = ('Da pagare entro %d minuti'):format(math.max(0, r.minutiResidui or 0))
            end

            voci[#voci + 1] = {
                icona = '📕',
                titolo = ('Cartella n. %d — %s'):format(r.id, r.descrizione),
                sottotitolo = nota,
                valore = U.Euro(r.dovuto),
                tono = r.stato == 'esecutiva' and 'rosso' or nil,
                inerte = true,
            }
        end

        local misure = MySQL.query.await([[
            SELECT tipo, bersaglio, importo FROM riscossione_misure
            WHERE citizenid = ? AND revocata = 0
        ]], { g.citizenid }) or {}
        for _, m in ipairs(misure) do
            local nomi = {
                preavviso_fermo = 'Preavviso di fermo',
                fermo = 'Fermo amministrativo',
                ipoteca = 'Ipoteca',
                pignoramento_conto = 'Pignoramento del conto',
                pignoramento_stipendio = 'Pignoramento dello stipendio',
            }
            voci[#voci + 1] = {
                icona = '⛔', titolo = nomi[m.tipo] or m.tipo,
                sottotitolo = tostring(m.bersaglio or '—'),
                valore = U.Euro(m.importo or 0), tono = 'rosso', inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📕', titolo = 'Nessuna cartella', inerte = true }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Debito a ruolo',
            valore = U.Euro(debitoTotale(g.citizenid)),
            nota = 'Oneri di riscossione compresi. Si paga o si rateizza allo sportello.',
            voci = voci,
        }
    end,
})
