--[[
    AUREA · Economia — configurazione

    Il prezzo di un bene si muove per una ragione sola: qualcuno lo ha
    comprato o venduto. Ogni acquisto alza la domanda, ogni conferimento
    alza l'offerta, e il rapporto fra le due determina il prezzo entro i
    limiti fissati per quel bene. Nessun prezzo casuale.
]]

ECO = {}

ECO.Ciclo = {
    -- Ogni quanti minuti reali il listino viene ricalcolato
    minuti = 10,
    -- Quanto domanda e offerta tornano verso l'equilibrio a ogni ciclo
    ritornoEquilibrio = 0.12,
    -- Sensibilità del prezzo allo squilibrio (elasticità)
    elasticita = 0.55,
    -- Variazione massima consentita a ciclo, per evitare oscillazioni brusche
    variazioneMassima = 0.18,
}

ECO.Squilibri = {
    -- Punti di domanda per unità acquistata
    domandaPerUnita = 1.6,
    -- Punti di offerta per unità conferita
    offertaPerUnita = 1.4,
    -- Valori di equilibrio
    equilibrio = 100,
    -- Limiti
    minimo = 20,
    massimo = 400,
}

ECO.Inflazione = {
    -- L'indice dei prezzi si muove con la massa monetaria in circolazione
    massaRiferimento = 500000000,    -- 5.000.000 € fra tutti i giocatori
    -- Quanto l'indice reagisce allo scostamento
    sensibilita = 0.35,
    -- Limiti dell'indice (100 = base)
    minimo = 80,
    massimo = 160,
    -- L'indice modula i prezzi al consumo
    pesoSuiPrezzi = 0.6,
}

--- Effetti degli eventi ambientali sul listino
ECO.EffettiEvento = {
    prezzi  = { descrizione = 'Prezzi al dettaglio ridotti' },
    domanda = { descrizione = 'Domanda in aumento sui prodotti tipici' },
    lavoro  = { descrizione = 'Compensi del lavoro aumentati' },
}

--- Bacheca del listino consultabile in gioco
ECO.Bacheca = {
    nome = 'Borsa Merci',
    coord = vector3(-1084.5, -1246.0, 5.6),
    blip = { sprite = 108, colore = 46, scala = 0.7 },
}

--- Calcola il nuovo prezzo dato lo squilibrio fra domanda e offerta.
function ECO.NuovoPrezzo(prezzoBase, prezzoAttuale, domanda, offerta, indice, minMult, maxMult)
    -- rapporto: >1 domanda supera l'offerta, <1 il contrario
    local rapporto = (domanda + 1) / (offerta + 1)

    -- l'elasticità smorza la reazione
    local obiettivo = prezzoBase * (rapporto ^ ECO.Ciclo.elasticita)

    -- l'indice dei prezzi trascina tutto il listino
    obiettivo = obiettivo * (1 + ((indice - 100) / 100) * ECO.Inflazione.pesoSuiPrezzi)

    -- si limita l'escursione a ciclo
    local massimoPasso = prezzoAttuale * ECO.Ciclo.variazioneMassima
    local delta = obiettivo - prezzoAttuale
    if delta > massimoPasso then delta = massimoPasso end
    if delta < -massimoPasso then delta = -massimoPasso end

    local nuovo = prezzoAttuale + delta

    -- si resta dentro i limiti fissati per il bene
    return math.floor(math.max(prezzoBase * minMult, math.min(prezzoBase * maxMult, nuovo)))
end
