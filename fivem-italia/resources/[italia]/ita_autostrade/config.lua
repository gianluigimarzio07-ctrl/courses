--[[
    AUREA · Autostrade (configurazione)

    IL PEDAGGIO

    In Italia l'autostrada si paga, e si paga in un modo particolare: non
    all'ingresso e non a forfait, ma sulla DISTANZA fra il casello dove
    sei entrato e quello dove esci. Per saperlo, il sistema si ricorda di
    te: prendi un biglietto entrando, lo consegni uscendo.

    Il che significa che il conto lo può fare solo chi ha visto entrambi i
    passaggi — e infatti qui il transito è una riga nel database aperta al
    casello d'ingresso e chiusa a quello d'uscita.

    TRE MODI DI USCIRE

    · PAGHI. Fine.
    · HAI IL TELEPASS, e passi senza fermarti. Costa un canone e ti
      addebita dopo; se il conto è vuoto l'addebito resta insoluto.
    · FORZI LA SBARRA. È l'art. 176 CdS, e non è un furto da poco: è una
      violazione del codice della strada con verbale, e il pedaggio resta
      dovuto comunque.

    E QUELLO CHE NON PAGHI

    Il pedaggio insoluto non svanisce. La concessionaria lo mette a ruolo,
    e a quel punto non è più un debito con un'azienda: è una cartella, con
    tutto quello che ne segue — fermo del veicolo compreso.

    È il motivo per cui questa risorsa e ita_riscossione si parlano.
]]

AUT = {}

AUT.Lavoro = 'autostrade'

-- ---------------------------------------------------------------------------
--  I caselli
--
--  Le distanze sono in chilometri fittizi lungo la rete: servono a
--  calcolare il pedaggio, non a descrivere la mappa.
-- ---------------------------------------------------------------------------
AUT.Caselli = {
    { id = 'sud',     nome = 'Casello sud',       coord = vector3(-30.4, -2570.0, 6.0),  km = 0,   blip = { sprite = 522, colore = 3 } },
    { id = 'centro',  nome = 'Casello centro',    coord = vector3(88.0, -1290.0, 29.2),  km = 18,  blip = { sprite = 522, colore = 3 } },
    { id = 'ovest',   nome = 'Casello ovest',     coord = vector3(-1560.0, -430.0, 35.0), km = 41, blip = { sprite = 522, colore = 3 } },
    { id = 'harmony', nome = 'Casello Harmony',   coord = vector3(1180.0, 2660.0, 37.8), km = 96,  blip = { sprite = 522, colore = 3 } },
    { id = 'nord',    nome = 'Casello nord',      coord = vector3(1700.0, 4900.0, 42.0), km = 138, blip = { sprite = 522, colore = 3 } },
}

AUT.raggioCasello = 12.0

function AUT.GetCasello(id)
    for _, c in ipairs(AUT.Caselli) do
        if c.id == id then return c end
    end
    return nil
end

function AUT.CaselloVicino(coord)
    for _, c in ipairs(AUT.Caselli) do
        if #(coord - c.coord) <= AUT.raggioCasello then return c end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Le classi tariffarie
--
--  Quelle vere: A moto, B auto, e le classi pesanti per numero di assi.
-- ---------------------------------------------------------------------------
AUT.Classi = {
    A = { nome = 'Classe A — motocicli',       tariffa = 620,  categorie = { 'moto' } },
    B = { nome = 'Classe B — due assi',        tariffa = 820,  categorie = { 'auto', 'suv', 'sportiva' } },
    ['3'] = { nome = 'Classe 3 — tre assi',    tariffa = 1450, categorie = { 'furgone' } },
    ['5'] = { nome = 'Classe 5 — cinque assi', tariffa = 2380, categorie = { 'camion', 'autobus' } },
}

--- La classe tariffaria di un veicolo, dalla sua categoria.
function AUT.ClasseDi(categoria)
    for classe, dati in pairs(AUT.Classi) do
        for _, c in ipairs(dati.categorie) do
            if c == categoria then return classe end
        end
    end
    return 'B'
end

--- Il pedaggio: tariffa al chilometro per la distanza fra i due caselli,
--- più l'importo fisso di esazione.
function AUT.Pedaggio(classe, km)
    local dati = AUT.Classi[classe] or AUT.Classi.B
    return math.max(AUT.Regole.minimo, math.floor((dati.tariffa / 10) * math.abs(km)) + AUT.Regole.esazione)
end

AUT.Regole = {
    -- Quota fissa per l'esazione
    esazione = 180,
    -- Nessun pedaggio è più basso di così
    minimo = 900,

    -- Entrare e uscire dallo stesso casello: si paga la tratta minima,
    -- non zero. In Italia si chiama "pedaggio forfetario" e serve
    -- esattamente a evitare il giochetto.
    kmMinimiFatturati = 6,

    -- Un transito aperto da troppo tempo si chiude d'ufficio alla
    -- tariffa massima: è quello che succede se perdi il biglietto.
    minutiTransitoMassimo = 40,
    kmBigliettoPerduto = 138,

    -- Art. 176 c. 11 CdS: mancato pagamento del pedaggio
    infrazione = '176',
}

-- ---------------------------------------------------------------------------
--  Telepass
-- ---------------------------------------------------------------------------
AUT.Telepass = {
    canoneAttivazione = 24000,
    -- Sconto sul pedaggio: il telepass conviene, ed è il motivo per cui
    -- ce l'hanno tutti.
    sconto = 0.05,
    -- Oltre questo insoluto l'apparato si disattiva
    insolutoMassimo = 300000,
}

-- ---------------------------------------------------------------------------
--  Insoluti e ruolo
-- ---------------------------------------------------------------------------
AUT.Insoluti = {
    -- Ogni quanti minuti la concessionaria guarda chi non ha pagato
    minutiScansione = 10,
    -- Minuti dopo i quali un insoluto va a ruolo
    minutiPrimaDelRuolo = 25,
    -- Sotto questa cifra non si mette a ruolo niente: costerebbe più
    -- la cartella del debito.
    sogliaRuolo = 3000,
}
