--[[
    AUREA · Nettezza urbana — configurazione

    Raccolta porta a porta. Il giro è un percorso di cassonetti da
    svuotare a piedi mentre il collega guida: è uno dei pochi lavori che
    funziona meglio in due, e la paga lo riflette.

    E la differenziata conta: quello che si separa vale, quello che si
    butta nell'indifferenziato vale la metà.
]]

NET = {}

NET.Lavoro = 'netturbino'

NET.Deposito = {
    nome = 'Deposito nettezza urbana',
    coord = vector3(-322.0, -1545.0, 31.0),
    mezzi = { vector4(-334.0, -1537.0, 27.6, 260.0), vector4(-334.0, -1543.0, 27.6, 260.0) },
    modello = 'trash',
    blip = { sprite = 318, colore = 2, scala = 0.7 },
}

--- I giri disponibili: ogni giro è una sequenza di cassonetti.
NET.Giri = {
    {
        id = 'centro', nome = 'Giro del centro', paga = 4200,
        punti = {
            vector3(-292.0, -1520.0, 31.0), vector3(-243.0, -1440.0, 31.0),
            vector3(-180.0, -1380.0, 31.0), vector3(-110.0, -1320.0, 30.0),
            vector3(-60.0, -1270.0, 29.5),  vector3(20.0, -1220.0, 29.3),
        },
    },
    {
        id = 'mare', nome = 'Giro del lungomare', paga = 4800,
        punti = {
            vector3(-1180.0, -1500.0, 4.4), vector3(-1250.0, -1440.0, 4.3),
            vector3(-1320.0, -1380.0, 4.4), vector3(-1400.0, -1320.0, 4.5),
            vector3(-1470.0, -1260.0, 4.5),
        },
    },
    {
        id = 'periferia', nome = 'Giro di periferia', paga = 5600,
        punti = {
            vector3(1210.0, -1420.0, 35.0), vector3(1150.0, -1350.0, 34.5),
            vector3(1080.0, -1290.0, 34.0), vector3(1020.0, -1230.0, 33.5),
            vector3(960.0, -1180.0, 33.0),  vector3(900.0, -1120.0, 32.5),
            vector3(840.0, -1060.0, 32.0),
        },
    },
}

NET.Raccolta = {
    distanzaPunto = 4.0,
    durataSvuotamento = 7000,
    -- Bonus per ogni collega in servizio sullo stesso mezzo
    bonusCollega = 0.35,
    -- Ogni cassonetto può contenere qualcosa di recuperabile
    probabilitaRecupero = 22,
    recuperabili = { 'plastica', 'acciaio', 'rame', 'componenti_elettronici' },
}

--- La differenziata: i materiali si conferiscono all'isola ecologica.
NET.Conferimento = {
    nome = 'Isola ecologica',
    coord = vector3(-351.0, -1560.0, 26.0),
    prezzi = {
        plastica = 900, acciaio = 1600, rame = 2400, componenti_elettronici = 3200,
    },
    -- Chi butta tutto insieme prende la metà
    penalitaIndifferenziato = 0.5,
}

function NET.GetGiro(id)
    for _, g in ipairs(NET.Giri) do
        if g.id == id then return g end
    end
    return nil
end
