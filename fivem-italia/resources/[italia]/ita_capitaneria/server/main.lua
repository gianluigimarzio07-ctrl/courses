--[[
    AUREA · Capitaneria di Porto (server)

    Il server tiene tre registri e nient'altro: le ordinanze in vigore, le
    ricerche aperte con i loro settori, i fermi amministrativi.

    La regola che vale per tutti e tre è la stessa che vale ovunque in
    AUREA: il client racconta dov'è, il server decide che cosa significa.
    Un client che dice «sono fuori dall'area interdetta» viene creduto
    sulla posizione — non c'è modo di fare altrimenti — ma la posizione la
    confronta il server con le ordinanze che conosce lui, e il verbale lo
    scrive lui.
]]

local U = AUREA.Util

--- Il testo che arriva dal client non si scrive mai com'è: si tronca e si
--- toglie tutto quello che manderebbe a capo un verbale.
local function pulisci(s, massimo)
    return (tostring(s or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, massimo or 140)
end

local ordinanze = {}    -- [id] = { tipo, centro, raggio, motivo, dal, scade, ufficiale, nome }
local ricerche  = {}    -- [id] = { centro, settori, battuti, aperta, ... }
local fermi     = {}    -- [targa] = { motivo, dal, id }

local ultimoVerbale  = {}   -- ['citizenid|idOrdinanza'] = timestamp
local ultimoControllo = {}  -- [targa] = timestamp

-- ---------------------------------------------------------------------------
--  Chi è chi
-- ---------------------------------------------------------------------------
local function militare(g, permesso)
    return g and g.lavoro.nome == CAP.Lavoro and g.lavoro.servizio
       and (permesso == nil or g:HaPermessoLavoro(permesso))
end

--- Le altre forze in mare esistono, e alcune cose le possono fare: la
--- finanza fa polizia economica anche a galla, i carabinieri fanno
--- polizia giudiziaria ovunque. Quello che NON possono fare è firmare
--- un'ordinanza, perché quella è potestà del Comandante del porto.
local function inDivisaInMare(g)
    if not g or not g.lavoro.servizio then return false end
    local l = g.lavoro.nome
    return l == CAP.Lavoro or l == 'carabinieri' or l == 'guardia_finanza'
end

-- ---------------------------------------------------------------------------
--  Le ordinanze
-- ---------------------------------------------------------------------------

--- Le ordinanze che coprono un punto. Restituisce una lista, perché
--- niente vieta che un divieto di pesca e una limitazione di velocità
--- insistano sullo stesso tratto di mare.
local function ordinanzeSu(coord)
    local out = {}
    for id, o in pairs(ordinanze) do
        if CAP.DistanzaPiana(coord, o.centro) <= o.raggio then
            o.id = id
            out[#out + 1] = o
        end
    end
    return out
end

exports('OrdinanzeSu', function(coord)
    local out = {}
    for _, o in ipairs(ordinanzeSu(coord)) do
        out[#out + 1] = { id = o.id, tipo = o.tipo, motivo = o.motivo, raggio = o.raggio }
    end
    return out
end)

--- Lo chiedono ita_pesca e chi altro voglia sapere se in un punto si può
--- fare una certa cosa. `attivita` è uno dei `vieta` delle ordinanze.
exports('Consentito', function(coord, attivita)
    for _, o in ipairs(ordinanzeSu(coord)) do
        local d = CAP.GetOrdinanza(o.tipo)
        if d and d.vieta == attivita then
            return false, d.etichetta, o.motivo
        end
    end
    return true
end)

local function pacchettoOrdinanze()
    local out = {}
    for id, o in pairs(ordinanze) do
        local d = CAP.GetOrdinanza(o.tipo)
        out[#out + 1] = {
            id = id, tipo = o.tipo,
            etichetta = d and d.etichetta or o.tipo,
            icona = d and d.icona or '⚓',
            coloreBlip = d and d.coloreBlip or 1,
            centro = o.centro, raggio = o.raggio,
            motivo = o.motivo, ufficiale = o.nome,
            minutiResidui = math.max(0, math.floor((o.scade - os.time()) / 60)),
        }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

--- Tutti devono saperlo, non solo chi è in mare: un'ordinanza è pubblica.
local function diffondiOrdinanze()
    TriggerClientEvent('cap:ordinanze', -1, pacchettoOrdinanze())
end

local function revocaOrdinanza(id, motivo)
    local o = ordinanze[id]
    if not o then return false end

    MySQL.update.await(
        'UPDATE capitaneria_ordinanze SET revocata = 1, revocata_il = NOW() WHERE id = ?', { id })
    ordinanze[id] = nil
    diffondiOrdinanze()

    local d = CAP.GetOrdinanza(o.tipo)
    exports.aurea_ui:NotificaTutti({
        tipo = 'info', icona = '⚓', durata = 12000,
        titolo = 'Ordinanza revocata',
        testo = ('%s — %s'):format(d and d.etichetta or o.tipo,
                                   motivo or 'il provvedimento non è più in vigore.'),
    })
    AUREA.Log('staff', 'info', nil, ('revocata l\'ordinanza #%d'):format(id))
    return true
end

AUREA.Callback.Registra('cap:emetti', function(src, rispondi, tipo, raggio, motivo)
    local g = AUREA.GetPlayer(src)
    if not militare(g, 'ordinanza') then
        return rispondi(false, 'L\'ordinanza la firma un ufficiale della Capitaneria in servizio.')
    end

    local d = CAP.GetOrdinanza(tipo)
    if not d then return rispondi(false, 'Tipo di ordinanza non previsto.') end

    raggio = tonumber(raggio) or 0
    local ammesso = false
    for _, r in ipairs(CAP.Ordinanza.raggi) do
        if r == raggio then ammesso = true break end
    end
    if not ammesso then return rispondi(false, 'Raggio non ammesso.') end

    motivo = pulisci(motivo, 140)
    if #motivo < 4 then return rispondi(false, 'Serve una motivazione: un\'ordinanza senza motivo non è un atto.') end

    local quante = 0
    for _ in pairs(ordinanze) do quante = quante + 1 end
    if quante >= CAP.Ordinanza.massimoAttive then
        return rispondi(false, 'Ci sono già troppe ordinanze in vigore: revocane una.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local scade = os.time() + CAP.Ordinanza.minutiDurata * 60

    local id = MySQL.insert.await([[
        INSERT INTO capitaneria_ordinanze
            (tipo, centro_x, centro_y, raggio, motivo, ufficiale, nome_ufficiale, scade_il)
        VALUES (?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], { tipo, coord.x, coord.y, raggio, motivo, g.citizenid, g:NomeCompleto(), scade })

    ordinanze[id] = {
        tipo = tipo, centro = vector3(coord.x, coord.y, 0.0), raggio = raggio,
        motivo = motivo, dal = os.time(), scade = scade,
        ufficiale = g.citizenid, nome = g:NomeCompleto(),
    }
    diffondiOrdinanze()

    exports.aurea_ui:NotificaTutti({
        tipo = 'avviso', icona = d.icona, durata = 18000,
        titolo = d.etichetta,
        testo = ('%s\n%s — raggio %d metri, per %d minuti.')
            :format(motivo, d.descrizione, raggio, CAP.Ordinanza.minutiDurata),
    })

    AUREA.Log('staff', 'info', g, ('ordinanza %s su raggio %dm: %s'):format(tipo, raggio, motivo))
    rispondi(true, ('Ordinanza emessa. Vale %d minuti su %d metri.')
        :format(CAP.Ordinanza.minutiDurata, raggio))
end)

AUREA.Callback.Registra('cap:revoca', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not militare(g, 'ordinanza') then
        return rispondi(false, 'Serve un ufficiale in servizio.')
    end
    id = tonumber(id)
    if not id or not ordinanze[id] then return rispondi(false, 'Ordinanza non trovata.') end

    revocaOrdinanza(id, ('revocata da %s.'):format(g:NomeCompleto()))
    rispondi(true, 'Ordinanza revocata.')
end)

AUREA.Callback.Registra('cap:ordinanzeAttive', function(src, rispondi)
    rispondi(pacchettoOrdinanze())
end)

-- ---------------------------------------------------------------------------
--  La violazione di un'ordinanza
--
--  Il client segnala che sta facendo una certa cosa in un certo punto.
--  Il server guarda se lì c'è un'ordinanza che la vieta, e se sì scrive
--  il verbale — con il raffreddamento, perché un'ordinanza non è una
--  macchina per stampare multe.
-- ---------------------------------------------------------------------------
RegisterNetEvent('cap:violazione', function(attivita, targa)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end
    -- Chi è in servizio nelle forze in mare ci entra per lavoro
    if inDivisaInMare(g) then return end

    local coord = GetEntityCoords(GetPlayerPed(src))

    for _, o in ipairs(ordinanzeSu(coord)) do
        local d = CAP.GetOrdinanza(o.tipo)
        if d and d.vieta == attivita then
            local chiave = ('%s|%d'):format(g.citizenid, o.id)
            if (ultimoVerbale[chiave] or 0) + CAP.Ordinanza.secondiRaffreddamento > os.time() then
                return
            end
            ultimoVerbale[chiave] = os.time()

            exports.ita_codicestrada:EmettiVerbale({
                citizenid = g.citizenid,
                targa = targa and tostring(targa):upper() or nil,
                articolo = d.articolo,
                descrizione = ('%s — %s'):format(d.etichetta, o.motivo),
                importo = d.sanzione, punti = 0,
                origine = 'agente',
                agente = 'Capitaneria di Porto',
                luogo = 'specchio acqueo interdetto',
            })

            exports.aurea_ui:NotificaEnte(CAP.Ente, {
                tipo = 'avviso', icona = d.icona, durata = 14000,
                titolo = 'Ordinanza violata',
                testo = ('%s è entrato in zona %s.'):format(g:NomeCompleto(), d.etichetta:lower()),
            }, true)
            return
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il controllo di un'unità
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cap:controlla', function(src, rispondi, targa, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not inDivisaInMare(g) then
        return rispondi(false, 'Serve essere in servizio in una forza abilitata ai controlli in mare.')
    end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    if #targa < 2 then return rispondi(false, 'Targa non leggibile.') end

    if (ultimoControllo[targa] or 0) + CAP.Controllo.minutiRaffreddamento * 60 > os.time() then
        return rispondi(false, 'Questa unità è stata controllata da poco.')
    end

    local bersaglio = AUREA.GetPlayer(tonumber(bersaglioSrc) or 0)
    if not bersaglio then return rispondi(false, 'A bordo non c\'è nessuno da identificare.') end

    local distanza = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(bersaglio.source)))
    if distanza > CAP.Controllo.raggio then
        return rispondi(false, 'Troppo lontano: il controllo si fa sottobordo.')
    end

    ultimoControllo[targa] = os.time()

    local coord = GetEntityCoords(GetPlayerPed(bersaglio.source))
    local rilievi, totale = {}, 0

    local function contesta(articolo, descrizione, importo)
        rilievi[#rilievi + 1] = descrizione
        totale = totale + importo
        exports.ita_codicestrada:EmettiVerbale({
            citizenid = bersaglio.citizenid, targa = targa,
            articolo = articolo, descrizione = descrizione,
            importo = importo, punti = 0,
            origine = 'agente', agente = g:NomeCompleto(),
            luogo = 'controllo in mare',
        })
    end

    -- 1. La patente nautica
    local okP, haPatente = pcall(function()
        return exports.ita_nautica:PatenteNautica(bersaglio.citizenid)
    end)
    if okP and not haPatente then
        contesta(CAP.Controllo.articoloPatente,
                 'Conduzione di unità senza patente nautica', CAP.Controllo.sanzionePatente)
    end

    -- 2. Le dotazioni di sicurezza
    local haDotazione = false
    for _, item in ipairs(CAP.Controllo.dotazioni) do
        local okI, ha = pcall(function()
            return exports.aurea_inventory:Ha(bersaglio.citizenid, item, 1)
        end)
        if okI and ha then haDotazione = true break end
    end
    if not haDotazione then
        contesta(CAP.Controllo.articoloDotazioni,
                 'Dotazioni di sicurezza mancanti a bordo', CAP.Controllo.sanzioneDotazioni)
    end

    -- 3. Le ordinanze sul punto
    for _, o in ipairs(ordinanzeSu(coord)) do
        local d = CAP.GetOrdinanza(o.tipo)
        if d and d.vieta ~= 'velocita' then
            contesta(d.articolo, ('%s — %s'):format(d.etichetta, o.motivo), d.sanzione)
        end
    end

    -- 4. Il fermo già in essere
    local giaFermo = fermi[targa] ~= nil

    MySQL.insert.await([[
        INSERT INTO capitaneria_controlli (targa, conducente, operatore, rilievi, sanzione)
        VALUES (?, ?, ?, ?, ?)
    ]], { targa, bersaglio.citizenid, g.citizenid,
          #rilievi > 0 and table.concat(rilievi, ' · ') or 'nessun rilievo', totale })

    -- Il fermo amministrativo scatta da solo quando i rilievi sono tanti
    local fermato = false
    if not giaFermo and #rilievi >= CAP.Fermo.violazioniPerFermo then
        fermi[targa] = { motivo = table.concat(rilievi, ' · '), dal = os.time() }
        fermi[targa].id = MySQL.insert.await([[
            INSERT INTO capitaneria_fermi (targa, proprietario, motivo, disposto_da, importo)
            VALUES (?, ?, ?, ?, ?)
        ]], { targa, bersaglio.citizenid, fermi[targa].motivo, g.citizenid, CAP.Fermo.importoDissequestro })
        fermato = true
        TriggerClientEvent('cap:fermata', -1, targa, true)
    end

    AUREA.Log('multe', 'info', g, ('controllo in mare su %s: %d rilievi'):format(targa, #rilievi))

    rispondi(true, {
        targa = targa,
        conducente = bersaglio:NomeCompleto(),
        patente = okP and haPatente or false,
        dotazioni = haDotazione,
        rilievi = rilievi,
        totale = totale,
        fermato = fermato,
        giaFermo = giaFermo,
    })
end)

-- ---------------------------------------------------------------------------
--  Fermo amministrativo
-- ---------------------------------------------------------------------------
exports('NatanteFermato', function(targa)
    local f = fermi[tostring(targa or ''):upper()]
    if not f then return false end
    return true, f.motivo
end)

AUREA.Callback.Registra('cap:statoFermo', function(src, rispondi, targa)
    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local f = fermi[targa]
    if not f then return rispondi(false, 'Su questa targa non risulta alcun fermo.') end
    rispondi(true, {
        targa = targa, motivo = f.motivo,
        importo = CAP.Fermo.importoDissequestro,
        minuti = math.floor((os.time() - f.dal) / 60),
    })
end)

AUREA.Callback.Registra('cap:dissequestra', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    local f = fermi[targa]
    if not f then return rispondi(false, 'Nessun fermo su questa targa.') end

    if not g:SottraiOvunque(CAP.Fermo.importoDissequestro, ('dissequestro %s'):format(targa)) then
        return rispondi(false, ('Il dissequestro costa %s.'):format(U.Euro(CAP.Fermo.importoDissequestro)))
    end

    MySQL.update.await(
        'UPDATE capitaneria_fermi SET dissequestrato = 1, dissequestrato_il = NOW() WHERE id = ?', { f.id })
    fermi[targa] = nil
    TriggerClientEvent('cap:fermata', -1, targa, false)

    TriggerEvent('aurea:fisco:incasso', 'diritti_marittimi', CAP.Fermo.importoDissequestro, g.citizenid)
    AUREA.Log('veicoli', 'info', g, ('dissequestrato il natante %s'):format(targa))

    rispondi(true, ('Fermo revocato. L\'unità può riprendere il mare. Pagati %s.')
        :format(U.Euro(CAP.Fermo.importoDissequestro)))
end)

-- I fermi non durano per sempre
CreateThread(function()
    while true do
        Wait(60000)
        local adesso = os.time()

        for targa, f in pairs(fermi) do
            if adesso - f.dal >= CAP.Fermo.minutiDurata * 60 then
                MySQL.update.await(
                    'UPDATE capitaneria_fermi SET dissequestrato = 1, dissequestrato_il = NOW() WHERE id = ?', { f.id })
                fermi[targa] = nil
                TriggerClientEvent('cap:fermata', -1, targa, false)
            end
        end

        for id, o in pairs(ordinanze) do
            if adesso >= o.scade then
                revocaOrdinanza(id, 'il provvedimento è scaduto.')
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Ricerca e soccorso
-- ---------------------------------------------------------------------------
local function pacchettoRicerche()
    local out = {}
    for id, r in pairs(ricerche) do
        local battuti, totali = 0, #r.settori
        for _ in pairs(r.battuti) do battuti = battuti + 1 end
        out[#out + 1] = {
            id = id, motivo = r.motivo, centro = r.centro,
            settori = r.settori, battuti = r.battuti,
            quantiBattuti = battuti, totali = totali,
            minutiResidui = math.max(0, math.floor((r.scade - os.time()) / 60)),
            trovato = r.trovato,
        }
    end
    return out
end

--- Le ricerche le vedono solo le forze in mare: un SAR non è uno spettacolo.
local function diffondiRicerche()
    local p = pacchettoRicerche()
    for _, g in pairs(AUREA.Giocatori) do
        if inDivisaInMare(g) then
            TriggerClientEvent('cap:ricerche', g.source, p)
        end
    end
end

local function apriRicerca(centro, motivo, dispersoCid)
    local quante = 0
    for _ in pairs(ricerche) do quante = quante + 1 end
    if quante >= CAP.SAR.massimoAperte then return nil end

    -- Il punto dove l'hanno visto l'ultima volta non è dove sta adesso:
    -- la corrente lo ha spostato, e la griglia si costruisce sul punto
    -- stimato, non su quello segnalato.
    local deriva = CAP.SAR.derivaMassima
    local stimato = vector3(
        centro.x + math.random(-deriva, deriva),
        centro.y + math.random(-deriva, deriva), 0.0)

    local id = MySQL.insert.await([[
        INSERT INTO capitaneria_sar (centro_x, centro_y, motivo, disperso)
        VALUES (?, ?, ?, ?)
    ]], { stimato.x, stimato.y, motivo, dispersoCid })

    ricerche[id] = {
        centro = stimato, motivo = motivo, disperso = dispersoCid,
        settori = CAP.Settori(stimato), battuti = {},
        aperta = os.time(), scade = os.time() + CAP.SAR.minutiDurata * 60,
        -- Il settore dove sta davvero. Il client non lo sa e non lo saprà.
        settoreBuono = math.random(1, CAP.SAR.settoriPerLato * CAP.SAR.settoriPerLato),
        trovato = false,
    }
    diffondiRicerche()

    exports.aurea_ui:NotificaEnte(CAP.Ente, {
        tipo = 'avviso', icona = '🆘', durata = 22000,
        titolo = 'Evento SAR aperto',
        testo = ('%s\nGriglia di ricerca su %d settori. Coordinatevi in radio.')
            :format(motivo, #ricerche[id].settori),
    }, true)

    AUREA.Log('staff', 'avviso', nil, ('aperto SAR #%d: %s'):format(id, motivo))
    return id
end

--- La chiama ita_nautica quando qualcuno spara un razzo, e chiunque
--- altro abbia una persona in acqua. Va dentro un pcall: questa risorsa
--- può non essere installata.
exports('ApriRicerca', function(centro, motivo, dispersoCid)
    if type(centro) ~= 'vector3' and type(centro) ~= 'table' then return nil end
    local c = vector3(centro.x or 0.0, centro.y or 0.0, 0.0)

    -- Due griglie sovrapposte sullo stesso tratto di mare non servono a
    -- nessuno: chi cerca non saprebbe più quale settore sta battendo.
    local lato = CAP.SAR.latoSettore * CAP.SAR.settoriPerLato
    for _, r in pairs(ricerche) do
        if CAP.DistanzaPiana(c, r.centro) <= lato then return nil end
    end

    return apriRicerca(c, pulisci(motivo ~= nil and motivo or 'Segnalazione in mare', 140), dispersoCid)
end)

local function chiudiRicerca(id, esito)
    local r = ricerche[id]
    if not r then return end
    MySQL.update.await(
        'UPDATE capitaneria_sar SET chiusa = 1, chiusa_il = NOW(), esito = ? WHERE id = ?',
        { esito, id })
    ricerche[id] = nil
    diffondiRicerche()
end

AUREA.Callback.Registra('cap:battuto', function(src, rispondi, idRicerca, indiceSettore)
    local g = AUREA.GetPlayer(src)
    if not inDivisaInMare(g) then return rispondi(false, 'Non sei in servizio.') end

    idRicerca = tonumber(idRicerca)
    indiceSettore = tonumber(indiceSettore)
    local r = idRicerca and ricerche[idRicerca]
    if not r then return rispondi(false, 'Ricerca non più aperta.') end
    if not indiceSettore or not r.settori[indiceSettore] then
        return rispondi(false, 'Settore inesistente.')
    end
    if r.battuti[indiceSettore] then return rispondi(false, 'Settore già battuto.') end

    -- Il mezzo deve essere davvero lì: il settore si batte navigandolo.
    local s = r.settori[indiceSettore]
    local coord = GetEntityCoords(GetPlayerPed(src))
    if CAP.DistanzaPiana(coord, { x = s.x, y = s.y }) > CAP.SAR.raggioSettore then
        return rispondi(false, 'Sei fuori dal settore che stai dichiarando battuto.')
    end

    r.battuti[indiceSettore] = g.citizenid

    if indiceSettore == r.settoreBuono then
        r.trovato = true
        g:Aggiungi('banca', CAP.SAR.compensoRecupero, 'recupero in mare')

        -- Se il disperso è un giocatore, il recupero lo tira fuori
        -- dall'acqua: il resto lo fa il 118 a terra.
        if r.disperso then
            local d = AUREA.GetPlayerByCitizenId(r.disperso)
            if d then
                TriggerClientEvent('cap:recuperato', d.source, GetEntityCoords(GetPlayerPed(src)))
            end
        end

        exports.aurea_ui:NotificaEnte(CAP.Ente, {
            tipo = 'successo', icona = '🆘', durata = 20000,
            titolo = ('Settore %s — persona recuperata'):format(CAP.NomeSettore(indiceSettore)),
            testo = ('%s ha chiuso la ricerca.'):format(g:NomeCompleto()),
        }, true)

        chiudiRicerca(idRicerca, 'recuperato')
        AUREA.Log('staff', 'info', g, ('chiuso SAR #%d con recupero'):format(idRicerca))
        return rispondi(true, ('Persona recuperata nel settore %s. Compenso %s.')
            :format(CAP.NomeSettore(indiceSettore), U.Euro(CAP.SAR.compensoRecupero)))
    end

    g:Aggiungi('banca', CAP.SAR.compensoSettore, 'ricerca in mare')
    diffondiRicerche()

    local battuti = 0
    for _ in pairs(r.battuti) do battuti = battuti + 1 end

    rispondi(true, ('Settore %s battuto, niente. %d su %d.')
        :format(CAP.NomeSettore(indiceSettore), battuti, #r.settori))
end)

AUREA.Callback.Registra('cap:ricercheAperte', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not inDivisaInMare(g) then return rispondi(nil) end
    rispondi(pacchettoRicerche())
end)

AUREA.Callback.Registra('cap:apriSAR', function(src, rispondi, motivo)
    local g = AUREA.GetPlayer(src)
    if not militare(g, 'sar') then
        return rispondi(false, 'La ricerca la apre chi ha il comando di una motovedetta.')
    end
    motivo = pulisci(motivo, 140)
    if #motivo < 4 then return rispondi(false, 'Serve dire che cosa si cerca.') end

    local id = apriRicerca(GetEntityCoords(GetPlayerPed(src)), motivo, nil)
    if not id then return rispondi(false, 'Ci sono già troppe ricerche aperte.') end
    rispondi(true, 'Ricerca aperta. La griglia è sul tuo punto, con la deriva stimata.')
end)

-- Le ricerche scadono: oltre un certo tempo, in acqua non si torna.
CreateThread(function()
    while true do
        Wait(30000)
        for id, r in pairs(ricerche) do
            if os.time() >= r.scade then
                exports.aurea_ui:NotificaEnte(CAP.Ente, {
                    tipo = 'errore', icona = '🆘', durata = 18000,
                    titolo = 'Ricerca sospesa',
                    testo = ('%s — nessun esito. Le operazioni sono sospese.'):format(r.motivo),
                }, true)
                chiudiRicerca(id, 'sospesa')
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('fermonatante', 'utente', 'Stato del fermo amministrativo di un\'unità', {
    { name = 'targa', help = 'Targa del natante' },
}, function(src, args)
    local targa = tostring(args[1] or ''):upper():gsub('%s+', '')
    local f = fermi[targa]
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = f and 'errore' or 'successo', icona = '⚓',
        titolo = ('Unità %s'):format(targa ~= '' and targa or '—'),
        testo = f and ('SOTTO FERMO AMMINISTRATIVO.\n%s\nDissequestro: %s.')
                    :format(f.motivo, U.Euro(CAP.Fermo.importoDissequestro))
                  or 'Nessun fermo a carico di questa unità.',
        durata = 16000,
    })
end)

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    -- Un riavvio non revoca un'ordinanza e non dissequestra una barca.
    local o = MySQL.query.await([[
        SELECT id, tipo, centro_x, centro_y, raggio, motivo, nome_ufficiale,
               UNIX_TIMESTAMP(emessa_il) AS dal, UNIX_TIMESTAMP(scade_il) AS scade
        FROM capitaneria_ordinanze
        WHERE revocata = 0 AND scade_il > NOW()
    ]]) or {}
    for _, r in ipairs(o) do
        ordinanze[r.id] = {
            tipo = r.tipo, centro = vector3(r.centro_x, r.centro_y, 0.0),
            raggio = r.raggio, motivo = r.motivo, nome = r.nome_ufficiale,
            dal = r.dal or os.time(), scade = r.scade or (os.time() + 600),
        }
    end

    local f = MySQL.query.await([[
        SELECT id, targa, motivo, UNIX_TIMESTAMP(disposto_il) AS dal
        FROM capitaneria_fermi WHERE dissequestrato = 0
    ]]) or {}
    for _, r in ipairs(f) do
        fermi[r.targa] = { id = r.id, motivo = r.motivo, dal = r.dal or os.time() }
    end

    if #o > 0 or #f > 0 then
        print(('[AUREA] capitaneria: %d ordinanze in vigore, %d unità sotto fermo'):format(#o, #f))
    end
    diffondiOrdinanze()
end)

AddEventHandler('aurea:giocatore:caricato', function(src)
    TriggerClientEvent('cap:ordinanze', src, pacchettoOrdinanze())
end)
