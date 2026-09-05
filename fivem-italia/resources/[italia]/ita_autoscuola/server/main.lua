--[[
    AUREA · Autoscuola (server)

    Le risposte giuste non escono mai dal server. Al client vanno domanda
    e alternative mescolate; la correzione la fa qui.
]]

local U = AUREA.Util
local quiz = {}         -- [src] = { categoria, domande, indici, risposte }
local pratiche = {}     -- [src] = { categoria, avviata, punti, tappa }

local function ultimoTentativo(g, chiave)
    return math.floor(tonumber(g:Get('asc_' .. chiave)) or 0)
end

-- ---------------------------------------------------------------------------
--  Sportello
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asc:sportello', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local possedute = MySQL.query.await(
        'SELECT categoria FROM patenti WHERE citizenid = ? AND ritirata = 0', { g.citizenid }) or {}
    local ho = {}
    for _, p in ipairs(possedute) do ho[p.categoria] = true end

    local out = {}
    for id, c in pairs(ASC.Categorie) do
        local teoriaPassata = ultimoTentativo(g, 'teoria_' .. id)
        local valida = teoriaPassata > 0
            and (os.time() - teoriaPassata) < ASC.Regole.validitaTeoriaMinuti * 60

        local motivo = nil
        if ho[id] then motivo = 'la possiedi già'
        elseif c.richiede and not ho[c.richiede] then
            motivo = ('serve prima la patente %s'):format(c.richiede)
        end

        out[#out + 1] = {
            id = id, nome = c.nome, descrizione = c.descrizione,
            costoTeoria = c.costoTeoria, costoPratica = c.costoPratica,
            posseduta = ho[id] == true,
            teoriaValida = valida,
            minutiResiduiTeoria = valida
                and math.floor(ASC.Regole.validitaTeoriaMinuti - (os.time() - teoriaPassata) / 60) or nil,
            bloccata = motivo,
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)

    rispondi({ categorie = out })
end)

-- ---------------------------------------------------------------------------
--  Teoria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asc:teoria', function(src, rispondi, categoria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c = ASC.GetCategoria(categoria)
    if not c then return rispondi(nil, 'Categoria non prevista.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - ASC.Sede.aula) > 6.0 then
        return rispondi(nil, 'L\'esame di teoria si fa in aula.')
    end

    local ultimo = ultimoTentativo(g, 'bocciato_' .. categoria)
    local attesa = ASC.Regole.minutiRitentare * 60 - (os.time() - ultimo)
    if ultimo > 0 and attesa > 0 then
        return rispondi(nil, ('Puoi ripetere fra %d minuti.'):format(math.ceil(attesa / 60)))
    end

    if not g:SottraiOvunque(c.costoTeoria, ('esame di teoria %s'):format(c.nome)) then
        return rispondi(nil, ('L\'esame costa %s.'):format(U.Euro(c.costoTeoria)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_motorizzazione', c.costoTeoria, g.citizenid)

    -- Si estraggono le domande e si mescolano le alternative
    local pool = {}
    for n = 1, #ASC.Domande do pool[n] = n end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local domande, indici = {}, {}
    for n = 1, math.min(c.domandeEsame, #pool) do
        local d = ASC.Domande[pool[n]]

        local ordine = {}
        for k = 1, #d.r do ordine[k] = k end
        for i = #ordine, 2, -1 do
            local j = math.random(i)
            ordine[i], ordine[j] = ordine[j], ordine[i]
        end

        local risposte, giustaMescolata = {}, nil
        for k, originale in ipairs(ordine) do
            risposte[k] = d.r[originale]
            if originale == d.giusta then giustaMescolata = k end
        end

        domande[n] = { testo = d.d, risposte = risposte }
        indici[n] = giustaMescolata
    end

    quiz[src] = { categoria = categoria, indici = indici, risposte = {} }

    rispondi({
        categoria = categoria, nome = c.nome,
        domande = domande,
        erroriAmmessi = c.erroriAmmessi,
    })
end)

AUREA.Callback.Registra('asc:consegnaTeoria', function(src, rispondi, risposte)
    local g = AUREA.GetPlayer(src)
    local q = quiz[src]
    if not g or not q then return rispondi(nil, 'Nessun esame in corso.') end
    quiz[src] = nil

    local c = ASC.GetCategoria(q.categoria)
    local errori, dettaglio = 0, {}

    for n, giusta in ipairs(q.indici) do
        local data = tonumber(risposte and risposte[n])
        local corretta = data == giusta
        if not corretta then errori = errori + 1 end
        dettaglio[n] = { corretta = corretta, giusta = giusta }
    end

    local passato = errori <= c.erroriAmmessi

    if passato then
        g:Set('asc_teoria_' .. q.categoria, os.time(), true)
        g:Set('asc_bocciato_' .. q.categoria, 0, false)
    else
        g:Set('asc_bocciato_' .. q.categoria, os.time(), false)
    end

    MySQL.update('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
        { json.encode(g.metadata), g.citizenid })

    AUREA.Log('veicoli', 'debug', g,
        ('esame di teoria %s: %d errori, %s'):format(q.categoria, errori, passato and 'idoneo' or 'respinto'))

    rispondi({
        passato = passato, errori = errori, ammessi = c.erroriAmmessi,
        dettaglio = dettaglio,
        messaggio = passato
            and ('Idoneo con %d errori. Hai %d minuti per fare la pratica.')
                :format(errori, ASC.Regole.validitaTeoriaMinuti)
            or ('Respinto: %d errori su %d ammessi. Puoi ripetere fra %d minuti.')
                :format(errori, c.erroriAmmessi, ASC.Regole.minutiRitentare),
    })
end)

-- ---------------------------------------------------------------------------
--  Pratica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asc:pratica', function(src, rispondi, categoria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c = ASC.GetCategoria(categoria)
    if not c then return rispondi(nil, 'Categoria non prevista.') end

    local teoria = ultimoTentativo(g, 'teoria_' .. categoria)
    if teoria == 0 or (os.time() - teoria) > ASC.Regole.validitaTeoriaMinuti * 60 then
        return rispondi(nil, 'Devi prima superare la teoria, e la pratica va fatta entro il termine.')
    end

    if not g:SottraiOvunque(c.costoPratica, ('esame di guida %s'):format(c.nome)) then
        return rispondi(nil, ('L\'esame di guida costa %s.'):format(U.Euro(c.costoPratica)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_motorizzazione', c.costoPratica, g.citizenid)

    pratiche[src] = { categoria = categoria, avviata = os.time(), punti = 0 }

    rispondi({
        categoria = categoria, modello = c.modello,
        partenza = { x = ASC.Sede.partenzaEsame.x, y = ASC.Sede.partenzaEsame.y,
                     z = ASC.Sede.partenzaEsame.z, w = ASC.Sede.partenzaEsame.w },
        percorso = ASC.Pratica.percorso,
        soglia = ASC.Pratica.sogliaBocciatura,
        durata = ASC.Pratica.durataMassima,
    })
end)

--- Il client segnala gli errori mentre guida: qui si sommano.
RegisterNetEvent('asc:errore', function(tipo)
    local src = source
    local p = pratiche[src]
    if not p then return end

    local costo = ASC.Pratica.penalita[tipo]
    if not costo then return end

    p.punti = p.punti + costo
    TriggerClientEvent('asc:penalita', src, tipo, costo, p.punti)
end)

AUREA.Callback.Registra('asc:concludiPratica', function(src, rispondi, completato)
    local g = AUREA.GetPlayer(src)
    local p = pratiche[src]
    if not g or not p then return rispondi(nil, 'Nessun esame in corso.') end
    pratiche[src] = nil

    local durata = os.time() - p.avviata
    local passato = completato and p.punti < ASC.Pratica.sogliaBocciatura
        and durata <= ASC.Pratica.durataMassima

    if not passato then
        g:Set('asc_bocciato_' .. p.categoria, os.time(), false)
        return rispondi({
            passato = false, punti = p.punti,
            messaggio = not completato and 'Non hai completato il percorso.'
                or (durata > ASC.Pratica.durataMassima and 'Tempo scaduto.'
                    or ('Troppi errori: %d punti su %d ammessi.')
                        :format(p.punti, ASC.Pratica.sogliaBocciatura)),
        })
    end

    -- Idoneo: si emette la patente
    exports.ita_codicestrada:RilasciaPatente(g.citizenid, p.categoria)

    g:Set('asc_teoria_' .. p.categoria, 0, false)
    MySQL.update('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
        { json.encode(g.metadata), g.citizenid })

    AUREA.Log('veicoli', 'info', g, ('ha conseguito la patente %s'):format(p.categoria))

    rispondi({
        passato = true, punti = p.punti,
        messaggio = ('Idoneo con %d punti di penalità. Patente %s rilasciata: venti punti, e da adesso sono affari tuoi.')
            :format(p.punti, p.categoria),
    })
end)

AddEventHandler('playerDropped', function()
    quiz[source] = nil
    pratiche[source] = nil
end)
