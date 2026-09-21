--[[
    AUREA · Taxi (configurazione)

    UN LAVORO CHE ESISTEVA E NON SI POTEVA FARE

    In `lavori.lua` c'è `tassista` da sempre, con due gradi e uno
    stipendio. È uno dei pochi mestieri del server che aveva la voce in
    busta paga e nessuna risorsa dietro: si poteva essere tassisti e non
    si poteva fare il tassista.

    IL TASSAMETRO

    La cosa che distingue un taxi da una macchina con dentro due persone
    è il tassametro, e il tassametro in Italia è una cosa regolata: c'è
    uno SCATTO ALLA PARTENZA, una TARIFFA AL CHILOMETRO, e una TARIFFA
    A TEMPO che scatta quando sei fermo nel traffico — perché il tempo
    del tassista vale anche quando la macchina non si muove.

    Qui il conto lo tiene il server leggendo la posizione del veicolo:
    non è il tassista a dire quanti chilometri ha fatto.

    LA LICENZA

    E poi c'è il pezzo che in Italia vale più della macchina: la licenza
    comunale. È un numero chiuso, si compra, e senza di quella guidare
    gente a pagamento non è un mestiere — è ABUSIVISMO, che l'art. 86
    CdS punisce sul serio, con il sequestro del veicolo.

    Il server distingue le due cose: una corsa con licenza è un lavoro,
    una corsa senza è un illecito che lascia una traccia.
]]

TAX = {}

TAX.Lavoro = 'tassista'

TAX.Rimessa = {
    nome = 'Rimessa taxi',
    coord = vector3(895.2, -179.4, 74.7),
    raggio = 2.6,
    spawn = vector4(903.0, -173.0, 74.1, 240.0),
    modello = 'taxi',
    blip = { sprite = 198, colore = 5, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  La licenza
-- ---------------------------------------------------------------------------
TAX.Licenza = {
    -- Chi la rilascia: il Comune, con il permesso sulle licenze
    lavoroRilascio = 'comune',
    permesso = 'licenze',

    -- Numero chiuso: quante licenze esistono in tutto
    contingente = 12,

    costo = 850000,
    giorniValidita = 120,
}

-- ---------------------------------------------------------------------------
--  Il tassametro
-- ---------------------------------------------------------------------------
TAX.Tariffa = {
    -- Scatto alla partenza
    scatto = 350,

    -- Al chilometro
    alKm = 110,

    -- Al minuto di sosta o di marcia sotto i 10 km/h: il tempo del
    -- tassista vale anche nel traffico.
    alMinutoFermo = 45,
    sogliaFermo = 10.0,

    -- Supplementi
    notturno = { dalle = 22, alle = 6, supplemento = 0.25 },
    festivo = 0.15,

    -- Ogni quanti secondi il tassametro aggiorna
    secondiAggiornamento = 5,
}

--- Il moltiplicatore orario: notturno e festivo si sommano.
function TAX.Moltiplicatore(ora, giornoSettimana)
    local m = 1.0

    local n = TAX.Tariffa.notturno
    local notte = (n.dalle <= n.alle) and (ora >= n.dalle and ora < n.alle)
                                      or (ora >= n.dalle or ora < n.alle)
    if notte then m = m + n.supplemento end
    if giornoSettimana == 7 then m = m + TAX.Tariffa.festivo end

    return m
end

--- Il totale di una corsa.
function TAX.Totale(metri, secondiFermo, moltiplicatore)
    local km = (tonumber(metri) or 0) / 1000
    local minuti = (tonumber(secondiFermo) or 0) / 60

    local base = TAX.Tariffa.scatto
        + math.floor(km * TAX.Tariffa.alKm)
        + math.floor(minuti * TAX.Tariffa.alMinutoFermo)

    return math.max(TAX.Tariffa.scatto, math.floor(base * (moltiplicatore or 1.0)))
end

-- ---------------------------------------------------------------------------
--  Abusivismo
-- ---------------------------------------------------------------------------
TAX.Abusivismo = {
    -- Art. 86 CdS: esercizio abusivo di attività di trasporto
    infrazione = '86',

    -- Probabilità che una corsa senza licenza venga notata
    probabilitaSegnalazione = 22,

    -- Quota che il Comune trattiene sulle corse regolari
    quotaComune = 0.06,
}
