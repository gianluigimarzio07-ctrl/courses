--[[
    AUREA · Sinistri stradali (configurazione)

    IL MODULO BLU

    ita_veicoli sapeva già cosa fare quando sbatti: peggiora la classe di
    merito e, se hai la kasko, ti rimborsa. Funziona, ed è la metà della
    cosa — la metà in cui c'è una macchina sola.

    Nella realtà il sinistro è quasi sempre fra DUE persone, e fra due
    persone la domanda non è "quanto è il danno" ma CHI HA TORTO. Per
    rispondere, in Italia esiste un foglio che si chiama constatazione
    amichevole, il modulo blu, e ha una caratteristica che lo rende
    interessante in un gioco di ruolo:

        VALE SOLO SE LO FIRMANO TUTTI E DUE.

    Se lo firmate insieme, la compagnia paga in fretta e nessuno discute.
    Se uno dei due non firma, il sinistro diventa CONTESTATO e serve un
    perito, servono le foto, serve tempo. E nel frattempo la macchina
    resta rotta.

    È una meccanica che non ha bisogno di forzature: l'incentivo a
    mettersi d'accordo sul posto è lo stesso che c'è nella vita.

    IL PERITO

    Il danno non lo dice chi l'ha subito: lo stima un perito, e lo stima
    guardando il mezzo. Qui il numero lo calcola il server sui danni
    effettivi della carrozzeria — se dichiari molto più di quello che si
    vede, non è una furbata: è l'art. 642 c.p., fraudolenta distruzione
    della cosa propria e mutilazione fraudolenta, che è il reato di chi
    gonfia un sinistro.

    CHI PAGA

    · Responsabile con RCA → paga la compagnia, e la classe di merito
      del responsabile peggiora.
    · Responsabile senza RCA → paga lui, di tasca sua, tutto. E si becca
      l'art. 193 CdS, che c'era già.
    · Concorso di colpa → ognuno si tiene metà del proprio danno.
]]

SIN = {}

SIN.Lavoro = 'perito'

-- ---------------------------------------------------------------------------
--  L'agenzia
-- ---------------------------------------------------------------------------
SIN.Agenzia = {
    nome = 'Agenzia infortunistica stradale',
    coord = vector3(-820.4, -1071.8, 11.3),
    raggio = 2.4,
    blip = { sprite = 498, colore = 3, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  Il sinistro
-- ---------------------------------------------------------------------------
SIN.Rilevamento = {
    -- Velocità di impatto sotto la quale non è un sinistro, è una
    -- manovra da parcheggio
    velocitaMinima = 22.0,

    -- Distanza entro cui le due vetture si considerano coinvolte
    distanza = 12.0,

    -- Quanti secondi passano prima che lo stesso conducente possa
    -- aprire un altro sinistro
    raffreddamentoSecondi = 90,

    -- Entro quanti minuti si può ancora firmare la constatazione
    minutiPerFirmare = 20,
}

-- ---------------------------------------------------------------------------
--  La perizia
-- ---------------------------------------------------------------------------
SIN.Perizia = {
    -- Il danno si stima sulla carrozzeria: quanto vale un punto di
    -- danno, in centesimi, per fascia di valore del veicolo.
    perPuntoDanno = 420,

    -- Quota del valore del veicolo oltre la quale il danno è totale e
    -- il mezzo si dichiara non riparabile
    sogliaAntieconomico = 0.65,

    durataSecondi = 30,
    compensoPerito = 14000,

    -- Lo scarto ammesso fra quello che il danneggiato dichiara e quello
    -- che il perito misura. Oltre, è frode.
    scartoAmmesso = 0.45,

    reatoFrode = '642',
}

-- ---------------------------------------------------------------------------
--  La liquidazione
-- ---------------------------------------------------------------------------
SIN.Liquidazione = {
    -- Quanto della perizia la compagnia riconosce davvero. Non è mai
    -- cento: c'è sempre qualcosa che "non è riconducibile al sinistro".
    quotaRiconosciuta = 0.80,

    -- La franchigia che resta comunque a carico
    franchigia = 25000,

    -- Peggioramento della classe di merito per chi ha torto
    passiClasseMerito = 2,
    passiConcorso = 1,

    -- Chi non è assicurato paga tutto di tasca sua, e senza sconti
    quotaNonAssicurato = 1.0,
}

-- ---------------------------------------------------------------------------
--  Chi ha torto
-- ---------------------------------------------------------------------------
SIN.Responsabilita = {
    { id = 'a', nome = 'Ha torto il primo conducente' },
    { id = 'b', nome = 'Ha torto il secondo conducente' },
    { id = 'concorso', nome = 'Concorso di colpa' },
}
