--[[
    AUREA · Soccorso stradale (server)
]]

local U = AUREA.Util
local chiamate = {}     -- [id] = { citizenid, targa, coord, aperta, presa }
local contatore = 0

local function inServizio()
    return AUREA.GetGiocatoriPerLavoro(SOC.Lavoro, true) or {}
end

-- ---------------------------------------------------------------------------
--  Chiamata di soccorso
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('soc:chiama', function(src, rispondi, targa, guasto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    for _, c in pairs(chiamate) do
        if c.citizenid == g.citizenid and not c.chiusa then
            return rispondi(false, 'Hai già una richiesta aperta.')
        end
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    contatore = contatore + 1
    local id = contatore

    chiamate[id] = {
        id = id, citizenid = g.citizenid, nome = g:NomeCompleto(),
        targa = tostring(targa or ''):gsub('%s+', ''):upper(),
        guasto = tostring(guasto or 'guasto generico'):sub(1, 80),
        coord = { x = coord.x, y = coord.y, z = coord.z },
        aperta = os.time(),
    }

    local soccorritori = inServizio()

    for _, s in ipairs(soccorritori) do
        TriggerClientEvent('soc:nuovaChiamata', s.source, chiamate[id])
    end

    -- Se non risponde nessuno, entro qualche minuto passa il carro comunale
    CreateThread(function()
        Wait(SOC.Chiamata.minutiPrimaDellaRimozione * 60000)
        local c = chiamate[id]
        if not c or c.chiusa or c.presa then return end
        rimozioneForzata(id)
    end)

    rispondi(true, #soccorritori > 0
        and ('Richiesta trasmessa: %d soccorritori in servizio.'):format(#soccorritori)
        or ('Nessun soccorritore in servizio. Fra %d minuti interviene il carro comunale, a tue spese.')
            :format(SOC.Chiamata.minutiPrimaDellaRimozione))
end)

AUREA.Callback.Registra('soc:chiamate', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= SOC.Lavoro or not g.lavoro.servizio then return rispondi({}) end

    local out = {}
    for _, c in pairs(chiamate) do
        if not c.chiusa then
            out[#out + 1] = {
                id = c.id, nome = c.nome, targa = c.targa, guasto = c.guasto,
                coord = c.coord,
                presa = c.presa and c.presaDa or nil,
                minuti = math.floor((os.time() - c.aperta) / 60),
            }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    rispondi(out)
end)

AUREA.Callback.Registra('soc:prendi', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local c = chiamate[id]
    if not g or not c or c.chiusa then return rispondi(false, 'Chiamata non più valida.') end
    if g.lavoro.nome ~= SOC.Lavoro or not g.lavoro.servizio then return rispondi(false, 'Non sei in servizio.') end
    if c.presa then return rispondi(false, ('L\'ha già presa %s.'):format(c.presaDa)) end

    c.presa = g.citizenid
    c.presaDa = g:NomeCompleto()

    local cliente = AUREA.GetPlayerByCitizenId(c.citizenid)
    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'successo', icona = '🚛', durata = 13000,
            titolo = 'Soccorso in arrivo',
            testo = ('%s ha preso in carico la tua richiesta.'):format(g:NomeCompleto()),
        })
    end

    rispondi(true, c.coord)
end)

--- Il carro comunale: nessuno ha risposto, il mezzo va in depositeria.
function rimozioneForzata(id)
    local c = chiamate[id]
    if not c then return end
    c.chiusa = true

    if c.targa ~= '' then
        exports.ita_veicoli:SequestraVeicolo(c.targa,
            'rimozione forzata per veicolo in avaria su sede stradale',
            'carro comunale')
    end

    AUREA.Denaro.SottraiOffline(c.citizenid, 'banca', SOC.Chiamata.costoRimozioneForzata,
        'rimozione forzata del veicolo', true)

    TriggerEvent('aurea:fisco:incasso', 'rimozioni', SOC.Chiamata.costoRimozioneForzata, c.citizenid)

    local cliente = AUREA.GetPlayerByCitizenId(c.citizenid)
    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'errore', icona = '🚛', durata = 18000,
            titolo = 'Rimozione forzata',
            testo = ('Nessun soccorritore è intervenuto. Il carro comunale ha portato %s in depositeria: %s addebitati.')
                :format(c.targa ~= '' and c.targa or 'il mezzo', U.Euro(SOC.Chiamata.costoRimozioneForzata)),
        })
    end
end

-- ---------------------------------------------------------------------------
--  Interventi sul posto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('soc:intervento', function(src, rispondi, idIntervento, clienteSrc)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= SOC.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio.')
    end

    local i = SOC.GetIntervento(idIntervento)
    if not i then return rispondi(false, 'Intervento non previsto.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(i.oggetto, 1) then
        return rispondi(false, ('Serve %s.'):format(AUREA.Item[i.oggetto].etichetta))
    end

    local cliente = AUREA.GetPlayer(tonumber(clienteSrc))
    if cliente then
        local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(cliente.source)))
        if d > 12.0 then return rispondi(false, 'Il cliente è troppo lontano.') end
    end

    rispondi(true, { nome = i.nome, durata = i.durata, prezzo = i.prezzo, effetto = i.effetto,
                     salute = i.salutePercentuale })
end)

AUREA.Callback.Registra('soc:concludiIntervento', function(src, rispondi, idIntervento, clienteSrc)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local i = SOC.GetIntervento(idIntervento)
    if not i then return rispondi(false) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(i.oggetto, 1) then return rispondi(false, 'Il materiale è finito.') end
    inventario:Rimuovi(i.oggetto, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local cliente = AUREA.GetPlayer(tonumber(clienteSrc))
    local incassato = 0

    if cliente then
        if cliente:SottraiOvunque(i.prezzo, ('soccorso stradale: %s'):format(i.nome)) then
            incassato = i.prezzo
        else
            TriggerClientEvent('aurea:ui:notifica', cliente.source, {
                tipo = 'avviso', icona = '🧾', durata = 12000,
                titolo = 'Non hai coperto la spesa',
                testo = 'L\'intervento è stato fatto lo stesso: mettiti d\'accordo col soccorritore.',
            })
        end
    end

    if incassato > 0 then
        local quotaOfficina = math.floor(incassato * SOC.Chiamata.quotaOfficina)
        g:Aggiungi('banca', incassato - quotaOfficina, 'intervento di soccorso')
        TriggerEvent('aurea:fisco:incasso', 'iva_servizi', quotaOfficina, g.citizenid)
    end

    rispondi(true, incassato > 0
        and ('%s eseguito. Incassati %s.'):format(i.nome, U.Euro(incassato - math.floor(incassato * SOC.Chiamata.quotaOfficina)))
        or ('%s eseguito, ma il cliente non ha pagato.'):format(i.nome))
end)

-- ---------------------------------------------------------------------------
--  Chiusura della chiamata
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('soc:concludiTraino', function(src, rispondi, id, km)
    local g = AUREA.GetPlayer(src)
    local c = chiamate[id]
    if not g or not c or c.chiusa then return rispondi(false, 'Chiamata non più valida.') end
    if c.presa ~= g.citizenid then return rispondi(false, 'Non è la tua chiamata.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - SOC.Sede.officina) > 25.0 then
        return rispondi(false, 'Il mezzo va scaricato in officina.')
    end

    km = math.max(0, math.min(60, math.floor(tonumber(km) or 0)))
    local dovuto = SOC.Chiamata.tariffaBase + km * SOC.Chiamata.tariffaAlKm

    c.chiusa = true

    local pagato = AUREA.Denaro.SottraiOffline(c.citizenid, 'banca', dovuto, 'soccorso stradale', true)
    local quotaOfficina = math.floor(dovuto * SOC.Chiamata.quotaOfficina)

    g:Aggiungi('banca', dovuto - quotaOfficina, 'traino')
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', quotaOfficina, g.citizenid)

    if c.targa ~= '' then
        MySQL.update('UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ?', { c.targa })
    end

    local cliente = AUREA.GetPlayerByCitizenId(c.citizenid)
    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'successo', icona = '🚛', durata = 14000,
            titolo = 'Veicolo recuperato',
            testo = ('%s è in officina. Addebitati %s (%d km di traino).')
                :format(c.targa ~= '' and c.targa or 'Il mezzo', U.Euro(dovuto), km),
        })
    end

    AUREA.Log('veicoli', 'info', g, ('traino di %s per %d km, %s'):format(c.targa, km, U.Euro(dovuto)))
    rispondi(true, ('Traino concluso. Incassati %s.'):format(U.Euro(dovuto - quotaOfficina)))
end)

--- Le chiamate vecchie si chiudono da sole.
CreateThread(function()
    while true do
        Wait(600000)
        for id, c in pairs(chiamate) do
            if c.chiusa or (os.time() - c.aperta) > 3600 then chiamate[id] = nil end
        end
    end
end)
