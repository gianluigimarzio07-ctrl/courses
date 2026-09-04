--[[
    AUREA · Sanità (server)
]]

local U = AUREA.Util
local incoscienti = {}      -- [src] = { da = os.time(), soccorso = false }

-- ---------------------------------------------------------------------------
--  Stato di incoscienza
-- ---------------------------------------------------------------------------
RegisterNetEvent('med:incosciente', function(stato)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    if stato then
        if incoscienti[src] then return end
        incoscienti[src] = { da = os.time() }
        g:Set('ferito', true, true)

        -- Allerta automatica del 118
        local coord = GetEntityCoords(GetPlayerPed(src))
        TriggerEvent('aurea:112:allerta', 'malore',
            { x = coord.x, y = coord.y, z = coord.z },
            ('Persona a terra: %s'):format(g:NomeCompleto()), 'posizione trasmessa dal telefono')

        AUREA.Log('giustizia', 'info', g, 'ha perso conoscenza')
    else
        incoscienti[src] = nil
        g:Set('ferito', false, true)
    end
end)

--- Le ferite si salvano: sopravvivono al riavvio e alla disconnessione.
RegisterNetEvent('med:aggiornaFerite', function(lesioni)
    local g = AUREA.GetPlayer(source)
    if not g or type(lesioni) ~= 'table' then return end

    MySQL.query('INSERT INTO ferite (citizenid, dati) VALUES (?, ?) ON DUPLICATE KEY UPDATE dati = VALUES(dati)',
        { g.citizenid, json.encode(lesioni) })
end)

-- ---------------------------------------------------------------------------
--  Rianimazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:rianima', function(src, rispondi, bersaglioSrc, professionale, haKit)
    local soccorritore = AUREA.GetPlayer(src)
    local ferito = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not soccorritore or not ferito then return rispondi(false, 'Persona non trovata.') end
    if not incoscienti[ferito.source] then return rispondi(false, 'La persona è già cosciente.') end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(ferito.source)))
    if d > 3.0 then return rispondi(false, 'Ti sei allontanato dal ferito.') end

    -- Il personale 118 in servizio riesce sempre; un civile ha una probabilità
    local eSanitario = soccorritore:HaPermessoLavoro('stabilizza') and soccorritore.lavoro.servizio
    local riuscita = eSanitario or (math.random() < MED.Regole.successoSenzaKit)

    if eSanitario and haKit then
        exports.aurea_inventory:Rimuovi(soccorritore.citizenid, 'kit_medico', 1)
    elseif eSanitario then
        exports.aurea_inventory:Rimuovi(soccorritore.citizenid, 'adrenalina', 1)
    end

    if not riuscita then
        return rispondi(false, 'Non sei riuscito a rianimarlo. Serve personale sanitario.')
    end

    incoscienti[ferito.source] = nil
    ferito:Set('ferito', false, true)
    local salute = eSanitario and 165 or MED.Regole.saluteRisveglio
    TriggerClientEvent('med:rianimato', ferito.source, salute)

    -- Il soccorso professionale è prestazione retribuita
    if eSanitario then
        local compenso = 18000
        soccorritore:Aggiungi('banca', compenso, 'intervento di soccorso')
        TriggerEvent('aurea:fisco:erogazione', 'sanita', compenso, soccorritore.citizenid)

        MySQL.insert('INSERT INTO cartelle_cliniche (citizenid, diagnosi, terapia, medico, ticket) VALUES (?, ?, ?, ?, ?)', {
            ferito.citizenid, 'Perdita di coscienza sul territorio',
            'Rianimazione cardiopolmonare e stabilizzazione sul posto',
            soccorritore:NomeCompleto(), MED.Regole.ticket118,
        })
    end

    AUREA.Log('giustizia', 'info', soccorritore, ('ha rianimato %s'):format(ferito.citizenid))
    rispondi(true, ('%s ha ripreso conoscenza.'):format(ferito:NomeCompleto()))
end)

--- Trasporto in ambulanza verso l'ospedale più vicino.
RegisterNetEvent('med:trasporta', function(bersaglioSrc)
    local src = source
    local soccorritore = AUREA.GetPlayer(src)
    local ferito = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not soccorritore or not ferito then return end
    if not soccorritore:HaPermessoLavoro('trasporto') or not soccorritore.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale 118 in servizio.',
        })
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - GetEntityCoords(GetPlayerPed(ferito.source))) > 3.5 then return end

    TriggerClientEvent('med:trasportato', ferito.source, { x = coord.x, y = coord.y, z = coord.z + 0.5 })
    TriggerClientEvent('aurea:ui:notifica', ferito.source, {
        tipo = 'info', icona = '🚑', titolo = 'Caricato in ambulanza',
        testo = ('%s ti sta trasportando.'):format(soccorritore:NomeCompleto()),
    })
end)

-- ---------------------------------------------------------------------------
--  Risveglio in ospedale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('med:risveglio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local stato = incoscienti[src]
    if not stato then return rispondi(false) end
    if (os.time() - stato.da) < (MED.Regole.secondiPrimaResa - 5) then return rispondi(false) end

    incoscienti[src] = nil
    g:Set('ferito', false, true)

    -- Ticket del pronto soccorso, addebitato anche a debito
    local ticket = MED.Regole.ticketPronto
    if not g:SottraiOvunque(ticket, 'ticket pronto soccorso') then
        exports.ita_fisco:IscriviTributo(g.citizenid, 'sanita', os.date('%Y-%m'), ticket, 15)
    else
        TriggerEvent('aurea:fisco:incasso', 'ticket_sanitario', ticket, g.citizenid)
    end

    MySQL.query('DELETE FROM ferite WHERE citizenid = ?', { g.citizenid })
    MySQL.insert('INSERT INTO cartelle_cliniche (citizenid, diagnosi, terapia, ticket) VALUES (?, ?, ?, ?)', {
        g.citizenid, 'Accesso al pronto soccorso in codice rosso',
        'Stabilizzazione, trattamento delle lesioni e dimissione', ticket,
    })

    rispondi(true, MED.Regole.saluteRisveglio, ticket)
end)

AUREA.Callback.Registra('med:curaCompleta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local ticket = MED.Regole.ticketPronto
    if not g:SottraiOvunque(ticket, 'ricovero e cura') then
        return rispondi(false, ('Il ticket è di %s.'):format(U.Euro(ticket)))
    end

    TriggerEvent('aurea:fisco:incasso', 'ticket_sanitario', ticket, g.citizenid)
    MySQL.query('DELETE FROM ferite WHERE citizenid = ?', { g.citizenid })
    MySQL.insert('INSERT INTO cartelle_cliniche (citizenid, diagnosi, terapia, ticket) VALUES (?, ?, ?, ?)', {
        g.citizenid, 'Visita e trattamento delle lesioni riportate',
        'Medicazioni, riduzione delle fratture, terapia antalgica', ticket,
    })

    rispondi(true, ('Dimesso in buone condizioni. Ticket %s.'):format(U.Euro(ticket)))
end)

-- ---------------------------------------------------------------------------
--  Consultazione della cartella clinica (personale sanitario)
-- ---------------------------------------------------------------------------
AUREA.Comando('cartella', 'utente', 'Consulta la cartella clinica di un paziente', {
    { name = 'cf', help = 'Codice fiscale del paziente' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('cartella') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale medico.',
        })
    end

    local cf = (args[1] or ''):upper()
    local pg = MySQL.single.await('SELECT citizenid, nome, cognome FROM personaggi WHERE codice_fiscale = ?', { cf })
    if not pg then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Paziente non trovato', testo = cf })
    end

    local voci = MySQL.query.await(
        'SELECT diagnosi, terapia, medico, data FROM cartelle_cliniche WHERE citizenid = ? ORDER BY id DESC LIMIT 6',
        { pg.citizenid }) or {}

    local righe = {}
    for _, v in ipairs(voci) do
        righe[#righe + 1] = ('%s — %s%s'):format(
            U.DataOraIT(math.floor((v.data or 0) / 1000)), v.diagnosi,
            v.medico and (' (' .. v.medico .. ')') or '')
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '🩺', durata = 18000,
        titolo = ('Cartella clinica — %s %s'):format(pg.nome, pg.cognome),
        testo = #righe > 0 and table.concat(righe, '\n') or 'Nessun accesso registrato.',
    })
end)

AddEventHandler('playerDropped', function() incoscienti[source] = nil end)

--- Un giocatore che si disconnette da incosciente resta ferito al rientro.
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    local riga = MySQL.single.await('SELECT dati FROM ferite WHERE citizenid = ?', { g.citizenid })
    if riga and riga.dati then
        TriggerClientEvent('med:ripristinaFerite', src, json.decode(riga.dati))
    end
end)
