--[[
    AUREA · Lavori e gerarchie

    Ogni lavoro ha gradi progressivi con stipendio orario (in centesimi) e
    permessi. I permessi sono stringhe verificate lato server sull'oggetto
    Giocatore, con g:HaPermessoLavoro('permesso').
]]

AUREA = AUREA or {}
AUREA.Lavori = {}

local function L(nome, dati)
    dati.nome = nome
    AUREA.Lavori[nome] = dati
    return dati
end

-- ---------------------------------------------------------------------------
--  CIVILE
-- ---------------------------------------------------------------------------
L('disoccupato', {
    etichetta = 'Disoccupato',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Nessuna occupazione', stipendio = 3500 },  -- sussidio 35 €/h
    },
})

L('corriere', {
    etichetta = 'Corriere espresso',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Fattorino',      stipendio = 9000 },
        [1] = { etichetta = 'Corriere',       stipendio = 12000 },
        [2] = { etichetta = 'Capo turno',     stipendio = 15500, permessi = { 'gestione_turni' } },
    },
})

L('tassista', {
    etichetta = 'Taxi',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Tassista',       stipendio = 9500 },
        [1] = { etichetta = 'Tassista senior',stipendio = 13000 },
        [2] = { etichetta = 'Titolare licenza', stipendio = 17000, permessi = { 'assumi', 'licenzia', 'cassa' } },
    },
})

L('meccanico', {
    etichetta = 'Officina',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Apprendista',    stipendio = 10000, permessi = { 'ripara' } },
        [1] = { etichetta = 'Meccanico',      stipendio = 14500, permessi = { 'ripara', 'tuning' } },
        [2] = { etichetta = 'Capo officina',  stipendio = 19000, permessi = { 'ripara', 'tuning', 'revisione', 'carroattrezzi' } },
        [3] = { etichetta = 'Titolare',       stipendio = 24000, permessi = { 'ripara', 'tuning', 'revisione', 'carroattrezzi', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('ristoratore', {
    etichetta = 'Ristorazione',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Cameriere',      stipendio = 9000 },
        [1] = { etichetta = 'Cuoco',          stipendio = 13500, permessi = { 'cucina' } },
        [2] = { etichetta = 'Chef',           stipendio = 18000, permessi = { 'cucina', 'menu' } },
        [3] = { etichetta = 'Titolare',       stipendio = 23000, permessi = { 'cucina', 'menu', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('giornalista', {
    etichetta = 'Redazione',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Praticante',     stipendio = 9500,  permessi = { 'pubblica' } },
        [1] = { etichetta = 'Cronista',       stipendio = 14000, permessi = { 'pubblica' } },
        [2] = { etichetta = 'Caporedattore',  stipendio = 20000, permessi = { 'pubblica', 'diretta', 'assumi' } },
    },
})

L('avvocato', {
    etichetta = 'Studio legale',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Praticante',     stipendio = 12000, permessi = { 'consulta_casellario' } },
        [1] = { etichetta = 'Avvocato',       stipendio = 20000, permessi = { 'consulta_casellario', 'colloquio_detenuto', 'ricorso' } },
        [2] = { etichetta = 'Penalista',      stipendio = 28000, permessi = { 'consulta_casellario', 'colloquio_detenuto', 'ricorso', 'patteggiamento' } },
    },
})

-- ---------------------------------------------------------------------------
--  FORZE DELL'ORDINE E SOCCORSO
-- ---------------------------------------------------------------------------
L('carabinieri', {
    etichetta = 'Arma dei Carabinieri',
    tipo = 'forze_ordine',
    ente = 'carabinieri',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Carabiniere',            stipendio = 15000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt' } },
        [1] = { etichetta = 'Appuntato',              stipendio = 17500, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro' } },
        [2] = { etichetta = 'Brigadiere',             stipendio = 20000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto' } },
        [3] = { etichetta = 'Maresciallo',            stipendio = 24000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto', 'armeria' } },
        [4] = { etichetta = 'Luogotenente',           stipendio = 28000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto', 'armeria', 'assumi' } },
        [5] = { etichetta = 'Tenente',                stipendio = 33000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto', 'armeria', 'assumi', 'licenzia' } },
        [6] = { etichetta = 'Capitano',               stipendio = 39000, permessi = { 'tutti' } },
        [7] = { etichetta = 'Comandante di Compagnia',stipendio = 46000, permessi = { 'tutti' } },
    },
})

L('polizia', {
    etichetta = 'Polizia di Stato',
    tipo = 'forze_ordine',
    ente = 'polizia',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Agente',                 stipendio = 15000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt' } },
        [1] = { etichetta = 'Assistente',             stipendio = 17500, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro' } },
        [2] = { etichetta = 'Sovrintendente',         stipendio = 20500, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto' } },
        [3] = { etichetta = 'Ispettore',              stipendio = 25000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto', 'armeria', 'indagine' } },
        [4] = { etichetta = 'Commissario',            stipendio = 32000, permessi = { 'tutti' } },
        [5] = { etichetta = 'Questore',               stipendio = 45000, permessi = { 'tutti' } },
    },
})

L('guardia_finanza', {
    etichetta = 'Guardia di Finanza',
    tipo = 'forze_ordine',
    ente = 'guardia_finanza',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Finanziere',   stipendio = 16000, permessi = { 'fermo', 'multa', 'mdt', 'verifica_fiscale' } },
        [1] = { etichetta = 'Brigadiere',   stipendio = 19000, permessi = { 'fermo', 'multa', 'mdt', 'verifica_fiscale', 'sequestro' } },
        [2] = { etichetta = 'Maresciallo',  stipendio = 23000, permessi = { 'fermo', 'multa', 'mdt', 'verifica_fiscale', 'sequestro', 'arresto', 'congelamento_conti' } },
        [3] = { etichetta = 'Capitano',     stipendio = 34000, permessi = { 'tutti' } },
    },
})

L('118', {
    etichetta = 'Emergenza Sanitaria 118',
    tipo = 'soccorso',
    ente = '118',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Soccorritore',    stipendio = 14000, permessi = { 'stabilizza', 'trasporto' } },
        [1] = { etichetta = 'Infermiere',      stipendio = 18500, permessi = { 'stabilizza', 'trasporto', 'farmaci' } },
        [2] = { etichetta = 'Medico',          stipendio = 26000, permessi = { 'stabilizza', 'trasporto', 'farmaci', 'cartella', 'chirurgia' } },
        [3] = { etichetta = 'Primario',        stipendio = 36000, permessi = { 'tutti' } },
    },
})

L('vigili_fuoco', {
    etichetta = 'Vigili del Fuoco',
    tipo = 'soccorso',
    ente = 'vigili_fuoco',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Vigile',          stipendio = 14500, permessi = { 'estinzione', 'estricazione' } },
        [1] = { etichetta = 'Capo squadra',    stipendio = 19000, permessi = { 'estinzione', 'estricazione', 'coordinamento' } },
        [2] = { etichetta = 'Capo reparto',    stipendio = 25000, permessi = { 'tutti' } },
    },
})

-- ---------------------------------------------------------------------------
--  ISTITUZIONI
-- ---------------------------------------------------------------------------
L('comune', {
    etichetta = 'Comune',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Impiegato',       stipendio = 12000, permessi = { 'anagrafe' } },
        [1] = { etichetta = 'Funzionario',     stipendio = 17000, permessi = { 'anagrafe', 'licenze', 'permessi_ztl' } },
        [2] = { etichetta = 'Dirigente',       stipendio = 24000, permessi = { 'anagrafe', 'licenze', 'permessi_ztl', 'urbanistica' } },
        [3] = { etichetta = 'Sindaco',         stipendio = 35000, permessi = { 'tutti' } },
    },
})

L('agenzia_entrate', {
    etichetta = 'Agenzia delle Entrate',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Operatore',       stipendio = 13000, permessi = { 'consulta_fisco' } },
        [1] = { etichetta = 'Funzionario',     stipendio = 19000, permessi = { 'consulta_fisco', 'accertamento' } },
        [2] = { etichetta = 'Direttore',       stipendio = 28000, permessi = { 'tutti' } },
    },
})

L('motorizzazione', {
    etichetta = 'Motorizzazione Civile',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Esaminatore',     stipendio = 14000, permessi = { 'esame_patente', 'immatricola' } },
        [1] = { etichetta = 'Direttore',       stipendio = 22000, permessi = { 'tutti' } },
    },
})

-- ---------------------------------------------------------------------------
--  Helper condivisi
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
--  Servizi pubblici e mestieri
-- ---------------------------------------------------------------------------
L('camionista', {
    etichetta = 'Autotrasporti',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Autista',         stipendio = 11000 },
        [1] = { etichetta = 'Autista esperto', stipendio = 15000 },
        [2] = { etichetta = 'Titolare',        stipendio = 20000, permessi = { 'assumi', 'licenzia' } },
    },
})

L('netturbino', {
    etichetta = 'Nettezza urbana',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Operatore ecologico', stipendio = 10500 },
        [1] = { etichetta = 'Caposquadra',         stipendio = 14000, permessi = { 'gestione_turni' } },
    },
})

L('benzinaio', {
    etichetta = 'Distribuzione carburanti',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Addetto',         stipendio = 11500 },
        [1] = { etichetta = 'Autista cisterna',stipendio = 16000 },
    },
})

L('elettricista', {
    etichetta = 'Rete elettrica',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Operaio',         stipendio = 13000 },
        [1] = { etichetta = 'Tecnico',         stipendio = 18000, permessi = { 'gestione_turni' } },
    },
})

L('autista', {
    etichetta = 'Trasporto pubblico',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Autista di linea', stipendio = 12500 },
        [1] = { etichetta = 'Controllore',      stipendio = 15000, permessi = { 'controllo_titoli' } },
        [2] = { etichetta = 'Capo deposito',    stipendio = 19000, permessi = { 'assumi', 'gestione_turni' } },
    },
})

L('ausiliario', {
    etichetta = 'Ausiliari del traffico',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Ausiliario',       stipendio = 11000, permessi = { 'sosta' } },
        [1] = { etichetta = 'Coordinatore',     stipendio = 15000, permessi = { 'sosta', 'gestione_turni' } },
    },
})

L('barista', {
    etichetta = 'Bar',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Barista',          stipendio = 10000 },
        [1] = { etichetta = 'Titolare',         stipendio = 16000, permessi = { 'assumi', 'cassa' } },
    },
})

L('cuoco', {
    etichetta = 'Cucina',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Aiuto cuoco',      stipendio = 11000 },
        [1] = { etichetta = 'Cuoco',            stipendio = 15500 },
        [2] = { etichetta = 'Chef',             stipendio = 21000, permessi = { 'assumi', 'cassa' } },
    },
})

L('medico', {
    etichetta = 'Medicina di base',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Medico',           stipendio = 22000, permessi = { 'prescrivi', 'cartella' } },
        [1] = { etichetta = 'Primario',         stipendio = 30000, permessi = { 'tutti' } },
    },
})

L('giudice', {
    etichetta = 'Magistratura',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Magistrato',       stipendio = 30000, permessi = { 'udienza', 'sentenza' } },
        [1] = { etichetta = 'Presidente',       stipendio = 40000, permessi = { 'tutti' } },
    },
})

L('penitenziaria', {
    etichetta = 'Polizia Penitenziaria',
    tipo = 'forze_ordine',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Agente',           stipendio = 15000, permessi = { 'fermo', 'perquisizione' } },
        [1] = { etichetta = 'Sovrintendente',   stipendio = 19000, permessi = { 'fermo', 'perquisizione', 'arresto' } },
    },
})

function AUREA.GetLavoro(nome)
    return AUREA.Lavori[nome] or AUREA.Lavori['disoccupato']
end

function AUREA.GetGrado(lavoro, grado)
    local l = AUREA.GetLavoro(lavoro)
    return l.gradi[grado] or l.gradi[0]
end

--- Etichetta leggibile "Polizia di Stato — Ispettore"
function AUREA.EtichettaLavoro(lavoro, grado)
    local l = AUREA.GetLavoro(lavoro)
    local g = AUREA.GetGrado(lavoro, grado)
    return ('%s — %s'):format(l.etichetta, g.etichetta)
end

--- true se il grado indicato possiede il permesso (o 'tutti')
function AUREA.GradoHaPermesso(lavoro, grado, permesso)
    local g = AUREA.GetGrado(lavoro, grado)
    for _, p in ipairs(g.permessi or {}) do
        if p == 'tutti' or p == permesso then return true end
    end
    return false
end

--- Lavori che appartengono alle forze dell'ordine
function AUREA.EForzaOrdine(lavoro)
    local l = AUREA.Lavori[lavoro]
    return l ~= nil and l.tipo == 'forze_ordine'
end

function AUREA.ESoccorso(lavoro)
    local l = AUREA.Lavori[lavoro]
    return l ~= nil and l.tipo == 'soccorso'
end

return AUREA.Lavori
