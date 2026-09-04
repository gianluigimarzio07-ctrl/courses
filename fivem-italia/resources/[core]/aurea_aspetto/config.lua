--[[
    AUREA · Aspetto — configurazione

    Tre luoghi distinti, come nella realtà: il negozio vende vestiti, il
    barbiere taglia capelli e barba, il tatuatore fa i tatuaggi. Nessuno dei
    tre ti lascia rifare la faccia: quella si sceglie una volta sola alla
    creazione del personaggio, e cambiarla costa parecchio in chirurgia.
]]

ASP = {}

-- ---------------------------------------------------------------------------
--  Componenti dell'abbigliamento
--  L'id è quello nativo di GTA, l'etichetta è per l'interfaccia.
-- ---------------------------------------------------------------------------
ASP.Componenti = {
    { id = 1,  chiave = 'maschera',    nome = 'Maschera',        negozio = 'abbigliamento' },
    { id = 3,  chiave = 'braccia',     nome = 'Braccia',         negozio = 'abbigliamento' },
    { id = 4,  chiave = 'pantaloni',   nome = 'Pantaloni',       negozio = 'abbigliamento' },
    { id = 5,  chiave = 'borsa',       nome = 'Borsa',           negozio = 'abbigliamento' },
    { id = 6,  chiave = 'scarpe',      nome = 'Scarpe',          negozio = 'abbigliamento' },
    { id = 7,  chiave = 'collana',     nome = 'Collana',         negozio = 'abbigliamento' },
    { id = 8,  chiave = 'maglietta',   nome = 'Sottomaglia',     negozio = 'abbigliamento' },
    { id = 9,  chiave = 'giubbotto',   nome = 'Giubbotto',       negozio = 'abbigliamento' },
    { id = 10, chiave = 'stampa',      nome = 'Stampa',          negozio = 'abbigliamento' },
    { id = 11, chiave = 'giacca',      nome = 'Giacca',          negozio = 'abbigliamento' },
}

ASP.Accessori = {
    { id = 0, chiave = 'cappello',   nome = 'Cappello',   negozio = 'abbigliamento' },
    { id = 1, chiave = 'occhiali',   nome = 'Occhiali',   negozio = 'abbigliamento' },
    { id = 2, chiave = 'orecchini',  nome = 'Orecchini',  negozio = 'abbigliamento' },
    { id = 6, chiave = 'orologio',   nome = 'Orologio',   negozio = 'abbigliamento' },
    { id = 7, chiave = 'bracciale',  nome = 'Bracciale',  negozio = 'abbigliamento' },
}

-- ---------------------------------------------------------------------------
--  Tratti somatici: i 20 slider del volto
-- ---------------------------------------------------------------------------
ASP.Tratti = {
    [0]  = 'Larghezza del naso',
    [1]  = 'Altezza della punta del naso',
    [2]  = 'Lunghezza del naso',
    [3]  = 'Profilo del naso',
    [4]  = 'Punta del naso',
    [5]  = 'Inclinazione del naso',
    [6]  = 'Altezza delle sopracciglia',
    [7]  = 'Profondità delle sopracciglia',
    [8]  = 'Altezza degli zigomi',
    [9]  = 'Larghezza degli zigomi',
    [10] = 'Guance',
    [11] = 'Apertura degli occhi',
    [12] = 'Spessore delle labbra',
    [13] = 'Larghezza della mandibola',
    [14] = 'Forma della mandibola',
    [15] = 'Altezza del mento',
    [16] = 'Profondità del mento',
    [17] = 'Fossetta del mento',
    [18] = 'Larghezza del collo',
    [19] = 'Corporatura',
}

-- ---------------------------------------------------------------------------
--  Sovrapposizioni del volto (peluria, trucco, imperfezioni)
--  colore: 0 nessuno, 1 capelli, 2 trucco/labbra
-- ---------------------------------------------------------------------------
ASP.Sovrapposizioni = {
    { id = 1,  chiave = 'barba',        nome = 'Barba',              colore = 1, sede = 'barbiere' },
    { id = 2,  chiave = 'sopracciglia', nome = 'Sopracciglia',       colore = 1, sede = 'barbiere' },
    { id = 10, chiave = 'petto',        nome = 'Peluria sul petto',  colore = 1, sede = 'barbiere' },
    { id = 0,  chiave = 'imperfezioni', nome = 'Imperfezioni',       colore = 0, sede = 'creazione' },
    { id = 3,  chiave = 'invecchiamento', nome = 'Segni del tempo',  colore = 0, sede = 'creazione' },
    { id = 6,  chiave = 'carnagione',   nome = 'Carnagione',         colore = 0, sede = 'creazione' },
    { id = 7,  chiave = 'sole',         nome = 'Esposizione al sole',colore = 0, sede = 'creazione' },
    { id = 9,  chiave = 'lentiggini',   nome = 'Lentiggini',         colore = 0, sede = 'creazione' },
    { id = 11, chiave = 'segni_corpo',  nome = 'Segni sul corpo',    colore = 0, sede = 'creazione' },
    { id = 4,  chiave = 'trucco',       nome = 'Trucco',             colore = 2, sede = 'barbiere' },
    { id = 5,  chiave = 'fard',         nome = 'Fard',               colore = 2, sede = 'barbiere' },
    { id = 8,  chiave = 'rossetto',     nome = 'Rossetto',           colore = 2, sede = 'barbiere' },
}

-- ---------------------------------------------------------------------------
--  Zone dei tatuaggi
-- ---------------------------------------------------------------------------
ASP.ZoneTatuaggi = {
    { chiave = 'ZONE_TORSO',      nome = 'Torso' },
    { chiave = 'ZONE_HEAD',       nome = 'Testa e collo' },
    { chiave = 'ZONE_LEFT_ARM',   nome = 'Braccio sinistro' },
    { chiave = 'ZONE_RIGHT_ARM',  nome = 'Braccio destro' },
    { chiave = 'ZONE_LEFT_LEG',   nome = 'Gamba sinistra' },
    { chiave = 'ZONE_RIGHT_LEG',  nome = 'Gamba destra' },
    { chiave = 'ZONE_TORSO_BACK', nome = 'Schiena' },
}

-- ---------------------------------------------------------------------------
--  Luoghi
-- ---------------------------------------------------------------------------
ASP.Negozi = {
    { nome = 'Abbigliamento Vespucci',  coord = vector3(72.3, -1399.1, 29.4),   tipo = 'abbigliamento' },
    { nome = 'Abbigliamento Del Perro', coord = vector3(-1193.4, -772.3, 17.3), tipo = 'abbigliamento' },
    { nome = 'Abbigliamento Centro',    coord = vector3(127.0, -223.5, 54.6),   tipo = 'abbigliamento' },
    { nome = 'Abbigliamento Paleto',    coord = vector3(-822.3, -1073.8, 11.3), tipo = 'abbigliamento' },
    { nome = 'Sartoria Rockford',       coord = vector3(-703.8, -152.2, 37.4),  tipo = 'abbigliamento', lusso = true },
}

ASP.Barbieri = {
    { nome = 'Barbiere Hawick',   coord = vector3(-278.1, 6228.5, 31.7) },
    { nome = 'Barbiere Vespucci', coord = vector3(-1282.6, -1116.8, 7.0) },
    { nome = 'Barbiere Centro',   coord = vector3(136.8, -1708.4, 29.3) },
    { nome = 'Barbiere Rockford', coord = vector3(-32.9, -152.3, 57.1) },
}

ASP.Tatuatori = {
    { nome = 'Tatuatore Vespucci', coord = vector3(-1153.6, -1425.6, 4.9) },
    { nome = 'Tatuatore Downtown', coord = vector3(322.1, 180.4, 103.6) },
    { nome = 'Tatuatore Paleto',   coord = vector3(-193.1, 6321.5, 31.5) },
}

--- Chirurgia estetica: l'unico posto dove si rifà il volto
ASP.Chirurgia = {
    nome = 'Chirurgia Estetica',
    coord = vector3(311.5, -571.4, 43.3),
    costo = 2500000,     -- 25.000 €
}

--- L'armadio di casa, dove si salvano e si richiamano i completi
ASP.Armadio = {
    completiMassimi = 12,
}

-- ---------------------------------------------------------------------------
--  Prezzi
-- ---------------------------------------------------------------------------
ASP.Prezzi = {
    -- Per capo cambiato in negozio
    capo = 3500,
    capoLusso = 22000,
    accessorio = 2800,
    accessorioLusso = 15000,
    -- Barbiere
    taglioCapelli = 2500,
    barba = 1500,
    trucco = 2000,
    -- Tatuatore, per tatuaggio
    tatuaggio = 18000,
    rimozioneTatuaggio = 35000,
    -- Cambio completo dall'armadio: gratis
    armadio = 0,
}

-- ---------------------------------------------------------------------------
--  Divise di servizio: assegnate dal lavoro, non acquistabili
-- ---------------------------------------------------------------------------
ASP.Divise = {
    carabinieri = {
        nome = 'Uniforme Carabinieri',
        M = { [11] = { 55, 0 }, [8] = { 58, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [3] = { 11, 0 } },
        F = { [11] = { 48, 0 }, [8] = { 35, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [3] = { 14, 0 } },
    },
    polizia = {
        nome = 'Uniforme Polizia di Stato',
        M = { [11] = { 55, 1 }, [8] = { 58, 0 }, [4] = { 35, 1 }, [6] = { 25, 0 }, [3] = { 11, 0 } },
        F = { [11] = { 48, 1 }, [8] = { 35, 0 }, [4] = { 34, 1 }, [6] = { 25, 0 }, [3] = { 14, 0 } },
    },
    guardia_finanza = {
        nome = 'Uniforme Guardia di Finanza',
        M = { [11] = { 55, 2 }, [8] = { 58, 0 }, [4] = { 35, 2 }, [6] = { 25, 0 }, [3] = { 11, 0 } },
        F = { [11] = { 48, 2 }, [8] = { 35, 0 }, [4] = { 34, 2 }, [6] = { 25, 0 }, [3] = { 14, 0 } },
    },
    ['118'] = {
        nome = 'Divisa 118',
        M = { [11] = { 250, 0 }, [8] = { 129, 0 }, [4] = { 96, 0 }, [6] = { 25, 0 }, [3] = { 85, 0 } },
        F = { [11] = { 258, 0 }, [8] = { 159, 0 }, [4] = { 99, 0 }, [6] = { 25, 0 }, [3] = { 109, 0 } },
    },
    vigili_fuoco = {
        nome = 'Divisa Vigili del Fuoco',
        M = { [11] = { 250, 1 }, [8] = { 129, 0 }, [4] = { 96, 1 }, [6] = { 25, 0 }, [3] = { 85, 0 } },
        F = { [11] = { 258, 1 }, [8] = { 159, 0 }, [4] = { 99, 1 }, [6] = { 25, 0 }, [3] = { 109, 0 } },
    },
    meccanico = {
        nome = 'Tuta da officina',
        M = { [11] = { 58, 0 }, [8] = { 59, 0 }, [4] = { 43, 0 }, [6] = { 24, 0 }, [3] = { 66, 0 } },
        F = { [11] = { 63, 0 }, [8] = { 36, 0 }, [4] = { 44, 0 }, [6] = { 24, 0 }, [3] = { 74, 0 } },
    },
    ristoratore = {
        nome = 'Divisa da sala',
        M = { [11] = { 31, 0 }, [8] = { 15, 0 }, [4] = { 10, 0 }, [6] = { 10, 0 }, [3] = { 1, 0 } },
        F = { [11] = { 36, 0 }, [8] = { 14, 0 }, [4] = { 11, 0 }, [6] = { 9, 0 }, [3] = { 5, 0 } },
    },
}

--- Componente massimo interrogabile per un modello: evita indici fuori scala.
function ASP.MassimoComponente(ped, componente)
    return GetNumberOfPedDrawableVariations(ped, componente) - 1
end

function ASP.MassimoTexture(ped, componente, drawable)
    return GetNumberOfPedTextureVariations(ped, componente, drawable) - 1
end
