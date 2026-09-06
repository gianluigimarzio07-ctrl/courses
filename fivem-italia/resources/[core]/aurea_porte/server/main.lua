--[[
    AUREA · Serrature (server)

    Lo stato di ogni porta vive qui. Il client lo riceve e lo applica, ma
    non lo decide mai: un client compromesso può disegnarsi la porta
    aperta quanto vuole, il server continuerà a dire che è chiusa a tutti
    gli altri e la porta resterà chiusa per loro.
]]

local U = AUREA.Util
local stato = {}        -- [id] = bloccata (bool)

CreateThread(function()
    for _, p in ipairs(POR.Porte) do
        stato[p.id] = p.bloccata ~= false
    end
    Wait(2000)
    GlobalState.porte = stato
end)

local function pubblica()
    GlobalState.porte = stato
    TriggerClientEvent('por:stato', -1, stato)
end

--- Chi può aprire questa porta senza scassinarla.
local function autorizzato(g, p)
    if not p.lavori then return true end

    if U.Contiene(p.lavori, g.lavoro.nome) then
        if p.grado and g.lavoro.grado < p.grado then return false end
        return true
    end

    -- Una chiave nell'inventario vale quanto il distintivo
    if p.oggetto then
        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        if inv:Ha(p.oggetto, 1) then return true end
    end

    return false
end

AUREA.Callback.Registra('por:stato', function(src, rispondi)
    rispondi(stato)
end)

AUREA.Callback.Registra('por:usa', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local p = POR.GetPorta(id)
    if not p then return rispondi(false, 'Porta sconosciuta.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - p.coord) > POR.Regole.distanzaMassima + 1.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    if not autorizzato(g, p) then
        return rispondi(false, 'Non hai le chiavi di questa porta.')
    end

    stato[p.id] = not stato[p.id]
    pubblica()

    -- Alcune porte si richiudono da sole
    if p.autochiusura and not stato[p.id] then
        CreateThread(function()
            Wait(POR.Regole.secondiAutochiusura * 1000)
            if stato[p.id] == false then
                stato[p.id] = true
                pubblica()
            end
        end)
    end

    AUREA.Log('staff', 'debug', g, ('%s %s'):format(stato[p.id] and 'ha chiuso' or 'ha aperto', p.nome))
    rispondi(true, stato[p.id] and ('%s chiusa.'):format(p.nome) or ('%s aperta.'):format(p.nome))
end)

--- Scassinare. Rumoroso, incerto, e spesso costa l'attrezzo.
AUREA.Callback.Registra('por:scassina', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local p = POR.GetPorta(id)
    if not p then return rispondi(false, 'Porta sconosciuta.') end
    if p.scassinabile == false then
        return rispondi(false, 'È blindata: con un grimaldello non si apre.')
    end
    if stato[p.id] == false then return rispondi(false, 'È già aperta.') end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(POR.Regole.grimaldello, 1) then
        return rispondi(false, 'Serve un grimaldello.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - p.coord) > POR.Regole.distanzaMassima + 1.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    rispondi(true, POR.Regole.durataScasso)
end)

AUREA.Callback.Registra('por:concludiScasso', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local p = POR.GetPorta(id)
    if not p then return rispondi(false) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(POR.Regole.grimaldello, 1) then return rispondi(false, 'Non hai più l\'attrezzo.') end

    local coord = GetEntityCoords(GetPlayerPed(src))

    -- Il rumore lo sente qualcuno, riuscito o no
    if math.random(100) <= POR.Regole.probabilitaAllarme then
        TriggerEvent('aurea:112:allerta', 'sospetto', { x = coord.x, y = coord.y, z = coord.z },
            ('Rumori di effrazione su una porta di servizio: %s.'):format(p.nome),
            'segnalazione dei residenti')
    end

    -- Chi armeggia sulla serratura lascia le dita sulla maniglia, a meno
    -- che non abbia avuto la pazienza di mettersi i guanti
    TriggerEvent('aurea:scientifica:effrazione', g.citizenid,
        { x = coord.x, y = coord.y, z = coord.z }, inv:Ha('guanti', 1))

    local riuscito = math.random(100) <= POR.Regole.probabilitaRiuscita

    if not riuscito then
        if math.random(100) <= POR.Regole.probabilitaRotturaAttrezzo then
            inv:Rimuovi(POR.Regole.grimaldello, 1)
            TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
            return rispondi(false, 'La serratura ha tenuto e il grimaldello si è spezzato.')
        end
        return rispondi(false, 'La serratura ha tenuto.')
    end

    stato[p.id] = false
    pubblica()

    exports.ita_giustizia:ApriFascicolo(g.citizenid, '624b', 'indagine d\'ufficio',
        ('Effrazione della porta: %s.'):format(p.nome))

    AUREA.Log('giustizia', 'avviso', g, ('ha scassinato %s'):format(p.nome))
    rispondi(true, ('%s forzata. Da adesso è aperta per tutti.'):format(p.nome))
end)

--- Le altre risorse possono chiudere o aprire una porta: il quadro
--- elettrico saltato apre i cancelli, l'allarme li chiude.
exports('Imposta', function(id, bloccata)
    if stato[id] == nil then return false end
    stato[id] = bloccata == true
    pubblica()
    return true
end)

exports('EBloccata', function(id) return stato[id] == true end)
