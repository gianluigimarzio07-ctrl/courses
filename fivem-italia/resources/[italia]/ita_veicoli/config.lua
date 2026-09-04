--[[
    AUREA · Veicoli — configurazione

    Un veicolo in Italia costa anche dopo l'acquisto: bollo, RCA e revisione
    hanno scadenze reali e conseguenze reali (sanzione, fermo, sequestro).
]]

VEI = {}

-- ---------------------------------------------------------------------------
--  Classi ambientali: incidono su bollo e accesso alle ZTL
-- ---------------------------------------------------------------------------
VEI.ClassiAmbientali = {
    ['Euro 0'] = { moltiplicatoreBollo = 1.60, ztlVietata = true },
    ['Euro 3'] = { moltiplicatoreBollo = 1.30, ztlVietata = true },
    ['Euro 4'] = { moltiplicatoreBollo = 1.10, ztlVietata = false },
    ['Euro 5'] = { moltiplicatoreBollo = 1.00, ztlVietata = false },
    ['Euro 6'] = { moltiplicatoreBollo = 0.95, ztlVietata = false },
    ['Elettrico'] = { moltiplicatoreBollo = 0.00, ztlVietata = false, esenzioneAnni = 5 },
}

-- ---------------------------------------------------------------------------
--  Bollo auto: calcolato sui kW come nella realtà
--  Tariffa per kW fino a 100, poi tariffa maggiorata (superbollo di fatto).
-- ---------------------------------------------------------------------------
VEI.Bollo = {
    tariffaBase   = 290,     -- 2,90 € per kW fino a 100 kW
    tariffaOltre  = 435,     -- 4,35 € per kW oltre i 100
    minimo        = 5000,    -- 50,00 €
    validitaGiorni = 365,
    -- Mora per pagamento tardivo
    moraPercentuale = 0.30,
    -- Dopo quanti giorni di mancato pagamento scatta il fermo amministrativo
    giorniFermo   = 90,
}

-- ---------------------------------------------------------------------------
--  Assicurazione RC Auto
-- ---------------------------------------------------------------------------
VEI.Assicurazione = {
    tipi = {
        rca = {
            etichetta = 'RC Auto',
            descrizione = 'Copre i danni causati a terzi. Obbligatoria per circolare.',
            premioBase = 42000,          -- 420,00 € annui
            rimborsoDanni = 0.0,
        },
        kasko = {
            etichetta = 'Kasko',
            descrizione = 'Copre anche i danni al tuo veicolo, furto e incendio.',
            premioBase = 118000,         -- 1.180,00 €
            rimborsoDanni = 0.70,        -- rimborso del 70% sulle riparazioni
            rimborsoFurto = 0.60,
        },
    },
    validitaGiorni = 365,
    -- Classe di merito: chi non causa sinistri paga meno
    bonusMalus = {
        [1] = 0.55, [2] = 0.65, [3] = 0.75, [4] = 0.85, [5] = 0.95,
        [6] = 1.00,  -- classe di ingresso
        [7] = 1.20, [8] = 1.45, [9] = 1.75, [10] = 2.10, [11] = 2.60,
    },
    classeIngresso = 6,
    -- Sinistri e anni senza sinistri fanno salire o scendere di una classe
    minutiPerClasse = 900,
}

-- ---------------------------------------------------------------------------
--  Revisione periodica
-- ---------------------------------------------------------------------------
VEI.Revisione = {
    costo = 7900,               -- 79,00 €
    primaRevisioneGiorni = 1460,-- 4 anni dall'immatricolazione
    intervalloGiorni = 730,     -- poi ogni 2 anni
    -- Con motore o carrozzeria sotto queste soglie la revisione non passa
    sogliaMotore = 600,
    sogliaCarrozzeria = 500,
    duratsCollaudo = 12000,     -- ms
}

-- ---------------------------------------------------------------------------
--  Concessionarie
-- ---------------------------------------------------------------------------
VEI.Concessionarie = {
    {
        id = 'auto_nuove',
        nome = 'Concessionaria Auto',
        coord = vector3(-56.5, -1096.7, 26.4),
        anteprima = vector4(-47.4, -1097.3, 26.4, 300.0),
        blip = { sprite = 326, colore = 3, scala = 0.8 },
        categorie = { 'utilitaria', 'berlina', 'suv', 'sportiva' },
    },
    {
        id = 'moto',
        nome = 'Concessionaria Moto',
        coord = vector3(285.9, -1150.6, 29.3),
        anteprima = vector4(291.2, -1152.9, 29.3, 90.0),
        blip = { sprite = 226, colore = 3, scala = 0.75 },
        categorie = { 'moto' },
    },
    {
        id = 'commerciali',
        nome = 'Veicoli Commerciali',
        coord = vector3(1234.5, -3255.0, 6.0),
        anteprima = vector4(1229.0, -3260.3, 6.0, 180.0),
        blip = { sprite = 477, colore = 3, scala = 0.75 },
        categorie = { 'furgone', 'camion' },
    },
}

-- ---------------------------------------------------------------------------
--  Catalogo veicoli in vendita
--  kw serve per il bollo, prezzo in centesimi.
-- ---------------------------------------------------------------------------
VEI.Catalogo = {
    -- Utilitarie
    { modello = 'blista',   nome = 'Dinka Blista',      categoria = 'utilitaria', prezzo = 950000,   kw = 74,  classe = 'Euro 6' },
    { modello = 'panto',    nome = 'Benefactor Panto',  categoria = 'utilitaria', prezzo = 720000,   kw = 55,  classe = 'Euro 6' },
    { modello = 'issi2',    nome = 'Weeny Issi',        categoria = 'utilitaria', prezzo = 1180000,  kw = 85,  classe = 'Euro 6' },
    { modello = 'prairie',  nome = 'Bollokan Prairie',  categoria = 'utilitaria', prezzo = 1050000,  kw = 80,  classe = 'Euro 5' },
    -- Berline
    { modello = 'asea',     nome = 'Declasse Asea',     categoria = 'berlina',    prezzo = 1450000,  kw = 96,  classe = 'Euro 5' },
    { modello = 'primo2',   nome = 'Albany Primo',      categoria = 'berlina',    prezzo = 1980000,  kw = 118, classe = 'Euro 5' },
    { modello = 'fugitive', nome = 'Cheval Fugitive',   categoria = 'berlina',    prezzo = 2650000,  kw = 132, classe = 'Euro 6' },
    { modello = 'schafter2',nome = 'Benefactor Schafter',categoria = 'berlina',   prezzo = 4200000,  kw = 165, classe = 'Euro 6' },
    -- SUV
    { modello = 'baller',   nome = 'Gallivanter Baller',categoria = 'suv',        prezzo = 5400000,  kw = 190, classe = 'Euro 6' },
    { modello = 'granger',  nome = 'Declasse Granger',  categoria = 'suv',        prezzo = 4800000,  kw = 205, classe = 'Euro 5' },
    { modello = 'xls',      nome = 'Benefactor XLS',    categoria = 'suv',        prezzo = 6900000,  kw = 220, classe = 'Euro 6' },
    -- Sportive
    { modello = 'sultan',   nome = 'Karin Sultan',      categoria = 'sportiva',   prezzo = 3800000,  kw = 186, classe = 'Euro 5' },
    { modello = 'comet2',   nome = 'Pfister Comet',     categoria = 'sportiva',   prezzo = 9500000,  kw = 280, classe = 'Euro 6' },
    { modello = 'italigtb', nome = 'Progen Itali GTB',  categoria = 'sportiva',   prezzo = 24500000, kw = 400, classe = 'Euro 6' },
    { modello = 'neon',     nome = 'Pfister Neon',      categoria = 'sportiva',   prezzo = 12800000, kw = 320, classe = 'Elettrico' },
    -- Moto
    { modello = 'faggio2',  nome = 'Pegassi Faggio',    categoria = 'moto',       prezzo = 320000,   kw = 8,   classe = 'Euro 5' },
    { modello = 'bati',     nome = 'Pegassi Bati 801',  categoria = 'moto',       prezzo = 2100000,  kw = 110, classe = 'Euro 6' },
    { modello = 'akuma',    nome = 'Dinka Akuma',       categoria = 'moto',       prezzo = 1750000,  kw = 95,  classe = 'Euro 5' },
    -- Commerciali
    { modello = 'burrito3', nome = 'Declasse Burrito',  categoria = 'furgone',    prezzo = 2200000,  kw = 110, classe = 'Euro 4' },
    { modello = 'rumpo',    nome = 'Bravado Rumpo',     categoria = 'furgone',    prezzo = 2450000,  kw = 118, classe = 'Euro 5' },
    { modello = 'mule',     nome = 'Maibatsu Mule',     categoria = 'camion',     prezzo = 4200000,  kw = 175, classe = 'Euro 4' },
    { modello = 'pounder',  nome = 'MTL Pounder',       categoria = 'camion',     prezzo = 7800000,  kw = 240, classe = 'Euro 4' },
}

-- ---------------------------------------------------------------------------
--  Centri revisione e agenzie assicurative
-- ---------------------------------------------------------------------------
VEI.CentriRevisione = {
    { nome = 'Centro Revisioni Innocence', coord = vector3(-337.3, -136.6, 39.0) },
    { nome = 'Centro Revisioni Sandy',     coord = vector3(1175.0, 2640.2, 37.8) },
}

VEI.Assicurazioni = {
    { nome = 'Agenzia Assicurativa Centro', coord = vector3(-30.5, -613.2, 36.1) },
}

-- ---------------------------------------------------------------------------
--  Depositeria giudiziaria: dove finiscono i veicoli sequestrati
-- ---------------------------------------------------------------------------
VEI.Depositeria = {
    nome = 'Depositeria Giudiziaria',
    coord = vector3(409.0, -1622.9, 29.3),
    ritiro = vector4(400.6, -1631.4, 29.3, 230.0),
    -- costo di custodia per giorno di permanenza
    custodiaGiornaliera = 3500,
    dissequestroBase = 15000,
}

-- ---------------------------------------------------------------------------
--  Calcolo del bollo per un veicolo
-- ---------------------------------------------------------------------------
function VEI.CalcolaBollo(kw, classe)
    local c = VEI.ClassiAmbientali[classe] or VEI.ClassiAmbientali['Euro 5']
    if c.moltiplicatoreBollo == 0 then return 0 end

    local base
    if kw <= 100 then
        base = kw * VEI.Bollo.tariffaBase
    else
        base = (100 * VEI.Bollo.tariffaBase) + ((kw - 100) * VEI.Bollo.tariffaOltre)
    end

    return math.max(VEI.Bollo.minimo, math.floor(base * c.moltiplicatoreBollo))
end

--- Premio assicurativo dato tipo, potenza e classe di merito.
function VEI.CalcolaPremio(tipo, kw, classeMerito)
    local t = VEI.Assicurazione.tipi[tipo]
    if not t then return 0 end
    local coefficiente = VEI.Assicurazione.bonusMalus[classeMerito or VEI.Assicurazione.classeIngresso] or 1.0
    local potenza = 1.0 + math.max(0, (kw - 90)) / 400
    return math.floor(t.premioBase * coefficiente * potenza)
end

function VEI.GetVeicoloCatalogo(modello)
    for _, v in ipairs(VEI.Catalogo) do
        if v.modello == modello then return v end
    end
    return nil
end
