--[[
    AUREA · Rapine (server)
]]

local U = AUREA.Util
local inCorso = {}          -- [idBersaglio] = { promotore, avviata, fase, partecipanti }
local raffreddamenti = {}   -- [idBersaglio] = timestamp di riapertura
local portavaloriAttivo = nil

-- ---------------------------------------------------------------------------
--  Presupposti
-- ---------------------------------------------------------------------------

--- Quanti agenti delle forze dell'ordine sono realmente in servizio.
local function agentiInServizio()
    local totale = 0
    for _, ente in ipairs({ 'carabinieri', 'polizia', 'guardia_finanza' }) do
        totale = totale + #AUREA.GetGiocatoriPerEnte(ente, true)
    end
    return totale
end

exports('AgentiInServizio', agentiInServizio)

--- Verifica tutte le condizioni per avviare un colpo.
local function verifica(g, bersaglio)
    local livello = RAP.Livelli[bersaglio.livello]

    if inCorso[bersaglio.id] then
        return false, 'C\'è già un colpo in corso qui.'
    end

    local riapertura = raffreddamenti[bersaglio.id]
    if riapertura and os.time() < riapertura then
        return false, ('Il posto è ancora sorvegliato. Riprova fra %d minuti.'):format(
            math.ceil((riapertura - os.time()) / 60))
    end

    local agenti = agentiInServizio()
    if agenti < livello.agentiRichiesti then
        return false, ('Servono almeno %d agenti in servizio: adesso ce ne sono %d. Senza qualcuno che possa rispondere, il colpo non ha senso.'):format(
            livello.agentiRichiesti, agenti)
    end

    if livello.attrezzo and not exports.aurea_inventory:Ha(g.citizenid, livello.attrezzo, 1) then
        local dati = AUREA.Item[livello.attrezzo]
        return false, ('Ti serve: %s.'):format(dati and dati.etichetta or livello.attrezzo)
    end

    for _, item in ipairs(livello.richiedeInoltre or {}) do
        if not exports.aurea_inventory:Ha(g.citizenid, item, 1) then
            local dati = AUREA.Item[item]
            return false, ('Ti serve anche: %s.'):format(dati and dati.etichetta or item)
        end
    end

    -- I colpi grossi richiedono una squadra sul posto
    if livello.complicMinimi then
        local origine = GetEntityCoords(GetPlayerPed(g.source))
        local presenti = 0
        for _, altro in pairs(AUREA.Giocatori) do
            if #(origine - GetEntityCoords(GetPlayerPed(altro.source))) <= RAP.Regole.raggioPresenza then
                presenti = presenti + 1
            end
        end
        if presenti < livello.complicMinimi then
            return false, ('Servono almeno %d persone sul posto: siete in %d.'):format(
                livello.complicMinimi, presenti)
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rap:avvia', function(src, rispondi, idBersaglio, mascherato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local bersaglio = RAP.GetBersaglio(idBersaglio)
    if not bersaglio then return rispondi(nil, 'Bersaglio non riconosciuto.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - bersaglio.coord) > RAP.Regole.distanza + 2.0 then
        return rispondi(nil, 'Sei troppo lontano.')
    end

    local ok, motivo = verifica(g, bersaglio)
    if not ok then return rispondi(nil, motivo) end

    local livello = RAP.Livelli[bersaglio.livello]

    -- Chi c'è intorno partecipa e incassa
    local partecipanti = {}
    for _, altro in pairs(AUREA.Giocatori) do
        if #(coord - GetEntityCoords(GetPlayerPed(altro.source))) <= RAP.Regole.raggioPresenza then
            partecipanti[#partecipanti + 1] = altro.citizenid
        end
    end

    inCorso[bersaglio.id] = {
        promotore = g.citizenid,
        avviata = os.time(),
        fase = 1,
        partecipanti = partecipanti,
        mascherato = mascherato == true,
        coord = { x = bersaglio.coord.x, y = bersaglio.coord.y, z = bersaglio.coord.z },
    }

    -- La centrale riceve l'allarme
    TriggerEvent('aurea:112:allerta', 'rapina',
        { x = bersaglio.coord.x, y = bersaglio.coord.y, z = bersaglio.coord.z },
        ('Allarme antirapina: %s'):format(bersaglio.nome),
        bersaglio.nome)

    exports.aurea_ui:NotificaEnte('carabinieri', {
        tipo = 'errore', icona = '🚨', durata = 20000,
        titolo = 'RAPINA IN CORSO',
        testo = ('%s — allarme scattato. Intervento immediato.'):format(bersaglio.nome),
    }, true)
    exports.aurea_ui:NotificaEnte('polizia', {
        tipo = 'errore', icona = '🚨', durata = 20000,
        titolo = 'RAPINA IN CORSO',
        testo = ('%s — allarme scattato. Intervento immediato.'):format(bersaglio.nome),
    }, true)

    if g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, livello.calore, 'rapina')
    end

    AUREA.Log('giustizia', 'allarme', g, ('rapina avviata: %s (%d partecipanti)'):format(
        bersaglio.nome, #partecipanti))

    rispondi({
        livello = bersaglio.livello,
        nome = bersaglio.nome,
        durata = livello.durata,
        fasi = livello.fasi,
        vetrine = livello.vetrine,
        durataVetrina = livello.durataVetrina,
        partecipanti = #partecipanti,
    })
end)

-- ---------------------------------------------------------------------------
--  Avanzamento e conclusione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rap:concludi', function(src, rispondi, idBersaglio, completata)
    local g = AUREA.GetPlayer(src)
    local rapina = inCorso[idBersaglio]
    if not g or not rapina then return rispondi(false, 'Nessun colpo in corso.') end
    if rapina.promotore ~= g.citizenid then return rispondi(false, 'Non sei tu a condurre il colpo.') end

    local bersaglio = RAP.GetBersaglio(idBersaglio)
    local livello = RAP.Livelli[bersaglio.livello]

    inCorso[idBersaglio] = nil
    raffreddamenti[idBersaglio] = os.time() + livello.raffreddamentoMinuti * 60

    if not completata then
        AUREA.Log('giustizia', 'info', g, ('rapina abbandonata: %s'):format(bersaglio.nome))
        return rispondi(false, 'Colpo abbandonato.')
    end

    -- Il tempo dev'essere trascorso davvero
    local trascorso = (os.time() - rapina.avviata) * 1000
    if trascorso < livello.durata * 0.7 then
        AUREA.Log('anticheat', 'allarme', g, ('rapina conclusa troppo in fretta su %s'):format(bersaglio.nome))
        return rispondi(false, 'Operazione non valida.')
    end

    -- Il bottino si divide fra chi era presente ed è ancora sul posto
    local presenti = {}
    local origine = vector3(rapina.coord.x, rapina.coord.y, rapina.coord.z)

    for _, citizenid in ipairs(rapina.partecipanti) do
        local p = AUREA.GetPlayerByCitizenId(citizenid)
        if p and #(origine - GetEntityCoords(GetPlayerPed(p.source))) <= RAP.Regole.raggioPresenza then
            presenti[#presenti + 1] = p
        end
    end

    if #presenti == 0 then presenti = { g } end

    local bottino = math.random(livello.bottinoMin, livello.bottinoMax)
    local quota = math.max(1, math.floor(bottino / #presenti))

    for _, p in ipairs(presenti) do
        local inventario = exports.aurea_inventory:Inventario(p.citizenid)
        inventario:Aggiungi(RAP.Regole.provento, quota)
        TriggerClientEvent('inv:aggiorna', p.source, inventario:Pacchetto())

        -- Fascicolo a carico di tutti i presenti
        exports.ita_giustizia:ApriFascicolo(p.citizenid, livello.reato,
            'accertamento sui filmati',
            ('Rapina ai danni di %s'):format(bersaglio.nome))
    end

    -- Le telecamere: senza volto coperto si viene identificati subito
    local probabilita = rapina.mascherato
        and RAP.Regole.probabilitaIdentificazioneMascherato
        or RAP.Regole.probabilitaIdentificazione

    if math.random(100) <= probabilita then
        local nomi = {}
        for _, p in ipairs(presenti) do nomi[#nomi + 1] = p:NomeCompleto() end

        exports.aurea_ui:NotificaEnte('carabinieri', {
            tipo = 'avviso', icona = '📹', durata = 18000,
            titolo = 'Filmati acquisiti',
            testo = ('%s — identificati: %s'):format(bersaglio.nome, table.concat(nomi, ', ')),
        }, true)
        exports.aurea_ui:NotificaEnte('polizia', {
            tipo = 'avviso', icona = '📹', durata = 18000,
            titolo = 'Filmati acquisiti',
            testo = ('%s — identificati: %s'):format(bersaglio.nome, table.concat(nomi, ', ')),
        }, true)
    else
        exports.aurea_ui:NotificaEnte('carabinieri', {
            tipo = 'info', icona = '📹', durata = 14000,
            titolo = 'Filmati acquisiti',
            testo = ('%s — soggetti a volto coperto, identificazione non possibile.'):format(bersaglio.nome),
        }, true)
    end

    AUREA.Log('giustizia', 'allarme', g, ('rapina completata su %s: %d banconote a %d persone'):format(
        bersaglio.nome, bottino, #presenti))

    rispondi(true, ('%d banconote non tracciate, divise fra %d persone. Vanno ripulite prima di poterle versare.'):format(
        bottino, #presenti))
end)

--- Interruzione forzata da parte delle forze dell'ordine.
AUREA.Callback.Registra('rap:interrompi', function(src, rispondi, idBersaglio)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio then return rispondi(false) end

    local l = AUREA.GetLavoro(g.lavoro.nome)
    if l.tipo ~= 'forze_ordine' then return rispondi(false, 'Non sei autorizzato.') end

    local rapina = inCorso[idBersaglio]
    if not rapina then return rispondi(false, 'Nessun colpo in corso qui.') end

    local bersaglio = RAP.GetBersaglio(idBersaglio)
    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - bersaglio.coord) > 15.0 then return rispondi(false, 'Sei troppo lontano.') end

    inCorso[idBersaglio] = nil
    raffreddamenti[idBersaglio] = os.time() + RAP.Livelli[bersaglio.livello].raffreddamentoMinuti * 60

    for _, citizenid in ipairs(rapina.partecipanti) do
        local p = AUREA.GetPlayerByCitizenId(citizenid)
        if p then
            TriggerClientEvent('rap:interrotta', p.source, idBersaglio)
            TriggerClientEvent('aurea:ui:notifica', p.source, {
                tipo = 'errore', icona = '🚔', durata = 12000,
                titolo = 'Colpo sventato',
                testo = 'Le forze dell\'ordine hanno interrotto l\'azione.',
            })
        end
    end

    AUREA.Log('giustizia', 'avviso', g, ('ha sventato la rapina a %s'):format(bersaglio.nome))
    rispondi(true, ('Colpo sventato a %s.'):format(bersaglio.nome))
end)

--- Stato dei bersagli, per il client.
AUREA.Callback.Registra('rap:stato', function(src, rispondi)
    local agenti = agentiInServizio()
    local stato = {}

    for _, b in ipairs(RAP.Bersagli) do
        local livello = RAP.Livelli[b.livello]
        local riapertura = raffreddamenti[b.id]
        stato[b.id] = {
            disponibile = not inCorso[b.id] and (not riapertura or os.time() >= riapertura)
                and agenti >= livello.agentiRichiesti,
            inCorso = inCorso[b.id] ~= nil,
            minutiAttesa = riapertura and math.max(0, math.ceil((riapertura - os.time()) / 60)) or 0,
            agentiRichiesti = livello.agentiRichiesti,
        }
    end

    rispondi({ bersagli = stato, agenti = agenti })
end)

-- ---------------------------------------------------------------------------
--  Portavalori
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(120000)
    while true do
        if not portavaloriAttivo and agentiInServizio() >= RAP.Livelli.portavalori.agentiRichiesti then
            local partenza = RAP.Portavalori.partenze[math.random(#RAP.Portavalori.partenze)]
            portavaloriAttivo = {
                coord = partenza,
                comparso = os.time(),
                svuotato = false,
            }

            TriggerClientEvent('rap:portavaloriComparso', -1, {
                x = partenza.x, y = partenza.y, z = partenza.z, w = partenza.w,
            })

            SetTimeout(RAP.Portavalori.minutiPermanenza * 60000, function()
                portavaloriAttivo = nil
                TriggerClientEvent('rap:portavaloriSparito', -1)
            end)
        end

        Wait(RAP.Portavalori.minutiFraApparizioni * 60000)
    end
end)

AUREA.Callback.Registra('rap:portavalori', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not portavaloriAttivo or portavaloriAttivo.svuotato then
        return rispondi(false, 'Il furgone è già stato svuotato o non è più in circolazione.')
    end

    local livello = RAP.Livelli.portavalori
    if not exports.aurea_inventory:Ha(g.citizenid, livello.attrezzo, 1) then
        return rispondi(false, 'Ti serve un grimaldello.')
    end

    local agenti = agentiInServizio()
    if agenti < livello.agentiRichiesti then
        return rispondi(false, ('Servono almeno %d agenti in servizio: ce ne sono %d.'):format(
            livello.agentiRichiesti, agenti))
    end

    portavaloriAttivo.svuotato = true

    local coord = GetEntityCoords(GetPlayerPed(src))
    TriggerEvent('aurea:112:allerta', 'rapina',
        { x = coord.x, y = coord.y, z = coord.z },
        'Assalto a furgone portavalori in corso.', 'allarme automatico del mezzo')

    local bottino = math.random(livello.bottinoMin, livello.bottinoMax)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    inventario:Aggiungi(RAP.Regole.provento, bottino)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    exports.ita_giustizia:ApriFascicolo(g.citizenid, livello.reato,
        'accertamento', 'Assalto a furgone portavalori')

    if g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, livello.calore, 'assalto portavalori')
    end

    TriggerClientEvent('rap:portavaloriSparito', -1)
    AUREA.Log('giustizia', 'allarme', g, ('assalto al portavalori: %d banconote'):format(bottino))

    rispondi(true, ('%d banconote non tracciate.'):format(bottino))
end)

AUREA.Callback.Registra('rap:portavaloriDove', function(src, rispondi)
    if not portavaloriAttivo or portavaloriAttivo.svuotato then return rispondi(nil) end
    rispondi({
        x = portavaloriAttivo.coord.x,
        y = portavaloriAttivo.coord.y,
        z = portavaloriAttivo.coord.z,
        w = portavaloriAttivo.coord.w,
    })
end)

-- ---------------------------------------------------------------------------
--  Pulizia delle rapine abbandonate
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        for id, rapina in pairs(inCorso) do
            local bersaglio = RAP.GetBersaglio(id)
            local livello = bersaglio and RAP.Livelli[bersaglio.livello]
            if livello and (os.time() - rapina.avviata) > (livello.durata / 1000) + 300 then
                inCorso[id] = nil
                raffreddamenti[id] = os.time() + livello.raffreddamentoMinuti * 60
                TriggerClientEvent('rap:interrotta', -1, id)
            end
        end
    end
end)
