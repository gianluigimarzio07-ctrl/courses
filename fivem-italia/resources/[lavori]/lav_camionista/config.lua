--[[
    AUREA · Camionista — configurazione

    Trasporto merci su lunga distanza. Non è "guida dal punto A al punto
    B": il carico si sposta se freni di colpo, e un carico che si sposta
    vale meno all'arrivo. Il pagamento è a merce consegnata integra.
]]

CAM = {}

CAM.Lavoro = 'camionista'

CAM.Deposito = {
    nome = 'Deposito merci',
    coord = vector3(1208.0, -3113.0, 5.5),
    mezzi = {
        vector4(1197.0, -3120.0, 5.5, 90.0),
        vector4(1197.0, -3126.0, 5.5, 90.0),
    },
    rimorchi = {
        vector4(1180.0, -3120.0, 5.5, 90.0),
    },
    blip = { sprite = 477, colore = 5, scala = 0.8 },
}

CAM.Motrice = 'phantom'
CAM.Rimorchio = 'trailers2'

--- Le destinazioni. La paga scala con la distanza e con la difficoltà.
CAM.Destinazioni = {
    { id = 'porto',    nome = 'Terminal portuale',  coord = vector3(1085.0, -2900.0, 5.9),  paga = 185000, difficolta = 1 },
    { id = 'aeroporto',nome = 'Cargo aeroportuale', coord = vector3(-1042.0, -2600.0, 20.0), paga = 240000, difficolta = 1 },
    { id = 'nord',     nome = 'Magazzino nord',     coord = vector3(1698.0, 4920.0, 42.0),   paga = 420000, difficolta = 2 },
    { id = 'montagna', nome = 'Deposito in quota',  coord = vector3(-570.0, 5350.0, 70.0),   paga = 560000, difficolta = 3 },
    { id = 'deserto',  nome = 'Piattaforma di Sandy', coord = vector3(1730.0, 3300.0, 41.2), paga = 380000, difficolta = 2 },
}

CAM.Carico = {
    -- Il carico si degrada se si guida male
    integritaIniziale = 100,
    -- Quanto si perde per ogni frenata brusca o urto
    perditaPerUrto = 8,
    perditaPerFrenata = 3,
    -- Sopra questa velocità in curva il carico si sposta
    velocitaCritica = 90,
    -- Sotto questa integrità il carico è rifiutato
    sogliaRifiuto = 40,
    -- La paga scala con l'integrità
    pagaProporzionale = true,
}

CAM.Regole = {
    -- Ogni viaggio dà esperienza: più viaggi, più destinazioni si aprono
    viaggiPerLivello = 5,
    livelloMassimo = 4,
    -- Il carburante è a carico del camionista
    rimborsoCarburante = 0.15,
}

function CAM.GetDestinazione(id)
    for _, d in ipairs(CAM.Destinazioni) do
        if d.id == id then return d end
    end
    return nil
end
