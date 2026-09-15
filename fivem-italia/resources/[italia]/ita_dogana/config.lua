--[[
    AUREA · Agenzia delle Dogane e dei Monopoli — configurazione

    IL PUNTO

    Il porto c'era (ita_nautica), il mercato nero c'era (ita_illegale), la
    Guardia di Finanza c'era. Mancava il posto in cui la merce entra nel
    paese — e con lei il modo più italiano di guadagnare male: dichiarare
    meno di quello che c'è dentro.

    IL CIRCUITO DOGANALE

    Non è un'invenzione: in dogana ogni dichiarazione viene assegnata a un
    canale di controllo.

        verde       svincolo immediato, nessun controllo
        giallo      controllo documentale
        arancione   scanner
        rosso       visita merce: aprono il container

    Il canale lo estrae il SERVER quando la dichiarazione viene presentata,
    e l'importatore non lo sa finché non gli viene comunicato. Dichiarare
    il falso è quindi una scommessa con probabilità note: conviene quasi
    sempre, finché non conviene per niente.

    Se il canale è rosso e dentro c'è più di quanto dichiarato, scatta il
    contrabbando: art. 292 D.P.R. 43/1973, o il 291-bis se sono tabacchi.
]]

DOG = {}

DOG.Lavoro = 'guardia_finanza'

-- ---------------------------------------------------------------------------
--  L'ufficio doganale e il terminal container
-- ---------------------------------------------------------------------------
DOG.Ufficio = {
    nome = 'Agenzia delle Dogane — Ufficio di Porto',
    coord = vector3(1200.4, -3113.8, 5.9),
    raggio = 2.4,
    blip = { sprite = 478, colore = 5, scala = 0.75 },
}

DOG.Terminal = {
    nome = 'Terminal container',
    coord = vector3(1084.2, -3170.5, 5.9),
    blip = { sprite = 477, colore = 47, scala = 0.8 },
    -- Dove si materializzano i container in attesa di svincolo
    piazzale = {
        vector3(1071.6, -3182.4, 5.9),
        vector3(1077.2, -3186.1, 5.9),
        vector3(1082.8, -3189.8, 5.9),
        vector3(1088.4, -3193.5, 5.9),
    },
}

-- ---------------------------------------------------------------------------
--  Le partite di merce
--
--  `valoreReale` è quanto c'è davvero dentro. L'importatore dichiara un
--  valore a piacere: da lì si calcolano dazio, accisa e IVA.
-- ---------------------------------------------------------------------------
DOG.Partite = {
    {
        id = 'tessile', nome = 'Partita tessile', icona = '🧵',
        costo = 180000, valoreReale = 420000,
        dazio = 0.12, accisa = 0,
        resa = { tessuto_pregiato = 14, plastica = 6 },
        descrizione = 'Rotoli di tessuto e accessori. Merce banale, dazio basso.',
    },
    {
        id = 'elettronica', nome = 'Partita di elettronica', icona = '💻',
        costo = 340000, valoreReale = 780000,
        dazio = 0.14, accisa = 0,
        resa = { componenti_elettronici = 18, rame = 10, plastica = 8 },
        descrizione = 'Componentistica. Vale molto e pesa poco: è quella che tentano tutti.',
    },
    {
        id = 'alcolici', nome = 'Partita di alcolici', icona = '🍾',
        costo = 260000, valoreReale = 610000,
        dazio = 0.10, accisa = 0.28,
        resa = { vino_docg = 10, amaro = 8 },
        descrizione = 'Soggetta ad accisa: qui il fisco pesa più del dazio.',
        reatoSeSottodichiarata = '292',
    },
    {
        id = 'tabacchi', nome = 'Partita di tabacchi lavorati', icona = '🚬',
        costo = 300000, valoreReale = 980000,
        dazio = 0.10, accisa = 0.59,
        resa = { sigarette = 40 },
        descrizione = 'Accisa al 59%. Il contrabbando di TLE esiste per questo.',
        reatoSeSottodichiarata = '291b',
        soloConLicenza = true,
    },
    {
        id = 'ricambi', nome = 'Partita di ricambi auto', icona = '🔧',
        costo = 220000, valoreReale = 495000,
        dazio = 0.08, accisa = 0,
        resa = { acciaio = 12, kit_riparazione = 6, componenti_elettronici = 5 },
        descrizione = 'Ricambistica generica. Chi ha un\'officina la rivende bene.',
    },
}

function DOG.GetPartita(id)
    for _, p in ipairs(DOG.Partite) do
        if p.id == id then return p end
    end
end

-- ---------------------------------------------------------------------------
--  Tributi
-- ---------------------------------------------------------------------------
DOG.Tributi = {
    iva = 0.22,
    -- Diritti fissi per bolletta, comunque dovuti
    dirittiDoganali = 4500,
    -- Giorni per pagare quanto liquidato
    giorniPagamento = 5,
}

-- ---------------------------------------------------------------------------
--  Il circuito di controllo
--
--  Le probabilità cambiano con quanto è credibile la dichiarazione: chi
--  dichiara metà del dovuto finisce sul rosso molto più spesso. Non è
--  magia, è analisi del rischio — e funziona così anche nella realtà.
-- ---------------------------------------------------------------------------
DOG.Circuito = {
    -- Probabilità di base, con dichiarazione congrua
    base = { verde = 0.62, giallo = 0.20, arancione = 0.12, rosso = 0.06 },
    -- Quanto si sposta verso il rosso per ogni 10% di valore non dichiarato
    spostamentoPerDecile = 0.055,
    -- Un operatore già colto in fallo resta profilato a rischio
    penalitaPrecedenti = 0.09,
    massimoRosso = 0.80,
}

--- Estrae il canale. `scostamento` è la quota di valore non dichiarata (0-1).
function DOG.EstraiCanale(scostamento, precedenti)
    local rosso = DOG.Circuito.base.rosso
        + math.max(0, scostamento) * 10 * DOG.Circuito.spostamentoPerDecile
        + (precedenti or 0) * DOG.Circuito.penalitaPrecedenti
    rosso = math.min(DOG.Circuito.massimoRosso, rosso)

    local resto = 1 - rosso
    local arancione = resto * 0.18
    local giallo = resto * 0.26
    local estratto = math.random()

    if estratto < rosso then return 'rosso' end
    if estratto < rosso + arancione then return 'arancione' end
    if estratto < rosso + arancione + giallo then return 'giallo' end
    return 'verde'
end

DOG.Canali = {
    verde     = { nome = 'Canale verde',     icona = '🟢', controlla = false, testo = 'Svincolo immediato.' },
    giallo    = { nome = 'Canale giallo',    icona = '🟡', controlla = false, testo = 'Controllo documentale: la bolletta viene riletta, la merce no.' },
    arancione = { nome = 'Canale arancione', icona = '🟠', controlla = 'scanner', testo = 'Scanner: si vede la sagoma, non il valore.' },
    rosso     = { nome = 'Canale rosso',     icona = '🔴', controlla = 'visita', testo = 'Visita merce: aprono il container.' },
}

-- ---------------------------------------------------------------------------
--  Sanzioni
-- ---------------------------------------------------------------------------
DOG.Sanzioni = {
    -- Multiplo del tributo evaso (art. 295 TULD: da 2 a 10 volte)
    moltiplicatoreMinimo = 2,
    moltiplicatoreMassimo = 6,
    -- Sotto questa soglia di evasione è solo illecito amministrativo
    sogliaPenale = 100000,      -- 1.000 € di tributo evaso
    -- La merce sequestrata non torna indietro
    confisca = true,
}

-- ---------------------------------------------------------------------------
--  Licenza di importazione
--
--  Serve per le partite soggette a monopolio. La rilascia l'ufficio
--  doganale a chi ha una partita IVA attiva.
-- ---------------------------------------------------------------------------
DOG.Licenza = {
    costo = 250000,
    validitaMinuti = 360,
    item = 'visura',
}
