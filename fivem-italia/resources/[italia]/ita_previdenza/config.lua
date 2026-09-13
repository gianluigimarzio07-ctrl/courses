--[[
    AUREA · Previdenza sociale (INPS e INAIL) — configurazione

    IL BUCO CHE CHIUDE

    I contributi previdenziali uscivano già dalle buste paga — 9% in
    ita_fisco, la ritenuta in aurea_core — e finivano nell'erario sotto la
    voce "inps". Poi non succedeva niente. Nessuno andava in pensione,
    nessuno prendeva la malattia, un infortunio sul lavoro non esisteva
    nemmeno come concetto. Era una tassa travestita da contributo.

    Qui i contributi tornano indietro.

    COME FUNZIONA LA PENSIONE, E PERCHÉ NON C'È UN SALVADANAIO

    Il sistema italiano è a RIPARTIZIONE: i contributi di chi lavora oggi
    pagano le pensioni di chi è in pensione oggi. Non esiste un conto
    personale con dentro i soldi. Quello che si accumula è un numero — il
    montante contributivo — che serve solo a calcolare quanto spetterà.

    Quindi qui il montante è una scrittura, non un deposito: cresce del 33%
    dell'imponibile (la quota di computo italiana) a ogni busta paga, ma
    nessun denaro viene messo da parte. Le pensioni le paga l'erario,
    esattamente come nella realtà. Se l'erario va in rosso il sistema è in
    disavanzo e la Guardia di Finanza e il Comune lo vengono a sapere: è
    una notizia, non un bug.

    COSA SI PRENDE

        pensione     maturata a settimane, calcolata sul montante
        malattia     con certificato del medico, a quota dell'imponibile
        infortunio   INAIL, e il datore ha l'obbligo di denunciarlo
        NASpI        disoccupazione, ma solo per chi ha contribuito

    E COSA SERVE AGLI ALTRI

    Il DURC — la regolarità contributiva. Senza, in Italia, un cantiere non
    apre e un appalto non si prende. ita_edilizia lo chiede prima di far
    aprire un cantiere, ed è il motivo per cui pagare i contributi conviene
    anche a chi non pensa alla pensione.
]]

PRE = {}

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
PRE.Sede = {
    nome = 'INPS — Sede provinciale',
    coord = vector3(-262.5, -1064.8, 31.2),
    raggio = 2.2,
    blip = { sprite = 407, colore = 38, scala = 0.75 },
}

-- ---------------------------------------------------------------------------
--  Contributi
--
--  aliquotaComputo è la quota di imponibile che alimenta il montante: in
--  Italia è il 33% (9,19% a carico del lavoratore, 23,81% del datore).
--  Qui trattenuto dalla busta paga è solo il primo pezzo — il resto è la
--  quota del datore, che nel sistema a ripartizione non si accantona.
-- ---------------------------------------------------------------------------
PRE.Contributi = {
    aliquotaComputo = 0.33,
    aliquotaLavoratore = 0.0919,

    -- Una busta paga vale una settimana di contribuzione. Il ciclo degli
    -- stipendi è di 30 minuti reali, quindi mezz'ora di gioco = una
    -- settimana di carriera: una vita lavorativa non può durare una vita.
    settimanePerBusta = 1,

    -- Sotto questo imponibile la settimana non viene accreditata: è il
    -- minimale contributivo, e serve a impedire che un lavoretto da pochi
    -- euro faccia maturare la pensione come un lavoro vero.
    minimaleSettimanale = 4000,   -- 40 €
}

-- ---------------------------------------------------------------------------
--  Pensione di vecchiaia
-- ---------------------------------------------------------------------------
PRE.Pensione = {
    -- Requisito contributivo minimo
    settimaneMinime = 400,

    -- Pensione anticipata: più settimane, ma si può chiedere prima di
    -- raggiungere l'anzianità piena pagando una penalizzazione
    settimaneAnticipata = 300,
    penalizzazioneAnticipata = 0.18,

    -- Coefficiente di trasformazione: quanto del montante si incassa a
    -- ogni erogazione. Il montante non si consuma — è a ripartizione.
    coefficiente = 0.019,

    -- Ogni quanto arriva il rateo
    minuti = 30,

    -- Nessuno prende meno di così, se ha maturato il diritto: è
    -- l'integrazione al trattamento minimo
    trattamentoMinimo = 6000,     -- 60 €

    -- E nessuno prende più di così: il massimale
    massimale = 60000,            -- 600 €

    -- Il lavoro assegnato a chi si ritira
    lavoro = 'pensionato',
}

-- ---------------------------------------------------------------------------
--  Malattia
--
--  Serve il certificato del medico (aurea_ospedale, tipo 'malattia'). Chi
--  lo ha si mette in malattia e prende l'indennità; chi si mette in
--  servizio mentre la prende commette indebita percezione.
-- ---------------------------------------------------------------------------
PRE.Malattia = {
    -- Quota dell'ultimo imponibile
    quota = 0.60,
    -- Per quante erogazioni
    ratei = 6,
    minuti = 15,
    -- Giorni di carenza: i primi ratei non sono a carico dell'INPS
    carenza = 1,
    -- Quante volte si può andare in malattia in un ciclo di vita del
    -- personaggio prima che scatti la visita fiscale automatica
    primaDellaVisitaFiscale = 3,
    -- La visita fiscale: se il medico legale non ti trova, decade tutto
    finestraVisitaMinuti = 10,
}

-- ---------------------------------------------------------------------------
--  Infortunio sul lavoro (INAIL)
--
--  Art. 53 D.P.R. 1124/1965: il datore denuncia l'infortunio entro due
--  giorni da quando ne ha notizia. Non farlo è una sanzione, e in AUREA è
--  anche la strada più rapida per un DURC irregolare.
-- ---------------------------------------------------------------------------
PRE.Infortunio = {
    -- Il tempo che il datore ha per denunciare
    minutiDenuncia = 45,
    -- La sanzione se non lo fa
    sanzioneOmessa = 129000,      -- 1.290 €, il minimo edittale

    -- Indennità temporanea, a quota dell'imponibile, per gravità
    gravita = {
        lieve =  { quota = 0.60, ratei = 4,  etichetta = 'Infortunio lieve' },
        medio =  { quota = 0.75, ratei = 8,  etichetta = 'Infortunio con prognosi' },
        grave =  { quota = 1.00, ratei = 16, etichetta = 'Infortunio grave' },
    },
    minuti = 15,

    -- Oltre questa soglia di infortuni in capo allo stesso datore scatta
    -- la segnalazione all'ispettorato: non è più sfortuna, è un metodo
    sogliaIspezione = 3,
}

-- ---------------------------------------------------------------------------
--  NASpI
--
--  Il sussidio di disoccupazione di aurea_lavori resta com'è per tutti:
--  è l'assistenza, e non si nega a nessuno. La NASpI è un'altra cosa —
--  è previdenza, e la prende solo chi ha versato.
-- ---------------------------------------------------------------------------
PRE.NASpI = {
    settimaneMinime = 13,
    quota = 0.75,
    -- Durata: metà delle settimane contribuite, entro questi limiti
    rateiMinimi = 4,
    rateiMassimi = 24,
    minuti = 20,
    -- Decalage: dopo questi ratei l'importo cala del 3% a rateo
    decalageDopo = 6,
    decalage = 0.03,
}

-- ---------------------------------------------------------------------------
--  DURC — Documento Unico di Regolarità Contributiva
-- ---------------------------------------------------------------------------
PRE.DURC = {
    -- Oltre questo debito contributivo il DURC è irregolare
    sogliaDebito = 15000,         -- 150 €
    -- Un infortunio non denunciato rende irregolari finché non si sana
    infortunioOmessoBlocca = true,
    -- Validità di un DURC rilasciato, in minuti
    validitaMinuti = 120,
}

-- ---------------------------------------------------------------------------
--  Chi controlla
--
--  Il Nucleo Ispettorato del Lavoro è un reparto dei Carabinieri: non serve
--  inventare un ente nuovo.
-- ---------------------------------------------------------------------------
PRE.Vigilanza = {
    lavori = { 'carabinieri', 'guardia_finanza' },
    -- Chi può vedere la posizione contributiva altrui allo sportello
    sportello = { 'agenzia_entrate', 'comune' },
}

-- ---------------------------------------------------------------------------
--  Aiutanti
-- ---------------------------------------------------------------------------

--- L'importo di un rateo di pensione a partire dal montante.
function PRE.RateoPensione(montante, anticipata)
    local lordo = math.floor(montante * PRE.Pensione.coefficiente)
    if anticipata then
        lordo = math.floor(lordo * (1 - PRE.Pensione.penalizzazioneAnticipata))
    end
    if lordo < PRE.Pensione.trattamentoMinimo then lordo = PRE.Pensione.trattamentoMinimo end
    if lordo > PRE.Pensione.massimale then lordo = PRE.Pensione.massimale end
    return lordo
end

--- Quanti ratei di NASpI spettano per le settimane contribuite.
function PRE.RateiNASpI(settimane)
    local r = math.floor(settimane / 2)
    if r < PRE.NASpI.rateiMinimi then r = PRE.NASpI.rateiMinimi end
    if r > PRE.NASpI.rateiMassimi then r = PRE.NASpI.rateiMassimi end
    return r
end

--- La descrizione a parole del requisito pensionistico.
function PRE.StatoRequisito(settimane)
    if settimane >= PRE.Pensione.settimaneMinime then
        return 'maturato', 'Hai maturato il diritto alla pensione di vecchiaia.'
    end
    if settimane >= PRE.Pensione.settimaneAnticipata then
        return 'anticipata', ('Puoi chiedere la pensione anticipata, con una riduzione del %d%%.')
            :format(math.floor(PRE.Pensione.penalizzazioneAnticipata * 100))
    end
    return 'non_maturato', ('Ti mancano %d settimane sulle %d richieste.')
        :format(PRE.Pensione.settimaneAnticipata - settimane, PRE.Pensione.settimaneMinime)
end
