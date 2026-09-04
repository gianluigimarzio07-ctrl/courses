--[[
    AUREA · Chat di ruolo (client)
    Resa dei messaggi e testo sopra la testa di chi parla.
]]

local sopraTesta = {}      -- [serverId] = { testo, scadenza, canale }

-- ---------------------------------------------------------------------------
--  Resa dei messaggi in chat
-- ---------------------------------------------------------------------------
RegisterNetEvent('chat:messaggio', function(m)
    local corpo

    if m.formato then
        -- /me e /fai hanno una forma propria
        corpo = m.formato:format(m.mittente, m.testo)
    elseif m.etichetta and m.etichetta ~= '' then
        corpo = ('%s %s: %s'):format(m.etichetta, m.mittente, m.testo)
    else
        corpo = ('%s: %s'):format(m.mittente, m.testo)
    end

    TriggerEvent('chat:addMessage', {
        color = m.colore or { 255, 255, 255 },
        multiline = true,
        args = { corpo },
    })

    if m.canale == 'radio' and not m.proprio then
        PlaySoundFrontend(-1, 'Menu_Accept', 'Phone_SoundSet_Default', true)
    end
end)

-- ---------------------------------------------------------------------------
--  Testo sopra la testa
-- ---------------------------------------------------------------------------
RegisterNetEvent('chat:sopraTesta', function(serverId, testo, canale)
    sopraTesta[serverId] = {
        testo = #testo > 70 and (testo:sub(1, 70) .. '...') or testo,
        scadenza = GetGameTimer() + CHAT.Regole.durataTestoSopraTesta,
        canale = canale,
    }
end)

CreateThread(function()
    while true do
        local attesa = 400

        if next(sopraTesta) then
            attesa = 0
            local adesso = GetGameTimer()
            local mioPed = PlayerPedId()
            local miaCoord = GetEntityCoords(mioPed)

            for serverId, dati in pairs(sopraTesta) do
                if adesso > dati.scadenza then
                    sopraTesta[serverId] = nil
                else
                    local giocatore = GetPlayerFromServerId(serverId)
                    if giocatore ~= -1 then
                        local ped = GetPlayerPed(giocatore)
                        local coord = GetEntityCoords(ped)

                        if #(miaCoord - coord) < 20.0 then
                            local cfg = CHAT.Canali[dati.canale] or CHAT.Canali.normale
                            local prefisso = cfg.corsivo and '* ' or ''
                            AUREA.Testo3D(coord.x, coord.y, coord.z + 1.02,
                                prefisso .. dati.testo, 0.32)
                        end
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Parlato: la chat normale diventa parlato di prossimità
-- ---------------------------------------------------------------------------
AddEventHandler('chatMessage', function(_, _, testo)
    CancelEvent()

    if testo:sub(1, 1) == '/' then return end

    -- Il prefisso decide la portata: ! grida, # sussurra
    local primo = testo:sub(1, 1)
    if primo == '!' then
        TriggerServerEvent('chat:parla', testo:sub(2), 'grido')
    elseif primo == '#' then
        TriggerServerEvent('chat:parla', testo:sub(2), 'sussurro')
    else
        TriggerServerEvent('chat:parla', testo, 'normale')
    end
end)

-- ---------------------------------------------------------------------------
--  Promemoria all'ingresso
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(9000)
        TriggerEvent('chat:addMessage', {
            color = { 212, 175, 55 },
            multiline = true,
            args = { 'AUREA',
                'Parla normalmente per farti sentire a pochi metri. ' ..
                'Anteponi ! per gridare, # per sussurrare.\n' ..
                'Usa /me per le tue azioni, /fai per descrivere ciò che sta intorno, ' ..
                '/ooc per parlare fuori personaggio.\n' ..
                'Se un\'azione ha esito incerto, risolvila con /tentativo invece di litigare.' },
        })
    end)
end)
