--[[
    AUREA · Edilizia e sicurezza sul lavoro — configurazione

    IL PUNTO

    Un cantiere non è un posto dove si preme E e cresce un palazzo. È il
    posto dove si intrecciano tre cose che nel server esistevano già
    separate e non si parlavano: il Comune che rilascia i titoli, l'INPS
    che certifica la regolarità contributiva, e la salute di chi lavora.

    Per aprire un cantiere servono tre carte:

        permesso a costruire   dal Comune, con gli oneri di urbanizzazione
        DURC regolare          dall'INPS (ita_previdenza)
        POS                    il piano operativo di sicurezza

    Manca il permesso? Si può costruire lo stesso. Si chiama abuso edilizio,
    art. 44 D.P.R. 380/2001, e finisce con il sequestro del cantiere.

    LA SICUREZZA NON È UN ORPELLO

    Ogni lavorazione senza i DPI previsti alza il RISCHIO del cantiere.
    Sopra soglia, qualcuno si fa male sul serio: parte l'infortunio INAIL,
    il datore ha l'obbligo di denunciarlo entro il termine, e il cantiere
    può essere sospeso dall'ispettorato (art. 14 D.Lgs. 81/2008).

    Lavorare in regola costa tempo e attrezzatura. Lavorare senza costa di
    più, ma dopo — ed è esattamente il punto.
]]

EDI = {}

EDI.Lavoro = 'edile'

-- ---------------------------------------------------------------------------
--  Lo Sportello Unico per l'Edilizia
-- ---------------------------------------------------------------------------
EDI.Sportello = {
    nome = 'Sportello Unico per l\'Edilizia',
    coord = vector3(-546.2, -193.4, 38.2),
    raggio = 2.2,
    blip = { sprite = 566, colore = 46, scala = 0.7 },
}

--- Il deposito da cui l'impresa si rifornisce. Si paga dalla cassa
--- dell'ente: il materiale non lo compra il manovale di tasca sua.
EDI.Fornitore = {
    nome = 'Rivendita di materiali edili',
    coord = vector3(1219.4, 1866.5, 78.8),
    raggio = 3.0,
    blip = { sprite = 473, colore = 46, scala = 0.7 },
    listino = {
        { item = 'cemento',        prezzo = 1200,  quantita = 10 },
        { item = 'sabbia',         prezzo = 700,   quantita = 10 },
        { item = 'mattoni',        prezzo = 1500,  quantita = 10 },
        { item = 'tondino',        prezzo = 2600,  quantita = 5 },
        { item = 'tubo_ponteggio', prezzo = 3100,  quantita = 5 },
        -- I DPI li compra il datore: è un obbligo, non una gentilezza
        { item = 'casco_cantiere', prezzo = 2200,  quantita = 1, dpi = true },
        { item = 'scarpe_antinfortunistiche', prezzo = 4800, quantita = 1, dpi = true },
        { item = 'imbracatura',    prezzo = 9500,  quantita = 1, dpi = true },
        { item = 'gilet_alta_visibilita', prezzo = 1400, quantita = 1, dpi = true },
    },
}

-- ---------------------------------------------------------------------------
--  I lotti edificabili
--
--  Sono posti fissi: un cantiere per lotto, e finché non si consegna il
--  lotto resta occupato. Serve a impedire che mezza città diventi un
--  cantiere perpetuo.
-- ---------------------------------------------------------------------------
EDI.Lotti = {
    {
        id = 'vespucci',
        nome = 'Lotto Vespucci — edificio residenziale',
        coord = vector3(-1300.5, -1150.2, 4.6),
        volumetria = 2400,          -- metri cubi: determina oneri e compenso
        destinazione = 'residenziale',
    },
    {
        id = 'mirror',
        nome = 'Lotto Mirror Park — villetta bifamiliare',
        coord = vector3(1035.8, -450.3, 63.2),
        volumetria = 900,
        destinazione = 'residenziale',
    },
    {
        id = 'cava',
        nome = 'Lotto zona industriale — capannone',
        coord = vector3(2760.4, 1465.8, 24.5),
        volumetria = 4200,
        destinazione = 'produttiva',
    },
    {
        id = 'paleto',
        nome = 'Lotto Paleto — ristrutturazione',
        coord = vector3(-380.2, 6230.6, 31.5),
        volumetria = 600,
        destinazione = 'residenziale',
    },
}

-- ---------------------------------------------------------------------------
--  Il titolo edilizio
-- ---------------------------------------------------------------------------
EDI.Permesso = {
    -- Diritti di segreteria: si pagano al deposito dell'istanza e non
    -- tornano indietro nemmeno se l'istanza viene respinta
    dirittiSegreteria = 8000,

    -- Oneri di urbanizzazione: al metro cubo, alla cassa del Comune
    onerePerMetroCubo = 180,

    -- Silenzio-assenso (art. 20 D.P.R. 380/2001): se gli uffici non
    -- decidono entro il termine, il permesso si intende rilasciato.
    -- Non è una scorciatoia per il server vuoto: è la legge.
    silenzioAssensoMinuti = 20,

    -- Validità del titolo: scaduto, il cantiere va fermato
    validitaMinuti = 240,
}

-- ---------------------------------------------------------------------------
--  Le fasi di un cantiere
--
--  Ogni fase chiede materiali (per unità di lavorazione), un numero di
--  lavorazioni e i DPI previsti. `quota` distribuisce la volumetria fra
--  le fasi e determina il compenso di ciascuna.
-- ---------------------------------------------------------------------------
EDI.Fasi = {
    {
        id = 'scavo', nome = 'Scavo e sbancamento', quota = 0.10,
        lavorazioni = 6, secondi = 9,
        materiali = {},
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche', 'gilet_alta_visibilita' },
        animazione = { dizionario = 'amb@world_human_const_drill@male@drill@base', nome = 'base' },
    },
    {
        id = 'fondazioni', nome = 'Fondazioni', quota = 0.18,
        lavorazioni = 8, secondi = 11,
        materiali = { cemento = 2, sabbia = 2, tondino = 1 },
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche' },
        animazione = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
    },
    {
        id = 'struttura', nome = 'Struttura portante', quota = 0.26,
        lavorazioni = 10, secondi = 12,
        materiali = { cemento = 2, tondino = 2 },
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche', 'imbracatura' },
        richiedePonteggio = true,
        inQuota = true,
        animazione = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
    },
    {
        id = 'tamponamenti', nome = 'Tamponamenti e murature', quota = 0.20,
        lavorazioni = 9, secondi = 10,
        materiali = { mattoni = 3, cemento = 1, sabbia = 1 },
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche', 'imbracatura' },
        richiedePonteggio = true,
        inQuota = true,
        animazione = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
    },
    {
        id = 'impianti', nome = 'Impianti', quota = 0.14,
        lavorazioni = 7, secondi = 10,
        materiali = { rame = 2, plastica = 2 },
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche' },
        animazione = { dizionario = 'amb@world_human_welding@male@base', nome = 'base' },
    },
    {
        id = 'finiture', nome = 'Finiture', quota = 0.12,
        lavorazioni = 6, secondi = 8,
        materiali = { vetro = 1, plastica = 1 },
        dpi = { 'casco_cantiere', 'scarpe_antinfortunistiche' },
        animazione = { dizionario = 'amb@world_human_janitor@male@base', nome = 'base' },
    },
}

-- ---------------------------------------------------------------------------
--  Il ponteggio
-- ---------------------------------------------------------------------------
EDI.Ponteggio = {
    tubiNecessari = 12,
    secondiPerCampata = 7,
    campate = 4,
    -- Lo monta chi ha il permesso: non è un lavoro da manovale
    permesso = 'monta_ponteggio',
}

-- ---------------------------------------------------------------------------
--  Sicurezza e rischio
--
--  Il rischio è un numero da 0 a 100 per cantiere. Sale a ogni lavorazione
--  fatta male e scende da solo quando si lavora in regola.
-- ---------------------------------------------------------------------------
EDI.Sicurezza = {
    -- Quanto sale per ogni DPI mancante, a lavorazione
    perDpiMancante = 7,
    -- Quanto sale se si lavora in quota senza ponteggio
    senzaPonteggio = 18,
    -- Quanto sale se manca il POS
    senzaPos = 4,
    -- Quanto scende per una lavorazione fatta in regola
    inRegola = -3,

    -- Sopra questa soglia ogni lavorazione può finire male
    sogliaInfortunio = 45,
    -- La probabilità, a soglia e a rischio massimo
    probabilitaASoglia = 0.05,
    probabilitaAlMassimo = 0.35,

    -- Il POS: si redige una volta, costa tempo, e vale per il cantiere
    posSecondi = 20,
}

--- Quanto è grave l'infortunio, dato il rischio e se si era in quota.
function EDI.GravitaInfortunio(rischio, inQuota)
    if inQuota and rischio >= 80 then return 'grave' end
    if rischio >= 75 then return 'grave' end
    if rischio >= 60 or inQuota then return 'medio' end
    return 'lieve'
end

EDI.Infortuni = {
    lieve = {
        { testo = 'ha battuto la testa contro un ferro sporgente', danno = 12 },
        { testo = 'si è tagliato una mano su una lamiera', danno = 10 },
        { testo = 'ha inciampato sul materiale lasciato a terra', danno = 8 },
    },
    medio = {
        { testo = 'è stato colpito da un blocco caduto dall\'alto', danno = 32 },
        { testo = 'è scivolato sul ponteggio bagnato', danno = 28 },
        { testo = 'ha preso una scarica dalla linea non sezionata', danno = 30 },
    },
    grave = {
        { testo = 'è caduto dal ponteggio', danno = 62, bloccato = true },
        { testo = 'è rimasto sotto il crollo di una parete', danno = 70, bloccato = true },
        { testo = 'è stato travolto dal carico della gru', danno = 66, bloccato = true },
    },
}

-- ---------------------------------------------------------------------------
--  Compensi
-- ---------------------------------------------------------------------------
EDI.Compensi = {
    -- Alla consegna, al metro cubo, nella cassa dell'impresa
    perMetroCubo = 900,
    -- A ogni lavorazione, in tasca a chi l'ha fatta
    aLavorazione = 2400,
    -- Il collaudo finale, al Comune
    collaudo = 45000,
    -- Chi consegna un cantiere con rischio basso prende un premio:
    -- la sicurezza deve avere un ritorno, non solo un costo evitato
    premioSicurezza = 0.15,
    rischioPerPremio = 15,
}

-- ---------------------------------------------------------------------------
--  Vigilanza
-- ---------------------------------------------------------------------------
EDI.Vigilanza = {
    -- Il Nucleo Ispettorato del Lavoro è un reparto dei Carabinieri
    lavori = { 'carabinieri', 'comune' },

    sanzioni = {
        senzaPermesso  = { importo = 520000, testo = 'abuso edilizio, art. 44 D.P.R. 380/2001' },
        senzaDurc      = { importo = 180000, testo = 'irregolarità contributiva' },
        senzaPos       = { importo = 120000, testo = 'POS mancante, art. 96 D.Lgs. 81/2008' },
        senzaPonteggio = { importo = 260000, testo = 'lavori in quota senza opere provvisionali, art. 122 D.Lgs. 81/2008' },
        dpiMancanti    = { importo = 150000, testo = 'mancata fornitura dei DPI, art. 77 D.Lgs. 81/2008' },
    },

    -- Sospensione dell'attività imprenditoriale (art. 14 D.Lgs. 81/2008):
    -- scatta quando le violazioni gravi superano questa soglia
    violazioniPerSospensione = 2,
    -- Quanto dura, e quanto costa revocarla
    sospensioneMinuti = 30,
    revocaSospensione = 300000,
}

-- ---------------------------------------------------------------------------
--  Aiutanti
-- ---------------------------------------------------------------------------

function EDI.GetLotto(id)
    for _, l in ipairs(EDI.Lotti) do
        if l.id == id then return l end
    end
end

function EDI.GetFase(id)
    for i, f in ipairs(EDI.Fasi) do
        if f.id == id then return f, i end
    end
end

--- La fase successiva, o nil se il cantiere è finito.
function EDI.FaseDopo(id)
    local _, i = EDI.GetFase(id)
    return i and EDI.Fasi[i + 1] or nil
end

--- Percentuale complessiva dato lo stato di avanzamento.
function EDI.Avanzamento(faseId, fatte)
    local completate = 0
    for _, f in ipairs(EDI.Fasi) do
        if f.id == faseId then
            return math.floor((completate + f.quota * (fatte / f.lavorazioni)) * 100)
        end
        completate = completate + f.quota
    end
    return 100
end

--- La probabilità che la prossima lavorazione finisca in infortunio.
function EDI.ProbabilitaInfortunio(rischio)
    local S = EDI.Sicurezza
    if rischio < S.sogliaInfortunio then return 0 end
    local t = (rischio - S.sogliaInfortunio) / math.max(1, 100 - S.sogliaInfortunio)
    return S.probabilitaASoglia + (S.probabilitaAlMassimo - S.probabilitaASoglia) * t
end
