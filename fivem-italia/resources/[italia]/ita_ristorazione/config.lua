--[[
    AUREA · Ristorazione — configurazione

    Un bar e una pizzeria che funzionano come funzionano davvero: qualcuno
    in cucina che prepara, qualcuno in sala che prende l'ordine e serve, e
    il cliente che si siede e aspetta. Non è un distributore automatico.

    Chi mangia un piatto fatto da un giocatore ricava molto più di chi
    compra la stessa cosa in negozio: è quello che rende il lavoro sensato.
]]

RIS = {}

RIS.Locali = {
    {
        id = 'bar', nome = 'Bar Centrale', lavoro = 'barista',
        banco = vector3(-1193.0, -898.0, 14.0),
        cucina = vector3(-1198.0, -894.0, 14.0),
        cassa = vector3(-1190.0, -899.0, 14.0),
        tavoli = {
            vector3(-1186.0, -894.0, 13.9), vector3(-1183.0, -890.0, 13.9),
            vector3(-1180.0, -886.0, 13.9),
        },
        blip = { sprite = 93, colore = 5, scala = 0.7 },
    },
    {
        id = 'pizzeria', nome = 'Pizzeria da Gennaro', lavoro = 'cuoco',
        banco = vector3(-1483.0, -651.0, 30.0),
        cucina = vector3(-1487.0, -646.0, 30.0),
        cassa = vector3(-1480.0, -652.0, 30.0),
        tavoli = {
            vector3(-1476.0, -646.0, 29.9), vector3(-1472.0, -642.0, 29.9),
        },
        blip = { sprite = 267, colore = 5, scala = 0.7 },
    },
}

--- Le ricette. Ogni piatto ha ingredienti veri, presi dalle filiere.
RIS.Ricette = {
    espresso = {
        nome = 'Caffè', locale = 'bar', icona = '☕',
        ingredienti = { { item = 'caffe_crudo', quantita = 1 } },
        durata = 6000, prezzo = 1200,
        effetto = { sete = 6, stress = -10 },
    },
    cappuccino = {
        nome = 'Cappuccino', locale = 'bar', icona = '☕',
        ingredienti = { { item = 'caffe_crudo', quantita = 1 }, { item = 'latte_crudo', quantita = 1 } },
        durata = 9000, prezzo = 1800,
        effetto = { fame = 8, sete = 12, stress = -12 },
    },
    cornetto = {
        nome = 'Cornetto', locale = 'bar', icona = '🥐',
        ingredienti = { { item = 'farina_00', quantita = 1 } },
        durata = 12000, prezzo = 1500,
        effetto = { fame = 18 },
    },
    panino = {
        nome = 'Panino', locale = 'bar', icona = '🥪',
        ingredienti = { { item = 'farina_00', quantita = 1 }, { item = 'prosciutto', quantita = 1 } },
        durata = 14000, prezzo = 4500,
        effetto = { fame = 32, sete = -4 },
    },
    pizza_margherita = {
        nome = 'Pizza margherita', locale = 'pizzeria', icona = '🍕',
        ingredienti = {
            { item = 'impasto_pizza', quantita = 1 },
            { item = 'pomodoro_san_marzano', quantita = 1 },
            { item = 'mozzarella_bufala', quantita = 1 },
        },
        durata = 25000, prezzo = 7500,
        effetto = { fame = 55, sete = -10 },
    },
    pizza_marinara = {
        nome = 'Pizza marinara', locale = 'pizzeria', icona = '🍕',
        ingredienti = {
            { item = 'impasto_pizza', quantita = 1 },
            { item = 'pomodoro_san_marzano', quantita = 1 },
        },
        durata = 20000, prezzo = 6000,
        effetto = { fame = 45, sete = -8 },
    },
    pasta_carbonara = {
        nome = 'Pasta alla carbonara', locale = 'pizzeria', icona = '🍝',
        ingredienti = {
            { item = 'pasta_secca', quantita = 1 },
            { item = 'pomodoro_san_marzano', quantita = 1 },
        },
        durata = 22000, prezzo = 6800,
        effetto = { fame = 50, sete = -6 },
    },
}

RIS.Servizio = {
    -- Un piatto preparato da un giocatore nutre più di uno comprato
    bonusFattoAMano = 1.4,
    -- Quanto resta al locale sull'incasso, il resto è ricavo del lavoratore
    quotaLocale = 0.35,
    -- Il piatto servito al tavolo vale di più
    bonusAlTavolo = 0.25,
    -- Distanza per servire
    distanzaServizio = 3.0,
    -- Un piatto si raffredda
    minutiPrimaDiRaffreddarsi = 8,
    penalitaFreddo = 0.5,
}

RIS.Comande = {
    -- Quante comande aperte insieme per locale
    massime = 8,
    -- Dopo quanti minuti una comanda non servita decade
    minutiScadenza = 15,
}

function RIS.GetLocale(id)
    for _, l in ipairs(RIS.Locali) do
        if l.id == id then return l end
    end
    return nil
end

function RIS.LocaleVicino(coord, raggio)
    for _, l in ipairs(RIS.Locali) do
        if #(coord - l.banco) < (raggio or 4.0) then return l end
    end
    return nil
end

function RIS.GetRicetta(id) return RIS.Ricette[id] end
