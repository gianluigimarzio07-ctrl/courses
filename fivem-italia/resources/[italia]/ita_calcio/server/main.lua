--[[
    AUREA · Calcio (server)

    Il campionato gira per conto suo: un thread gioca una partita ogni
    tanto e aggiorna la classifica, che nessuno online può toccare. È il
    solo modo perché una scommessa su una partita significhi qualcosa —
    se il risultato lo dichiarasse un giocatore, sarebbe una scommessa
    su di lui.

    Il risultato pesa la forma delle due squadre, ma non la copia: una
    squadra in fondo alla classifica vince ancora, ogni tanto. Come
    dev'essere.
]]

local U = AUREA.Util
local eventiPartita = {}    -- [idPartita] = id dell'evento di scommessa

-- ---------------------------------------------------------------------------
--  Tifosi e biglietti
-- ---------------------------------------------------------------------------
local function tifosoDi(citizenid)
    return MySQL.single.await(
        'SELECT squadra, tessera, ingressi FROM calcio_tifosi WHERE citizenid = ?', { citizenid })
end

exports('SquadraDi', function(citizenid)
    local t = tifosoDi(citizenid)
    return t and t.squadra or nil
end)

AUREA.Callback.Registra('cal:stadio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local classifica = MySQL.query.await([[
        SELECT codice, nome, punti, giocate, vinte, pari, perse, gol_fatti, gol_subiti
        FROM calcio_squadre
        ORDER BY punti DESC, (gol_fatti - gol_subiti) DESC, gol_fatti DESC
    ]]) or {}

    local partita = MySQL.single.await([[
        SELECT id, casa, ospite, gol_casa, gol_ospite, stato, spettatori,
               TIMESTAMPDIFF(MINUTE, inizio_il, NOW()) AS minuti
        FROM calcio_partite WHERE stato IN ('programmata','in_corso')
        ORDER BY inizio_il ASC LIMIT 1
    ]])

    if partita then
        partita.nomeCasa = (CAL.GetSquadra(partita.casa) or {}).nome or partita.casa
        partita.nomeOspite = (CAL.GetSquadra(partita.ospite) or {}).nome or partita.ospite
    end

    local ultime = MySQL.query.await([[
        SELECT casa, ospite, gol_casa, gol_ospite, spettatori, incidenti,
               TIMESTAMPDIFF(MINUTE, fine_il, NOW()) AS minutiFa
        FROM calcio_partite WHERE stato = 'finita' ORDER BY id DESC LIMIT 5
    ]]) or {}
    for _, p in ipairs(ultime) do
        p.nomeCasa = (CAL.GetSquadra(p.casa) or {}).nome or p.casa
        p.nomeOspite = (CAL.GetSquadra(p.ospite) or {}).nome or p.ospite
    end

    rispondi({
        tifoso = tifosoDi(g.citizenid),
        squadre = CAL.Squadre,
        classifica = classifica,
        partita = partita,
        ultime = ultime,
        prezzi = CAL.Biglietti,
    })
end)

AUREA.Callback.Registra('cal:tessera', function(src, rispondi, squadra)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if not CAL.GetSquadra(squadra) then return rispondi(false, 'Squadra inesistente.') end

    if not g:SottraiOvunque(CAL.Biglietti.tessera, 'tessera del tifoso') then
        return rispondi(false, ('La tessera costa %s.'):format(U.Euro(CAL.Biglietti.tessera)))
    end

    local tessera = ('TF%s'):format(U.Random(7, '0123456789'))
    MySQL.query.await([[
        INSERT INTO calcio_tifosi (citizenid, squadra, tessera) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE squadra = VALUES(squadra)
    ]], { g.citizenid, squadra, tessera })

    rispondi(true, ('Tessera %s per %s.\nSenza, allo stadio non si entra.')
        :format(tessera, (CAL.GetSquadra(squadra) or {}).nome))
end)

AUREA.Callback.Registra('cal:biglietto', function(src, rispondi, settore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAL.Stadio.ingresso) > 8.0 then
        return rispondi(false, 'Il botteghino è allo stadio.')
    end

    local t = tifosoDi(g.citizenid)
    if not t then return rispondi(false, 'Serve la tessera del tifoso.') end

    -- Il DASPO. È l'intera ragione per cui questa risorsa esiste.
    local ok, daspo = pcall(function()
        return exports.ita_questura:DaspoAttivo(g.citizenid, CAL.Stadio.luogoDaspo)
    end)
    if ok and daspo then
        return rispondi(false, 'Risulta a tuo carico un divieto di accesso alle manifestazioni sportive. Il biglietto non ti si può vendere.')
    end

    local partita = MySQL.single.await([[
        SELECT id, casa, ospite, spettatori FROM calcio_partite
        WHERE stato IN ('programmata','in_corso') ORDER BY inizio_il ASC LIMIT 1
    ]])
    if not partita then return rispondi(false, 'Non c\'è nessuna partita in programma.') end

    if (partita.spettatori or 0) >= CAL.Biglietti.capienza then
        return rispondi(false, 'Tutto esaurito.')
    end

    local prezzo = settore == 'tribuna' and CAL.Biglietti.tribuna or CAL.Biglietti.curva
    if not g:SottraiOvunque(prezzo, 'biglietto allo stadio') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(prezzo)))
    end

    local quota = math.floor(prezzo * CAL.Biglietti.quotaSquadra)
    MySQL.update.await([[
        UPDATE calcio_partite SET spettatori = spettatori + 1, incassi = incassi + ? WHERE id = ?
    ]], { prezzo, partita.id })
    MySQL.update.await('UPDATE calcio_tifosi SET ingressi = ingressi + 1 WHERE citizenid = ?',
        { g.citizenid })

    TriggerEvent('aurea:fisco:incasso', 'impianti_sportivi', prezzo - quota, g.citizenid)

    rispondi(true, ('%s — %s.\n%s contro %s.')
        :format(settore == 'tribuna' and 'Tribuna' or 'Curva', U.Euro(prezzo),
                (CAL.GetSquadra(partita.casa) or {}).nome,
                (CAL.GetSquadra(partita.ospite) or {}).nome))
end)

-- ---------------------------------------------------------------------------
--  Il campionato
-- ---------------------------------------------------------------------------
local function programma()
    -- Le due squadre che hanno giocato meno: così il calendario si
    -- riequilibra da solo senza tenere un girone.
    local squadre = MySQL.query.await([[
        SELECT codice, punti, giocate FROM calcio_squadre ORDER BY giocate ASC, RAND() LIMIT 2
    ]]) or {}
    if #squadre < 2 then return end

    local id = MySQL.insert.await(
        'INSERT INTO calcio_partite (casa, ospite) VALUES (?, ?)',
        { squadre[1].codice, squadre[2].codice })

    local nomeCasa = (CAL.GetSquadra(squadre[1].codice) or {}).nome or squadre[1].codice
    local nomeOspite = (CAL.GetSquadra(squadre[2].codice) or {}).nome or squadre[2].codice

    -- L'evento su cui scommettere lo apre aurea_scommesse: qui non si
    -- riscrive un banco che esiste già, e soprattutto non si scrive
    -- nella sua tabella — si usa il suo export, perché è lui a sapere
    -- come si liquida.
    local idEvento
    pcall(function()
        idEvento = exports.aurea_scommesse:ApriEvento(
            ('%s - %s'):format(nomeCasa, nomeOspite), { '1', 'X', '2' })
    end)
    if idEvento then eventiPartita[id] = idEvento end

    exports.aurea_ui:NotificaTutti({
        tipo = 'info', icona = '⚽', durata = 14000,
        titolo = 'Prossima partita',
        testo = ('%s contro %s. Biglietti allo stadio, scommesse al banco.')
            :format(nomeCasa, nomeOspite),
    })

    return id
end

--- Il risultato. Pesa la forma senza copiarla.
local function gioca(partita)
    local forzaCasa = MySQL.scalar.await(
        'SELECT punti FROM calcio_squadre WHERE codice = ?', { partita.casa }) or 0
    local forzaOspite = MySQL.scalar.await(
        'SELECT punti FROM calcio_squadre WHERE codice = ?', { partita.ospite }) or 0

    local totale = math.max(1, forzaCasa + forzaOspite)
    local peso = CAL.Campionato.pesoForma

    local function gol(forza)
        local base = math.random(0, CAL.Campionato.golMassimi)
        local vantaggio = ((forza / totale) - 0.5) * peso * CAL.Campionato.golMassimi * 2
        return math.max(0, math.min(CAL.Campionato.golMassimi,
            math.floor(base + vantaggio + 0.5)))
    end

    -- Il fattore campo: mezzo gol, che è quello che vale davvero
    local golCasa = gol(forzaCasa + 3)
    local golOspite = gol(forzaOspite)

    return golCasa, golOspite
end

local function chiudi(partita, golCasa, golOspite)
    MySQL.update.await([[
        UPDATE calcio_partite SET gol_casa = ?, gol_ospite = ?, stato = 'finita', fine_il = NOW()
        WHERE id = ?
    ]], { golCasa, golOspite, partita.id })

    local function aggiorna(codice, fatti, subiti, punti, esito)
        MySQL.update.await(([[
            UPDATE calcio_squadre
            SET punti = punti + ?, giocate = giocate + 1, %s = %s + 1,
                gol_fatti = gol_fatti + ?, gol_subiti = gol_subiti + ?
            WHERE codice = ?
        ]]):format(esito, esito), { punti, fatti, subiti, codice })
    end

    if golCasa > golOspite then
        aggiorna(partita.casa, golCasa, golOspite, 3, 'vinte')
        aggiorna(partita.ospite, golOspite, golCasa, 0, 'perse')
    elseif golOspite > golCasa then
        aggiorna(partita.casa, golCasa, golOspite, 0, 'perse')
        aggiorna(partita.ospite, golOspite, golCasa, 3, 'vinte')
    else
        aggiorna(partita.casa, golCasa, golOspite, 1, 'pari')
        aggiorna(partita.ospite, golOspite, golCasa, 1, 'pari')
    end

    local nomeCasa = (CAL.GetSquadra(partita.casa) or {}).nome or partita.casa
    local nomeOspite = (CAL.GetSquadra(partita.ospite) or {}).nome or partita.ospite

    -- L'esito lo dichiara il sistema, non un giocatore: è la ragione
    -- per cui su queste partite si può scommettere senza fidarsi di
    -- nessuno. La liquidazione la fa aurea_scommesse, che è l'unico a
    -- sapere quanto c'è nel monte.
    local esito = golCasa > golOspite and '1' or (golOspite > golCasa and '2' or 'X')
    local idEvento = eventiPartita[partita.id]
    if idEvento then
        pcall(function() exports.aurea_scommesse:Liquida(idEvento, esito, 'campionato') end)
        eventiPartita[partita.id] = nil
    end

    exports.aurea_ui:NotificaTutti({
        tipo = 'info', icona = '⚽', durata = 16000,
        titolo = 'Finale',
        testo = ('%s %d - %d %s'):format(nomeCasa, golCasa, golOspite, nomeOspite),
    })

    AUREA.Log('economia', 'info', nil, ('%s %d-%d %s'):format(nomeCasa, golCasa, golOspite, nomeOspite))
end

-- ---------------------------------------------------------------------------
--  Ordine pubblico allo stadio
-- ---------------------------------------------------------------------------
local function tafferuglio(partita)
    local presenti = {}
    for _, g in pairs(AUREA.Giocatori) do
        if #(GetEntityCoords(GetPlayerPed(g.source)) - CAL.Stadio.coord)
           <= CAL.Stadio.raggioTifoseria then
            local t = tifosoDi(g.citizenid)
            if t then
                presenti[t.squadra] = presenti[t.squadra] or {}
                table.insert(presenti[t.squadra], g)
            end
        end
    end

    local tifoserie = {}
    for squadra, elenco in pairs(presenti) do
        if #elenco >= CAL.Ordine.tifosiPerTafferuglio then
            tifoserie[#tifoserie + 1] = { squadra = squadra, gente = elenco }
        end
    end

    if #tifoserie < 2 then return false end
    if math.random(100) > CAL.Ordine.probabilitaTafferuglio then return false end

    local coinvolti = {}
    for _, t in ipairs(tifoserie) do
        for _, g in ipairs(t.gente) do coinvolti[#coinvolti + 1] = g end
    end

    for _, g in ipairs(coinvolti) do
        exports.ita_giustizia:ApriFascicolo(g.citizenid, CAL.Ordine.reato,
            'servizio di ordine pubblico',
            ('Tafferugli allo stadio durante %s'):format(CAL.Stadio.nome))

        g:SottraiOvunque(CAL.Ordine.sanzione, 'sanzione per disordini allo stadio')
        TriggerEvent('aurea:fisco:incasso', 'sanzioni_amministrative',
            CAL.Ordine.sanzione, g.citizenid)

        -- Il DASPO lo dispone la Questura. Qui si chiede, non si impone.
        MySQL.insert.await([[
            INSERT INTO questura_daspo (citizenid, luogo, motivo, emesso_da, scadenza)
            VALUES (?, ?, ?, NULL, DATE_ADD(NOW(), INTERVAL ? HOUR))
        ]], { g.citizenid, CAL.Stadio.luogoDaspo,
              'Disordini accertati durante una manifestazione sportiva', CAL.Ordine.oreDaspo })

        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '🚷', durata = 20000,
            titolo = 'DASPO',
            testo = ('Sei stato coinvolto nei tafferugli. Divieto di accesso allo stadio per %d ore e sanzione di %s.')
                :format(CAL.Ordine.oreDaspo, U.Euro(CAL.Ordine.sanzione)),
        })
    end

    MySQL.update.await('UPDATE calcio_partite SET incidenti = incidenti + ? WHERE id = ?',
        { #coinvolti, partita.id })

    exports.aurea_ui:NotificaEnte('polizia', {
        tipo = 'errore', icona = '🚨', durata = 20000,
        titolo = 'Disordini allo stadio',
        testo = ('%d persone coinvolte. DASPO emessi d\'ufficio.'):format(#coinvolti),
    }, true)

    AUREA.Log('giustizia', 'avviso', nil, ('tafferugli allo stadio: %d coinvolti'):format(#coinvolti))
    return true
end

-- ---------------------------------------------------------------------------
--  Il ciclo del campionato
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(20000)

    while true do
        local partita = MySQL.single.await([[
            SELECT id, casa, ospite FROM calcio_partite
            WHERE stato = 'programmata' ORDER BY inizio_il ASC LIMIT 1
        ]])

        if not partita then
            programma()
            Wait(CAL.Campionato.minutiFraPartite * 60000)
        else
            MySQL.update.await('UPDATE calcio_partite SET stato = ? WHERE id = ?',
                { 'in_corso', partita.id })

            -- Durante la partita, a metà, si guarda se succede qualcosa
            Wait(math.floor(CAL.Campionato.minutiDurata * 60000 / 2))
            tafferuglio(partita)
            Wait(math.floor(CAL.Campionato.minutiDurata * 60000 / 2))

            local golCasa, golOspite = gioca(partita)
            chiudi(partita, golCasa, golOspite)

            Wait(CAL.Campionato.minutiFraPartite * 60000)
        end
    end
end)
