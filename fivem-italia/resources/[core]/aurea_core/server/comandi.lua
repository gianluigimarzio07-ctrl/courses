--[[
    AUREA · Registrazione comandi con controllo dei permessi

    AUREA.Comando('nome', 'gruppo_minimo', 'descrizione', { argomenti }, fn)
    Il gruppo 'utente' rende il comando pubblico.
]]

local C = AUREA.Config
local U = AUREA.Util

local registrati = {}

function AUREA.Comando(nome, gruppo, descrizione, argomenti, fn)
    registrati[nome] = { gruppo = gruppo, descrizione = descrizione }

    RegisterCommand(nome, function(src, args, raw)
        if src == 0 then
            -- console: consentito solo per comandi di gestione
            return fn(0, args, raw, nil)
        end

        if gruppo ~= 'utente' and not AUREA.HaGruppo(src, gruppo) then
            TriggerClientEvent('aurea:ui:notifica', src, {
                tipo = 'errore', titolo = 'Permesso negato',
                testo = 'Non hai i permessi per questo comando.',
            })
            AUREA.Log('anticheat', 'avviso', src, ('comando negato: /%s'):format(nome))
            return
        end

        local g = AUREA.GetPlayer(src)
        fn(src, args, raw, g)
    end, false)

    TriggerClientEvent('chat:addSuggestion', -1, '/' .. nome, descrizione, argomenti or {})
    AddEventHandler('aurea:giocatore:caricato', function(src)
        TriggerClientEvent('chat:addSuggestion', src, '/' .. nome, descrizione, argomenti or {})
    end)
end

exports('Comando', AUREA.Comando)

local function notifica(src, tipo, titolo, testo)
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = tipo, titolo = titolo, testo = testo })
end

-- ---------------------------------------------------------------------------
--  Comandi pubblici
-- ---------------------------------------------------------------------------

AUREA.Comando('id', 'utente', 'Mostra il tuo codice cittadino', {}, function(src, _, _, g)
    if not g then return end
    notifica(src, 'info', 'Documento', ('%s · CF %s · Tel. %s'):format(g:NomeCompleto(), g.cf, g.telefono))
end)

AUREA.Comando('contanti', 'utente', 'Mostra i contanti in tasca', {}, function(src, _, _, g)
    if not g then return end
    notifica(src, 'info', 'Portafoglio', U.Euro(g.denaro.contanti))
end)

AUREA.Comando('dai', 'utente', 'Consegna contanti alla persona più vicina', {
    { name = 'importo', help = 'Euro (es. 50 oppure 12.50)' },
}, function(src, args, _, g)
    if not g then return end
    local euro = tonumber((args[1] or ''):gsub(',', '.'))
    if not euro or euro <= 0 then return notifica(src, 'errore', 'Importo non valido', 'Esempio: /dai 25.50') end

    local ped = GetPlayerPed(src)
    local origine = GetEntityCoords(ped)
    local vicino, distanzaMin = nil, 3.0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= src then
            local d = #(origine - GetEntityCoords(GetPlayerPed(altro.source)))
            if d < distanzaMin then vicino, distanzaMin = altro, d end
        end
    end
    if not vicino then return notifica(src, 'errore', 'Nessuno vicino', 'Avvicinati alla persona.') end

    TriggerEvent('aurea:denaro:consegna', vicino.source, U.ACentesimi(euro))
end)

AUREA.Comando('servizio', 'utente', 'Entra o esci dal servizio', {}, function(src, _, _, g)
    if not g then return end
    local l = AUREA.GetLavoro(g.lavoro.nome)
    if not l.servizio then return notifica(src, 'errore', 'Non disponibile', 'Il tuo lavoro non prevede turni di servizio.') end

    g:ImpostaServizio(not g.lavoro.servizio)
    notifica(src, g.lavoro.servizio and 'successo' or 'info',
        g.lavoro.servizio and 'In servizio' or 'Fuori servizio',
        AUREA.EtichettaLavoro(g.lavoro.nome, g.lavoro.grado))
end)

-- ---------------------------------------------------------------------------
--  Comandi staff
-- ---------------------------------------------------------------------------

AUREA.Comando('dammi', 'gestore', 'Accredita denaro a un giocatore', {
    { name = 'id', help = 'ID sessione' },
    { name = 'conto', help = 'contanti | banca' },
    { name = 'euro', help = 'Importo in euro' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local conto = args[2]
    local euro = tonumber((args[3] or ''):gsub(',', '.'))
    if not bersaglio or (conto ~= 'contanti' and conto ~= 'banca') or not euro then
        return notifica(src, 'errore', 'Uso', '/dammi <id> <contanti|banca> <euro>')
    end
    bersaglio:Aggiungi(conto, U.ACentesimi(euro), 'accredito staff')
    notifica(src, 'successo', 'Fatto', ('%s accreditati a %s'):format(U.Euro(U.ACentesimi(euro)), bersaglio:NomeCompleto()))
    AUREA.Log('staff', 'avviso', src, ('accredito staff di %s a %s'):format(U.Euro(U.ACentesimi(euro)), bersaglio.citizenid))
end)

AUREA.Comando('setlavoro', 'admin', 'Assegna un lavoro a un giocatore', {
    { name = 'id', help = 'ID sessione' },
    { name = 'lavoro', help = 'Nome interno del lavoro' },
    { name = 'grado', help = 'Grado numerico' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    if not bersaglio then return notifica(src, 'errore', 'Uso', '/setlavoro <id> <lavoro> <grado>') end
    if not AUREA.Lavori[args[2]] then
        local elenco = {}
        for nome in pairs(AUREA.Lavori) do elenco[#elenco + 1] = nome end
        table.sort(elenco)
        return notifica(src, 'errore', 'Lavoro sconosciuto', table.concat(elenco, ', '))
    end
    bersaglio:ImpostaLavoro(args[2], tonumber(args[3]) or 0)
    notifica(src, 'successo', 'Fatto', ('%s → %s'):format(bersaglio:NomeCompleto(), AUREA.EtichettaLavoro(args[2], tonumber(args[3]) or 0)))
end)

AUREA.Comando('tp', 'moderatore', 'Teletrasporta al marker o a un giocatore', {
    { name = 'id', help = 'ID sessione (facoltativo)' },
}, function(src, args)
    local bersaglio = tonumber(args[1])
    if bersaglio and AUREA.GetPlayer(bersaglio) then
        local coord = GetEntityCoords(GetPlayerPed(bersaglio))
        TriggerClientEvent('aurea:admin:teletrasporta', src, { x = coord.x, y = coord.y, z = coord.z })
    else
        TriggerClientEvent('aurea:admin:teletrasportaMarker', src)
    end
end)

AUREA.Comando('portami', 'moderatore', 'Porta un giocatore da te', {
    { name = 'id', help = 'ID sessione' },
}, function(src, args)
    local bersaglio = tonumber(args[1])
    if not bersaglio or not AUREA.GetPlayer(bersaglio) then return notifica(src, 'errore', 'Uso', '/portami <id>') end
    local coord = GetEntityCoords(GetPlayerPed(src))
    TriggerClientEvent('aurea:admin:teletrasporta', bersaglio, { x = coord.x, y = coord.y, z = coord.z })
    AUREA.Log('staff', 'avviso', src, ('ha teletrasportato da sé il giocatore %s'):format(bersaglio))
end)

AUREA.Comando('salvatutti', 'admin', 'Forza il salvataggio di tutti i personaggi', {}, function(src)
    local n = 0
    for _, g in pairs(AUREA.Giocatori) do
        pcall(function() g:Salva() end)
        n = n + 1
    end
    notifica(src, 'successo', 'Salvataggio completato', ('%d personaggi salvati.'):format(n))
end)

AUREA.Comando('online', 'utente', 'Mostra i giocatori collegati', {}, function(src)
    local righe = {}
    for _, g in pairs(AUREA.Giocatori) do
        righe[#righe + 1] = ('[%d] %s'):format(g.source, g:NomeCompleto())
    end
    table.sort(righe)
    notifica(src, 'info', ('Online: %d'):format(#righe), #righe > 0 and table.concat(righe, ' · ') or 'Nessuno.')
end)
