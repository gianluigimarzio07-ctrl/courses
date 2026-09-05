--[[
    AUREA · Farmacia (server)
]]

local U = AUREA.Util

AUREA.Callback.Registra('far:banco', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    if not FAR.FarmaciaVicina(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(nil, 'Non sei in farmacia.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    -- Le ricette che ha addosso, ancora valide
    local ricette = {}
    for _, riga in ipairs(inventario.item) do
        if riga.nome == 'ricetta' and riga.metadata then
            local emessa = tonumber(riga.metadata.emessa) or 0
            if (os.time() - emessa) < FAR.Ricette.validitaOre * 3600 then
                ricette[riga.metadata.farmaco] = {
                    slot = riga.slot,
                    confezioni = tonumber(riga.metadata.confezioni) or 1,
                    medico = riga.metadata.medico,
                }
            end
        end
    end

    local catalogo = {}
    for _, f in ipairs(FAR.Catalogo) do
        local r = ricette[f.item]
        local prezzo = f.prezzo
        if f.ricetta and r then prezzo = math.floor(f.prezzo * FAR.Ticket.quota) end

        catalogo[#catalogo + 1] = {
            item = f.item, nome = f.nome, descrizione = f.descrizione,
            prezzo = prezzo, prezzoPieno = f.prezzo,
            ricetta = f.ricetta,
            haRicetta = r ~= nil,
            confezioni = r and r.confezioni or nil,
            medico = r and r.medico or nil,
        }
    end

    rispondi({ catalogo = catalogo, quotaTicket = FAR.Ticket.quota })
end)

AUREA.Callback.Registra('far:acquista', function(src, rispondi, item, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not FAR.FarmaciaVicina(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Non sei in farmacia.')
    end

    local f = FAR.GetFarmaco(item)
    if not f then return rispondi(false, 'Farmaco non in catalogo.') end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 1, 1, 10))
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    local prezzoUnitario = f.prezzo
    local slotRicetta = nil

    if f.ricetta then
        -- Si cerca una ricetta valida per questo farmaco
        for _, riga in ipairs(inventario.item) do
            if riga.nome == 'ricetta' and riga.metadata
               and riga.metadata.farmaco == item then
                local emessa = tonumber(riga.metadata.emessa) or 0
                if (os.time() - emessa) < FAR.Ricette.validitaOre * 3600 then
                    slotRicetta = riga.slot
                    quantita = math.min(quantita, tonumber(riga.metadata.confezioni) or 1)
                    prezzoUnitario = math.floor(f.prezzo * FAR.Ticket.quota)
                    break
                end
            end
        end

        if not slotRicetta then
            return rispondi(false, ('%s si vende solo con ricetta medica.'):format(f.nome))
        end
    end

    local totale = prezzoUnitario * quantita
    if not g:SottraiOvunque(totale, ('farmacia · %s'):format(f.nome)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(totale)))
    end

    if not inventario:Aggiungi(item, quantita) then
        g:Aggiungi('contanti', totale, 'rimborso farmacia')
        return rispondi(false, 'Non hai spazio.')
    end

    -- La ricetta si consuma
    if slotRicetta then inventario:Rimuovi('ricetta', 1, slotRicetta) end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    -- Sui farmaci l'IVA è agevolata al 10%
    TriggerEvent('aurea:fisco:incasso', 'iva_farmaci', math.floor(totale * 0.10), g.citizenid)

    rispondi(true, ('%d× %s per %s.%s'):format(quantita, f.nome, U.Euro(totale),
        slotRicetta and ' Ricetta ritirata.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Prescrizione, da parte del medico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('far:prescrivi', function(src, rispondi, bersaglioSrc, item, confezioni)
    local g = AUREA.GetPlayer(src)
    local paziente = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not paziente then return rispondi(false, 'Paziente non trovato.') end

    if not U.Contiene(FAR.Ricette.lavori, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(false, 'Solo il personale sanitario in servizio può prescrivere.')
    end

    local f = FAR.GetFarmaco(item)
    if not f or not f.ricetta then return rispondi(false, 'Questo farmaco non richiede ricetta.') end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(paziente.source)))
    if d > 4.0 then return rispondi(false, 'Il paziente deve essere davanti a te.') end

    confezioni = math.floor(U.Clamp(tonumber(confezioni) or 1, 1, FAR.Ricette.confezioniMassime))

    TriggerEvent('aurea:inventario:aggiungi', paziente.citizenid, 'ricetta', 1, {
        farmaco = item,
        nomeFarmaco = f.nome,
        confezioni = confezioni,
        medico = g:NomeCompleto(),
        paziente = paziente:NomeCompleto(),
        emessa = os.time(),
        validaOre = FAR.Ricette.validitaOre,
    })

    TriggerClientEvent('aurea:ui:notifica', paziente.source, {
        tipo = 'successo', icona = '💊', durata = 13000,
        titolo = 'Ricetta rilasciata',
        testo = ('%s ti ha prescritto %d× %s. Vale %d ore.')
            :format(g:NomeCompleto(), confezioni, f.nome, FAR.Ricette.validitaOre),
    })

    AUREA.Log('staff', 'debug', g, ('ha prescritto %s a %s'):format(item, paziente.citizenid))
    rispondi(true, ('Ricetta per %d× %s consegnata a %s.')
        :format(confezioni, f.nome, paziente:NomeCompleto()))
end)

AUREA.Callback.Registra('far:prescrivibili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene(FAR.Ricette.lavori, g.lavoro.nome) then return rispondi({}) end

    local out = {}
    for _, f in ipairs(FAR.Catalogo) do
        if f.ricetta then
            out[#out + 1] = { item = f.item, nome = f.nome, descrizione = f.descrizione }
        end
    end
    rispondi(out)
end)
