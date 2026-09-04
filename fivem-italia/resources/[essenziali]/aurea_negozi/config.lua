--[[
    AUREA · Negozi — configurazione

    I prezzi indicati sono LORDI (IVA inclusa, come sugli scaffali italiani).
    Lo scorporo dell'imposta avviene alla cassa e l'IVA va all'erario.
]]

NEG = {}

NEG.Tipi = {
    alimentari = {
        nome = 'Alimentari',
        blip = { sprite = 52, colore = 2, scala = 0.6 },
        catalogo = {
            { item = 'acqua', prezzo = 80 },
            { item = 'acqua_frizzante', prezzo = 90 },
            { item = 'panino', prezzo = 350 },
            { item = 'cornetto', prezzo = 150 },
            { item = 'pizza_margherita', prezzo = 750 },
            { item = 'pasta_carbonara', prezzo = 1100 },
            { item = 'mozzarella_bufala', prezzo = 980 },
            { item = 'olio_extravergine', prezzo = 1900 },
            { item = 'farina_00', prezzo = 130 },
            { item = 'pomodoro_san_marzano', prezzo = 220 },
            { item = 'biglietto_lotteria', prezzo = 500 },
        },
    },
    bar = {
        nome = 'Bar',
        blip = { sprite = 93, colore = 21, scala = 0.6 },
        catalogo = {
            { item = 'espresso', prezzo = 110 },
            { item = 'cappuccino', prezzo = 160 },
            { item = 'cornetto', prezzo = 130 },
            { item = 'acqua', prezzo = 100 },
            { item = 'spritz', prezzo = 600 },
            { item = 'birra', prezzo = 500 },
            { item = 'amaro', prezzo = 450 },
            { item = 'vino_rosso', prezzo = 1450 },
            { item = 'panino', prezzo = 400 },
        },
    },
    farmacia = {
        nome = 'Farmacia',
        blip = { sprite = 51, colore = 25, scala = 0.6 },
        catalogo = {
            { item = 'bendaggio', prezzo = 850 },
            { item = 'antidolorifico', prezzo = 620 },
            { item = 'stecca', prezzo = 2200 },
            { item = 'acqua', prezzo = 120 },
        },
    },
    ferramenta = {
        nome = 'Ferramenta',
        blip = { sprite = 402, colore = 46, scala = 0.6 },
        catalogo = {
            { item = 'kit_riparazione', prezzo = 12500 },
            { item = 'tanica', prezzo = 4800 },
            { item = 'cavi_avviamento', prezzo = 3200 },
            { item = 'corda', prezzo = 1800 },
            { item = 'chiave_inglese', prezzo = 2400 },
            { item = 'borsone', prezzo = 8900 },
            { item = 'valigetta', prezzo = 6400 },
            { item = 'powerbank', prezzo = 2900 },
        },
    },
    elettronica = {
        nome = 'Elettronica',
        blip = { sprite = 606, colore = 3, scala = 0.6 },
        catalogo = {
            { item = 'telefono', prezzo = 34900 },
            { item = 'laptop', prezzo = 89000 },
            { item = 'radio', prezzo = 12000 },
            { item = 'powerbank', prezzo = 2900 },
            { item = 'gps_tracker', prezzo = 18000, licenza = 'forze_ordine' },
        },
    },
    mercato = {
        nome = 'Mercato Generale',
        blip = { sprite = 496, colore = 47, scala = 0.7 },
        -- Il mercato compra E vende ai prezzi dinamici del modulo economia
        dinamico = true,
        acquista = {
            'uva_sangiovese', 'uva_nebbiolo', 'olive', 'latte_crudo', 'caffe_verde',
            'mosto', 'vino_rosso', 'vino_docg', 'olio_extravergine', 'olio_dop',
            'formaggio_fresco', 'parmigiano_dop', 'caffe_tostato', 'mozzarella_bufala',
            'pomodoro_san_marzano', 'capo_sartoriale', 'tessuto_pregiato',
            'rame', 'acciaio', 'componenti_elettronici',
        },
        vende = {
            'caglio', 'farina_00', 'tessuto_pregiato', 'caffe_verde', 'plastica', 'vetro',
        },
    },
}

--- Punti vendita sulla mappa
NEG.PuntiVendita = {
    { tipo = 'alimentari', nome = 'Alimentari Vespucci',   coord = vector3(25.7, -1347.3, 29.5) },
    { tipo = 'alimentari', nome = 'Alimentari Grove',      coord = vector3(-47.4, -1758.5, 29.4) },
    { tipo = 'alimentari', nome = 'Alimentari Sandy',      coord = vector3(1961.5, 3740.7, 32.3) },
    { tipo = 'alimentari', nome = 'Alimentari Paleto',     coord = vector3(-3242.2, 1000.4, 12.8) },
    { tipo = 'alimentari', nome = 'Alimentari Mirror Park',coord = vector3(1163.4, -323.8, 69.2) },
    { tipo = 'alimentari', nome = 'Alimentari Little Seoul',coord = vector3(-707.5, -914.4, 19.2) },
    { tipo = 'alimentari', nome = 'Alimentari Del Perro',  coord = vector3(-1487.6, -379.1, 40.2) },

    { tipo = 'bar', nome = 'Bar Centrale',      coord = vector3(-561.2, 286.0, 82.2) },
    { tipo = 'bar', nome = 'Bar del Porto',     coord = vector3(1207.0, -3115.6, 5.5) },
    { tipo = 'bar', nome = 'Bar Vinewood',      coord = vector3(129.1, -1284.1, 29.3) },
    { tipo = 'bar', nome = 'Caffè Rockford',    coord = vector3(-1393.4, -606.5, 30.3) },

    { tipo = 'farmacia', nome = 'Farmacia Comunale', coord = vector3(310.4, -595.1, 43.3) },
    { tipo = 'farmacia', nome = 'Farmacia Paleto',   coord = vector3(-247.5, 6331.2, 32.4) },

    { tipo = 'ferramenta', nome = 'Ferramenta Cypress', coord = vector3(2748.0, 3472.9, 55.7) },
    { tipo = 'ferramenta', nome = 'Ferramenta Centro',  coord = vector3(45.4, -1749.2, 29.6) },

    { tipo = 'elettronica', nome = 'Elettronica Centro', coord = vector3(-655.3, -854.6, 24.5) },

    { tipo = 'mercato', nome = 'Mercato Generale', coord = vector3(-1080.2, -1250.9, 5.6) },
}

--- Ricarico applicato dai negozi sul prezzo di mercato (per i beni dinamici)
NEG.Ricarico = 1.35
--- Sconto applicato dal mercato quando acquista dai produttori
NEG.ScontoAcquisto = 0.85

function NEG.GetTipo(id) return NEG.Tipi[id] end
