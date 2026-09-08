--[[
    AUREA · Telefono — chiamate (server)

    Il telefono non trasporta la voce: quella la fa aurea_voce, che si
    appoggia a pma-voice. Qui si decide soltanto chi sta parlando con chi,
    e si scrive il tabulato.

    Il tabulato è la parte che vale la pena avere. Una chiamata lascia una
    riga con mittente, destinatario, esito e durata, e la polizia
    giudiziaria può chiederla. Non c'è il contenuto — quello è voce e non
    si registra — ma il fatto che due numeri si siano parlati alle tre di
    notte è già un'informazione, ed è esattamente il genere di informazione
    su cui si costruisce un'indagine.
]]

local U = AUREA.Util

Chiamate = {}

local attive = {}       -- [id] = { chiamante, chiamato, dalle, accettata }
local perSource = {}    -- [src] = id
local contatore = 0

-- ---------------------------------------------------------------------------
--  Voce
-- ---------------------------------------------------------------------------
local function collegaVoce(a, b, attiva)
    pcall(function() exports.aurea_voce:Telefonata(a, b, attiva) end)
end

-- ---------------------------------------------------------------------------
--  Registro
-- ---------------------------------------------------------------------------
local function scriviTabulato(mittente, destinatario, esito, secondi)
    MySQL.insert('INSERT INTO tel_chiamate (mittente, destinatario, esito, secondi) VALUES (?, ?, ?, ?)',
        { mittente, destinatario, esito, math.max(0, math.floor(secondi or 0)) })
end

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
function Chiamate.Avvia(g, numero)
    numero = tostring(numero or ''):gsub('%D', '')
    if #numero < 3 then return false, 'Numero non valido.' end
    if numero == g.telefono then return false, 'Non puoi chiamare te stesso.' end

    -- I numeri di emergenza non passano di qui: hanno la loro app
    if TEL.GetEmergenza(numero) then
        return { ok = true, chiudi = true,
                 eventoClient = { nome = 'nue:apriChiamata', dati = TEL.GetEmergenza(numero).ente } }
    end

    if perSource[g.source] then return false, 'Sei già in chiamata.' end

    local destinatario = AUREA.GetPlayerByTelefono(numero)

    if not destinatario then
        scriviTabulato(g.telefono, numero, 'persa', 0)
        return false, 'Il numero non è raggiungibile.'
    end

    if perSource[destinatario.source] then
        scriviTabulato(g.telefono, numero, 'persa', 0)
        return false, 'La persona è già in conversazione.'
    end

    local impostazioni = Registro.Impostazioni(destinatario)
    if impostazioni.nonDisturbare then
        scriviTabulato(g.telefono, numero, 'persa', 0)
        return false, 'La persona ha il telefono in "non disturbare".'
    end

    contatore = contatore + 1
    local id = contatore

    local mie = Registro.Impostazioni(g)
    local rubricaDestinatario = MySQL.scalar.await(
        'SELECT nome FROM tel_contatti WHERE citizenid = ? AND numero = ? LIMIT 1',
        { destinatario.citizenid, g.telefono })

    attive[id] = {
        id = id,
        chiamante = g.source, chiamato = destinatario.source,
        numeroChiamante = g.telefono, numeroChiamato = numero,
        dalle = os.time(), accettata = false,
        anonimo = mie.anonimo == true,
    }
    perSource[g.source] = id
    perSource[destinatario.source] = id

    TriggerClientEvent('tel:squillo', destinatario.source, {
        id = id,
        -- Il numero nascosto lo è per il destinatario, non per il tabulato
        numero = attive[id].anonimo and 'Anonimo' or g.telefono,
        nome = attive[id].anonimo and 'Numero privato' or (rubricaDestinatario or g.telefono),
        entrante = true,
    })

    TriggerClientEvent('tel:squillo', g.source, {
        id = id, numero = numero,
        nome = MySQL.scalar.await(
            'SELECT nome FROM tel_contatti WHERE citizenid = ? AND numero = ? LIMIT 1',
            { g.citizenid, numero }) or numero,
        entrante = false,
    })

    -- Se non risponde entro il tempo dello squillo, la chiamata cade
    CreateThread(function()
        Wait(TEL.Chiamate.secondiSquillo * 1000)
        local c = attive[id]
        if c and not c.accettata then
            Chiamate.Chiudi(id, 'persa')
        end
    end)

    return { ok = true, chiudi = true }
end

-- ---------------------------------------------------------------------------
--  Risposta e chiusura
-- ---------------------------------------------------------------------------
RegisterNetEvent('tel:rispondi', function(id, accetta)
    local src = source
    local c = attive[tonumber(id) or 0]
    if not c or c.chiamato ~= src then return end

    if not accetta then
        return Chiamate.Chiudi(c.id, 'rifiutata')
    end

    c.accettata = true
    c.dalle = os.time()

    collegaVoce(c.chiamante, c.chiamato, true)

    TriggerClientEvent('tel:chiamataAttiva', c.chiamante, c.id)
    TriggerClientEvent('tel:chiamataAttiva', c.chiamato, c.id)
end)

RegisterNetEvent('tel:riaggancia', function(id)
    local src = source
    local c = attive[tonumber(id) or 0]
    if not c or (c.chiamante ~= src and c.chiamato ~= src) then return end
    Chiamate.Chiudi(c.id, c.accettata and 'conclusa' or 'persa')
end)

function Chiamate.Chiudi(id, esito)
    local c = attive[id]
    if not c then return end

    attive[id] = nil
    perSource[c.chiamante] = nil
    perSource[c.chiamato] = nil

    collegaVoce(c.chiamante, c.chiamato, false)

    scriviTabulato(c.numeroChiamante, c.numeroChiamato, esito,
        c.accettata and (os.time() - c.dalle) or 0)

    TriggerClientEvent('tel:chiamataChiusa', c.chiamante, esito)
    TriggerClientEvent('tel:chiamataChiusa', c.chiamato, esito)
end

--- Chi si disconnette a metà chiamata la chiude per l'altro.
AddEventHandler('playerDropped', function()
    local id = perSource[source]
    if id then Chiamate.Chiudi(id, 'conclusa') end
end)

-- ---------------------------------------------------------------------------
--  Tabulati
--
--  Non c'è il contenuto: c'è chi ha chiamato chi, quando e per quanto. È
--  quello che si ottiene davvero con un'acquisizione di tabulati.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tel:tabulati', function(src, rispondi, numero)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene(TEL.Chiamate.lavoriTabulati, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi({}, 'L\'acquisizione dei tabulati è riservata alla polizia giudiziaria in servizio.')
    end

    numero = tostring(numero or ''):gsub('%D', '')
    if #numero < 3 then return rispondi({}, 'Numero non valido.') end

    local righe = MySQL.query.await([[
        SELECT mittente, destinatario, esito, secondi, momento
        FROM tel_chiamate
        WHERE (mittente = ? OR destinatario = ?)
          AND momento > DATE_SUB(NOW(), INTERVAL ? DAY)
        ORDER BY id DESC LIMIT 60
    ]], { numero, numero, TEL.Chiamate.giorniTabulati })

    local intestatario = MySQL.scalar.await(
        'SELECT CONCAT(nome, \' \', cognome) FROM personaggi WHERE telefono = ? LIMIT 1', { numero })

    AUREA.Log('giustizia', 'info', g, ('ha acquisito i tabulati del numero %s'):format(numero))

    rispondi(righe or {}, nil, intestatario)
end)

--- Il comando per la polizia giudiziaria: sta fuori dal telefono perché è
--- un atto d'ufficio, non una app che ti porti in tasca.
AUREA.Comando('tabulati', 'utente', 'Acquisisce i tabulati di un numero (polizia giudiziaria)', {
    { name = 'numero', help = 'Numero da acquisire' },
}, function(src, args, _, g)
    if not g then return end

    local numero = (args[1] or ''):gsub('%D', '')
    if #numero < 3 then
        return TriggerClientEvent('aurea:ui:notifica', src,
            { tipo = 'errore', titolo = 'Uso', testo = '/tabulati <numero>' })
    end

    TriggerClientEvent('tel:apriTabulati', src, numero)
end)
