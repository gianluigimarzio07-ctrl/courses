--[[
    AUREA · Criptovalute (server)

    Il prezzo lo fa questo lato e nessun altro. È la cosa che va detta per
    prima, perché in un mercato è l'unica che conta davvero: se il client
    potesse anticipare la quotazione successiva, comprare e vendere non
    sarebbe una scommessa ma una stampante di soldi.

    Il ciclo del prezzo gira qui, la quotazione viene pubblicata quando è
    già fatta, e le compravendite si liquidano al prezzo che il server ha
    in quel momento — non a quello che il client dice di aver visto.
]]

local U = AUREA.Util

local mercato = {}      -- [id] = { prezzo, storico = {}, variazione }
local ultimaOra = {}    -- [citizenid] = { totale, dalle }

-- ---------------------------------------------------------------------------
--  Avvio del mercato
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(2000)

    for _, m in ipairs(CRP.Monete) do
        local salvato = MySQL.single.await(
            'SELECT prezzo, storico FROM cripto_mercato WHERE moneta = ? LIMIT 1', { m.id })

        mercato[m.id] = {
            prezzo = salvato and tonumber(salvato.prezzo) or m.iniziale,
            storico = salvato and salvato.storico and json.decode(salvato.storico) or { m.iniziale },
            variazione = 0.0,
        }

        if not salvato then
            MySQL.insert.await(
                'INSERT INTO cripto_mercato (moneta, prezzo, storico) VALUES (?, ?, ?)',
                { m.id, mercato[m.id].prezzo, json.encode(mercato[m.id].storico) })
        end
    end

    GlobalState.criptoAttivo = true
    print(('[aurea_cripto] Mercato avviato con %d monete.'):format(#CRP.Monete))
end)

-- ---------------------------------------------------------------------------
--  Il movimento dei prezzi
-- ---------------------------------------------------------------------------
local function pubblicaMercato()
    local quadro = {}

    for _, m in ipairs(CRP.Monete) do
        local stato = mercato[m.id]
        if stato then
            quadro[#quadro + 1] = {
                id = m.id, nome = m.nome, simbolo = m.simbolo,
                descrizione = m.descrizione,
                prezzo = stato.prezzo,
                variazione = stato.variazione,
                storico = stato.storico,
                accettaNero = m.accettaNero or false,
                scontoNero = m.scontoNero,
            }
        end
    end

    GlobalState.criptoQuadro = quadro
    TriggerClientEvent('crp:quadro', -1, quadro)
end

CreateThread(function()
    Wait(6000)

    while true do
        Wait(CRP.Mercato.secondiTick * 1000)

        -- Un evento vale per tutte le monete insieme: è quello che rende
        -- il mercato un mercato e non quattro dadi indipendenti.
        local eventoAttivo = nil
        for _, e in ipairs(CRP.Mercato.eventi) do
            if math.random(100) <= e.probabilita then eventoAttivo = e break end
        end

        for _, m in ipairs(CRP.Monete) do
            local stato = mercato[m.id]
            if stato then
                local prima = stato.prezzo

                -- Passeggiata aleatoria: la volatilità decide l'ampiezza,
                -- la deriva inclina la moneta verso l'alto o verso il basso
                local scossa = ((math.random() * 2) - 1) * (m.volatilita / 100)
                local variazione = scossa + (m.deriva / 100)

                if eventoAttivo then
                    -- Le monete volatili reagiscono di più alle notizie
                    variazione = variazione + eventoAttivo.effetto * (m.volatilita / 8)
                end

                local nuovo = math.floor(stato.prezzo * (1 + variazione))
                stato.prezzo = math.max(m.minimo, math.min(m.massimo, nuovo))
                stato.variazione = prima > 0 and ((stato.prezzo - prima) / prima * 100) or 0

                stato.storico[#stato.storico + 1] = stato.prezzo
                while #stato.storico > CRP.Mercato.storicoPunti do
                    table.remove(stato.storico, 1)
                end

                MySQL.update('UPDATE cripto_mercato SET prezzo = ?, storico = ? WHERE moneta = ?',
                    { stato.prezzo, json.encode(stato.storico), m.id })
            end
        end

        pubblicaMercato()

        if eventoAttivo then
            exports.aurea_ui:NotificaTutti({
                tipo = eventoAttivo.effetto > 0 and 'successo' or 'avviso',
                icona = '📉', durata = 12000,
                titolo = 'Mercato delle criptovalute',
                testo = eventoAttivo.nome,
            })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Portafogli
-- ---------------------------------------------------------------------------
local function portafoglio(citizenid)
    local righe = MySQL.query.await(
        'SELECT moneta, quantita FROM cripto_portafogli WHERE citizenid = ?', { citizenid }) or {}

    local out = {}
    for _, r in ipairs(righe) do out[r.moneta] = tonumber(r.quantita) or 0 end
    return out
end

local function sequestrato(citizenid)
    return MySQL.scalar.await(
        'SELECT sequestrato FROM cripto_conti WHERE citizenid = ? LIMIT 1', { citizenid }) == 1
end

local function variaPortafoglio(citizenid, moneta, delta)
    MySQL.query.await([[
        INSERT INTO cripto_portafogli (citizenid, moneta, quantita) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE quantita = GREATEST(0, quantita + VALUES(quantita))
    ]], { citizenid, moneta, delta })
end

-- ---------------------------------------------------------------------------
--  Antiriciclaggio
-- ---------------------------------------------------------------------------
local function segnala(g, importo, nero, moneta)
    local m = CRP.GetMoneta(moneta)
    local A = CRP.Antiriciclaggio

    local ora = os.time()
    local finestra = ultimaOra[g.citizenid]
    if not finestra or (ora - finestra.dalle) > 3600 then
        finestra = { totale = 0, dalle = ora }
    end
    finestra.totale = finestra.totale + importo
    ultimaOra[g.citizenid] = finestra

    local soglia = nero and (A.sogliaOperazione / A.moltiplicatoreNero) or A.sogliaOperazione
    local sospetta = importo >= soglia
        or finestra.totale >= A.sogliaOraria
        or (m and m.sempreSegnalata)

    if not sospetta then return false end

    local punti = A.puntiPerSegnalazione * (nero and A.moltiplicatoreNero or 1)

    MySQL.query.await([[
        INSERT INTO cripto_conti (citizenid, attenzione, ultima_segnalazione)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE attenzione = attenzione + VALUES(attenzione),
            ultima_segnalazione = NOW()
    ]], { g.citizenid, math.floor(punti) })

    local totale = MySQL.scalar.await(
        'SELECT attenzione FROM cripto_conti WHERE citizenid = ?', { g.citizenid }) or 0

    if totale >= A.sogliaAttenzione then
        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '🔎', durata = 18000,
            titolo = 'Segnalazione di operazione sospetta',
            testo = ('Un portafoglio ha superato la soglia di attenzione. Consulta con /uif.'),
        }, true)
    end

    return true
end

-- ---------------------------------------------------------------------------
--  Quadro e portafoglio, per il client
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('crp:quadro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local quadro = GlobalState.criptoQuadro or {}
    local mio = portafoglio(g.citizenid)

    local righe = {}
    for _, q in ipairs(quadro) do
        local quantita = mio[q.id] or 0
        righe[#righe + 1] = {
            id = q.id, nome = q.nome, simbolo = q.simbolo,
            descrizione = q.descrizione,
            prezzo = q.prezzo, variazione = q.variazione, storico = q.storico,
            accettaNero = q.accettaNero, scontoNero = q.scontoNero,
            quantita = quantita,
            controvalore = CRP.Controvalore(quantita, q.prezzo),
        }
    end

    rispondi(righe, {
        sequestrato = sequestrato(g.citizenid),
        commissione = CRP.Mercato.commissione,
        massimoNero = CRP.Exchange.massimoNeroPerOperazione,
    })
end)

-- ---------------------------------------------------------------------------
--  Acquisto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('crp:compra', function(src, rispondi, idMoneta, euroCentesimi, conNero)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local m = CRP.GetMoneta(idMoneta)
    local stato = mercato[idMoneta]
    if not m or not stato then return rispondi(false, 'Moneta non quotata.') end

    if sequestrato(g.citizenid) then
        return rispondi(false, 'Il tuo portafoglio è sotto sequestro: nessuna operazione è consentita.')
    end

    local importo = math.floor(tonumber(euroCentesimi) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end

    if conNero then
        if not m.accettaNero then
            return rispondi(false, ('%s non accetta contante non tracciato.'):format(m.nome))
        end
        if importo > CRP.Exchange.massimoNeroPerOperazione then
            return rispondi(false, ('In nero il massimo per operazione è %s.')
                :format(U.Euro(CRP.Exchange.massimoNeroPerOperazione)))
        end
        if #(GetEntityCoords(GetPlayerPed(src)) - CRP.Exchange.coord) > CRP.Exchange.raggio + 1.0 then
            return rispondi(false, 'Il contante si porta allo sportello, non si manda da un\'app.')
        end
    end

    -- Il prezzo è quello che il server ha adesso, non quello che il client
    -- crede di aver visto un momento fa
    local prezzo = stato.prezzo
    local commissione = math.floor(importo * CRP.Mercato.commissione / 1000)
    local netto = importo - commissione

    -- In nero il cambio è peggiore: è il prezzo di non essere chiesti nulla
    if conNero then netto = math.floor(netto * (m.scontoNero or 0.75)) end

    local quantita = CRP.Millesimi(netto, prezzo)
    if quantita <= 0 then return rispondi(false, 'La cifra è troppo bassa per comprare qualcosa.') end

    if conNero then
        local unita = math.floor(importo / 10000)   -- banconote da 100 €
        if unita <= 0 then return rispondi(false, 'Il taglio minimo in contanti è 100 €.') end

        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        if not inv:Ha('contanti_sporchi', unita) then
            return rispondi(false, ('Servono %d banconote non tracciate.'):format(unita))
        end
        inv:Rimuovi('contanti_sporchi', unita)
        TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
    else
        if not g:SottraiOvunque(importo, ('acquisto %s'):format(m.simbolo)) then
            return rispondi(false, ('Non hai %s.'):format(U.Euro(importo)))
        end
        TriggerEvent('aurea:fisco:incasso', 'iva_servizi', commissione, g.citizenid)
    end

    variaPortafoglio(g.citizenid, idMoneta, quantita)

    MySQL.insert('INSERT INTO cripto_movimenti (citizenid, moneta, verso, quantita, prezzo, controvalore, nero) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { g.citizenid, idMoneta, 'acquisto', quantita, prezzo, importo, conNero and 1 or 0 })

    local segnalata = segnala(g, importo, conNero, idMoneta)

    AUREA.Log('economia', 'info', g,
        ('ha comprato %s %s per %s%s'):format(CRP.FormattaQuantita(quantita), m.simbolo,
            U.Euro(importo), conNero and ' in contanti non tracciati' or ''))

    rispondi(true, ('%s %s acquistati a %s l\'uno. Commissione %s.%s'):format(
        CRP.FormattaQuantita(quantita), m.simbolo, U.Euro(prezzo), U.Euro(commissione),
        (conNero and segnalata) and '\nLo sportello ha compilato una segnalazione.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Vendita
-- ---------------------------------------------------------------------------
--- La vendita. Sta in una funzione perché la chiamano in due: il menu
--- allo sportello e l'app sul telefono. Duplicarla vorrebbe dire due
--- posti dove sbagliare la commissione.
local function vendi(g, idMoneta, millesimi)
    local m = CRP.GetMoneta(idMoneta)
    local stato = mercato[idMoneta]
    if not m or not stato then return false, 'Moneta non quotata.' end

    if sequestrato(g.citizenid) then
        return false, 'Il tuo portafoglio è sotto sequestro.'
    end

    local quantita = math.floor(tonumber(millesimi) or 0)
    if quantita <= 0 then return false, 'Quantità non valida.' end

    local mio = portafoglio(g.citizenid)
    if (mio[idMoneta] or 0) < quantita then
        return false, ('Ne hai solo %s.'):format(CRP.FormattaQuantita(mio[idMoneta] or 0))
    end

    local prezzo = stato.prezzo
    local lordo = CRP.Controvalore(quantita, prezzo)
    local commissione = math.floor(lordo * CRP.Mercato.commissione / 1000)
    local netto = lordo - commissione

    variaPortafoglio(g.citizenid, idMoneta, -quantita)

    -- Il ricavato arriva in banca: è denaro tracciato, ed è proprio questo
    -- il punto di tutta la manovra per chi ci è arrivato con il nero
    g:Aggiungi('banca', netto, ('vendita %s'):format(m.simbolo))
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', commissione, g.citizenid)

    MySQL.insert('INSERT INTO cripto_movimenti (citizenid, moneta, verso, quantita, prezzo, controvalore, nero) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { g.citizenid, idMoneta, 'vendita', quantita, prezzo, lordo, 0 })

    segnala(g, lordo, false, idMoneta)

    AUREA.Log('economia', 'info', g,
        ('ha venduto %s %s per %s'):format(CRP.FormattaQuantita(quantita), m.simbolo, U.Euro(netto)))

    return true, ('%s %s venduti a %s l\'uno. Accreditati %s al netto della commissione.')
        :format(CRP.FormattaQuantita(quantita), m.simbolo, U.Euro(prezzo), U.Euro(netto))
end

AUREA.Callback.Registra('crp:vendi', function(src, rispondi, idMoneta, millesimi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    rispondi(vendi(g, idMoneta, millesimi))
end)

-- ---------------------------------------------------------------------------
--  Trasferimento fra portafogli
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('crp:trasferisci', function(src, rispondi, idMoneta, millesimi, destinatarioSrc)
    local g = AUREA.GetPlayer(src)
    local d = AUREA.GetPlayer(tonumber(destinatarioSrc))
    if not g or not d then return rispondi(false, 'Destinatario non trovato.') end
    if g.citizenid == d.citizenid then return rispondi(false, 'Non ha senso.') end

    local m = CRP.GetMoneta(idMoneta)
    if not m then return rispondi(false, 'Moneta non quotata.') end
    if sequestrato(g.citizenid) then return rispondi(false, 'Il tuo portafoglio è sotto sequestro.') end

    local quantita = math.floor(tonumber(millesimi) or 0)
    if quantita <= 0 then return rispondi(false, 'Quantità non valida.') end

    local mio = portafoglio(g.citizenid)
    if (mio[idMoneta] or 0) < quantita then return rispondi(false, 'Non ne hai abbastanza.') end

    variaPortafoglio(g.citizenid, idMoneta, -quantita)
    variaPortafoglio(d.citizenid, idMoneta, quantita)

    local prezzo = mercato[idMoneta].prezzo
    local controvalore = CRP.Controvalore(quantita, prezzo)

    MySQL.insert('INSERT INTO cripto_movimenti (citizenid, moneta, verso, quantita, prezzo, controvalore, nero, controparte) VALUES (?, ?, ?, ?, ?, ?, 0, ?)',
        { g.citizenid, idMoneta, 'invio', quantita, prezzo, controvalore, d.citizenid })
    MySQL.insert('INSERT INTO cripto_movimenti (citizenid, moneta, verso, quantita, prezzo, controvalore, nero, controparte) VALUES (?, ?, ?, ?, ?, ?, 0, ?)',
        { d.citizenid, idMoneta, 'ricezione', quantita, prezzo, controvalore, g.citizenid })

    segnala(g, controvalore, false, idMoneta)

    TriggerClientEvent('aurea:ui:notifica', d.source, {
        tipo = 'successo', icona = '🪙', durata = 13000,
        titolo = 'Trasferimento ricevuto',
        testo = ('%s %s da %s (controvalore %s).')
            :format(CRP.FormattaQuantita(quantita), m.simbolo, g:NomeCompleto(), U.Euro(controvalore)),
    })

    rispondi(true, ('Inviati %s %s a %s.')
        :format(CRP.FormattaQuantita(quantita), m.simbolo, d:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  Guardia di Finanza: l'unità di informazione finanziaria
-- ---------------------------------------------------------------------------
local function investigatore(g, grado)
    if not g then return false end
    if not U.Contiene(CRP.LavoriControllo, g.lavoro.nome) then return false end
    if not g.lavoro.servizio then return false end
    if grado and g.lavoro.grado < grado then return false end
    return true
end

AUREA.Callback.Registra('crp:sospetti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not investigatore(g) then return rispondi({}, 'Riservato alla Guardia di Finanza in servizio.') end

    local righe = MySQL.query.await([[
        SELECT c.citizenid, c.attenzione, c.sequestrato, c.ultima_segnalazione,
               p.nome, p.cognome
        FROM cripto_conti c
        LEFT JOIN personaggi p ON p.citizenid = c.citizenid
        WHERE c.attenzione > 0
        ORDER BY c.attenzione DESC LIMIT 25
    ]])

    rispondi(righe or {}, nil, CRP.Antiriciclaggio.sogliaAttenzione)
end)

AUREA.Callback.Registra('crp:movimenti', function(src, rispondi, citizenid)
    local g = AUREA.GetPlayer(src)
    if not investigatore(g) then return rispondi({}, 'Non hai titolo per questa consultazione.') end

    local righe = MySQL.query.await([[
        SELECT moneta, verso, quantita, prezzo, controvalore, nero, controparte, momento
        FROM cripto_movimenti WHERE citizenid = ?
        ORDER BY id DESC LIMIT 40
    ]], { citizenid })

    AUREA.Log('giustizia', 'info', g,
        ('ha consultato i movimenti in criptovaluta di %s'):format(citizenid))

    rispondi(righe or {})
end)

AUREA.Callback.Registra('crp:sequestra', function(src, rispondi, citizenid, revoca)
    local g = AUREA.GetPlayer(src)
    if not investigatore(g, CRP.Sequestro.gradoMinimo) then
        return rispondi(false, 'Il sequestro lo dispone un ufficiale.')
    end

    if not revoca and CRP.Sequestro.richiedeFascicolo then
        local fascicolo = MySQL.scalar.await([[
            SELECT id FROM casellario WHERE citizenid = ? AND stato = 'indagato' LIMIT 1
        ]], { citizenid })
        if not fascicolo then
            return rispondi(false, 'Senza un fascicolo aperto non si sequestra: apri prima l\'indagine.')
        end
    end

    MySQL.query.await([[
        INSERT INTO cripto_conti (citizenid, sequestrato) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE sequestrato = VALUES(sequestrato)
    ]], { citizenid, revoca and 0 or 1 })

    local bersaglio = AUREA.GetPlayerByCitizenId(citizenid)

    if revoca then
        if bersaglio then
            TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
                tipo = 'successo', icona = '🪙', durata = 15000,
                titolo = 'Sequestro revocato',
                testo = 'Il tuo portafoglio è di nuovo operativo.',
            })
        end
        AUREA.Log('giustizia', 'info', g, ('ha revocato il sequestro su %s'):format(citizenid))
        return rispondi(true, 'Sequestro revocato.')
    end

    -- Il saldo confluisce all'erario. È il momento in cui il riciclaggio
    -- diventa una perdita secca invece di un rischio teorico.
    local saldo = 0
    for _, m in ipairs(CRP.Monete) do
        local q = MySQL.scalar.await(
            'SELECT quantita FROM cripto_portafogli WHERE citizenid = ? AND moneta = ?',
            { citizenid, m.id }) or 0
        if q > 0 then
            saldo = saldo + CRP.Controvalore(q, mercato[m.id] and mercato[m.id].prezzo or m.iniziale)
        end
    end

    MySQL.update('DELETE FROM cripto_portafogli WHERE citizenid = ?', { citizenid })

    if saldo > 0 then
        TriggerEvent('aurea:fisco:incasso', CRP.Sequestro.voceErario, saldo, citizenid)
    end

    exports.ita_giustizia:ApriFascicolo(citizenid, CRP.Antiriciclaggio.reato, g:NomeCompleto(),
        ('Sequestro di portafoglio in criptovaluta per controvalore di %s.'):format(U.Euro(saldo)))

    if bersaglio then
        TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
            tipo = 'errore', icona = '🪙', durata = 22000,
            titolo = 'Portafoglio sequestrato',
            testo = ('La Guardia di Finanza ha sequestrato il tuo portafoglio: %s di controvalore.')
                :format(U.Euro(saldo)),
        })
    end

    AUREA.Log('giustizia', 'avviso', g,
        ('ha sequestrato il portafoglio cripto di %s per %s'):format(citizenid, U.Euro(saldo)))

    rispondi(true, ('Sequestro eseguito: %s confluiti all\'erario.'):format(U.Euro(saldo)))
end)

--- L'attenzione decade: chi si ferma torna pulito.
CreateThread(function()
    while true do
        Wait(3600000)
        MySQL.update('UPDATE cripto_conti SET attenzione = GREATEST(0, attenzione - ?)',
            { CRP.Antiriciclaggio.decadimentoOrario })
    end
end)

exports('Controvalore', function(citizenid)
    local totale = 0
    for moneta, quantita in pairs(portafoglio(citizenid)) do
        local stato = mercato[moneta]
        if stato then totale = totale + CRP.Controvalore(quantita, stato.prezzo) end
    end
    return totale
end)

-- ---------------------------------------------------------------------------
--  App sul telefono
--
--  Lo sportello fisico resta il solo posto dove si opera in contante: da
--  qui si vede il mercato e si vende, che è tutto quello che serve avere
--  in tasca. Il nero deve continuare a costare un viaggio.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'exchange',
    nome = 'Exchange',
    icona = '🪙',
    colore = 'linear-gradient(150deg,#c9a227,#7e6414)',
    ordine = 55,

    schermata = function(g)
        local mio = {}
        for _, r in ipairs(MySQL.query.await(
            'SELECT moneta, quantita FROM cripto_portafogli WHERE citizenid = ?',
            { g.citizenid }) or {}) do
            mio[r.moneta] = tonumber(r.quantita) or 0
        end

        local bloccato = MySQL.scalar.await(
            'SELECT sequestrato FROM cripto_conti WHERE citizenid = ? LIMIT 1',
            { g.citizenid }) == 1

        local voci, totale = {}, 0

        for _, m in ipairs(CRP.Monete) do
            local stato = GlobalState.criptoQuadro or {}
            local prezzo, variazione = m.iniziale, 0

            for _, q in ipairs(stato) do
                if q.id == m.id then prezzo, variazione = q.prezzo, q.variazione end
            end

            local quantita = mio[m.id] or 0
            local controvalore = CRP.Controvalore(quantita, prezzo)
            totale = totale + controvalore

            voci[#voci + 1] = {
                icona = variazione > 1 and '📈' or (variazione < -1 and '📉' or '🪙'),
                titolo = ('%s — %s'):format(m.simbolo, U.Euro(prezzo)),
                sottotitolo = ('%+.2f%% · %s'):format(variazione,
                    quantita > 0 and ('ne hai %s'):format(CRP.FormattaQuantita(quantita))
                        or 'non ne hai'),
                valore = quantita > 0 and U.Euro(controvalore) or nil,
                tono = variazione > 1 and 'verde' or (variazione < -1 and 'rosso' or nil),
                azione = quantita > 0 and 'vendi' or nil,
                dati = { moneta = m.id, quantita = quantita },
                inerte = quantita <= 0,
            }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Controvalore del portafoglio',
            valore = U.Euro(totale),
            nota = bloccato and 'PORTAFOGLIO SOTTO SEQUESTRO'
                or 'Per comprare in contante serve lo sportello',
            voci = voci,
        }
    end,

    azione = function(g, azione, dati)
        dati = dati or {}

        if azione == 'vendi' then
            return { ok = true, dialogo = {
                titolo = 'Vendita',
                campi = { { etichetta = ('Millesimi da vendere (ne hai %d)')
                    :format(dati.quantita or 0), tipo = 'number', min = 1,
                    max = dati.quantita or 1, obbligatorio = true } },
                azione = 'eseguiVendita', chiave = 'millesimi',
            } }
        end

        if azione == 'eseguiVendita' then
            -- Si riusa la stessa funzione dello sportello: stessi
            -- controlli, stessa commissione, stesso registro.
            local ok, messaggio = vendi(g, dati.moneta, dati.millesimi)
            return ok, messaggio, true
        end

        return false, 'Azione sconosciuta.'
    end,
})
