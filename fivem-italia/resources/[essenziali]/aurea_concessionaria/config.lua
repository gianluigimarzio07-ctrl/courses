--[[
    AUREA · Concessionaria — configurazione

    Comprare un'auto qui non è scegliere da un listino: è una pratica.
    Si prova il mezzo, si firma, si paga il passaggio di proprietà e si
    immatricola. E il mercato dell'usato è vero — le auto usate le mettono
    in vendita i giocatori, con il loro chilometraggio e i loro acciacchi.
]]

CON = {}

CON.Sedi = {
    {
        id = 'premium', nome = 'Concessionaria Premium',
        coord = vector3(-56.7, -1096.6, 26.4),
        consegna = vector4(-46.3, -1093.0, 26.4, 68.0),
        prova = vector4(-32.0, -1101.0, 26.4, 250.0),
        categorie = { 'utilitaria', 'berlina', 'suv', 'sportiva' },
        blip = { sprite = 326, colore = 3, scala = 0.85 },
    },
    {
        id = 'moto', nome = 'Concessionaria moto',
        coord = vector3(287.6, -1148.0, 29.3),
        consegna = vector4(279.0, -1152.0, 29.2, 90.0),
        prova = vector4(273.0, -1140.0, 29.3, 180.0),
        categorie = { 'moto' },
        blip = { sprite = 226, colore = 3, scala = 0.75 },
    },
    {
        id = 'commerciali', nome = 'Veicoli commerciali',
        coord = vector3(1224.0, 2727.0, 38.0),
        consegna = vector4(1216.0, 2733.0, 38.0, 0.0),
        prova = vector4(1230.0, 2718.0, 38.0, 180.0),
        categorie = { 'furgone', 'camion' },
        blip = { sprite = 477, colore = 3, scala = 0.75 },
    },
}

-- ---------------------------------------------------------------------------
--  Listino
--
--  I prezzi sono in centesimi e sono IVA esclusa: l'IVA si somma alla
--  cassa, come su una fattura vera, e finisce all'erario.
-- ---------------------------------------------------------------------------
CON.Listino = {
    -- Utilitarie
    { modello = 'blista',    nome = 'Compatta',            categoria = 'utilitaria', prezzo = 1250000,  kw = 66 },
    { modello = 'panto',     nome = 'Citycar',             categoria = 'utilitaria', prezzo = 980000,   kw = 51 },
    { modello = 'issi2',     nome = 'Utilitaria sportiva', categoria = 'utilitaria', prezzo = 1680000,  kw = 74 },
    { modello = 'prairie',   nome = 'Utilitaria diesel',   categoria = 'utilitaria', prezzo = 1420000,  kw = 70 },

    -- Berline
    { modello = 'asea',      nome = 'Berlina economica',   categoria = 'berlina', prezzo = 1750000,  kw = 85 },
    { modello = 'primo2',    nome = 'Berlina media',       categoria = 'berlina', prezzo = 2350000,  kw = 103 },
    { modello = 'schafter2', nome = 'Berlina di classe',   categoria = 'berlina', prezzo = 4900000,  kw = 180 },
    { modello = 'tailgater', nome = 'Berlina sportiva',    categoria = 'berlina', prezzo = 5600000,  kw = 195 },

    -- SUV
    { modello = 'baller',    nome = 'SUV urbano',          categoria = 'suv', prezzo = 6200000,  kw = 210 },
    { modello = 'landstalker', nome = 'SUV familiare',     categoria = 'suv', prezzo = 4300000,  kw = 165 },
    { modello = 'huntley',   nome = 'SUV di lusso',        categoria = 'suv', prezzo = 8900000,  kw = 250 },

    -- Sportive
    { modello = 'sultan',    nome = 'Sportiva compatta',   categoria = 'sportiva', prezzo = 7400000,  kw = 235 },
    { modello = 'jester',    nome = 'Coupé sportiva',      categoria = 'sportiva', prezzo = 12500000, kw = 290 },
    { modello = 'comet2',    nome = 'Sportiva da pista',   categoria = 'sportiva', prezzo = 16800000, kw = 331 },
    { modello = 'italigto',  nome = 'Granturismo',         categoria = 'sportiva', prezzo = 34000000, kw = 449 },

    -- Moto
    { modello = 'faggio2',   nome = 'Scooter 125',         categoria = 'moto', prezzo = 320000,   kw = 8 },
    { modello = 'bati',      nome = 'Sportiva 1000',       categoria = 'moto', prezzo = 2400000,  kw = 147 },
    { modello = 'nemesis',   nome = 'Naked media',         categoria = 'moto', prezzo = 890000,   kw = 55 },
    { modello = 'sanchez',   nome = 'Enduro',              categoria = 'moto', prezzo = 640000,   kw = 30 },

    -- Commerciali
    { modello = 'burrito3',  nome = 'Furgone da lavoro',   categoria = 'furgone', prezzo = 2100000,  kw = 96 },
    { modello = 'rumpo',     nome = 'Furgone refrigerato', categoria = 'furgone', prezzo = 2650000,  kw = 110 },
    { modello = 'pounder',   nome = 'Motrice',             categoria = 'camion', prezzo = 7800000,  kw = 290 },
    { modello = 'phantom',   nome = 'Trattore stradale',   categoria = 'camion', prezzo = 11200000, kw = 353 },
}

CON.Categorie = {
    utilitaria = { nome = 'Utilitarie',  icona = '🚗' },
    berlina    = { nome = 'Berline',     icona = '🚙' },
    suv        = { nome = 'SUV',         icona = '🚐' },
    sportiva   = { nome = 'Sportive',    icona = '🏎' },
    moto       = { nome = 'Moto',        icona = '🏍' },
    furgone    = { nome = 'Furgoni',     icona = '🚚' },
    camion     = { nome = 'Camion',      icona = '🚛' },
}

-- ---------------------------------------------------------------------------
--  Oneri di acquisto
-- ---------------------------------------------------------------------------
CON.Oneri = {
    -- IPT (imposta provinciale di trascrizione) sul passaggio di proprietà
    ipt = 15100,
    -- Emolumenti ACI e diritti di motorizzazione
    diritti = 5800,
    -- Messa su strada
    messaStrada = 45000,
    -- Il bollo del primo anno lo paga il concessionario
    bolloIncluso = true,
}

-- ---------------------------------------------------------------------------
--  Prova su strada
-- ---------------------------------------------------------------------------
CON.Prova = {
    durata = 180,               -- secondi
    -- Non si esce dal perimetro concordato
    raggio = 700.0,
    -- Cauzione trattenuta durante la prova, restituita al rientro
    cauzione = 250000,
    -- Se il mezzo torna ammaccato, la cauzione non torna tutta
    sogliaDanni = 0.15,
}

-- ---------------------------------------------------------------------------
--  Usato fra privati
-- ---------------------------------------------------------------------------
CON.Usato = {
    -- Dove si conclude la compravendita fra privati
    sedeAtto = vector3(-56.7, -1096.6, 26.4),
    -- Quanto trattiene lo Stato sul passaggio fra privati
    ipt = 15100,
    diritti = 5800,
    -- I due devono essere vicini
    distanza = 5.0,
    -- Il prezzo lo fanno loro, ma non si regala nulla per aggirare le tasse
    prezzoMinimo = 50000,
}

function CON.SedeVicina(coord, raggio)
    for _, s in ipairs(CON.Sedi) do
        if #(coord - s.coord) < (raggio or 3.0) then return s end
    end
    return nil
end

function CON.GetVeicolo(modello)
    for _, v in ipairs(CON.Listino) do
        if v.modello == modello then return v end
    end
    return nil
end

--- Totale da pagare: prezzo, IVA e oneri.
function CON.Totale(prezzo, aliquotaIva)
    local iva = math.floor(prezzo * ((aliquotaIva or 22) / 100))
    local oneri = CON.Oneri.ipt + CON.Oneri.diritti + CON.Oneri.messaStrada
    return prezzo + iva + oneri, iva, oneri
end
