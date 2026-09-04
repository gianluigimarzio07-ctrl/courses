--[[
    AUREA · Ambiente (server)
    Il server è l'unica fonte di verità per ora e meteo: i client li ricevono.
]]

local U = AUREA.Util

Ambiente = {
    meteo = 'CLEAR',
    prossimoCambio = 0,
    ore = 8,
    minuti = 0,
    eventoAttivo = nil,
}

-- ---------------------------------------------------------------------------
--  Orologio
-- ---------------------------------------------------------------------------
CreateThread(function()
    -- Si parte dall'ora reale italiana, poi il tempo scorre accelerato
    Ambiente.ore = tonumber(os.date('%H'))
    Ambiente.minuti = tonumber(os.date('%M'))

    local intervallo = math.floor(60000 / AMB.Tempo.scala)

    while true do
        Wait(intervallo)
        Ambiente.minuti = Ambiente.minuti + 1
        if Ambiente.minuti >= 60 then
            Ambiente.minuti = 0
            Ambiente.ore = (Ambiente.ore + 1) % 24
        end
    end
end)

CreateThread(function()
    while true do
        Wait(AMB.Tempo.intervalloSincroSecondi * 1000)
        TriggerClientEvent('amb:sincronizza', -1, {
            ore = Ambiente.ore,
            minuti = Ambiente.minuti,
            meteo = Ambiente.meteo,
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Meteo
-- ---------------------------------------------------------------------------
local function cambiaMeteo(forzato)
    local mese = tonumber(os.date('%m'))
    local stagione = AMB.StagioneDelMese(mese)

    local nuovo = forzato or AMB.ProssimoMeteo(Ambiente.meteo, stagione)
    if nuovo == Ambiente.meteo and not forzato then return end

    Ambiente.meteo = nuovo
    TriggerClientEvent('amb:meteo', -1, nuovo, AMB.Meteo.transizioneSecondi)

    AUREA.Log('economia', 'debug', nil, ('Meteo: %s (stagione %s)'):format(nuovo, stagione))
end

CreateThread(function()
    Wait(5000)
    cambiaMeteo()

    while true do
        local durata = math.random(AMB.Meteo.durataMinima, AMB.Meteo.durataMassima)
        Wait(durata * 60000)
        if not (Ambiente.eventoAttivo and Ambiente.eventoAttivo.forzaMeteo) then
            cambiaMeteo()
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Festività
-- ---------------------------------------------------------------------------
local function applicaFestivita()
    local festa = AMB.FestivitaOggi()
    local periodo = AMB.PeriodoCorrente()
    local effetto = (festa and festa.effetto) or (periodo and periodo.effetto) or nil

    TriggerClientEvent('amb:atmosfera', -1, {
        effetto = effetto,
        nome = (festa and festa.nome) or (periodo and periodo.nome) or nil,
    })

    if festa then
        TriggerClientEvent('aurea:ui:notifica', -1, {
            tipo = 'info', icona = '🇮🇹', durata = 15000,
            titolo = festa.nome,
            testo = festa.messaggio or 'Oggi è festa.',
        })

        -- Il Primo Maggio l'erario raddoppia gli stipendi pubblici
        if festa.effetto == 'lavoro' then
            for _, g in pairs(AUREA.Giocatori) do
                local grado = AUREA.GetGrado(g.lavoro.nome, g.lavoro.grado)
                if grado.stipendio and grado.stipendio > 0 then
                    g:Aggiungi('banca', grado.stipendio, 'gratifica Festa dei Lavoratori')
                    TriggerEvent('aurea:fisco:erogazione', 'gratifiche', grado.stipendio, g.citizenid)
                end
            end
        end
    end

    return effetto
end

CreateThread(function()
    Wait(20000)
    applicaFestivita()
    while true do
        Wait(30 * 60000)
        applicaFestivita()
    end
end)

-- ---------------------------------------------------------------------------
--  Eventi dinamici
-- ---------------------------------------------------------------------------
local function avviaEvento(evento)
    Ambiente.eventoAttivo = evento

    if evento.forzaMeteo then cambiaMeteo(evento.forzaMeteo) end

    TriggerClientEvent('amb:evento', -1, {
        id = evento.id, nome = evento.nome, descrizione = evento.descrizione,
        minuti = evento.durataMinuti, effetto = evento.effetto,
        coord = evento.coord and { x = evento.coord.x, y = evento.coord.y, z = evento.coord.z } or nil,
    })

    -- Gli eventi economici li raccoglie il motore dei prezzi
    TriggerEvent('aurea:ambiente:evento', evento.id, evento.effetto)

    -- I controlli straordinari allertano le forze dell'ordine
    if evento.effetto.tipo == 'controlli' then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'polizia', icona = '🚔', durata = 14000,
            titolo = 'Servizio straordinario disposto',
            testo = 'Predisporre posti di controllo sulle arterie principali.',
        }, true)
    end

    AUREA.Log('economia', 'info', nil, ('Evento avviato: %s'):format(evento.nome))

    SetTimeout(evento.durataMinuti * 60000, function()
        if Ambiente.eventoAttivo and Ambiente.eventoAttivo.id == evento.id then
            Ambiente.eventoAttivo = nil
            TriggerClientEvent('amb:eventoConcluso', -1, evento.id)
            TriggerEvent('aurea:ambiente:eventoConcluso', evento.id)
            AUREA.Log('economia', 'debug', nil, ('Evento concluso: %s'):format(evento.nome))
        end
    end)
end

CreateThread(function()
    Wait(120000)
    while true do
        Wait(AMB.IntervalloEventiMinuti * 60000)

        if not Ambiente.eventoAttivo then
            -- Si valuta un evento per volta, in ordine casuale
            local candidati = {}
            for _, e in ipairs(AMB.Eventi) do
                local oraValida = true
                if e.oreValide then
                    local da, a = e.oreValide[1], e.oreValide[2]
                    if da <= a then
                        oraValida = Ambiente.ore >= da and Ambiente.ore < a
                    else
                        oraValida = Ambiente.ore >= da or Ambiente.ore < a
                    end
                end
                if oraValida then candidati[#candidati + 1] = e end
            end

            if #candidati > 0 then
                local evento = candidati[math.random(#candidati)]
                if math.random(100) <= evento.probabilita then
                    avviaEvento(evento)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Stato per i nuovi arrivati
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('amb:stato', function(src, rispondi)
    local mese = tonumber(os.date('%m'))
    local stagione, dati = AMB.StagioneDelMese(mese)
    local festa = AMB.FestivitaOggi()
    local periodo = AMB.PeriodoCorrente()

    rispondi({
        ore = Ambiente.ore, minuti = Ambiente.minuti, meteo = Ambiente.meteo,
        stagione = stagione, stagioneEtichetta = dati.etichetta,
        alba = AMB.Tempo.albaPerMese[mese], tramonto = AMB.Tempo.tramontoPerMese[mese],
        atmosfera = (festa and festa.effetto) or (periodo and periodo.effetto) or nil,
        atmosferaNome = (festa and festa.nome) or (periodo and periodo.nome) or nil,
        evento = Ambiente.eventoAttivo and {
            id = Ambiente.eventoAttivo.id,
            nome = Ambiente.eventoAttivo.nome,
            descrizione = Ambiente.eventoAttivo.descrizione,
            coord = Ambiente.eventoAttivo.coord and {
                x = Ambiente.eventoAttivo.coord.x,
                y = Ambiente.eventoAttivo.coord.y,
                z = Ambiente.eventoAttivo.coord.z,
            } or nil,
        } or nil,
    })
end)

exports('MeteoCorrente', function() return Ambiente.meteo end)
exports('OraCorrente', function() return Ambiente.ore, Ambiente.minuti end)
exports('EventoAttivo', function() return Ambiente.eventoAttivo end)

-- ---------------------------------------------------------------------------
--  Comandi staff
-- ---------------------------------------------------------------------------
AUREA.Comando('meteo', 'moderatore', 'Imposta le condizioni meteo', {
    { name = 'condizione', help = 'CLEAR, RAIN, THUNDER, FOGGY, ...' },
}, function(src, args)
    local condizione = (args[1] or ''):upper()
    if not AMB.Transizioni[condizione] then
        local elenco = {}
        for k in pairs(AMB.Transizioni) do elenco[#elenco + 1] = k end
        table.sort(elenco)
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Condizione non valida', testo = table.concat(elenco, ', '),
        })
    end
    cambiaMeteo(condizione)
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Meteo impostato', testo = condizione })
end)

AUREA.Comando('ora', 'moderatore', 'Imposta l\'ora di gioco', {
    { name = 'ore', help = '0-23' },
    { name = 'minuti', help = '0-59' },
}, function(src, args)
    local ore = tonumber(args[1])
    if not ore or ore < 0 or ore > 23 then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/ora <0-23> [minuti]' })
    end
    Ambiente.ore = math.floor(ore)
    Ambiente.minuti = math.floor(U.Clamp(tonumber(args[2]) or 0, 0, 59))

    TriggerClientEvent('amb:sincronizza', -1, { ore = Ambiente.ore, minuti = Ambiente.minuti, meteo = Ambiente.meteo })
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Ora impostata', testo = ('%02d:%02d'):format(Ambiente.ore, Ambiente.minuti),
    })
end)

AUREA.Comando('evento', 'admin', 'Avvia un evento dinamico', {
    { name = 'id', help = 'Identificativo dell\'evento' },
}, function(src, args)
    local id = args[1]
    for _, e in ipairs(AMB.Eventi) do
        if e.id == id then
            avviaEvento(e)
            return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Evento avviato', testo = e.nome })
        end
    end

    local elenco = {}
    for _, e in ipairs(AMB.Eventi) do elenco[#elenco + 1] = e.id end
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'errore', titolo = 'Eventi disponibili', testo = table.concat(elenco, ', '), durata = 12000,
    })
end)
