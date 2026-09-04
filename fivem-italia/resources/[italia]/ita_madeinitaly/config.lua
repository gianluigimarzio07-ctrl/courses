--[[
    AUREA · Made in Italy — configurazione

    La differenza rispetto a un normale crafting: qui la QUALITÀ non è binaria.
    Ogni passaggio produce un lotto con un punteggio da 0 a 100 che dipende
    dalla maestria dell'artigiano, dalla qualità delle materie prime e dal
    rispetto dei tempi. Solo un lotto di qualità alta può ottenere la
    certificazione, e la certificazione moltiplica il valore fino a tre volte.
]]

MIT = {}

-- ---------------------------------------------------------------------------
--  Maestria: si accumula lavorando, sblocca prodotti e alza la qualità
-- ---------------------------------------------------------------------------
MIT.Maestria = {
    -- XP necessari per raggiungere ciascun livello
    soglie = { 0, 120, 320, 700, 1400, 2600, 4500, 7200, 11000, 16000 },
    titoli = {
        'Apprendista', 'Garzone', 'Artigiano', 'Artigiano esperto', 'Maestro',
        'Maestro provetto', 'Mastro', 'Gran Mastro', 'Eccellenza', 'Patrimonio',
    },
    -- Ogni livello aggiunge questo alla qualità base
    bonusQualitaPerLivello = 4,
}

-- ---------------------------------------------------------------------------
--  Certificazioni: soglie di qualità e moltiplicatori di prezzo
-- ---------------------------------------------------------------------------
MIT.Certificazioni = {
    { id = 'nessuna', etichetta = 'Nessuna certificazione', soglia = 0,  moltiplicatore = 1.00, costo = 0 },
    { id = 'IGP',     etichetta = 'IGP',  soglia = 60, moltiplicatore = 1.40, costo = 25000 },
    { id = 'BIO',     etichetta = 'BIO',  soglia = 65, moltiplicatore = 1.50, costo = 32000 },
    { id = 'DOP',     etichetta = 'DOP',  soglia = 78, moltiplicatore = 1.90, costo = 68000 },
    { id = 'DOCG',    etichetta = 'DOCG', soglia = 88, moltiplicatore = 2.20, costo = 120000, soloFiliera = 'vino' },
}

-- ---------------------------------------------------------------------------
--  FILIERE
--
--  Ogni filiera è una catena di lavorazioni: la resa di una alimenta la
--  successiva, e la qualità si trasmette (con perdita se si sbaglia).
-- ---------------------------------------------------------------------------
MIT.Filiere = {

    -- ========================= VINO =========================
    vino = {
        etichetta = 'Filiera vitivinicola',
        icona = '🍇',
        disciplina = 'enologia',
        postazioni = {
            {
                id = 'vigna', nome = 'Vigneto',
                coord = vector3(-1887.4, 2065.0, 138.9),
                azione = 'Vendemmia',
                durata = 12000,
                anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
                produce = { { item = 'uva_sangiovese', min = 3, max = 6 }, { item = 'uva_nebbiolo', min = 1, max = 3 } },
                xp = 12,
                -- La vendemmia rende di più nella stagione giusta
                stagioneOttimale = { 9, 10 },
            },
            {
                id = 'pigiatura', nome = 'Cantina — pigiatura',
                coord = vector3(-1889.0, 2050.5, 140.9),
                azione = 'Pigiatura',
                durata = 15000,
                richiede = { { item = 'uva_sangiovese', quantita = 4 } },
                produce = { { item = 'mosto', min = 2, max = 3 } },
                xp = 18,
            },
            {
                id = 'fermentazione', nome = 'Cantina — botti',
                coord = vector3(-1893.2, 2045.7, 140.9),
                azione = 'Messa in botte',
                durata = 20000,
                richiede = { { item = 'mosto', quantita = 3 } },
                produce = { { item = 'vino_rosso', min = 2, max = 3 } },
                xp = 26,
                -- Affinamento: il lotto va lasciato riposare prima di ritirarlo
                affinamentoMinuti = 25,
                affinamentoBonus = 22,
                -- Con qualità alta e affinamento completo diventa DOCG
                sbloccaSuperiore = { item = 'vino_docg', qualitaMinima = 82 },
            },
        },
    },

    -- ========================= OLIO =========================
    olio = {
        etichetta = 'Filiera olearia',
        icona = '🫒',
        disciplina = 'olivicoltura',
        postazioni = {
            {
                id = 'oliveto', nome = 'Oliveto',
                coord = vector3(2214.0, 5150.0, 60.4),
                azione = 'Raccolta delle olive',
                durata = 13000,
                anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
                produce = { { item = 'olive', min = 4, max = 8 } },
                xp = 12,
                stagioneOttimale = { 10, 11 },
            },
            {
                id = 'frantoio', nome = 'Frantoio',
                coord = vector3(2205.6, 5141.2, 60.5),
                azione = 'Molitura a freddo',
                durata = 18000,
                richiede = { { item = 'olive', quantita = 6 } },
                produce = { { item = 'olio_extravergine', min = 1, max = 2 } },
                xp = 24,
                -- La molitura entro poche ore dalla raccolta alza l'acidità: qui
                -- si premia chi lavora olive fresche
                premiaFreschezza = true,
                sbloccaSuperiore = { item = 'olio_dop', qualitaMinima = 80 },
            },
        },
    },

    -- ========================= FORMAGGIO =========================
    formaggio = {
        etichetta = 'Filiera casearia',
        icona = '🧀',
        disciplina = 'caseificazione',
        postazioni = {
            {
                id = 'stalla', nome = 'Stalla',
                coord = vector3(2432.0, 4966.0, 46.8),
                azione = 'Mungitura',
                durata = 11000,
                produce = { { item = 'latte_crudo', min = 4, max = 7 } },
                xp = 10,
            },
            {
                id = 'caseificio', nome = 'Caseificio',
                coord = vector3(2440.5, 4972.4, 46.8),
                azione = 'Cagliata',
                durata = 16000,
                richiede = { { item = 'latte_crudo', quantita = 5 }, { item = 'caglio', quantita = 1 } },
                produce = { { item = 'formaggio_fresco', min = 2, max = 3 } },
                xp = 22,
            },
            {
                id = 'stagionatura', nome = 'Cella di stagionatura',
                coord = vector3(2446.0, 4968.9, 46.8),
                azione = 'Messa a stagionare',
                durata = 10000,
                richiede = { { item = 'formaggio_fresco', quantita = 3 } },
                produce = { { item = 'parmigiano_dop', min = 1, max = 1 } },
                xp = 34,
                affinamentoMinuti = 40,
                affinamentoBonus = 30,
            },
        },
    },

    -- ========================= CAFFÈ =========================
    caffe = {
        etichetta = 'Torrefazione',
        icona = '☕',
        disciplina = 'torrefazione',
        postazioni = {
            {
                id = 'torrefazione', nome = 'Torrefazione',
                coord = vector3(-1198.0, -1476.5, 4.4),
                azione = 'Tostatura',
                durata = 14000,
                richiede = { { item = 'caffe_verde', quantita = 3 } },
                produce = { { item = 'caffe_tostato', min = 2, max = 3 } },
                xp = 20,
                -- La tostatura è delicata: sbagliare i tempi rovina il lotto
                finestraPrecisione = true,
            },
            {
                id = 'macinatura', nome = 'Banco espresso',
                coord = vector3(-1204.5, -1471.0, 4.4),
                azione = 'Estrazione espresso',
                durata = 6000,
                richiede = { { item = 'caffe_tostato', quantita = 1 } },
                produce = { { item = 'espresso', min = 4, max = 7 } },
                xp = 8,
            },
        },
    },

    -- ========================= PIZZA =========================
    pizza = {
        etichetta = 'Pizzeria',
        icona = '🍕',
        disciplina = 'panificazione',
        postazioni = {
            {
                id = 'impasto', nome = 'Banco impasto',
                coord = vector3(-1224.9, -900.3, 12.3),
                azione = 'Impasto e staglio',
                durata = 15000,
                richiede = { { item = 'farina_00', quantita = 2 } },
                produce = { { item = 'impasto_pizza', min = 3, max = 5 } },
                xp = 14,
                affinamentoMinuti = 15,
                affinamentoBonus = 25,
            },
            {
                id = 'forno', nome = 'Forno a legna',
                coord = vector3(-1229.5, -895.7, 12.3),
                azione = 'Cottura',
                durata = 9000,
                richiede = {
                    { item = 'impasto_pizza', quantita = 1 },
                    { item = 'pomodoro_san_marzano', quantita = 1 },
                    { item = 'mozzarella_bufala', quantita = 1 },
                },
                produce = { { item = 'pizza_margherita', min = 1, max = 2 } },
                xp = 16,
                finestraPrecisione = true,
            },
        },
    },

    -- ========================= SARTORIA =========================
    moda = {
        etichetta = 'Sartoria',
        icona = '👔',
        disciplina = 'sartoria',
        postazioni = {
            {
                id = 'atelier', nome = 'Atelier',
                coord = vector3(-1338.0, -1278.0, 4.9),
                azione = 'Confezione su misura',
                durata = 30000,
                richiede = { { item = 'tessuto_pregiato', quantita = 3 } },
                produce = { { item = 'capo_sartoriale', min = 1, max = 1 } },
                xp = 40,
                livelloMinimo = 3,
            },
        },
    },
}

-- ---------------------------------------------------------------------------
--  Consorzio di tutela: dove si chiede la certificazione
-- ---------------------------------------------------------------------------
MIT.Consorzio = {
    nome = 'Consorzio di Tutela',
    coord = vector3(-1329.0, -527.5, 30.4),
    blip = { sprite = 496, colore = 5, scala = 0.8 },
}

-- ---------------------------------------------------------------------------
--  Helper
-- ---------------------------------------------------------------------------

function MIT.Livello(xp)
    local livello = 1
    for n, soglia in ipairs(MIT.Maestria.soglie) do
        if xp >= soglia then livello = n end
    end
    return livello
end

function MIT.Titolo(livello)
    return MIT.Maestria.titoli[math.min(livello, #MIT.Maestria.titoli)] or 'Apprendista'
end

function MIT.ProssimaSoglia(xp)
    for _, soglia in ipairs(MIT.Maestria.soglie) do
        if xp < soglia then return soglia end
    end
    return nil
end

function MIT.GetPostazione(filiera, idPostazione)
    local f = MIT.Filiere[filiera]
    if not f then return nil end
    for _, p in ipairs(f.postazioni) do
        if p.id == idPostazione then return p, f end
    end
    return nil
end

--- Certificazione più alta ottenibile per un lotto.
function MIT.CertificazionePer(qualita, filiera)
    local migliore = MIT.Certificazioni[1]
    for _, c in ipairs(MIT.Certificazioni) do
        if qualita >= c.soglia and (not c.soloFiliera or c.soloFiliera == filiera) then
            if c.moltiplicatore > migliore.moltiplicatore then migliore = c end
        end
    end
    return migliore
end

function MIT.GetCertificazione(id)
    for _, c in ipairs(MIT.Certificazioni) do
        if c.id == id then return c end
    end
    return MIT.Certificazioni[1]
end
