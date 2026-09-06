--[[
    AUREA · Persistenza — configurazione

    Il problema che risolve, e che quasi nessun server risolve: al riavvio
    tutto sparisce. L'auto che avevi lasciato in strada, il borsone posato
    dietro il capannone, la moto parcheggiata sotto casa. La mattina dopo
    la città è vuota e sterile, e nessuno lascia più niente in giro.

    Qui ogni veicolo intestato che sta fuori dal garage viene salvato dove
    si trova, con i suoi danni e il suo carburante, e al riavvio torna
    esattamente lì. Lo stesso per gli oggetti a terra.

    Il costo è che una città diventa piena di macchine abbandonate: per
    questo c'è la rimozione dei relitti, che dopo un po' porta via quello
    che nessuno tocca più.
]]

PER = {}

PER.Veicoli = {
    -- Ogni quanto si fotografa dove stanno i veicoli fuori
    minutiSalvataggio = 5,
    -- Al riavvio i veicoli tornano dove erano
    ripristinaAllAvvio = true,
    -- Quanti se ne ricreano insieme, per non ingolfare il caricamento
    perOndata = 8,
    pausaFraOndate = 2000,

    -- Non si salva quello che è in movimento con qualcuno dentro:
    -- quello lo salva già il garage quando si scende
    salvaSoloFermi = true,
    velocitaMassima = 1.0,

    -- I relitti: un veicolo che nessuno tocca da tanto viene rimosso
    oreRelitto = 72,
    -- Quello rimosso non si perde: torna in garage
    relittoInGarage = true,
}

PER.Oggetti = {
    -- Gli oggetti a terra si salvano già, ma qui si decide quanto durano
    oreDurata = 48,
    minutiSalvataggio = 10,
}

PER.Regole = {
    -- Il salvataggio non deve pesare: si fa a scaglioni
    scaglionato = true,
    -- All'arresto del server si salva comunque tutto
    salvaAllArresto = true,
}
