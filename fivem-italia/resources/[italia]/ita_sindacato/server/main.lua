--[[
    AUREA · Sindacato (server)

    Tutto qui dentro dipende da un numero solo: quante persone hanno
    aderito. Non ci sono scorciatoie, non c'è un permesso che salta la
    conta, e il delegato da solo non può niente.

    Lo sciopero è un thread che per un po' toglie soldi alla cassa
    dell'attività e ne dà pochi a chi si è fermato. Nessuno dei due ci
    guadagna: è il punto.
]]

local U = AUREA.Util
local scioperiAttivi = {}   -- [lavoro] = { vertenza, fino, aderenti }

local function sindacalista(g, permesso)
    return g and g.lavoro.nome == SIND.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'vertenza')
end

local function inCamera(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - SIND.Camera.coord) <= 8.0
end

local function iscritto(citizenid)
    return MySQL.single.await([[
        SELECT sigla, iscritto_il FROM sindacato_iscritti WHERE citizenid = ?
    ]], { citizenid })
end

--- Lo chiede chi vuole sapere se un mestiere è fermo. Lo usa il
--- calcolo degli stipendi: chi sciopera non viene pagato.
exports('InSciopero', function(lavoro)
    local s = scioperiAttivi[lavoro]
    if not s then return false end
    return true, s.aderenti
end)

exports('Aderente', function(citizenid, lavoro)
    local s = scioperiAttivi[lavoro]
    if not s then return false end
    return s.elenco and s.elenco[citizenid] == true
end)

-- ---------------------------------------------------------------------------
--  Iscrizione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sind:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local vertenze = MySQL.query.await([[
        SELECT v.id, v.lavoro, v.oggetto, v.richiesta, v.adesioni, v.stato,
               CONCAT(p.nome, ' ', p.cognome) AS promotore,
               TIMESTAMPDIFF(MINUTE, NOW(), v.scade_il) AS minuti,
               (SELECT COUNT(*) FROM vertenza_adesioni a
                WHERE a.vertenza_id = v.id AND a.citizenid = ?) AS aderito
        FROM vertenze v
        LEFT JOIN personaggi p ON p.citizenid = v.promotore
        WHERE v.stato IN ('aperta','sciopero')
        ORDER BY v.aperta_il DESC LIMIT 12
    ]], { g.citizenid }) or {}

    for _, v in ipairs(vertenze) do
        v.nomeOggetto = (SIND.GetOggetto(v.oggetto) or {}).nome or v.oggetto
        v.etichettaLavoro = AUREA.EtichettaLavoro(v.lavoro, 0)
        v.mio = v.lavoro == g.lavoro.nome
    end

    rispondi({
        iscritto = iscritto(g.citizenid),
        sigle = SIND.Sigle,
        quota = SIND.Iscrizione.quota,
        vertenze = vertenze,
        oggetti = SIND.Vertenza.oggetti,
        delegato = sindacalista(g),
        puoScioperare = sindacalista(g, 'sciopero'),
        soglie = {
            sciopero = SIND.Vertenza.adesioniPerSciopero,
            accordo = SIND.Vertenza.adesioniPerAccordo,
        },
        mioLavoro = g.lavoro.nome,
    })
end)

AUREA.Callback.Registra('sind:iscrivi', function(src, rispondi, sigla)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local valida = false
    for _, s in ipairs(SIND.Sigle) do if s.id == sigla then valida = true end end
    if not valida then return rispondi(false, 'Sigla inesistente.') end

    if not g:SottraiOvunque(SIND.Iscrizione.quota, 'quota sindacale') then
        return rispondi(false, ('La quota è %s.'):format(U.Euro(SIND.Iscrizione.quota)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(SIND.Lavoro, SIND.Iscrizione.quota, 'quote associative')
    end)

    MySQL.query.await([[
        INSERT INTO sindacato_iscritti (citizenid, sigla, quota_versata_il)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE sigla = VALUES(sigla), quota_versata_il = NOW()
    ]], { g.citizenid, sigla })

    rispondi(true, ('Iscritto. Da adesso puoi aderire alle vertenze: chi non è iscritto non conta nella conta.'))
end)

-- ---------------------------------------------------------------------------
--  Vertenze
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sind:apri', function(src, rispondi, lavoro, oggettoId, richiesta)
    local g = AUREA.GetPlayer(src)
    if not sindacalista(g) then return rispondi(false, 'La vertenza la apre un delegato in servizio.') end
    if not inCamera(src) then return rispondi(false, 'Si apre in Camera del lavoro.') end

    local oggetto = SIND.GetOggetto(oggettoId)
    if not oggetto then return rispondi(false, 'Oggetto non previsto.') end
    if not AUREA.Lavori[lavoro] then return rispondi(false, 'Mestiere inesistente.') end

    local gia = MySQL.scalar.await([[
        SELECT id FROM vertenze WHERE lavoro = ? AND stato IN ('aperta','sciopero')
    ]], { lavoro })
    if gia then return rispondi(false, 'Su quel mestiere c\'è già una vertenza aperta.') end

    local id = MySQL.insert.await([[
        INSERT INTO vertenze (lavoro, oggetto, richiesta, promotore, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { lavoro, oggettoId, tostring(richiesta or oggetto.nome):sub(1, 255),
          g.citizenid, SIND.Vertenza.minutiDurata })

    exports.aurea_ui:NotificaLavoro(lavoro, {
        tipo = 'info', icona = '✊', durata = 20000,
        titolo = 'Vertenza aperta',
        testo = ('%s\n%s\nServono %d adesioni per lo sciopero, %d per l\'accordo. Camera del lavoro.')
            :format(oggetto.nome, richiesta or '',
                    SIND.Vertenza.adesioniPerSciopero, SIND.Vertenza.adesioniPerAccordo),
    }, false)

    AUREA.Log('economia', 'info', g, ('vertenza su %s: %s'):format(lavoro, oggettoId))
    rispondi(true, ('Vertenza n. %d aperta su %s.\nAdesso serve che aderiscano: da solo un delegato non è niente.')
        :format(id, AUREA.EtichettaLavoro(lavoro, 0)))
end)

AUREA.Callback.Registra('sind:aderisci', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if SIND.Vertenza.richiedeIscrizione and not iscritto(g.citizenid) then
        return rispondi(false, 'Per aderire bisogna essere iscritti. La quota si versa in Camera del lavoro.')
    end

    local v = MySQL.single.await(
        'SELECT id, lavoro, oggetto, adesioni FROM vertenze WHERE id = ? AND stato = ?',
        { tonumber(id), 'aperta' })
    if not v then return rispondi(false, 'Vertenza non più aperta.') end
    if v.lavoro ~= g.lavoro.nome then
        return rispondi(false, 'Si aderisce alle vertenze del proprio mestiere.')
    end

    local gia = MySQL.scalar.await(
        'SELECT id FROM vertenza_adesioni WHERE vertenza_id = ? AND citizenid = ?',
        { v.id, g.citizenid })
    if gia then return rispondi(false, 'Hai già aderito.') end

    MySQL.insert.await('INSERT INTO vertenza_adesioni (vertenza_id, citizenid) VALUES (?, ?)',
        { v.id, g.citizenid })
    MySQL.update.await('UPDATE vertenze SET adesioni = adesioni + 1 WHERE id = ?', { v.id })

    local ora = (v.adesioni or 0) + 1
    rispondi(true, ('Adesione registrata: siete in %d.\n%s')
        :format(ora,
            ora >= SIND.Vertenza.adesioniPerAccordo and 'Bastano per chiudere con un accordo.'
            or (ora >= SIND.Vertenza.adesioniPerSciopero
                and 'Bastano per proclamare lo sciopero.'
                or ('Ne servono %d per lo sciopero.'):format(SIND.Vertenza.adesioniPerSciopero))))
end)

-- ---------------------------------------------------------------------------
--  Sciopero
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sind:proclama', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not sindacalista(g, 'sciopero') then
        return rispondi(false, 'Lo sciopero lo proclama il segretario.')
    end

    local v = MySQL.single.await(
        'SELECT id, lavoro, oggetto, adesioni FROM vertenze WHERE id = ? AND stato = ?',
        { tonumber(id), 'aperta' })
    if not v then return rispondi(false, 'Vertenza non più aperta.') end

    if not SIND.Scioperabile(v.lavoro) then
        return rispondi(false, 'È un servizio pubblico essenziale: non si sciopera (L. 146/1990).')
    end
    if (v.adesioni or 0) < SIND.Vertenza.adesioniPerSciopero then
        return rispondi(false, ('Servono %d adesioni, siete in %d.')
            :format(SIND.Vertenza.adesioniPerSciopero, v.adesioni or 0))
    end
    if scioperiAttivi[v.lavoro] then return rispondi(false, 'Quel mestiere è già fermo.') end

    local aderenti = MySQL.query.await(
        'SELECT citizenid FROM vertenza_adesioni WHERE vertenza_id = ?', { v.id }) or {}

    local elenco = {}
    for _, a in ipairs(aderenti) do elenco[a.citizenid] = true end

    scioperiAttivi[v.lavoro] = {
        vertenza = v.id,
        fino = os.time() + SIND.Sciopero.minutiDurata * 60,
        aderenti = #aderenti,
        elenco = elenco,
    }

    MySQL.update.await('UPDATE vertenze SET stato = ? WHERE id = ?', { 'sciopero', v.id })

    exports.aurea_ui:NotificaTutti({
        tipo = 'avviso', icona = '✊', durata = 20000,
        titolo = 'Sciopero proclamato',
        testo = ('%s si ferma per %d minuti. %d aderenti.')
            :format(AUREA.EtichettaLavoro(v.lavoro, 0), SIND.Sciopero.minutiDurata, #aderenti),
    })

    AUREA.Log('economia', 'avviso', g, ('sciopero su %s: %d aderenti'):format(v.lavoro, #aderenti))

    rispondi(true, ('Sciopero proclamato: %d aderenti per %d minuti.\nLa cassa di quel mestiere si sta già svuotando.')
        :format(#aderenti, SIND.Sciopero.minutiDurata))
end)

--- Lo sciopero costa. A tutti e due.
CreateThread(function()
    while true do
        Wait(60000)

        for lavoro, s in pairs(scioperiAttivi) do
            if os.time() >= s.fino then
                -- Finito: si guarda se la vertenza ha ottenuto qualcosa
                local v = MySQL.single.await(
                    'SELECT id, oggetto, adesioni FROM vertenze WHERE id = ?', { s.vertenza })

                if v and (v.adesioni or 0) >= SIND.Vertenza.adesioniPerAccordo then
                    local oggetto = SIND.GetOggetto(v.oggetto)
                    local arretrati = oggetto and oggetto.arretrati or 0

                    local pagati = 0
                    for citizenid in pairs(s.elenco) do
                        local presa = false
                        pcall(function()
                            presa = exports.aurea_azienda:PrelevaDaCassa(lavoro, arretrati,
                                'arretrati da accordo sindacale') == true
                        end)
                        if presa then
                            AUREA.Denaro.AggiungiOffline(citizenid, 'banca', arretrati,
                                'arretrati da accordo sindacale')
                            pagati = pagati + 1
                        end

                        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Sindacato',
                            presa
                                and ('Accordo raggiunto: %s di arretrati accreditati.')
                                    :format(U.Euro(arretrati))
                                or 'Accordo raggiunto, ma la cassa dell\'attività è vuota: gli arretrati non ci sono.')
                    end

                    MySQL.update.await(
                        'UPDATE vertenze SET stato = ?, chiusa_il = NOW() WHERE id = ?',
                        { 'accolta', v.id })

                    exports.aurea_ui:NotificaTutti({
                        tipo = 'successo', icona = '✊', durata = 16000,
                        titolo = 'Vertenza chiusa con accordo',
                        testo = ('%s: %d lavoratori hanno ottenuto gli arretrati.')
                            :format(AUREA.EtichettaLavoro(lavoro, 0), pagati),
                    })
                else
                    MySQL.update.await(
                        'UPDATE vertenze SET stato = ?, chiusa_il = NOW() WHERE id = ?',
                        { 'respinta', s.vertenza })

                    for citizenid in pairs(s.elenco) do
                        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Sindacato',
                            'Lo sciopero è finito senza accordo. Le ore perse restano perse.')
                    end
                end

                scioperiAttivi[lavoro] = nil
            else
                -- Mentre dura: indennità a chi si è fermato, danno alla cassa
                local danno = SIND.Sciopero.dannoAlMinuto * s.aderenti
                pcall(function()
                    exports.aurea_azienda:PrelevaDaCassa(lavoro, danno, 'mancato incasso da sciopero')
                end)

                for citizenid in pairs(s.elenco) do
                    AUREA.Denaro.AggiungiOffline(citizenid, 'banca',
                        math.floor(SIND.Sciopero.indennita / SIND.Sciopero.minutiDurata),
                        'indennità di sciopero')
                end
            end
        end
    end
end)

--- Le vertenze che nessuno ha portato avanti decadono.
CreateThread(function()
    while true do
        Wait(180000)
        MySQL.update.await([[
            UPDATE vertenze SET stato = 'decaduta', chiusa_il = NOW()
            WHERE stato = 'aperta' AND scade_il <= NOW()
        ]])
    end
end)
