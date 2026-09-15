--[[
    AUREA · Dogane (server)

    Due numeri non devono mai stare sullo stesso lato del filo: quanto c'è
    davvero nel container, e quanto l'importatore ha dichiarato. Il primo
    lo sa solo il server. Il secondo lo scrive il giocatore.

    Il canale di controllo si estrae qui, alla presentazione della
    bolletta, e viene comunicato subito — ma la visita merce la fa un
    funzionario in carne e ossa, e finché non arriva il container resta
    lì. È il tempo in cui si può provare a farlo sparire.
]]

local U = AUREA.Util

local container = {}    -- [id] = { partita, dichiarato, canale, importatore, ... }
local contatore = 0

-- ---------------------------------------------------------------------------
--  Chi controlla
-- ---------------------------------------------------------------------------
local function funzionario(g)
    return g and g.lavoro.nome == DOG.Lavoro and g.lavoro.servizio
end

local function precedentiDi(citizenid)
    return MySQL.scalar.await(
        'SELECT COUNT(*) FROM dogana_bollette WHERE importatore = ? AND esito = ?',
        { citizenid, 'contrabbando' }) or 0
end

--- Il posto libero sul piazzale, o nil se è pieno.
local function postoLibero()
    local occupati = {}
    for _, c in pairs(container) do occupati[c.posto] = true end
    for i = 1, #DOG.Terminal.piazzale do
        if not occupati[i] then return i end
    end
end

local function pubblica()
    local elenco = {}
    for id, c in pairs(container) do
        elenco[#elenco + 1] = {
            id = id, posto = c.posto, partita = c.partita,
            canale = c.canale, svincolato = c.svincolato,
        }
    end
    TriggerClientEvent('dog:container', -1, elenco)
end

-- ---------------------------------------------------------------------------
--  Liquidazione dei tributi
-- ---------------------------------------------------------------------------
local function liquida(partita, valoreDichiarato)
    local dazio = math.floor(valoreDichiarato * partita.dazio)
    local accisa = math.floor(valoreDichiarato * (partita.accisa or 0))
    local imponibileIva = valoreDichiarato + dazio + accisa
    local iva = math.floor(imponibileIva * DOG.Tributi.iva)
    return dazio + accisa + iva + DOG.Tributi.dirittiDoganali, dazio, accisa, iva
end

-- ---------------------------------------------------------------------------
--  Presentazione della bolletta
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dog:importa', function(src, rispondi, partitaId, valoreEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local p = DOG.GetPartita(partitaId)
    if not p then return rispondi(false, 'Partita non a catalogo.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - DOG.Ufficio.coord) > 6.0 then
        return rispondi(false, 'La bolletta si presenta allo sportello doganale.')
    end

    if p.soloConLicenza then
        local lic = MySQL.scalar.await(
            'SELECT id FROM dogana_licenze WHERE citizenid = ? AND scade_il > NOW() LIMIT 1', { g.citizenid })
        if not lic then
            return rispondi(false, 'Questa partita è soggetta a monopolio: serve la licenza di importazione.')
        end
    end

    local posto = postoLibero()
    if not posto then return rispondi(false, 'Il piazzale è pieno. Aspetta che qualcuno svincoli.') end

    -- Il costo della merce all'origine: si paga sempre, comunque vada
    if not g:Sottrai('banca', p.costo, ('acquisto partita %s'):format(p.nome)) then
        return rispondi(false, ('Servono %s per la partita.'):format(U.Euro(p.costo)))
    end

    local dichiarato = U.ACentesimi(tonumber(tostring(valoreEuro):gsub(',', '.')) or 0)
    dichiarato = math.max(0, math.min(dichiarato, p.valoreReale))

    local scostamento = (p.valoreReale - dichiarato) / p.valoreReale
    local canale = DOG.EstraiCanale(scostamento, precedentiDi(g.citizenid))

    local dovuto, dazio, accisa, iva = liquida(p, dichiarato)

    contatore = contatore + 1
    local id = contatore

    local bolletta = MySQL.insert.await([[
        INSERT INTO dogana_bollette
            (importatore, partita, valore_reale, valore_dichiarato, tributi, canale)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { g.citizenid, partitaId, p.valoreReale, dichiarato, dovuto, canale })

    container[id] = {
        id = id, bolletta = bolletta, partita = partitaId,
        importatore = g.citizenid, nomeImportatore = g:NomeCompleto(),
        dichiarato = dichiarato, reale = p.valoreReale,
        tributi = dovuto, canale = canale, posto = posto,
        presentata = os.time(), svincolato = false,
    }

    exports.ita_fisco:IscriviTributo(g.citizenid, 'dogana',
        ('bolletta %d — %s'):format(bolletta, p.nome), dovuto, DOG.Tributi.giorniPagamento)

    pubblica()

    local c = DOG.Canali[canale]
    if c.controlla then
        exports.aurea_ui:NotificaLavoro(DOG.Lavoro, {
            tipo = 'avviso', icona = '🛃', durata = 18000,
            titolo = ('%s %s — bolletta %d'):format(c.icona, c.nome, bolletta),
            testo = ('%s ha presentato una %s. %s Usa /visitamerce al terminal.')
                :format(g:NomeCompleto(), p.nome, c.testo),
        }, true)
    end

    AUREA.Log('economia', 'info', g,
        ('bolletta %d: %s dichiarata %s su %s, canale %s')
            :format(bolletta, p.nome, U.Euro(dichiarato), U.Euro(p.valoreReale), canale))

    rispondi(true, ('%s %s\n%s\n\nTributi liquidati: %s (dazio %s · accisa %s · IVA %s).\nIl container è al posto %d del piazzale.')
        :format(c.icona, c.nome, c.testo, U.Euro(dovuto), U.Euro(dazio), U.Euro(accisa), U.Euro(iva), posto))
end)

-- ---------------------------------------------------------------------------
--  Svincolo: l'importatore ritira la merce
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dog:svincola', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local c = container[tonumber(id) or 0]
    if not c then return rispondi(false, 'Container non trovato.') end
    if c.importatore ~= g.citizenid then return rispondi(false, 'Non è la tua merce.') end

    local coord = DOG.Terminal.piazzale[c.posto]
    if #(GetEntityCoords(GetPlayerPed(src)) - coord) > 5.0 then
        return rispondi(false, 'Devi essere al container.')
    end

    -- Il canale rosso e l'arancione trattengono la merce finché un
    -- funzionario non l'ha vista. Provare a portarla via prima è
    -- sottrazione di merce vincolata.
    if DOG.Canali[c.canale].controlla and not c.controllato then
        return rispondi(false, ('%s: il container è vincolato al controllo. Finché non passa la Finanza non si tocca.')
            :format(DOG.Canali[c.canale].nome))
    end

    local p = DOG.GetPartita(c.partita)
    local dati = {}
    for item, quanti in pairs(p.resa) do
        if exports.aurea_inventory:Aggiungi(g.citizenid, item, quanti) then
            dati[#dati + 1] = ('%d × %s'):format(quanti, AUREA.Item[item].etichetta)
        end
    end

    if #dati == 0 then
        return rispondi(false, 'Non hai spazio addosso: la merce pesa, serve un mezzo.')
    end

    MySQL.update('UPDATE dogana_bollette SET esito = ?, chiusa_il = NOW() WHERE id = ?',
        { 'svincolata', c.bolletta })

    container[c.id] = nil
    pubblica()

    AUREA.Log('economia', 'info', g, ('ha svincolato la bolletta %d'):format(c.bolletta))
    rispondi(true, ('Merce svincolata: %s.'):format(table.concat(dati, ', ')))
end)

-- ---------------------------------------------------------------------------
--  Visita merce
--
--  Il momento in cui i due numeri si incontrano.
-- ---------------------------------------------------------------------------
AUREA.Comando('visitamerce', 'utente', 'Controlla il container doganale che hai davanti', {},
function(src, _, _, g)
    if not funzionario(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🛃', titolo = 'Non autorizzato',
            testo = 'La visita merce la esegue la Guardia di Finanza in servizio.',
        })
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local c
    for _, x in pairs(container) do
        if #(coord - DOG.Terminal.piazzale[x.posto]) <= 5.0 then c = x end
    end

    if not c then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🛃', titolo = 'Nessun container',
            testo = 'Non c\'è nessun container in attesa qui.',
        })
    end

    local p = DOG.GetPartita(c.partita)
    c.controllato = true

    local scoperto = c.reale - c.dichiarato

    -- Lo scanner vede la sagoma, non il valore: rileva solo scostamenti
    -- grossolani. La visita merce vede tutto.
    if DOG.Canali[c.canale].controlla == 'scanner' and scoperto < c.reale * 0.30 then
        pubblica()
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🟠', durata = 16000,
            titolo = 'Scanner — nessuna anomalia',
            testo = ('%s di %s. La sagoma corrisponde alla bolletta. Svincolabile.')
                :format(p.nome, c.nomeImportatore),
        })
    end

    if scoperto <= 0 then
        pubblica()
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🛃', durata = 16000,
            titolo = 'Visita merce — regolare',
            testo = ('%s di %s: dichiarazione congrua, %s. Niente da contestare.')
                :format(p.nome, c.nomeImportatore, U.Euro(c.reale)),
        })
    end

    -- Contrabbando
    local _, dazioReale, accisaReale, ivaReale = liquida(p, c.reale)
    local _, dazioDich, accisaDich, ivaDich = liquida(p, c.dichiarato)
    local evaso = (dazioReale + accisaReale + ivaReale) - (dazioDich + accisaDich + ivaDich)

    local moltiplicatore = DOG.Sanzioni.moltiplicatoreMinimo
        + (DOG.Sanzioni.moltiplicatoreMassimo - DOG.Sanzioni.moltiplicatoreMinimo)
          * math.min(1, scoperto / c.reale)
    local sanzione = math.floor(evaso * moltiplicatore)

    exports.ita_fisco:IscriviTributo(c.importatore, 'sanzione',
        ('contrabbando — bolletta %d'):format(c.bolletta), sanzione + evaso, 7)

    local penale = evaso >= DOG.Sanzioni.sogliaPenale
    if penale then
        TriggerEvent('aurea:giustizia:apriFascicolo', c.importatore,
            p.reatoSeSottodichiarata or '292', g:NomeCompleto(),
            ('Bolletta %d: dichiarati %s a fronte di %s. Tributo evaso %s.')
                :format(c.bolletta, U.Euro(c.dichiarato), U.Euro(c.reale), U.Euro(evaso)))
    end

    MySQL.update('UPDATE dogana_bollette SET esito = ?, sanzione = ?, chiusa_il = NOW() WHERE id = ?',
        { 'contrabbando', sanzione, c.bolletta })

    container[c.id] = nil
    pubblica()

    local importatore = AUREA.GetPlayerByCitizenId(c.importatore)
    if importatore then
        TriggerClientEvent('aurea:ui:notifica', importatore.source, {
            tipo = 'errore', icona = '🔴', durata = 25000,
            titolo = 'Merce sequestrata',
            testo = ('Visita merce sulla bolletta %d: dichiarati %s su %s.\nTributo evaso %s, sanzione %s.%s')
                :format(c.bolletta, U.Euro(c.dichiarato), U.Euro(c.reale),
                        U.Euro(evaso), U.Euro(sanzione),
                        penale and '\nSegue denuncia all\'autorità giudiziaria.' or ''),
        })
    end
    TriggerEvent('aurea:telefono:messaggioSistema', c.importatore, 'Dogane',
        ('Bolletta %d: merce confiscata, sanzione %s.'):format(c.bolletta, U.Euro(sanzione)))

    AUREA.Log('giustizia', 'avviso', g,
        ('ha scoperto contrabbando sulla bolletta %d (%s evasi)'):format(c.bolletta, U.Euro(evaso)))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🔴', durata = 25000,
        titolo = 'Contrabbando accertato',
        testo = ('%s di %s.\nDichiarati %s su %s reali.\nTributo evaso %s · sanzione %s (×%.1f).\nMerce confiscata.%s')
            :format(p.nome, c.nomeImportatore, U.Euro(c.dichiarato), U.Euro(c.reale),
                    U.Euro(evaso), U.Euro(sanzione), moltiplicatore,
                    penale and '\nFascicolo aperto.' or '\nSotto soglia penale: solo amministrativo.'),
    })
end)

-- ---------------------------------------------------------------------------
--  Licenza di importazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dog:licenza', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local ok, imprese = pcall(function() return exports.ita_fisco:ImpreseDi(g.citizenid) end)
    if not ok or not imprese or #imprese == 0 then
        return rispondi(false, 'La licenza si rilascia a chi ha una partita IVA attiva.')
    end

    if not g:Sottrai('banca', DOG.Licenza.costo, 'licenza di importazione') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(DOG.Licenza.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'monopoli', DOG.Licenza.costo, g.citizenid)

    MySQL.query.await([[
        INSERT INTO dogana_licenze (citizenid, scade_il)
        VALUES (?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE scade_il = VALUES(scade_il)
    ]], { g.citizenid, DOG.Licenza.validitaMinuti })

    AUREA.Log('economia', 'info', g, 'ha ottenuto la licenza di importazione')
    rispondi(true, ('Licenza rilasciata. Vale %d minuti e apre le partite soggette a monopolio.')
        :format(DOG.Licenza.validitaMinuti))
end)

-- ---------------------------------------------------------------------------
--  Elenco dei propri container
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dog:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local fuori = {}
    for _, c in pairs(container) do
        if c.importatore == g.citizenid then
            local p = DOG.GetPartita(c.partita)
            fuori[#fuori + 1] = {
                id = c.id, nome = p.nome, icona = p.icona, posto = c.posto,
                canale = c.canale, controllato = c.controllato or false,
                tributi = c.tributi, dichiarato = c.dichiarato,
            }
        end
    end
    rispondi(fuori)
end)

AddEventHandler('aurea:giocatore:caricato', function(src)
    CreateThread(function() Wait(5000) pubblica() end)
end)

print('[AUREA] dogane: circuito doganale attivo')
