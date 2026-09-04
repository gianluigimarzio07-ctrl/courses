--[[
    AUREA · Fisco (server) — callback, comandi e tributi ricorrenti
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Callback contribuente
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fisco:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local tributi, totale = Erario.Debito(g.citizenid)
    local fatture = Imprese.FattureDaPagare(g.citizenid)
    local imprese = Imprese.Del(g.citizenid)

    for _, f in ipairs(fatture) do
        f.scadenzaIT = U.DataOraIT(math.floor((f.scadenza or 0) / 1000))
    end

    rispondi({
        cf = g.cf,
        tributi = tributi,
        totaleTributi = totale,
        fatture = fatture,
        imprese = imprese,
    })
end)

AUREA.Callback.Registra('fisco:paga', function(src, rispondi, idTributo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    local ok, messaggio = Erario.Salda(g.citizenid, idTributo)
    rispondi(ok, messaggio)
end)

AUREA.Callback.Registra('fisco:pagaFattura', function(src, rispondi, idFattura)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    local ok, messaggio = Imprese.PagaFattura(g.citizenid, idFattura)
    rispondi(ok, messaggio)
end)

AUREA.Callback.Registra('fisco:apriImpresa', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil, 'Sessione non valida.') end
    local impresa, errore = Imprese.Apri(g.citizenid, dati or {})
    rispondi(impresa, errore)
end)

AUREA.Callback.Registra('fisco:mieImprese', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local imprese = Imprese.Del(g.citizenid)
    for _, i in ipairs(imprese) do
        i.dipendenti = MySQL.query.await([[
            SELECT d.citizenid, d.mansione, d.stipendio, p.nome, p.cognome
            FROM impresa_dipendenti d
            JOIN personaggi p ON p.citizenid = d.citizenid
            WHERE d.impresa_id = ?
        ]], { i.id }) or {}
        i.regimeEtichetta = FISCO.Regimi[i.regime].etichetta
        i.formaEtichetta = FISCO.Forme[i.forma].etichetta
    end
    rispondi(imprese)
end)

AUREA.Callback.Registra('fisco:emettiFattura', function(src, rispondi, impresaId, cfCliente, descrizione, euro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local cliente = MySQL.scalar.await('SELECT citizenid FROM personaggi WHERE codice_fiscale = ?', { (cfCliente or ''):upper() })
    if not cliente then return rispondi(false, 'Codice fiscale del cliente non trovato.') end
    if cliente == g.citizenid then return rispondi(false, 'Non puoi fatturare a te stesso.') end

    local imponibile = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    local _, errore = Imprese.Fattura(impresaId, g.citizenid, cliente, descrizione, imponibile)
    if errore then return rispondi(false, errore) end

    rispondi(true, ('Fattura emessa per %s.'):format(U.Euro(imponibile)))
end)

AUREA.Callback.Registra('fisco:assumi', function(src, rispondi, impresaId, cfDipendente, mansione, stipendioEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local impresa = MySQL.single.await('SELECT * FROM imprese WHERE id = ? AND titolare = ?', { impresaId, g.citizenid })
    if not impresa then return rispondi(false, 'Non sei titolare di questa impresa.') end

    local dipendente = MySQL.scalar.await('SELECT citizenid FROM personaggi WHERE codice_fiscale = ?', { (cfDipendente or ''):upper() })
    if not dipendente then return rispondi(false, 'Codice fiscale non trovato.') end

    local quanti = MySQL.scalar.await('SELECT COUNT(*) FROM impresa_dipendenti WHERE impresa_id = ?', { impresaId }) or 0
    if quanti >= impresa.dipendenti_max then
        return rispondi(false, ('Questa forma societaria ammette al massimo %d dipendenti.'):format(impresa.dipendenti_max))
    end

    local stipendio = U.ACentesimi(tonumber(tostring(stipendioEuro):gsub(',', '.')) or 0)
    if stipendio <= 0 then return rispondi(false, 'Stipendio non valido.') end

    MySQL.query.await([[
        INSERT INTO impresa_dipendenti (impresa_id, citizenid, mansione, stipendio)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE mansione = VALUES(mansione), stipendio = VALUES(stipendio)
    ]], { impresaId, dipendente, (mansione or 'operaio'):sub(1, 40), stipendio })

    local assunto = AUREA.GetPlayerByCitizenId(dipendente)
    if assunto then
        TriggerClientEvent('aurea:ui:notifica', assunto.source, {
            tipo = 'successo', icona = '📄', durata = 10000,
            titolo = 'Contratto di assunzione',
            testo = ('%s ti ha assunto come %s. Stipendio %s ogni ciclo di paga.'):format(
                impresa.ragione_sociale, mansione or 'operaio', U.Euro(stipendio)),
        })
    end

    rispondi(true, 'Assunzione registrata.')
end)

--- Versamento in cassa o prelievo di utili da parte del titolare.
AUREA.Callback.Registra('fisco:movimentoCassa', function(src, rispondi, impresaId, verso, euro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local impresa = MySQL.single.await('SELECT * FROM imprese WHERE id = ? AND titolare = ? AND attiva = 1',
        { impresaId, g.citizenid })
    if not impresa then return rispondi(false, 'Non sei titolare di questa impresa.') end

    local importo = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end

    if verso == 'ricapitalizza' then
        if not g:Sottrai('banca', importo, ('versamento cassa %s'):format(impresa.ragione_sociale)) then
            return rispondi(false, 'Fondi insufficienti sul conto corrente.')
        end
        MySQL.update.await('UPDATE imprese SET cassa = cassa + ? WHERE id = ?', { importo, impresaId })
        return rispondi(true, ('Versati %s nella cassa aziendale.'):format(U.Euro(importo)))
    end

    -- Prelievo di utili: non si può prosciugare la cassa lasciando l'IVA scoperta
    local disponibile = impresa.cassa - impresa.iva_a_debito
    if importo > disponibile then
        return rispondi(false, ('Prelevabili al massimo %s: %s sono accantonati per l\'IVA.'):format(
            U.Euro(math.max(0, disponibile)), U.Euro(impresa.iva_a_debito)))
    end

    MySQL.update.await('UPDATE imprese SET cassa = cassa - ? WHERE id = ?', { importo, impresaId })
    g:Aggiungi('banca', importo, ('prelievo utili %s'):format(impresa.ragione_sociale))
    rispondi(true, ('Prelevati %s dalla cassa.'):format(U.Euro(importo)))
end)

-- ---------------------------------------------------------------------------
--  Stipendi privati: erogati dalla cassa dell'impresa
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(120000)
    while true do
        Wait(FISCO.Tributi.inps.periodicitaMinuti * 60000)

        local rapporti = MySQL.query.await([[
            SELECT d.citizenid, d.stipendio, d.mansione, i.id AS impresa_id,
                   i.ragione_sociale, i.cassa
            FROM impresa_dipendenti d
            JOIN imprese i ON i.id = d.impresa_id
            WHERE i.attiva = 1 AND d.stipendio > 0
        ]]) or {}

        for _, r in ipairs(rapporti) do
            if r.cassa >= r.stipendio then
                local contributi = math.floor(r.stipendio * FISCO.Tributi.inps.aliquota)
                local irpef = math.floor(r.stipendio * 0.23)
                local netto = r.stipendio - contributi - irpef

                MySQL.update.await('UPDATE imprese SET cassa = cassa - ? WHERE id = ?', { r.stipendio, r.impresa_id })
                AUREA.Denaro.AggiungiOffline(r.citizenid, 'banca', netto, ('stipendio %s'):format(r.ragione_sociale))
                Erario.Incassa('inps', contributi, r.citizenid)
                Erario.Incassa('irpef', irpef, r.citizenid)

                local g = AUREA.GetPlayerByCitizenId(r.citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'successo', icona = '💶', durata = 8000,
                        titolo = ('Busta paga — %s'):format(r.ragione_sociale),
                        testo = ('Netto %s · contributi %s · IRPEF %s'):format(U.Euro(netto), U.Euro(contributi), U.Euro(irpef)),
                    })
                end
            else
                local titolare = MySQL.scalar.await('SELECT titolare FROM imprese WHERE id = ?', { r.impresa_id })
                local g = titolare and AUREA.GetPlayerByCitizenId(titolare)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'errore', icona = '⚠', durata = 11000,
                        titolo = ('Cassa insufficiente — %s'):format(r.ragione_sociale),
                        testo = 'Non è stato possibile pagare uno stipendio. Ricapitalizza l\'impresa.',
                    })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  IMU e TARI sugli immobili
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(180000)
    while true do
        Wait(FISCO.Tributi.imu.periodicitaMinuti * 60000)

        local immobili = MySQL.query.await([[
            SELECT id, codice, nome, proprietario, rendita_catastale
            FROM immobili WHERE proprietario IS NOT NULL
        ]]) or {}

        -- Il primo immobile di ciascun proprietario è abitazione principale: esente IMU
        local contati = {}
        local periodo = ('%s-S%d'):format(os.date('%Y'), tonumber(os.date('%m')) <= 6 and 1 or 2)

        for _, imm in ipairs(immobili) do
            contati[imm.proprietario] = (contati[imm.proprietario] or 0) + 1

            local tari = FISCO.Tributi.tari.importoBase
            Erario.IscriviTributo(imm.proprietario, 'tari', ('%s/%s'):format(periodo, imm.codice), tari, 20)

            if contati[imm.proprietario] > 1 or not FISCO.Tributi.imu.esenteAbitazionePrincipale then
                local imu = math.floor((imm.rendita_catastale or 0) * FISCO.Tributi.imu.aliquota)
                if imu > 0 then
                    Erario.IscriviTributo(imm.proprietario, 'imu', ('%s/%s'):format(periodo, imm.codice), imu, 20)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('cassetto', 'utente', 'Consulta la tua posizione fiscale', {}, function(src, _, _, g)
    if not g then return end
    local tributi, totale = Erario.Debito(g.citizenid)
    local fatture = Imprese.FattureDaPagare(g.citizenid)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = (totale > 0 or #fatture > 0) and 'avviso' or 'successo',
        icona = '🗃', durata = 11000,
        titolo = 'Cassetto fiscale',
        testo = ('CF %s · %d tributi per %s · %d fatture insolute'):format(g.cf, #tributi, U.Euro(totale), #fatture),
    })
end)

AUREA.Comando('verificafiscale', 'utente', 'Verifica la posizione fiscale di un contribuente', {
    { name = 'cf', help = 'Codice fiscale' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('verifica_fiscale') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato alla Guardia di Finanza e all\'Agenzia delle Entrate.' })
    end

    local cf = (args[1] or ''):upper()
    local pg = MySQL.single.await('SELECT citizenid, nome, cognome FROM personaggi WHERE codice_fiscale = ?', { cf })
    if not pg then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non trovato', testo = ('Nessun contribuente con CF %s.'):format(cf) })
    end

    local _, debito = Erario.Debito(pg.citizenid)
    local imprese = MySQL.query.await('SELECT ragione_sociale, piva, regime, fatturato_anno FROM imprese WHERE titolare = ? AND attiva = 1', { pg.citizenid }) or {}

    local righe = {}
    for _, i in ipairs(imprese) do
        righe[#righe + 1] = ('%s (P.IVA %s, %s)'):format(i.ragione_sociale, i.piva, i.regime)
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = debito > 0 and 'errore' or 'info',
        icona = '💼', durata = 16000,
        titolo = ('%s %s'):format(pg.nome, pg.cognome),
        testo = ('Debito erariale: %s\nImprese: %s'):format(
            U.Euro(debito), #righe > 0 and table.concat(righe, ' · ') or 'nessuna'),
    })
    AUREA.Log('economia', 'info', g, ('verifica fiscale su %s'):format(cf))
end)

AUREA.Comando('erario', 'admin', 'Mostra il saldo dell\'erario', {}, function(src)
    local saldo = Erario.Saldo()
    local gettito = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = \'gettito_fiscale\'') or 0
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '🏛', durata = 12000,
        titolo = 'Conti pubblici',
        testo = ('Saldo erario: %s · gettito complessivo: %s'):format(U.Euro(saldo), U.Euro(tonumber(gettito) or 0)),
    })
end)
