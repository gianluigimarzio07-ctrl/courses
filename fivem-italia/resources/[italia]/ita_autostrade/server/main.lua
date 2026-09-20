--[[
    AUREA · Autostrade (server)

    Un transito è una riga aperta a un casello e chiusa a un altro. Il
    pedaggio si calcola alla chiusura, sulla differenza fra i due
    chilometraggi — e per questo non esiste un modo di saperlo in anticipo
    né di dichiararlo dal client.

    Chi entra e non esce mai paga la tratta massima, che è quello che
    succede davvero quando perdi il biglietto.
]]

local U = AUREA.Util

local function esattore(g)
    return g and g.lavoro.nome == AUT.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro('casello')
end

-- ---------------------------------------------------------------------------
--  Telepass
-- ---------------------------------------------------------------------------
local function telepassDi(targa)
    return MySQL.single.await(
        'SELECT id, citizenid, codice, attivo, insoluto FROM telepass WHERE targa = ?', { targa })
end

exports('TelepassSu', function(targa)
    local t = telepassDi(targa)
    return t ~= nil and t.attivo == 1
end)

AUREA.Callback.Registra('aut:telepass', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local righe = MySQL.query.await(
        'SELECT targa, codice, attivo, insoluto FROM telepass WHERE citizenid = ?',
        { g.citizenid }) or {}

    local miei = MySQL.query.await([[
        SELECT targa, modello FROM veicoli
        WHERE citizenid = ? AND stato != 'demolito'
          AND targa NOT IN (SELECT targa FROM telepass)
    ]], { g.citizenid }) or {}

    rispondi({ apparati = righe, veicoli = miei,
               canone = AUT.Telepass.canoneAttivazione,
               sconto = AUT.Telepass.sconto })
end)

AUREA.Callback.Registra('aut:attivaTelepass', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local mio = MySQL.scalar.await('SELECT targa FROM veicoli WHERE targa = ? AND citizenid = ?',
        { targa, g.citizenid })
    if not mio then return rispondi(false, 'Quel veicolo non è intestato a te.') end

    if telepassDi(targa) then return rispondi(false, 'Su quella targa c\'è già un apparato.') end

    if not g:Sottrai('banca', AUT.Telepass.canoneAttivazione, 'attivazione Telepass') then
        return rispondi(false, ('Servono %s di canone.'):format(U.Euro(AUT.Telepass.canoneAttivazione)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(AUT.Lavoro, AUT.Telepass.canoneAttivazione, 'canoni Telepass')
    end)

    local codice = ('TP%s'):format(U.Random(8, '0123456789'))
    MySQL.insert.await(
        'INSERT INTO telepass (citizenid, targa, codice) VALUES (?, ?, ?)',
        { g.citizenid, targa, codice })

    rispondi(true, ('Apparato %s attivato su %s. Sconto del %d%% sul pedaggio, addebito a posteriori.')
        :format(codice, targa, math.floor(AUT.Telepass.sconto * 100)))
end)

-- ---------------------------------------------------------------------------
--  Ingresso in autostrada
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('aut:entra', function(src, rispondi, idCasello, targa, categoria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local casello = AUT.GetCasello(idCasello)
    if not casello then return rispondi(false, 'Casello inesistente.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - casello.coord) > AUT.raggioCasello then
        return rispondi(false, 'Non sei al casello.')
    end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    if targa == '' then return rispondi(false, 'Targa non leggibile.') end

    -- Un transito già aperto su questa targa: si chiude d'ufficio, come
    -- succede a chi esce da un'uscita senza casello e rientra altrove.
    local aperto = MySQL.single.await(
        'SELECT id FROM autostrade_transiti WHERE targa = ? AND stato = ?', { targa, 'aperto' })
    if aperto then
        return rispondi(false, 'Risulta già un transito aperto su questa targa: prima va chiuso a un\'uscita.')
    end

    -- La categoria la si ricava dal veicolo immatricolato, non da quello
    -- che dice il client: la classe tariffaria è soldi.
    local v = MySQL.single.await('SELECT categoria FROM veicoli WHERE targa = ?', { targa })
    local classe = AUT.ClasseDi(v and v.categoria or tostring(categoria or 'auto'))

    local t = telepassDi(targa)

    MySQL.insert.await([[
        INSERT INTO autostrade_transiti (targa, citizenid, ingresso, classe, stato)
        VALUES (?, ?, ?, ?, 'aperto')
    ]], { targa, g.citizenid, casello.id, classe })

    rispondi(true, ('%s — %s.\n%s')
        :format(casello.nome, (AUT.Classi[classe] or {}).nome or classe,
                t and t.attivo == 1 and 'Telepass riconosciuto: all\'uscita non ti fermi.'
                                    or 'Biglietto ritirato: conservalo fino all\'uscita.'),
        classe)
end)

-- ---------------------------------------------------------------------------
--  Uscita
-- ---------------------------------------------------------------------------
local function chiudi(transito, caselloUscita, pedaggio, stato)
    MySQL.update.await([[
        UPDATE autostrade_transiti
        SET uscita = ?, uscito_il = NOW(), pedaggio = ?, stato = ?
        WHERE id = ?
    ]], { caselloUscita, pedaggio, stato, transito.id })
end

AUREA.Callback.Registra('aut:esce', function(src, rispondi, idCasello, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local casello = AUT.GetCasello(idCasello)
    if not casello then return rispondi(false, 'Casello inesistente.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - casello.coord) > AUT.raggioCasello then
        return rispondi(false, 'Non sei al casello.')
    end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local t = MySQL.single.await([[
        SELECT id, targa, citizenid, ingresso, classe,
               TIMESTAMPDIFF(MINUTE, entrato_il, NOW()) AS minuti
        FROM autostrade_transiti WHERE targa = ? AND stato = 'aperto' LIMIT 1
    ]], { targa })
    if not t then
        return rispondi(false, 'Nessun transito aperto su questa targa: risulta che non sei mai entrato.')
    end

    local ingresso = AUT.GetCasello(t.ingresso)
    local km = math.abs((casello.km or 0) - ((ingresso and ingresso.km) or 0))
    km = math.max(km, AUT.Regole.kmMinimiFatturati)

    -- Biglietto perduto: troppo tempo dentro, si paga la tratta massima
    if (t.minuti or 0) > AUT.Regole.minutiTransitoMassimo then
        km = AUT.Regole.kmBigliettoPerduto
    end

    local pedaggio = AUT.Pedaggio(t.classe, km)
    local apparato = telepassDi(targa)
    local conTelepass = apparato ~= nil and apparato.attivo == 1

    if conTelepass then
        pedaggio = math.floor(pedaggio * (1 - AUT.Telepass.sconto))
    end

    -- Con il Telepass si passa e si addebita dopo; senza, si paga adesso
    if conTelepass then
        local pagato = AUREA.Denaro.SottraiOffline(apparato.citizenid, 'banca', pedaggio,
            ('pedaggio %s → %s'):format(t.ingresso, casello.id))

        if pagato then
            chiudi(t, casello.id, pedaggio, 'telepass')
            pcall(function()
                exports.aurea_azienda:VersaInCassa(AUT.Lavoro, pedaggio, 'pedaggi')
            end)
        else
            MySQL.update.await('UPDATE telepass SET insoluto = insoluto + ? WHERE id = ?',
                { pedaggio, apparato.id })
            chiudi(t, casello.id, pedaggio, 'insoluto')

            local insoluto = (apparato.insoluto or 0) + pedaggio
            if insoluto >= AUT.Telepass.insolutoMassimo then
                MySQL.update.await('UPDATE telepass SET attivo = 0 WHERE id = ?', { apparato.id })
                TriggerEvent('aurea:telefono:messaggioSistema', apparato.citizenid, 'Telepass',
                    ('Apparato disattivato: insoluto di %s. Da adesso paghi al casello.')
                        :format(U.Euro(insoluto)))
            end
        end

        return rispondi(true, ('%s — %d km, pedaggio %s.\n%s')
            :format(casello.nome, km, U.Euro(pedaggio),
                    pagato and 'Addebitato sul conto.' or 'Conto scoperto: resta insoluto.'))
    end

    if not g:SottraiOvunque(pedaggio, ('pedaggio %s → %s'):format(t.ingresso, casello.id)) then
        chiudi(t, casello.id, pedaggio, 'insoluto')
        return rispondi(false, ('Il pedaggio è %s per %d km e non li hai.\nIl transito resta insoluto: la concessionaria lo mette a ruolo.')
            :format(U.Euro(pedaggio), km))
    end

    chiudi(t, casello.id, pedaggio, 'pagato')
    pcall(function()
        exports.aurea_azienda:VersaInCassa(AUT.Lavoro, pedaggio, 'pedaggi')
    end)

    rispondi(true, ('%s — %d km da %s.\nPedaggio %s, pagato.')
        :format(casello.nome, km, ingresso and ingresso.nome or t.ingresso, U.Euro(pedaggio)))
end)

-- ---------------------------------------------------------------------------
--  Forzare la sbarra
--
--  Art. 176 c. 11 CdS. Non annulla il pedaggio: aggiunge un verbale.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('aut:forza', function(src, rispondi, idCasello, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local casello = AUT.GetCasello(idCasello)
    if not casello then return rispondi(false) end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local t = MySQL.single.await(
        'SELECT id, classe, ingresso FROM autostrade_transiti WHERE targa = ? AND stato = ? LIMIT 1',
        { targa, 'aperto' })

    local km = AUT.Regole.kmBigliettoPerduto
    if t then
        local ingresso = AUT.GetCasello(t.ingresso)
        km = math.max(math.abs((casello.km or 0) - ((ingresso and ingresso.km) or 0)),
                      AUT.Regole.kmMinimiFatturati)
        chiudi(t, casello.id, AUT.Pedaggio(t.classe, km), 'insoluto')
    else
        -- Forzare l'uscita senza essere mai entrato da un casello: si
        -- fattura la tratta massima, e il verbale è lo stesso.
        MySQL.insert.await([[
            INSERT INTO autostrade_transiti
                (targa, citizenid, ingresso, uscita, uscito_il, classe, pedaggio, stato)
            VALUES (?, ?, 'ignoto', ?, NOW(), 'B', ?, 'insoluto')
        ]], { targa, g.citizenid, casello.id, AUT.Pedaggio('B', km) })
    end

    local infrazione = AUREA.Infrazioni[AUT.Regole.infrazione]
    exports.ita_codicestrada:EmettiVerbale({
        citizenid = g.citizenid, targa = targa ~= '' and targa or nil,
        articolo = infrazione.articolo,
        descrizione = ('%s — %s'):format(infrazione.nome, casello.nome),
        importo = infrazione.importo, punti = infrazione.punti,
        origine = 'semaforo', agente = 'rilevamento automatico', luogo = casello.nome,
    })

    exports.aurea_ui:NotificaLavoro(AUT.Lavoro, {
        tipo = 'avviso', icona = '🛣', durata = 14000,
        titolo = 'Sbarra forzata',
        testo = ('%s a %s. Pedaggio insoluto e verbale emesso.'):format(targa, casello.nome),
    }, false)

    AUREA.Log('multe', 'avviso', g, ('sbarra forzata a %s con %s'):format(casello.nome, targa))
    rispondi(true, ('Sbarra forzata. Verbale art. 176 CdS: %s.\nIl pedaggio resta dovuto.')
        :format(U.Euro(infrazione.importo)))
end)

-- ---------------------------------------------------------------------------
--  Gli insoluti finiscono a ruolo
--
--  È il passaggio che trasforma un debito con una concessionaria in una
--  cartella dello Stato. Da lì in poi non se ne occupa più il casello.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(AUT.Insoluti.minutiScansione * 60000)

        local righe = MySQL.query.await([[
            SELECT id, targa, citizenid, ingresso, uscita, pedaggio
            FROM autostrade_transiti
            WHERE stato = 'insoluto'
              AND citizenid IS NOT NULL
              AND pedaggio >= ?
              AND TIMESTAMPDIFF(MINUTE, uscito_il, NOW()) >= ?
            LIMIT 25
        ]], { AUT.Insoluti.sogliaRuolo, AUT.Insoluti.minutiPrimaDelRuolo }) or {}

        for _, r in ipairs(righe) do
            local iscritto = nil
            pcall(function()
                iscritto = exports.ita_riscossione:IscriviARuolo(r.citizenid, 'sanzione', r.id,
                    ('Pedaggio autostradale %s → %s'):format(r.ingresso, r.uscita or '—'),
                    r.pedaggio)
            end)

            if iscritto then
                -- Dal punto di vista della concessionaria il conto è
                -- chiuso: il credito è passato all'agente della
                -- riscossione, e da lì in poi è una cartella.
                MySQL.update.await(
                    'UPDATE autostrade_transiti SET stato = \'pagato\' WHERE id = ?', { r.id })

                TriggerEvent('aurea:telefono:messaggioSistema', r.citizenid, 'Autostrade',
                    ('Pedaggio insoluto di %s messo a ruolo. Adesso è una cartella, non una bolletta.')
                        :format(U.Euro(r.pedaggio)))
            end
            -- Se la riscossione è ferma il transito resta insoluto e ci
            -- si riprova al giro dopo: niente si condona da solo.
        end

        -- I transiti rimasti aperti troppo a lungo si chiudono d'ufficio
        -- alla tariffa massima: nessuno resta dentro per sempre.
        local dimenticati = MySQL.query.await([[
            SELECT id, targa, classe FROM autostrade_transiti
            WHERE stato = 'aperto' AND TIMESTAMPDIFF(MINUTE, entrato_il, NOW()) > ?
            LIMIT 25
        ]], { AUT.Regole.minutiTransitoMassimo * 2 }) or {}

        for _, d in ipairs(dimenticati) do
            MySQL.update.await([[
                UPDATE autostrade_transiti
                SET uscita = 'ufficio', uscito_il = NOW(), pedaggio = ?, stato = 'insoluto'
                WHERE id = ?
            ]], { AUT.Pedaggio(d.classe, AUT.Regole.kmBigliettoPerduto), d.id })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il quadro della tratta, per chi ci lavora
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('aut:tratta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not esattore(g) then return rispondi(nil) end

    local aperti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM autostrade_transiti WHERE stato = ?', { 'aperto' }) or 0
    local insoluti = MySQL.single.await([[
        SELECT COUNT(*) AS quanti, COALESCE(SUM(pedaggio), 0) AS totale
        FROM autostrade_transiti WHERE stato = 'insoluto'
    ]]) or { quanti = 0, totale = 0 }
    local incassato = MySQL.scalar.await([[
        SELECT COALESCE(SUM(pedaggio), 0) FROM autostrade_transiti
        WHERE stato IN ('pagato','telepass')
    ]]) or 0

    rispondi({
        aperti = aperti,
        insolutiQuanti = insoluti.quanti or 0,
        insolutiTotale = insoluti.totale or 0,
        incassato = incassato,
    })
end)
