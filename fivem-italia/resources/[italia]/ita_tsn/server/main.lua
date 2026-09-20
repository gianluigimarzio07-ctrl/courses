--[[
    AUREA · Tiro a Segno Nazionale (server)

    Il punteggio della serie lo tira il server. Non è pignoleria: il
    punteggio porta al certificato, il certificato porta al porto d'armi,
    e il porto d'armi porta a girare armati. Tutta la catena poggia su un
    numero, e quel numero non può venire dal client.
]]

local U = AUREA.Util

local function istruttore(g)
    return g and g.lavoro.nome == TSN.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro('lezione')
end

local function inSezione(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - TSN.Sezione.coord) <= 30.0
end

local function sullaLinea(src)
    local coord = GetEntityCoords(GetPlayerPed(src))
    for _, l in ipairs(TSN.Sezione.linee) do
        if #(coord - l) <= TSN.Sezione.raggioLinea then return true end
    end
    return false
end

--- Un istruttore in servizio dentro la sezione, se c'è.
local function istruttorePresente()
    for _, g in pairs(AUREA.GetGiocatoriPerLavoro(TSN.Lavoro, true) or {}) do
        if inSezione(g.source) then return g end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Posizione dell'iscritto
-- ---------------------------------------------------------------------------
local function posizione(citizenid)
    return MySQL.single.await('SELECT * FROM tsn_iscritti WHERE citizenid = ?', { citizenid })
end

local function certificatoValido(citizenid)
    local r = MySQL.scalar.await([[
        SELECT citizenid FROM tsn_iscritti
        WHERE citizenid = ? AND certificato_scadenza IS NOT NULL
          AND certificato_scadenza >= CURDATE()
    ]], { citizenid })
    return r ~= nil
end

--- Lo chiedono ita_questura (porto d'armi) e ita_sicurezza (decreto di
--- guardia giurata). È l'unico motivo per cui questa risorsa esiste.
exports('CertificatoValido', certificatoValido)

exports('Posizione', function(citizenid)
    local p = posizione(citizenid)
    if not p then return nil end
    return {
        tessera = p.tessera,
        lezioni = p.lezioni,
        certificato = certificatoValido(citizenid),
    }
end)

AUREA.Callback.Registra('tsn:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = posizione(g.citizenid)
    if p then
        p.tesseraIT = U.DataIT(math.floor((p.scadenza_tessera or 0) / 1000))
        p.certificatoIT = p.certificato_scadenza
            and U.DataIT(math.floor(p.certificato_scadenza / 1000)) or nil
        p.valido = certificatoValido(g.citizenid)
        p.tesseraValida = (p.scadenza_tessera or 0) / 1000 >= os.time()
    end

    local ist = istruttorePresente()
    rispondi(p, ist ~= nil and ist:NomeCompleto() or nil)
end)

-- ---------------------------------------------------------------------------
--  Iscrizione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tsn:iscrivi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSezione(src) then return rispondi(false, 'Ci si iscrive in sezione.') end

    if not g:SottraiOvunque(TSN.Iscrizione.quota, 'quota di iscrizione TSN') then
        return rispondi(false, ('Servono %s di quota.'):format(U.Euro(TSN.Iscrizione.quota)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(TSN.Lavoro, TSN.Iscrizione.quota, 'quota di iscrizione')
    end)

    local tessera = ('TSN%s'):format(U.Random(6, '0123456789'))
    MySQL.query.await([[
        INSERT INTO tsn_iscritti (citizenid, iscritto_il, tessera, scadenza_tessera, lezioni)
        VALUES (?, CURDATE(), ?, ?, 0)
        ON DUPLICATE KEY UPDATE scadenza_tessera = VALUES(scadenza_tessera)
    ]], { g.citizenid, tessera, U.DataPiuGiorni(TSN.Iscrizione.giorniValidita) })

    AUREA.Log('economia', 'info', g, ('iscritto al TSN, tessera %s'):format(tessera))
    rispondi(true, ('Iscrizione registrata, tessera %s. Ora servono %d lezioni valide.')
        :format(tessera, TSN.Lezione.lezioniPerCertificato))
end)

-- ---------------------------------------------------------------------------
--  La lezione di tiro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tsn:lezione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not sullaLinea(src) then return rispondi(false, 'Si spara dalla linea di tiro, non da qui.') end

    local p = posizione(g.citizenid)
    if not p then return rispondi(false, 'Non risulti iscritto alla sezione.') end
    if (p.scadenza_tessera or 0) / 1000 < os.time() then
        return rispondi(false, 'La tessera è scaduta: prima si rinnova.')
    end

    if not g:SottraiOvunque(TSN.Lezione.costo, 'lezione di tiro') then
        return rispondi(false, ('Servono %s per la serie.'):format(U.Euro(TSN.Lezione.costo)))
    end

    local ist = istruttorePresente()
    pcall(function()
        exports.aurea_azienda:VersaInCassa(TSN.Lavoro,
            TSN.Lezione.costo - (ist and TSN.Lezione.compensoIstruttore or 0), 'lezione di tiro')
    end)

    local punteggio, centri = TSN.Serie(TSN.Lezione.colpi, ist ~= nil)
    local valida = punteggio >= TSN.Lezione.punteggioMinimo

    MySQL.insert.await([[
        INSERT INTO tsn_sessioni (citizenid, istruttore, colpi, punteggio)
        VALUES (?, ?, ?, ?)
    ]], { g.citizenid, ist and ist.citizenid or nil, TSN.Lezione.colpi, punteggio })

    if valida then
        MySQL.update.await('UPDATE tsn_iscritti SET lezioni = lezioni + 1 WHERE citizenid = ?',
            { g.citizenid })
    end

    if ist then
        ist:Aggiungi('banca', TSN.Lezione.compensoIstruttore, 'lezione di tiro')
        TriggerClientEvent('aurea:ui:notifica', ist.source, {
            tipo = 'info', icona = '🎯', durata = 10000,
            titolo = 'Serie seguita',
            testo = ('%s: %d/100. %s'):format(g:NomeCompleto(), punteggio,
                valida and 'Lezione valida.' or 'Sotto il minimo, va ripetuta.'),
        })
    end

    local fatte = (p.lezioni or 0) + (valida and 1 or 0)
    rispondi(true, ('%d centri su %d — punteggio %d/100.\n%s\nLezioni valide: %d di %d.')
        :format(centri, TSN.Lezione.colpi * 10, punteggio,
                valida and 'Serie valida.' or ('Sotto il minimo di %d: non conta.'):format(TSN.Lezione.punteggioMinimo),
                fatte, TSN.Lezione.lezioniPerCertificato),
        punteggio, valida)
end)

-- ---------------------------------------------------------------------------
--  Il certificato
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tsn:certificato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSezione(src) then return rispondi(false, 'Il certificato si ritira in sezione.') end

    local p = posizione(g.citizenid)
    if not p then return rispondi(false, 'Non risulti iscritto.') end
    if (p.lezioni or 0) < TSN.Lezione.lezioniPerCertificato then
        return rispondi(false, ('Servono %d lezioni valide, ne risultano %d.')
            :format(TSN.Lezione.lezioniPerCertificato, p.lezioni or 0))
    end

    -- Il certificato lo firma qualcuno. Se in sezione non c'è nessuno,
    -- non si firma: è il punto di tutta la risorsa.
    local ist = istruttorePresente()
    if not ist then
        return rispondi(false, 'Non c\'è nessun istruttore in sezione: il certificato lo deve firmare una persona.')
    end

    if not g:SottraiOvunque(TSN.Certificato.costo, 'certificato di idoneità') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(TSN.Certificato.costo)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(TSN.Lavoro, TSN.Certificato.costo, 'rilascio certificato')
    end)

    MySQL.update.await([[
        UPDATE tsn_iscritti
        SET certificato_il = CURDATE(), certificato_scadenza = ?, lezioni = 0
        WHERE citizenid = ?
    ]], { U.DataPiuGiorni(TSN.Certificato.giorniValidita), g.citizenid })

    TriggerClientEvent('aurea:ui:notifica', ist.source, {
        tipo = 'successo', icona = '🎯', durata = 12000,
        titolo = 'Certificato firmato',
        testo = ('Idoneità al maneggio delle armi per %s.'):format(g:NomeCompleto()),
    })

    AUREA.Log('economia', 'info', g, ('certificato di idoneità al maneggio rilasciato da %s')
        :format(ist.citizenid))

    rispondi(true, ('Certificato di idoneità al maneggio delle armi rilasciato, valido %d giorni.\nFirmato da %s.\n\nAdesso la Questura può valutare il porto d\'armi.')
        :format(TSN.Certificato.giorniValidita, ist:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  Lo stato della sezione, per chi ci lavora
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tsn:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not istruttore(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT i.tessera, i.lezioni, i.certificato_scadenza,
               CONCAT(p.nome, ' ', p.cognome) AS nominativo,
               (SELECT AVG(s.punteggio) FROM tsn_sessioni s WHERE s.citizenid = i.citizenid) AS media
        FROM tsn_iscritti i
        LEFT JOIN personaggi p ON p.citizenid = i.citizenid
        WHERE i.scadenza_tessera >= CURDATE()
        ORDER BY i.lezioni DESC LIMIT 25
    ]]) or {}

    for _, r in ipairs(righe) do
        r.media = math.floor(tonumber(r.media) or 0)
        r.certificatoIT = r.certificato_scadenza
            and U.DataIT(math.floor(r.certificato_scadenza / 1000)) or nil
    end
    rispondi(righe)
end)
