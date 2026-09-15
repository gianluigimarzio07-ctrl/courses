--[[
    AUREA · Usura — configurazione

    PERCHÉ ESISTE

    La banca dà mutui a chi ha il merito creditizio. Chi non ce l'ha —
    perché ha debiti fiscali, perché ha un fascicolo aperto, perché ha
    appena perso tutto al casinò — non ha nessun posto dove andare.

    Quel vuoto, in Italia, lo riempie qualcun altro. Ed è il modo in cui
    un'organizzazione criminale entra nell'economia legale senza sparare
    a nessuno: presta, si fa restituire il doppio, e quando non gli
    restituiscono si prende l'attività.

    COME FUNZIONA QUI

    Un giocatore offre un prestito a un altro, faccia a faccia, al tasso
    che vuole. Il modulo calcola il TAEG e lo confronta con il tasso
    soglia trimestrale: sopra quello è usura, art. 644 c.p., e il
    contratto è nullo — gli interessi non sono dovuti per legge.

    Ma il creditore non lo sa che il contratto è nullo, e nemmeno gli
    interessa: ha altri modi per farsi pagare. Le rate scadono da sole, e
    a ogni rata saltata il debitore riceve una visita. Le visite non le
    fa il modulo: le fa chi ha prestato, e il modulo gli dice a chi
    andare.

    LA VIA D'USCITA

    Denunciare. Chi denuncia perde il rapporto e guadagna un processo,
    ma il debito si estingue con il contratto: è l'unica cosa che
    funziona davvero, e costa esattamente quello che costa nella realtà.
]]

USU = {}

-- ---------------------------------------------------------------------------
--  Il tasso soglia
--
--  In Italia lo pubblica il MEF ogni trimestre: tasso medio rilevato,
--  aumentato di un quarto, più quattro punti. Qui è un numero fisso ma
--  calcolato con la stessa formula, così resta spiegabile.
-- ---------------------------------------------------------------------------
USU.Soglia = {
    tassoMedio = 0.11,
    -- (medio × 1,25) + 4 punti = soglia
    moltiplicatore = 1.25,
    puntiAggiuntivi = 0.04,
}

function USU.TassoSoglia()
    return USU.Soglia.tassoMedio * USU.Soglia.moltiplicatore + USU.Soglia.puntiAggiuntivi
end

--- Il TAEG di un prestito: interesse totale sul capitale, annualizzato
--- sul numero di rate. Le rate qui sono "mesi".
function USU.Taeg(capitale, totaleDaRestituire, rate)
    if capitale <= 0 or rate <= 0 then return 0 end
    local interesse = (totaleDaRestituire - capitale) / capitale
    return interesse * (12 / rate)
end

-- ---------------------------------------------------------------------------
--  Limiti del prestito
-- ---------------------------------------------------------------------------
USU.Prestito = {
    minimo = 50000,          -- 500 €
    massimo = 15000000,      -- 150.000 €
    rateMinime = 3,
    rateMassime = 12,
    -- Ogni quanto scade una rata, in minuti
    minutiPerRata = 20,
    -- Quanti prestiti attivi può avere un debitore
    massimiPerDebitore = 2,
    -- E quanti ne può avere in piedi un creditore
    massimiPerCreditore = 6,
}

-- ---------------------------------------------------------------------------
--  Morosità
--
--  Saltare una rata non fa scattare niente in automatico: manda un
--  avviso al creditore. È lui a decidere cosa fare, e quello che fa lo
--  fa con le sue mani.
-- ---------------------------------------------------------------------------
USU.Morosita = {
    -- Interesse di mora che si aggiunge al residuo, a rata saltata
    moraPerRata = 0.08,
    -- Dopo quante rate saltate il credito si considera inesigibile e
    -- l'organizzazione passa alle maniere che conosce
    rateInsolvenza = 3,
    -- Il calore che l'insolvenza porta all'organizzazione del creditore
    calorePerInsolvenza = 6,
}

-- ---------------------------------------------------------------------------
--  Denuncia
-- ---------------------------------------------------------------------------
USU.Denuncia = {
    -- Chi denuncia vede estinto il debito residuo
    estingueDebito = true,
    -- Il fondo di solidarietà per le vittime: l'erario restituisce una
    -- quota di quanto già pagato in interessi
    ristoro = 0.50,
    -- Aggravante se il creditore è affiliato a un'organizzazione
    reatoBase = '644',
    reatoAggravato = '644a',
}

-- ---------------------------------------------------------------------------
--  Dove si denuncia e dove si contratta
-- ---------------------------------------------------------------------------
USU.Distanza = {
    -- Creditore e debitore devono essere così vicini per stipulare
    stipula = 3.0,
}

--- Come si giudica un tasso.
function USU.Giudizio(taeg)
    local soglia = USU.TassoSoglia()
    if taeg <= USU.Soglia.tassoMedio then return 'onesto', 'Sotto il tasso medio di mercato.' end
    if taeg <= soglia then
        return 'caro', ('Caro ma lecito: la soglia d\'usura è al %.1f%%.'):format(soglia * 100)
    end
    return 'usurario', ('USURA. Soglia %.1f%%, tu sei al %.1f%%. Gli interessi non sono dovuti.')
        :format(soglia * 100, taeg * 100)
end
