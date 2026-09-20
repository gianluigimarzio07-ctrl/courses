--[[
    AUREA · Istituti di vigilanza privata — configurazione

    IL PROBLEMA CHE RISOLVE

    ita_rapine è costruito bene: nessun colpo parte se non ci sono
    abbastanza agenti in servizio, perché una rapina senza inseguimento è
    un bancomat. Ma questo vuol dire che quando la polizia è scarsa non
    succede niente — e chi voleva fare il rapinatore sta fermo.

    La vigilanza privata è la terza parte che mancava. Non sono forze
    dell'ordine e non arrestano nessuno: sono guardie particolari giurate,
    che in Italia hanno una qualifica precisa (art. 133 TULPS), un decreto
    del prefetto, e il diritto di portare l'arma solo in servizio.

    COSA FANNO

        piantonamento   presidiano un esercizio: l'allarme parte prima
        portavalori     trasportano contante fra le filiali

    Il portavalori è la parte interessante: è un obiettivo che si muove,
    con dentro una cifra che tutti sanno e nessuno può contare. Chi lo
    scorta guadagna sulla consegna. Chi lo assalta lo sa in anticipo,
    perché un furgone blindato in strada si vede.

    LA QUALIFICA

    Il decreto lo rilascia la Questura — qui: un pubblico ufficiale — e
    richiede il porto d'armi e il casellario pulito. Chi prende una
    condanna lo perde, come nella realtà.
]]

SIC = {}

SIC.Lavoro = 'vigilanza'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
SIC.Istituto = {
    nome = 'Istituto di vigilanza',
    coord = vector3(-350.8, -46.2, 49.0),
    raggio = 2.4,
    blip = { sprite = 60, colore = 40, scala = 0.7 },
}

-- ---------------------------------------------------------------------------
--  Guardia particolare giurata
-- ---------------------------------------------------------------------------
SIC.Giuramento = {
    -- Chi rilascia il decreto
    lavoriAbilitati = { 'polizia', 'carabinieri' },
    -- Requisiti
    richiedePortoArmi = true,
    -- Il certificato di idoneità al maneggio delle armi, che rilascia il
    -- Tiro a Segno Nazionale. Non è lo stesso del porto d'armi: uno dice
    -- che puoi portarla, l'altro che sai usarla.
    richiedeCertificatoTSN = true,
    gravitaOstativa = 3,          -- un reato di questa gravità nel casellario blocca
    -- Durata del decreto, in minuti
    validitaMinuti = 480,
    -- Tassa di concessione
    costo = 120000,
}

-- ---------------------------------------------------------------------------
--  Piantonamento
--
--  La guardia sta davanti a un esercizio. Finché è lì e in servizio,
--  l'allarme di quell'esercizio parte prima.
-- ---------------------------------------------------------------------------
SIC.Piantonamento = {
    -- Raggio entro cui la guardia si considera sul posto
    raggio = 25.0,
    -- Quanto si accorcia il tempo d'allarme, in quota
    riduzioneAllarme = 0.55,
    -- Compenso a turno concluso
    compensoPerTurno = 42000,
    minutiPerTurno = 12,
    -- Quante guardie contano su uno stesso obiettivo
    massimePerObiettivo = 2,

    -- Indennità per chi piantona un obiettivo rimasto senza linea
    -- d'allarme. Quando salta la corrente la centrale operativa non vede
    -- più niente di quel punto: l'unico presidio che resta è una persona
    -- lì davanti, e si paga di conseguenza.
    indennitaSenzaLinea = 0.60,
}

SIC.Obiettivi = {
    { id = 'banca_centrale', nome = 'Filiale centrale',      coord = vector3(149.2, -1040.6, 29.4) },
    { id = 'banca_vespucci', nome = 'Filiale di Vespucci',   coord = vector3(-1212.8, -335.4, 37.8) },
    { id = 'gioielleria',    nome = 'Gioielleria del centro', coord = vector3(-630.4, -236.6, 38.1) },
    { id = 'ufficio_postale',nome = 'Ufficio postale',       coord = vector3(-262.4, -1046.2, 31.2) },
    { id = 'supermercato',   nome = 'Supermercato di Strawberry', coord = vector3(28.6, -1339.4, 29.5) },
}

function SIC.GetObiettivo(id)
    for _, o in ipairs(SIC.Obiettivi) do
        if o.id == id then return o end
    end
end

-- ---------------------------------------------------------------------------
--  Portavalori
--
--  Il servizio si prende all'istituto, si carica alla filiale di partenza
--  e si scarica a quella d'arrivo. Il valore è noto a tutti: è quello che
--  rende il furgone un obiettivo.
-- ---------------------------------------------------------------------------
SIC.Portavalori = {
    -- Il veicolo del servizio
    modello = 'stockade',
    -- Il valore trasportato, estratto fra questi due
    valoreMinimo = 8000000,       -- 80.000 €
    valoreMassimo = 25000000,     -- 250.000 €
    -- Quota al vigilante sulla consegna
    compenso = 0.035,
    -- Quanti servizi contemporanei
    contemporanei = 2,
    -- Tempo massimo per la consegna, in minuti
    limiteMinuti = 20,
    -- Il furgone si vede: la segnalazione parte dopo il carico
    secondiPrimaDellAvviso = 25,
    -- Quanto contante si trova a bordo se il furgone viene aperto a forza
    quotaRapinabile = 0.70,
    -- Serve un tempo di scasso davanti al portellone
    secondiScasso = 45,
}

SIC.Filiali = {
    { id = 'centrale', nome = 'Filiale centrale',    coord = vector3(147.8, -1046.2, 29.4) },
    { id = 'vespucci', nome = 'Filiale di Vespucci', coord = vector3(-1208.4, -330.2, 37.8) },
    { id = 'rockford', nome = 'Filiale di Rockford', coord = vector3(-2960.6, 482.4, 15.7) },
    { id = 'paleto',   nome = 'Filiale di Paleto',   coord = vector3(-104.2, 6462.8, 31.6) },
    { id = 'sandy',    nome = 'Filiale di Sandy',    coord = vector3(1175.4, 2706.8, 38.1) },
}

function SIC.GetFiliale(id)
    for _, f in ipairs(SIC.Filiali) do
        if f.id == id then return f end
    end
end

-- ---------------------------------------------------------------------------
--  Il porto d'armi in servizio
--
--  La guardia giurata porta l'arma solo mentre è in servizio. Fuori
--  servizio è un cittadino con un'arma addosso, e vale l'art. 699 c.p.
-- ---------------------------------------------------------------------------
SIC.Arma = {
    soloInServizio = true,
    reatoFuoriServizio = '699',
}
