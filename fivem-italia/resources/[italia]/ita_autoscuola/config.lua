--[[
    AUREA · Autoscuola — configurazione

    La patente non si compra: si prende. Teoria con quiz veri sul Codice
    della Strada, poi la pratica su un percorso dove il sistema guarda
    come guidi — limiti, semafori, stop, e il numero di volte in cui hai
    toccato qualcosa.

    Bocciare deve essere possibile, altrimenti l'esame non serve a niente.
]]

ASC = {}

ASC.Sede = {
    nome = 'Autoscuola',
    coord = vector3(240.0, -1379.0, 33.7),
    aula = vector3(236.0, -1374.0, 33.7),
    partenzaEsame = vector4(228.0, -1391.0, 30.5, 320.0),
    blip = { sprite = 545, colore = 5, scala = 0.8 },
}

ASC.Categorie = {
    B = {
        nome = 'Patente B', descrizione = 'Autovetture fino a 3,5 t.',
        costoTeoria = 68000, costoPratica = 145000,
        modello = 'blista',
        domandeEsame = 10, erroriAmmessi = 2,
        etaMinima = 18,
    },
    A = {
        nome = 'Patente A', descrizione = 'Motocicli.',
        costoTeoria = 52000, costoPratica = 110000,
        modello = 'nemesis',
        domandeEsame = 8, erroriAmmessi = 2,
        etaMinima = 18,
    },
    C = {
        nome = 'Patente C', descrizione = 'Autocarri oltre 3,5 t.',
        costoTeoria = 95000, costoPratica = 260000,
        modello = 'pounder',
        domandeEsame = 12, erroriAmmessi = 2,
        etaMinima = 21,
        richiede = 'B',
    },
}

-- ---------------------------------------------------------------------------
--  Quiz — domande vere del Codice della Strada
-- ---------------------------------------------------------------------------
ASC.Domande = {
    { d = 'Il limite di velocità nei centri abitati è di norma:',
      r = { '50 km/h', '70 km/h', '30 km/h', '60 km/h' }, giusta = 1 },
    { d = 'Sulle strade extraurbane secondarie il limite generale è:',
      r = { '90 km/h', '110 km/h', '70 km/h', '130 km/h' }, giusta = 1 },
    { d = 'Il tasso alcolemico massimo per un conducente con patente da oltre tre anni è:',
      r = { '0,5 g/l', '0,8 g/l', '0,0 g/l', '0,3 g/l' }, giusta = 1 },
    { d = 'Per un neopatentato nei primi tre anni il tasso alcolemico ammesso è:',
      r = { '0,0 g/l', '0,5 g/l', '0,2 g/l', '0,8 g/l' }, giusta = 1 },
    { d = 'La patente B alla prima emissione ha:',
      r = { '20 punti', '30 punti', '10 punti', '25 punti' }, giusta = 1 },
    { d = 'Il segnale di STOP impone:',
      r = { 'l\'arresto completo del veicolo', 'di rallentare',
            'di dare la precedenza solo a destra', 'di suonare il clacson' }, giusta = 1 },
    { d = 'In una intersezione senza segnaletica vale:',
      r = { 'la precedenza a destra', 'la precedenza a sinistra',
            'chi arriva prima', 'il veicolo più grande' }, giusta = 1 },
    { d = 'Le cinture di sicurezza:',
      r = { 'sono obbligatorie per tutti i passeggeri',
            'servono solo al conducente', 'sono facoltative in città',
            'servono solo in autostrada' }, giusta = 1 },
    { d = 'La ZTL è:',
      r = { 'una zona a traffico limitato con accesso regolato',
            'una zona di libera sosta', 'una corsia preferenziale',
            'un limite di velocità' }, giusta = 1 },
    { d = 'La revisione periodica di un\'autovettura nuova va fatta:',
      r = { 'dopo 4 anni, poi ogni 2', 'ogni anno', 'dopo 2 anni, poi ogni anno',
            'solo alla vendita' }, giusta = 1 },
    { d = 'Guidare senza aver mai conseguito la patente comporta:',
      r = { 'una sanzione amministrativa e il fermo del veicolo',
            'solo un richiamo verbale', 'la sola decurtazione di punti',
            'nessuna conseguenza se maggiorenne' }, giusta = 1 },
    { d = 'Con semaforo giallo si deve:',
      r = { 'arrestarsi se si può farlo in condizioni di sicurezza',
            'accelerare per passare', 'proseguire sempre',
            'suonare e passare' }, giusta = 1 },
    { d = 'Il triangolo di emergenza va esposto:',
      r = { 'ad almeno 50 metri dal veicolo fermo',
            'ad almeno 10 metri', 'accanto al veicolo', 'solo di notte' }, giusta = 1 },
    { d = 'L\'assicurazione RCA è:',
      r = { 'obbligatoria per la circolazione', 'facoltativa',
            'obbligatoria solo in autostrada', 'inclusa nel bollo' }, giusta = 1 },
    { d = 'Il bollo auto si calcola principalmente su:',
      r = { 'potenza in kW e classe ambientale', 'colore del veicolo',
            'anno di acquisto', 'peso del veicolo' }, giusta = 1 },
    { d = 'Superare il limite di oltre 60 km/h comporta:',
      r = { 'sospensione della patente e decurtazione di 10 punti',
            'solo una multa lieve', 'nessuna decurtazione',
            'il ritiro della carta di circolazione' }, giusta = 1 },
    { d = 'L\'uso del telefono alla guida senza auricolare:',
      r = { 'è vietato e comporta decurtazione di punti',
            'è consentito sotto i 30 km/h', 'è consentito in coda',
            'è consentito se breve' }, giusta = 1 },
    { d = 'Sul veicolo la revisione scaduta comporta:',
      r = { 'sanzione e divieto di circolazione fino alla revisione',
            'solo un avviso', 'nulla se l\'assicurazione è valida',
            'la sola decurtazione di 2 punti' }, giusta = 1 },
}

-- ---------------------------------------------------------------------------
--  Esame pratico
-- ---------------------------------------------------------------------------
ASC.Pratica = {
    -- I punti da toccare in ordine
    percorso = {
        { nome = 'Immissione', coord = vector3(215.0, -1420.0, 30.4), limite = 50 },
        { nome = 'Rotatoria',  coord = vector3(147.0, -1490.0, 29.2), limite = 50 },
        { nome = 'Rettilineo urbano', coord = vector3(60.0, -1560.0, 29.6), limite = 50 },
        { nome = 'Zona 30',    coord = vector3(-40.0, -1600.0, 29.3), limite = 30 },
        { nome = 'Rientro',    coord = vector3(228.0, -1391.0, 30.5), limite = 50 },
    },
    raggioPunto = 12.0,

    -- Errori e quanto pesano
    penalita = {
        eccessoVelocita = 15,       -- ogni volta che si supera il limite del tratto
        collisione = 25,
        contromano = 20,
        sensoVietato = 20,
        fuoriPercorso = 10,
    },
    -- Sopra questo punteggio di errore si è bocciati
    sogliaBocciatura = 40,

    -- Tempo massimo, in secondi
    durataMassima = 420,
}

ASC.Regole = {
    -- Quanto si aspetta prima di ripetere un esame andato male
    minutiRitentare = 20,
    -- Il foglio rosa: senza teoria superata non si fa la pratica
    validitaTeoriaMinuti = 240,
}

function ASC.GetCategoria(id) return ASC.Categorie[id] end
