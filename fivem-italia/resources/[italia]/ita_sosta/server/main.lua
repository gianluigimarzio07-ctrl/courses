--[[
    AUREA · Sosta a pagamento (server)
]]

local U = AUREA.Util
local soste = {}        -- [targa] = { zona, scade, citizenid }
local sanzionati = {}   -- [targa] = os.time()

local function attiva(targa)
    local s = soste[targa]
    if not s then return nil end
    if os.time() > s.scade then soste[targa] = nil return nil end
    return s
end

exports('SostaValida', function(targa, zona)
    local s = attiva(tostring(targa or ''):upper())
    return s ~= nil and (not zona or s.zona == zona)
end)

-- ---------------------------------------------------------------------------
--  Parcometro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sos:parcometro', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local p = SOS.ParcometroVicino(coord)
    if not p then return rispondi(nil, 'Non sei a un parcometro.') end

    local zona
    for _, z in ipairs(SOS.Zone) do if z.id == p.zona then zona = z end end
    if not zona then return rispondi(nil) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local s = attiva(targa)

    local ora = tonumber(os.date('%H'))
    local giorno = tonumber(os.date('%u'))
    local gratuita = SOS.Gratuita(ora, giorno)

    local pass = MySQL.scalar.await([[
        SELECT id FROM sosta_pass
        WHERE citizenid = ? AND zona = ? AND scadenza >= CURDATE()
    ]], { g.citizenid, zona.id })

    rispondi({
        zona = zona.nome, idZona = zona.id,
        tariffa = zona.tariffaOraria,
        frazione = SOS.Tariffe.frazioneMinuti,
        oreMassime = SOS.Tariffe.oreMassime,
        gratuita = gratuita,
        haPass = pass ~= nil,
        costoPass = SOS.Regole.costoPass,
        sostaAttiva = s and math.floor((s.scade - os.time()) / 60) or nil,
        targa = targa,
    })
end)

AUREA.Callback.Registra('sos:paga', function(src, rispondi, targa, minuti)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local p = SOS.ParcometroVicino(GetEntityCoords(GetPlayerPed(src)))
    if not p then return rispondi(false, 'Non sei a un parcometro.') end

    local zona
    for _, z in ipairs(SOS.Zone) do if z.id == p.zona then zona = z end end
    if not zona then return rispondi(false) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    if targa == '' then return rispondi(false, 'Targa non valida.') end

    minuti = math.floor(U.Clamp(tonumber(minuti) or SOS.Tariffe.frazioneMinuti,
        SOS.Tariffe.frazioneMinuti, SOS.Tariffe.oreMassime * 60))

    -- Si arrotonda alla frazione superiore, come i parcometri veri
    local frazioni = math.ceil(minuti / SOS.Tariffe.frazioneMinuti)
    minuti = frazioni * SOS.Tariffe.frazioneMinuti
    local costo = math.floor(zona.tariffaOraria * (minuti / 60))

    if not g:SottraiOvunque(costo, ('sosta · %s'):format(zona.nome)) then
        return rispondi(false, ('Servono %s per %d minuti.'):format(U.Euro(costo), minuti))
    end

    TriggerEvent('aurea:fisco:incasso', 'sosta', costo, g.citizenid)

    local esistente = attiva(targa)
    local base = esistente and esistente.scade or os.time()
    soste[targa] = { zona = zona.id, scade = base + minuti * 60, citizenid = g.citizenid }

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, SOS.Regole.tagliando, 1, {
        targa = targa, zona = zona.nome,
        scade = os.date('%H:%M', soste[targa].scade),
    })

    rispondi(true, ('Sosta pagata fino alle %s per %s. Esponi il tagliando.')
        :format(os.date('%H:%M', soste[targa].scade), targa))
end)

AUREA.Callback.Registra('sos:pass', function(src, rispondi, idZona)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if not SOS.Regole.passResidenti then return rispondi(false, 'I pass non sono previsti.') end

    -- Il pass si dà a chi risiede lì
    local residenza = g:Get('residenza')
    if not residenza then
        return rispondi(false, 'Serve la residenza, che si trasferisce al Comune.')
    end

    if not g:SottraiOvunque(SOS.Regole.costoPass, 'pass residenti') then
        return rispondi(false, ('Il pass costa %s.'):format(U.Euro(SOS.Regole.costoPass)))
    end
    TriggerEvent('aurea:fisco:incasso', 'sosta', SOS.Regole.costoPass, g.citizenid)

    MySQL.query.await([[
        INSERT INTO sosta_pass (citizenid, zona, scadenza)
        VALUES (?, ?, DATE_ADD(CURDATE(), INTERVAL ? DAY))
        ON DUPLICATE KEY UPDATE scadenza = VALUES(scadenza)
    ]], { g.citizenid, idZona, SOS.Regole.validitaPassGiorni })

    rispondi(true, ('Pass residenti attivo per %d giorni.'):format(SOS.Regole.validitaPassGiorni))
end)

-- ---------------------------------------------------------------------------
--  Ausiliario del traffico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sos:verifica', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if g.lavoro.nome ~= SOS.Lavoro or not g.lavoro.servizio then
        return rispondi(nil, 'Non sei in servizio.')
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local coord = GetEntityCoords(GetPlayerPed(src))
    local zona = SOS.ZonaDi(coord)
    if not zona then return rispondi(nil, 'Non sei in una zona a sosta regolamentata.') end

    local ora = tonumber(os.date('%H'))
    local giorno = tonumber(os.date('%u'))
    if SOS.Gratuita(ora, giorno) then
        return rispondi({ regolare = true }, 'In questa fascia la sosta è libera.')
    end

    local s = attiva(targa)
    if s and s.zona == zona.id then
        return rispondi({ regolare = true, scade = os.date('%H:%M', s.scade) },
            ('Titolo valido fino alle %s.'):format(os.date('%H:%M', s.scade)))
    end

    local proprietario = MySQL.scalar.await('SELECT citizenid FROM veicoli WHERE targa = ?', { targa })
    if proprietario then
        local pass = MySQL.scalar.await([[
            SELECT id FROM sosta_pass WHERE citizenid = ? AND zona = ? AND scadenza >= CURDATE()
        ]], { proprietario, zona.id })
        if pass then
            return rispondi({ regolare = true }, 'Il veicolo espone un pass residenti valido.')
        end
    end

    local ultima = sanzionati[targa]
    if ultima and (os.time() - ultima) < SOS.Sanzione.minutiFraSanzioni * 60 then
        return rispondi({ regolare = false, giaSanzionato = true },
            'Già sanzionato di recente: non si può rimultare adesso.')
    end

    rispondi({ regolare = false, zona = zona.nome, importo = SOS.Sanzione.importo,
               proprietario = proprietario },
        'Nessun titolo di sosta valido.')
end)

AUREA.Callback.Registra('sos:sanziona', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= SOS.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio.')
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local zona = SOS.ZonaDi(GetEntityCoords(GetPlayerPed(src)))
    if not zona then return rispondi(false, 'Fuori zona.') end

    if attiva(targa) then return rispondi(false, 'Il veicolo ha un titolo valido.') end

    local ultima = sanzionati[targa]
    if ultima and (os.time() - ultima) < SOS.Sanzione.minutiFraSanzioni * 60 then
        return rispondi(false, 'Già sanzionato di recente.')
    end

    local proprietario = MySQL.scalar.await('SELECT citizenid FROM veicoli WHERE targa = ?', { targa })
    if not proprietario then return rispondi(false, 'Veicolo non immatricolato: non si può notificare.') end

    sanzionati[targa] = os.time()

    MySQL.insert.await([[
        INSERT INTO multe (citizenid, targa, articolo, descrizione, importo, punti, agente, stato)
        VALUES (?, ?, ?, ?, ?, 0, ?, 'da_pagare')
    ]], {
        proprietario, targa, SOS.Sanzione.articolo, SOS.Sanzione.descrizione,
        SOS.Sanzione.importo, g:NomeCompleto(),
    })

    -- All'ausiliario spetta una quota, il resto va al Comune
    local quota = math.floor(SOS.Sanzione.importo * SOS.Sanzione.quotaAusiliario)
    g:Aggiungi('banca', quota, 'quota su verbale di sosta')

    local intestatario = AUREA.GetPlayerByCitizenId(proprietario)
    if intestatario then
        TriggerClientEvent('aurea:ui:notifica', intestatario.source, {
            tipo = 'errore', icona = '🅿', durata = 15000,
            titolo = 'Preavviso di accertamento',
            testo = ('%s in %s: %s. %s. Lo trovi in /multe.')
                :format(targa, zona.nome, SOS.Sanzione.descrizione, U.Euro(SOS.Sanzione.importo)),
        })
    end

    AUREA.Log('veicoli', 'debug', g, ('preavviso di sosta a %s in %s'):format(targa, zona.nome))
    rispondi(true, ('Preavviso elevato: %s. La tua quota è %s.')
        :format(U.Euro(SOS.Sanzione.importo), U.Euro(quota)))
end)

--- Le soste scadute si dimenticano.
CreateThread(function()
    while true do
        Wait(600000)
        local adesso = os.time()
        for targa, s in pairs(soste) do
            if adesso > s.scade + 1800 then soste[targa] = nil end
        end
        for targa, quando in pairs(sanzionati) do
            if adesso - quando > 7200 then sanzionati[targa] = nil end
        end
    end
end)
