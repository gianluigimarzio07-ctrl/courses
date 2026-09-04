--[[
    AUREA · Giustizia — configurazione
]]

GIU = {}

GIU.Carcere = {
    nome = 'Casa Circondariale',
    ingresso = vector3(1690.0, 2565.0, 45.6),
    -- Punti di vita in cella
    celle = {
        vector4(1762.0, 2568.9, 45.7, 90.0),
        vector4(1762.0, 2564.5, 45.7, 90.0),
        vector4(1762.0, 2560.1, 45.7, 90.0),
        vector4(1780.2, 2568.9, 45.7, 270.0),
        vector4(1780.2, 2564.5, 45.7, 270.0),
    },
    cortile = vector3(1770.0, 2545.0, 45.7),
    -- Punto di rilascio a fine pena
    rilascio = vector4(1846.0, 2585.8, 45.7, 275.0),
    -- Area entro cui il detenuto deve restare
    perimetro = { centro = vector3(1770.0, 2560.0, 45.7), raggio = 130.0 },
    blip = { sprite = 188, colore = 40, scala = 0.8 },
}

GIU.Tribunale = {
    nome = 'Tribunale',
    coord = vector3(242.6, -1071.5, 29.3),
    blip = { sprite = 419, colore = 5, scala = 0.8 },
    -- Sconto di pena per il patteggiamento
    scontoPatteggiamento = 0.33,
    -- Costo del patrocinio legale
    onorarioAvvocato = 85000,
}

GIU.Centrali = {
    { nome = 'Comando Carabinieri', coord = vector3(441.2, -981.5, 30.7), lavoro = 'carabinieri' },
    { nome = 'Questura',            coord = vector3(-1093.0, -809.1, 19.3), lavoro = 'polizia' },
}

GIU.Regole = {
    -- Minuti di detenzione per punto di gravità del reato
    minutiPerGravita = 12,
    -- Riduzione di pena per buona condotta (lavori socialmente utili)
    riduzionePerLavoro = 4,      -- minuti scontati per attività completata
    duratsAttivita = 45000,      -- ms per una attività in carcere
    -- Massimo di minuti scontabili con il lavoro rispetto alla pena
    massimoRiduzione = 0.4,
    -- Cauzione: si esce pagando, se la gravità lo consente
    cauzioneMassimaGravita = 3,
    cauzionePerMinuto = 4500,
    -- Un'evasione aggiunge questa pena e impedisce ulteriori cauzioni
    penaEvasione = 60,
    -- Durata del fermo per identificazione prima della convalida
    minutiFermo = 15,
    -- Il casellario si "pulisce" dopo questo tempo per i reati lievi
    prescrizioneMinuti = { [1] = 240, [2] = 600, [3] = 1440, [4] = 4320, [5] = 0 },
}

--- Attività trattamentali disponibili in carcere
GIU.Attivita = {
    { id = 'lavanderia', nome = 'Lavanderia',   coord = vector3(1779.6, 2570.5, 45.8), sconto = 4 },
    { id = 'officina',   nome = 'Officina',     coord = vector3(1774.0, 2551.0, 45.8), sconto = 5 },
    { id = 'orto',       nome = 'Orto interno', coord = vector3(1755.0, 2543.0, 45.8), sconto = 4 },
    { id = 'biblioteca', nome = 'Biblioteca',   coord = vector3(1785.0, 2557.0, 45.8), sconto = 3 },
}

function GIU.CellaCasuale()
    return GIU.Carcere.celle[math.random(#GIU.Carcere.celle)]
end
