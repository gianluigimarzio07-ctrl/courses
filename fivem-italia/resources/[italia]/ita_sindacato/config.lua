--[[
    AUREA · Sindacato (configurazione)

    L'ALTRA METÀ DEL LAVORO

    Il server ha l'Ispettorato, che controlla dall'alto, e ha le
    aziende, che pagano. Non aveva la terza parte, quella che in Italia
    è nata prima delle altre due: i lavoratori che si mettono d'accordo
    fra loro.

    LA VERTENZA

    Un delegato la apre contro un mestiere — non contro una persona,
    contro un mestiere — su una di quattro cose: retribuzione,
    sicurezza, orario, licenziamento. Poi serve che gli altri
    aderiscano, e questo è tutto il punto: una vertenza a cui nessuno
    aderisce non è una vertenza, è una lamentela.

    LO SCIOPERO

    Raggiunte abbastanza adesioni, il sindacato può proclamarlo. Durante
    lo sciopero chi aderisce non lavora e non guadagna — riceve
    l'indennità dal fondo, che è molto meno dello stipendio. In cambio
    la CASSA di quel mestiere si svuota, perché un'attività ferma non
    incassa.

    È una partita a chi resiste di più, ed è esattamente quello che uno
    sciopero è: costa a tutti e due, e vince chi può permetterselo più a
    lungo.

    L'ACCORDO

    Se la vertenza si chiude bene, gli arretrati li paga la cassa
    dell'attività a chi ha aderito. Se si chiude male, chi ha scioperato
    ha perso delle ore e basta.

    Anche questo è realistico, e anche questo è il motivo per cui in
    Italia scioperare non è gratis per nessuno.
]]

SIND = {}

SIND.Lavoro = 'sindacato'

SIND.Camera = {
    nome = 'Camera del lavoro',
    coord = vector3(-1090.4, -806.2, 19.3),
    raggio = 2.4,
    blip = { sprite = 407, colore = 1, scala = 0.65 },
}

--- Le sigle. Non cambiano niente meccanicamente: cambiano a chi versi
--- la quota, e ogni tanto quello basta a litigare.
SIND.Sigle = {
    { id = 'cgil', nome = 'C.G.I.L.' },
    { id = 'cisl', nome = 'C.I.S.L.' },
    { id = 'uil',  nome = 'U.I.L.' },
}

SIND.Iscrizione = {
    quota = 4500,
    minutiValidita = 240,
}

-- ---------------------------------------------------------------------------
--  Vertenze
-- ---------------------------------------------------------------------------
SIND.Vertenza = {
    oggetti = {
        { id = 'retribuzione',  nome = 'Adeguamento della retribuzione',
          arretrati = 180000,
          descrizione = 'Gli stipendi non seguono il costo della vita.' },
        { id = 'sicurezza',     nome = 'Condizioni di sicurezza',
          arretrati = 90000,
          descrizione = 'Si lavora in condizioni che nessuno ha mai verificato.' },
        { id = 'orario',        nome = 'Orario di lavoro',
          arretrati = 120000,
          descrizione = 'Turni che non finiscono mai.' },
        { id = 'licenziamento', nome = 'Licenziamento illegittimo',
          arretrati = 260000,
          descrizione = 'Qualcuno è stato mandato via e non doveva.' },
    },

    -- Quanto resta aperta prima di decadere
    minutiDurata = 90,

    -- Adesioni necessarie per poter proclamare lo sciopero
    adesioniPerSciopero = 3,

    -- Adesioni necessarie perché la vertenza si chiuda con un accordo
    adesioniPerAccordo = 5,

    -- Solo gli iscritti aderiscono. Sembra una formalità, è la ragione
    -- per cui i sindacati raccolgono quote.
    richiedeIscrizione = true,
}

function SIND.GetOggetto(id)
    for _, o in ipairs(SIND.Vertenza.oggetti) do
        if o.id == id then return o end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Sciopero
-- ---------------------------------------------------------------------------
SIND.Sciopero = {
    minutiDurata = 20,

    -- L'indennità dal fondo, per chi aderisce. Molto meno di quello che
    -- si perde: gli scioperi costano a chi li fa.
    indennita = 22000,

    -- Quanto si svuota la cassa dell'attività, per ogni minuto di
    -- sciopero e per ogni aderente
    dannoAlMinuto = 3200,

    -- I mestieri che non si possono fermare. In Italia si chiamano
    -- servizi pubblici essenziali (L. 146/1990) e hanno la precettazione.
    nonScioperabili = {
        'carabinieri', 'polizia', 'guardia_finanza', '118', 'vigili_fuoco',
        'medico', 'penitenziaria', 'prefettura', 'giudice',
    },
}

function SIND.Scioperabile(lavoro)
    for _, l in ipairs(SIND.Sciopero.nonScioperabili) do
        if l == lavoro then return false end
    end
    return true
end
