--[[
    AUREA · Lavori — configurazione
]]

LAV = {}

--- Centro per l'Impiego: da qui si accede ai lavori civili senza selezione
LAV.CentroImpiego = {
    nome = 'Centro per l\'Impiego',
    coord = vector3(-268.8, -956.4, 31.2),
    blip = { sprite = 407, colore = 2, scala = 0.8 },
    -- Lavori assegnabili senza colloquio
    liberi = { 'corriere', 'tassista', 'meccanico', 'ristoratore', 'giornalista' },
    -- Sussidio di disoccupazione: erogato dall'erario a chi non ha lavoro
    sussidio = { importo = 3500, minuti = 30 },
}

--- Punti di inizio turno per lavoro
LAV.PuntiTurno = {
    corriere    = { coord = vector3(45.4, -1749.2, 29.6), nome = 'Deposito corrieri', veicolo = 'burrito3', spawn = vector4(52.2, -1741.6, 29.6, 320.0) },
    tassista    = { coord = vector3(903.2, -170.4, 74.1), nome = 'Rimessa taxi',      veicolo = 'taxi',     spawn = vector4(910.9, -178.5, 74.1, 235.0) },
    meccanico   = { coord = vector3(-337.3, -136.6, 39.0), nome = 'Officina',          veicolo = 'towtruck', spawn = vector4(-345.1, -125.9, 38.7, 70.0) },
    ristoratore = { coord = vector3(-1222.9, -907.0, 12.3), nome = 'Ristorante' },
    giornalista = { coord = vector3(-598.5, -929.5, 23.9), nome = 'Redazione' },
}

--- Missioni di consegna per il corriere
LAV.Consegne = {
    { nome = 'Farmacia Comunale',  coord = vector3(310.4, -595.1, 43.3),   compenso = 4500 },
    { nome = 'Alimentari Vespucci',coord = vector3(25.7, -1347.3, 29.5),   compenso = 5200 },
    { nome = 'Bar Centrale',       coord = vector3(-561.2, 286.0, 82.2),   compenso = 6800 },
    { nome = 'Ferramenta Cypress', coord = vector3(2748.0, 3472.9, 55.7),  compenso = 12500 },
    { nome = 'Alimentari Paleto',  coord = vector3(-3242.2, 1000.4, 12.8), compenso = 16500 },
    { nome = 'Alimentari Sandy',   coord = vector3(1961.5, 3740.7, 32.3),  compenso = 13800 },
    { nome = 'Elettronica Centro', coord = vector3(-655.3, -854.6, 24.5),  compenso = 5900 },
    { nome = 'Officina Innocence', coord = vector3(-337.3, -136.6, 39.0),  compenso = 5400 },
    { nome = 'Deposito Portuale',  coord = vector3(1204.0, -3115.0, 5.5),  compenso = 9200 },
    { nome = 'Mercato Generale',   coord = vector3(-1080.2, -1250.9, 5.6), compenso = 6100 },
}

--- Fermate del taxi: partenze e destinazioni
LAV.Fermate = {
    { nome = 'Stazione Centrale',   coord = vector3(-215.0, -1023.0, 30.1) },
    { nome = 'Aeroporto',           coord = vector3(-1037.0, -2737.6, 20.2) },
    { nome = 'Ospedale Centrale',   coord = vector3(305.4, -595.0, 43.3) },
    { nome = 'Legion Square',       coord = vector3(215.3, -810.4, 30.8) },
    { nome = 'Del Perro Pier',      coord = vector3(-1850.0, -1230.0, 13.0) },
    { nome = 'Vinewood Boulevard',  coord = vector3(283.4, 175.9, 104.2) },
    { nome = 'Rockford Plaza',      coord = vector3(-1290.0, -560.0, 30.0) },
    { nome = 'Porto',               coord = vector3(1204.0, -3115.0, 5.5) },
    { nome = 'Sandy Shores',        coord = vector3(1961.5, 3740.7, 32.3) },
    { nome = 'Paleto Bay',          coord = vector3(-247.5, 6331.2, 32.4) },
}

LAV.Regole = {
    -- Bonus al compenso se la consegna avviene entro il tempo previsto
    bonusPuntualita = 0.35,
    -- Secondi concessi per ogni 100 metri di percorso
    secondiPer100m = 22,
    -- Penale se il veicolo di servizio viene danneggiato
    penaleDanni = 0.4,
    -- Compenso base per corsa taxi, poi al km
    taxiScatto = 3500,
    taxiAlKm = 1400,
    -- Riparazione in officina
    costoRiparazione = 42000,
    duratsRiparazione = 15000,
}

function LAV.PuntoTurno(lavoro) return LAV.PuntiTurno[lavoro] end
