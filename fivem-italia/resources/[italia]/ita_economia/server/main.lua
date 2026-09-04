--[[
    AUREA · Motore economico (server)
]]

local U = AUREA.Util
local moltiplicatoreEvento = 1.0

-- ---------------------------------------------------------------------------
--  Registrazione degli scambi
-- ---------------------------------------------------------------------------

--- Un acquisto alza la domanda del bene.
AddEventHandler('aurea:economia:domanda', function(righe)
    for _, r in ipairs(righe or {}) do
        MySQL.update([[
            UPDATE mercato SET domanda = LEAST(?, domanda + ?) WHERE item = ?
        ]], { ECO.Squilibri.massimo, (r.quantita or 1) * ECO.Squilibri.domandaPerUnita, r.item })
    end
end)

--- Un conferimento alza l'offerta.
AddEventHandler('aurea:economia:offerta', function(righe)
    for _, r in ipairs(righe or {}) do
        MySQL.update([[
            UPDATE mercato SET offerta = LEAST(?, offerta + ?) WHERE item = ?
        ]], { ECO.Squilibri.massimo, (r.quantita or 1) * ECO.Squilibri.offertaPerUnita, r.item })
    end
end)

-- ---------------------------------------------------------------------------
--  Indice dei prezzi
-- ---------------------------------------------------------------------------
local function leggiStato(chiave, predefinito)
    local v = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?', { chiave })
    return v and tonumber(v) or predefinito
end

local function scriviStato(chiave, valore)
    MySQL.query.await([[
        INSERT INTO economia_stato (chiave, valore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { chiave, tostring(valore) })
end

--- La massa monetaria è tutto il denaro in mano ai personaggi.
local function massaMonetaria()
    local riga = MySQL.single.await('SELECT SUM(contanti) AS c, SUM(banca) AS b FROM personaggi WHERE eliminato = 0')
    if not riga then return 0 end
    return (tonumber(riga.c) or 0) + (tonumber(riga.b) or 0)
end

local function aggiornaIndice()
    local massa = massaMonetaria()
    local indice = leggiStato('indice_prezzi', 100)

    -- Scostamento dalla massa di riferimento
    local scostamento = (massa - ECO.Inflazione.massaRiferimento) / ECO.Inflazione.massaRiferimento
    local obiettivo = 100 * (1 + scostamento * ECO.Inflazione.sensibilita)

    -- l'indice si muove lentamente verso l'obiettivo
    indice = indice + (obiettivo - indice) * 0.2
    indice = U.Clamp(indice, ECO.Inflazione.minimo, ECO.Inflazione.massimo)

    scriviStato('indice_prezzi', U.Round(indice, 2))
    scriviStato('massa_monetaria', math.floor(massa))

    return indice, massa
end

-- ---------------------------------------------------------------------------
--  Ciclo di listino
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(60000)

    while true do
        local indice, massa = aggiornaIndice()
        local beni = MySQL.query.await('SELECT * FROM mercato') or {}

        local aggiornati, rialzi, ribassi = 0, 0, 0

        for _, b in ipairs(beni) do
            local nuovo = ECO.NuovoPrezzo(
                b.prezzo_base, b.prezzo, b.domanda, b.offerta, indice,
                tonumber(b.min_mult), tonumber(b.max_mult))

            -- Domanda e offerta rientrano verso l'equilibrio
            local domanda = b.domanda + (ECO.Squilibri.equilibrio - b.domanda) * ECO.Ciclo.ritornoEquilibrio
            local offerta = b.offerta + (ECO.Squilibri.equilibrio - b.offerta) * ECO.Ciclo.ritornoEquilibrio

            if nuovo ~= b.prezzo then
                aggiornati = aggiornati + 1
                if nuovo > b.prezzo then rialzi = rialzi + 1 else ribassi = ribassi + 1 end
            end

            MySQL.update('UPDATE mercato SET prezzo = ?, domanda = ?, offerta = ? WHERE item = ?',
                { nuovo, math.floor(domanda), math.floor(offerta), b.item })
        end

        scriviStato('ultimo_ciclo', os.time())

        AUREA.Log('economia', 'debug', nil, ('Listino aggiornato: %d beni (%d in rialzo, %d in ribasso) · indice %.2f · massa %s'):format(
            aggiornati, rialzi, ribassi, indice, U.Euro(massa)))

        Wait(ECO.Ciclo.minuti * 60000)
    end
end)

-- ---------------------------------------------------------------------------
--  Effetti degli eventi ambientali
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:ambiente:evento', function(id, effetto)
    if not effetto then return end

    if effetto.tipo == 'prezzi' then
        moltiplicatoreEvento = effetto.moltiplicatore or 1.0
        MySQL.update('UPDATE mercato SET prezzo = FLOOR(prezzo * ?)', { moltiplicatoreEvento })

    elseif effetto.tipo == 'domanda' then
        -- La sagra fa impennare la domanda sui prodotti tipici
        MySQL.update([[
            UPDATE mercato SET domanda = LEAST(?, domanda * ?)
            WHERE item IN ('vino_rosso','vino_docg','olio_extravergine','olio_dop',
                           'parmigiano_dop','formaggio_fresco','pizza_margherita',
                           'mozzarella_bufala','espresso','caffe_tostato')
        ]], { ECO.Squilibri.massimo, effetto.moltiplicatore or 1.3 })
    end
end)

AddEventHandler('aurea:ambiente:eventoConcluso', function()
    if moltiplicatoreEvento ~= 1.0 then
        MySQL.update('UPDATE mercato SET prezzo = FLOOR(prezzo / ?)', { moltiplicatoreEvento })
        moltiplicatoreEvento = 1.0
    end
end)

-- ---------------------------------------------------------------------------
--  Consultazione del listino
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('eco:listino', function(src, rispondi)
    local beni = MySQL.query.await('SELECT * FROM mercato ORDER BY item ASC') or {}
    local indice = leggiStato('indice_prezzi', 100)
    local massa = leggiStato('massa_monetaria', 0)

    local out = {}
    for _, b in ipairs(beni) do
        local dati = AUREA.Item[b.item]
        if dati then
            local variazione = ((b.prezzo - b.prezzo_base) / b.prezzo_base) * 100
            out[#out + 1] = {
                item = b.item,
                etichetta = dati.etichetta,
                categoria = dati.categoria,
                prezzo = b.prezzo,
                prezzoBase = b.prezzo_base,
                variazione = U.Round(variazione, 1),
                domanda = b.domanda,
                offerta = b.offerta,
                tensione = b.domanda > b.offerta and 'domanda' or (b.offerta > b.domanda and 'offerta' or 'equilibrio'),
            }
        end
    end

    table.sort(out, function(a, b) return math.abs(a.variazione) > math.abs(b.variazione) end)

    rispondi({
        beni = out,
        indice = U.Round(indice, 2),
        massa = massa,
        prossimoCiclo = ECO.Ciclo.minuti,
    })
end)

--- Prezzo corrente di un bene, per gli altri moduli.
exports('PrezzoDi', function(item)
    local riga = MySQL.single.await('SELECT prezzo FROM mercato WHERE item = ?', { item })
    return riga and tonumber(riga.prezzo) or nil
end)

exports('IndicePrezzi', function() return leggiStato('indice_prezzi', 100) end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('listino', 'utente', 'Consulta il listino della Borsa Merci', {}, function(src)
    TriggerClientEvent('eco:apriListino', src)
end)

AUREA.Comando('economia', 'admin', 'Stato macroeconomico del server', {}, function(src)
    local indice = leggiStato('indice_prezzi', 100)
    local massa = leggiStato('massa_monetaria', 0)
    local gettito = leggiStato('gettito_fiscale', 0)
    local erario = leggiStato('erario_saldo', 0)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '📊', durata = 16000,
        titolo = 'Conti del Paese',
        testo = ('Indice dei prezzi: %.2f\nMassa monetaria: %s\nGettito complessivo: %s\nSaldo erariale: %s'):format(
            indice, U.Euro(massa), U.Euro(gettito), U.Euro(erario)),
    })
end)
