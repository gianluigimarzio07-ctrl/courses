--[[
    AUREA · Furti su veicolo — configurazione

    Rubare un'auto qui non è "premi E e parti". È una catena di quattro
    passaggi, ognuno con il suo rumore e il suo rischio:

      1. APERTURA      grimaldello o spadino, difficoltà per fascia
      2. ALLARME       le auto di pregio suonano, e chi passa chiama
      3. AVVIAMENTO    ponticellare i cavi, tempo per fascia
      4. BLOCCO MOTORE le vetture recenti non partono senza centralina

    E soprattutto: quello che rubi appartiene a qualcuno. Se il veicolo è
    intestato a un giocatore, quel giocatore riceve la denuncia; se ha
    montato l'antifurto satellitare, riceve anche la posizione — e dopo
    qualche minuto la riceve pure la centrale operativa.

    L'autodemolizione non compra a caso: lavora su commessa. Ogni ora esce
    un ordine ("servono tre SUV") e chi lo rispetta viene pagato il doppio.
    È questo che decide quali auto vale la pena rubare stasera.
]]

FUR = {}

-- ---------------------------------------------------------------------------
--  Fasce di veicolo
--
--  La fascia si deduce dalla classe GTA del veicolo, che è già una buona
--  approssimazione del suo valore.
-- ---------------------------------------------------------------------------
FUR.Fasce = {
    utilitaria = {
        nome = 'Utilitaria',
        classi = { 0, 1, 2 },              -- compact, sedan, SUV
        difficoltaApertura = 20,           -- probabilità di rompere l'attrezzo
        durataApertura = 8000,
        durataAvviamento = 12000,
        allarme = false,
        bloccoMotore = false,
        valore = 320000,
    },
    berlina = {
        nome = 'Berlina',
        classi = { 3, 4, 9, 10, 11, 12 },  -- coupé, muscle, off-road, industrial…
        difficoltaApertura = 32,
        durataApertura = 11000,
        durataAvviamento = 16000,
        allarme = true,
        bloccoMotore = false,
        valore = 620000,
    },
    sportiva = {
        nome = 'Sportiva',
        classi = { 5, 6, 7 },              -- sport classics, sports, super
        difficoltaApertura = 48,
        durataApertura = 15000,
        durataAvviamento = 22000,
        allarme = true,
        bloccoMotore = true,
        valore = 1450000,
    },
    speciale = {
        nome = 'Mezzo speciale',
        classi = { 8, 13, 14, 15, 16, 17, 18, 19, 20, 21 },
        difficoltaApertura = 40,
        durataApertura = 13000,
        durataAvviamento = 19000,
        allarme = false,
        bloccoMotore = false,
        valore = 780000,
    },
}

--- Fascia di un veicolo, dalla sua classe.
function FUR.FasciaDiClasse(classe)
    for id, f in pairs(FUR.Fasce) do
        for _, c in ipairs(f.classi) do
            if c == classe then return id, f end
        end
    end
    return 'utilitaria', FUR.Fasce.utilitaria
end

-- ---------------------------------------------------------------------------
--  Attrezzi
-- ---------------------------------------------------------------------------
FUR.Attrezzi = {
    -- Il grimaldello è rozzo: lascia segni e a volte si spezza
    grimaldello = {
        nome = 'Grimaldello',
        bonusRiuscita = 0, probabilitaRottura = 22,
        lasciaSegni = true,
    },
    -- Lo spadino elettronico apre pulito, ma costa
    spadino = {
        nome = 'Spadino elettronico',
        bonusRiuscita = 35, probabilitaRottura = 6,
        lasciaSegni = false,
    },
}

--- Serve a superare il blocco motore delle vetture recenti
FUR.Centralina = 'centralina'

-- ---------------------------------------------------------------------------
--  Allarme e testimoni
-- ---------------------------------------------------------------------------
FUR.Allarme = {
    durata = 22000,
    -- Probabilità che qualcuno chiami il 112 mentre l'allarme suona
    probabilitaChiamata = 55,
    -- Un'apertura con segni di scasso si nota anche senza allarme
    probabilitaTestimone = 18,
}

-- ---------------------------------------------------------------------------
--  Antifurto satellitare
--
--  Lo installa il proprietario, sul proprio veicolo. Non impedisce il
--  furto: lo racconta.
-- ---------------------------------------------------------------------------
FUR.Antifurto = {
    item = 'antifurto',
    -- Ogni quanto trasmette la posizione al proprietario
    intervalloSegnalazione = 45000,
    -- Dopo quanti minuti dal furto la posizione arriva anche in centrale
    minutiPrimaDellaCentrale = 4,
    -- Si può disattivare, ma serve tempo e si resta fermi
    durataDisattivazione = 25000,
    -- Senza tronchesi non si trova il cablaggio
    attrezzoDisattivazione = 'tronchesi',
}

-- ---------------------------------------------------------------------------
--  Targhe
-- ---------------------------------------------------------------------------
FUR.Targhe = {
    item = 'targa_clonata',
    durata = 18000,
    -- Con la targa cambiata il veicolo sparisce dalle banche dati
    -- finché qualcuno non controlla il numero di telaio
    probabilitaScopertaAlControllo = 35,
}

-- ---------------------------------------------------------------------------
--  Autodemolizione clandestina
-- ---------------------------------------------------------------------------
FUR.Demolizione = {
    nome = 'Autodemolizione clandestina',
    coord = vector3(1522.0, -2135.0, 77.5),
    raggio = 30.0,
    durata = 35000,

    pezzi = {
        { item = 'acciaio', min = 3, max = 8 },
        { item = 'rame', min = 2, max = 5 },
        { item = 'componenti_elettronici', min = 1, max = 4 },
        { item = 'plastica', min = 2, max = 6 },
    },

    -- Veicoli demolibili in un'ora, per non svuotare la città
    limiteOrario = 4,
    calore = 10,
    provento = 'contanti_sporchi',
    tagliobanconota = 10000,

    -- Quanto scende il ricavato se il veicolo arriva sfasciato
    penalitaDanni = 0.45,
}

--- Le commesse: ogni ciclo l'officina chiede un tipo di mezzo e lo paga di più.
FUR.Commesse = {
    -- Ogni quanto cambia la richiesta
    durataMinuti = 60,
    -- Quanto paga in più un veicolo che rientra nella commessa
    moltiplicatore = 2.0,
    -- Quanti pezzi chiede ogni commessa
    quantitaMinima = 2, quantitaMassima = 4,

    tipi = {
        { fascia = 'utilitaria', testo = 'utilitarie' },
        { fascia = 'berlina',    testo = 'berline' },
        { fascia = 'sportiva',   testo = 'sportive' },
        { fascia = 'speciale',   testo = 'mezzi speciali' },
    },
}

-- ---------------------------------------------------------------------------
--  Reati
-- ---------------------------------------------------------------------------
FUR.Regole = {
    -- Veicolo in sosta, senza nessuno a bordo
    reatoFurto = '624',
    -- Con il conducente a bordo non è furto: è rapina
    reatoRapina = '628',
    -- Chi demolisce roba altrui
    reatoRicettazione = '648b',
    -- La targa clonata è un falso
    reatoTargaFalsa = '476',
    -- Quanto vicino deve essere il conducente perché sia rapina
    distanzaConducente = 6.0,
    calorefurto = 5,
}

function FUR.AllaDemolizione(coord)
    return #(coord - FUR.Demolizione.coord) < FUR.Demolizione.raggio
end
