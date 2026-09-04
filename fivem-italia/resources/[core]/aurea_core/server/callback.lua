--[[
    AUREA · Callback server -> client e client -> server

    Uso lato server:
        AUREA.Callback.Registra('nome', function(source, cb, ...) cb(risultato) end)
        AUREA.Callback.Client(source, 'nome_client', function(risposta) end, ...)

    Uso lato client:
        AUREA.Callback.Chiama('nome', function(risposta) end, ...)
        local r = AUREA.Callback.Attendi('nome', ...)   -- dentro una thread

    Ogni handler registrato riceve sempre il source come primo parametro:
    non fidarsi mai di un citizenid passato dal client.
]]

AUREA = AUREA or {}
AUREA.Callback = { handler = {}, inAttesa = {}, contatore = 0 }

local CB = AUREA.Callback

--- Registra un handler che il client può invocare.
---@param nome string
---@param fn fun(source:number, rispondi:fun(...), ...)
function CB.Registra(nome, fn)
    CB.handler[nome] = fn
end

RegisterNetEvent('aurea:callback:richiesta', function(nome, token, ...)
    local src = source
    local fn = CB.handler[nome]
    if not fn then
        print(('[AUREA] callback sconosciuta richiesta da %s: %s'):format(src, nome))
        TriggerClientEvent('aurea:callback:risposta', src, token)
        return
    end

    local risposto = false
    local function rispondi(...)
        if risposto then return end
        risposto = true
        TriggerClientEvent('aurea:callback:risposta', src, token, ...)
    end

    local ok, err = pcall(fn, src, rispondi, ...)
    if not ok then
        print(('[AUREA] errore nella callback "%s": %s'):format(nome, err))
        rispondi(nil)
    end
end)

--- Invoca una callback registrata sul client.
function CB.Client(src, nome, cb, ...)
    CB.contatore = CB.contatore + 1
    local token = CB.contatore
    CB.inAttesa[token] = cb
    TriggerClientEvent('aurea:callback:client', src, nome, token, ...)

    -- timeout di sicurezza: 10 secondi
    SetTimeout(10000, function()
        if CB.inAttesa[token] then
            CB.inAttesa[token] = nil
            cb(nil)
        end
    end)
end

RegisterNetEvent('aurea:callback:clientRisposta', function(token, ...)
    local cb = CB.inAttesa[token]
    if not cb then return end
    CB.inAttesa[token] = nil
    cb(...)
end)

exports('RegistraCallback', CB.Registra)
