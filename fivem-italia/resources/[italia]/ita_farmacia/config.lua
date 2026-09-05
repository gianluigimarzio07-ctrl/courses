--[[
    AUREA · Farmacia — configurazione

    Alcuni farmaci si prendono al banco, altri no: per quelli serve la
    ricetta di un medico, e la ricetta è un oggetto vero che il medico
    firma e il farmacista ritira. È il pezzo che dà un senso al lavoro del
    118 anche quando non c'è nessuno da rianimare.
]]

FAR = {}

FAR.Farmacie = {
    { nome = 'Farmacia comunale',   coord = vector3(-133.0, -1284.0, 29.3) },
    { nome = 'Farmacia del Nord',   coord = vector3(1685.0, 4820.0, 42.0) },
    { nome = 'Farmacia del porto',  coord = vector3(1153.0, -1529.0, 35.4) },
}

FAR.Blip = { sprite = 51, colore = 25, scala = 0.65 }

--- Il ticket: quanto paga il cittadino su un farmaco con ricetta.
FAR.Ticket = { quota = 0.25, esenzioneRedditoSotto = 800000 }

FAR.Catalogo = {
    -- Da banco
    {
        item = 'antidolorifico', nome = 'Antidolorifico', prezzo = 4500,
        ricetta = false, descrizione = 'Attenua il dolore. Non cura niente.',
    },
    {
        item = 'bendaggio', nome = 'Bende', prezzo = 2800,
        ricetta = false, descrizione = 'Ferma un\'emorragia leggera.',
    },
    {
        item = 'disinfettante', nome = 'Disinfettante', prezzo = 3200,
        ricetta = false, descrizione = 'Evita che una ferita peggiori.',
    },
    -- Con ricetta
    {
        item = 'antibiotico', nome = 'Antibiotico', prezzo = 14000,
        ricetta = true, descrizione = 'Cura le infezioni. Serve la ricetta.',
    },
    {
        item = 'kit_medico', nome = 'Kit medico', prezzo = 38000,
        ricetta = true, descrizione = 'Per interventi seri sul posto.',
    },
    {
        item = 'adrenalina', nome = 'Adrenalina', prezzo = 52000,
        ricetta = true, descrizione = 'Rianima chi è in arresto. Solo con ricetta.',
    },
    {
        item = 'ansiolitico', nome = 'Ansiolitico', prezzo = 11000,
        ricetta = true, descrizione = 'Abbassa lo stress. Dà assuefazione.',
    },
}

FAR.Ricette = {
    -- Chi può prescrivere
    lavori = { 'medico' },
    -- Quanto vale una ricetta prima di scadere
    validitaOre = 48,
    -- Quante confezioni al massimo per ricetta
    confezioniMassime = 3,
}

function FAR.FarmaciaVicina(coord)
    for _, f in ipairs(FAR.Farmacie) do
        if #(coord - f.coord) < 3.0 then return f end
    end
    return nil
end

function FAR.GetFarmaco(item)
    for _, f in ipairs(FAR.Catalogo) do
        if f.item == item then return f end
    end
    return nil
end
