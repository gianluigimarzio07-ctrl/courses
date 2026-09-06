--[[
    AUREA · Banchi da lavoro — configurazione

    C'era un problema silenzioso: mezzo server consuma grimaldelli, kit di
    riparazione, bende e centraline, ma nessuno li fabbrica. Tutto quello
    che si rompe o si consuma andava ricomprato al negozio, cioè creato dal
    nulla in cambio di denaro. Un'economia che produce solo denaro e non
    oggetti finisce per gonfiarsi e basta.

    Questi sono i banchi delle cose ordinarie. Il Made in Italy — vino,
    olio, formaggi, sartoria — resta in ita_madeinitaly, dove la qualità
    conta e la maestria si accumula: quella è un'altra cosa e non va
    mescolata. Qui non c'è qualità, c'è solo se sai farlo e se hai il
    materiale.

    Due regole che cambiano il gioco più di quanto sembri:

      · lo smontaggio restituisce parte dei materiali, quindi la roba
        vecchia vale qualcosa e non si butta;
      · alcuni banchi vogliono un mestiere, così un meccanico serve
        davvero a qualcosa anche quando non ripara niente.
]]

CRA = {}

-- ---------------------------------------------------------------------------
--  Banchi
-- ---------------------------------------------------------------------------
CRA.Banchi = {
    {
        id = 'ferramenta',
        nome = 'Banco da lavoro',
        coord = vector3(-336.6, -132.1, 39.0), raggio = 2.5,
        -- Chiunque, ma serve l'attrezzo giusto
        attrezzo = 'chiave_inglese',
        blip = { sprite = 446, colore = 46, scala = 0.7 },
    },
    {
        id = 'elettronica',
        nome = 'Banco di elettronica',
        coord = vector3(-1080.3, -248.0, 37.8), raggio = 2.5,
        attrezzo = 'tronchesi',
        blip = { sprite = 606, colore = 3, scala = 0.7 },
    },
    {
        id = 'officina',
        nome = 'Banco dell\'officina',
        coord = vector3(-347.0, -111.3, 39.0), raggio = 3.0,
        lavoro = 'meccanico',
        attrezzo = 'chiave_inglese',
        blip = { sprite = 446, colore = 5, scala = 0.7 },
    },
    {
        id = 'farmaceutico',
        nome = 'Banco farmaceutico',
        coord = vector3(303.9, -570.2, 43.3), raggio = 2.5,
        lavori = { '118', 'medico' },
        blip = { sprite = 51, colore = 1, scala = 0.7 },
    },
    {
        id = 'clandestino',
        nome = 'Banco clandestino',
        coord = vector3(1391.6, 3605.2, 34.9), raggio = 2.5,
        -- Nessun requisito, ma quello che ci si fa è tutto illecito
        illecito = true,
        blip = nil,
    },
}

-- ---------------------------------------------------------------------------
--  Ricette
--
--  banco:      su quale banco si fa
--  ingredienti: { { item, quantita }, ... }  consumati sempre
--  attrezzi:   { item, ... }  devono esserci ma non si consumano
--  produce:    { item, quantita }
--  durata:     millisecondi
--  smontabile: se il prodotto si può ridurre di nuovo in materiali
-- ---------------------------------------------------------------------------
CRA.Ricette = {
    -- ------------------------------------------------------------------ ferramenta
    {
        id = 'kit_riparazione', banco = 'ferramenta', durata = 14000,
        nome = 'Kit di riparazione',
        ingredienti = { { 'acciaio', 3 }, { 'plastica', 2 }, { 'rame', 1 } },
        produce = { 'kit_riparazione', 1 }, smontabile = true,
    },
    {
        id = 'corda', banco = 'ferramenta', durata = 9000,
        nome = 'Corda',
        ingredienti = { { 'tessuto_pregiato', 2 } },
        produce = { 'corda', 1 },
    },
    {
        id = 'tanica', banco = 'ferramenta', durata = 11000,
        nome = 'Tanica di carburante',
        ingredienti = { { 'plastica', 4 }, { 'acciaio', 1 } },
        produce = { 'tanica', 1 }, smontabile = true,
    },
    {
        id = 'tronchesi', banco = 'ferramenta', durata = 16000,
        nome = 'Tronchesi',
        ingredienti = { { 'acciaio', 4 }, { 'plastica', 1 } },
        attrezzi = { 'chiave_inglese' },
        produce = { 'tronchesi', 1 }, smontabile = true,
    },
    {
        id = 'guanti', banco = 'ferramenta', durata = 6000,
        nome = 'Guanti da lavoro',
        ingredienti = { { 'tessuto_pregiato', 1 }, { 'plastica', 1 } },
        produce = { 'guanti', 2 },
    },

    -- ------------------------------------------------------------------ elettronica
    {
        id = 'componenti_elettronici', banco = 'elettronica', durata = 12000,
        nome = 'Componenti elettronici',
        ingredienti = { { 'rame', 2 }, { 'plastica', 1 }, { 'quarzo', 1 } },
        produce = { 'componenti_elettronici', 3 },
    },
    {
        id = 'powerbank', banco = 'elettronica', durata = 13000,
        nome = 'Batteria portatile',
        ingredienti = { { 'componenti_elettronici', 2 }, { 'plastica', 2 } },
        produce = { 'powerbank', 1 }, smontabile = true,
    },
    {
        id = 'radio', banco = 'elettronica', durata = 20000,
        nome = 'Radio ricetrasmittente',
        ingredienti = { { 'componenti_elettronici', 4 }, { 'plastica', 2 }, { 'rame', 2 } },
        attrezzi = { 'tronchesi' },
        produce = { 'radio', 1 }, smontabile = true,
    },
    {
        id = 'gps_tracker', banco = 'elettronica', durata = 18000,
        nome = 'Localizzatore GPS',
        ingredienti = { { 'componenti_elettronici', 3 }, { 'quarzo', 1 } },
        produce = { 'gps_tracker', 1 }, smontabile = true,
    },
    {
        id = 'antifurto', banco = 'elettronica', durata = 22000,
        nome = 'Antifurto satellitare',
        ingredienti = { { 'componenti_elettronici', 5 }, { 'rame', 2 }, { 'plastica', 2 } },
        attrezzi = { 'tronchesi' },
        produce = { 'antifurto', 1 }, smontabile = true,
    },

    -- ------------------------------------------------------------------ officina
    {
        id = 'centralina', banco = 'officina', durata = 26000,
        nome = 'Centralina di ricambio',
        ingredienti = { { 'componenti_elettronici', 4 }, { 'rame', 3 }, { 'plastica', 2 } },
        attrezzi = { 'chiave_inglese' },
        produce = { 'centralina', 1 }, smontabile = true,
    },
    {
        id = 'cavi_avviamento', banco = 'officina', durata = 10000,
        nome = 'Cavi di avviamento',
        ingredienti = { { 'rame', 3 }, { 'plastica', 2 } },
        produce = { 'cavi_avviamento', 1 }, smontabile = true,
    },

    -- ------------------------------------------------------------------ farmaceutico
    {
        id = 'bendaggio', banco = 'farmaceutico', durata = 7000,
        nome = 'Bendaggio',
        ingredienti = { { 'tessuto_pregiato', 1 }, { 'disinfettante', 1 } },
        produce = { 'bendaggio', 3 },
    },
    {
        id = 'disinfettante', banco = 'farmaceutico', durata = 8000,
        nome = 'Disinfettante',
        ingredienti = { { 'solvente', 1 }, { 'erbe_officinali', 2 } },
        produce = { 'disinfettante', 2 },
    },
    {
        id = 'kit_medico', banco = 'farmaceutico', durata = 20000,
        nome = 'Kit medico',
        ingredienti = { { 'bendaggio', 3 }, { 'disinfettante', 2 }, { 'antidolorifico', 1 } },
        produce = { 'kit_medico', 1 },
    },
    {
        id = 'tampone_dna', banco = 'farmaceutico', durata = 6000,
        nome = 'Tampone sterile',
        ingredienti = { { 'plastica', 1 }, { 'tessuto_pregiato', 1 } },
        produce = { 'tampone_dna', 4 },
    },
    {
        id = 'narcotest', banco = 'farmaceutico', durata = 11000,
        nome = 'Narcotest',
        ingredienti = { { 'solvente', 2 }, { 'plastica', 1 }, { 'vetro', 1 } },
        produce = { 'narcotest', 2 },
    },

    -- ------------------------------------------------------------------ clandestino
    {
        id = 'grimaldello', banco = 'clandestino', durata = 15000,
        nome = 'Grimaldello',
        ingredienti = { { 'acciaio', 2 } },
        attrezzi = { 'tronchesi' },
        produce = { 'grimaldello', 2 }, illecito = true,
    },
    {
        id = 'spadino', banco = 'clandestino', durata = 12000,
        nome = 'Spadino',
        ingredienti = { { 'acciaio', 1 }, { 'plastica', 1 } },
        produce = { 'spadino', 2 }, illecito = true,
    },
    {
        id = 'targa_clonata', banco = 'clandestino', durata = 24000,
        nome = 'Targa clonata',
        ingredienti = { { 'plastica', 3 }, { 'acciaio', 1 }, { 'componenti_elettronici', 1 } },
        produce = { 'targa_clonata', 1 }, illecito = true,
    },
    {
        id = 'jammer', banco = 'clandestino', durata = 40000,
        nome = 'Disturbatore di frequenze',
        ingredienti = { { 'componenti_elettronici', 8 }, { 'rame', 4 }, { 'powerbank', 1 } },
        attrezzi = { 'tronchesi' },
        produce = { 'jammer', 1 }, illecito = true,
    },
}

-- ---------------------------------------------------------------------------
--  Smontaggio
--
--  Riduce un oggetto nei materiali della sua ricetta, in parte. È il modo
--  in cui la roba vecchia rientra nell'economia invece di sparire.
-- ---------------------------------------------------------------------------
CRA.Smontaggio = {
    -- Quota dei materiali che si recupera, arrotondata per difetto
    resa = 0.5,
    durata = 9000,
    -- Serve un attrezzo per smontare
    attrezzo = 'chiave_inglese',
}

-- ---------------------------------------------------------------------------
--  Regole
-- ---------------------------------------------------------------------------
CRA.Regole = {
    -- Il banco clandestino richiama attenzione
    probabilitaSegnalazione = 18,
    reatoIllecito = '697',
    -- Quante volte di fila si può produrre prima di dover riavviare il menu
    massimoPerVolta = 5,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function CRA.GetBanco(id)
    for _, b in ipairs(CRA.Banchi) do
        if b.id == id then return b end
    end
    return nil
end

function CRA.GetRicetta(id)
    for _, r in ipairs(CRA.Ricette) do
        if r.id == id then return r end
    end
    return nil
end

--- Le ricette di un banco.
function CRA.RicetteDi(banco)
    local out = {}
    for _, r in ipairs(CRA.Ricette) do
        if r.banco == banco then out[#out + 1] = r end
    end
    return out
end

--- La ricetta che produce un certo oggetto, se esiste ed è smontabile.
function CRA.RicettaDiProdotto(item)
    for _, r in ipairs(CRA.Ricette) do
        if r.produce[1] == item and r.smontabile then return r end
    end
    return nil
end

function CRA.BancoVicino(coord)
    for _, b in ipairs(CRA.Banchi) do
        if #(coord - b.coord) <= b.raggio + 1.0 then return b end
    end
    return nil
end
