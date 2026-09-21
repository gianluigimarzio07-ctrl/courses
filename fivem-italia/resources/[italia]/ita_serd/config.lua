--[[
    AUREA · Ser.D. — Servizio per le Dipendenze (configurazione)

    LA COSA CHE IN ITALIA NON È REATO

    ita_droga sa fare tutto il lato penale: coltivazione, spaccio,
    sequestro, art. 73. Quello che non sapeva fare era distinguere lo
    spacciatore dal consumatore — e in Italia quella distinzione è
    l'intera architettura della legge sulle droghe.

    Detenere sostanze PER USO PERSONALE non è reato. È un illecito
    amministrativo (art. 75 D.P.R. 309/1990), e la conseguenza non è un
    processo: è una CONVOCAZIONE DAL PREFETTO, che ti guarda in faccia e
    ti manda al Ser.D.

    Non è indulgenza. È una scelta tecnica precisa, e ha conseguenze
    concrete che questa risorsa mette in gioco:

    · alla PRIMA volta, il Prefetto può limitarsi a un formale invito;
    · dalla SECONDA in poi arrivano le sanzioni vere, e la prima è
      quella che fa male a chiunque: SOSPENSIONE DELLA PATENTE;
    · ma se accetti un PROGRAMMA TERAPEUTICO al Ser.D. e lo porti a
      termine, il procedimento si chiude e le sanzioni cadono.

    Quest'ultimo pezzo è il motivo per cui il Ser.D. esiste: è l'unica
    istituzione del server che offre una via d'uscita invece di una
    punizione, e funziona solo se ci vai davvero, più volte.

    CHI CI LAVORA

    Operatori, non agenti. Qui non si arresta nessuno e non si
    sequestra niente: si fanno colloqui. È un lavoro lento e serve a
    qualcosa proprio perché è lento.
]]

SERD = {}

SERD.Lavoro = 'serd'

SERD.Sede = {
    nome = 'Ser.D. — Servizio per le Dipendenze',
    coord = vector3(315.8, -566.4, 43.3),
    raggio = 2.4,
    blip = { sprite = 403, colore = 2, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  Uso personale
-- ---------------------------------------------------------------------------
SERD.UsoPersonale = {
    -- Sotto questa quantità di dosi si presume l'uso personale. Sopra,
    -- è materia penale e il Ser.D. non c'entra.
    dosiMassime = 5,
}

-- ---------------------------------------------------------------------------
--  Le sanzioni del Prefetto (art. 75 c. 1)
--
--  Sono in ordine: alla prima si può solo ammonire, dalla seconda si
--  applicano sul serio.
-- ---------------------------------------------------------------------------
SERD.Sanzioni = {
    -- Alla prima segnalazione: formale invito, nessuna sanzione
    primaVolta = 'invito',

    -- Dalla seconda: sospensione della patente
    giorniPatente = 30,
    giorniPatenteRecidiva = 90,

    -- E una sanzione pecuniaria, che è quella che in Italia colpisce
    -- chi non ha la patente
    pecuniaria = 45000,

    -- Minuti entro cui presentarsi al Ser.D. dopo la convocazione
    minutiPerPresentarsi = 60,
}

-- ---------------------------------------------------------------------------
--  Il programma terapeutico
-- ---------------------------------------------------------------------------
SERD.Programma = {
    -- Quanti colloqui servono per concluderlo
    sessioni = 4,

    -- Minuti fra un colloquio e l'altro: non si fanno tutti di seguito,
    -- ed è il punto.
    minutiFraSessioni = 15,

    durataSecondi = 40,

    -- Chi conclude il programma vede cadere le sanzioni e si chiude il
    -- procedimento. È l'art. 75 c. 3.
    chiudeSegnalazione = true,

    -- Compenso all'operatore per ogni colloquio
    compensoOperatore = 9000,

    -- Il programma dà anche un beneficio concreto sullo stato: lo
    -- stress cala, e chi ha assunto sostanze lo sa quanto pesa.
    beneficioStress = -18,
}

-- ---------------------------------------------------------------------------
--  Il test
-- ---------------------------------------------------------------------------
SERD.Test = {
    -- Il colloquio comincia con un test: chi risulta ancora positivo
    -- non ha interrotto, e la sessione non conta.
    probabilitaPositivo = 35,
    riduzionePerSessione = 8,
}
