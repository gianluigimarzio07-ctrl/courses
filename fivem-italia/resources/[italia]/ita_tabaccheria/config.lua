--[[
    AUREA · Tabaccheria (configurazione)

    IL MONOPOLIO

    Una tabaccheria in Italia non è un negozio: è un pezzo di Stato dato
    in concessione. Il tabaccaio non vende roba sua — riscuote per conto
    dello Stato e tiene una percentuale, che si chiama AGGIO.

    Da lì passano tre cose che il server già sfiorava e non chiudeva:

    · I SIGARETTE. L'oggetto `sigarette` esisteva già in item.lua con
      una descrizione che diceva "vendibili solo con licenza di
      monopolio", e non c'era nessun posto con quella licenza. Il
      contrabbando (ita_dogana) aveva un mercato nero e nessun mercato
      legale a cui contrapporsi.

    · IL GRATTA E VINCI. `biglietto_lotteria` aveva già il suo
      meccanismo di vincita in aurea_inventory, e non si poteva
      comprare da nessuna parte.

    · IL LOTTO. Questo è nuovo, ed è la cosa più italiana che ci sia:
      si giocano dei numeri su una ruota, si aspetta l'estrazione, e le
      quote sono quelle vere — 11,23 volte per l'estratto, 250 per
      l'ambo, 4.250 per il terno. Sembrano alte. Non lo sono: sono
      calcolate per far perdere, e la matematica è pubblica.

    E POI I VALORI BOLLATI

    La marca da bollo. Quella cosa che in Italia serve per fare le
    pratiche e che si compra solo dal tabaccaio. Qui serve davvero: il
    passaporto in Questura non si rilascia senza.

    È una dipendenza minuscola e volutamente fastidiosa, ed è il tipo di
    attrito che rende un server un posto invece di un menu.
]]

TAB = {}

TAB.Lavoro = 'tabaccaio'

TAB.Rivendite = {
    { codice = 'tab_centro',  nome = 'Tabaccheria del centro',
      coord = vector3(373.8, 327.2, 103.6), blip = { sprite = 51, colore = 5 } },
    { codice = 'tab_porto',   nome = 'Tabaccheria del porto',
      coord = vector3(-709.4, -913.6, 19.2), blip = { sprite = 51, colore = 5 } },
    { codice = 'tab_paleto',  nome = 'Tabaccheria di Paleto',
      coord = vector3(-160.4, 6320.8, 31.6), blip = { sprite = 51, colore = 5 } },
}

TAB.raggio = 2.4

function TAB.RivenditaVicina(coord)
    for _, r in ipairs(TAB.Rivendite) do
        if #(coord - r.coord) <= 8.0 then return r end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Il banco
-- ---------------------------------------------------------------------------
TAB.Banco = {
    { item = 'sigarette',          nome = 'Stecca di sigarette', prezzo = 6200, aggio = 0.10 },
    { item = 'biglietto_lotteria', nome = 'Gratta e vinci',      prezzo = 500,  aggio = 0.08 },
}

-- ---------------------------------------------------------------------------
--  Valori bollati
-- ---------------------------------------------------------------------------
TAB.Bolli = {
    { valore = 1600,  nome = 'Marca da bollo da 16,00 €' },
    { valore = 7350,  nome = 'Contrassegno per passaporto — 73,50 €' },
}

--- L'aggio del tabaccaio sui valori bollati. È minuscolo: lo Stato non
--- regala niente su una cosa che deve vendere per forza.
TAB.aggioBolli = 0.02

-- ---------------------------------------------------------------------------
--  Il Lotto
-- ---------------------------------------------------------------------------
TAB.Lotto = {
    ruote = { 'Bari', 'Cagliari', 'Firenze', 'Genova', 'Milano',
              'Napoli', 'Palermo', 'Roma', 'Torino', 'Venezia' },

    -- Ogni quanti minuti si estrae
    minutiEstrazione = 25,

    -- Cinque numeri da 1 a 90, per ruota
    numeriEstratti = 5,
    numeroMassimo = 90,

    giocataMinima = 100,
    giocataMassima = 200000,

    -- Le quote vere del Lotto italiano, al netto della ritenuta.
    -- Quella dell'ambo sembra generosa e non lo è: la probabilità di
    -- fare ambo con due numeri su una ruota è una su 400,5.
    sorti = {
        estratto  = { numeri = 1, quota = 11.23,   nome = 'Estratto' },
        ambo      = { numeri = 2, quota = 250.0,   nome = 'Ambo' },
        terno     = { numeri = 3, quota = 4250.0,  nome = 'Terno' },
        quaterna  = { numeri = 4, quota = 80000.0, nome = 'Quaterna' },
        cinquina  = { numeri = 5, quota = 1000000.0, nome = 'Cinquina' },
    },

    -- La ritenuta sulle vincite: in Italia è l'8%, e si chiama prelievo
    -- sulle vincite. Lo Stato vince sempre due volte.
    ritenuta = 0.08,

    -- Quota della giocata che resta al tabaccaio
    aggio = 0.08,
}

function TAB.GetSorte(id) return TAB.Lotto.sorti[id] end

--- Quanti numeri giocati sono usciti.
function TAB.Indovinati(giocati, estratti)
    local usciti = {}
    for _, n in ipairs(estratti) do usciti[n] = true end

    local quanti = 0
    for _, n in ipairs(giocati) do
        if usciti[n] then quanti = quanti + 1 end
    end
    return quanti
end
