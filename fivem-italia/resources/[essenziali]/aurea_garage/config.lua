--[[
    AUREA · Garage — configurazione
]]

GAR = {}

--- Ogni garage ha un punto di accesso, uno o più punti di uscita del veicolo
--- e le categorie ammesse.
GAR.Garage = {
    {
        id = 'centrale', nome = 'Autorimessa Centrale',
        accesso = vector3(215.9, -808.1, 30.7),
        uscite = { vector4(228.5, -800.6, 30.6, 250.0), vector4(232.1, -805.9, 30.6, 250.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'sportiva', 'furgone' },
        blip = true, costoGiornaliero = 1500,
    },
    {
        id = 'rockford', nome = 'Autorimessa Rockford',
        accesso = vector3(-1180.5, -735.9, 19.9),
        uscite = { vector4(-1186.1, -742.2, 19.4, 35.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'sportiva' },
        blip = true, costoGiornaliero = 2800,
    },
    {
        id = 'vespucci', nome = 'Autorimessa Vespucci',
        accesso = vector3(-1191.5, -1189.9, 6.6),
        uscite = { vector4(-1199.6, -1197.3, 6.4, 125.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'sportiva', 'moto' },
        blip = true, costoGiornaliero = 1800,
    },
    {
        id = 'paleto', nome = 'Autorimessa Paleto Bay',
        accesso = vector3(107.5, 6614.0, 31.8),
        uscite = { vector4(114.6, 6620.5, 31.4, 315.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'furgone', 'moto' },
        blip = true, costoGiornaliero = 900,
    },
    {
        id = 'sandy', nome = 'Autorimessa Sandy Shores',
        accesso = vector3(1737.5, 3710.5, 34.1),
        uscite = { vector4(1729.2, 3714.0, 34.1, 200.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'furgone', 'camion', 'moto' },
        blip = true, costoGiornaliero = 900,
    },
    {
        id = 'porto', nome = 'Deposito Portuale',
        accesso = vector3(1204.0, -3115.0, 5.5),
        uscite = { vector4(1213.5, -3120.6, 5.5, 90.0), vector4(1213.5, -3128.0, 5.5, 90.0) },
        categorie = { 'furgone', 'camion' },
        blip = true, costoGiornaliero = 2200,
    },
    {
        id = 'depositeria', nome = 'Depositeria Giudiziaria',
        accesso = vector3(409.0, -1622.9, 29.3),
        uscite = { vector4(400.6, -1631.4, 29.3, 230.0) },
        categorie = { 'auto', 'utilitaria', 'berlina', 'suv', 'sportiva', 'moto', 'furgone', 'camion' },
        blip = false, soloDissequestro = true,
    },
}

--- Distributori di carburante
GAR.Distributori = {
    vector3(265.7, -1261.3, 29.3), vector3(49.4, 2778.8, 58.0), vector3(263.9, 2606.5, 44.9),
    vector3(1039.9, 2671.1, 39.6), vector3(1207.3, 2660.2, 37.9), vector3(2539.7, 2594.2, 37.9),
    vector3(2679.8, 3263.9, 55.2), vector3(2005.1, 3773.9, 32.4), vector3(1687.2, 4929.4, 42.1),
    vector3(1701.3, 6416.0, 32.8), vector3(179.9, 6602.8, 31.9), vector3(-94.5, 6419.6, 31.5),
    vector3(-2555.0, 2334.1, 33.1), vector3(-1800.4, 803.6, 138.7), vector3(-1437.7, -276.8, 46.2),
    vector3(-2096.2, -320.3, 13.2), vector3(-724.6, -935.1, 19.2), vector3(-526.0, -1211.0, 18.2),
    vector3(-70.2, -1761.8, 29.5), vector3(265.0, -1261.3, 29.3), vector3(819.6, -1028.8, 26.4),
    vector3(1208.9, -1402.5, 35.2), vector3(1181.4, -330.8, 69.3), vector3(620.8, 269.1, 103.1),
    vector3(2581.3, 362.0, 108.5), vector3(176.6, -1562.1, 29.3), vector3(-319.3, -1471.7, 30.5),
}

GAR.Carburante = {
    prezzoLitro = 189,          -- 1,89 € al litro
    prezzoLitroPremium = 215,   -- 2,15 €
    capienzaMedia = 60,         -- litri
    -- Consumo: percentuale di serbatoio per minuto a velocità di crociera
    consumoBase = 0.55,
    -- Il consumo scala con classe del veicolo e stile di guida
    moltiplicatoriClasse = {
        [0] = 0.8,  [1] = 0.9,  [2] = 1.3, [3] = 1.0, [4] = 1.1,
        [5] = 1.5,  [6] = 1.4,  [7] = 1.7, [8] = 0.5, [9] = 1.4,
        [10] = 2.0, [11] = 1.2, [12] = 1.8, [13] = 0.0, [14] = 1.6,
        [15] = 2.2, [16] = 2.4, [17] = 1.2, [18] = 1.3, [19] = 1.5,
        [20] = 2.1,
    },
}

GAR.Usura = {
    -- Km percorsi ogni minuto a velocità media, per l'odometro
    kmPerMinuto = 1.2,
    -- Il motore si degrada con l'uso: punti di salute persi ogni 100 km
    degradoMotorePer100km = 8,
}

function GAR.GetGarage(id)
    for _, g in ipairs(GAR.Garage) do
        if g.id == id then return g end
    end
    return nil
end
