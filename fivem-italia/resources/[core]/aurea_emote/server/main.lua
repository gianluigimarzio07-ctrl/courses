--[[
    AUREA · Emote (server)
    Media gli inviti alle azioni condivise verificando la prossimità.
]]

local inviti = {}      -- [destinatario] = { da, tipo, momento }

RegisterNetEvent('emo:invita', function(bersaglioSrc, tipo)
    local src = source
    local mittente = AUREA.GetPlayer(src)
    local destinatario = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not mittente or not destinatario or mittente.source == destinatario.source then return end

    local condivisa = EMO.Condivise[tipo]
    if not condivisa then return end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(destinatario.source)))
    if d > condivisa.distanza + 1.5 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Troppo lontano', testo = 'Avvicinati alla persona.',
        })
    end

    inviti[destinatario.source] = { da = src, tipo = tipo, momento = os.time() }
    TriggerClientEvent('emo:invitoRicevuto', destinatario.source, src, mittente:NomeCompleto(), tipo)
end)

RegisterNetEvent('emo:rispondi', function(mittenteSrc, tipo, accettato)
    local src = source
    local invito = inviti[src]
    if not invito or invito.da ~= tonumber(mittenteSrc) or invito.tipo ~= tipo then return end
    inviti[src] = nil

    -- l'invito scade da solo dopo quindici secondi
    if (os.time() - invito.momento) > 15 then return end

    local mittente = AUREA.GetPlayer(invito.da)
    local destinatario = AUREA.GetPlayer(src)
    if not mittente or not destinatario then return end

    if not accettato then
        return TriggerClientEvent('aurea:ui:notifica', mittente.source, {
            tipo = 'info', icona = '🤝', titolo = 'Invito rifiutato',
            testo = ('%s ha declinato.'):format(destinatario:NomeCompleto()),
        })
    end

    local condivisa = EMO.Condivise[tipo]
    local d = #(GetEntityCoords(GetPlayerPed(mittente.source)) - GetEntityCoords(GetPlayerPed(src)))
    if d > condivisa.distanza + 1.5 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Troppo lontano', testo = 'Vi siete allontanati.',
        })
    end

    TriggerClientEvent('emo:condivisa', mittente.source, tipo, 'promotore', src)
    TriggerClientEvent('emo:condivisa', src, tipo, 'invitato', mittente.source)
end)

AddEventHandler('playerDropped', function()
    inviti[source] = nil
    for dest, invito in pairs(inviti) do
        if invito.da == source then inviti[dest] = nil end
    end
end)
