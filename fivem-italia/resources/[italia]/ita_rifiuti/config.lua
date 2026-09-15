--[[
    AUREA · Traffico di rifiuti — configurazione

    DA DOVE NASCE

    C'era il netturbino, che raccoglie l'indifferenziato e porta all'isola
    ecologica. Ma quella è la spazzatura di casa. I rifiuti che contano —
    quelli che in Italia hanno creato un'economia criminale intera — sono
    i RIFIUTI SPECIALI: quello che producono un cantiere, un'officina, un
    ospedale, un laboratorio.

    Per quelli non basta il cassonetto. Serve il formulario di
    identificazione (il FIR), che accompagna il carico dal produttore
    all'impianto e dice chi ha prodotto cosa, quanto, e dove è finito.

    LA SCORCIATOIA

    Smaltire in regola costa al chilo. Darlo a qualcuno che "se ne
    occupa" costa meno, e quel qualcuno lo scarica in campagna. È tutto
    qui: il traffico illecito di rifiuti è una differenza di prezzo.

    Il problema è che il carico lascia una traccia. Il produttore ha un
    registro di carico e scarico, e se i chili prodotti non tornano con i
    formulari, la differenza è finita da qualche parte.

    COSA RISCHIA CHI LO FA

    Art. 256 D.Lgs. 152/2006 per la gestione non autorizzata. Ma se il
    giro è organizzato e continuativo si passa all'art. 452-quaterdecies
    c.p. — attività organizzate per il traffico illecito — che è il reato
    per cui esiste la parola ecomafia.

    E la bonifica la paga chi l'ha sporcato. Sempre.
]]

RIF = {}

RIF.Vigilanza = { 'carabinieri', 'guardia_finanza' }

-- ---------------------------------------------------------------------------
--  Impianto autorizzato
-- ---------------------------------------------------------------------------
RIF.Impianto = {
    nome = 'Impianto di smaltimento autorizzato',
    coord = vector3(-336.4, -1548.6, 25.9),
    raggio = 4.0,
    blip = { sprite = 318, colore = 2, scala = 0.8 },
    -- Costo di smaltimento al chilo, in centesimi
    costoAlChilo = 260,
}

-- ---------------------------------------------------------------------------
--  Chi produce rifiuti speciali, e quanti
--
--  Il peso si accumula in silenzio mentre si lavora: non è un'attività,
--  è una conseguenza. Te ne accorgi quando devi smaltirli.
-- ---------------------------------------------------------------------------
RIF.Produzione = {
    edile        = { chiliPerAzione = 14, codice = 'CER 17', nome = 'Rifiuti da costruzione e demolizione' },
    meccanico    = { chiliPerAzione = 6,  codice = 'CER 13', nome = 'Oli esausti e filtri' },
    ristoratore  = { chiliPerAzione = 3,  codice = 'CER 20', nome = 'Oli vegetali esausti' },
    cuoco        = { chiliPerAzione = 3,  codice = 'CER 20', nome = 'Oli vegetali esausti' },
    medico       = { chiliPerAzione = 4,  codice = 'CER 18', nome = 'Rifiuti sanitari a rischio infettivo' },
    ['118']      = { chiliPerAzione = 4,  codice = 'CER 18', nome = 'Rifiuti sanitari a rischio infettivo' },
}

function RIF.ProduzionePer(lavoro)
    return RIF.Produzione[lavoro]
end

-- ---------------------------------------------------------------------------
--  Formulario
-- ---------------------------------------------------------------------------
RIF.Formulario = {
    -- Il carico minimo che vale un formulario
    chiliMinimi = 20,
    -- Il peso massimo che una persona può trasportare addosso
    chiliMassimiAddosso = 400,
}

-- ---------------------------------------------------------------------------
--  Le discariche abusive
--
--  Posti fuori mano. Quando qualcuno ci scarica, il posto si contamina e
--  resta contaminato finché non lo bonificano.
-- ---------------------------------------------------------------------------
RIF.Siti = {
    { id = 'cava',     nome = 'Cava abbandonata di Senora',  coord = vector3(2916.4, 2790.6, 40.8) },
    { id = 'canale',   nome = 'Canale di scolo di Alamo',    coord = vector3(1626.2, 3086.4, 39.5) },
    { id = 'bosco',    nome = 'Pista forestale del Chiliad', coord = vector3(-480.6, 5194.2, 100.4) },
    { id = 'capannone',nome = 'Capannone dismesso di Cypress', coord = vector3(830.4, -2246.8, 29.6) },
    { id = 'scogliera',nome = 'Scogliera di Paleto',         coord = vector3(-292.8, 6605.4, 7.2) },
}

function RIF.GetSito(id)
    for _, s in ipairs(RIF.Siti) do
        if s.id == id then return s end
    end
end

RIF.Discarica = {
    -- Quanto paga lo smaltitore abusivo al chilo: meno dell'impianto, ed
    -- è tutta la ragione per cui questo esiste
    compensoAlChilo = 140,
    -- Quanto tempo ci vuole a scaricare
    secondiScarico = 25,
    -- Sopra questo peso accumulato il sito diventa visibile dall'alto e
    -- comincia a comparire nelle segnalazioni
    chiliVisibile = 600,
    -- Contaminazione: sale con i chili, scende con la bonifica
    contaminazionePerCentoChili = 4,
    -- Probabilità, a ogni controllo, che qualcuno segnali un sito visibile
    probabilitaSegnalazione = 0.22,
    controlloMinuti = 12,
}

-- ---------------------------------------------------------------------------
--  Bonifica
-- ---------------------------------------------------------------------------
RIF.Bonifica = {
    -- Quanto costa al chilo: più del doppio dello smaltimento regolare,
    -- perché bonificare è sempre più caro che non sporcare
    costoAlChilo = 620,
    secondiPerLotto = 18,
    chiliPerLotto = 100,
    -- Compenso a chi la esegue materialmente
    compensoPerLotto = 18000,
}

-- ---------------------------------------------------------------------------
--  Reati
-- ---------------------------------------------------------------------------
RIF.Reati = {
    gestione = '256',
    organizzato = '452q',
    -- Sopra questo peso scaricato in totale da una persona si passa
    -- dall'illecito puntuale al traffico organizzato
    sogliaOrganizzato = 2500,
    -- Sanzione amministrativa al chilo non tracciato
    sanzioneAlChilo = 900,
    -- Calore per l'organizzazione dello smaltitore
    calorePerScarico = 4,
}
