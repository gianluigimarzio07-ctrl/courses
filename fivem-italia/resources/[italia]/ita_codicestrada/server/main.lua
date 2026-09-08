--[[
    AUREA · Codice della Strada (server)

    Punto chiave: la velocità che finisce nel verbale NON è quella dichiarata
    dal client. Il server risale all'entità di rete del veicolo e ne legge
    lui stesso la velocità, confrontandola con quella dichiarata: uno scarto
    eccessivo è un indizio di manomissione e viene registrato.
]]

local U = AUREA.Util
local ultimoRilevamento = {}    -- [src] = { [postazione] = timestamp }

-- ---------------------------------------------------------------------------
--  Velocità letta lato server
-- ---------------------------------------------------------------------------
local function velocitaServer(netId)
    if not netId then return nil end
    local entita = NetworkGetEntityFromNetworkId(netId)
    if not entita or entita == 0 or not DoesEntityExist(entita) then return nil end
    local v = GetEntityVelocity(entita)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) * 3.6, entita
end

--- Risale al proprietario della targa; se non è un veicolo immatricolato,
--- il verbale va al conducente.
local function intestatario(targa, conducente)
    if targa then
        local proprietario = MySQL.scalar.await('SELECT citizenid FROM veicoli WHERE targa = ?', { targa:gsub('%s+', '') })
        if proprietario then return proprietario end
    end
    return conducente.citizenid
end

-- ---------------------------------------------------------------------------
--  Rilevamento velocità e semafori
-- ---------------------------------------------------------------------------
RegisterNetEvent('cds:rilevamento', function(dati)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return end

    -- anti-flood per postazione
    ultimoRilevamento[src] = ultimoRilevamento[src] or {}
    local adesso = os.clock()
    if (adesso - (ultimoRilevamento[src][dati.postazione] or 0)) < CDS.Regole.antiDuplicatoSecondi then return end
    ultimoRilevamento[src][dati.postazione] = adesso

    local targa = (dati.targa or ''):gsub('%s+', ''):upper()
    local luogo = dati.nome or 'postazione non identificata'
    local proprietario = intestatario(targa, g)

    if dati.tipo == 'autovelox' then
        local kmh = velocitaServer(dati.netId)
        if not kmh then return end

        -- verifica che la postazione esista davvero e che il veicolo le sia vicino
        local postazione
        for _, av in ipairs(CDS.Autovelox) do
            if av.id == dati.postazione then postazione = av break end
        end
        if not postazione then
            AUREA.Log('anticheat', 'allarme', src, ('rilevamento su postazione inesistente: %s'):format(tostring(dati.postazione)))
            return
        end

        local delta = kmh - postazione.limite
        local infrazione = AUREA.InfrazioneVelocita(delta)
        if not infrazione then return end

        Verbali.Emetti({
            citizenid = proprietario,
            targa = targa ~= '' and targa or nil,
            articolo = infrazione.articolo,
            descrizione = ('%s (rilevati %d km/h su limite di %d)'):format(infrazione.nome, math.floor(kmh), postazione.limite),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'autovelox',
            luogo = luogo,
            prova = { velocita = math.floor(kmh), limite = postazione.limite, coord = dati.coord },
        })

        if infrazione.sospensione and infrazione.sospensione > 0 then
            Patente.Sospendi(proprietario, infrazione.sospensione, infrazione.nome)
        end

    elseif dati.tipo == 'tutor' then
        local tratta
        for _, t in ipairs(CDS.Tutor) do
            if t.id == dati.postazione then tratta = t break end
        end
        if not tratta then return end

        -- Il server ricalcola la media dai dati dichiarati e la valida:
        -- una percorrenza fisicamente impossibile viene scartata.
        local secondi = tonumber(dati.secondi) or 0
        if secondi < 10 then return end
        local media = (tratta.lunghezza / secondi) * 3.6
        if media > 400 then
            AUREA.Log('anticheat', 'allarme', src, ('media tutor implausibile: %.1f km/h su %s'):format(media, tratta.id))
            return
        end

        local infrazione = AUREA.InfrazioneVelocita(media - tratta.limite)
        if not infrazione then return end

        Verbali.Emetti({
            citizenid = proprietario,
            targa = targa ~= '' and targa or nil,
            articolo = infrazione.articolo,
            descrizione = ('%s — velocità media %d km/h su limite di %d'):format(infrazione.nome, math.floor(media), tratta.limite),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'tutor',
            luogo = tratta.nome,
            prova = { media = math.floor(media), secondi = math.floor(secondi), tratta = tratta.lunghezza },
        })

    elseif dati.tipo == 'semaforo' then
        local semaforo
        for _, s in ipairs(CDS.Semafori) do
            if s.id == dati.postazione then semaforo = s break end
        end
        if not semaforo then return end

        -- Il server ricalcola la fase: se al momento dichiarato non era rossa,
        -- il verbale non parte.
        local secondi = tonumber(dati.secondiGioco) or -1
        if secondi >= 0 and CDS.FaseSemaforo(semaforo.id, secondi) ~= 'rosso' then
            AUREA.Log('anticheat', 'avviso', src, ('segnalazione semaforo con fase non rossa: %s'):format(semaforo.id))
            return
        end

        local infrazione = AUREA.Infrazioni['146']
        Verbali.Emetti({
            citizenid = proprietario,
            targa = targa ~= '' and targa or nil,
            articolo = infrazione.articolo,
            descrizione = infrazione.nome,
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'semaforo',
            luogo = semaforo.nome,
            prova = { coord = dati.coord },
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Varchi ZTL
-- ---------------------------------------------------------------------------
RegisterNetEvent('cds:ztlTransito', function(dati)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return end

    local zona
    for _, z in ipairs(CDS.ZTL) do
        if z.id == dati.zona then zona = z break end
    end
    if not zona then return end

    local targa = (dati.targa or ''):gsub('%s+', ''):upper()
    if targa == '' then return end

    -- Giorno della settimana in gioco (1 = lunedì)
    local giorno = tonumber(os.date('%u'))
    local attiva = CDS.InFascia(zona.fasce, tonumber(dati.ora) or 0)
        and (not zona.giorni or U.Contiene(zona.giorni, giorno))

    local permesso = MySQL.single.await(
        'SELECT tipo, scadenza FROM ztl_permessi WHERE zona = ? AND targa = ? AND scadenza >= CURDATE()',
        { zona.id, targa })

    local autorizzato = permesso ~= nil

    -- Mezzi in servizio di emergenza: transito sempre consentito
    if not autorizzato and g.lavoro.servizio then
        local l = AUREA.GetLavoro(g.lavoro.nome)
        if l.tipo == 'forze_ordine' or l.tipo == 'soccorso' then autorizzato = true end
    end

    local multaId = nil
    if attiva and not autorizzato then
        local infrazione = AUREA.Infrazioni['7_ztl']
        multaId = Verbali.Emetti({
            citizenid = intestatario(targa, g),
            targa = targa,
            articolo = infrazione.articolo,
            descrizione = ('%s — %s'):format(infrazione.nome, zona.nome),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'ztl',
            luogo = zona.nome,
            prova = { coord = dati.coord, ora = dati.ora },
        })
    end

    MySQL.insert('INSERT INTO ztl_transiti (zona, targa, citizenid, autorizzato, multa_id) VALUES (?, ?, ?, ?, ?)',
        { zona.id, targa, g.citizenid, autorizzato and 1 or 0, multaId })

    TriggerClientEvent('cds:ztlEsito', src, {
        nome = zona.nome,
        attiva = attiva,
        autorizzato = autorizzato,
        tipo = permesso and permesso.tipo or nil,
        scadenza = permesso and U.DataIT(math.floor(permesso.scadenza / 1000)) or nil,
    })
end)

AddEventHandler('playerDropped', function()
    ultimoRilevamento[source] = nil
end)

-- ---------------------------------------------------------------------------
--  Callback client
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cds:miaPatente', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = Patente.Get(g.citizenid)
    if not p then return rispondi(nil) end

    rispondi({
        numero = p.numero,
        categorie = p.categorie or '',
        punti = p.punti,
        ritirata = p.ritirata,
        neopatentato = p.neopatentato,
        scadenza = U.DataIT(math.floor((p.scadenza or 0) / 1000)),
        sospesa = p.sospesa_fino and (p.sospesa_fino / 1000) > os.time() or false,
    })
end)

AUREA.Callback.Registra('cds:mieMulte', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end
    rispondi(Verbali.Aperti(g.citizenid))
end)

AUREA.Callback.Registra('cds:pagaMulte', function(src, rispondi, idVerbale)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    local ok, messaggio = Verbali.Paga(g.citizenid, idVerbale)
    rispondi(ok, messaggio)
end)

-- Corso di recupero punti ---------------------------------------------------
local corsiInCorso = {}

AUREA.Callback.Registra('cds:iniziaCorso', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = Patente.Get(g.citizenid)
    if not p or p.punti >= CDS.Regole.puntiMassimi then return rispondi(nil) end
    if not g:SottraiOvunque(CDS.Regole.costoCorso, 'corso recupero punti') then return rispondi(false) end

    corsiInCorso[src] = os.time()
    TriggerEvent('aurea:fisco:incasso', 'motorizzazione', CDS.Regole.costoCorso, g.citizenid)
    rispondi(true)
end)

AUREA.Callback.Registra('cds:concludiCorso', function(src, rispondi, completato)
    local g = AUREA.GetPlayer(src)
    if not g or not corsiInCorso[src] then return rispondi(false) end

    -- il corso ha una durata minima: chi lo interrompe non recupera nulla
    local trascorso = os.time() - corsiInCorso[src]
    corsiInCorso[src] = nil

    if not completato or trascorso < (CDS.Regole.durataCorsoMinuti - 2) then
        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Corso interrotto',
            testo = 'Hai lasciato l\'aula: la quota non viene rimborsata.',
        })
        return rispondi(false)
    end

    local nuovi = Patente.Restituisci(g.citizenid, CDS.Regole.puntiCorso)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Corso completato',
        testo = ('Recuperati %d punti. Saldo: %d punti.'):format(CDS.Regole.puntiCorso, nuovi),
        durata = 8000,
    })
    rispondi(true)
end)

-- Esami ---------------------------------------------------------------------
local esamiInCorso = {}

AUREA.Callback.Registra('cds:domandeEsame', function(src, rispondi, categoria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local cat
    for _, c in ipairs(CDS.Motorizzazione.categorie) do
        if c.id == categoria then cat = c break end
    end
    if not cat then return rispondi(nil) end

    -- prerequisito di categoria
    if cat.richiede and not Patente.HaCategoria(g.citizenid, cat.richiede) then
        return rispondi(nil)
    end

    -- età anagrafica
    local anno = tonumber((g.dataNascita or ''):sub(1, 4))
    if anno then
        local eta = tonumber(os.date('%Y')) - anno
        if eta < cat.etaMinima then return rispondi(nil) end
    end

    if not g:SottraiOvunque(cat.costo, ('esame patente %s'):format(cat.id)) then return rispondi(nil) end
    TriggerEvent('aurea:fisco:incasso', 'motorizzazione', cat.costo, g.citizenid)

    esamiInCorso[src] = { categoria = categoria, iniziato = os.time() }
    rispondi(Patente.EstraiDomande(10))
end)

AUREA.Callback.Registra('cds:esitoEsame', function(src, rispondi, categoria, superata, corrette)
    local g = AUREA.GetPlayer(src)
    local esame = esamiInCorso[src]
    if not g or not esame or esame.categoria ~= categoria then return rispondi(false) end
    esamiInCorso[src] = nil

    if not superata then
        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Esame non superato',
            testo = 'Puoi ripresentarti pagando nuovamente la quota.',
        })
        return rispondi(false)
    end

    local numero = Patente.AggiungiCategoria(g.citizenid, categoria)
    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'patente', 1, {
        numero = numero, categorie = categoria, intestatario = g:NomeCompleto(), cf = g.cf,
    })

    local p = Patente.Get(g.citizenid)
    TriggerClientEvent('cds:puntiAggiornati', src, p and p.punti or 20)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🪪', durata = 10000,
        titolo = ('Patente %s conseguita'):format(categoria),
        testo = ('Numero %s · %d punti. Ricorda: da neopatentato le decurtazioni sono raddoppiate.'):format(numero, p and p.punti or 20),
    })
    AUREA.Log('multe', 'info', g, ('ha conseguito la patente categoria %s'):format(categoria))
    rispondi(true)
end)

AUREA.Callback.Registra('cds:duplicatoPatente', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    local p = Patente.Get(g.citizenid)
    if not p then return rispondi(false) end

    if not g:SottraiOvunque(CDS.Motorizzazione.costoDuplicato, 'duplicato patente') then
        TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Fondi insufficienti', testo = U.Euro(CDS.Motorizzazione.costoDuplicato) .. ' richiesti.' })
        return rispondi(false)
    end

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'patente', 1, {
        numero = p.numero, categorie = p.categorie, intestatario = g:NomeCompleto(), cf = g.cf,
    })
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Duplicato rilasciato', testo = 'Trovi il documento nell\'inventario.' })
    rispondi(true)
end)

-- ---------------------------------------------------------------------------
--  Contestazione da parte di un agente
-- ---------------------------------------------------------------------------
AUREA.Comando('verbale', 'utente', 'Eleva un verbale al conducente più vicino', {
    { name = 'codice', help = 'Codice infrazione (es. 142_2, 173, 186_1)' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('multa') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Solo il personale in servizio può elevare verbali.' })
    end
    if not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Fuori servizio', testo = 'Devi essere in servizio.' })
    end

    local infrazione = AUREA.Infrazioni[args[1] or '']
    if not infrazione then
        local elenco = {}
        for codice, i in pairs(AUREA.Infrazioni) do elenco[#elenco + 1] = ('%s (%s)'):format(codice, i.nome) end
        table.sort(elenco)
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', titolo = 'Codici disponibili', testo = table.concat(elenco, ' · '), durata = 20000,
        })
    end

    -- destinatario: persona più vicina
    local origine = GetEntityCoords(GetPlayerPed(src))
    local bersaglio, distanzaMin = nil, 6.0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= src then
            local d = #(origine - GetEntityCoords(GetPlayerPed(altro.source)))
            if d < distanzaMin then bersaglio, distanzaMin = altro, d end
        end
    end
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati al conducente.' })
    end

    local veicolo = GetVehiclePedIsIn(GetPlayerPed(bersaglio.source), false)
    local targa = veicolo ~= 0 and GetVehicleNumberPlateText(veicolo) or nil

    Verbali.Emetti({
        citizenid = bersaglio.citizenid,
        targa = targa and targa:gsub('%s+', '') or nil,
        articolo = infrazione.articolo,
        descrizione = infrazione.nome,
        importo = infrazione.importo,
        punti = infrazione.punti,
        origine = 'agente',
        agente = ('%s (%s)'):format(g:NomeCompleto(), AUREA.EtichettaLavoro(g.lavoro.nome, g.lavoro.grado)),
        luogo = 'contestazione immediata',
    })

    if infrazione.sospensione and infrazione.sospensione > 0 then
        Patente.Sospendi(bersaglio.citizenid, infrazione.sospensione, infrazione.nome)
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Verbale elevato',
        testo = ('%s a %s — %s'):format(infrazione.articolo, bersaglio:NomeCompleto(), U.Euro(infrazione.importo)),
    })
end)

AUREA.Comando('etilometro', 'utente', 'Sottopone la persona più vicina al test alcolemico', {}, function(src, _, _, g)
    if not g or not g:HaPermessoLavoro('multa') or not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale in servizio.' })
    end

    local origine = GetEntityCoords(GetPlayerPed(src))
    local bersaglio, distanzaMin = nil, 4.0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= src then
            local d = #(origine - GetEntityCoords(GetPlayerPed(altro.source)))
            if d < distanzaMin then bersaglio, distanzaMin = altro, d end
        end
    end
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
    end

    local tasso = bersaglio.stato.alcol or 0
    local infrazione = AUREA.InfrazioneAlcol(tasso)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = infrazione and 'errore' or 'successo',
        icona = '🍷', durata = 10000,
        titolo = ('Etilometro: %.2f g/l'):format(tasso),
        testo = infrazione and ('%s — %s'):format(infrazione.articolo, infrazione.nome) or 'Nella norma. Nessuna violazione.',
    })
    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = infrazione and 'errore' or 'info', icona = '🍷',
        titolo = ('Test alcolemico: %.2f g/l'):format(tasso),
        testo = infrazione and 'Sei oltre il limite di legge.' or 'Puoi metterti alla guida.',
    })

    if infrazione then
        Verbali.Emetti({
            citizenid = bersaglio.citizenid,
            articolo = infrazione.articolo,
            descrizione = ('%s — tasso rilevato %.2f g/l'):format(infrazione.nome, tasso),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'agente',
            agente = g:NomeCompleto(),
            luogo = 'controllo stradale',
            prova = { tasso = tasso },
        })
        if infrazione.sospensione > 0 then
            Patente.Sospendi(bersaglio.citizenid, infrazione.sospensione, infrazione.nome)
        end
        if infrazione.arresto then
            TriggerEvent('aurea:giustizia:apriFascicolo', bersaglio.citizenid, '186_3', g:NomeCompleto())
        end
    end
end)

AUREA.Comando('permessoztl', 'utente', 'Rilascia un permesso ZTL (Comune)', {
    { name = 'targa', help = 'Targa del veicolo' },
    { name = 'zona', help = 'Id della zona' },
    { name = 'giorni', help = 'Durata in giorni' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('permessi_ztl') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato agli uffici comunali.' })
    end

    local targa = (args[1] or ''):upper()
    local zona = args[2]
    local giorni = tonumber(args[3]) or 30

    local esiste = false
    for _, z in ipairs(CDS.ZTL) do if z.id == zona then esiste = true break end end
    if targa == '' or not esiste then
        local ids = {}
        for _, z in ipairs(CDS.ZTL) do ids[#ids + 1] = z.id end
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = ('/permessoztl <targa> <%s> <giorni>'):format(table.concat(ids, '|')),
            durata = 10000,
        })
    end

    MySQL.query.await([[
        INSERT INTO ztl_permessi (zona, targa, tipo, scadenza) VALUES (?, ?, 'residente', ?)
        ON DUPLICATE KEY UPDATE scadenza = VALUES(scadenza)
    ]], { zona, targa, U.DataPiuGiorni(giorni) })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Permesso rilasciato',
        testo = ('Targa %s in %s fino al %s.'):format(targa, zona, U.DataIT(os.time() + giorni * 86400)),
    })
    AUREA.Log('multe', 'info', g, ('permesso ZTL %s per %s (%d giorni)'):format(zona, targa, giorni))
end)

-- ---------------------------------------------------------------------------
--  App sul telefono: la patente a punti
--
--  I verbali stanno nel cassetto fiscale, perché sono un debito. Qui c'è
--  la patente: i punti che restano e come sono stati persi, che è la cosa
--  che si guarda con ansia dopo un controllo.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'patente',
    nome = 'Patente',
    icona = '🚗',
    colore = 'linear-gradient(150deg,#4a5b7a,#28334a)',
    ordine = 110,

    condizione = function(g)
        return Patente.Get(g.citizenid) ~= nil
    end,

    schermata = function(g)
        local p = Patente.Get(g.citizenid)
        if not p then
            return { tipo = 'testo', titolo = 'Patente',
                     corpo = 'Non risulti titolare di patente di guida.' }
        end

        local voci = {}

        for _, m in ipairs(MySQL.query.await([[
            SELECT articolo, descrizione, punti_decurtati, emessa
            FROM multe WHERE citizenid = ? AND punti_decurtati > 0
            ORDER BY id DESC LIMIT 20
        ]], { g.citizenid }) or {}) do
            voci[#voci + 1] = {
                icona = '➖',
                titolo = ('%s — %s'):format(m.articolo, m.descrizione),
                valore = ('−%d'):format(m.punti_decurtati),
                tono = 'rosso',
                inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '✅', titolo = 'Nessuna decurtazione',
                        sottotitolo = 'Non hai mai perso punti.', inerte = true }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Punti residui',
            valore = tostring(p.punti),
            nota = ('N. %s · categorie %s'):format(
                p.numero, p.categorie ~= '' and p.categorie or '—'),
            voci = voci,
        }
    end,
})
