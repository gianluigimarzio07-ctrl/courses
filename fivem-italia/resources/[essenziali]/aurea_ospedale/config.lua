--[[
    AUREA · Ospedale — configurazione

    aurea_medico si occupa di chi è a terra: rianimazione, ferite, ticket
    del pronto soccorso. Quella parte non si tocca.

    Qui c'è l'ospedale come luogo che produce documenti. Il triage, che
    decide chi passa prima. Gli esami, che dicono cose che il paziente
    magari non voleva far sapere: quanto ha bevuto, cosa ha assunto, che
    calibro ha il proiettile che ha in corpo. La cartella clinica, che
    resta. Le certificazioni di idoneità, senza le quali non si rinnova la
    patente né si ottiene il porto d'armi. E l'obitorio, dove il medico
    legale stabilisce la causa della morte.

    È il pezzo che collega la sanità al resto del mondo: un esame
    tossicologico positivo è una prova, un certificato di idoneità è un
    requisito, un riscontro diagnostico è l'inizio di un'indagine.
]]

OSP = {}

OSP.Lavori = { '118', 'medico' }

--- Chi firma i referti e i certificati: non l'infermiere di turno.
OSP.GradoMedico = 2
--- Chi può fare il riscontro diagnostico
OSP.GradoLegale = 3

-- ---------------------------------------------------------------------------
--  Reparti
-- ---------------------------------------------------------------------------
OSP.Reparti = {
    accettazione = {
        nome = 'Accettazione e triage',
        coord = vector3(309.1, -571.9, 43.3), raggio = 3.0,
    },
    diagnostica = {
        nome = 'Diagnostica per immagini',
        coord = vector3(324.0, -558.5, 43.3), raggio = 3.5,
    },
    laboratorio = {
        nome = 'Laboratorio analisi',
        coord = vector3(299.2, -566.9, 43.3), raggio = 3.0,
    },
    ambulatorio = {
        nome = 'Ambulatorio — medicina legale',
        coord = vector3(333.2, -594.4, 43.3), raggio = 3.0,
    },
    obitorio = {
        nome = 'Obitorio',
        coord = vector3(279.4, -580.7, 43.3), raggio = 3.5,
    },
}

-- ---------------------------------------------------------------------------
--  Triage
--
--  Il codice non lo sceglie il paziente: lo assegna chi accetta. Ma il
--  paziente può dichiarare il sintomo, e il sistema propone un codice.
-- ---------------------------------------------------------------------------
OSP.Triage = {
    codici = {
        { id = 'rosso',  nome = 'Codice rosso',  priorita = 1, colore = { 200, 60, 60 },
          descrizione = 'Compromissione delle funzioni vitali. Accesso immediato.' },
        { id = 'giallo', nome = 'Codice giallo', priorita = 2, colore = { 220, 180, 60 },
          descrizione = 'Rischio evolutivo. Va visto in fretta.' },
        { id = 'verde',  nome = 'Codice verde',  priorita = 3, colore = { 90, 180, 110 },
          descrizione = 'Urgenza differibile.' },
        { id = 'bianco', nome = 'Codice bianco', priorita = 4, colore = { 220, 220, 220 },
          descrizione = 'Non urgente. In Italia si paga il ticket pieno.' },
    },

    -- Il ticket dipende dal codice: chi va in pronto soccorso per un
    -- raffreddore paga, chi arriva in codice rosso no.
    ticket = {
        rosso = 0, giallo = 0, verde = 2500, bianco = 4500,
    },

    -- Sintomi dichiarabili all'accettazione, con il codice che suggeriscono
    sintomi = {
        { id = 'trauma',    nome = 'Trauma da caduta o incidente', suggerito = 'giallo' },
        { id = 'arma',      nome = 'Ferita da arma',               suggerito = 'rosso' },
        { id = 'dolore',    nome = 'Dolore toracico',              suggerito = 'rosso' },
        { id = 'malore',    nome = 'Malore, giramenti di testa',   suggerito = 'verde' },
        { id = 'febbre',    nome = 'Febbre e sintomi influenzali',  suggerito = 'bianco' },
        { id = 'certificato', nome = 'Richiesta di certificazione', suggerito = 'bianco' },
    },
}

-- ---------------------------------------------------------------------------
--  Esami
-- ---------------------------------------------------------------------------
OSP.Esami = {
    emocromo = {
        nome = 'Emocromo con formula', icona = '🩸',
        reparto = 'laboratorio', durata = 14000, ticket = 1800,
        -- Dice come sta, niente di riservato
        rivela = 'salute',
    },
    alcolemia = {
        nome = 'Alcolemia ematica', icona = '🍷',
        reparto = 'laboratorio', durata = 16000, ticket = 2200,
        rivela = 'alcol',
        -- L'esame di laboratorio, a differenza dell'etilometro, fa prova
        -- piena: se il paziente è arrivato dopo un incidente, il referto
        -- va alla polizia giudiziaria
        segnalaOltre = 0.8,
    },
    tossicologico = {
        nome = 'Esame tossicologico', icona = '🧪',
        reparto = 'laboratorio', durata = 22000, ticket = 4800,
        rivela = 'sostanze',
        -- Il referto positivo è un fatto sanitario, ma se il paziente è un
        -- conducente diventa altro
        segnala = true,
    },
    radiografia = {
        nome = 'Radiografia', icona = '🦴',
        reparto = 'diagnostica', durata = 18000, ticket = 3500,
        rivela = 'ferite',
    },
    tac = {
        nome = 'TAC total body', icona = '🧠',
        reparto = 'diagnostica', durata = 28000, ticket = 9500,
        rivela = 'ferite_dettaglio',
    },
}

-- ---------------------------------------------------------------------------
--  Quanto restano rilevabili le sostanze
--
--  Non è farmacologia seria, è un compromesso di gioco: abbastanza da
--  rendere l'esame utile, non tanto da rendere impossibile ripulirsi.
-- ---------------------------------------------------------------------------
OSP.Tossicologia = {
    minutiRilevabilita = {
        erba = 90, hashish = 90,
        cocaina = 70, mdma = 80, eroina = 110,
        sostanza_raffinata = 70,
    },
    predefinito = 60,

    -- Sotto questa soglia l'esame è dubbio e va ripetuto
    sogliaCerta = 20,
}

-- ---------------------------------------------------------------------------
--  Certificazioni
--
--  Documenti che servono altrove. È il modo in cui la sanità entra nella
--  vita amministrativa: senza il certificato non c'è porto d'armi, e
--  senza la visita non c'è rinnovo della patente.
-- ---------------------------------------------------------------------------
OSP.Certificati = {
    {
        id = 'idoneita_guida',
        nome = 'Certificato di idoneità psicofisica alla guida',
        item = 'certificato_medico',
        tipo = 'guida',
        costo = 8500, validitaGiorni = 365,
        durata = 20000,
        -- Non si rilascia a chi è positivo al tossicologico o all'alcolemia
        richiedeEsami = { 'alcolemia', 'tossicologico' },
    },
    {
        id = 'idoneita_armi',
        nome = 'Certificato anamnestico per porto d\'armi',
        item = 'certificato_medico',
        tipo = 'armi',
        costo = 14000, validitaGiorni = 365,
        durata = 25000,
        richiedeEsami = { 'tossicologico' },
    },
    {
        id = 'idoneita_sport',
        nome = 'Certificato di idoneità sportiva agonistica',
        item = 'certificato_medico',
        tipo = 'sport',
        costo = 5500, validitaGiorni = 365,
        durata = 15000,
        richiedeEsami = {},
    },
    {
        id = 'malattia',
        nome = 'Certificato di malattia',
        item = 'certificato_medico',
        tipo = 'malattia',
        costo = 2500, validitaGiorni = 7,
        durata = 8000,
        richiedeEsami = {},
    },
}

-- ---------------------------------------------------------------------------
--  Riscontro diagnostico
--
--  Il medico legale stabilisce la causa della morte. Se è violenta,
--  l'informativa va alla polizia giudiziaria: è così che parte
--  un'indagine su una morte che poteva passare per naturale.
-- ---------------------------------------------------------------------------
OSP.Obitorio = {
    durata = 40000,
    onorario = 22000,
    -- A chi va l'informativa
    avvisa = { 'carabinieri', 'polizia' },
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function OSP.GetCodice(id)
    for _, c in ipairs(OSP.Triage.codici) do
        if c.id == id then return c end
    end
    return nil
end

function OSP.GetEsame(id) return OSP.Esami[id] end

function OSP.GetCertificato(id)
    for _, c in ipairs(OSP.Certificati) do
        if c.id == id then return c end
    end
    return nil
end

function OSP.GetReparto(id) return OSP.Reparti[id] end

function OSP.InReparto(coord, id)
    local r = OSP.Reparti[id]
    if not r then return false end
    return #(coord - r.coord) <= r.raggio + 1.0
end
