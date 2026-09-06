--[[
    AUREA · Banchi da lavoro (server)

    Il client manda solo "voglio fare questo, tante volte". Materiali,
    attrezzi, distanza dal banco e requisiti di mestiere li verifica il
    server, e li riverifica al momento di consegnare il prodotto: fra
    l'inizio e la fine della barra di avanzamento passano venti secondi in
    cui l'inventario può essere cambiato.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Requisiti
-- ---------------------------------------------------------------------------
local function bancoAmmesso(g, banco)
    if banco.lavoro and g.lavoro.nome ~= banco.lavoro then
        return false, ('Questo banco è dell\'officina: serve il mestiere di %s.')
            :format(AUREA.Lavori[banco.lavoro].etichetta)
    end
    if banco.lavori and not U.Contiene(banco.lavori, g.lavoro.nome) then
        return false, 'Non hai titolo per usare questo banco.'
    end
    return true
end

--- Materiali e attrezzi ci sono? Restituisce anche cosa manca, così il
--- messaggio è utile invece di un "non puoi" secco.
local function verifica(inv, ricetta, volte)
    local mancanti = {}

    for _, ing in ipairs(ricetta.ingredienti) do
        local servono = ing[2] * volte
        local ho = inv:Quantita(ing[1])
        if ho < servono then
            local dati = AUREA.Item[ing[1]]
            mancanti[#mancanti + 1] = ('%s (hai %d, servono %d)')
                :format(dati and dati.etichetta or ing[1], ho, servono)
        end
    end

    for _, attrezzo in ipairs(ricetta.attrezzi or {}) do
        if not inv:Ha(attrezzo, 1) then
            local dati = AUREA.Item[attrezzo]
            mancanti[#mancanti + 1] = ('%s (attrezzo)'):format(dati and dati.etichetta or attrezzo)
        end
    end

    return #mancanti == 0, mancanti
end

-- ---------------------------------------------------------------------------
--  Elenco delle ricette di un banco, con quello che il giocatore può fare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cra:ricette', function(src, rispondi, idBanco)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local banco = CRA.GetBanco(idBanco)
    if not banco then return rispondi({}, 'Banco sconosciuto.') end

    local ok, motivo = bancoAmmesso(g, banco)
    if not ok then return rispondi({}, motivo) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local out = {}

    for _, r in ipairs(CRA.RicetteDi(idBanco)) do
        local fattibile, mancanti = verifica(inv, r, 1)
        local dati = AUREA.Item[r.produce[1]]

        local elenco = {}
        for _, ing in ipairs(r.ingredienti) do
            local d = AUREA.Item[ing[1]]
            elenco[#elenco + 1] = ('%dx %s'):format(ing[2], d and d.etichetta or ing[1])
        end

        out[#out + 1] = {
            id = r.id, nome = r.nome,
            produce = r.produce[1], quantita = r.produce[2],
            etichetta = dati and dati.etichetta or r.produce[1],
            ingredienti = table.concat(elenco, ', '),
            attrezzi = r.attrezzi,
            fattibile = fattibile,
            mancanti = table.concat(mancanti, '; '),
            illecito = r.illecito or false,
            durata = r.durata,
        }
    end

    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Produzione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cra:avvia', function(src, rispondi, idRicetta, volte)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local r = CRA.GetRicetta(idRicetta)
    if not r then return rispondi(false, 'Ricetta sconosciuta.') end

    local banco = CRA.GetBanco(r.banco)
    if #(GetEntityCoords(GetPlayerPed(src)) - banco.coord) > banco.raggio + 1.0 then
        return rispondi(false, 'Devi essere al banco.')
    end

    local ok, motivo = bancoAmmesso(g, banco)
    if not ok then return rispondi(false, motivo) end

    if banco.attrezzo then
        local inv = exports.aurea_inventory:Inventario(g.citizenid)
        if not inv:Ha(banco.attrezzo, 1) then
            return rispondi(false, ('Per lavorare a questo banco serve %s.')
                :format(AUREA.Item[banco.attrezzo].etichetta))
        end
    end

    volte = math.max(1, math.min(CRA.Regole.massimoPerVolta, math.floor(tonumber(volte) or 1)))

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local fattibile, mancanti = verifica(inv, r, volte)
    if not fattibile then
        return rispondi(false, ('Materiale insufficiente: %s.'):format(table.concat(mancanti, '; ')))
    end

    rispondi(true, r.durata * volte, volte)
end)

AUREA.Callback.Registra('cra:concludi', function(src, rispondi, idRicetta, volte)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local r = CRA.GetRicetta(idRicetta)
    if not r then return rispondi(false) end

    local banco = CRA.GetBanco(r.banco)
    if #(GetEntityCoords(GetPlayerPed(src)) - banco.coord) > banco.raggio + 2.0 then
        return rispondi(false, 'Ti sei allontanato dal banco: il lavoro è saltato.')
    end

    volte = math.max(1, math.min(CRA.Regole.massimoPerVolta, math.floor(tonumber(volte) or 1)))

    local inv = exports.aurea_inventory:Inventario(g.citizenid)

    -- Riverifica: fra l'avvio e adesso l'inventario può essere cambiato
    local fattibile, mancanti = verifica(inv, r, volte)
    if not fattibile then
        return rispondi(false, ('Il materiale non c\'è più: %s.'):format(table.concat(mancanti, '; ')))
    end

    -- Prima si prova ad aggiungere il prodotto: se non c'è spazio, i
    -- materiali non si consumano. Il contrario sarebbe furto.
    local prodotti = r.produce[2] * volte
    if not inv:Aggiungi(r.produce[1], prodotti) then
        return rispondi(false, 'Non hai spazio per il prodotto finito.')
    end

    for _, ing in ipairs(r.ingredienti) do
        inv:Rimuovi(ing[1], ing[2] * volte)
    end

    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    -- Il banco clandestino non è invisibile
    if r.illecito and math.random(100) <= CRA.Regole.probabilitaSegnalazione then
        local coord = GetEntityCoords(GetPlayerPed(src))
        TriggerEvent('aurea:112:allerta', 'sospetto', { x = coord.x, y = coord.y, z = coord.z },
            'Segnalazione di attività sospetta in un capannone.', 'segnalazione anonima')
    end

    AUREA.Log('economia', 'debug', g, ('ha prodotto %dx %s'):format(prodotti, r.produce[1]))

    rispondi(true, ('%dx %s.'):format(prodotti, AUREA.Item[r.produce[1]].etichetta))
end)

-- ---------------------------------------------------------------------------
--  Smontaggio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cra:smontabili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local banco = CRA.BancoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not banco then return rispondi({}, 'Non sei a un banco.') end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local out = {}

    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        local r = CRA.RicettaDiProdotto(riga.nome)
        if r then
            local resa = {}
            for _, ing in ipairs(r.ingredienti) do
                local quanti = math.floor(ing[2] * CRA.Smontaggio.resa)
                if quanti > 0 then
                    local d = AUREA.Item[ing[1]]
                    resa[#resa + 1] = ('%dx %s'):format(quanti, d and d.etichetta or ing[1])
                end
            end

            if #resa > 0 then
                out[#out + 1] = {
                    item = riga.nome, etichetta = riga.etichetta,
                    quantita = riga.quantita, resa = table.concat(resa, ', '),
                }
            end
        end
    end

    rispondi(out)
end)

AUREA.Callback.Registra('cra:smonta', function(src, rispondi, item)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local banco = CRA.BancoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not banco then return rispondi(false, 'Non sei a un banco.') end

    local r = CRA.RicettaDiProdotto(item)
    if not r then return rispondi(false, 'Questo non si smonta.') end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(item, 1) then return rispondi(false, 'Non ce l\'hai.') end
    if not inv:Ha(CRA.Smontaggio.attrezzo, 1) then
        return rispondi(false, ('Serve %s.'):format(AUREA.Item[CRA.Smontaggio.attrezzo].etichetta))
    end

    rispondi(true, CRA.Smontaggio.durata)
end)

AUREA.Callback.Registra('cra:concludiSmontaggio', function(src, rispondi, item)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local r = CRA.RicettaDiProdotto(item)
    if not r then return rispondi(false) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(item, 1) then return rispondi(false, 'Non ce l\'hai più.') end

    inv:Rimuovi(item, 1)

    local recuperati = {}
    for _, ing in ipairs(r.ingredienti) do
        local quanti = math.floor(ing[2] * CRA.Smontaggio.resa)
        if quanti > 0 and inv:Aggiungi(ing[1], quanti) then
            local d = AUREA.Item[ing[1]]
            recuperati[#recuperati + 1] = ('%dx %s'):format(quanti, d and d.etichetta or ing[1])
        end
    end

    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    rispondi(true, #recuperati > 0
        and ('Recuperati: %s.'):format(table.concat(recuperati, ', '))
        or 'Non è rimasto niente di riutilizzabile.')
end)
