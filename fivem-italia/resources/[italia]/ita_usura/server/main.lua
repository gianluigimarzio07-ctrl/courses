--[[
    AUREA · Usura (server)

    Il prestito è un contratto fra due giocatori: il server non presta
    niente e non garantisce niente. Quello che fa è tenere il conto,
    farlo scadere, e dire a tutti e due la stessa cosa — compreso se il
    tasso è sopra la soglia, che è un'informazione che in un contratto
    vero il debitore avrebbe.

    Il modulo non manda nessuno a picchiare nessuno. Manda un avviso e
    un indirizzo. Cosa succede dopo lo decidono le persone, ed è la parte
    che non si può scrivere in Lua.
]]

local U = AUREA.Util

local proposte = {}     -- [citizenidDebitore] = proposta in attesa

-- ---------------------------------------------------------------------------
--  Lettura
-- ---------------------------------------------------------------------------
local function prestitiDi(citizenid, comeCreditore)
    local colonna = comeCreditore and 'creditore' or 'debitore'
    local righe = MySQL.query.await(([[
        SELECT p.*,
               CONCAT(d.nome, ' ', d.cognome) AS nome_debitore,
               CONCAT(c.nome, ' ', c.cognome) AS nome_creditore
        FROM usura_prestiti p
        LEFT JOIN personaggi d ON d.citizenid = p.debitore
        LEFT JOIN personaggi c ON c.citizenid = p.creditore
        WHERE p.%s = ? AND p.stato = 'attivo'
        ORDER BY p.id DESC
    ]]):format(colonna), { citizenid }) or {}

    for _, r in ipairs(righe) do
        r.taeg = USU.Taeg(r.capitale, r.totale, r.rate)
        r.giudizio = select(1, USU.Giudizio(r.taeg))
    end
    return righe
end

-- ---------------------------------------------------------------------------
--  Proposta di prestito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('usu:proponi', function(src, rispondi, debitoreSrc, capitaleEuro, totaleEuro, rate)
    local c = AUREA.GetPlayer(src)
    if not c then return rispondi(false, 'Sessione non valida.') end

    local d = AUREA.GetPlayer(tonumber(debitoreSrc))
    if not d then return rispondi(false, 'La persona non è collegata.') end
    if d.citizenid == c.citizenid then return rispondi(false, 'Non si presta a sé stessi.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(d.source))) > USU.Distanza.stipula then
        return rispondi(false, 'Dovete essere faccia a faccia.')
    end

    local capitale = U.ACentesimi(tonumber(tostring(capitaleEuro):gsub(',', '.')) or 0)
    local totale = U.ACentesimi(tonumber(tostring(totaleEuro):gsub(',', '.')) or 0)
    rate = math.floor(U.Clamp(tonumber(rate) or 0, USU.Prestito.rateMinime, USU.Prestito.rateMassime))

    if capitale < USU.Prestito.minimo or capitale > USU.Prestito.massimo then
        return rispondi(false, ('Il capitale sta fra %s e %s.')
            :format(U.Euro(USU.Prestito.minimo), U.Euro(USU.Prestito.massimo)))
    end
    if totale < capitale then return rispondi(false, 'La restituzione non può essere inferiore al prestato.') end

    local aperti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM usura_prestiti WHERE creditore = ? AND stato = ?', { c.citizenid, 'attivo' }) or 0
    if aperti >= USU.Prestito.massimiPerCreditore then
        return rispondi(false, ('Hai già %d prestiti in piedi.'):format(aperti))
    end

    local suoi = MySQL.scalar.await(
        'SELECT COUNT(*) FROM usura_prestiti WHERE debitore = ? AND stato = ?', { d.citizenid, 'attivo' }) or 0
    if suoi >= USU.Prestito.massimiPerDebitore then
        return rispondi(false, 'Quella persona ha già troppi debiti in piedi.')
    end

    if c:Saldo('contanti') < capitale then
        return rispondi(false, ('Ti servono %s in contanti: un prestito così non passa dalla banca.')
            :format(U.Euro(capitale)))
    end

    local taeg = USU.Taeg(capitale, totale, rate)
    local giudizio, spiegazione = USU.Giudizio(taeg)

    proposte[d.citizenid] = {
        creditore = c.citizenid, nomeCreditore = c:NomeCompleto(),
        capitale = capitale, totale = totale, rate = rate,
        taeg = taeg, giudizio = giudizio, creata = os.time(),
    }

    TriggerClientEvent('usu:proposta', d.source, {
        creditore = c:NomeCompleto(),
        capitale = U.Euro(capitale), totale = U.Euro(totale),
        rata = U.Euro(math.ceil(totale / rate)), rate = rate,
        minuti = USU.Prestito.minutiPerRata,
        taeg = ('%.1f%%'):format(taeg * 100),
        giudizio = giudizio, spiegazione = spiegazione,
    })

    rispondi(true, ('Proposta trasmessa.\nTAEG %.1f%% — %s'):format(taeg * 100, spiegazione))
end)

-- ---------------------------------------------------------------------------
--  Accettazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('usu:accetta', function(src, rispondi, accetta)
    local d = AUREA.GetPlayer(src)
    if not d then return rispondi(false, 'Sessione non valida.') end

    local p = proposte[d.citizenid]
    if not p then return rispondi(false, 'Nessuna proposta in attesa.') end
    proposte[d.citizenid] = nil

    local c = AUREA.GetPlayerByCitizenId(p.creditore)
    if not c then return rispondi(false, 'Il creditore si è scollegato.') end

    if not accetta then
        TriggerClientEvent('aurea:ui:notifica', c.source, {
            tipo = 'errore', icona = '💸', titolo = 'Proposta rifiutata',
            testo = ('%s non ha accettato.'):format(d:NomeCompleto()), durata = 12000 })
        return rispondi(true, 'Hai rifiutato.')
    end

    if not c:Sottrai('contanti', p.capitale, 'prestito concesso') then
        return rispondi(false, 'Il creditore non ha più i contanti.')
    end
    d:Aggiungi('contanti', p.capitale, 'prestito ricevuto')

    local id = MySQL.insert.await([[
        INSERT INTO usura_prestiti
            (creditore, debitore, capitale, totale, rate, residuo, taeg, usurario, prossima_rata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { p.creditore, d.citizenid, p.capitale, p.totale, p.rate, p.totale,
          math.floor(p.taeg * 10000), p.giudizio == 'usurario' and 1 or 0,
          USU.Prestito.minutiPerRata })

    TriggerClientEvent('aurea:ui:notifica', c.source, {
        tipo = 'successo', icona = '💸', durata = 16000,
        titolo = 'Prestito erogato',
        testo = ('%s ti deve %s in %d rate.'):format(d:NomeCompleto(), U.Euro(p.totale), p.rate),
    })

    AUREA.Log('economia', p.giudizio == 'usurario' and 'avviso' or 'info', c,
        ('ha prestato %s a %s (TAEG %.1f%%, %s)')
            :format(U.Euro(p.capitale), d:NomeCompleto(), p.taeg * 100, p.giudizio))

    rispondi(true, ('Hai ricevuto %s. Devi restituire %s in %d rate, una ogni %d minuti.%s')
        :format(U.Euro(p.capitale), U.Euro(p.totale), p.rate, USU.Prestito.minutiPerRata,
                p.giudizio == 'usurario'
                    and '\n\nIl tasso è oltre la soglia d\'usura: per legge quegli interessi non li devi. Puoi denunciare con /denunciausura.'
                    or ''))
end)

-- ---------------------------------------------------------------------------
--  Pagamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('usu:paga', function(src, rispondi, id, tutto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local p = MySQL.single.await(
        'SELECT * FROM usura_prestiti WHERE id = ? AND debitore = ? AND stato = ?',
        { id, g.citizenid, 'attivo' })
    if not p then return rispondi(false, 'Prestito non trovato.') end

    local rata = tutto and p.residuo or math.min(p.residuo, math.ceil(p.totale / p.rate))
    if not g:SottraiOvunque(rata, 'rata di prestito') then
        return rispondi(false, ('Ti servono %s.'):format(U.Euro(rata)))
    end

    AUREA.Denaro.AggiungiOffline(p.creditore, 'contanti', rata, 'rata incassata')

    local residuo = p.residuo - rata
    local pagate = p.rate_pagate + 1

    if residuo <= 0 then
        MySQL.update.await('UPDATE usura_prestiti SET residuo = 0, rate_pagate = ?, stato = ?, chiuso_il = NOW() WHERE id = ?',
            { pagate, 'estinto', p.id })

        local c = AUREA.GetPlayerByCitizenId(p.creditore)
        if c then
            TriggerClientEvent('aurea:ui:notifica', c.source, {
                tipo = 'successo', icona = '💸', durata = 14000,
                titolo = 'Debito estinto',
                testo = ('%s ha saldato.'):format(g:NomeCompleto()) })
        end
        return rispondi(true, ('Saldato. Hai versato %s in tutto.'):format(U.Euro(p.totale)))
    end

    MySQL.update.await([[
        UPDATE usura_prestiti
        SET residuo = ?, rate_pagate = ?, rate_saltate = 0,
            prossima_rata = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE id = ?
    ]], { residuo, pagate, USU.Prestito.minutiPerRata, p.id })

    rispondi(true, ('Versati %s. Residuo %s.'):format(U.Euro(rata), U.Euro(residuo)))
end)

-- ---------------------------------------------------------------------------
--  Elenchi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('usu:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}, {}) end
    rispondi(prestitiDi(g.citizenid, false), prestitiDi(g.citizenid, true))
end)

-- ---------------------------------------------------------------------------
--  Le rate scadono da sole
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(45000)
    while true do
        Wait(60000)

        local scadute = MySQL.query.await([[
            SELECT p.*, CONCAT(d.nome, ' ', d.cognome) AS nome_debitore
            FROM usura_prestiti p
            LEFT JOIN personaggi d ON d.citizenid = p.debitore
            WHERE p.stato = 'attivo' AND p.prossima_rata <= NOW()
        ]]) or {}

        for _, p in ipairs(scadute) do
            local mora = math.floor(p.residuo * USU.Morosita.moraPerRata)
            local saltate = p.rate_saltate + 1

            MySQL.update.await([[
                UPDATE usura_prestiti
                SET residuo = residuo + ?, rate_saltate = ?,
                    prossima_rata = DATE_ADD(NOW(), INTERVAL ? MINUTE)
                WHERE id = ?
            ]], { mora, saltate, USU.Prestito.minutiPerRata, p.id })

            TriggerEvent('aurea:telefono:messaggioSistema', p.debitore, 'Avviso',
                ('Rata scaduta. Al residuo si aggiungono %s di mora.'):format(U.Euro(mora)))

            local d = AUREA.GetPlayerByCitizenId(p.debitore)
            if d then
                TriggerClientEvent('aurea:ui:notifica', d.source, {
                    tipo = 'errore', icona = '💸', durata = 18000,
                    titolo = 'Rata saltata',
                    testo = ('Il residuo sale di %s. Rate saltate: %d.'):format(U.Euro(mora), saltate),
                })
            end

            -- Il creditore riceve un avviso e un indirizzo. Quello che fa
            -- dopo lo fa lui: il modulo non manda nessuno da nessuna parte.
            local c = AUREA.GetPlayerByCitizenId(p.creditore)
            if c then
                local dove = d and 'in linea adesso' or 'non collegato'
                TriggerClientEvent('aurea:ui:notifica', c.source, {
                    tipo = 'avviso', icona = '💸', durata = 20000,
                    titolo = ('%s non ha pagato'):format(p.nome_debitore or 'Il debitore'),
                    testo = ('Rata %d saltata su %d. Residuo %s. È %s.')
                        :format(saltate, p.rate, U.Euro(p.residuo + mora), dove),
                })
            end

            if saltate >= USU.Morosita.rateInsolvenza then
                MySQL.update('UPDATE usura_prestiti SET stato = ? WHERE id = ?', { 'insolvente', p.id })

                -- Un'insolvenza che finisce così scalda l'organizzazione:
                -- è il momento in cui il credito diventa un problema per
                -- qualcuno di più grande del creditore.
                TriggerEvent('aurea:famiglie:calore', p.creditore, USU.Morosita.calorePerInsolvenza,
                    'credito inesigibile')

                if c then
                    TriggerClientEvent('aurea:ui:notifica', c.source, {
                        tipo = 'errore', icona = '💸', durata = 22000,
                        titolo = 'Credito inesigibile',
                        testo = ('%s non paga da %d rate. Il rapporto è chiuso: quello che vuoi recuperare, recuperalo tu.')
                            :format(p.nome_debitore or 'Il debitore', saltate),
                    })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Denuncia
-- ---------------------------------------------------------------------------
AUREA.Comando('denunciausura', 'utente', 'Denuncia un prestito a tasso usurario', {},
function(src, _, _, g)
    if not g then return end

    local righe = MySQL.query.await([[
        SELECT p.*, CONCAT(c.nome, ' ', c.cognome) AS nome_creditore
        FROM usura_prestiti p
        LEFT JOIN personaggi c ON c.citizenid = p.creditore
        WHERE p.debitore = ? AND p.usurario = 1 AND p.stato IN ('attivo','insolvente')
    ]], { g.citizenid }) or {}

    if #righe == 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '⚖', titolo = 'Nessun prestito usurario',
            testo = 'Non risultano a tuo carico prestiti oltre la soglia. Un tasso caro non è ancora usura.',
        })
    end

    local ristoro, quanti = 0, 0
    for _, p in ipairs(righe) do
        quanti = quanti + 1
        local pagato = p.totale - p.residuo
        ristoro = ristoro + math.floor(math.max(0, pagato) * USU.Denuncia.ristoro)

        MySQL.update.await('UPDATE usura_prestiti SET stato = ?, chiuso_il = NOW() WHERE id = ?',
            { 'denunciato', p.id })

        -- L'aggravante se il creditore è affiliato: lo chiede a ita_famiglie
        local ok, org = pcall(function()
            return exports.ita_famiglie:OrganizzazioneDi(p.creditore)
        end)
        local reato = (ok and org) and USU.Denuncia.reatoAggravato or USU.Denuncia.reatoBase

        TriggerEvent('aurea:giustizia:apriFascicolo', p.creditore, reato, 'denuncia della persona offesa',
            ('Prestito di %s da restituire %s in %d rate. TAEG %.1f%%, soglia %.1f%%.')
                :format(U.Euro(p.capitale), U.Euro(p.totale), p.rate,
                        (p.taeg or 0) / 100, USU.TassoSoglia() * 100))

        local c = AUREA.GetPlayerByCitizenId(p.creditore)
        if c then
            TriggerClientEvent('aurea:ui:notifica', c.source, {
                tipo = 'errore', icona = '⚖', durata = 24000,
                titolo = 'Denuncia per usura',
                testo = ('%s ti ha denunciato. Il credito è estinto e c\'è un fascicolo a tuo carico.')
                    :format(g:NomeCompleto()),
            })
        end
    end

    if ristoro > 0 then
        g:Aggiungi('banca', ristoro, 'fondo di solidarietà per le vittime dell\'usura')
        TriggerEvent('aurea:fisco:erogazione', 'fondo_usura', ristoro, g.citizenid)
    end

    exports.aurea_ui:NotificaEnte('carabinieri', {
        tipo = 'avviso', icona = '⚖', durata = 18000,
        titolo = 'Denuncia per usura',
        testo = ('%s ha denunciato %d prestiti usurari.'):format(g:NomeCompleto(), quanti),
    }, true)

    AUREA.Log('giustizia', 'info', g, ('ha denunciato %d prestiti usurari'):format(quanti))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '⚖', durata = 24000,
        titolo = 'Denuncia depositata',
        testo = ('%d contratti estinti: gli interessi non erano dovuti.%s\n\nAdesso però lo sanno anche loro.')
            :format(quanti, ristoro > 0 and ('\nFondo di solidarietà: %s.'):format(U.Euro(ristoro)) or ''),
    })
end)

print('[AUREA] usura: prestiti fra privati e tasso soglia attivi')
