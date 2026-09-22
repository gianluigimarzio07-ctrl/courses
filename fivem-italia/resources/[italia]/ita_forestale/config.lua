--[[
    AUREA · Carabinieri Forestali — configurazione

    L'ex Corpo Forestale dello Stato, confluito nell'Arma nel 2017. Fa
    polizia giudiziaria come i colleghi in nero, ma su una materia che
    nessun altro presidia: il bosco, la fauna, i rifiuti nei fossi, i
    vincoli sul terreno.

    Il pezzo che tiene insieme tutta la risorsa è l'ARTICOLO 10 DELLA
    LEGGE 353 DEL 2000, ed è una delle norme meglio scritte che abbiamo.

    Il problema che risolve è questo: bruciare un bosco conviene, perché
    un terreno senza alberi si può edificare e un pascolo bruciato si può
    recintare. Finché brucia conviene, ci sarà sempre qualcuno che accende.

    La risposta della legge non è una multa più alta. È togliere il
    movente: sul soprassuolo percorso dal fuoco si applica per DIECI ANNI
    il divieto di edificare, di pascolare e di rimboschire a fini
    produttivi. Il terreno resta tuo e non vale più niente.

    Qui funziona uguale. I Vigili del Fuoco spengono, i Forestali
    rilevano, e il vincolo lo mette un maresciallo dopo aver misurato la
    superficie percorsa. Da quel momento ita_edilizia non apre cantieri
    lì sopra, e chi ha bruciato per costruire ha bruciato per niente.
]]

FOR = {}

FOR.Lavoro = 'forestale'
FOR.Ente   = 'forestale'

-- ---------------------------------------------------------------------------
--  Le sedi
-- ---------------------------------------------------------------------------
FOR.Sedi = {
    {
        id = 'paleto',
        nome = 'Comando Stazione Carabinieri Forestali — Paleto',
        coord = vector3(-433.5, 6172.3, 31.5),
        raggio = 2.2,
        principale = true,
        blip = { sprite = 442, colore = 52, scala = 0.85 },
    },
    {
        id = 'grapeseed',
        nome = 'Nucleo Carabinieri Forestali — Grapeseed',
        coord = vector3(1697.2, 4923.5, 42.1),
        raggio = 2.2,
        blip = { sprite = 442, colore = 52, scala = 0.75 },
    },
}

function FOR.SedePrincipale()
    for _, s in ipairs(FOR.Sedi) do
        if s.principale then return s end
    end
    return FOR.Sedi[1]
end

-- ---------------------------------------------------------------------------
--  Il vincolo decennale
-- ---------------------------------------------------------------------------
FOR.Vincolo = {
    -- Quanto terreno resta vincolato attorno al punto d'innesco, per ettaro
    -- accertato. Un ettaro è 10 000 m²: il raggio del cerchio equivalente
    -- è circa 56 metri, e ci si tiene larghi perché il fuoco non è tondo.
    metriPerEttaro = 62,
    raggioMinimo = 80,
    raggioMassimo = 420,
    -- Dieci anni veri sarebbero un'eternità in gioco. Qui il vincolo dura
    -- quanto basta a rendere inutile il movente: tre ore di server.
    minutiDurata = 180,
    -- La legge parla di anni, e il certificato deve dirlo
    anniNominali = 10,
    articolo = 'art. 10 L. 353/2000',
}

-- ---------------------------------------------------------------------------
--  Rilievo della superficie percorsa
--
--  Non è una formalità: la superficie la si misura camminandola. Il
--  numero di ettari esce da quanti punti perimetrali il militare ha
--  rilevato e da quanto è durato l'incendio.
-- ---------------------------------------------------------------------------
FOR.Rilievo = {
    -- Punti perimetrali da rilevare
    puntiRichiesti = 4,
    -- Distanza minima fra un punto e il precedente: non si rileva da fermi
    metriFraPunti = 35,
    -- Entro quanto dal centro dell'incendio si può rilevare
    raggioMassimo = 500,
    secondiPerPunto = 6,
    -- Ettari per minuto di durata dell'incendio, più il contributo dei punti
    ettariPerMinuto = 0.35,
    ettariPerPunto = 0.2,
    -- Scaduto questo tempo dall'incendio, il rilievo non si fa più:
    -- la superficie non è più riconoscibile
    minutiPerRilevare = 40,
    compenso = 48000,
}

-- ---------------------------------------------------------------------------
--  L'origine dell'incendio
--
--  Dolosa, colposa, naturale o ignota. La differenza non è accademica:
--  il dolo apre un fascicolo, la colpa è una sanzione, il fulmine non è
--  colpa di nessuno.
-- ---------------------------------------------------------------------------
FOR.Origini = {
    ignota   = { etichetta = 'Origine da accertare', icona = '❓', sanzione = 0,      reato = nil },
    naturale = { etichetta = 'Origine naturale',     icona = '⛈',  sanzione = 0,      reato = nil },
    colposa  = { etichetta = 'Incendio colposo',     icona = '⚠',  sanzione = 206000, reato = '449',
                 articolo = 'art. 449 c.p.' },
    dolosa   = { etichetta = 'Incendio doloso',      icona = '🔥', sanzione = 0,      reato = '423b',
                 articolo = 'art. 423-bis c.p.' },
}

function FOR.GetOrigine(id)
    return FOR.Origini[id]
end

-- ---------------------------------------------------------------------------
--  Gli accertamenti su strada e nel bosco
-- ---------------------------------------------------------------------------
FOR.Accertamenti = {
    bracconaggio = {
        etichetta = 'Esercizio venatorio senza titolo',
        icona = '🦌',
        descrizione = 'Caccia senza licenza o fuori dai casi consentiti.',
        articolo = 'art. 30 L. 157/92',
        sanzione = 103000,
        -- La doppietta si sequestra: è il corpo del reato
        sequestraArmi = true,
    },
    taglio = {
        etichetta = 'Taglio boschivo abusivo',
        icona = '🪓',
        descrizione = 'Abbattimento senza autorizzazione forestale.',
        articolo = 'art. 734 c.p.',
        sanzione = 154000,
    },
    discarica = {
        etichetta = 'Abbandono di rifiuti',
        icona = '🗑',
        descrizione = 'Rifiuti abbandonati fuori dal circuito autorizzato.',
        articolo = 'art. 255 D.Lgs. 152/2006',
        sanzione = 61600,
    },
    pascolo = {
        etichetta = 'Pascolo su superficie vincolata',
        icona = '🐑',
        descrizione = 'Pascolo su soprassuolo percorso dal fuoco.',
        articolo = 'art. 10 c.1 L. 353/2000',
        sanzione = 121000,
    },
    vincolo = {
        etichetta = 'Violazione del vincolo decennale',
        icona = '⛔',
        descrizione = 'Attività edilizia su terreno percorso dal fuoco.',
        articolo = 'art. 10 c.1 L. 353/2000',
        sanzione = 412000,
    },
}

function FOR.GetAccertamento(id)
    return FOR.Accertamenti[id]
end

-- ---------------------------------------------------------------------------
--  Il sequestro al bracconiere
--
--  In AUREA non esistono un «fucile da caccia» e una «carabina» come
--  oggetti distinti: c'è un solo item `arma`, e ogni pezzo ha la sua
--  matricola nel registro di aurea_armi. Quello che si sequestra qui è
--  dunque l'arma che la persona ha addosso, qualunque sia, più le
--  cartucce — che invece un item dedicato ce l'hanno.
-- ---------------------------------------------------------------------------
FOR.Sequestro = {
    arma = 'arma',
    munizioni = 'cartuccia_caccia',
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function FOR.DistanzaPiana(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

--- Il raggio del vincolo, dati gli ettari accertati.
function FOR.RaggioVincolo(ettari)
    local r = math.floor(math.sqrt(math.max(0, ettari)) * FOR.Vincolo.metriPerEttaro)
    if r < FOR.Vincolo.raggioMinimo then return FOR.Vincolo.raggioMinimo end
    if r > FOR.Vincolo.raggioMassimo then return FOR.Vincolo.raggioMassimo end
    return r
end

--- Gli ettari percorsi, dati i punti rilevati e la durata dell'incendio.
function FOR.Ettari(punti, minutiIncendio)
    local e = (punti or 0) * FOR.Rilievo.ettariPerPunto
            + (minutiIncendio or 0) * FOR.Rilievo.ettariPerMinuto
    return math.floor(e * 100 + 0.5) / 100
end
