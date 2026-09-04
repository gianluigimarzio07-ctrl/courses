--[[
    AUREA · Attività di raccolta — configurazione

    Quello che distingue queste attività da un semplice "premi E e ricevi
    l'oggetto" è che in Italia sono regolate. Per pescare serve la licenza,
    per cacciare servono licenza e tesserino, ci sono stagioni di chiusura,
    taglie minime e specie protette. Chi non rispetta le regole rischia il
    verbale della Guardia Costiera o della vigilanza venatoria.
]]

ATT = {}

-- ---------------------------------------------------------------------------
--  Licenze
-- ---------------------------------------------------------------------------
ATT.Licenze = {
    pesca = {
        etichetta = 'Licenza di pesca dilettantistica tipo B',
        rilasciata = 'Regione',
        costo = 3000, validitaGiorni = 365,
        sanzione = 25800, articolo = 'art. 40 L.R. pesca',
    },
    caccia = {
        etichetta = 'Licenza di caccia',
        rilasciata = 'Provincia',
        costo = 17300, validitaGiorni = 365,
        sanzione = 51600, articolo = 'art. 30 L. 157/92',
        -- Serve anche il porto d'armi per uso venatorio
        richiedePortoArmi = 'caccia',
    },
    raccolta = {
        etichetta = 'Tesserino per la raccolta di funghi e tartufi',
        rilasciata = 'Comune',
        costo = 2500, validitaGiorni = 365,
        sanzione = 12900, articolo = 'art. 17 L. 752/85',
    },
}

-- ---------------------------------------------------------------------------
--  PESCA
--  taglia minima in centimetri; sotto quella il pesce va rigettato
-- ---------------------------------------------------------------------------
ATT.Pesca = {
    durata = 14000,
    -- Serve una canna
    attrezzo = 'canna_pesca',
    -- Esche: migliorano la resa
    esche = { esca_semplice = 1.0, esca_pregiata = 1.6 },

    specie = {
        { item = 'orata',        nome = 'Orata',        taglia = 20, peso = 5,  rarita = 22, zona = 'mare' },
        { item = 'branzino',     nome = 'Branzino',     taglia = 25, peso = 4,  rarita = 18, zona = 'mare' },
        { item = 'sgombro',      nome = 'Sgombro',      taglia = 18, peso = 15, rarita = 30, zona = 'mare' },
        { item = 'tonno',        nome = 'Tonno',        taglia = 115, peso = 1, rarita = 3,  zona = 'mare', pregiato = true },
        { item = 'polpo',        nome = 'Polpo',        taglia = 0,  peso = 8,  rarita = 12, zona = 'mare' },
        { item = 'trota',        nome = 'Trota',        taglia = 22, peso = 10, rarita = 25, zona = 'lago' },
        { item = 'luccio',       nome = 'Luccio',       taglia = 45, peso = 3,  rarita = 8,  zona = 'lago', pregiato = true },
        { item = 'carpa',        nome = 'Carpa',        taglia = 30, peso = 6,  rarita = 20, zona = 'lago' },
    },

    --- Specie in divieto di cattura: prenderle è illecito anche con licenza
    protette = {
        { item = 'dattero',      nome = 'Dattero di mare', rarita = 4, sanzione = 200000,
          nota = 'La raccolta dei datteri di mare è vietata: distrugge la scogliera.' },
    },

    zone = {
        { nome = 'Costa di Vespucci', coord = vector3(-1850.0, -1250.0, 8.0), raggio = 260.0, zona = 'mare' },
        { nome = 'Molo di Paleto',    coord = vector3(-275.0, 6635.0, 7.5),   raggio = 180.0, zona = 'mare' },
        { nome = 'Porto',             coord = vector3(1300.0, -2900.0, 8.0),  raggio = 200.0, zona = 'mare' },
        { nome = 'Lago Alamo',        coord = vector3(1300.0, 4200.0, 30.0),  raggio = 300.0, zona = 'lago' },
        { nome = 'Fiume Zancudo',     coord = vector3(-1600.0, 2700.0, 6.0),  raggio = 220.0, zona = 'lago' },
    },

    --- Dove si vende il pescato
    mercatoIttico = { nome = 'Mercato ittico', coord = vector3(1207.0, -3110.0, 5.5) },
}

-- ---------------------------------------------------------------------------
--  CACCIA
--  Il calendario venatorio decide che cosa si può prendere e quando.
-- ---------------------------------------------------------------------------
ATT.Caccia = {
    durata = 6000,
    -- Fuori da questi mesi la caccia è chiusa del tutto
    stagioneDa = 9,    -- settembre
    stagioneA = 1,     -- gennaio
    -- Orari consentiti (ora di gioco)
    oraDa = 6, oraA = 19,

    specie = {
        { item = 'carne_cinghiale', nome = 'Cinghiale', modello = 'a_c_boar',   rarita = 30, valore = 2800 },
        { item = 'carne_cervo',     nome = 'Cervo',     modello = 'a_c_deer',   rarita = 22, valore = 4200 },
        { item = 'carne_lepre',     nome = 'Lepre',     modello = 'a_c_rabbit_01', rarita = 40, valore = 1400 },
    },

    --- Specie protette: abbatterle è reato, non semplice illecito
    protette = {
        { modello = 'a_c_coyote',   nome = 'Lupo',    reato = '544', sanzione = 300000 },
        { modello = 'a_c_mtlion',   nome = 'Lince',   reato = '544', sanzione = 400000 },
        { modello = 'a_c_westy',    nome = 'Cane',    reato = '544', sanzione = 150000 },
    },

    zone = {
        { nome = 'Riserva di Chiliad',   coord = vector3(-700.0, 5300.0, 100.0), raggio = 500.0 },
        { nome = 'Boschi di Paleto',     coord = vector3(-1100.0, 4600.0, 220.0), raggio = 450.0 },
        { nome = 'Riserva di Grapeseed', coord = vector3(2400.0, 4900.0, 40.0),  raggio = 400.0 },
    },

    --- Capi abbattibili per giornata di gioco
    capiGiornalieri = 8,
}

-- ---------------------------------------------------------------------------
--  CAVA E RACCOLTA
-- ---------------------------------------------------------------------------
ATT.Cava = {
    nome = 'Cava di Davis',
    coord = vector3(2954.0, 2790.0, 41.0), raggio = 220.0,
    durata = 11000,
    attrezzo = 'piccone',
    resa = {
        { item = 'pietra',   rarita = 45 },
        { item = 'rame',     rarita = 25 },
        { item = 'acciaio',  rarita = 20 },
        { item = 'quarzo',   rarita = 8 },
        { item = 'oro_grezzo', rarita = 2, pregiato = true },
    },
    -- Dove si conferisce il materiale grezzo
    conferimento = { nome = 'Impianto di lavorazione', coord = vector3(2947.0, 2748.0, 43.5) },
}

ATT.Raccolta = {
    durata = 5000,
    zone = {
        { nome = 'Boschi di Chiliad', coord = vector3(-500.0, 5200.0, 90.0), raggio = 400.0,
          resa = { { item = 'porcini', rarita = 35 }, { item = 'tartufo_nero', rarita = 8 },
                   { item = 'tartufo_bianco', rarita = 2, pregiato = true },
                   { item = 'castagne', rarita = 45 } } },
        { nome = 'Colline di Paleto', coord = vector3(-1400.0, 4500.0, 40.0), raggio = 350.0,
          resa = { { item = 'porcini', rarita = 40 }, { item = 'castagne', rarita = 50 },
                   { item = 'erbe_officinali', rarita = 20 } } },
    },
    -- La raccolta è limitata per giornata: non si spoglia il bosco
    limiteGiornaliero = 30,
}

-- ---------------------------------------------------------------------------
--  Sportello licenze
-- ---------------------------------------------------------------------------
ATT.Sportello = {
    nome = 'Sportello Licenze',
    coord = vector3(-544.2, -204.4, 38.2),
}

-- ---------------------------------------------------------------------------
--  Helper
-- ---------------------------------------------------------------------------

--- Estrae una specie in base alla rarità.
function ATT.Estrai(elenco)
    local totale = 0
    for _, s in ipairs(elenco) do totale = totale + s.rarita end
    if totale <= 0 then return nil end

    local estratto = math.random(totale)
    local somma = 0
    for _, s in ipairs(elenco) do
        somma = somma + s.rarita
        if estratto <= somma then return s end
    end
    return elenco[1]
end

--- La stagione venatoria attraversa il capodanno.
function ATT.CacciaAperta(mese)
    if ATT.Caccia.stagioneDa <= ATT.Caccia.stagioneA then
        return mese >= ATT.Caccia.stagioneDa and mese <= ATT.Caccia.stagioneA
    end
    return mese >= ATT.Caccia.stagioneDa or mese <= ATT.Caccia.stagioneA
end

function ATT.ZonaPesca(coord)
    for _, z in ipairs(ATT.Pesca.zone) do
        if #(coord - z.coord) < z.raggio then return z end
    end
    return nil
end

function ATT.ZonaCaccia(coord)
    for _, z in ipairs(ATT.Caccia.zone) do
        if #(coord - z.coord) < z.raggio then return z end
    end
    return nil
end

function ATT.ZonaRaccolta(coord)
    for _, z in ipairs(ATT.Raccolta.zone) do
        if #(coord - z.coord) < z.raggio then return z end
    end
    return nil
end
