--[[
    AUREA · Trasporto pubblico — configurazione

    Due cose insieme: un lavoro (guidare la linea, fermata per fermata,
    con la gente che sale davvero) e un servizio (chi non ha l'auto si
    muove comprando il biglietto).

    E il biglietto va obliterato: chi non lo fa rischia il controllore.
]]

TRA = {}

TRA.Lavoro = 'autista'

TRA.Deposito = {
    nome = 'Deposito ATM',
    coord = vector3(462.0, -600.0, 28.5),
    mezzi = { vector4(454.0, -594.0, 28.4, 180.0), vector4(449.0, -594.0, 28.4, 180.0) },
    modello = 'bus',
    blip = { sprite = 513, colore = 5, scala = 0.75 },
}

--- Le linee. Ogni fermata è un punto dove il bus si ferma e la gente sale.
TRA.Linee = {
    {
        id = 'linea1', nome = 'Linea 1 — Centro/Porto', pagaFermata = 5200,
        fermate = {
            { nome = 'Capolinea Centro',   coord = vector3(437.0, -645.0, 28.6) },
            { nome = 'Stazione',           coord = vector3(-260.0, -1010.0, 30.2) },
            { nome = 'Ospedale',           coord = vector3(310.0, -580.0, 43.3) },
            { nome = 'Lungomare',          coord = vector3(-1230.0, -1450.0, 4.4) },
            { nome = 'Porto',              coord = vector3(1150.0, -1490.0, 34.7) },
            { nome = 'Capolinea Centro',   coord = vector3(437.0, -645.0, 28.6) },
        },
    },
    {
        id = 'linea2', nome = 'Linea 2 — Periferia', pagaFermata = 6400,
        fermate = {
            { nome = 'Capolinea Sud',      coord = vector3(120.0, -1960.0, 20.8) },
            { nome = 'Zona industriale',   coord = vector3(720.0, -960.0, 25.0) },
            { nome = 'Aeroporto',          coord = vector3(-1040.0, -2730.0, 20.2) },
            { nome = 'Vespucci',           coord = vector3(-1180.0, -1500.0, 4.4) },
            { nome = 'Capolinea Sud',      coord = vector3(120.0, -1960.0, 20.8) },
        },
    },
    {
        id = 'extraurbana', nome = 'Extraurbana — Paese nord', pagaFermata = 11000,
        fermate = {
            { nome = 'Capolinea Centro',   coord = vector3(437.0, -645.0, 28.6) },
            { nome = 'Sandy Shores',       coord = vector3(1690.0, 3580.0, 35.6) },
            { nome = 'Paleto',             coord = vector3(-380.0, 6070.0, 31.5) },
            { nome = 'Capolinea Centro',   coord = vector3(437.0, -645.0, 28.6) },
        },
    },
}

TRA.Servizio = {
    distanzaFermata = 12.0,
    -- Il bus deve stare fermo perché la gente salga
    secondiFermata = 6,
    velocitaMassimaFermata = 3.0,
    -- Bonus se sul bus ci sono passeggeri veri
    bonusPasseggero = 0.25,
}

-- ---------------------------------------------------------------------------
--  Biglietteria
-- ---------------------------------------------------------------------------
TRA.Biglietti = {
    corsa = { nome = 'Biglietto di corsa semplice', prezzo = 1500, validitaMinuti = 90 },
    giornaliero = { nome = 'Biglietto giornaliero', prezzo = 5000, validitaMinuti = 1440 },
    abbonamento = { nome = 'Abbonamento mensile', prezzo = 35000, validitaMinuti = 43200 },
    item = 'biglietto',
}

TRA.Controllo = {
    -- Chi può fare il controllore
    lavori = { 'autista' },
    -- Sanzione per chi viaggia senza titolo obliterato
    sanzione = 5400,
    articolo = 'art. 24 legge regionale — mancata obliterazione',
    quotaControllore = 0.10,
}

function TRA.GetLinea(id)
    for _, l in ipairs(TRA.Linee) do
        if l.id == id then return l end
    end
    return nil
end

function TRA.FermataVicina(coord)
    for _, l in ipairs(TRA.Linee) do
        for _, f in ipairs(l.fermate) do
            if #(coord - f.coord) < TRA.Servizio.distanzaFermata then return f, l end
        end
    end
    return nil
end
