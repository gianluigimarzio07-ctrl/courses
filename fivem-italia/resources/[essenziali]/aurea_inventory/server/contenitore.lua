--[[
    AUREA · Contenitori di inventario

    Un contenitore è qualunque cosa possa contenere oggetti: le tasche di un
    personaggio, il bagagliaio di un veicolo, una cassaforte, un borsone, un
    mucchio a terra. Hanno tutti la stessa struttura, quindi lo spostamento
    fra due qualsiasi di essi usa un solo percorso di codice.

    Formato di un item in memoria:
        { slot = 3, nome = 'acqua', quantita = 2, metadata = { ... } }
]]

Contenitore = {}
Contenitore.__index = Contenitore

local cache = {}      -- [id] = Contenitore
local C = AUREA.Config

-- ---------------------------------------------------------------------------
--  Costruzione e caricamento
-- ---------------------------------------------------------------------------

--- Carica (o crea) un contenitore dal database.
---@param id string  es. 'pg:RM4F82K1', 'veh:AB123CD', 'cass:banca_1'
---@param opzioni table|nil { tipo, capienza, pesoMax }
function Contenitore.Carica(id, opzioni)
    if cache[id] then return cache[id] end
    opzioni = opzioni or {}

    local riga = MySQL.single.await('SELECT * FROM inventari WHERE contenitore = ?', { id })

    local c = setmetatable({}, Contenitore)
    c.id = id
    c.tipo = opzioni.tipo or (riga and riga.tipo) or 'generico'
    c.capienza = opzioni.capienza or (riga and riga.capienza) or C.Inventario.slotPersonaggio
    c.pesoMax = opzioni.pesoMax or (riga and riga.peso_max) or C.Inventario.pesoPersonaggio
    c.item = (riga and riga.dati) and json.decode(riga.dati) or {}
    c.sporco = false

    if not riga then
        MySQL.insert('INSERT INTO inventari (contenitore, tipo, capienza, peso_max, dati) VALUES (?, ?, ?, ?, ?)',
            { id, c.tipo, c.capienza, c.pesoMax, json.encode({}) })
    end

    cache[id] = c
    return c
end

function Contenitore.Cache()
    return cache
end

--- Scarica dalla memoria dopo il salvataggio (per contenitori temporanei).
function Contenitore:Scarica()
    self:Salva()
    cache[self.id] = nil
end

function Contenitore:Salva()
    if not self.sporco then return end
    self.sporco = false
    MySQL.update('UPDATE inventari SET dati = ?, capienza = ?, peso_max = ? WHERE contenitore = ?',
        { json.encode(self.item), self.capienza, self.pesoMax, self.id })
end

-- ---------------------------------------------------------------------------
--  Interrogazione
-- ---------------------------------------------------------------------------

function Contenitore:Peso()
    local totale = 0
    for _, riga in ipairs(self.item) do
        local dati = AUREA.Item[riga.nome]
        if dati then totale = totale + (dati.peso * riga.quantita) end
    end
    return totale
end

function Contenitore:SlotOccupati()
    return #self.item
end

--- Quante unità di un oggetto sono presenti.
function Contenitore:Quantita(nome)
    local totale = 0
    for _, riga in ipairs(self.item) do
        if riga.nome == nome then totale = totale + riga.quantita end
    end
    return totale
end

function Contenitore:Ha(nome, quantita)
    return self:Quantita(nome) >= (quantita or 1)
end

--- Primo item che soddisfa un predicato sui metadata.
function Contenitore:Trova(nome, filtro)
    for _, riga in ipairs(self.item) do
        if riga.nome == nome and (not filtro or filtro(riga.metadata or {})) then
            return riga
        end
    end
    return nil
end

function Contenitore:GetSlot(slot)
    for _, riga in ipairs(self.item) do
        if riga.slot == slot then return riga end
    end
    return nil
end

--- Primo slot libero, o nil se il contenitore è pieno.
function Contenitore:SlotLibero()
    local occupati = {}
    for _, riga in ipairs(self.item) do occupati[riga.slot] = true end
    for s = 1, self.capienza do
        if not occupati[s] then return s end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Mutazione
-- ---------------------------------------------------------------------------

--- Aggiunge un oggetto. Restituisce (ok, motivo).
---@param nome string
---@param quantita integer
---@param metadata table|nil  se presente l'item diventa un'istanza a sé
function Contenitore:Aggiungi(nome, quantita, metadata, slotDesiderato)
    local dati = AUREA.Item[nome]
    if not dati then return false, 'Oggetto sconosciuto.' end

    quantita = math.floor(tonumber(quantita) or 1)
    if quantita <= 0 then return false, 'Quantità non valida.' end

    if (self:Peso() + dati.peso * quantita) > self.pesoMax then
        return false, 'Peso massimo superato.'
    end

    local impilabile = dati.impilabile and not dati.unico and metadata == nil

    if impilabile then
        -- si prova prima ad accumulare su una pila esistente
        for _, riga in ipairs(self.item) do
            if riga.nome == nome and (riga.metadata == nil or next(riga.metadata) == nil) then
                riga.quantita = riga.quantita + quantita
                self.sporco = true
                return true
            end
        end
    end

    -- ogni unità non impilabile occupa uno slot proprio
    local unitaPerSlot = impilabile and quantita or 1
    local rimanenti = quantita

    while rimanenti > 0 do
        local slot = slotDesiderato
        if slot and self:GetSlot(slot) then slot = nil end
        slot = slot or self:SlotLibero()
        if not slot then
            self.sporco = true
            return false, 'Spazio insufficiente.'
        end

        local q = math.min(unitaPerSlot, rimanenti)
        self.item[#self.item + 1] = {
            slot = slot,
            nome = nome,
            quantita = q,
            metadata = metadata and AUREA.Util.CopiaProfonda(metadata) or nil,
            creato = os.time(),
        }
        rimanenti = rimanenti - q
        slotDesiderato = nil
    end

    self.sporco = true
    return true
end

--- Rimuove una quantità di un oggetto. Restituisce (ok, motivo).
function Contenitore:Rimuovi(nome, quantita, slot)
    quantita = math.floor(tonumber(quantita) or 1)
    if quantita <= 0 then return false, 'Quantità non valida.' end

    if slot then
        local riga = self:GetSlot(slot)
        if not riga or riga.nome ~= nome or riga.quantita < quantita then
            return false, 'Oggetto non presente in quello slot.'
        end
        riga.quantita = riga.quantita - quantita
        if riga.quantita <= 0 then self:SvuotaSlot(slot) end
        self.sporco = true
        return true
    end

    if self:Quantita(nome) < quantita then return false, 'Non ne hai abbastanza.' end

    local rimanenti = quantita
    for i = #self.item, 1, -1 do
        local riga = self.item[i]
        if riga.nome == nome then
            local presi = math.min(riga.quantita, rimanenti)
            riga.quantita = riga.quantita - presi
            rimanenti = rimanenti - presi
            if riga.quantita <= 0 then table.remove(self.item, i) end
            if rimanenti <= 0 then break end
        end
    end

    self.sporco = true
    return true
end

function Contenitore:SvuotaSlot(slot)
    for i = #self.item, 1, -1 do
        if self.item[i].slot == slot then
            table.remove(self.item, i)
            self.sporco = true
            return true
        end
    end
    return false
end

--- Sposta (o divide) un item verso un altro contenitore.
---@return boolean ok, string|nil motivo
function Contenitore:Sposta(destinazione, slotOrigine, quantita, slotDestinazione)
    local riga = self:GetSlot(slotOrigine)
    if not riga then return false, 'Slot di origine vuoto.' end

    quantita = math.min(math.max(1, math.floor(tonumber(quantita) or riga.quantita)), riga.quantita)

    local dati = AUREA.Item[riga.nome]
    if not dati then return false, 'Oggetto sconosciuto.' end

    if (destinazione:Peso() + dati.peso * quantita) > destinazione.pesoMax then
        return false, 'Il contenitore di destinazione non regge il peso.'
    end

    -- Un contenitore non può finire dentro sé stesso
    if riga.metadata and riga.metadata.contenitoreId == destinazione.id then
        return false, 'Non puoi mettere un contenitore dentro sé stesso.'
    end

    local ok, motivo = destinazione:Aggiungi(riga.nome, quantita, riga.metadata, slotDestinazione)
    if not ok then return false, motivo end

    self:Rimuovi(riga.nome, quantita, slotOrigine)
    return true
end

--- Scambia due slot all'interno dello stesso contenitore.
function Contenitore:Scambia(slotA, slotB)
    local a, b = self:GetSlot(slotA), self:GetSlot(slotB)
    if not a then return false end
    if b then
        -- pile dello stesso oggetto senza metadata: si uniscono
        local dati = AUREA.Item[a.nome]
        if a.nome == b.nome and dati and dati.impilabile
           and (a.metadata == nil or next(a.metadata) == nil)
           and (b.metadata == nil or next(b.metadata) == nil) then
            b.quantita = b.quantita + a.quantita
            self:SvuotaSlot(slotA)
            self.sporco = true
            return true
        end
        b.slot = slotA
    end
    a.slot = slotB
    self.sporco = true
    return true
end

--- Rappresentazione per il client, arricchita con i dati del catalogo.
function Contenitore:Pacchetto()
    local item = {}
    for _, riga in ipairs(self.item) do
        local dati = AUREA.Item[riga.nome]
        if dati then
            item[#item + 1] = {
                slot = riga.slot,
                nome = riga.nome,
                etichetta = dati.etichetta,
                quantita = riga.quantita,
                peso = dati.peso,
                categoria = dati.categoria,
                descrizione = dati.descrizione,
                usabile = dati.usabile or false,
                metadata = riga.metadata,
                deperibile = dati.degrada ~= nil,
                freschezza = dati.degrada and math.max(0, math.min(100,
                    100 - ((os.time() - (riga.creato or os.time())) / 60 / dati.degrada) * 100)) or nil,
            }
        end
    end

    return {
        id = self.id,
        tipo = self.tipo,
        capienza = self.capienza,
        pesoMax = self.pesoMax,
        peso = self:Peso(),
        item = item,
    }
end

-- ---------------------------------------------------------------------------
--  Deperimento degli alimenti freschi
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(5 * 60000)
        local adesso = os.time()

        for _, c in pairs(cache) do
            local rimossi = 0
            for i = #c.item, 1, -1 do
                local riga = c.item[i]
                local dati = AUREA.Item[riga.nome]
                if dati and dati.degrada and riga.creato then
                    local minuti = (adesso - riga.creato) / 60
                    if minuti > dati.degrada then
                        table.remove(c.item, i)
                        rimossi = rimossi + 1
                        c.sporco = true
                    end
                end
            end

            if rimossi > 0 and c.tipo == 'personaggio' then
                local citizenid = c.id:match('^pg:(.+)$')
                local g = citizenid and AUREA.GetPlayerByCitizenId(citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '🗑', durata = 8000,
                        titolo = 'Alimenti deteriorati',
                        testo = ('%d prodotti sono andati a male e sono stati buttati.'):format(rimossi),
                    })
                    TriggerClientEvent('inv:aggiorna', g.source, c:Pacchetto())
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Salvataggio periodico dei contenitori modificati
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        for _, c in pairs(cache) do
            pcall(function() c:Salva() end)
        end
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, c in pairs(cache) do pcall(function() c:Salva() end) end
end)
