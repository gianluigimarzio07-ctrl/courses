--[[
    AUREA · Metriche — configurazione

    Quello che serve davvero sapere di un server che gira: quanti sono
    dentro, quanto denaro c'è in circolazione, se l'inflazione sta
    scappando, quali risorse stanno consumando tempo. Non è una vetrina:
    è il pannello che dice se qualcosa sta andando storto prima che se ne
    accorgano i giocatori.
]]

MET = {}

MET.Regole = {
    gruppoLettura = 'admin',
    -- Ogni quanto si campiona
    minutiCampionamento = 15,
    -- Quanti campioni si tengono
    campioniStorici = 96,      -- ventiquattro ore
    -- Soglie oltre le quali si avvisa lo staff
    soglie = {
        -- Millisecondi medi di tick sul server
        tickServer = 12.0,
        -- Massa monetaria oltre la quale l'economia è a rischio inflazione
        massaMonetaria = 5000000000,
        -- Rapporto fra denaro creato e distrutto nell'ultima ora
        rapportoCreazione = 1.6,
    },
}

--- Le voci del pannello.
MET.Pannello = {
    { id = 'giocatori',  nome = 'Giocatori connessi',   icona = '👥' },
    { id = 'economia',   nome = 'Massa monetaria',      icona = '💶' },
    { id = 'erario',     nome = 'Saldo dell\'erario',   icona = '🏛' },
    { id = 'veicoli',    nome = 'Veicoli immatricolati',icona = '🚗' },
    { id = 'immobili',   nome = 'Immobili assegnati',   icona = '🏠' },
    { id = 'imprese',    nome = 'Imprese attive',       icona = '🏢' },
    { id = 'prestazioni',nome = 'Prestazioni del server', icona = '⚙' },
}
