--[[
    AUREA · Stupefacenti — configurazione

    L'idea che regge tutto il modulo è una sola: LA PUREZZA.

    Ogni unità di sostanza porta nei metadata un numero da 0 a 100. Non è
    un'etichetta decorativa: è la variabile da cui dipende il prezzo, il
    reato contestato, l'effetto sul consumatore e il rischio di ammazzarlo.

    Da lì nasce il dilemma che rende il traffico un gioco e non un pulsante:
    tagliare moltiplica la merce ma abbassa la purezza, e sotto una certa
    soglia i clienti la rifiutano e le piazze si bruciano; non tagliare
    lascia una purezza che il consumatore non regge, e un morto per overdose
    non è più spaccio — è l'art. 586 c.p., e il fascicolo cambia peso.

    La massa attiva si conserva: tagliando 10 dosi al 90% con 10 parti di
    mannitolo ottieni 20 dosi al 45%. Nessuna magia, solo aritmetica — ed è
    per questo che il calcolo si può insegnare a un giocatore nuovo in un
    minuto e restare interessante dopo cento ore.
]]

DRO = {}

-- ---------------------------------------------------------------------------
--  Le sostanze
-- ---------------------------------------------------------------------------
--  purezzaTipica  · quella che il mercato si aspetta
--  purezzaLetale  · sopra questa soglia il consumatore rischia l'overdose
--  purezzaMinima  · sotto questa il cliente si accorge ed è roba invendibile
--  prezzoPuro     · quanto vale una dose al 100%, in centesimi
-- ---------------------------------------------------------------------------
DRO.Sostanze = {
    erba = {
        nome = 'Marijuana', icona = '🌿',
        item = 'erba',
        prezzoPuro = 9000,
        purezzaTipica = 55, purezzaMinima = 15, purezzaLetale = 100,
        -- Non si taglia: si vende come esce dalla pianta
        tagliabile = false,
        articolo = 'dpr73l',
        articoloGrave = 'dpr73',
        sogliaGrave = 40,
    },
    hashish = {
        nome = 'Hashish', icona = '🟫',
        item = 'hashish',
        prezzoPuro = 11000,
        purezzaTipica = 50, purezzaMinima = 12, purezzaLetale = 100,
        tagliabile = true,
        articolo = 'dpr73l',
        articoloGrave = 'dpr73',
        sogliaGrave = 40,
    },
    cocaina = {
        nome = 'Cocaina', icona = '❄',
        item = 'cocaina',
        prezzoPuro = 46000,
        purezzaTipica = 70, purezzaMinima = 25, purezzaLetale = 88,
        tagliabile = true,
        articolo = 'dpr73',
        articoloGrave = 'dpr73',
        sogliaGrave = 15,
    },
    eroina = {
        nome = 'Eroina', icona = '🟤',
        item = 'eroina',
        prezzoPuro = 52000,
        purezzaTipica = 45, purezzaMinima = 18, purezzaLetale = 62,
        tagliabile = true,
        articolo = 'dpr73',
        articoloGrave = 'dpr73',
        sogliaGrave = 10,
    },
    mdma = {
        nome = 'MDMA', icona = '💊',
        item = 'mdma',
        prezzoPuro = 34000,
        purezzaTipica = 75, purezzaMinima = 30, purezzaLetale = 92,
        tagliabile = true,
        articolo = 'dpr73',
        articoloGrave = 'dpr73',
        sogliaGrave = 20,
    },
}

--- Dalla sostanza si risale all'oggetto e viceversa.
DRO.SostanzaDiItem = {}
for id, s in pairs(DRO.Sostanze) do DRO.SostanzaDiItem[s.item] = id end

function DRO.GetSostanza(id) return DRO.Sostanze[id] end

-- ---------------------------------------------------------------------------
--  Coltivazione — l'unica filiera che nasce qui
-- ---------------------------------------------------------------------------
DRO.Coltivazione = {
    minutiCrescita = 55,
    minutiSenzaCura = 25,
    massimoPiante = 12,
    resaMinima = 2, resaMassima = 5,

    -- La purezza dell'infiorescenza dipende da come è stata curata la pianta:
    -- ogni annaffiatura puntuale la alza, ogni ritardo la abbassa.
    purezzaBase = 40,
    purezzaPerCura = 7,
    purezzaPersaPerRitardo = 9,
    purezzaMassima = 82,

    -- L'odore esce e i vicini chiamano
    probabilitaSegnalazionePerPianta = 3,
    minutiControlloOdore = 12,
    calore = 4,

    seme = 'seme',
    raccolto = 'infiorescenza',
    attrezzo = 'annaffiatoio',

    zoneAlChiuso = {
        { nome = 'Magazzino portuale', coord = vector3(1009.7, -3195.0, -38.9), raggio = 40.0 },
    },
}

-- ---------------------------------------------------------------------------
--  Laboratori e lavorazione
--
--  Ogni ricetta prende materie prime e restituisce una sostanza con una
--  purezza calcolata. La maestria in "chimica" è la stessa tabella delle
--  discipline artigiane: si sale lavorando, e un chimico bravo tira fuori
--  dalla stessa pasta base venti punti di purezza in più.
-- ---------------------------------------------------------------------------
DRO.Laboratori = {
    { id = 'lab_porto',   nome = 'Laboratorio del porto',   coord = vector3(1198.0, -3255.0, -39.0), raggio = 22.0, resa = 1.00 },
    { id = 'lab_deserto', nome = 'Laboratorio nel deserto', coord = vector3(1391.0, 3608.0, 38.9),   raggio = 25.0, resa = 0.90 },
    { id = 'lab_collina', nome = 'Laboratorio in collina',  coord = vector3(-1150.0, 4940.0, 222.0), raggio = 25.0, resa = 1.10 },
}

DRO.Ricette = {
    hashish = {
        nome = 'Pressatura dell\'hashish',
        sostanza = 'hashish',
        ingredienti = { { item = 'infiorescenza', quantita = 4 } },
        resa = 2,
        durata = 16000,
        -- La purezza parte da quella della materia prima
        daMateriaPrima = 'infiorescenza',
        purezzaBase = 10,
        probabilitaFallimento = 6,
        calore = 4,
    },
    cocaina = {
        nome = 'Raffinazione della cocaina',
        sostanza = 'cocaina',
        ingredienti = { { item = 'pasta_base', quantita = 3 }, { item = 'solvente', quantita = 1 } },
        resa = 4,
        durata = 26000,
        purezzaBase = 62,
        probabilitaFallimento = 14,
        probabilitaIncendio = 25,
        calore = 8,
    },
    eroina = {
        nome = 'Raffinazione dell\'eroina',
        sostanza = 'eroina',
        ingredienti = { { item = 'oppio_grezzo', quantita = 3 }, { item = 'solvente', quantita = 2 } },
        resa = 3,
        durata = 30000,
        purezzaBase = 55,
        probabilitaFallimento = 18,
        probabilitaIncendio = 35,
        calore = 9,
    },
    mdma = {
        nome = 'Sintesi dell\'MDMA',
        sostanza = 'mdma',
        ingredienti = { { item = 'precursori', quantita = 2 }, { item = 'solvente', quantita = 1 } },
        resa = 6,
        durata = 34000,
        purezzaBase = 70,
        probabilitaFallimento = 20,
        probabilitaIncendio = 40,
        calore = 7,
    },
}

DRO.Maestria = {
    disciplina = 'chimica',
    -- Punti di purezza per livello oltre il primo
    purezzaPerLivello = 4,
    livelloMassimo = 6,
    xpPerLavorazione = 12,
    xpPerLivello = 120,
}

-- ---------------------------------------------------------------------------
--  Taglio
--
--  La massa attiva si conserva. Con `attive` unità di principio attivo
--  distribuite su `totale` dosi, la purezza è attive/totale.
-- ---------------------------------------------------------------------------
DRO.Taglio = {
    sostanzeDaTaglio = {
        mannitolo = { nome = 'Mannitolo', resa = 1.0, insospettabile = true },
        lattosio  = { nome = 'Lattosio',  resa = 1.0, insospettabile = true },
        -- La caffeina rende più di una parte per parte, ma si sente
        caffeina  = { nome = 'Caffeina',  resa = 1.4, insospettabile = false },
    },
    -- Serve il bilancino: senza, il taglio è approssimativo e si perde roba
    attrezzo = 'bilancino',
    perditaSenzaBilancino = 0.15,
    durata = 9000,
    -- Un taglio con caffeina lascia una traccia che il narcotest rivela
    calore = 2,
}

-- ---------------------------------------------------------------------------
--  Spaccio e piazze
--
--  Le piazze sono il cuore del gioco cooperativo: da solo puoi vendere,
--  ma male. Con una vedetta appostata i clienti arrivano da soli, il
--  prezzo tiene e sai in anticipo quando arriva una volante.
-- ---------------------------------------------------------------------------
DRO.Spaccio = {
    distanza = 2.5,
    durata = 6000,

    -- Il prezzo segue la purezza in modo più che proporzionale: la roba
    -- buona non vale il doppio della mediocre, vale molto di più.
    esponentePurezza = 1.35,

    bonusTerritorio = 1.35,
    penalitaSaturazione = 0.6,
    cessioniPrimaSaturazione = 6,
    minutiRecuperoPiazza = 25,

    probabilitaRifiuto = 26,
    probabilitaAgente = 6,
    probabilitaSegnalazione = 14,
    calore = 3,

    provento = 'contanti_sporchi',
    -- Un contante non tracciato ogni tot incassato
    tagliobanconota = 10000,
}

DRO.Piazze = {
    {
        id = 'piazza_vespucci', nome = 'Piazza di Vespucci',
        coord = vector3(-1170.0, -1571.0, 4.6), raggio = 28.0,
        vedetta = { coord = vector3(-1157.0, -1550.0, 4.4), raggio = 6.0 },
        territorio = 'lungomare',
    },
    {
        id = 'piazza_grove', nome = 'Piazza di Grove Street',
        coord = vector3(97.0, -1955.0, 20.8), raggio = 30.0,
        vedetta = { coord = vector3(113.0, -1936.0, 21.3), raggio = 6.0 },
        territorio = 'quartiere_sud',
    },
    {
        id = 'piazza_stazione', nome = 'Piazza della stazione',
        coord = vector3(-233.0, -1018.0, 30.1), raggio = 25.0,
        vedetta = { coord = vector3(-216.0, -1005.0, 30.1), raggio = 6.0 },
        territorio = 'centro_st',
    },
}

DRO.Vedetta = {
    -- Quanto la piazza rende in più quando qualcuno fa il palo
    moltiplicatorePrezzo = 1.25,
    -- Quanto scende il rischio di finire davanti a un agente sotto copertura
    riduzioneRischio = 0.5,
    -- Raggio entro cui la vedetta vede arrivare le forze dell'ordine
    raggioAvvistamento = 120.0,
    -- Quota del ricavato che spetta alla vedetta
    quota = 0.20,
    -- Ogni quanto si ricontrolla che sia ancora al suo posto
    intervalloControllo = 8000,
}

-- ---------------------------------------------------------------------------
--  Consumo e overdose
-- ---------------------------------------------------------------------------
DRO.Consumo = {
    -- Effetti sullo stato del personaggio, per sostanza
    effetti = {
        erba    = { stato = { fame = -8, sete = -12 }, durata = 90000,  filtro = 'DrugsDrivingIn' },
        hashish = { stato = { fame = -10, sete = -14 }, durata = 100000, filtro = 'DrugsDrivingIn' },
        cocaina = { stato = { fame = -20, sete = -18 }, durata = 70000,  filtro = 'DrugsMichaelAliensFightIn' },
        mdma    = { stato = { fame = -18, sete = -25 }, durata = 110000, filtro = 'DrugsTrevorClownsFightIn' },
        eroina  = { stato = { fame = -14, sete = -14 }, durata = 130000, filtro = 'Drugs_Trails_Amb' },
    },
    -- Sopra la purezza letale della sostanza si rischia l'arresto respiratorio
    probabilitaOverdoseBase = 55,
    -- Ogni punto oltre la soglia alza il rischio
    probabilitaPerPunto = 4,
    -- L'overdose porta all'incoscienza: senza soccorso si muore
    secondiPrimaDelDecesso = 180,
}

-- ---------------------------------------------------------------------------
--  Narcotest — l'analisi speditiva delle forze dell'ordine
-- ---------------------------------------------------------------------------
DRO.Narcotest = {
    item = 'narcotest',
    durata = 8000,
    lavori = { 'carabinieri', 'polizia', 'guardia_finanza' },
    -- Il reattivo consuma il kit e una minima parte del campione
    consumaCampione = false,
}

-- ---------------------------------------------------------------------------
--  Regole penali
-- ---------------------------------------------------------------------------
DRO.Regole = {
    -- Sotto questa quantità E sotto la soglia grave della sostanza, il fatto
    -- si contesta come lieve entità (art. 73 comma 5).
    sogliaUsoPersonale = 5,
    -- La morte del consumatore come conseguenza dello spaccio
    reatoMorteConseguente = '586',
    reatoColtivazione = 'dpr73',
    reatoAssociazione = 'dpr74',
    -- Quanti spacciatori distinti sulla stessa piazza fanno scattare il 74
    affiliatiPerAssociazione = 3,
}

-- ---------------------------------------------------------------------------
--  Utilità condivise
-- ---------------------------------------------------------------------------

--- Purezza normalizzata di una riga d'inventario.
function DRO.Purezza(metadata)
    local p = metadata and tonumber(metadata.purezza)
    if not p then return DRO.Sostanze.erba.purezzaTipica end
    return math.max(0, math.min(100, math.floor(p)))
end

--- Prezzo di una dose, data la sostanza e la purezza.
function DRO.PrezzoDose(idSostanza, purezza)
    local s = DRO.Sostanze[idSostanza]
    if not s then return 0 end
    local fattore = (math.max(0, math.min(100, purezza)) / 100) ^ DRO.Spaccio.esponentePurezza
    return math.floor(s.prezzoPuro * fattore)
end

--- Come si chiama, in gergo di strada, una certa purezza.
function DRO.GiudizioPurezza(idSostanza, purezza)
    local s = DRO.Sostanze[idSostanza]
    if not s then return 'sconosciuta' end
    if purezza >= s.purezzaLetale then return 'pericolosamente pura' end
    if purezza >= s.purezzaTipica + 15 then return 'roba ottima' end
    if purezza >= s.purezzaTipica - 10 then return 'nella media' end
    if purezza >= s.purezzaMinima then return 'molto tagliata' end
    return 'invendibile'
end

function DRO.PiazzaVicina(coord)
    for _, p in ipairs(DRO.Piazze) do
        if #(coord - p.coord) < p.raggio then return p end
    end
    return nil
end

function DRO.LaboratorioVicino(coord)
    for _, l in ipairs(DRO.Laboratori) do
        if #(coord - l.coord) < l.raggio then return l end
    end
    return nil
end

function DRO.AlChiuso(coord)
    for _, z in ipairs(DRO.Coltivazione.zoneAlChiuso) do
        if #(coord - z.coord) < z.raggio then return true end
    end
    return false
end
