--[[
    AUREA · Rifornimento distributori — configurazione

    I distributori hanno una cisterna che si svuota davvero, perché sono
    gli altri giocatori a fare benzina. Quando una pompa resta a secco,
    smette di erogare: e allora serve qualcuno che vada alla raffineria,
    carichi e rifornisca.

    È il lavoro meno appariscente del server, ed è quello che tiene in
    piedi tutti gli altri.
]]

BEN = {}

BEN.Lavoro = 'benzinaio'

BEN.Raffineria = {
    nome = 'Raffineria',
    coord = vector3(2680.0, 1450.0, 24.5),
    carico = vector3(2687.0, 1440.0, 24.5),
    mezzi = { vector4(2670.0, 1460.0, 24.5, 180.0) },
    modello = 'tanker',
    blip = { sprite = 361, colore = 5, scala = 0.8 },
}

BEN.Cisterna = {
    -- Litri che il mezzo porta
    capienza = 12000,
    durataCarico = 25000,
    durataScarico = 20000,
    distanzaScarico = 12.0,
    -- Quanto si paga al litro consegnato
    pagaAlLitro = 12,
}

--- I distributori serviti. Le coordinate coincidono con quelle di
--- aurea_garage: è la stessa pompa vista dall'altro lato.
BEN.Distributori = {
    { id = 'grove',    nome = 'Distributore di Grove',    coord = vector3(265.0, -1261.0, 29.3) },
    { id = 'porto',    nome = 'Distributore del porto',   coord = vector3(1208.0, -1402.0, 35.2) },
    { id = 'stazione', nome = 'Distributore stazione',    coord = vector3(-724.0, -935.0, 19.2) },
    { id = 'nord',     nome = 'Distributore nord',        coord = vector3(1687.0, 4929.0, 42.1) },
    { id = 'sandy',    nome = 'Distributore di Sandy',    coord = vector3(1701.0, 6416.0, 32.8) },
}

BEN.Serbatoi = {
    -- Litri che ogni distributore contiene a pieno
    capienza = 30000,
    -- Sotto questa soglia il distributore è "in riserva" e va rifornito
    sogliaAllarme = 0.25,
    -- A zero non eroga più
    -- Consumo di riferimento: quanto cala in autonomia ogni ora
    caloOrario = 400,
}

function BEN.GetDistributore(id)
    for _, d in ipairs(BEN.Distributori) do
        if d.id == id then return d end
    end
    return nil
end
