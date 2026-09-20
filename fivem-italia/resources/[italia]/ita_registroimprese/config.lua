--[[
    AUREA · Camera di Commercio — Registro delle Imprese (configurazione)

    DUE NUMERI PER LA STESSA DITTA

    Chi apre un'attività in Italia esce con due numeri, dati da due enti
    diversi, che non si parlano quasi mai:

    · la PARTITA IVA, che dà l'Agenzia delle Entrate e serve al fisco;
    · il numero REA, che dà la Camera di Commercio e serve a tutti gli
      altri — a chi vuole sapere chi sei, chi comanda, chi ci ha messo i
      soldi.

    Il server aveva già il primo: ita_fisco apre le imprese e assegna la
    P.IVA. Non aveva il secondo, e senza il secondo mancava una cosa
    semplice e utilissima: un posto dove CHIUNQUE può andare a guardare
    com'è fatta davvero un'impresa. La visura camerale è pubblica, e in
    Italia è lo strumento con cui si scopre che il titolare di comodo ha
    un socio che nessuno si aspettava.

    Qui il Registro non crea imprese: le PRENDE IN CARICO. Lavora sulla
    stessa tabella `imprese`, ci aggiunge il REA, la compagine sociale e
    il diritto annuale.

    E CHI NON PAGA?

    Il diritto annuale è piccolo e nessuno lo ricorda. Chi non lo paga
    finisce SOSPESO dal Registro, e da sospeso non apre cantieri e non
    fa il mediatore. Non è una multa: è non poter lavorare.
]]

REG = {}

REG.Lavoro = 'camera_commercio'
REG.Permesso = 'registro_imprese'

-- ---------------------------------------------------------------------------
--  Lo sportello
-- ---------------------------------------------------------------------------
REG.Sportello = {
    nome = 'Camera di Commercio — Registro delle Imprese',
    coord = vector3(-350.8, -49.2, 49.0),
    raggio = 2.3,
    blip = { sprite = 521, colore = 46, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Iscrizione
-- ---------------------------------------------------------------------------
REG.Iscrizione = {
    -- Diritti di segreteria e bollo
    costo = 13000,
    secondiIstruttoria = 25,
}

-- ---------------------------------------------------------------------------
--  Visura
-- ---------------------------------------------------------------------------
REG.Visura = {
    -- Pubblica, come nella realtà: chiunque può sapere chi c'è dietro
    -- un'impresa. È il contrario del segreto, ed è voluto.
    costo = 5500,
}

-- ---------------------------------------------------------------------------
--  Compagine sociale
-- ---------------------------------------------------------------------------
REG.Soci = {
    -- Le quote sono percentuali: la somma non può superare cento
    quotaMassimaTotale = 100,
    -- Costo del deposito dell'atto che modifica la compagine
    costoDeposito = 7500,
    -- Massimo di soci per impresa
    massimo = 6,
}

-- ---------------------------------------------------------------------------
--  Diritto annuale
-- ---------------------------------------------------------------------------
REG.DirittoAnnuale = {
    -- Ogni quanti minuti si apre un nuovo periodo
    minutiPeriodo = 120,

    -- Quota fissa per le ditte individuali
    quotaFissa = 5300,

    -- Per le società: quota fissa più una frazione del fatturato
    aliquotaFatturato = 0.0015,
    importoMassimo = 120000,

    -- Minuti dalla emissione entro cui pagare, poi si è sospesi
    minutiPerPagare = 60,
}

--- L'importo del diritto annuale per un'impresa.
function REG.Importo(forma, fatturato)
    if forma == 'ditta_individuale' then return REG.DirittoAnnuale.quotaFissa end

    local variabile = math.floor((tonumber(fatturato) or 0) * REG.DirittoAnnuale.aliquotaFatturato)
    return math.min(REG.DirittoAnnuale.quotaFissa + variabile, REG.DirittoAnnuale.importoMassimo)
end
