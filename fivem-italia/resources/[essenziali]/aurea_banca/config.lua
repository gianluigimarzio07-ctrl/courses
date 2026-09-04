--[[
    AUREA · Banca — configurazione
]]

BANCA = {}

BANCA.Filiali = {
    { nome = 'Filiale Centro',      coord = vector3(149.9, -1040.5, 29.4) },
    { nome = 'Filiale Rockford',    coord = vector3(-1212.9, -330.8, 37.8) },
    { nome = 'Filiale Vespucci',    coord = vector3(-2962.5, 482.2, 15.7) },
    { nome = 'Filiale Paleto',      coord = vector3(-112.2, 6469.9, 31.6) },
    { nome = 'Filiale Sandy Shores',coord = vector3(1175.0, 2706.6, 38.1) },
}

BANCA.Sportelli = {
    vector3(147.4, -1035.5, 29.3), vector3(-1205.0, -324.8, 37.8),
    vector3(-2955.6, 488.9, 15.7), vector3(-104.9, 6477.2, 31.6),
    vector3(1172.5, 2702.6, 38.1), vector3(-386.2, 6046.4, 31.5),
    vector3(288.1, 143.5, 104.2),  vector3(-1315.6, -834.6, 16.9),
    vector3(24.1, -946.1, 29.4),   vector3(-56.9, -1752.4, 29.4),
    vector3(1687.6, 4815.8, 42.0), vector3(-660.8, -853.4, 24.5),
}

BANCA.Commissioni = {
    -- Prelievo allo sportello automatico oltre una soglia
    prelievoGratuitoFinoA = 50000,      -- 500,00 €
    prelievoPercentuale   = 0.015,
    -- Bonifico verso un altro intestatario
    bonifico              = 150,        -- 1,50 €
    bonificoIstantaneo    = 500,        -- 5,00 €
    -- Massimale per operazione
    massimaleOperazione   = 5000000,    -- 50.000 €
    -- Oltre questa soglia scatta la segnalazione antiriciclaggio
    sogliaAntiriciclaggio = 1000000,    -- 10.000 €
}

BANCA.Mutui = {
    -- Tasso base annuo, poi maggiorato in base al merito creditizio
    tassoBase = 4.50,
    -- Numero massimo di rate
    rateMassime = 24,
    -- Ogni rata viene addebitata ogni N minuti reali
    minutiPerRata = 45,
    -- Rapporto massimo fra rata e reddito stimato
    incidenzaMassima = 0.35,
    -- Dopo quante rate insolute scatta il pignoramento
    rateInsoluteMassime = 3,
    -- Importo massimo finanziabile
    importoMassimo = 50000000,   -- 500.000 €
}

--- Merito creditizio semplificato: 1 (ottimo) .. 5 (pessimo)
--- Determina la maggiorazione sul tasso.
BANCA.Merito = {
    [1] = { etichetta = 'Ottimo',      maggiorazione = 0.00 },
    [2] = { etichetta = 'Buono',       maggiorazione = 0.75 },
    [3] = { etichetta = 'Sufficiente', maggiorazione = 1.80 },
    [4] = { etichetta = 'Scarso',      maggiorazione = 3.50 },
    [5] = { etichetta = 'Compromesso', maggiorazione = 7.00 },
}
