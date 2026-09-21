--[[
    AUREA · C.A.F. e patronato (configurazione)

    L'IRPEF CHE NON TORNAVA MAI INDIETRO

    aurea_core trattiene l'IRPEF su ogni busta paga: aliquota secca, 23%
    o 27% a seconda del lordo, e via. È la ritenuta alla fonte, e in
    Italia funziona esattamente così — con una differenza fondamentale
    che il server non aveva:

        LA RITENUTA È UN ACCONTO, NON L'IMPOSTA.

    L'imposta vera si calcola a fine periodo, su TUTTO il reddito, con
    gli SCAGLIONI progressivi, e togliendo le DETRAZIONI. Poi si fa la
    differenza con quello che è già stato trattenuto: se hai versato di
    più, ti torna indietro; se hai versato di meno, paghi il saldo.

    Questo si chiama CONGUAGLIO, ed è il motivo per cui a giugno in
    Italia qualcuno riceve dei soldi e non sa bene perché.

    LE DETRAZIONI

    Sono il pezzo interessante, perché non sono regali: sono spese che
    hai già fatto e che lo Stato ti riconosce in parte. Qui si prendono
    da quello che il server già sa di te:

    · le spese mediche (ita_farmacia, aurea_ospedale),
    · gli interessi sul mutuo (aurea_banca),
    · le spese condominiali straordinarie (ita_condominio),
    · i contributi previdenziali (ita_previdenza).

    Non le dichiara il contribuente a caso: le trova il CAF guardando.

    E CHI BARA?

    Può dichiarare detrazioni che non ha. Il visto di conformità del CAF
    non le controlla tutte, e la dichiarazione passa. Poi però arriva il
    controllo formale dell'Agenzia delle Entrate, e quello sì che
    guarda: quello che non è documentato torna indietro, con la
    sanzione.
]]

CAF = {}

CAF.Lavoro = 'caf'

CAF.Sede = {
    nome = 'C.A.F. e patronato',
    coord = vector3(-540.6, -190.2, 38.2),
    raggio = 2.3,
    blip = { sprite = 498, colore = 26, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  Gli scaglioni IRPEF
--
--  Quelli veri, riscalati sul ritmo di gioco: il reddito di periodo qui
--  è una frazione di un anno, quindi anche le soglie lo sono.
-- ---------------------------------------------------------------------------
CAF.Scaglioni = {
    { fino = 2800000,  aliquota = 0.23 },
    { fino = 5000000,  aliquota = 0.35 },
    { fino = math.huge, aliquota = 0.43 },
}

--- L'imposta lorda su un imponibile, a scaglioni.
function CAF.Imposta(imponibile)
    imponibile = math.max(0, math.floor(tonumber(imponibile) or 0))
    local imposta, precedente = 0, 0

    for _, s in ipairs(CAF.Scaglioni) do
        if imponibile <= precedente then break end
        local quota = math.min(imponibile, s.fino) - precedente
        imposta = imposta + math.floor(quota * s.aliquota)
        precedente = s.fino
    end

    return imposta
end

-- ---------------------------------------------------------------------------
--  Detrazioni
-- ---------------------------------------------------------------------------
CAF.Detrazioni = {
    -- Detrazione da lavoro dipendente: spetta a chi ha un reddito e
    -- scende man mano che il reddito sale. È la ragione per cui i
    -- redditi bassi in Italia pagano poco o niente.
    lavoro = {
        importo = 195000,
        azzeramento = 6000000,
    },

    -- Le aliquote di detrazione per tipo di spesa
    aliquote = {
        mediche     = 0.19,
        mutuo       = 0.19,
        condominio  = 0.50,
        previdenza  = 1.00,   -- deducibile, non detraibile: vale tutto
    },

    -- Tetti di spesa detraibile
    tetti = {
        mediche     = 1500000,
        mutuo       = 800000,
        condominio  = 4000000,
    },
}

--- La detrazione per lavoro dipendente, decrescente col reddito.
function CAF.DetrazioneLavoro(reddito)
    local d = CAF.Detrazioni.lavoro
    if reddito <= 0 then return 0 end
    if reddito >= d.azzeramento then return 0 end
    return math.floor(d.importo * (1 - (reddito / d.azzeramento)))
end

-- ---------------------------------------------------------------------------
--  Il periodo d'imposta
-- ---------------------------------------------------------------------------
CAF.Periodo = {
    -- Quanti minuti dura un periodo d'imposta
    minutiDurata = 180,

    -- Quanto costa l'assistenza del CAF
    compenso = 9800,

    -- Quota del compenso che resta all'operatore
    quotaOperatore = 0.35,

    secondiCompilazione = 30,
}

-- ---------------------------------------------------------------------------
--  Controllo formale
-- ---------------------------------------------------------------------------
CAF.Controllo = {
    -- Probabilità che una dichiarazione finisca sotto controllo
    probabilita = 30,

    -- Minuti dopo la liquidazione entro cui può arrivare
    minutiDopo = 45,

    -- Sanzione sulle detrazioni non documentate
    sanzione = 0.30,
}
