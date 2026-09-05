--[[
    AUREA · Casinò (server)

    Ogni esito lo estrae il server. Il client manda solo la puntata e il
    tipo di scommessa: le carte, il numero e i rulli non li vede mai
    prima che siano decisi qui.
]]

local U = AUREA.Util
local bilanci = {}      -- [citizenid] = { netto, dalle }

local function bilancio(citizenid)
    local b = bilanci[citizenid]
    if not b or (os.time() - b.dalle) > CAS.Regole.oreAzzeramento * 3600 then
        b = { netto = 0, dalle = os.time() }
        bilanci[citizenid] = b
    end
    return b
end

local function fiches(g)
    return exports.aurea_inventory:Inventario(g.citizenid):Quantita(CAS.Fiches.item)
end

local function alCasino(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - CAS.Sede.coord) < 60.0
end

-- ---------------------------------------------------------------------------
--  Cassa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cas:cassa', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    rispondi({
        fiches = fiches(g),
        valore = CAS.Fiches.valore,
        commissione = CAS.Fiches.commissione,
        netto = bilancio(g.citizenid).netto,
        tetto = CAS.Regole.tettoVinciteGiornaliere,
    })
end)

AUREA.Callback.Registra('cas:cambia', function(src, rispondi, verso, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAS.Sede.cassa) > 4.0 then
        return rispondi(false, 'Devi essere alla cassa.')
    end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 0, 1, 500))
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if verso == 'compra' then
        local costo = quantita * CAS.Fiches.valore
        local commissione = math.floor(costo * CAS.Fiches.commissione)

        if not g:SottraiOvunque(costo + commissione, 'acquisto fiches') then
            return rispondi(false, ('Servono %s (%d fiches + %s di commissione).')
                :format(U.Euro(costo + commissione), quantita, U.Euro(commissione)))
        end
        if not inventario:Aggiungi(CAS.Fiches.item, quantita) then
            g:Aggiungi('contanti', costo + commissione, 'rimborso fiches')
            return rispondi(false, 'Non hai spazio per le fiches.')
        end

        TriggerEvent('aurea:fisco:incasso', 'iva_giochi', commissione, g.citizenid)
        TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
        return rispondi(true, ('%d fiches. Commissione %s.'):format(quantita, U.Euro(commissione)))
    end

    -- Cambio inverso
    if not inventario:Ha(CAS.Fiches.item, quantita) then
        return rispondi(false, 'Non hai tutte quelle fiches.')
    end

    local lordo = quantita * CAS.Fiches.valore
    local commissione = math.floor(lordo * CAS.Fiches.commissione)

    -- Sulle vincite si paga l'imposta, come su una vincita vera
    local b = bilancio(g.citizenid)
    local imposta = 0
    if b.netto > 0 then
        imposta = math.floor(math.min(lordo, b.netto) * CAS.Regole.aliquotaImposta)
    end

    inventario:Rimuovi(CAS.Fiches.item, quantita)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local netto = lordo - commissione - imposta
    g:Aggiungi('banca', netto, 'cambio fiches')

    TriggerEvent('aurea:fisco:incasso', 'iva_giochi', commissione, g.citizenid)
    if imposta > 0 then
        TriggerEvent('aurea:fisco:incasso', 'imposta_vincite', imposta, g.citizenid)
    end

    rispondi(true, ('Accreditati %s%s.'):format(U.Euro(netto),
        imposta > 0 and (' (imposta sulle vincite %s)'):format(U.Euro(imposta)) or ''))
end)

-- ---------------------------------------------------------------------------
--  Il tavolo
-- ---------------------------------------------------------------------------
local function puoGiocare(g, src, idTavolo, puntata)
    if not alCasino(src) then return false, 'Non sei al casinò.' end

    local t = CAS.GetTavolo(idTavolo)
    if not t then return false, 'Tavolo inesistente.' end

    puntata = math.floor(tonumber(puntata) or 0)
    if puntata < t.puntataMinima or puntata > t.puntataMassima then
        return false, ('La puntata va da %d a %d fiches.'):format(t.puntataMinima, t.puntataMassima)
    end

    if fiches(g) < puntata then return false, 'Non hai abbastanza fiches.' end

    local b = bilancio(g.citizenid)
    if b.netto >= CAS.Regole.tettoVinciteGiornaliere then
        return false, 'Il banco ti ha chiuso i tavoli per oggi. Torna domani.'
    end

    return true, nil, t, puntata
end

local function regola(g, puntata, vincita)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    inventario:Rimuovi(CAS.Fiches.item, puntata)
    if vincita > 0 then inventario:Aggiungi(CAS.Fiches.item, vincita) end
    TriggerClientEvent('inv:aggiorna', g.source, inventario:Pacchetto())

    local b = bilancio(g.citizenid)
    b.netto = b.netto + (vincita - puntata) * CAS.Fiches.valore
end

-- ---------------------------------------------------------------------------
--  Roulette
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cas:roulette', function(src, rispondi, tipo, puntata, numero)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local ok, errore, t, importo = puoGiocare(g, src, 'roulette', puntata)
    if not ok then return rispondi(nil, errore) end

    local scommessa
    for _, s in ipairs(t.scommesse) do if s.id == tipo then scommessa = s end end
    if not scommessa then return rispondi(nil, 'Scommessa non prevista.') end

    -- Ruota vera: 0-36. Lo zero è la casa.
    local uscito = math.random(0, 36)
    local rossi = { [1]=true,[3]=true,[5]=true,[7]=true,[9]=true,[12]=true,[14]=true,[16]=true,
                    [18]=true,[19]=true,[21]=true,[23]=true,[25]=true,[27]=true,[30]=true,
                    [32]=true,[34]=true,[36]=true }

    local vinta = false
    if uscito ~= 0 then
        if tipo == 'pieno' then vinta = (tonumber(numero) == uscito)
        elseif tipo == 'rosso' then vinta = rossi[uscito] == true
        elseif tipo == 'nero' then vinta = not rossi[uscito]
        elseif tipo == 'pari' then vinta = (uscito % 2 == 0)
        elseif tipo == 'dispari' then vinta = (uscito % 2 == 1)
        elseif tipo == 'dozzina' then
            local d = tonumber(numero) or 1
            vinta = uscito > (d - 1) * 12 and uscito <= d * 12
        end
    end

    local vincita = vinta and importo * (scommessa.quota + 1) or 0
    regola(g, importo, vincita)

    rispondi({
        numero = uscito,
        colore = uscito == 0 and 'verde' or (rossi[uscito] and 'rosso' or 'nero'),
        vinta = vinta, vincita = vincita, puntata = importo,
    })
end)

-- ---------------------------------------------------------------------------
--  Slot
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cas:slot', function(src, rispondi, puntata)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local ok, errore, t, importo = puoGiocare(g, src, 'slot', puntata)
    if not ok then return rispondi(nil, errore) end

    -- I rulli non sono uniformi: i simboli che pagano di più escono meno.
    -- È così che il margine del banco diventa quello dichiarato.
    local pesi = {}
    for n, c in ipairs(t.combinazioni) do
        pesi[#pesi + 1] = { simbolo = c.simbolo, peso = n * n, quota = c.quota }
    end

    local totale = 0
    for _, p in ipairs(pesi) do totale = totale + p.peso end

    local function estrai()
        local r = math.random() * totale
        local acc = 0
        for _, p in ipairs(pesi) do
            acc = acc + p.peso
            if r <= acc then return p end
        end
        return pesi[#pesi]
    end

    local rulli = { estrai(), estrai(), estrai() }
    local vincita = 0

    if rulli[1].simbolo == rulli[2].simbolo and rulli[2].simbolo == rulli[3].simbolo then
        vincita = importo * rulli[1].quota
    elseif rulli[1].simbolo == rulli[2].simbolo or rulli[2].simbolo == rulli[3].simbolo then
        -- Due uguali: si recupera la puntata sui simboli bassi
        if rulli[2].quota <= 3 then vincita = importo end
    end

    regola(g, importo, vincita)

    rispondi({
        rulli = { rulli[1].simbolo, rulli[2].simbolo, rulli[3].simbolo },
        vinta = vincita > 0, vincita = vincita, puntata = importo,
    })
end)

-- ---------------------------------------------------------------------------
--  Blackjack
--
--  Una mano sola per volta: si pesca finché non si sta, poi gioca il
--  banco con la regola dei casinò (tira sotto 17, sta a 17).
-- ---------------------------------------------------------------------------
local mani = {}     -- [src] = { mazzo, giocatore, banco, puntata }

local function nuovoMazzo()
    local mazzo = {}
    for _ = 1, 6 do          -- sei mazzi, come al tavolo
        for _, v in ipairs({ 2,3,4,5,6,7,8,9,10,10,10,10,11 }) do
            for _ = 1, 4 do mazzo[#mazzo + 1] = v end
        end
    end
    for i = #mazzo, 2, -1 do
        local j = math.random(i)
        mazzo[i], mazzo[j] = mazzo[j], mazzo[i]
    end
    return mazzo
end

local function punteggio(carte)
    local somma, assi = 0, 0
    for _, c in ipairs(carte) do
        somma = somma + c
        if c == 11 then assi = assi + 1 end
    end
    while somma > 21 and assi > 0 do somma = somma - 10 assi = assi - 1 end
    return somma
end

AUREA.Callback.Registra('cas:blackjackApri', function(src, rispondi, puntata)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if mani[src] then return rispondi(nil, 'Hai già una mano aperta.') end

    local ok, errore, t, importo = puoGiocare(g, src, 'blackjack', puntata)
    if not ok then return rispondi(nil, errore) end

    local mazzo = nuovoMazzo()
    local giocatore = { table.remove(mazzo), table.remove(mazzo) }
    local banco = { table.remove(mazzo) }

    mani[src] = { mazzo = mazzo, giocatore = giocatore, banco = banco, puntata = importo }

    rispondi({
        giocatore = giocatore, punteggio = punteggio(giocatore),
        banco = banco, puntoBanco = punteggio(banco),
        puntata = importo,
        blackjack = punteggio(giocatore) == 21,
    })
end)

AUREA.Callback.Registra('cas:blackjackCarta', function(src, rispondi)
    local m = mani[src]
    if not m then return rispondi(nil, 'Nessuna mano aperta.') end

    m.giocatore[#m.giocatore + 1] = table.remove(m.mazzo)
    local p = punteggio(m.giocatore)

    rispondi({ giocatore = m.giocatore, punteggio = p, sballato = p > 21 })
end)

AUREA.Callback.Registra('cas:blackjackChiudi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local m = mani[src]
    if not g or not m then return rispondi(nil, 'Nessuna mano aperta.') end
    mani[src] = nil

    local mio = punteggio(m.giocatore)
    local t = CAS.Tavoli.blackjack

    -- Il banco tira finché non arriva a 17
    while punteggio(m.banco) < 17 do
        m.banco[#m.banco + 1] = table.remove(m.mazzo)
    end
    local suo = punteggio(m.banco)

    local vincita, esito = 0, ''
    if mio > 21 then
        esito = 'Hai sballato.'
    elseif mio == 21 and #m.giocatore == 2 then
        vincita = math.floor(m.puntata * (1 + t.pagamentoBlackjack))
        esito = 'Blackjack!'
    elseif suo > 21 then
        vincita = m.puntata * 2
        esito = 'Il banco ha sballato.'
    elseif mio > suo then
        vincita = m.puntata * 2
        esito = 'Hai battuto il banco.'
    elseif mio == suo then
        vincita = m.puntata
        esito = 'Pareggio: la puntata torna.'
    else
        esito = 'Vince il banco.'
    end

    regola(g, m.puntata, vincita)

    rispondi({
        giocatore = m.giocatore, punteggio = mio,
        banco = m.banco, puntoBanco = suo,
        vincita = vincita, puntata = m.puntata, esito = esito,
    })
end)

AddEventHandler('playerDropped', function() mani[source] = nil end)
