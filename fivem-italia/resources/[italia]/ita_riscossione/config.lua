--[[
    AUREA · Agenzia delle Entrate-Riscossione (configurazione)

    CHI ESIGE NON È CHI ACCERTA

    Il server sapeva già iscrivere tributi (ita_fisco) ed emettere verbali
    (ita_codicestrada). Tutti e due, quando nessuno pagava, mandavano una
    cosa chiamata "cartella esattoriale" — e lì finiva. La cartella era una
    notifica sul telefono, e nient'altro. Nessuno veniva mai a prendersi
    i soldi.

    In Italia quel qualcuno esiste, si chiama Agenzia delle Entrate-
    Riscossione, ed è un soggetto DIVERSO da chi ha accertato il debito.
    È una distinzione che sembra formale e invece cambia tutto: l'Agenzia
    delle Entrate decide QUANTO devi, l'agente della riscossione decide
    COME te li prende.

    E i modi sono quattro, in ordine crescente di fastidio:

    1. LA RATEIZZAZIONE. Chiedi di pagare a rate. Te la danno quasi
       sempre. Ma se salti troppe rate DECADI dal beneficio (art. 19
       D.P.R. 602/1973) e torni al punto di partenza, peggio di prima.

    2. IL FERMO AMMINISTRATIVO. Prima arriva il PREAVVISO: hai trenta
       giorni. Se non paghi, il veicolo è fermo — non "multato": fermo.
       Non lo tiri fuori dal garage.

    3. IL PIGNORAMENTO DELLO STIPENDIO. Presso terzi: non lo chiedono a
       te, lo chiedono al tuo datore di lavoro, che trattiene e versa.
       Il limite è UN QUINTO (art. 545 c.p.c.) e non si tocca: è la
       ragione per cui in busta paga qualcosa arriva sempre.

    4. IL PIGNORAMENTO DEL CONTO. L'ultima, e la più brutale.

    Qui sono implementati tutti e quattro, e il terzo passa davvero dal
    calcolo dello stipendio in aurea_core: il datore di lavoro trattiene
    prima di accreditare.
]]

RIS = {}

RIS.Lavoro = 'agenzia_entrate'
RIS.Permesso = 'riscossione'

-- ---------------------------------------------------------------------------
--  Lo sportello
-- ---------------------------------------------------------------------------
RIS.Sportello = {
    nome = 'Agenzia delle Entrate-Riscossione',
    coord = vector3(-686.4, -142.8, 37.4),
    raggio = 2.3,
    blip = { sprite = 407, colore = 6, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Iscrizione a ruolo
-- ---------------------------------------------------------------------------
RIS.Ruolo = {
    -- Ogni quanto l'agente rastrella quello che è diventato esigibile
    minutiScansione = 6,

    -- Oneri di riscossione (l'aggio): la quota che l'agente trattiene
    -- per il disturbo di venire a prenderseli.
    aggio = 0.06,

    -- Giorni per pagare la cartella prima che diventi esecutiva
    giorniPerPagare = 60,

    -- Sotto questa soglia non si iscrive niente a ruolo: non conviene
    -- nemmeno all'agente.
    sogliaMinima = 5000,
}

-- ---------------------------------------------------------------------------
--  Rateizzazione
-- ---------------------------------------------------------------------------
RIS.Rateizzazione = {
    -- Numero massimo di rate concedibili
    rateMassime = 12,
    -- Minuti fra una rata e l'altra
    minutiPerRata = 25,
    -- Interessi di dilazione sull'intero
    interessi = 0.04,

    -- Rate non pagate dopo le quali si decade dal beneficio. Otto è il
    -- numero vero, e non è mai stato un numero gentile.
    rateDecadenza = 8,

    -- Dopo la decadenza non si può più rateizzare quel ruolo
    riammissione = false,
}

-- ---------------------------------------------------------------------------
--  Misure cautelari ed esecutive
-- ---------------------------------------------------------------------------
RIS.Misure = {
    preavvisoFermo = {
        -- Debito oltre il quale si può fermare un veicolo
        sogliaDebito = 80000,
        -- Minuti fra il preavviso e il fermo vero
        minutiPreavviso = 30,
    },

    ipoteca = {
        -- L'ipoteca non si iscrive per due lire: la soglia vera è
        -- ventimila euro, ed è l'unica garanzia che ha chi possiede casa.
        sogliaDebito = 2000000,
    },

    pignoramentoConto = {
        sogliaDebito = 120000,
        -- Quota del saldo aggredibile in una volta
        quotaMassima = 0.5,
        -- Quello che resta sempre: sotto questa cifra il conto non si tocca
        impignorabile = 30000,
    },

    pignoramentoStipendio = {
        sogliaDebito = 50000,
        -- Art. 545 c.p.c.: un quinto, e non uno di più
        quota = 0.20,
    },
}

--- L'importo totale di un ruolo, capitale più aggio.
function RIS.Dovuto(ruolo)
    return math.max(0, (ruolo.importo + ruolo.aggio) - (ruolo.incassato or 0))
end

--- Il piano di rateizzazione: importo di ogni rata, interessi compresi.
function RIS.Piano(dovuto, rate)
    local conInteressi = math.floor(dovuto * (1 + RIS.Rateizzazione.interessi))
    local base = math.floor(conInteressi / rate)
    local resto = conInteressi - (base * rate)
    return base, resto, conInteressi
end
