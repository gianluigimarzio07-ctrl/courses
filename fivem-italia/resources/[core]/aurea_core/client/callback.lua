--[[
    AUREA · Callback lato client
]]

AUREA = AUREA or {}
AUREA.Callback = { inAttesa = {}, contatore = 0, handler = {} }

local CB = AUREA.Callback

--- Invoca una callback registrata sul server.
---@param nome string
---@param cb fun(...)|nil
function CB.Chiama(nome, cb, ...)
    CB.contatore = CB.contatore + 1
    local token = CB.contatore
    CB.inAttesa[token] = cb or function() end
    TriggerServerEvent('aurea:callback:richiesta', nome, token, ...)

    SetTimeout(15000, function()
        if CB.inAttesa[token] then
            CB.inAttesa[token] = nil
            if cb then cb(nil) end
        end
    end)
end

--- Versione bloccante: da usare dentro CreateThread.
function CB.Attendi(nome, ...)
    local risultato, pronto = nil, false
    CB.Chiama(nome, function(...)
        risultato = { ... }
        pronto = true
    end, ...)
    while not pronto do Wait(0) end
    return table.unpack(risultato)
end

RegisterNetEvent('aurea:callback:risposta', function(token, ...)
    local cb = CB.inAttesa[token]
    if not cb then return end
    CB.inAttesa[token] = nil
    cb(...)
end)

--- Registra un handler che il server può invocare sul client.
function CB.Registra(nome, fn)
    CB.handler[nome] = fn
end

RegisterNetEvent('aurea:callback:client', function(nome, token, ...)
    local fn = CB.handler[nome]
    if not fn then return TriggerServerEvent('aurea:callback:clientRisposta', token) end
    local risposto = false
    fn(function(...)
        if risposto then return end
        risposto = true
        TriggerServerEvent('aurea:callback:clientRisposta', token, ...)
    end, ...)
end)

exports('Chiama', CB.Chiama)
exports('Attendi', CB.Attendi)
