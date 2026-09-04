--[[
    AUREA · Made in Italy (server)

    La lavorazione è sempre validata qui: quantità, prossimità, materie prime
    e tempo trascorso. Il client dice soltanto "ho finito", non quanto ha reso.
]]

local U = AUREA.Util
local lavorazioni = {}      -- [src] = { filiera, postazione, avviata }

-- ---------------------------------------------------------------------------
--  Maestria
-- ---------------------------------------------------------------------------
local function maestria(citizenid, disciplina)
    local riga = MySQL.single.await('SELECT xp, livello FROM maestria WHERE citizenid = ? AND disciplina = ?',
        { citizenid, disciplina })
    if riga then return riga.xp, riga.livello end
    return 0, 1
end

local function aggiungiXP(citizenid, disciplina, xp)
    local attuali = select(1, maestria(citizenid, disciplina))
    local nuovi = attuali + xp
    local livelloPrima = MIT.Livello(attuali)
    local livelloDopo = MIT.Livello(nuovi)

    MySQL.query.await([[
        INSERT INTO maestria (citizenid, disciplina, xp, livello) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = VALUES(xp), livello = VALUES(livello)
    ]], { citizenid, disciplina, nuovi, livelloDopo })

    if livelloDopo > livelloPrima then
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        if g then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'successo', icona = '🏅', durata = 12000,
                titolo = ('%s — livello %d'):format(disciplina:gsub('^%l', string.upper), livelloDopo),
                testo = ('Sei diventato %s. La qualità dei tuoi lotti aumenta.'):format(MIT.Titolo(livelloDopo)),
            })
        end
    end

    return nuovi, livelloDopo
end

-- ---------------------------------------------------------------------------
--  Calcolo della qualità di un lotto
-- ---------------------------------------------------------------------------

--- La qualità nasce dalla maestria, dalle materie prime usate e dalla
--- precisione dell'esecuzione. Non è mai deterministica del tutto.
local function calcolaQualita(livello, qualitaMateriePrime, precisione, affinato)
    -- base: 30 punti, più 4 per livello di maestria
    local base = 30 + (livello - 1) * MIT.Maestria.bonusQualitaPerLivello

    -- le materie prime pesano per un terzo
    if qualitaMateriePrime then
        base = base + (qualitaMateriePrime - 50) * 0.35
    end

    -- precisione dell'esecuzione (0..1)
    base = base + (precisione or 0.7) * 18

    -- affinamento completato
    if affinato then base = base + affinato end

    -- variabilità artigianale
    base = base + math.random(-6, 6)

    return math.floor(U.Clamp(base, 0, 100))
end

--- Qualità media dei lotti consumati come materia prima.
local function qualitaMateriePrime(inventario, richieste)
    local somma, conteggio = 0, 0
    for _, r in ipairs(richieste or {}) do
        local riga = inventario:Trova(r.item, function(m) return m.qualita ~= nil end)
        if riga and riga.metadata and riga.metadata.qualita then
            somma = somma + riga.metadata.qualita
            conteggio = conteggio + 1
        end
    end
    if conteggio == 0 then return nil end
    return somma / conteggio
end

-- ---------------------------------------------------------------------------
--  Avvio della lavorazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mit:avvia', function(src, rispondi, filiera, idPostazione)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local postazione, f = MIT.GetPostazione(filiera, idPostazione)
    if not postazione then return rispondi(false, 'Postazione non riconosciuta.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - postazione.coord) > 6.0 then return rispondi(false, 'Non sei alla postazione.') end

    local xp, livello = maestria(g.citizenid, f.disciplina)
    if postazione.livelloMinimo and livello < postazione.livelloMinimo then
        return rispondi(false, ('Serve il livello %d in %s. Sei al livello %d.'):format(
            postazione.livelloMinimo, f.disciplina, livello))
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    for _, r in ipairs(postazione.richiede or {}) do
        if not inventario:Ha(r.item, r.quantita) then
            local dati = AUREA.Item[r.item]
            return rispondi(false, ('Servono %d× %s.'):format(r.quantita, dati and dati.etichetta or r.item))
        end
    end

    lavorazioni[src] = {
        filiera = filiera,
        postazione = idPostazione,
        avviata = os.time(),
        qualitaMateriePrime = qualitaMateriePrime(inventario, postazione.richiede),
    }

    rispondi(true, nil, {
        durata = postazione.durata,
        azione = postazione.azione,
        anim = postazione.anim,
        precisione = postazione.finestraPrecisione or false,
    })
end)

-- ---------------------------------------------------------------------------
--  Conclusione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mit:concludi', function(src, rispondi, precisione)
    local g = AUREA.GetPlayer(src)
    local lav = lavorazioni[src]
    if not g or not lav then return rispondi(false, 'Nessuna lavorazione in corso.') end
    lavorazioni[src] = nil

    local postazione, f = MIT.GetPostazione(lav.filiera, lav.postazione)
    if not postazione then return rispondi(false, 'Postazione non riconosciuta.') end

    -- Il server verifica che sia trascorso davvero il tempo di lavorazione
    local trascorso = (os.time() - lav.avviata) * 1000
    if trascorso < (postazione.durata * 0.8) then
        AUREA.Log('anticheat', 'allarme', g, ('lavorazione %s conclusa in %d ms su %d'):format(
            postazione.id, trascorso, postazione.durata))
        return rispondi(false, 'Lavorazione non valida.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - postazione.coord) > 8.0 then return rispondi(false, 'Ti sei allontanato dalla postazione.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    -- Consumo delle materie prime (ricontrollato adesso)
    for _, r in ipairs(postazione.richiede or {}) do
        if not inventario:Ha(r.item, r.quantita) then
            return rispondi(false, 'Le materie prime non sono più disponibili.')
        end
    end
    for _, r in ipairs(postazione.richiede or {}) do
        inventario:Rimuovi(r.item, r.quantita)
    end

    local xp, livello = maestria(g.citizenid, f.disciplina)
    precisione = U.Clamp(tonumber(precisione) or 0.7, 0, 1)

    -- Stagione favorevole: la raccolta rende di più
    local moltiplicatoreResa = 1.0
    if postazione.stagioneOttimale then
        local mese = tonumber(os.date('%m'))
        if U.Contiene(postazione.stagioneOttimale, mese) then
            moltiplicatoreResa = 1.5
        end
    end

    local qualita = calcolaQualita(livello, lav.qualitaMateriePrime, precisione, nil)
    local lotto = ('%s-%s-%s'):format(f.disciplina:sub(1, 3):upper(), os.date('%y%m%d'), U.Random(4))

    -- Prodotto superiore se la qualità lo consente
    local prodotti = {}
    for _, p in ipairs(postazione.produce) do
        local quantita = math.max(1, math.floor(math.random(p.min, p.max) * moltiplicatoreResa))
        local item = p.item

        if postazione.sbloccaSuperiore and qualita >= postazione.sbloccaSuperiore.qualitaMinima then
            item = postazione.sbloccaSuperiore.item
            quantita = math.max(1, math.floor(quantita * 0.6))
        end

        prodotti[#prodotti + 1] = { item = item, quantita = quantita }
    end

    -- Affinamento: il lotto resta in attesa e va ritirato più tardi
    if postazione.affinamentoMinuti then
        local id = MySQL.insert.await([[
            INSERT INTO produzioni (citizenid, filiera, prodotto, qualita, quantita, lotto, stagionatura_fine)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            g.citizenid, lav.filiera, prodotti[1].item, qualita, prodotti[1].quantita, lotto,
            U.DataOraPiuOre(postazione.affinamentoMinuti / 60),
        })

        aggiungiXP(g.citizenid, f.disciplina, postazione.xp)
        return rispondi(true, ('Lotto %s messo ad affinare. Torna fra %d minuti: l\'attesa alza la qualità di %d punti.'):format(
            lotto, postazione.affinamentoMinuti, postazione.affinamentoBonus), { affinamento = true, lotto = lotto })
    end

    -- Consegna immediata
    local consegnati = {}
    for _, p in ipairs(prodotti) do
        local ok = inventario:Aggiungi(p.item, p.quantita, {
            qualita = qualita, lotto = lotto, filiera = lav.filiera,
            produttore = g:NomeCompleto(),
        })
        if ok then consegnati[#consegnati + 1] = ('%d× %s'):format(p.quantita, AUREA.Item[p.item].etichetta) end
    end

    if #consegnati == 0 then
        return rispondi(false, 'Inventario pieno: la lavorazione è andata persa.')
    end

    MySQL.insert('INSERT INTO produzioni (citizenid, filiera, prodotto, qualita, quantita, lotto) VALUES (?, ?, ?, ?, ?, ?)',
        { g.citizenid, lav.filiera, prodotti[1].item, qualita, prodotti[1].quantita, lotto })

    aggiungiXP(g.citizenid, f.disciplina, postazione.xp)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local certificabile = MIT.CertificazionePer(qualita, lav.filiera)

    rispondi(true, ('%s · lotto %s · qualità %d/100%s'):format(
        table.concat(consegnati, ', '), lotto, qualita,
        certificabile.id ~= 'nessuna' and (' — certificabile ' .. certificabile.etichetta) or ''),
        { qualita = qualita, lotto = lotto })
end)

-- ---------------------------------------------------------------------------
--  Ritiro dei lotti affinati
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mit:lottiPronti', function(src, rispondi, filiera)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, filiera, prodotto, qualita, quantita, lotto, stagionatura_fine,
               TIMESTAMPDIFF(MINUTE, NOW(), stagionatura_fine) AS minuti_mancanti
        FROM produzioni
        WHERE citizenid = ? AND stagionatura_fine IS NOT NULL AND filiera = ?
        ORDER BY stagionatura_fine ASC
    ]], { g.citizenid, filiera }) or {}

    for _, r in ipairs(righe) do
        local dati = AUREA.Item[r.prodotto]
        r.etichetta = dati and dati.etichetta or r.prodotto
        r.pronto = (r.minuti_mancanti or 0) <= 0
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('mit:ritira', function(src, rispondi, idLotto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local riga = MySQL.single.await([[
        SELECT *, TIMESTAMPDIFF(MINUTE, NOW(), stagionatura_fine) AS minuti_mancanti
        FROM produzioni WHERE id = ? AND citizenid = ?
    ]], { idLotto, g.citizenid })
    if not riga then return rispondi(false, 'Lotto non trovato.') end
    if (riga.minuti_mancanti or 0) > 0 then
        return rispondi(false, ('Mancano ancora %d minuti di affinamento.'):format(riga.minuti_mancanti))
    end

    local f = MIT.Filiere[riga.filiera]
    local bonus = 0
    for _, p in ipairs(f and f.postazioni or {}) do
        if p.affinamentoBonus then bonus = p.affinamentoBonus break end
    end

    local qualitaFinale = math.min(100, riga.qualita + bonus)

    -- Con la qualità alzata dall'affinamento può scattare il prodotto superiore
    local prodotto = riga.prodotto
    for _, p in ipairs(f and f.postazioni or {}) do
        if p.sbloccaSuperiore and qualitaFinale >= p.sbloccaSuperiore.qualitaMinima then
            prodotto = p.sbloccaSuperiore.item
        end
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local ok = inventario:Aggiungi(prodotto, riga.quantita, {
        qualita = qualitaFinale, lotto = riga.lotto, filiera = riga.filiera,
        produttore = g:NomeCompleto(), affinato = true,
    })
    if not ok then return rispondi(false, 'Inventario pieno: libera spazio e riprova.') end

    MySQL.update.await('UPDATE produzioni SET stagionatura_fine = NULL, qualita = ?, prodotto = ? WHERE id = ?',
        { qualitaFinale, prodotto, idLotto })

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local certificabile = MIT.CertificazionePer(qualitaFinale, riga.filiera)
    rispondi(true, ('Ritirato il lotto %s: %d× %s, qualità %d/100%s'):format(
        riga.lotto, riga.quantita, AUREA.Item[prodotto].etichetta, qualitaFinale,
        certificabile.id ~= 'nessuna' and (' — certificabile ' .. certificabile.etichetta) or ''))
end)

-- ---------------------------------------------------------------------------
--  Consorzio di tutela: certificazione dei lotti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mit:certificabili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local out = {}

    for _, riga in ipairs(inventario.item) do
        local m = riga.metadata
        if m and m.qualita and (not m.certificazione or m.certificazione == 'nessuna') then
            local certificabile = MIT.CertificazionePer(m.qualita, m.filiera)
            if certificabile.id ~= 'nessuna' then
                out[#out + 1] = {
                    slot = riga.slot,
                    item = riga.nome,
                    etichetta = AUREA.Item[riga.nome].etichetta,
                    quantita = riga.quantita,
                    qualita = m.qualita,
                    lotto = m.lotto,
                    certificazione = certificabile.id,
                    certificazioneEtichetta = certificabile.etichetta,
                    costo = certificabile.costo,
                    moltiplicatore = certificabile.moltiplicatore,
                }
            end
        end
    end

    rispondi(out)
end)

AUREA.Callback.Registra('mit:certifica', function(src, rispondi, slot)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - MIT.Consorzio.coord) > 4.0 then return rispondi(false, 'Devi essere al Consorzio di Tutela.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local riga = inventario:GetSlot(slot)
    if not riga or not riga.metadata or not riga.metadata.qualita then
        return rispondi(false, 'Questo lotto non è certificabile.')
    end
    if riga.metadata.certificazione and riga.metadata.certificazione ~= 'nessuna' then
        return rispondi(false, 'Il lotto è già certificato.')
    end

    local certificazione = MIT.CertificazionePer(riga.metadata.qualita, riga.metadata.filiera)
    if certificazione.id == 'nessuna' then
        return rispondi(false, ('Qualità %d insufficiente: serve almeno 60 per la IGP.'):format(riga.metadata.qualita))
    end

    if not g:SottraiOvunque(certificazione.costo, ('certificazione %s'):format(certificazione.etichetta)) then
        return rispondi(false, ('La pratica costa %s.'):format(U.Euro(certificazione.costo)))
    end

    riga.metadata.certificazione = certificazione.id
    inventario.sporco = true

    MySQL.update('UPDATE produzioni SET certificazione = ? WHERE lotto = ? AND citizenid = ?',
        { certificazione.id, riga.metadata.lotto, g.citizenid })

    TriggerEvent('aurea:fisco:incasso', 'diritti_consorzio', certificazione.costo, g.citizenid)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    AUREA.Log('economia', 'info', g, ('lotto %s certificato %s'):format(riga.metadata.lotto, certificazione.id))
    rispondi(true, ('Lotto %s certificato %s. Il valore di mercato sale del %d%%.'):format(
        riga.metadata.lotto, certificazione.etichetta,
        math.floor((certificazione.moltiplicatore - 1) * 100)))
end)

-- ---------------------------------------------------------------------------
--  Stato della maestria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('mit:maestria', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await('SELECT disciplina, xp, livello FROM maestria WHERE citizenid = ?', { g.citizenid }) or {}
    for _, r in ipairs(righe) do
        r.titolo = MIT.Titolo(r.livello)
        r.prossima = MIT.ProssimaSoglia(r.xp)
    end
    rispondi(righe)
end)

AddEventHandler('playerDropped', function() lavorazioni[source] = nil end)
