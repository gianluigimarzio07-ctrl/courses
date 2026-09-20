--[[
    AUREA · Donazione di sangue (configurazione)

    UN OGGETTO CHE C'ERA E NON SERVIVA A NIENTE

    In `item.lua` esisteva da sempre una voce: `sacca_sangue`, "Sacca di
    sangue", usabile. Nessuna risorsa la produceva, nessuna la consumava,
    nessuna la vendeva. Era un oggetto fantasma.

    Questa risorsa gli dà una filiera, e la filiera è quella vera:

        qualcuno dona → il centro trasfusionale tiene le scorte per
        gruppo → l'ospedale e il 118 le comprano → chi ne ha bisogno
        la riceve.

    IL GRUPPO SANGUIGNO

    Non è un dettaglio di colore. Una trasfusione con il gruppo sbagliato
    non è inefficace: è una reazione emolitica, e fa danno. Qui succede
    esattamente questo, con la tabella di compatibilità vera — quella per
    cui lo 0 negativo va bene a tutti e l'AB positivo riceve da tutti.

    Il gruppo di una persona non si sceglie: si ha. Qui si ricava dal
    codice cittadino, in modo che sia sempre lo stesso per lo stesso
    personaggio, e che la distribuzione somigli a quella italiana.

    L'INTERVALLO

    Fra una donazione e l'altra devono passare novanta giorni, e per le
    donne in età fertile il limite annuale è più basso. Qui l'intervallo
    è in minuti, ma esiste: non si dona due volte di fila.
]]

SAN = {}

SAN.Lavoro = '118'

-- ---------------------------------------------------------------------------
--  Il centro trasfusionale
-- ---------------------------------------------------------------------------
SAN.Centro = {
    nome = 'Centro trasfusionale — AVIS',
    coord = vector3(307.6, -595.4, 43.3),
    raggio = 2.4,
    blip = { sprite = 153, colore = 1, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  I gruppi
--
--  Le frequenze sono quelle italiane, arrotondate. La somma fa cento.
-- ---------------------------------------------------------------------------
SAN.Gruppi = {
    { id = '0+',  frequenza = 40 },
    { id = 'A+',  frequenza = 36 },
    { id = 'B+',  frequenza = 8 },
    { id = 'AB+', frequenza = 3 },
    { id = '0-',  frequenza = 7 },
    { id = 'A-',  frequenza = 4 },
    { id = 'B-',  frequenza = 1 },
    { id = 'AB-', frequenza = 1 },
}

--- Compatibilità: chi PUÒ RICEVERE da chi.
--- Si legge: `SAN.Compatibile['A+']` è l'elenco dei gruppi che un A+ può
--- ricevere senza reazione.
SAN.Compatibile = {
    ['0-']  = { '0-' },
    ['0+']  = { '0-', '0+' },
    ['A-']  = { '0-', 'A-' },
    ['A+']  = { '0-', '0+', 'A-', 'A+' },
    ['B-']  = { '0-', 'B-' },
    ['B+']  = { '0-', '0+', 'B-', 'B+' },
    ['AB-'] = { '0-', 'A-', 'B-', 'AB-' },
    ['AB+'] = { '0-', '0+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+' },
}

function SAN.Compatibili(ricevente, donatore)
    for _, g in ipairs(SAN.Compatibile[ricevente] or {}) do
        if g == donatore then return true end
    end
    return false
end

--- Il gruppo di una persona, stabile e derivato dal codice cittadino.
--- Non si estrae ogni volta: lo stesso personaggio ha sempre lo stesso
--- sangue, che è come funziona il sangue.
function SAN.GruppoDi(citizenid)
    local somma = 0
    for i = 1, #citizenid do
        somma = somma + citizenid:byte(i) * i
    end

    local punto = somma % 100
    local cumulata = 0
    for _, g in ipairs(SAN.Gruppi) do
        cumulata = cumulata + g.frequenza
        if punto < cumulata then return g.id end
    end
    return '0+'
end

-- ---------------------------------------------------------------------------
--  Donazione
-- ---------------------------------------------------------------------------
SAN.Donazione = {
    durataSecondi = 30,

    -- Minuti fra una donazione e l'altra
    minutiIntervallo = 60,

    -- Donare stanca: si perde un po' di salute e resta per un po'
    saluteSottratta = 15,

    -- In Italia il sangue non si paga. Quello che si dà è un ristoro:
    -- la colazione, e il permesso retribuito. Qui è un piccolo rimborso
    -- e un pasto.
    ristoro = 3500,
    itemRistoro = 'panino',

    -- Sotto questa salute non si dona
    saluteMinima = 70,
}

-- ---------------------------------------------------------------------------
--  Scorte e cessione
-- ---------------------------------------------------------------------------
SAN.Scorte = {
    -- Sacche prodotte da una donazione
    sacchePerDonazione = 1,

    -- Sotto questa soglia il gruppo è in carenza e il centro lo dice
    sogliaCarenza = 4,

    -- Quanto paga il 118 per ritirare una sacca. Il sangue è gratis,
    -- la lavorazione no.
    costoSacca = 7800,

    -- Tetto per gruppo: oltre, le sacche scadono e si buttano
    massimoPerGruppo = 40,

    -- Ogni quanti minuti scade qualcosa
    minutiScadenza = 45,
    scaduteAlGiro = 1,
}

-- ---------------------------------------------------------------------------
--  Trasfusione
-- ---------------------------------------------------------------------------
SAN.Trasfusione = {
    item = 'sacca_sangue',

    -- Salute restituita da una sacca compatibile
    saluteCompatibile = 45,

    -- E il danno di una reazione emolitica. Non è "non funziona": è
    -- peggio di prima.
    dannoReazione = 35,

    -- Solo chi ha una qualifica sanitaria sa fare una trasfusione. Un
    -- passante che ci prova fa danno anche se il gruppo è giusto.
    lavoriAbilitati = { '118', 'medico' },
    dannoSenzaQualifica = 20,
}
