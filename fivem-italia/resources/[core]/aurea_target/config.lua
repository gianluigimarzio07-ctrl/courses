--[[
    AUREA · Terzo occhio — configurazione

    Il problema che risolve: fino a ieri ogni risorsa disegnava il proprio
    prompt "premi E" e due punti vicini si accavallavano. Qui le opzioni si
    registrano in un posto solo e il giocatore le vede tutte insieme,
    puntando con il mouse.

    Una risorsa non tocca questo file: registra le sue voci con gli export.

        exports.aurea_target:AggiungiZona('officina', coord, raggio, {
            { etichetta = 'Apri il listino', icona = '🔧',
              lavoro = 'meccanico',
              azione = function() apriListino() end },
        })

        exports.aurea_target:AggiungiModello({ `prop_atm_01` }, {
            { etichetta = 'Preleva', icona = '💶', azione = ... },
        })
]]

TGT = {}

TGT.Tasto = 25              -- tasto destro: tieni premuto per mirare
TGT.TastoSelezione = 24     -- tasto sinistro: conferma

TGT.Distanza = 4.0          -- portata massima del raggio
TGT.DistanzaEntita = 3.0    -- portata su ped e veicoli

-- Ogni quanto si ricalcola cosa c'è sotto il puntatore
TGT.Frequenza = 60

TGT.Colori = {
    -- Contorno del punto quando è a tiro
    attivo   = { 200, 165, 90, 220 },
    inattivo = { 255, 255, 255, 90 },
}

--- Voci che valgono ovunque, su qualunque veicolo.
TGT.VociVeicolo = {
    {
        id = 'bagagliaio', etichetta = 'Apri il bagagliaio', icona = '🎒',
        -- Solo da fuori e sul retro
        soloEsterno = true,
    },
    {
        id = 'cofano', etichetta = 'Apri il cofano', icona = '🔧',
        soloEsterno = true,
    },
}

--- Voci che valgono su qualunque persona a portata di mano.
TGT.VociPersona = {
    { id = 'documenti', etichetta = 'Chiedi i documenti', icona = '🪪' },
    { id = 'perquisisci', etichetta = 'Perquisisci', icona = '🔍',
      lavori = { 'carabinieri', 'polizia', 'guardia_finanza' }, inServizio = true },
}
