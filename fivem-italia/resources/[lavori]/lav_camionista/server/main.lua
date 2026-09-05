--[[
    AUREA · Camionista (server)
]]

local U = AUREA.Util
local viaggi = {}       -- [src] = { destinazione, avviato, integrita }

local function livello(g)
    local fatti = math.floor(tonumber(g:Get('cam_viaggi')) or 0)
    return math.min(CAM.Regole.livelloMassimo, 1 + math.floor(fatti / CAM.Regole.viaggiPerLivello)), fatti
end

AUREA.Callback.Registra('cam:destinazioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if g.lavoro.nome ~= CAM.Lavoro then return rispondi(nil, 'Non sei assunto come camionista.') end

    local liv, fatti = livello(g)

    local out = {}
    for _, d in ipairs(CAM.Destinazioni) do
        out[#out + 1] = {
            id = d.id, nome = d.nome, paga = d.paga, difficolta = d.difficolta,
            coord = { x = d.coord.x, y = d.coord.y, z = d.coord.z },
            aperta = d.difficolta <= liv,
        }
    end
    table.sort(out, function(a, b) return a.paga < b.paga end)

    rispondi({
        destinazioni = out, livello = liv, viaggi = fatti,
        prossimo = CAM.Regole.viaggiPerLivello - (fatti % CAM.Regole.viaggiPerLivello),
        motrice = CAM.Motrice, rimorchio = CAM.Rimorchio,
        mezzi = CAM.Deposito.mezzi, rimorchi = CAM.Deposito.rimorchi,
    })
end)

AUREA.Callback.Registra('cam:parti', function(src, rispondi, idDestinazione)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= CAM.Lavoro then return rispondi(false, 'Non sei un camionista.') end
    if viaggi[src] then return rispondi(false, 'Hai già un viaggio in corso.') end

    local d = CAM.GetDestinazione(idDestinazione)
    if not d then return rispondi(false, 'Destinazione sconosciuta.') end

    local liv = livello(g)
    if d.difficolta > liv then
        return rispondi(false, ('Serve il livello %d: fai altri viaggi più corti.'):format(d.difficolta))
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAM.Deposito.coord) > 60.0 then
        return rispondi(false, 'Si parte dal deposito.')
    end

    viaggi[src] = {
        destinazione = idDestinazione, avviato = os.time(),
        integrita = CAM.Carico.integritaIniziale,
    }

    rispondi(true, {
        nome = d.nome,
        coord = { x = d.coord.x, y = d.coord.y, z = d.coord.z },
        paga = d.paga,
        soglia = CAM.Carico.sogliaRifiuto,
    })
end)

--- Il client segnala urti e frenate; il server tiene il conto.
RegisterNetEvent('cam:danneggia', function(tipo)
    local src = source
    local v = viaggi[src]
    if not v then return end

    local perdita = tipo == 'urto' and CAM.Carico.perditaPerUrto or CAM.Carico.perditaPerFrenata
    v.integrita = math.max(0, v.integrita - perdita)
    TriggerClientEvent('cam:integrita', src, v.integrita)
end)

AUREA.Callback.Registra('cam:consegna', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local v = viaggi[src]
    if not g or not v then return rispondi(false, 'Nessun viaggio in corso.') end

    local d = CAM.GetDestinazione(v.destinazione)
    if not d then viaggi[src] = nil return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - d.coord) > 40.0 then
        return rispondi(false, 'Non sei alla destinazione.')
    end

    viaggi[src] = nil

    if v.integrita < CAM.Carico.sogliaRifiuto then
        return rispondi(false, ('Carico rifiutato: integrità al %d%%, sotto la soglia del %d%%. Niente paga.')
            :format(v.integrita, CAM.Carico.sogliaRifiuto))
    end

    local paga = CAM.Carico.pagaProporzionale
        and math.floor(d.paga * (v.integrita / 100))
        or d.paga

    local ritenuta = math.floor(paga * 0.20)
    g:Aggiungi('banca', paga - ritenuta, ('trasporto · %s'):format(d.nome))
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    local fatti = math.floor(tonumber(g:Get('cam_viaggi')) or 0) + 1
    g:Set('cam_viaggi', fatti, true)

    local liv = livello(g)

    AUREA.Log('economia', 'debug', g,
        ('consegna a %s, integrità %d%%, %s'):format(d.nome, v.integrita, U.Euro(paga)))

    rispondi(true, ('Consegnato con integrità al %d%%. Netti %s (ritenuta %s). Viaggi: %d, livello %d.')
        :format(v.integrita, U.Euro(paga - ritenuta), U.Euro(ritenuta), fatti, liv))
end)

AddEventHandler('playerDropped', function() viaggi[source] = nil end)
