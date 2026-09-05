--[[
    AUREA · Tribunale — configurazione

    Fino a ieri l'arresto era la fine della storia: il poliziotto decideva
    la pena e amen. Qui c'è un grado in mezzo, ed è dove il roleplay
    diventa interessante: un pubblico ministero che sostiene l'accusa, un
    avvocato che difende, un giudice che decide, e un imputato che può
    patteggiare o rischiare il dibattimento.

    Il patteggiamento sconta un terzo, come nella realtà. Il dibattimento
    può finire in assoluzione, e allora la detenzione salta del tutto.
]]

TRI = {}

TRI.Sede = {
    nome = 'Tribunale',
    coord = vector3(242.0, -1379.0, 33.7),
    aula = vector3(-548.0, -204.0, 38.2),
    blip = { sprite = 419, colore = 3, scala = 0.8 },
}

TRI.Ruoli = {
    giudice   = { lavoro = 'giudice',   gradoMinimo = 0, nome = 'Giudice' },
    pm        = { lavoro = 'giudice',   gradoMinimo = 0, nome = 'Pubblico ministero' },
    avvocato  = { lavoro = 'avvocato',  gradoMinimo = 0, nome = 'Difensore' },
}

TRI.Riti = {
    patteggiamento = {
        nome = 'Patteggiamento', icona = '🤝',
        descrizione = 'Si concorda la pena. Sconto di un terzo, nessun dibattimento.',
        sconto = 1 / 3,
        richiedeGiudice = true,
        richiedeAvvocato = false,
    },
    abbreviato = {
        nome = 'Rito abbreviato', icona = '📄',
        descrizione = 'Si giudica sugli atti. Sconto di un terzo, ma il giudice può assolvere.',
        sconto = 1 / 3,
        richiedeGiudice = true,
        richiedeAvvocato = true,
        ammetteAssoluzione = true,
    },
    ordinario = {
        nome = 'Dibattimento', icona = '⚖',
        descrizione = 'Accusa e difesa discutono. Nessuno sconto, ma si può essere assolti del tutto.',
        sconto = 0,
        richiedeGiudice = true,
        richiedeAvvocato = true,
        ammetteAssoluzione = true,
        -- In dibattimento il giudice può anche aggravare
        ammetteAggravio = true,
        aggravioMassimo = 0.4,
    },
}

TRI.Regole = {
    -- Un processo si può aprire solo su fascicoli aperti
    statiProcessabili = { 'indagato', 'imputato' },
    -- Quanti fascicoli si trattano in un'udienza
    capiMassimi = 6,
    -- L'imputato deve essere presente
    distanzaAula = 25.0,
    -- Il difensore d'ufficio, se non c'è un avvocato
    difensoreUfficio = true,
    -- Senza difensore in dibattimento non si procede
    -- Onorario del difensore, a carico dell'imputato
    onorarioAvvocato = 180000,
    onorarioUfficio = 45000,
    -- Le spese di giustizia, sempre dovute in caso di condanna
    speseGiustizia = 62000,
}

function TRI.GetRito(id) return TRI.Riti[id] end
