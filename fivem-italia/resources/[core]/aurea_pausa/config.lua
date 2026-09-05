--[[
    AUREA · Menu di pausa — configurazione

    Il menu ESC del gioco base è pieno di roba che qui non serve e vuoto
    di quello che serve. Questo lo sostituisce: chi sei, cosa hai, dove
    stai andando, e le tre o quattro cose che uno cerca quando mette in
    pausa — le regole, il supporto, l'uscita pulita.
]]

PAU = {}

PAU.Voci = {
    { id = 'personaggio', nome = 'Il tuo personaggio', icona = '👤' },
    { id = 'regolamento', nome = 'Regolamento',        icona = '📜', comando = 'regolamento' },
    { id = 'ticket',      nome = 'Supporto',           icona = '💬', comando = 'ticket' },
    { id = 'comandi',     nome = 'Comandi e tasti',    icona = '⌨' },
    { id = 'esci',        nome = 'Esci dal server',    icona = '🚪' },
}

--- L'elenco dei tasti, così nessuno deve chiederlo in chat.
PAU.Tasti = {
    { tasto = 'TAB',  cosa = 'Inventario, bagagliaio, oggetti a terra' },
    { tasto = 'F1',   cosa = 'Telefono' },
    { tasto = 'F3',   cosa = 'Emote' },
    { tasto = 'F5',   cosa = 'Interazioni con chi hai davanti' },
    { tasto = 'F6',   cosa = 'Quadro interventi 112 (in servizio)' },
    { tasto = 'F7',   cosa = 'Banca dati interforze (in servizio)' },
    { tasto = 'F10',  cosa = 'Presenze e servizi attivi' },
    { tasto = 'Tasto destro (tenuto)', cosa = 'Terzo occhio: punta e agisci' },
    { tasto = 'B',    cosa = 'Cintura di sicurezza' },
    { tasto = 'X',    cosa = 'Mani in alto' },
    { tasto = 'H',    cosa = 'Azioni contestuali sul posto' },
}

PAU.Comandi = {
    { comando = '/me /fai', cosa = 'Azione interpretata e descrizione dell\'ambiente' },
    { comando = '/ooc',     cosa = 'Fuori personaggio, da usare il meno possibile' },
    { comando = '/112',     cosa = 'Chiamata al Numero Unico Emergenze' },
    { comando = '/id /iban /contanti', cosa = 'Documenti e portafoglio' },
    { comando = '/multe /patente',     cosa = 'Verbali e stato della patente' },
    { comando = '/soccorso', cosa = 'Chiama il carro attrezzi' },
    { comando = '/ticket',   cosa = 'Apri una richiesta allo staff' },
    { comando = '/regolamento', cosa = 'Rileggi le regole' },
}

PAU.Regole = {
    -- Quanto si aspetta prima che l'uscita sia effettiva: serve a evitare
    -- che si esca per sfuggire a una situazione
    secondiUscita = 15,
    -- Se si sta facendo qualcosa di sensibile, l'attesa si allunga
    secondiUscitaInAzione = 45,
}
