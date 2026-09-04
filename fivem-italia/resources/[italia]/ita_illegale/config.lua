--[[
    AUREA · Attività illecite — configurazione

    Il criterio che tiene insieme il modulo: l'illecito rende, ma lascia
    tracce. Ogni passaggio alza il calore dell'organizzazione, produce odore
    o rumore che i vicini segnalano al 112, e il denaro che ne esce non è
    spendibile finché non passa da una lavanderia.

    Non esiste il "premi E e guadagna": ogni filiera ha una catena, e la
    catena si può spezzare in più punti.
]]

ILL = {}

-- ---------------------------------------------------------------------------
--  COLTIVAZIONE
--  Le piante crescono col tempo reale e vanno curate, altrimenti muoiono.
-- ---------------------------------------------------------------------------
ILL.Coltivazione = {
    -- Un seme diventa pianta matura in questo tempo
    minutiCrescita = 55,
    -- Senza acqua entro questo tempo la pianta appassisce
    minutiSenzaCura = 25,
    -- Piante contemporanee per personaggio
    massimoPiante = 12,
    -- Resa alla raccolta
    resaMinima = 2, resaMassima = 5,
    -- Ogni pianta emette odore: più piante insieme, più è probabile la segnalazione
    probabilitaSegnalazionePerPianta = 3,
    -- Ogni quanto si valuta la segnalazione
    minutiControlloOdore = 12,
    -- Calore generato
    calorePiantagione = 4,

    seme = 'seme',
    grezzo = 'sostanza_grezza',
    attrezzo = 'annaffiatoio',

    --- Le serre al chiuso non emettono odore verso l'esterno
    zoneAlChiuso = {
        { nome = 'Magazzino portuale', coord = vector3(1009.7, -3195.0, -38.9), raggio = 40.0 },
    },
}

-- ---------------------------------------------------------------------------
--  RAFFINAZIONE
--  Serve un laboratorio: fisso, quindi individuabile.
-- ---------------------------------------------------------------------------
ILL.Laboratori = {
    { id = 'lab_porto',   nome = 'Laboratorio del porto',   coord = vector3(1198.0, -3255.0, -39.0), raggio = 22.0 },
    { id = 'lab_deserto', nome = 'Laboratorio nel deserto', coord = vector3(1391.0, 3608.0, 38.9),   raggio = 25.0 },
    { id = 'lab_collina', nome = 'Laboratorio in collina',  coord = vector3(-1150.0, 4940.0, 222.0), raggio = 25.0 },
}

ILL.Raffinazione = {
    durata = 22000,
    -- Quanto grezzo serve per una dose raffinata
    grezzoPerDose = 3,
    -- Il processo può andare storto
    probabilitaFallimento = 12,
    -- Un fallimento può provocare un principio di incendio
    probabilitaIncendio = 25,
    calore = 6,
    raffinata = 'sostanza_raffinata',
}

-- ---------------------------------------------------------------------------
--  SPACCIO
--  Si vende agli NPC, ma ogni cessione può essere vista.
-- ---------------------------------------------------------------------------
ILL.Spaccio = {
    -- Prezzo per dose, oscilla con la piazza
    prezzoBase = 18000,
    -- Il prezzo sale nelle zone controllate dalla tua organizzazione
    bonusTerritorio = 1.35,
    -- Il prezzo scende dove c'è troppa offerta
    penalitaSaturazione = 0.6,
    -- Cessioni prima che la piazza si saturi
    cessioniPrimaSaturazione = 6,
    minutiRecuperoPiazza = 25,
    -- Distanza massima dal cliente
    distanza = 2.5,
    durata = 6000,
    -- Probabilità che il cliente rifiuti
    probabilitaRifiuto = 30,
    -- Probabilità che il cliente sia un agente sotto copertura
    probabilitaAgente = 6,
    -- Probabilità che un passante chiami il 112
    probabilitaSegnalazione = 14,
    calore = 3,
    -- I proventi sono contanti non tracciati
    provento = 'contanti_sporchi',
}

-- ---------------------------------------------------------------------------
--  SMONTAGGIO VEICOLI
-- ---------------------------------------------------------------------------
ILL.Smontaggio = {
    nome = 'Autodemolizione clandestina',
    coord = vector3(1522.0, -2135.0, 77.5),
    raggio = 30.0,
    durata = 35000,
    -- Un veicolo intestato a qualcuno rende di più ma lascia la traccia
    valoreBase = 450000,
    -- Pezzi recuperati
    pezzi = {
        { item = 'acciaio', min = 3, max = 8 },
        { item = 'rame', min = 2, max = 5 },
        { item = 'componenti_elettronici', min = 1, max = 4 },
        { item = 'plastica', min = 2, max = 6 },
    },
    -- Il proprietario si accorge del furto
    avvisaProprietario = true,
    calore = 10,
    -- Veicoli smontabili in un'ora, per non svuotare la città
    limiteOrario = 4,
}

-- ---------------------------------------------------------------------------
--  MERCATO NERO
-- ---------------------------------------------------------------------------
ILL.MercatoNero = {
    nome = 'Mercato nero',
    -- Cambia posizione a ogni riavvio fra questi punti
    posizioni = {
        vector3(-1155.0, -2033.0, 13.2),
        vector3(482.0, -1310.0, 29.2),
        vector3(1387.0, 3606.0, 34.9),
    },
    catalogo = {
        { item = 'grimaldello',      prezzo = 145000 },
        { item = 'jammer',           prezzo = 980000 },
        { item = 'gps_tracker',      prezzo = 220000 },
        { item = 'documento_falso',  prezzo = 640000 },
        { item = 'targa_clonata',    prezzo = 380000 },
        { item = 'seme',             prezzo = 42000 },
        { item = 'annaffiatoio',     prezzo = 28000 },
        { item = 'cartuccia',        prezzo = 2200 },
    },
    -- Vendita di armi clandestine
    armi = {
        { arma = 'WEAPON_SNSPISTOL',      prezzo = 850000 },
        { arma = 'WEAPON_MICROSMG',       prezzo = 2400000 },
        { arma = 'WEAPON_SAWNOFFSHOTGUN', prezzo = 1600000 },
        { arma = 'WEAPON_MACHETE',        prezzo = 90000 },
        { arma = 'WEAPON_KNIFE',          prezzo = 45000 },
    },
    -- Si paga solo in contanti non tracciati
    soloContantiSporchi = true,
}

-- ---------------------------------------------------------------------------
--  Regole comuni
-- ---------------------------------------------------------------------------
ILL.Regole = {
    -- Reati contestati
    reatoColtivazione = 'dpr73',
    reatoSpaccio = 'dpr73l',
    reatoSpaccioGrave = 'dpr73',
    reatoRicettazione = '648b',
    reatoFurtoVeicolo = '624',
    -- Oltre questa quantità addosso si presume lo spaccio, non l'uso personale
    sogliaUsoPersonale = 5,
}

function ILL.LaboratorioVicino(coord)
    for _, l in ipairs(ILL.Laboratori) do
        if #(coord - l.coord) < l.raggio then return l end
    end
    return nil
end

function ILL.AlChiuso(coord)
    for _, z in ipairs(ILL.Coltivazione.zoneAlChiuso) do
        if #(coord - z.coord) < z.raggio then return true end
    end
    return false
end
