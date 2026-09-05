--[[
    AUREA · Mercato nero (server)
]]

local U = AUREA.Util
local posizioneMercato = nil

local function calore(g, punti, motivo)
    if g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, punti, motivo)
    end
end

local function banconote(prezzo, quantita)
    return math.ceil((prezzo * (quantita or 1)) / ILL.MercatoNero.tagliobanconota)
end

-- ---------------------------------------------------------------------------
--  Il banco si sposta a ogni riavvio
-- ---------------------------------------------------------------------------
CreateThread(function()
    posizioneMercato = ILL.MercatoNero.posizioni[math.random(#ILL.MercatoNero.posizioni)]
    Wait(4000)
    print(('[AUREA] mercato nero collocato in %.1f %.1f'):format(posizioneMercato.x, posizioneMercato.y))
end)

AUREA.Callback.Registra('ill:mercatoDove', function(src, rispondi)
    if not posizioneMercato then return rispondi(nil) end
    rispondi({ x = posizioneMercato.x, y = posizioneMercato.y, z = posizioneMercato.z })
end)

local function alBanco(src)
    local coord = GetEntityCoords(GetPlayerPed(src))
    return posizioneMercato ~= nil and #(coord - posizioneMercato) <= ILL.MercatoNero.distanza
end

-- ---------------------------------------------------------------------------
--  Catalogo e acquisti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:mercatoCatalogo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if not alBanco(src) then return rispondi(nil, 'Non sei al mercato.') end

    local oggetti = {}
    for _, v in ipairs(ILL.MercatoNero.catalogo) do
        local dati = AUREA.Item[v.item]
        if dati then
            oggetti[#oggetti + 1] = {
                item = v.item, etichetta = dati.etichetta,
                descrizione = dati.descrizione,
                prezzo = v.prezzo, banconote = banconote(v.prezzo),
            }
        end
    end
    table.sort(oggetti, function(a, b) return a.prezzo < b.prezzo end)

    local armi = {}
    for _, v in ipairs(ILL.MercatoNero.armi) do
        armi[#armi + 1] = {
            arma = v.arma, prezzo = v.prezzo, banconote = banconote(v.prezzo),
        }
    end
    table.sort(armi, function(a, b) return a.prezzo < b.prezzo end)

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    rispondi({
        oggetti = oggetti, armi = armi,
        banconote = inventario:Quantita(ILL.MercatoNero.provento),
    })
end)

AUREA.Callback.Registra('ill:mercatoAcquista', function(src, rispondi, tipo, chiave, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if not alBanco(src) then return rispondi(false, 'Non sei al mercato.') end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 1, 1, 50))

    local prezzo, item, arma
    if tipo == 'oggetto' then
        for _, v in ipairs(ILL.MercatoNero.catalogo) do
            if v.item == chiave then prezzo = v.prezzo item = v.item break end
        end
    else
        quantita = 1
        for _, v in ipairs(ILL.MercatoNero.armi) do
            if v.arma == chiave then prezzo = v.prezzo arma = v.arma break end
        end
    end

    if not prezzo then return rispondi(false, 'Merce non disponibile.') end

    local dovute = banconote(prezzo, quantita)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if not inventario:Ha(ILL.MercatoNero.provento, dovute) then
        return rispondi(false, ('Servono %d banconote non tracciate. Qui non si accettano bonifici.'):format(dovute))
    end

    inventario:Rimuovi(ILL.MercatoNero.provento, dovute)

    if item then
        if not inventario:Aggiungi(item, quantita) then
            inventario:Aggiungi(ILL.MercatoNero.provento, dovute)
            return rispondi(false, 'Non hai spazio.')
        end
    else
        -- Arma clandestina: nessuna matricola, nessun registro
        exports.aurea_armi:RegistraArma(g.citizenid, arma, true)
    end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
    calore(g, ILL.MercatoNero.calore, 'acquisto al mercato nero')

    AUREA.Log('giustizia', 'debug', g, ('acquisto al mercato nero: %s'):format(chiave))
    rispondi(true, ('Affare fatto. %d banconote consegnate.'):format(dovute))
end)
