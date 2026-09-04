--[[
    AUREA · 112 NUE — configurazione

    Il 112 è un numero unico: il chiamante non sceglie l'ente, descrive
    l'emergenza. È la centrale che assegna il codice di priorità e smista
    all'ente competente, esattamente come il modello europeo.
]]

NUE = {}

-- ---------------------------------------------------------------------------
--  Codici di priorità (triage sanitario italiano)
-- ---------------------------------------------------------------------------
NUE.Priorita = {
    bianco = { etichetta = 'Codice bianco', descrizione = 'Non urgente',        colore = 0,  attesa = 900 },
    verde  = { etichetta = 'Codice verde',  descrizione = 'Urgenza differibile', colore = 2,  attesa = 600 },
    giallo = { etichetta = 'Codice giallo', descrizione = 'Urgenza indifferibile', colore = 5, attesa = 300 },
    rosso  = { etichetta = 'Codice rosso',  descrizione = 'Emergenza — pericolo di vita', colore = 1, attesa = 120 },
}

-- ---------------------------------------------------------------------------
--  Enti e loro identità operativa
-- ---------------------------------------------------------------------------
NUE.Enti = {
    carabinieri     = { etichetta = 'Carabinieri',       sigla = 'CC',  blip = 60,  colore = 38, icona = '🎖' },
    polizia         = { etichetta = 'Polizia di Stato',  sigla = 'PS',  blip = 60,  colore = 3,  icona = '👮' },
    guardia_finanza = { etichetta = 'Guardia di Finanza',sigla = 'GdF', blip = 60,  colore = 5,  icona = '💼' },
    ['118']         = { etichetta = 'Emergenza Sanitaria', sigla = '118', blip = 61, colore = 1, icona = '🚑' },
    vigili_fuoco    = { etichetta = 'Vigili del Fuoco',  sigla = 'VVF', blip = 436, colore = 47, icona = '🚒' },
}

-- ---------------------------------------------------------------------------
--  Tipologie di intervento
--  Ogni voce dice a chi va la chiamata e con quale codice.
-- ---------------------------------------------------------------------------
NUE.Tipologie = {
    -- Sanitarie
    { id = 'malore',        etichetta = 'Malore o perdita di coscienza',   ente = '118',         priorita = 'rosso' },
    { id = 'trauma',        etichetta = 'Caduta o trauma',                 ente = '118',         priorita = 'giallo' },
    { id = 'ferita_arma',   etichetta = 'Ferito da arma da fuoco',         ente = 'multiplo',    priorita = 'rosso', enti = { '118', 'carabinieri' } },
    { id = 'incidente',     etichetta = 'Incidente stradale',              ente = 'multiplo',    priorita = 'giallo', enti = { '118', 'polizia' } },
    { id = 'incidente_grave', etichetta = 'Incidente stradale con feriti gravi', ente = 'multiplo', priorita = 'rosso', enti = { '118', 'polizia', 'vigili_fuoco' } },
    { id = 'intossicazione',etichetta = 'Intossicazione o overdose',       ente = '118',         priorita = 'rosso' },

    -- Ordine pubblico
    { id = 'rissa',         etichetta = 'Rissa o aggressione',             ente = 'carabinieri', priorita = 'giallo' },
    { id = 'furto',         etichetta = 'Furto in corso',                  ente = 'carabinieri', priorita = 'giallo' },
    { id = 'rapina',        etichetta = 'Rapina',                          ente = 'multiplo',    priorita = 'rosso', enti = { 'carabinieri', 'polizia' } },
    { id = 'spari',         etichetta = 'Colpi d\'arma da fuoco',          ente = 'multiplo',    priorita = 'rosso', enti = { 'carabinieri', 'polizia' } },
    { id = 'sospetto',      etichetta = 'Persona o veicolo sospetto',      ente = 'polizia',     priorita = 'verde' },
    { id = 'disturbo',      etichetta = 'Disturbo della quiete',           ente = 'polizia',     priorita = 'bianco' },
    { id = 'sequestro',     etichetta = 'Sequestro di persona',            ente = 'multiplo',    priorita = 'rosso', enti = { 'carabinieri', 'polizia' } },

    -- Soccorso tecnico
    { id = 'incendio',      etichetta = 'Incendio',                        ente = 'multiplo',    priorita = 'rosso', enti = { 'vigili_fuoco', '118' } },
    { id = 'fuga_gas',      etichetta = 'Fuga di gas o sostanze',          ente = 'vigili_fuoco',priorita = 'rosso' },
    { id = 'persona_bloccata', etichetta = 'Persona bloccata o intrappolata', ente = 'multiplo', priorita = 'giallo', enti = { 'vigili_fuoco', '118' } },
    { id = 'crollo',        etichetta = 'Crollo o dissesto',               ente = 'vigili_fuoco',priorita = 'giallo' },

    -- Economico-finanziaria
    { id = 'contraffazione',etichetta = 'Merce contraffatta o abusivismo', ente = 'guardia_finanza', priorita = 'verde' },
    { id = 'riciclaggio',   etichetta = 'Movimenti di denaro sospetti',    ente = 'guardia_finanza', priorita = 'verde' },
}

-- ---------------------------------------------------------------------------
--  Regole operative
-- ---------------------------------------------------------------------------
NUE.Regole = {
    -- Non si può chiamare più di una volta ogni N secondi
    intervalloChiamate = 45,
    -- Le chiamate senza risposta si chiudono da sole dopo N minuti
    scadenzaMinuti = 25,
    -- Le chiamate false costano: sanzione per procurato allarme (art. 658 c.p.)
    sanzioneFalsaChiamata = 41300,
    -- Massimo di interventi contemporaneamente assegnabili a un operatore
    interventiPerOperatore = 3,
    -- Raggio entro cui un intervento è considerato "in posto"
    raggioInPosto = 60.0,
}

-- ---------------------------------------------------------------------------
--  Centrali operative sulla mappa
-- ---------------------------------------------------------------------------
NUE.Centrali = {
    { ente = 'carabinieri',  nome = 'Comando Provinciale Carabinieri', coord = vector3(441.2, -981.5, 30.7) },
    { ente = 'polizia',      nome = 'Questura',                        coord = vector3(-1093.0, -809.1, 19.3) },
    { ente = '118',          nome = 'Centrale Operativa 118',          coord = vector3(305.4, -595.0, 43.3) },
    { ente = 'vigili_fuoco', nome = 'Comando Vigili del Fuoco',        coord = vector3(1193.5, -1473.0, 34.9) },
    { ente = 'guardia_finanza', nome = 'Comando Guardia di Finanza',   coord = vector3(-608.9, -929.7, 23.9) },
}

--- Restituisce gli enti competenti per una tipologia.
function NUE.EntiPer(tipologia)
    if tipologia.enti then return tipologia.enti end
    return { tipologia.ente }
end

function NUE.GetTipologia(id)
    for _, t in ipairs(NUE.Tipologie) do
        if t.id == id then return t end
    end
    return nil
end
