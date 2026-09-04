--[[
    AUREA · Anagrafe
    Generazione di identificatori univoci: codice cittadino, codice fiscale,
    numero di telefono, numero di patente.
]]

AUREA = AUREA or {}
AUREA.Anagrafe = {}

local A = AUREA.Anagrafe
local U = AUREA.Util
local C = AUREA.Config

--- Codice cittadino: sigla provincia + 6 alfanumerici. Es. RM4F82K1
function A.NuovoCitizenId(provincia)
    for _ = 1, 25 do
        local sigla = provincia or C.Province[math.random(#C.Province)].sigla
        local codice = sigla .. U.Random(6)
        local esiste = MySQL.scalar.await('SELECT citizenid FROM personaggi WHERE citizenid = ?', { codice })
        if not esiste then return codice end
    end
    error('[AUREA] impossibile generare un codice cittadino univoco')
end

--- Numero di telefono italiano non ancora assegnato
function A.NuovoTelefono()
    for _ = 1, 40 do
        local prefisso = C.PrefissiTelefono[math.random(#C.PrefissiTelefono)]
        local numero = prefisso .. U.Random(7, '0123456789')
        local esiste = MySQL.scalar.await('SELECT telefono FROM personaggi WHERE telefono = ?', { numero })
        if not esiste then return numero end
    end
    error('[AUREA] impossibile generare un numero di telefono univoco')
end

--- Codice fiscale, con omocodia risolta come nella realtà (sostituzione cifre)
local OMOCODIA = { ['0']='L', ['1']='M', ['2']='N', ['3']='P', ['4']='Q', ['5']='R', ['6']='S', ['7']='T', ['8']='U', ['9']='V' }

function A.NuovoCodiceFiscale(cognome, nome, dataNascita, sesso, comune)
    local prov
    for _, p in ipairs(C.Province) do
        if p.comune == comune then prov = p break end
    end
    prov = prov or C.Province[1]

    local base = U.CodiceFiscale(cognome, nome, dataNascita, sesso, prov.catastale)
    if not base then return nil end

    local esiste = MySQL.scalar.await('SELECT codice_fiscale FROM personaggi WHERE codice_fiscale = ?', { base })
    if not esiste then return base end

    -- Omocodia: si sostituiscono da destra le cifre del codice con lettere
    local posizioni = { 15, 14, 13, 12, 11, 10, 8, 7 }  -- cifre nel CF, dalla più a destra
    local corrente = base
    for _, pos in ipairs(posizioni) do
        local ch = corrente:sub(pos, pos)
        local sost = OMOCODIA[ch]
        if sost then
            corrente = corrente:sub(1, pos - 1) .. sost .. corrente:sub(pos + 1)
            -- ricalcolo del carattere di controllo sui primi 15
            local ricalcolato = U.CodiceFiscale(cognome, nome, dataNascita, sesso, prov.catastale)
            corrente = corrente:sub(1, 15) .. (ricalcolato and ricalcolato:sub(16, 16) or 'X')
            local dup = MySQL.scalar.await('SELECT codice_fiscale FROM personaggi WHERE codice_fiscale = ?', { corrente })
            if not dup then return corrente end
        end
    end
    -- fallback: suffisso casuale
    return base:sub(1, 14) .. U.Random(2)
end

--- Numero di patente: sigla provincia + 8 cifre + lettera
function A.NuovoNumeroPatente(citizenid)
    local sigla = (citizenid or 'RM'):sub(1, 2)
    for _ = 1, 25 do
        local numero = ('%s%s%s'):format(sigla, U.Random(7, '0123456789'), U.Random(1))
        local esiste = MySQL.scalar.await('SELECT numero FROM patenti WHERE numero = ?', { numero })
        if not esiste then return numero end
    end
    return sigla .. U.Random(8)
end

--- Targa italiana non ancora immatricolata
function A.NuovaTarga()
    for _ = 1, 40 do
        local targa = U.GeneraTarga()
        local esiste = MySQL.scalar.await('SELECT targa FROM veicoli WHERE targa = ?', { targa })
        if not esiste then return targa end
    end
    error('[AUREA] impossibile generare una targa univoca')
end

--- IBAN non ancora assegnato
function A.NuovoIBAN(seed)
    for _ = 1, 25 do
        local iban = U.GeneraIBAN(seed)
        local esiste = MySQL.scalar.await('SELECT iban FROM conti WHERE iban = ?', { iban })
        if not esiste then return iban end
    end
    error('[AUREA] impossibile generare un IBAN univoco')
end

--- Partita IVA non ancora assegnata
function A.NuovaPartitaIVA()
    for _ = 1, 25 do
        local piva = U.GeneraPartitaIVA()
        local esiste = MySQL.scalar.await('SELECT piva FROM imprese WHERE piva = ?', { piva })
        if not esiste then return piva end
    end
    error('[AUREA] impossibile generare una partita IVA univoca')
end

exports('NuovaTarga', A.NuovaTarga)
exports('NuovoIBAN', A.NuovoIBAN)
exports('NuovaPartitaIVA', A.NuovaPartitaIVA)
