--[[
    AUREA · Voce (server)

    Il server tiene chi è su quale frequenza radio, perché è l'unico che
    può verificare che tu abbia il lavoro giusto e la radio in tasca.
    Le portate della voce le applica il client, ma il server le impone a
    tutti allo stesso modo: non si può alzare il proprio raggio.
]]

local U = AUREA.Util
local frequenze = {}    -- [src] = frequenza

--- pma-voice espone questi export. Se manca, si lavora lo stesso.
local function pma(nome, ...)
    -- I varargs non attraversano la closure: si impacchettano prima.
    local argomenti = table.pack(...)
    local ok = pcall(function()
        return exports['pma-voice'][nome](exports['pma-voice'], table.unpack(argomenti, 1, argomenti.n))
    end)
    return ok
end

CreateThread(function()
    Wait(3000)
    if not pma('setPlayerRadio', 0, 0) then
        print('[AUREA] pma-voice non risponde: la voce resta quella base di FiveM. '
            .. 'Per le portate e la radio, installa pma-voice.')
    end
end)

-- ---------------------------------------------------------------------------
--  Portata della voce
-- ---------------------------------------------------------------------------
RegisterNetEvent('voc:portata', function(id)
    local src = source
    local p = VOC.GetPortata(id)

    -- Il raggio lo impone il server: il client dice solo quale delle tre
    -- portate previste vuole usare.
    pma('setPlayerProximity', src, p.metri)
    TriggerClientEvent('voc:portataConfermata', src, p.id, p.metri)
end)

-- ---------------------------------------------------------------------------
--  Radio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('voc:frequenze', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local haRadio = inventario:Ha(VOC.Radio.oggetto, 1)

    local elenco = {}
    for f, lavori in pairs(VOC.Radio.riservate) do
        elenco[#elenco + 1] = {
            frequenza = f,
            nome = table.concat(lavori, ', '),
            ammessa = VOC.FrequenzaAmmessa(f, g.lavoro.nome),
        }
    end
    table.sort(elenco, function(a, b) return a.frequenza < b.frequenza end)

    rispondi({
        haRadio = haRadio,
        attuale = frequenze[src],
        riservate = elenco,
        liberaDa = VOC.Radio.liberaDa, liberaA = VOC.Radio.liberaA,
    })
end)

AUREA.Callback.Registra('voc:sintonizza', function(src, rispondi, frequenza)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    -- Scendere dalla radio si può sempre
    if not frequenza or frequenza == 0 then
        frequenze[src] = nil
        pma('setPlayerRadio', src, 0)
        return rispondi(true, 'Radio spenta.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(VOC.Radio.oggetto, 1) then
        return rispondi(false, 'Non hai una radio addosso.')
    end

    frequenza = math.floor((tonumber(frequenza) or 0) * 10) / 10

    if not VOC.FrequenzaAmmessa(frequenza, g.lavoro.nome) then
        return rispondi(false, ('La %0.1f è riservata. Le libere vanno dalla %0.1f alla %0.1f.')
            :format(frequenza, VOC.Radio.liberaDa, VOC.Radio.liberaA))
    end

    frequenze[src] = frequenza
    pma('setPlayerRadio', src, frequenza)

    local quanti = 0
    for _, f in pairs(frequenze) do
        if f == frequenza then quanti = quanti + 1 end
    end

    rispondi(true, ('%s — sintonizzato sulla %0.1f. In ascolto: %d.')
        :format(VOC.NomeFrequenza(frequenza), frequenza, quanti))
end)

--- Chi perde la radio esce dalla frequenza: non si resta in ascolto
--- perché si è dimenticato di scollegarsi.
CreateThread(function()
    while true do
        Wait(30000)
        for src, f in pairs(frequenze) do
            local g = AUREA.GetPlayer(src)
            if not g then
                frequenze[src] = nil
            else
                local inv = exports.aurea_inventory:Inventario(g.citizenid)
                if not inv:Ha(VOC.Radio.oggetto, 1) then
                    frequenze[src] = nil
                    pma('setPlayerRadio', src, 0)
                    TriggerClientEvent('aurea:ui:notifica', src, {
                        tipo = 'avviso', icona = '📻', durata = 9000,
                        titolo = 'Radio persa',
                        testo = 'Senza apparecchio sei uscito dalla frequenza.',
                    })
                end
            end
        end
    end
end)

--- Chi cambia lavoro esce dalle frequenze che non gli spettano più.
AddEventHandler('aurea:lavoro:cambiato', function(src, lavoro)
    local f = frequenze[src]
    if f and not VOC.FrequenzaAmmessa(f, lavoro) then
        frequenze[src] = nil
        pma('setPlayerRadio', src, 0)
    end
end)

exports('FrequenzaDi', function(src) return frequenze[src] end)

-- ---------------------------------------------------------------------------
--  Telefonate
--
--  Il telefono decide chi parla con chi; qui si apre e si chiude il canale
--  vocale fra i due. pma-voice ha già il concetto di chiamata, quindi non
--  si inventa niente: si usa il suo.
--
--  Chi è vicino sente la tua metà della conversazione e non quella
--  dell'altro, che è come funziona un telefono all'orecchio. Lo fa
--  pma-voice da solo tenendo la voce di prossimità accesa.
-- ---------------------------------------------------------------------------
exports('Telefonata', function(sorgenteA, sorgenteB, attiva)
    local a, b = tonumber(sorgenteA), tonumber(sorgenteB)
    if not a or not b then return false end

    if attiva then
        pma('addPlayerToCall', a, b)
    else
        pma('removePlayerFromCall', a)
        pma('removePlayerFromCall', b)
    end

    return true
end)

-- ---------------------------------------------------------------------------
--  La frequenza sintonizzata, per chi deve saperla
--
--  C'era una sola radio nel gioco ma due elenchi di sintonizzati: uno qui,
--  per la voce, e uno in aurea_chat, per il testo. Erano indipendenti, e
--  il comando /radio del client copriva quello del server: chi si
--  sintonizzava parlava ma non scriveva. Adesso l'elenco è questo, uno
--  solo, e aurea_chat lo legge da qui.
-- ---------------------------------------------------------------------------

--- La frequenza su cui è sintonizzato un giocatore, o nil se ha la radio spenta.
exports('FrequenzaDi', function(src)
    return frequenze[tonumber(src)]
end)

--- Chi è sintonizzato su una frequenza: elenco di source.
exports('SintonizzatiSu', function(frequenza)
    local out = {}
    for src, f in pairs(frequenze) do
        if f == frequenza then out[#out + 1] = src end
    end
    return out
end)

AddEventHandler('playerDropped', function() frequenze[source] = nil end)
