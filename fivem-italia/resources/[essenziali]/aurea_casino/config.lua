--[[
    AUREA · Casinò — configurazione

    Il banco vince. Non per cattiveria: perché è così che funziona, e
    perché un casinò che paga più di quanto incassa è una stampante di
    denaro che rompe l'economia del server in una serata.

    Ogni tavolo ha il suo margine dichiarato qui sopra, e c'è un tetto
    giornaliero alle vincite: oltre quello il banco chiude il tavolo, come
    farebbe un casinò vero con chi conta le carte.
]]

CAS = {}

CAS.Sede = {
    nome = 'Casinò',
    coord = vector3(935.0, 46.0, 81.0),
    cassa = vector3(940.0, 40.0, 81.0),
    blip = { sprite = 679, colore = 5, scala = 0.85 },
}

CAS.Fiches = {
    item = 'fiches',
    -- Una fiche vale questo, in centesimi
    valore = 10000,
    -- Il cambio ha una commissione: entrare e uscire costa
    commissione = 0.03,
}

-- ---------------------------------------------------------------------------
--  Tavoli
--
--  vantaggioBanco: la quota che in media resta al casinò. Non è un
--  "quanto perdi": è quanto il banco tiene su un numero grande di mani.
-- ---------------------------------------------------------------------------
CAS.Tavoli = {
    blackjack = {
        nome = 'Blackjack', icona = '🃏',
        coord = { vector3(929.0, 44.0, 81.0), vector3(925.0, 48.0, 81.0) },
        puntataMinima = 1, puntataMassima = 25,     -- in fiches
        vantaggioBanco = 0.015,
        pagamentoBlackjack = 1.5,
    },
    roulette = {
        nome = 'Roulette', icona = '🎡',
        coord = { vector3(946.0, 51.0, 81.0) },
        puntataMinima = 1, puntataMassima = 40,
        vantaggioBanco = 0.027,          -- lo zero singolo, come in Europa
        scommesse = {
            { id = 'pieno',  nome = 'Numero pieno',     quota = 35, probabilita = 1/37 },
            { id = 'rosso',  nome = 'Rosso',            quota = 1,  probabilita = 18/37 },
            { id = 'nero',   nome = 'Nero',             quota = 1,  probabilita = 18/37 },
            { id = 'pari',   nome = 'Pari',             quota = 1,  probabilita = 18/37 },
            { id = 'dispari',nome = 'Dispari',          quota = 1,  probabilita = 18/37 },
            { id = 'dozzina',nome = 'Dozzina',          quota = 2,  probabilita = 12/37 },
        },
    },
    slot = {
        nome = 'Slot machine', icona = '🎰',
        coord = { vector3(919.0, 33.0, 81.0), vector3(921.0, 33.0, 81.0), vector3(923.0, 33.0, 81.0) },
        puntataMinima = 1, puntataMassima = 5,
        vantaggioBanco = 0.06,
        simboli = { '🍒', '🍋', '🔔', '⭐', '💎', '7️⃣' },
        combinazioni = {
            { simbolo = '7️⃣', quota = 60 },
            { simbolo = '💎', quota = 25 },
            { simbolo = '⭐', quota = 12 },
            { simbolo = '🔔', quota = 6 },
            { simbolo = '🍋', quota = 3 },
            { simbolo = '🍒', quota = 2 },
        },
    },
}

CAS.Regole = {
    -- Oltre questa vincita netta nella giornata, il banco ti manda a casa
    tettoVinciteGiornaliere = 8000000,
    -- Sotto questa età non si entra. È un dato del personaggio, non del giocatore
    etaMinima = 18,
    -- Ogni quanto si azzera il conteggio
    oreAzzeramento = 24,
    -- Le vincite sono soggette a imposta
    aliquotaImposta = 0.20,
}

function CAS.GetTavolo(id) return CAS.Tavoli[id] end

function CAS.TavoloVicino(coord)
    for id, t in pairs(CAS.Tavoli) do
        for _, c in ipairs(t.coord) do
            if #(coord - c) < 2.2 then return id, t end
        end
    end
    return nil
end
