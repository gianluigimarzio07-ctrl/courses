--[[
    AUREA · Rapine — configurazione

    Il principio che le rende sensate: una rapina è possibile solo se
    qualcuno può rispondere. Se non c'è abbastanza personale in servizio,
    il colpo non parte — non per punire il giocatore, ma perché una rapina
    senza inseguimento non è roleplay, è un bancomat.

    La difficoltà scala: più il bersaglio è ricco, più agenti servono, più
    dura, più la refurtiva è difficile da spendere.
]]

RAP = {}

-- ---------------------------------------------------------------------------
--  Livelli di bersaglio
-- ---------------------------------------------------------------------------
RAP.Livelli = {
    esercizio = {
        nome = 'Esercizio commerciale',
        agentiRichiesti = 2,
        durata = 45000,
        attrezzo = nil,
        bottinoMin = 25, bottinoMax = 60,          -- banconote non tracciate
        raffreddamentoMinuti = 30,
        calore = 12,
        reato = '628',
        priorita112 = 'giallo',
    },
    gioielleria = {
        nome = 'Gioielleria',
        agentiRichiesti = 4,
        durata = 90000,
        attrezzo = 'grimaldello',
        bottinoMin = 120, bottinoMax = 240,
        raffreddamentoMinuti = 75,
        calore = 25,
        reato = '628',
        priorita112 = 'rosso',
        -- Le vetrine si aprono una alla volta
        vetrine = 6,
        durataVetrina = 12000,
    },
    portavalori = {
        nome = 'Furgone portavalori',
        agentiRichiesti = 4,
        durata = 60000,
        attrezzo = 'grimaldello',
        bottinoMin = 180, bottinoMax = 320,
        raffreddamentoMinuti = 60,
        calore = 22,
        reato = '628',
        priorita112 = 'rosso',
    },
    istituto = {
        nome = 'Istituto di credito',
        agentiRichiesti = 6,
        durata = 180000,
        attrezzo = 'grimaldello',
        richiedeInoltre = { 'jammer' },
        bottinoMin = 450, bottinoMax = 800,
        raffreddamentoMinuti = 150,
        calore = 40,
        reato = '628',
        priorita112 = 'rosso',
        -- Serve una squadra: non si fa da soli
        complicMinimi = 3,
        -- Fasi successive, ognuna con la sua durata
        fasi = {
            { nome = 'Disattivazione dell\'allarme', durata = 35000, attrezzo = 'jammer' },
            { nome = 'Apertura della porta blindata', durata = 55000, attrezzo = 'grimaldello' },
            { nome = 'Svuotamento del caveau', durata = 90000 },
        },
    },
}

-- ---------------------------------------------------------------------------
--  Bersagli sulla mappa
-- ---------------------------------------------------------------------------
RAP.Bersagli = {
    -- Esercizi commerciali
    { id = 'neg_vespucci',  livello = 'esercizio', nome = 'Alimentari Vespucci',   coord = vector3(25.7, -1347.3, 29.5) },
    { id = 'neg_grove',     livello = 'esercizio', nome = 'Alimentari Grove',      coord = vector3(-47.4, -1758.5, 29.4) },
    { id = 'neg_sandy',     livello = 'esercizio', nome = 'Alimentari Sandy',      coord = vector3(1961.5, 3740.7, 32.3) },
    { id = 'neg_paleto',    livello = 'esercizio', nome = 'Alimentari Paleto',     coord = vector3(-3242.2, 1000.4, 12.8) },
    { id = 'neg_mirror',    livello = 'esercizio', nome = 'Alimentari Mirror Park',coord = vector3(1163.4, -323.8, 69.2) },
    { id = 'neg_seoul',     livello = 'esercizio', nome = 'Alimentari Little Seoul',coord = vector3(-707.5, -914.4, 19.2) },
    { id = 'neg_delperro',  livello = 'esercizio', nome = 'Alimentari Del Perro',  coord = vector3(-1487.6, -379.1, 40.2) },

    -- Gioielleria
    { id = 'gioielleria',   livello = 'gioielleria', nome = 'Gioielleria del Centro', coord = vector3(-630.5, -236.5, 38.1) },

    -- Istituti di credito
    { id = 'banca_centro',  livello = 'istituto', nome = 'Filiale Centro',   coord = vector3(149.9, -1040.5, 29.4) },
    { id = 'banca_paleto',  livello = 'istituto', nome = 'Filiale Paleto',   coord = vector3(-112.2, 6469.9, 31.6) },
}

-- ---------------------------------------------------------------------------
--  Portavalori: girano per la città a orari variabili
-- ---------------------------------------------------------------------------
RAP.Portavalori = {
    modello = 'stockade',
    -- Percorsi: il furgone compare in uno di questi punti
    partenze = {
        vector4(149.9, -1040.5, 29.4, 340.0),
        vector4(-1212.9, -330.8, 37.8, 25.0),
        vector4(-2962.5, 482.2, 15.7, 85.0),
    },
    -- Ogni quanto ne circola uno
    minutiFraApparizioni = 45,
    -- Quanto resta prima di sparire
    minutiPermanenza = 25,
}

-- ---------------------------------------------------------------------------
--  Regole comuni
-- ---------------------------------------------------------------------------
RAP.Regole = {
    -- Distanza entro cui si può agire
    distanza = 3.0,
    -- Serve un'arma impugnata per minacciare
    richiedeArma = true,
    -- Chi partecipa deve restare nel raggio, altrimenti la rapina fallisce
    raggioPresenza = 40.0,
    -- Il bottino è in contanti non tracciati
    provento = 'contanti_sporchi',
    -- Ostaggi: prendere un ostaggio rallenta la risposta ma aggrava la pena
    reatoOstaggio = '605',
    -- Chi viene fermato entro questo tempo dalla rapina è colto in flagranza
    minutiFlagranza = 20,
    -- Le telecamere registrano: il volto coperto riduce le probabilità
    -- di essere identificati
    probabilitaIdentificazione = 70,
    probabilitaIdentificazioneMascherato = 15,
}

--- Bersaglio più vicino a una posizione.
function RAP.BersaglioVicino(coord)
    for _, b in ipairs(RAP.Bersagli) do
        if #(coord - b.coord) < RAP.Regole.distanza then return b end
    end
    return nil
end

function RAP.GetBersaglio(id)
    for _, b in ipairs(RAP.Bersagli) do
        if b.id == id then return b end
    end
    return nil
end
