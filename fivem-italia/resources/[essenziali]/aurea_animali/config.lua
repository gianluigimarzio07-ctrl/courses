--[[
    AUREA · Animali — configurazione

    Un cane non è un oggetto: ha fame, si affeziona e se lo trascuri
    scappa. È l'unica cosa nel server che si perde per disattenzione e
    non per una scelta sbagliata.

    E c'è l'anagrafe canina, che in Italia è obbligatoria: senza microchip
    l'animale è irregolare e la sanzione la fa l'ASL.
]]

ANI = {}

ANI.Canile = {
    nome = 'Canile municipale',
    coord = vector3(1146.0, -1246.0, 34.0),
    blip = { sprite = 442, colore = 2, scala = 0.7 },
    -- Adozione: si paga solo il microchip e i vaccini
    costoAdozione = 12000,
}

ANI.Veterinario = {
    nome = 'Ambulatorio veterinario',
    coord = vector3(1698.0, 3584.0, 35.6),
    blip = { sprite = 442, colore = 3, scala = 0.7 },
    costoVisita = 24000,
    costoMicrochip = 8000,
}

--- Le razze disponibili. Ognuna ha un carattere che si sente giocando.
ANI.Razze = {
    pastore    = { nome = 'Pastore tedesco', modello = 'a_c_shepherd',  velocita = 1.10, guardia = true },
    rottweiler = { nome = 'Rottweiler',      modello = 'a_c_rottweiler', velocita = 1.05, guardia = true },
    husky      = { nome = 'Husky',           modello = 'a_c_husky',      velocita = 1.15, guardia = false },
    retriever  = { nome = 'Labrador',        modello = 'a_c_retriever',  velocita = 1.00, guardia = false },
    pug        = { nome = 'Carlino',         modello = 'a_c_pug',        velocita = 0.85, guardia = false },
    gatto      = { nome = 'Gatto',           modello = 'a_c_cat_01',     velocita = 0.95, guardia = false },
}

ANI.Bisogni = {
    -- Ogni quanti minuti reali cala la fame
    minutiPerPunto = 8,
    -- Sotto questa soglia l'animale è visibilmente sofferente
    sogliaSofferenza = 30,
    -- A zero, e trascurato abbastanza a lungo, se ne va
    minutiPrimaDellaFuga = 180,

    cibo = 'crocchette',
    puntiPerPasto = 40,
    guinzaglio = 'guinzaglio',
}

ANI.Affetto = {
    -- Cresce stando insieme, cala stando lontani
    massimo = 100,
    puntiPerCarezza = 4,
    puntiPerPasto = 6,
    minutiPerCalo = 45,
    -- Sotto questo affetto l'animale non obbedisce ai comandi
    sogliaObbedienza = 25,
}

ANI.Comandi = {
    { id = 'seguimi', nome = 'Seguimi',   icona = '🐾', affetto = 0 },
    { id = 'resta',   nome = 'Resta',     icona = '✋', affetto = 20 },
    { id = 'siedi',   nome = 'Seduto',    icona = '🪑', affetto = 35 },
    { id = 'cerca',   nome = 'Cerca',     icona = '🔍', affetto = 60,
      descrizione = 'Segnala droga e armi nascoste nel raggio. Solo cani da guardia.' },
    { id = 'guardia', nome = 'Fai la guardia', icona = '🛡', affetto = 70,
      descrizione = 'Avvisa quando qualcuno si avvicina. Solo cani da guardia.' },
}

ANI.Regole = {
    -- Un animale per persona
    massimoPerPersona = 1,
    -- L'anagrafe canina è obbligatoria
    sanzioneSenzaMicrochip = 42000,
    articoloSanzione = 'Art. 4 legge 281/1991 — omessa iscrizione all\'anagrafe',
}

function ANI.GetRazza(id) return ANI.Razze[id] end
