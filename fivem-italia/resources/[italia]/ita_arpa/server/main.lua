--[[
    AUREA · A.R.P.A. (server)

    Il valore misurato lo estrae il server, sempre. Un campionamento che
    il client potesse dichiarare sarebbe un'autocertificazione, e
    l'autocertificazione in materia ambientale è esattamente la cosa
    contro cui l'A.R.P.A. esiste.

    Le prescrizioni scadute le guarda un thread: è l'unico punto in cui
    il tempo, da solo, trasforma una raccomandazione in una sanzione.
]]

local U = AUREA.Util
local raffreddamenti = {}   -- [bersaglio] = timestamp

local function tecnico(g, permesso)
    return g and g.lavoro.nome == ARPA.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'campionamento')
end

-- ---------------------------------------------------------------------------
--  Chi c'è, qui intorno, che si possa misurare
--
--  L'A.R.P.A. non misura l'aria in generale: misura un bersaglio. Il
--  bersaglio lo si ricava da quello che le altre risorse hanno già
--  censito in quel punto.
-- ---------------------------------------------------------------------------
local function bersaglioIn(coord)
    -- Un campionamento si fa in un punto, e il punto è il bersaglio.
    -- Se il tecnico sa a cosa attribuirlo — un cantiere, un locale, una
    -- discarica — lo scrive lui nel campo del bersaglio: è quello che
    -- fa un verbale di campionamento vero, e non una deduzione
    -- automatica del server.
    return ('%.0f, %.0f'):format(coord.x, coord.y)
end

-- ---------------------------------------------------------------------------
--  Il campionamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('arpa:campiona', function(src, rispondi, matriceId, bersaglio)
    local g = AUREA.GetPlayer(src)
    if not tecnico(g) then return rispondi(false, 'Serve un tecnico A.R.P.A. in servizio.') end

    local matrice = ARPA.GetMatrice(matriceId)
    if not matrice then return rispondi(false, 'Matrice non prevista.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    bersaglio = tostring(bersaglio or ''):sub(1, 64)
    if bersaglio == '' then bersaglio = bersaglioIn(coord) end

    local chiave = ('%s:%s'):format(matriceId, bersaglio)
    if (raffreddamenti[chiave] or 0) > os.time() then
        return rispondi(false, 'Su questo punto c\'è già un campionamento recente.')
    end
    raffreddamenti[chiave] = os.time() + ARPA.Regole.minutiFraControlli * 60

    -- Il valore. Il rumore lo si misura su quello che suona davvero:
    -- se c'è uno stereo acceso qui intorno, il valore parte più alto.
    local valore = math.random(matrice.minimo, matrice.massimo)

    if matriceId == 'rumore' then
        local acceso = false
        pcall(function()
            acceso = exports.aurea_musica:StereoVicino(coord, ARPA.Regole.raggioRumore) == true
        end)
        if acceso then valore = math.min(matrice.massimo, valore + 22) end
    end

    local esito = ARPA.Esito(matrice, valore)

    -- Chi è il responsabile, se si riesce a risalirci
    local responsabile
    if matriceId == 'suolo' or matriceId == 'scarico' then
        responsabile = MySQL.scalar.await([[
            SELECT citizenid FROM rifiuti_registro
            WHERE citizenid IS NOT NULL ORDER BY id DESC LIMIT 1
        ]])
    end

    local sanzione = 0
    if esito == 'grave' then
        sanzione = matrice.sanzione
    end

    local id = MySQL.insert.await([[
        INSERT INTO arpa_controlli (tipo, bersaglio, citizenid, tecnico, valore, limite, esito, sanzione)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { matriceId, bersaglio, responsabile, g.citizenid,
          valore, matrice.limite, esito, sanzione })

    -- Il superamento non grave diventa una prescrizione: hai tempo
    if esito == 'superamento' then
        MySQL.insert.await([[
            INSERT INTO arpa_prescrizioni (controllo_id, citizenid, bersaglio, descrizione, scade_il)
            VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ]], { id, responsabile, bersaglio, matrice.prescrizione,
              ARPA.Prescrizione.minutiPerOttemperare })

        if responsabile then
            TriggerEvent('aurea:telefono:messaggioSistema', responsabile, 'A.R.P.A.',
                ('Superamento su %s: %d %s contro un limite di %d.\nPrescrizione: %s\nHai %d minuti, poi la sanzione raddoppia.')
                    :format(matrice.nome, valore, matrice.unita, matrice.limite,
                            matrice.prescrizione, ARPA.Prescrizione.minutiPerOttemperare))
        end
    end

    if esito == 'grave' then
        if responsabile then
            AUREA.Denaro.SottraiOffline(responsabile, 'banca', sanzione,
                ('sanzione ambientale — %s'):format(matrice.nome), true)
            TriggerEvent('aurea:fisco:incasso', 'sanzioni_ambientali', sanzione, responsabile)
            exports.ita_giustizia:ApriFascicolo(responsabile, '452q', g:NomeCompleto(),
                ('Superamento grave dei limiti: %s, %d %s su un limite di %d (%s)')
                    :format(matrice.nome, valore, matrice.unita, matrice.limite, matrice.norma))
        end

        exports.aurea_ui:NotificaEnte('carabinieri', {
            tipo = 'errore', icona = '☣', durata = 18000,
            titolo = 'Superamento grave accertato',
            testo = ('%s su %s: %d %s contro %d.')
                :format(matrice.nome, bersaglio, valore, matrice.unita, matrice.limite),
        }, true)
    end

    AUREA.Log('economia', esito == 'conforme' and 'info' or 'avviso', g,
        ('campionamento %s su %s: %d %s (%s)')
            :format(matriceId, bersaglio, valore, matrice.unita, esito))

    rispondi(true, {
        matrice = matrice.nome, unita = matrice.unita,
        valore = valore, limite = matrice.limite, esito = esito,
        norma = matrice.norma, sanzione = sanzione,
        prescrizione = esito == 'superamento' and matrice.prescrizione or nil,
        minuti = ARPA.Prescrizione.minutiPerOttemperare,
    })
end)

-- ---------------------------------------------------------------------------
--  Ottemperare
--
--  Chi ha ricevuto una prescrizione può dichiarare di aver sistemato.
--  Non basta dirlo: serve che un tecnico torni a misurare, e la
--  seconda misura è quella che chiude o che condanna.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('arpa:prescrizioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local mie = MySQL.query.await([[
        SELECT p.id, p.bersaglio, p.descrizione, c.tipo, c.valore, c.limite,
               TIMESTAMPDIFF(MINUTE, NOW(), p.scade_il) AS minuti
        FROM arpa_prescrizioni p
        JOIN arpa_controlli c ON c.id = p.controllo_id
        WHERE p.citizenid = ? AND p.ottemperata = 0
    ]], { g.citizenid }) or {}

    local tutte = {}
    if tecnico(g) then
        tutte = MySQL.query.await([[
            SELECT p.id, p.bersaglio, p.descrizione, c.tipo,
                   CONCAT(x.nome, ' ', x.cognome) AS responsabile,
                   TIMESTAMPDIFF(MINUTE, NOW(), p.scade_il) AS minuti
            FROM arpa_prescrizioni p
            JOIN arpa_controlli c ON c.id = p.controllo_id
            LEFT JOIN personaggi x ON x.citizenid = p.citizenid
            WHERE p.ottemperata = 0 ORDER BY p.scade_il ASC LIMIT 25
        ]]) or {}
    end

    rispondi({ mie = mie, tutte = tutte, tecnico = tecnico(g, 'prescrizione') })
end)

AUREA.Callback.Registra('arpa:verifica', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not tecnico(g, 'prescrizione') then
        return rispondi(false, 'La verifica di ottemperanza la chiude un tecnico capo.')
    end

    local p = MySQL.single.await([[
        SELECT p.*, c.tipo FROM arpa_prescrizioni p
        JOIN arpa_controlli c ON c.id = p.controllo_id
        WHERE p.id = ? AND p.ottemperata = 0
    ]], { tonumber(id) })
    if not p then return rispondi(false, 'Prescrizione non trovata.') end

    local matrice = ARPA.GetMatrice(p.tipo)
    if not matrice then return rispondi(false, 'Matrice sconosciuta.') end

    -- La seconda misura. Chi ha davvero sistemato di solito rientra,
    -- ma non è garantito: il server tira un valore più basso, non zero.
    local valore = math.random(matrice.minimo, math.floor(matrice.limite * 1.3))
    local rientrato = valore <= matrice.limite

    MySQL.insert.await([[
        INSERT INTO arpa_controlli (tipo, bersaglio, citizenid, tecnico, valore, limite, esito)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { p.tipo, p.bersaglio, p.citizenid, g.citizenid, valore, matrice.limite,
          rientrato and 'conforme' or 'superamento' })

    if rientrato then
        MySQL.update.await('UPDATE arpa_prescrizioni SET ottemperata = 1 WHERE id = ?', { p.id })
        if p.citizenid then
            TriggerEvent('aurea:telefono:messaggioSistema', p.citizenid, 'A.R.P.A.',
                ('Verifica su %s: %d %s, rientrato nei limiti. Prescrizione chiusa senza sanzione.')
                    :format(matrice.nome, valore, matrice.unita))
        end
    end

    rispondi(true, ('%s su %s: %d %s contro %d.\n%s')
        :format(matrice.nome, p.bersaglio, valore, matrice.unita, matrice.limite,
                rientrato and 'Rientrato: prescrizione chiusa.'
                          or 'Ancora fuori: la prescrizione resta aperta e scade.'))
end)

-- ---------------------------------------------------------------------------
--  Le prescrizioni scadute
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(120000)

        local scadute = MySQL.query.await([[
            SELECT p.id, p.citizenid, p.bersaglio, p.descrizione, c.tipo
            FROM arpa_prescrizioni p
            JOIN arpa_controlli c ON c.id = p.controllo_id
            WHERE p.ottemperata = 0 AND p.sanzionata = 0 AND p.scade_il <= NOW()
        ]]) or {}

        for _, p in ipairs(scadute) do
            local matrice = ARPA.GetMatrice(p.tipo)
            if matrice then
                local importo = math.floor(matrice.sanzione
                    * ARPA.Prescrizione.moltiplicatoreInadempienza)

                MySQL.update.await('UPDATE arpa_prescrizioni SET sanzionata = 1 WHERE id = ?', { p.id })

                if p.citizenid then
                    AUREA.Denaro.SottraiOffline(p.citizenid, 'banca', importo,
                        ('inottemperanza alla prescrizione — %s'):format(matrice.nome), true)
                    TriggerEvent('aurea:fisco:incasso', 'sanzioni_ambientali', importo, p.citizenid)

                    TriggerEvent('aurea:telefono:messaggioSistema', p.citizenid, 'A.R.P.A.',
                        ('Il termine per la prescrizione su %s è scaduto senza ottemperanza. Sanzione %s, il doppio di quanto sarebbe costato rientrare.')
                            :format(matrice.nome, U.Euro(importo)))

                    exports.ita_giustizia:ApriFascicolo(p.citizenid, '256', 'A.R.P.A.',
                        ('Inottemperanza alla prescrizione ambientale su %s'):format(p.bersaglio))
                end

                AUREA.Log('economia', 'avviso', nil,
                    ('prescrizione %d scaduta su %s: sanzione %s')
                        :format(p.id, p.bersaglio, U.Euro(importo)))
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il registro dei controlli
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('arpa:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not tecnico(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT c.tipo, c.bersaglio, c.valore, c.limite, c.esito, c.sanzione,
               CONCAT(p.nome, ' ', p.cognome) AS tecnico,
               TIMESTAMPDIFF(MINUTE, c.quando, NOW()) AS minutiFa
        FROM arpa_controlli c
        LEFT JOIN personaggi p ON p.citizenid = c.tecnico
        ORDER BY c.quando DESC LIMIT 25
    ]]) or {}

    for _, r in ipairs(righe) do
        local m = ARPA.GetMatrice(r.tipo)
        r.nomeMatrice = m and m.nome or r.tipo
        r.unita = m and m.unita or ''
    end
    rispondi(righe)
end)
