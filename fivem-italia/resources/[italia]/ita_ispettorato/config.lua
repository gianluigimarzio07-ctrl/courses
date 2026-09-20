--[[
    AUREA · Ispettorato Nazionale del Lavoro (configurazione)

    LA COSA CHE NESSUNO CONTROLLAVA

    Il server aveva le imprese (ita_fisco), i dipendenti, i contributi
    (ita_previdenza) e il DURC. Aveva tutto il lato formale del lavoro.
    Quello che non aveva era qualcuno che andasse a vedere se le persone
    che stanno lavorando in un posto sono le stesse che risultano assunte.

    In Italia quel qualcuno esiste e si chiama Ispettorato. Arriva senza
    avvisare, conta le persone presenti, e le confronta con le carte. La
    differenza fra i due numeri è il LAVORO NERO, e ha un prezzo preciso:
    la MAXISANZIONE (art. 3 D.L. 12/2002), che si paga a testa.

    LA SOSPENSIONE

    Ma la maxisanzione è la parte meno grave. Se i lavoratori irregolari
    superano una quota dei presenti, l'Ispettorato SOSPENDE L'ATTIVITÀ
    (art. 14 D.Lgs. 81/2008). Non è una multa: è una serranda abbassata.
    Nessuno di quel lavoro può più mettersi in servizio, e la revoca si
    paga a parte.

    Questa è l'unica risorsa del server che può fermare un intero mestiere,
    ed è agganciata direttamente a `Giocatore:ImpostaServizio` in
    aurea_core: quando c'è il provvedimento, non si timbra.

    E IL CAPORALATO

    Se oltre al nero c'è lo sfruttamento — tanti irregolari, pagati sotto
    una soglia — non è più un illecito amministrativo. È l'art. 603-bis
    c.p., intermediazione illecita e sfruttamento del lavoro, e da lì in
    poi se ne occupa la Procura.
]]

ISP = {}

ISP.Lavoro = 'ispettorato'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
ISP.Sede = {
    nome = 'Ispettorato Territoriale del Lavoro',
    coord = vector3(-598.2, -930.4, 23.9),
    raggio = 2.4,
    blip = { sprite = 498, colore = 5, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  L'accesso ispettivo
-- ---------------------------------------------------------------------------
ISP.Accesso = {
    -- Raggio entro cui si contano i lavoratori presenti
    raggio = 40.0,

    -- Quanto dura l'accesso, in secondi. Non è veloce: si identificano
    -- tutti, uno per uno.
    durataSecondi = 45,

    -- Quanti minuti devono passare prima di tornare sullo stesso lavoro
    minutiRaffreddamento = 20,

    -- Maxisanzione per lavoratore irregolare. In Italia è una forchetta:
    -- qui il server tira dentro l'intervallo, e chi sbaglia due volte
    -- non ha la fortuna dalla sua.
    maxisanzioneMin = 180000,
    maxisanzioneMax = 1080000,

    -- Quota di irregolari sui presenti oltre la quale scatta la
    -- sospensione dell'attività (art. 14 D.Lgs. 81/2008: il 10%).
    quotaSospensione = 0.10,

    -- Serve almeno questo numero di presenti perché la sospensione abbia
    -- senso: con due persone in tutto, una irregolare è il 50% e non
    -- significa niente.
    presentiMinimiPerSospensione = 3,
}

-- ---------------------------------------------------------------------------
--  Sospensione
-- ---------------------------------------------------------------------------
ISP.Sospensione = {
    -- Quanto costa la revoca del provvedimento. Non è una multa: è la
    -- somma aggiuntiva che si paga per riaprire.
    importoRevoca = 2500000,

    -- Dopo quanti minuti decade da sola, se nessuno la revoca. Serve a
    -- non lasciare un mestiere morto per sempre perché l'ispettore è
    -- andato offline.
    minutiDecadenza = 90,
}

-- ---------------------------------------------------------------------------
--  Caporalato
-- ---------------------------------------------------------------------------
ISP.Caporalato = {
    -- Irregolari da cui in su si ipotizza lo sfruttamento
    irregolariMinimi = 4,

    -- Retribuzione oraria sotto la quale si considera sfruttamento
    -- (art. 603-bis c. 3 n. 1: retribuzione palesemente difforme).
    sogliaRetribuzione = 7000,

    articolo = '603bis',
}

--- I lavori che l'Ispettorato non può sospendere: fermare i carabinieri
--- o il 118 per irregolarità amministrative non è un provvedimento, è un
--- danno. La legge italiana li esclude per la stessa ragione.
ISP.NonSospendibili = {
    'carabinieri', 'polizia', 'guardia_finanza', '118', 'vigili_fuoco',
    'medico', 'giudice', 'penitenziaria', 'ispettorato', 'prefettura',
}

function ISP.Sospendibile(lavoro)
    for _, l in ipairs(ISP.NonSospendibili) do
        if l == lavoro then return false end
    end
    return true
end
