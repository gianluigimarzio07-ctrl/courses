--[[
    AUREA · A.R.P.A. (configurazione)

    CHI MISURA

    Il server aveva già chi punisce l'inquinamento: ita_rifiuti apre
    fascicoli per gestione non autorizzata, ita_edilizia sospende i
    cantieri, ita_asl chiude i locali sporchi. Quello che non aveva era
    chi MISURA — e senza una misura, l'inquinamento è solo un'opinione.

    L'A.R.P.A. non fa multe e non chiude niente. Fa una cosa sola: va lì
    con uno strumento, legge un numero, e lo confronta con un limite.
    Da quel numero discende tutto il resto, e di solito non è una
    sanzione: è una PRESCRIZIONE.

    LA PRESCRIZIONE

    È il pezzo che rende questa risorsa diversa da un'altra ispezione.
    Un superamento non ti costa subito: ti dà un termine per rientrare.
    Se rientri, non è successo niente. Se il termine scade e sei ancora
    fuori, allora sì — e a quel punto costa più di quanto sarebbe
    costato mettersi a posto.

    È esattamente il meccanismo del D.Lgs. 152/2006, ed è il motivo per
    cui in Italia le aziende che rispettano l'ambiente non sono quelle
    virtuose: sono quelle che hanno fatto due conti.

    COSA SI MISURA

    · EMISSIONI in atmosfera, sui camini dei capannoni;
    · SCARICHI idrici, che ita_rifiuti già tiene in tabella;
    · RUMORE, e qui si misura quello che suona davvero — anche uno
      stereo acceso da aurea_musica;
    · AMIANTO nelle coperture dei cantieri;
    · SUOLO, dove ita_rifiuti ha registrato una discarica abusiva.
]]

ARPA = {}

ARPA.Lavoro = 'arpa'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
ARPA.Sede = {
    nome = 'A.R.P.A. — Dipartimento provinciale',
    coord = vector3(1206.4, -1263.2, 35.2),
    raggio = 2.4,
    blip = { sprite = 568, colore = 2, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  Le matrici
--
--  Ogni tipo di controllo ha un'unità, un limite di legge e uno
--  strumento. Il valore misurato lo estrae il server: il campionamento
--  non è una cosa che il client possa dichiarare.
-- ---------------------------------------------------------------------------
ARPA.Matrici = {
    emissioni = {
        nome = 'Emissioni in atmosfera',
        unita = 'mg/Nm³',
        limite = 150,
        minimo = 20, massimo = 420,
        durataSecondi = 35,
        norma = 'art. 269 D.Lgs. 152/2006',
        sanzione = 280000,
        prescrizione = 'Adeguare l\'impianto di abbattimento e ripresentare l\'autocontrollo.',
    },
    scarico = {
        nome = 'Scarico idrico',
        unita = 'mg/l COD',
        limite = 160,
        minimo = 30, massimo = 600,
        durataSecondi = 30,
        norma = 'art. 137 D.Lgs. 152/2006',
        sanzione = 340000,
        prescrizione = 'Ripristinare il trattamento a monte dello scarico.',
    },
    rumore = {
        nome = 'Rumore ambientale',
        unita = 'dB(A)',
        limite = 65,
        minimo = 35, massimo = 105,
        durataSecondi = 20,
        norma = 'L. 447/1995',
        sanzione = 96000,
        prescrizione = 'Rientrare nei limiti di immissione o chiudere la sorgente.',
    },
    amianto = {
        nome = 'Fibre di amianto',
        unita = 'ff/l',
        limite = 2,
        minimo = 0, massimo = 40,
        durataSecondi = 40,
        norma = 'D.M. 6/9/1994',
        sanzione = 520000,
        prescrizione = 'Incapsulare o rimuovere la copertura con ditta abilitata.',
    },
    suolo = {
        nome = 'Contaminazione del suolo',
        unita = 'mg/kg',
        limite = 50,
        minimo = 5, massimo = 300,
        durataSecondi = 45,
        norma = 'art. 242 D.Lgs. 152/2006',
        sanzione = 460000,
        prescrizione = 'Presentare il piano di caratterizzazione e avviare la bonifica.',
    },
}

function ARPA.GetMatrice(id)
    return ARPA.Matrici[id]
end

-- ---------------------------------------------------------------------------
--  Le prescrizioni
-- ---------------------------------------------------------------------------
ARPA.Prescrizione = {
    -- Quanti minuti per rientrare
    minutiPerOttemperare = 40,

    -- Chi non ottempera paga il doppio della sanzione che avrebbe
    -- pagato subito. È il motivo per cui conviene mettersi a posto.
    moltiplicatoreInadempienza = 2.0,

    -- Il superamento sotto questa soglia sopra il limite è "grave": si
    -- va dritti alla sanzione, senza prescrizione.
    sogliaGrave = 2.5,
}

-- ---------------------------------------------------------------------------
--  Raffreddamento
-- ---------------------------------------------------------------------------
ARPA.Regole = {
    minutiFraControlli = 12,
    raggioRumore = 40.0,
}

--- L'esito di un controllo, dal valore misurato.
function ARPA.Esito(matrice, valore)
    if valore <= matrice.limite then return 'conforme' end
    if valore >= matrice.limite * ARPA.Prescrizione.sogliaGrave then return 'grave' end
    return 'superamento'
end
