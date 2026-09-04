--[[
    AUREA · Immobili — configurazione

    Gli interni usano ambienti già presenti nella mappa base, resi privati
    tramite routing bucket: ogni immobile ha la propria istanza, quindi due
    appartamenti diversi non si vedono a vicenda anche se condividono le
    stesse coordinate.
]]

CASA = {}

--- Interni disponibili, con punti notevoli
CASA.Interni = {
    shell_piccolo = {
        etichetta = 'Monolocale',
        ingresso = vector4(266.1, -1007.5, -101.0, 0.0),
        deposito = vector3(268.9, -1002.3, -101.0),
        guardaroba = vector3(263.0, -999.5, -101.0),
        capienzaDeposito = 30, pesoDeposito = 80000,
    },
    shell_medio = {
        etichetta = 'Appartamento',
        ingresso = vector4(346.6, -998.9, -99.2, 180.0),
        deposito = vector3(341.1, -998.1, -99.2),
        guardaroba = vector3(350.3, -994.6, -99.2),
        capienzaDeposito = 50, pesoDeposito = 150000,
    },
    shell_grande = {
        etichetta = 'Residenza signorile',
        ingresso = vector4(-786.9, 323.1, 210.9, 180.0),
        deposito = vector3(-782.3, 328.5, 210.9),
        guardaroba = vector3(-793.6, 331.9, 217.0),
        capienzaDeposito = 90, pesoDeposito = 320000,
    },
    shell_locale = {
        etichetta = 'Locale commerciale',
        ingresso = vector4(-1220.0, -906.5, 12.3, 30.0),
        deposito = vector3(-1214.5, -900.2, 12.3),
        capienzaDeposito = 70, pesoDeposito = 250000,
    },
    shell_magazzino = {
        etichetta = 'Magazzino',
        ingresso = vector4(1009.7, -3195.0, -38.9, 180.0),
        deposito = vector3(1002.6, -3199.3, -38.9),
        capienzaDeposito = 150, pesoDeposito = 900000,
    },
}

CASA.Regole = {
    -- Imposta di registro sull'acquisto
    impostaRegistro = 0.09,
    -- Provvigione dell'agenzia
    provvigione = 0.03,
    -- Canone di locazione: percentuale del valore, addebitata ogni ciclo
    canoneSuValore = 0.004,
    minutiCanone = 240,
    -- Dopo quante mensilità non pagate scatta lo sfratto
    mensilitaSfratto = 3,
    -- Massimo di immobili per personaggio
    immobiliMassimi = 3,
    -- Numero massimo di chiavi cedibili
    chiaviMassime = 6,
    -- Sconto alla rivendita all'agenzia
    scontoRivendita = 0.75,
}

--- Agenzia immobiliare: da qui si consultano gli immobili in vendita
CASA.Agenzia = {
    nome = 'Agenzia Immobiliare',
    coord = vector3(-716.2, 261.5, 84.1),
    blip = { sprite = 374, colore = 2, scala = 0.8 },
}

function CASA.GetInterno(id) return CASA.Interni[id] or CASA.Interni.shell_medio end
