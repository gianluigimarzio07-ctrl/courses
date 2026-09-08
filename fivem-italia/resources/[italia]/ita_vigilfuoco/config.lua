--[[
    AUREA · Vigili del Fuoco — configurazione

    Nel server c'era un buco imbarazzante: il lavoro `vigili_fuoco` esiste
    da sempre in shared/lavori.lua, con tre gradi e i permessi
    'estinzione' ed 'estricazione' già scritti, e non c'era una sola riga
    di codice che li usasse. Un intero corpo di soccorso senza niente da
    fare.

    Questo lo riempie, e prova a farlo in un modo che non sia il solito
    "premi E sul fuoco finché sparisce".

    L'IDEA: IL FUOCO SI MUOVE

    Un incendio non è un punto: è un insieme di focolai, ognuno con la sua
    intensità. Ogni focolaio cresce da solo, e quando supera una soglia ne
    accende uno vicino. Se la squadra è lenta, l'incendio si allarga più in
    fretta di quanto lo spengano, e a quel punto o arrivano rinforzi o
    l'edificio se ne va.

    Questo cambia il gioco in un modo preciso: non conta quanto in fretta
    premi il tasto, conta quanti siete e come vi dividete. Un vigile da
    solo su un incendio a sei focolai non ce la fa, e non perché il server
    glielo vieta — perché il fuoco cresce più in fretta di lui.

    L'ACQUA FINISCE

    La lancia consuma l'acqua dell'autobotte a cui è collegata. Quando
    finisce, si torna all'idrante. È la ragione per cui l'autobotte va
    parcheggiata con la testa, e per cui qualcuno deve restare al mezzo.
]]

VVF = {}

VVF.Lavoro = 'vigili_fuoco'

-- ---------------------------------------------------------------------------
--  Caserme
-- ---------------------------------------------------------------------------
VVF.Caserme = {
    {
        nome = 'Comando Provinciale — Distaccamento Centro',
        coord = vector3(1193.5, -1466.0, 34.9),
        armadio = vector3(1197.4, -1471.3, 34.9),
        rimessa = vector4(1204.0, -1461.5, 34.9, 40.0),
        blip = { sprite = 436, colore = 1, scala = 0.9 },
    },
    {
        nome = 'Distaccamento di Paleto',
        coord = vector3(-379.1, 6115.6, 31.5),
        armadio = vector3(-374.2, 6119.0, 31.5),
        rimessa = vector4(-370.5, 6109.8, 31.5, 225.0),
        blip = { sprite = 436, colore = 1, scala = 0.8 },
    },
}

-- ---------------------------------------------------------------------------
--  Mezzi
-- ---------------------------------------------------------------------------
VVF.Mezzi = {
    { modello = 'firetruk', nome = 'APS — Autopompa serbatoio', acqua = 3000, grado = 0 },
    { modello = 'firetruk', nome = 'Autobotte', acqua = 6000, grado = 1 },
    { modello = 'ambulance', nome = 'Mezzo di supporto', acqua = 0, grado = 0 },
}

--- Litri consumati al secondo dalla lancia. Con 3000 litri fanno cinque
--- minuti di getto continuo: sembra tanto, non lo è su sei focolai.
VVF.ConsumoAlSecondo = 10

-- ---------------------------------------------------------------------------
--  Idranti
--
--  Dove si ricarica l'autobotte. Sono pochi di proposito: la posizione
--  degli idranti decide dove conviene attestarsi.
-- ---------------------------------------------------------------------------
VVF.Idranti = {
    vector3(1191.0, -1449.1, 34.8),
    vector3(215.9, -812.4, 30.8),
    vector3(-247.5, -978.0, 31.2),
    vector3(305.4, -595.0, 43.3),
    vector3(-1219.0, -910.1, 12.3),
    vector3(1205.7, -3110.4, 5.5),
    vector3(-379.1, 6115.6, 31.5),
    vector3(1961.5, 3740.7, 32.3),
    vector3(-3241.0, 1001.2, 12.5),
}

VVF.Ricarica = {
    raggio = 8.0,
    -- Litri al secondo in ricarica: riempire un'autobotte da 6000 litri
    -- richiede un minuto e mezzo, che è il tempo in cui il fuoco cresce.
    litriAlSecondo = 70,
}

-- ---------------------------------------------------------------------------
--  Il fuoco
-- ---------------------------------------------------------------------------
VVF.Fuoco = {
    -- Intensità iniziale di un focolaio appena nato
    intensitaIniziale = 35,
    -- Quanto cresce ogni tick (2 secondi) se nessuno lo tocca
    crescitaPerTick = 1.6,
    -- Sopra questa intensità il focolaio ne accende uno vicino
    sogliaPropagazione = 80,
    -- Distanza a cui nasce il focolaio figlio
    distanzaPropagazione = 6.0,
    -- Quanti focolai al massimo per incendio: oltre, l'incendio smette di
    -- crescere e comincia a consumarsi da solo (l'edificio è perso)
    massimoFocolai = 14,

    -- Quanto abbassa l'intensità un secondo di getto d'acqua
    spegnimentoAlSecondo = 9,
    -- L'estintore fa meno, e serve solo sui focolai piccoli
    estintoreAlSecondo = 4,
    estintoreIntensitaMassima = 45,

    -- Il fuoco fa male a chi ci sta dentro senza protezione
    raggioDanno = 3.5,
    dannoPerTick = 4,
    -- Con i dispositivi di protezione il danno è quasi nullo
    dannoConDPI = 1,
}

-- ---------------------------------------------------------------------------
--  Tipologie di intervento
--
--  Ognuna nasce da una causa diversa e ha una sua difficoltà.
-- ---------------------------------------------------------------------------
VVF.Tipologie = {
    veicolo = {
        nome = 'Incendio di autoveicolo', icona = '🚗',
        focolaiIniziali = 2, compenso = 32000,
        descrizione = 'Vano motore in fiamme. Attenzione al serbatoio.',
        -- Un veicolo in fiamme può esplodere se lo si lascia andare
        esplode = true, sogliaEsplosione = 95,
    },
    appartamento = {
        nome = 'Incendio di appartamento', icona = '🏠',
        focolaiIniziali = 3, compenso = 68000,
        descrizione = 'Fiamme in ambiente confinato. Verificare la presenza di persone.',
        personePossibili = true,
    },
    attivita = {
        nome = 'Incendio in attività commerciale', icona = '🏪',
        focolaiIniziali = 4, compenso = 95000,
        descrizione = 'Locale aperto al pubblico. Priorità all\'evacuazione.',
        personePossibili = true,
    },
    boschivo = {
        nome = 'Incendio boschivo', icona = '🌲',
        focolaiIniziali = 5, compenso = 120000,
        descrizione = 'Fronte di fiamma su vegetazione. Si allarga in fretta con il vento.',
        -- Il vento e la siccità lo rendono peggiore
        sensibileAlMeteo = true,
    },
    industriale = {
        nome = 'Incendio in area industriale', icona = '🏭',
        focolaiIniziali = 6, compenso = 165000,
        descrizione = 'Presenza di sostanze pericolose. Autorespiratore obbligatorio.',
        richiedeAutorespiratore = true,
    },
    gas = {
        nome = 'Fuga di gas', icona = '💨',
        focolaiIniziali = 1, compenso = 78000,
        descrizione = 'Nessuna fiamma. Va intercettata la valvola, non annaffiata.',
        senzaAcqua = true,
        richiedeAutorespiratore = true,
    },
}

-- ---------------------------------------------------------------------------
--  Dove possono nascere gli incendi spontanei
-- ---------------------------------------------------------------------------
VVF.Zone = {
    { nome = 'Centro storico',      coord = vector3(215.0, -810.0, 30.8),    raggio = 220.0, tipologie = { 'appartamento', 'attivita', 'veicolo' } },
    { nome = 'Zona industriale',    coord = vector3(720.0, -960.0, 25.0),    raggio = 260.0, tipologie = { 'industriale', 'gas', 'veicolo' } },
    { nome = 'Porto',               coord = vector3(1205.0, -3110.0, 5.5),   raggio = 300.0, tipologie = { 'industriale', 'gas' } },
    { nome = 'Lungomare',           coord = vector3(-1220.0, -1300.0, 5.0),  raggio = 250.0, tipologie = { 'attivita', 'appartamento' } },
    { nome = 'Colline nord',        coord = vector3(1400.0, 3600.0, 35.0),   raggio = 500.0, tipologie = { 'boschivo' } },
    { nome = 'Monte Chiliad',       coord = vector3(-500.0, 5300.0, 80.0),   raggio = 600.0, tipologie = { 'boschivo' } },
    { nome = 'Paleto',              coord = vector3(-330.0, 6100.0, 31.0),   raggio = 250.0, tipologie = { 'appartamento', 'veicolo', 'boschivo' } },
}

VVF.Spontanei = {
    -- Ogni quanti minuti si tira il dado
    minutiControllo = 22,
    -- Probabilità che nasca un incendio, se c'è almeno un vigile in servizio
    probabilita = 34,
    -- Senza vigili in servizio la probabilità crolla: non ha senso
    -- bruciare la città quando non c'è nessuno che possa intervenire
    probabilitaSenzaVigili = 4,
    -- Non più di questi incendi aperti insieme
    massimoAperti = 2,
    -- La siccità di ita_ambiente moltiplica la probabilità dei boschivi
    moltiplicatoreSiccita = 2.5,
    -- Se nessuno interviene, l'incendio si estingue da solo dopo tot minuti
    -- lasciando però il danno fatto
    minutiAutoestinzione = 25,
}

-- ---------------------------------------------------------------------------
--  Attrezzatura
-- ---------------------------------------------------------------------------
VVF.Attrezzatura = {
    dpi = 'dpi_antincendio',
    lancia = 'manichetta',
    estintore = 'estintore',
    autorespiratore = 'autorespiratore',
    cesoie = 'cesoie_idrauliche',
    ascia = 'ascia_pompiere',

    -- Cosa c'è nell'armadio di caserma, per grado
    armadio = {
        [0] = { 'dpi_antincendio', 'manichetta', 'estintore', 'ascia_pompiere' },
        [1] = { 'dpi_antincendio', 'manichetta', 'estintore', 'ascia_pompiere',
                'autorespiratore', 'cesoie_idrauliche' },
        [2] = { 'dpi_antincendio', 'manichetta', 'estintore', 'ascia_pompiere',
                'autorespiratore', 'cesoie_idrauliche' },
    },
}

-- ---------------------------------------------------------------------------
--  Estricazione
--
--  Chi resta incastrato in un veicolo dopo un incidente non lo tira fuori
--  il 118: lo tirano fuori i vigili con le cesoie. È il momento in cui i
--  due servizi devono per forza lavorare insieme.
-- ---------------------------------------------------------------------------
VVF.Estricazione = {
    durata = 22000,
    compenso = 45000,
    -- Distanza massima dal veicolo
    raggio = 4.0,
    -- Un ferito incastrato peggiora mentre aspetta
    dannoPerMinuto = 6,
}

-- ---------------------------------------------------------------------------
--  Certificato di prevenzione incendi
--
--  I VVF non fanno solo emergenza: rilasciano il CPI alle attività, ed è
--  un reddito ordinario che non dipende dal fatto che scoppi un incendio.
-- ---------------------------------------------------------------------------
VVF.CPI = {
    nome = 'Certificato di prevenzione incendi',
    item = 'cpi',
    durata = 25000,
    onorario = 42000,
    validitaGiorni = 365,
    gradoMinimo = 1,
    -- Un'attività senza CPI valido rischia la sanzione in caso di controllo
    sanzione = 129000,
    articolo = 'art. 20 D.Lgs. 139/2006',
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function VVF.GetTipologia(id) return VVF.Tipologie[id] end

function VVF.GetZona(nome)
    for _, z in ipairs(VVF.Zone) do
        if z.nome == nome then return z end
    end
    return nil
end

function VVF.CasermaVicina(coord, distanza)
    for _, c in ipairs(VVF.Caserme) do
        if #(coord - c.coord) <= (distanza or 40.0) then return c end
    end
    return nil
end

function VVF.IdranteVicino(coord)
    for _, i in ipairs(VVF.Idranti) do
        if #(coord - i) <= VVF.Ricarica.raggio then return i end
    end
    return nil
end

--- Un punto a caso dentro una zona, sul piano.
function VVF.PuntoInZona(zona)
    local angolo = math.random() * math.pi * 2
    local raggio = math.sqrt(math.random()) * zona.raggio
    return vector3(
        zona.coord.x + math.cos(angolo) * raggio,
        zona.coord.y + math.sin(angolo) * raggio,
        zona.coord.z)
end
