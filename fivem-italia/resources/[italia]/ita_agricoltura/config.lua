--[[
    AUREA · Agricoltura — configurazione

    DA DOVE ARRIVA LA MATERIA PRIMA

    ita_madeinitaly ha sei filiere che partono tutte da qualcosa: uva,
    olive, latte, grano, pomodoro. Quel qualcosa, fino a ieri, compariva
    dal niente — si comprava al consorzio e basta. La parte più italiana
    della catena, il campo, non c'era.

    IL CAMPO NON È UNA MINIERA

    Un giacimento dà sempre la stessa cosa. Un campo no: dipende dalla
    stagione, da quanto l'hai irrigato, e da quanto tempo lo fai riposare.
    Seminare pomodori a dicembre non dà niente, e seminare grano sullo
    stesso solco tre volte di fila lo esaurisce.

    Sono quattro gesti in ordine — arare, seminare, irrigare, raccogliere
    — e fra l'uno e l'altro passa del tempo vero. Non si sta lì a
    guardare: si semina, si va a fare altro, si torna.

    LA PAC

    E poi c'è il contributo comunitario, che in Italia è una parte enorme
    del reddito agricolo. Si presenta la domanda unica, si dichiara la
    superficie coltivata, e l'erario paga a ettaro. Dichiarare più di
    quello che si coltiva è truffa aggravata — ed è, nella realtà, uno
    dei reati agricoli più frequenti.
]]

AGR = {}

AGR.Lavoro = 'agricoltore'

-- ---------------------------------------------------------------------------
--  Il consorzio agrario
-- ---------------------------------------------------------------------------
AGR.Consorzio = {
    nome = 'Consorzio agrario',
    coord = vector3(2225.4, 5577.2, 53.8),
    raggio = 3.0,
    blip = { sprite = 85, colore = 25, scala = 0.8 },
}

-- ---------------------------------------------------------------------------
--  I poderi
--
--  Ognuno ha una superficie in ettari e un certo numero di solchi: i
--  solchi sono i punti dove si lavora, gli ettari servono alla PAC.
-- ---------------------------------------------------------------------------
AGR.Poderi = {
    {
        id = 'senora', nome = 'Podere di Grand Senora', ettari = 14,
        centro = vector3(2010.6, 4906.2, 41.2), raggio = 70.0, solchi = 8,
        canone = 180000,
    },
    {
        id = 'alamo', nome = 'Podere del fiume Alamo', ettari = 9,
        centro = vector3(1710.4, 4790.8, 41.0), raggio = 55.0, solchi = 6,
        canone = 130000,
    },
    {
        id = 'paleto', nome = 'Podere di Paleto', ettari = 11,
        centro = vector3(-160.8, 6320.4, 31.4), raggio = 60.0, solchi = 7,
        canone = 150000,
    },
    {
        id = 'vinewood', nome = 'Vigneto delle colline', ettari = 6,
        centro = vector3(1120.2, 1780.6, 78.4), raggio = 45.0, solchi = 5,
        canone = 220000, soloVite = true,
    },
}

function AGR.GetPodere(id)
    for _, p in ipairs(AGR.Poderi) do
        if p.id == id then return p end
    end
end

-- ---------------------------------------------------------------------------
--  Le colture
--
--  `stagioni` sono quelle in cui la semina attecchisce. Fuori stagione si
--  può seminare lo stesso, ma la resa crolla: è così che un campo
--  insegna il calendario.
-- ---------------------------------------------------------------------------
AGR.Colture = {
    grano = {
        nome = 'Grano duro', icona = '🌾',
        stagioni = { 'autunno', 'inverno' },
        seme = 'seme_grano', resa = 'grano',
        minutiMaturazione = 18, resaBase = 6,
        irrigazioniOttimali = 2,
        consumoSuolo = 22,
    },
    pomodoro = {
        nome = 'Pomodoro San Marzano', icona = '🍅',
        stagioni = { 'primavera', 'estate' },
        seme = 'seme_pomodoro', resa = 'pomodoro_san_marzano',
        minutiMaturazione = 14, resaBase = 8,
        irrigazioniOttimali = 3,
        consumoSuolo = 28,
    },
    olivo = {
        nome = 'Oliveto', icona = '🫒',
        stagioni = { 'autunno' },
        seme = 'seme_olivo', resa = 'olive',
        minutiMaturazione = 26, resaBase = 5,
        irrigazioniOttimali = 1,
        consumoSuolo = 12,
    },
    vite = {
        nome = 'Vite da vino', icona = '🍇',
        stagioni = { 'estate', 'autunno' },
        seme = 'seme_vite', resa = 'uva_sangiovese',
        resaAlternativa = 'uva_nebbiolo',
        minutiMaturazione = 30, resaBase = 5,
        irrigazioniOttimali = 2,
        consumoSuolo = 18,
        soloVigneto = true,
    },
    foraggio = {
        nome = 'Foraggio', icona = '🌱',
        stagioni = { 'primavera', 'estate', 'autunno' },
        seme = 'seme_foraggio', resa = 'foraggio',
        minutiMaturazione = 10, resaBase = 10,
        irrigazioniOttimali = 1,
        consumoSuolo = 8,
    },
}

function AGR.GetColtura(id)
    return AGR.Colture[id]
end

function AGR.InStagione(coltura, stagione)
    local c = AGR.GetColtura(coltura)
    if not c then return false end
    for _, s in ipairs(c.stagioni) do
        if s == stagione then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
--  Le lavorazioni
-- ---------------------------------------------------------------------------
AGR.Lavorazioni = {
    aratura   = { etichetta = 'Ara il solco',     secondi = 14, richiedeVeicolo = true },
    semina    = { etichetta = 'Semina',           secondi = 10 },
    irrigazione = { etichetta = 'Irriga',         secondi = 8, oggetto = 'annaffiatoio' },
    raccolta  = { etichetta = 'Raccogli',         secondi = 16 },
}

-- Il trattore serve per arare: a mano non si ara niente
AGR.Trattori = { 'tractor', 'tractor2', 'tractor3' }

-- ---------------------------------------------------------------------------
--  Fertilità del suolo
--
--  Ogni raccolto consuma. Il riposo restituisce. Chi forza il campo
--  raccoglie meno, e a un certo punto non raccoglie più niente.
-- ---------------------------------------------------------------------------
AGR.Suolo = {
    iniziale = 100,
    recuperoPerOra = 14,
    -- Sotto questa fertilità la resa comincia a calare vistosamente
    sogliaCalo = 55,
    -- Il concime la restituisce in fretta, e costa
    concime = 'concime',
    recuperoConcime = 30,
}

--- Il moltiplicatore di resa: stagione, irrigazione, fertilità.
function AGR.Moltiplicatore(coltura, stagione, irrigazioni, fertilita)
    local c = AGR.GetColtura(coltura)
    if not c then return 0 end

    local m = AGR.InStagione(coltura, stagione) and 1.0 or 0.35

    -- Irrigare quanto serve, non di più: l'acqua in eccesso non aiuta
    local scarto = math.abs((irrigazioni or 0) - c.irrigazioniOttimali)
    m = m * math.max(0.4, 1 - scarto * 0.22)

    m = m * math.max(0.15, math.min(1.15, (fertilita or 100) / 85))
    return m
end

-- ---------------------------------------------------------------------------
--  Prezzi del consorzio
-- ---------------------------------------------------------------------------
AGR.Listino = {
    seme_grano    = 1400,
    seme_pomodoro = 2200,
    seme_olivo    = 3800,
    seme_vite     = 4600,
    seme_foraggio = 900,
    concime       = 5200,
    annaffiatoio  = 12000,
}

-- ---------------------------------------------------------------------------
--  Affitto dei poderi
-- ---------------------------------------------------------------------------
AGR.Affitto = {
    -- Ogni quanto si paga il canone
    minuti = 60,
    -- Dopo quanti canoni non pagati il podere torna libero
    canoniPrimaDelloSfratto = 2,
}

-- ---------------------------------------------------------------------------
--  PAC — domanda unica
-- ---------------------------------------------------------------------------
AGR.Pac = {
    -- Contributo a ettaro dichiarato, per erogazione
    perEttaro = 42000,
    minuti = 90,
    -- La domanda si rinnova
    validitaMinuti = 180,
    -- Il controllo: quanto spesso l'organismo pagatore verifica
    probabilitaControllo = 0.35,
    -- Dichiarare più ettari di quelli che si coltivano davvero
    reatoFrode = '640',
    sanzioneMoltiplicatore = 3,
}
