--[[
    AUREA · Nautica da diporto — configurazione

    Il mare c'era e non serviva a niente: ci si poteva andare con qualunque
    barca, senza titolo, senza dotazioni, senza che nessuno controllasse.
    In un server italiano è uno spreco, perché la nautica da diporto è uno
    dei pochi ambiti in cui la regola è semplice, vera e facile da
    riconoscere.

    Tre cose la reggono:

      · LA PATENTE NAUTICA non serve sempre. Serve oltre le sei miglia,
        oltre i 40,8 cavalli, e per le moto d'acqua sempre. Sotto quella
        soglia si va senza. È la regola vera dell'art. 39 del Codice della
        nautica, ed è interessante da giocare proprio perché non è un
        divieto secco: è una soglia.

      · LE DOTAZIONI DI SICUREZZA sono obbligatorie e cambiano con la
        distanza dalla costa. Un controllo della Guardia Costiera che trova
        un giubbotto in meno è una sanzione, non un fastidio.

      · IL MARE È PERICOLOSO. Chi finisce in acqua lontano dalla costa non
        se la cava da solo, e il soccorso arriva solo se qualcuno lo
        chiama. È il motivo per cui il razzo di segnalazione conta.
]]

NAU = {}

NAU.Lavori = { 'guardia_finanza' }
NAU.LavoriSoccorso = { 'guardia_finanza', '118', 'vigili_fuoco' }

-- ---------------------------------------------------------------------------
--  La costa
--
--  La distanza dalla costa non si può misurare bene in GTA, quindi si
--  approssima con la distanza da un insieme di punti costieri. È una
--  bugia utile: dà lo stesso comportamento in gioco senza costare niente.
-- ---------------------------------------------------------------------------
NAU.Costa = {
    vector3(-1850.0, -1230.0, 0.0),   -- Del Perro
    vector3(-1600.0, -1080.0, 0.0),
    vector3(-1200.0, -1600.0, 0.0),
    vector3(-800.0, -2200.0, 0.0),
    vector3(-100.0, -2700.0, 0.0),
    vector3(700.0, -3000.0, 0.0),
    vector3(1300.0, -3300.0, 0.0),
    vector3(3300.0, -200.0, 0.0),     -- costa est
    vector3(3400.0, 2400.0, 0.0),
    vector3(1300.0, 4200.0, 0.0),     -- nord
    vector3(-200.0, 6600.0, 0.0),
    vector3(-2000.0, 5000.0, 0.0),    -- costa ovest
    vector3(-2800.0, 2000.0, 0.0),
    vector3(-3200.0, 800.0, 0.0),
}

--- Un miglio nautico sono 1852 metri; in GTA la scala è compressa, quindi
--- si usa un miglio "di gioco" più corto, altrimenti la mappa intera
--- starebbe dentro le sei miglia e la regola non si sentirebbe mai.
NAU.MetriPerMiglio = 260

NAU.Fasce = {
    { miglia = 1,  nome = 'Entro 1 miglio',   dotazioni = { 'giubbotto_salvataggio' } },
    { miglia = 3,  nome = 'Entro 3 miglia',   dotazioni = { 'giubbotto_salvataggio', 'razzo_segnalazione' } },
    { miglia = 6,  nome = 'Entro 6 miglia',   dotazioni = { 'giubbotto_salvataggio', 'razzo_segnalazione', 'kit_medico' } },
    { miglia = 12, nome = 'Entro 12 miglia',  dotazioni = { 'giubbotto_salvataggio', 'razzo_segnalazione', 'kit_medico', 'radio' }, richiedePatente = true },
    { miglia = 999, nome = 'Oltre 12 miglia', dotazioni = { 'giubbotto_salvataggio', 'razzo_segnalazione', 'kit_medico', 'radio' }, richiedePatente = true },
}

-- ---------------------------------------------------------------------------
--  Patente nautica
-- ---------------------------------------------------------------------------
NAU.Patente = {
    tipo = 'nautica',
    etichetta = 'Patente nautica entro 12 miglia',
    item = 'patente_nautica',
    rilasciata = 'Motorizzazione — Sezione nautica',
    costo = 24000,
    validitaGiorni = 1825,      -- cinque anni, come quella vera

    -- Oltre queste soglie la patente serve comunque (art. 39 Codice nautica)
    migliaSenzaPatente = 6,
    cavalliSenzaPatente = 40.8,
    -- Le moto d'acqua la vogliono sempre
    modelliSempreConPatente = { 'seashark', 'seashark2', 'seashark3' },

    -- Esame: domande vere sul Codice della nautica e sulla navigazione
    domandeEsame = 8,
    erroriAmmessi = 2,
    costoEsame = 9000,
}

--- Le domande. Come per l'autoscuola, la risposta giusta non lascia mai
--- il server: il client riceve solo il testo e le alternative.
NAU.Quiz = {
    {
        domanda = 'Entro quale distanza dalla costa si può navigare senza patente nautica, con motore fino a 40,8 CV?',
        opzioni = { 'Entro 6 miglia', 'Entro 3 miglia', 'Entro 12 miglia', 'Nessun limite' },
        giusta = 1,
        nota = 'Art. 39 D.Lgs. 171/2005: oltre le sei miglia la patente serve sempre.',
    },
    {
        domanda = 'Di notte, una nave che mostra luce bianca su tutto l\'orizzonte e nessuna luce di via è:',
        opzioni = { 'Alla fonda (ancorata)', 'In navigazione a motore', 'In pesca', 'Senza governo' },
        giusta = 1,
        nota = 'La luce bianca visibile a 360° senza luci di via indica una nave alla fonda.',
    },
    {
        domanda = 'Due unità a motore che si incrociano con rotte che portano a collisione: chi deve manovrare?',
        opzioni = { 'Quella che vede l\'altra alla propria dritta', 'Quella più veloce',
                    'Quella più grande', 'Nessuna: si accordano via radio' },
        giusta = 1,
        nota = 'Regola 15 COLREG: dà la precedenza chi ha l\'altra a dritta.',
    },
    {
        domanda = 'Il fanale di via verde di un\'unità a motore in navigazione si trova:',
        opzioni = { 'A dritta', 'A sinistra', 'A poppa', 'In testa d\'albero' },
        giusta = 1,
        nota = 'Verde a dritta, rosso a sinistra, bianco a poppa.',
    },
    {
        domanda = 'Che cosa segnala una bandiera rossa con banda diagonale bianca (bandiera Alfa)?',
        opzioni = { 'Sub in immersione: mantenersi a distanza', 'Divieto di balneazione',
                    'Unità in avaria', 'Zona di ancoraggio' },
        giusta = 1,
        nota = 'Segnala subacquei in immersione: si sta a 100 metri e a velocità minima.',
    },
    {
        domanda = 'Entro quanti metri dalla costa è vietata la navigazione a motore nelle spiagge frequentate?',
        opzioni = { '200 metri', '50 metri', '500 metri', '1000 metri' },
        giusta = 1,
        nota = 'Ordinanze di sicurezza balneare: 200 metri dalle spiagge, 100 dalle coste a picco.',
    },
    {
        domanda = 'Il numero da chiamare per un\'emergenza in mare è:',
        opzioni = { '1530', '112 soltanto', '118', '115' },
        giusta = 1,
        nota = 'Il 1530 è il numero blu della Guardia Costiera. Il 112 comunque smista.',
    },
    {
        domanda = 'Quale dotazione è sempre obbligatoria, a qualunque distanza dalla costa?',
        opzioni = { 'Le cinture di salvataggio per ogni persona a bordo', 'Il radar',
                    'La zattera autogonfiabile', 'Il VHF' },
        giusta = 1,
        nota = 'Un salvagente per persona è il minimo assoluto, anche sotto il miglio.',
    },
    {
        domanda = 'Un razzo a paracadute rosso in mare significa:',
        opzioni = { 'Richiesta di soccorso', 'Segnalazione di rotta libera',
                    'Inizio di una regata', 'Avviso di immersione' },
        giusta = 1,
        nota = 'È un segnale di pericolo: chi lo vede è tenuto a intervenire o a riferire.',
    },
    {
        domanda = 'La velocità massima consentita nelle acque portuali è normalmente:',
        opzioni = { '3 nodi', '10 nodi', '20 nodi', 'Non c\'è limite' },
        giusta = 1,
        nota = 'In porto si va al minimo, per non produrre onda.',
    },
}

-- ---------------------------------------------------------------------------
--  Porti e ormeggi
-- ---------------------------------------------------------------------------
NAU.Porti = {
    {
        id = 'marina_ovest',
        nome = 'Marina di Del Perro',
        capitaneria = vector3(-1604.9, -1069.0, 13.1),
        pontile = vector4(-1608.5, -1093.6, 0.2, 105.0),
        rimessaggio = vector3(-1600.2, -1057.4, 13.1),
        canoneMensile = 48000,
        blip = { sprite = 356, colore = 3, scala = 0.8 },
    },
    {
        id = 'porto_sud',
        nome = 'Porto commerciale',
        capitaneria = vector3(1198.4, -2996.7, 6.0),
        pontile = vector4(1215.6, -3033.9, 0.2, 175.0),
        rimessaggio = vector3(1204.0, -3002.1, 6.0),
        canoneMensile = 32000,
        blip = { sprite = 356, colore = 3, scala = 0.8 },
    },
    {
        id = 'paleto',
        nome = 'Porticciolo di Paleto',
        capitaneria = vector3(-278.5, 6635.3, 7.5),
        pontile = vector4(-290.1, 6653.2, 0.2, 45.0),
        rimessaggio = vector3(-274.0, 6631.0, 7.5),
        canoneMensile = 26000,
        blip = { sprite = 356, colore = 3, scala = 0.7 },
    },
}

-- ---------------------------------------------------------------------------
--  Noleggio
-- ---------------------------------------------------------------------------
NAU.Noleggio = {
    cauzione = 90000,
    listino = {
        { modello = 'dinghy',    nome = 'Gommone',            oraria = 12000, cavalli = 40,  patente = false },
        { modello = 'seashark',  nome = 'Moto d\'acqua',      oraria = 9000,  cavalli = 110, patente = true },
        { modello = 'suntrap',   nome = 'Barca da diporto',   oraria = 18000, cavalli = 90,  patente = true },
        { modello = 'jetmax',    nome = 'Motoscafo',          oraria = 34000, cavalli = 260, patente = true },
        { modello = 'marquis',   nome = 'Imbarcazione a vela',oraria = 26000, cavalli = 35,  patente = false },
        { modello = 'toro',      nome = 'Yacht sportivo',     oraria = 58000, cavalli = 400, patente = true },
    },
    -- Riportarla in ritardo costa
    penaleOraria = 22000,
}

-- ---------------------------------------------------------------------------
--  Controlli della Guardia Costiera
-- ---------------------------------------------------------------------------
NAU.Controlli = {
    sanzioneSenzaPatente = 227400,      -- art. 53 D.Lgs. 171/2005
    articoloSenzaPatente = 'art. 53 c.1 D.Lgs. 171/2005',
    sanzionePerDotazione = 27400,
    articoloDotazioni = 'art. 53 c.4 D.Lgs. 171/2005',
    sanzioneSottoCosta = 100600,
    articoloSottoCosta = 'ordinanza di sicurezza balneare',
    -- Sotto questa distanza dalla riva non si va a motore
    metriDallaRiva = 60,
    velocitaConsentitaSottoCosta = 12.0,   -- km/h
}

-- ---------------------------------------------------------------------------
--  Soccorso in mare
-- ---------------------------------------------------------------------------
NAU.Soccorso = {
    -- Oltre questa distanza dalla costa, chi è in acqua è in difficoltà
    migliaPericolo = 2,
    -- Ogni quanti secondi si perde salute in acqua aperta
    secondiTick = 20,
    dannoPerTick = 5,
    -- Il razzo di segnalazione manda la posizione a tutti i soccorritori
    razzo = 'razzo_segnalazione',
    compensoRecupero = 62000,
    raggioRecupero = 6.0,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------

--- Metri dalla costa, approssimati sul punto costiero più vicino.
function NAU.MetriDallaCosta(coord)
    local punto = vector3(coord.x, coord.y, 0.0)
    local minima = math.huge
    for _, c in ipairs(NAU.Costa) do
        local d = #(punto - c)
        if d < minima then minima = d end
    end
    return minima
end

function NAU.MigliaDallaCosta(coord)
    return NAU.MetriDallaCosta(coord) / NAU.MetriPerMiglio
end

function NAU.FasciaPer(miglia)
    for _, f in ipairs(NAU.Fasce) do
        if miglia <= f.miglia then return f end
    end
    return NAU.Fasce[#NAU.Fasce]
end

function NAU.GetPorto(id)
    for _, p in ipairs(NAU.Porti) do
        if p.id == id then return p end
    end
    return nil
end

function NAU.GetNoleggio(modello)
    for _, n in ipairs(NAU.Noleggio.listino) do
        if n.modello == modello then return n end
    end
    return nil
end

--- Serve la patente per questa unità a questa distanza?
function NAU.ServePatente(modello, miglia, cavalli)
    for _, m in ipairs(NAU.Patente.modelliSempreConPatente) do
        if m == modello then return true, 'moto d\'acqua' end
    end
    if miglia > NAU.Patente.migliaSenzaPatente then
        return true, ('oltre %d miglia'):format(NAU.Patente.migliaSenzaPatente)
    end
    if cavalli and cavalli > NAU.Patente.cavalliSenzaPatente then
        return true, ('motore oltre %.1f CV'):format(NAU.Patente.cavalliSenzaPatente)
    end
    return false, nil
end
