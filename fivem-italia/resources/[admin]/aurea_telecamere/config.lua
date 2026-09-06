--[[
    AUREA · Videosorveglianza — configurazione

    Serve a chiudere un cerchio che era aperto: la Scientifica trova le
    tracce dopo, il 112 riceve la chiamata durante, ma nessuno poteva
    guardare prima. Con le telecamere una pattuglia può vedere una rapina
    mentre succede, e un'indagine può partire da un'immagine invece che da
    una testimonianza.

    Il contrappeso è che le telecamere si possono spegnere. Un blackout le
    fa cadere tutte, un disturbatore di frequenze acceca quelle vicine, e
    la sala controllo lo dice: "questa non trasmette". Chi progetta un
    colpo ha un modo per toglierle di mezzo, e quel modo lascia una
    traccia sua.
]]

TVC = {}

TVC.Lavori = { 'carabinieri', 'polizia', 'guardia_finanza' }

--- Sale di controllo: da qui si accede al circuito
TVC.Sale = {
    { nome = 'Sala operativa — Comando Carabinieri', coord = vector3(446.7, -996.1, 30.7),
      circuito = 'urbano', raggio = 2.5 },
    { nome = 'Sala operativa — Questura', coord = vector3(437.3, -996.7, 30.7),
      circuito = 'urbano', raggio = 2.5 },
    { nome = 'Sala controllo — Casa Circondariale', coord = vector3(1780.8, 2592.1, 45.8),
      circuito = 'carcere', raggio = 2.5, lavori = { 'penitenziaria' } },
}

-- ---------------------------------------------------------------------------
--  Le telecamere
--
--  coord:    dove sta l'obiettivo
--  guarda:   verso dove punta di base
--  rotazione: quanto può ruotare a destra e a sinistra rispetto a "guarda"
--  zoom:     campo visivo minimo e massimo (fov)
-- ---------------------------------------------------------------------------
TVC.Telecamere = {
    -- ---------------------------------------------------------- circuito urbano
    { id = 'banca_centrale', nome = 'Banca Centrale — atrio', circuito = 'urbano',
      coord = vector3(253.8, 222.4, 106.3), guarda = 160.0, rotazione = 70.0 },
    { id = 'banca_esterno', nome = 'Banca Centrale — esterno', circuito = 'urbano',
      coord = vector3(263.1, 210.9, 111.0), guarda = 250.0, rotazione = 80.0 },
    { id = 'legion', nome = 'Legion Square', circuito = 'urbano',
      coord = vector3(215.9, -812.4, 36.0), guarda = 90.0, rotazione = 120.0 },
    { id = 'stazione', nome = 'Stazione Centrale', circuito = 'urbano',
      coord = vector3(-214.3, -1025.6, 36.0), guarda = 20.0, rotazione = 100.0 },
    { id = 'ospedale', nome = 'Ospedale Centrale — ingresso', circuito = 'urbano',
      coord = vector3(305.9, -589.1, 48.0), guarda = 200.0, rotazione = 90.0 },
    { id = 'porto', nome = 'Porto — varco doganale', circuito = 'urbano',
      coord = vector3(1205.7, -3110.4, 11.0), guarda = 90.0, rotazione = 110.0 },
    { id = 'gioielleria', nome = 'Gioielleria Vangelico', circuito = 'urbano',
      coord = vector3(-627.4, -234.1, 42.0), guarda = 130.0, rotazione = 80.0 },
    { id = 'aeroporto', nome = 'Aeroporto — piazzale', circuito = 'urbano',
      coord = vector3(-1037.9, -2731.5, 26.0), guarda = 330.0, rotazione = 100.0 },
    { id = 'tribunale', nome = 'Tribunale — ingresso', circuito = 'urbano',
      coord = vector3(242.9, -1063.0, 34.0), guarda = 180.0, rotazione = 70.0 },
    { id = 'municipio', nome = 'Municipio — piazza', circuito = 'urbano',
      coord = vector3(-544.2, -197.5, 43.0), guarda = 210.0, rotazione = 90.0 },
    { id = 'lungomare', nome = 'Lungomare — pontile', circuito = 'urbano',
      coord = vector3(-1849.4, -1225.7, 18.0), guarda = 40.0, rotazione = 120.0 },
    { id = 'paleto', nome = 'Paleto Bay — corso', circuito = 'urbano',
      coord = vector3(-269.6, 6229.7, 36.0), guarda = 45.0, rotazione = 110.0 },
    { id = 'sandy', nome = 'Sandy Shores — statale', circuito = 'urbano',
      coord = vector3(1961.9, 3745.1, 38.0), guarda = 300.0, rotazione = 110.0 },

    -- ---------------------------------------------------------- circuito carcere
    { id = 'car_cortile', nome = 'Cortile', circuito = 'carcere',
      coord = vector3(1770.4, 2545.9, 52.0), guarda = 180.0, rotazione = 130.0 },
    { id = 'car_bracci', nome = 'Corridoio bracci', circuito = 'carcere',
      coord = vector3(1771.2, 2564.7, 49.0), guarda = 90.0, rotazione = 60.0 },
    { id = 'car_ingresso', nome = 'Ingresso e matricola', circuito = 'carcere',
      coord = vector3(1783.6, 2596.2, 49.0), guarda = 250.0, rotazione = 70.0 },
    { id = 'car_recinzione', nome = 'Recinzione lato nord', circuito = 'carcere',
      coord = vector3(1793.9, 2586.8, 49.0), guarda = 300.0, rotazione = 90.0 },
    { id = 'car_officina', nome = 'Officina interna', circuito = 'carcere',
      coord = vector3(1757.1, 2539.4, 49.0), guarda = 20.0, rotazione = 80.0 },
}

-- ---------------------------------------------------------------------------
--  Comportamento della visuale
-- ---------------------------------------------------------------------------
TVC.Ottica = {
    fovMinimo = 20.0,       -- zoom massimo
    fovMassimo = 65.0,      -- grandangolo
    velocitaRotazione = 45.0,
    velocitaZoom = 30.0,
    -- Inclinazione consentita
    inclinazioneMin = -50.0,
    inclinazioneMax = 12.0,
    -- Distanza entro cui la sala controllo riconosce una persona
    distanzaRiconoscimento = 45.0,
}

-- ---------------------------------------------------------------------------
--  Guasti e sabotaggi
-- ---------------------------------------------------------------------------
TVC.Guasti = {
    -- Solo il circuito urbano dipende dalla rete pubblica: il carcere ha
    -- il suo gruppo elettrogeno, e infatti non lo si spegne dall'esterno.
    circuitoSuReteElettrica = 'urbano',

    -- Quali telecamere stanno sotto quale cabina di lav_elettricista.
    -- Non c'è un elenco per nome: si prende tutto quello che sta nel
    -- raggio, così aggiungere una telecamera non obbliga a ricordarsi di
    -- aggiornare anche questa tabella.
    cabine = {
        centro      = { coord = vector3(-538.0, -60.0, 42.0),   raggio = 900.0,  zona = 'Centro' },
        porto       = { coord = vector3(797.0, -2380.0, 30.0),  raggio = 1100.0, zona = 'Zona portuale' },
        vespucci    = { coord = vector3(-1230.0, -1300.0, 5.0), raggio = 900.0,  zona = 'Lungomare' },
        industriale = { coord = vector3(720.0, -960.0, 25.0),   raggio = 900.0,  zona = 'Zona industriale' },
        nord        = { coord = vector3(1690.0, 4880.0, 42.0),  raggio = 2500.0, zona = 'Paese nord' },
    },

    -- Il disturbatore di frequenze acceca le telecamere entro questo raggio
    jammer = { oggetto = 'jammer', raggio = 90.0, minuti = 8 },

    -- Un impianto rimasto giù troppo a lungo si riavvia da solo
    minutiRipristinoAutomatico = 25,
}

-- ---------------------------------------------------------------------------
--  Fermo immagine
--
--  Non è una foto vera: è un verbale con data, ora, telecamera e chi c'era
--  inquadrato. Serve come atto, non come immagine.
-- ---------------------------------------------------------------------------
TVC.Fermo = {
    -- Un fermo immagine ogni tot secondi, per non riempire il database
    secondiFraFermi = 20,
    -- Quanti fermi restano consultabili
    massimoConsultabili = 40,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function TVC.GetTelecamera(id)
    for _, t in ipairs(TVC.Telecamere) do
        if t.id == id then return t end
    end
    return nil
end

function TVC.Circuito(nome)
    local out = {}
    for _, t in ipairs(TVC.Telecamere) do
        if t.circuito == nome then out[#out + 1] = t end
    end
    return out
end

function TVC.SalaVicina(coord)
    for _, s in ipairs(TVC.Sale) do
        if #(coord - s.coord) <= s.raggio + 1.0 then return s end
    end
    return nil
end
