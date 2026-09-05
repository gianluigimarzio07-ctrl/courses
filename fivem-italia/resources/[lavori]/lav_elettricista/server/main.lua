--[[
    AUREA · Manutenzione rete elettrica (server)
]]

local U = AUREA.Util
local guasti = {}       -- [idCabina] = { tipo, aperto, presoDa }

local function quantiAperti()
    local n = 0
    for _ in pairs(guasti) do n = n + 1 end
    return n
end

local function apriGuasto(idCabina, causa)
    if guasti[idCabina] then return end
    if quantiAperti() >= ELE.Guasti.massimoAperti then return end

    local c = ELE.GetCabina(idCabina)
    if not c then return end

    local tipo = ELE.Guasti.tipi[math.random(#ELE.Guasti.tipi)]
    guasti[idCabina] = { tipo = tipo.id, aperto = os.time(), causa = causa }

    TriggerClientEvent('ele:blackout', -1, idCabina, true)

    exports.aurea_ui:NotificaLavoro(ELE.Lavoro, {
        tipo = 'avviso', icona = '⚡', durata = 16000,
        titolo = ('Guasto: %s'):format(c.nome),
        testo = ('%s — %s è senza corrente. Usa /guasti.'):format(tipo.nome, c.zona),
    }, false)

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '💡', durata = 12000,
        titolo = 'Interruzione di corrente',
        testo = ('%s è al buio. La manutenzione è stata avvisata.'):format(c.zona),
    })

    -- Se nessuno ci va, la ditta esterna risolve, ma nessuno viene pagato
    CreateThread(function()
        Wait(ELE.Guasti.minutiPrimaDellaDitta * 60000)
        if guasti[idCabina] then
            guasti[idCabina] = nil
            TriggerClientEvent('ele:blackout', -1, idCabina, false)
            exports.aurea_ui:NotificaLavoro(ELE.Lavoro, {
                tipo = 'info', icona = '⚡', durata = 12000,
                titolo = 'Guasto risolto da terzi',
                testo = ('%s: è intervenuta una ditta esterna. Nessun compenso.'):format(c.nome),
            }, false)
        end
    end)
end

--- Le altre risorse possono provocare un guasto: il quadro elettrico
--- staccato durante un colpo è un guasto a tutti gli effetti.
exports('ProvocaGuasto', function(idCabina, causa) apriGuasto(idCabina, causa or 'causa esterna') end)

exports('ZonaAlBuio', function(idCabina) return guasti[idCabina] ~= nil end)

-- ---------------------------------------------------------------------------
--  Turno
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ele:guasti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local out = {}
    for id, guasto in pairs(guasti) do
        local c = ELE.GetCabina(id)
        local t = ELE.GetTipoGuasto(guasto.tipo)
        if c and t then
            out[#out + 1] = {
                id = id, cabina = c.nome, zona = c.zona,
                coord = { x = c.coord.x, y = c.coord.y, z = c.coord.z },
                guasto = t.nome, paga = t.paga,
                oggetto = t.oggetto, quantita = t.quantita,
                etichettaOggetto = AUREA.Item[t.oggetto].etichetta,
                minuti = math.floor((os.time() - guasto.aperto) / 60),
                causa = guasto.causa,
            }
        end
    end
    table.sort(out, function(a, b) return a.minuti > b.minuti end)

    rispondi({
        guasti = out,
        eElettricista = g.lavoro.nome == ELE.Lavoro,
        mezzi = ELE.Sede.mezzi, modello = ELE.Sede.modello,
    })
end)

AUREA.Callback.Registra('ele:ripara', function(src, rispondi, idCabina)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= ELE.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end

    local guasto = guasti[idCabina]
    if not guasto then return rispondi(false, 'Non risulta nessun guasto qui.') end

    local c = ELE.GetCabina(idCabina)
    local t = ELE.GetTipoGuasto(guasto.tipo)
    if not c or not t then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - c.coord) > ELE.Regole.distanzaIntervento then
        return rispondi(false, 'Non sei alla cabina.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(t.oggetto, t.quantita) then
        return rispondi(false, ('Servono %d× %s.'):format(t.quantita, AUREA.Item[t.oggetto].etichetta))
    end

    rispondi(true, { nome = t.nome, durata = t.durata, paga = t.paga })
end)

AUREA.Callback.Registra('ele:concludiRiparazione', function(src, rispondi, idCabina, staccato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local guasto = guasti[idCabina]
    if not guasto then return rispondi(false, 'Il guasto è già stato risolto.') end

    local c = ELE.GetCabina(idCabina)
    local t = ELE.GetTipoGuasto(guasto.tipo)
    if not c or not t then return rispondi(false) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(t.oggetto, t.quantita) then
        return rispondi(false, 'Il materiale è finito.')
    end
    inventario:Rimuovi(t.oggetto, t.quantita)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    -- Chi lavora sotto tensione rischia
    local scossa = false
    if not staccato and math.random(100) <= ELE.Regole.probabilitaScossa then
        scossa = true
        TriggerClientEvent('ele:scossa', src, ELE.Regole.dannoScossa)
    end

    guasti[idCabina] = nil
    TriggerClientEvent('ele:blackout', -1, idCabina, false)

    local paga = t.paga
    local ritenuta = math.floor(paga * 0.20)
    g:Aggiungi('banca', paga - ritenuta, ('riparazione %s'):format(c.nome))
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'successo', icona = '💡', durata = 10000,
        titolo = 'Corrente ripristinata',
        testo = ('%s è tornata alla normalità.'):format(c.zona),
    })

    rispondi(true, ('%s riparato. Netti %s.%s'):format(t.nome, U.Euro(paga - ritenuta),
        scossa and ' Hai preso la scossa: dovevi staccare la tensione.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Guasti spontanei
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(120000)
    while true do
        Wait(ELE.Guasti.minutiControllo * 60000)

        local probabilita = ELE.Guasti.probabilitaSpontanea

        -- Col maltempo saltano più spesso
        local meteo = GlobalState.meteo
        if meteo == 'temporale' or meteo == 'pioggia' then
            probabilita = probabilita * ELE.Guasti.moltiplicatoreMaltempo
        end

        if math.random(100) <= math.min(80, probabilita) then
            local c = ELE.Cabine[math.random(#ELE.Cabine)]
            apriGuasto(c.id, meteo == 'temporale' and 'fulmine' or 'usura')
        end
    end
end)
