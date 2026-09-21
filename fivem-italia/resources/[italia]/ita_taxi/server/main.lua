--[[
    AUREA · Taxi (server)

    Il tassametro è una riga aperta nel database e una posizione
    campionata dal server. I metri non li dichiara il tassista: li
    misura chi tiene il conto, che è la sola cosa che rende un
    tassametro un tassametro e non un prezzo trattato al finestrino.
]]

local U = AUREA.Util
local corse = {}        -- [idCorsa] = { tassista, cliente, ultimaCoord, metri, secondiFermo }
local contatore = 0

local function tassista(g)
    return g and g.lavoro.nome == TAX.Lavoro and g.lavoro.servizio
end

local function inRimessa(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - TAX.Rimessa.coord) <= 10.0
end

-- ---------------------------------------------------------------------------
--  La licenza
-- ---------------------------------------------------------------------------
local function licenzaDi(citizenid)
    return MySQL.single.await([[
        SELECT id, numero, targa, sospesa, scadenza,
               DATEDIFF(scadenza, CURDATE()) AS giorni
        FROM taxi_licenze WHERE citizenid = ? AND sospesa = 0 AND scadenza >= CURDATE()
    ]], { citizenid })
end

exports('LicenzaValida', function(citizenid)
    return licenzaDi(citizenid) ~= nil
end)

AUREA.Callback.Registra('tax:licenze', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local rilasciate = MySQL.scalar.await(
        'SELECT COUNT(*) FROM taxi_licenze WHERE scadenza >= CURDATE()') or 0

    rispondi({
        mia = licenzaDi(g.citizenid),
        rilasciate = rilasciate,
        contingente = TAX.Licenza.contingente,
        costo = TAX.Licenza.costo,
        giorni = TAX.Licenza.giorniValidita,
    })
end)

AUREA.Callback.Registra('tax:chiediLicenza', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if g.lavoro.nome ~= TAX.Lavoro then
        return rispondi(false, 'La licenza la prende chi fa il tassista.')
    end

    if licenzaDi(g.citizenid) then return rispondi(false, 'Ne hai già una valida.') end

    local rilasciate = MySQL.scalar.await(
        'SELECT COUNT(*) FROM taxi_licenze WHERE scadenza >= CURDATE()') or 0
    if rilasciate >= TAX.Licenza.contingente then
        return rispondi(false, ('Il contingente comunale è di %d licenze e sono tutte assegnate. Bisogna aspettare che una scada.')
            :format(TAX.Licenza.contingente))
    end

    if not g:Sottrai('banca', TAX.Licenza.costo, 'licenza taxi') then
        return rispondi(false, ('La licenza costa %s.'):format(U.Euro(TAX.Licenza.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'licenze_comunali', TAX.Licenza.costo, g.citizenid)

    local numero = ('TX%s'):format(U.Random(5, '0123456789'))
    MySQL.query.await([[
        INSERT INTO taxi_licenze (citizenid, numero, scadenza)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE numero = VALUES(numero), scadenza = VALUES(scadenza), sospesa = 0
    ]], { g.citizenid, numero, U.DataPiuGiorni(TAX.Licenza.giorniValidita) })

    AUREA.Log('economia', 'info', g, ('licenza taxi %s rilasciata'):format(numero))
    rispondi(true, ('Licenza %s rilasciata, valida %d giorni.\nDa adesso le corse sono un mestiere e non un illecito.')
        :format(numero, TAX.Licenza.giorniValidita))
end)

-- ---------------------------------------------------------------------------
--  La corsa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tax:avvia', function(src, rispondi, sorgenteCliente)
    local g = AUREA.GetPlayer(src)
    if not tassista(g) then return rispondi(false, 'Serve essere tassista in servizio.') end

    local cliente = AUREA.GetPlayer(tonumber(sorgenteCliente))
    if not cliente then return rispondi(false, 'Il cliente non è collegato.') end
    if cliente.citizenid == g.citizenid then return rispondi(false, 'Non puoi essere cliente di te stesso.') end

    for _, c in pairs(corse) do
        if c.tassista == g.citizenid then return rispondi(false, 'Hai già una corsa aperta.') end
    end

    local ped = GetPlayerPed(src)
    local veicolo = GetVehiclePedIsIn(ped, false)
    if veicolo == 0 then return rispondi(false, 'Il tassametro si avvia in macchina.') end
    if #(GetEntityCoords(ped) - GetEntityCoords(GetPlayerPed(cliente.source))) > 8.0 then
        return rispondi(false, 'Il cliente non è a bordo.')
    end

    local licenza = licenzaDi(g.citizenid)
    local coord = GetEntityCoords(ped)

    contatore = contatore + 1
    corse[contatore] = {
        id = contatore,
        tassista = g.citizenid,
        tassistaSrc = src,
        cliente = cliente.citizenid,
        clienteSrc = cliente.source,
        licenza = licenza and licenza.numero or nil,
        targa = (GetVehicleNumberPlateText(veicolo) or ''):gsub('%s+$', ''),
        coord = coord,
        metri = 0,
        secondiFermo = 0,
        partenza = ('%.0f, %.0f'):format(coord.x, coord.y),
        avviata = os.time(),
    }

    TriggerClientEvent('tax:tassametro', src, contatore, true)
    TriggerClientEvent('aurea:ui:notifica', cliente.source, {
        tipo = 'info', icona = '🚕', durata = 12000,
        titolo = 'Tassametro avviato',
        testo = ('Scatto %s, poi %s al chilometro.%s')
            :format(U.Euro(TAX.Tariffa.scatto), U.Euro(TAX.Tariffa.alKm),
                    licenza and '' or '\nQuesto taxi non espone una licenza.'),
    })

    rispondi(true, ('Tassametro avviato.%s')
        :format(licenza and (' Licenza %s.'):format(licenza.numero)
                        or ' SENZA LICENZA: è trasporto abusivo.'), contatore)
end)

--- Il client manda la posizione; il server calcola la distanza. Se il
--- salto è implausibile, non si conta: un teletrasporto non è un
--- chilometro percorso.
RegisterNetEvent('tax:posizione', function(idCorsa, fermo)
    local src = source
    local c = corse[tonumber(idCorsa) or 0]
    if not c or c.tassistaSrc ~= src then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local delta = #(coord - c.coord)

    -- 5 secondi a 200 km/h sono 278 metri: oltre, è un salto
    if delta > 0 and delta < 300.0 then
        c.metri = c.metri + delta
    end
    c.coord = coord

    if fermo then
        c.secondiFermo = c.secondiFermo + TAX.Tariffa.secondiAggiornamento
    end
end)

AUREA.Callback.Registra('tax:stato', function(src, rispondi, idCorsa)
    local c = corse[tonumber(idCorsa) or 0]
    if not c then return rispondi(nil) end

    local ora = tonumber(os.date('%H'))
    local giorno = tonumber(os.date('%u'))
    local m = TAX.Moltiplicatore(ora, giorno)

    rispondi({
        metri = math.floor(c.metri),
        secondiFermo = c.secondiFermo,
        importo = TAX.Totale(c.metri, c.secondiFermo, m),
        moltiplicatore = m,
        licenza = c.licenza,
    })
end)

AUREA.Callback.Registra('tax:chiudi', function(src, rispondi, idCorsa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local c = corse[tonumber(idCorsa) or 0]
    if not c or c.tassista ~= g.citizenid then return rispondi(false, 'Non è una tua corsa.') end

    local ora = tonumber(os.date('%H'))
    local giorno = tonumber(os.date('%u'))
    local importo = TAX.Totale(c.metri, c.secondiFermo, TAX.Moltiplicatore(ora, giorno))

    local cliente = AUREA.GetPlayerByCitizenId(c.cliente)
    local pagata = false

    if cliente then
        pagata = cliente:SottraiOvunque(importo, 'corsa in taxi')
        if pagata then
            local quota = c.licenza and math.floor(importo * TAX.Abusivismo.quotaComune) or 0
            g:Aggiungi('contanti', importo - quota, 'corsa in taxi')
            if quota > 0 then
                TriggerEvent('aurea:fisco:incasso', 'licenze_comunali', quota, g.citizenid)
            end
        end
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    MySQL.insert.await([[
        INSERT INTO taxi_corse
            (tassista, cliente, licenza, partenza, arrivo, metri, secondi, importo, pagata, chiusa_il)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], { c.tassista, c.cliente, c.licenza, c.partenza,
          ('%.0f, %.0f'):format(coord.x, coord.y),
          math.floor(c.metri), os.time() - c.avviata, importo, pagata and 1 or 0 })

    -- Senza licenza è trasporto abusivo, e ogni tanto qualcuno lo vede
    if not c.licenza and math.random(100) <= TAX.Abusivismo.probabilitaSegnalazione then
        local infrazione = AUREA.Infrazioni[TAX.Abusivismo.infrazione]
        exports.ita_codicestrada:EmettiVerbale({
            citizenid = g.citizenid,
            targa = c.targa ~= '' and c.targa or nil,
            articolo = infrazione.articolo,
            descrizione = ('%s — corsa a pagamento senza licenza'):format(infrazione.nome),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'agente',
            agente = 'accertamento su segnalazione',
            luogo = c.partenza,
        })

        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚕', durata = 18000,
            titolo = 'Trasporto abusivo contestato',
            testo = ('Qualcuno ha segnalato la corsa. Art. 86 CdS: %s.')
                :format(U.Euro(infrazione.importo)),
        })
    end

    corse[c.id] = nil
    TriggerClientEvent('tax:tassametro', src, idCorsa, false)

    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = pagata and 'successo' or 'errore', icona = '🚕', durata = 12000,
            titolo = 'Corsa conclusa',
            testo = ('%.1f km · %s%s'):format(c.metri / 1000, U.Euro(importo),
                pagata and '' or '\nNon avevi i soldi: la corsa resta insoluta.'),
        })
    end

    rispondi(true, ('%.1f km in %d minuti — %s.%s')
        :format(c.metri / 1000, math.floor((os.time() - c.avviata) / 60), U.Euro(importo),
                pagata and '' or '\nIl cliente non ha pagato.'))
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, c in pairs(corse) do
        if c.tassistaSrc == src or c.clienteSrc == src then corse[id] = nil end
    end
end)

-- ---------------------------------------------------------------------------
--  Il registro delle corse
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tax:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    rispondi(MySQL.query.await([[
        SELECT partenza, arrivo, metri, importo, pagata, licenza,
               TIMESTAMPDIFF(MINUTE, chiusa_il, NOW()) AS minutiFa
        FROM taxi_corse WHERE tassista = ? ORDER BY id DESC LIMIT 15
    ]], { g.citizenid }) or {})
end)
