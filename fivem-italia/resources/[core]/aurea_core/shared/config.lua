--[[
    AUREA · Italia Roleplay
    Configurazione condivisa del framework.

    Tutti gli importi monetari nel codice sono espressi in CENTESIMI di euro
    (interi). Non usare mai float per il denaro: 12,50 € = 1250.
]]

AUREA = AUREA or {}
AUREA.Config = {}

local C = AUREA.Config

-- ---------------------------------------------------------------------------
--  Identità del server
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
--  Framework
--
--  'nativo'  AUREA gestisce accesso, personaggi, denaro e lavori. È la
--            modalità normale, ed è quella che regge i centesimi interi.
--
--  'esx'     Il vero es_extended è il framework: gestisce lui l'accesso,
--            il denaro e i lavori, e AUREA gli si appoggia sopra tramite
--            [esx]/aurea_esx. In questa modalità aurea_core NON apre la
--            selezione personaggio e non tocca playerConnecting, perché
--            lo fa già ESX: due flussi d'accesso in parallelo si
--            annullerebbero a vicenda.
--
--  Attenzione: [esx]/es_extended (il ponte che espone ESX sopra AUREA) è
--  un'altra cosa e vuole 'nativo'. Vedi docs/ESX.md.
-- ---------------------------------------------------------------------------
C.Framework = 'nativo'

C.Server = {
    nome        = 'AUREA · Italia Roleplay',
    sigla       = 'AUREA',
    fusoOrario  = 'Europe/Rome',
    lingua      = 'it',
    valuta      = '€',
    -- Il tempo di gioco scorre più veloce del reale: 1 minuto reale = N minuti IG
    scalaTempo  = 6,
    -- Slot personaggio di default per account
    slotBase    = 2,
}

-- ---------------------------------------------------------------------------
--  Nuovo personaggio
-- ---------------------------------------------------------------------------
C.Avvio = {
    contanti = 25000,      -- 250,00 €
    banca    = 150000,     -- 1.500,00 €
    posizione = { x = -1037.0, y = -2737.6, z = 20.2, h = 328.0 },  -- Aeroporto
    lavoro   = 'disoccupato',
    -- Item consegnati alla creazione
    corredo = {
        { item = 'carta_identita', quantita = 1 },
        { item = 'telefono',       quantita = 1 },
        { item = 'tessera_sanitaria', quantita = 1 },
        { item = 'acqua',          quantita = 2 },
        { item = 'panino',         quantita = 2 },
    },
}

-- ---------------------------------------------------------------------------
--  Bisogni primari (decadimento per minuto di gioco)
-- ---------------------------------------------------------------------------
C.Stato = {
    fame       = { max = 100, decadimento = 0.30, sogliaDanno = 0 },
    sete       = { max = 100, decadimento = 0.42, sogliaDanno = 0 },
    stress     = { max = 100, crescitaBase = 0.08 },
    -- Danno inflitto ogni tick quando fame o sete sono a zero
    dannoDigiuno = 3,
    tickSecondi  = 60,
}

-- ---------------------------------------------------------------------------
--  Gerarchia permessi staff (dal più basso al più alto)
-- ---------------------------------------------------------------------------
C.Gruppi = {
    utente     = 0,
    supporto   = 10,
    moderatore = 20,
    admin      = 30,
    gestore    = 40,
    fondatore  = 100,
}

-- ---------------------------------------------------------------------------
--  Salvataggi
-- ---------------------------------------------------------------------------
C.Salvataggio = {
    intervalloMinuti = 5,
    salvaAllUscita   = true,
}

-- ---------------------------------------------------------------------------
--  Province italiane usate per generare codici fiscali e codici cittadino
-- ---------------------------------------------------------------------------
C.Province = {
    { sigla = 'RM', comune = 'Roma',     catastale = 'H501' },
    { sigla = 'MI', comune = 'Milano',   catastale = 'F205' },
    { sigla = 'NA', comune = 'Napoli',   catastale = 'F839' },
    { sigla = 'TO', comune = 'Torino',   catastale = 'L219' },
    { sigla = 'PA', comune = 'Palermo',  catastale = 'G273' },
    { sigla = 'BO', comune = 'Bologna',  catastale = 'A944' },
    { sigla = 'FI', comune = 'Firenze',  catastale = 'D612' },
    { sigla = 'BA', comune = 'Bari',     catastale = 'A662' },
    { sigla = 'VE', comune = 'Venezia',  catastale = 'L736' },
    { sigla = 'GE', comune = 'Genova',   catastale = 'D969' },
    { sigla = 'CT', comune = 'Catania',  catastale = 'C351' },
    { sigla = 'CA', comune = 'Cagliari', catastale = 'B354' },
}

-- ---------------------------------------------------------------------------
--  Prefissi telefonici mobili italiani
-- ---------------------------------------------------------------------------
C.PrefissiTelefono = { '320', '328', '333', '335', '338', '340', '342', '345', '347', '349', '366', '388', '391', '393' }

-- ---------------------------------------------------------------------------
--  Numeri di emergenza raggiungibili dal telefono
-- ---------------------------------------------------------------------------
C.Emergenze = {
    ['112'] = 'multiplo',        -- NUE
    ['113'] = 'polizia',
    ['115'] = 'vigili_fuoco',
    ['117'] = 'guardia_finanza',
    ['118'] = '118',
}

-- ---------------------------------------------------------------------------
--  Inventario
-- ---------------------------------------------------------------------------
C.Inventario = {
    slotPersonaggio = 40,
    pesoPersonaggio = 30000,      -- grammi (30 kg)
    slotVeicoloDefault = 25,
    pesoVeicoloDefault = 60000,
    distanzaMassima = 2.5,        -- metri per interazioni con contenitori
    duratsTerra = 30,             -- minuti di persistenza degli oggetti a terra
}

-- ---------------------------------------------------------------------------
--  Registro / logging
-- ---------------------------------------------------------------------------
C.Log = {
    suDatabase = true,
    -- Webhook Discord per canale. Lasciare vuoto per disattivare.
    -- I webhook NON vanno committati: usare server.cfg con setr / convar.
    canali = {
        connessioni  = '',
        denaro       = '',
        inventario   = '',
        veicoli      = '',
        multe        = '',
        giustizia    = '',
        anticheat    = '',
        staff        = '',
        economia     = '',
    },
}

return C
