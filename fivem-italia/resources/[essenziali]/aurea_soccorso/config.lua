--[[
    AUREA · Soccorso stradale — configurazione

    Il carro attrezzi non è un pulsante che teletrasporta l'auto in garage:
    è un lavoro. Qualcuno chiama, qualcuno arriva, aggancia, traina e
    scarica in officina. E se nessuno risponde entro un po', il mezzo lo
    rimuove il carro comunale — a spese del proprietario, come nella vita.
]]

SOC = {}

SOC.Lavoro = 'meccanico'

SOC.Sede = {
    nome = 'Soccorso stradale',
    coord = vector3(-337.0, -136.0, 39.0),
    officina = vector3(-320.0, -130.0, 39.0),
    blip = { sprite = 446, colore = 47, scala = 0.8 },
    -- Dove compaiono i carri attrezzi di servizio
    mezzi = {
        vector4(-350.0, -119.0, 39.0, 70.0),
        vector4(-345.0, -114.0, 39.0, 70.0),
    },
    modello = 'flatbed',
}

SOC.Chiamata = {
    -- Quanto si paga al soccorritore per l'intervento
    tariffaBase = 38000,
    -- In più, per ogni chilometro di traino
    tariffaAlKm = 4200,
    -- Percentuale che resta all'officina
    quotaOfficina = 0.30,

    -- Se nessuno prende la chiamata entro questo tempo, interviene il carro
    -- comunale: costa di più e il mezzo finisce in depositeria
    minutiPrimaDellaRimozione = 8,
    costoRimozioneForzata = 145000,
    giorniInDepositeria = 2,
}

SOC.Traino = {
    -- Distanza massima per agganciare
    distanzaAggancio = 6.0,
    durataAggancio = 8000,
    durataSgancio = 5000,
    -- Il mezzo trainato non si guida: sta sul pianale
    altezzaPianale = 1.05,
}

--- Le riparazioni che il soccorritore può fare sul posto.
SOC.Interventi = {
    carburante = {
        nome = 'Rifornimento d\'emergenza', icona = '⛽',
        oggetto = 'tanica', durata = 12000, prezzo = 22000,
        effetto = 'carburante',
    },
    gomma = {
        nome = 'Sostituzione pneumatico', icona = '🛞',
        oggetto = 'kit_riparazione', durata = 20000, prezzo = 35000,
        effetto = 'gomme',
    },
    batteria = {
        nome = 'Avviamento con cavi', icona = '🔋',
        oggetto = 'cavi_avviamento', durata = 10000, prezzo = 18000,
        effetto = 'motore',
    },
    meccanica = {
        nome = 'Riparazione sul posto', icona = '🔧',
        oggetto = 'kit_riparazione', durata = 30000, prezzo = 62000,
        effetto = 'completo',
        -- Non rimette a nuovo: rimette in strada
        salutePercentuale = 0.65,
    },
}

function SOC.GetIntervento(id) return SOC.Interventi[id] end
