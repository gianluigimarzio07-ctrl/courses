--[[
    AUREA · Ambiente — configurazione

    Il meteo non è casuale: segue le probabilità stagionali italiane e cambia
    per transizioni plausibili (dal sereno non si passa al temporale senza
    prima annuvolarsi). Il calendario porta con sé le festività, che
    cambiano davvero la città.
]]

AMB = {}

-- ---------------------------------------------------------------------------
--  Tempo di gioco
-- ---------------------------------------------------------------------------
AMB.Tempo = {
    -- Quanti minuti di gioco passano per ogni minuto reale
    scala = 6,
    -- Sincronizzazione verso i client
    intervalloSincroSecondi = 20,
    -- L'alba e il tramonto seguono la stagione, come in Italia
    albaPerMese  = { 7.6, 7.2, 6.4, 6.5, 5.8, 5.5, 5.7, 6.2, 6.8, 7.3, 7.0, 7.5 },
    tramontoPerMese = { 17.0, 17.6, 18.2, 20.0, 20.5, 20.9, 20.8, 20.2, 19.3, 18.4, 16.9, 16.7 },
}

-- ---------------------------------------------------------------------------
--  Meteo per stagione: probabilità relative
-- ---------------------------------------------------------------------------
AMB.Stagioni = {
    inverno   = { mesi = { 12, 1, 2 },  etichetta = 'Inverno' },
    primavera = { mesi = { 3, 4, 5 },   etichetta = 'Primavera' },
    estate    = { mesi = { 6, 7, 8 },   etichetta = 'Estate' },
    autunno   = { mesi = { 9, 10, 11 }, etichetta = 'Autunno' },
}

AMB.Probabilita = {
    inverno = {
        EXTRASUNNY = 12, CLEAR = 18, CLOUDS = 22, OVERCAST = 20,
        FOGGY = 12, RAIN = 10, THUNDER = 3, SMOG = 3,
    },
    primavera = {
        EXTRASUNNY = 26, CLEAR = 28, CLOUDS = 20, OVERCAST = 10,
        FOGGY = 3, RAIN = 9, THUNDER = 4,
    },
    estate = {
        EXTRASUNNY = 45, CLEAR = 30, CLOUDS = 13, OVERCAST = 4,
        RAIN = 3, THUNDER = 5,
    },
    autunno = {
        EXTRASUNNY = 14, CLEAR = 20, CLOUDS = 24, OVERCAST = 18,
        FOGGY = 8, RAIN = 12, THUNDER = 4,
    },
}

--- Transizioni plausibili: da uno stato si può passare solo a questi.
AMB.Transizioni = {
    EXTRASUNNY = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS' },
    CLEAR      = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'FOGGY' },
    CLOUDS     = { 'CLEAR', 'CLOUDS', 'OVERCAST', 'SMOG', 'FOGGY' },
    OVERCAST   = { 'CLOUDS', 'OVERCAST', 'RAIN', 'FOGGY' },
    RAIN       = { 'OVERCAST', 'RAIN', 'THUNDER', 'CLOUDS' },
    THUNDER    = { 'RAIN', 'OVERCAST' },
    FOGGY      = { 'FOGGY', 'CLOUDS', 'CLEAR', 'OVERCAST' },
    SMOG       = { 'SMOG', 'CLOUDS', 'CLEAR' },
}

AMB.Meteo = {
    -- Durata di una condizione, in minuti reali
    durataMinima = 12,
    durataMassima = 35,
    -- Durata della transizione visiva
    transizioneSecondi = 45,
}

-- ---------------------------------------------------------------------------
--  Festività italiane: cambiano l'atmosfera e portano effetti concreti
-- ---------------------------------------------------------------------------
AMB.Festivita = {
    { giorno = '01-01', nome = 'Capodanno',            effetto = 'festa',    messaggio = 'Buon anno. Molte attività sono chiuse.' },
    { giorno = '06-01', nome = 'Epifania',             effetto = 'festa' },
    { giorno = '25-04', nome = 'Festa della Liberazione', effetto = 'festa' },
    { giorno = '01-05', nome = 'Festa dei Lavoratori', effetto = 'lavoro',   messaggio = 'Oggi gli stipendi pubblici sono raddoppiati.' },
    { giorno = '02-06', nome = 'Festa della Repubblica', effetto = 'festa' },
    { giorno = '15-08', nome = 'Ferragosto',           effetto = 'esodo',    messaggio = 'Esodo estivo: la città è mezza vuota e il mare è pieno.' },
    { giorno = '01-11', nome = 'Ognissanti',           effetto = 'festa' },
    { giorno = '08-12', nome = 'Immacolata',           effetto = 'natale' },
    { giorno = '25-12', nome = 'Natale',               effetto = 'natale',   messaggio = 'Buon Natale. Le luminarie sono accese in tutta la città.' },
    { giorno = '26-12', nome = 'Santo Stefano',        effetto = 'natale' },
    { giorno = '31-12', nome = 'San Silvestro',        effetto = 'festa',    messaggio = 'Ultimo dell\'anno: attenzione ai botti.' },
}

--- Periodi lunghi che cambiano l'atmosfera
AMB.Periodi = {
    { da = '01-12', a = '06-01', nome = 'Periodo natalizio', effetto = 'natale' },
    { da = '01-08', a = '31-08', nome = 'Agosto',            effetto = 'esodo' },
}

-- ---------------------------------------------------------------------------
--  Eventi dinamici: cose che succedono in città da sole
-- ---------------------------------------------------------------------------
AMB.Eventi = {
    {
        id = 'mercato_settimanale',
        nome = 'Mercato settimanale',
        descrizione = 'Bancarelle in centro: i prezzi al dettaglio scendono.',
        durataMinuti = 60,
        probabilita = 12,
        oreValide = { 8, 14 },
        effetto = { tipo = 'prezzi', moltiplicatore = 0.85 },
        coord = vector3(-1080.2, -1250.9, 5.6),
    },
    {
        id = 'sciopero_trasporti',
        nome = 'Sciopero dei trasporti',
        descrizione = 'Le consegne rendono di più: manca personale.',
        durataMinuti = 90,
        probabilita = 7,
        effetto = { tipo = 'lavoro', moltiplicatore = 1.6 },
    },
    {
        id = 'allerta_meteo',
        nome = 'Allerta meteo arancione',
        descrizione = 'Pioggia intensa: strade viscide e visibilità ridotta.',
        durataMinuti = 45,
        probabilita = 8,
        forzaMeteo = 'THUNDER',
        effetto = { tipo = 'guida' },
    },
    {
        id = 'controlli_straordinari',
        nome = 'Controlli straordinari del territorio',
        descrizione = 'Posti di blocco: documenti alla mano.',
        durataMinuti = 50,
        probabilita = 10,
        effetto = { tipo = 'controlli' },
    },
    {
        id = 'sagra',
        nome = 'Sagra di paese',
        descrizione = 'A Paleto si mangia e si beve: prodotti tipici molto richiesti.',
        durataMinuti = 75,
        probabilita = 9,
        oreValide = { 17, 23 },
        effetto = { tipo = 'domanda', filiera = 'tutte', moltiplicatore = 1.4 },
        coord = vector3(-247.5, 6331.2, 32.4),
    },
    {
        id = 'blackout',
        nome = 'Blackout in centro',
        descrizione = 'Salta la corrente: allarmi e telecamere fuori uso.',
        durataMinuti = 30,
        probabilita = 5,
        oreValide = { 21, 4 },
        effetto = { tipo = 'blackout' },
        coord = vector3(215.3, -810.4, 30.8),
    },
}

AMB.IntervalloEventiMinuti = 25

-- ---------------------------------------------------------------------------
--  Helper
-- ---------------------------------------------------------------------------
function AMB.StagioneDelMese(mese)
    for id, s in pairs(AMB.Stagioni) do
        for _, m in ipairs(s.mesi) do
            if m == mese then return id, s end
        end
    end
    return 'primavera', AMB.Stagioni.primavera
end

--- Estrae una condizione meteo dalle probabilità stagionali, rispettando
--- le transizioni plausibili a partire da quella corrente.
function AMB.ProssimoMeteo(corrente, stagione)
    local ammessi = AMB.Transizioni[corrente] or { 'CLEAR' }
    local probabilita = AMB.Probabilita[stagione] or AMB.Probabilita.primavera

    local candidati, totale = {}, 0
    for _, meteo in ipairs(ammessi) do
        local peso = probabilita[meteo]
        if peso and peso > 0 then
            candidati[#candidati + 1] = { meteo = meteo, peso = peso }
            totale = totale + peso
        end
    end

    if totale == 0 then return 'CLEAR' end

    local estratto = math.random(totale)
    local accumulato = 0
    for _, c in ipairs(candidati) do
        accumulato = accumulato + c.peso
        if estratto <= accumulato then return c.meteo end
    end
    return candidati[1].meteo
end

function AMB.FestivitaOggi()
    local oggi = os.date('%d-%m')
    for _, f in ipairs(AMB.Festivita) do
        if f.giorno == oggi then return f end
    end
    return nil
end

function AMB.PeriodoCorrente()
    local giorno = tonumber(os.date('%d'))
    local mese = tonumber(os.date('%m'))

    for _, p in ipairs(AMB.Periodi) do
        local gDa, mDa = p.da:match('(%d+)-(%d+)')
        local gA, mA = p.a:match('(%d+)-(%d+)')
        gDa, mDa, gA, mA = tonumber(gDa), tonumber(mDa), tonumber(gA), tonumber(mA)

        local dopoInizio = mese > mDa or (mese == mDa and giorno >= gDa)
        local primaFine = mese < mA or (mese == mA and giorno <= gA)

        -- periodo che attraversa il capodanno
        if mDa > mA then
            if dopoInizio or primaFine then return p end
        elseif dopoInizio and primaFine then
            return p
        end
    end
    return nil
end
