--[[
    AUREA · Intercettazioni — configurazione

    COSA MANCAVA

    I tabulati c'erano già: /tabulati dà chi ha chiamato chi, quando e per
    quanto. Ma il tabulato è il contorno della conversazione, non la
    conversazione. Mancava il contenuto — e mancava soprattutto la ragione
    per cui il contenuto è difficile da ottenere.

    IL MECCANISMO, CHE È QUELLO VERO

    La polizia giudiziaria non decide di intercettare: chiede. Il decreto
    lo emette il giudice, su richiesta del pubblico ministero, e solo se
    ci sono gravi indizi di reato e l'intercettazione è indispensabile
    (art. 267 c.p.p.).

    Ma i giudici non sono sempre svegli, nemmeno nella realtà. Per questo
    esiste il comma 2: nei casi d'urgenza il PM dispone con decreto
    motivato, e il giudice CONVALIDA entro quarantotto ore. Se non
    convalida, l'intercettazione non può essere utilizzata.

    Qui funziona uguale. Se c'è un giudice in servizio, si chiede a lui. Se
    non c'è, si procede d'urgenza — e si resta con un fascicolo che vale
    zero finché qualcuno non lo convalida. È la differenza fra avere le
    prove e avere solo saputo delle cose.

    COSA SI OTTIENE

    Un brogliaccio: le chiamate e gli SMS del bersaglio, in chiaro, dal
    momento del decreto in avanti. Mai prima — quello che è già stato
    detto non torna indietro.

    E COSA COSTA

    Intercettare senza decreto è art. 617 c.p. Passare a un terzo quello
    che si è ascoltato è art. 326 c.p. Il modulo non impedisce né l'una né
    l'altra: le rende contestabili.
]]

INT = {}

-- Chi può chiedere un decreto
INT.PoliziaGiudiziaria = { 'carabinieri', 'polizia', 'guardia_finanza' }
-- Chi lo emette e lo convalida
INT.Magistratura = 'giudice'

-- ---------------------------------------------------------------------------
--  La sala d'ascolto
--
--  Il brogliaccio si legge lì e basta: non è un'app del telefono, non si
--  consulta dal divano. È una scelta, non una dimenticanza.
-- ---------------------------------------------------------------------------
INT.Sala = {
    nome = 'Sala intercettazioni — Procura',
    coord = vector3(238.6, -415.2, 48.1),
    raggio = 2.2,
    blip = { sprite = 60, colore = 27, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Il decreto
-- ---------------------------------------------------------------------------
INT.Decreto = {
    -- Quanto dura un'autorizzazione, in minuti
    durataMinuti = 60,
    -- Proroga: quante volte si può chiedere
    prorogheMassime = 2,
    -- Il termine per la convalida dell'urgenza (48 ore → minuti di gioco)
    convalidaMinuti = 25,
    -- Quante intercettazioni contemporanee regge la sala
    contemporaneeMassime = 6,
    -- Costo a carico dell'erario, per decreto: le intercettazioni costano
    costoErario = 180000,
}

-- ---------------------------------------------------------------------------
--  I presupposti
--
--  Non si intercetta per curiosità. Serve un fascicolo aperto a carico del
--  bersaglio per uno di questi reati, e la gravità decide se basta.
-- ---------------------------------------------------------------------------
INT.Presupposti = {
    -- Gravità minima del reato nel casellario del bersaglio
    gravitaMinima = 3,
    -- Reati per cui si procede comunque, qualunque sia la gravità
    sempreAmmessi = { '416', '416b', 'dpr74', '629', '644', '648b', '452q' },
}

-- ---------------------------------------------------------------------------
--  Stati di un decreto
-- ---------------------------------------------------------------------------
INT.Stati = {
    richiesto   = { nome = 'Richiesta in attesa',     icona = '⏳', ascolta = false, utilizzabile = false },
    autorizzato = { nome = 'Autorizzato dal giudice', icona = '⚖', ascolta = true,  utilizzabile = true  },
    urgenza     = { nome = 'Urgenza del PM',          icona = '⚠', ascolta = true,  utilizzabile = false },
    convalidato = { nome = 'Convalidato',             icona = '✅', ascolta = true,  utilizzabile = true  },
    respinto    = { nome = 'Respinto',                icona = '⛔', ascolta = false, utilizzabile = false },
    inutilizzabile = { nome = 'Inutilizzabile',       icona = '🗑', ascolta = false, utilizzabile = false },
    scaduto     = { nome = 'Scaduto',                 icona = '⏱', ascolta = false, utilizzabile = false },
}

function INT.EPoliziaGiudiziaria(lavoro)
    for _, l in ipairs(INT.PoliziaGiudiziaria) do
        if l == lavoro then return true end
    end
    return false
end

function INT.Ammesso(reatoCodice)
    for _, c in ipairs(INT.Presupposti.sempreAmmessi) do
        if c == reatoCodice then return true end
    end
    local r = AUREA.Reati[reatoCodice]
    return r ~= nil and r.gravita >= INT.Presupposti.gravitaMinima
end
