--[[
    AUREA · Regolamento e primo accesso — configurazione

    Il regolamento consultabile in gioco, e un tutorial che al primo
    ingresso non spiega i tasti: spiega come si gioca qui. La differenza
    fra i due è che il regolamento si legge quando serve, il tutorial si
    fa una volta e non torna più.
]]

REG = {}

REG.Sezioni = {
    {
        id = 'fondamentali', titolo = 'I tre principi', icona = '⚖',
        voci = {
            'Il personaggio non sa quello che sai tu. Se una cosa l\'hai letta su Discord o vista da spettatore, il personaggio la ignora.',
            'Il personaggio ha una vita sola e ci tiene. Non si rischia la pelle per niente, non si insegue una pattuglia armata per sport.',
            'Perdere fa parte del gioco. Una rapina che va male, un arresto, un\'auto rubata: sono storie, non ingiustizie.',
        },
    },
    {
        id = 'metagaming', titolo = 'Metagaming e powergaming', icona = '🚫',
        voci = {
            'Metagaming: usare in gioco informazioni che il personaggio non può avere. È la cosa che rovina di più il roleplay.',
            'Powergaming: imporre agli altri azioni a cui non possono reagire, o fare cose che il personaggio non potrebbe fare.',
            'Nel dubbio, lascia all\'altro la possibilità di rispondere. Un\'azione ben scritta è un\'azione a cui si può reagire.',
        },
    },
    {
        id = 'violenza', titolo = 'Quando si può sparare', icona = '🔫',
        voci = {
            'Serve un motivo che regge dentro la storia. "Mi andava" non è un motivo.',
            'Prima di sparare si parla, quando è possibile. Una rapina senza una parola non è roleplay.',
            'Chi è a terra è ferito, non morto: non si finisce e non si deruba oltre il ragionevole.',
            'Il conflitto fra organizzazioni si concorda: due gruppi che si sparano senza contesto non è una guerra, è un poligono.',
        },
    },
    {
        id = 'nuovo', titolo = 'Se è il tuo primo giorno', icona = '🌱',
        voci = {
            'Nessuno pretende che tu sappia già tutto. Sbagliare va bene, non chiedere no.',
            'Il Centro per l\'Impiego dà un lavoro subito. Da lì si costruisce il resto.',
            'Se qualcosa non torna, apri un ticket con /ticket. Non serve avere ragione per chiedere.',
        },
    },
    {
        id = 'sanzioni', titolo = 'Cosa succede se si sbaglia', icona = '📋',
        voci = {
            'La prima volta si parla. La seconda si scrive. La terza si sospende.',
            'Le sanzioni restano agli atti e si possono contestare aprendo un ticket.',
            'Il cheating e l\'uso di programmi esterni non hanno gradazioni: si esce e basta.',
        },
    },
}

--- Il tutorial del primo accesso: pochi passi, tutti utili.
REG.Tutorial = {
    {
        titolo = 'Benvenuto',
        testo = 'Questo è un server di ruolo ambientato in Italia. Le regole del gioco sono quelle vere: il codice della strada, il fisco, i documenti. Fanno parte del divertimento, non gli stanno contro.',
    },
    {
        titolo = 'I tasti che userai sempre',
        testo = 'TAB apre l\'inventario. F1 il telefono. F3 le emote. Il tasto destro del mouse tenuto premuto è il "terzo occhio": punta una cosa e ti dice che ci puoi fare.',
    },
    {
        titolo = 'Parlare',
        testo = 'Quello che scrivi in chat lo sentono solo quelli vicini. /me per le azioni, /fai per descrivere l\'ambiente, /ooc solo per le cose fuori dal personaggio.',
    },
    {
        titolo = 'I primi soldi',
        testo = 'Al Centro per l\'Impiego si trova un lavoro in due minuti. Consegne, raccolta rifiuti, autobus: si comincia da lì, come si comincia davvero.',
    },
    {
        titolo = 'I documenti contano',
        testo = 'Senza patente non si guida, senza assicurazione il veicolo si sequestra, senza residenza non si vota. Sono le cose che rendono questo posto un posto e non una mappa.',
    },
    {
        titolo = 'Se ti serve aiuto',
        testo = '/ticket apre una richiesta allo staff. /regolamento riapre queste regole quando vuoi. Buon gioco.',
    },
}

REG.Regole = {
    -- Il tutorial si mostra una volta sola
    chiaveMetadata = 'tutorial_visto',
    secondiFraPassi = 0,
}
