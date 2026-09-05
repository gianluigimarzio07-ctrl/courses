--[[
    AUREA · Autonoleggio — configurazione

    Serve a chi è appena arrivato e non ha ancora un'auto, e a chi la sua
    l'ha lasciata dall'altra parte della città. Si paga a ore, si lascia
    una cauzione, e se il mezzo torna a pezzi la cauzione resta lì.
]]

NOL = {}

NOL.Punti = {
    { nome = 'Autonoleggio aeroporto', coord = vector3(-1037.0, -2733.0, 20.2),
      spawn = vector4(-1028.0, -2725.0, 20.2, 240.0) },
    { nome = 'Autonoleggio stazione',  coord = vector3(-215.0, -1000.0, 30.1),
      spawn = vector4(-225.0, -1012.0, 30.1, 160.0) },
}

NOL.Blip = { sprite = 524, colore = 3, scala = 0.65 }

NOL.Flotta = {
    { modello = 'blista',  nome = 'Utilitaria',   tariffaOraria = 22000, cauzione = 150000 },
    { modello = 'asea',    nome = 'Berlina',      tariffaOraria = 34000, cauzione = 250000 },
    { modello = 'baller',  nome = 'SUV',          tariffaOraria = 68000, cauzione = 500000 },
    { modello = 'faggio2', nome = 'Scooter',      tariffaOraria = 9000,  cauzione = 60000 },
    { modello = 'burrito3',nome = 'Furgone',      tariffaOraria = 45000, cauzione = 300000 },
}

NOL.Regole = {
    oreMinime = 1,
    oreMassime = 12,
    -- Sopra questa percentuale di danni si trattiene la cauzione
    sogliaDanni = 0.20,
    -- Riconsegna oltre l'orario: penale a ora iniziata
    penaleOraria = 1.5,
    -- Il mezzo si riconsegna dove si è preso
    riconsegnaOvunque = false,
}

function NOL.PuntoVicino(coord)
    for _, p in ipairs(NOL.Punti) do
        if #(coord - p.coord) < 4.0 then return p end
    end
    return nil
end

function NOL.GetVeicolo(modello)
    for _, v in ipairs(NOL.Flotta) do
        if v.modello == modello then return v end
    end
    return nil
end
