--[[
    AUREA · Chat di ruolo — configurazione

    Tutto quello che si dice in gioco ha una portata. Il parlato normale si
    sente a pochi metri, un urlo arriva più lontano, un sussurro solo a chi
    ti sta addosso. La radio è l'unica cosa che ignora la distanza, e serve
    un apparecchio per usarla.
]]

CHAT = {}

-- ---------------------------------------------------------------------------
--  Portate in metri
-- ---------------------------------------------------------------------------
CHAT.Portate = {
    sussurro = 3.0,
    normale  = 14.0,
    grido    = 38.0,
    azione   = 18.0,     -- /me e /do
    ooc      = 18.0,
}

-- ---------------------------------------------------------------------------
--  Canali
--  Ogni canale ha colore, prefisso e regole proprie.
-- ---------------------------------------------------------------------------
CHAT.Canali = {
    normale = {
        etichetta = '', colore = { 255, 255, 255 },
        portata = 'normale', corsivo = false,
    },
    grido = {
        etichetta = '[grida]', colore = { 255, 214, 140 },
        portata = 'grido', corsivo = false,
    },
    sussurro = {
        etichetta = '[sussurra]', colore = { 168, 176, 192 },
        portata = 'sussurro', corsivo = false,
    },
    me = {
        etichetta = '', colore = { 194, 141, 255 },
        portata = 'azione', corsivo = true, formato = '%s %s',
    },
    fai = {
        etichetta = '', colore = { 120, 176, 255 },
        portata = 'azione', corsivo = true, formato = '%s (( %s ))',
    },
    ooc = {
        etichetta = '(OOC)', colore = { 150, 155, 165 },
        portata = 'ooc', corsivo = false,
    },
    tentativo = {
        etichetta = '', colore = { 226, 178, 74 },
        portata = 'azione', corsivo = true,
    },
    radio = {
        etichetta = '[RADIO]', colore = { 96, 200, 140 },
        portata = nil, corsivo = false,
    },
    servizio = {
        etichetta = '[SERVIZIO]', colore = { 70, 140, 235 },
        portata = nil, corsivo = false,
    },
}

-- ---------------------------------------------------------------------------
--  Regole
-- ---------------------------------------------------------------------------
CHAT.Regole = {
    -- Lunghezza massima di un messaggio
    lunghezzaMassima = 300,
    -- Messaggi al minuto prima di essere silenziati
    messaggiAlMinuto = 20,
    -- Durata del silenziamento automatico, in secondi
    silenziamento = 30,
    -- Chi è ammanettato o incosciente non può gridare
    bloccaGridoSeFermo = true,
    -- Il testo IC compare anche sopra la testa per qualche secondo
    testoSopraTesta = true,
    durataTestoSopraTesta = 6000,
    -- Le conversazioni finiscono nel registro: serve alla moderazione
    registraSuDatabase = true,
}

-- ---------------------------------------------------------------------------
--  Canali radio: chi può accedere a cosa
-- ---------------------------------------------------------------------------
CHAT.Radio = {
    -- Frequenze riservate, non selezionabili dai civili
    riservate = {
        [1]  = { nome = 'Carabinieri — operativo', lavori = { 'carabinieri' } },
        [2]  = { nome = 'Polizia — operativo',     lavori = { 'polizia' } },
        [3]  = { nome = 'Guardia di Finanza',      lavori = { 'guardia_finanza' } },
        [4]  = { nome = 'Emergenza Sanitaria 118', lavori = { '118' } },
        [5]  = { nome = 'Vigili del Fuoco',        lavori = { 'vigili_fuoco' } },
        [10] = { nome = 'Interforze',              lavori = { 'carabinieri', 'polizia', 'guardia_finanza', '118', 'vigili_fuoco' } },
    },
    -- Intervallo di frequenze libere
    libereDa = 20,
    libereA = 999,
    -- Serve una ricetrasmittente nell'inventario
    richiedeApparecchio = true,
}

--- Verifica se un lavoro può accedere a una frequenza.
function CHAT.PuoUsareFrequenza(frequenza, lavoro)
    local riservata = CHAT.Radio.riservate[frequenza]
    if not riservata then
        return frequenza >= CHAT.Radio.libereDa and frequenza <= CHAT.Radio.libereA
    end
    for _, l in ipairs(riservata.lavori) do
        if l == lavoro then return true end
    end
    return false
end

function CHAT.NomeFrequenza(frequenza)
    local riservata = CHAT.Radio.riservate[frequenza]
    return riservata and riservata.nome or ('Frequenza %d'):format(frequenza)
end
