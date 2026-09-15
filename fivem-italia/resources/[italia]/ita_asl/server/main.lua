--[[
    AUREA · ASL (server)

    L'igiene di un locale è un numero che sta qui e scende da solo. Il
    client non lo tocca: chiede di cucinare e riceve un piatto, e se il
    piatto fa male lo decide questo file.

    L'ispezione non è un tasto che dà una multa: è un confronto fra tre
    numeri che il locale ha costruito da solo nelle ore precedenti.
]]

local U = AUREA.Util

local locali = {}       -- [idLocale] = { igiene, haccp, sospeso, ultimaIspezione }

-- ---------------------------------------------------------------------------
--  Stato di un locale
-- ---------------------------------------------------------------------------
local function stato(idLocale)
    if locali[idLocale] then return locali[idLocale] end

    local r = MySQL.single.await('SELECT * FROM asl_locali WHERE locale = ?', { idLocale })
    if not r then
        MySQL.insert.await('INSERT IGNORE INTO asl_locali (locale, igiene) VALUES (?, ?)',
            { idLocale, ASL.Igiene.iniziale })
        r = { locale = idLocale, igiene = ASL.Igiene.iniziale, sospeso_fino = nil }
    end

    locali[idLocale] = {
        igiene = tonumber(r.igiene) or ASL.Igiene.iniziale,
        ultimoCalo = os.time(),
        sospesoFino = nil,
        ultimaIspezione = 0,
    }
    return locali[idLocale]
end

local function salva(idLocale)
    local s = locali[idLocale]
    if not s then return end
    MySQL.query.await([[
        INSERT INTO asl_locali (locale, igiene) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE igiene = VALUES(igiene)
    ]], { idLocale, math.floor(s.igiene) })
end

--- Il locale più vicino, fra quelli che ita_ristorazione conosce.
local function localeVicino(coord)
    local ok, elenco = pcall(function() return exports.ita_ristorazione:Locali() end)
    for _, l in ipairs(ok and elenco or {}) do
        if #(coord - vector3(l.banco.x, l.banco.y, l.banco.z)) <= 18.0 then return l end
    end
end

--- Lo sporco che si accumula da solo, anche a locale fermo.
local function aggiorna(idLocale)
    local s = stato(idLocale)
    local ore = (os.time() - s.ultimoCalo) / 3600
    if ore > 0 then
        s.igiene = math.max(0, s.igiene - ore * ASL.Igiene.perOraDiFermo)
        s.ultimoCalo = os.time()
    end
    return s
end

-- ---------------------------------------------------------------------------
--  Export: è la porta da cui entra ita_ristorazione
-- ---------------------------------------------------------------------------

--- Il locale può cucinare? Torna (ok, motivo, igiene).
exports('PuoCucinare', function(idLocale)
    local s = aggiorna(idLocale)
    if s.sospesoFino and os.time() < s.sospesoFino then
        return false, 'Attività sospesa dall\'ASL.', math.floor(s.igiene)
    end
    return true, nil, math.floor(s.igiene)
end)

--- Un piatto è stato preparato: sporca, e può far male.
---@return boolean tossinfezione
exports('PiattoPreparato', function(idLocale, citizenidCliente)
    local s = aggiorna(idLocale)
    s.igiene = math.max(0, s.igiene - ASL.Igiene.perPiatto)
    salva(idLocale)

    if math.random() >= ASL.RischioTossinfezione(s.igiene) then return false end
    if not citizenidCliente then return false end

    local g = AUREA.GetPlayerByCitizenId(citizenidCliente)
    if g then
        TriggerClientEvent('aurea:stato:danno', g.source, ASL.Tossinfezione.danno)
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '🤢', durata = 18000,
            titolo = 'Ti senti male',
            testo = 'Crampi violenti poco dopo aver mangiato. Non era il piatto, era la cucina.',
        })

        local coord = GetEntityCoords(GetPlayerPed(g.source))
        TriggerEvent('aurea:112:allerta', 'intossicazione',
            { x = coord.x, y = coord.y, z = coord.z },
            'Sospetta tossinfezione alimentare.', 'esercizio pubblico')
    end

    if ASL.Tossinfezione.segnalaSempre then
        exports.aurea_ui:NotificaLavoro(ASL.Lavoro, {
            tipo = 'avviso', icona = '🤢', durata = 20000,
            titolo = 'Segnalazione di tossinfezione',
            testo = ('Un caso riconducibile a %s. Igiene rilevata %d%%. Ispezione con /ispezionealimenti.')
                :format(idLocale, math.floor(s.igiene)),
        }, false)
    end

    MySQL.insert('INSERT INTO asl_eventi (locale, tipo, igiene, dettaglio) VALUES (?, ?, ?, ?)',
        { idLocale, 'tossinfezione', math.floor(s.igiene), 'caso segnalato al 118' })

    AUREA.Log('sanita', 'avviso', nil,
        ('Tossinfezione riconducibile a %s (igiene %d)'):format(idLocale, math.floor(s.igiene)))
    return true
end)

exports('IgieneLocale', function(idLocale)
    return math.floor(aggiorna(idLocale).igiene)
end)

-- ---------------------------------------------------------------------------
--  Sanificazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asl:sanifica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local l = localeVicino(GetEntityCoords(GetPlayerPed(src)))
    if not l then return rispondi(false, 'Non sei in un esercizio.') end
    if g.lavoro.nome ~= l.lavoro and g.lavoro.nome ~= 'ristoratore' then
        return rispondi(false, 'Qui non ci lavori.')
    end

    if not exports.aurea_inventory:Ha(g.citizenid, ASL.Igiene.prodotto, ASL.Igiene.prodottoQuantita) then
        return rispondi(false, ('Serve %s.'):format(AUREA.Item[ASL.Igiene.prodotto].etichetta))
    end
    exports.aurea_inventory:Rimuovi(g.citizenid, ASL.Igiene.prodotto, ASL.Igiene.prodottoQuantita)

    local s = aggiorna(l.id)
    s.igiene = math.min(100, s.igiene + ASL.Igiene.sanificazioneRecupero)
    salva(l.id)

    local giudizio, spiegazione = ASL.Giudizio(s.igiene)
    rispondi(true, ('Sanificato. Igiene %d%% — %s'):format(math.floor(s.igiene), spiegazione))
end)

AUREA.Callback.Registra('asl:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local l = localeVicino(GetEntityCoords(GetPlayerPed(src)))
    if not l then return rispondi(nil) end

    local s = aggiorna(l.id)
    local giudizio, spiegazione = ASL.Giudizio(s.igiene)
    local haccp = MySQL.scalar.await(
        'SELECT id FROM asl_haccp WHERE locale = ? AND scade_il > NOW() LIMIT 1', { l.id })

    rispondi({
        id = l.id, nome = l.nome,
        igiene = math.floor(s.igiene), giudizio = giudizio, spiegazione = spiegazione,
        haccp = haccp ~= nil,
        sospeso = s.sospesoFino ~= nil and os.time() < s.sospesoFino,
        minutiSospensione = s.sospesoFino and math.max(0, math.ceil((s.sospesoFino - os.time()) / 60)) or 0,
    })
end)

-- ---------------------------------------------------------------------------
--  HACCP
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asl:haccp', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local l = localeVicino(GetEntityCoords(GetPlayerPed(src)))
    if not l then return rispondi(false, 'Il piano si deposita nel locale a cui si riferisce.') end

    if not g:Sottrai('banca', ASL.Haccp.costo, 'piano di autocontrollo HACCP') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(ASL.Haccp.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_sanitari', ASL.Haccp.costo, g.citizenid)

    MySQL.query.await([[
        INSERT INTO asl_haccp (locale, depositato_da, scade_il)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE depositato_da = VALUES(depositato_da),
                                depositato_il = NOW(), scade_il = VALUES(scade_il)
    ]], { l.id, g.citizenid, ASL.Haccp.validitaMinuti })

    rispondi(true, ('Piano di autocontrollo depositato per %s. Vale %d minuti.')
        :format(l.nome, ASL.Haccp.validitaMinuti))
end)

-- ---------------------------------------------------------------------------
--  Ispezione
-- ---------------------------------------------------------------------------
AUREA.Comando('ispezionealimenti', 'utente', 'Ispezione igienico-sanitaria dell\'esercizio', {},
function(src, _, _, g)
    if not g or g.lavoro.nome ~= ASL.Lavoro or not g:HaPermessoLavoro(ASL.Permesso) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🧪', titolo = 'Non autorizzato',
            testo = 'L\'ispezione la esegue un tecnico della prevenzione.' })
    end

    local l = localeVicino(GetEntityCoords(GetPlayerPed(src)))
    if not l then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🧪', titolo = 'Nessun esercizio', testo = 'Qui non c\'è niente da ispezionare.' })
    end

    local s = aggiorna(l.id)
    if os.time() - s.ultimaIspezione < ASL.Ispezione.raffreddamentoMinuti * 60 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🧪', titolo = 'Troppo presto',
            testo = ('%s è stato ispezionato da poco.'):format(l.nome) })
    end
    s.ultimaIspezione = os.time()

    local violazioni, totale, gravi = {}, 0, 0
    local function contesta(chiave)
        local v = ASL.Ispezione.sanzioni[chiave]
        violazioni[#violazioni + 1] = v.testo
        totale = totale + v.importo
        if v.grave then gravi = gravi + 1 end
    end

    local giudizio = ASL.Giudizio(s.igiene)
    if giudizio == 'inaccettabile' or giudizio == 'grave' then contesta('igiene_grave')
    elseif giudizio == 'scarso' then contesta('igiene_scarsa') end

    local haccp = MySQL.scalar.await(
        'SELECT id FROM asl_haccp WHERE locale = ? AND scade_il > NOW() LIMIT 1', { l.id })
    if not haccp then contesta('haccp_mancante') end

    -- Tracciabilità: se in cucina non c'è nessuna materia prima, la merce
    -- servita non ha origine dimostrabile
    local haMateria = false
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.nome == l.lavoro
            and #(GetEntityCoords(GetPlayerPed(altro.source)) - vector3(l.banco.x, l.banco.y, l.banco.z)) <= 18.0 then
            for _, item in ipairs({ 'farina_00', 'pomodoro_san_marzano', 'mozzarella_bufala', 'caffe_tostato' }) do
                if exports.aurea_inventory:Ha(altro.citizenid, item, 1) then haMateria = true end
            end
        end
    end
    if not haMateria then contesta('tracciabilita') end

    g:Aggiungi('banca', ASL.Ispezione.compenso, 'ispezione igienico-sanitaria')

    MySQL.insert('INSERT INTO asl_eventi (locale, tipo, igiene, dettaglio) VALUES (?, ?, ?, ?)',
        { l.id, 'ispezione', math.floor(s.igiene),
          #violazioni > 0 and table.concat(violazioni, '; ') or 'nessuna violazione' })

    if #violazioni == 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🧪', durata = 18000,
            titolo = ('Ispezione — %s'):format(l.nome),
            testo = ('Igiene %d%%, HACCP in ordine, merce tracciabile. Niente da contestare.')
                :format(math.floor(s.igiene)),
        })
    end

    local sospeso = gravi >= ASL.Ispezione.graviPerSospensione
    if sospeso then
        s.sospesoFino = os.time() + ASL.Ispezione.sospensioneMinuti * 60
    end

    exports.aurea_ui:NotificaLavoro(l.lavoro, {
        tipo = 'errore', icona = '🧪', durata = 25000,
        titolo = sospeso and 'Attività sospesa' or 'Verbale ASL',
        testo = ('%s\n· %s\n\nSanzione %s%s'):format(l.nome, table.concat(violazioni, '\n· '), U.Euro(totale),
            sospeso and ('\n\nSOSPENSIONE per %d minuti. In cucina non si entra.')
                :format(ASL.Ispezione.sospensioneMinuti) or ''),
    }, false)

    -- La sanzione la paga chi ha la partita IVA del locale; se non la
    -- troviamo, resta a carico di chi ci lavora in quel momento.
    local titolare
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.nome == l.lavoro and altro:HaPermessoLavoro('cassa') then titolare = altro end
    end
    if titolare then
        exports.ita_fisco:IscriviTributo(titolare.citizenid, 'sanzione',
            ('violazioni igienico-sanitarie %s'):format(l.nome), totale, 7)
    else
        pcall(function()
            exports.aurea_azienda:PrelevaDaCassa(l.lavoro, totale, ('sanzione ASL %s'):format(l.nome))
        end)
    end

    AUREA.Log('sanita', 'avviso', g,
        ('ha verbalizzato %d violazioni presso %s (%s)'):format(#violazioni, l.nome, U.Euro(totale)))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '🧪', durata = 25000,
        titolo = ('Ispezione — %s'):format(l.nome),
        testo = ('Igiene %d%%\n%d violazioni:\n· %s\n\nSanzione %s%s')
            :format(math.floor(s.igiene), #violazioni, table.concat(violazioni, '\n· '),
                    U.Euro(totale), sospeso and '\nATTIVITÀ SOSPESA.' or ''),
    })
end)

-- ---------------------------------------------------------------------------
--  Riapertura dopo una sospensione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asl:riapri', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local l = localeVicino(GetEntityCoords(GetPlayerPed(src)))
    if not l then return rispondi(false, 'Non sei in un esercizio.') end

    local s = aggiorna(l.id)
    if not s.sospesoFino or os.time() >= s.sospesoFino then
        return rispondi(false, 'Il locale non è sospeso.')
    end
    if s.igiene < ASL.Igiene.sogliaAvviso then
        return rispondi(false, ('Prima si pulisce: l\'igiene è al %d%%, serve almeno %d%%.')
            :format(math.floor(s.igiene), ASL.Igiene.sogliaAvviso))
    end

    if not g:Sottrai('banca', ASL.Ispezione.riapertura, 'diritti di riapertura') then
        return rispondi(false, ('Servono %s di diritti.'):format(U.Euro(ASL.Ispezione.riapertura)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_sanitari', ASL.Ispezione.riapertura, g.citizenid)

    s.sospesoFino = nil
    rispondi(true, ('%s può riaprire.'):format(l.nome))
end)

-- Lo sporco si salva ogni tanto: un riavvio non deve ripulire le cucine
CreateThread(function()
    while true do
        Wait(300000)
        for id in pairs(locali) do
            aggiorna(id)
            salva(id)
        end
    end
end)

print('[AUREA] ASL: vigilanza igienico-sanitaria attiva')
