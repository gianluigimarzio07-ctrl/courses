--[[
    AUREA · Armi — configurazione

    In Italia un'arma è un oggetto tracciato. Ha una matricola, è iscritta a
    un registro, e chi la porta deve avere un titolo che glielo consenta.
    Un'arma senza matricola è di per sé un reato, e il possesso di un'arma
    regolare senza porto d'armi è un altro reato ancora.
]]

ARM = {}

-- ---------------------------------------------------------------------------
--  Titoli di porto d'armi
-- ---------------------------------------------------------------------------
ARM.Titoli = {
    sportivo = {
        etichetta = 'Porto d\'armi per uso sportivo',
        descrizione = 'Consente il trasporto scarico e in custodia verso il poligono.',
        costo = 18000, validitaGiorni = 365,
        consentePorto = false,       -- non si può girare armati per strada
        categorie = { 'sportiva' },
        requisiti = { fedinaPulita = true },
    },
    caccia = {
        etichetta = 'Porto d\'armi per uso venatorio',
        descrizione = 'Valido per fucili da caccia nelle zone e nei periodi consentiti.',
        costo = 25000, validitaGiorni = 365,
        consentePorto = false,
        categorie = { 'caccia' },
        requisiti = { fedinaPulita = true, licenzaCaccia = true },
    },
    difesa = {
        etichetta = 'Porto d\'armi per difesa personale',
        descrizione = 'Il titolo più difficile da ottenere: consente il porto in luogo pubblico.',
        costo = 120000, validitaGiorni = 365,
        consentePorto = true,
        categorie = { 'sportiva', 'difesa' },
        requisiti = { fedinaPulita = true, motivazione = true },
    },
    servizio = {
        etichetta = 'Arma di ordinanza',
        descrizione = 'Assegnata dall\'amministrazione al personale in servizio.',
        costo = 0, validitaGiorni = 3650,
        consentePorto = true,
        categorie = { 'ordinanza', 'difesa', 'sportiva' },
        soloLavori = { 'carabinieri', 'polizia', 'guardia_finanza' },
    },
}

-- ---------------------------------------------------------------------------
--  Catalogo delle armi
--  categoria: sportiva | caccia | difesa | ordinanza | clandestina
-- ---------------------------------------------------------------------------
ARM.Catalogo = {
    -- Sportive e da difesa
    { arma = 'WEAPON_PISTOL',        nome = 'Pistola semiautomatica', categoria = 'difesa',    prezzo = 380000, munizioni = 'cartuccia', capienza = 12 },
    { arma = 'WEAPON_COMBATPISTOL',  nome = 'Pistola da difesa',      categoria = 'difesa',    prezzo = 520000, munizioni = 'cartuccia', capienza = 12 },
    { arma = 'WEAPON_VINTAGEPISTOL', nome = 'Pistola da collezione',  categoria = 'sportiva',  prezzo = 460000, munizioni = 'cartuccia', capienza = 8 },
    { arma = 'WEAPON_REVOLVER',      nome = 'Revolver',               categoria = 'sportiva',  prezzo = 610000, munizioni = 'cartuccia', capienza = 6 },

    -- Caccia
    { arma = 'WEAPON_PUMPSHOTGUN',   nome = 'Fucile a pompa',         categoria = 'caccia',    prezzo = 720000, munizioni = 'cartuccia_caccia', capienza = 8 },
    { arma = 'WEAPON_DBSHOTGUN',     nome = 'Doppietta',              categoria = 'caccia',    prezzo = 540000, munizioni = 'cartuccia_caccia', capienza = 2 },
    { arma = 'WEAPON_SNIPERRIFLE',   nome = 'Carabina di precisione', categoria = 'caccia',    prezzo = 1450000, munizioni = 'cartuccia_caccia', capienza = 5 },

    -- Ordinanza
    { arma = 'WEAPON_STUNGUN',       nome = 'Pistola a impulsi',      categoria = 'ordinanza', prezzo = 0, munizioni = nil },
    { arma = 'WEAPON_NIGHTSTICK',    nome = 'Sfollagente',            categoria = 'ordinanza', prezzo = 0, munizioni = nil },
    { arma = 'WEAPON_SMG',           nome = 'Pistola mitragliatrice', categoria = 'ordinanza', prezzo = 0, munizioni = 'cartuccia', capienza = 30 },
    { arma = 'WEAPON_CARBINERIFLE',  nome = 'Carabina d\'ordinanza',  categoria = 'ordinanza', prezzo = 0, munizioni = 'cartuccia', capienza = 30, gradoMinimo = 3 },
    { arma = 'WEAPON_FLASHLIGHT',    nome = 'Torcia di servizio',     categoria = 'ordinanza', prezzo = 0 },

    -- Clandestine: nessuna matricola, nessun registro
    { arma = 'WEAPON_SNSPISTOL',     nome = 'Pistola clandestina',    categoria = 'clandestina', prezzo = 850000, munizioni = 'cartuccia', capienza = 8 },
    { arma = 'WEAPON_MICROSMG',      nome = 'Mitraglietta',           categoria = 'clandestina', prezzo = 2400000, munizioni = 'cartuccia', capienza = 16 },
    { arma = 'WEAPON_SAWNOFFSHOTGUN',nome = 'Fucile a canne mozze',   categoria = 'clandestina', prezzo = 1600000, munizioni = 'cartuccia_caccia', capienza = 8 },
    { arma = 'WEAPON_MACHETE',       nome = 'Machete',                categoria = 'clandestina', prezzo = 90000 },
    { arma = 'WEAPON_KNIFE',         nome = 'Coltello',               categoria = 'clandestina', prezzo = 45000 },
}

-- ---------------------------------------------------------------------------
--  Luoghi
-- ---------------------------------------------------------------------------
ARM.Armerie = {
    { nome = 'Armeria Centro',   coord = vector3(21.7, -1106.4, 29.8) },
    { nome = 'Armeria Sandy',    coord = vector3(1693.4, 3760.2, 34.7) },
    { nome = 'Armeria Paleto',   coord = vector3(-330.2, 6083.9, 31.5) },
}

--- Sportello della Questura per il rilascio dei titoli
ARM.Ufficio = {
    nome = 'Ufficio Armi — Questura',
    coord = vector3(-1096.7, -822.1, 19.3),
}

--- Armerie di reparto: solo per il personale in servizio
ARM.Armadi = {
    { nome = 'Armeria Carabinieri', coord = vector3(453.4, -980.1, 30.7), lavoro = 'carabinieri' },
    { nome = 'Armeria Questura',    coord = vector3(-1108.4, -839.5, 19.3), lavoro = 'polizia' },
    { nome = 'Armeria GdF',         coord = vector3(-616.2, -935.4, 23.9), lavoro = 'guardia_finanza' },
}

--- Poligono: si può sparare senza commettere reato
ARM.Poligoni = {
    { nome = 'Poligono di tiro', coord = vector3(15.6, -1096.6, 29.8), raggio = 40.0 },
}

-- ---------------------------------------------------------------------------
--  Regole
-- ---------------------------------------------------------------------------
ARM.Regole = {
    -- Prezzo delle munizioni per cartuccia
    prezzoCartuccia = 450,
    prezzoCartucciaCaccia = 700,
    -- Munizioni acquistabili per volta
    massimoAcquistoMunizioni = 250,
    -- Il porto d'armi va rinnovato: allo scadere l'arma va consegnata
    giorniPreavvisoScadenza = 7,
    -- Denuncia di detenzione: obbligatoria entro N giorni dall'acquisto
    giorniDenuncia = 3,
    -- Un'arma clandestina addosso è reato in sé
    reatoClandestina = '697',
    reatoPortoAbusivo = '699',
    -- Costo per abradere la matricola al mercato nero
    costoAbrasione = 250000,
    -- Probabilità che un'arma abrasa venga comunque ricondotta al proprietario
    probabilitaTracciamento = 0.25,
}

function ARM.GetArma(nomeArma)
    for _, a in ipairs(ARM.Catalogo) do
        if a.arma == nomeArma then return a end
    end
    return nil
end

--- Armi acquistabili con un dato titolo.
function ARM.AcquistabiliCon(titolo)
    local t = ARM.Titoli[titolo]
    if not t then return {} end

    local out = {}
    for _, a in ipairs(ARM.Catalogo) do
        for _, categoria in ipairs(t.categorie) do
            if a.categoria == categoria and a.prezzo > 0 then
                out[#out + 1] = a
                break
            end
        end
    end
    return out
end
