--[[
    AUREA · Organizzazioni criminali — configurazione

    L'idea che tiene insieme il modulo è il CALORE: ogni attività illecita
    alza l'attenzione delle forze dell'ordine sull'organizzazione. Il calore
    alto porta rendite ridotte, controlli automatici e, oltre una soglia,
    l'apertura di un'indagine per associazione. Restare sotto traccia conviene.
]]

FAM = {}

-- ---------------------------------------------------------------------------
--  Gerarchia interna
-- ---------------------------------------------------------------------------
FAM.Gradi = {
    [0] = { etichetta = 'Picciotto',   permessi = {} },
    [1] = { etichetta = 'Soldato',     permessi = { 'pizzo' } },
    [2] = { etichetta = 'Caporegime',  permessi = { 'pizzo', 'territori', 'cassa_preleva' } },
    [3] = { etichetta = 'Consigliere', permessi = { 'pizzo', 'territori', 'cassa_preleva', 'recluta' } },
    [4] = { etichetta = 'Capo',        permessi = { 'tutti' } },
}

-- ---------------------------------------------------------------------------
--  Calore investigativo
-- ---------------------------------------------------------------------------
FAM.Calore = {
    -- Quanto sale per tipo di attività
    perAttivita = {
        pizzo_imposto   = 6,
        pizzo_riscosso  = 2,
        riciclaggio     = 5,
        contesa         = 12,
        rendita         = 1,
        omicidio        = 25,
        rapina          = 15,
    },
    -- Quanto scende ogni ciclo di raffreddamento
    raffreddamento = 3,
    minutiRaffreddamento = 20,
    -- Soglie
    sogliaControlli = 45,      -- oltre: controlli automatici sui territori
    sogliaIndagine = 75,       -- oltre: apertura del fascicolo 416-bis
    -- Riduzione della rendita a calore alto
    penalitaRendita = 0.5,
}

-- ---------------------------------------------------------------------------
--  Pizzo
-- ---------------------------------------------------------------------------
FAM.Pizzo = {
    percentualeMassima = 20,
    percentualeMinima = 5,
    -- Il titolare può denunciare: se lo fa, il calore schizza
    calorePerDenuncia = 30,
    -- Quota della cassa che va al riscossore
    quotaRiscossore = 0.15,
}

-- ---------------------------------------------------------------------------
--  Riciclaggio
--  Il denaro non tracciato va ripulito prima di poter entrare in banca.
-- ---------------------------------------------------------------------------
FAM.Riciclaggio = {
    -- Percentuale trattenuta dal lavaggio
    commissione = 0.32,
    -- Con un'impresa compiacente la commissione scende
    commissioneConImpresa = 0.18,
    -- Massimo ripulibile per operazione
    massimoOperazione = 50,      -- unità di contanti_sporchi
    durata = 25000,
    -- Punti di calore per operazione
    calore = 5,
    lavanderie = {
        { nome = 'Lavanderia Vespucci', coord = vector3(-1204.6, -1550.5, 4.4) },
        { nome = 'Sala giochi Est',     coord = vector3(1141.0, -981.0, 46.4) },
        { nome = 'Autolavaggio Sud',    coord = vector3(-699.5, -932.0, 19.0) },
    },
}

-- ---------------------------------------------------------------------------
--  Territori contendibili (i codici corrispondono alla tabella territori)
-- ---------------------------------------------------------------------------
FAM.Territori = {
    porto         = { nome = 'Zona Portuale',       coord = vector3(1204.0, -3115.0, 5.5),   raggio = 180.0 },
    mercato       = { nome = 'Mercato Generale',    coord = vector3(-1080.2, -1250.9, 5.6),  raggio = 140.0 },
    quartiere_sud = { nome = 'Quartiere Sud',       coord = vector3(-47.4, -1758.5, 29.4),   raggio = 200.0 },
    lungomare     = { nome = 'Lungomare',           coord = vector3(-1850.0, -1230.0, 13.0), raggio = 190.0 },
    zona_ind      = { nome = 'Zona Industriale',    coord = vector3(920.0, -1800.0, 30.0),   raggio = 220.0 },
    centro_st     = { nome = 'Centro Storico',      coord = vector3(215.3, -810.4, 30.8),    raggio = 160.0 },
    periferia_e   = { nome = 'Periferia Est',       coord = vector3(1140.0, -450.0, 66.0),   raggio = 200.0 },
    collina       = { nome = 'Quartiere Collinare', coord = vector3(-1450.2, -390.5, 37.9),  raggio = 190.0 },
}

FAM.Contesa = {
    -- Durata della contesa
    durataMinuti = 12,
    -- Presenti richiesti per avviare
    minimoPartecipanti = 2,
    -- Punti di controllo guadagnati al minuto per ogni membro presente
    puntiPerMembro = 1.6,
    -- Controllo minimo per rivendicare il territorio
    sogliaConquista = 60,
    -- Attesa prima di poter ricontendere lo stesso territorio
    raffreddamentoMinuti = 45,
    -- Rendita erogata al proprietario
    minutiRendita = 30,
}

FAM.Regole = {
    costoFondazione = 5000000,   -- 50.000 €
    membriMassimi = 20,
    -- Quota della cassa prelevabile per volta dai gradi abilitati
    prelievoMassimo = 0.25,
}

function FAM.GradoHaPermesso(grado, permesso)
    local g = FAM.Gradi[grado]
    if not g then return false end
    for _, p in ipairs(g.permessi) do
        if p == 'tutti' or p == permesso then return true end
    end
    return false
end

function FAM.EtichettaGrado(grado)
    return (FAM.Gradi[grado] or FAM.Gradi[0]).etichetta
end
