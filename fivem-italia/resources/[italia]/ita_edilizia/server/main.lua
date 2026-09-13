--[[
    AUREA · Edilizia e sicurezza sul lavoro (server)

    Il cantiere vive qui: avanzamento, materiali consumati, rischio
    accumulato e infortuni li decide il server. Il client chiede di fare
    una lavorazione e riceve un esito — non lo propone.

    Questo conta più del solito, perché qui il client avrebbe due cose
    ghiotte da falsificare: dire di avere i DPI addosso, e dire di aver
    finito una fase. La prima la verifica l'inventario lato server, la
    seconda è un contatore che sta solo qui.
]]

local U = AUREA.Util

local cantieri = {}     -- [lottoId] = riga di edilizia_cantieri, tenuta in memoria
local permessiAttesa = {}   -- [citizenid] = { lotto, protocollo, scade }

-- ---------------------------------------------------------------------------
--  Chi è chi
-- ---------------------------------------------------------------------------
local function edile(g, permesso)
    if not g or g.lavoro.nome ~= EDI.Lavoro then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

local function vigile(g)
    if not g or not g.lavoro.servizio then return false end
    for _, l in ipairs(EDI.Vigilanza.lavori) do
        if g.lavoro.nome == l then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
--  Caricamento
-- ---------------------------------------------------------------------------
local function carica()
    local righe = MySQL.query.await([[
        SELECT * FROM edilizia_cantieri WHERE stato IN ('aperto','sospeso')
    ]]) or {}

    for _, c in ipairs(righe) do
        -- La sospensione riprende da dove era: riaprire il server non è
        -- un modo per far decadere un provvedimento.
        if c.sospeso_fino then
            local a, m, gg, h, mi, sec = tostring(c.sospeso_fino):match(
                '(%d+)-(%d+)-(%d+)[ T](%d+):(%d+):(%d+)')
            if a then
                c.sospesoFino = os.time({ year = tonumber(a), month = tonumber(m), day = tonumber(gg),
                                          hour = tonumber(h), min = tonumber(mi), sec = tonumber(sec) })
            end
        end
        c.sospeso_fino = nil
        cantieri[c.lotto] = c
    end

    print(('[AUREA] edilizia: %d cantieri aperti'):format(#righe))
end

AddEventHandler('onResourceStart', function(risorsa)
    if risorsa == GetCurrentResourceName() then
        CreateThread(function() Wait(2500) carica() end)
    end
end)

local function salva(c)
    MySQL.update([[
        UPDATE edilizia_cantieri
        SET fase = ?, lavorazioni = ?, rischio = ?, ponteggio = ?, pos = ?,
            stato = ?, sospeso_fino = ?
        WHERE id = ?
    ]], { c.fase, c.lavorazioni, c.rischio, c.ponteggio, c.pos, c.stato,
          c.sospesoFino and os.date('%Y-%m-%d %H:%M:%S', c.sospesoFino) or nil, c.id })
end

--- Il cantiere più vicino a una posizione, entro il raggio di lavoro.
local function cantiereVicino(coord)
    for lottoId, c in pairs(cantieri) do
        local l = EDI.GetLotto(lottoId)
        if l and #(coord - l.coord) <= 22.0 then return c, l end
    end
end

-- ---------------------------------------------------------------------------
--  Permesso a costruire
--
--  Si protocolla un'istanza al Comune, che la esamina con /istanze. Se
--  nessuno la esamina entro il termine, vale il silenzio-assenso: art. 20
--  D.P.R. 380/2001, e non è una scorciatoia inventata per il server vuoto.
-- ---------------------------------------------------------------------------
local function rilascia(citizenid, lottoId, comeSilenzio)
    local l = EDI.GetLotto(lottoId)
    if not l then return end

    MySQL.insert.await([[
        INSERT INTO edilizia_permessi (citizenid, lotto, silenzio_assenso, scade_il)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { citizenid, lottoId, comeSilenzio and 1 or 0, EDI.Permesso.validitaMinuti })

    local oneri = math.floor(l.volumetria * EDI.Permesso.onerePerMetroCubo)
    exports.ita_fisco:IscriviTributo(citizenid, 'oneri', ('urbanizzazione %s'):format(l.nome), oneri, 5)

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'successo', icona = '🏗', durata = 18000,
            titolo = 'Permesso a costruire rilasciato',
            testo = ('%s.%s\nOneri di urbanizzazione: %s, iscritti a ruolo.')
                :format(l.nome,
                        comeSilenzio and ' Per silenzio-assenso: gli uffici non hanno deciso nei termini.' or '',
                        U.Euro(oneri)),
        })
    end
    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'SUE',
        ('Permesso a costruire rilasciato per %s. Oneri %s.'):format(l.nome, U.Euro(oneri)))

    AUREA.Log('economia', 'info', nil, ('Permesso a costruire su %s a %s%s')
        :format(lottoId, citizenid, comeSilenzio and ' (silenzio-assenso)' or ''))
end

AUREA.Callback.Registra('edi:chiediPermesso', function(src, rispondi, lottoId)
    local g = AUREA.GetPlayer(src)
    if not edile(g, 'apri_cantiere') then
        return rispondi(false, 'Solo il direttore di cantiere può chiedere un titolo edilizio.')
    end

    local l = EDI.GetLotto(lottoId)
    if not l then return rispondi(false, 'Lotto non riconosciuto.') end
    if cantieri[lottoId] then return rispondi(false, 'Su quel lotto c\'è già un cantiere aperto.') end
    if permessiAttesa[g.citizenid] then return rispondi(false, 'Hai già un\'istanza in esame.') end

    local esistente = MySQL.scalar.await([[
        SELECT id FROM edilizia_permessi
        WHERE lotto = ? AND consumato = 0 AND scade_il > NOW() LIMIT 1
    ]], { lottoId })
    if esistente then return rispondi(false, 'Su quel lotto esiste già un titolo valido.') end

    if not g:Sottrai('banca', EDI.Permesso.dirittiSegreteria, 'diritti di segreteria SUE') then
        return rispondi(false, ('Servono %s di diritti di segreteria.'):format(U.Euro(EDI.Permesso.dirittiSegreteria)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_segreteria', EDI.Permesso.dirittiSegreteria, g.citizenid)

    MySQL.insert.await([[
        INSERT INTO istanze_comunali (citizenid, tipo, contenuto, stato)
        VALUES (?, 'permesso_costruire', ?, 'in_esame')
    ]], { g.citizenid, l.nome })

    permessiAttesa[g.citizenid] = {
        lotto = lottoId,
        scade = os.time() + EDI.Permesso.silenzioAssensoMinuti * 60,
    }

    exports.aurea_ui:NotificaLavoro('comune', {
        tipo = 'info', icona = '🏗', durata = 16000,
        titolo = 'Istanza di permesso a costruire',
        testo = ('%s chiede di edificare su %s. Esaminala con /istanze entro %d minuti, altrimenti scatta il silenzio-assenso.')
            :format(g:NomeCompleto(), l.nome, EDI.Permesso.silenzioAssensoMinuti),
    }, false)

    rispondi(true, ('Istanza protocollata per %s. Diritti versati: %s. Se gli uffici non decidono entro %d minuti il permesso si intende rilasciato.')
        :format(l.nome, U.Euro(EDI.Permesso.dirittiSegreteria), EDI.Permesso.silenzioAssensoMinuti))
end)

--- La decisione degli uffici arriva da ita_comune.
AddEventHandler('aurea:comune:istanzaDecisa', function(tipo, citizenid, _, accolta)
    if tipo ~= 'permesso_costruire' then return end

    local attesa = permessiAttesa[citizenid]
    if not attesa then return end
    permessiAttesa[citizenid] = nil

    if accolta then
        rilascia(citizenid, attesa.lotto, false)
    else
        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'SUE',
            'Istanza di permesso a costruire respinta. I diritti di segreteria non si restituiscono.')
    end
end)

--- Silenzio-assenso allo scadere del termine.
CreateThread(function()
    while true do
        Wait(30000)
        local adesso = os.time()
        for citizenid, attesa in pairs(permessiAttesa) do
            if adesso >= attesa.scade then
                permessiAttesa[citizenid] = nil
                MySQL.update('UPDATE istanze_comunali SET stato = ?, decisa_da = ? WHERE citizenid = ? AND tipo = ? AND stato = ?',
                    { 'accolta', 'silenzio-assenso', citizenid, 'permesso_costruire', 'in_esame' })
                rilascia(citizenid, attesa.lotto, true)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Apertura del cantiere
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:apri', function(src, rispondi, lottoId, abusivo)
    local g = AUREA.GetPlayer(src)
    if not edile(g, 'apri_cantiere') then
        return rispondi(false, 'Solo il direttore di cantiere può aprire un cantiere.')
    end

    local l = EDI.GetLotto(lottoId)
    if not l then return rispondi(false, 'Lotto non riconosciuto.') end
    if cantieri[lottoId] then return rispondi(false, 'Su quel lotto c\'è già un cantiere.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - l.coord) > 30.0 then
        return rispondi(false, 'Devi essere sul lotto.')
    end

    local permesso = MySQL.single.await([[
        SELECT * FROM edilizia_permessi
        WHERE lotto = ? AND consumato = 0 AND scade_il > NOW()
        ORDER BY id DESC LIMIT 1
    ]], { lottoId })

    if not permesso and not abusivo then
        return rispondi(false, 'Non c\'è un titolo edilizio valido su questo lotto.')
    end

    -- Il DURC: senza regolarità contributiva un cantiere non apre. È il
    -- motivo per cui pagare i contributi conviene anche a chi della
    -- pensione non gliene importa niente.
    local okDurc, regolare, motivi = pcall(function()
        return exports.ita_previdenza:DURCRegolare(g.citizenid)
    end)
    if okDurc and regolare == false then
        return rispondi(false, ('DURC irregolare: %s. Sistema la posizione all\'INPS.')
            :format(table.concat(motivi or {}, '; ')))
    end

    if permesso then
        MySQL.update.await('UPDATE edilizia_permessi SET consumato = 1 WHERE id = ?', { permesso.id })
    end

    local id = MySQL.insert.await([[
        INSERT INTO edilizia_cantieri (lotto, impresa, direttore, permesso_id, fase, stato)
        VALUES (?, ?, ?, ?, ?, 'aperto')
    ]], { lottoId, g.lavoro.nome, g.citizenid, permesso and permesso.id or nil, EDI.Fasi[1].id })

    cantieri[lottoId] = {
        id = id, lotto = lottoId, impresa = g.lavoro.nome, direttore = g.citizenid,
        permesso_id = permesso and permesso.id or nil,
        fase = EDI.Fasi[1].id, lavorazioni = 0, rischio = 0,
        ponteggio = 0, pos = 0, stato = 'aperto',
    }

    TriggerClientEvent('edi:cantiere', -1, cantieri[lottoId])

    if not permesso then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'avviso', icona = '🏗', durata = 18000,
            testo = ('Segnalazione: attività edilizia su %s senza titolo. Verificare con /ispezionecantiere.')
                :format(l.nome),
            titolo = 'Sospetto abuso edilizio',
        }, true)
        AUREA.Log('giustizia', 'avviso', g, ('ha aperto un cantiere abusivo su %s'):format(lottoId))
    else
        AUREA.Log('economia', 'info', g, ('ha aperto il cantiere su %s'):format(lottoId))
    end

    rispondi(true, permesso
        and ('Cantiere aperto su %s. Prima fase: %s.'):format(l.nome, EDI.Fasi[1].nome)
        or 'Cantiere aperto SENZA titolo edilizio. È abuso edilizio: se ti trovano, sequestrano tutto.')
end)

-- ---------------------------------------------------------------------------
--  Stato del cantiere, per il pannello
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c, l = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then return rispondi(nil) end

    local fase = EDI.GetFase(c.fase)
    rispondi({
        id = c.id, lotto = c.lotto, nome = l.nome,
        impresa = c.impresa, tua = c.impresa == g.lavoro.nome,
        fase = c.fase, nomeFase = fase and fase.nome or '?',
        lavorazioni = c.lavorazioni,
        lavorazioniTotali = fase and fase.lavorazioni or 0,
        avanzamento = EDI.Avanzamento(c.fase, c.lavorazioni),
        rischio = c.rischio,
        ponteggio = c.ponteggio == 1,
        pos = c.pos == 1,
        stato = c.stato,
        abusivo = c.permesso_id == nil,
        materiali = fase and fase.materiali or {},
        dpi = fase and fase.dpi or {},
        richiedePonteggio = fase and fase.richiedePonteggio or false,
    })
end)

-- ---------------------------------------------------------------------------
--  POS e ponteggio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:pos', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not edile(g, 'preposto') then
        return rispondi(false, 'Il piano operativo di sicurezza lo redige il preposto.')
    end

    local c = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then return rispondi(false, 'Non sei in cantiere.') end
    if c.impresa ~= g.lavoro.nome then return rispondi(false, 'Non è un cantiere della tua impresa.') end
    if c.pos == 1 then return rispondi(false, 'Il POS è già depositato.') end

    c.pos = 1
    c.rischio = math.max(0, c.rischio - 10)
    salva(c)
    TriggerClientEvent('edi:cantiere', -1, c)

    AUREA.Log('economia', 'info', g, ('ha depositato il POS del cantiere %d'):format(c.id))
    rispondi(true, 'POS depositato. Il rischio del cantiere scende e l\'ispettorato non ha più questo appiglio.')
end)

AUREA.Callback.Registra('edi:ponteggio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not edile(g, EDI.Ponteggio.permesso) then
        return rispondi(false, 'Il ponteggio lo monta chi è abilitato, non il primo che passa.')
    end

    local c = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then return rispondi(false, 'Non sei in cantiere.') end
    if c.impresa ~= g.lavoro.nome then return rispondi(false, 'Non è un cantiere della tua impresa.') end
    if c.ponteggio == 1 then return rispondi(false, 'Il ponteggio è già montato.') end

    if not exports.aurea_inventory:Ha(g.citizenid, 'tubo_ponteggio', EDI.Ponteggio.tubiNecessari) then
        return rispondi(false, ('Servono %d tubi da ponteggio.'):format(EDI.Ponteggio.tubiNecessari))
    end

    exports.aurea_inventory:Rimuovi(g.citizenid, 'tubo_ponteggio', EDI.Ponteggio.tubiNecessari)

    c.ponteggio = 1
    salva(c)
    TriggerClientEvent('edi:cantiere', -1, c)

    AUREA.Log('economia', 'info', g, ('ha montato il ponteggio del cantiere %d'):format(c.id))
    rispondi(true, 'Ponteggio montato. Adesso si può salire.')
end)

-- ---------------------------------------------------------------------------
--  L'infortunio
-- ---------------------------------------------------------------------------
local function infortuna(g, c, fase)
    local gravita = EDI.GravitaInfortunio(c.rischio, fase.inQuota)
    local elenco = EDI.Infortuni[gravita]
    local caso = elenco[math.random(#elenco)]
    local coord = GetEntityCoords(GetPlayerPed(g.source))
    local l = EDI.GetLotto(c.lotto)

    TriggerClientEvent('aurea:stato:danno', g.source, caso.danno)
    if caso.bloccato then
        TriggerClientEvent('med:abbatti', g.source,
            ('Infortunio sul lavoro: %s.'):format(caso.testo))
    end

    -- Il 112, con la tipologia giusta: sotto un crollo non serve
    -- un'ambulanza, servono anche i vigili del fuoco.
    TriggerEvent('aurea:112:allerta',
        caso.bloccato and 'persona_bloccata' or 'trauma',
        { x = coord.x, y = coord.y, z = coord.z },
        ('Infortunio in cantiere: un operaio %s.'):format(caso.testo),
        l and l.nome or 'cantiere')

    -- INAIL. Il datore è il direttore del cantiere, e da adesso ha un
    -- termine per denunciare.
    TriggerEvent('aurea:previdenza:infortunio', g.citizenid, c.direttore,
        ('%s in cantiere (%s)'):format(caso.testo:gsub('^ha ', 'Ha '), l and l.nome or c.lotto),
        gravita)

    MySQL.insert('INSERT INTO edilizia_infortuni (cantiere_id, citizenid, gravita, descrizione, rischio) VALUES (?, ?, ?, ?, ?)',
        { c.id, g.citizenid, gravita, caso.testo, c.rischio })

    exports.aurea_ui:NotificaLavoro(c.impresa, {
        tipo = 'errore', icona = '🦺', durata = 20000,
        titolo = 'Infortunio in cantiere',
        testo = ('%s %s. Rischio del cantiere: %d%%.'):format(g:NomeCompleto(), caso.testo, c.rischio),
    }, false)

    AUREA.Log('sanita', 'avviso', g, ('infortunio %s in cantiere %d (rischio %d)'):format(gravita, c.id, c.rischio))
end

-- ---------------------------------------------------------------------------
--  La lavorazione
--
--  È qui che si decide tutto: i materiali si consumano davvero, i DPI si
--  verificano sull'inventario del server, il rischio sale o scende e
--  ogni tanto qualcuno si fa male.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:lavora', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not edile(g, 'lavora_cantiere') then
        return rispondi(false, 'In cantiere ci lavora chi è assunto e ha la qualifica.')
    end

    local c, l = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then return rispondi(false, 'Non sei in cantiere.') end
    if c.impresa ~= g.lavoro.nome then return rispondi(false, 'Non è un cantiere della tua impresa.') end
    if c.stato == 'sospeso' then
        return rispondi(false, 'Il cantiere è sotto provvedimento di sospensione. Non si tocca niente.')
    end

    local fase = EDI.GetFase(c.fase)
    if not fase then return rispondi(false, 'Il cantiere è concluso.') end

    -- I materiali
    for item, quanti in pairs(fase.materiali) do
        if not exports.aurea_inventory:Ha(g.citizenid, item, quanti) then
            return rispondi(false, ('Ti servono %d × %s.'):format(quanti, AUREA.Item[item].etichetta))
        end
    end

    -- I DPI: quelli che mancano non fermano il lavoro, lo rendono
    -- pericoloso. È esattamente il modo in cui succede nella realtà.
    local mancanti = {}
    for _, dpi in ipairs(fase.dpi) do
        if not exports.aurea_inventory:Ha(g.citizenid, dpi, 1) then
            mancanti[#mancanti + 1] = AUREA.Item[dpi].etichetta
        end
    end

    local S = EDI.Sicurezza
    local delta = #mancanti * S.perDpiMancante
    if fase.richiedePonteggio and c.ponteggio ~= 1 then delta = delta + S.senzaPonteggio end
    if c.pos ~= 1 then delta = delta + S.senzaPos end
    if delta == 0 then delta = S.inRegola end

    c.rischio = math.floor(U.Clamp(c.rischio + delta, 0, 100))

    -- Consuma i materiali solo ora: se qualcosa sopra ha rifiutato, il
    -- sacco di cemento è ancora nel bancale.
    for item, quanti in pairs(fase.materiali) do
        exports.aurea_inventory:Rimuovi(g.citizenid, item, quanti)
    end

    -- L'infortunio
    if math.random() < EDI.ProbabilitaInfortunio(c.rischio) then
        salva(c)
        TriggerClientEvent('edi:cantiere', -1, c)
        infortuna(g, c, fase)
        return rispondi(false, 'Infortunio sul lavoro.')
    end

    c.lavorazioni = c.lavorazioni + 1
    g:Aggiungi('contanti', EDI.Compensi.aLavorazione, 'lavorazione in cantiere')

    local messaggio
    if c.lavorazioni >= fase.lavorazioni then
        local dopo = EDI.FaseDopo(c.fase)
        if dopo then
            c.fase, c.lavorazioni = dopo.id, 0
            messaggio = ('%s completata. Si passa a: %s.'):format(fase.nome, dopo.nome)
            exports.aurea_ui:NotificaLavoro(c.impresa, {
                tipo = 'successo', icona = '🏗', durata = 12000,
                titolo = 'Fase completata',
                testo = ('%s — %s completata.'):format(l.nome, fase.nome),
            }, false)
        else
            salva(c)
            TriggerClientEvent('edi:cantiere', -1, c)
            return rispondi(true, 'Ultima lavorazione eseguita. Il cantiere è pronto per la consegna.', true)
        end
    else
        messaggio = ('%s — lavorazione %d di %d. Rischio del cantiere: %d%%.')
            :format(fase.nome, c.lavorazioni, fase.lavorazioni, c.rischio)
    end

    salva(c)
    TriggerClientEvent('edi:cantiere', -1, c)

    if #mancanti > 0 then
        messaggio = ('%s\nSenza %s: il rischio è salito.'):format(messaggio, table.concat(mancanti, ', '))
    end

    rispondi(true, messaggio)
end)

-- ---------------------------------------------------------------------------
--  Consegna
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:consegna', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not edile(g, 'apri_cantiere') then
        return rispondi(false, 'La consegna la firma il direttore di cantiere.')
    end

    local c, l = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then return rispondi(false, 'Non sei in cantiere.') end
    if c.impresa ~= g.lavoro.nome then return rispondi(false, 'Non è un cantiere della tua impresa.') end
    if c.stato == 'sospeso' then return rispondi(false, 'Il cantiere è sospeso.') end

    local ultima = EDI.Fasi[#EDI.Fasi]
    if c.fase ~= ultima.id or c.lavorazioni < ultima.lavorazioni then
        return rispondi(false, ('Il cantiere è al %d%%: non si consegna un\'opera incompiuta.')
            :format(EDI.Avanzamento(c.fase, c.lavorazioni)))
    end

    local compenso = math.floor(l.volumetria * EDI.Compensi.perMetroCubo)
    local premio = 0
    if c.rischio <= EDI.Compensi.rischioPerPremio then
        premio = math.floor(compenso * EDI.Compensi.premioSicurezza)
    end

    exports.aurea_azienda:VersaInCassa(c.impresa, compenso + premio,
        ('consegna %s'):format(l.nome))

    if not g:Sottrai('banca', EDI.Compensi.collaudo, 'collaudo finale') then
        exports.ita_fisco:IscriviTributo(g.citizenid, 'oneri', ('collaudo %s'):format(l.nome),
            EDI.Compensi.collaudo, 7)
    else
        TriggerEvent('aurea:fisco:incasso', 'collaudo', EDI.Compensi.collaudo, g.citizenid)
    end

    MySQL.update.await('UPDATE edilizia_cantieri SET stato = ?, consegnato_il = NOW() WHERE id = ?',
        { 'consegnato', c.id })
    cantieri[c.lotto] = nil
    TriggerClientEvent('edi:cantiereChiuso', -1, c.lotto)

    AUREA.Log('economia', 'info', g, ('ha consegnato il cantiere %s (rischio finale %d)'):format(c.lotto, c.rischio))

    rispondi(true, ('Opera consegnata. In cassa %s%s. Collaudo %s.')
        :format(U.Euro(compenso),
                premio > 0 and (' più %s di premio: hai portato tutti a casa interi'):format(U.Euro(premio)) or '',
                U.Euro(EDI.Compensi.collaudo)))
end)

-- ---------------------------------------------------------------------------
--  Ispezione
--
--  È il momento in cui tutte le scorciatoie presentano il conto insieme.
-- ---------------------------------------------------------------------------
AUREA.Comando('ispezionecantiere', 'utente', 'Ispeziona il cantiere in cui ti trovi', {},
function(src, _, _, g)
    if not vigile(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🔎', titolo = 'Non autorizzato',
            testo = 'L\'ispezione la fa il personale di vigilanza in servizio.',
        })
    end

    local c, l = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🔎', titolo = 'Nessun cantiere', testo = 'Qui non risulta nessun cantiere aperto.',
        })
    end

    local V = EDI.Vigilanza
    local violazioni, totale = {}, 0

    local function contesta(chiave)
        local s = V.sanzioni[chiave]
        violazioni[#violazioni + 1] = s.testo
        totale = totale + s.importo
    end

    if not c.permesso_id then contesta('senzaPermesso') end
    if c.pos ~= 1 then contesta('senzaPos') end

    local fase = EDI.GetFase(c.fase)
    if fase and fase.richiedePonteggio and c.ponteggio ~= 1 then contesta('senzaPonteggio') end

    local okDurc, regolare = pcall(function()
        return exports.ita_previdenza:DURCRegolare(c.direttore)
    end)
    if okDurc and regolare == false then contesta('senzaDurc') end

    -- I DPI si controllano addosso a chi sta lavorando, non sulla carta
    local scoperti = 0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.nome == c.impresa
            and #(GetEntityCoords(GetPlayerPed(altro.source)) - l.coord) <= 22.0 then
            for _, dpi in ipairs(fase and fase.dpi or {}) do
                if not exports.aurea_inventory:Ha(altro.citizenid, dpi, 1) then
                    scoperti = scoperti + 1
                    break
                end
            end
        end
    end
    if scoperti > 0 then contesta('dpiMancanti') end

    MySQL.insert('INSERT INTO edilizia_ispezioni (cantiere_id, ispettore, violazioni, sanzione) VALUES (?, ?, ?, ?)',
        { c.id, g:NomeCompleto(), json.encode(violazioni), totale })

    if #violazioni == 0 then
        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🔎', durata = 16000,
            titolo = ('Ispezione — %s'):format(l.nome),
            testo = ('Nessuna violazione. Rischio rilevato %d%%, avanzamento %d%%.')
                :format(c.rischio, EDI.Avanzamento(c.fase, c.lavorazioni)),
        })
        return AUREA.Log('giustizia', 'info', g, ('ha ispezionato il cantiere %d: regolare'):format(c.id))
    end

    exports.ita_fisco:IscriviTributo(c.direttore, 'sanzione',
        ('violazioni in cantiere %s'):format(l.nome), totale, 10)

    local sospeso = #violazioni >= V.violazioniPerSospensione
    if sospeso then
        c.stato = 'sospeso'
        c.sospesoFino = os.time() + V.sospensioneMinuti * 60
        salva(c)
        TriggerClientEvent('edi:cantiere', -1, c)
    end

    exports.aurea_ui:NotificaLavoro(c.impresa, {
        tipo = 'errore', icona = '🔎', durata = 25000,
        titolo = sospeso and 'Cantiere sospeso' or 'Verbale di ispezione',
        testo = ('%s\n\nSanzione: %s%s'):format(
            table.concat(violazioni, '\n· '), U.Euro(totale),
            sospeso and ('\n\nSospensione dell\'attività per %d minuti, art. 14 D.Lgs. 81/2008.')
                :format(V.sospensioneMinuti) or ''),
    }, false)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '🔎', durata = 25000,
        titolo = ('Ispezione — %s'):format(l.nome),
        testo = ('%d violazioni:\n· %s\n\nSanzione %s%s'):format(
            #violazioni, table.concat(violazioni, '\n· '), U.Euro(totale),
            sospeso and '\nCantiere SOSPESO.' or ''),
    })

    AUREA.Log('giustizia', 'avviso', g,
        ('ha verbalizzato %d violazioni nel cantiere %d (%s)'):format(#violazioni, c.id, U.Euro(totale)))
end)

--- La sospensione decade da sola allo scadere del termine.
CreateThread(function()
    while true do
        Wait(60000)
        for _, c in pairs(cantieri) do
            if c.stato == 'sospeso' and c.sospesoFino then
                if os.time() >= c.sospesoFino then
                    c.stato, c.sospesoFino = 'aperto', nil
                    salva(c)
                    TriggerClientEvent('edi:cantiere', -1, c)
                    exports.aurea_ui:NotificaLavoro(c.impresa, {
                        tipo = 'info', icona = '🏗', durata = 12000,
                        titolo = 'Sospensione revocata',
                        testo = 'Il provvedimento è decaduto: si può riprendere.',
                    }, false)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Fornitore di materiali
--
--  Paga la cassa dell'impresa, non il manovale. I DPI in particolare sono
--  un obbligo del datore di lavoro (art. 18 D.Lgs. 81/2008) e non una
--  spesa che si scarica su chi li deve indossare.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('edi:acquista', function(src, rispondi, indice, moltiplicatore)
    local g = AUREA.GetPlayer(src)
    if not edile(g) then return rispondi(false, 'Non lavori per un\'impresa edile.') end

    local voce = EDI.Fornitore.listino[tonumber(indice) or 0]
    if not voce then return rispondi(false, 'Articolo non a listino.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - EDI.Fornitore.coord) > 6.0 then
        return rispondi(false, 'Devi essere alla rivendita.')
    end

    local n = math.floor(U.Clamp(tonumber(moltiplicatore) or 1, 1, 20))
    local costo = voce.prezzo * n
    local quantita = voce.quantita * n

    local pagato = select(1, exports.aurea_azienda:PrelevaDaCassa(g.lavoro.nome, costo,
        ('materiali: %d × %s'):format(quantita, voce.item)))
    if not pagato then
        return rispondi(false, ('La cassa dell\'impresa non ha %s.'):format(U.Euro(costo)))
    end

    if not exports.aurea_inventory:Aggiungi(g.citizenid, voce.item, quantita) then
        exports.aurea_azienda:VersaInCassa(g.lavoro.nome, costo, 'storno: non ci stava nulla')
        return rispondi(false, 'Non hai spazio addosso. Il materiale pesa, serve un mezzo.')
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_materiali', math.floor(costo * 0.22 / 1.22), g.citizenid)

    rispondi(true, ('%d × %s per %s, dalla cassa dell\'impresa.')
        :format(quantita, AUREA.Item[voce.item].etichetta, U.Euro(costo)))
end)

-- ---------------------------------------------------------------------------
--  Sequestro del cantiere abusivo
-- ---------------------------------------------------------------------------
AUREA.Comando('sequestracantiere', 'utente', 'Sequestra un cantiere privo di titolo edilizio', {},
function(src, _, _, g)
    if not vigile(g) or g.lavoro.nome ~= 'carabinieri' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⛔', titolo = 'Non autorizzato',
            testo = 'Il sequestro preventivo lo esegue la polizia giudiziaria.',
        })
    end

    local c, l = cantiereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not c then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '⛔', titolo = 'Nessun cantiere', testo = 'Qui non c\'è niente da sequestrare.',
        })
    end
    if c.permesso_id then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⛔', titolo = 'Cantiere in regola',
            testo = 'Il cantiere ha un titolo edilizio: non c\'è il presupposto per il sequestro.',
        })
    end

    MySQL.update.await('UPDATE edilizia_cantieri SET stato = ?, consegnato_il = NOW() WHERE id = ?',
        { 'sequestrato', c.id })
    cantieri[c.lotto] = nil
    TriggerClientEvent('edi:cantiereChiuso', -1, c.lotto)

    exports.ita_fisco:IscriviTributo(c.direttore, 'sanzione',
        ('abuso edilizio %s'):format(l.nome), EDI.Vigilanza.sanzioni.senzaPermesso.importo, 10)

    exports.aurea_ui:NotificaLavoro(c.impresa, {
        tipo = 'errore', icona = '⛔', durata = 25000,
        titolo = 'Cantiere sequestrato',
        testo = ('%s: sequestro preventivo per abuso edilizio, art. 44 D.P.R. 380/2001. Tutto quello che avete fatto resta lì.')
            :format(l.nome),
    }, false)

    AUREA.Log('giustizia', 'avviso', g, ('ha sequestrato il cantiere abusivo %s'):format(c.lotto))
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '⛔', durata = 15000,
        titolo = 'Sequestro eseguito',
        testo = ('%s sequestrato. Sanzione di %s a carico del direttore.')
            :format(l.nome, U.Euro(EDI.Vigilanza.sanzioni.senzaPermesso.importo)),
    })
end)

-- ---------------------------------------------------------------------------
--  Export e app
-- ---------------------------------------------------------------------------

--- Il cantiere aperto su un lotto, per chi lo deve sapere.
exports('CantiereSu', function(lottoId)
    local c = cantieri[lottoId]
    if not c then return nil end
    return { id = c.id, impresa = c.impresa, fase = c.fase, rischio = c.rischio,
             stato = c.stato, abusivo = c.permesso_id == nil }
end)

AureaApp({
    id = 'cantieri',
    nome = 'Cantieri',
    icona = '🏗',
    colore = 'linear-gradient(150deg,#c58a2e,#6d4a14)',
    ordine = 135,

    condizione = function(g) return g.lavoro.nome == EDI.Lavoro end,

    schermata = function(g)
        local voci = {}

        for lottoId, c in pairs(cantieri) do
            if c.impresa == g.lavoro.nome then
                local l = EDI.GetLotto(lottoId)
                local fase = EDI.GetFase(c.fase)
                voci[#voci + 1] = {
                    icona = c.stato == 'sospeso' and '⛔' or '🏗',
                    titolo = l and l.nome or lottoId,
                    sottotitolo = ('%s · avanzamento %d%% · rischio %d%%%s'):format(
                        fase and fase.nome or '—',
                        EDI.Avanzamento(c.fase, c.lavorazioni), c.rischio,
                        c.permesso_id and '' or ' · SENZA TITOLO'),
                    valore = c.stato == 'sospeso' and 'SOSPESO' or ('%d%%'):format(
                        EDI.Avanzamento(c.fase, c.lavorazioni)),
                    tono = c.stato == 'sospeso' and 'rosso'
                        or (c.rischio >= EDI.Sicurezza.sogliaInfortunio and 'giallo' or 'verde'),
                    inerte = true,
                }
            end
        end

        if #voci == 0 then
            voci[1] = { icona = '🏗', titolo = 'Nessun cantiere aperto',
                        sottotitolo = 'Il titolo edilizio si chiede allo Sportello Unico.', inerte = true }
        end

        return { tipo = 'lista', sottotitolo = 'Cantieri della tua impresa', voci = voci }
    end,
})

print('[AUREA] edilizia: cantieri e sicurezza sul lavoro attivi')
