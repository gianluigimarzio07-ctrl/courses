--[[
    AUREA · Prefettura — Ufficio Territoriale del Governo (configurazione)

    IL PEZZO CHE MANCAVA ALLO STATO

    Il server sapeva multare benissimo. Autovelox, ZTL, verbale dell'agente,
    cartella esattoriale: tutta la catena c'era, e funzionava in una
    direzione sola. Chi prendeva una multa sbagliata aveva due scelte:
    pagarla o non pagarla.

    In Italia ce n'è una terza, e per la maggior parte delle persone è
    l'unico momento in cui parlano con lo Stato senza avere torto per
    definizione: IL RICORSO.

    Contro un verbale si ricorre al Prefetto (art. 203 CdS) oppure al
    Giudice di Pace (art. 204-bis). Le due strade sono alternative — se
    prendi una, l'altra si chiude — e hanno prezzi e rischi diversi:

    · Il PREFETTO è gratis. Ma se rigetta emette un'ORDINANZA-INGIUNZIONE
      che, per legge, non può essere inferiore al DOPPIO del minimo
      edittale. Ricorrere gratis e perdere costa il doppio di pagare
      subito. Questo non è un cattiveria del server: è l'art. 204 CdS.

    · Il GIUDICE DI PACE costa il contributo unificato, ma se accoglie
      può anche solo ridurre la sanzione al minimo invece di annullarla.

    · E poi c'è la terza possibilità, quella che in Italia conoscono tutti
      gli avvocati e quasi nessun altro: se il Prefetto NON DECIDE entro
      il termine, il ricorso si intende ACCOLTO (art. 204 c. 1-bis).
      Un ufficio lento è una multa che sparisce. Qui succede uguale:
      se nessuno in Prefettura guarda la coda, i ricorsi si accolgono
      da soli.

    L'ALTRO MESTIERE DELLA PREFETTURA

    La Prefettura non fa solo ricorsi. Tiene l'elenco degli ADDETTI AI
    SERVIZI DI CONTROLLO — i buttafuori. Senza quell'iscrizione stare
    sulla porta di un locale a decidere chi entra non è un lavoro: è un
    illecito, e il locale lo paga insieme a te.

    È il motivo per cui questa risorsa e ita_discoteca si parlano.
]]

PREF = {}

PREF.Lavoro = 'prefettura'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
PREF.Sede = {
    nome = 'Prefettura — Ufficio Territoriale del Governo',
    coord = vector3(-544.8, -204.2, 38.2),
    raggio = 2.4,
    blip = { sprite = 419, colore = 38, scala = 0.8 },
}

-- ---------------------------------------------------------------------------
--  Ricorsi
-- ---------------------------------------------------------------------------
PREF.Ricorso = {
    -- Entro quanti giorni dal verbale si può ricorrere (art. 203: 60 gg).
    giorniPerRicorrere = 60,

    -- Quanto ha la Prefettura per decidere, in minuti di gioco. Scaduto
    -- il termine senza decisione il ricorso è accolto e basta: non serve
    -- che qualcuno lo dichiari.
    minutiPerDecidere = 90,

    -- Art. 204 CdS: l'ordinanza-ingiunzione non può essere inferiore al
    -- doppio del minimo edittale. Qui il minimo è l'importo del verbale.
    moltiplicatoreIngiunzione = 2.0,

    -- Il ricorso al Giudice di Pace costa il contributo unificato.
    contributoUnificato = 4300,

    -- Se il Giudice di Pace accoglie parzialmente, la sanzione scende a
    -- questa quota dell'originale invece di essere annullata.
    riduzioneGiudicePace = 0.4,

    -- Probabilità che il Giudice di Pace, deciso d'ufficio perché in
    -- servizio non c'è nessuno, accolga. Il Prefetto invece NON decide
    -- mai d'ufficio: se nessuno guarda, vale il silenzio-accoglimento.
    probabilitaAccoglimentoGdP = 45,

    -- Motivi che il cittadino può indicare. Non cambiano l'esito da soli
    -- — decide chi istruisce — ma sono quello che compare nel fascicolo.
    motivi = {
        { id = 'inesistenza',  nome = 'Il fatto non sussiste',
          descrizione = 'Non ero io, non ero lì, il veicolo non era mio.' },
        { id = 'notifica',     nome = 'Vizio di notifica',
          descrizione = 'Il verbale non mi è mai stato notificato, o è arrivato tardi.' },
        { id = 'segnaletica',  nome = 'Segnaletica assente o irregolare',
          descrizione = 'Il limite non era segnalato, il varco non era indicato.' },
        { id = 'taratura',     nome = 'Mancata taratura dello strumento',
          descrizione = 'L\'autovelox non risulta omologato e tarato.' },
        { id = 'emergenza',    nome = 'Stato di necessità',
          descrizione = 'Stavo trasportando una persona in pericolo di vita.' },
        { id = 'identita',     nome = 'Veicolo ceduto o rubato',
          descrizione = 'Alla guida c\'era un altro, e posso dire chi.' },
    },
}

--- Il motivo per id.
function PREF.GetMotivo(id)
    for _, m in ipairs(PREF.Ricorso.motivi) do
        if m.id == id then return m end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Ordinanze del Prefetto
-- ---------------------------------------------------------------------------
PREF.Ordinanze = {
    -- La sospensione della patente non la dispone l'agente che ferma:
    -- ritira il documento e lo trasmette al Prefetto, che poi decide.
    -- Qui il Prefetto la dispone direttamente, ed è l'unico che può.
    sospensioneMassimaGiorni = 730,

    -- Il foglio di via obbligatorio: allontanamento da una zona.
    foglioVia = {
        oreDefault = 48,
        oreMassime = 336,
    },
}

-- ---------------------------------------------------------------------------
--  Elenco prefettizio degli addetti ai servizi di controllo
-- ---------------------------------------------------------------------------
PREF.Elenco = {
    -- Quanto costa l'istruttoria dell'iscrizione
    costoIstruttoria = 12000,

    -- Per quanti giorni vale l'iscrizione
    giorniValidita = 90,

    -- Gravità massima nel casellario che consente l'iscrizione.
    -- Chi ha precedenti seri non fa il buttafuori: è esattamente il
    -- controllo che l'elenco prefettizio esiste per fare.
    gravitaMassimaPrecedenti = 2,

    -- Reati che escludono comunque, qualunque sia la gravità registrata
    reatiOstativi = { '628', '629', '416bis', '575', '582', '73' },

    secondiIstruttoria = 20,
}

--- L'importo dell'ordinanza-ingiunzione a partire dal verbale.
function PREF.Ingiunzione(importoVerbale)
    return math.floor(importoVerbale * PREF.Ricorso.moltiplicatoreIngiunzione)
end
