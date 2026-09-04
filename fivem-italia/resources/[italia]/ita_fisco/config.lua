--[[
    AUREA · Fisco — configurazione

    Il denaro che esce dall'economia non svanisce: confluisce nell'erario,
    che a sua volta finanzia stipendi pubblici e sussidi. È questo a rendere
    l'economia del server chiusa invece che inflazionistica.
]]

FISCO = {}

-- ---------------------------------------------------------------------------
--  IRPEF a scaglioni (aliquote applicate al reddito del periodo)
-- ---------------------------------------------------------------------------
FISCO.Irpef = {
    scaglioni = {
        { fino = 2800000,  aliquota = 0.23 },   -- fino a 28.000 €
        { fino = 5000000,  aliquota = 0.35 },   -- fino a 50.000 €
        { fino = math.huge, aliquota = 0.43 },
    },
    -- Detrazione fissa per lavoro dipendente
    detrazione = 190000,
}

-- ---------------------------------------------------------------------------
--  IVA
-- ---------------------------------------------------------------------------
FISCO.Iva = {
    ordinaria = 22,
    ridotta   = 10,     -- ristorazione, trasporti
    minima    = 4,      -- beni di prima necessità
    -- Aliquota per categoria di oggetto
    perCategoria = {
        cibo = 4, bevande = 10, alcolici = 22, materiali = 22, sanita = 10,
        elettronica = 22, moda = 22, attrezzi = 22, documenti = 0, varie = 22,
        armi = 22, contenitori = 22, servizio = 22, illegale = 22,
    },
    -- Liquidazione periodica
    periodicitaMinuti = 180,
}

-- ---------------------------------------------------------------------------
--  Regimi d'impresa
-- ---------------------------------------------------------------------------
FISCO.Regimi = {
    forfettario = {
        etichetta = 'Regime forfettario',
        descrizione = 'Imposta sostitutiva del 15% sul fatturato. Nessuna IVA da versare.',
        aliquota = 0.15,
        applicaIva = false,
        limiteFatturato = 8500000,   -- 85.000 €
    },
    ordinario = {
        etichetta = 'Regime ordinario',
        descrizione = 'IRES al 24% sugli utili e IVA da liquidare periodicamente.',
        aliquota = 0.24,
        applicaIva = true,
        limiteFatturato = math.huge,
    },
}

-- ---------------------------------------------------------------------------
--  Forme societarie: costo di costituzione e capacità
-- ---------------------------------------------------------------------------
FISCO.Forme = {
    ditta_individuale = { etichetta = 'Ditta individuale', costo = 35000,   dipendenti = 3,  capitaleMinimo = 0 },
    snc               = { etichetta = 'S.n.c.',            costo = 120000,  dipendenti = 6,  capitaleMinimo = 0 },
    srl               = { etichetta = 'S.r.l.',            costo = 450000,  dipendenti = 15, capitaleMinimo = 1000000 },
    spa               = { etichetta = 'S.p.A.',            costo = 2800000, dipendenti = 40, capitaleMinimo = 5000000 },
    cooperativa       = { etichetta = 'Cooperativa',       costo = 180000,  dipendenti = 12, capitaleMinimo = 250000 },
}

-- ---------------------------------------------------------------------------
--  Settori di attività: determinano cosa l'impresa può fare
-- ---------------------------------------------------------------------------
FISCO.Settori = {
    { id = 'ristorazione',  etichetta = 'Ristorazione e bar',        ivaVendita = 10 },
    { id = 'commercio',     etichetta = 'Commercio al dettaglio',    ivaVendita = 22 },
    { id = 'agricoltura',   etichetta = 'Agricoltura e allevamento', ivaVendita = 4 },
    { id = 'artigianato',   etichetta = 'Artigianato',               ivaVendita = 22 },
    { id = 'autoriparazione', etichetta = 'Autoriparazione',         ivaVendita = 22 },
    { id = 'trasporti',     etichetta = 'Trasporti e logistica',     ivaVendita = 10 },
    { id = 'servizi',       etichetta = 'Servizi alle imprese',      ivaVendita = 22 },
    { id = 'immobiliare',   etichetta = 'Immobiliare',               ivaVendita = 22 },
    { id = 'moda',          etichetta = 'Moda e sartoria',           ivaVendita = 22 },
    { id = 'intrattenimento', etichetta = 'Intrattenimento',         ivaVendita = 22 },
}

-- ---------------------------------------------------------------------------
--  Tributi ricorrenti
-- ---------------------------------------------------------------------------
FISCO.Tributi = {
    -- Contributi previdenziali sul reddito da lavoro
    inps = { aliquota = 0.09, periodicitaMinuti = 240 },
    -- Imposta sugli immobili diversi dall'abitazione principale
    imu  = { aliquota = 0.0106, periodicitaMinuti = 720, esenteAbitazionePrincipale = true },
    -- Tassa rifiuti, forfettaria per immobile
    tari = { importoBase = 18000, periodicitaMinuti = 720 },
    -- Interessi di mora sui tributi non pagati
    moraGiornaliera = 0.005,
    -- Dopo quanti giorni il tributo diventa cartella esattoriale
    giorniCartella = 30,
    -- Soglia oltre la quale la Guardia di Finanza riceve una segnalazione
    sogliaSegnalazione = 5000000,   -- 50.000 €
}

-- ---------------------------------------------------------------------------
--  Sportelli
-- ---------------------------------------------------------------------------
FISCO.Sportelli = {
    agenziaEntrate = {
        nome = 'Agenzia delle Entrate',
        coord = vector3(-1381.0, -502.2, 32.2),
        blip = { sprite = 407, colore = 5, scala = 0.8 },
    },
    cameraCommercio = {
        nome = 'Camera di Commercio',
        coord = vector3(-1330.4, -519.6, 30.4),
        blip = { sprite = 475, colore = 3, scala = 0.8 },
    },
}

-- ---------------------------------------------------------------------------
--  Calcolo IRPEF a scaglioni
-- ---------------------------------------------------------------------------
function FISCO.CalcolaIrpef(reddito)
    local imposta = 0
    local precedente = 0

    for _, s in ipairs(FISCO.Irpef.scaglioni) do
        if reddito <= precedente then break end
        local imponibile = math.min(reddito, s.fino) - precedente
        imposta = imposta + imponibile * s.aliquota
        precedente = s.fino
    end

    return math.max(0, math.floor(imposta - FISCO.Irpef.detrazione))
end

--- Aliquota IVA applicabile a un oggetto del catalogo.
function FISCO.AliquotaItem(nomeItem)
    local item = AUREA.Item and AUREA.Item[nomeItem]
    if not item then return FISCO.Iva.ordinaria end
    return FISCO.Iva.perCategoria[item.categoria] or FISCO.Iva.ordinaria
end

--- Scorpora l'IVA da un prezzo lordo: restituisce imponibile e imposta.
function FISCO.Scorpora(lordo, aliquota)
    aliquota = aliquota or FISCO.Iva.ordinaria
    local imponibile = math.floor(lordo / (1 + aliquota / 100))
    return imponibile, lordo - imponibile
end
