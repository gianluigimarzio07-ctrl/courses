--[[
    AUREA · Regolamento (server)
]]

AUREA.Callback.Registra('reg:sezioni', function(src, rispondi)
    rispondi(REG.Sezioni)
end)

--- Chi entra per la prima volta vede il tutorial. Una volta sola.
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    if g:Get(REG.Regole.chiaveMetadata) then return end

    CreateThread(function()
        Wait(12000)
        TriggerClientEvent('reg:tutorial', src, REG.Tutorial)
    end)
end)

AUREA.Callback.Registra('reg:tutorialVisto', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    g:Set(REG.Regole.chiaveMetadata, true, false)
    MySQL.update('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
        { json.encode(g.metadata), g.citizenid })

    rispondi(true)
end)

--- Lo staff può rimostrarlo a chi ne ha bisogno.
AUREA.Comando('tutorial', 'supporto', 'Mostra il tutorial a un giocatore', {
    { name = 'id', help = 'ID del giocatore' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Giocatore non trovato',
        })
    end

    TriggerClientEvent('reg:tutorial', bersaglio.source, REG.Tutorial)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Tutorial inviato',
        testo = bersaglio:NomeCompleto(),
    })
end)
