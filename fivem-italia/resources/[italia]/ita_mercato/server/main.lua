--[[
    AUREA · Mercato rionale (server)

    Due registri: le concessioni dei posteggi e i banchi aperti adesso.

    Il banco aperto vive solo in memoria, e va bene così: è una presenza,
    e dopo un riavvio nessuno è dietro il suo banco. Quello che invece
    finisce nel database è ogni singola vendita, battuta o non battuta,
    perché è su quel registro che la Guardia di Finanza fa i conti — e un
    controllo che si fida di un contatore in RAM non è un controllo.
]]

local U = AUREA.Util

local concessioni = {}   -- [idPosteggio] = { citizenid, nome, scade }
local banchi = {}        -- [citizenid] = { posteggio, mercato, banco, aperto, prossimoCliente, cliente, vendite }
local ultimoControllo = {}  -- [citizenid] = timestamp

-- ---------------------------------------------------------------------------
--  La licenza e il posteggio
-- ---------------------------------------------------------------------------
local function haLicenza(citizenid)
    return MySQL.scalar.await([[
        SELECT id FROM licenze
        WHERE citizenid = ? AND tipo = ? AND revocata = 0 AND scadenza >= CURDATE()
    ]], { citizenid, MER.Licenza.tipo }) ~= nil
end

exports('HaLicenzaAreaPubblica', haLicenza)

local function posteggioDi(citizenid)
    for id, c in pairs(concessioni) do
        if c.citizenid == citizenid and c.scade > os.time() then
            return id, c
        end
    end
end

exports('PosteggioDi', posteggioDi)

AUREA.Callback.Registra('mer:sportello', function(src, rispondi, idMercato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local m = MER.GetMercato(idMercato)
    if not m then return rispondi(nil) end

    local liberi, miei = {}, nil
    for _, p in ipairs(m.posteggi) do
        local c = concessioni[p.id]
        if c and c.scade > os.time() then
            if c.citizenid == g.citizenid then
                miei = { id = p.id, canone = p.canone,
                         minutiResidui = math.ceil((c.scade - os.time()) / 60) }
            end
        else
            liberi[#liberi + 1] = { id = p.id, canone = p.canone }
        end
    end

    rispondi({
        mercato = m.id, nome = m.nome,
        liberi = liberi, mio = miei,
        licenza = haLicenza(g.citizenid),
        costoLicenza = MER.Licenza.costo,
    })
end)

AUREA.Callback.Registra('mer:licenza', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    if haLicenza(g.citizenid) then
        return rispondi(false, 'L\'autorizzazione ce l\'hai già ed è valida.')
    end

    if not g:SottraiOvunque(MER.Licenza.costo, 'autorizzazione al commercio su area pubblica') then
        return rispondi(false, ('L\'autorizzazione costa %s.'):format(U.Euro(MER.Licenza.costo)))
    end

    MySQL.insert.await([[
        INSERT INTO licenze (citizenid, tipo, rilascio, scadenza)
        VALUES (?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL ? DAY))
        ON DUPLICATE KEY UPDATE rilascio = CURDATE(),
            scadenza = DATE_ADD(CURDATE(), INTERVAL ? DAY), revocata = 0
    ]], { g.citizenid, MER.Licenza.tipo, MER.Licenza.validitaGiorni, MER.Licenza.validitaGiorni })

    TriggerEvent('aurea:fisco:incasso', 'diritti_comunali', MER.Licenza.costo, g.citizenid)
    AUREA.Log('economia', 'info', g, 'rilasciata autorizzazione al commercio su area pubblica')

    rispondi(true, ('%s rilasciata. Adesso ti serve un posteggio.'):format(MER.Licenza.etichetta))
end)

AUREA.Callback.Registra('mer:assegna', function(src, rispondi, idPosteggio)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    if not haLicenza(g.citizenid) then
        return rispondi(false, 'Prima l\'autorizzazione al commercio su area pubblica.')
    end

    local p, m = MER.GetPosteggio(idPosteggio)
    if not p then return rispondi(false, 'Posteggio inesistente.') end

    local c = concessioni[idPosteggio]
    if c and c.scade > os.time() then
        return rispondi(false, 'Quel posteggio è già assegnato.')
    end

    local gia = posteggioDi(g.citizenid)
    if gia then
        return rispondi(false, ('Hai già il posteggio %s: uno per licenza.'):format(gia))
    end

    local scade = os.time() + MER.Posteggio.minutiConcessione * 60
    local id = MySQL.insert.await([[
        INSERT INTO mercato_concessioni (posteggio, mercato, citizenid, canone, scade_il)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], { idPosteggio, m.id, g.citizenid, p.canone, scade })

    concessioni[idPosteggio] = {
        citizenid = g.citizenid, nome = g:NomeCompleto(), scade = scade, id = id,
    }

    -- Il canone non si paga allo sportello: si iscrive a ruolo, e la
    -- cartella arriva. È la TOSAP, e funziona esattamente così.
    pcall(function()
        exports.ita_fisco:IscriviTributo(g.citizenid, MER.Posteggio.tributoTipo,
            ('posteggio %s'):format(idPosteggio), p.canone)
    end)

    AUREA.Log('economia', 'info', g,
        ('assegnato il posteggio %s al %s'):format(idPosteggio, m.nome))

    rispondi(true, ('Posteggio %s assegnato per %d minuti.\nIl canone di %s è iscritto a ruolo: arriverà la cartella.')
        :format(idPosteggio, MER.Posteggio.minutiConcessione, U.Euro(p.canone)))
end)

-- ---------------------------------------------------------------------------
--  Il banco
-- ---------------------------------------------------------------------------
--- L'igiene di un posteggio. Vive con la concessione: chi prende il
--- posteggio lo trova pulito, e se lo lascia sporco è suo il problema.
local function igieneDi(idPosteggio)
    local c = concessioni[idPosteggio]
    if not c then return MER.Igiene.iniziale end
    if c.igiene == nil then c.igiene = MER.Igiene.iniziale end
    return c.igiene
end

exports('IgienePosteggio', igieneDi)

local function pezziEsposti(citizenid, banco)
    local b = MER.GetBanco(banco)
    if not b then return 0 end

    local ok, inv = pcall(function()
        return exports.aurea_inventory:Inventario(citizenid)
    end)
    if not ok or not inv then return 0 end

    local totale = 0
    for _, item in ipairs(b.items) do
        totale = totale + (inv:Quantita(item) or 0)
    end
    return totale
end

AUREA.Callback.Registra('mer:apri', function(src, rispondi, banco)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    if banchi[g.citizenid] then return rispondi(false, 'Il banco è già aperto.') end

    local b = MER.GetBanco(banco)
    if not b then return rispondi(false, 'Tipo di banco non previsto.') end

    if not haLicenza(g.citizenid) then
        return rispondi(false, 'Senza autorizzazione al commercio su area pubblica non si apre.')
    end

    local idPosteggio = posteggioDi(g.citizenid)
    if not idPosteggio then
        return rispondi(false, 'Non hai un posteggio assegnato: passa dallo sportello del mercato.')
    end

    local p, m = MER.GetPosteggio(idPosteggio)
    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - p.coord) > MER.Posteggio.raggio then
        return rispondi(false, ('Il tuo posteggio è il %s, e non è qui.'):format(idPosteggio))
    end

    -- L'igiene del banco. Non è quella dei locali dell'ASL — un banco non
    -- ha quattro mura — è il piano di vendita, che vendendo si sporca.
    if b.alimentare and igieneDi(idPosteggio) < MER.Igiene.soglia then
        return rispondi(false, ('Il banco è a %d/100 di igiene: sotto %d gli alimentari non si trattano. Serve il detergente.')
            :format(igieneDi(idPosteggio), MER.Igiene.soglia))
    end

    local pezzi = pezziEsposti(g.citizenid, banco)
    if pezzi <= 0 then
        return rispondi(false, 'Non hai niente da vendere di questo banco.')
    end

    banchi[g.citizenid] = {
        posteggio = idPosteggio, mercato = m.id, banco = banco,
        aperto = os.time(), prossimoCliente = os.time() + 8,
        cliente = nil,
        vendite = { battute = 0, nonBattute = 0, imponibileBattuto = 0, imponibileNon = 0 },
    }

    local moltiplicatore, fascia = MER.Afflusso(tonumber(os.date('%H')) or 12)

    rispondi(true, {
        banco = b.etichetta,
        posteggio = idPosteggio,
        pezzi = pezzi,
        fascia = fascia,
        afflusso = moltiplicatore,
    })
end)

AUREA.Callback.Registra('mer:chiudi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not banchi[g.citizenid] then return rispondi(false, 'Il banco non è aperto.') end

    local v = banchi[g.citizenid].vendite
    local minuti = math.floor((os.time() - banchi[g.citizenid].aperto) / 60)
    banchi[g.citizenid] = nil

    rispondi(true, {
        minuti = minuti,
        battute = v.battute, nonBattute = v.nonBattute,
        incassato = v.imponibileBattuto + v.imponibileNon,
    })
end)

-- ---------------------------------------------------------------------------
--  I clienti
--
--  Arrivano su un ciclo del server, non del client: un cliente che nasce
--  nel client sarebbe un cliente che si può moltiplicare.
-- ---------------------------------------------------------------------------
local function certificazioneDi(inv, item)
    -- Il lotto migliore che ho di quell'item decide il prezzo. Il
    -- moltiplicatore lo conosce ita_madeinitaly: se non c'è, si vende al
    -- prezzo nudo.
    local riga = inv:Trova(item, function(m) return m and m.qualita ~= nil end)
    local qualita = riga and riga.metadata and tonumber(riga.metadata.qualita) or nil
    if not qualita then return 1.0, nil, nil end

    local ok, cert = pcall(function()
        return exports.ita_madeinitaly:CertificazioneDi(qualita, riga.metadata.filiera)
    end)
    if ok and type(cert) == 'table' and cert.moltiplicatore then
        return cert.moltiplicatore, cert.id, qualita
    end

    -- Senza ita_madeinitaly la qualità vale ancora qualcosa, ma poco:
    -- da 50 a 100 si va da 1,0 a 1,5. Non si inventa una certificazione
    -- che solo quella risorsa può rilasciare.
    return 1.0 + math.max(0, (qualita - 50)) / 100, nil, qualita
end

local function nuovoCliente(citizenid, stato)
    local b = MER.GetBanco(stato.banco)
    if not b then return end

    local ok, inv = pcall(function()
        return exports.aurea_inventory:Inventario(citizenid)
    end)
    if not ok or not inv then return end

    -- Il cliente vuole una cosa fra quelle che HAI: un cliente che chiede
    -- quello che non c'è è solo un messaggio d'errore travestito.
    local disponibili = {}
    for _, item in ipairs(b.items) do
        local q = inv:Quantita(item) or 0
        if q > 0 then disponibili[#disponibili + 1] = { item = item, quantita = q } end
    end
    if #disponibili == 0 then return end

    local scelto = disponibili[math.random(#disponibili)]
    local quanti = math.min(scelto.quantita,
        math.random(MER.Clienti.quantitaMin, MER.Clienti.quantitaMax))

    local prezzoMercato = nil
    local okP, p = pcall(function()
        return exports.ita_economia:PrezzoDi(scelto.item)
    end)
    prezzoMercato = (okP and tonumber(p)) or nil
    if not prezzoMercato then
        -- Non tutti gli item del banco stanno nel listino all'ingrosso di
        -- ita_economia. Per quelli si usa il prezzo di riserva del banco:
        -- gli item di AUREA non hanno un prezzo intrinseco, e inventarne
        -- uno leggendo un campo che non esiste vorrebbe dire vendere
        -- tutto a zero.
        prezzoMercato = b.prezzoRiserva or 900
    end

    local molt, cert, qualita = certificazioneDi(inv, scelto.item)
    local unitario = MER.PrezzoAlBanco(prezzoMercato, molt)

    stato.cliente = {
        item = scelto.item,
        quantita = quanti,
        unitario = unitario,
        totale = unitario * quanti,
        certificazione = cert,
        qualita = qualita,
        scade = os.time() + MER.Clienti.secondiPazienza,
    }

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        local dati = AUREA.Item[scelto.item]
        TriggerClientEvent('mer:cliente', g.source, {
            item = scelto.item,
            etichetta = dati and dati.etichetta or scelto.item,
            quantita = quanti,
            totale = stato.cliente.totale,
            certificazione = cert,
            qualita = qualita,
            secondi = MER.Clienti.secondiPazienza,
        })
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local adesso = os.time()
        local ora = tonumber(os.date('%H')) or 12

        for citizenid, stato in pairs(banchi) do
            local g = AUREA.GetPlayerByCitizenId(citizenid)

            -- Chi se ne va, chiude il banco. Un banco senza banconiere non
            -- vende: è il senso di tutta la risorsa.
            if not g then
                banchi[citizenid] = nil
                goto prossimo
            end

            do
                local p = MER.GetPosteggio(stato.posteggio)
                if p and #(GetEntityCoords(GetPlayerPed(g.source)) - p.coord) > MER.Posteggio.raggio + 6.0 then
                    banchi[citizenid] = nil
                    TriggerClientEvent('mer:chiuso', g.source, 'Ti sei allontanato dal banco.')
                    goto prossimo
                end
            end

            -- Il cliente in attesa se ne va da solo
            if stato.cliente and adesso >= stato.cliente.scade then
                stato.cliente = nil
                TriggerClientEvent('mer:clientePerso', g.source)
            end

            if not stato.cliente and adesso >= stato.prossimoCliente then
                local afflusso = MER.Afflusso(ora)
                local m = MER.GetMercato(stato.mercato)
                local bonus = MER.BonusEsposto(pezziEsposti(citizenid, stato.banco))

                -- Il ritmo: più afflusso e più merce, meno attesa. Il
                -- minimo è otto secondi, perché un cliente al secondo non
                -- è un mercato, è un rubinetto.
                local attesa = MER.Clienti.secondiFraClienti
                    / math.max(0.05, afflusso * bonus)
                    * (22 / math.max(1, (m and m.afflussoBase or 22)))

                stato.prossimoCliente = adesso + math.max(8, math.floor(attesa))
                nuovoCliente(citizenid, stato)
            end

            ::prossimo::
        end
    end
end)

-- ---------------------------------------------------------------------------
--  La vendita
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mer:vendi', function(src, rispondi, battere)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    local stato = banchi[g.citizenid]
    if not stato then return rispondi(false, 'Il banco non è aperto.') end
    if not stato.cliente then return rispondi(false, 'Non c\'è nessun cliente al banco.') end

    local c = stato.cliente
    if os.time() >= c.scade then
        stato.cliente = nil
        return rispondi(false, 'Il cliente se n\'è andato.')
    end

    local ok, inv = pcall(function()
        return exports.aurea_inventory:Inventario(g.citizenid)
    end)
    if not ok or not inv then return rispondi(false, 'Errore sull\'inventario.') end

    if not inv:Ha(c.item, c.quantita) then
        stato.cliente = nil
        return rispondi(false, 'La merce non c\'è più.')
    end

    exports.aurea_inventory:Rimuovi(g.citizenid, c.item, c.quantita)

    battere = battere == true
    local netto = c.totale

    if battere then
        -- Lo scontrino: l'IVA è dentro il prezzo al pubblico, e si scorpora.
        local iva = math.floor(c.totale * MER.Scontrino.aliquota / (1 + MER.Scontrino.aliquota))
        netto = c.totale - iva
        TriggerEvent('aurea:fisco:incasso', 'iva', iva, g.citizenid)

        stato.vendite.battute = stato.vendite.battute + 1
        stato.vendite.imponibileBattuto = stato.vendite.imponibileBattuto + netto
    else
        stato.vendite.nonBattute = stato.vendite.nonBattute + 1
        stato.vendite.imponibileNon = stato.vendite.imponibileNon + c.totale
    end

    g:Aggiungi('contanti', netto, ('vendita al mercato — %s'):format(c.item))

    -- Il banco si sporca, e quando scende sotto soglia gli alimentari si
    -- fermano. Il banco resta aperto: è la merce che non si può più
    -- trattare, e per rimetterlo a posto serve il detergente.
    local banco = MER.GetBanco(stato.banco)
    if banco and banco.alimentare then
        local conc = concessioni[stato.posteggio]
        if conc then
            conc.igiene = math.max(0, igieneDi(stato.posteggio) - MER.Igiene.caloPerVendita)
            if conc.igiene < MER.Igiene.soglia then
                banchi[g.citizenid] = nil
                TriggerClientEvent('mer:chiuso', g.source,
                    ('Banco a %d/100 di igiene: gli alimentari non si trattano più. Passa il detergente.')
                        :format(conc.igiene))
            end
        end
    end

    MySQL.insert.await([[
        INSERT INTO mercato_vendite
            (citizenid, posteggio, item, quantita, importo, scontrino, certificazione)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { g.citizenid, stato.posteggio, c.item, c.quantita, c.totale,
          battere and 1 or 0, c.certificazione })

    stato.cliente = nil

    rispondi(true, {
        item = c.item, quantita = c.quantita,
        incassato = netto, lordo = c.totale,
        scontrino = battere,
        battute = stato.vendite.battute,
        nonBattute = stato.vendite.nonBattute,
    })
end)

AUREA.Callback.Registra('mer:sanifica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    local idPosteggio = posteggioDi(g.citizenid)
    if not idPosteggio then return rispondi(false, 'Non hai un posteggio.') end

    local p = MER.GetPosteggio(idPosteggio)
    if #(GetEntityCoords(GetPlayerPed(src)) - p.coord) > MER.Posteggio.raggio then
        return rispondi(false, 'Il banco si pulisce stando al banco.')
    end

    if igieneDi(idPosteggio) >= MER.Igiene.iniziale then
        return rispondi(false, 'Il banco è già pulito.')
    end

    local ok, ha = pcall(function()
        return exports.aurea_inventory:Ha(g.citizenid, MER.Igiene.item, 1)
    end)
    if not ok or not ha then
        return rispondi(false, 'Serve un detergente professionale.')
    end
    exports.aurea_inventory:Rimuovi(g.citizenid, MER.Igiene.item, 1)

    local conc = concessioni[idPosteggio]
    conc.igiene = math.min(MER.Igiene.iniziale, igieneDi(idPosteggio) + MER.Igiene.recupero)

    rispondi(true, ('Banco sanificato: %d/100.'):format(conc.igiene))
end)

-- ---------------------------------------------------------------------------
--  Il controllo della Guardia di Finanza
--
--  Guarda il REGISTRO, non il contatore in memoria: un controllo che si
--  fida di quello che dice il banco non controlla niente. E guarda la
--  sessione intera, non l'ultima vendita — è quello che rende
--  l'evasione una scommessa e non un'abitudine sicura.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mer:controlla', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio
       or not U.Contiene(MER.Scontrino.controllo.lavori, g.lavoro.nome) then
        return rispondi(false, 'Il controllo sugli scontrini lo fa la Guardia di Finanza.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc) or 0)
    if not b then return rispondi(false, 'Nessun esercente davanti a te.') end

    local stato = banchi[b.citizenid]
    if not stato then
        -- Chi vende senza posteggio è un abusivo, e questo lo si vede
        -- anche a banco chiuso.
        return rispondi(false, 'Questa persona non ha un banco aperto.')
    end

    if (ultimoControllo[b.citizenid] or 0)
       + MER.Scontrino.controllo.minutiFraControlli * 60 > os.time() then
        return rispondi(false, 'Su questo banco c\'è già stato un controllo di recente.')
    end
    ultimoControllo[b.citizenid] = os.time()

    local riga = MySQL.single.await([[
        SELECT COUNT(*) AS totali,
               SUM(scontrino = 0) AS non_battute,
               SUM(CASE WHEN scontrino = 0 THEN importo ELSE 0 END) AS imponibile_non
        FROM mercato_vendite
        WHERE citizenid = ? AND venduto_il >= FROM_UNIXTIME(?)
    ]], { b.citizenid, stato.aperto })

    local totali = tonumber(riga and riga.totali) or 0
    local nonBattute = tonumber(riga and riga.non_battute) or 0
    local imponibileNon = tonumber(riga and riga.imponibile_non) or 0

    if totali == 0 then
        return rispondi(true, {
            esercente = b:NomeCompleto(), totali = 0, nonBattute = 0,
            quota = 0, sanzione = 0, sospeso = false,
        })
    end

    local quota = nonBattute / totali
    local sanzione, sospeso = 0, false

    if quota >= MER.Scontrino.controllo.sogliaEvasione then
        sanzione = math.max(MER.Scontrino.controllo.sanzioneMinima,
            math.floor(imponibileNon * MER.Scontrino.controllo.quotaSanzione))

        exports.ita_codicestrada:EmettiVerbale({
            citizenid = b.citizenid,
            articolo = MER.Scontrino.controllo.articolo,
            descrizione = ('Omessa certificazione dei corrispettivi — %d vendite su %d senza scontrino')
                :format(nonBattute, totali),
            importo = sanzione, punti = 0,
            origine = 'agente', agente = g:NomeCompleto(),
            luogo = ('posteggio %s'):format(stato.posteggio),
        })

        if quota >= MER.Scontrino.controllo.sogliaSospensione then
            sospeso = true
            banchi[b.citizenid] = nil
            TriggerClientEvent('mer:chiuso', b.source,
                ('Banco chiuso d\'autorità: %d%% delle vendite senza scontrino.')
                    :format(math.floor(quota * 100)))
        end
    end

    MySQL.insert.await([[
        INSERT INTO mercato_controlli
            (citizenid, operatore, posteggio, vendite, non_battute, sanzione, sospeso)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { b.citizenid, g.citizenid, stato.posteggio, totali, nonBattute,
          sanzione, sospeso and 1 or 0 })

    AUREA.Log('economia', sanzione > 0 and 'avviso' or 'info', g,
        ('controllo scontrini su %s: %d/%d non battute'):format(b.citizenid, nonBattute, totali))

    rispondi(true, {
        esercente = b:NomeCompleto(),
        totali = totali, nonBattute = nonBattute,
        quota = math.floor(quota * 100),
        imponibileNon = imponibileNon,
        sanzione = sanzione, sospeso = sospeso,
    })
end)

-- ---------------------------------------------------------------------------
--  L'abusivo
--
--  Chi vende sull'area pubblica senza autorizzazione. Non serve un banco
--  aperto per contestarlo: serve che non abbia la licenza e che stia
--  dentro un mercato.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mer:abusivo', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio
       or not U.Contiene(MER.Scontrino.controllo.lavori, g.lavoro.nome) then
        return rispondi(false, 'Serve essere in servizio in una forza di polizia.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc) or 0)
    if not b then return rispondi(false, 'Nessuno davanti a te.') end

    local coord = GetEntityCoords(GetPlayerPed(b.source))
    local dentroMercato = nil
    for _, m in ipairs(MER.Mercati) do
        for _, p in ipairs(m.posteggi) do
            if #(coord - p.coord) <= 25.0 then dentroMercato = m break end
        end
        if dentroMercato then break end
    end

    if not dentroMercato then
        return rispondi(false, 'Non siete in un\'area di mercato: non c\'è commercio su area pubblica da contestare.')
    end

    if haLicenza(b.citizenid) and posteggioDi(b.citizenid) then
        return rispondi(false, 'Ha autorizzazione e posteggio: è tutto in regola.')
    end

    local senzaLicenza = not haLicenza(b.citizenid)
    local importo = senzaLicenza and MER.Licenza.sanzione or MER.Posteggio.sanzioneAbusivo
    local articolo = senzaLicenza and MER.Licenza.articolo or MER.Posteggio.articoloAbusivo

    exports.ita_codicestrada:EmettiVerbale({
        citizenid = b.citizenid,
        articolo = articolo,
        descrizione = senzaLicenza
            and 'Commercio su area pubblica senza autorizzazione'
            or 'Occupazione di posteggio non assegnato',
        importo = importo, punti = 0,
        origine = 'agente', agente = g:NomeCompleto(),
        luogo = dentroMercato.nome,
    })

    banchi[b.citizenid] = nil

    -- Il sequestro della merce. È la parte che fa male, ed è quella vera:
    -- all'abusivo si sequestra il banco, non si scrive una lettera.
    local sequestrati = 0
    local okI, inv = pcall(function()
        return exports.aurea_inventory:Inventario(b.citizenid)
    end)
    if okI and inv and g:HaPermessoLavoro('sequestro') then
        for _, banco in pairs(MER.Banchi) do
            for _, item in ipairs(banco.items) do
                local q = inv:Quantita(item) or 0
                if q > 0 then
                    exports.aurea_inventory:Rimuovi(b.citizenid, item, q)
                    sequestrati = sequestrati + q
                end
            end
        end
    end

    AUREA.Log('economia', 'avviso', g,
        ('contestato commercio abusivo a %s, %d pezzi sequestrati'):format(b.citizenid, sequestrati))

    rispondi(true, {
        persona = b:NomeCompleto(),
        motivo = senzaLicenza and 'senza autorizzazione' or 'posteggio non assegnato',
        importo = importo,
        sequestrati = sequestrati,
    })
end)

-- ---------------------------------------------------------------------------
--  Stato del banco, per l'interfaccia
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mer:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local stato = banchi[g.citizenid]
    if not stato then return rispondi({ aperto = false }) end

    local afflusso, fascia = MER.Afflusso(tonumber(os.date('%H')) or 12)
    rispondi({
        aperto = true,
        banco = MER.GetBanco(stato.banco).etichetta,
        posteggio = stato.posteggio,
        minuti = math.floor((os.time() - stato.aperto) / 60),
        pezzi = pezziEsposti(g.citizenid, stato.banco),
        fascia = fascia, afflusso = afflusso,
        igiene = igieneDi(stato.posteggio),
        alimentare = MER.GetBanco(stato.banco).alimentare == true,
        battute = stato.vendite.battute,
        nonBattute = stato.vendite.nonBattute,
        incassato = stato.vendite.imponibileBattuto + stato.vendite.imponibileNon,
    })
end)

-- ---------------------------------------------------------------------------
--  Scadenze
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        for id, c in pairs(concessioni) do
            if c.scade <= os.time() then
                MySQL.update.await(
                    'UPDATE mercato_concessioni SET scaduta = 1 WHERE id = ?', { c.id })
                concessioni[id] = nil
                banchi[c.citizenid] = nil

                local g = AUREA.GetPlayerByCitizenId(c.citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '🏪', durata = 14000,
                        titolo = 'Concessione scaduta',
                        testo = ('Il posteggio %s è tornato libero. Rinnovalo allo sportello.'):format(id),
                    })
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    local righe = MySQL.query.await([[
        SELECT c.id, c.posteggio, c.citizenid, UNIX_TIMESTAMP(c.scade_il) AS scade,
               CONCAT(p.nome, ' ', p.cognome) AS nome
        FROM mercato_concessioni c
        LEFT JOIN personaggi p ON p.citizenid = c.citizenid
        WHERE c.scaduta = 0 AND c.scade_il > NOW()
    ]]) or {}

    for _, r in ipairs(righe) do
        concessioni[r.posteggio] = {
            id = r.id, citizenid = r.citizenid, nome = r.nome,
            scade = r.scade or os.time(),
        }
    end

    if #righe > 0 then
        print(('[AUREA] mercato: %d posteggi assegnati'):format(#righe))
    end
end)
