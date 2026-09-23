--[[
    AUREA · Mercato rionale — configurazione

    In AUREA si può già vendere in tre modi: al negozio a prezzo fisso
    (aurea_negozi), conferendo all'ingrosso a un centro di raccolta
    (ita_economia), o al ricettatore in nero. Tutti e tre sono la stessa
    cosa dal punto di vista di chi gioca: premi un tasto, la merce esce,
    i soldi entrano.

    Il mercato è un'altra cosa, e la differenza è che CI DEVI STARE.

    Apri il banco al tuo posteggio e i clienti arrivano da soli, uno alla
    volta, a un ritmo che dipende dall'ora e da quanta roba hai in mostra.
    Ognuno vuole qualcosa di preciso; se ce l'hai la compra, e quanto
    paga dipende dalla qualità del lotto e dalla certificazione — un
    pecorino DOP a 88 di qualità lo paghi due volte tanto uno anonimo.
    Se non ce l'hai, quel cliente se ne va e non torna.

    E poi c'è lo SCONTRINO, che è il pezzo per cui questa risorsa esiste.

    Ogni vendita si può battere o non battere. Battuta: l'IVA va
    all'Erario e a te resta il netto. Non battuta: tieni tutto. La
    seconda conviene sempre, nel momento in cui la fai — ed è esattamente
    il motivo per cui in Italia c'è un finanziere che entra al mercato e
    chiede lo scontrino all'ultimo cliente uscito. Se il conto delle
    vendite battute non torna con quello che hai in cassa, è sanzione.

    Il calcolo è deliberatamente favorevole all'evasione nel breve: chi
    non batte guadagna il 22% in più ogni volta. Solo che il controllo
    guarda la SESSIONE intera, e la sanzione è tarata per essere più
    pesante di quello che si è risparmiato. Chi evade poco passa liscio,
    chi evade tutto ci rimette. Come nella realtà, è una scommessa sul
    fatto che non passi nessuno.
]]

MER = {}

-- ---------------------------------------------------------------------------
--  I mercati
--
--  Ogni mercato ha un numero chiuso di posteggi, che il Comune assegna.
--  I giorni e le ore contano: un mercato di quartiere la sera è morto.
-- ---------------------------------------------------------------------------
MER.Mercati = {
    {
        id = 'centrale',
        nome = 'Mercato coperto del centro',
        ufficio = vector3(-45.9, -1748.2, 29.4),
        raggio = 2.2,
        -- I posteggi: uno per bancarella
        posteggi = {
            { id = 'c1', coord = vector3(-42.7, -1751.6, 29.4), canone = 42000 },
            { id = 'c2', coord = vector3(-39.1, -1755.0, 29.4), canone = 42000 },
            { id = 'c3', coord = vector3(-35.5, -1758.4, 29.4), canone = 38000 },
            { id = 'c4', coord = vector3(-31.9, -1761.8, 29.4), canone = 34000 },
        },
        -- Quanti clienti l'ora passano di qui nelle ore buone
        afflussoBase = 22,
        blip = { sprite = 52, colore = 46, scala = 0.9 },
    },
    {
        id = 'paleto',
        nome = 'Mercato settimanale di Paleto',
        ufficio = vector3(-274.8, 6226.5, 31.5),
        raggio = 2.2,
        posteggi = {
            { id = 'p1', coord = vector3(-278.3, 6229.9, 31.5), canone = 22000 },
            { id = 'p2', coord = vector3(-281.9, 6233.3, 31.5), canone = 22000 },
            { id = 'p3', coord = vector3(-285.5, 6236.7, 31.5), canone = 18000 },
        },
        afflussoBase = 12,
        blip = { sprite = 52, colore = 46, scala = 0.75 },
    },
}

function MER.GetMercato(id)
    for _, m in ipairs(MER.Mercati) do
        if m.id == id then return m end
    end
end

function MER.GetPosteggio(idPosteggio)
    for _, m in ipairs(MER.Mercati) do
        for _, p in ipairs(m.posteggi) do
            if p.id == idPosteggio then return p, m end
        end
    end
end

-- ---------------------------------------------------------------------------
--  Le fasce orarie
--
--  Il mercato è un posto del mattino. Il pomeriggio si tira avanti, la
--  sera non passa nessuno — e chi tiene il banco aperto di notte non sta
--  vendendo, sta aspettando.
-- ---------------------------------------------------------------------------
MER.Fasce = {
    { da = 6,  a = 9,  nome = 'apertura',    moltiplicatore = 0.7 },
    { da = 9,  a = 13, nome = 'pieno',       moltiplicatore = 1.0 },
    { da = 13, a = 16, nome = 'pomeriggio',  moltiplicatore = 0.5 },
    { da = 16, a = 20, nome = 'chiusura',    moltiplicatore = 0.3 },
    { da = 20, a = 6,  nome = 'notte',       moltiplicatore = 0.05 },
}

--- Il moltiplicatore d'afflusso per un'ora del giorno.
function MER.Afflusso(ora)
    for _, f in ipairs(MER.Fasce) do
        if f.da < f.a then
            if ora >= f.da and ora < f.a then return f.moltiplicatore, f.nome end
        else
            -- la fascia che scavalca la mezzanotte
            if ora >= f.da or ora < f.a then return f.moltiplicatore, f.nome end
        end
    end
    return 0.3, 'fuori fascia'
end

-- ---------------------------------------------------------------------------
--  Il posteggio
-- ---------------------------------------------------------------------------
MER.Posteggio = {
    -- La concessione dura, poi va rinnovata al Comune
    minutiConcessione = 480,
    -- Il canone si iscrive a ruolo come tributo: non si paga allo
    -- sportello, arriva la cartella. È così anche nella realtà — la TOSAP.
    -- Il `periodo` dei tributi è un VARCHAR(16), quindi ci sta l'id del
    -- posteggio e non una descrizione.
    tributoTipo = 'tosap',
    -- Entro quanti metri dal posteggio si può tenere il banco
    raggio = 4.0,
    -- Chi vende senza posteggio: sanzione e sequestro della merce
    sanzioneAbusivo = 516000,
    articoloAbusivo = 'art. 29 D.Lgs. 114/1998',
}

-- ---------------------------------------------------------------------------
--  La licenza di commercio su area pubblica
-- ---------------------------------------------------------------------------
MER.Licenza = {
    tipo = 'area_pubblica',
    etichetta = 'Autorizzazione al commercio su area pubblica',
    costo = 86000,
    validitaGiorni = 365,
    sanzione = 258000,
    articolo = 'art. 29 c.1 D.Lgs. 114/1998',
}

-- ---------------------------------------------------------------------------
--  Che cosa si vende al mercato
--
--  Non tutto: il mercato rionale è alimentare e tessile. Gli item sono
--  quelli che le filiere Made in Italy, l'azienda agricola e la pesca
--  producono già — non ce n'è nessuno inventato per l'occasione.
--
--  `alimentare` dice se il banco si sporca vendendo e se sotto una certa
--  soglia di igiene non può più trattare quella merce: il parmigiano sì,
--  il tessuto pregiato no.
--
--  `prezzoRiserva` è il prezzo di un pezzo quando ita_economia non ha un
--  listino per quell'item. Serve perché non tutti gli item del banco
--  stanno nel mercato all'ingrosso, e un cliente che offre zero non è un
--  cliente.
-- ---------------------------------------------------------------------------
MER.Banchi = {
    ortofrutta = {
        prezzoRiserva = 900,
        etichetta = 'Ortofrutta e prodotti del bosco',
        icona = '🍅',
        alimentare = true,
        items = { 'pomodoro_san_marzano', 'olive', 'uva_sangiovese', 'uva_nebbiolo',
                  'grano', 'porcini', 'castagne', 'tartufo_nero', 'erbe_officinali' },
    },
    pescheria = {
        prezzoRiserva = 1600,
        etichetta = 'Pescheria',
        icona = '🐟',
        alimentare = true,
        items = { 'branzino', 'orata', 'dentice', 'gambero_rosso', 'pesce_azzurro',
                  'sgombro', 'polpo', 'trota', 'dattero' },
    },
    gastronomia = {
        prezzoRiserva = 2400,
        etichetta = 'Gastronomia e salumeria',
        icona = '🧀',
        alimentare = true,
        items = { 'parmigiano_dop', 'mozzarella_bufala', 'formaggio_fresco',
                  'olio_extravergine', 'olio_dop', 'prosciutto', 'pasta_secca',
                  'vino_rosso', 'vino_docg', 'caffe_tostato' },
    },
    tessile = {
        prezzoRiserva = 6800,
        etichetta = 'Tessile e sartoria',
        icona = '👔',
        alimentare = false,
        items = { 'capo_sartoriale', 'tessuto_pregiato' },
    },
}

function MER.GetBanco(id)
    return MER.Banchi[id]
end

--- Il banco a cui appartiene un item, se ce n'è uno.
function MER.BancoDi(item)
    for id, b in pairs(MER.Banchi) do
        for _, i in ipairs(b.items) do
            if i == item then return id, b end
        end
    end
end

-- ---------------------------------------------------------------------------
--  I clienti
-- ---------------------------------------------------------------------------
MER.Clienti = {
    -- Secondi fra un cliente e il successivo, prima dei moltiplicatori
    secondiFraClienti = 22,
    -- Quanto compra un cliente
    quantitaMin = 1, quantitaMax = 3,
    -- Quanto tempo resta prima di andarsene
    secondiPazienza = 30,
    -- Il ricarico del banco sul prezzo di mercato: è il margine del
    -- commerciante, e senza quello vendere al mercato non conviene
    -- rispetto a conferire all'ingrosso.
    ricarico = 1.35,
    -- La merce in mostra attira: più roba hai, più gente si ferma. Il
    -- bonus è a rendimento decrescente e si ferma qui.
    bonusEspostoMassimo = 0.5,
    pezziPerBonusPieno = 40,
}

-- ---------------------------------------------------------------------------
--  Lo scontrino
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
--  L'igiene del banco
--
--  Un banco di alimentari si sporca vendendo, e sotto soglia non ci si
--  può più stare. Non è l'igiene dei locali dell'ASL — quella riguarda
--  gli esercizi con quattro mura — è il banco che va passato col
--  detergente fra un mercato e l'altro.
-- ---------------------------------------------------------------------------
MER.Igiene = {
    iniziale = 100,
    -- Punti persi per ogni vendita di alimentari
    caloPerVendita = 2,
    -- Sotto questa soglia gli alimentari non si vendono più
    soglia = 40,
    -- La sanificazione: un detergente e un po' di tempo
    item = 'detergente',
    secondi = 8,
    recupero = 55,
}

MER.Scontrino = {
    -- L'IVA che si versa quando lo batti
    aliquota = 0.22,
    -- Il controllo della Guardia di Finanza
    controllo = {
        lavori = { 'guardia_finanza', 'carabinieri' },
        -- Sopra questa quota di vendite non battute scatta la sanzione
        sogliaEvasione = 0.30,
        -- La sanzione è proporzionale all'imponibile sottratto, con un
        -- minimo. Il 90% è l'aliquota vera dell'art. 6 D.Lgs. 471/1997.
        quotaSanzione = 0.90,
        sanzioneMinima = 51600,
        articolo = 'art. 6 c.3 D.Lgs. 471/1997',
        -- La sospensione dell'attività per chi evade troppo, art. 12
        sogliaSospensione = 0.70,
        minutiSospensione = 60,
        minutiFraControlli = 6,
    },
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------

--- Il prezzo al banco di un pezzo: prezzo di mercato, più il ricarico del
--- commerciante, per il moltiplicatore della certificazione.
---
--- Il moltiplicatore lo passa chi chiama, perché è ita_madeinitaly a
--- conoscerlo e questa risorsa non deve dipendere dal suo config.
function MER.PrezzoAlBanco(prezzoMercato, moltiplicatoreCertificazione)
    local p = (prezzoMercato or 0) * MER.Clienti.ricarico
             * (moltiplicatoreCertificazione or 1.0)
    return math.floor(p + 0.5)
end

--- Il bonus d'afflusso dato dalla merce esposta.
function MER.BonusEsposto(pezzi)
    local q = math.min(1.0, (pezzi or 0) / MER.Clienti.pezziPerBonusPieno)
    return 1.0 + MER.Clienti.bonusEspostoMassimo * q
end
