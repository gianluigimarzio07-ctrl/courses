--[[
    AUREA · Negozi (server)
]]

local U = AUREA.Util

--- Prezzo corrente di un bene a mercato dinamico.
local function prezzoMercato(item)
    local riga = MySQL.single.await('SELECT prezzo, prezzo_base FROM mercato WHERE item = ?', { item })
    if not riga then return nil end
    return tonumber(riga.prezzo) or tonumber(riga.prezzo_base)
end

--- Catalogo esposto al client, con prezzi già aggiornati.
AUREA.Callback.Registra('neg:catalogo', function(src, rispondi, tipoNegozio)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local tipo = NEG.GetTipo(tipoNegozio)
    if not tipo then return rispondi(nil) end

    local out = { vende = {}, acquista = {} }

    if tipo.dinamico then
        for _, item in ipairs(tipo.vende or {}) do
            local dati = AUREA.Item[item]
            local prezzo = prezzoMercato(item)
            if dati and prezzo then
                out.vende[#out.vende + 1] = {
                    item = item, etichetta = dati.etichetta, categoria = dati.categoria,
                    prezzo = math.floor(prezzo * NEG.Ricarico), peso = dati.peso,
                }
            end
        end

        local inventario = exports.aurea_inventory:Inventario(g.citizenid)
        for _, item in ipairs(tipo.acquista or {}) do
            local dati = AUREA.Item[item]
            local prezzo = prezzoMercato(item)
            local posseduti = inventario:Quantita(item)
            if dati and prezzo and posseduti > 0 then
                out.acquista[#out.acquista + 1] = {
                    item = item, etichetta = dati.etichetta,
                    prezzo = math.floor(prezzo * NEG.ScontoAcquisto),
                    posseduti = posseduti,
                }
            end
        end
    else
        for _, riga in ipairs(tipo.catalogo or {}) do
            local dati = AUREA.Item[riga.item]
            if dati then
                local ammesso = true
                if riga.licenza == 'forze_ordine' then
                    ammesso = AUREA.EForzaOrdine(g.lavoro.nome)
                end
                if ammesso then
                    out.vende[#out.vende + 1] = {
                        item = riga.item, etichetta = dati.etichetta, categoria = dati.categoria,
                        prezzo = riga.prezzo, peso = dati.peso, descrizione = dati.descrizione,
                    }
                end
            end
        end
    end

    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Acquisto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('neg:acquista', function(src, rispondi, tipoNegozio, carrello, conBancomat)
    local g = AUREA.GetPlayer(src)
    if not g or type(carrello) ~= 'table' then return rispondi(false, 'Richiesta non valida.') end

    local tipo = NEG.GetTipo(tipoNegozio)
    if not tipo then return rispondi(false, 'Negozio non riconosciuto.') end

    -- Si ricostruisce il prezzo lato server: il client non lo decide
    local totale, ivaTotale, righe = 0, 0, {}

    for _, voce in ipairs(carrello) do
        local quantita = math.max(1, math.min(100, math.floor(tonumber(voce.quantita) or 1)))
        local prezzo

        if tipo.dinamico then
            if not U.Contiene(tipo.vende or {}, voce.item) then return rispondi(false, 'Articolo non in vendita.') end
            local base = prezzoMercato(voce.item)
            if not base then return rispondi(false, 'Prezzo non disponibile.') end
            prezzo = math.floor(base * NEG.Ricarico)
        else
            for _, riga in ipairs(tipo.catalogo or {}) do
                if riga.item == voce.item then prezzo = riga.prezzo break end
            end
            if not prezzo then return rispondi(false, 'Articolo non in vendita.') end
        end

        local lordo = prezzo * quantita
        local aliquota = exports.ita_fisco:AliquotaItem(voce.item)
        local imponibile = math.floor(lordo / (1 + aliquota / 100))

        totale = totale + lordo
        ivaTotale = ivaTotale + (lordo - imponibile)
        righe[#righe + 1] = { item = voce.item, quantita = quantita, lordo = lordo }
    end

    if totale <= 0 then return rispondi(false, 'Carrello vuoto.') end

    local conto = conBancomat and 'banca' or 'contanti'
    if not g:Sottrai(conto, totale, ('acquisto presso %s'):format(tipo.nome)) then
        return rispondi(false, ('Servono %s%s.'):format(U.Euro(totale), conBancomat and ' sul conto' or ' in contanti'))
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local consegnati = {}
    for _, riga in ipairs(righe) do
        local ok = inventario:Aggiungi(riga.item, riga.quantita)
        if ok then
            consegnati[#consegnati + 1] = riga
        else
            -- rimborso della parte non consegnabile
            g:Aggiungi(conto, riga.lordo, 'rimborso articolo non consegnabile')
            totale = totale - riga.lordo
        end
    end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
    TriggerEvent('aurea:fisco:incasso', 'iva', ivaTotale, g.citizenid)
    TriggerEvent('aurea:economia:domanda', righe)

    if #consegnati == 0 then
        return rispondi(false, 'Inventario pieno: nessun articolo consegnato.')
    end

    rispondi(true, ('Scontrino di %s · IVA %s. %d articoli.'):format(
        U.Euro(totale), U.Euro(ivaTotale), #consegnati))
end)

-- ---------------------------------------------------------------------------
--  Vendita al mercato
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('neg:vendi', function(src, rispondi, tipoNegozio, item, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local tipo = NEG.GetTipo(tipoNegozio)
    if not tipo or not tipo.dinamico or not U.Contiene(tipo.acquista or {}, item) then
        return rispondi(false, 'Questo esercizio non acquista tale merce.')
    end

    quantita = math.max(1, math.min(500, math.floor(tonumber(quantita) or 1)))

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(item, quantita) then return rispondi(false, 'Non ne hai abbastanza.') end

    local base = prezzoMercato(item)
    if not base then return rispondi(false, 'Prezzo non disponibile.') end

    -- I prodotti certificati valgono di più: si legge la metadata del lotto
    local riga = inventario:Trova(item, function(m) return m.certificazione ~= nil end)
    local moltiplicatore = 1.0
    if riga and riga.metadata then
        local bonus = { IGP = 1.4, DOP = 1.9, DOCG = 2.2, BIO = 1.5 }
        moltiplicatore = bonus[riga.metadata.certificazione] or 1.0
        if riga.metadata.qualita then
            moltiplicatore = moltiplicatore * (0.7 + (riga.metadata.qualita / 100) * 0.6)
        end
    end

    local unitario = math.floor(base * NEG.ScontoAcquisto * moltiplicatore)
    local ricavo = unitario * quantita

    inventario:Rimuovi(item, quantita)
    g:Aggiungi('contanti', ricavo, ('vendita %dx %s'):format(quantita, item))
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    TriggerEvent('aurea:economia:offerta', { { item = item, quantita = quantita } })

    rispondi(true, ('Venduti %d× %s per %s (%s l\'uno%s).'):format(
        quantita, AUREA.Item[item].etichetta, U.Euro(ricavo), U.Euro(unitario),
        moltiplicatore > 1.05 and ', certificazione valorizzata' or ''))
end)
