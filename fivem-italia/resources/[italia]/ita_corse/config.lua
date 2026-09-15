--[[
    AUREA · Corse clandestine — configurazione

    PERCHÉ NON È UNA GARA E BASTA

    C'era il tuning, c'erano le officine clandestine, c'erano macchine
    elaborate. Non c'era niente da farci.

    Una corsa qui non è un minigioco: è un reato che si commette in
    pubblico. L'art. 9-ter del Codice della Strada punisce chi partecipa a
    competizioni di velocità non autorizzate, e prevede una cosa che fa
    male sul serio — la confisca del veicolo. Non la multa: il veicolo.

    E quindi la corsa è una decisione: ci vai con la macchina buona, che
    è quella che ti fa vincere e quella che ti possono portare via.

    COME FUNZIONA

    Qualcuno apre una corsa su un tracciato e mette la quota. Chi vuole
    partecipare paga la stessa quota entro la finestra d'iscrizione. Il
    montepremi è la somma, meno la percentuale di chi ha organizzato.

    Durante la corsa i checkpoint li valida il server confrontando la
    posizione del veicolo: non si passa un checkpoint da fermi, e non si
    salta.

    E le pattuglie la sentono. Una corsa in corso manda una segnalazione
    al 112 come "competizione non autorizzata", con la zona ma non con il
    percorso: sta a loro trovarla.
]]

COR = {}

-- ---------------------------------------------------------------------------
--  I tracciati
--
--  Ogni checkpoint è una coordinata e un raggio. Il primo è la griglia.
-- ---------------------------------------------------------------------------
COR.Tracciati = {
    {
        id = 'porto',
        nome = 'Anello del porto',
        zona = 'Area portuale',
        giri = 2,
        descrizione = 'Rettilinei lunghi e due curve cieche fra i container.',
        checkpoint = {
            vector3(1208.4, -3118.6, 5.5),
            vector3(893.2, -3180.4, 5.9),
            vector3(506.8, -3138.2, 6.1),
            vector3(261.4, -2972.6, 5.9),
            vector3(488.6, -2865.2, 5.7),
            vector3(1012.8, -2938.4, 5.9),
        },
    },
    {
        id = 'collina',
        nome = 'Salita di Vinewood',
        zona = 'Colline di Vinewood',
        giri = 1,
        descrizione = 'Tornanti stretti in salita. Vince chi frena tardi, o chi finisce giù.',
        checkpoint = {
            vector3(-461.2, 1148.6, 325.4),
            vector3(-268.4, 1364.8, 337.2),
            vector3(96.6, 1523.4, 329.8),
            vector3(452.8, 1622.2, 351.4),
            vector3(744.2, 1289.6, 360.1),
            vector3(455.6, 1163.4, 322.8),
        },
    },
    {
        id = 'aeroporto',
        nome = 'Perimetro dell\'aeroporto',
        zona = 'Los Santos International',
        giri = 3,
        descrizione = 'Veloce e piatto. Si vince di potenza, non di manico.',
        checkpoint = {
            vector3(-1038.6, -2734.2, 20.1),
            vector3(-1580.4, -2794.6, 13.9),
            vector3(-1652.8, -3148.4, 13.9),
            vector3(-1226.2, -3392.6, 13.9),
            vector3(-856.4, -3202.8, 13.9),
        },
    },
    {
        id = 'statale',
        nome = 'Statale del Chiliad',
        zona = 'Grand Senora',
        giri = 1,
        descrizione = 'Venti chilometri di niente. Solo tu, la strada e chi ti insegue.',
        checkpoint = {
            vector3(1700.4, 3288.6, 41.1),
            vector3(1225.8, 3546.2, 34.8),
            vector3(586.4, 3510.6, 33.2),
            vector3(-116.2, 3200.8, 30.1),
            vector3(-563.6, 2760.4, 33.8),
            vector3(-980.2, 2650.8, 30.4),
        },
    },
}

function COR.GetTracciato(id)
    for _, t in ipairs(COR.Tracciati) do
        if t.id == id then return t end
    end
end

COR.RaggioCheckpoint = 22.0

-- ---------------------------------------------------------------------------
--  Iscrizioni e montepremi
-- ---------------------------------------------------------------------------
COR.Gara = {
    quotaMinima = 50000,          -- 500 €
    quotaMassima = 5000000,       -- 50.000 €
    -- Quanto trattiene chi organizza
    quotaOrganizzatore = 0.10,
    -- Finestra di iscrizione, in secondi
    iscrizioniSecondi = 120,
    -- Partecipanti
    minimi = 2,
    massimi = 8,
    -- Tempo massimo per chiudere la gara, in minuti
    limiteMinuti = 12,
    -- Quanto si aspetta prima di poterne aprire un'altra
    raffreddamentoMinuti = 15,
}

--- Come si divide il montepremi. Le quote sono sul totale netto.
COR.Podio = { 0.65, 0.25, 0.10 }

-- ---------------------------------------------------------------------------
--  Il rischio
-- ---------------------------------------------------------------------------
COR.Rischio = {
    -- Dopo quanti secondi dalla partenza la segnalazione arriva al 112
    secondiSegnalazione = 35,
    -- Il reato: art. 9-ter CdS, competizione non autorizzata
    articolo = 'art. 9-ter CdS',
    sanzione = 800000,            -- 8.000 €
    puntiPatente = 10,
    -- La confisca del veicolo: è quello che rende la corsa una scelta
    confiscaVeicolo = true,
    -- Sospensione della patente, in minuti
    sospensionePatenteMinuti = 60,
}

--- Il montepremi netto e le quote del podio.
function COR.Montepremi(quota, partecipanti)
    local lordo = quota * partecipanti
    local allOrganizzatore = math.floor(lordo * COR.Gara.quotaOrganizzatore)
    return lordo - allOrganizzatore, allOrganizzatore
end
