--[[
    AUREA su ESX — configurazione

    Questa è la strada opposta a [esx]/es_extended.

    Là AUREA è il framework e ESX è la facciata. Qui è il vero es_extended
    a comandare — identità, denaro, lavoro — e AUREA gli si appoggia sopra
    per portare tutto il resto: codice della strada, fisco, giustizia,
    droga con la purezza, carcere, scientifica, i mestieri.

    SI USA UNA SOLA DELLE DUE. Sono alternative, non complementari.

    QUANDO SCEGLIERE QUESTA

    Quando hai già un server ESX in piedi con giocatori dentro, uno stack di
    script esx_* che non vuoi toccare e un database `users` che non vuoi
    migrare. Tieni tutto e ci aggiungi AUREA.

    QUANDO NON SCEGLIERLA

    Se parti da zero, usa l'altra: AUREA autoritativa lavora in centesimi
    interi e non perde niente, mentre qui i soldi restano quelli di ESX e
    sotto il centesimo si arrotonda per forza.

    COME FUNZIONA

    Il personaggio AUREA non nasce dalla selezione di aurea_core (che in
    questa modalità va spenta insieme ad aurea_spawn): nasce quando ESX
    emette esx:playerLoaded. A quel punto qui si cerca la riga `personaggi`
    legata a quell'identifier ESX e, se non c'è, la si crea al volo
    ricavando quello che si può da ESX e generando il resto — codice
    fiscale, telefono, IBAN — con l'anagrafe AUREA.

    Da quel momento il Giocatore AUREA e l'xPlayer ESX descrivono la stessa
    persona, e ogni movimento di denaro o cambio di lavoro fatto da una
    parte si riflette sull'altra.
]]

AEC = {}

-- ---------------------------------------------------------------------------
--  Quale dato comanda
--
--  Su ogni campo condiviso uno dei due deve avere l'ultima parola,
--  altrimenti si rincorrono. Qui è scritto quale.
-- ---------------------------------------------------------------------------
AEC.Autorita = {
    -- Il denaro sta in ESX: AUREA legge e scrive lì.
    denaro = 'esx',
    -- Il lavoro sta in ESX: i lavori AUREA vanno caricati nelle tabelle
    -- jobs e job_grades di ESX con sql/esx/01_lavori.sql.
    lavoro = 'esx',
    -- L'identità anagrafica è di AUREA: ESX non ha codice fiscale, luogo
    -- di nascita, patente a punti né telefono in quel formato.
    anagrafe = 'aurea',
    -- L'inventario resta di AUREA, perché senza metadata per istanza
    -- cadono purezza, matricole, reperti e documenti.
    inventario = 'aurea',
}

-- ---------------------------------------------------------------------------
--  Conti
-- ---------------------------------------------------------------------------
AEC.Conti = {
    contanti = 'money',
    banca    = 'bank',
}

--- Il nero ESX (black_money) verso l'oggetto AUREA.
AEC.Nero = {
    oggetto = 'contanti_sporchi',
    valoreUnita = 10000,   -- centesimi per banconota
    -- Se true, all'ingresso il black_money ESX viene convertito una volta
    -- sola in banconote AUREA e azzerato su ESX, così il nero smette di
    -- esistere in due posti. Consigliato.
    convertiAllIngresso = true,
}

-- ---------------------------------------------------------------------------
--  Creazione del personaggio AUREA al primo accesso
-- ---------------------------------------------------------------------------
AEC.PrimoAccesso = {
    -- Se ESX ha già nome e cognome, si usano quelli. Se non li ha, si
    -- prende il nome Steam e si spezza; se non basta, questi.
    nomeRipiego = 'Mario',
    cognomeRipiego = 'Rossi',

    -- Data di nascita se ESX non ce l'ha
    nascitaRipiego = '1995-06-15',
    comuneRipiego = 'Roma',

    -- Il corredo iniziale AUREA (documenti, telefono) si consegna anche a
    -- chi arriva da ESX: senza carta d'identità mezzo server non funziona.
    consegnaCorredo = true,

    -- Apre il conto corrente AUREA con l'IBAN. Il saldo iniziale è quello
    -- che il giocatore ha già in banca su ESX, non un regalo.
    apriConto = true,
}

-- ---------------------------------------------------------------------------
--  Sincronizzazione continua
-- ---------------------------------------------------------------------------
AEC.Sincronia = {
    -- Ogni quanti secondi si rilegge il denaro da ESX. Serve perché uno
    -- script esx_* può cambiarlo senza passare da noi e senza emettere
    -- nulla che possiamo ascoltare.
    secondiDenaro = 10,

    -- Il lavoro invece arriva sempre con l'evento esx:setJob, quindi non
    -- serve interrogarlo a intervalli.
    -- Salvataggio del Giocatore AUREA (posizione, stato, metadata).
    secondiSalvataggio = 300,
}

-- ---------------------------------------------------------------------------
--  Risorse AUREA da spegnere in questa modalità
--
--  Non le spegne il codice: le spegni tu in server.cfg. Sono elencate qui
--  perché è l'unico posto in cui uno va a cercarle.
--
--    aurea_spawn        la selezione personaggio la fa ESX
--    aurea_caricamento  se usi già una loadscreen ESX
--
--  E in aurea_core/shared/config.lua metti C.Framework = 'esx'.
-- ---------------------------------------------------------------------------
AEC.DaSpegnere = { 'aurea_spawn' }

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function AEC.AEuro(centesimi)
    return math.floor((tonumber(centesimi) or 0)) / 100
end

function AEC.ACentesimi(euro)
    local n = tonumber(euro) or 0
    return math.floor(n * 100 + (n >= 0 and 0.5 or -0.5))
end
