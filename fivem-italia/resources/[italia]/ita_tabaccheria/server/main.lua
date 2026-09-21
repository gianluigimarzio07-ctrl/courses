--[[
    AUREA · Tabaccheria (server)

    L'estrazione è un thread che gira per conto suo e non guarda le
    giocate: i numeri escono prima di sapere chi ha puntato cosa. È
    l'unico modo per cui un gioco a quote fisse sia onesto.

    Le vincite si calcolano dopo, confrontando. E la quota è quella
    vera — alta abbastanza da sembrare una buona idea, bassa abbastanza
    da non esserlo.
]]

local U = AUREA.Util

local function tabaccaio(g)
    return g and g.lavoro.nome == TAB.Lavoro and g.lavoro.servizio
end

-- ---------------------------------------------------------------------------
--  Il banco
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tab:banco', function(src, rispondi)
    local r = TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not r then return rispondi(nil) end

    local ultima = MySQL.single.await(
        'SELECT ruota, numeri, quando FROM lotto_estrazioni ORDER BY id DESC LIMIT 1')

    local g = AUREA.GetPlayer(src)
    local giocate = {}
    if g then
        giocate = MySQL.query.await([[
            SELECT id, ruota, sorte, numeri, importo, vincita, stato
            FROM lotto_giocate WHERE citizenid = ?
            ORDER BY quando DESC LIMIT 8
        ]], { g.citizenid }) or {}
    end

    local bolli = {}
    if g then
        bolli = MySQL.query.await([[
            SELECT codice, valore FROM valori_bollati WHERE citizenid = ? AND usato = 0
        ]], { g.citizenid }) or {}
    end

    rispondi({
        rivendita = r,
        banco = TAB.Banco,
        bolli = TAB.Bolli,
        mieiBolli = bolli,
        ruote = TAB.Lotto.ruote,
        sorti = TAB.Lotto.sorti,
        giocate = giocate,
        ultima = ultima,
        minuti = TAB.Lotto.minutiEstrazione,
    })
end)

AUREA.Callback.Registra('tab:compra', function(src, rispondi, itemId, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local r = TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not r then return rispondi(false, 'Non sei in una tabaccheria.') end

    local voce
    for _, b in ipairs(TAB.Banco) do if b.item == itemId then voce = b end end
    if not voce then return rispondi(false, 'Non si vende qui.') end

    quantita = math.max(1, math.min(10, math.floor(tonumber(quantita) or 1)))
    local totale = voce.prezzo * quantita

    if not g:SottraiOvunque(totale, ('%s x%d'):format(voce.nome, quantita)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(totale)))
    end

    if not exports.aurea_inventory:Aggiungi(g.citizenid, voce.item, quantita) then
        g:Aggiungi('contanti', totale, 'rimborso: inventario pieno')
        return rispondi(false, 'Non ci sta nello zaino.')
    end

    -- L'aggio al tabaccaio, il resto allo Stato. È il monopolio.
    local aggio = math.floor(totale * voce.aggio)
    for _, t in pairs(AUREA.GetGiocatoriPerLavoro(TAB.Lavoro, true) or {}) do
        if TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(t.source))) then
            t:Aggiungi('contanti', aggio, 'aggio di rivendita')
            aggio = 0
            break
        end
    end
    TriggerEvent('aurea:fisco:incasso', 'monopoli', totale - aggio, g.citizenid)

    rispondi(true, ('%s x%d — %s.'):format(voce.nome, quantita, U.Euro(totale)))
end)

-- ---------------------------------------------------------------------------
--  Valori bollati
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tab:bollo', function(src, rispondi, valore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local r = TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not r then return rispondi(false, 'I valori bollati si comprano dal tabaccaio.') end

    valore = math.floor(tonumber(valore) or 0)
    local voce
    for _, b in ipairs(TAB.Bolli) do if b.valore == valore then voce = b end end
    if not voce then return rispondi(false, 'Taglio non emesso.') end

    if not g:SottraiOvunque(valore, voce.nome) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(valore)))
    end

    local aggio = math.floor(valore * TAB.aggioBolli)
    TriggerEvent('aurea:fisco:incasso', 'valori_bollati', valore - aggio, g.citizenid)

    local codice = ('%s-%s'):format(U.Random(2, 'ABCDEFGHILMNOPQRSTUVZ'), U.Random(10, '0123456789'))
    MySQL.insert.await(
        'INSERT INTO valori_bollati (codice, citizenid, valore) VALUES (?, ?, ?)',
        { codice, g.citizenid, valore })

    rispondi(true, ('%s emesso.\nCodice %s. Serve per le pratiche: chi te lo chiede lo annulla.')
        :format(voce.nome, codice))
end)

--- Annulla un bollo del taglio richiesto. Lo chiama chi ha bisogno di
--- una marca da bollo per una pratica — oggi la Questura, per il
--- passaporto.
exports('ConsumaBollo', function(citizenid, valore, usatoPer)
    valore = math.floor(tonumber(valore) or 0)

    local b = MySQL.single.await([[
        SELECT id, codice FROM valori_bollati
        WHERE citizenid = ? AND valore = ? AND usato = 0
        ORDER BY emesso_il ASC LIMIT 1
    ]], { citizenid, valore })
    if not b then return false end

    MySQL.update.await([[
        UPDATE valori_bollati SET usato = 1, usato_per = ?, usato_il = NOW() WHERE id = ?
    ]], { tostring(usatoPer or 'pratica'):sub(1, 96), b.id })

    return true, b.codice
end)

exports('BolliDi', function(citizenid)
    return MySQL.query.await([[
        SELECT codice, valore FROM valori_bollati WHERE citizenid = ? AND usato = 0
    ]], { citizenid }) or {}
end)

-- ---------------------------------------------------------------------------
--  Il Lotto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tab:gioca', function(src, rispondi, ruota, sorteId, numeriTesto, importo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local r = TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not r then return rispondi(false, 'Si gioca al banco.') end

    if not U.Contiene(TAB.Lotto.ruote, ruota) then return rispondi(false, 'Ruota inesistente.') end

    local sorte = TAB.GetSorte(sorteId)
    if not sorte then return rispondi(false, 'Sorte non prevista.') end

    -- I numeri: si accettano solo interi fra 1 e 90, senza ripetizioni
    local numeri, visti = {}, {}
    for pezzo in tostring(numeriTesto or ''):gmatch('%d+') do
        local n = tonumber(pezzo)
        if n and n >= 1 and n <= TAB.Lotto.numeroMassimo and not visti[n] then
            visti[n] = true
            numeri[#numeri + 1] = n
        end
    end

    if #numeri ~= sorte.numeri then
        return rispondi(false, ('Per %s servono esattamente %d numeri diversi fra 1 e %d.')
            :format(sorte.nome:lower(), sorte.numeri, TAB.Lotto.numeroMassimo))
    end

    importo = math.floor(tonumber(importo) or 0)
    if importo < TAB.Lotto.giocataMinima or importo > TAB.Lotto.giocataMassima then
        return rispondi(false, ('La giocata va da %s a %s.')
            :format(U.Euro(TAB.Lotto.giocataMinima), U.Euro(TAB.Lotto.giocataMassima)))
    end

    if not g:SottraiOvunque(importo, ('giocata al lotto — %s'):format(ruota)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(importo)))
    end

    local aggio = math.floor(importo * TAB.Lotto.aggio)
    for _, t in pairs(AUREA.GetGiocatoriPerLavoro(TAB.Lavoro, true) or {}) do
        if TAB.RivenditaVicina(GetEntityCoords(GetPlayerPed(t.source))) then
            t:Aggiungi('contanti', aggio, 'aggio sulla raccolta')
            aggio = 0
            break
        end
    end
    TriggerEvent('aurea:fisco:incasso', 'monopoli', importo - aggio, g.citizenid)

    table.sort(numeri)
    MySQL.insert.await([[
        INSERT INTO lotto_giocate (citizenid, ruota, sorte, numeri, importo)
        VALUES (?, ?, ?, ?, ?)
    ]], { g.citizenid, ruota, sorteId, table.concat(numeri, ','), importo })

    rispondi(true, ('%s su %s: %s per %s.\nQuota %.2f. La prossima estrazione è entro %d minuti.')
        :format(sorte.nome, ruota, table.concat(numeri, ' · '), U.Euro(importo),
                sorte.quota, TAB.Lotto.minutiEstrazione))
end)

-- ---------------------------------------------------------------------------
--  L'estrazione
--
--  Esce prima di guardare le giocate. Sempre.
-- ---------------------------------------------------------------------------
local function estrai()
    for _, ruota in ipairs(TAB.Lotto.ruote) do
        -- Cinque numeri distinti fra 1 e 90
        local urna, numeri = {}, {}
        for n = 1, TAB.Lotto.numeroMassimo do urna[n] = n end
        for i = 1, TAB.Lotto.numeriEstratti do
            local j = math.random(i, #urna)
            urna[i], urna[j] = urna[j], urna[i]
            numeri[#numeri + 1] = urna[i]
        end

        local id = MySQL.insert.await(
            'INSERT INTO lotto_estrazioni (ruota, numeri) VALUES (?, ?)',
            { ruota, table.concat(numeri, ',') })

        -- Adesso si guarda chi ha vinto
        local giocate = MySQL.query.await([[
            SELECT id, citizenid, sorte, numeri, importo FROM lotto_giocate
            WHERE ruota = ? AND stato = 'aperta'
        ]], { ruota }) or {}

        for _, gi in ipairs(giocate) do
            local sorte = TAB.GetSorte(gi.sorte)
            local giocati = {}
            for pezzo in gi.numeri:gmatch('%d+') do giocati[#giocati + 1] = tonumber(pezzo) end

            local indovinati = TAB.Indovinati(giocati, numeri)
            local vinta = sorte and indovinati >= sorte.numeri

            if vinta then
                local lordo = math.floor(gi.importo * sorte.quota)
                local netto = lordo - math.floor(lordo * TAB.Lotto.ritenuta)

                MySQL.update.await(
                    'UPDATE lotto_giocate SET stato = ?, vincita = ?, estrazione_id = ? WHERE id = ?',
                    { 'vinta', netto, id, gi.id })

                AUREA.Denaro.AggiungiOffline(gi.citizenid, 'banca', netto,
                    ('vincita al lotto — %s'):format(ruota))
                TriggerEvent('aurea:fisco:incasso', 'prelievo_vincite',
                    lordo - netto, gi.citizenid)

                TriggerEvent('aurea:telefono:messaggioSistema', gi.citizenid, 'Lotto',
                    ('%s su %s: %s.\nVincita lorda %s, netto %s dopo il prelievo.')
                        :format(sorte.nome, ruota, table.concat(numeri, ' · '),
                                U.Euro(lordo), U.Euro(netto)))

                AUREA.Log('denaro', 'info', nil, ('vincita al lotto: %s a %s')
                    :format(U.Euro(netto), gi.citizenid))
            else
                MySQL.update.await(
                    'UPDATE lotto_giocate SET stato = ?, estrazione_id = ? WHERE id = ?',
                    { 'perdente', id, gi.id })
            end
        end
    end

    exports.aurea_ui:NotificaTutti({
        tipo = 'info', icona = '🎰', durata = 12000,
        titolo = 'Estrazione del Lotto',
        testo = 'I numeri sono usciti su tutte le ruote. Controlla la giocata in tabaccheria.',
    })
end

CreateThread(function()
    Wait(30000)
    while true do
        Wait(TAB.Lotto.minutiEstrazione * 60000)
        estrai()
    end
end)

AUREA.Callback.Registra('tab:estrazioni', function(src, rispondi)
    rispondi(MySQL.query.await([[
        SELECT ruota, numeri, TIMESTAMPDIFF(MINUTE, quando, NOW()) AS minutiFa
        FROM lotto_estrazioni ORDER BY id DESC LIMIT 10
    ]]) or {})
end)
