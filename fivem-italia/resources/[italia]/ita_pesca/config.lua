--[[
    AUREA · Pesca professionale — configurazione

    NON È LA CANNA DA PESCA

    ita_attivita ha la pesca sportiva: licenza, taglie minime, specie
    protette, la Guardia Costiera che controlla. Va benissimo per un
    pomeriggio in banchina.

    Questa è un'altra cosa: il peschereccio, le quote, il mercato ittico.
    Un mestiere, con dentro il problema che ha il mestiere vero — il mare
    non è infinito e qualcuno tiene il conto.

    LE QUOTE

    Ogni specie ha una quota di cattura per il periodo, distribuita fra
    chi ha la licenza. Superarla è un illecito, e la quota non si ricarica
    perché hai finito: si ricarica quando finisce il periodo.

    Chi pesca oltre quota può sempre non dichiararlo. Il pesce non
    dichiarato non passa dal mercato ittico — va venduto a qualcun altro,
    a meno, e senza tracciabilità. È lo stesso schema della dogana e dei
    rifiuti, ed è lo schema con cui funziona davvero.

    IL MERCATO ITTICO

    Il pesce si vende all'asta, e il prezzo si muove: più ne arriva, meno
    vale. Chi esce per primo la mattina lo vende bene, chi arriva dopo
    trova il banco pieno.
]]

PES = {}

PES.Lavoro = 'pescatore'

-- ---------------------------------------------------------------------------
--  Il porto peschereccio
-- ---------------------------------------------------------------------------
PES.Porto = {
    nome = 'Mercato ittico',
    coord = vector3(-1602.4, 5260.8, 3.1),
    raggio = 3.5,
    blip = { sprite = 356, colore = 3, scala = 0.8 },
    -- Dove si prende il peschereccio
    imbarco = vector3(-1598.2, 5254.6, 0.4),
    modello = 'tug',
    modelloPiccolo = 'dinghy',
}

-- ---------------------------------------------------------------------------
--  Le zone di pesca
--
--  Più sono lontane, più rendono. E più è lontana, più è un problema se
--  si rompe qualcosa.
-- ---------------------------------------------------------------------------
PES.Zone = {
    {
        id = 'costa', nome = 'Sottocosta', coord = vector3(-1720.6, 5380.4, 0.0),
        raggio = 90.0, moltiplicatore = 1.0, minutiCalata = 3,
        specie = { 'branzino', 'orata', 'sarda' },
    },
    {
        id = 'secca', nome = 'Secca di Paleto', coord = vector3(-2240.8, 5920.2, 0.0),
        raggio = 120.0, moltiplicatore = 1.4, minutiCalata = 4,
        specie = { 'branzino', 'dentice', 'sarda' },
    },
    {
        id = 'altura', nome = 'Alto mare', coord = vector3(-3180.4, 6100.6, 0.0),
        raggio = 180.0, moltiplicatore = 1.9, minutiCalata = 6,
        specie = { 'tonno', 'dentice', 'gambero' },
        richiedeDotazioni = true,
    },
    {
        id = 'canyon', nome = 'Canyon sommerso', coord = vector3(3820.6, 4520.8, 0.0),
        raggio = 150.0, moltiplicatore = 2.2, minutiCalata = 7,
        specie = { 'tonno', 'gambero', 'dentice' },
        richiedeDotazioni = true,
    },
}

function PES.GetZona(id)
    for _, z in ipairs(PES.Zone) do
        if z.id == id then return z end
    end
end

-- ---------------------------------------------------------------------------
--  Le specie
--
--  `quota` è quanto se ne può pescare in tutto il periodo, fra tutti.
-- ---------------------------------------------------------------------------
PES.Specie = {
    sarda    = { nome = 'Sarde',    item = 'pesce_azzurro', prezzoBase = 900,   quota = 900, resa = { 6, 14 } },
    branzino = { nome = 'Branzino', item = 'branzino',      prezzoBase = 2800,  quota = 400, resa = { 3, 7 } },
    orata    = { nome = 'Orata',    item = 'orata',         prezzoBase = 2600,  quota = 400, resa = { 3, 7 } },
    dentice  = { nome = 'Dentice',  item = 'dentice',       prezzoBase = 4200,  quota = 220, resa = { 2, 5 } },
    gambero  = { nome = 'Gamberi',  item = 'gambero_rosso', prezzoBase = 5600,  quota = 180, resa = { 2, 4 } },
    tonno    = { nome = 'Tonno rosso', item = 'tonno_rosso', prezzoBase = 14000, quota = 60, resa = { 1, 2 },
                 -- Il tonno rosso ha una quota internazionale e un registro
                 -- dedicato: pescarne uno in più è una cosa seria
                 sanzioneExtraQuota = 400000 },
}

function PES.GetSpecie(id)
    return PES.Specie[id]
end

-- ---------------------------------------------------------------------------
--  Periodo di quota
-- ---------------------------------------------------------------------------
PES.Periodo = {
    minuti = 120,
    -- Sopra questa quota consumata il prezzo al mercato crolla
    sogliaAbbondanza = 0.60,
    caloPrezzoMassimo = 0.45,
}

-- ---------------------------------------------------------------------------
--  Licenza
-- ---------------------------------------------------------------------------
PES.Licenza = {
    costo = 180000,
    validitaMinuti = 480,
    -- Serve la patente nautica: un peschereccio è un'unità da diporto
    richiedePatenteNautica = true,
}

-- ---------------------------------------------------------------------------
--  La calata
-- ---------------------------------------------------------------------------
PES.Calata = {
    -- Va fatta in mare, sopra la zona, con il motore spento
    velocitaMassima = 3.0,
    -- Quante calate prima che la rete vada rammendata
    calatePerRete = 6,
    rete = 'rete_pesca',
    -- Rammendare costa tempo
    secondiRammendo = 30,
}

-- ---------------------------------------------------------------------------
--  Mercato e vendita in nero
-- ---------------------------------------------------------------------------
PES.Mercato = {
    -- Trattenuta del mercato ittico
    commissione = 0.08,
    -- Il nero: chi compra senza fattura paga meno, ma paga subito e in
    -- contanti — ed è quello che rende il fuori quota conveniente
    quotaNero = 0.62,
    -- Chi compra in nero
    ricettatore = vector3(-2190.4, 5180.6, 16.4),
}

-- ---------------------------------------------------------------------------
--  Controlli
-- ---------------------------------------------------------------------------
PES.Controlli = {
    lavoro = 'capitaneria',
    -- La Guardia Costiera è il reparto operativo della Capitaneria, e in
    -- AUREA sta in ita_capitaneria. Carabinieri e finanza restano
    -- ammessi: in mare fanno polizia giudiziaria come a terra.
    lavoriAmmessi = { 'capitaneria', 'carabinieri', 'guardia_finanza' },
    sanzioneSenzaLicenza = 250000,
    sanzioneFuoriQuota = 320000,
    reato = '256',
}

--- Il prezzo corrente di una specie, dato quanto della quota è andato.
function PES.Prezzo(specieId, consumata)
    local s = PES.GetSpecie(specieId)
    if not s then return 0 end

    local frazione = math.min(1, (consumata or 0) / s.quota)
    if frazione <= PES.Periodo.sogliaAbbondanza then return s.prezzoBase end

    local eccesso = (frazione - PES.Periodo.sogliaAbbondanza)
        / (1 - PES.Periodo.sogliaAbbondanza)
    return math.floor(s.prezzoBase * (1 - eccesso * PES.Periodo.caloPrezzoMassimo))
end
