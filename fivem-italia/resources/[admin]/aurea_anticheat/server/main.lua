--[[
    AUREA · Protezioni (server)

    Nessuna di queste misure sostituisce la buona architettura: il vero
    presidio è che ogni operazione sensibile è già validata dal modulo che
    la esegue. Qui si intercetta ciò che resta.
]]

local U = AUREA.Util
local sospetti = {}      -- [src] = { punteggio, ultimi = {} }

-- ---------------------------------------------------------------------------
--  Punteggio di sospetto
-- ---------------------------------------------------------------------------
local SOGLIA_AVVISO = 30
local SOGLIA_ESPULSIONE = 70

local function segnala(src, punti, motivo, dati)
    local g = AUREA.GetPlayer(src)
    sospetti[src] = sospetti[src] or { punteggio = 0, ultimi = {} }
    local s = sospetti[src]

    s.punteggio = s.punteggio + punti
    s.ultimi[#s.ultimi + 1] = motivo
    if #s.ultimi > 10 then table.remove(s.ultimi, 1) end

    AUREA.Log('anticheat', s.punteggio >= SOGLIA_AVVISO and 'allarme' or 'avviso', src,
        ('%s (+%d, totale %d)'):format(motivo, punti, s.punteggio), dati)

    -- Lo staff online viene informato quando il punteggio supera la soglia
    if s.punteggio >= SOGLIA_AVVISO and not s.avvisato then
        s.avvisato = true
        for altroSrc in pairs(AUREA.Giocatori) do
            if AUREA.HaGruppo(altroSrc, 'moderatore') then
                TriggerClientEvent('aurea:ui:notifica', altroSrc, {
                    tipo = 'errore', icona = '🛡', durata = 16000,
                    titolo = 'Anomalia rilevata',
                    testo = ('[%d] %s\n%s'):format(src, g and g:NomeCompleto() or GetPlayerName(src) or '?', motivo),
                })
            end
        end
    end

    if s.punteggio >= SOGLIA_ESPULSIONE then
        local riepilogo = table.concat(s.ultimi, '; ')
        AUREA.Log('anticheat', 'allarme', src, ('espulsione automatica: %s'):format(riepilogo))
        MySQL.insert('INSERT INTO sanzioni_admin (license, citizenid, tipo, motivo, staff) VALUES (?, ?, ?, ?, ?)', {
            g and g.license or 'sconosciuta', g and g.citizenid or nil,
            'kick', ('Rilevamento automatico: %s'):format(riepilogo), 'anticheat',
        })
        DropPlayer(src, 'Attività anomala rilevata. Se ritieni si tratti di un errore, apri un ticket sul Discord.')
    end
end

exports('Segnala', segnala)

-- Il punteggio decade nel tempo: un falso positivo non resta per sempre
CreateThread(function()
    while true do
        Wait(120000)
        for src, s in pairs(sospetti) do
            s.punteggio = math.max(0, s.punteggio - 5)
            if s.punteggio < SOGLIA_AVVISO then s.avvisato = false end
            if s.punteggio == 0 then sospetti[src] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Eventi vietati: i trigger dei framework più diffusi non esistono qui
-- ---------------------------------------------------------------------------
local EVENTI_VIETATI = {
    'esx:getSharedObject', 'esx:setJob', 'esx:addInventoryItem', 'esx_society:',
    'QBCore:', 'qb-', 'bank:', 'AdminMenu:', 'Server_Give', 'DiscordBot:',
}

AddEventHandler('__cfx_internal:commandFallback', function(comando)
    local src = source
    if src == 0 then return end

    -- Comandi tipici dei menu di cheat
    local sospetto = comando:match('^spawn') or comando:match('^giveitem')
        or comando:match('^setmoney') or comando:match('^godmode')
    if sospetto then
        segnala(src, 15, ('comando non riconosciuto: /%s'):format(comando:sub(1, 40)))
    end
    CancelEvent()
end)

-- ---------------------------------------------------------------------------
--  Protezione entità: chi crea un veicolo deve avere titolo per farlo
-- ---------------------------------------------------------------------------
AddEventHandler('entityCreating', function(entita)
    local tipo = GetEntityType(entita)
    if tipo ~= 2 then return end   -- solo veicoli

    local proprietario = NetworkGetEntityOwner(entita)
    if not proprietario or proprietario == 0 then return end

    local g = AUREA.GetPlayer(proprietario)
    if not g then return end

    -- Le risorse del server dichiarano gli spawn legittimi
    if GetPlayerRoutingBucket(proprietario) ~= 0 then return end

    local statoSpawn = Player(proprietario).state.spawnAutorizzato
    if statoSpawn and (os.time() - statoSpawn) < 12 then return end

    -- Un veicolo comparso senza autorizzazione è sospetto, ma non blocchiamo
    -- il gioco: si registra e si lascia allo staff la valutazione.
    segnala(proprietario, 6, ('spawn veicolo non dichiarato: %s'):format(GetEntityModel(entita)))
end)

--- Le risorse legittime dichiarano lo spawn prima di crearlo.
local function autorizzaSpawn(src)
    Player(src).state:set('spawnAutorizzato', os.time(), false)
end
exports('AutorizzaSpawn', autorizzaSpawn)

RegisterNetEvent('aurea:anticheat:autorizzaSpawn', function()
    autorizzaSpawn(source)
end)

-- ---------------------------------------------------------------------------
--  Movimento implausibile
-- ---------------------------------------------------------------------------
local ultimePosizioni = {}

CreateThread(function()
    while true do
        Wait(3000)

        for src, g in pairs(AUREA.Giocatori) do
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 then
                local coord = GetEntityCoords(ped)
                local precedente = ultimePosizioni[src]

                if precedente then
                    local distanza = #(coord - precedente.coord)
                    local secondi = os.time() - precedente.momento
                    if secondi > 0 then
                        local velocita = (distanza / secondi) * 3.6

                        -- Oltre 450 km/h nessun veicolo di terra è plausibile.
                        -- Aerei ed elicotteri sono esclusi dal controllo.
                        local veicolo = GetVehiclePedIsIn(src, false)
                        local classe = veicolo ~= 0 and GetVehicleClass(veicolo) or -1
                        local inVolo = classe == 15 or classe == 16

                        if velocita > 450 and not inVolo and not exports.aurea_admin:InServizioStaff(src) then
                            segnala(src, 12, ('movimento implausibile: %.0f km/h'):format(velocita),
                                { distanza = distanza, secondi = secondi })
                        end
                    end
                end

                ultimePosizioni[src] = { coord = coord, momento = os.time() }
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Salute e armatura fuori scala
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(10000)

        for src in pairs(AUREA.Giocatori) do
            if not exports.aurea_admin:InServizioStaff(src) then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local salute = GetEntityHealth(ped)
                    local armatura = GetPedArmour(ped)

                    if salute > 210 then
                        segnala(src, 20, ('salute fuori scala: %d'):format(salute))
                        SetEntityHealth(ped, 200)
                    end
                    if armatura > 105 then
                        segnala(src, 15, ('armatura fuori scala: %d'):format(armatura))
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Integrità delle risorse client
-- ---------------------------------------------------------------------------
RegisterNetEvent('aurea:anticheat:risorse', function(elenco)
    local src = source
    if type(elenco) ~= 'table' then return end

    local attese = {}
    for i = 0, GetNumResources() - 1 do
        local nome = GetResourceByFindIndex(i)
        if nome and GetResourceState(nome) == 'started' then attese[nome] = true end
    end

    for _, nome in ipairs(elenco) do
        if not attese[nome] then
            segnala(src, 25, ('risorsa client non prevista: %s'):format(tostring(nome):sub(1, 40)))
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Blocco degli eventi dei framework non installati
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, prefisso in ipairs(EVENTI_VIETATI) do
        RegisterNetEvent(prefisso)
        AddEventHandler(prefisso, function()
            local src = source
            if src == 0 then return end
            segnala(src, 35, ('evento di framework estraneo: %s'):format(prefisso))
            CancelEvent()
        end)
    end
end)

AddEventHandler('playerDropped', function()
    sospetti[source] = nil
    ultimePosizioni[source] = nil
end)

AUREA.Comando('sospetti', 'moderatore', 'Elenca i giocatori con anomalie registrate', {}, function(src)
    local righe = {}
    for altroSrc, s in pairs(sospetti) do
        if s.punteggio > 0 then
            local g = AUREA.GetPlayer(altroSrc)
            righe[#righe + 1] = ('[%d] %s — %d punti (%s)'):format(
                altroSrc, g and g:NomeCompleto() or '?', s.punteggio, s.ultimi[#s.ultimi] or '')
        end
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = #righe > 0 and 'avviso' or 'successo',
        icona = '🛡', durata = 18000,
        titolo = ('%d giocatori segnalati'):format(#righe),
        testo = #righe > 0 and table.concat(righe, '\n') or 'Nessuna anomalia in corso.',
    })
end)
