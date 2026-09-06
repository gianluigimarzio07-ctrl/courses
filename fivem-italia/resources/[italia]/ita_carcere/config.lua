--[[
    AUREA · Casa Circondariale — configurazione

    La pena la gestisce già ita_giustizia: quanto dura, come scorre, come
    si riduce lavorando, come si esce su cauzione. Qui non si tocca niente
    di tutto questo.

    Quello che manca è la vita dentro, ed è la parte che decide se il
    carcere è una punizione o solo un timer da guardare. Dentro non hai i
    tuoi soldi: hai il peculio, che è un conto amministrato dalla direzione
    e si spende solo al sopravvitto. Non hai la tua roba: è depositata
    all'ufficio matricola e te la ridanno all'uscita. Puoi ricevere
    colloqui, ma li deve autorizzare l'istituto. Ti possono perquisire la
    cella, e se ti trovano qualcosa che non dovresti avere finisci in
    isolamento.

    E da qui si può scappare, ma serve roba che dentro non c'è: qualcuno
    da fuori deve fartela arrivare, e quel qualcuno rischia l'art. 385
    quanto te.
]]

CAR = {}

CAR.Lavoro = 'penitenziaria'

-- ---------------------------------------------------------------------------
--  Ufficio matricola: entrata e uscita
-- ---------------------------------------------------------------------------
CAR.Matricola = {
    nome = 'Ufficio matricola',
    coord = vector3(1779.5, 2596.4, 45.8),

    -- Quello che il detenuto tiene con sé. Tutto il resto va in deposito
    -- e gli viene restituito all'uscita.
    ammessiInCella = {
        'carta_identita', 'tessera_sanitaria', 'giornale',
        'antidolorifico', 'ansiolitico', 'antibiotico',
    },

    -- I contanti diventano peculio: dentro non circola denaro
    contantiInPeculio = true,
}

-- ---------------------------------------------------------------------------
--  Sopravvitto — lo spaccio interno
--
--  Prezzi più alti del fuori, perché è così che funziona e perché il
--  peculio deve essere una risorsa scarsa.
-- ---------------------------------------------------------------------------
CAR.Sopravvitto = {
    nome = 'Sopravvitto',
    coord = vector3(1774.8, 2545.0, 45.8),
    orario = { da = 9, a = 18 },

    listino = {
        { item = 'acqua',          prezzo = 180 },
        { item = 'espresso',       prezzo = 250 },
        { item = 'panino',         prezzo = 600 },
        { item = 'cornetto',       prezzo = 450 },
        { item = 'giornale',       prezzo = 350 },
        { item = 'antidolorifico', prezzo = 1200 },
        { item = 'crocchette',     prezzo = 400 },
    },
}

-- ---------------------------------------------------------------------------
--  Lavoro penitenziario (art. 20 ord. pen.)
--
--  Il lavoro che riduce la pena sta in ita_giustizia. Quello che si
--  guadagna — la mercede — sta qui, perché finisce sul peculio.
-- ---------------------------------------------------------------------------
CAR.Lavorazione = {
    nome = 'Lavorazione interna',
    coord = vector3(1758.4, 2542.6, 45.8),
    durata = 22000,
    -- Mercede per turno, sul peculio
    mercede = 2200,
    -- Turni consecutivi prima della pausa obbligatoria
    turniPrimaDiRiposo = 6,
    minutiRiposo = 12,
}

-- ---------------------------------------------------------------------------
--  Colloqui (art. 18 ord. pen.)
--
--  Il visitatore deve chiedere l'autorizzazione, la direzione la concede,
--  e il colloquio si svolge in sala colloqui alla presenza degli agenti.
-- ---------------------------------------------------------------------------
CAR.Colloqui = {
    salaAttesa = vector3(1801.0, 2593.7, 45.8),
    sala = vector3(1785.6, 2596.2, 45.8),
    raggio = 6.0,

    -- Quanti colloqui pendenti può avere un detenuto
    massimoPendenti = 3,
    -- Durata di un colloquio autorizzato, in minuti
    durataMinuti = 20,
    -- Il difensore entra senza autorizzazione preventiva (art. 104 c.p.p.)
    lavoriSenzaAutorizzazione = { 'avvocato' },
}

-- ---------------------------------------------------------------------------
--  Perquisizione e sanzioni disciplinari
-- ---------------------------------------------------------------------------
CAR.Disciplina = {
    -- Cosa non si può avere dentro. Tutto ciò che non è in
    -- CAR.Matricola.ammessiInCella è già irregolare, ma questi sono i
    -- casi che fanno scattare l'isolamento.
    gravi = {
        'telefono', 'grimaldello', 'spadino', 'tronchesi', 'esplosivo',
        'arma', 'cartuccia', 'erba', 'hashish', 'cocaina', 'eroina', 'mdma',
        'sostanza_raffinata', 'documento_falso', 'corda', 'chiave_inglese',
    },

    -- Isolamento (art. 39 ord. pen.): minuti in cui la pena scorre ma
    -- non si può uscire dalla cella di isolamento
    minutiIsolamento = 15,
    minutiIsolamentoGrave = 35,
    cellaIsolamento = vector4(1746.1, 2560.2, 45.7, 180.0),

    -- Il rinvenimento di stupefacenti o armi non è solo disciplinare
    reatoStupefacenti = 'dpr73l',
    reatoArmi = '697',
}

-- ---------------------------------------------------------------------------
--  Evasione
--
--  Non basta camminare fuori dal perimetro: quello lo punisce già
--  ita_giustizia con l'aumento di pena. Qui c'è la via d'uscita vera, e
--  costa fatica e complicità.
-- ---------------------------------------------------------------------------
CAR.Evasione = {
    -- I punti da cui si può lavorare per uscire
    varchi = {
        {
            id = 'grata_officina', nome = 'Grata dell\'officina',
            coord = vector3(1758.9, 2536.2, 45.7),
            attrezzo = 'tronchesi', durata = 45000,
            -- Probabilità che gli agenti se ne accorgano mentre lavori
            probabilitaAvvistamento = 45,
        },
        {
            id = 'muro_cortile', nome = 'Muro di cinta, lato cortile',
            coord = vector3(1791.4, 2531.6, 45.7),
            attrezzo = 'corda', durata = 38000,
            probabilitaAvvistamento = 60,
        },
        {
            id = 'condotta', nome = 'Condotta di scarico',
            coord = vector3(1741.6, 2571.0, 45.7),
            attrezzo = 'chiave_inglese', durata = 60000,
            probabilitaAvvistamento = 28,
        },
    },

    -- Dove si sbuca
    uscita = vector4(1698.6, 2513.1, 45.6, 210.0),

    -- L'attrezzo si consuma sempre: si esce una volta sola per attrezzo
    consumaAttrezzo = true,

    -- Chi evade davvero non prende solo l'aumento di pena: prende il
    -- fascicolo e resta ricercato
    reato = '385',
    -- Minuti aggiunti alla pena residua se ripreso
    aggravioPena = 90,
}

-- ---------------------------------------------------------------------------
--  Contrabbando
--
--  Chi porta roba dentro rischia quanto chi la riceve.
-- ---------------------------------------------------------------------------
CAR.Contrabbando = {
    -- I punti dove si può passare qualcosa attraverso la recinzione
    punti = {
        { nome = 'Recinzione lato nord', coord = vector3(1793.2, 2586.3, 45.7) },
        { nome = 'Recinzione lato officina', coord = vector3(1750.6, 2536.9, 45.7) },
    },
    raggio = 3.0,
    durata = 8000,
    -- Probabilità che una telecamera riprenda il passaggio
    probabilitaRipreso = 35,
    reatoComplice = '378',
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------

--- L'oggetto resta al detenuto o va in deposito?
function CAR.AmmessoInCella(nome)
    for _, n in ipairs(CAR.Matricola.ammessiInCella) do
        if n == nome then return true end
    end
    return false
end

--- Il rinvenimento è grave (isolamento lungo e fascicolo) o no?
function CAR.EGrave(nome)
    for _, n in ipairs(CAR.Disciplina.gravi) do
        if n == nome then return true end
    end
    return false
end

function CAR.GetVarco(id)
    for _, v in ipairs(CAR.Evasione.varchi) do
        if v.id == id then return v end
    end
    return nil
end

function CAR.PrezzoSopravvitto(item)
    for _, r in ipairs(CAR.Sopravvitto.listino) do
        if r.item == item then return r.prezzo end
    end
    return nil
end
