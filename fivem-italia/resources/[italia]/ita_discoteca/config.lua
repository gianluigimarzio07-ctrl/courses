--[[
    AUREA · Locali notturni (configurazione)

    IL NODO

    Questa risorsa non inventa quasi niente. Prende quattro cose che il
    server ha già e le mette nello stesso punto: la porta di una discoteca.

    Per aprire una serata servono, tutte insieme:

    · la LICENZA DI PUBBLICO SPETTACOLO, art. 68 TULPS, che rilascia la
      Questura (ita_questura);
    · il PERMESSO PER TRATTENIMENTO DANZANTE della SIAE (ita_siae);
    · almeno un ADDETTO AI SERVIZI DI CONTROLLO in servizio, iscritto
      all'elenco della Prefettura (ita_prefettura);
    · e che il locale non sia sotto provvedimento.

    Manca una qualsiasi delle quattro e la serata non si apre. Non è
    burocrazia messa lì per fare attrito: è il modo in cui quattro uffici
    che non si parlano mai finiscono per parlarsi in un posto solo.

    LA CAPIENZA

    E poi c'è la capienza, che è la cosa per cui in Italia i locali
    chiudono davvero. Il numero sulla licenza non è un consiglio: chi lo
    supera si vede sospendere la licenza, e la serata finisce lì.

    Il buttafuori che fa entrare uno con il DASPO non commette un errore
    di valutazione: esce dall'elenco prefettizio, e senza elenco quel
    mestiere non lo fa più.
]]

DISCO = {}

DISCO.Lavoro = 'locale_notturno'

-- ---------------------------------------------------------------------------
--  I locali
--
--  I codici coincidono con gli id in SIAE.Locali: è lo stesso posto visto
--  da due uffici diversi, e deve restare lo stesso posto.
-- ---------------------------------------------------------------------------
DISCO.Locali = {
    {
        codice = 'discoteca_riva',
        nome = 'Discoteca sul lungomare',
        capienza = 60,
        ingresso = vector3(-1605.0, -1108.0, 2.6),
        cassa = vector3(-1600.4, -1113.0, 2.6),
        consolle = vector3(-1610.2, -1102.8, 2.6),
        blip = { sprite = 136, colore = 27, scala = 0.8 },
    },
    {
        codice = 'circolo',
        nome = 'Circolo ricreativo',
        capienza = 35,
        ingresso = vector3(129.0, -1300.2, 29.2),
        cassa = vector3(125.6, -1297.8, 29.2),
        consolle = vector3(132.4, -1303.0, 29.2),
        blip = { sprite = 136, colore = 47, scala = 0.7 },
    },
}

function DISCO.GetLocale(codice)
    for _, l in ipairs(DISCO.Locali) do
        if l.codice == codice then return l end
    end
    return nil
end

function DISCO.LocaleVicino(coord, raggio)
    for _, l in ipairs(DISCO.Locali) do
        if #(coord - l.ingresso) <= (raggio or 30.0) then return l end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Gestione
-- ---------------------------------------------------------------------------
DISCO.Gestione = {
    -- Il grado del lavoro che può prendersi un locale
    gradoGestore = 4,
    -- Il grado che fa il filtro all'ingresso
    gradoFiltro = 2,
    -- Quanto costa subentrare nella gestione
    costoSubentro = 450000,
}

-- ---------------------------------------------------------------------------
--  Serate
-- ---------------------------------------------------------------------------
DISCO.Serata = {
    -- Prezzo d'ingresso: lo decide il gestore, dentro questi limiti
    ingressoMinimo = 1000,
    ingressoMassimo = 5000,

    -- Durata massima di una serata, in minuti. Poi si chiude da sola.
    minutiMassimi = 90,

    -- Quota dell'incasso che resta nella cassa del locale; il resto è
    -- il compenso di chi ha lavorato quella sera.
    quotaCassa = 0.70,

    -- Serve almeno un addetto ai servizi di controllo iscritto
    richiedeFiltro = true,

    -- Sopra questa quota della capienza, il filtro comincia a rifiutare
    -- anche chi è in regola: dentro non ci sta più nessuno.
    sogliaPienone = 1.0,

    -- Quante persone oltre la capienza fanno scattare la sospensione
    -- della licenza. Zero: la capienza è la capienza.
    tolleranzaCapienza = 0,
}

-- ---------------------------------------------------------------------------
--  Controlli
-- ---------------------------------------------------------------------------
DISCO.Controllo = {
    -- Chi può fare il controllo su un locale aperto
    entiAbilitati = { 'carabinieri', 'polizia', 'guardia_finanza' },
    durataSecondi = 20,

    -- Sanzione per sovraffollamento, a persona oltre la capienza
    sanzionePerEccedenza = 42000,

    -- Se il locale è senza filtro iscritto, la licenza si sospende
    sospendiSenzaFiltro = true,
}
