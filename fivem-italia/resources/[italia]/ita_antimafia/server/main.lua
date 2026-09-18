--[[
    AUREA · Misure di prevenzione (server)

    Il conto lo fa il server, con numeri che esistono già in altri moduli:
    quanto una persona ha dichiarato al fisco da una parte, quanto valgono
    conti, cripto, veicoli e immobili dall'altra.

    Nessuno di questi numeri arriva dal client. Il proposto può dire
    quello che vuole in contraddittorio: quello che conta è cosa risulta.
]]

local U = AUREA.Util

local proposte = {}     -- [citizenid] = { scade, patrimonio, reddito, ... }

-- ---------------------------------------------------------------------------
--  Chi propone e chi decide
-- ---------------------------------------------------------------------------
local function pg(g)
    if not g or not g.lavoro.servizio then return false end
    for _, l in ipairs(ANT.PoliziaGiudiziaria) do
        if g.lavoro.nome == l then return true end
    end
    return false
end

local function magistrato(g)
    return g and g.lavoro.nome == ANT.Magistratura
end

-- ---------------------------------------------------------------------------
--  L'accertamento patrimoniale
--
--  È il cuore del modulo: mette in fila quello che una persona ha.
-- ---------------------------------------------------------------------------
local function patrimonioDi(citizenid)
    local voci, totale = {}, 0

    local conti = MySQL.single.await(
        'SELECT banca, contanti FROM personaggi WHERE citizenid = ?', { citizenid }) or {}
    local liquido = (conti.banca or 0) + (conti.contanti or 0)
    if liquido > 0 then
        voci[#voci + 1] = { tipo = 'banca', descrizione = 'Disponibilità liquide', valore = liquido }
        totale = totale + liquido
    end

    -- Le cripto si valutano alla quotazione corrente: `quantita` è in
    -- millesimi di moneta, `prezzo` in centesimi per unità intera.
    local cripto = math.floor(MySQL.scalar.await([[
        SELECT COALESCE(SUM(p.quantita * m.prezzo / 1000), 0)
        FROM cripto_portafogli p JOIN cripto_mercato m ON m.moneta = p.moneta
        WHERE p.citizenid = ?
    ]], { citizenid }) or 0)
    if cripto > 0 then
        voci[#voci + 1] = { tipo = 'cripto', descrizione = 'Criptovalute', valore = cripto }
        totale = totale + cripto
    end

    for _, v in ipairs(MySQL.query.await(
        'SELECT targa, modello FROM veicoli WHERE citizenid = ? AND stato <> ?',
        { citizenid, 'demolito' }) or {}) do
        local listino = select(2, pcall(function()
            return exports.ita_veicoli:ValoreVeicolo(v.targa)
        end)) or 0
        local valore = math.floor((tonumber(listino) or 0) * ANT.Valori.scontoVeicolo)
        if valore > 0 then
            voci[#voci + 1] = { tipo = 'veicoli', riferimento = v.targa,
                descrizione = ('Veicolo %s (%s)'):format(v.modello, v.targa), valore = valore }
            totale = totale + valore
        end
    end

    for _, i in ipairs(MySQL.query.await(
        'SELECT id, nome, prezzo FROM immobili WHERE proprietario = ?', { citizenid }) or {}) do
        voci[#voci + 1] = { tipo = 'immobili', riferimento = tostring(i.id),
            descrizione = ('Immobile %s'):format(i.nome), valore = i.prezzo or 0 }
        totale = totale + (i.prezzo or 0)
    end

    return voci, totale
end

--- Quanto ha dichiarato: i tributi pagati sono la prova migliore che un
--- reddito c'è stato, perché su un reddito nero non si paga l'IRPEF.
local function redditoDichiaratoDa(citizenid)
    local irpef = MySQL.scalar.await([[
        SELECT SUM(importo) FROM tributi
        WHERE citizenid = ? AND tipo IN ('irpef','inps') AND stato = 'pagato'
    ]], { citizenid }) or 0

    -- Dall'IRPEF si risale al lordo: aliquota media del 23%
    local daTributi = math.floor(irpef / 0.23)

    local fatture = MySQL.scalar.await([[
        SELECT SUM(f.imponibile) FROM fatture f
        JOIN imprese i ON i.id = f.impresa_id
        WHERE i.titolare = ? AND f.pagata = 1
    ]], { citizenid }) or 0

    return daTributi + math.floor(fatture)
end

-- ---------------------------------------------------------------------------
--  Accertamento, su richiesta della polizia giudiziaria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ant:accerta', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not pg(g) and not magistrato(g) then return rispondi(nil, 'Non autorizzato.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(nil, 'La persona non è collegata.') end

    local voci, patrimonio = patrimonioDi(b.citizenid)
    local reddito = redditoDichiaratoDa(b.citizenid)

    local calore = 0
    local ok, tag = pcall(function() return exports.ita_famiglie:OrganizzazioneDi(b.citizenid) end)
    if ok and tag then
        local ok2, c = pcall(function() return exports.ita_famiglie:CaloreOrganizzazione(tag) end)
        calore = (ok2 and tonumber(c)) or 0
    end

    local gravita = 0
    local ok3, precedenti = pcall(function()
        return exports.ita_giustizia:Precedenti(b.citizenid, false)
    end)
    for _, p in ipairs(ok3 and precedenti or {}) do gravita = gravita + (p.gravita or 0) end

    local sproporzionato = reddito <= 0 or (patrimonio / math.max(1, reddito)) >= ANT.Presupposti.sproporzione
    local presupposti = (calore >= ANT.Presupposti.caloreMinimo or gravita >= ANT.Presupposti.gravitaCumulata)

    rispondi({
        citizenid = b.citizenid, nome = b:NomeCompleto(),
        voci = voci, patrimonio = patrimonio, reddito = reddito,
        rapporto = reddito > 0 and (patrimonio / reddito) or nil,
        calore = calore, gravita = gravita,
        sproporzionato = sproporzionato,
        presupposti = presupposti,
        proponibile = sproporzionato and presupposti
            and patrimonio >= ANT.Presupposti.patrimonioMinimo,
        soglia = ANT.Presupposti.sproporzione,
    })
end)

-- ---------------------------------------------------------------------------
--  La proposta
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ant:proponi', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not magistrato(g) then return rispondi(false, 'La proposta la avanza la magistratura.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'La persona non è collegata.') end
    if proposte[b.citizenid] then return rispondi(false, 'C\'è già un procedimento aperto a suo carico.') end

    local voci, patrimonio = patrimonioDi(b.citizenid)
    local reddito = redditoDichiaratoDa(b.citizenid)

    if patrimonio < ANT.Presupposti.patrimonioMinimo then
        return rispondi(false, 'Patrimonio sotto la soglia: non si procede per così poco.')
    end
    if reddito > 0 and (patrimonio / reddito) < ANT.Presupposti.sproporzione then
        return rispondi(false, ('Il conto torna: %s di patrimonio su %s dichiarati.')
            :format(U.Euro(patrimonio), U.Euro(reddito)))
    end

    local id = MySQL.insert.await([[
        INSERT INTO antimafia_procedimenti
            (proposto, patrimonio, reddito, proponente, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { b.citizenid, patrimonio, reddito, g:NomeCompleto(), ANT.Contraddittorio.minuti })

    proposte[b.citizenid] = {
        id = id, patrimonio = patrimonio, reddito = reddito, giustificato = 0,
        voci = voci, proponente = g:NomeCompleto(),
        scade = os.time() + ANT.Contraddittorio.minuti * 60,
    }

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'errore', icona = '⚖', durata = 30000,
        titolo = 'Proposta di misura di prevenzione',
        testo = ('D.Lgs. 159/2011.\nPatrimonio accertato %s, redditi dichiarati %s.\n\nHai %d minuti per giustificarne la provenienza: usa /giustifica. Quello che non giustifichi viene confiscato.')
            :format(U.Euro(patrimonio), U.Euro(reddito), ANT.Contraddittorio.minuti),
    })
    TriggerEvent('aurea:telefono:messaggioSistema', b.citizenid, 'Tribunale',
        ('Procedimento di prevenzione patrimoniale. Contraddittorio aperto per %d minuti.')
            :format(ANT.Contraddittorio.minuti))

    AUREA.Log('giustizia', 'allarme', g,
        ('ha proposto una misura di prevenzione su %s (%s di patrimonio)')
            :format(b:NomeCompleto(), U.Euro(patrimonio)))

    rispondi(true, ('Proposta depositata.\n%s\nIl contraddittorio dura %d minuti.')
        :format(select(1, ANT.Motivazione(patrimonio, reddito, 0)), ANT.Contraddittorio.minuti))
end)

-- ---------------------------------------------------------------------------
--  Il contraddittorio
--
--  Non si giustifica a parole: si giustifica pagando quello che non si è
--  pagato. Ogni euro versato al fisco in questa finestra è un euro di
--  patrimonio che si salva — perché su un reddito dichiarato le imposte
--  si pagano, ed è esattamente quello che il proposto non ha fatto.
-- ---------------------------------------------------------------------------
AUREA.Comando('giustifica', 'utente', 'Giustifica la provenienza del patrimonio', {
    { name = 'euro', help = 'Quanto vuoi regolarizzare' },
}, function(src, args, _, g)
    if not g then return end

    local p = proposte[g.citizenid]
    if not p then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '⚖', titolo = 'Nessun procedimento',
            testo = 'Non hai niente da giustificare.' })
    end

    local importo = U.ACentesimi(tonumber(tostring(args[1] or ''):gsub(',', '.')) or 0)
    if importo <= 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⚖', titolo = 'Uso',
            testo = '/giustifica <euro> — regolarizzi quella quota pagandoci le imposte.' })
    end

    -- Regolarizzare costa: è l'imposta che non si è pagata a suo tempo
    local imposta = math.floor(importo * 0.23)
    if not g:SottraiOvunque(imposta, 'regolarizzazione fiscale') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⚖', titolo = 'Fondi insufficienti',
            testo = ('Per giustificare %s servono %s di imposte.')
                :format(U.Euro(importo), U.Euro(imposta)) })
    end
    TriggerEvent('aurea:fisco:incasso', 'irpef', imposta, g.citizenid)

    p.giustificato = p.giustificato + importo
    MySQL.update('UPDATE antimafia_procedimenti SET giustificato = ? WHERE id = ?',
        { p.giustificato, p.id })

    local _, scoperto = ANT.Motivazione(p.patrimonio, p.reddito, p.giustificato)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '⚖', durata = 18000,
        titolo = 'Quota giustificata',
        testo = ('Hai regolarizzato %s pagando %s di imposte.\nResta scoperto: %s.')
            :format(U.Euro(importo), U.Euro(imposta), U.Euro(scoperto)),
    })
end)

-- ---------------------------------------------------------------------------
--  La confisca
-- ---------------------------------------------------------------------------
local function confisca(citizenid)
    local p = proposte[citizenid]
    if not p then return end
    proposte[citizenid] = nil

    local _, scoperto = ANT.Motivazione(p.patrimonio, p.reddito, p.giustificato)

    if scoperto <= 0 then
        MySQL.update('UPDATE antimafia_procedimenti SET esito = ?, chiuso_il = NOW() WHERE id = ?',
            { 'archiviato', p.id })
        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Tribunale',
            'Procedimento di prevenzione archiviato: il patrimonio risulta giustificato.')
        return
    end

    -- Si aggredisce nell'ordine: prima il liquido, poi il resto
    local residuo, confiscati = scoperto, {}

    for _, tipo in ipairs(ANT.Ordine) do
        for _, v in ipairs(p.voci) do
            if v.tipo == tipo and residuo > 0 then
                local preso = math.min(residuo, v.valore)

                if tipo == 'banca' then
                    AUREA.Denaro.SottraiOffline(citizenid, 'banca', preso, 'confisca di prevenzione', true)
                elseif tipo == 'cripto' then
                    MySQL.update('UPDATE cripto_portafogli SET quantita = 0 WHERE citizenid = ?', { citizenid })
                elseif tipo == 'veicoli' then
                    MySQL.update('UPDATE veicoli SET stato = ? WHERE targa = ?', { 'sequestrato', v.riferimento })
                elseif tipo == 'immobili' then
                    MySQL.update('UPDATE immobili SET proprietario = NULL, inquilino = NULL, in_vendita = 0 WHERE id = ?',
                        { v.riferimento })
                    MySQL.insert('INSERT INTO antimafia_beni (procedimento_id, immobile_id, descrizione, valore) VALUES (?, ?, ?, ?)',
                        { p.id, tonumber(v.riferimento), v.descrizione, v.valore })
                end

                residuo = residuo - preso
                confiscati[#confiscati + 1] = v.descrizione
                TriggerEvent('aurea:fisco:incasso', 'confische', preso, citizenid)
            end
        end
    end

    MySQL.update('UPDATE antimafia_procedimenti SET esito = ?, confiscato = ?, chiuso_il = NOW() WHERE id = ?',
        { 'confisca', scoperto - residuo, p.id })

    -- E la misura personale
    MySQL.query.await([[
        INSERT INTO antimafia_sorveglianze (citizenid, scade_il)
        VALUES (?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE scade_il = VALUES(scade_il), revocata = 0
    ]], { citizenid, ANT.Sorveglianza.durataMinuti })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '⚖', durata = 30000,
            titolo = 'Decreto di confisca',
            testo = ('%s\n\nConfiscati:\n· %s\n\nSei sottoposto a sorveglianza speciale per %d minuti.')
                :format(select(1, ANT.Motivazione(p.patrimonio, p.reddito, p.giustificato)),
                        table.concat(confiscati, '\n· '), ANT.Sorveglianza.durataMinuti),
        })
    end

    for _, lavoro in ipairs(ANT.PoliziaGiudiziaria) do
        exports.aurea_ui:NotificaLavoro(lavoro, {
            tipo = 'successo', icona = '⚖', durata = 20000,
            titolo = 'Confisca eseguita',
            testo = ('%s di beni sottratti alla disponibilità. Gli immobili passano al riutilizzo sociale.')
                :format(U.Euro(scoperto - residuo)),
        }, true)
    end

    AUREA.Log('giustizia', 'allarme', nil,
        ('Confisca di prevenzione su %s: %s'):format(citizenid, U.Euro(scoperto - residuo)))
end

CreateThread(function()
    while true do
        Wait(20000)
        for citizenid, p in pairs(proposte) do
            if os.time() >= p.scade then confisca(citizenid) end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Sorveglianza speciale
-- ---------------------------------------------------------------------------
exports('SottoSorveglianza', function(citizenid)
    local s = MySQL.single.await(
        'SELECT scade_il FROM antimafia_sorveglianze WHERE citizenid = ? AND revocata = 0 AND scade_il > NOW()',
        { citizenid })
    return s ~= nil
end)

--- Chi è sorvegliato non porta armi: aurea_armi lo chiede a noi.
AddEventHandler('aurea:armi:controllo', function(citizenid, rispondi)
    if type(rispondi) ~= 'function' then return end
    local s = MySQL.single.await(
        'SELECT scade_il FROM antimafia_sorveglianze WHERE citizenid = ? AND revocata = 0 AND scade_il > NOW()',
        { citizenid })
    if s then rispondi(false, 'Sottoposto a sorveglianza speciale: divieto di porto d\'armi.') end
end)

-- ---------------------------------------------------------------------------
--  Riutilizzo sociale
--
--  Lo decide il Comune. È una scelta politica e deve restare tale.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ant:beni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= 'comune' then return rispondi({}) end

    rispondi(MySQL.query.await([[
        SELECT id, immobile_id, descrizione, valore, destinazione
        FROM antimafia_beni WHERE destinazione IS NULL ORDER BY id DESC LIMIT 20
    ]]) or {})
end)

AUREA.Callback.Registra('ant:destina', function(src, rispondi, idBene, destinazione)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= 'comune' or not g:HaPermessoLavoro('anagrafe') then
        return rispondi(false, 'La destinazione la decide il Comune.')
    end

    local d = ANT.GetRiutilizzo(destinazione)
    if not d then return rispondi(false, 'Destinazione sconosciuta.') end

    local b = MySQL.single.await('SELECT * FROM antimafia_beni WHERE id = ? AND destinazione IS NULL', { idBene })
    if not b then return rispondi(false, 'Bene non trovato o già destinato.') end

    MySQL.update.await('UPDATE antimafia_beni SET destinazione = ?, destinato_da = ?, destinato_il = NOW() WHERE id = ?',
        { destinazione, g:NomeCompleto(), idBene })

    if destinazione == 'alloggio' and b.immobile_id then
        -- Torna sul mercato come alloggio popolare: prezzo simbolico
        MySQL.update('UPDATE immobili SET in_vendita = 1, prezzo = FLOOR(prezzo * 0.25) WHERE id = ?',
            { b.immobile_id })
    elseif destinazione == 'mensa' then
        MySQL.query([[
            INSERT INTO economia_stato (chiave, valore) VALUES ('chiesa_scorta', ?)
            ON DUPLICATE KEY UPDATE valore = CAST(valore AS UNSIGNED) + ?
        ]], { tostring(d.porzioni), d.porzioni })
    end

    exports.aurea_ui:NotificaTutti({
        tipo = 'successo', icona = '⚖', durata = 20000,
        titolo = 'Bene confiscato restituito alla città',
        testo = ('%s: %s.\n%s'):format(b.descrizione, d.nome, d.descrizione),
    })

    AUREA.Log('giustizia', 'info', g,
        ('ha destinato %s a %s'):format(b.descrizione, d.nome))

    rispondi(true, ('%s destinato a: %s.'):format(b.descrizione, d.nome))
end)

print('[AUREA] antimafia: misure di prevenzione attive')
