--[[
    AUREA · Autolavaggio — configurazione

    Lo sporco non è decorativo: si accumula guidando, e un mezzo sudicio
    è un mezzo che una pattuglia nota. Lavarlo costa poco, non lavarlo
    costa un controllo in più.
]]

LAV = {}

LAV.Impianti = {
    { nome = 'Autolavaggio di Vespucci', coord = vector3(-699.0, -932.0, 19.0), prezzo = 4500 },
    { nome = 'Autolavaggio della Stazione', coord = vector3(26.0, -1391.0, 29.3), prezzo = 4500 },
    { nome = 'Autolavaggio Nord', coord = vector3(1362.0, 3591.0, 34.9), prezzo = 3800 },
}

LAV.Lavaggio = {
    durata = 14000,
    distanza = 6.0,
    -- Quanto sporco si accumula ogni minuto di guida
    sporcoAlMinuto = 0.9,
    -- Sopra questa soglia il mezzo è visibilmente sporco
    sogliaVisibile = 6.0,
    massimo = 15.0,
}

function LAV.ImpiantoVicino(coord)
    for _, i in ipairs(LAV.Impianti) do
        if #(coord - i.coord) < LAV.Lavaggio.distanza then return i end
    end
    return nil
end
