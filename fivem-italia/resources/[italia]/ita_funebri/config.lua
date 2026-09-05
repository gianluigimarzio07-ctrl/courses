--[[
    AUREA · Onoranze funebri — configurazione

    La morte definitiva, per chi la vuole. Non è obbligatoria: si sceglie
    quando il personaggio è finito, e allora il funerale è il modo di
    chiuderla bene invece di sparire e basta.

    C'è un cimitero vero, le lapidi restano, e chi c'era al funerale
    resta scritto sopra. È l'unica cosa del server che non si può
    annullare, e proprio per questo va chiesta due volte.
]]

FUN = {}

FUN.Lavoro = 'comune'

FUN.Impresa = {
    nome = 'Onoranze funebri',
    coord = vector3(-1660.0, -1080.0, 13.2),
    blip = { sprite = 274, colore = 0, scala = 0.7 },
    carro = 'romero',
    spawn = vector4(-1668.0, -1073.0, 13.0, 320.0),
}

FUN.Cimitero = {
    nome = 'Cimitero comunale',
    coord = vector3(-1690.0, -230.0, 58.0),
    blip = { sprite = 274, colore = 0, scala = 0.8 },
    -- Dove si celebra
    celebrazione = vector3(-1696.0, -237.0, 58.2),
    -- Le lapidi si dispongono su una griglia
    griglia = {
        origine = vector3(-1710.0, -250.0, 58.0),
        passoX = 2.4, passoY = 3.0, perFila = 8,
    },
}

FUN.Costi = {
    -- Il funerale lo paga la famiglia, o il Comune se non c'è nessuno
    servizioBase = 380000,
    lapide = 120000,
    -- Il Comune interviene per chi non ha nessuno
    contributoComunale = 250000,
}

FUN.Regole = {
    -- La morte definitiva la chiede il giocatore, e va confermata due volte
    richiedeDoppiaConferma = true,
    -- Il personaggio resta consultabile nei registri, non si cancella
    conservaAnagrafe = true,
    -- Chi assiste al funerale resta scritto sulla lapide
    registraPresenti = true,
    distanzaPresenza = 20.0,
    durataCerimonia = 45000,
    -- L'eredità: quanto passa agli eredi designati
    quotaEredi = 0.5,
    -- Il resto va allo Stato, come le successioni senza testamento
    voceSuccessione = 'imposta_successione',
}

function FUN.PosizioneLapide(numero)
    local g = FUN.Cimitero.griglia
    local fila = math.floor((numero - 1) / g.perFila)
    local posto = (numero - 1) % g.perFila
    return vector3(
        g.origine.x + posto * g.passoX,
        g.origine.y + fila * g.passoY,
        g.origine.z
    )
end
