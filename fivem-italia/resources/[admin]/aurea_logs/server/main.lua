--[[
    AUREA · Registro su Discord

    I webhook non stanno nel codice: si leggono dalle convar impostate in
    server.cfg (setr aurea_webhook_denaro "https://..."), così il repository
    resta pubblicabile senza esporre segreti.

    Il recapito è accodato e limitato in frequenza: Discord accetta al massimo
    una manciata di richieste al secondo per webhook, e un server pieno
    genera molti più eventi di così.
]]

local U = AUREA.Util

local coda = {}          -- [canale] = { messaggi in attesa }
local ultimoInvio = {}   -- [canale] = timestamp

local INTERVALLO_MINIMO = 2000    -- ms fra due invii sullo stesso canale
local MASSIMO_PER_LOTTO = 8       -- righe accorpate in un solo messaggio

local COLORI = {
    debug   = 0x6B7280,
    info    = 0x3D8BFD,
    avviso  = 0xD4AF37,
    allarme = 0xCF2E2E,
}

local ICONE = {
    connessioni = '🚪', denaro = '💶', inventario = '🎒', veicoli = '🚗',
    multe = '📄', giustizia = '⚖', anticheat = '🛡', staff = '🛠', economia = '📊',
}

--- Legge il webhook del canale dalle convar.
local function webhookDi(canale)
    local convar = GetConvar('aurea_webhook_' .. canale, '')
    if convar ~= '' then return convar end

    local configurato = AUREA.Config.Log.canali[canale]
    return (configurato and configurato ~= '') and configurato or nil
end

--- Accoda una riga di log.
local function accoda(canale, livello, citizenid, messaggio, dati)
    if not webhookDi(canale) then return end

    coda[canale] = coda[canale] or {}
    local righe = coda[canale]

    righe[#righe + 1] = {
        livello = livello,
        testo = ('%s%s'):format(citizenid and ('`' .. citizenid .. '` ') or '', messaggio),
        dati = dati,
        momento = os.date('%H:%M:%S'),
    }

    -- La coda non cresce all'infinito: le righe più vecchie decadono
    while #righe > 60 do table.remove(righe, 1) end
end

AddEventHandler('aurea:log', accoda)

--- Invia un lotto di righe come singolo embed.
local function inviaLotto(canale, righe)
    local url = webhookDi(canale)
    if not url then return end

    -- Il livello dell'embed è il più alto presente nel lotto
    local livello = 'debug'
    local ordine = { debug = 1, info = 2, avviso = 3, allarme = 4 }
    for _, r in ipairs(righe) do
        if (ordine[r.livello] or 1) > (ordine[livello] or 1) then livello = r.livello end
    end

    local descrizione = {}
    for _, r in ipairs(righe) do
        descrizione[#descrizione + 1] = ('`%s` %s'):format(r.momento, r.testo)
    end

    local corpo = {
        username = 'AUREA · Registro',
        embeds = { {
            title = ('%s %s'):format(ICONE[canale] or '📋', canale:gsub('^%l', string.upper)),
            description = table.concat(descrizione, '\n'):sub(1, 3800),
            color = COLORI[livello] or COLORI.info,
            footer = { text = ('%s · %d eventi'):format(AUREA.Config.Server.nome, #righe) },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }

    PerformHttpRequest(url, function(codice, _, _)
        if codice ~= 200 and codice ~= 204 then
            print(('[AUREA] webhook %s ha risposto %s'):format(canale, tostring(codice)))
        end
    end, 'POST', json.encode(corpo), { ['Content-Type'] = 'application/json' })
end

-- ---------------------------------------------------------------------------
--  Ciclo di svuotamento
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local adesso = GetGameTimer()

        for canale, righe in pairs(coda) do
            if #righe > 0 and (adesso - (ultimoInvio[canale] or 0)) >= INTERVALLO_MINIMO then
                local lotto = {}
                for _ = 1, math.min(MASSIMO_PER_LOTTO, #righe) do
                    lotto[#lotto + 1] = table.remove(righe, 1)
                end
                ultimoInvio[canale] = adesso
                inviaLotto(canale, lotto)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Pulizia periodica del registro su database
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(300000)
    while true do
        -- I log di debug scadono presto, gli allarmi restano a lungo
        MySQL.update("DELETE FROM registro_eventi WHERE livello = 'debug' AND momento < DATE_SUB(NOW(), INTERVAL 2 DAY)")
        MySQL.update("DELETE FROM registro_eventi WHERE livello = 'info' AND momento < DATE_SUB(NOW(), INTERVAL 14 DAY)")
        MySQL.update("DELETE FROM registro_eventi WHERE livello = 'avviso' AND momento < DATE_SUB(NOW(), INTERVAL 60 DAY)")
        Wait(6 * 3600000)
    end
end)

-- ---------------------------------------------------------------------------
--  Consultazione dal gioco
-- ---------------------------------------------------------------------------
AUREA.Comando('registro', 'admin', 'Consulta gli ultimi eventi di un canale', {
    { name = 'canale', help = 'denaro, veicoli, multe, giustizia, anticheat, staff...' },
    { name = 'quanti', help = 'Numero di righe (max 20)' },
}, function(src, args)
    local canale = args[1]
    local quanti = math.min(20, math.max(1, tonumber(args[2]) or 10))

    if not canale then
        local elenco = {}
        for nome in pairs(AUREA.Config.Log.canali) do elenco[#elenco + 1] = nome end
        table.sort(elenco)
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', titolo = 'Canali disponibili', testo = table.concat(elenco, ', '), durata = 12000,
        })
    end

    local righe = MySQL.query.await([[
        SELECT livello, citizenid, messaggio, momento FROM registro_eventi
        WHERE canale = ? ORDER BY id DESC LIMIT ?
    ]], { canale, quanti }) or {}

    local testo = {}
    for _, r in ipairs(righe) do
        testo[#testo + 1] = ('%s %s%s'):format(
            os.date('%H:%M', math.floor((r.momento or 0) / 1000)),
            r.citizenid and (r.citizenid .. ' ') or '',
            r.messaggio)
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = ICONE[canale] or '📋', durata = 25000,
        titolo = ('Registro · %s'):format(canale),
        testo = #testo > 0 and table.concat(testo, '\n') or 'Nessun evento registrato.',
    })
end)

print('[AUREA] registro avviato · i webhook si configurano con "setr aurea_webhook_<canale>"')
