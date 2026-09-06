--[[
    AUREA · Persistenza (server)

    Il server chiede periodicamente ai client dove stanno i veicoli che
    hanno intorno, e scrive. Al riavvio li ricrea. È l'unico modo:
    il server non ha le entità in scena, ce le hanno i client.
]]

local U = AUREA.Util
local inRipristino = false

-- ---------------------------------------------------------------------------
--  Salvataggio
-- ---------------------------------------------------------------------------

--- Un client segnala dove stanno i veicoli intestati che ha intorno.
RegisterNetEvent('per:segnala', function(elenco)
    local src = source
    if not AUREA.GetPlayer(src) then return end
    if type(elenco) ~= 'table' then return end

    for _, v in ipairs(elenco) do
        local targa = tostring(v.targa or ''):gsub('%s+', ''):upper()
        if targa ~= '' and type(v.x) == 'number' then
            -- Si scrive solo per i veicoli che risultano davvero fuori:
            -- il client non può far "riapparire" un mezzo sequestrato
            MySQL.update([[
                UPDATE veicoli
                SET posizione = ?, carburante = ?, motore = ?, carrozzeria = ?,
                    stato = 'fuori', visto_il = NOW()
                WHERE targa = ? AND stato IN ('fuori','garage')
            ]], {
                json.encode({ x = v.x, y = v.y, z = v.z, h = v.h or 0.0 }),
                math.max(0, math.min(100, tonumber(v.carburante) or 100)),
                math.max(0, math.min(1000, tonumber(v.motore) or 1000)),
                math.max(0, math.min(1000, tonumber(v.carrozzeria) or 1000)),
                targa,
            })
        end
    end
end)

CreateThread(function()
    Wait(60000)
    while true do
        Wait(PER.Veicoli.minutiSalvataggio * 60000)
        TriggerClientEvent('per:raccogli', -1)
    end
end)

-- ---------------------------------------------------------------------------
--  Ripristino all'avvio
-- ---------------------------------------------------------------------------
CreateThread(function()
    if not PER.Veicoli.ripristinaAllAvvio then return end

    Wait(20000)
    inRipristino = true

    local righe = MySQL.query.await([[
        SELECT targa, modello, hash, posizione, carburante, motore, carrozzeria, proprieta
        FROM veicoli WHERE stato = 'fuori' AND posizione IS NOT NULL
    ]]) or {}

    if #righe == 0 then
        inRipristino = false
        return
    end

    print(('[AUREA] ripristino di %d veicoli lasciati fuori'):format(#righe))

    local lotto = {}
    for n, v in ipairs(righe) do
        local ok, pos = pcall(json.decode, v.posizione)
        if ok and pos and pos.x then
            lotto[#lotto + 1] = {
                targa = v.targa, modello = v.modello,
                x = pos.x, y = pos.y, z = pos.z, h = pos.h or 0.0,
                carburante = v.carburante, motore = v.motore, carrozzeria = v.carrozzeria,
                proprieta = v.proprieta,
            }
        end

        if #lotto >= PER.Veicoli.perOndata or n == #righe then
            TriggerClientEvent('per:ricrea', -1, lotto)
            lotto = {}
            Wait(PER.Veicoli.pausaFraOndate)
        end
    end

    inRipristino = false
    print('[AUREA] ripristino completato')
end)

--- Chi entra a server già avviato riceve quello che c'è in giro.
AddEventHandler('aurea:giocatore:caricato', function(src)
    if inRipristino then return end

    CreateThread(function()
        Wait(15000)

        local righe = MySQL.query.await([[
            SELECT targa, modello, posizione, carburante, motore, carrozzeria
            FROM veicoli WHERE stato = 'fuori' AND posizione IS NOT NULL
        ]]) or {}

        local lotto = {}
        for n, v in ipairs(righe) do
            local ok, pos = pcall(json.decode, v.posizione)
            if ok and pos and pos.x then
                lotto[#lotto + 1] = {
                    targa = v.targa, modello = v.modello,
                    x = pos.x, y = pos.y, z = pos.z, h = pos.h or 0.0,
                    carburante = v.carburante, motore = v.motore, carrozzeria = v.carrozzeria,
                }
            end
            if #lotto >= PER.Veicoli.perOndata or n == #righe then
                TriggerClientEvent('per:ricrea', src, lotto)
                lotto = {}
                Wait(PER.Veicoli.pausaFraOndate)
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Relitti
--
--  Una città piena di macchine abbandonate è il prezzo della persistenza.
--  Questo è il conto che lo tiene sotto controllo.
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(300000)
    while true do
        -- Un veicolo che nessun client segnala più da ore è un relitto:
        -- nessuno ci sale e nessuno gli sta vicino.
        local rimossi = MySQL.update.await([[
            UPDATE veicoli SET stato = ?, garage = 'centrale', posizione = NULL
            WHERE stato = 'fuori'
              AND visto_il IS NOT NULL
              AND visto_il < DATE_SUB(NOW(), INTERVAL ? HOUR)
        ]], { PER.Veicoli.relittoInGarage and 'garage' or 'demolito', PER.Veicoli.oreRelitto })

        if (rimossi or 0) > 0 then
            AUREA.Log('veicoli', 'info', nil,
                ('%d relitti rimossi dalla strada e riportati in garage'):format(rimossi))
            TriggerClientEvent('per:pulisci', -1)
        end

        Wait(3600000)
    end
end)

-- ---------------------------------------------------------------------------
--  All'arresto si salva comunque
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() or not PER.Regole.salvaAllArresto then return end
    TriggerClientEvent('per:raccogli', -1)
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(dati)
    if dati and dati.secondsRemaining and dati.secondsRemaining <= 60 then
        TriggerClientEvent('per:raccogli', -1)
    end
end)

--- Le altre risorse possono forzare un salvataggio.
exports('Salva', function() TriggerClientEvent('per:raccogli', -1) end)
