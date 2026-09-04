--[[
    AUREA · Comune — configurazione

    L'ente che dà al server una politica: il sindaco è eletto dai giocatori,
    resta in carica un tempo definito, e mentre governa decide davvero
    qualcosa — l'addizionale comunale che finisce nelle tasche di tutti.
]]

COM = {}

COM.Sede = {
    nome = 'Municipio',
    coord = vector3(-544.2, -204.4, 38.2),
    -- Sala consiliare, dove si celebrano i matrimoni
    saleMatrimoni = {
        { nome = 'Sala consiliare', coord = vector3(-551.4, -190.9, 38.2) },
        { nome = 'Belvedere del molo', coord = vector3(-1850.0, -1240.0, 8.6) },
        { nome = 'Giardini di Vinewood', coord = vector3(300.0, 190.0, 104.0) },
    },
    blip = { sprite = 419, colore = 5, scala = 0.85 },
}

-- ---------------------------------------------------------------------------
--  Servizi anagrafici
-- ---------------------------------------------------------------------------
COM.Servizi = {
    residenza = {
        nome = 'Cambio di residenza',
        descrizione = 'Aggiorna l\'indirizzo sui documenti. Serve un immobile intestato o locato.',
        costo = 1600,
    },
    duplicato_ci = {
        nome = 'Duplicato della carta d\'identità',
        descrizione = 'Se hai smarrito il documento.',
        costo = 2250,
    },
    duplicato_ts = {
        nome = 'Duplicato della tessera sanitaria',
        descrizione = 'Rilascio immediato allo sportello.',
        costo = 0,
    },
    certificato = {
        nome = 'Certificato di stato di famiglia',
        descrizione = 'Attesta il tuo stato civile e la composizione del nucleo.',
        costo = 1600,
    },
    cambio_nome = {
        nome = 'Istanza di cambio del nome',
        descrizione = 'Procedura eccezionale, richiede il decreto del Prefetto.',
        costo = 180000,
        richiedeApprovazione = true,
    },
}

-- ---------------------------------------------------------------------------
--  Matrimonio civile
-- ---------------------------------------------------------------------------
COM.Matrimonio = {
    -- Diritti di segreteria
    costo = 32000,
    -- Il rito richiede la presenza di entrambi e di un celebrante
    distanzaSposi = 3.0,
    durataRito = 20000,
    -- Chi può celebrare
    celebranti = { 'comune' },
    gradoMinimoCelebrante = 1,
    -- Regime patrimoniale
    regimi = {
        comunione = {
            nome = 'Comunione dei beni',
            descrizione = 'Quanto acquistato dopo le nozze appartiene a entrambi.',
        },
        separazione = {
            nome = 'Separazione dei beni',
            descrizione = 'Ciascuno resta titolare di ciò che acquista.',
        },
    },
    -- Divorzio
    costoDivorzio = 95000,
    -- In comunione, il divorzio divide il saldo bancario
    divideBanca = true,
}

-- ---------------------------------------------------------------------------
--  Elezioni comunali
-- ---------------------------------------------------------------------------
COM.Elezioni = {
    -- Durata del mandato, in minuti reali
    durataMandato = 10080,        -- una settimana
    -- Durata della campagna elettorale
    durataCampagna = 1440,        -- un giorno
    -- Quota per presentare la candidatura
    cauzioneCandidatura = 250000,
    -- Firme necessarie per la presentazione della lista
    firmeNecessarie = 3,
    -- Un elettore vota una volta sola
    -- Requisito per candidarsi: nessuna condanna grave
    gravitaOstativa = 4,
    -- Stipendio del sindaco, per ciclo di paga
    indennitaSindaco = 42000,
}

--- Leve che il sindaco può manovrare
COM.LeveSindaco = {
    addizionale = {
        nome = 'Addizionale comunale IRPEF',
        descrizione = 'Quota della ritenuta sugli stipendi devoluta al Comune anziché allo Stato.',
        minimo = 0, massimo = 8,      -- punti percentuali
        predefinito = 2,
    },
    tari = {
        nome = 'Tassa sui rifiuti',
        descrizione = 'Quota fissa per immobile.',
        minimo = 5000, massimo = 45000,
        predefinito = 18000,
    },
    ztl = {
        nome = 'Fasce orarie della ZTL',
        descrizione = 'Restringere le fasce riduce i verbali, allargarle aumenta il gettito.',
        opzioni = { 'ridotta', 'ordinaria', 'estesa' },
        predefinito = 'ordinaria',
    },
    sussidio = {
        nome = 'Sussidio di disoccupazione',
        descrizione = 'Quanto riceve chi non ha lavoro, per ciclo.',
        minimo = 1500, massimo = 9000,
        predefinito = 3500,
    },
}

-- ---------------------------------------------------------------------------
--  Cicli tributari del Comune
-- ---------------------------------------------------------------------------
COM.Tributi = {
    -- Ogni quanto si iscrive a ruolo la TARI
    intervalloTari = 3600000,          -- un'ora reale
    -- Ogni quanto si eroga il sussidio
    intervalloSussidio = 1800000,      -- mezz'ora reale
    -- Chi lo riceve
    lavoroDisoccupato = 'disoccupato',
}

function COM.GetServizio(id) return COM.Servizi[id] end
