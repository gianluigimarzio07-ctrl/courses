--[[
    AUREA · Utility condivise (client + server)
]]

AUREA = AUREA or {}
AUREA.Util = {}

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Denaro: internamente in centesimi, in output formattato all'italiana
-- ---------------------------------------------------------------------------

--- Formatta un importo in centesimi come "1.234,56 €"
---@param centesimi integer
---@param conSimbolo boolean|nil
---@return string
function U.Euro(centesimi, conSimbolo)
    centesimi = math.floor(tonumber(centesimi) or 0)
    local negativo = centesimi < 0
    centesimi = math.abs(centesimi)

    local interi = math.floor(centesimi / 100)
    local decimali = centesimi % 100

    -- separatore delle migliaia con il punto
    local s = tostring(interi)
    local out, count = '', 0
    for i = #s, 1, -1 do
        out = s:sub(i, i) .. out
        count = count + 1
        if count % 3 == 0 and i > 1 then out = '.' .. out end
    end

    local testo = ('%s,%02d'):format(out, decimali)
    if negativo then testo = '-' .. testo end
    if conSimbolo ~= false then testo = testo .. ' €' end
    return testo
end

--- Converte euro (float, da config leggibili) in centesimi interi
function U.ACentesimi(euro)
    return math.floor((tonumber(euro) or 0) * 100 + 0.5)
end

-- ---------------------------------------------------------------------------
--  Stringhe e identificatori
-- ---------------------------------------------------------------------------

local ALFABETO = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local CIFRE = '0123456789'

--- Stringa casuale su un alfabeto dato
function U.Random(lunghezza, alfabeto)
    alfabeto = alfabeto or (ALFABETO .. CIFRE)
    local t = {}
    for i = 1, lunghezza do
        local n = math.random(#alfabeto)
        t[i] = alfabeto:sub(n, n)
    end
    return table.concat(t)
end

--- Targa italiana moderna: AA000AA (senza I, O, Q, U per le lettere)
function U.GeneraTarga()
    local lettere = 'ABCDEFGHJKLMNPRSTVWXYZ'
    return U.Random(2, lettere) .. U.Random(3, CIFRE) .. U.Random(2, lettere)
end

--- IBAN italiano plausibile: IT + 2 check + CIN + ABI(5) + CAB(5) + conto(12)
function U.GeneraIBAN(seed)
    local cin = U.Random(1, ALFABETO)
    local abi = U.Random(5, CIFRE)
    local cab = U.Random(5, CIFRE)
    local conto = (seed and tostring(seed):gsub('%D', '') or '') .. U.Random(12, CIFRE)
    conto = conto:sub(1, 12)
    return ('IT%s%s%s%s%s'):format(U.Random(2, CIFRE), cin, abi, cab, conto)
end

--- Partita IVA a 11 cifre con check digit secondo l'algoritmo di Luhn dispari/pari
function U.GeneraPartitaIVA()
    local base = U.Random(10, CIFRE)
    local somma = 0
    for i = 1, 10 do
        local d = tonumber(base:sub(i, i))
        if i % 2 == 0 then
            d = d * 2
            if d > 9 then d = d - 9 end
        end
        somma = somma + d
    end
    local check = (10 - (somma % 10)) % 10
    return base .. tostring(check)
end

-- ---------------------------------------------------------------------------
--  Codice fiscale
-- ---------------------------------------------------------------------------

local MESI_CF = { 'A', 'B', 'C', 'D', 'E', 'H', 'L', 'M', 'P', 'R', 'S', 'T' }

local function consonanti(s)
    return (s:upper():gsub('[^BCDFGHJKLMNPQRSTVWXYZ]', ''))
end

local function vocali(s)
    return (s:upper():gsub('[^AEIOU]', ''))
end

local function terna(s, isCognome)
    s = s:upper():gsub('[^A-Z]', '')
    local c, v = consonanti(s), vocali(s)
    -- Per il nome con 4+ consonanti si prendono 1a, 3a, 4a
    if not isCognome and #c >= 4 then
        return c:sub(1, 1) .. c:sub(3, 3) .. c:sub(4, 4)
    end
    local out = (c .. v .. 'XXX'):sub(1, 3)
    return out
end

--- Calcola un codice fiscale italiano (con carattere di controllo corretto).
---@param cognome string
---@param nome string
---@param dataNascita string  formato YYYY-MM-DD
---@param sesso string        'M' | 'F'
---@param codiceCatastale string es. 'H501'
function U.CodiceFiscale(cognome, nome, dataNascita, sesso, codiceCatastale)
    local anno, mese, giorno = dataNascita:match('(%d+)-(%d+)-(%d+)')
    anno, mese, giorno = tonumber(anno), tonumber(mese), tonumber(giorno)
    if not anno then return nil end

    if sesso == 'F' then giorno = giorno + 40 end

    local parziale = ('%s%s%02d%s%02d%s'):format(
        terna(cognome, true),
        terna(nome, false),
        anno % 100,
        MESI_CF[mese] or 'A',
        giorno,
        (codiceCatastale or 'H501'):upper()
    )

    -- Carattere di controllo
    local dispari = {
        ['0']=1,['1']=0,['2']=5,['3']=7,['4']=9,['5']=13,['6']=15,['7']=17,['8']=19,['9']=21,
        ['A']=1,['B']=0,['C']=5,['D']=7,['E']=9,['F']=13,['G']=15,['H']=17,['I']=19,['J']=21,
        ['K']=2,['L']=4,['M']=18,['N']=20,['O']=11,['P']=3,['Q']=6,['R']=8,['S']=12,['T']=14,
        ['U']=16,['V']=10,['W']=22,['X']=25,['Y']=24,['Z']=23,
    }
    local pari = {
        ['0']=0,['1']=1,['2']=2,['3']=3,['4']=4,['5']=5,['6']=6,['7']=7,['8']=8,['9']=9,
        ['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,['J']=9,
        ['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,['R']=17,['S']=18,
        ['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,['Z']=25,
    }
    local resto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

    local somma = 0
    for i = 1, 15 do
        local ch = parziale:sub(i, i)
        somma = somma + ((i % 2 == 1) and (dispari[ch] or 0) or (pari[ch] or 0))
    end
    local idx = (somma % 26) + 1
    return parziale .. resto:sub(idx, idx)
end

-- ---------------------------------------------------------------------------
--  Tabelle
-- ---------------------------------------------------------------------------

function U.CopiaProfonda(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = U.CopiaProfonda(v) end
    return out
end

function U.Conta(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function U.Contiene(lista, valore)
    for _, v in ipairs(lista or {}) do
        if v == valore then return true end
    end
    return false
end

--- Divide una stringa su un separatore
function U.Split(s, sep)
    local out = {}
    for parte in tostring(s):gmatch('([^' .. (sep or ',') .. ']+)') do
        out[#out + 1] = parte:match('^%s*(.-)%s*$')
    end
    return out
end

--- Arrotonda a n decimali
function U.Round(v, n)
    local m = 10 ^ (n or 0)
    return math.floor((tonumber(v) or 0) * m + 0.5) / m
end

--- Interpolazione lineare limitata all'intervallo
function U.Clamp(v, minimo, massimo)
    if v < minimo then return minimo end
    if v > massimo then return massimo end
    return v
end

-- ---------------------------------------------------------------------------
--  Date all'italiana
-- ---------------------------------------------------------------------------

function U.DataIT(timestamp)
    return os.date('%d/%m/%Y', timestamp or os.time())
end

function U.DataOraIT(timestamp)
    return os.date('%d/%m/%Y %H:%M', timestamp or os.time())
end

--- Aggiunge giorni a una data e la restituisce in formato SQL
function U.DataPiuGiorni(giorni, da)
    return os.date('%Y-%m-%d', (da or os.time()) + (giorni * 86400))
end

function U.DataOraPiuOre(ore, da)
    return os.date('%Y-%m-%d %H:%M:%S', (da or os.time()) + (ore * 3600))
end

return U
