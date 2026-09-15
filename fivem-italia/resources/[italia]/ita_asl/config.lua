--[[
    AUREA · ASL — vigilanza igienico-sanitaria — configurazione

    QUELLO CHE MANCAVA AI LOCALI

    ita_ristorazione fa cucinare davvero: ingredienti veri, ricette vere,
    il fatto a mano che nutre di più. Ma un locale, una volta aperto, non
    aveva nessun obbligo. Nessuno controllava niente e non si poteva
    chiudere niente.

    In Italia un esercizio che somministra alimenti ha tre cose addosso:
    la SCIA, il piano di autocontrollo HACCP, e il rischio che entri
    qualcuno dell'ASL senza avvisare.

    L'IGIENE COME NUMERO

    Ogni locale ha un punteggio igienico da 0 a 100. Scende da solo
    lavorando — ogni piatto sporca — e risale con la sanificazione, che
    costa tempo e prodotto. Sotto certe soglie i clienti se ne accorgono,
    e sotto un'altra il piatto può far male sul serio: tossinfezione
    alimentare, che è un intervento del 118 e una segnalazione all'ASL.

    L'ISPEZIONE

    Un tecnico della prevenzione entra, guarda tre cose — igiene, HACCP,
    tracciabilità — e verbalizza. Le prescrizioni si sanano; le violazioni
    gravi portano alla sospensione dell'attività, che per un locale vuol
    dire non poter più cucinare finché non si rimette in regola.

    Non è burocrazia messa lì per fastidio: è la ragione per cui vale la
    pena perdere due minuti a pulire.
]]

ASL = {}

-- L'ASL è un ufficio del Comune: non serve un ente nuovo per tre persone.
ASL.Lavoro = 'comune'
ASL.Permesso = 'anagrafe'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
ASL.Sede = {
    nome = 'ASL — Servizio Igiene degli Alimenti',
    coord = vector3(-249.6, -1332.4, 31.3),
    raggio = 2.3,
    blip = { sprite = 403, colore = 25, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Igiene
-- ---------------------------------------------------------------------------
ASL.Igiene = {
    -- Da dove parte un locale appena aperto
    iniziale = 92,
    -- Quanto scende per ogni piatto preparato
    perPiatto = 0.9,
    -- E quanto per ogni ora reale, a locale fermo: lo sporco non aspetta
    perOraDiFermo = 1.5,
    -- Sanificazione
    sanificazioneSecondi = 45,
    sanificazioneRecupero = 22,
    prodotto = 'detergente',
    prodottoQuantita = 1,
    -- Soglie
    sogliaAvviso = 65,        -- i clienti cominciano a notarlo
    sogliaRischio = 45,       -- da qui il piatto può far male
    sogliaSospensione = 25,   -- l'ASL chiude
    -- Probabilità di tossinfezione, a igiene zero
    probabilitaMassima = 0.22,
}

--- La probabilità che un piatto servito faccia male, data l'igiene.
function ASL.RischioTossinfezione(igiene)
    if igiene >= ASL.Igiene.sogliaRischio then return 0 end
    local t = (ASL.Igiene.sogliaRischio - igiene) / ASL.Igiene.sogliaRischio
    return ASL.Igiene.probabilitaMassima * t
end

function ASL.Giudizio(igiene)
    if igiene >= 85 then return 'ottimo', 'Locale in ordine.' end
    if igiene >= ASL.Igiene.sogliaAvviso then return 'buono', 'Nella norma.' end
    if igiene >= ASL.Igiene.sogliaRischio then return 'scarso', 'Si vede che è da pulire.' end
    if igiene >= ASL.Igiene.sogliaSospensione then return 'grave', 'Condizioni igieniche gravemente carenti.' end
    return 'inaccettabile', 'Condizioni tali da giustificare la chiusura immediata.'
end

-- ---------------------------------------------------------------------------
--  HACCP
--
--  Il piano di autocontrollo si deposita una volta e vale un periodo. Non
--  averlo non impedisce di cucinare: impedisce di superare un'ispezione.
-- ---------------------------------------------------------------------------
ASL.Haccp = {
    costo = 90000,
    validitaMinuti = 300,
    -- Quanto pesa la sua assenza sul verbale
    sanzione = 200000,
}

-- ---------------------------------------------------------------------------
--  Ispezione
-- ---------------------------------------------------------------------------
ASL.Ispezione = {
    -- Compenso al tecnico che la esegue, dalla cassa del Comune
    compenso = 28000,
    -- Non si può ispezionare lo stesso locale più spesso di così
    raffreddamentoMinuti = 20,

    sanzioni = {
        igiene_scarsa    = { importo = 150000, testo = 'carenze igieniche, art. 6 L. 283/1962', grave = false },
        igiene_grave     = { importo = 400000, testo = 'condizioni igieniche gravemente carenti', grave = true },
        haccp_mancante   = { importo = 200000, testo = 'piano di autocontrollo assente, Reg. CE 852/2004', grave = true },
        tracciabilita    = { importo = 120000, testo = 'merce priva di tracciabilità', grave = false },
    },

    -- Quante violazioni gravi portano alla sospensione
    graviPerSospensione = 1,
    sospensioneMinuti = 25,
    -- Quanto costa la riapertura dopo una sospensione
    riapertura = 250000,
}

-- ---------------------------------------------------------------------------
--  Tossinfezione
-- ---------------------------------------------------------------------------
ASL.Tossinfezione = {
    -- Danno alla salute di chi mangia
    danno = 22,
    -- Quanto dura il malessere, in secondi
    durata = 90,
    -- La segnalazione all'ASL parte da sola: è un obbligo del 118
    segnalaSempre = true,
}
