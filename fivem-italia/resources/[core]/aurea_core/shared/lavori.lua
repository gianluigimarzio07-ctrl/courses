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

-- Chi si è ritirato. Lo stipendio è zero perché il rateo di pensione non
-- è uno stipendio: lo eroga ita_previdenza a parte, calcolato sul montante.
L('pensionato', {
    etichetta = 'Pensionato',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Trattamento di quiescenza', stipendio = 0 },
    },
})

L('edile', {
    etichetta = 'Impresa edile',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Manovale',          stipendio = 9500 },
        [1] = { etichetta = 'Muratore',          stipendio = 13500, permessi = { 'lavora_cantiere' } },
        [2] = { etichetta = 'Capo squadra',      stipendio = 17500, permessi = { 'lavora_cantiere', 'monta_ponteggio' } },
        [3] = { etichetta = 'Preposto',          stipendio = 21000, permessi = { 'lavora_cantiere', 'monta_ponteggio', 'preposto' } },
        [4] = { etichetta = 'Direttore di cantiere', stipendio = 27000,
                permessi = { 'lavora_cantiere', 'monta_ponteggio', 'preposto', 'apri_cantiere', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('immobiliarista', {
    etichetta = 'Agenzia immobiliare',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Collaboratore',  stipendio = 10000 },
        [1] = { etichetta = 'Agente',         stipendio = 14000, permessi = { 'visita', 'pubblica' } },
        [2] = { etichetta = 'Agente senior',  stipendio = 18500, permessi = { 'visita', 'pubblica', 'stima' } },
        [3] = { etichetta = 'Titolare',       stipendio = 24000, permessi = { 'visita', 'pubblica', 'stima', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('vigilanza', {
    etichetta = 'Istituto di vigilanza',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Addetto',        stipendio = 11000 },
        [1] = { etichetta = 'Guardia giurata',stipendio = 15500, permessi = { 'piantonamento', 'portavalori' } },
        [2] = { etichetta = 'Capo servizio',  stipendio = 19500, permessi = { 'piantonamento', 'portavalori', 'assegna' } },
        [3] = { etichetta = 'Direttore',      stipendio = 25000, permessi = { 'piantonamento', 'portavalori', 'assegna', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('agricoltore', {
    etichetta = 'Azienda agricola',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Bracciante',     stipendio = 8500 },
        [1] = { etichetta = 'Coltivatore',    stipendio = 12500, permessi = { 'coltiva' } },
        [2] = { etichetta = 'Conduttore',     stipendio = 16500, permessi = { 'coltiva', 'affitta_podere' } },
        [3] = { etichetta = 'Titolare',       stipendio = 21000, permessi = { 'coltiva', 'affitta_podere', 'pac', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('clero', {
    etichetta = 'Parrocchia',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Sacrestano',     stipendio = 7500,  permessi = { 'mensa' } },
        [1] = { etichetta = 'Diacono',        stipendio = 11000, permessi = { 'mensa', 'rito' } },
        [2] = { etichetta = 'Parroco',        stipendio = 15000, permessi = { 'mensa', 'rito', 'confessione', 'assumi', 'cassa' } },
    },
})

L('pescatore', {
    etichetta = 'Pesca professionale',
    tipo = 'civile',
    gradi = {
        [0] = { etichetta = 'Mozzo',          stipendio = 9000 },
        [1] = { etichetta = 'Pescatore',      stipendio = 13000, permessi = { 'cala' } },
        [2] = { etichetta = 'Comandante',     stipendio = 18000, permessi = { 'cala', 'armatore' } },
        [3] = { etichetta = 'Armatore',       stipendio = 23000, permessi = { 'cala', 'armatore', 'assumi', 'licenzia', 'cassa' } },
    },
})

L('ferroviere', {
    etichetta = 'Ferrovie',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Manovratore',    stipendio = 10500 },
        [1] = { etichetta = 'Capotreno',      stipendio = 14500, permessi = { 'capotreno' } },
        [2] = { etichetta = 'Macchinista',    stipendio = 19000, permessi = { 'capotreno', 'macchinista' } },
        [3] = { etichetta = 'Capo deposito',  stipendio = 24000, permessi = { 'capotreno', 'macchinista', 'assumi', 'licenzia', 'cassa' } },
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
        -- Il notaio è un pubblico ufficiale, non un avvocato: ma tenerlo
        -- come grado dello studio evita un ente da tre persone che non
        -- si riempirebbe mai. Il permesso 'rogito' è quello che conta.
        [3] = { etichetta = 'Notaio',         stipendio = 34000, permessi = { 'consulta_casellario', 'colloquio_detenuto', 'ricorso', 'patteggiamento', 'rogito', 'assumi', 'licenzia', 'cassa' } },
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
        -- 'tulps': le licenze di polizia (passaporto, porto d'armi, DASPO,
        -- licenza di pubblico spettacolo). In Questura le tiene la
        -- Divisione Polizia Amministrativa, non chi sta in volante.
        [3] = { etichetta = 'Ispettore',              stipendio = 25000, permessi = { 'fermo', 'multa', 'perquisizione', 'mdt', 'sequestro', 'arresto', 'armeria', 'indagine', 'tulps' } },
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
        -- 'uif': le segnalazioni di operazione sospetta. Le riceve il
        -- Nucleo Speciale di Polizia Valutaria, non la pattuglia.
        [1] = { etichetta = 'Brigadiere',   stipendio = 19000, permessi = { 'fermo', 'multa', 'mdt', 'verifica_fiscale', 'sequestro', 'uif' } },
        [2] = { etichetta = 'Maresciallo',  stipendio = 23000, permessi = { 'fermo', 'multa', 'mdt', 'verifica_fiscale', 'sequestro', 'arresto', 'congelamento_conti', 'uif' } },
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
        -- 'riscossione': l'Agenzia delle Entrate accerta, l'Agenzia
        -- Entrate-Riscossione esige. Sono due cose diverse e lo sono
        -- anche qui: chi ha questo permesso può iscrivere a ruolo,
        -- rateizzare, chiedere il fermo e il pignoramento.
        [1] = { etichetta = 'Funzionario',     stipendio = 19000, permessi = { 'consulta_fisco', 'accertamento', 'riscossione' } },
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

-- La Prefettura — Ufficio Territoriale del Governo.
--
-- In Italia non è un posto dove si va volentieri: è dove finisce il
-- ricorso contro una multa, dove si decide se ti sospendono la patente,
-- e dove si tiene l'elenco di chi può fare il buttafuori. Tre cose che
-- sembrano scollegate e invece stanno tutte sullo stesso tavolo.
L('prefettura', {
    etichetta = 'Prefettura — U.T.G.',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Istruttore',      stipendio = 14000, permessi = { 'ricorsi' } },
        [1] = { etichetta = 'Viceprefetto',    stipendio = 24000, permessi = { 'ricorsi', 'ordinanze', 'elenco_prefettizio' } },
        [2] = { etichetta = 'Prefetto',        stipendio = 38000, permessi = { 'tutti' } },
    },
})

-- Ispettorato Nazionale del Lavoro.
L('ispettorato', {
    etichetta = 'Ispettorato del Lavoro',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Ispettore',       stipendio = 16000, permessi = { 'accesso_ispettivo' } },
        [1] = { etichetta = 'Ispettore capo',  stipendio = 23000, permessi = { 'accesso_ispettivo', 'sospensione_attivita' } },
        [2] = { etichetta = 'Direttore',       stipendio = 30000, permessi = { 'tutti' } },
    },
})

-- Camera di Commercio: il Registro delle Imprese.
L('camera_commercio', {
    etichetta = 'Camera di Commercio',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Addetto al registro', stipendio = 12500, permessi = { 'registro_imprese' } },
        [1] = { etichetta = 'Conservatore',    stipendio = 21000, permessi = { 'tutti' } },
    },
})

-- Soprintendenza Archeologia, Belle Arti e Paesaggio.
L('soprintendenza', {
    etichetta = 'Soprintendenza',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Funzionario archeologo', stipendio = 15000, permessi = { 'scavo', 'perizia' } },
        [1] = { etichetta = 'Soprintendente',  stipendio = 26000, permessi = { 'tutti' } },
    },
})

-- ---------------------------------------------------------------------------
--  ENTI E ATTIVITÀ PRIVATE
-- ---------------------------------------------------------------------------

-- SIAE. Non è un ente pubblico e non è un'azienda come le altre: è un
-- ente che incassa per conto di chi la musica l'ha scritta, e manda i
-- suoi a controllare che tu il permesso ce l'abbia.
L('siae', {
    etichetta = 'S.I.A.E.',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Mandatario',      stipendio = 13000, permessi = { 'permessi_musica' } },
        [1] = { etichetta = 'Ispettore',       stipendio = 18000, permessi = { 'permessi_musica', 'ispezione' } },
        [2] = { etichetta = 'Direttore di sede', stipendio = 25000, permessi = { 'tutti' } },
    },
})

-- Concessionaria autostradale.
L('autostrade', {
    etichetta = 'Concessionaria autostradale',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Esattore',        stipendio = 11000, permessi = { 'casello' } },
        [1] = { etichetta = 'Ausiliario della viabilità', stipendio = 15000, permessi = { 'casello', 'viabilita' } },
        [2] = { etichetta = 'Capo tratta',     stipendio = 21000, permessi = { 'tutti' } },
    },
})

-- Il locale notturno. L'addetto ai servizi di controllo — il buttafuori —
-- non è un mestiere che si fa e basta: serve l'iscrizione all'elenco
-- tenuto dalla Prefettura, ed è il motivo per cui questo lavoro e la
-- Prefettura si parlano.
L('locale_notturno', {
    etichetta = 'Locale notturno',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Guardaroba',      stipendio = 9500 },
        [1] = { etichetta = 'Barman',          stipendio = 12000, permessi = { 'bar' } },
        [2] = { etichetta = 'Addetto ai servizi di controllo', stipendio = 14000, permessi = { 'bar', 'filtro' } },
        [3] = { etichetta = 'PR',              stipendio = 13000, permessi = { 'bar', 'serata' } },
        [4] = { etichetta = 'Gestore',         stipendio = 24000, permessi = { 'tutti' } },
    },
})

-- A.R.P.A. — l'agenzia regionale per la protezione dell'ambiente.
--
-- Non fa multe da sola: misura. Poi il numero che ha misurato diventa
-- una prescrizione, e se la prescrizione non la ottemperi diventa altro.
L('arpa', {
    etichetta = 'A.R.P.A.',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Tecnico',         stipendio = 15000, permessi = { 'campionamento' } },
        [1] = { etichetta = 'Tecnico capo',    stipendio = 21000, permessi = { 'campionamento', 'prescrizione' } },
        [2] = { etichetta = 'Direttore',       stipendio = 28000, permessi = { 'tutti' } },
    },
})

-- Ser.D. — il servizio per le dipendenze. È un presidio sanitario, non
-- un ufficio di polizia: qui non si punisce, si prova a smettere.
L('serd', {
    etichetta = 'Ser.D.',
    tipo = 'istituzione',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Operatore',       stipendio = 14000, permessi = { 'colloquio' } },
        [1] = { etichetta = 'Responsabile',    stipendio = 23000, permessi = { 'tutti' } },
    },
})

-- C.A.F. e patronato. Un mestiere che in Italia esiste perché la
-- dichiarazione dei redditi da soli non la sa fare quasi nessuno.
L('caf', {
    etichetta = 'C.A.F. e patronato',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Operatore',       stipendio = 11500, permessi = { 'assistenza' } },
        [1] = { etichetta = 'Responsabile del visto', stipendio = 18000, permessi = { 'assistenza', 'visto' } },
        [2] = { etichetta = 'Titolare',        stipendio = 24000, permessi = { 'tutti' } },
    },
})

-- Il perito assicurativo. Decide quanto vale un danno, e dalla sua
-- stima dipende quanto paga la compagnia e quanto sale il premio.
L('perito', {
    etichetta = 'Perito assicurativo',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Perito',          stipendio = 16000, permessi = { 'perizia' } },
        [1] = { etichetta = 'Perito capo',     stipendio = 23000, permessi = { 'perizia', 'liquidazione' } },
        [2] = { etichetta = 'Ispettore di sinistri', stipendio = 29000, permessi = { 'tutti' } },
    },
})

-- Ambulatorio veterinario.
L('veterinario', {
    etichetta = 'Ambulatorio veterinario',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Assistente',      stipendio = 11000 },
        [1] = { etichetta = 'Veterinario',     stipendio = 20000, permessi = { 'visita', 'vaccino', 'microchip' } },
        [2] = { etichetta = 'Direttore sanitario', stipendio = 27000, permessi = { 'tutti' } },
    },
})

-- Tabaccheria. Monopolio di Stato: il tabaccaio non vende, riscuote per
-- conto dello Stato e tiene l'aggio.
L('tabaccaio', {
    etichetta = 'Tabaccheria',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Addetto',         stipendio = 10500, permessi = { 'banco' } },
        [1] = { etichetta = 'Titolare',        stipendio = 18000, permessi = { 'tutti' } },
    },
})

-- Sindacato.
L('sindacato', {
    etichetta = 'Sindacato',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Delegato',        stipendio = 11000, permessi = { 'vertenza' } },
        [1] = { etichetta = 'Segretario',      stipendio = 19000, permessi = { 'vertenza', 'sciopero' } },
        [2] = { etichetta = 'Segretario generale', stipendio = 26000, permessi = { 'tutti' } },
    },
})

-- Aviazione civile.
L('pilota', {
    etichetta = 'Aviazione civile',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Addetto di scalo', stipendio = 12000, permessi = { 'scalo' } },
        [1] = { etichetta = 'Pilota',          stipendio = 22000, permessi = { 'scalo', 'volo' } },
        [2] = { etichetta = 'Comandante',      stipendio = 31000, permessi = { 'tutti' } },
    },
})

-- Sezione del Tiro a Segno Nazionale. Esiste per una ragione sola: il
-- certificato di idoneità al maneggio delle armi, senza il quale la
-- Questura il porto d'armi non lo rilascia e l'istituto di vigilanza
-- non può far girare nessuno armato.
L('tsn', {
    etichetta = 'Tiro a Segno Nazionale',
    tipo = 'civile',
    servizio = true,
    gradi = {
        [0] = { etichetta = 'Istruttore',      stipendio = 13000, permessi = { 'lezione' } },
        [1] = { etichetta = 'Direttore di tiro', stipendio = 19000, permessi = { 'tutti' } },
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
