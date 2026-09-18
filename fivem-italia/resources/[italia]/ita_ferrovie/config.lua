--[[
    AUREA · Ferrovie — configurazione

    NON È UN ALTRO AUTOBUS

    ita_trasporti ha le linee urbane: fermate vicine, biglietto da
    obliterare, controllore. Funziona, ed è il trasporto di chi si muove
    in città.

    Il treno è un'altra cosa, e la differenza non è la lunghezza del
    percorso: è che il treno ha un ORARIO. Parte a un minuto stabilito,
    che tu ci sia o no, e se sei in ritardo al capolinea il ritardo lo
    porti addosso per tutta la corsa.

    Il macchinista non guida dove vuole: guida fra due stazioni, e quello
    che conta è arrivare quando deve. Il capotreno vende e controlla.

    E POI C'È IL PASSAGGIO A LIVELLO

    Quando un convoglio è in avvicinamento, il passaggio a livello si
    chiude. Chi lo forza commette una violazione seria — art. 147 CdS,
    sei punti — e rischia molto peggio di una multa.
]]

FER = {}

FER.Lavoro = 'ferroviere'

-- ---------------------------------------------------------------------------
--  Le stazioni
-- ---------------------------------------------------------------------------
FER.Stazioni = {
    { id = 'centrale', nome = 'Stazione Centrale',    coord = vector3(-533.4, -1276.2, 26.4), banchina = vector3(-529.8, -1281.6, 26.4) },
    { id = 'porto',    nome = 'Stazione Porto',       coord = vector3(1066.8, -2200.4, 30.5), banchina = vector3(1070.2, -2205.8, 30.5) },
    { id = 'aeroporto',nome = 'Stazione Aeroporto',   coord = vector3(-1046.2, -2740.8, 21.3), banchina = vector3(-1042.6, -2745.4, 21.3) },
    { id = 'sandy',    nome = 'Stazione di Sandy Shores', coord = vector3(1720.4, 3290.6, 41.1), banchina = vector3(1724.8, 3295.2, 41.1) },
    { id = 'paleto',   nome = 'Stazione di Paleto',   coord = vector3(-190.6, 6398.2, 31.5), banchina = vector3(-186.2, 6403.4, 31.5) },
}

function FER.GetStazione(id)
    for _, s in ipairs(FER.Stazioni) do
        if s.id == id then return s end
    end
end

-- ---------------------------------------------------------------------------
--  Le linee
--
--  `orario` è ogni quanti minuti parte una corsa, e a che minuto
--  dell'ora. Il treno parte da solo: chi non c'è, resta a terra.
-- ---------------------------------------------------------------------------
FER.Linee = {
    {
        id = 'r1', nome = 'Regionale 1 — Centrale/Paleto',
        fermate = { 'centrale', 'porto', 'sandy', 'paleto' },
        minutiFraFermate = 4,
        prezzo = 45000,
        compensoMacchinista = 38000,
        compensoCapotreno = 26000,
    },
    {
        id = 'r2', nome = 'Regionale 2 — Aeroporto/Sandy',
        fermate = { 'aeroporto', 'centrale', 'sandy' },
        minutiFraFermate = 5,
        prezzo = 38000,
        compensoMacchinista = 32000,
        compensoCapotreno = 22000,
    },
}

function FER.GetLinea(id)
    for _, l in ipairs(FER.Linee) do
        if l.id == id then return l end
    end
end

-- ---------------------------------------------------------------------------
--  Orario e puntualità
-- ---------------------------------------------------------------------------
FER.Orario = {
    -- Ogni quanti minuti reali parte una corsa
    cadenzaMinuti = 12,
    -- Tolleranza sull'arrivo prima che si parli di ritardo
    tolleranzaSecondi = 45,
    -- Quanto si perde di compenso per ogni minuto di ritardo
    penalePerMinuto = 0.12,
    -- E quanto si prende in più arrivando in orario su tutte le fermate
    premioPuntualita = 0.25,
    -- Distanza entro cui una fermata si considera servita
    raggioFermata = 30.0,
}

-- ---------------------------------------------------------------------------
--  Biglietti
-- ---------------------------------------------------------------------------
FER.Biglietti = {
    item = 'biglietto_treno',
    -- Quanto vale un biglietto dopo l'obliterazione, in minuti
    validitaMinuti = 30,
    -- La sanzione di chi viaggia senza
    sanzione = 120000,
    -- Quanto trattiene l'azienda
    quotaAzienda = 0.45,
}

-- ---------------------------------------------------------------------------
--  Passaggi a livello
-- ---------------------------------------------------------------------------
FER.PassaggiLivello = {
    { id = 'pl_sandy',  nome = 'PL di Sandy Shores', coord = vector3(1680.4, 3240.2, 40.8) },
    { id = 'pl_alamo',  nome = 'PL del ponte Alamo', coord = vector3(1290.6, 2820.4, 38.2) },
    { id = 'pl_paleto', nome = 'PL di Paleto',       coord = vector3(-320.8, 6250.6, 31.4) },
    { id = 'pl_porto',  nome = 'PL della zona portuale', coord = vector3(920.4, -2050.8, 30.2) },
}

FER.Sbarre = {
    -- Quanto prima si chiudono, in secondi
    anticipoSecondi = 40,
    -- Quanto restano chiuse dopo il passaggio
    codaSecondi = 15,
    -- Raggio entro cui un veicolo è "sul passaggio"
    raggio = 12.0,
    -- La violazione
    articolo = 'art. 147 CdS',
    sanzione = 240000,
    punti = 6,
}

FER.Treno = {
    -- Il modello del convoglio: FiveM ha un treno su binari, ma qui si
    -- guida un mezzo normale su percorso ferroviario — è una scelta di
    -- praticità, non di pigrizia: i binari nativi non si fermano dove
    -- vuoi tu.
    modello = 'freight',
    vagone = 'freightcar',
}
