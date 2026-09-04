--[[
    AUREA · Telefono (server)
]]

local U = AUREA.Util

--- Formatta una data DB (millisecondi) in formato italiano.
local function quando(valore)
    return U.DataOraIT(math.floor((valore or 0) / 1000))
end

local function dataBreve(valore)
    if type(valore) == 'number' then return U.DataIT(math.floor(valore / 1000)) end
    local a, m, g = tostring(valore or ''):match('(%d%d%d%d)-(%d%d)-(%d%d)')
    return a and ('%s/%s/%s'):format(g, m, a) or '—'
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
local function conteggioBadge(g)
    local nonLetti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM tel_messaggi WHERE destinatario = ? AND letto = 0', { g.telefono }) or 0

    local verbali = exports.ita_codicestrada:VerbaliAperti(g.citizenid)
    local tributi = exports.ita_fisco:DebitoFiscale(g.citizenid)

    return { messaggi = nonLetti, fisco = #verbali + #tributi }
end

AUREA.Callback.Registra('tel:apertura', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    -- Documenti mostrati nella sezione identità digitale
    local documenti = {}

    local patente = exports.ita_codicestrada:PatenteGet(g.citizenid)
    if patente then
        documenti[#documenti + 1] = {
            icona = '🚗', titolo = 'Patente di guida',
            dettaglio = ('N. %s · categorie %s · scadenza %s'):format(
                patente.numero, patente.categorie ~= '' and patente.categorie or '—', dataBreve(patente.scadenza)),
            valore = ('%d punti'):format(patente.punti),
        }
    end

    local veicoli = MySQL.query.await('SELECT targa, modello FROM veicoli WHERE citizenid = ? LIMIT 6', { g.citizenid }) or {}
    for _, v in ipairs(veicoli) do
        documenti[#documenti + 1] = { icona = '🚙', titolo = v.targa, dettaglio = ('Veicolo intestato · %s'):format(v.modello) }
    end

    local imprese = MySQL.query.await('SELECT ragione_sociale, piva FROM imprese WHERE titolare = ? AND attiva = 1', { g.citizenid }) or {}
    for _, i in ipairs(imprese) do
        documenti[#documenti + 1] = { icona = '🏢', titolo = i.ragione_sociale, dettaglio = ('P.IVA %s'):format(i.piva) }
    end

    local immobili = MySQL.query.await('SELECT nome, indirizzo FROM immobili WHERE proprietario = ?', { g.citizenid }) or {}
    for _, i in ipairs(immobili) do
        documenti[#documenti + 1] = { icona = '🏠', titolo = i.nome, dettaglio = i.indirizzo }
    end

    rispondi({
        pg = {
            nome = g.nome, cognome = g.cognome, cf = g.cf,
            telefono = g.telefono, citizenid = g.citizenid,
            dataNascita = dataBreve(g.dataNascita), luogoNascita = g.luogoNascita,
            documenti = documenti,
        },
        badge = conteggioBadge(g),
    })
end)

-- ---------------------------------------------------------------------------
--  Rubrica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:contatti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({ contatti = {} }) end

    local contatti = MySQL.query.await(
        'SELECT id, nome, numero FROM tel_contatti WHERE citizenid = ? ORDER BY nome ASC', { g.citizenid }) or {}
    rispondi({ contatti = contatti })
end)

AUREA.Callback.Registra('tel:salvaContatto', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return rispondi({ ok = false }) end

    local nome = tostring(dati.nome or ''):sub(1, 40)
    local numero = tostring(dati.numero or ''):gsub('%D', ''):sub(1, 15)
    if #nome < 1 or #numero < 6 then return rispondi({ ok = false }) end

    MySQL.insert.await('INSERT INTO tel_contatti (citizenid, nome, numero) VALUES (?, ?, ?)',
        { g.citizenid, nome, numero })
    rispondi({ ok = true })
end)

-- ---------------------------------------------------------------------------
--  Messaggi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:conversazioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({ conversazioni = {} }) end

    local righe = MySQL.query.await([[
        SELECT interlocutore, MAX(momento) AS ultimo_momento,
               SUBSTRING_INDEX(GROUP_CONCAT(testo ORDER BY momento DESC SEPARATOR '\n'), '\n', 1) AS ultimo,
               SUM(CASE WHEN destinatario = ? AND letto = 0 THEN 1 ELSE 0 END) AS non_letti
        FROM (
            SELECT CASE WHEN mittente = ? THEN destinatario ELSE mittente END AS interlocutore,
                   testo, momento, destinatario, letto
            FROM tel_messaggi
            WHERE mittente = ? OR destinatario = ?
        ) AS conv
        GROUP BY interlocutore
        ORDER BY ultimo_momento DESC
        LIMIT 30
    ]], { g.telefono, g.telefono, g.telefono, g.telefono }) or {}

    -- si abbina il nome dalla rubrica
    local rubrica = {}
    for _, c in ipairs(MySQL.query.await('SELECT nome, numero FROM tel_contatti WHERE citizenid = ?', { g.citizenid }) or {}) do
        rubrica[c.numero] = c.nome
    end

    local out = {}
    for _, r in ipairs(righe) do
        out[#out + 1] = {
            numero = r.interlocutore,
            nome = rubrica[r.interlocutore],
            ultimo = (r.ultimo or ''):sub(1, 60),
            nonLetti = tonumber(r.non_letti) or 0,
        }
    end
    rispondi({ conversazioni = out })
end)

AUREA.Callback.Registra('tel:messaggi', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return rispondi({ messaggi = {} }) end

    local numero = tostring(dati.numero or ''):sub(1, 20)

    local righe = MySQL.query.await([[
        SELECT mittente, destinatario, testo, momento FROM tel_messaggi
        WHERE (mittente = ? AND destinatario = ?) OR (mittente = ? AND destinatario = ?)
        ORDER BY momento ASC LIMIT 80
    ]], { g.telefono, numero, numero, g.telefono }) or {}

    MySQL.update('UPDATE tel_messaggi SET letto = 1 WHERE destinatario = ? AND mittente = ?', { g.telefono, numero })

    local out = {}
    for _, m in ipairs(righe) do
        out[#out + 1] = {
            mio = m.mittente == g.telefono,
            sistema = m.mittente:match('^%a') ~= nil,
            testo = m.testo,
            quando = quando(m.momento),
        }
    end

    TriggerClientEvent('tel:badge', src, conteggioBadge(g))
    rispondi({ messaggi = out })
end)

AUREA.Callback.Registra('tel:inviaMessaggio', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return rispondi({ ok = false }) end

    local numero = tostring(dati.numero or ''):gsub('%s+', ''):sub(1, 20)
    local testo = tostring(dati.testo or ''):sub(1, 300)
    if #numero < 3 or #testo < 1 then return rispondi({ ok = false }) end

    MySQL.insert.await('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
        { g.telefono, numero, testo })

    local destinatario = AUREA.GetPlayerByTelefono(numero)
    if destinatario then
        TriggerClientEvent('tel:messaggioRicevuto', destinatario.source, g.telefono, testo)
        TriggerClientEvent('tel:badge', destinatario.source, conteggioBadge(destinatario))
    end

    rispondi({ ok = true })
end)

--- Messaggi di servizio inviati dai moduli (verbali, fisco, ACI, imprese).
AddEventHandler('aurea:telefono:messaggioSistema', function(citizenid, mittente, testo)
    local numero = MySQL.scalar.await('SELECT telefono FROM personaggi WHERE citizenid = ?', { citizenid })
    if not numero then return end

    MySQL.insert('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
        { tostring(mittente):sub(1, 15), numero, tostring(testo):sub(1, 400) })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('tel:badge', g.source, conteggioBadge(g))
    end
end)

-- ---------------------------------------------------------------------------
--  Banca e fisco
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:banca', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local iban = exports.aurea_banca:IBANDi(g.citizenid)
    local movimenti = MySQL.query.await(
        'SELECT causale, importo, momento FROM movimenti WHERE iban = ? ORDER BY id DESC LIMIT 20', { iban }) or {}

    for _, m in ipairs(movimenti) do m.quando = quando(m.momento) end

    rispondi({ saldo = g.denaro.banca, iban = iban, movimenti = movimenti })
end)

AUREA.Callback.Registra('tel:fisco', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({ voci = {} }) end

    local voci = {}

    for _, m in ipairs(exports.ita_codicestrada:VerbaliAperti(g.citizenid)) do
        voci[#voci + 1] = {
            icona = '📄', titolo = ('%s — %s'):format(m.articolo, m.descrizione),
            dettaglio = ('%s · %s'):format(m.luogo or 'n.d.', m.emessa),
            importo = m.dovuto,
        }
    end

    local tributi = exports.ita_fisco:DebitoFiscale(g.citizenid)
    for _, t in ipairs(tributi) do
        voci[#voci + 1] = {
            icona = t.stato == 'cartella' and '📮' or '🧾',
            titolo = ('%s — %s'):format(t.tipo:upper(), t.periodo),
            dettaglio = ('Scadenza %s%s'):format(t.scadenzaIT, t.mora > 0 and (' · mora ' .. U.Euro(t.mora)) or ''),
            importo = t.dovuto,
        }
    end

    rispondi({ voci = voci })
end)

-- ---------------------------------------------------------------------------
--  Annunci
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:annunci', function(src, rispondi)
    local righe = MySQL.query.await([[
        SELECT titolo, testo, prezzo, numero, categoria, momento
        FROM annunci WHERE momento > DATE_SUB(NOW(), INTERVAL 2 DAY)
        ORDER BY momento DESC LIMIT 40
    ]]) or {}

    for _, a in ipairs(righe) do a.quando = quando(a.momento) end
    rispondi({ annunci = righe })
end)

AUREA.Callback.Registra('tel:pubblicaAnnuncio', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return rispondi({ ok = false }) end

    local titolo = tostring(dati.titolo or ''):sub(1, 80)
    local testo = tostring(dati.testo or ''):sub(1, 400)
    if #titolo < 3 or #testo < 3 then return rispondi({ ok = false }) end

    -- anti-spam: un annuncio ogni due minuti
    local ultimo = MySQL.scalar.await(
        'SELECT UNIX_TIMESTAMP(momento) FROM annunci WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { g.citizenid })
    if ultimo and (os.time() - ultimo) < 120 then
        return rispondi({ ok = false, errore = 'Puoi pubblicare un annuncio ogni due minuti.' })
    end

    MySQL.insert.await([[
        INSERT INTO annunci (citizenid, categoria, titolo, testo, prezzo, numero)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        g.citizenid, tostring(dati.categoria or 'generale'):sub(1, 30), titolo, testo,
        U.ACentesimi(tonumber(tostring(dati.prezzo or '0'):gsub(',', '.')) or 0), g.telefono,
    })

    rispondi({ ok = true })
end)

-- ---------------------------------------------------------------------------
--  Comando rapido
-- ---------------------------------------------------------------------------
AUREA.Comando('sms', 'utente', 'Invia un SMS rapido', {
    { name = 'numero', help = 'Numero del destinatario' },
    { name = 'testo', help = 'Messaggio' },
}, function(src, args, _, g)
    if not g then return end
    local numero = (args[1] or ''):gsub('%D', '')
    local testo = table.concat(args, ' ', 2)
    if #numero < 6 or #testo < 1 then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/sms <numero> <messaggio>' })
    end

    MySQL.insert('INSERT INTO tel_messaggi (mittente, destinatario, testo) VALUES (?, ?, ?)',
        { g.telefono, numero, testo:sub(1, 300) })

    local destinatario = AUREA.GetPlayerByTelefono(numero)
    if destinatario then
        TriggerClientEvent('tel:messaggioRicevuto', destinatario.source, g.telefono, testo)
    end

    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', icona = '💬', titolo = 'Messaggio inviato', testo = numero })
end)
