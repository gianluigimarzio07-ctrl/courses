--[[
    AUREA · Corriere — configurazione

    Consegne a domicilio. La differenza rispetto a un giro di punti a
    caso: gli indirizzi sono immobili veri, e se il destinatario è in
    partita gli arriva la notifica e può venire a ritirare di persona —
    che è più veloce e vale di più per entrambi.
]]

COR = {}

COR.Lavoro = 'corriere'

COR.Deposito = {
    nome = 'Centro smistamento',
    coord = vector3(-424.0, -2790.0, 6.0),
    mezzi = { vector4(-432.0, -2782.0, 6.0, 45.0), vector4(-437.0, -2777.0, 6.0, 45.0) },
    modello = 'boxville3',
    blip = { sprite = 478, colore = 5, scala = 0.75 },
}

COR.Consegne = {
    -- Quanti pacchi si caricano per giro
    perGiro = 6,
    -- Paga base a pacco
    pagaBase = 8500,
    -- Se il destinatario ritira di persona, prende di più
    bonusRitiroDiretto = 0.6,
    -- Il pacco va portato a mano dal furgone alla porta
    distanzaPorta = 3.0,
    durataConsegna = 6000,
    -- Se un pacco non si consegna entro il tempo, torna in deposito
    minutiPerConsegna = 12,
    -- Il pacco si porta in mano
    prop = 'prop_cs_cardbox_01',
}

COR.Regole = {
    -- Chi guida troppo veloce con il furgone carico rovina i pacchi
    velocitaCritica = 110,
    penalitaPacchiRovinati = 0.5,
}
