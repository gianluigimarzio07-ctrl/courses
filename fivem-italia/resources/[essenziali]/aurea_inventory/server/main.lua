--[[
    AUREA · Inventario (server)
    API pubblica, apertura contenitori, oggetti a terra.
]]

local U = AUREA.Util
local C = AUREA.Config

local aperti = {}          -- [src] = { primario = id, secondario = id|nil }
local mucchi = {}          -- [id] = { coord, scadenza, oggetto }
local contatoreMucchi = 0

-- ---------------------------------------------------------------------------
--  Accesso rapido
-- ---------------------------------------------------------------------------

local function inventarioDi(citizenid)
    return Contenitore.Carica('pg:' .. citizenid, {
        tipo = 'personaggio',
        capienza = C.Inventario.slotPersonaggio,
        pesoMax = C.Inventario.pesoPersonaggio,
    })
end

--- Verifica che il giocatore possa davvero interagire con un contenitore.
local function autorizzato(src, idContenitore)
    local g = AUREA.GetPlayer(src)
    if not g then return false end

    if idContenitore == 'pg:' .. g.citizenid then return true end

    local sessione = aperti[src]
    if not sessione then return false end
    return sessione.primario == idContenitore or sessione.secondario == idContenitore
end

-- ---------------------------------------------------------------------------
--  API per gli altri moduli
-- ---------------------------------------------------------------------------

local function Aggiungi(citizenid, nome, quantita, metadata)
    local inv = inventarioDi(citizenid)
    local ok, motivo = inv:Aggiungi(nome, quantita or 1, metadata)

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        if ok then
            local dati = AUREA.Item[nome]
            TriggerClientEvent('inv:aggiorna', g.source, inv:Pacchetto())
            TriggerClientEvent('inv:variazione', g.source, {
                nome = nome, etichetta = dati and dati.etichetta or nome,
                quantita = quantita or 1, verso = 'entrata',
            })
        else
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', titolo = 'Inventario pieno', testo = motivo,
            })
        end
    end

    return ok, motivo
end

local function Rimuovi(citizenid, nome, quantita)
    local inv = inventarioDi(citizenid)
    local ok, motivo = inv:Rimuovi(nome, quantita or 1)

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g and ok then
        local dati = AUREA.Item[nome]
        TriggerClientEvent('inv:aggiorna', g.source, inv:Pacchetto())
        TriggerClientEvent('inv:variazione', g.source, {
            nome = nome, etichetta = dati and dati.etichetta or nome,
            quantita = quantita or 1, verso = 'uscita',
        })
    end

    return ok, motivo
end

local function Ha(citizenid, nome, quantita)
    return inventarioDi(citizenid):Ha(nome, quantita or 1)
end

local function Quantita(citizenid, nome)
    return inventarioDi(citizenid):Quantita(nome)
end

local function Trova(citizenid, nome, filtro)
    return inventarioDi(citizenid):Trova(nome, filtro)
end

exports('Aggiungi', Aggiungi)
exports('Rimuovi', Rimuovi)
exports('Ha', Ha)
exports('Quantita', Quantita)
exports('Trova', Trova)
exports('Inventario', inventarioDi)
exports('CaricaContenitore', Contenitore.Carica)

-- Eventi usati dagli altri moduli
AddEventHandler('aurea:inventario:aggiungi', function(citizenid, nome, quantita, metadata)
    Aggiungi(citizenid, nome, quantita, metadata)
end)

AddEventHandler('aurea:inventario:rimuovi', function(citizenid, nome, quantita)
    Rimuovi(citizenid, nome, quantita)
end)

AddEventHandler('aurea:inventario:corredoIniziale', function(citizenid, corredo)
    local inv = inventarioDi(citizenid)
    for _, riga in ipairs(corredo or {}) do
        inv:Aggiungi(riga.item, riga.quantita or 1)
    end
    inv:Salva()
end)

-- ---------------------------------------------------------------------------
--  Apertura dell'inventario
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('inv:apri', function(src, rispondi, richiesta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local primario = inventarioDi(g.citizenid)
    local secondario = nil

    if richiesta and richiesta.tipo then
        if richiesta.tipo == 'veicolo' then
            local targa = (richiesta.targa or ''):upper():gsub('%s+', '')
            if targa == '' then return rispondi(nil) end

            -- il bagagliaio si apre solo se il veicolo è vicino
            local posizione = GetEntityCoords(GetPlayerPed(src))
            if richiesta.coord then
                local d = #(posizione - vector3(richiesta.coord.x, richiesta.coord.y, richiesta.coord.z))
                if d > 5.0 then return rispondi(nil) end
            end

            local capienza = richiesta.capienza or C.Inventario.slotVeicoloDefault
            secondario = Contenitore.Carica('veh:' .. targa, {
                tipo = 'veicolo', capienza = capienza,
                pesoMax = richiesta.pesoMax or C.Inventario.pesoVeicoloDefault,
            })

        elseif richiesta.tipo == 'terra' then
            local mucchio = mucchi[richiesta.id]
            if not mucchio then return rispondi(nil) end
            local posizione = GetEntityCoords(GetPlayerPed(src))
            if #(posizione - mucchio.coord) > C.Inventario.distanzaMassima then return rispondi(nil) end
            secondario = Contenitore.Carica('terra:' .. richiesta.id, { tipo = 'terra', capienza = 20, pesoMax = 100000 })

        elseif richiesta.tipo == 'contenitore' then
            -- borsone o valigetta nell'inventario del giocatore
            local riga = primario:GetSlot(richiesta.slot)
            if not riga then return rispondi(nil) end
            local dati = AUREA.Item[riga.nome]
            if not dati or not dati.contenitore then return rispondi(nil) end

            riga.metadata = riga.metadata or {}
            if not riga.metadata.contenitoreId then
                riga.metadata.contenitoreId = ('cont:%s_%d'):format(riga.nome, math.random(100000, 999999))
                primario.sporco = true
            end
            secondario = Contenitore.Carica(riga.metadata.contenitoreId, {
                tipo = 'portatile',
                capienza = dati.contenitore.slot,
                pesoMax = dati.contenitore.peso,
            })

        elseif richiesta.tipo == 'esterno' then
            -- contenitori aperti da altre risorse (casseforti, magazzini, negozi)
            if not richiesta.id then return rispondi(nil) end
            secondario = Contenitore.Carica(richiesta.id, {
                tipo = richiesta.tipoContenitore or 'deposito',
                capienza = richiesta.capienza or 40,
                pesoMax = richiesta.pesoMax or 200000,
            })

        elseif richiesta.tipo == 'persona' then
            -- perquisizione: richiede il permesso e la prossimità
            local bersaglio = AUREA.GetPlayer(tonumber(richiesta.bersaglio))
            if not bersaglio then return rispondi(nil) end
            if not g:HaPermessoLavoro('perquisizione') or not g.lavoro.servizio then
                AUREA.Log('anticheat', 'allarme', src, 'tentata perquisizione senza permesso')
                return rispondi(nil)
            end
            local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(bersaglio.source)))
            if d > 3.0 then return rispondi(nil) end

            secondario = inventarioDi(bersaglio.citizenid)
            AUREA.Log('inventario', 'info', g, ('perquisizione di %s'):format(bersaglio:NomeCompleto()))
            TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
                tipo = 'avviso', icona = '🔍',
                titolo = 'Perquisizione in corso', testo = ('%s sta ispezionando le tue tasche.'):format(g:NomeCompleto()),
            })
        end
    end

    aperti[src] = {
        primario = primario.id,
        secondario = secondario and secondario.id or nil,
    }

    rispondi({
        primario = primario:Pacchetto(),
        secondario = secondario and secondario:Pacchetto() or nil,
        etichettaSecondaria = richiesta and richiesta.etichetta or nil,
    })
end)

RegisterNetEvent('inv:chiudi', function()
    local src = source
    local sessione = aperti[src]
    if sessione then
        local p = Contenitore.Cache()[sessione.primario]
        if p then p:Salva() end
        if sessione.secondario then
            local s = Contenitore.Cache()[sessione.secondario]
            if s then s:Salva() end
        end
    end
    aperti[src] = nil
end)

-- ---------------------------------------------------------------------------
--  Spostamento di oggetti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('inv:sposta', function(src, rispondi, azione)
    local g = AUREA.GetPlayer(src)
    if not g or type(azione) ~= 'table' then return rispondi(false) end

    if not autorizzato(src, azione.da) or not autorizzato(src, azione.a) then
        AUREA.Log('anticheat', 'allarme', src, ('spostamento su contenitore non autorizzato: %s -> %s'):format(tostring(azione.da), tostring(azione.a)))
        return rispondi(false, 'Operazione non consentita.')
    end

    local origine = Contenitore.Cache()[azione.da]
    local destinazione = Contenitore.Cache()[azione.a]
    if not origine or not destinazione then return rispondi(false, 'Contenitore non disponibile.') end

    local ok, motivo
    if origine.id == destinazione.id then
        ok = origine:Scambia(azione.slotDa, azione.slotA)
        motivo = ok and nil or 'Spostamento non riuscito.'
    else
        ok, motivo = origine:Sposta(destinazione, azione.slotDa, azione.quantita, azione.slotA)
    end

    if ok then
        AUREA.Log('inventario', 'debug', g, ('%s slot %s -> %s slot %s'):format(
            origine.id, tostring(azione.slotDa), destinazione.id, tostring(azione.slotA)))
    end

    rispondi(ok, motivo, {
        primario = Contenitore.Cache()[aperti[src].primario]:Pacchetto(),
        secondario = aperti[src].secondario and Contenitore.Cache()[aperti[src].secondario]:Pacchetto() or nil,
    })
end)

-- ---------------------------------------------------------------------------
--  Oggetti a terra
-- ---------------------------------------------------------------------------
--- Il mucchio a terra in quel punto: se non c'è, lo crea. Restituisce il
--- contenitore, perché è quello che serve a chi ci deve mettere roba.
local function mucchioIn(posizione)
    -- si cerca un mucchio già presente a meno di 1,5 m
    local idMucchio
    for id, m in pairs(mucchi) do
        if #(posizione - m.coord) < 1.5 then idMucchio = id break end
    end

    if not idMucchio then
        contatoreMucchi = contatoreMucchi + 1
        idMucchio = ('m%d_%d'):format(os.time() % 100000, contatoreMucchi)
        mucchi[idMucchio] = {
            coord = posizione,
            scadenza = os.time() + C.Inventario.duratsTerra * 60,
        }
        TriggerClientEvent('inv:mucchioCreato', -1, idMucchio, {
            x = posizione.x, y = posizione.y, z = posizione.z,
        })
    else
        mucchi[idMucchio].scadenza = os.time() + C.Inventario.duratsTerra * 60
    end

    return Contenitore.Carica('terra:' .. idMucchio,
        { tipo = 'terra', capienza = 20, pesoMax = 100000 }), idMucchio
end

--- Lascia oggetti a terra senza che nessuno li abbia in tasca prima.
--- Serve a chi genera bottino sul posto (e al ponte ESX, per i pickup).
exports('Deposita', function(coord, nome, quantita, metadata)
    if not AUREA.Item[nome] then return false end
    local posizione = vector3(coord.x, coord.y, coord.z)
    local terra = mucchioIn(posizione)
    return (terra:Aggiungi(nome, math.max(1, math.floor(tonumber(quantita) or 1)), metadata))
end)

AUREA.Callback.Registra('inv:getta', function(src, rispondi, slot, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local inv = inventarioDi(g.citizenid)
    local riga = inv:GetSlot(slot)
    if not riga then return rispondi(false, 'Slot vuoto.') end

    quantita = math.min(math.max(1, math.floor(tonumber(quantita) or riga.quantita)), riga.quantita)

    local posizione = GetEntityCoords(GetPlayerPed(src))
    local terra = mucchioIn(posizione)

    local ok, motivo = terra:Aggiungi(riga.nome, quantita, riga.metadata)
    if not ok then return rispondi(false, motivo) end

    inv:Rimuovi(riga.nome, quantita, slot)
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    AUREA.Log('inventario', 'info', g, ('ha gettato %dx %s'):format(quantita, riga.nome))
    rispondi(true)
end)

--- Elenco dei mucchi per chi entra in gioco.
AUREA.Callback.Registra('inv:mucchi', function(src, rispondi)
    local out = {}
    for id, m in pairs(mucchi) do
        out[#out + 1] = { id = id, coord = { x = m.coord.x, y = m.coord.y, z = m.coord.z } }
    end
    rispondi(out)
end)

-- Pulizia dei mucchi scaduti o vuoti
CreateThread(function()
    while true do
        Wait(60000)
        local adesso = os.time()
        for id, m in pairs(mucchi) do
            local terra = Contenitore.Cache()['terra:' .. id]
            local vuoto = terra and #terra.item == 0
            if adesso > m.scadenza or vuoto then
                mucchi[id] = nil
                if terra then
                    MySQL.query('DELETE FROM inventari WHERE contenitore = ?', { 'terra:' .. id })
                    Contenitore.Cache()['terra:' .. id] = nil
                end
                TriggerClientEvent('inv:mucchioRimosso', -1, id)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Ciclo di vita del giocatore
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    local inv = inventarioDi(g.citizenid)
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
end)

AddEventHandler('aurea:giocatore:scaricato', function(src, g)
    local inv = Contenitore.Cache()['pg:' .. g.citizenid]
    if inv then inv:Scarica() end
    aperti[src] = nil
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('dammiitem', 'gestore', 'Aggiunge un oggetto a un giocatore', {
    { name = 'id', help = 'ID sessione' },
    { name = 'oggetto', help = 'Nome interno' },
    { name = 'quantita', help = 'Quantità' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local nome = args[2]
    if not bersaglio or not nome or not AUREA.Item[nome] then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Uso', testo = '/dammiitem <id> <oggetto> <quantita>',
        })
    end

    local ok, motivo = Aggiungi(bersaglio.citizenid, nome, tonumber(args[3]) or 1)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = ok and 'successo' or 'errore',
        titolo = ok and 'Oggetto consegnato' or 'Consegna fallita',
        testo = ok and ('%s a %s'):format(nome, bersaglio:NomeCompleto()) or motivo,
    })
    AUREA.Log('staff', 'avviso', src, ('ha dato %dx %s a %s'):format(tonumber(args[3]) or 1, nome, bersaglio.citizenid))
end)

AUREA.Comando('oggetti', 'admin', 'Elenca gli oggetti disponibili', {}, function(src)
    local nomi = {}
    for nome in pairs(AUREA.Item) do nomi[#nomi + 1] = nome end
    table.sort(nomi)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', titolo = ('%d oggetti'):format(#nomi),
        testo = table.concat(nomi, ', '), durata = 30000,
    })
end)
