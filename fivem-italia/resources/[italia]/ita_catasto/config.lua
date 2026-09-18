--[[
    AUREA · Catasto — configurazione

    IL BUCO CHE HA APERTO L'EDILIZIA

    Con ita_edilizia si costruisce davvero: sei fasi, materiali, ponteggio,
    infortuni. Alla consegna l'impresa incassa e il cantiere si chiude.

    E poi? Niente. Il palazzo non esisteva da nessuna parte. Non si poteva
    comprare, non si poteva abitare, non pagava IMU. Era un'opera fatta e
    un immobile che non c'era.

    In Italia manca esattamente un passaggio: l'ACCATASTAMENTO. Un
    fabbricato nuovo va dichiarato al catasto entro trenta giorni dalla
    fine dei lavori. Da lì nasce la scheda catastale, la categoria, e
    soprattutto la RENDITA — il numero da cui discende tutto il resto,
    a cominciare dall'IMU.

    E L'ALTRO BUCO: LA VOLTURA

    Dopo un rogito il notaio trasferisce la proprietà. Ma il catasto non
    lo sa finché qualcuno non presenta la voltura. Finché non è presentata
    l'immobile risulta ancora intestato a chi l'ha venduto — e le imposte
    le paga lui.

    Non è un fastidio inventato: è il motivo per cui in Italia si paga
    l'IMU di una casa venduta tre anni prima. Qui succede uguale, e si
    risolve allo sportello.
]]

CAT = {}

CAT.Lavoro = 'comune'
CAT.Permesso = 'anagrafe'

-- ---------------------------------------------------------------------------
--  Lo sportello
-- ---------------------------------------------------------------------------
CAT.Sportello = {
    nome = 'Agenzia delle Entrate — Servizi catastali',
    coord = vector3(-702.6, -154.2, 37.4),
    raggio = 2.3,
    blip = { sprite = 407, colore = 4, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Categorie catastali
--
--  Quelle vere, con il moltiplicatore che porta dalla rendita alla base
--  imponibile. Non serve l'elenco intero: bastano quelle che il server usa.
-- ---------------------------------------------------------------------------
CAT.Categorie = {
    A2 = { nome = 'A/2 — abitazione civile',     abitativa = true,  moltiplicatore = 160, renditaPerMetroCubo = 42 },
    A7 = { nome = 'A/7 — villino',               abitativa = true,  moltiplicatore = 160, renditaPerMetroCubo = 58 },
    A10 = { nome = 'A/10 — ufficio',             abitativa = false, moltiplicatore = 80,  renditaPerMetroCubo = 66 },
    C1 = { nome = 'C/1 — negozio',               abitativa = false, moltiplicatore = 55,  renditaPerMetroCubo = 74 },
    C2 = { nome = 'C/2 — magazzino',             abitativa = false, moltiplicatore = 140, renditaPerMetroCubo = 18 },
    C6 = { nome = 'C/6 — box o posto auto',      abitativa = false, moltiplicatore = 160, renditaPerMetroCubo = 14 },
    D1 = { nome = 'D/1 — opificio',              abitativa = false, moltiplicatore = 65,  renditaPerMetroCubo = 30 },
}

--- Che categoria spetta a un'opera, dalla destinazione del lotto.
function CAT.CategoriaPer(destinazione, volumetria)
    if destinazione == 'produttiva' then return volumetria >= 3000 and 'D1' or 'C2' end
    if volumetria >= 2000 then return 'A2' end
    return 'A7'
end

--- Il tipo di immobile per la tabella `immobili`, dalla categoria.
CAT.TipoImmobile = {
    A2 = 'appartamento', A7 = 'villa', A10 = 'locale',
    C1 = 'locale', C2 = 'magazzino', C6 = 'box', D1 = 'magazzino',
}

-- ---------------------------------------------------------------------------
--  Accatastamento (la pratica DOCFA)
-- ---------------------------------------------------------------------------
CAT.Docfa = {
    -- Tributi speciali catastali, per pratica
    tributi = 65000,
    -- Quanto ci mette la pratica a essere istruita, in secondi
    secondiIstruttoria = 30,
    -- Entro quanti minuti dalla consegna va presentata. Dopo, sanzione.
    minutiPerPresentare = 120,
    sanzioneTardiva = 180000,
    -- Il prezzo di listino che l'immobile nuovo assume: la rendita
    -- moltiplicata per il coefficiente di mercato
    coefficienteMercato = 210,
}

-- ---------------------------------------------------------------------------
--  Voltura
-- ---------------------------------------------------------------------------
CAT.Voltura = {
    tributi = 35000,
    -- Entro quanti minuti dal rogito. Dopo, l'imposta resta al venditore
    -- e chi ha comprato se ne accorge tardi.
    minutiPerPresentare = 90,
    sanzioneTardiva = 60000,
}

-- ---------------------------------------------------------------------------
--  Visura
-- ---------------------------------------------------------------------------
CAT.Visura = {
    -- La visura è pubblica: chiunque può vedere di chi è una casa. In
    -- Italia è così, ed è la ragione per cui si sa sempre tutto di tutti.
    pubblica = true,
    costo = 9000,
}

--- La rendita di un fabbricato, dalla volumetria e dalla categoria.
function CAT.Rendita(categoria, volumetria)
    local c = CAT.Categorie[categoria]
    if not c then return 0 end
    return math.floor((volumetria / 100) * c.renditaPerMetroCubo * 100)
end
