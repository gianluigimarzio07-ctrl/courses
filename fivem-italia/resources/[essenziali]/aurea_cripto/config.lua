--[[
    AUREA · Criptovalute — configurazione

    Il server aveva già il riciclaggio (ita_famiglie), l'antiriciclaggio in
    banca, la Guardia di Finanza con vent'anni di codice attorno e i
    contanti non tracciati come oggetto fisico. Mancava il passaggio che
    nella realtà collega tutte queste cose, ed è quello che rende il gioco
    interessante: un posto dove il denaro sporco si trasforma in qualcosa
    che si muove da solo.

    COME SI RICICLA QUI

    L'exchange compra criptovaluta anche in contanti non tracciati. Lo fa a
    un cambio peggiore — la differenza è il prezzo del silenzio — e senza
    chiedere niente. Da lì in poi quella somma non è più una mazzetta in
    tasca: è un saldo che si può rivendere in euro puliti.

    Ma lascia una traccia. Ogni operazione finisce nel registro, e la
    Guardia di Finanza può leggerlo. Non vede il nome dietro il portafoglio
    finché non lo chiede a un giudice; vede però i movimenti, e i movimenti
    parlano. Chi ricicla in fretta e a cifre tonde si fa notare.

    IL PREZZO SI MUOVE DA SOLO

    Non è un moltiplicatore fisso: è una passeggiata aleatoria con eventi.
    Comprare al momento sbagliato fa perdere soldi anche a chi ha fatto
    tutto giusto, e questo è voluto. Il riciclaggio deve avere un rischio,
    e qui il rischio non è solo la Finanza: è anche il mercato.

    Il prezzo lo calcola il server e lo pubblica. Il client non lo tocca,
    non lo prevede e non lo può anticipare.
]]

CRP = {}

CRP.LavoriControllo = { 'guardia_finanza' }

-- ---------------------------------------------------------------------------
--  Le monete
--
--  volatilita: quanto oscilla per tick, in percentuale
--  deriva:     tendenza di fondo per tick (positiva o negativa)
--  minimo/massimo: le sponde, così nessuna moneta va a zero né alle stelle
-- ---------------------------------------------------------------------------
CRP.Monete = {
    {
        id = 'aur', nome = 'Aurum', simbolo = 'AUR',
        descrizione = 'La più vecchia e la più tranquilla. Si muove poco e si muove tardi.',
        iniziale = 4200000,          -- 42.000,00 € in centesimi
        volatilita = 2.2, deriva = 0.05,
        minimo = 1500000, massimo = 12000000,
        accettaNero = true, scontoNero = 0.72,
    },
    {
        id = 'vlt', nome = 'Volta', simbolo = 'VLT',
        descrizione = 'Nata per i pagamenti veloci. Oscilla parecchio, e chi la usa lo sa.',
        iniziale = 128000,           -- 1.280,00 €
        volatilita = 5.8, deriva = 0.0,
        minimo = 30000, massimo = 900000,
        accettaNero = true, scontoNero = 0.68,
    },
    {
        id = 'nbl', nome = 'Nebula', simbolo = 'NBL',
        descrizione = 'Anonima per progetto. Nessuno sa chi la emette, e infatti la Finanza la guarda.',
        iniziale = 31000,            -- 310,00 €
        volatilita = 11.0, deriva = -0.08,
        minimo = 2000, massimo = 400000,
        accettaNero = true, scontoNero = 0.85,
        -- Le operazioni su questa moneta finiscono sempre in segnalazione
        sempreSegnalata = true,
    },
    {
        id = 'stb', nome = 'Stabile', simbolo = 'STB',
        descrizione = 'Ancorata all\'euro. Non fa guadagnare, ma non fa nemmeno perdere.',
        iniziale = 100000,           -- 1.000,00 €
        volatilita = 0.3, deriva = 0.0,
        minimo = 96000, massimo = 104000,
        accettaNero = false,
    },
}

-- ---------------------------------------------------------------------------
--  Il mercato
-- ---------------------------------------------------------------------------
CRP.Mercato = {
    -- Ogni quanti secondi si ricalcolano i prezzi
    secondiTick = 45,
    -- Quante quotazioni si tengono per il grafico
    storicoPunti = 40,

    -- Commissione dell'exchange su ogni operazione, in millesimi
    commissione = 15,        -- 1,5%

    -- Ogni tanto succede qualcosa che muove tutto insieme
    eventi = {
        { nome = 'Stretta regolamentare annunciata', effetto = -0.18, probabilita = 4 },
        { nome = 'Adozione da parte di un grande esercente', effetto = 0.15, probabilita = 4 },
        { nome = 'Violazione di un exchange estero', effetto = -0.25, probabilita = 2 },
        { nome = 'Afflusso di capitali istituzionali', effetto = 0.22, probabilita = 3 },
        { nome = 'Sequestro di portafogli da parte dell\'autorità', effetto = -0.12, probabilita = 3 },
    },
}

-- ---------------------------------------------------------------------------
--  Exchange
-- ---------------------------------------------------------------------------
CRP.Exchange = {
    nome = 'Exchange — sportello fisico',
    -- Lo sportello fisico serve per il nero: il contante non passa da
    -- un'app, deve passare da un bancone.
    coord = vector3(-1573.2, -546.3, 34.9),
    raggio = 3.0,
    blip = { sprite = 617, colore = 46, scala = 0.75 },

    -- Dal telefono si opera solo in euro tracciati
    daTelefono = true,
    -- Limite di una singola operazione in nero, in centesimi
    massimoNeroPerOperazione = 5000000,   -- 50.000 €
}

-- ---------------------------------------------------------------------------
--  Antiriciclaggio
--
--  Non è un dado: sono soglie. Chi le conosce può starci sotto, e starci
--  sotto costa tempo. È esattamente il compromesso che si vuole.
-- ---------------------------------------------------------------------------
CRP.Antiriciclaggio = {
    -- Sopra questa cifra in una sola operazione parte la segnalazione
    sogliaOperazione = 1500000,          -- 15.000 €
    -- Sopra questa cifra nell'arco di un'ora, idem
    sogliaOraria = 4000000,              -- 40.000 €
    -- Le operazioni in nero fanno sempre più rumore
    moltiplicatoreNero = 2.0,

    -- Il "punteggio di attenzione" del portafoglio: sopra questo la
    -- Guardia di Finanza lo vede in cima all'elenco
    sogliaAttenzione = 100,
    puntiPerSegnalazione = 25,
    -- Decadono col tempo: chi si ferma torna pulito
    decadimentoOrario = 8,

    reato = '648b',
}

-- ---------------------------------------------------------------------------
--  Sequestro
-- ---------------------------------------------------------------------------
CRP.Sequestro = {
    -- Chi può disporlo
    gradoMinimo = 2,
    -- Il saldo sequestrato va all'erario
    voceErario = 'sequestri',
    -- Serve un fascicolo aperto: non si sequestra a sensazione
    richiedeFascicolo = true,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function CRP.GetMoneta(id)
    for _, m in ipairs(CRP.Monete) do
        if m.id == id then return m end
    end
    return nil
end

--- Il valore in centesimi di una quantità, dato il prezzo unitario.
--- Le quantità si tengono in millesimi di moneta per non perdere spiccioli
--- su monete che valgono decine di migliaia di euro l'una.
function CRP.Controvalore(millesimi, prezzo)
    return math.floor((millesimi * prezzo) / 1000)
end

function CRP.Millesimi(centesimi, prezzo)
    if prezzo <= 0 then return 0 end
    return math.floor((centesimi * 1000) / prezzo)
end

--- Quantità leggibile: 1500 millesimi -> "1,500"
function CRP.FormattaQuantita(millesimi)
    return ('%d,%03d'):format(math.floor(millesimi / 1000), millesimi % 1000)
end
