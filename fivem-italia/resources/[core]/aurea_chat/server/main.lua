--[[
    AUREA · Chat di ruolo (server)

    La distanza la calcola sempre il server: un client manomesso non può
    farsi sentire dall'altra parte della mappa.
]]

local U = AUREA.Util
local traffico = {}       -- [src] = { conteggio, azzeramento, silenziatoFino }

-- ---------------------------------------------------------------------------
--  Limitazione di frequenza
-- ---------------------------------------------------------------------------
local function puoParlare(src)
    local adesso = os.time()
    local t = traffico[src]

    if not t then
        traffico[src] = { conteggio = 1, azzeramento = adesso + 60 }
        return true
    end

    if t.silenziatoFino and adesso < t.silenziatoFino then
        return false, math.ceil(t.silenziatoFino - adesso)
    end

    if adesso >= t.azzeramento then
        t.conteggio, t.azzeramento = 1, adesso + 60
        return true
    end

    t.conteggio = t.conteggio + 1
    if t.conteggio > CHAT.Regole.messaggiAlMinuto then
        t.silenziatoFino = adesso + CHAT.Regole.silenziamento
        AUREA.Log('staff', 'avviso', src, 'silenziato automaticamente per eccesso di messaggi')
        return false, CHAT.Regole.silenziamento
    end

    return true
end

-- ---------------------------------------------------------------------------
--  Invio di un messaggio a chi è nel raggio
-- ---------------------------------------------------------------------------

--- Restituisce le sessioni entro la distanza indicata dal mittente.
local function ascoltatori(src, portata)
    local origine = GetEntityCoords(GetPlayerPed(src))
    local out = {}

    for altroSrc in pairs(AUREA.Giocatori) do
        local d = #(origine - GetEntityCoords(GetPlayerPed(altroSrc)))
        if d <= portata then out[#out + 1] = altroSrc end
    end

    return out
end

--- Recapita un messaggio su un canale.
---@param src number mittente
---@param canale string chiave di CHAT.Canali
---@param testo string
---@param nomeSovrascritto string|nil  per i canali che non usano il nome del pg
local function recapita(src, canale, testo, nomeSovrascritto)
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local cfg = CHAT.Canali[canale]
    if not cfg then return end

    testo = tostring(testo or ''):sub(1, CHAT.Regole.lunghezzaMassima)
    if #testo == 0 then return end

    local consentito, attesa = puoParlare(src)
    if not consentito then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Stai scrivendo troppo',
            testo = ('Riprova fra %d secondi.'):format(attesa or 30),
        })
    end

    local mittente = nomeSovrascritto or g:NomeCompleto()
    local destinatari

    if cfg.portata then
        destinatari = ascoltatori(src, CHAT.Portate[cfg.portata] or 14.0)
    else
        destinatari = { src }
    end

    for _, dest in ipairs(destinatari) do
        TriggerClientEvent('chat:messaggio', dest, {
            canale = canale,
            mittente = mittente,
            testo = testo,
            etichetta = cfg.etichetta,
            colore = cfg.colore,
            corsivo = cfg.corsivo,
            formato = cfg.formato,
            proprio = dest == src,
        })
    end

    -- Il parlato IC compare anche sopra la testa di chi lo dice
    if CHAT.Regole.testoSopraTesta and cfg.portata and canale ~= 'ooc' then
        for _, dest in ipairs(destinatari) do
            TriggerClientEvent('chat:sopraTesta', dest, src, testo, canale)
        end
    end

    if CHAT.Regole.registraSuDatabase then
        AUREA.Log('chat', 'debug', g, ('[%s] %s'):format(canale, testo))
    end

    return #destinatari
end

exports('Recapita', recapita)

-- ---------------------------------------------------------------------------
--  Parlato normale
-- ---------------------------------------------------------------------------
RegisterNetEvent('chat:parla', function(testo, canale)
    local src = source
    canale = (canale == 'grido' or canale == 'sussurro') and canale or 'normale'

    local g = AUREA.GetPlayer(src)
    if not g then return end

    -- Chi è incosciente non parla
    if g:Get('ferito') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non puoi parlare', testo = 'Sei privo di sensi.',
        })
    end

    recapita(src, canale, testo)
end)

-- ---------------------------------------------------------------------------
--  Comandi di ruolo
-- ---------------------------------------------------------------------------
AUREA.Comando('me', 'utente', 'Descrive una tua azione', {
    { name = 'azione', help = 'Es. si accende una sigaretta' },
}, function(src, args, _, g)
    if not g then return end
    local n = recapita(src, 'me', table.concat(args, ' '))
    if n == 0 then
        TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'info', titolo = 'Nessuno intorno', testo = 'Non c\'è nessuno che possa vederti.' })
    end
end)

AUREA.Comando('fai', 'utente', 'Descrive l\'ambiente o un dettaglio', {
    { name = 'descrizione', help = 'Es. l\'odore di bruciato riempie la stanza' },
}, function(src, args, _, g)
    if not g then return end
    recapita(src, 'fai', table.concat(args, ' '))
end)

AUREA.Comando('ooc', 'utente', 'Messaggio fuori personaggio a chi è vicino', {
    { name = 'testo', help = 'Messaggio' },
}, function(src, args, _, g)
    if not g then return end
    recapita(src, 'ooc', table.concat(args, ' '))
end)

AUREA.Comando('grida', 'utente', 'Grida un messaggio', {
    { name = 'testo', help = 'Messaggio' },
}, function(src, args, _, g)
    if not g then return end
    recapita(src, 'grido', table.concat(args, ' '))
end)

AUREA.Comando('sussurra', 'utente', 'Sussurra a chi ti sta accanto', {
    { name = 'testo', help = 'Messaggio' },
}, function(src, args, _, g)
    if not g then return end
    recapita(src, 'sussurro', table.concat(args, ' '))
end)

-- ---------------------------------------------------------------------------
--  Tentativi e dadi: risolvono le situazioni incerte senza litigare
-- ---------------------------------------------------------------------------
AUREA.Comando('tentativo', 'utente', 'Tenta un\'azione dall\'esito incerto', {
    { name = 'azione', help = 'Es. scassinare la serratura' },
}, function(src, args, _, g)
    if not g then return end

    local azione = table.concat(args, ' ')
    if #azione < 3 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = '/tentativo <cosa stai provando a fare>',
        })
    end

    local riuscito = math.random(100) <= 50
    recapita(src, 'tentativo',
        ('%s — %s'):format(azione, riuscito and 'RIUSCITO' or 'FALLITO'),
        g:NomeCompleto())
end)

AUREA.Comando('dado', 'utente', 'Tira un dado', {
    { name = 'facce', help = 'Numero di facce (predefinito 100)' },
}, function(src, args, _, g)
    if not g then return end

    local facce = math.floor(U.Clamp(tonumber(args[1]) or 100, 2, 1000))
    local esito = math.random(facce)

    recapita(src, 'tentativo', ('tira un dado a %d facce: %d'):format(facce, esito), g:NomeCompleto())
end)

-- ---------------------------------------------------------------------------
--  Radio di servizio
--
--  Sintonizzarsi è /radio, e lo gestisce aurea_voce: è lì che sta
--  l'apparecchio, il controllo sulle frequenze riservate e il canale di
--  pma-voice. Qui c'è solo il testo, che va sulla stessa frequenza della
--  voce — perché è la stessa radio.
--
--  Prima erano due elenchi separati e il comando client di aurea_voce
--  copriva quello di qui: uno si sintonizzava, parlava, e i suoi /r non
--  arrivavano a nessuno.
-- ---------------------------------------------------------------------------

--- La frequenza del giocatore secondo aurea_voce, o nil.
local function frequenzaDi(src)
    local ok, f = pcall(function() return exports.aurea_voce:FrequenzaDi(src) end)
    return ok and f or nil
end

AUREA.Comando('r', 'utente', 'Trasmette sulla frequenza sintonizzata', {
    { name = 'testo', help = 'Messaggio radio' },
}, function(src, args, _, g)
    if not g then return end

    local frequenza = frequenzaDi(src)
    if not frequenza then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📻', titolo = 'Radio spenta', testo = 'Sintonizzati con /radio <frequenza>.',
        })
    end

    if CHAT.Radio.richiedeApparecchio and not exports.aurea_inventory:Ha(g.citizenid, 'radio', 1) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📻', titolo = 'Apparecchio perduto', testo = 'Non hai più la ricetrasmittente.',
        })
    end

    local testo = table.concat(args, ' ')
    if #testo == 0 then return end

    local consentito, attesa = puoParlare(src)
    if not consentito then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Stai trasmettendo troppo',
            testo = ('Riprova fra %d secondi.'):format(attesa or 30),
        })
    end

    local cfg = CHAT.Canali.radio
    local ok, ascolto = pcall(function() return exports.aurea_voce:SintonizzatiSu(frequenza) end)

    for _, altroSrc in ipairs(ok and ascolto or { src }) do
        if AUREA.GetPlayer(altroSrc) then
            TriggerClientEvent('chat:messaggio', altroSrc, {
                canale = 'radio',
                mittente = ('%0.1f · %s'):format(frequenza, g:NomeCompleto()),
                testo = testo:sub(1, CHAT.Regole.lunghezzaMassima),
                etichetta = cfg.etichetta,
                colore = cfg.colore,
                proprio = altroSrc == src,
            })
        end
    end
end)

--- Comunicazione interna di un ente, senza bisogno di apparecchio.
AUREA.Comando('d', 'utente', 'Comunicazione interna dell\'ente di appartenenza', {
    { name = 'testo', help = 'Messaggio di servizio' },
}, function(src, args, _, g)
    if not g then return end

    local l = AUREA.GetLavoro(g.lavoro.nome)
    if not l.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non disponibile', testo = 'Il tuo lavoro non ha un canale di servizio.',
        })
    end
    if not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Fuori servizio', testo = 'Entra in servizio con /servizio.',
        })
    end

    local testo = table.concat(args, ' ')
    if #testo == 0 then return end

    local cfg = CHAT.Canali.servizio
    for _, collega in ipairs(AUREA.GetGiocatoriPerLavoro(g.lavoro.nome, true)) do
        TriggerClientEvent('chat:messaggio', collega.source, {
            canale = 'servizio',
            mittente = ('%s %s'):format(AUREA.GetGrado(g.lavoro.nome, g.lavoro.grado).etichetta, g:NomeCompleto()),
            testo = testo:sub(1, CHAT.Regole.lunghezzaMassima),
            etichetta = cfg.etichetta,
            colore = cfg.colore,
            proprio = collega.source == src,
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Moderazione
-- ---------------------------------------------------------------------------
AUREA.Comando('silenzia', 'moderatore', 'Silenzia un giocatore in chat', {
    { name = 'id', help = 'ID sessione' },
    { name = 'minuti', help = 'Durata' },
}, function(src, args)
    local bersaglio = tonumber(args[1])
    local minuti = tonumber(args[2]) or 10

    if not bersaglio or not AUREA.GetPlayer(bersaglio) then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/silenzia <id> <minuti>' })
    end

    traffico[bersaglio] = traffico[bersaglio] or { conteggio = 0, azzeramento = os.time() + 60 }
    traffico[bersaglio].silenziatoFino = os.time() + minuti * 60

    TriggerClientEvent('aurea:ui:notifica', bersaglio, {
        tipo = 'errore', titolo = 'Sei stato silenziato',
        testo = ('Non potrai scrivere in chat per %d minuti.'):format(minuti),
    })
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Silenziato', testo = ('ID %d per %d minuti.'):format(bersaglio, minuti),
    })
    AUREA.Log('staff', 'avviso', src, ('ha silenziato %d per %d minuti'):format(bersaglio, minuti))
end)

AddEventHandler('playerDropped', function()
    traffico[source] = nil
end)
