--[[
    AUREA · Poste (server)
]]

local U = AUREA.Util

local function destinatarioDaCF(cf)
    return MySQL.single.await(
        'SELECT citizenid, nome, cognome FROM personaggi WHERE codice_fiscale = ?',
        { tostring(cf or ''):upper() })
end

-- ---------------------------------------------------------------------------
--  Sportello
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pos:sportello', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    if not POS.UfficioVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(nil, 'Non sei in un ufficio postale.')
    end

    local inGiacenza = MySQL.query.await([[
        SELECT id, tipo, mittente_nome, oggetto, spedita_il
        FROM corrispondenza
        WHERE destinatario = ? AND ritirata = 0
        ORDER BY id ASC
    ]], { g.citizenid }) or {}

    for _, c in ipairs(inGiacenza) do
        c.quando = U.DataOraIT(math.floor((c.spedita_il or 0) / 1000))
    end

    local tributi = MySQL.query.await([[
        SELECT id, tipo, periodo, importo, scadenza
        FROM tributi WHERE citizenid = ? AND stato = 'dovuto'
        ORDER BY scadenza ASC LIMIT 20
    ]], { g.citizenid }) or {}

    for _, t in ipairs(tributi) do
        t.entro = U.DataIT(math.floor((t.scadenza or 0) / 1000))
    end

    rispondi({
        corrispondenza = inGiacenza,
        tributi = tributi,
        commissione = POS.Bollettini.commissione,
        tariffe = POS.Tariffe,
    })
end)

-- ---------------------------------------------------------------------------
--  Spedizione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pos:spedisci', function(src, rispondi, tipo, cf, oggetto, testo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not POS.UfficioVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Devi essere allo sportello.')
    end

    local t = POS.GetTariffa(tipo)
    if not t then return rispondi(false, 'Tipo di invio non previsto.') end

    local d = destinatarioDaCF(cf)
    if not d then return rispondi(false, 'Codice fiscale non trovato in anagrafe.') end
    if d.citizenid == g.citizenid then return rispondi(false, 'Non puoi spedire a te stesso.') end

    local oggi = os.date('%Y-%m-%d')
    local inviati = MySQL.scalar.await([[
        SELECT COUNT(*) FROM corrispondenza WHERE mittente = ? AND DATE(spedita_il) = ?
    ]], { g.citizenid, oggi }) or 0
    if inviati >= POS.Regole.inviiGiornalieri then
        return rispondi(false, 'Hai raggiunto il limite di invii giornalieri.')
    end

    if not g:SottraiOvunque(t.costo, ('spedizione %s'):format(t.nome)) then
        return rispondi(false, ('La spedizione costa %s.'):format(U.Euro(t.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(t.costo * 0.22), g.citizenid)

    local contenitore = nil
    if tipo == 'pacco' then
        contenitore = ('pacco:%s_%d'):format(g.citizenid, math.random(100000, 999999))
    end

    local id = MySQL.insert.await([[
        INSERT INTO corrispondenza
            (tipo, mittente, mittente_nome, destinatario, oggetto, testo, contenitore, scade_il)
        VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], {
        tipo, g.citizenid, g:NomeCompleto(), d.citizenid,
        tostring(oggetto or ''):sub(1, 90),
        tostring(testo or ''):sub(1, POS.Regole.lunghezzaTesto),
        contenitore, t.giacenzaOre,
    })

    local destinatario = AUREA.GetPlayerByCitizenId(d.citizenid)
    if destinatario then
        TriggerClientEvent('aurea:ui:notifica', destinatario.source, {
            tipo = 'info', icona = '📮', durata = 14000,
            titolo = ('Hai %s in giacenza'):format(t.nome:lower()),
            testo = ('Da %s. Passa in un ufficio postale a ritirarla.'):format(g:NomeCompleto()),
        })
    end

    rispondi(true, contenitore and { id = id, contenitore = contenitore,
        capienza = t.slot, pesoMax = t.peso }
        or ('%s spedita a %s %s.'):format(t.nome, d.nome, d.cognome))
end)

-- ---------------------------------------------------------------------------
--  Ritiro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pos:ritira', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    if not POS.UfficioVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(nil, 'Devi essere allo sportello.')
    end

    local c = MySQL.single.await(
        'SELECT * FROM corrispondenza WHERE id = ? AND destinatario = ? AND ritirata = 0',
        { id, g.citizenid })
    if not c then return rispondi(nil, 'Non risulta in giacenza.') end

    MySQL.update.await('UPDATE corrispondenza SET ritirata = 1, ritirata_il = NOW() WHERE id = ?', { id })

    -- Sulla raccomandata il mittente riceve l'avviso di ricevimento
    local t = POS.GetTariffa(c.tipo)
    if t and t.ricevuta then
        local mittente = AUREA.GetPlayerByCitizenId(c.mittente)
        if mittente then
            TriggerClientEvent('aurea:ui:notifica', mittente.source, {
                tipo = 'successo', icona = '📮', durata = 13000,
                titolo = 'Avviso di ricevimento',
                testo = ('%s ha ritirato la tua raccomandata "%s".')
                    :format(g:NomeCompleto(), c.oggetto or ''),
            })
        end
    end

    rispondi({
        tipo = c.tipo, oggetto = c.oggetto, testo = c.testo,
        mittente = c.mittente_nome,
        contenitore = c.contenitore,
        quando = U.DataOraIT(math.floor((c.spedita_il or 0) / 1000)),
    })
end)

-- ---------------------------------------------------------------------------
--  Bollettini
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pos:paga', function(src, rispondi, idTributo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not POS.UfficioVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Devi essere allo sportello.')
    end

    local t = MySQL.single.await(
        'SELECT * FROM tributi WHERE id = ? AND citizenid = ? AND stato = \'dovuto\'',
        { idTributo, g.citizenid })
    if not t then return rispondi(false, 'Bollettino non trovato.') end

    local dovuto = math.floor(tonumber(t.importo) or 0) + POS.Bollettini.commissione

    if not g:SottraiOvunque(dovuto, ('bollettino %s'):format(t.tipo)) then
        return rispondi(false, ('Servono %s (%s + %s di commissione).')
            :format(U.Euro(dovuto), U.Euro(t.importo), U.Euro(POS.Bollettini.commissione)))
    end

    MySQL.update.await('UPDATE tributi SET stato = \'pagato\', pagato_il = NOW() WHERE id = ?', { idTributo })

    TriggerEvent('aurea:fisco:incasso', t.tipo, math.floor(tonumber(t.importo)), g.citizenid)
    TriggerEvent('aurea:fisco:incasso', 'commissioni_postali', POS.Bollettini.commissione, g.citizenid)

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'visura', 1, {
        ragione = 'Ricevuta di pagamento',
        tributo = t.tipo, periodo = t.periodo,
        importo = U.Euro(t.importo),
        intestatario = g:NomeCompleto(),
    })

    rispondi(true, ('Bollettino pagato: %s. La ricevuta è nel tuo inventario.'):format(U.Euro(dovuto)))
end)

-- ---------------------------------------------------------------------------
--  Giacenze scadute: tornano al mittente
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1800000)
        if POS.Regole.restituisciDopoGiacenza then
            local scadute = MySQL.query.await([[
                SELECT id, mittente, tipo, oggetto FROM corrispondenza
                WHERE ritirata = 0 AND scade_il < NOW()
            ]]) or {}

            for _, c in ipairs(scadute) do
                MySQL.update('UPDATE corrispondenza SET ritirata = 2 WHERE id = ?', { c.id })

                local mittente = AUREA.GetPlayerByCitizenId(c.mittente)
                if mittente then
                    TriggerClientEvent('aurea:ui:notifica', mittente.source, {
                        tipo = 'avviso', icona = '📮', durata = 13000,
                        titolo = 'Compiuta giacenza',
                        testo = ('"%s" non è stata ritirata ed è tornata al mittente.')
                            :format(c.oggetto or c.tipo),
                    })
                end
            end
        end
    end
end)
