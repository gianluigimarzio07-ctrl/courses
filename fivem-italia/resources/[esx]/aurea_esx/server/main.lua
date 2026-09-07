--[[
    AUREA su ESX (server)

    Il punto delicato di tutta la risorsa è uno solo: come fare in modo che
    Giocatore:Aggiungi('contanti', 5000) finisca davvero nel portafoglio
    ESX, e non in una seconda contabilità parallela che poi diverge.

    La soluzione è sostituire i metodi del denaro sulla singola istanza.
    In Lua, se scrivi g.Aggiungi = ..., quel campo copre il metodo del
    metatable per quell'oggetto e per nessun altro. Quindi il Giocatore
    creato qui ha metodi del denaro che parlano con xPlayer, mentre tutto
    il resto del framework resta identico e non se ne accorge.

    Le 78 risorse AUREA continuano a chiamare g:Aggiungi, g:Sottrai e
    g:SottraiOvunque come hanno sempre fatto. Nessuna di loro sa che sotto
    c'è ESX, e nessuna va modificata.
]]

local ESX
local U = AUREA.Util
local C = AUREA.Config

local sincronizzati = {}   -- [source] = true

CreateThread(function()
    local tentativi = 0
    while not ESX and tentativi < 50 do
        local ok, oggetto = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and type(oggetto) == 'table' then ESX = oggetto end
        tentativi = tentativi + 1
        Wait(200)
    end

    if not ESX then
        print('[aurea_esx] es_extended non risponde. Questa risorsa serve solo se usi il VERO '
            .. 'es_extended come framework. Se invece vuoi ESX costruito sopra AUREA, spegni '
            .. 'aurea_esx e accendi [esx]/es_extended.')
        return
    end

    print('[aurea_esx] Agganciato a es_extended. AUREA gira sopra ESX.')
end)

-- ---------------------------------------------------------------------------
--  Il denaro: metodi sostituiti sull'istanza
-- ---------------------------------------------------------------------------
local function collegaDenaro(g, identificatore)
    local function x()
        return ESX and ESX.GetPlayerFromId(g.source) or nil
    end

    --- Rilegge i saldi da ESX dentro la cache del Giocatore, così le
    --- letture (g:Saldo, g.denaro.contanti) restano istantanee.
    function g:AggiornaDenaroDaESX()
        local px = x()
        if not px then return end
        self.denaro.contanti = AEC.ACentesimi(px:getAccount('money').money)
        self.denaro.banca = AEC.ACentesimi(px:getAccount('bank').money)
    end

    function g:Aggiungi(conto, importo, causale)
        importo = math.floor(tonumber(importo) or 0)
        if importo <= 0 then return false end

        local contoESX = AEC.Conti[conto]
        if not contoESX then return false end

        local px = x()
        if not px then return false end

        px:addAccountMoney(contoESX, AEC.AEuro(importo), causale or 'AUREA')
        self:AggiornaDenaroDaESX()
        self:SincronizzaDenaro()

        AUREA.Log('denaro', 'info', self, ('+%s su %s — %s'):format(U.Euro(importo), conto, causale or 'n.d.'))
        TriggerEvent('aurea:denaro:variato', self.source, conto, importo, causale)
        return true
    end

    function g:Sottrai(conto, importo, causale)
        importo = math.floor(tonumber(importo) or 0)
        if importo <= 0 then return false end

        local contoESX = AEC.Conti[conto]
        if not contoESX then return false end

        local px = x()
        if not px then return false end

        -- ESX non rifiuta sempre lo scoperto: il controllo lo facciamo qui.
        if AEC.ACentesimi(px:getAccount(contoESX).money) < importo then return false end

        px:removeAccountMoney(contoESX, AEC.AEuro(importo), causale or 'AUREA')
        self:AggiornaDenaroDaESX()
        self:SincronizzaDenaro()

        AUREA.Log('denaro', 'info', self, ('-%s da %s — %s'):format(U.Euro(importo), conto, causale or 'n.d.'))
        TriggerEvent('aurea:denaro:variato', self.source, conto, -importo, causale)
        return true
    end

    -- SottraiOvunque nel core chiama Sottrai, che qui è già sostituito:
    -- si eredita corretto senza toccarlo.

    g:AggiornaDenaroDaESX()
end

-- ---------------------------------------------------------------------------
--  Il lavoro
-- ---------------------------------------------------------------------------
local function collegaLavoro(g)
    local originale = g.ImpostaLavoro

    function g:ImpostaLavoro(nome, grado)
        if not AUREA.Lavori[nome] then return false end

        -- Prima ESX, che è l'autorità: se rifiuta non si cambia niente.
        local px = ESX and ESX.GetPlayerFromId(self.source)
        if px then px:setJob(nome, tonumber(grado) or 0) end

        self.lavoro.nome = nome
        self.lavoro.grado = tonumber(grado) or 0
        self.lavoro.servizio = false
        self:Sincronizza()
        TriggerEvent('aurea:lavoro:cambiato', self.source, nome, self.lavoro.grado)
        return true
    end
end

-- ---------------------------------------------------------------------------
--  Trovare o creare il personaggio AUREA per un identifier ESX
-- ---------------------------------------------------------------------------
local function personaggioPer(px)
    local identificatore = px:getIdentifier()

    local riga = MySQL.single.await(
        'SELECT * FROM personaggi WHERE esx_identifier = ? AND eliminato = 0 LIMIT 1',
        { identificatore })
    if riga then return riga end

    -- Non c'è: si crea, ricavando da ESX quello che ESX sa.
    local nomeCompleto = px:getName() or ''
    local nome, cognome = nomeCompleto:match('^(%S+)%s+(.+)$')
    nome = (nome or nomeCompleto):gsub('[^%a]', ''):sub(1, 24)
    cognome = (cognome or ''):gsub('[^%a]', ''):sub(1, 24)

    if #nome < 2 then nome = AEC.PrimoAccesso.nomeRipiego end
    if #cognome < 2 then cognome = AEC.PrimoAccesso.cognomeRipiego end

    local comune = AEC.PrimoAccesso.comuneRipiego
    local sigla = 'RM'
    for _, p in ipairs(C.Province) do
        if p.comune == comune then sigla = p.sigla break end
    end

    local nascita = AEC.PrimoAccesso.nascitaRipiego
    local sesso = 'M'

    local citizenid = AUREA.Anagrafe.NuovoCitizenId(sigla)
    local cf = AUREA.Anagrafe.NuovoCodiceFiscale(cognome, nome, nascita, sesso, comune)
    local telefono = AUREA.Anagrafe.NuovoTelefono()

    -- L'account AUREA serve per i gruppi staff e le sanzioni: si crea
    -- agganciato alla stessa licenza che usa ESX.
    local license = identificatore:gsub('^license:', '')
    local account = MySQL.single.await('SELECT * FROM account WHERE license = ?', { license })
    if not account then
        local id = MySQL.insert.await(
            'INSERT INTO account (license, nome_discord, slot_massimi) VALUES (?, ?, ?)',
            { license, nomeCompleto, 1 })
        account = { id = id }
    end

    MySQL.insert.await([[
        INSERT INTO personaggi
            (citizenid, account_id, slot, nome, cognome, data_nascita, luogo_nascita, sesso,
             codice_fiscale, telefono, contanti, banca, lavoro, posizione, stato, metadata,
             esx_identifier)
        VALUES (?, ?, 1, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?)
    ]], {
        citizenid, account.id, nome, cognome, nascita, comune, sesso,
        cf, telefono, px:getJob().name or 'disoccupato',
        json.encode(C.Avvio.posizione),
        json.encode({ fame = 100, sete = 100, stress = 0, salute = 200, armatura = 0, alcol = 0, energia = 100 }),
        json.encode({}),
        identificatore,
    })

    if AEC.PrimoAccesso.apriConto then
        local iban = AUREA.Anagrafe.NuovoIBAN(account.id)
        local saldo = AEC.ACentesimi(px:getAccount('bank').money)
        MySQL.insert.await('INSERT INTO conti (iban, intestatario, tipo, nome, saldo) VALUES (?, ?, ?, ?, ?)',
            { iban, citizenid, 'personale', 'Conto corrente', saldo })
        MySQL.update.await('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
            { json.encode({ iban = iban }), citizenid })
    end

    if AEC.PrimoAccesso.consegnaCorredo then
        TriggerEvent('aurea:inventario:corredoIniziale', citizenid, C.Avvio.corredo)
    end

    AUREA.Log('connessioni', 'info', nil,
        ('Personaggio AUREA creato da ESX: %s %s (%s) — CF %s'):format(nome, cognome, citizenid, cf))

    return MySQL.single.await('SELECT * FROM personaggi WHERE citizenid = ?', { citizenid })
end

-- ---------------------------------------------------------------------------
--  Ingresso
-- ---------------------------------------------------------------------------
AddEventHandler('esx:playerLoaded', function(src, px)
    if not px then return end
    if sincronizzati[src] then return end

    CreateThread(function()
        local riga = personaggioPer(px)
        if not riga then
            return print(('[aurea_esx] impossibile preparare il personaggio AUREA per %d'):format(src))
        end

        local license = px:getIdentifier():gsub('^license:', '')
        local account = MySQL.single.await('SELECT * FROM account WHERE id = ?', { riga.account_id })
            or { id = riga.account_id, license = license, gruppo = 'utente' }
        account.license = account.license or license

        -- Il lavoro autoritativo è quello ESX
        local lavoroESX = px:getJob()
        if AUREA.Lavori[lavoroESX.name] then
            riga.lavoro = lavoroESX.name
            riga.lavoro_grado = lavoroESX.grade or 0
        end

        local g = AUREA.CostruisciGiocatore(src, riga, account)

        collegaDenaro(g, px:getIdentifier())
        collegaLavoro(g)

        AUREA.Giocatori[src] = g
        AUREA.PerCitizenId[g.citizenid] = src
        sincronizzati[src] = true

        -- Il nero ESX diventa banconote AUREA una volta sola
        if AEC.Nero.convertiAllIngresso then
            local nero = AEC.ACentesimi(px:getAccount('black_money').money)
            local unita = math.floor(nero / AEC.Nero.valoreUnita)
            if unita > 0 then
                local inv = exports.aurea_inventory:Inventario(g.citizenid)
                if inv:Aggiungi(AEC.Nero.oggetto, unita) then
                    px:removeAccountMoney('black_money', AEC.AEuro(unita * AEC.Nero.valoreUnita),
                        'conversione in banconote')
                end
            end
        end

        MySQL.update('UPDATE personaggi SET ultimo_uso = NOW() WHERE citizenid = ?', { g.citizenid })

        AUREA.Log('connessioni', 'info', g, ('%s è entrato in gioco (via ESX)'):format(g:NomeCompleto()))
        TriggerEvent('aurea:giocatore:caricato', src, g)
        TriggerClientEvent('aurea:giocatore:caricato', src, g:Pacchetto(), g.aspetto)
    end)
end)

-- ---------------------------------------------------------------------------
--  Uscita
-- ---------------------------------------------------------------------------
local function scarica(src)
    local g = AUREA.Giocatori[src]
    if not g then return end

    TriggerEvent('aurea:giocatore:scaricato', src, g)
    pcall(function() g:Salva() end)

    AUREA.PerCitizenId[g.citizenid] = nil
    AUREA.Giocatori[src] = nil
    sincronizzati[src] = nil
end

AddEventHandler('esx:playerDropped', function(src) scarica(src) end)
AddEventHandler('playerDropped', function() scarica(source) end)

-- ---------------------------------------------------------------------------
--  Il lavoro cambiato da ESX
-- ---------------------------------------------------------------------------
AddEventHandler('esx:setJob', function(src, lavoro)
    local g = AUREA.Giocatori[src]
    if not g or not lavoro then return end
    if not AUREA.Lavori[lavoro.name] then return end
    if g.lavoro.nome == lavoro.name and g.lavoro.grado == (lavoro.grade or 0) then return end

    g.lavoro.nome = lavoro.name
    g.lavoro.grado = lavoro.grade or 0
    g.lavoro.servizio = false
    g:Sincronizza()
    TriggerEvent('aurea:lavoro:cambiato', src, g.lavoro.nome, g.lavoro.grado)
end)

-- ---------------------------------------------------------------------------
--  Riallineamento periodico del denaro
--
--  Serve perché uno script esx_* può togliere o dare soldi senza passare
--  da noi. Non è bello, ma è l'unico modo onesto: ESX non emette un evento
--  su ogni movimento.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(AEC.Sincronia.secondiDenaro * 1000)
        if ESX then
            for src, g in pairs(AUREA.Giocatori) do
                if g.AggiornaDenaroDaESX then
                    local prima = g.denaro.contanti + g.denaro.banca
                    g:AggiornaDenaroDaESX()
                    if (g.denaro.contanti + g.denaro.banca) ~= prima then
                        g:SincronizzaDenaro()
                    end
                end
            end
        end
    end
end)

--- Salvataggio periodico della parte AUREA (posizione, stato, metadata).
--- Il denaro non lo salva: quello è di ESX e lo salva ESX.
CreateThread(function()
    while true do
        Wait(AEC.Sincronia.secondiSalvataggio * 1000)
        for _, g in pairs(AUREA.Giocatori) do
            pcall(function() g:Salva() end)
        end
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, g in pairs(AUREA.Giocatori) do
        pcall(function() g:Salva() end)
    end
end)

-- ---------------------------------------------------------------------------
--  La posizione salvata, per il client
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('aesx:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    rispondi(g.posizione)
end)

-- ---------------------------------------------------------------------------
--  Diagnostica
-- ---------------------------------------------------------------------------
AUREA.Comando('aureaesx', 'admin', 'Stato del ponte AUREA/ESX', {}, function(src)
    local righe = {
        ('es_extended agganciato: %s'):format(ESX and 'sì' or 'NO'),
        ('Giocatori AUREA in gioco: %d'):format(#AUREA.GetGiocatori()),
        ('Autorità denaro: %s · lavoro: %s'):format(AEC.Autorita.denaro, AEC.Autorita.lavoro),
    }

    if src > 0 then
        TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = ESX and 'successo' or 'errore', icona = '🔗', durata = 15000,
            titolo = 'Ponte AUREA · ESX', testo = table.concat(righe, '\n'),
        })
    else
        for _, r in ipairs(righe) do print('[aurea_esx] ' .. r) end
    end
end)
