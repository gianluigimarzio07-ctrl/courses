--[[
    AUREA · Garage (server)
]]

local U = AUREA.Util
local fuori = {}      -- [targa] = { netId, src }

-- ---------------------------------------------------------------------------
--  Elenco dei veicoli ricoverati in un garage
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('gar:elenco', function(src, rispondi, idGarage)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local garage = GAR.GetGarage(idGarage)
    if not garage then return rispondi({}) end

    local statoRichiesto = garage.soloDissequestro and 'sequestrato' or 'garage'
    local condizioneGarage = garage.soloDissequestro and '' or ' AND garage = ?'
    local parametri = garage.soloDissequestro and { g.citizenid, statoRichiesto }
        or { g.citizenid, statoRichiesto, idGarage }

    local righe = MySQL.query.await(([[
        SELECT targa, modello, categoria, carburante, motore, carrozzeria, km,
               bollo_scadenza, assicurazione_tipo, assicurazione_scadenza, revisione_scadenza,
               proprieta
        FROM veicoli WHERE citizenid = ? AND stato = ?%s
        ORDER BY acquistato_il DESC
    ]]):format(condizioneGarage), parametri) or {}

    local adesso = os.time()
    for _, v in ipairs(righe) do
        local catalogo = VEI.GetVeicoloCatalogo(v.modello)
        v.nome = catalogo and catalogo.nome or v.modello
        v.assicurato = v.assicurazione_tipo ~= 'nessuna'
            and v.assicurazione_scadenza and (v.assicurazione_scadenza / 1000) >= adesso
        v.bolloScaduto = not v.bollo_scadenza or (v.bollo_scadenza / 1000) < adesso
        v.revisioneScaduta = not v.revisione_scadenza or (v.revisione_scadenza / 1000) < adesso
        v.giaFuori = fuori[v.targa] ~= nil
        v.proprieta = v.proprieta and json.decode(v.proprieta) or nil
    end

    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Prelievo dal garage
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('gar:preleva', function(src, rispondi, targa, idGarage)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ? AND citizenid = ?', { targa, g.citizenid })
    if not v then return rispondi(false, 'Veicolo non intestato a te.') end
    if v.stato ~= 'garage' then return rispondi(false, 'Il veicolo non è disponibile: è ' .. v.stato .. '.') end
    if fuori[targa] then return rispondi(false, 'Il veicolo risulta già in circolazione.') end

    -- Senza patente valida non si esce dal garage
    local catalogo = VEI.GetVeicoloCatalogo(v.modello)
    local categoriaPatente = (v.categoria == 'moto') and 'A' or (v.categoria == 'camion') and 'C' or 'B'
    if not exports.ita_codicestrada:PatenteHaCategoria(g.citizenid, categoriaPatente) then
        return rispondi(false, ('Non hai una patente %s valida: potrebbe essere sospesa o revocata.'):format(categoriaPatente))
    end

    MySQL.update.await('UPDATE veicoli SET stato = \'fuori\' WHERE targa = ?', { targa })
    fuori[targa] = { src = src }

    local avvisi = {}
    local adesso = os.time()
    if not v.bollo_scadenza or (v.bollo_scadenza / 1000) < adesso then avvisi[#avvisi + 1] = 'bollo scaduto' end
    if not v.revisione_scadenza or (v.revisione_scadenza / 1000) < adesso then avvisi[#avvisi + 1] = 'revisione scaduta' end
    if v.assicurazione_tipo == 'nessuna' or not v.assicurazione_scadenza or (v.assicurazione_scadenza / 1000) < adesso then
        avvisi[#avvisi + 1] = 'SENZA ASSICURAZIONE (art. 193 CdS: sanzione e sequestro)'
    end

    rispondi(true, #avvisi > 0 and ('Attenzione: %s.'):format(table.concat(avvisi, ', ')) or nil, {
        modello = v.modello,
        proprieta = v.proprieta and json.decode(v.proprieta) or nil,
        carburante = v.carburante,
        motore = v.motore,
        carrozzeria = v.carrozzeria,
        targa = targa,
    })
end)

-- ---------------------------------------------------------------------------
--  Ricovero
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('gar:ricovera', function(src, rispondi, dati)
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return rispondi(false, 'Sessione non valida.') end

    local targa = tostring(dati.targa or ''):upper():gsub('%s+', '')
    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ?', { targa })
    if not v then return rispondi(false, 'Veicolo non immatricolato: non può essere ricoverato.') end

    -- Si può ricoverare il proprio veicolo, o quello di cui si hanno le chiavi
    if v.citizenid ~= g.citizenid then
        local proprieta = v.proprieta and json.decode(v.proprieta) or {}
        if not U.Contiene(proprieta.chiavi or {}, g.citizenid) then
            return rispondi(false, 'Non hai le chiavi di questo veicolo.')
        end
    end

    local garage = GAR.GetGarage(dati.garage)
    if not garage or garage.soloDissequestro then return rispondi(false, 'Garage non valido.') end

    MySQL.update.await([[
        UPDATE veicoli SET stato = 'garage', garage = ?, carburante = ?, motore = ?, carrozzeria = ?, km = ?
        WHERE targa = ?
    ]], {
        dati.garage,
        math.max(0, math.min(100, tonumber(dati.carburante) or v.carburante)),
        math.max(0, math.min(1000, tonumber(dati.motore) or v.motore)),
        math.max(0, math.min(1000, tonumber(dati.carrozzeria) or v.carrozzeria)),
        math.max(v.km, math.floor(tonumber(dati.km) or v.km)),
        targa,
    })

    fuori[targa] = nil
    rispondi(true, ('%s ricoverato in %s.'):format(targa, garage.nome))
end)

--- Salvataggio delle personalizzazioni (colori, cerchi, elaborazioni).
RegisterNetEvent('gar:salvaProprieta', function(targa, proprieta)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g or type(proprieta) ~= 'table' then return end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local v = MySQL.single.await('SELECT proprieta FROM veicoli WHERE targa = ? AND citizenid = ?', { targa, g.citizenid })
    if not v then return end

    -- si conservano i campi gestiti dal server (chiavi, classe di merito)
    local esistenti = v.proprieta and json.decode(v.proprieta) or {}
    proprieta.chiavi = esistenti.chiavi
    proprieta.classeMerito = esistenti.classeMerito
    proprieta.sinistri = esistenti.sinistri

    MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(proprieta), targa })
end)

--- Aggiornamento periodico dello stato del veicolo mentre è in circolazione.
RegisterNetEvent('gar:sincronizza', function(dati)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g or type(dati) ~= 'table' then return end

    local targa = tostring(dati.targa or ''):upper():gsub('%s+', '')
    if targa == '' or not fuori[targa] then return end

    MySQL.update('UPDATE veicoli SET carburante = ?, motore = ?, carrozzeria = ?, km = ? WHERE targa = ? AND citizenid = ?', {
        math.max(0, math.min(100, tonumber(dati.carburante) or 100)),
        math.max(0, math.min(1000, tonumber(dati.motore) or 1000)),
        math.max(0, math.min(1000, tonumber(dati.carrozzeria) or 1000)),
        math.max(0, math.floor(tonumber(dati.km) or 0)),
        targa, g.citizenid,
    })
end)

-- ---------------------------------------------------------------------------
--  Rifornimento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('gar:rifornisci', function(src, rispondi, litri, premium)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    litri = math.max(1, math.min(120, math.floor(tonumber(litri) or 0)))
    local prezzo = premium and GAR.Carburante.prezzoLitroPremium or GAR.Carburante.prezzoLitro
    local totale = litri * prezzo

    if not g:SottraiOvunque(totale, 'rifornimento carburante') then
        return rispondi(false, ('Servono %s per %d litri.'):format(U.Euro(totale), litri))
    end

    -- Le accise sui carburanti sono la voce fiscale più corposa
    exports.ita_fisco:ErarioIncassa('accise_carburanti', math.floor(totale * 0.62), g.citizenid)

    rispondi(true, ('%d litri per %s (%s al litro).'):format(litri, U.Euro(totale), U.Euro(prezzo)), litri)
end)

-- ---------------------------------------------------------------------------
--  Rientro forzato dei veicoli al logout
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giocatore:scaricato', function(src, g)
    local rientrati = MySQL.update.await(
        'UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE citizenid = ? AND stato = \'fuori\'',
        { g.citizenid })

    for targa, dati in pairs(fuori) do
        if dati.src == src then fuori[targa] = nil end
    end

    if rientrati and rientrati > 0 then
        AUREA.Log('veicoli', 'debug', g, ('%d veicoli rientrati in garage alla disconnessione'):format(rientrati))
    end
end)

-- All'avvio della risorsa nessun veicolo può essere "fuori"
CreateThread(function()
    Wait(2000)
    MySQL.update('UPDATE veicoli SET stato = \'garage\' WHERE stato = \'fuori\'')
end)

-- ---------------------------------------------------------------------------
--  Chiavi condivise
-- ---------------------------------------------------------------------------
AUREA.Comando('chiavi', 'utente', 'Dai le chiavi del veicolo alla persona più vicina', {
    { name = 'targa', help = 'Targa del veicolo' },
}, function(src, args, _, g)
    if not g then return end

    local targa = (args[1] or ''):upper():gsub('%s+', '')
    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ? AND citizenid = ?', { targa, g.citizenid })
    if not v then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non tuo', testo = 'Questo veicolo non è intestato a te.' })
    end

    local origine = GetEntityCoords(GetPlayerPed(src))
    local bersaglio, minima = nil, 4.0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= src then
            local d = #(origine - GetEntityCoords(GetPlayerPed(altro.source)))
            if d < minima then bersaglio, minima = altro, d end
        end
    end
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
    end

    local proprieta = v.proprieta and json.decode(v.proprieta) or {}
    proprieta.chiavi = proprieta.chiavi or {}

    if U.Contiene(proprieta.chiavi, bersaglio.citizenid) then
        for i, c in ipairs(proprieta.chiavi) do
            if c == bersaglio.citizenid then table.remove(proprieta.chiavi, i) break end
        end
        TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'info', icona = '🔑', titolo = 'Chiavi ritirate', testo = bersaglio:NomeCompleto() })
        TriggerClientEvent('aurea:ui:notifica', bersaglio.source, { tipo = 'avviso', icona = '🔑', titolo = 'Chiavi ritirate', testo = ('%s ti ha tolto le chiavi di %s.'):format(g:NomeCompleto(), targa) })
    else
        proprieta.chiavi[#proprieta.chiavi + 1] = bersaglio.citizenid
        TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', icona = '🔑', titolo = 'Chiavi consegnate', testo = bersaglio:NomeCompleto() })
        TriggerClientEvent('aurea:ui:notifica', bersaglio.source, { tipo = 'successo', icona = '🔑', titolo = 'Chiavi ricevute', testo = ('%s ti ha dato le chiavi di %s.'):format(g:NomeCompleto(), targa) })
    end

    MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(proprieta), targa })
end)
