--[[
    AUREA · Consiglio dell'Ordine degli Avvocati — configurazione

    Il lavoro `avvocato` in AUREA esisteva già, con i suoi permessi:
    consultare il casellario, fare colloquio con un detenuto, presentare
    ricorso, chiedere il patteggiamento. Quello che non c'era è l'ORDINE —
    cioè le due cose che in Italia rendono l'avvocatura una professione e
    non un mestiere qualunque.

    LA PRIMA È CHE NESSUNO RESTA SENZA DIFESA.

    ita_tribunale aveva già un difensore d'ufficio, ma era un fantasma:
    `onorarioUfficio = 45000`, l'imputato pagava, e comparivano le parole
    «difensore d'ufficio» al posto di un nome. Nessuno veniva chiamato.

    In Italia esiste un turno. Il Consiglio dell'Ordine tiene un elenco di
    avvocati reperibili, e quando qualcuno arriva davanti a un giudice
    senza difensore si chiama chi è di turno — una persona vera, che si
    alza e va. Qui funziona così: se c'è un avvocato di turno online,
    viene avvisato e l'incarico è suo, con l'onorario che ne segue. Se non
    c'è nessuno, resta il vecchio difensore d'ufficio fantasma, perché un
    processo non si può fermare in attesa che qualcuno accenda il PC.

    LA SECONDA È CHE LA DIFESA NON DIPENDE DA QUANTO HAI.

    Il gratuito patrocinio, D.P.R. 115/2002: sotto una certa soglia di
    reddito l'onorario del difensore lo paga lo Stato. E la soglia si
    misura sul REDDITO IMPONIBILE DELL'ULTIMA DICHIARAZIONE — che in
    AUREA è una colonna che esiste davvero, `dichiarazioni.reddito`,
    riempita da ita_caf quando si fa il conguaglio.

    Il che produce una conseguenza che mi piace: per farsi difendere
    gratis bisogna aver presentato la dichiarazione dei redditi. Chi non
    l'ha mai fatta non può dimostrare di essere povero.

    (Nella realtà si è ammessi in via provvisoria su autocertificazione, e
    la Guardia di Finanza controlla dopo. Qui si è più severi: senza
    dichiarazione la domanda è inammissibile e ti si manda al CAF. È una
    semplificazione, ma tira dentro una risorsa che altrimenti nessuno
    apre.)
]]

AVV = {}

AVV.Lavoro = 'avvocato'

-- ---------------------------------------------------------------------------
--  Il Consiglio dell'Ordine
-- ---------------------------------------------------------------------------
AVV.Sede = {
    nome = 'Consiglio dell\'Ordine degli Avvocati',
    coord = vector3(-1913.4, -573.6, 19.1),
    raggio = 2.0,
    blip = { sprite = 419, colore = 27, scala = 0.8 },
}

-- ---------------------------------------------------------------------------
--  L'albo
--
--  Iscriversi non è un pulsante: serve il grado. Un praticante non è
--  avvocato, e in Italia non può stare sul turno delle difese d'ufficio
--  né chiedere l'ammissione al patrocinio a spese dello Stato.
-- ---------------------------------------------------------------------------
AVV.Albo = {
    -- Grado minimo nel lavoro `avvocato`: 0 è il praticante
    gradoMinimo = 1,
    -- Tassa di iscrizione annuale, che finisce all'Erario
    tassaIscrizione = 240000,
    -- Ogni quanto va rinnovata
    minutiValidita = 600,
    -- Chi ha un fascicolo aperto abbastanza grave non si iscrive. In
    -- Italia la radiazione di diritto scatta su condanne per reati
    -- determinati (corruzione, falso, riciclaggio, associazione); qui si
    -- usa la gravità del casellario, che è il dato che c'è, e la soglia è
    -- il gradino sopra la delinquenza comune.
    gravitaOstativa = 4,
}

-- ---------------------------------------------------------------------------
--  Il turno delle difese d'ufficio
-- ---------------------------------------------------------------------------
AVV.Turno = {
    -- Quanto dura un turno prima di scadere da solo
    minutiDurata = 90,
    -- Quanti avvocati possono starci insieme
    massimoContemporanei = 6,
    -- Indennità di reperibilità, la paga l'Erario anche se non ti chiamano
    indennita = 22000,
    -- Ogni quanto matura l'indennità
    minutiFraIndennita = 30,
    -- Chi rifiuta un incarico d'ufficio esce dal turno: in Italia il
    -- difensore d'ufficio NON può rifiutare, e chi lo fa risponde al
    -- Consiglio
    sanzioneRifiuto = 180000,
}

-- ---------------------------------------------------------------------------
--  Gratuito patrocinio
-- ---------------------------------------------------------------------------
AVV.Patrocinio = {
    articolo = 'D.P.R. 115/2002',
    -- La soglia vera è 12 838,01 € di reddito imponibile annuo. Qui i
    -- redditi sono su scala di gioco, quindi la soglia è quella che
    -- separa chi campa con uno stipendio da chi ha un'attività.
    sogliaReddito = 4500000,     -- 45 000,00 € di imponibile del periodo
    -- Quanto paga lo Stato al difensore. È meno dell'onorario di fiducia,
    -- e anche questo è vero: la liquidazione al patrocinio a spese dello
    -- Stato si fa sui minimi tariffari.
    onorarioLiquidato = 96000,
    -- L'ammissione dura per un po', non per sempre
    minutiValidita = 240,
    -- Chi ha un'impresa attiva non è ammesso: il reddito d'impresa non
    -- sta nella dichiarazione da dipendente e il presupposto cade
    escludiTitolariImpresa = true,
}

-- ---------------------------------------------------------------------------
--  Il procedimento disciplinare
--
--  Il Consiglio non condanna: censura, sospende o radia. Sono le tre
--  sanzioni vere, e la differenza fra loro è il tempo.
-- ---------------------------------------------------------------------------
AVV.Disciplinare = {
    censura = {
        etichetta = 'Censura',
        icona = '📄',
        descrizione = 'Rimprovero formale. Resta agli atti e non toglie nulla.',
        minutiSospensione = 0,
        sanzione = 60000,
    },
    sospensione = {
        etichetta = 'Sospensione dall\'esercizio',
        icona = '⏸',
        descrizione = 'Per la durata non si patrocina e non si sta sul turno.',
        minutiSospensione = 120,
        sanzione = 200000,
    },
    radiazione = {
        etichetta = 'Radiazione dall\'albo',
        icona = '⛔',
        descrizione = 'Cancellazione. Per tornare serve iscriversi da capo.',
        minutiSospensione = -1,   -- -1 = cancellato, non sospeso
        sanzione = 0,
    },
}

function AVV.GetSanzione(id)
    return AVV.Disciplinare[id]
end

-- Chi può aprire un procedimento disciplinare: il Consiglio si autogoverna,
-- quindi sono gli avvocati di grado alto, più il giudice.
AVV.Disciplinare.chiPuoAgire = { 'avvocato', 'giudice' }
AVV.Disciplinare.gradoMinimo = 2

-- ---------------------------------------------------------------------------
--  Gli incarichi
-- ---------------------------------------------------------------------------
AVV.Incarichi = {
    fiducia   = { etichetta = 'Difesa di fiducia',        icona = '🤝', aCarico = 'assistito' },
    ufficio   = { etichetta = 'Difesa d\'ufficio',        icona = '📞', aCarico = 'assistito' },
    patrocinio= { etichetta = 'Patrocinio a spese dello Stato', icona = '🏛', aCarico = 'erario' },
}

function AVV.GetIncarico(id)
    return AVV.Incarichi[id]
end
