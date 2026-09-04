--[[
    AUREA · Codice della Strada — configurazione

    Tre sistemi di rilevamento, tutti autonomi e senza agenti online:
      1. AUTOVELOX     postazioni fisse, rilevano la velocità istantanea
      2. TUTOR         tratte con calcolo della velocità media fra due portali
      3. VARCHI ZTL    lettura targhe agli accessi delle zone a traffico limitato
]]

CDS = {}

-- ---------------------------------------------------------------------------
--  Tolleranze e regole generali
-- ---------------------------------------------------------------------------
CDS.Regole = {
    -- Tolleranza di legge: 5% del limite con un minimo di 5 km/h
    tolleranzaPercentuale = 0.05,
    tolleranzaMinima      = 5,

    -- Un secondo verbale sulla stessa postazione non parte prima di N secondi
    antiDuplicatoSecondi  = 120,

    -- Sconto del 30% se il verbale viene pagato entro N giorni (art. 202 CdS)
    scontoGiorni          = 5,
    scontoPercentuale     = 0.30,

    -- Scadenza del verbale: dopo diventa cartella esattoriale maggiorata
    scadenzaGiorni        = 60,
    maggiorazioneRuolo    = 0.50,

    -- Patente
    puntiIniziali         = 20,
    puntiMassimi          = 20,
    -- Neopatentato: entro N minuti di gioco dal rilascio, punti raddoppiati
    neopatentatoMinuti    = 1800,
    -- Recupero punti: 2 punti ogni N minuti di guida senza infrazioni
    recuperoMinuti        = 240,
    recuperoPunti         = 2,
    -- Corso di recupero punti presso la Motorizzazione
    costoCorso            = 45000,   -- 450,00 €
    puntiCorso            = 6,
    durataCorsoMinuti     = 12,
}

-- ---------------------------------------------------------------------------
--  AUTOVELOX  ·  postazioni fisse
--  Il cono di rilevamento è dato da raggio + differenza di direzione.
-- ---------------------------------------------------------------------------
CDS.Autovelox = {
    { id = 'av_senora_n',   nome = 'Senora Freeway nord',    coord = vector3(2564.1, 2740.5, 42.9),   direzione = 190.0, limite = 130, raggio = 26.0 },
    { id = 'av_senora_s',   nome = 'Senora Freeway sud',     coord = vector3(2562.0, 2010.3, 40.1),   direzione = 10.0,  limite = 130, raggio = 26.0 },
    { id = 'av_olympic',    nome = 'Olympic Freeway',        coord = vector3(-490.3, -805.4, 30.4),   direzione = 265.0, limite = 90,  raggio = 22.0 },
    { id = 'av_delperro',   nome = 'Del Perro Freeway',      coord = vector3(-1198.0, -1502.2, 4.4),  direzione = 300.0, limite = 90,  raggio = 22.0 },
    { id = 'av_route68',    nome = 'Route 68 Harmony',       coord = vector3(1108.6, 2650.1, 37.9),   direzione = 88.0,  limite = 90,  raggio = 24.0 },
    { id = 'av_paleto',     nome = 'Great Ocean Hwy Paleto', coord = vector3(-269.6, 6244.5, 31.4),   direzione = 45.0,  limite = 90,  raggio = 24.0 },
    { id = 'av_vinewood',   nome = 'Vinewood Blvd',          coord = vector3(283.4, 175.9, 104.2),    direzione = 160.0, limite = 50,  raggio = 18.0 },
    { id = 'av_scuola',     nome = 'Zona scolastica Davis',  coord = vector3(196.3, -1650.4, 29.3),   direzione = 320.0, limite = 30,  raggio = 18.0, fascia = { 7, 17 } },
    { id = 'av_porto',      nome = 'Ingresso Porto',         coord = vector3(1023.5, -2980.6, 5.9),   direzione = 270.0, limite = 50,  raggio = 20.0 },
    { id = 'av_aeroporto',  nome = 'Viale Aeroporto',        coord = vector3(-1037.8, -2733.0, 20.2), direzione = 240.0, limite = 50,  raggio = 20.0 },
}

-- ---------------------------------------------------------------------------
--  TUTOR  ·  velocità media su tratta
--  L'infrazione scatta solo se la media sull'intera tratta supera il limite:
--  frenare davanti al portale non serve a niente.
-- ---------------------------------------------------------------------------
CDS.Tutor = {
    {
        id = 'tutor_senora',
        nome = 'Tratta Senora Freeway',
        limite = 130,
        ingresso = { coord = vector3(2400.4, 3050.7, 48.1), raggio = 40.0 },
        uscita   = { coord = vector3(2680.0, 1600.2, 35.0), raggio = 40.0 },
        lunghezza = 1470.0,   -- metri fra i due portali, per la media
    },
    {
        id = 'tutor_ovest',
        nome = 'Tratta Great Ocean Highway',
        limite = 90,
        ingresso = { coord = vector3(-2180.0, 4280.5, 48.0), raggio = 45.0 },
        uscita   = { coord = vector3(-1600.0, 5250.0, 18.0), raggio = 45.0 },
        lunghezza = 1130.0,
    },
    {
        id = 'tutor_olympic',
        nome = 'Tratta Olympic Freeway',
        limite = 90,
        ingresso = { coord = vector3(-180.0, -1080.0, 27.0), raggio = 35.0 },
        uscita   = { coord = vector3(-870.0, -680.0, 22.0), raggio = 35.0 },
        lunghezza = 800.0,
    },
}

-- ---------------------------------------------------------------------------
--  ZONE A TRAFFICO LIMITATO
--  poligono: elenco di vector2 in ordine (orario o antiorario, indifferente)
--  fasce: { {inizio, fine}, ... } in ore del tempo di gioco
--  giorni: 1 = lunedì ... 7 = domenica (nil = tutti)
-- ---------------------------------------------------------------------------
CDS.ZTL = {
    {
        id = 'centro_storico',
        nome = 'ZTL Centro Storico',
        limiteVelocita = 30,
        fasce = { { 7, 20 } },
        giorni = { 1, 2, 3, 4, 5, 6 },
        costoPermessoMensile = 4500,
        poligono = {
            vector2(-100.0, -1050.0), vector2(240.0, -1010.0), vector2(330.0, -790.0),
            vector2(180.0, -560.0),   vector2(-160.0, -600.0), vector2(-280.0, -840.0),
        },
    },
    {
        id = 'zona_pedonale_vespucci',
        nome = 'Area pedonale Vespucci',
        limiteVelocita = 20,
        fasce = { { 10, 23 } },
        costoPermessoMensile = 3000,
        poligono = {
            vector2(-1300.0, -1180.0), vector2(-1180.0, -1300.0),
            vector2(-1290.0, -1420.0), vector2(-1400.0, -1300.0),
        },
    },
    {
        id = 'ztl_rockford',
        nome = 'ZTL Rockford Hills',
        limiteVelocita = 30,
        fasce = { { 8, 19 } },
        giorni = { 1, 2, 3, 4, 5 },
        costoPermessoMensile = 7500,
        poligono = {
            vector2(-1600.0, -400.0), vector2(-1380.0, -280.0),
            vector2(-1230.0, -480.0), vector2(-1450.0, -640.0),
        },
    },
}

-- ---------------------------------------------------------------------------
--  SEMAFORI SORVEGLIATI  ·  incroci con rilevamento del passaggio con il rosso
--
--  GTA non espone lo stato reale del semaforo agli script, quindi il ciclo è
--  simulato: la fase deriva dall'ORA DI GIOCO, che il server sincronizza su
--  tutti i client. Tutti vedono quindi la stessa fase nello stesso istante e
--  il server può ricalcolarla in autonomia per validare il verbale.
-- ---------------------------------------------------------------------------
CDS.CicloSemaforo = { verde = 26, giallo = 4, rosso = 24 }   -- secondi

CDS.Semafori = {
    { id = 'sem_legion_1',  nome = 'Legion Square / Vespucci Blvd', coord = vector3(215.3, -810.4, 30.8),  direzione = 340.0, raggio = 12.0 },
    { id = 'sem_legion_2',  nome = 'Legion Square / Alta St',       coord = vector3(115.6, -750.2, 31.4),  direzione = 250.0, raggio = 12.0 },
    { id = 'sem_pillbox',   nome = 'Pillbox Hill / Strawberry Ave', coord = vector3(330.1, -560.7, 28.7),  direzione = 160.0, raggio = 12.0 },
    { id = 'sem_vinewood',  nome = 'Vinewood Blvd / Meteor St',     coord = vector3(310.9, 180.4, 103.5),  direzione = 70.0,  raggio = 12.0 },
    { id = 'sem_delperro',  nome = 'Del Perro / Bay City Ave',      coord = vector3(-1290.4, -640.1, 26.6),direzione = 30.0,  raggio = 12.0 },
    { id = 'sem_davis',     nome = 'Davis Ave / Grove St',          coord = vector3(90.2, -1560.8, 29.3),  direzione = 230.0, raggio = 12.0 },
    { id = 'sem_rockford',  nome = 'Rockford Dr / Portola Dr',      coord = vector3(-1450.2, -390.5, 37.9),direzione = 300.0, raggio = 12.0 },
    { id = 'sem_textile',   nome = 'Textile City / Elgin Ave',      coord = vector3(240.5, -380.2, 44.4),  direzione = 340.0, raggio = 12.0 },
}

--- Fase del semaforo per un dato id in un dato istante del giorno di gioco.
--- Ogni incrocio ha uno sfasamento stabile derivato dal proprio id, così i
--- semafori non scattano tutti insieme.
---@param id string
---@param secondiDelGiorno integer  ora*3600 + minuti*60 + secondi
---@return 'verde'|'giallo'|'rosso'
function CDS.FaseSemaforo(id, secondiDelGiorno)
    local ciclo = CDS.CicloSemaforo.verde + CDS.CicloSemaforo.giallo + CDS.CicloSemaforo.rosso

    local sfasamento = 0
    for i = 1, #id do sfasamento = (sfasamento * 31 + id:byte(i)) % ciclo end

    local t = (secondiDelGiorno + sfasamento) % ciclo
    if t < CDS.CicloSemaforo.verde then return 'verde' end
    if t < CDS.CicloSemaforo.verde + CDS.CicloSemaforo.giallo then return 'giallo' end
    return 'rosso'
end

-- ---------------------------------------------------------------------------
--  Sportello Motorizzazione: esami, corsi di recupero punti, duplicati
-- ---------------------------------------------------------------------------
CDS.Motorizzazione = {
    coord = vector3(240.7, -1379.5, 33.7),
    blip = { sprite = 525, colore = 3, scala = 0.8, nome = 'Motorizzazione Civile' },
    costoEsameTeoria = 12000,
    costoEsamePratica = 18000,
    costoDuplicato = 4200,
    categorie = {
        { id = 'AM', etichetta = 'AM — ciclomotori',  etaMinima = 14, costo = 9000 },
        { id = 'A',  etichetta = 'A — motocicli',     etaMinima = 18, costo = 22000, richiede = 'AM' },
        { id = 'B',  etichetta = 'B — autovetture',   etaMinima = 18, costo = 30000 },
        { id = 'C',  etichetta = 'C — autocarri',     etaMinima = 21, costo = 48000, richiede = 'B' },
        { id = 'D',  etichetta = 'D — autobus',       etaMinima = 24, costo = 62000, richiede = 'B' },
        { id = 'E',  etichetta = 'E — rimorchi',      etaMinima = 21, costo = 35000, richiede = 'B' },
    },
}

-- ---------------------------------------------------------------------------
--  Sportello pagamento verbali (Comune)
-- ---------------------------------------------------------------------------
CDS.SportelloVerbali = {
    coord = vector3(-544.2, -204.4, 38.2),
    blip = { sprite = 498, colore = 5, scala = 0.75, nome = 'Ufficio Verbali' },
}

--- Verifica se un'ora rientra in una delle fasce configurate.
function CDS.InFascia(fasce, ora)
    if not fasce or #fasce == 0 then return true end
    for _, f in ipairs(fasce) do
        local inizio, fine = f[1], f[2]
        if inizio <= fine then
            if ora >= inizio and ora < fine then return true end
        else
            -- fascia che attraversa la mezzanotte
            if ora >= inizio or ora < fine then return true end
        end
    end
    return false
end

--- Punto dentro poligono (ray casting).
function CDS.DentroPoligono(punto, poligono)
    local dentro = false
    local j = #poligono
    for i = 1, #poligono do
        local a, b = poligono[i], poligono[j]
        if ((a.y > punto.y) ~= (b.y > punto.y)) and
           (punto.x < (b.x - a.x) * (punto.y - a.y) / (b.y - a.y) + a.x) then
            dentro = not dentro
        end
        j = i
    end
    return dentro
end

--- Soglia oltre la quale scatta il verbale, tolleranza inclusa.
function CDS.SogliaVelocita(limite)
    return limite + math.max(CDS.Regole.tolleranzaMinima, limite * CDS.Regole.tolleranzaPercentuale)
end
