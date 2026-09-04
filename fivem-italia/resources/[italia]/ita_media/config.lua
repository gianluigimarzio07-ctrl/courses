--[[
    AUREA · Media — configurazione

    Un server senza cronaca è un server dove le cose accadono e poi spariscono.
    La testata serve a questo: dare memoria pubblica ai fatti, e dare a chi
    viene raccontato male gli strumenti che la legge italiana gli riconosce —
    la rettifica e la querela per diffamazione a mezzo stampa.
]]

MED = {}

MED.Testata = {
    nome = 'Il Corriere di Los Santos',
    sottotitolo = 'Quotidiano di cronaca, politica ed economia',
    lavoro = 'giornalista',
    -- Redazione
    sede = { nome = 'Redazione', coord = vector3(-598.4, -929.4, 23.9) },
    blip = { sprite = 184, colore = 4, scala = 0.8 },
}

--- Le edicole: chi non fa il giornalista legge qui, o dal telefono.
MED.Edicole = {
    { nome = 'Edicola di Vespucci',   coord = vector3(-1236.0, -1445.0, 4.3) },
    { nome = 'Edicola di Vinewood',   coord = vector3(331.5, 179.0, 103.6) },
    { nome = 'Edicola della Stazione', coord = vector3(-256.0, -1004.0, 30.2) },
    { nome = 'Edicola del Porto',     coord = vector3(1163.0, -323.0, 69.2) },
}

MED.Copia = {
    item = 'giornale',
    prezzo = 150,                  -- 1,50 €
    -- Quota di ogni copia che finisce nella cassa della testata
    quotaTestata = 0.70,
}

-- ---------------------------------------------------------------------------
--  Articoli
-- ---------------------------------------------------------------------------
MED.Articoli = {
    -- Quante edizioni restano in prima pagina
    inPrimaPagina = 8,
    -- Quanti articoli si conservano in archivio
    archivio = 120,
    -- Un cronista non può pubblicare più spesso di così
    attesaFraPezzi = 240,          -- secondi
    lunghezzaMassima = 2400,
    titoloMassimo = 110,
    -- Compenso lordo a pezzo, a carico della cassa della testata.
    -- Si sceglie in base al grado di chi firma: la ritenuta è del 20%.
    compenso = {
        praticante    = 2500,
        cronista      = 6500,
        caporedattore = 18000,
    },
}

MED.Sezioni = {
    { id = 'cronaca',   nome = 'Cronaca',            icona = '🚨' },
    { id = 'politica',  nome = 'Politica',           icona = '🏛' },
    { id = 'economia',  nome = 'Economia e lavoro',  icona = '📈' },
    { id = 'giudiziaria', nome = 'Cronaca giudiziaria', icona = '⚖' },
    { id = 'inchiesta', nome = 'Inchieste',          icona = '🔎' },
    { id = 'cultura',   nome = 'Cultura e spettacoli', icona = '🎭' },
    { id = 'sport',     nome = 'Sport',              icona = '⚽' },
    { id = 'necrologi', nome = 'Necrologi',          icona = '🕯' },
}

-- ---------------------------------------------------------------------------
--  Diritti di chi viene raccontato
-- ---------------------------------------------------------------------------
MED.Rettifica = {
    -- Art. 8 legge 47/1948: chi è citato ha diritto alla rettifica
    nome = 'Diritto di rettifica',
    -- Entro quanto si può chiedere, dalla pubblicazione
    entroSecondi = 5400,
    -- La redazione ha questo tempo per pubblicarla, poi scatta l'omessa rettifica
    terminePubblicazione = 3600,
    lunghezzaMassima = 800,
    -- Sanzione a carico della testata se la rettifica non esce nei termini
    sanzioneOmissione = 120000,
}

MED.Diffamazione = {
    -- Art. 595 comma 3 c.p. — diffamazione col mezzo della stampa
    articolo = '595',
    -- Costo del deposito della querela
    costoQuerela = 0,
    -- Entro quanto si può querelare (tre mesi "in gioco")
    entroSecondi = 10800,
    -- Se il fascicolo si chiude con condanna, la testata risarcisce
    risarcimento = 250000,
}

-- ---------------------------------------------------------------------------
--  Diretta televisiva
-- ---------------------------------------------------------------------------
MED.Diretta = {
    -- Serve il caporedattore o chi ha il permesso
    permesso = 'diretta',
    -- Serve un operatore: la diretta è un fatto di due persone
    richiedeOperatore = true,
    distanzaOperatore = 12.0,
    -- Durata massima di un collegamento
    durataMassima = 600000,
    -- Fascia sotto lo schermo di tutti
    coloreFascia = { 172, 26, 26 },
}

-- ---------------------------------------------------------------------------
--  Inserzioni pubblicitarie
-- ---------------------------------------------------------------------------
MED.Inserzioni = {
    formati = {
        colonnino = { nome = 'Colonnino',      costo = 25000,  edizioni = 2 },
        mezza     = { nome = 'Mezza pagina',   costo = 90000,  edizioni = 4 },
        pagina    = { nome = 'Pagina intera',  costo = 220000, edizioni = 6 },
    },
    testoMassimo = 240,
    -- Quante inserzioni convivono in una edizione
    perEdizione = 4,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function MED.GetSezione(id)
    for _, s in ipairs(MED.Sezioni) do
        if s.id == id then return s end
    end
    return nil
end

function MED.EdicolaVicina(coord, raggio)
    for _, e in ipairs(MED.Edicole) do
        if #(coord - e.coord) < (raggio or 2.2) then return e end
    end
    return nil
end
