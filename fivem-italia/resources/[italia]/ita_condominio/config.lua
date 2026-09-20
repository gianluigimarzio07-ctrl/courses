--[[
    AUREA · Condominio (configurazione)

    LA COSA PIÙ ITALIANA DI TUTTE

    Il server aveva le case: si compravano, si vendevano, si pagava l'IMU.
    Ogni appartamento era un'isola. Ma un appartamento non è un'isola: sta
    in un palazzo, e quel palazzo ha un tetto che piove, una facciata che
    si scrosta, un ascensore che si rompe, e un tizio che deve convincere
    otto persone a pagare per ripararli.

    Questa risorsa è quel tizio.

    I MILLESIMI

    Non si vota a testa: si vota a millesimi. Ogni unità ha un peso
    proporzionale al suo valore catastale, e la somma fa mille. Chi ha
    l'attico decide più di chi ha il seminterrato, e paga di più.

    I millesimi qui non li inventa nessuno: si calcolano dalla RENDITA
    CATASTALE che ita_catasto già tiene. È il modo vero.

    LE MAGGIORANZE

    Art. 1136 c.c., e sono due diverse:
    · spesa ORDINARIA — basta la maggioranza dei votanti con un terzo
      dei millesimi;
    · spesa STRAORDINARIA — servono cinquecento millesimi. Metà del
      palazzo, e non una testa in meno.

    È la ragione per cui in Italia i tetti si rifanno dopo vent'anni.

    IL MOROSO

    E poi c'è quello che non paga. L'amministratore ha un'arma che pochi
    creditori hanno: il decreto ingiuntivo dell'art. 63 delle disposizioni
    di attuazione del codice civile, che è IMMEDIATAMENTE ESECUTIVO. Non
    serve aspettare un giudizio: si va sul conto e si prende.

    IL DECORO

    Un palazzo tenuto bene vale più di uno tenuto male, e questo il server
    lo misura: il `decoro` sale quando si spende in manutenzione e scende
    quando non si spende. ita_immobiliare lo legge quando stima un
    appartamento. Il tetto che non hai rifatto te lo ritrovi sul prezzo.
]]

CON = {}

-- ---------------------------------------------------------------------------
--  I condomini
-- ---------------------------------------------------------------------------
CON.Condomini = {
    {
        codice = 'via_rossini',
        nome = 'Condominio Via Rossini 12',
        indirizzo = 'Via Rossini 12',
        coord = vector3(-663.4, -854.6, 24.5),
        raggio = 90.0,
        compensoAnnuo = 180000,
        blip = { sprite = 375, colore = 25, scala = 0.6 },
    },
    {
        codice = 'lungomare_8',
        nome = 'Condominio Lungomare 8',
        indirizzo = 'Lungomare 8',
        coord = vector3(-1150.8, -1520.4, 10.6),
        raggio = 90.0,
        compensoAnnuo = 240000,
        blip = { sprite = 375, colore = 25, scala = 0.6 },
    },
    {
        codice = 'piazza_duomo',
        nome = 'Condominio Piazza Duomo 3',
        indirizzo = 'Piazza Duomo 3',
        coord = vector3(-14.2, -1450.6, 31.1),
        raggio = 80.0,
        compensoAnnuo = 300000,
        blip = { sprite = 375, colore = 25, scala = 0.6 },
    },
}

function CON.GetCondominio(codice)
    for _, c in ipairs(CON.Condomini) do
        if c.codice == codice then return c end
    end
    return nil
end

function CON.CondominioVicino(coord)
    for _, c in ipairs(CON.Condomini) do
        if #(coord - c.coord) <= c.raggio then return c end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Millesimi
-- ---------------------------------------------------------------------------
CON.Millesimi = {
    -- La somma dei millesimi di un condominio
    totale = 1000,
    -- Millesimi minimi per unità: nessuno vale zero
    minimo = 20,
}

-- ---------------------------------------------------------------------------
--  Assemblea e maggioranze (art. 1136 c.c.)
-- ---------------------------------------------------------------------------
CON.Maggioranze = {
    ordinaria = {
        -- Maggioranza dei votanti e un terzo dei millesimi
        millesimiMinimi = 334,
        richiedeMaggioranzaVotanti = true,
    },
    straordinaria = {
        -- Cinquecento millesimi, e non uno di meno
        millesimiMinimi = 500,
        richiedeMaggioranzaVotanti = true,
    },

    -- Quanti minuti resta aperta una votazione prima di decadere
    minutiVotazione = 60,
}

-- ---------------------------------------------------------------------------
--  Spese
-- ---------------------------------------------------------------------------
CON.Spese = {
    importoMinimo = 20000,
    importoMassimo = 8000000,

    -- Minuti per pagare la propria quota
    minutiPerPagare = 45,

    -- Tipi di spesa proponibili. `decoro` è di quanto alza il decoro del
    -- palazzo quando la spesa è deliberata e pagata.
    voci = {
        { id = 'pulizia',    nome = 'Pulizia delle scale',        tipo = 'ordinaria',     decoro = 4 },
        { id = 'ascensore',  nome = 'Manutenzione dell\'ascensore', tipo = 'ordinaria',   decoro = 6 },
        { id = 'giardino',   nome = 'Cura del giardino',          tipo = 'ordinaria',     decoro = 5 },
        { id = 'luce',       nome = 'Illuminazione delle parti comuni', tipo = 'ordinaria', decoro = 3 },
        { id = 'facciata',   nome = 'Rifacimento della facciata',  tipo = 'straordinaria', decoro = 22 },
        { id = 'tetto',      nome = 'Rifacimento del tetto',       tipo = 'straordinaria', decoro = 25 },
        { id = 'caldaia',    nome = 'Sostituzione della caldaia',  tipo = 'straordinaria', decoro = 14 },
        { id = 'antisismico',nome = 'Interventi antisismici',      tipo = 'straordinaria', decoro = 18 },
    },
}

function CON.GetVoce(id)
    for _, v in ipairs(CON.Spese.voci) do
        if v.id == id then return v end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Decoro
-- ---------------------------------------------------------------------------
CON.Decoro = {
    -- Ogni quanti minuti il palazzo si degrada da solo
    minutiDegrado = 60,
    puntiDegrado = 3,

    -- Quanto conta il decoro sul valore di un appartamento: uno scarto
    -- massimo in più o in meno rispetto alla stima nuda.
    influenzaMassima = 0.18,
}

--- Il moltiplicatore sul valore di un appartamento, dato il decoro.
--- A 50 è neutro; a 100 è il massimo in su, a 0 il massimo in giù.
function CON.Moltiplicatore(decoro)
    local d = math.max(0, math.min(100, tonumber(decoro) or 50))
    return 1 + (((d - 50) / 50) * CON.Decoro.influenzaMassima)
end

-- ---------------------------------------------------------------------------
--  Morosità
-- ---------------------------------------------------------------------------
CON.Morosita = {
    -- Dopo quanti minuti dalla scadenza si può chiedere il decreto
    minutiPerIngiungere = 15,

    -- Art. 63 disp. att. c.c.: il decreto è immediatamente esecutivo.
    -- Si va sul conto e si prende, anche andando sotto.
    esecuzioneImmediata = true,

    -- Spese legali che si aggiungono alla quota
    speseLegali = 45000,
}
