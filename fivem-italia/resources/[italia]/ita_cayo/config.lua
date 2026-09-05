--[[
    AUREA · Punta Corvo — configurazione

    L'isola del latitante.

    Da vent'anni un capocosca gestisce dal mare le rotte della cocaina che
    entrano dal porto. Vive in una villa fortificata su uno scoglio fuori
    giurisdizione, e da lì decide chi lavora e chi no. Chi vuole entrare in
    quel giro senza chiedere permesso ha una sola strada: andarlo a prendere
    dove sta.

    Il colpo è la cosa più lunga che si può fare su questo server, e non è
    un caso: è costruito in sei momenti e ognuno può saltare.

      1. RICOGNIZIONE   ci vai in incognito e fotografi. Ogni foto è
                        un'opzione che si apre; senza foto non si parte.
      2. PREPARATIVI    l'attrezzatura si compra o si ruba, non si evoca.
      3. APPROCCIO      mare, aria o container: tre vie, tre requisiti.
      4. INFILTRAZIONE  torre radio e quadro elettrico prima del caveau.
      5. BOTTINO        il primario è fisso, i secondari costano tempo.
      6. RIENTRO        il bottino va portato a terra, e a terra c'è la
                        Guardia di Finanza.

    Nota sulle coordinate: sono quelle dell'isola del DLC Cayo Perico e
    vanno rifinite in gioco. Il modulo funziona lo stesso con qualunque
    punto: cambia i vector3 e resta tutto coerente.
]]

CAY = {}

CAY.Isola = {
    nome = 'Punta Corvo',
    -- Centro dell'isola: serve a capire se qualcuno è "sull'isola"
    centro = vector3(4840.0, -5174.0, 2.0),
    raggio = 1800.0,
    -- Da qui si guarda il mare e si vede lo scoglio
    puntoOsservazione = vector3(-1850.0, -1240.0, 8.6),
    blip = { sprite = 568, colore = 5, scala = 1.0 },
}

-- ---------------------------------------------------------------------------
--  1. RICOGNIZIONE
--
--  Ogni bersaglio fotografato sblocca qualcosa. Chi fa il sopralluogo non
--  deve essere per forza chi entra: la ricognizione vale per la squadra.
-- ---------------------------------------------------------------------------
CAY.Ricognizione = {
    attrezzo = 'fotocamera',
    distanzaScatto = 22.0,
    durataScatto = 4000,
    -- Per quanti minuti resta valida
    validitaMinuti = 90,
    -- Quanti bersagli servono come minimo per poter pianificare
    minimoObbligatori = 3,

    bersagli = {
        {
            id = 'approdo', nome = 'Il punto di sbarco',
            coord = vector3(4979.0, -5170.0, 2.5),
            sblocca = 'Consente l\'approccio via mare.',
            obbligatorio = true,
        },
        {
            id = 'quadro', nome = 'Il quadro elettrico',
            coord = vector3(5008.0, -5757.0, 20.5),
            sblocca = 'Consente di spegnere le telecamere.',
            obbligatorio = true,
        },
        {
            id = 'torre', nome = 'La torre radio',
            coord = vector3(4891.0, -5744.0, 33.0),
            sblocca = 'Consente di isolare la villa dai rinforzi.',
            obbligatorio = true,
        },
        {
            id = 'caveau', nome = 'La stanza blindata',
            coord = vector3(5008.0, -5751.0, 15.0),
            sblocca = 'Individua il bottino principale.',
            obbligatorio = true,
        },
        {
            id = 'pista', nome = 'La pista d\'atterraggio',
            coord = vector3(4487.0, -4497.0, 4.0),
            sblocca = 'Consente l\'approccio dal cielo.',
        },
        {
            id = 'porto', nome = 'Il molo dei container',
            coord = vector3(4525.0, -4477.0, 3.5),
            sblocca = 'Consente l\'ingresso nascosto in un container.',
        },
        {
            id = 'deposito', nome = 'Il deposito della cocaina',
            coord = vector3(5185.0, -5216.0, 2.5),
            sblocca = 'Aggiunge la cocaina fra i bottini secondari.',
        },
        {
            id = 'quadreria', nome = 'La quadreria',
            coord = vector3(4972.0, -5735.0, 20.5),
            sblocca = 'Aggiunge i dipinti fra i bottini secondari.',
        },
    },
}

-- ---------------------------------------------------------------------------
--  2. PREPARATIVI
-- ---------------------------------------------------------------------------
CAY.Attrezzatura = {
    -- Sempre necessari
    obbligatori = {
        { item = 'grimaldello', quantita = 1, nota = 'Per le porte di servizio.' },
        { item = 'jammer', quantita = 1, nota = 'Per zittire la torre radio.' },
        { item = 'borsone', quantita = 1, nota = 'Per portare via qualcosa.' },
    },
    -- Necessari solo per certi approcci o certe fasi
    opzionali = {
        { item = 'muta', quantita = 1, nota = 'Indispensabile per l\'approccio via mare.' },
        { item = 'tronchesi', quantita = 1, nota = 'Velocizza il quadro elettrico.' },
        { item = 'esplosivo', quantita = 1, nota = 'Apre il caveau in un terzo del tempo, ma si sente.' },
        { item = 'documento_falso', quantita = 1, nota = 'Serve per entrare dal molo dei container.' },
    },
}

-- ---------------------------------------------------------------------------
--  3. APPROCCIO
-- ---------------------------------------------------------------------------
CAY.Approcci = {
    mare = {
        nome = 'Via mare, dalla grotta',
        descrizione = 'Si scende in acqua al largo e si entra dalla grotta sotto la villa.',
        richiedeFoto = 'approdo',
        richiedeItem = 'muta',
        -- Sospetto iniziale: quanto si parte già "visti"
        sospettoIniziale = 5,
        -- Punto in cui la squadra si ritrova
        punto = vector3(4979.0, -5170.0, 2.5),
    },
    aria = {
        nome = 'Dal cielo, col paracadute',
        descrizione = 'Il salto è rapido ma ti lascia allo scoperto appena tocchi terra.',
        richiedeFoto = 'pista',
        sospettoIniziale = 25,
        punto = vector3(4487.0, -4497.0, 4.0),
    },
    container = {
        nome = 'Nel container, dal molo',
        descrizione = 'Entri con la merce. È la via più silenziosa e la più lenta.',
        richiedeFoto = 'porto',
        richiedeItem = 'documento_falso',
        sospettoIniziale = 0,
        punto = vector3(4525.0, -4477.0, 3.5),
    },
}

-- ---------------------------------------------------------------------------
--  4. INFILTRAZIONE
--
--  Ogni fase alza il sospetto. Oltre 100 la villa si chiude e il colpo
--  salta: è il contatore che rende il tempo una risorsa.
-- ---------------------------------------------------------------------------
CAY.Fasi = {
    {
        id = 'torre', nome = 'Isolare la torre radio',
        coord = vector3(4891.0, -5744.0, 33.0),
        durata = 25000,
        richiedeItem = 'jammer',
        sospetto = 12,
        nota = 'Senza radio la villa non chiama nessuno.',
    },
    {
        id = 'quadro', nome = 'Staccare il quadro elettrico',
        coord = vector3(5008.0, -5757.0, 20.5),
        durata = 30000,
        durataConAttrezzo = 16000,
        attrezzoVeloce = 'tronchesi',
        sospetto = 18,
        nota = 'Le telecamere si spengono, gli uomini no.',
    },
    {
        id = 'caveau', nome = 'Aprire la stanza blindata',
        coord = vector3(5008.0, -5751.0, 15.0),
        durata = 60000,
        durataConAttrezzo = 20000,
        attrezzoVeloce = 'esplosivo',
        -- L'esplosivo è veloce ma fa rumore
        sospettoConAttrezzo = 45,
        sospetto = 22,
        nota = 'L\'esplosivo dimezza i tempi e triplica il rumore.',
    },
}

CAY.Sospetto = {
    massimo = 100,
    -- Cresce da solo mentre si sta sull'isola
    crescitaAlMinuto = 4,
    -- Sopra questa soglia parte la reazione degli uomini della villa
    sogliaAllarme = 70,
}

-- ---------------------------------------------------------------------------
--  5. BOTTINO
--
--  Il primario è sempre lo stesso e vale da solo il viaggio. I secondari
--  costano tempo: ogni borsone riempito alza il sospetto.
-- ---------------------------------------------------------------------------
CAY.Bottino = {
    primario = {
        item = 'contabilita',
        nome = 'Il libro mastro della cosca',
        -- Vale in contanti non tracciati se lo si vende, ma vale molto di
        -- più come merce di scambio: chi ce l'ha ha in mano il latitante.
        valore = 4200000,
        durata = 15000,
    },

    secondari = {
        {
            id = 'contanti', nome = 'Contanti nel caveau',
            item = 'contanti_sporchi', minimo = 90, massimo = 160,
            durata = 12000, sospetto = 6,
        },
        {
            id = 'oro', nome = 'Lingotti',
            item = 'lingotto', minimo = 2, massimo = 5,
            durata = 18000, sospetto = 8,
        },
        {
            id = 'cocaina', nome = 'Cocaina del deposito',
            item = 'cocaina', minimo = 8, massimo = 16,
            -- Roba non ancora tagliata: purezza altissima e pericolosa
            purezza = { minimo = 86, massimo = 96 },
            coord = vector3(5185.0, -5216.0, 2.5),
            richiedeFoto = 'deposito',
            durata = 20000, sospetto = 12,
        },
        {
            id = 'quadri', nome = 'Dipinti d\'autore',
            item = 'quadro', minimo = 1, massimo = 2,
            coord = vector3(4972.0, -5735.0, 20.5),
            richiedeFoto = 'quadreria',
            durata = 22000, sospetto = 10,
        },
    },

    tagliobanconota = 10000,
}

-- ---------------------------------------------------------------------------
--  6. RIENTRO
--
--  Il colpo non finisce sull'isola. Il bottino va portato a terra, e la
--  Guardia di Finanza è avvisata da quando la torre radio è saltata.
-- ---------------------------------------------------------------------------
CAY.Rientro = {
    -- Dove si consegna
    punto = vector3(-1605.0, -1160.0, 2.0),
    nome = 'Rimessaggio di Vespucci',
    raggio = 12.0,
    -- Da quando si esce dal caveau, quanti minuti prima che scatti il posto
    -- di blocco: se ci sono finanzieri in servizio, vengono avvisati.
    minutiPrimaDelBlocco = 3,
    -- Il fascicolo che si apre a colpo consumato
    reato = '416b',
    reatoRicettazione = '648b',
}

-- ---------------------------------------------------------------------------
--  Requisiti della squadra
-- ---------------------------------------------------------------------------
CAY.Squadra = {
    minimo = 3,
    massimo = 6,
    -- Distanza entro cui si è "insieme" al momento della partenza
    distanzaRitrovo = 40.0,
    -- Quota di chi resta fuori dal colpo ma è nella squadra: nessuna.
    -- Si divide fra chi è ancora sull'isola alla fine.
}

CAY.Cooldown = {
    -- Il colpo non si ripete a raffica: la villa cambia le serrature
    minutiFraColpi = 240,
    -- Un giocatore non partecipa a due colpi ravvicinati
    minutiPerGiocatore = 180,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function CAY.SullIsola(coord)
    return #(coord - CAY.Isola.centro) < CAY.Isola.raggio
end

function CAY.GetBersaglio(id)
    for _, b in ipairs(CAY.Ricognizione.bersagli) do
        if b.id == id then return b end
    end
    return nil
end

function CAY.GetFase(id)
    for n, f in ipairs(CAY.Fasi) do
        if f.id == id then return f, n end
    end
    return nil
end

function CAY.GetSecondario(id)
    for _, s in ipairs(CAY.Bottino.secondari) do
        if s.id == id then return s end
    end
    return nil
end
