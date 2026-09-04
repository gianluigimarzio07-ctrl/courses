--[[
    AUREA · Sanità — configurazione

    Il ferito non muore: perde conoscenza. Da lì può essere soccorso dal 118,
    trasportato in ospedale o, dopo un'attesa, arrendersi e risvegliarsi al
    pronto soccorso pagando il ticket.
]]

MED = {}

MED.Ospedali = {
    {
        nome = 'Ospedale Centrale',
        coord = vector3(305.4, -595.0, 43.3),
        risveglio = vector4(340.0, -585.0, 43.3, 70.0),
        prontoSoccorso = vector3(298.4, -584.4, 43.3),
        blip = { sprite = 61, colore = 1, scala = 0.9 },
    },
    {
        nome = 'Ospedale di Paleto',
        coord = vector3(-247.5, 6331.2, 32.4),
        risveglio = vector4(-254.6, 6324.0, 32.4, 315.0),
        prontoSoccorso = vector3(-251.2, 6327.1, 32.4),
        blip = { sprite = 61, colore = 1, scala = 0.8 },
    },
    {
        nome = 'Ospedale di Sandy Shores',
        coord = vector3(1839.6, 3672.9, 34.3),
        risveglio = vector4(1833.0, 3679.5, 34.3, 210.0),
        prontoSoccorso = vector3(1836.2, 3675.4, 34.3),
        blip = { sprite = 61, colore = 1, scala = 0.8 },
    },
}

--- Parti del corpo colpibili, con conseguenze diverse
MED.PartiCorpo = {
    testa   = { etichetta = 'Testa',           gravita = 5, ossa = { 31086, 39317 } },
    collo   = { etichetta = 'Collo',           gravita = 5, ossa = { 39317 } },
    torace  = { etichetta = 'Torace',          gravita = 4, ossa = { 24818, 24817, 10706 } },
    addome  = { etichetta = 'Addome',          gravita = 4, ossa = { 11816 } },
    braccio_sx = { etichetta = 'Braccio sinistro', gravita = 2, ossa = { 45509, 61163, 18905 } },
    braccio_dx = { etichetta = 'Braccio destro',   gravita = 2, ossa = { 40269, 28252, 57005 } },
    gamba_sx = { etichetta = 'Gamba sinistra', gravita = 3, ossa = { 58271, 63931, 14201 } },
    gamba_dx = { etichetta = 'Gamba destra',   gravita = 3, ossa = { 51826, 36864, 52301 } },
}

--- Tipi di lesione
MED.Lesioni = {
    contusione   = { etichetta = 'Contusione',        emorragia = 0, dolore = 10, curaBase = true },
    lacerazione  = { etichetta = 'Lacerazione',       emorragia = 1, dolore = 20, curaBase = true },
    ferita_arma  = { etichetta = 'Ferita da arma da fuoco', emorragia = 3, dolore = 45, curaBase = false },
    frattura     = { etichetta = 'Frattura',          emorragia = 0, dolore = 55, curaBase = false, immobilizza = true },
    ustione      = { etichetta = 'Ustione',           emorragia = 1, dolore = 40, curaBase = false },
    trauma       = { etichetta = 'Trauma da impatto', emorragia = 2, dolore = 35, curaBase = false },
}

MED.Regole = {
    -- Salute sotto la quale si perde conoscenza invece di morire
    sogliaIncoscienza = 101,
    -- Secondi di incoscienza prima di poter chiedere il risveglio in ospedale
    secondiPrimaResa = 300,
    -- Danno al secondo per ogni punto di emorragia
    dannoEmorragia = 0.6,
    -- Ticket del pronto soccorso quando ci si risveglia senza soccorso
    ticketPronto = 45000,
    -- Ticket ridotto se il trasporto lo fa il 118
    ticket118 = 12000,
    -- Salute al risveglio
    saluteRisveglio = 140,
    -- Durata delle manovre
    duratsRianimazione = 12000,
    duratsMedicazione = 8000,
    duratsIngessatura = 15000,
    -- Probabilità che una rianimazione riesca senza kit medico
    successoSenzaKit = 0.35,
}

--- Conseguenze durature: restano finché non curate in ospedale
MED.Conseguenze = {
    zoppia      = { etichetta = 'Zoppia',          effetto = 'velocita' },
    tremore     = { etichetta = 'Tremore alle mani', effetto = 'mira' },
    offuscamento= { etichetta = 'Vista offuscata', effetto = 'vista' },
    fiato_corto = { etichetta = 'Fiato corto',     effetto = 'resistenza' },
}

--- Individua la parte del corpo dall'osso colpito.
function MED.ParteDaOsso(osso)
    for id, parte in pairs(MED.PartiCorpo) do
        for _, o in ipairs(parte.ossa) do
            if o == osso then return id, parte end
        end
    end
    return 'torace', MED.PartiCorpo.torace
end

--- Tipo di lesione a partire dall'arma che l'ha causata.
function MED.LesioneDaArma(hashArma)
    local corpoACorpo = {
        [`WEAPON_UNARMED`] = 'contusione', [`WEAPON_KNIFE`] = 'lacerazione',
        [`WEAPON_BAT`] = 'contusione', [`WEAPON_CROWBAR`] = 'contusione',
        [`WEAPON_HAMMER`] = 'frattura', [`WEAPON_MACHETE`] = 'lacerazione',
        [`WEAPON_BOTTLE`] = 'lacerazione',
    }
    if corpoACorpo[hashArma] then return corpoACorpo[hashArma] end

    if hashArma == `WEAPON_MOLOTOV` or hashArma == `WEAPON_PETROLCAN`
       or hashArma == `WEAPON_FIREEXTINGUISHER` then return 'ustione' end
    if hashArma == `WEAPON_RUN_OVER_BY_CAR` or hashArma == `WEAPON_RAMMED_BY_CAR`
       or hashArma == `WEAPON_FALL` then return 'trauma' end

    return 'ferita_arma'
end

function MED.OspedalePiuVicino(coord)
    local migliore, distanza = MED.Ospedali[1], math.huge
    for _, o in ipairs(MED.Ospedali) do
        local d = #(coord - o.coord)
        if d < distanza then migliore, distanza = o, d end
    end
    return migliore
end
