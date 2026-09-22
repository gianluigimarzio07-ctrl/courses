--[[
    AUREA · Capitaneria di Porto — Guardia Costiera — configurazione

    Nel codice di AUREA la Capitaneria c'era già prima di esistere.
    ita_nautica tiene in ogni porto una coordinata chiamata `capitaneria`
    e non ci mette niente sopra; ita_pesca scrive
    `PES.Controlli.lavoro = 'guardia_costiera'` e poi ammette ai controlli
    i carabinieri e la finanza, con accanto il commento che dice «la
    Guardia Costiera in AUREA è un reparto della Capitaneria». Questa
    risorsa è quel reparto.

    La differenza con le altre forze non è il distintivo, è il confine.
    A terra la Capitaneria non ferma nessuno: la sua autorità comincia
    sulla banchina e finisce dove finisce il mare territoriale. In cambio,
    in acqua comanda lei — anche sui carabinieri, che in mare sono
    ospiti.

    Tre cose che qui si fanno e altrove no:

      · l'ORDINANZA. Un atto scritto che chiude un pezzo di mare:
        niente balneazione, niente motore, niente reti. Vale per tutti,
        anche per chi non l'ha letta, e chi ci entra prende il verbale.

      · il SAR. La ricerca e soccorso non è «vai lì e raccoglilo»:
        è un'area divisa in settori, ognuno assegnato a un mezzo, e
        finché i settori non sono battuti la persona è ancora in acqua.

      · il FERMO AMMINISTRATIVO. Un natante fermato non si muove più
        finché qualcuno non paga. Non è un sequestro penale: è la sanzione
        che morde davvero, perché la barca resta al pontile.
]]

CAP = {}

CAP.Lavoro = 'capitaneria'
CAP.Ente   = 'capitaneria'

-- ---------------------------------------------------------------------------
--  Le sedi
--
--  Sono le stesse coordinate che ita_nautica già chiama `capitaneria` nei
--  suoi porti. Le ripetiamo qui perché una risorsa non deve dipendere dal
--  config di un'altra per sapere dove sta di casa.
-- ---------------------------------------------------------------------------
CAP.Sedi = {
    {
        id = 'marina_ovest',
        nome = 'Capitaneria di Porto — Marina di Del Perro',
        coord = vector3(-1604.9, -1069.0, 13.1),
        raggio = 2.2,
        principale = true,
        blip = { sprite = 356, colore = 38, scala = 0.85 },
    },
    {
        id = 'porto_sud',
        nome = 'Ufficio Circondariale Marittimo — Porto commerciale',
        coord = vector3(1198.4, -2996.7, 6.0),
        raggio = 2.2,
        blip = { sprite = 356, colore = 38, scala = 0.75 },
    },
    {
        id = 'paleto',
        nome = 'Delegazione di Spiaggia — Paleto',
        coord = vector3(-278.5, 6635.3, 7.5),
        raggio = 2.2,
        blip = { sprite = 356, colore = 38, scala = 0.7 },
    },
}

function CAP.SedePrincipale()
    for _, s in ipairs(CAP.Sedi) do
        if s.principale then return s end
    end
    return CAP.Sedi[1]
end

-- ---------------------------------------------------------------------------
--  Le ordinanze
--
--  Ogni tipo dice che cosa vieta e quanto costa violarlo. Gli importi
--  sono quelli veri dell'art. 1231 del Codice della Navigazione e delle
--  ordinanze balneari tipo, arrotondati.
-- ---------------------------------------------------------------------------
CAP.Ordinanze = {
    balneazione = {
        etichetta = 'Divieto di balneazione',
        icona = '🚱',
        -- Chi si tuffa dove è vietato
        vieta = 'nuoto',
        sanzione = 10300,
        articolo = 'ordinanza balneare — art. 1164 Cod. Nav.',
        descrizione = 'Acque non idonee: nessuno entra in acqua.',
        coloreBlip = 1,
    },
    specchio = {
        etichetta = 'Interdizione dello specchio acqueo',
        icona = '⛔',
        -- Nessuna unità entra, a motore o a vela
        vieta = 'navigazione',
        sanzione = 103000,
        articolo = 'art. 1231 Cod. Nav.',
        descrizione = 'Area interdetta alla navigazione: nessuna unità entra.',
        coloreBlip = 1,
    },
    pesca = {
        etichetta = 'Divieto di pesca',
        icona = '🎣',
        vieta = 'pesca',
        sanzione = 206000,
        articolo = 'art. 7 D.Lgs. 4/2012',
        descrizione = 'Fermo biologico o zona di tutela: non si cala.',
        coloreBlip = 47,
    },
    velocita = {
        etichetta = 'Limitazione di velocità',
        icona = '🐌',
        vieta = 'velocita',
        -- Sopra questa velocità dentro la zona si prende il verbale
        nodiMassimi = 6,
        sanzione = 27400,
        articolo = 'art. 1174 Cod. Nav.',
        descrizione = 'Andatura ridotta: si procede a passo d\'uomo.',
        coloreBlip = 5,
    },
}

function CAP.GetOrdinanza(tipo)
    return CAP.Ordinanze[tipo]
end

CAP.Ordinanza = {
    -- Raggi selezionabili quando si emette, in metri
    raggi = { 60, 120, 250, 500 },
    -- Un'ordinanza non è eterna: scade da sola
    minutiDurata = 90,
    -- Fra un verbale e il successivo alla stessa persona nella stessa zona
    secondiRaffreddamento = 120,
    -- Quante possono essercene insieme
    massimoAttive = 6,
}

-- ---------------------------------------------------------------------------
--  Ricerca e soccorso
--
--  L'evento SAR nasce in tre modi: lo apre un ufficiale, lo gira il 112,
--  o lo fa partire un razzo di segnalazione sparato in mare aperto —
--  lo stesso razzo che ita_nautica usa già per chiamare i soccorsi.
--
--  L'area si divide in settori quadrati. Un settore è «battuto» quando un
--  mezzo della Capitaneria ci è passato dentro abbastanza a lungo. Finché
--  restano settori non battuti, la ricerca è aperta.
-- ---------------------------------------------------------------------------
CAP.SAR = {
    -- Lato del settore, in metri
    latoSettore = 180,
    -- Quanti settori per lato: 3 → griglia 3×3 attorno al punto stimato
    settoriPerLato = 3,
    -- Quanto bisogna restare dentro un settore perché conti come battuto
    secondiPerSettore = 12,
    -- Entro quanti metri dal centro del settore si è «dentro»
    raggioSettore = 90,
    -- Il dispers0 non sta esattamente dove l'hanno visto l'ultima volta
    derivaMassima = 260,
    -- Compenso all'equipaggio che chiude la ricerca con un recupero
    compensoRecupero = 74000,
    -- Compenso ridotto a chi ha battuto settori senza trovare
    compensoSettore = 5200,
    -- Dopo quanti minuti la ricerca si chiude comunque
    minutiDurata = 25,
    -- Massimo di ricerche aperte insieme
    massimoAperte = 3,
}

-- ---------------------------------------------------------------------------
--  Controllo di un'unità
--
--  Si fa a bordo, con il natante fermo. Il server guarda quattro cose:
--  patente nautica, licenza di pesca se ci sono reti a bordo, ordinanze
--  in vigore sul punto, fermo amministrativo già in essere.
-- ---------------------------------------------------------------------------
CAP.Controllo = {
    -- Il natante deve essere praticamente fermo
    velocitaMassima = 8.0,
    -- Distanza massima dall'unità controllata
    raggio = 12.0,
    secondiDurata = 6,
    -- Fra un controllo e l'altro sulla stessa targa
    minutiRaffreddamento = 4,
    -- Dotazioni di sicurezza: se mancano è verbale. L'unità le ha se a
    -- bordo c'è almeno uno di questi.
    dotazioni = { 'giubbotto_salvataggio', 'razzo_segnalazione' },
    sanzioneDotazioni = 27400,
    articoloDotazioni = 'art. 53 c.4 D.Lgs. 171/2005',
    -- Gli stessi importi che ita_nautica applica già nei suoi controlli.
    -- Sono ripetuti e non letti da lì per la ragione detta in cima al
    -- file: una risorsa non dipende dal config di un'altra. Se li cambi
    -- di là, cambiali anche qui.
    articoloPatente = 'art. 53 c.1 D.Lgs. 171/2005',
    sanzionePatente = 227400,
}

-- ---------------------------------------------------------------------------
--  Fermo amministrativo
-- ---------------------------------------------------------------------------
CAP.Fermo = {
    -- Quanto costa dissequestrare
    importoDissequestro = 180000,
    -- Da quante violazioni in su scatta d'ufficio
    violazioniPerFermo = 2,
    -- Durata massima: oltre, decade
    minutiDurata = 180,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------

--- Distanza piana fra due punti, ignorando la quota: in mare la z è rumore.
function CAP.DistanzaPiana(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

--- I settori di una ricerca, come lista di punti con il loro indice.
function CAP.Settori(centro)
    local n = CAP.SAR.settoriPerLato
    local lato = CAP.SAR.latoSettore
    local mezzo = (n - 1) / 2
    local out = {}
    for ix = 0, n - 1 do
        for iy = 0, n - 1 do
            out[#out + 1] = {
                indice = #out + 1,
                x = centro.x + (ix - mezzo) * lato,
                y = centro.y + (iy - mezzo) * lato,
            }
        end
    end
    return out
end

--- L'etichetta di un settore come la direbbe una radio: A1, B3, C2.
function CAP.NomeSettore(indice)
    local n = CAP.SAR.settoriPerLato
    local i = indice - 1
    return ('%s%d'):format(string.char(65 + math.floor(i / n)), (i % n) + 1)
end
