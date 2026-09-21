--[[
    AUREA · Calcio (configurazione)

    IL DASPO CHE NON AVEVA UNO STADIO

    ita_questura sa emettere il DASPO — il divieto di accesso ai luoghi
    dove si svolgono manifestazioni sportive. È un provvedimento che
    esiste dal 1989 e che in Italia ha una storia molto precisa: è nato
    per gli stadi.

    Nel server però uno stadio non c'era. Il DASPO si poteva dare per
    "locali notturni" o "centro storico", mai per la cosa per cui è
    stato inventato. Questa risorsa gli restituisce il suo luogo.

    COSA C'È DENTRO

    Un campionato che gira da solo: sei squadre, partite che si giocano
    a intervalli, un risultato che il server estrae pesando la forza
    relativa, e una classifica che si aggiorna. Nessuno deve essere
    online perché il campionato continui.

    E intorno, le tre cose che in Italia fanno il calcio:

    · LA TESSERA DEL TIFOSO, che serve per entrare;
    · IL BIGLIETTO, che si compra e che al DASPO non si vende;
    · GLI INCIDENTI, che scattano quando in curva c'è troppa gente
      delle due tifoserie insieme — e che finiscono in DASPO.

    LE SCOMMESSE

    aurea_scommesse sa già aprire eventi a quote e pagare. Qui non si
    duplica niente: ogni partita apre un evento lì, con i tre esiti che
    tutti conoscono. Il calcio dà alle scommesse una cosa che non
    avevano — qualcosa su cui scommettere che non dipende da un
    giocatore che dichiara il risultato.
]]

CAL = {}

CAL.Stadio = {
    nome = 'Stadio comunale',
    coord = vector3(-248.2, -2019.8, 29.1),
    ingresso = vector3(-252.6, -2013.4, 29.1),
    raggio = 2.6,
    -- Il raggio entro cui si è "allo stadio", per i tafferugli
    raggioTifoseria = 70.0,
    blip = { sprite = 313, colore = 2, scala = 0.8 },

    -- Il luogo come lo scrive la Questura nel provvedimento: deve
    -- coincidere, altrimenti il DASPO non morde qui.
    luogoDaspo = 'Stadio comunale',
}

-- ---------------------------------------------------------------------------
--  Il campionato
-- ---------------------------------------------------------------------------
CAL.Campionato = {
    -- Ogni quanti minuti si gioca una partita
    minutiFraPartite = 20,

    -- Quanti minuti dura
    minutiDurata = 6,

    -- Quanto conta la classifica nel determinare il risultato: zero
    -- sarebbe un sorteggio, uno sarebbe una tabella. Sta in mezzo.
    pesoForma = 0.35,

    golMassimi = 4,
}

-- ---------------------------------------------------------------------------
--  Biglietti e tessera
-- ---------------------------------------------------------------------------
CAL.Biglietti = {
    tessera = 4500,
    curva = 1200,
    tribuna = 3500,

    -- Quota dell'incasso che va alla squadra di casa; il resto è
    -- gestione dell'impianto, cioè del Comune.
    quotaSquadra = 0.70,

    capienza = 80,
}

-- ---------------------------------------------------------------------------
--  Ordine pubblico
-- ---------------------------------------------------------------------------
CAL.Ordine = {
    -- Se allo stadio ci sono tifosi di due squadre diverse e le due
    -- tifoserie superano questa soglia, succede qualcosa.
    tifosiPerTafferuglio = 4,

    probabilitaTafferuglio = 35,

    -- Quanto dura il DASPO che ne esce, in ore
    oreDaspo = 240,

    -- E la sanzione
    sanzione = 80000,

    reato = '588',
}

function CAL.GetSquadra(codice)
    for _, s in ipairs(CAL.Squadre) do
        if s.codice == codice then return s end
    end
    return nil
end

--- Le squadre come le conosce il client. I dati veri (punti, partite)
--- stanno nel database: qui c'è solo il nome.
CAL.Squadre = {
    { codice = 'aurea',    nome = 'A.C. Aurea' },
    { codice = 'portuale', nome = 'Portuale Calcio' },
    { codice = 'paleto',   nome = 'Paleto Bay F.C.' },
    { codice = 'sandy',    nome = 'Sandy Shores United' },
    { codice = 'vespucci', nome = 'Vespucci 1921' },
    { codice = 'harmony',  nome = 'Harmony Sportiva' },
}
