--[[
    AUREA · Tribunale (server)

    Il processo è un oggetto che vive in memoria per il tempo dell'udienza:
    quello che resta nel database è la sentenza.
]]

local U = AUREA.Util
local udienze = {}      -- [id] = { imputato, capi, rito, giudice, pm, difensore }
local contatore = 0

local function fascicoliAperti(citizenid)
    local righe = MySQL.query.await([[
        SELECT id, reato, articolo, gravita, pena_mesi, ammenda, stato
        FROM casellario
        WHERE citizenid = ? AND stato IN ('indagato','imputato')
        ORDER BY gravita DESC LIMIT ?
    ]], { citizenid, TRI.Regole.capiMassimi }) or {}
    return righe
end

-- ---------------------------------------------------------------------------
--  Apertura dell'udienza
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tri:apri', function(src, rispondi, imputatoSrc)
    local g = AUREA.GetPlayer(src)
    local imputato = AUREA.GetPlayer(tonumber(imputatoSrc))
    if not g or not imputato then return rispondi(false, 'Imputato non trovato.') end

    if g.lavoro.nome ~= TRI.Ruoli.giudice.lavoro then
        return rispondi(false, 'Solo un magistrato può aprire un\'udienza.')
    end

    local coordAula = GetEntityCoords(GetPlayerPed(src))
    if #(coordAula - TRI.Sede.aula) > TRI.Regole.distanzaAula then
        return rispondi(false, 'L\'udienza si tiene in aula.')
    end
    if #(coordAula - GetEntityCoords(GetPlayerPed(imputato.source))) > TRI.Regole.distanzaAula then
        return rispondi(false, 'L\'imputato deve essere presente in aula.')
    end

    for _, u in pairs(udienze) do
        if u.imputato == imputato.citizenid then
            return rispondi(false, 'C\'è già un\'udienza aperta a suo carico.')
        end
    end

    local capi = fascicoliAperti(imputato.citizenid)
    if #capi == 0 then return rispondi(false, 'Non risultano fascicoli pendenti a suo carico.') end

    -- Chi è in aula e che ruolo può ricoprire
    local avvocati = {}
    for altroSrc, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.nome == TRI.Ruoli.avvocato.lavoro
           and #(coordAula - GetEntityCoords(GetPlayerPed(altroSrc))) <= TRI.Regole.distanzaAula then
            avvocati[#avvocati + 1] = { src = altroSrc, nome = altro:NomeCompleto() }
        end
    end

    contatore = contatore + 1
    local id = contatore

    local penaTotale, ammendaTotale = 0, 0
    for _, c in ipairs(capi) do
        penaTotale = penaTotale + (tonumber(c.pena_mesi) or 0)
        ammendaTotale = ammendaTotale + (tonumber(c.ammenda) or 0)
    end

    udienze[id] = {
        id = id,
        imputato = imputato.citizenid,
        nomeImputato = imputato:NomeCompleto(),
        srcImputato = imputato.source,
        giudice = g.citizenid,
        nomeGiudice = g:NomeCompleto(),
        capi = capi,
        pena = penaTotale, ammenda = ammendaTotale,
        aperta = os.time(),
    }

    TriggerClientEvent('tri:convocato', imputato.source, {
        id = id, giudice = g:NomeCompleto(),
        capi = capi, pena = penaTotale, ammenda = ammendaTotale,
        riti = TRI.Riti, avvocati = avvocati,
        onorario = TRI.Regole.onorarioAvvocato,
        onorarioUfficio = TRI.Regole.onorarioUfficio,
    })

    rispondi(true, ('Udienza %d aperta a carico di %s: %d capi, %d mesi richiesti.')
        :format(id, imputato:NomeCompleto(), #capi, penaTotale))
end)

--- L'imputato sceglie il rito e il difensore.
AUREA.Callback.Registra('tri:scegli', function(src, rispondi, id, rito, difensoreSrc)
    local g = AUREA.GetPlayer(src)
    local u = udienze[id]
    if not g or not u then return rispondi(false, 'Udienza non trovata.') end
    if u.imputato ~= g.citizenid then return rispondi(false, 'Non è la tua udienza.') end

    local r = TRI.GetRito(rito)
    if not r then return rispondi(false, 'Rito non previsto.') end

    local difensore = difensoreSrc and AUREA.GetPlayer(tonumber(difensoreSrc)) or nil
    local dUfficio = false

    if r.richiedeAvvocato and not difensore then
        if not TRI.Regole.difensoreUfficio then
            return rispondi(false, 'Serve un difensore. Chiamane uno.')
        end
        dUfficio = true
    end

    local onorario = difensore and TRI.Regole.onorarioAvvocato or (dUfficio and TRI.Regole.onorarioUfficio or 0)
    if onorario > 0 and not g:SottraiOvunque(onorario, 'onorario difensivo') then
        return rispondi(false, ('L\'onorario è di %s.'):format(U.Euro(onorario)))
    end

    if difensore and onorario > 0 then
        difensore:Aggiungi('banca', math.floor(onorario * 0.8), 'onorario difensivo')
        TriggerEvent('aurea:fisco:ritenuta', difensore.citizenid, math.floor(onorario * 0.2), 'irpef')
    elseif dUfficio and onorario > 0 then
        TriggerEvent('aurea:fisco:incasso', 'spese_giustizia', onorario, g.citizenid)
    end

    u.rito = rito
    u.difensore = difensore and difensore.citizenid or nil
    u.nomeDifensore = difensore and difensore:NomeCompleto() or (dUfficio and 'difensore d\'ufficio' or nil)

    local giudice = AUREA.GetPlayerByCitizenId(u.giudice)
    if giudice then
        TriggerClientEvent('tri:pronta', giudice.source, {
            id = id, imputato = u.nomeImputato, rito = r.nome,
            difensore = u.nomeDifensore,
            pena = u.pena, ammenda = u.ammenda,
            sconto = r.sconto, ammetteAssoluzione = r.ammetteAssoluzione == true,
            ammetteAggravio = r.ammetteAggravio == true,
            aggravioMassimo = r.aggravioMassimo,
            capi = u.capi,
        })
    end

    rispondi(true, ('Rito scelto: %s%s. Ora decide il giudice.')
        :format(r.nome, u.nomeDifensore and (', difeso da %s'):format(u.nomeDifensore) or ''))
end)

--- La sentenza.
AUREA.Callback.Registra('tri:sentenza', function(src, rispondi, id, esito, mesi, motivazione)
    local g = AUREA.GetPlayer(src)
    local u = udienze[id]
    if not g or not u then return rispondi(false, 'Udienza non trovata.') end
    if u.giudice ~= g.citizenid then return rispondi(false, 'Non presiedi tu.') end
    if not u.rito then return rispondi(false, 'L\'imputato non ha ancora scelto il rito.') end

    local r = TRI.GetRito(u.rito)
    udienze[id] = nil

    local imputato = AUREA.GetPlayerByCitizenId(u.imputato)

    -- Assoluzione
    if esito == 'assoluzione' then
        if not r.ammetteAssoluzione then
            return rispondi(false, 'Con questo rito non si può assolvere.')
        end

        for _, c in ipairs(u.capi) do
            MySQL.update('UPDATE casellario SET stato = \'assolto\', chiuso_il = NOW() WHERE id = ?', { c.id })
        end

        if imputato then
            imputato:Set('ricercato', 0, true)
            TriggerClientEvent('aurea:ui:notifica', imputato.source, {
                tipo = 'successo', icona = '⚖', durata = 20000,
                titolo = 'Assolto',
                testo = motivazione and motivazione ~= '' and motivazione
                    or 'Il tribunale ti ha assolto da tutti i capi. Sei libero.',
            })
        end

        AUREA.Log('giustizia', 'info', g,
            ('ha assolto %s da %d capi'):format(u.nomeImputato, #u.capi))
        return rispondi(true, ('%s assolto da tutti i capi.'):format(u.nomeImputato))
    end

    -- Condanna
    local base = tonumber(mesi) or u.pena
    base = math.floor(U.Clamp(base, 0, u.pena * (1 + (r.aggravioMassimo or 0))))

    if not r.ammetteAggravio and base > u.pena then base = u.pena end

    local finale = math.floor(base * (1 - (r.sconto or 0)))
    local ammenda = u.ammenda + TRI.Regole.speseGiustizia

    for _, c in ipairs(u.capi) do
        MySQL.update('UPDATE casellario SET stato = \'condannato\', chiuso_il = NOW() WHERE id = ?', { c.id })
    end

    if imputato then
        imputato:SottraiOvunque(ammenda, 'ammenda e spese di giustizia')
        TriggerEvent('aurea:fisco:incasso', 'spese_giustizia', ammenda, u.imputato)

        if finale > 0 then
            exports.ita_giustizia:Incarcera(u.imputato, finale, ('sentenza del %s'):format(g:NomeCompleto()))
        end

        TriggerClientEvent('aurea:ui:notifica', imputato.source, {
            tipo = 'errore', icona = '⚖', durata = 22000,
            titolo = ('Condannato a %d minuti'):format(finale),
            testo = ('%s%s Ammenda e spese: %s.')
                :format(motivazione and motivazione ~= '' and (motivazione .. ' ') or '',
                        r.sconto > 0 and ('Pena ridotta di un terzo per il rito scelto.') or '',
                        U.Euro(ammenda)),
        })
    end

    AUREA.Log('giustizia', 'info', g,
        ('ha condannato %s a %d minuti (rito %s)'):format(u.nomeImputato, finale, u.rito))

    rispondi(true, ('%s condannato a %d minuti e %s fra ammenda e spese.')
        :format(u.nomeImputato, finale, U.Euro(ammenda)))
end)

AUREA.Callback.Registra('tri:pendenti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for id, u in pairs(udienze) do
        if u.giudice == g.citizenid or u.imputato == g.citizenid or u.difensore == g.citizenid then
            out[#out + 1] = {
                id = id, imputato = u.nomeImputato, giudice = u.nomeGiudice,
                rito = u.rito and TRI.Riti[u.rito].nome or 'da scegliere',
                capi = #u.capi, pena = u.pena,
            }
        end
    end
    rispondi(out)
end)

--- Le udienze abbandonate decadono.
CreateThread(function()
    while true do
        Wait(600000)
        for id, u in pairs(udienze) do
            if (os.time() - u.aperta) > 2700 then udienze[id] = nil end
        end
    end
end)
