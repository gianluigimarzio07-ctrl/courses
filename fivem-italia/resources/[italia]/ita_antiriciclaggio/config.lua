--[[
    AUREA · Antiriciclaggio (configurazione)

    IL VERSAMENTO CHE NESSUNO GUARDAVA DUE VOLTE

    aurea_banca aveva una riga sola di antiriciclaggio: versamento sopra
    soglia, notifica alla Guardia di Finanza, fine. Funziona contro chi
    versa centomila euro in una volta — cioè contro nessuno, perché
    nessuno lo fa.

    Chi ricicla davvero fa l'opposto: versa poco, tante volte, sempre
    sotto la soglia. Si chiama FRAZIONAMENTO, è l'art. 1 del D.Lgs.
    231/2007, ed è l'unico comportamento che una soglia secca non può
    vedere. Per vederlo serve guardare una FINESTRA DI TEMPO invece di
    una singola operazione.

    Questa risorsa fa quello.

    L'ADEGUATA VERIFICA

    E poi c'è il pezzo noioso e fondamentale: l'adeguata verifica della
    clientela. Prima di farti muovere somme rilevanti, la banca deve
    sapere chi sei e da dove vengono i tuoi soldi. Se non lo sa, non
    può eseguire l'operazione — non "non dovrebbe": NON PUÒ, ed è il
    motivo per cui in Italia ti chiedono la fonte del reddito anche
    quando non ha senso.

    Qui la verifica scade, e quando è scaduta le operazioni grosse si
    fermano finché non la rifai. È fastidioso di proposito.

    IL CONGELAMENTO

    La segnalazione di operazione sospetta va alla Guardia di Finanza,
    che può congelare le somme. Il congelamento non è una confisca: ha
    un termine. O entro quel termine si conferma, e allora i soldi si
    perdono, oppure cade e tornano indietro.

    Chi ha versato contanti sporchi (ita_illegale ne produce a valanga)
    scopre che la parte difficile non è farli: è spiegarli.
]]

AML = {}

AML.Lavoro = 'guardia_finanza'

-- ---------------------------------------------------------------------------
--  L'ufficio
-- ---------------------------------------------------------------------------
AML.Nucleo = {
    nome = 'Nucleo di polizia economico-finanziaria',
    coord = vector3(240.6, 220.4, 106.3),
    raggio = 2.4,
    blip = { sprite = 617, colore = 3, scala = 0.65 },
}

--- Dove si fa l'adeguata verifica: allo sportello della banca, che è
--- l'unico posto in cui ha senso farla.
AML.Sportello = {
    coord = vector3(149.2, -1040.6, 29.4),
    raggio = 2.4,
}

-- ---------------------------------------------------------------------------
--  Adeguata verifica
-- ---------------------------------------------------------------------------
AML.Verifica = {
    -- Oltre questa soglia di operazione serve una verifica valida
    sogliaOperazione = 400000,

    -- Per quanti minuti vale la verifica
    minutiValidita = 240,

    -- Le fonti di reddito dichiarabili. Non sono un controllo: sono
    -- quello che poi non torna, se il conto racconta un'altra storia.
    fonti = {
        { id = 'lavoro',     nome = 'Reddito da lavoro' },
        { id = 'impresa',    nome = 'Ricavi d\'impresa' },
        { id = 'immobili',   nome = 'Redditi da immobili' },
        { id = 'eredita',    nome = 'Successione o donazione' },
        { id = 'risparmio',  nome = 'Risparmi pregressi' },
        { id = 'vincite',    nome = 'Vincite al gioco' },
    },

    -- Il profilo di rischio che il funzionario assegna. Da quello
    -- dipende quanto stretta è la maglia.
    soglie = {
        basso = 900000,
        medio = 500000,
        alto  = 200000,
    },
}

function AML.GetFonte(id)
    for _, f in ipairs(AML.Verifica.fonti) do
        if f.id == id then return f end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Frazionamento
-- ---------------------------------------------------------------------------
AML.Frazionamento = {
    -- La finestra in cui si sommano le operazioni
    minutiFinestra = 30,

    -- Sopra questo totale cumulato scatta la segnalazione, anche se
    -- nessuna operazione presa da sola superava la soglia.
    sogliaCumulata = 700000,

    -- Quante operazioni servono perché si parli di frazionamento e non
    -- di un cliente che versa due volte
    operazioniMinime = 3,
}

-- ---------------------------------------------------------------------------
--  Congelamento
-- ---------------------------------------------------------------------------
AML.Congelamento = {
    -- Quanto dura il blocco prima di cadere da solo
    minutiDurata = 90,

    -- Quota massima del saldo che si può bloccare
    quotaMassima = 0.75,

    -- Serve un fascicolo aperto per confermare il congelamento in
    -- confisca: senza, le somme tornano.
    reatoRiciclaggio = '648b',
}

-- ---------------------------------------------------------------------------
--  Limite al contante fra privati (art. 49)
-- ---------------------------------------------------------------------------
AML.Contante = {
    -- Oltre questa cifra un pagamento in contanti fra privati è
    -- vietato. Non è una tassa: è un divieto, e chi lo viola paga
    -- entrambi, chi dà e chi riceve.
    limite = 500000,
    sanzione = 300000,

    -- Il contante sporco pesa doppio: versarlo è già di per sé
    -- un'operazione da segnalare, qualunque sia l'importo.
    itemSporco = 'contanti_sporchi',
}
