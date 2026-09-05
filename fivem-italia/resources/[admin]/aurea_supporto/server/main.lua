--[[
    AUREA · Supporto (server)
]]

local U = AUREA.Util

AUREA.Callback.Registra('sup:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT id, categoria, titolo, stato, presa_da, aperto_il
        FROM ticket WHERE citizenid = ? ORDER BY id DESC LIMIT 10
    ]], { g.citizenid }) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.aperto_il or 0) / 1000))
    end

    rispondi({ ticket = righe, categorie = SUP.Categorie })
end)

AUREA.Callback.Registra('sup:apri', function(src, rispondi, categoria, titolo, testo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not SUP.GetCategoria(categoria) then return rispondi(false, 'Categoria non prevista.') end

    local aperti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM ticket WHERE citizenid = ? AND stato != \'chiuso\'',
        { g.citizenid }) or 0
    if aperti >= SUP.Regole.apertiPerPersona then
        return rispondi(false, 'Hai già un ticket aperto. Aspetta che venga chiuso.')
    end

    titolo = tostring(titolo or ''):sub(1, 90)
    testo = tostring(testo or ''):sub(1, SUP.Regole.lunghezzaMessaggio)
    if #titolo < 5 or #testo < 20 then
        return rispondi(false, 'Descrivi meglio il problema: senza dettagli nessuno può aiutarti.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))

    local id = MySQL.insert.await([[
        INSERT INTO ticket (citizenid, nome, categoria, titolo, stato, posizione)
        VALUES (?, ?, ?, ?, 'aperto', ?)
    ]], { g.citizenid, g:NomeCompleto(), categoria, titolo,
          json.encode({ x = coord.x, y = coord.y, z = coord.z }) })

    MySQL.insert.await(
        'INSERT INTO ticket_messaggi (ticket_id, autore, staff, testo) VALUES (?, ?, 0, ?)',
        { id, g:NomeCompleto(), testo })

    local c = SUP.GetCategoria(categoria)
    for altroSrc in pairs(AUREA.Giocatori) do
        if AUREA.HaGruppo(altroSrc, SUP.Regole.gruppoStaff) then
            TriggerClientEvent('aurea:ui:notifica', altroSrc, {
                tipo = c.priorita <= 1 and 'errore' or 'avviso',
                icona = c.icona, durata = 15000,
                titolo = ('Ticket #%d — %s'):format(id, c.nome),
                testo = ('%s: %s'):format(g:NomeCompleto(), titolo),
            })
        end
    end

    AUREA.Log('staff', 'info', g, ('ticket #%d aperto: %s'):format(id, titolo))
    rispondi(true, ('Ticket #%d aperto. Qualcuno lo prenderà in carico.'):format(id))
end)

AUREA.Callback.Registra('sup:leggi', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local t = MySQL.single.await('SELECT * FROM ticket WHERE id = ?', { id })
    if not t then return rispondi(nil, 'Ticket inesistente.') end

    local staff = AUREA.HaGruppo(src, SUP.Regole.gruppoStaff)
    if t.citizenid ~= g.citizenid and not staff then return rispondi(nil, 'Non è il tuo.') end

    local messaggi = MySQL.query.await(
        'SELECT autore, staff, testo, momento FROM ticket_messaggi WHERE ticket_id = ? ORDER BY id ASC',
        { id }) or {}

    for _, m in ipairs(messaggi) do
        m.quando = U.DataOraIT(math.floor((m.momento or 0) / 1000))
    end

    rispondi({
        id = t.id, titolo = t.titolo, categoria = t.categoria,
        stato = t.stato, presaDa = t.presa_da, autore = t.nome,
        messaggi = messaggi, staff = staff,
        posizione = staff and t.posizione and json.decode(t.posizione) or nil,
    })
end)

AUREA.Callback.Registra('sup:rispondi', function(src, rispondi, id, testo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local t = MySQL.single.await('SELECT * FROM ticket WHERE id = ? AND stato != \'chiuso\'', { id })
    if not t then return rispondi(false, 'Ticket chiuso o inesistente.') end

    local staff = AUREA.HaGruppo(src, SUP.Regole.gruppoStaff)
    if t.citizenid ~= g.citizenid and not staff then return rispondi(false, 'Non è il tuo.') end

    testo = tostring(testo or ''):sub(1, SUP.Regole.lunghezzaMessaggio)
    if #testo < 2 then return rispondi(false, 'Scrivi qualcosa.') end

    MySQL.insert.await(
        'INSERT INTO ticket_messaggi (ticket_id, autore, staff, testo) VALUES (?, ?, ?, ?)',
        { id, g:NomeCompleto(), staff and 1 or 0, testo })

    -- Chi deve leggere lo sa subito
    if staff then
        local autore = AUREA.GetPlayerByCitizenId(t.citizenid)
        if autore then
            TriggerClientEvent('aurea:ui:notifica', autore.source, {
                tipo = 'info', icona = '💬', durata = 14000,
                titolo = ('Risposta al ticket #%d'):format(id),
                testo = ('%s: %s'):format(g:NomeCompleto(), testo:sub(1, 100)),
            })
        end
    else
        for altroSrc in pairs(AUREA.Giocatori) do
            if AUREA.HaGruppo(altroSrc, SUP.Regole.gruppoStaff) then
                TriggerClientEvent('aurea:ui:notifica', altroSrc, {
                    tipo = 'info', icona = '💬', durata = 11000,
                    titolo = ('Ticket #%d aggiornato'):format(id),
                    testo = ('%s ha risposto.'):format(g:NomeCompleto()),
                })
            end
        end
    end

    rispondi(true, 'Messaggio inviato.')
end)

AUREA.Callback.Registra('sup:aperti', function(src, rispondi)
    if not AUREA.HaGruppo(src, SUP.Regole.gruppoStaff) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, nome, categoria, titolo, stato, presa_da, aperto_il
        FROM ticket WHERE stato != 'chiuso' ORDER BY aperto_il ASC LIMIT 40
    ]]) or {}

    for _, r in ipairs(righe) do
        local c = SUP.GetCategoria(r.categoria)
        r.priorita = c and c.priorita or 5
        r.icona = c and c.icona or '❓'
        r.nomeCategoria = c and c.nome or r.categoria
        r.minuti = math.floor((os.time() - math.floor((r.aperto_il or 0) / 1000)) / 60)
    end
    table.sort(righe, function(a, b)
        if a.priorita ~= b.priorita then return a.priorita < b.priorita end
        return a.minuti > b.minuti
    end)

    rispondi(righe)
end)

AUREA.Callback.Registra('sup:prendi', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g or not AUREA.HaGruppo(src, SUP.Regole.gruppoStaff) then
        return rispondi(false, 'Non sei autorizzato.')
    end

    local t = MySQL.single.await('SELECT * FROM ticket WHERE id = ? AND stato = \'aperto\'', { id })
    if not t then return rispondi(false, 'Già preso in carico o chiuso.') end

    MySQL.update.await('UPDATE ticket SET stato = \'in_carico\', presa_da = ? WHERE id = ?',
        { g:NomeCompleto(), id })

    local autore = AUREA.GetPlayerByCitizenId(t.citizenid)
    if autore then
        TriggerClientEvent('aurea:ui:notifica', autore.source, {
            tipo = 'successo', icona = '💬', durata = 13000,
            titolo = ('Ticket #%d preso in carico'):format(id),
            testo = ('%s si sta occupando del tuo problema.'):format(g:NomeCompleto()),
        })
    end

    rispondi(true, t.posizione and json.decode(t.posizione) or true)
end)

AUREA.Callback.Registra('sup:chiudi', function(src, rispondi, id, nota)
    local g = AUREA.GetPlayer(src)
    if not g or not AUREA.HaGruppo(src, SUP.Regole.gruppoStaff) then
        return rispondi(false, 'Non sei autorizzato.')
    end

    local t = MySQL.single.await('SELECT * FROM ticket WHERE id = ?', { id })
    if not t or t.stato == 'chiuso' then return rispondi(false, 'Già chiuso.') end

    MySQL.update.await('UPDATE ticket SET stato = \'chiuso\', chiuso_da = ?, chiuso_il = NOW() WHERE id = ?',
        { g:NomeCompleto(), id })

    if nota and nota ~= '' then
        MySQL.insert.await(
            'INSERT INTO ticket_messaggi (ticket_id, autore, staff, testo) VALUES (?, ?, 1, ?)',
            { id, g:NomeCompleto(), tostring(nota):sub(1, SUP.Regole.lunghezzaMessaggio) })
    end

    local autore = AUREA.GetPlayerByCitizenId(t.citizenid)
    if autore then
        TriggerClientEvent('aurea:ui:notifica', autore.source, {
            tipo = 'info', icona = '✅', durata = 13000,
            titolo = ('Ticket #%d chiuso'):format(id),
            testo = nota and nota ~= '' and nota or 'Il tuo ticket è stato chiuso.',
        })
    end

    AUREA.Log('staff', 'info', g, ('ticket #%d chiuso'):format(id))
    rispondi(true, 'Ticket chiuso.')
end)

--- I ticket dimenticati si chiudono da soli.
CreateThread(function()
    while true do
        Wait(3600000)
        MySQL.update([[
            UPDATE ticket SET stato = 'chiuso', chiuso_da = 'chiusura automatica', chiuso_il = NOW()
            WHERE stato != 'chiuso' AND aperto_il < DATE_SUB(NOW(), INTERVAL ? HOUR)
        ]], { SUP.Regole.oreChiusuraAutomatica })
    end
end)
