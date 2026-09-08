--[[
    AUREA · Telefono — app di base (server)

    Sono le app che il telefono porta con sé. Tutte le altre le registrano
    le risorse che le riguardano, con lo stesso contratto che si usa qui:
    nessuna di queste ha un trattamento speciale, e se ne cancellassi una
    il telefono continuerebbe a funzionare senza.
]]

local U = AUREA.Util

local function quando(valore)
    return U.DataOraIT(math.floor((tonumber(valore) or 0) / 1000))
end

local function dataBreve(valore)
    if type(valore) == 'number' then return U.DataIT(math.floor(valore / 1000)) end
    local a, m, g = tostring(valore or ''):match('(%d%d%d%d)-(%d%d)-(%d%d)')
    return a and ('%s/%s/%s'):format(g, m, a) or '—'
end

--- La rubrica come mappa numero -> nome, per dare un volto ai messaggi.
local function rubricaDi(citizenid)
    local out = {}
    for _, c in ipairs(MySQL.query.await(
        'SELECT nome, numero FROM tel_contatti WHERE citizenid = ?', { citizenid }) or {}) do
        out[c.numero] = c.nome
    end
    return out
end

-- ===========================================================================
--  TELEFONO — chiamate e tastierino
-- ===========================================================================
Registro.Aggiungi({
    id = 'chiamate',
    nome = 'Telefono',
    icona = '📞',
    colore = TEL.Colori.telefono,
    ordine = 10,

    badge = function(g)
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM tel_chiamate
            WHERE destinatario = ? AND esito = 'persa' AND vista = 0
        ]], { g.telefono }) or 0
    end,

    schermata = function(g)
        MySQL.update('UPDATE tel_chiamate SET vista = 1 WHERE destinatario = ?', { g.telefono })

        local rubrica = rubricaDi(g.citizenid)
        local righe = MySQL.query.await([[
            SELECT mittente, destinatario, esito, secondi, momento
            FROM tel_chiamate
            WHERE mittente = ? OR destinatario = ?
            ORDER BY id DESC LIMIT 30
        ]], { g.telefono, g.telefono }) or {}

        local voci = {}
        for _, r in ipairs(righe) do
            local uscente = r.mittente == g.telefono
            local altro = uscente and r.destinatario or r.mittente

            voci[#voci + 1] = {
                icona = r.esito == 'persa' and (uscente and '↗' or '↙')
                    or (uscente and '↗' or '↙'),
                titolo = rubrica[altro] or altro,
                sottotitolo = ('%s · %s'):format(
                    r.esito == 'persa' and 'persa'
                        or (r.esito == 'rifiutata' and 'rifiutata'
                        or ('%d secondi'):format(r.secondi or 0)),
                    quando(r.momento)),
                tono = r.esito == 'persa' and 'rosso' or nil,
                azione = 'chiama',
                dati = { numero = altro },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📞', titolo = 'Nessuna chiamata', sottotitolo = 'Il registro è vuoto.', inerte = true }
        end

        return {
            tipo = 'lista',
            sottotitolo = ('Il tuo numero: %s'):format(g.telefono),
            barra = {
                { id = 'componi', etichetta = 'Componi', icona = '🔢' },
            },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        if azione == 'componi' then
            return { ok = true, dialogo = {
                titolo = 'Componi numero',
                campi = { { etichetta = 'Numero', tipo = 'text', segnaposto = '3401234567', obbligatorio = true } },
                azione = 'chiama', chiave = 'numero',
            } }
        end

        if azione == 'chiama' then
            local numero = tostring((dati or {}).numero or ''):gsub('%D', '')
            if #numero < 3 then return false, 'Numero non valido.' end
            return Chiamate.Avvia(g, numero)
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  MESSAGGI
-- ===========================================================================
Registro.Aggiungi({
    id = 'messaggi',
    nome = 'Messaggi',
    icona = '💬',
    colore = TEL.Colori.messaggi,
    ordine = 20,

    badge = function(g)
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM tel_messaggi WHERE destinatario = ? AND letto = 0', { g.telefono }) or 0
    end,

    schermata = function(g, argomenti)
        argomenti = argomenti or {}

        -- Una conversazione aperta
        if argomenti.numero then
            local numero = tostring(argomenti.numero):sub(1, 20)
            local rubrica = rubricaDi(g.citizenid)

            local righe = MySQL.query.await([[
                SELECT mittente, testo, momento FROM tel_messaggi
                WHERE (mittente = ? AND destinatario = ?) OR (mittente = ? AND destinatario = ?)
                ORDER BY momento ASC LIMIT 80
            ]], { g.telefono, numero, numero, g.telefono }) or {}

            MySQL.update('UPDATE tel_messaggi SET letto = 1 WHERE destinatario = ? AND mittente = ?',
                { g.telefono, numero })

            local bolle = {}
            for _, m in ipairs(righe) do
                bolle[#bolle + 1] = {
                    mio = m.mittente == g.telefono,
                    -- Un mittente che comincia per lettera è un servizio,
                    -- non una persona: verbali, fisco, ACI
                    sistema = m.mittente:match('^%a') ~= nil,
                    testo = m.testo,
                    quando = quando(m.momento),
                }
            end

            return {
                tipo = 'chat',
                titolo = rubrica[numero] or numero,
                sottotitolo = numero,
                numero = numero,
                bolle = bolle,
            }
        end

        -- L'elenco delle conversazioni
        local righe = MySQL.query.await([[
            SELECT interlocutore, MAX(momento) AS ultimo_momento,
                   SUBSTRING_INDEX(GROUP_CONCAT(testo ORDER BY momento DESC SEPARATOR '\n'), '\n', 1) AS ultimo,
                   SUM(CASE WHEN destinatario = ? AND letto = 0 THEN 1 ELSE 0 END) AS non_letti
            FROM (
                SELECT CASE WHEN mittente = ? THEN destinatario ELSE mittente END AS interlocutore,
                       testo, momento, destinatario, letto
                FROM tel_messaggi WHERE mittente = ? OR destinatario = ?
            ) AS conv
            GROUP BY interlocutore ORDER BY ultimo_momento DESC LIMIT 30
        ]], { g.telefono, g.telefono, g.telefono, g.telefono }) or {}

        local rubrica = rubricaDi(g.citizenid)
        local voci = {}

        for _, r in ipairs(righe) do
            local nonLetti = tonumber(r.non_letti) or 0
            voci[#voci + 1] = {
                icona = r.interlocutore:match('^%a') and '🏛' or '💬',
                titolo = rubrica[r.interlocutore] or r.interlocutore,
                sottotitolo = (r.ultimo or ''):sub(1, 64),
                valore = quando(r.ultimo_momento):sub(-5),
                badge = nonLetti > 0 and nonLetti or nil,
                apri = { numero = r.interlocutore },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '💬', titolo = 'Nessun messaggio', sottotitolo = 'Scrivi a qualcuno.', inerte = true }
        end

        return {
            tipo = 'lista',
            barra = { { id = 'nuovo', etichetta = 'Nuovo', icona = '✎' } },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        dati = dati or {}

        if azione == 'nuovo' then
            return { ok = true, dialogo = {
                titolo = 'Nuovo messaggio',
                campi = {
                    { etichetta = 'Numero', tipo = 'text', obbligatorio = true },
                    { etichetta = 'Messaggio', tipo = 'textarea', obbligatorio = true },
                },
                azione = 'invia', chiavi = { 'numero', 'testo' },
            } }
        end

        if azione == 'invia' then
            local numero = tostring(dati.numero or ''):gsub('%s+', ''):sub(1, 20)
            local testo = tostring(dati.testo or ''):sub(1, 300)
            if #numero < 3 or #testo < 1 then return false, 'Numero o testo mancante.' end

            MySQL.insert.await('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
                { g.telefono, numero, testo })

            local destinatario = AUREA.GetPlayerByTelefono(numero)
            if destinatario then
                TriggerClientEvent('tel:messaggioRicevuto', destinatario.source,
                    rubricaDi(destinatario.citizenid)[g.telefono] or g.telefono, testo)
            end

            return true, nil, true
        end

        return false, 'Azione sconosciuta.'
    end,
})

--- I moduli mandano messaggi di servizio: verbali, scadenze, cartelle.
AddEventHandler('aurea:telefono:messaggioSistema', function(citizenid, mittente, testo)
    local numero = MySQL.scalar.await('SELECT telefono FROM personaggi WHERE citizenid = ?', { citizenid })
    if not numero then return end

    MySQL.insert('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
        { tostring(mittente):sub(1, 15), numero, tostring(testo):sub(1, 400) })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('tel:messaggioRicevuto', g.source, tostring(mittente), tostring(testo):sub(1, 90))
    end
end)

-- ===========================================================================
--  RUBRICA
-- ===========================================================================
Registro.Aggiungi({
    id = 'rubrica',
    nome = 'Rubrica',
    icona = '📇',
    colore = TEL.Colori.rubrica,
    ordine = 30,

    schermata = function(g)
        local contatti = MySQL.query.await(
            'SELECT id, nome, numero FROM tel_contatti WHERE citizenid = ? ORDER BY nome ASC',
            { g.citizenid }) or {}

        local voci = {}
        for _, c in ipairs(contatti) do
            voci[#voci + 1] = {
                icona = (c.nome:sub(1, 1)):upper(),
                titolo = c.nome,
                sottotitolo = c.numero,
                azione = 'apri',
                dati = { id = c.id, nome = c.nome, numero = c.numero },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📇', titolo = 'Rubrica vuota',
                        sottotitolo = 'Tocca "Nuovo" per aggiungere un contatto.', inerte = true }
        end

        return {
            tipo = 'lista',
            barra = { { id = 'nuovo', etichetta = 'Nuovo', icona = '＋' } },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        dati = dati or {}

        if azione == 'nuovo' then
            return { ok = true, dialogo = {
                titolo = 'Nuovo contatto',
                campi = {
                    { etichetta = 'Nome', tipo = 'text', obbligatorio = true },
                    { etichetta = 'Numero', tipo = 'text', segnaposto = '3401234567', obbligatorio = true },
                },
                azione = 'salva', chiavi = { 'nome', 'numero' },
            } }
        end

        if azione == 'salva' then
            local nome = tostring(dati.nome or ''):sub(1, 40)
            local numero = tostring(dati.numero or ''):gsub('%D', ''):sub(1, 15)
            if #nome < 1 or #numero < 6 then return false, 'Nome o numero non validi.' end

            MySQL.insert.await('INSERT INTO tel_contatti (citizenid, nome, numero) VALUES (?, ?, ?)',
                { g.citizenid, nome, numero })
            return true, ('%s salvato.'):format(nome), true
        end

        if azione == 'apri' then
            return { ok = true, scelta = {
                titolo = dati.nome or 'Contatto',
                voci = {
                    { id = 'chiama', icona = '📞', titolo = 'Chiama', dati = dati },
                    { id = 'scrivi', icona = '💬', titolo = 'Scrivi un messaggio', dati = dati },
                    { id = 'elimina', icona = '🗑', titolo = 'Elimina dalla rubrica', dati = dati },
                },
            } }
        end

        if azione == 'chiama' then
            return Chiamate.Avvia(g, tostring(dati.numero or ''))
        end

        if azione == 'scrivi' then
            return { ok = true, vaiA = { app = 'messaggi', argomenti = { numero = dati.numero } } }
        end

        if azione == 'elimina' then
            MySQL.update('DELETE FROM tel_contatti WHERE id = ? AND citizenid = ?',
                { tonumber(dati.id) or 0, g.citizenid })
            return true, 'Contatto eliminato.', true
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  IDENTITÀ DIGITALE
-- ===========================================================================
Registro.Aggiungi({
    id = 'identita',
    nome = 'Identità',
    icona = '🪪',
    colore = TEL.Colori.identita,
    ordine = 40,

    schermata = function(g)
        local voci = {}

        local ok, patente = pcall(function()
            return exports.ita_codicestrada:PatenteGet(g.citizenid)
        end)
        if ok and patente then
            voci[#voci + 1] = {
                icona = '🚗', titolo = 'Patente di guida',
                sottotitolo = ('N. %s · categorie %s · scade il %s'):format(
                    patente.numero, patente.categorie ~= '' and patente.categorie or '—',
                    dataBreve(patente.scadenza)),
                valore = ('%d punti'):format(patente.punti),
                tono = patente.punti <= 5 and 'rosso' or (patente.punti <= 10 and 'giallo' or nil),
                inerte = true,
            }
        end

        for _, v in ipairs(MySQL.query.await(
            'SELECT targa, modello FROM veicoli WHERE proprietario = ? LIMIT 8', { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = '🚙', titolo = v.targa,
                                sottotitolo = ('Veicolo intestato · %s'):format(v.modello), inerte = true }
        end

        for _, i in ipairs(MySQL.query.await(
            'SELECT ragione_sociale, piva FROM imprese WHERE titolare = ? AND attiva = 1', { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = '🏢', titolo = i.ragione_sociale,
                                sottotitolo = ('Partita IVA %s'):format(i.piva), inerte = true }
        end

        for _, i in ipairs(MySQL.query.await(
            'SELECT nome, indirizzo FROM immobili WHERE proprietario = ?', { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = '🏠', titolo = i.nome, sottotitolo = i.indirizzo, inerte = true }
        end

        for _, t in ipairs(MySQL.query.await(
            'SELECT titolo, abilitato FROM titoli WHERE citizenid = ?', { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = t.abilitato == 1 and '🎖' or '🎓', titolo = t.titolo,
                                sottotitolo = t.abilitato == 1 and 'Abilitato all\'esercizio'
                                    or 'Titolo conseguito', inerte = true }
        end

        for _, l in ipairs(MySQL.query.await(
            'SELECT tipo, scadenza FROM licenze WHERE citizenid = ? AND revocata = 0', { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = '📜', titolo = ('Licenza di %s'):format(l.tipo),
                                sottotitolo = ('Valida fino al %s'):format(dataBreve(l.scadenza)), inerte = true }
        end

        if #voci == 0 then
            voci[1] = { icona = '🪪', titolo = 'Nessun documento collegato', inerte = true }
        end

        return {
            tipo = 'tessera',
            tessera = {
                etichetta = 'Identità digitale',
                nome = g:NomeCompleto(),
                righe = {
                    { chiave = 'Codice fiscale', valore = g.cf },
                    { chiave = 'Nato il', valore = dataBreve(g.dataNascita) },
                    { chiave = 'Luogo', valore = g.luogoNascita },
                    { chiave = 'Codice cittadino', valore = g.citizenid },
                },
            },
            voci = voci,
        }
    end,
})

-- ===========================================================================
--  BANCA
-- ===========================================================================
Registro.Aggiungi({
    id = 'banca',
    nome = 'Banca',
    icona = '🏦',
    colore = TEL.Colori.banca,
    ordine = 50,

    schermata = function(g)
        local iban = select(2, pcall(function() return exports.aurea_banca:IBANDi(g.citizenid) end))
        local movimenti = iban and MySQL.query.await(
            'SELECT causale, importo, momento FROM movimenti WHERE iban = ? ORDER BY id DESC LIMIT 25',
            { iban }) or {}

        local voci = {}
        for _, m in ipairs(movimenti) do
            voci[#voci + 1] = {
                icona = m.importo >= 0 and '＋' or '－',
                titolo = m.causale,
                sottotitolo = quando(m.momento),
                valore = ('%s%s'):format(m.importo >= 0 and '+' or '', U.Euro(m.importo)),
                tono = m.importo >= 0 and 'verde' or 'rosso',
                inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '🏦', titolo = 'Nessun movimento', inerte = true }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Saldo disponibile',
            valore = U.Euro(g.denaro.banca),
            nota = iban or 'Nessun conto aperto',
            barra = { { id = 'bonifico', etichetta = 'Bonifico', icona = '➤' } },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        if azione == 'bonifico' then
            return { ok = true, dialogo = {
                titolo = 'Bonifico',
                campi = {
                    { etichetta = 'IBAN del beneficiario', tipo = 'text', obbligatorio = true },
                    { etichetta = 'Importo in euro', tipo = 'number', min = 1, obbligatorio = true },
                    { etichetta = 'Causale', tipo = 'text', obbligatorio = true },
                },
                azione = 'esegui', chiavi = { 'iban', 'importo', 'causale' },
            } }
        end

        if azione == 'esegui' then
            dati = dati or {}
            local ok, esito, messaggio = pcall(function()
                return exports.aurea_banca:Bonifico(g.citizenid,
                    tostring(dati.iban or ''):upper():gsub('%s+', ''),
                    U.ACentesimi(tonumber(dati.importo) or 0),
                    tostring(dati.causale or 'bonifico'):sub(1, 80))
            end)

            if not ok then return false, 'Il servizio della banca non risponde.' end
            return esito == true, messaggio or (esito and 'Bonifico eseguito.' or 'Bonifico rifiutato.'), true
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  CASSETTO FISCALE
-- ===========================================================================
Registro.Aggiungi({
    id = 'fisco',
    nome = 'Fisco',
    icona = '🧾',
    colore = TEL.Colori.fisco,
    ordine = 60,

    badge = function(g)
        local ok, verbali = pcall(function() return exports.ita_codicestrada:VerbaliAperti(g.citizenid) end)
        local ok2, tributi = pcall(function() return exports.ita_fisco:DebitoFiscale(g.citizenid) end)
        return (ok and #verbali or 0) + (ok2 and #tributi or 0)
    end,

    schermata = function(g)
        local voci, totale = {}, 0

        local ok, verbali = pcall(function() return exports.ita_codicestrada:VerbaliAperti(g.citizenid) end)
        for _, m in ipairs(ok and verbali or {}) do
            totale = totale + (m.dovuto or 0)
            voci[#voci + 1] = {
                icona = '📄',
                titolo = ('%s — %s'):format(m.articolo, m.descrizione),
                sottotitolo = ('%s · %s'):format(m.luogo or 'luogo non indicato', m.emessa),
                valore = U.Euro(m.dovuto),
                tono = 'rosso',
                inerte = true,
            }
        end

        local ok2, tributi = pcall(function() return exports.ita_fisco:DebitoFiscale(g.citizenid) end)
        for _, t in ipairs(ok2 and tributi or {}) do
            totale = totale + (t.dovuto or 0)
            voci[#voci + 1] = {
                icona = t.stato == 'cartella' and '📮' or '🧾',
                titolo = ('%s — %s'):format(tostring(t.tipo):upper(), t.periodo),
                sottotitolo = ('Scadenza %s%s'):format(t.scadenzaIT,
                    (t.mora or 0) > 0 and (' · mora ' .. U.Euro(t.mora)) or ''),
                valore = U.Euro(t.dovuto),
                tono = t.stato == 'cartella' and 'rosso' or 'giallo',
                inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '✅', titolo = 'Nessuna pendenza',
                        sottotitolo = 'Sei in regola con il fisco e con i verbali.', inerte = true }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Totale dovuto',
            valore = U.Euro(totale),
            nota = totale > 0 and 'Si paga in Comune o all\'Agenzia delle Entrate'
                or 'Nessun importo a debito',
            voci = voci,
        }
    end,
})

-- ===========================================================================
--  ANNUNCI
-- ===========================================================================
Registro.Aggiungi({
    id = 'annunci',
    nome = 'Annunci',
    icona = '📢',
    colore = TEL.Colori.annunci,
    ordine = 70,

    schermata = function(g)
        local righe = MySQL.query.await([[
            SELECT titolo, testo, prezzo, numero, categoria, momento
            FROM annunci WHERE momento > DATE_SUB(NOW(), INTERVAL 2 DAY)
            ORDER BY momento DESC LIMIT 40
        ]]) or {}

        local voci = {}
        for _, a in ipairs(righe) do
            voci[#voci + 1] = {
                icona = '📢',
                titolo = a.titolo,
                sottotitolo = ('%s\n%s · %s'):format(a.testo, a.categoria, quando(a.momento)),
                valore = (a.prezzo or 0) > 0 and U.Euro(a.prezzo) or nil,
                azione = 'contatta',
                dati = { numero = a.numero, titolo = a.titolo },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📢', titolo = 'Nessun annuncio', sottotitolo = 'La bacheca è vuota.', inerte = true }
        end

        return {
            tipo = 'lista',
            barra = { { id = 'pubblica', etichetta = 'Pubblica', icona = '＋' } },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        dati = dati or {}

        if azione == 'pubblica' then
            return { ok = true, dialogo = {
                titolo = 'Pubblica un annuncio',
                campi = {
                    { etichetta = 'Titolo', tipo = 'text', obbligatorio = true },
                    { etichetta = 'Testo', tipo = 'textarea', obbligatorio = true },
                    { etichetta = 'Prezzo in euro (0 se non si applica)', tipo = 'number', valore = 0 },
                    { etichetta = 'Categoria', tipo = 'select',
                      opzioni = { 'generale', 'lavoro', 'veicoli', 'immobili', 'servizi', 'acquisti' } },
                },
                azione = 'salva', chiavi = { 'titolo', 'testo', 'prezzo', 'categoria' },
            } }
        end

        if azione == 'salva' then
            local titolo = tostring(dati.titolo or ''):sub(1, 80)
            local testo = tostring(dati.testo or ''):sub(1, 400)
            if #titolo < 3 or #testo < 3 then return false, 'Titolo o testo troppo corti.' end

            local ultimo = MySQL.scalar.await(
                'SELECT UNIX_TIMESTAMP(momento) FROM annunci WHERE citizenid = ? ORDER BY id DESC LIMIT 1',
                { g.citizenid })
            if ultimo and (os.time() - ultimo) < 120 then
                return false, 'Puoi pubblicare un annuncio ogni due minuti.'
            end

            MySQL.insert.await([[
                INSERT INTO annunci (citizenid, categoria, titolo, testo, prezzo, numero)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], {
                g.citizenid, tostring(dati.categoria or 'generale'):sub(1, 30), titolo, testo,
                U.ACentesimi(tonumber(tostring(dati.prezzo or '0'):gsub(',', '.')) or 0), g.telefono,
            })

            return true, 'Annuncio pubblicato.', true
        end

        if azione == 'contatta' then
            return { ok = true, vaiA = { app = 'messaggi', argomenti = { numero = dati.numero } } }
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  EMERGENZE
-- ===========================================================================
Registro.Aggiungi({
    id = 'emergenze',
    nome = 'Emergenze',
    icona = '🆘',
    colore = TEL.Colori.emergenze,
    ordine = 80,

    schermata = function()
        local voci = {}
        for _, e in ipairs(TEL.Emergenze) do
            voci[#voci + 1] = {
                titolo = e.numero,
                sottotitolo = e.nome,
                tono = e.principale and 'rosso' or nil,
                azione = 'chiama',
                dati = { numero = e.numero },
            }
        end

        return { tipo = 'griglia', voci = voci, nota = TEL.AvvisoEmergenze }
    end,

    azione = function(g, azione, dati)
        if azione ~= 'chiama' then return false end

        local e = TEL.GetEmergenza(tostring((dati or {}).numero or ''))
        if not e then return false, 'Numero non attivo.' end

        return { ok = true, chiudi = true, eventoClient = { nome = 'nue:apriChiamata', dati = e.ente } }
    end,
})

-- ===========================================================================
--  METEO
-- ===========================================================================
Registro.Aggiungi({
    id = 'meteo',
    nome = 'Meteo',
    icona = '🌤',
    colore = TEL.Colori.meteo,
    ordine = 90,

    schermata = function()
        local stato = GlobalState.meteo
        local ora = GlobalState.oraGioco

        local voci = {
            { icona = '🕐', titolo = 'Ora locale',
              valore = type(ora) == 'table' and ('%02d:%02d'):format(ora.ore or 0, ora.minuti or 0) or '—',
              inerte = true },
            { icona = '🌡', titolo = 'Condizione',
              valore = type(stato) == 'table' and (stato.etichetta or stato.id or '—') or '—',
              inerte = true },
        }

        if GlobalState.siccita then
            voci[#voci + 1] = { icona = '🔥', titolo = 'Allerta incendi',
                                sottotitolo = 'Periodo di siccità: rischio elevato di incendi boschivi.',
                                tono = 'rosso', inerte = true }
        end

        return {
            tipo = 'lista',
            sottotitolo = 'Dati dal servizio meteorologico',
            voci = voci,
        }
    end,
})

-- ===========================================================================
--  NOTE
-- ===========================================================================
Registro.Aggiungi({
    id = 'note',
    nome = 'Note',
    icona = '📝',
    colore = TEL.Colori.note,
    ordine = 200,

    schermata = function(g, argomenti)
        local note = g:Get('note') or {}
        argomenti = argomenti or {}

        if argomenti.indice then
            local n = note[tonumber(argomenti.indice)]
            if not n then return { tipo = 'testo', titolo = 'Nota', corpo = 'Non esiste più.' } end
            return {
                tipo = 'testo', titolo = n.titolo, corpo = n.testo,
                barra = { { id = 'elimina', etichetta = 'Elimina', icona = '🗑',
                            dati = { indice = argomenti.indice } } },
            }
        end

        local voci = {}
        for i, n in ipairs(note) do
            voci[#voci + 1] = {
                icona = '📝', titolo = n.titolo,
                sottotitolo = (n.testo or ''):sub(1, 70),
                apri = { indice = i },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📝', titolo = 'Nessuna nota', sottotitolo = 'Le note restano sul telefono.', inerte = true }
        end

        return {
            tipo = 'lista',
            barra = { { id = 'nuova', etichetta = 'Nuova', icona = '＋' } },
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        dati = dati or {}
        local note = g:Get('note') or {}

        if azione == 'nuova' then
            return { ok = true, dialogo = {
                titolo = 'Nuova nota',
                campi = {
                    { etichetta = 'Titolo', tipo = 'text', obbligatorio = true },
                    { etichetta = 'Testo', tipo = 'textarea', obbligatorio = true },
                },
                azione = 'salva', chiavi = { 'titolo', 'testo' },
            } }
        end

        if azione == 'salva' then
            if #note >= TEL.Note.massime then return false, 'Hai raggiunto il numero massimo di note.' end
            table.insert(note, 1, {
                titolo = tostring(dati.titolo or 'Nota'):sub(1, 48),
                testo = tostring(dati.testo or ''):sub(1, TEL.Note.caratteri),
            })
            g:Set('note', note, false)
            return true, 'Nota salvata.', true
        end

        if azione == 'elimina' then
            table.remove(note, tonumber(dati.indice) or 0)
            g:Set('note', note, false)
            return { ok = true, messaggio = 'Nota eliminata.', vaiA = { app = 'note' } }
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  IMPOSTAZIONI
-- ===========================================================================
Registro.Aggiungi({
    id = 'impostazioni',
    nome = 'Impostazioni',
    icona = '⚙',
    colore = TEL.Colori.impostazioni,
    ordine = 900,

    schermata = function(g)
        local i = Registro.Impostazioni(g)

        local voci = {
            { icona = '🎨', titolo = 'Tema',
              valore = (i.tema or TEL.Aspetto.temaPredefinito) == 'chiaro' and 'Chiaro' or 'Scuro',
              azione = 'tema' },
            { icona = '🖼', titolo = 'Sfondo',
              valore = TEL.GetSfondo(i.sfondo or TEL.Aspetto.sfondoPredefinito).nome,
              azione = 'sfondo' },
            { icona = '🔕', titolo = 'Numero nascosto nelle chiamate',
              valore = i.anonimo and 'Sì' or 'No',
              azione = 'anonimo' },
            { icona = '📵', titolo = 'Non disturbare',
              valore = i.nonDisturbare and 'Attivo' or 'Spento',
              azione = 'nonDisturbare' },
        }

        voci[#voci + 1] = { icona = '📱', titolo = ('Numero: %s'):format(g.telefono),
                            sottotitolo = ('Codice cittadino %s'):format(g.citizenid), inerte = true }

        return { tipo = 'lista', voci = voci }
    end,

    azione = function(g, azione)
        local i = Registro.Impostazioni(g)

        if azione == 'tema' then
            Registro.SalvaImpostazione(g, 'tema',
                (i.tema or TEL.Aspetto.temaPredefinito) == 'chiaro' and 'scuro' or 'chiaro')
            return { ok = true, riapri = true }
        end

        if azione == 'sfondo' then
            local voci = {}
            for _, s in ipairs(TEL.Aspetto.sfondi) do
                voci[#voci + 1] = { id = 'sfondo:' .. s.id, icona = '🖼', titolo = s.nome }
            end
            return { ok = true, scelta = { titolo = 'Sfondo', voci = voci } }
        end

        local id = tostring(azione):match('^sfondo:(.+)$')
        if id then
            Registro.SalvaImpostazione(g, 'sfondo', id)
            return { ok = true, riapri = true }
        end

        if azione == 'anonimo' then
            Registro.SalvaImpostazione(g, 'anonimo', not i.anonimo)
            return true, nil, true
        end

        if azione == 'nonDisturbare' then
            Registro.SalvaImpostazione(g, 'nonDisturbare', not i.nonDisturbare)
            return true, nil, true
        end

        return false, 'Azione sconosciuta.'
    end,
})

-- ===========================================================================
--  Comando rapido, per chi preferisce la chat
-- ===========================================================================
AUREA.Comando('sms', 'utente', 'Invia un SMS rapido', {
    { name = 'numero', help = 'Numero del destinatario' },
    { name = 'testo', help = 'Messaggio' },
}, function(src, args, _, g)
    if not g then return end

    local numero = (args[1] or ''):gsub('%D', '')
    local testo = table.concat(args, ' ', 2)

    if #numero < 6 or #testo < 1 then
        return TriggerClientEvent('aurea:ui:notifica', src,
            { tipo = 'errore', titolo = 'Uso', testo = '/sms <numero> <messaggio>' })
    end

    MySQL.insert('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
        { g.telefono, numero, testo:sub(1, 300) })

    local destinatario = AUREA.GetPlayerByTelefono(numero)
    if destinatario then
        TriggerClientEvent('tel:messaggioRicevuto', destinatario.source, g.telefono, testo)
    end

    TriggerClientEvent('aurea:ui:notifica', src,
        { tipo = 'successo', icona = '💬', titolo = 'Messaggio inviato', testo = numero })
end)
