--[[
    AUREA · Agenzia scommesse — configurazione

    Si scommette su quello che succede davvero nel server: le corse
    organizzate dai giocatori, e gli incontri che qualcuno indice. Le
    quote non le decide un file: le muove il denaro puntato, come in
    un'agenzia vera.
]]

SCO = {}

SCO.Agenzie = {
    { nome = 'Ricevitoria del centro', coord = vector3(-1090.0, -252.0, 37.8) },
    { nome = 'Ricevitoria del porto',  coord = vector3(1136.0, -982.0, 46.4) },
}

SCO.Blip = { sprite = 617, colore = 2, scala = 0.6 }

SCO.Regole = {
    -- Trattenuta dell'agenzia sul monte premi
    quotaAgenzia = 0.12,
    -- Imposta unica sulle vincite
    aliquotaImposta = 0.20,

    puntataMinima = 50000,
    puntataMassima = 5000000,

    -- Chi apre un evento deposita una cauzione: serve a non aprire e sparire
    cauzioneEvento = 200000,
    -- Un evento resta aperto al massimo così
    minutiMassimi = 120,
    -- Servono almeno due esiti e almeno questo numero di scommesse
    scommesseMinimePerPagare = 3,

    -- Quote iniziali quando nessuno ha ancora puntato
    quotaIniziale = 2.0,
    -- Le quote non scendono sotto questo
    quotaMinima = 1.05,
}

--- Chi può aprire un evento e dichiararne l'esito.
SCO.Organizzatori = {
    -- Chiunque, ma con cauzione. Lo staff può aprirne senza.
    gruppoEsente = 'moderatore',
}

function SCO.AgenziaVicina(coord)
    for _, a in ipairs(SCO.Agenzie) do
        if #(coord - a.coord) < 3.0 then return a end
    end
    return nil
end

--- La quota di un esito: monte totale diviso quanto è puntato su quell'esito,
--- al netto della trattenuta. È il sistema del totalizzatore.
function SCO.Quota(montePuntato, monteEsito)
    if monteEsito <= 0 then return SCO.Regole.quotaIniziale end
    local netto = montePuntato * (1 - SCO.Regole.quotaAgenzia)
    return math.max(SCO.Regole.quotaMinima, netto / monteEsito)
end
