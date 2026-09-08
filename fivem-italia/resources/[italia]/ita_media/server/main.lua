--[[
    AUREA · Media (server)

    La testata pubblica, i cittadini leggono, e chi è stato raccontato male
    ha due strade: la rettifica o la querela. Entrambe hanno un prezzo per
    la redazione, ed è questo che rende il giornalismo una scelta e non un
    canale di annunci.
]]

local U = AUREA.Util
local ultimoPezzo = {}      -- [citizenid] = os.time()
local diretta = nil         -- { conduttore, operatore, titolo, iniziata }

-- ---------------------------------------------------------------------------
--  Cassa della testata
-- ---------------------------------------------------------------------------
local function leggiStato(chiave, predefinito)
    local v = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?', { 'media_' .. chiave })
    return v ~= nil and v or predefinito
end

local function scriviStato(chiave, valore)
    MySQL.query.await([[
        INSERT INTO economia_stato (chiave, valore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { 'media_' .. chiave, tostring(valore) })
end

local function cassa()
    return tonumber(leggiStato('cassa', 0)) or 0
end

local function versaInCassa(importo)
    scriviStato('cassa', cassa() + math.floor(importo))
end

--- Preleva dalla cassa. Se non basta, la testata va in rosso: è un dato,
--- non un errore — il caporedattore lo vede e deve rimediare.
local function prelevaDaCassa(importo)
    local saldo = cassa()
    scriviStato('cassa', saldo - math.floor(importo))
    return saldo >= importo
end

exports('CassaTestata', cassa)

-- ---------------------------------------------------------------------------
--  Lettura del giornale
-- ---------------------------------------------------------------------------
local function edizione(limite)
    local righe = MySQL.query.await([[
        SELECT a.id, a.sezione, a.titolo, a.occhiello, a.testo, a.firma, a.tipo,
               a.rettifica_di, a.pubblicato_il
        FROM articoli a
        WHERE a.ritirato = 0
        ORDER BY a.id DESC LIMIT ?
    ]], { limite or MED.Articoli.inPrimaPagina }) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.pubblicato_il or 0) / 1000))
        local s = MED.GetSezione(r.sezione)
        r.sezioneNome = s and s.nome or r.sezione
        r.icona = s and s.icona or '📰'
    end
    return righe
end

local function inserzioniVive()
    return MySQL.query.await([[
        SELECT id, inserzionista, formato, testo FROM inserzioni
        WHERE edizioni_residue > 0 ORDER BY id DESC LIMIT ?
    ]], { MED.Inserzioni.perEdizione }) or {}
end

AUREA.Callback.Registra('med:edizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    rispondi({
        testata = MED.Testata.nome,
        sottotitolo = MED.Testata.sottotitolo,
        articoli = edizione(),
        inserzioni = inserzioniVive(),
        eRedazione = g.lavoro.nome == MED.Testata.lavoro,
    })
end)

AUREA.Callback.Registra('med:archivio', function(src, rispondi, sezione)
    local righe = MySQL.query.await([[
        SELECT id, sezione, titolo, occhiello, firma, pubblicato_il
        FROM articoli
        WHERE ritirato = 0 AND (? = '' OR sezione = ?)
        ORDER BY id DESC LIMIT ?
    ]], { sezione or '', sezione or '', MED.Articoli.archivio }) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.pubblicato_il or 0) / 1000))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('med:articolo', function(src, rispondi, id)
    local r = MySQL.single.await('SELECT * FROM articoli WHERE id = ? AND ritirato = 0', { id })
    if not r then return rispondi(nil) end
    r.quando = U.DataOraIT(math.floor((r.pubblicato_il or 0) / 1000))
    rispondi(r)
end)

--- Acquisto della copia all'edicola.
AUREA.Callback.Registra('med:compra', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if not MED.EdicolaVicina(coord, 4.0) then
        return rispondi(false, 'Non sei davanti a un\'edicola.')
    end

    if not g:SottraiOvunque(MED.Copia.prezzo, 'quotidiano') then
        return rispondi(false, ('La copia costa %s.'):format(U.Euro(MED.Copia.prezzo)))
    end

    local aggiunto = exports.aurea_inventory:Aggiungi(g.citizenid, MED.Copia.item, 1, {
        testata = MED.Testata.nome,
        edizione = os.date('%d/%m/%Y %H:%M'),
    })
    if not aggiunto then
        g:Aggiungi('contanti', MED.Copia.prezzo, 'rimborso copia')
        return rispondi(false, 'Non hai spazio per il giornale.')
    end

    local quota = math.floor(MED.Copia.prezzo * MED.Copia.quotaTestata)
    versaInCassa(quota)
    TriggerEvent('aurea:fisco:incasso', 'iva_editoria', MED.Copia.prezzo - quota, g.citizenid)

    rispondi(true, 'Buona lettura.')
end)

-- ---------------------------------------------------------------------------
--  Pubblicazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:pubblica', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if g.lavoro.nome ~= MED.Testata.lavoro or not g:HaPermessoLavoro('pubblica') then
        return rispondi(false, 'Solo chi è iscritto all\'ordine può firmare un pezzo.')
    end

    local adesso = os.time()
    local ultimo = ultimoPezzo[g.citizenid] or 0
    if (adesso - ultimo) < MED.Articoli.attesaFraPezzi then
        return rispondi(false, ('Devi ancora aspettare %d secondi prima del prossimo pezzo.')
            :format(MED.Articoli.attesaFraPezzi - (adesso - ultimo)))
    end

    if not MED.GetSezione(dati.sezione) then return rispondi(false, 'Sezione non prevista.') end

    local titolo = tostring(dati.titolo or ''):sub(1, MED.Articoli.titoloMassimo)
    local occhiello = tostring(dati.occhiello or ''):sub(1, 120)
    local testo = tostring(dati.testo or ''):sub(1, MED.Articoli.lunghezzaMassima)

    if #titolo < 6 then return rispondi(false, 'Il titolo è troppo corto.') end
    if #testo < 60 then return rispondi(false, 'Il pezzo è troppo scarno per andare in stampa.') end

    local id = MySQL.insert.await([[
        INSERT INTO articoli (sezione, titolo, occhiello, testo, firma, autore, tipo)
        VALUES (?, ?, ?, ?, ?, ?, 'articolo')
    ]], { dati.sezione, titolo, occhiello, testo, g:NomeCompleto(), g.citizenid })

    ultimoPezzo[g.citizenid] = adesso

    -- Compenso a pezzo, a carico della testata
    local compenso = g.lavoro.grado >= 2 and MED.Articoli.compenso.caporedattore
        or (g.lavoro.grado >= 1 and MED.Articoli.compenso.cronista or MED.Articoli.compenso.praticante)

    local ritenuta = math.floor(compenso * 0.2)
    prelevaDaCassa(compenso)
    g:Aggiungi('banca', compenso - ritenuta, 'compenso a pezzo')
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    -- Le inserzioni consumano una edizione
    MySQL.update('UPDATE inserzioni SET edizioni_residue = edizioni_residue - 1 WHERE edizioni_residue > 0')

    local sezione = MED.GetSezione(dati.sezione)
    TriggerClientEvent('med:nuovaEdizione', -1, {
        icona = sezione.icona, sezione = sezione.nome, titolo = titolo, firma = g:NomeCompleto(),
    })

    AUREA.Log('economia', 'info', g, ('ha pubblicato "%s" in %s'):format(titolo, dati.sezione))
    rispondi(true, ('Pezzo in edicola. Compenso netto: %s (ritenuta %s).')
        :format(U.Euro(compenso - ritenuta), U.Euro(ritenuta)), id)
end)

--- Ritiro di un pezzo, riservato alla direzione.
AUREA.Callback.Registra('med:ritira', function(src, rispondi, id, motivo)
    local g = AUREA.GetPlayer(src)
    if not g or not g:HaPermessoLavoro('diretta') then return rispondi(false, 'Non autorizzato.') end

    local aggiornate = MySQL.update.await(
        'UPDATE articoli SET ritirato = 1, nota_direzione = ? WHERE id = ?',
        { tostring(motivo or ''):sub(1, 200), id })
    if (aggiornate or 0) == 0 then return rispondi(false, 'Articolo non trovato.') end

    AUREA.Log('staff', 'avviso', g, ('ha ritirato l\'articolo %d'):format(id))
    rispondi(true, 'Articolo ritirato dall\'edizione.')
end)

-- ---------------------------------------------------------------------------
--  Rettifica (art. 8 legge 47/1948)
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:chiediRettifica', function(src, rispondi, idArticolo, testo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local articolo = MySQL.single.await(
        'SELECT id, titolo, autore, UNIX_TIMESTAMP(pubblicato_il) AS quando FROM articoli WHERE id = ? AND ritirato = 0',
        { idArticolo })
    if not articolo then return rispondi(false, 'Articolo non trovato.') end

    if (os.time() - (articolo.quando or 0)) > MED.Rettifica.entroSecondi then
        return rispondi(false, 'Il termine per chiedere la rettifica è scaduto.')
    end
    if articolo.autore == g.citizenid then return rispondi(false, 'Non puoi rettificare te stesso.') end

    local esistente = MySQL.scalar.await(
        'SELECT id FROM rettifiche WHERE articolo_id = ? AND richiedente = ?', { idArticolo, g.citizenid })
    if esistente then return rispondi(false, 'Hai già chiesto la rettifica di questo pezzo.') end

    MySQL.insert.await([[
        INSERT INTO rettifiche (articolo_id, richiedente, nome_richiedente, testo)
        VALUES (?, ?, ?, ?)
    ]], { idArticolo, g.citizenid, g:NomeCompleto(),
          tostring(testo or ''):sub(1, MED.Rettifica.lunghezzaMassima) })

    exports.aurea_ui:NotificaLavoro(MED.Testata.lavoro, {
        tipo = 'avviso', icona = '✍', durata = 16000,
        titolo = 'Richiesta di rettifica',
        testo = ('%s chiede la rettifica di "%s". Va pubblicata entro un\'ora o la testata risponde.')
            :format(g:NomeCompleto(), articolo.titolo),
    }, false)

    rispondi(true, 'Richiesta trasmessa alla redazione.')
end)

AUREA.Callback.Registra('med:rettifiche', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= MED.Testata.lavoro then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT r.id, r.articolo_id, r.nome_richiedente, r.testo, r.stato,
               UNIX_TIMESTAMP(r.chiesta_il) AS quando, a.titolo
        FROM rettifiche r JOIN articoli a ON a.id = r.articolo_id
        WHERE r.stato = 'attesa' ORDER BY r.id ASC LIMIT 20
    ]]) or {}

    local adesso = os.time()
    for _, r in ipairs(righe) do
        local trascorsi = adesso - (r.quando or adesso)
        r.minutiResidui = math.max(0, math.floor((MED.Rettifica.terminePubblicazione - trascorsi) / 60))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('med:pubblicaRettifica', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g or not g:HaPermessoLavoro('pubblica') then return rispondi(false, 'Non autorizzato.') end

    local r = MySQL.single.await(
        'SELECT * FROM rettifiche WHERE id = ? AND stato = \'attesa\'', { id })
    if not r then return rispondi(false, 'Richiesta non trovata.') end

    local articolo = MySQL.single.await('SELECT titolo, sezione FROM articoli WHERE id = ?', { r.articolo_id })

    MySQL.insert.await([[
        INSERT INTO articoli (sezione, titolo, occhiello, testo, firma, autore, tipo, rettifica_di)
        VALUES (?, ?, 'Diritto di rettifica', ?, ?, ?, 'rettifica', ?)
    ]], {
        articolo and articolo.sezione or 'cronaca',
        ('Rettifica: %s'):format(articolo and articolo.titolo or 'articolo'),
        r.testo, r.nome_richiedente, r.richiedente, r.articolo_id,
    })

    MySQL.update.await('UPDATE rettifiche SET stato = \'pubblicata\' WHERE id = ?', { id })

    local soggetto = AUREA.GetPlayerByCitizenId(r.richiedente)
    if soggetto then
        TriggerClientEvent('aurea:ui:notifica', soggetto.source, {
            tipo = 'successo', icona = '✍', durata = 13000,
            titolo = 'Rettifica pubblicata',
            testo = 'La redazione ha dato spazio alla tua versione dei fatti.',
        })
    end

    rispondi(true, 'Rettifica in edizione.')
end)

--- Chi non rettifica nei termini paga. Il controllo gira ogni cinque minuti.
CreateThread(function()
    while true do
        Wait(300000)

        local scadute = MySQL.query.await(([[
            SELECT id, articolo_id FROM rettifiche
            WHERE stato = 'attesa' AND chiesta_il < DATE_SUB(NOW(), INTERVAL %d SECOND)
        ]]):format(MED.Rettifica.terminePubblicazione)) or {}

        for _, r in ipairs(scadute) do
            MySQL.update.await('UPDATE rettifiche SET stato = \'omessa\' WHERE id = ?', { r.id })
            prelevaDaCassa(MED.Rettifica.sanzioneOmissione)
            TriggerEvent('aurea:fisco:incasso', 'sanzioni_stampa', MED.Rettifica.sanzioneOmissione)

            exports.aurea_ui:NotificaLavoro(MED.Testata.lavoro, {
                tipo = 'errore', icona = '⚖', durata = 16000,
                titolo = 'Omessa rettifica',
                testo = ('La testata è stata sanzionata di %s per non aver pubblicato una rettifica.')
                    :format(U.Euro(MED.Rettifica.sanzioneOmissione)),
            }, false)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Querela per diffamazione a mezzo stampa (art. 595 c.3 c.p.)
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:querela', function(src, rispondi, idArticolo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local articolo = MySQL.single.await([[
        SELECT id, titolo, autore, firma, UNIX_TIMESTAMP(pubblicato_il) AS quando
        FROM articoli WHERE id = ?
    ]], { idArticolo })
    if not articolo then return rispondi(false, 'Articolo non trovato.') end
    if articolo.autore == g.citizenid then return rispondi(false, 'Non puoi querelare te stesso.') end

    if (os.time() - (articolo.quando or 0)) > MED.Diffamazione.entroSecondi then
        return rispondi(false, 'Il termine per la querela è decorso.')
    end

    local esistente = MySQL.scalar.await(
        'SELECT id FROM rettifiche WHERE articolo_id = ? AND richiedente = ? AND stato = \'querelata\'',
        { idArticolo, g.citizenid })
    if esistente then return rispondi(false, 'Hai già querelato questo pezzo.') end

    MySQL.insert.await([[
        INSERT INTO rettifiche (articolo_id, richiedente, nome_richiedente, testo, stato)
        VALUES (?, ?, ?, 'Querela per diffamazione a mezzo stampa.', 'querelata')
    ]], { idArticolo, g.citizenid, g:NomeCompleto() })

    exports.ita_giustizia:ApriFascicolo(articolo.autore, MED.Diffamazione.articolo,
        'querela di parte', ('Querela di %s per l\'articolo "%s".'):format(g:NomeCompleto(), articolo.titolo))

    -- La testata risponde in solido: il risarcimento esce dalla cassa
    prelevaDaCassa(MED.Diffamazione.risarcimento)
    AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', MED.Diffamazione.risarcimento,
        'risarcimento del danno da diffamazione')

    exports.aurea_ui:NotificaLavoro(MED.Testata.lavoro, {
        tipo = 'errore', icona = '⚖', durata = 18000,
        titolo = 'Querela contro la testata',
        testo = ('%s ha querelato per "%s". Risarcimento di %s a carico della cassa.')
            :format(g:NomeCompleto(), articolo.titolo, U.Euro(MED.Diffamazione.risarcimento)),
    }, false)

    AUREA.Log('giustizia', 'avviso', g, ('querela ex art. 595 c.p. per l\'articolo %d'):format(idArticolo))
    rispondi(true, 'Querela depositata. Il fascicolo è a carico di chi ha firmato il pezzo.')
end)

-- ---------------------------------------------------------------------------
--  Inserzioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:formati', function(src, rispondi)
    local out = {}
    for id, f in pairs(MED.Inserzioni.formati) do
        out[#out + 1] = { id = id, nome = f.nome, costo = f.costo, edizioni = f.edizioni }
    end
    table.sort(out, function(a, b) return a.costo < b.costo end)
    rispondi(out)
end)

AUREA.Callback.Registra('med:inserzione', function(src, rispondi, formato, testo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local f = MED.Inserzioni.formati[formato]
    if not f then return rispondi(false, 'Formato non previsto.') end

    testo = tostring(testo or ''):sub(1, MED.Inserzioni.testoMassimo)
    if #testo < 10 then return rispondi(false, 'Scrivi almeno una riga di annuncio.') end

    if not g:SottraiOvunque(f.costo, ('inserzione %s'):format(f.nome)) then
        return rispondi(false, ('Il formato costa %s.'):format(U.Euro(f.costo)))
    end

    local netto = math.floor(f.costo * 0.78)
    versaInCassa(netto)
    TriggerEvent('aurea:fisco:incasso', 'iva_editoria', f.costo - netto, g.citizenid)

    MySQL.insert.await([[
        INSERT INTO inserzioni (inserzionista, citizenid, formato, testo, edizioni_residue)
        VALUES (?, ?, ?, ?, ?)
    ]], { g:NomeCompleto(), g.citizenid, formato, testo, f.edizioni })

    rispondi(true, ('Inserzione acquistata: uscirà nelle prossime %d edizioni.'):format(f.edizioni))
end)

-- ---------------------------------------------------------------------------
--  Diretta televisiva
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:avviaDiretta', function(src, rispondi, titolo, operatoreSrc)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if g.lavoro.nome ~= MED.Testata.lavoro or not g:HaPermessoLavoro(MED.Diretta.permesso) then
        return rispondi(false, 'Solo la direzione può aprire un collegamento.')
    end
    if diretta then return rispondi(false, ('È già in onda: "%s".'):format(diretta.titolo)) end

    local operatore = nil
    if MED.Diretta.richiedeOperatore then
        operatore = AUREA.GetPlayer(tonumber(operatoreSrc))
        if not operatore or operatore.lavoro.nome ~= MED.Testata.lavoro then
            return rispondi(false, 'Serve un operatore della redazione accanto a te.')
        end
        local distanza = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(operatore.source)))
        if distanza > MED.Diretta.distanzaOperatore then
            return rispondi(false, 'L\'operatore è troppo lontano.')
        end
    end

    diretta = {
        conduttore = src,
        operatore = operatore and operatore.source or nil,
        titolo = tostring(titolo or ''):sub(1, 90),
        iniziata = GetGameTimer(),
    }

    TriggerClientEvent('med:direttaIniziata', -1, {
        testata = MED.Testata.nome,
        titolo = diretta.titolo,
        conduttore = g:NomeCompleto(),
        colore = MED.Diretta.coloreFascia,
    })

    AUREA.Log('economia', 'info', g, ('ha aperto la diretta "%s"'):format(diretta.titolo))
    rispondi(true, 'Sei in onda.')
end)

local function chiudiDiretta(motivo)
    if not diretta then return end
    diretta = nil
    TriggerClientEvent('med:direttaChiusa', -1, motivo)
end

AUREA.Callback.Registra('med:chiudiDiretta', function(src, rispondi)
    if not diretta then return rispondi(false, 'Non c\'è nessun collegamento aperto.') end
    if diretta.conduttore ~= src and diretta.operatore ~= src then
        local g = AUREA.GetPlayer(src)
        if not (g and g:HaPermessoLavoro(MED.Diretta.permesso)) then
            return rispondi(false, 'Non sei tu a condurre.')
        end
    end
    chiudiDiretta('Il collegamento è terminato.')
    rispondi(true, 'Collegamento chiuso.')
end)

--- La diretta non regge senza chi la tiene in piedi.
CreateThread(function()
    while true do
        Wait(4000)
        if diretta then
            local conduttoreVivo = AUREA.GetPlayer(diretta.conduttore) ~= nil
            local operatoreVivo = (not diretta.operatore) or AUREA.GetPlayer(diretta.operatore) ~= nil
            local scaduta = (GetGameTimer() - diretta.iniziata) > MED.Diretta.durataMassima

            if not conduttoreVivo or not operatoreVivo then
                chiudiDiretta('Il collegamento è caduto.')
            elseif scaduta then
                chiudiDiretta('Il collegamento è terminato.')
            end
        end
    end
end)

AUREA.Callback.Registra('med:statoDiretta', function(src, rispondi)
    if not diretta then return rispondi(nil) end
    local conduttore = AUREA.GetPlayer(diretta.conduttore)
    rispondi({
        testata = MED.Testata.nome,
        titolo = diretta.titolo,
        conduttore = conduttore and conduttore:NomeCompleto() or '—',
        colore = MED.Diretta.coloreFascia,
    })
end)

-- ---------------------------------------------------------------------------
--  Cassa e bilancio della testata
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:bilancio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= MED.Testata.lavoro then return rispondi(nil) end

    local pezzi = MySQL.scalar.await('SELECT COUNT(*) FROM articoli WHERE ritirato = 0') or 0
    local rettificheOmesse = MySQL.scalar.await('SELECT COUNT(*) FROM rettifiche WHERE stato = \'omessa\'') or 0
    local querele = MySQL.scalar.await('SELECT COUNT(*) FROM rettifiche WHERE stato = \'querelata\'') or 0

    rispondi({
        cassa = cassa(),
        pezzi = pezzi,
        rettificheOmesse = rettificheOmesse,
        querele = querele,
        eDirezione = g:HaPermessoLavoro('diretta'),
    })
end)

--- Il tesserino dell'ordine, rilasciato dal caporedattore.
AUREA.Callback.Registra('med:tesserino', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not altro then return rispondi(false, 'Persona non trovata.') end
    if not g:HaPermessoLavoro('assumi') then return rispondi(false, 'Non hai il titolo per rilasciarlo.') end

    TriggerEvent('aurea:inventario:aggiungi', altro.citizenid, 'tesserino_stampa', 1, {
        intestatario = altro:NomeCompleto(),
        testata = MED.Testata.nome,
        rilasciato = os.date('%d/%m/%Y'),
    })

    rispondi(true, ('Tesserino rilasciato a %s.'):format(altro:NomeCompleto()))
end)

-- Leggere la copia che si ha in tasca apre l'edizione, e non la consuma.
CreateThread(function()
    Wait(1500)
    exports.aurea_inventory:RegistraUso(MED.Copia.item, function(g)
        TriggerClientEvent('med:apriEdizione', g.source)
        return false
    end)
end)

AddEventHandler('playerDropped', function()
    if diretta and (diretta.conduttore == source or diretta.operatore == source) then
        chiudiDiretta('Il collegamento è caduto.')
    end
end)

-- ---------------------------------------------------------------------------
--  App sul telefono: il quotidiano
--
--  Si legge, non si scrive. Scrivere resta un atto che si fa in redazione,
--  perché un articolo pubblicato dal telefono mentre si scappa non è
--  giornalismo.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'quotidiano',
    nome = 'Quotidiano',
    icona = '📰',
    colore = 'linear-gradient(150deg,#8a8377,#514c44)',
    ordine = 140,

    schermata = function(g, argomenti)
        argomenti = argomenti or {}

        if argomenti.id then
            local a = MySQL.single.await(
                'SELECT * FROM articoli WHERE id = ? AND ritirato = 0 LIMIT 1',
                { tonumber(argomenti.id) or 0 })
            if not a then
                return { tipo = 'testo', titolo = 'Articolo',
                         corpo = 'L\'articolo non è più disponibile: può essere stato ritirato.' }
            end

            return {
                tipo = 'testo',
                titolo = a.titolo,
                sottotitolo = ('%s · di %s'):format(a.sezione or 'cronaca', a.firma or 'redazione'),
                corpo = ('%s\n\n%s'):format(a.occhiello or '', a.testo or ''),
            }
        end

        local voci = {}
        for _, a in ipairs(MySQL.query.await([[
            SELECT id, titolo, occhiello, firma, sezione, tipo
            FROM articoli WHERE ritirato = 0
            ORDER BY id DESC LIMIT 25
        ]]) or {}) do
            voci[#voci + 1] = {
                icona = a.tipo == 'rettifica' and '⚖' or '📰',
                titolo = a.titolo,
                sottotitolo = ('%s\n%s · %s'):format(
                    (a.occhiello or ''):sub(1, 90), a.sezione or 'cronaca',
                    a.firma or 'redazione'),
                apri = { id = a.id },
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '📰', titolo = 'Nessun articolo pubblicato',
                        sottotitolo = 'La redazione non ha ancora mandato in stampa.',
                        inerte = true }
        end

        return { tipo = 'lista', sottotitolo = 'Ultime notizie', voci = voci }
    end,
})
