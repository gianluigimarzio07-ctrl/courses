--[[
    AUREA · Telefono — configurazione

    IL PROBLEMA CHE RISOLVE

    Le informazioni del personaggio erano finite in dieci posti diversi.
    Il saldo in banca sul telefono, i titoli di studio in /titoli, il
    portafoglio in criptovaluta in /cripto, i punti patente in un altro
    comando ancora, il fascicolo sanitario da nessuna parte. Ogni risorsa
    nuova aggiungeva un comando nuovo, e nessuno se li ricordava.

    Adesso è uno solo. Ma non è un telefono che sa tutto: è un telefono che
    non sa niente e mette a disposizione un posto dove stare.

    COME FUNZIONA

    Una risorsa registra la sua app sul server e la descrive con dati, non
    con HTML:

        AureaApp({
            id = 'cripto', nome = 'Exchange', icona = '🪙',
            schermata = function(g) return { tipo = 'lista', voci = { ... } } end,
            azione = function(g, id, dati) ... end,
        })

    AureaApp arriva dal ponte (@aurea_core/bridge/aurea.lua) e consegna
    l'app appena il telefono è in piedi, ripresentandosi se il telefono
    riparte: l'ordine degli ensure non conta. Chi preferisce può chiamare
    direttamente exports.aurea_telefono:RegistraApp, ma allora deve
    pensarci lui.

    Il telefono rende cinque forme di schermata (elenco, saldo, tessera,
    testo, griglia) e rimanda le azioni a chi ha registrato l'app. Chi
    aggiunge una risorsa nuova non tocca né l'HTML né il CSS né il
    JavaScript del telefono: scrive venti righe di Lua sul server e la sua
    app compare in home.

    Il vantaggio vero non è la comodità: è che il telefono non diventa il
    posto dove tutto si accumula. Le app vivono nella risorsa che le
    riguarda, e se quella risorsa non è installata l'app semplicemente non
    c'è — senza righe morte e senza errori.
]]

TEL = {}

-- ---------------------------------------------------------------------------
--  Apparecchio
-- ---------------------------------------------------------------------------
TEL.Oggetto = 'telefono'
TEL.Tasto = 'F1'

TEL.Regole = {
    -- Il telefono non si usa da morti né da ammanettati
    vietatoDaIncoscienti = true,
    vietatoDaAmmanettati = true,
    -- Distanza entro cui gli altri ti vedono col telefono in mano
    animazione = { dizionario = 'cellphone@', nome = 'cellphone_text_read_base' },
}

-- ---------------------------------------------------------------------------
--  Aspetto
-- ---------------------------------------------------------------------------
TEL.Aspetto = {
    operatore = 'AUREA',
    -- Il tema lo sceglie il giocatore dalle impostazioni e resta nelle
    -- sue metadata: 'scuro' | 'chiaro'
    temaPredefinito = 'scuro',
    sfondoPredefinito = 'notte',

    sfondi = {
        { id = 'notte',    nome = 'Notte',       css = 'linear-gradient(160deg,#0f1420,#1b2333 55%,#0b0e16)' },
        { id = 'tricolore',nome = 'Tricolore',   css = 'linear-gradient(160deg,#0b2e13,#f2f2f2 50%,#7a1620)' },
        { id = 'mare',     nome = 'Mare',        css = 'linear-gradient(160deg,#0a2b3d,#12607f 60%,#08202c)' },
        { id = 'terra',    nome = 'Terra',       css = 'linear-gradient(160deg,#2b1f14,#6b4a2a 55%,#1a120b)' },
        { id = 'carbone',  nome = 'Carbone',     css = 'linear-gradient(160deg,#101010,#242424 55%,#0a0a0a)' },
    },
}

-- ---------------------------------------------------------------------------
--  Chiamate
--
--  Il telefono non trasporta la voce: quella la fa aurea_voce, che si
--  appoggia a pma-voice. Qui si gestisce solo chi sta chiamando chi.
-- ---------------------------------------------------------------------------
TEL.Chiamate = {
    -- Secondi di squillo prima che la chiamata cada
    secondiSquillo = 30,
    -- Il numero si può nascondere, ma resta nei tabulati
    anonimoAmmesso = true,
    -- I tabulati li può chiedere la polizia giudiziaria
    lavoriTabulati = { 'carabinieri', 'polizia', 'guardia_finanza' },
    giorniTabulati = 7,
}

-- ---------------------------------------------------------------------------
--  Emergenze
-- ---------------------------------------------------------------------------
TEL.Emergenze = {
    { numero = '112', nome = 'Numero Unico Emergenze', ente = nil,               principale = true },
    { numero = '113', nome = 'Polizia di Stato',       ente = 'polizia' },
    { numero = '115', nome = 'Vigili del Fuoco',       ente = 'vigili_fuoco' },
    { numero = '117', nome = 'Guardia di Finanza',     ente = 'guardia_finanza' },
    { numero = '118', nome = 'Emergenza Sanitaria',    ente = '118' },
    { numero = '1530',nome = 'Guardia Costiera',       ente = 'guardia_finanza' },
    { numero = '1515',nome = 'Emergenza ambientale',   ente = 'vigili_fuoco' },
}

TEL.AvvisoEmergenze = 'Le chiamate infondate sono punite ai sensi dell\'art. 658 c.p.'

-- ---------------------------------------------------------------------------
--  App di base
--
--  Sono quelle che il telefono porta con sé. Tutte le altre arrivano dalle
--  risorse che le registrano, e compaiono qui in mezzo secondo l'ordine.
--
--  ordine: più basso, più in alto in home.
-- ---------------------------------------------------------------------------
TEL.Colori = {
    rubrica   = 'linear-gradient(150deg,#3d8bfd,#2a5fb0)',
    messaggi  = 'linear-gradient(150deg,#1f9d55,#157040)',
    telefono  = 'linear-gradient(150deg,#4cc26a,#2b7a41)',
    identita  = 'linear-gradient(150deg,#d4af37,#9d7f21)',
    banca     = 'linear-gradient(150deg,#2f7d5f,#1b4a38)',
    fisco     = 'linear-gradient(150deg,#6b6f7d,#3f434e)',
    annunci   = 'linear-gradient(150deg,#c26a2a,#8a4718)',
    emergenze = 'linear-gradient(150deg,#cf2e2e,#8d1c1c)',
    meteo     = 'linear-gradient(150deg,#3aa0c4,#1e6280)',
    note      = 'linear-gradient(150deg,#c9a227,#8a6d14)',
    impostazioni = 'linear-gradient(150deg,#5a6070,#343943)',
    -- A disposizione di chi registra un'app
    denaro    = 'linear-gradient(150deg,#c9a227,#7e6414)',
    salute    = 'linear-gradient(150deg,#d1443f,#8d2724)',
    studio    = 'linear-gradient(150deg,#7b52c9,#4b2f80)',
    lavoro    = 'linear-gradient(150deg,#2f6f9e,#1c4462)',
    stampa    = 'linear-gradient(150deg,#8a8377,#514c44)',
    veicoli   = 'linear-gradient(150deg,#4a5b7a,#28334a)',
}

-- ---------------------------------------------------------------------------
--  Note personali
-- ---------------------------------------------------------------------------
TEL.Note = {
    massime = 20,
    caratteri = 1200,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function TEL.GetSfondo(id)
    for _, s in ipairs(TEL.Aspetto.sfondi) do
        if s.id == id then return s end
    end
    return TEL.Aspetto.sfondi[1]
end

function TEL.GetEmergenza(numero)
    for _, e in ipairs(TEL.Emergenze) do
        if e.numero == numero then return e end
    end
    return nil
end
