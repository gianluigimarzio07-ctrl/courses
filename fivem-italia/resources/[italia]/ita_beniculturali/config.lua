--[[
    AUREA · Soprintendenza e beni culturali (configurazione)

    IL TOMBAROLO

    C'è un mestiere illegale che esiste solo in Italia e in pochi altri
    posti al mondo: il tombarolo. Non ruba a qualcuno — ruba a nessuno.
    Va di notte in un campo, accende un metal detector, scava, e tira
    fuori una cosa che era lì da duemilacinquecento anni.

    La legge italiana su questo è netta e quasi nessuno la conosce: TUTTO
    QUELLO CHE STA SOTTO TERRA È DELLO STATO. Non del proprietario del
    campo, non di chi lo trova. Dello Stato, dal 1939.

    Da questo discendono due strade, e sono le due strade di questa
    risorsa:

    · DENUNCIARE il ritrovamento entro ventiquattr'ore (art. 90 del
      Codice dei beni culturali). Chi lo fa ha diritto a un PREMIO fino
      a un quarto del valore (art. 92). È poco, arriva tardi, ed è legale.

    · NON DENUNCIARLO. Da quel momento lo si detiene illecitamente, e
      quando salta fuori non è una multa: è l'art. 518-bis c.p., furto
      di beni culturali, entrato in vigore nel 2022.

    E IN MEZZO C'È IL MERCATO

    Perché un reperto vale, e chi lo compra non fa domande. Vale tre o
    quattro volte il premio dello Stato, e questa sproporzione è tutto il
    motivo per cui i tombaroli esistono davvero.

    Il server non risolve questa tensione: la mette in scena.
]]

BC = {}

BC.Lavoro = 'soprintendenza'

-- ---------------------------------------------------------------------------
--  La Soprintendenza
-- ---------------------------------------------------------------------------
BC.Sede = {
    nome = 'Soprintendenza Archeologia, Belle Arti e Paesaggio',
    coord = vector3(-1425.6, -222.4, 50.0),
    raggio = 2.4,
    blip = { sprite = 434, colore = 46, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  I siti
--
--  Ognuno ha un raggio, una ricchezza e un numero di prelievi oltre il
--  quale è esaurito. Un sito saccheggiato non ricresce in fretta: è il
--  motivo per cui il saccheggio è un danno e non un prelievo.
-- ---------------------------------------------------------------------------
BC.Siti = {
    {
        id = 'necropoli',
        nome = 'Necropoli in contrada',
        coord = vector3(1935.4, 4642.2, 40.4),
        raggio = 55.0,
        vincolato = true,
        prelieviMassimi = 14,
        valoreMin = 180000, valoreMax = 720000,
        reperti = { 'Olla cineraria', 'Fibula in bronzo', 'Kylix a figure nere',
                    'Unguentario in alabastro', 'Anello con castone inciso' },
    },
    {
        id = 'villa_romana',
        nome = 'Villa romana sotto il vigneto',
        coord = vector3(2410.0, 4990.4, 46.8),
        raggio = 48.0,
        vincolato = true,
        prelieviMassimi = 12,
        valoreMin = 220000, valoreMax = 880000,
        reperti = { 'Frammento di mosaico pavimentale', 'Lucerna a becco tondo',
                    'Anfora vinaria', 'Testina fittile', 'Denario d\'argento' },
    },
    {
        id = 'porto_antico',
        nome = 'Relitto presso il porto antico',
        coord = vector3(-2020.0, -1050.0, 2.0),
        raggio = 60.0,
        vincolato = true,
        prelieviMassimi = 10,
        valoreMin = 260000, valoreMax = 960000,
        reperti = { 'Ancora litica', 'Anfora da trasporto', 'Piombo da sonda',
                    'Ceppo d\'ancora in piombo' },
    },
    {
        id = 'castrum',
        nome = 'Castrum sulla collina',
        coord = vector3(-580.0, 5320.0, 70.0),
        raggio = 50.0,
        vincolato = true,
        prelieviMassimi = 11,
        valoreMin = 150000, valoreMax = 600000,
        reperti = { 'Punta di lancia', 'Moneta di bronzo', 'Chiave in ferro',
                    'Borchia da cintura' },
    },
}

function BC.GetSito(id)
    for _, s in ipairs(BC.Siti) do
        if s.id == id then return s end
    end
    return nil
end

function BC.SitoIn(coord)
    for _, s in ipairs(BC.Siti) do
        if #(coord - s.coord) <= s.raggio then return s end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Lo scavo
-- ---------------------------------------------------------------------------
BC.Scavo = {
    attrezzo = 'metal_detector',
    attrezzoScavo = 'trowel',
    durataRicerca = 18000,
    durataScavo = 26000,

    -- Probabilità che la ricerca trovi qualcosa
    probabilitaSegnale = 55,
    -- Di quei segnali, quanti sono rottami
    probabilitaFerraglia = 40,

    -- Lo scavo clandestino si sente: le forze dell'ordine possono
    -- riceverne segnalazione.
    probabilitaSegnalazione = 22,

    minutiFraScavi = 3,
}

-- ---------------------------------------------------------------------------
--  Denuncia del ritrovamento
-- ---------------------------------------------------------------------------
BC.Denuncia = {
    -- Quanti minuti di gioco valgono le ventiquattr'ore dell'art. 90
    minutiPerDenunciare = 45,

    -- Art. 92: il premio al ritrovatore, in quota sul valore di perizia.
    -- Un quarto è il massimo di legge. Nessuno si è mai arricchito così.
    premio = 0.25,

    -- Chi ha scavato senza autorizzazione ha diritto al premio? No: il
    -- premio spetta a chi trova per caso, non a chi va a cercare.
    premioSoloSeFortuito = true,

    -- Il premio se lo scavo era autorizzato: chi lavora per la
    -- Soprintendenza è pagato, non premiato.
    premioAutorizzato = 0.05,
}

-- ---------------------------------------------------------------------------
--  Autorizzazione allo scavo
-- ---------------------------------------------------------------------------
BC.Autorizzazione = {
    minutiValidita = 90,
    costo = 0,      -- la rilascia la Soprintendenza, non si compra
}

-- ---------------------------------------------------------------------------
--  Il mercato clandestino
-- ---------------------------------------------------------------------------
BC.Mercato = {
    -- Dove si piazza. Un ricettatore che non fa domande.
    coord = vector3(1234.8, -3255.4, 5.0),
    raggio = 2.4,

    -- Quanto paga, in quota sul valore di perizia. Tre volte il premio
    -- dello Stato: è tutta lì, la ragione per cui il mercato esiste.
    quota = 0.75,

    -- Serve appartenere a un'organizzazione: un ricettatore di reperti
    -- non compra dal primo che passa.
    richiedeOrganizzazione = true,

    -- Probabilità che la vendita lasci una traccia che porta a un
    -- fascicolo per ricettazione.
    probabilitaTraccia = 18,
}

-- ---------------------------------------------------------------------------
--  Reati
-- ---------------------------------------------------------------------------
BC.Reati = {
    detenzione = '518b',
    ricettazione = '518q',
    scavo = '518t',
    esportazione = '518u',
}
