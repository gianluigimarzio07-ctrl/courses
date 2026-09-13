--[[
    AUREA · Protezione Civile (server)

    L'emergenza vive qui: i punti da lavorare, chi ha fatto cosa, il
    cronometro. Il client vede dei marker e chiede di lavorarci sopra.

    Un dettaglio che conta: i punti si generano attorno al centro con
    math.random del SERVER. Non sono in nessun file, non si possono
    prevedere leggendo la configurazione, e due alluvioni sulla stessa
    zona non hanno gli stessi argini da tenere.
]]

local U = AUREA.Util

local allerta = 'verde'
local allertaDaSindaco = nil    -- se il Sindaco l'ha forzata, il meteo non la abbassa
local coc = false
local emergenza = nil           -- { id, tipo, zona, centro, compiti, aperta, partecipanti }
local ultimaChiusura = 0

-- ---------------------------------------------------------------------------
--  Volontari
-- ---------------------------------------------------------------------------
-- L'elenco sta in memoria: `diramazione` gira a ogni cambio di allerta e
-- il badge del telefono a ogni apertura, e non vale una query a testa.
local iscritti = {}     -- [citizenid] = { interventi }

CreateThread(function()
    Wait(3000)
    local righe = MySQL.query.await('SELECT citizenid, interventi FROM pc_volontari') or {}
    for _, r in ipairs(righe) do
        iscritti[r.citizenid] = { interventi = r.interventi }
    end
    print(('[AUREA] protezione civile: %d volontari iscritti'):format(#righe))
end)

local function volontario(citizenid)
    return iscritti[citizenid]
end

local function volontariAttivi()
    local fuori = {}
    for _, g in pairs(AUREA.Giocatori) do
        if iscritti[g.citizenid] then fuori[#fuori + 1] = g end
    end
    return fuori
end

--- Notifica i volontari e gli enti che devono comunque sapere.
local function diramazione(notifica)
    for _, g in ipairs(volontariAttivi()) do
        TriggerClientEvent('aurea:ui:notifica', g.source, notifica)
    end
    for _, ente in ipairs(PC.Comando.entiInformati) do
        exports.aurea_ui:NotificaLavoro(ente, notifica, true)
    end
    exports.aurea_ui:NotificaLavoro(PC.Comando.lavoro, notifica, false)
end

-- ---------------------------------------------------------------------------
--  Allerta e COC
-- ---------------------------------------------------------------------------
local function pubblicaStato()
    TriggerClientEvent('pc:sincronizza', -1, {
        allerta = allerta,
        coc = coc,
        emergenza = emergenza and {
            id = emergenza.id, tipo = emergenza.tipo, zona = emergenza.zona,
            centro = emergenza.centro, compiti = emergenza.compiti,
            scade = emergenza.scade,
        } or nil,
    })
end

local function impostaAllerta(livello, daSindaco)
    local l = PC.GetLivello(livello)
    if l.id == allerta then return end

    allerta = l.id
    if daSindaco then allertaDaSindaco = l.id end

    if l.apreCoc and not coc then
        coc = true
        diramazione({
            tipo = 'avviso', icona = '🚨', durata = 20000,
            titolo = ('COC attivato — %s'):format(l.nome),
            testo = 'Il Centro Operativo Comunale è aperto. I volontari del gruppo comunale sono attivati.',
        })
    elseif not l.apreCoc and coc and not emergenza then
        coc = false
        diramazione({
            tipo = 'info', icona = '🚨', durata = 14000,
            titolo = 'COC chiuso', testo = 'Cessata l\'allerta. Il centro operativo torna in sonno.',
        })
    end

    pubblicaStato()
    AUREA.Log('soccorso', 'info', nil, ('Allerta %s%s'):format(l.id, daSindaco and ' (dichiarata dal Sindaco)' or ''))
end

--- Il maltempo alza l'allerta da solo. Non la abbassa mai sotto quella
--- dichiarata dal Sindaco: quella la revoca chi l'ha messa.
CreateThread(function()
    Wait(45000)
    while true do
        Wait(120000)

        local ok, meteo = pcall(function() return exports.ita_ambiente:MeteoCorrente() end)
        if ok and meteo then
            local proposto = PC.AllertaDaMeteo[meteo] or 'verde'
            if allertaDaSindaco and PC.AlmenoAllerta(allertaDaSindaco, proposto) then
                proposto = allertaDaSindaco
            end
            if proposto ~= allerta then impostaAllerta(proposto, false) end
        end
    end
end)

--- Anche l'evento "allerta meteo" di ita_ambiente conta come tale.
AddEventHandler('aurea:ambiente:evento', function(id)
    if id == 'allerta_meteo' and not PC.AlmenoAllerta(allerta, 'arancione') then
        impostaAllerta('arancione', false)
    end
end)

-- ---------------------------------------------------------------------------
--  Apertura di un'emergenza
-- ---------------------------------------------------------------------------
local function generaCompiti(e, centro)
    local compiti, n = {}, 0
    for tipo, quanti in pairs(e.compiti) do
        for _ = 1, quanti do
            n = n + 1
            -- Attorno al centro, mai troppo vicini fra loro: un'emergenza
            -- che si risolve senza spostarsi non è un'emergenza.
            local angolo = math.random() * math.pi * 2
            local distanza = e.raggio * (0.35 + math.random() * 0.65)
            compiti[n] = {
                n = n, tipo = tipo, fatto = false,
                x = centro.x + math.cos(angolo) * distanza,
                y = centro.y + math.sin(angolo) * distanza,
                z = centro.z,
            }
        end
    end
    return compiti
end

local function apriEmergenza(tipoId, zonaScelta)
    if emergenza then return nil, 'C\'è già un\'emergenza in corso.' end

    local e = PC.GetEmergenza(tipoId)
    if not e then return nil, 'Tipo di emergenza sconosciuto.' end
    if not PC.AlmenoAllerta(allerta, e.allertaMinima) then
        return nil, ('Serve almeno l\'%s.'):format(PC.GetLivello(e.allertaMinima).nome:lower())
    end

    local zona = zonaScelta or e.zone[math.random(#e.zone)]
    local compiti = generaCompiti(e, zona.coord)

    local id = MySQL.insert.await([[
        INSERT INTO pc_emergenze (tipo, zona, compiti_totali, allerta)
        VALUES (?, ?, ?, ?)
    ]], { tipoId, zona.nome, #compiti, allerta })

    emergenza = {
        id = id, tipo = tipoId, zona = zona.nome,
        centro = { x = zona.coord.x, y = zona.coord.y, z = zona.coord.z },
        compiti = compiti,
        aperta = os.time(),
        scade = os.time() + e.minutiMassimi * 60,
        partecipanti = {},
        trovato = e.premioRitrovamento and math.random(#compiti) or nil,
    }

    if not coc then
        coc = true
        diramazione({
            tipo = 'avviso', icona = '🚨', durata = 15000,
            titolo = 'COC attivato',
            testo = 'Centro Operativo Comunale aperto per l\'emergenza in corso.',
        })
    end

    -- L'incendio boschivo è lo stesso fatto visto da due moduli: qui i
    -- volontari aprono la fascia tagliafuoco, di là i vigili del fuoco
    -- spengono. Non è una simulazione parallela: è un incendio solo.
    if e.accendeIncendio then
        pcall(function()
            exports.ita_vigilfuoco:AccendiIncendio(e.accendeIncendio, zona.coord, zona.nome, nil)
        end)
    end

    diramazione({
        tipo = 'errore', icona = e.icona, durata = 25000,
        titolo = ('EMERGENZA — %s'):format(e.nome),
        testo = ('%s\n%s\n%d punti da lavorare, %d minuti. Apri /pc per la mappa.')
            :format(zona.nome, e.descrizione, #compiti, e.minutiMassimi),
    })

    pubblicaStato()
    AUREA.Log('soccorso', 'avviso', nil, ('Emergenza %s aperta su %s (%d compiti)')
        :format(tipoId, zona.nome, #compiti))

    return id
end

-- ---------------------------------------------------------------------------
--  Chiusura
-- ---------------------------------------------------------------------------
local function chiudiEmergenza(riuscita)
    if not emergenza then return end

    local e = PC.GetEmergenza(emergenza.tipo)
    local squadra = {}
    for citizenid, fatti in pairs(emergenza.partecipanti) do
        squadra[#squadra + 1] = { citizenid = citizenid, fatti = fatti }
    end

    MySQL.update('UPDATE pc_emergenze SET esito = ?, chiusa_il = NOW(), partecipanti = ? WHERE id = ?',
        { riuscita and 'risolta' or 'fallita', #squadra, emergenza.id })

    if riuscita and #squadra > 0 then
        -- Il bonus si divide, ma chi ha lavorato di più prende di più
        local totaleFatti = 0
        for _, s in ipairs(squadra) do totaleFatti = totaleFatti + s.fatti end

        for _, s in ipairs(squadra) do
            local quota = math.floor(e.bonusChiusura * (s.fatti / math.max(1, totaleFatti)))
            AUREA.Denaro.AggiungiOffline(s.citizenid, 'banca', quota, 'rimborso protezione civile')
            TriggerEvent('aurea:fisco:erogazione', 'protezione_civile', quota, s.citizenid)
            MySQL.update('UPDATE pc_volontari SET interventi = interventi + 1 WHERE citizenid = ?', { s.citizenid })
            if iscritti[s.citizenid] then
                iscritti[s.citizenid].interventi = iscritti[s.citizenid].interventi + 1
            end

            local g = AUREA.GetPlayerByCitizenId(s.citizenid)
            if g then
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'successo', icona = '🚨', durata = 16000,
                    titolo = 'Emergenza risolta',
                    testo = ('%d compiti su %d. Rimborso di chiusura: %s.')
                        :format(s.fatti, #emergenza.compiti, U.Euro(quota)),
                })
            end
        end
    elseif not riuscita then
        if (e.dannoSeFallita or 0) > 0 then
            TriggerEvent('aurea:fisco:erogazione', 'danni_emergenza', e.dannoSeFallita, nil)
            diramazione({
                tipo = 'errore', icona = '🚨', durata = 22000,
                titolo = ('%s non contenuta'):format(e.nome),
                testo = ('%s. I danni ammontano a %s, a carico del bilancio comunale.')
                    :format(emergenza.zona, U.Euro(e.dannoSeFallita)),
            })
        end
    end

    AUREA.Log('soccorso', riuscita and 'info' or 'avviso', nil,
        ('Emergenza %s su %s: %s, %d partecipanti')
            :format(emergenza.tipo, emergenza.zona, riuscita and 'risolta' or 'fallita', #squadra))

    emergenza = nil
    ultimaChiusura = os.time()

    if not PC.GetLivello(allerta).apreCoc then
        coc = false
    end

    pubblicaStato()
end

--- Il cronometro. Un'emergenza che non si chiude in tempo è un'emergenza
--- persa: è quello che la rende una cosa da fare adesso.
CreateThread(function()
    while true do
        Wait(20000)
        if emergenza and os.time() >= emergenza.scade then
            chiudiEmergenza(false)
        end
    end
end)

--- E ogni tanto, a COC aperto, ne nasce una da sola.
CreateThread(function()
    Wait(120000)
    while true do
        Wait(PC.Rimborsi.controlloMinuti * 60000)

        if not emergenza and coc
            and os.time() - ultimaChiusura >= PC.Rimborsi.intervalloMinimoMinuti * 60
            and math.random() < PC.Rimborsi.probabilitaAutomatica then

            local possibili = PC.EmergenzePossibili(allerta)
            if #possibili > 0 then
                apriEmergenza(possibili[math.random(#possibili)])
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Iscrizione al gruppo comunale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pc:iscriviti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if volontario(g.citizenid) then
        return rispondi(false, 'Sei già iscritto al gruppo comunale.')
    end

    MySQL.insert.await('INSERT INTO pc_volontari (citizenid, nome) VALUES (?, ?)',
        { g.citizenid, g:NomeCompleto() })
    iscritti[g.citizenid] = { interventi = 0 }

    exports.aurea_inventory:Aggiungi(g.citizenid, PC.Volontariato.dpi, 1)

    AUREA.Log('soccorso', 'info', g, 'si è iscritto al gruppo comunale di protezione civile')
    rispondi(true, 'Iscritto al gruppo comunale. Ti hanno dato il gilet: senza, in emergenza non si entra.')
end)

-- ---------------------------------------------------------------------------
--  Dotazione
--
--  I sacchi di sabbia non se li compra il volontario: glieli dà il centro
--  operativo. È la differenza fra un sistema di protezione civile e un
--  hobby costoso.
-- ---------------------------------------------------------------------------
local ultimoRitiro = {}     -- [citizenid] = os.time()

AUREA.Callback.Registra('pc:dotazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not volontario(g.citizenid) then
        return rispondi(false, 'La dotazione è per i volontari iscritti.')
    end
    if not emergenza then
        return rispondi(false, 'Il magazzino si apre quando c\'è uno scenario in corso.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - PC.Sede.coord) > 6.0 then
        return rispondi(false, 'Devi essere alla sede del gruppo comunale.')
    end

    local attesa = PC.Volontariato.attesaDotazioneMinuti * 60
    local passato = os.time() - (ultimoRitiro[g.citizenid] or 0)
    if passato < attesa then
        return rispondi(false, ('Hai già ritirato. Riprova fra %d minuti.')
            :format(math.ceil((attesa - passato) / 60)))
    end

    local dato = {}
    for item, quanti in pairs(PC.Volontariato.dotazione) do
        if exports.aurea_inventory:Aggiungi(g.citizenid, item, quanti) then
            dato[#dato + 1] = ('%d × %s'):format(quanti, AUREA.Item[item].etichetta)
        end
    end
    if not exports.aurea_inventory:Ha(g.citizenid, PC.Volontariato.dpi, 1) then
        exports.aurea_inventory:Aggiungi(g.citizenid, PC.Volontariato.dpi, 1)
        dato[#dato + 1] = AUREA.Item[PC.Volontariato.dpi].etichetta
    end

    if #dato == 0 then
        return rispondi(false, 'Non hai spazio addosso per la dotazione.')
    end

    ultimoRitiro[g.citizenid] = os.time()
    rispondi(true, ('Dotazione ritirata: %s.'):format(table.concat(dato, ', ')))
end)

-- ---------------------------------------------------------------------------
--  Lo stato, per il pannello
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pc:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local v = volontario(g.citizenid)
    local e = emergenza and PC.GetEmergenza(emergenza.tipo)

    rispondi({
        allerta = allerta,
        nomeAllerta = PC.GetLivello(allerta).nome,
        coc = coc,
        volontario = v ~= nil,
        interventi = v and v.interventi or 0,
        emergenza = emergenza and {
            tipo = emergenza.tipo, nome = e.nome, icona = e.icona,
            descrizione = e.descrizione, zona = emergenza.zona,
            centro = emergenza.centro,
            compiti = emergenza.compiti,
            restanti = (function()
                local n = 0
                for _, c in ipairs(emergenza.compiti) do if not c.fatto then n = n + 1 end end
                return n
            end)(),
            totali = #emergenza.compiti,
            minutiResidui = math.max(0, math.ceil((emergenza.scade - os.time()) / 60)),
            miei = emergenza.partecipanti[g.citizenid] or 0,
        } or nil,
    })
end)

-- ---------------------------------------------------------------------------
--  Esecuzione di un compito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pc:compito', function(src, rispondi, numero)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not emergenza then return rispondi(false, 'Non c\'è nessuna emergenza in corso.') end

    if not volontario(g.citizenid) then
        return rispondi(false, 'Non sei iscritto al gruppo comunale di protezione civile.')
    end
    if not exports.aurea_inventory:Ha(g.citizenid, PC.Volontariato.dpi, 1) then
        return rispondi(false, 'Senza gilet ad alta visibilità non si entra in uno scenario.')
    end

    local c = emergenza.compiti[tonumber(numero) or 0]
    if not c then return rispondi(false, 'Punto non riconosciuto.') end
    if c.fatto then return rispondi(false, 'Quel punto è già stato lavorato.') end

    -- La distanza la misura il server: un client modificato non lavora
    -- da casa.
    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(c.x, c.y, c.z)) > 8.0 then
        return rispondi(false, 'Sei troppo lontano dal punto.')
    end

    local def = PC.Compiti[c.tipo]
    for item, quanti in pairs(def.materiali) do
        if not exports.aurea_inventory:Ha(g.citizenid, item, quanti) then
            return rispondi(false, ('Servono %d × %s.'):format(quanti, AUREA.Item[item].etichetta))
        end
    end
    for item, quanti in pairs(def.materiali) do
        exports.aurea_inventory:Rimuovi(g.citizenid, item, quanti)
    end

    c.fatto = true
    c.da = g:NomeCompleto()
    emergenza.partecipanti[g.citizenid] = (emergenza.partecipanti[g.citizenid] or 0) + 1

    AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', def.rimborso, 'rimborso protezione civile')
    TriggerEvent('aurea:fisco:erogazione', 'protezione_civile', def.rimborso, g.citizenid)

    local e = PC.GetEmergenza(emergenza.tipo)
    local messaggio = ('%s. Rimborso %s.'):format(def.etichetta, U.Euro(def.rimborso))

    -- Il disperso
    if emergenza.trovato == c.n then
        emergenza.trovato = nil
        AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', e.premioRitrovamento, 'ritrovamento del disperso')
        TriggerEvent('aurea:fisco:erogazione', 'protezione_civile', e.premioRitrovamento, g.citizenid)

        TriggerEvent('aurea:112:allerta', 'trauma', { x = c.x, y = c.y, z = c.z },
            'Persona dispersa ritrovata dai volontari, in ipotermia e disidratata.', emergenza.zona)

        diramazione({
            tipo = 'successo', icona = '🔦', durata = 22000,
            titolo = 'Disperso ritrovato',
            testo = ('%s ha individuato la persona su %s. Il 118 è in arrivo.')
                :format(g:NomeCompleto(), emergenza.zona),
        })

        messaggio = ('L\'HAI TROVATO. %s di riconoscimento, e il 118 sta arrivando.')
            :format(U.Euro(e.premioRitrovamento))
    end

    MySQL.update('UPDATE pc_emergenze SET compiti_fatti = compiti_fatti + 1 WHERE id = ?', { emergenza.id })
    pubblicaStato()

    -- Finiti i punti, l'emergenza è chiusa
    local restanti = 0
    for _, x in ipairs(emergenza.compiti) do if not x.fatto then restanti = restanti + 1 end end
    if restanti == 0 then
        rispondi(true, messaggio)
        return chiudiEmergenza(true)
    end

    rispondi(true, ('%s Restano %d punti, %d minuti.')
        :format(messaggio, restanti, math.max(0, math.ceil((emergenza.scade - os.time()) / 60))))
end)

-- ---------------------------------------------------------------------------
--  Comandi del Sindaco e degli uffici
-- ---------------------------------------------------------------------------
local function inComando(g)
    return g and g.lavoro.nome == PC.Comando.lavoro
end

AUREA.Comando('allerta', 'utente', 'Dichiara o revoca lo stato di allerta', {
    { name = 'livello', help = 'verde, gialla, arancione, rossa' },
}, function(src, args, _, g)
    if not inComando(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚨', titolo = 'Non autorizzato',
            testo = 'L\'allerta la dichiara il Comune.',
        })
    end

    local livello = tostring(args[1] or ''):lower()
    local l, i = PC.GetLivello(livello)
    if l.id ~= livello then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚨', titolo = 'Livello non valido',
            testo = 'Usa: verde, gialla, arancione, rossa.',
        })
    end

    if livello == 'verde' then allertaDaSindaco = nil end
    impostaAllerta(livello, livello ~= 'verde')

    diramazione({
        tipo = i >= 3 and 'errore' or 'info', icona = '🚨', durata = 20000,
        titolo = l.nome,
        testo = ('Dichiarata dal Comune. %s'):format(
            l.apreCoc and 'Il COC è aperto e i volontari sono attivati.'
                      or 'Nessuna attivazione operativa.'),
    })

    AUREA.Log('soccorso', 'info', g, ('ha dichiarato %s'):format(l.nome))
end)

AUREA.Comando('emergenza', 'utente', 'Apre uno scenario di emergenza (COC)', {
    { name = 'tipo', help = 'alluvione, incendio_boschivo, ricerca_dispersi' },
}, function(src, args, _, g)
    if not inComando(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚨', titolo = 'Non autorizzato',
            testo = 'Gli scenari li apre il Centro Operativo Comunale.',
        })
    end

    local id, errore = apriEmergenza(tostring(args[1] or ''))
    if not id then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚨', titolo = 'Non aperta',
            testo = errore or 'Tipo non valido. Usa: alluvione, incendio_boschivo, ricerca_dispersi.',
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Export
-- ---------------------------------------------------------------------------
exports('AllertaCorrente', function() return allerta, coc end)

exports('EmergenzaAttiva', function()
    if not emergenza then return nil end
    return { id = emergenza.id, tipo = emergenza.tipo, zona = emergenza.zona }
end)

--- Un altro modulo può aprire uno scenario: è la porta da cui in futuro
--- passeranno terremoti, frane e quello che verrà.
exports('ApriEmergenza', apriEmergenza)

-- ---------------------------------------------------------------------------
--  App del telefono
--
--  Sta in home per tutti, perché l'allerta riguarda tutti — non solo chi
--  è iscritto. È il senso del sistema di allertamento.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'protezionecivile',
    nome = 'Allerta',
    icona = '🚨',
    colore = 'linear-gradient(150deg,#d1732c,#7a3a10)',
    ordine = 145,

    badge = function()
        return emergenza and 1 or 0
    end,

    schermata = function(g)
        local l = PC.GetLivello(allerta)
        local voci = {}

        if emergenza then
            local e = PC.GetEmergenza(emergenza.tipo)
            local restanti = 0
            for _, c in ipairs(emergenza.compiti) do if not c.fatto then restanti = restanti + 1 end end

            voci[#voci + 1] = {
                icona = e.icona, titolo = e.nome,
                sottotitolo = ('%s · %s'):format(emergenza.zona, e.descrizione),
                valore = ('%d/%d'):format(#emergenza.compiti - restanti, #emergenza.compiti),
                tono = 'rosso', inerte = true,
            }
            voci[#voci + 1] = {
                icona = '⏱', titolo = 'Tempo residuo',
                valore = ('%d min'):format(math.max(0, math.ceil((emergenza.scade - os.time()) / 60))),
                sottotitolo = 'Scaduto il termine, i danni li paga il Comune', inerte = true,
            }
        else
            voci[#voci + 1] = { icona = '☑', titolo = 'Nessuno scenario in corso', inerte = true }
        end

        local v = volontario(g.citizenid)
        voci[#voci + 1] = {
            icona = v and '🦺' or '👤',
            titolo = v and 'Sei nel gruppo comunale' or 'Non sei volontario',
            sottotitolo = v and ('%d interventi conclusi'):format(v.interventi or 0)
                            or 'Ci si iscrive alla sede del gruppo comunale',
            tono = v and 'verde' or nil, inerte = true,
        }

        return {
            tipo = 'saldo',
            etichetta = 'Stato di allerta',
            valore = l.nome,
            nota = coc and 'Centro Operativo Comunale APERTO' or 'Centro operativo in sonno',
            voci = voci,
        }
    end,
})

-- Chi entra deve sapere subito com'è messa la giornata
AddEventHandler('aurea:giocatore:caricato', function(src)
    CreateThread(function()
        Wait(6000)
        TriggerClientEvent('pc:sincronizza', src, {
            allerta = allerta, coc = coc,
            emergenza = emergenza and {
                id = emergenza.id, tipo = emergenza.tipo, zona = emergenza.zona,
                centro = emergenza.centro, compiti = emergenza.compiti, scade = emergenza.scade,
            } or nil,
        })
    end)
end)

print('[AUREA] protezione civile: sistema di allertamento attivo')
