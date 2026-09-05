--[[
    AUREA · Autonoleggio (server)
]]

local U = AUREA.Util
local noleggi = {}      -- [citizenid] = { modello, targa, scade, cauzione, punto }

AUREA.Callback.Registra('nol:flotta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local punto = NOL.PuntoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not punto then return rispondi(nil, 'Non sei a un punto di noleggio.') end

    local attivo = noleggi[g.citizenid]
    if attivo and os.time() > attivo.scade + 3600 then
        noleggi[g.citizenid] = nil
        attivo = nil
    end

    rispondi({
        punto = punto.nome,
        flotta = NOL.Flotta,
        regole = NOL.Regole,
        attivo = attivo and {
            nome = NOL.GetVeicolo(attivo.modello).nome,
            targa = attivo.targa,
            minuti = math.floor((attivo.scade - os.time()) / 60),
            scaduto = os.time() > attivo.scade,
        } or nil,
    })
end)

AUREA.Callback.Registra('nol:noleggia', function(src, rispondi, modello, ore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local punto = NOL.PuntoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not punto then return rispondi(false, 'Non sei a un punto di noleggio.') end
    if noleggi[g.citizenid] then return rispondi(false, 'Hai già un mezzo a noleggio.') end

    local v = NOL.GetVeicolo(modello)
    if not v then return rispondi(false, 'Mezzo non in flotta.') end

    -- Senza patente non si noleggia
    if not exports.ita_codicestrada:PatenteHaCategoria(g.citizenid, 'B') then
        return rispondi(false, 'Serve la patente B in corso di validità.')
    end

    ore = math.floor(U.Clamp(tonumber(ore) or 1, NOL.Regole.oreMinime, NOL.Regole.oreMassime))
    local canone = v.tariffaOraria * ore
    local totale = canone + v.cauzione

    if not AUREA.Denaro.SottraiOffline(g.citizenid, 'banca', totale, ('noleggio %s'):format(v.nome)) then
        return rispondi(false, ('Servono %s sul conto (%s di canone + %s di cauzione).')
            :format(U.Euro(totale), U.Euro(canone), U.Euro(v.cauzione)))
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(canone * 0.22), g.citizenid)

    local targa = ('NOL%04d'):format(math.random(0, 9999))
    noleggi[g.citizenid] = {
        modello = modello, targa = targa,
        scade = os.time() + ore * 3600,
        cauzione = v.cauzione, tariffa = v.tariffaOraria,
        punto = punto.nome,
    }

    rispondi(true, {
        modello = modello, targa = targa,
        spawn = { x = punto.spawn.x, y = punto.spawn.y, z = punto.spawn.z, w = punto.spawn.w },
        messaggio = ('%s per %d ore. Cauzione %s, la riavrai se lo riporti intero e in orario.')
            :format(v.nome, ore, U.Euro(v.cauzione)),
    })
end)

AUREA.Callback.Registra('nol:riconsegna', function(src, rispondi, danni)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local n = noleggi[g.citizenid]
    if not n then return rispondi(false, 'Non hai mezzi a noleggio.') end

    if not NOL.PuntoVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Il mezzo va riportato a un punto di noleggio.')
    end

    noleggi[g.citizenid] = nil
    danni = math.max(0, math.min(1, tonumber(danni) or 0))

    local trattenuta = 0
    local note = {}

    if danni > NOL.Regole.sogliaDanni then
        trattenuta = math.floor(n.cauzione * danni)
        note[#note + 1] = ('danni al %d%%'):format(math.floor(danni * 100))
    end

    -- Riconsegna in ritardo
    local ritardo = os.time() - n.scade
    if ritardo > 0 then
        local oreRitardo = math.ceil(ritardo / 3600)
        local penale = math.floor(n.tariffa * NOL.Regole.penaleOraria * oreRitardo)
        trattenuta = trattenuta + penale
        note[#note + 1] = ('%d ore di ritardo'):format(oreRitardo)
    end

    trattenuta = math.min(trattenuta, n.cauzione)
    local restituita = n.cauzione - trattenuta

    if restituita > 0 then
        AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', restituita, 'restituzione cauzione noleggio')
    end
    if trattenuta > 0 then
        TriggerEvent('aurea:fisco:incasso', 'iva_servizi', trattenuta, g.citizenid)
    end

    rispondi(true, restituita == n.cauzione
        and ('Mezzo riconsegnato. Cauzione restituita per intero: %s.'):format(U.Euro(restituita))
        or ('Trattenuti %s (%s). Restituiti %s.')
            :format(U.Euro(trattenuta), table.concat(note, ' e '), U.Euro(restituita)))
end)

exports('EDiNoleggio', function(targa)
    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    for _, n in pairs(noleggi) do
        if n.targa == targa then return true end
    end
    return false
end)
