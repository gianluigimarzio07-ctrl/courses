--[[
    AUREA · Interazioni (server)

    Tutto quello che una persona fa a un'altra passa da qui, perché è qui
    che si può verificare la distanza, il permesso e — dove serve — il
    consenso di chi la subisce.
]]

local U = AUREA.Util
local ammanettati = {}      -- [src] = da chi
local trascinati = {}       -- [src] = da chi
local richieste = {}        -- [destinatario] = { da, azione, momento }

exports('EAmmanettato', function(src) return ammanettati[src] ~= nil end)

local function vicini(a, b, distanza)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b))) <= distanza
end

AUREA.Callback.Registra('int:azione', function(src, rispondi, idAzione, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not altro or g.source == altro.source then
        return rispondi(false, 'Persona non trovata.')
    end

    local a = INT.GetAzione(idAzione)
    if not a then return rispondi(false, 'Azione non prevista.') end

    if not vicini(src, altro.source, a.distanza) then
        return rispondi(false, 'Sei troppo lontano.')
    end

    if a.lavori and not U.Contiene(a.lavori, g.lavoro.nome) then
        return rispondi(false, 'Non è una cosa che puoi fare tu.')
    end
    if a.inServizio and not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end
    if a.oggetto then
        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        if not inv:Ha(a.oggetto, 1) then
            return rispondi(false, ('Serve %s.'):format(AUREA.Item[a.oggetto].etichetta))
        end
    end
    if a.richiedeAmmanettato and not ammanettati[altro.source] then
        return rispondi(false, 'Va prima ammanettato.')
    end

    -- Le azioni che si subiscono e si possono rifiutare
    if a.richiedeConsenso then
        richieste[altro.source] = { da = src, azione = idAzione, momento = os.time() }
        TriggerClientEvent('int:richiesta', altro.source, idAzione, g:NomeCompleto(), a.nome)
        return rispondi(true, ('Richiesta inviata a %s.'):format(altro:NomeCompleto()))
    end

    return esegui(src, altro.source, idAzione, rispondi)
end)

function esegui(src, bersaglio, idAzione, rispondi)
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(bersaglio)
    if not g or not altro then return rispondi(false) end

    local a = INT.GetAzione(idAzione)

    if idAzione == 'ammanetta' then
        if ammanettati[bersaglio] then
            ammanettati[bersaglio] = nil
            trascinati[bersaglio] = nil
            TriggerClientEvent('int:ammanettato', bersaglio, false)
            TriggerClientEvent('int:trascinato', bersaglio, false)
            return rispondi(true, ('%s non è più ammanettato.'):format(altro:NomeCompleto()))
        end

        ammanettati[bersaglio] = src
        TriggerClientEvent('int:ammanettato', bersaglio, true)
        AUREA.Log('giustizia', 'debug', g, ('ha ammanettato %s'):format(altro.citizenid))
        return rispondi(true, ('%s ammanettato.'):format(altro:NomeCompleto()))

    elseif idAzione == 'trascina' then
        if trascinati[bersaglio] then
            trascinati[bersaglio] = nil
            TriggerClientEvent('int:trascinato', bersaglio, false)
            return rispondi(true, 'Accompagnamento interrotto.')
        end
        trascinati[bersaglio] = src
        TriggerClientEvent('int:trascinato', bersaglio, true, src)
        return rispondi(true, ('Stai accompagnando %s.'):format(altro:NomeCompleto()))

    elseif idAzione == 'inVeicolo' then
        TriggerClientEvent('int:inVeicolo', bersaglio, src)
        trascinati[bersaglio] = nil
        return rispondi(true, 'Fatto salire.')

    elseif idAzione == 'daVeicolo' then
        TriggerClientEvent('int:daVeicolo', bersaglio)
        return rispondi(true, 'Fatto scendere.')

    elseif idAzione == 'perquisisci' then
        TriggerEvent('aurea:giustizia:perquisito', src, altro.citizenid)
        TriggerClientEvent('int:apriPerquisizione', src, bersaglio)
        return rispondi(true, ('Perquisizione di %s.'):format(altro:NomeCompleto()))

    elseif idAzione == 'documenti' then
        TriggerClientEvent('int:mostraDocumenti', bersaglio, src, g:NomeCompleto())
        return rispondi(true, 'Documenti richiesti.')

    elseif idAzione == 'stretta' then
        TriggerClientEvent('int:emote', src, 'stretta_mano')
        TriggerClientEvent('int:emote', bersaglio, 'stretta_mano')
        return rispondi(true, 'Fatto.')
    end

    rispondi(false, 'Azione non gestita.')
end

AUREA.Callback.Registra('int:rispondi', function(src, rispondi, accetta)
    local r = richieste[src]
    if not r then return rispondi(false, 'Nessuna richiesta.') end
    richieste[src] = nil

    if (os.time() - r.momento) > INT.Regole.secondiConsenso then
        return rispondi(false, 'La richiesta è scaduta.')
    end

    local richiedente = AUREA.GetPlayer(r.da)
    if not richiedente then return rispondi(false, 'L\'altra persona non c\'è più.') end

    if not accetta then
        TriggerClientEvent('aurea:ui:notifica', richiedente.source, {
            tipo = 'info', icona = '✋', durata = 8000,
            titolo = 'Rifiutato', testo = 'Non ha accettato.',
        })
        return rispondi(true, 'Hai rifiutato.')
    end

    return esegui(r.da, src, r.azione, rispondi)
end)

--- Chi è ammanettato non può fare certe cose: lo sa anche il server.
AddEventHandler('playerDropped', function()
    ammanettati[source] = nil
    trascinati[source] = nil
    richieste[source] = nil
    for s, da in pairs(trascinati) do
        if da == source then
            trascinati[s] = nil
            TriggerClientEvent('int:trascinato', s, false)
        end
    end
end)
