--[[
    AUREA · Sosta a pagamento — configurazione

    Le strisce blu. È la cosa più banalmente italiana che ci sia e nessun
    server la fa: parcheggi, paghi il grattino, e se scade passa
    l'ausiliario del traffico. Che è un lavoro vero, con uno stipendio,
    e non fa arrestare nessuno — fa solo arrabbiare tutti.
]]

SOS = {}

SOS.Lavoro = 'ausiliario'

--- Le zone a sosta regolamentata.
SOS.Zone = {
    { id = 'centro',   nome = 'Centro storico', coord = vector3(215.0, -800.0, 30.7),  raggio = 140.0, tariffaOraria = 20000 },
    { id = 'stazione', nome = 'Stazione',       coord = vector3(-260.0, -1000.0, 30.2), raggio = 120.0, tariffaOraria = 15000 },
    { id = 'mare',     nome = 'Lungomare',      coord = vector3(-1230.0, -1450.0, 4.4), raggio = 160.0, tariffaOraria = 12000 },
    { id = 'ospedale', nome = 'Zona ospedale',  coord = vector3(310.0, -580.0, 43.3),   raggio = 90.0,  tariffaOraria = 18000 },
}

SOS.Parcometri = {
    { zona = 'centro',   coord = vector3(228.0, -790.0, 30.6) },
    { zona = 'centro',   coord = vector3(180.0, -830.0, 31.0) },
    { zona = 'stazione', coord = vector3(-250.0, -990.0, 31.2) },
    { zona = 'mare',     coord = vector3(-1220.0, -1440.0, 4.4) },
    { zona = 'ospedale', coord = vector3(300.0, -575.0, 43.3) },
}

SOS.Tariffe = {
    -- Si paga a frazione di mezz'ora
    frazioneMinuti = 30,
    -- Massimo acquistabile in una volta
    oreMassime = 4,
    -- Fasce libere: la domenica e di notte non si paga
    orarioGratuito = { 20, 8 },
    giorniGratuiti = { 7 },       -- 7 = domenica
}

SOS.Sanzione = {
    -- Art. 7 comma 15 CdS — sosta senza esposizione del titolo
    articolo = 'art. 7 c.15 CdS',
    descrizione = 'Sosta in area a pagamento senza titolo valido',
    importo = 4200,
    -- Ogni quanto l'ausiliario può rimultare lo stesso veicolo
    minutiFraSanzioni = 60,
    -- Distanza per contestare
    distanza = 5.0,
    -- Quota che spetta all'ausiliario, il resto al Comune
    quotaAusiliario = 0.10,
}

SOS.Regole = {
    -- Il grattino è un oggetto: si espone sul cruscotto
    tagliando = 'tagliando_sosta',
    -- Chi ha il pass residenti non paga nella sua zona
    passResidenti = true,
    costoPass = 180000,
    validitaPassGiorni = 30,
}

function SOS.ZonaDi(coord)
    for _, z in ipairs(SOS.Zone) do
        if #(coord - z.coord) < z.raggio then return z end
    end
    return nil
end

function SOS.ParcometroVicino(coord)
    for _, p in ipairs(SOS.Parcometri) do
        if #(coord - p.coord) < 2.5 then return p end
    end
    return nil
end

--- La sosta è gratuita di notte e la domenica.
function SOS.Gratuita(ora, giorno)
    local d, a = SOS.Tariffe.orarioGratuito[1], SOS.Tariffe.orarioGratuito[2]
    local notte = (d <= a) and (ora >= d and ora < a) or (ora >= d or ora < a)
    if notte then return true end
    for _, g in ipairs(SOS.Tariffe.giorniGratuiti) do
        if g == giorno then return true end
    end
    return false
end
