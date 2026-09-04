--[[
    AUREA · API denaro
    Punto unico per gli spostamenti di denaro fra giocatori e verso l'esterno.
    Tutti gli importi sono in centesimi.
]]

local U = AUREA.Util

--- Aggiunge denaro a un giocatore online.
local function Aggiungi(src, conto, importo, causale)
    local g = AUREA.GetPlayer(src)
    if not g then return false end
    return g:Aggiungi(conto, importo, causale)
end

--- Sottrae denaro a un giocatore online.
local function Sottrai(src, conto, importo, causale)
    local g = AUREA.GetPlayer(src)
    if not g then return false end
    return g:Sottrai(conto, importo, causale)
end

--- Sottrae prima dai contanti, poi dalla banca.
local function Paga(src, importo, causale)
    local g = AUREA.GetPlayer(src)
    if not g then return false end
    return g:SottraiOvunque(importo, causale)
end

--- Accredita a un personaggio anche se offline (usa la tabella personaggi).
local function AggiungiOffline(citizenid, conto, importo, causale)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false end
    if conto ~= 'contanti' and conto ~= 'banca' then return false end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then return g:Aggiungi(conto, importo, causale) end

    local aggiornate = MySQL.update.await(
        ('UPDATE personaggi SET %s = %s + ? WHERE citizenid = ?'):format(conto, conto),
        { importo, citizenid })
    if aggiornate and aggiornate > 0 then
        AUREA.Log('denaro', 'info', nil, ('[offline] +%s su %s a %s — %s'):format(U.Euro(importo), conto, citizenid, causale or 'n.d.'))
        return true
    end
    return false
end

--- Addebita a un personaggio anche offline. Non porta mai il saldo sotto zero
--- sui contanti; sulla banca è consentito lo scoperto fino al fido registrato.
local function SottraiOffline(citizenid, conto, importo, causale, ammettiScoperto)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false end
    if conto ~= 'contanti' and conto ~= 'banca' then return false end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        if ammettiScoperto and conto == 'banca' then
            g.denaro.banca = g.denaro.banca - importo
            g:SincronizzaDenaro()
            return true
        end
        return g:Sottrai(conto, importo, causale)
    end

    local condizione = ammettiScoperto and '' or (' AND %s >= ?'):format(conto)
    local parametri = ammettiScoperto and { importo, citizenid } or { importo, citizenid, importo }
    local aggiornate = MySQL.update.await(
        ('UPDATE personaggi SET %s = %s - ? WHERE citizenid = ?%s'):format(conto, conto, condizione),
        parametri)

    if aggiornate and aggiornate > 0 then
        AUREA.Log('denaro', 'info', nil, ('[offline] -%s da %s a %s — %s'):format(U.Euro(importo), conto, citizenid, causale or 'n.d.'))
        return true
    end
    return false
end

--- Trasferimento atomico fra due personaggi.
local function Trasferisci(daCitizenid, aCitizenid, conto, importo, causale)
    if daCitizenid == aCitizenid then return false end
    if not SottraiOffline(daCitizenid, conto, importo, causale) then return false end
    if not AggiungiOffline(aCitizenid, conto, importo, causale) then
        -- rollback
        AggiungiOffline(daCitizenid, conto, importo, 'storno ' .. (causale or ''))
        return false
    end
    return true
end

--- Saldo complessivo (anche offline).
local function Saldo(citizenid)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then return g.denaro.contanti, g.denaro.banca end
    local r = MySQL.single.await('SELECT contanti, banca FROM personaggi WHERE citizenid = ?', { citizenid })
    if not r then return 0, 0 end
    return tonumber(r.contanti) or 0, tonumber(r.banca) or 0
end

AUREA.Denaro = {
    Aggiungi = Aggiungi,
    Sottrai = Sottrai,
    Paga = Paga,
    AggiungiOffline = AggiungiOffline,
    SottraiOffline = SottraiOffline,
    Trasferisci = Trasferisci,
    Saldo = Saldo,
}

exports('Aggiungi', Aggiungi)
exports('Sottrai', Sottrai)
exports('Paga', Paga)
exports('AggiungiOffline', AggiungiOffline)
exports('SottraiOffline', SottraiOffline)
exports('Trasferisci', Trasferisci)
exports('Saldo', Saldo)

-- ---------------------------------------------------------------------------
--  Consegna contanti a mano (richiede prossimità)
-- ---------------------------------------------------------------------------
RegisterNetEvent('aurea:denaro:consegna', function(bersaglioSrc, importo)
    local src = source
    local mittente = AUREA.GetPlayer(src)
    local destinatario = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not mittente or not destinatario or mittente.source == destinatario.source then return end

    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 or importo > 100000000 then return end

    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(destinatario.source))
    if #(a - b) > 3.0 then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Troppo lontano', testo = 'Avvicinati alla persona.' })
    end

    if not mittente:Sottrai('contanti', importo, 'consegna a mano') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Fondi insufficienti', testo = 'Non hai abbastanza contanti.' })
    end
    destinatario:Aggiungi('contanti', importo, ('consegna da %s'):format(mittente:NomeCompleto()))

    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Consegna effettuata', testo = ('Hai dato %s a %s.'):format(U.Euro(importo), destinatario:NomeCompleto()) })
    TriggerClientEvent('aurea:ui:notifica', destinatario.source, { tipo = 'successo', titolo = 'Contanti ricevuti', testo = ('%s da %s.'):format(U.Euro(importo), mittente:NomeCompleto()) })
end)
