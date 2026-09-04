--[[
    AUREA · Imprese e fatturazione
]]

Imprese = {}

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Apertura di una partita IVA
-- ---------------------------------------------------------------------------
function Imprese.Apri(citizenid, dati)
    local forma = FISCO.Forme[dati.forma]
    if not forma then return nil, 'Forma societaria non valida.' end

    local settore
    for _, s in ipairs(FISCO.Settori) do
        if s.id == dati.settore then settore = s break end
    end
    if not settore then return nil, 'Settore di attività non valido.' end

    local ragione = tostring(dati.ragioneSociale or ''):gsub('[^%w%s&.\'àèéìòù-]', ''):sub(1, 60)
    if #ragione < 3 then return nil, 'La ragione sociale deve avere almeno 3 caratteri.' end

    local giaTitolare = MySQL.scalar.await('SELECT COUNT(*) FROM imprese WHERE titolare = ? AND attiva = 1', { citizenid }) or 0
    if giaTitolare >= 2 then return nil, 'Puoi essere titolare di al massimo due imprese attive.' end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if not g then return nil, 'Devi essere in gioco.' end

    local costoTotale = forma.costo + forma.capitaleMinimo
    if not g:SottraiOvunque(costoTotale, ('costituzione %s'):format(ragione)) then
        return nil, ('Servono %s (diritti %s + capitale sociale %s).'):format(
            U.Euro(costoTotale), U.Euro(forma.costo), U.Euro(forma.capitaleMinimo))
    end

    local piva = AUREA.Anagrafe.NuovaPartitaIVA()
    local regime = (dati.regime == 'ordinario') and 'ordinario' or 'forfettario'

    local id = MySQL.insert.await([[
        INSERT INTO imprese (piva, ragione_sociale, forma, settore, titolare, regime, cassa, sede, dipendenti_max)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { piva, ragione, dati.forma, settore.id, citizenid, regime, forma.capitaleMinimo, dati.sede, forma.dipendenti })

    -- Conto corrente aziendale
    local iban = AUREA.Anagrafe.NuovoIBAN(id)
    MySQL.insert.await('INSERT INTO conti (iban, impresa_id, tipo, nome, saldo) VALUES (?, ?, \'impresa\', ?, ?)',
        { iban, id, ragione, forma.capitaleMinimo })

    -- Diritti camerali all'erario
    Erario.Incassa('diritti_camerali', forma.costo, citizenid)

    TriggerEvent('aurea:inventario:aggiungi', citizenid, 'visura', 1, {
        piva = piva, ragione = ragione, forma = forma.etichetta,
        settore = settore.etichetta, regime = regime, iban = iban,
    })

    AUREA.Log('economia', 'info', nil, ('Aperta impresa %s (P.IVA %s) da %s'):format(ragione, piva, citizenid))
    return { id = id, piva = piva, iban = iban, ragione = ragione }, nil
end

--- Imprese di cui il personaggio è titolare o dipendente.
function Imprese.Del(citizenid)
    return MySQL.query.await([[
        SELECT i.*, (i.titolare = ?) AS eTitolare,
               (SELECT mansione FROM impresa_dipendenti d WHERE d.impresa_id = i.id AND d.citizenid = ?) AS mansione
        FROM imprese i
        WHERE i.attiva = 1 AND (
            i.titolare = ? OR
            EXISTS (SELECT 1 FROM impresa_dipendenti d WHERE d.impresa_id = i.id AND d.citizenid = ?)
        )
    ]], { citizenid, citizenid, citizenid, citizenid }) or {}
end

-- ---------------------------------------------------------------------------
--  Fatturazione
-- ---------------------------------------------------------------------------

--- Emette una fattura verso un cliente.
---@return integer|nil id, string|nil errore
function Imprese.Fattura(impresaId, emittenteCitizenid, clienteCitizenid, descrizione, imponibile)
    local impresa = MySQL.single.await('SELECT * FROM imprese WHERE id = ? AND attiva = 1', { impresaId })
    if not impresa then return nil, 'Impresa non trovata.' end

    -- solo titolare o dipendente possono fatturare
    local abilitato = impresa.titolare == emittenteCitizenid
        or (MySQL.scalar.await('SELECT id FROM impresa_dipendenti WHERE impresa_id = ? AND citizenid = ?',
            { impresaId, emittenteCitizenid }) ~= nil)
    if not abilitato then return nil, 'Non sei autorizzato a fatturare per questa impresa.' end

    imponibile = math.floor(tonumber(imponibile) or 0)
    if imponibile <= 0 or imponibile > 100000000 then return nil, 'Importo non valido.' end

    local settore
    for _, s in ipairs(FISCO.Settori) do
        if s.id == impresa.settore then settore = s break end
    end

    local regime = FISCO.Regimi[impresa.regime]
    local aliquota = regime.applicaIva and (settore and settore.ivaVendita or FISCO.Iva.ordinaria) or 0
    local iva = math.floor(imponibile * aliquota / 100)
    local totale = imponibile + iva

    local progressivo = (MySQL.scalar.await('SELECT COUNT(*) FROM fatture WHERE emittente = ?', { impresaId }) or 0) + 1
    local numero = ('%d/%s'):format(progressivo, os.date('%Y'))

    local id = MySQL.insert.await([[
        INSERT INTO fatture (numero, emittente, emittente_pg, cliente_pg, descrizione,
                             imponibile, aliquota, iva, totale, scadenza)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { numero, impresaId, emittenteCitizenid, clienteCitizenid, descrizione,
          imponibile, aliquota, iva, totale, U.DataOraPiuOre(72) })

    local cliente = AUREA.GetPlayerByCitizenId(clienteCitizenid)
    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'avviso', icona = '🧾', durata = 12000,
            titolo = ('Fattura %s da %s'):format(numero, impresa.ragione_sociale),
            testo = ('%s — imponibile %s + IVA %d%% = %s. Pagala dal telefono entro 3 giorni.'):format(
                descrizione, U.Euro(imponibile), aliquota, U.Euro(totale)),
        })
    end
    TriggerEvent('aurea:telefono:messaggioSistema', clienteCitizenid, impresa.ragione_sociale,
        ('Fattura %s — %s. Totale %s.'):format(numero, descrizione, U.Euro(totale)))

    return id, nil
end

--- Il cliente paga una fattura: l'imponibile va all'impresa, l'IVA all'erario.
function Imprese.PagaFattura(clienteCitizenid, idFattura)
    local f = MySQL.single.await('SELECT * FROM fatture WHERE id = ? AND cliente_pg = ? AND stato = \'emessa\'',
        { idFattura, clienteCitizenid })
    if not f then return false, 'Fattura non trovata o già saldata.' end

    local g = AUREA.GetPlayerByCitizenId(clienteCitizenid)
    if not g then return false, 'Devi essere in gioco.' end
    if not g:SottraiOvunque(f.totale, ('fattura %s'):format(f.numero)) then
        return false, ('Servono %s.'):format(U.Euro(f.totale))
    end

    MySQL.update.await('UPDATE fatture SET stato = \'pagata\' WHERE id = ?', { idFattura })

    -- L'imponibile entra in cassa impresa, l'IVA resta a debito verso l'erario
    MySQL.update.await([[
        UPDATE imprese SET cassa = cassa + ?, fatturato_anno = fatturato_anno + ?, iva_a_debito = iva_a_debito + ?
        WHERE id = ?
    ]], { f.imponibile, f.imponibile, f.iva, f.emittente })

    -- Il pizzo, se imposto, si preleva subito dall'incasso
    TriggerEvent('aurea:famiglie:incassoImpresa', f.emittente, f.imponibile)

    return true, ('Fattura %s saldata: %s.'):format(f.numero, U.Euro(f.totale))
end

--- Fatture insolute del cliente.
function Imprese.FattureDaPagare(citizenid)
    return MySQL.query.await([[
        SELECT f.id, f.numero, f.descrizione, f.imponibile, f.aliquota, f.iva, f.totale, f.scadenza,
               i.ragione_sociale
        FROM fatture f
        LEFT JOIN imprese i ON i.id = f.emittente
        WHERE f.cliente_pg = ? AND f.stato = 'emessa'
        ORDER BY f.emessa_il ASC
    ]], { citizenid }) or {}
end

-- ---------------------------------------------------------------------------
--  Liquidazione IVA periodica e imposta sul reddito d'impresa
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(90000)
    while true do
        Wait(FISCO.Iva.periodicitaMinuti * 60000)

        local imprese = MySQL.query.await('SELECT * FROM imprese WHERE attiva = 1') or {}
        local periodo = ('%s-Q%d'):format(os.date('%Y'), math.ceil(tonumber(os.date('%m')) / 3))

        for _, imp in ipairs(imprese) do
            local regime = FISCO.Regimi[imp.regime] or FISCO.Regimi.forfettario

            if regime.applicaIva and imp.iva_a_debito > 0 then
                -- Versamento IVA: prima dalla cassa aziendale, poi a carico del titolare
                local dovuta = imp.iva_a_debito
                if imp.cassa >= dovuta then
                    MySQL.update.await('UPDATE imprese SET cassa = cassa - ?, iva_a_debito = 0 WHERE id = ?',
                        { dovuta, imp.id })
                    Erario.Incassa('iva', dovuta, imp.titolare)

                    local g = AUREA.GetPlayerByCitizenId(imp.titolare)
                    if g then
                        TriggerClientEvent('aurea:ui:notifica', g.source, {
                            tipo = 'info', icona = '🧾', durata = 9000,
                            titolo = ('Liquidazione IVA — %s'):format(imp.ragione_sociale),
                            testo = ('Versati %s dalla cassa aziendale.'):format(U.Euro(dovuta)),
                        })
                    end
                else
                    MySQL.update.await('UPDATE imprese SET iva_a_debito = 0 WHERE id = ?', { imp.id })
                    Erario.IscriviTributo(imp.titolare, 'iva', periodo, dovuta, 15)
                end
            end

            -- Imposta sul reddito d'impresa maturato nel periodo
            if imp.fatturato_anno > 0 then
                local imposta = math.floor(imp.fatturato_anno * regime.aliquota)
                MySQL.update.await('UPDATE imprese SET fatturato_anno = 0 WHERE id = ?', { imp.id })

                if imp.cassa >= imposta then
                    MySQL.update.await('UPDATE imprese SET cassa = cassa - ? WHERE id = ?', { imposta, imp.id })
                    Erario.Incassa(imp.regime == 'forfettario' and 'imposta_sostitutiva' or 'ires', imposta, imp.titolare)
                else
                    Erario.IscriviTributo(imp.titolare, 'irpef', periodo, imposta, 15)
                end
            end

            -- Superamento del limite del forfettario: passaggio d'ufficio all'ordinario
            if imp.regime == 'forfettario' and imp.fatturato_anno > FISCO.Regimi.forfettario.limiteFatturato then
                MySQL.update.await('UPDATE imprese SET regime = \'ordinario\' WHERE id = ?', { imp.id })
                local g = AUREA.GetPlayerByCitizenId(imp.titolare)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '📈', durata = 12000,
                        titolo = 'Uscita dal regime forfettario',
                        testo = ('%s ha superato gli 85.000 € di fatturato: da ora si applica il regime ordinario con IVA.'):format(imp.ragione_sociale),
                    })
                end
            end
        end

        -- Fatture scadute non pagate
        MySQL.update([[UPDATE fatture SET stato = 'insoluta' WHERE stato = 'emessa' AND scadenza < NOW()]])
    end
end)

exports('ApriImpresa', Imprese.Apri)
exports('EmettiFattura', Imprese.Fattura)
exports('ImpreseDi', Imprese.Del)
