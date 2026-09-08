--[[
    AUREA · Nautica (server)

    Le risposte del quiz non lasciano mai questo lato: al client va il
    testo delle domande e le alternative, la correzione la fa il server.
    È la stessa regola dell'autoscuola, e vale per la stessa ragione: una
    patente che si prende leggendo la memoria del client non è una patente.
]]

local U = AUREA.Util

local esami = {}        -- [src] = { domande, risposte, avviate }
local noleggi = {}      -- [citizenid] = { modello, dal, cauzione, porto }
local inMare = {}       -- [citizenid] = { da, miglia }

-- ---------------------------------------------------------------------------
--  Patente nautica
-- ---------------------------------------------------------------------------
local function patenteDi(citizenid)
    return MySQL.single.await([[
        SELECT rilascio, scadenza FROM licenze
        WHERE citizenid = ? AND tipo = ? AND revocata = 0 AND scadenza >= CURDATE()
        LIMIT 1
    ]], { citizenid, NAU.Patente.tipo })
end

exports('PatenteNautica', function(citizenid)
    return patenteDi(citizenid) ~= nil
end)

AUREA.Callback.Registra('nau:statoPatente', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = patenteDi(g.citizenid)
    rispondi({
        haPatente = p ~= nil,
        scadenza = p and p.scadenza or nil,
        costoEsame = NAU.Patente.costoEsame,
        costoRilascio = NAU.Patente.costo,
    })
end)

-- ---------------------------------------------------------------------------
--  Esame
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nau:avviaEsame', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    if patenteDi(g.citizenid) then
        return rispondi(nil, 'Hai già una patente nautica in corso di validità.')
    end

    if not g:SottraiOvunque(NAU.Patente.costoEsame, 'diritti d\'esame — patente nautica') then
        return rispondi(nil, ('I diritti d\'esame sono %s.'):format(U.Euro(NAU.Patente.costoEsame)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_motorizzazione', NAU.Patente.costoEsame, g.citizenid)

    -- Si sorteggiano le domande, e si tiene traccia di quali sono state
    -- date a chi: il client non può chiedere la correzione di una domanda
    -- che non gli è stata assegnata.
    local indici = {}
    for n = 1, #NAU.Quiz do indici[n] = n end
    for n = #indici, 2, -1 do
        local j = math.random(n)
        indici[n], indici[j] = indici[j], indici[n]
    end

    local scelte = {}
    for n = 1, math.min(NAU.Patente.domandeEsame, #indici) do scelte[n] = indici[n] end

    esami[src] = { domande = scelte, risposte = {}, avviato = os.time() }

    local pubbliche = {}
    for n, indice in ipairs(scelte) do
        local q = NAU.Quiz[indice]

        -- Le alternative si mescolano, così non è sempre la prima
        local ordine = {}
        for i = 1, #q.opzioni do ordine[i] = i end
        for i = #ordine, 2, -1 do
            local j = math.random(i)
            ordine[i], ordine[j] = ordine[j], ordine[i]
        end

        esami[src].risposte[n] = ordine   -- ricorda la permutazione

        local opzioni = {}
        for i, o in ipairs(ordine) do opzioni[i] = q.opzioni[o] end

        pubbliche[n] = { numero = n, domanda = q.domanda, opzioni = opzioni }
    end

    rispondi({
        domande = pubbliche,
        erroriAmmessi = NAU.Patente.erroriAmmessi,
    })
end)

AUREA.Callback.Registra('nau:consegnaEsame', function(src, rispondi, risposte)
    local g = AUREA.GetPlayer(src)
    local esame = esami[src]
    if not g or not esame then return rispondi(nil, 'Nessun esame in corso.') end

    esami[src] = nil

    local errori, dettaglio = 0, {}

    for n, indice in ipairs(esame.domande) do
        local q = NAU.Quiz[indice]
        local ordine = esame.risposte[n]
        local scelta = tonumber((risposte or {})[n])

        -- La risposta del client è l'indice nell'elenco mescolato: si
        -- risale all'originale e si confronta con quella giusta.
        local originale = scelta and ordine[scelta] or nil
        local giusta = originale == q.giusta

        if not giusta then
            errori = errori + 1
            dettaglio[#dettaglio + 1] = { domanda = q.domanda, nota = q.nota }
        end
    end

    local promosso = errori <= NAU.Patente.erroriAmmessi

    if promosso then
        if not g:SottraiOvunque(NAU.Patente.costo, 'rilascio patente nautica') then
            return rispondi({ promosso = false, errori = errori, dettaglio = dettaglio },
                ('Esame superato, ma il rilascio costa %s e non li hai.'):format(U.Euro(NAU.Patente.costo)))
        end
        TriggerEvent('aurea:fisco:incasso', 'diritti_motorizzazione', NAU.Patente.costo, g.citizenid)

        local scadenza = U.DataPiuGiorni(NAU.Patente.validitaGiorni)
        MySQL.query.await([[
            INSERT INTO licenze (citizenid, tipo, rilascio, scadenza)
            VALUES (?, ?, CURDATE(), ?)
            ON DUPLICATE KEY UPDATE rilascio = CURDATE(), scadenza = VALUES(scadenza), revocata = 0
        ]], { g.citizenid, NAU.Patente.tipo, scadenza })

        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        inv:Aggiungi(NAU.Patente.item, 1, {
            intestatario = g:NomeCompleto(),
            categoria = 'Entro 12 miglia',
            rilascio = U.DataIT(os.time()),
            scadenza = scadenza,
        })
        TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

        AUREA.Log('veicoli', 'info', g, 'ha conseguito la patente nautica')
    end

    rispondi({
        promosso = promosso,
        errori = errori,
        ammessi = NAU.Patente.erroriAmmessi,
        dettaglio = dettaglio,
    })
end)

-- ---------------------------------------------------------------------------
--  Noleggio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nau:listino', function(src, rispondi, idPorto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local porto = NAU.GetPorto(idPorto)
    if not porto then return rispondi({}, 'Porto sconosciuto.') end

    local haPatente = patenteDi(g.citizenid) ~= nil
    local out = {}

    for _, n in ipairs(NAU.Noleggio.listino) do
        out[#out + 1] = {
            modello = n.modello, nome = n.nome, oraria = n.oraria,
            cavalli = n.cavalli,
            patente = n.patente,
            disponibile = not n.patente or haPatente,
        }
    end

    rispondi(out, nil, {
        cauzione = NAU.Noleggio.cauzione,
        haPatente = haPatente,
        inCorso = noleggi[g.citizenid] ~= nil,
        pontile = porto.pontile,
    })
end)

AUREA.Callback.Registra('nau:noleggia', function(src, rispondi, idPorto, modello)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local porto = NAU.GetPorto(idPorto)
    local unita = NAU.GetNoleggio(modello)
    if not porto or not unita then return rispondi(false, 'Unità non a listino.') end

    if noleggi[g.citizenid] then
        return rispondi(false, 'Hai già un\'unità a noleggio: riportala prima.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - porto.capitaneria) > 8.0 then
        return rispondi(false, 'Devi essere allo sportello del porto.')
    end

    if unita.patente and not patenteDi(g.citizenid) then
        return rispondi(false, ('Per %s serve la patente nautica.'):format(unita.nome))
    end

    local totale = NAU.Noleggio.cauzione + unita.oraria
    if not g:SottraiOvunque(totale, ('noleggio %s + cauzione'):format(unita.nome)) then
        return rispondi(false, ('Servono %s: prima ora più cauzione.'):format(U.Euro(totale)))
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(unita.oraria * 0.22), g.citizenid)

    noleggi[g.citizenid] = {
        modello = modello, dal = os.time(),
        cauzione = NAU.Noleggio.cauzione, porto = idPorto,
    }

    AUREA.Log('veicoli', 'info', g, ('ha noleggiato %s al %s'):format(unita.nome, porto.nome))
    rispondi(true, porto.pontile, ('%s noleggiata. Cauzione %s, %s l\'ora.')
        :format(unita.nome, U.Euro(NAU.Noleggio.cauzione), U.Euro(unita.oraria)))
end)

AUREA.Callback.Registra('nau:riconsegna', function(src, rispondi, idPorto, danni)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local n = noleggi[g.citizenid]
    if not n then return rispondi(false, 'Non risulti avere unità a noleggio.') end

    local porto = NAU.GetPorto(idPorto)
    if not porto or #(GetEntityCoords(GetPlayerPed(src)) - porto.capitaneria) > 12.0 then
        return rispondi(false, 'La riconsegna si fa al porto.')
    end

    local unita = NAU.GetNoleggio(n.modello)
    local ore = math.max(0, math.floor((os.time() - n.dal) / 3600))
    local dovute = ore * unita.oraria

    -- I danni si trattengono dalla cauzione, come nel noleggio auto
    local trattenuta = math.floor(math.max(0, math.min(100, tonumber(danni) or 0)) / 100 * n.cauzione)
    local reso = math.max(0, n.cauzione - trattenuta - dovute)

    noleggi[g.citizenid] = nil

    if reso > 0 then g:Aggiungi('banca', reso, 'restituzione cauzione noleggio nautico') end

    AUREA.Log('veicoli', 'info', g, ('ha riconsegnato %s dopo %d ore'):format(unita.nome, ore))

    rispondi(true, ('Riconsegnata dopo %d ore. Ore aggiuntive %s, danni %s, cauzione resa %s.')
        :format(ore, U.Euro(dovute), U.Euro(trattenuta), U.Euro(reso)))
end)

-- ---------------------------------------------------------------------------
--  Controlli della Guardia Costiera
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nau:controlla', function(src, rispondi, bersaglioSrc, modello, miglia)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene(NAU.Lavori, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(false, 'Il controllo lo fa la Guardia Costiera in servizio.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Nessuno da controllare.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 12.0 then
        return rispondi(false, 'Troppo lontano.')
    end

    miglia = math.max(0, tonumber(miglia) or 0)
    local unita = NAU.GetNoleggio(modello)
    local fascia = NAU.FasciaPer(miglia)
    local inv = exports.aurea_inventory:Inventario(b.citizenid)

    local rilievi, sanzione = {}, 0

    -- Titolo abilitativo
    local serve, motivo = NAU.ServePatente(modello, miglia, unita and unita.cavalli or nil)
    if serve and not patenteDi(b.citizenid) then
        rilievi[#rilievi + 1] = ('Navigazione senza patente nautica (%s) — %s')
            :format(motivo, NAU.Controlli.articoloSenzaPatente)
        sanzione = sanzione + NAU.Controlli.sanzioneSenzaPatente
    end

    -- Dotazioni di sicurezza
    for _, dotazione in ipairs(fascia.dotazioni) do
        if not inv:Ha(dotazione, 1) then
            local dati = AUREA.Item[dotazione]
            rilievi[#rilievi + 1] = ('Manca: %s (%s) — %s')
                :format(dati and dati.etichetta or dotazione, fascia.nome, NAU.Controlli.articoloDotazioni)
            sanzione = sanzione + NAU.Controlli.sanzionePerDotazione
        end
    end

    if #rilievi == 0 then
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = 'successo', icona = '⚓', durata = 9000,
            titolo = 'Controllo Guardia Costiera', testo = 'Tutto in regola. Buona navigazione.',
        })
        return rispondi(true, ('%s: nessun rilievo. %s, dotazioni complete.')
            :format(b:NomeCompleto(), fascia.nome))
    end

    -- Il verbale lo emette ita_codicestrada, che sa già come si fa.
    -- Nessun punto decurtato: la patente nautica non è a punti.
    exports.ita_codicestrada:EmettiVerbale({
        citizenid = b.citizenid,
        articolo = NAU.Controlli.articoloDotazioni,
        descrizione = table.concat(rilievi, ' · '),
        importo = sanzione,
        punti = 0,
        origine = 'agente',
        agente = g:NomeCompleto(),
        luogo = ('%s dalla costa'):format(fascia.nome:lower()),
    })

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'errore', icona = '⚓', durata = 20000,
        titolo = 'Verbale della Guardia Costiera',
        testo = ('%s\nSanzione: %s'):format(table.concat(rilievi, '\n'), U.Euro(sanzione)),
    })

    AUREA.Log('giustizia', 'info', g,
        ('controllo nautico su %s: %d rilievi, %s'):format(b:NomeCompleto(), #rilievi, U.Euro(sanzione)))

    rispondi(true, ('%d rilievi su %s. Sanzione complessiva %s.')
        :format(#rilievi, b:NomeCompleto(), U.Euro(sanzione)))
end)

-- ---------------------------------------------------------------------------
--  Soccorso in mare
-- ---------------------------------------------------------------------------
RegisterNetEvent('nau:inAcqua', function(stato, miglia)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    if stato then
        if inMare[g.citizenid] then return end
        inMare[g.citizenid] = { da = os.time(), miglia = tonumber(miglia) or 0 }
    else
        inMare[g.citizenid] = nil
    end
end)

--- Il razzo di segnalazione: manda la posizione a chi può venire a
--- prenderti. È l'unico modo per farsi trovare in mare aperto.
AUREA.Callback.Registra('nau:razzo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(NAU.Soccorso.razzo, 1) then
        return rispondi(false, 'Non hai razzi di segnalazione.')
    end

    inv:Rimuovi(NAU.Soccorso.razzo, 1)
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    local coord = GetEntityCoords(GetPlayerPed(src))
    local miglia = NAU.MigliaDallaCosta(coord)

    for _, lavoro in ipairs(NAU.LavoriSoccorso) do
        exports.aurea_ui:NotificaLavoro(lavoro, {
            tipo = 'errore', icona = '🧨', durata = 25000,
            titolo = 'RAZZO DI SEGNALAZIONE IN MARE',
            testo = ('%s a %.1f miglia dalla costa. Posizione trasmessa.')
                :format(g:NomeCompleto(), miglia),
        }, true)
    end

    TriggerEvent('aurea:112:allerta', 'persona_bloccata',
        { x = coord.x, y = coord.y, z = coord.z },
        ('Segnale di soccorso in mare a %.1f miglia.'):format(miglia),
        'razzo a paracadute avvistato')

    -- La posizione va ai soccorritori, non a tutti
    for _, lavoro in ipairs(NAU.LavoriSoccorso) do
        for _, s in ipairs(AUREA.GetGiocatoriPerLavoro(lavoro, true)) do
            TriggerClientEvent('nau:segnale', s.source, {
                x = coord.x, y = coord.y, z = coord.z,
                nome = g:NomeCompleto(), miglia = miglia,
            })
        end
    end

    rispondi(true, 'Razzo sparato. Se qualcuno è in servizio, adesso sa dove sei.')
end)

AUREA.Callback.Registra('nau:recupera', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene(NAU.LavoriSoccorso, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(false, 'Il recupero lo fa il personale di soccorso in servizio.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Nessuno da recuperare.') end
    if not inMare[b.citizenid] then return rispondi(false, 'Quella persona non è in difficoltà.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source)))
        > NAU.Soccorso.raggioRecupero then
        return rispondi(false, 'Avvicinati.')
    end

    inMare[b.citizenid] = nil
    TriggerClientEvent('nau:recuperato', b.source)

    g:Aggiungi('banca', NAU.Soccorso.compensoRecupero, 'recupero in mare')
    TriggerEvent('aurea:fisco:erogazione', 'soccorso', NAU.Soccorso.compensoRecupero, g.citizenid)

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'successo', icona = '⚓', durata = 14000,
        titolo = 'Recuperato',
        testo = ('%s ti ha tirato a bordo.'):format(g:NomeCompleto()),
    })

    AUREA.Log('soccorso', 'info', g, ('ha recuperato in mare %s'):format(b:NomeCompleto()))
    rispondi(true, ('%s recuperato. Competenze %s.')
        :format(b:NomeCompleto(), U.Euro(NAU.Soccorso.compensoRecupero)))
end)

--- Chi resta in mare aperto si esaurisce.
CreateThread(function()
    while true do
        Wait(NAU.Soccorso.secondiTick * 1000)
        for citizenid, dati in pairs(inMare) do
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            if g then
                if dati.miglia >= NAU.Soccorso.migliaPericolo then
                    TriggerClientEvent('nau:sfinimento', g.source, NAU.Soccorso.dannoPerTick)
                end
            else
                inMare[citizenid] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Ormeggi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('nau:ormeggi', function(src, rispondi, idPorto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT v.targa, v.modello, o.porto, o.scadenza
        FROM ormeggi o
        JOIN veicoli v ON v.targa = o.targa
        WHERE o.citizenid = ?
        ORDER BY o.scadenza DESC
    ]], { g.citizenid })

    rispondi(righe or {}, NAU.GetPorto(idPorto))
end)

AUREA.Callback.Registra('nau:ormeggia', function(src, rispondi, idPorto, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local porto = NAU.GetPorto(idPorto)
    if not porto then return rispondi(false, 'Porto sconosciuto.') end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local proprietario = MySQL.scalar.await('SELECT proprietario FROM veicoli WHERE targa = ?', { targa })
    if proprietario ~= g.citizenid then
        return rispondi(false, 'Quell\'unità non è intestata a te.')
    end

    if not g:SottraiOvunque(porto.canoneMensile, ('canone di ormeggio — %s'):format(porto.nome)) then
        return rispondi(false, ('Il canone mensile è %s.'):format(U.Euro(porto.canoneMensile)))
    end
    TriggerEvent('aurea:fisco:incasso', 'canoni_demaniali', porto.canoneMensile, g.citizenid)

    MySQL.query.await([[
        INSERT INTO ormeggi (citizenid, targa, porto, scadenza)
        VALUES (?, ?, ?, DATE_ADD(CURDATE(), INTERVAL 30 DAY))
        ON DUPLICATE KEY UPDATE porto = VALUES(porto),
            scadenza = DATE_ADD(GREATEST(scadenza, CURDATE()), INTERVAL 30 DAY)
    ]], { g.citizenid, targa, idPorto })

    rispondi(true, ('Ormeggio pagato al %s per trenta giorni.'):format(porto.nome))
end)

AddEventHandler('aurea:giocatore:scaricato', function(_, g)
    inMare[g.citizenid] = nil
    esami[g.source] = nil
end)
