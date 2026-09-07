--[[
    ESX su AUREA — parte condivisa

    Qui nasce la tabella ESX e ci finiscono i pezzi che esistono identici
    da entrambe le parti: ESX.Math, ESX.Table, ESX.Items, i timeout.

    Il resto lo aggiungono server/oggetto.lua e client/oggetto.lua.
]]

ESX = ESX or {}

ESX.PlayerData = {}
ESX.PlayerLoaded = false

-- ---------------------------------------------------------------------------
--  ESX.Math
-- ---------------------------------------------------------------------------
ESX.Math = {}

function ESX.Math.Round(valore, decimali)
    if decimali and decimali > 0 then
        local m = 10 ^ decimali
        return math.floor((tonumber(valore) or 0) * m + 0.5) / m
    end
    return math.floor((tonumber(valore) or 0) + 0.5)
end

function ESX.Math.Trim(testo)
    if not testo then return nil end
    return (tostring(testo):gsub('^%s*(.-)%s*$', '%1'))
end

--- 1234567 -> "1.234.567". ESX usa la virgola all'inglese; qui il punto,
--- perché il server è italiano e i numeri si leggono come si scrivono in
--- Italia. Se uno script ESX si aspetta la virgola, la differenza è
--- estetica.
function ESX.Math.GroupDigits(valore)
    local segno, intero, decimali = tostring(tonumber(valore) or 0):match('^([%-]?)(%d+)%.?(%d*)$')
    if not intero then return tostring(valore) end

    local raggruppato = intero:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    if decimali ~= '' then
        return ('%s%s,%s'):format(segno, raggruppato, decimali)
    end
    return segno .. raggruppato
end

--- ESX 1.10 espone anche questi due.
function ESX.Math.Clamp(valore, minimo, massimo)
    return math.max(minimo, math.min(massimo, tonumber(valore) or 0))
end

function ESX.Math.Random(minimo, massimo)
    return math.random(minimo, massimo)
end

-- ---------------------------------------------------------------------------
--  ESX.Table
-- ---------------------------------------------------------------------------
ESX.Table = {}

function ESX.Table.SizeOf(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function ESX.Table.IndexOf(t, valore)
    for i, v in ipairs(t or {}) do
        if v == valore then return i end
    end
    return -1
end

function ESX.Table.LastIndexOf(t, valore)
    local trovato = -1
    for i, v in ipairs(t or {}) do
        if v == valore then trovato = i end
    end
    return trovato
end

function ESX.Table.Find(t, predicato)
    for i, v in ipairs(t or {}) do
        if predicato(v, i) then return v end
    end
    return nil
end

function ESX.Table.FindIndex(t, predicato)
    for i, v in ipairs(t or {}) do
        if predicato(v, i) then return i end
    end
    return -1
end

function ESX.Table.Filter(t, predicato)
    local out = {}
    for i, v in ipairs(t or {}) do
        if predicato(v, i) then out[#out + 1] = v end
    end
    return out
end

function ESX.Table.Map(t, trasforma)
    local out = {}
    for i, v in ipairs(t or {}) do out[i] = trasforma(v, i) end
    return out
end

function ESX.Table.Reverse(t)
    local out = {}
    for i = #t, 1, -1 do out[#out + 1] = t[i] end
    return out
end

function ESX.Table.Clone(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = ESX.Table.Clone(v) end
    return setmetatable(out, getmetatable(t))
end

function ESX.Table.Concat(a, b)
    local out = ESX.Table.Clone(a)
    for _, v in ipairs(b or {}) do out[#out + 1] = v end
    return out
end

function ESX.Table.Join(t, separatore)
    local pezzi = {}
    for _, v in ipairs(t or {}) do pezzi[#pezzi + 1] = tostring(v) end
    return table.concat(pezzi, separatore or ', ')
end

function ESX.Table.Set(t)
    local out = {}
    for _, v in ipairs(t or {}) do out[v] = true end
    return out
end

-- ---------------------------------------------------------------------------
--  Timeout
--
--  ESX.SetTimeout restituisce un id cancellabile. In AUREA non serviva,
--  ma parecchi script ESX ci contano.
-- ---------------------------------------------------------------------------
local timeout = {}
local prossimoTimeout = 1

function ESX.SetTimeout(millisecondi, fn)
    local id = prossimoTimeout
    prossimoTimeout = prossimoTimeout + 1
    timeout[id] = true

    CreateThread(function()
        Wait(millisecondi)
        if timeout[id] then
            timeout[id] = nil
            fn()
        end
    end)

    return id
end

function ESX.ClearTimeout(id)
    timeout[id] = nil
end

-- ---------------------------------------------------------------------------
--  Catalogo oggetti
--
--  ESX.Items[nome] = { label, weight, rare, canRemove }
--  Si ricava dal catalogo AUREA, che è la fonte unica.
-- ---------------------------------------------------------------------------
ESX.Items = {}

CreateThread(function()
    for nome, dati in pairs(AUREA.Item or {}) do
        ESX.Items[nome] = {
            name = nome,
            label = dati.etichetta,
            weight = math.floor((dati.peso or 100) * ESXC.Inventario.fattorePeso),
            rare = dati.unico and 1 or 0,
            canRemove = 1,
            -- Campi non standard, ma utili a chi scrive script nuovi:
            -- il catalogo AUREA ha più informazioni di quelle di ESX.
            categoria = dati.categoria,
            descrizione = dati.descrizione,
            usabile = dati.usabile or false,
            deperibile = dati.degrada ~= nil,
        }
    end
end)

function ESX.GetItemLabel(nome)
    local i = ESX.Items[nome]
    return i and i.label or nome
end

-- ---------------------------------------------------------------------------
--  Diagnostica
-- ---------------------------------------------------------------------------

--- Chiamata quando uno script tocca un pezzo di API che qui non esiste.
--- Non lancia: stampa e restituisce nil, così lo script prosegue zoppo
--- invece di morire, e tu sai esattamente cosa gli manca.
function ESX.NonImplementato(cosa, suggerimento)
    if not ESXC.Compat.avvisaNonImplementato then return nil end
    print(('[es_extended] %s non è implementato in questo ponte.%s')
        :format(cosa, suggerimento and (' ' .. suggerimento) or ''))
    return nil
end

function ESX.DumpTable(t, indentazione)
    indentazione = indentazione or 0
    local spazio = string.rep('  ', indentazione)
    local pezzi = { '{' }

    for k, v in pairs(t or {}) do
        local chiave = type(k) == 'number' and ('[%d]'):format(k) or tostring(k)
        if type(v) == 'table' then
            pezzi[#pezzi + 1] = ('%s  %s = %s'):format(spazio, chiave, ESX.DumpTable(v, indentazione + 1))
        else
            pezzi[#pezzi + 1] = ('%s  %s = %s'):format(spazio, chiave,
                type(v) == 'string' and ('"%s"'):format(v) or tostring(v))
        end
    end

    pezzi[#pezzi + 1] = spazio .. '}'
    return table.concat(pezzi, '\n')
end
