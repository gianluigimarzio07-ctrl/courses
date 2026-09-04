--[[
    AUREA · Negozi (client)
]]

local U = AUREA.Util

CreateThread(function()
    for _, p in ipairs(NEG.PuntiVendita) do
        local tipo = NEG.GetTipo(p.tipo)
        if tipo and tipo.blip then
            local blip = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
            SetBlipSprite(blip, tipo.blip.sprite)
            SetBlipColour(blip, tipo.blip.colore)
            SetBlipScale(blip, tipo.blip.scala)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(p.nome)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local vicino = nil

        for _, p in ipairs(NEG.PuntiVendita) do
            if #(coord - p.coord) < 2.2 then vicino = p break end
        end

        if vicino then
            attesa = 0
            exports.aurea_ui:Prompt(true, vicino.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                apriNegozio(vicino)
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Interfaccia del negozio
-- ---------------------------------------------------------------------------
function apriNegozio(punto)
    local tipo = NEG.GetTipo(punto.tipo)
    local catalogo = AUREA.Callback.Attendi('neg:catalogo', punto.tipo)
    if not catalogo then return end

    if tipo.dinamico then
        local sezione = exports.aurea_ui:Menu({
            titolo = punto.nome,
            sottotitolo = 'I prezzi seguono l\'andamento di domanda e offerta',
            voci = {
                { id = 'compra', icona = '🛒', titolo = 'Acquista materie prime',
                  descrizione = ('%d articoli disponibili'):format(#catalogo.vende) },
                { id = 'vendi', icona = '💰', titolo = 'Vendi i tuoi prodotti',
                  descrizione = #catalogo.acquista > 0
                    and ('%d tipi di merce conferibile'):format(#catalogo.acquista)
                    or 'Non hai merce che il mercato acquisti.',
                  disattivata = #catalogo.acquista == 0 },
            },
        })
        if not sezione then return end
        if sezione == 'vendi' then return venditaMercato(punto, catalogo.acquista) end
    end

    carrello(punto, tipo, catalogo.vende)
end

--- Selezione multipla con quantità, poi cassa.
function carrello(punto, tipo, articoli)
    local scelti = {}

    while true do
        local voci = {}
        local totale = 0

        for _, a in ipairs(articoli) do
            local q = scelti[a.item] or 0
            totale = totale + a.prezzo * q
            voci[#voci + 1] = {
                id = a.item,
                icona = q > 0 and '✅' or '🛒',
                titolo = a.etichetta,
                descrizione = a.descrizione or ('%.2f kg · %s'):format(a.peso / 1000, a.categoria),
                valore = q > 0 and ('%d × %s'):format(q, U.Euro(a.prezzo)) or U.Euro(a.prezzo),
            }
        end

        table.insert(voci, 1, {
            id = '__cassa',
            icona = '💳',
            titolo = totale > 0 and 'Vai alla cassa' or 'Carrello vuoto',
            descrizione = totale > 0 and 'Prezzi IVA inclusa, scontrino emesso alla cassa.' or 'Seleziona gli articoli.',
            valore = U.Euro(totale),
            disattivata = totale == 0,
        })

        if totale > 0 then
            table.insert(voci, 2, { id = '__svuota', icona = '🗑', titolo = 'Svuota il carrello' })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = punto.nome,
            sottotitolo = totale > 0 and ('Totale carrello: %s'):format(U.Euro(totale)) or 'Prezzi al pubblico',
            voci = voci,
        })

        if not scelta then return end

        if scelta == '__svuota' then
            scelti = {}
        elseif scelta == '__cassa' then
            return cassa(punto, scelti, totale)
        else
            local valori = exports.aurea_ui:Dialogo('Quantità', {
                { etichetta = 'Quante unità?', tipo = 'number', valore = (scelti[scelta] or 0) + 1, min = 0, max = 100 },
            })
            if valori then
                local q = math.max(0, math.min(100, tonumber(valori[1]) or 0))
                scelti[scelta] = q > 0 and q or nil
            end
        end
    end
end

function cassa(punto, scelti, totale)
    local metodo = exports.aurea_ui:Menu({
        titolo = 'Cassa',
        sottotitolo = ('Totale da pagare: %s'):format(U.Euro(totale)),
        voci = {
            { id = 'contanti', icona = '💶', titolo = 'Contanti', descrizione = 'Paghi con il denaro che hai addosso.' },
            { id = 'bancomat', icona = '💳', titolo = 'Bancomat', descrizione = 'Addebito diretto sul conto corrente.' },
        },
    })
    if not metodo then return end

    local righe = {}
    for item, quantita in pairs(scelti) do
        righe[#righe + 1] = { item = item, quantita = quantita }
    end

    local ok, messaggio = AUREA.Callback.Attendi('neg:acquista', punto.tipo, righe, metodo == 'bancomat')
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        icona = ok and '🧾' or '❌',
        titolo = ok and 'Acquisto completato' or 'Pagamento rifiutato',
        testo = messaggio, durata = 9000,
    })
end

-- ---------------------------------------------------------------------------
--  Vendita al mercato
-- ---------------------------------------------------------------------------
function venditaMercato(punto, articoli)
    local voci = {}
    for _, a in ipairs(articoli) do
        voci[#voci + 1] = {
            id = a.item, icona = '📦',
            titolo = a.etichetta,
            descrizione = ('Ne hai %d'):format(a.posseduti),
            valore = ('%s cad.'):format(U.Euro(a.prezzo)),
        }
    end

    local item = exports.aurea_ui:Menu({
        titolo = 'Conferimento merce',
        sottotitolo = 'I prodotti certificati DOP e DOCG valgono molto di più',
        voci = voci,
    })
    if not item then return end

    local disponibili = 1
    for _, a in ipairs(articoli) do
        if a.item == item then disponibili = a.posseduti break end
    end

    local valori = exports.aurea_ui:Dialogo('Quantità da vendere', {
        { etichetta = ('Unità (max %d)'):format(disponibili), tipo = 'number', valore = disponibili, min = 1, max = disponibili },
    })
    if not valori then return end

    local completato = exports.aurea_ui:Progresso({
        etichetta = 'Pesatura e conferimento...',
        durata = 4000, annullabile = true, blocca = { movimento = true },
    })
    if not completato then return end

    local ok, messaggio = AUREA.Callback.Attendi('neg:vendi', punto.tipo, item, valori[1])
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore',
        icona = '💰', titolo = ok and 'Merce conferita' or 'Conferimento rifiutato',
        testo = messaggio, durata = 10000,
    })
end
