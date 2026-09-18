--[[
    AUREA · Parrocchia — configurazione

    PERCHÉ UNA CHIESA IN UN SERVER ROLEPLAY

    Non per devozione: per tre meccaniche che nessun altro modulo può
    dare.

    1. IL MATRIMONIO CONCORDATARIO
       ita_comune celebra il matrimonio civile. In Italia esiste anche
       l'altro, che ha effetti civili se trascritto — e le due cose non
       sono intercambiabili: un rito religioso non trascritto non cambia
       niente sui beni, e chi non lo sa se ne accorge al divorzio.

    2. IL SEGRETO CONFESSIONALE
       Art. 200 c.p.p.: il ministro di culto NON PUÒ essere obbligato a
       deporre su quanto ha appreso per ragione del proprio ministero.
       Qui è letterale: quello che si dice in confessionale non finisce in
       nessun registro leggibile, non compare in nessun tabulato, e se
       qualcuno prova a acquisirlo si becca un rifiuto motivato.

       È l'unico canale del server che nemmeno un decreto del giudice
       apre. Ed è il motivo per cui serve.

    3. LA CARITÀ CHE COSTA A QUALCUNO
       La mensa dà da mangiare a chi non ha un lavoro. Ma non stampa
       cibo: distribuisce quello che i fedeli hanno lasciato. Se nessuno
       offre, la mensa chiude — che è esattamente come funziona.
]]

CHI = {}

CHI.Lavoro = 'clero'

-- ---------------------------------------------------------------------------
--  La parrocchia
-- ---------------------------------------------------------------------------
CHI.Parrocchia = {
    nome = 'Parrocchia di San Fiacre',
    coord = vector3(-1683.2, -289.4, 51.8),
    raggio = 3.0,
    blip = { sprite = 306, colore = 0, scala = 0.75 },

    -- I punti dentro: l'altare per i riti, il confessionale, la mensa
    altare = vector3(-1680.4, -285.2, 51.8),
    confessionale = vector3(-1687.6, -292.8, 51.8),
    mensa = vector3(-1674.8, -296.4, 51.6),
    offertorio = vector3(-1682.0, -294.0, 51.8),
}

-- ---------------------------------------------------------------------------
--  I riti
-- ---------------------------------------------------------------------------
CHI.Riti = {
    matrimonio = {
        nome = 'Matrimonio', icona = '💒',
        secondi = 40,
        -- Serve che siano già sposati civilmente: il concordatario qui è
        -- semplificato, ma l'ordine resta quello che conta
        richiedeMatrimonioCivile = true,
        offertaSuggerita = 150000,
        partecipanti = 2,
    },
    battesimo = {
        nome = 'Battesimo', icona = '💧',
        secondi = 25,
        offertaSuggerita = 40000,
        partecipanti = 1,
        -- Il padrino: un secondo presente che risponde per il battezzato
        richiedePadrino = true,
    },
    funerale = {
        nome = 'Esequie', icona = '🕯',
        secondi = 35,
        offertaSuggerita = 90000,
        partecipanti = 1,
        -- Le esequie si celebrano per chi è passato da ita_funebri
        richiedeDefunto = true,
    },
    benedizione = {
        nome = 'Benedizione', icona = '🙏',
        secondi = 12,
        offertaSuggerita = 0,
        partecipanti = 1,
        -- Toglie stress: è l'unico effetto meccanico, ed è modesto
        stress = -25,
    },
}

function CHI.GetRito(id)
    return CHI.Riti[id]
end

-- ---------------------------------------------------------------------------
--  Confessione
--
--  Il contenuto non si salva. Da nessuna parte. Non è una dimenticanza:
--  è il modulo.
-- ---------------------------------------------------------------------------
CHI.Confessione = {
    -- Quanto si può scrivere
    caratteriMassimi = 400,
    -- Quanta pace dà: il solo effetto misurabile
    stress = -40,
    -- Quanto spesso ci si può tornare
    attesaMinuti = 15,
    -- Chi può ascoltare
    permesso = 'confessione',
}

-- ---------------------------------------------------------------------------
--  Carità
--
--  La mensa distribuisce quello che c'è. `scorta` è un contatore di
--  porzioni che sale con le offerte in natura e scende a ogni pasto.
-- ---------------------------------------------------------------------------
CHI.Mensa = {
    -- Chi può mangiare alla mensa
    lavoriAmmessi = { 'disoccupato', 'pensionato' },
    -- E chiunque abbia fame sotto questa soglia, lavoro o no: la carità
    -- non chiede il curriculum
    fameSotto = 25,

    -- Cosa si dà
    piatto = 'panino',
    bevanda = 'acqua',
    -- Quante porzioni costa una razione
    porzioniPerPasto = 1,
    attesaMinuti = 20,

    -- Le offerte in natura: quanto vale una donazione
    offerteInNatura = {
        panino = 2, pizza_margherita = 4, pasta_carbonara = 4,
        farina_00 = 6, grano = 8, pomodoro_san_marzano = 5, acqua = 1,
    },
    -- E quante porzioni compra un'offerta in denaro
    porzioniPerEuro = 1 / 250,      -- 2,50 € a porzione
}

-- ---------------------------------------------------------------------------
--  Offertorio
--
--  Le offerte finanziano la mensa e la parrocchia. Una quota va alla
--  cassa dell'ente, il resto in porzioni.
-- ---------------------------------------------------------------------------
CHI.Offertorio = {
    quotaAllaMensa = 0.60,
    minimo = 100,
}

-- ---------------------------------------------------------------------------
--  Il segreto, visto da fuori
-- ---------------------------------------------------------------------------
CHI.Segreto = {
    articolo = 'art. 200 c.p.p.',
    -- Il testo che ricevono le forze dell'ordine o il giudice che provano
    -- ad acquisire qualcosa dal confessionale
    rifiuto = 'I ministri di culto non possono essere obbligati a deporre su quanto hanno conosciuto per ragione del loro ministero. Non c\'è niente da acquisire.',
}
