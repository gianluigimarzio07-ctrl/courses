--[[
    AUREA · Bische clandestine — configurazione

    IL CASINÒ C'ERA. QUESTO È IL SUO CONTRARIO.

    aurea_casino è legale: concessione, limiti di puntata, antiriciclaggio.
    Fa esattamente quello che deve fare un casinò autorizzato, e cioè
    poco.

    La bisca è l'altra metà: si apre dove capita, il banco lo mette
    qualcuno di tasca sua, non ci sono limiti, e non c'è nessuno che
    verifichi da dove vengono i soldi. È il posto dove il contante sporco
    si muove senza lasciare traccia, ed è per questo che le bische sono
    sempre state un affare delle organizzazioni.

    SETTE E MEZZO

    Il gioco è quello vero delle bische italiane, non una roulette. Si
    chiede carta finché si vuole, le figure valgono mezzo punto, sopra
    sette e mezzo si sballa. Il banco tira per ultimo e deve stare alle
    stesse regole — ma incassa lo sballo del giocatore anche quando
    poi sballa lui, che è il motivo per cui il banco vince.

    La matta (il re di denari) vale quanto vuoi: è la carta che rende
    il gioco un gioco e non un lancio di dado.

    COSA RISCHIA CHI APRE

    Art. 718 c.p. per chi tiene la bisca, art. 720 per chi ci gioca. Il
    banco si sequestra. E ogni serata alza il calore dell'organizzazione
    di chi l'ha aperta: una bisca che gira troppo è una bisca che finisce.
]]

BIS = {}

-- ---------------------------------------------------------------------------
--  Dove si può aprire
--
--  Retrobottega e magazzini. La bisca dura una serata e poi sparisce:
--  aprirne una nello stesso posto due volte di fila è come chiamarli.
-- ---------------------------------------------------------------------------
BIS.Luoghi = {
    { id = 'vespucci',  nome = 'Retro del bar di Vespucci',   coord = vector3(-1193.4, -893.2, 13.9) },
    { id = 'magazzino', nome = 'Magazzino di Cypress',        coord = vector3(756.2, -1398.6, 26.5) },
    { id = 'circolo',   nome = 'Circolo ricreativo di Paleto',coord = vector3(-149.8, 6355.4, 31.5) },
    { id = 'cantina',   nome = 'Cantina di Mirror Park',      coord = vector3(1140.6, -982.4, 46.4) },
    { id = 'officina',  nome = 'Officina dismessa di Sandy',  coord = vector3(1738.2, 3717.8, 34.1) },
}

function BIS.GetLuogo(id)
    for _, l in ipairs(BIS.Luoghi) do
        if l.id == id then return l end
    end
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
BIS.Apertura = {
    -- Il banco minimo che l'organizzatore deve mettere, in contanti
    bancoMinimo = 500000,        -- 5.000 €
    bancoMassimo = 20000000,     -- 200.000 €
    -- Quanto dura una serata, in minuti
    durataMinuti = 45,
    -- Quante bische possono essere aperte insieme su tutta la mappa
    contemporanee = 2,
    -- Attesa prima di poter riaprire nello stesso luogo, in minuti
    raffreddamentoLuogo = 90,
    -- Serve il contante sporco? No: la bisca accetta contanti e basta.
    -- È il punto: qui non si chiede niente a nessuno.
}

-- ---------------------------------------------------------------------------
--  Il tavolo
-- ---------------------------------------------------------------------------
BIS.Tavolo = {
    puntataMinima = 10000,       -- 100 €
    puntataMassima = 2000000,    -- 20.000 €
    -- La quota che il banco trattiene su ogni mano vinta dal giocatore
    rake = 0.05,
    -- Quante mani al minuto può giocare una persona: è un limite contro
    -- il grinding, non contro i bari
    secondiFraMani = 4,
}

-- ---------------------------------------------------------------------------
--  Il mazzo italiano
--
--  Quaranta carte, quattro semi. Le figure valgono mezzo punto. Il re di
--  denari è la matta.
-- ---------------------------------------------------------------------------
BIS.Semi = { 'denari', 'coppe', 'spade', 'bastoni' }

BIS.Carte = {
    { valore = 1,   nome = 'Asso',    punti = 1.0 },
    { valore = 2,   nome = 'Due',     punti = 2.0 },
    { valore = 3,   nome = 'Tre',     punti = 3.0 },
    { valore = 4,   nome = 'Quattro', punti = 4.0 },
    { valore = 5,   nome = 'Cinque',  punti = 5.0 },
    { valore = 6,   nome = 'Sei',     punti = 6.0 },
    { valore = 7,   nome = 'Sette',   punti = 7.0 },
    { valore = 8,   nome = 'Fante',   punti = 0.5 },
    { valore = 9,   nome = 'Cavallo', punti = 0.5 },
    { valore = 10,  nome = 'Re',      punti = 0.5 },
}

BIS.Regole = {
    limite = 7.5,
    -- Il banco si ferma a questo punteggio o sopra
    bancoSiFermaA = 5.5,
    -- Chi fa sette e mezzo con due carte prende una volta e mezza
    pagamentoSetteEMezzo = 1.5,
    -- La matta: il re di denari vale quanto serve per non sballare
    mattaSeme = 'denari',
    mattaValore = 10,
}

--- Il punteggio di una mano, con la matta usata al meglio.
---@param mano table elenco di { valore, seme }
---@return number punti, boolean haMatta
function BIS.Punteggio(mano)
    local punti, matta = 0, false

    for _, c in ipairs(mano) do
        if c.valore == BIS.Regole.mattaValore and c.seme == BIS.Regole.mattaSeme then
            matta = true
        else
            punti = punti + BIS.Carte[c.valore].punti
        end
    end

    if not matta then return punti, false end

    -- La matta vale il massimo che non fa sballare, da mezzo punto in su
    local restante = BIS.Regole.limite - punti
    if restante < 0.5 then return punti + 0.5, true end
    return punti + math.min(7, math.floor(restante * 2) / 2), true
end

function BIS.Sballato(punti)
    return punti > BIS.Regole.limite
end

-- ---------------------------------------------------------------------------
--  Rischio
-- ---------------------------------------------------------------------------
BIS.Rischio = {
    -- Calore che la serata porta all'organizzazione, a fine serata
    calorePerSerata = 5,
    -- Probabilità, a ogni controllo, che qualcuno faccia una soffiata
    probabilitaSoffiata = 0.10,
    controlloMinuti = 8,
    -- Quante mani servono perché la bisca cominci a farsi notare
    maniPrimaDellaSoffiata = 12,
}

BIS.Reati = {
    esercizio = '718',
    partecipazione = '720',
}
