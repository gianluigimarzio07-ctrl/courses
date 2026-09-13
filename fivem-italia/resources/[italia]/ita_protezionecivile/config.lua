--[[
    AUREA · Protezione Civile — configurazione

    COSA C'ERA E COSA MANCAVA

    Il meteo esisteva (ita_ambiente), gli incendi esistevano
    (ita_vigilfuoco), il 112 esisteva. Mancava la cosa che in Italia sta
    in mezzo: il sistema che si attiva quando l'emergenza è più grande di
    una squadra, e che non è fatto di professionisti ma di volontari.

    LA CATENA

        allerta      la dichiara il Sindaco, o sale da sola col maltempo
        COC          il Centro Operativo Comunale si apre sopra l'arancione
        volontari    chi è iscritto al gruppo comunale viene attivato
        compiti      sacchi di sabbia, idrovore, fasce tagliafuoco, ricerca
        rimborso     lo paga l'erario: il volontario non è pagato, è rimborsato

    È l'unico modulo del server in cui un cittadino qualunque, senza un
    lavoro, senza gradi e senza equipaggiamento, può fare qualcosa che
    conta. Serviva.
]]

PC = {}

-- ---------------------------------------------------------------------------
--  Sede del gruppo comunale
-- ---------------------------------------------------------------------------
PC.Sede = {
    nome = 'Protezione Civile — Gruppo comunale',
    coord = vector3(1699.2, 3584.4, 35.6),
    raggio = 2.5,
    blip = { sprite = 60, colore = 46, scala = 0.8 },
}

-- ---------------------------------------------------------------------------
--  Livelli di allerta
--
--  Sono quelli veri del sistema di allertamento nazionale.
-- ---------------------------------------------------------------------------
PC.Livelli = {
    { id = 'verde',     nome = 'Nessuna allerta',   colore = 2,  apreCoc = false },
    { id = 'gialla',    nome = 'Allerta gialla',    colore = 5,  apreCoc = false },
    { id = 'arancione', nome = 'Allerta arancione', colore = 47, apreCoc = true  },
    { id = 'rossa',     nome = 'Allerta rossa',     colore = 1,  apreCoc = true  },
}

--- Il livello che il meteo da solo giustifica. Il Sindaco può sempre
--- alzarlo: la valutazione politica sta sopra quella automatica.
PC.AllertaDaMeteo = {
    THUNDER   = 'arancione',
    RAIN      = 'gialla',
    CLEARING  = 'verde',
    FOGGY     = 'gialla',
    SNOW      = 'arancione',
    BLIZZARD  = 'rossa',
    SNOWLIGHT = 'gialla',
}

-- ---------------------------------------------------------------------------
--  Chi comanda e chi partecipa
-- ---------------------------------------------------------------------------
PC.Comando = {
    -- Chi dichiara l'allerta e apre il COC
    lavoro = 'comune',
    -- Gli enti che vedono sempre lo stato, anche senza essere volontari
    entiInformati = { 'vigili_fuoco', '118', 'carabinieri', 'polizia' },
}

PC.Volontariato = {
    -- L'iscrizione al gruppo comunale è aperta a chiunque
    apertoATutti = true,
    -- Ma serve il gilet: in emergenza chi non si vede è un pericolo
    dpi = 'gilet_alta_visibilita',
    -- Il materiale lo fornisce il COC, non se lo compra il volontario:
    -- è la differenza fra un sistema di protezione civile e un hobby.
    dotazione = { sabbia = 10 },
    -- E si ritira solo a scenario aperto, una volta ogni tot
    attesaDotazioneMinuti = 5,
    -- Quante emergenze concluse per passare a caposquadra
    interventiPerCaposquadra = 5,
}

-- ---------------------------------------------------------------------------
--  I compiti
--
--  Ogni emergenza è un elenco di punti sul terreno da lavorare. Il compito
--  dice cosa serve, quanto dura e che animazione fare.
-- ---------------------------------------------------------------------------
PC.Compiti = {
    sacchi = {
        etichetta = 'Posiziona i sacchi di sabbia',
        icona = '🧱',
        secondi = 12,
        materiali = { sabbia = 2 },
        animazione = { dizionario = 'anim@heists@narcotics@trash', nome = 'idle_c' },
        rimborso = 3200,
    },
    pompa = {
        etichetta = 'Aziona l\'idrovora',
        icona = '💧',
        secondi = 15,
        materiali = {},
        animazione = { dizionario = 'amb@world_human_hammering@male@base', nome = 'base' },
        rimborso = 3800,
    },
    taglio = {
        etichetta = 'Apri la fascia tagliafuoco',
        icona = '🪓',
        secondi = 14,
        materiali = {},
        animazione = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
        rimborso = 4200,
    },
    ricerca = {
        etichetta = 'Batti il settore',
        icona = '🔦',
        secondi = 10,
        materiali = {},
        animazione = { dizionario = 'amb@world_human_security_shine_torch@male@base', nome = 'base' },
        rimborso = 2600,
    },
}

-- ---------------------------------------------------------------------------
--  Le emergenze
--
--  `zone` sono i posti dove può cadere l'emergenza. I punti dei compiti si
--  generano attorno al centro scelto, così due alluvioni non sono mai
--  identiche.
-- ---------------------------------------------------------------------------
PC.Emergenze = {
    alluvione = {
        nome = 'Alluvione',
        icona = '🌊',
        descrizione = 'Il torrente è esondato. Arginare, poi svuotare.',
        allertaMinima = 'arancione',
        compiti = { sacchi = 6, pompa = 3 },
        raggio = 60.0,
        minutiMassimi = 45,
        bonusChiusura = 45000,
        -- Se non si chiude nei termini, i danni li paga il Comune
        dannoSeFallita = 800000,
        zone = {
            { nome = 'Sottopasso di Vespucci', coord = vector3(-1160.3, -1520.8, 4.4) },
            { nome = 'Torrente Alamo',         coord = vector3(1550.2, 3800.4, 33.8) },
            { nome = 'Porto commerciale',      coord = vector3(1210.5, -2980.6, 5.9) },
        },
    },

    incendio_boschivo = {
        nome = 'Incendio boschivo',
        icona = '🌲',
        descrizione = 'Fronte di fiamma su vegetazione. Ai volontari la fascia tagliafuoco, ai VVF le fiamme.',
        allertaMinima = 'gialla',
        compiti = { taglio = 5, pompa = 2 },
        raggio = 80.0,
        minutiMassimi = 40,
        bonusChiusura = 52000,
        dannoSeFallita = 600000,
        -- Accende davvero un incendio in ita_vigilfuoco: i due moduli
        -- lavorano sullo stesso fatto, ognuno per la sua parte
        accendeIncendio = 'boschivo',
        zone = {
            { nome = 'Monte Chiliad',    coord = vector3(-100.6, 5380.2, 122.4) },
            { nome = 'Boschi di Paleto', coord = vector3(-680.4, 5820.8, 17.3) },
            { nome = 'Colline di Vinewood', coord = vector3(760.2, 1280.6, 360.5) },
        },
    },

    ricerca_dispersi = {
        nome = 'Ricerca di persona dispersa',
        icona = '🔦',
        descrizione = 'Un escursionista non è rientrato. Battere i settori finché non si trova.',
        allertaMinima = 'verde',
        compiti = { ricerca = 8 },
        raggio = 120.0,
        minutiMassimi = 35,
        bonusChiusura = 60000,
        dannoSeFallita = 0,
        -- Chi trova il disperso prende un riconoscimento a parte: è la
        -- cosa che conta, e va premiata più del numero di settori battuti
        premioRitrovamento = 35000,
        zone = {
            { nome = 'Sentieri del Chiliad',  coord = vector3(450.8, 5580.4, 780.2) },
            { nome = 'Cave di Paleto',        coord = vector3(-560.2, 5290.6, 70.4) },
            { nome = 'Grand Senora',          coord = vector3(1420.6, 3100.2, 40.1) },
        },
    },
}

-- ---------------------------------------------------------------------------
--  Rimborsi
--
--  Il volontario non prende uno stipendio: prende il rimborso delle spese.
--  È una differenza di sostanza, non di parole, e il modulo la rispetta —
--  gli importi sono bassi apposta.
-- ---------------------------------------------------------------------------
PC.Rimborsi = {
    -- Ogni quanto l'emergenza può ripresentarsi da sola
    intervalloMinimoMinuti = 50,
    -- Probabilità che una si apra da sola a ogni controllo, con COC aperto
    probabilitaAutomatica = 0.18,
    controlloMinuti = 10,
}

-- ---------------------------------------------------------------------------
--  Aiutanti
-- ---------------------------------------------------------------------------

function PC.GetLivello(id)
    for i, l in ipairs(PC.Livelli) do
        if l.id == id then return l, i end
    end
    return PC.Livelli[1], 1
end

--- Confronta due livelli: true se `a` è almeno `b`.
function PC.AlmenoAllerta(a, b)
    local _, ia = PC.GetLivello(a)
    local _, ib = PC.GetLivello(b)
    return ia >= ib
end

function PC.GetEmergenza(id)
    return PC.Emergenze[id]
end

--- Le emergenze che il livello di allerta corrente permette.
function PC.EmergenzePossibili(allerta)
    local fuori = {}
    for id, e in pairs(PC.Emergenze) do
        if PC.AlmenoAllerta(allerta, e.allertaMinima) then
            fuori[#fuori + 1] = id
        end
    end
    return fuori
end
