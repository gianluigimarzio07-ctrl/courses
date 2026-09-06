--[[
    AUREA · Casa Circondariale (server)

    Tre cose vivono qui e nessuna vive sul client:

      · il peculio, che è denaro vero e va trattato come tale
      · il deposito degli effetti personali, che va restituito intero
      · l'isolamento, che è una restrizione e quindi la decide il server

    Il resto — quanto dura la pena, come scorre, come si riduce — resta
    dove stava, in ita_giustizia. Questa risorsa non la tocca.
]]

local U = AUREA.Util
local isolati = {}      -- [citizenid] = os.time() di fine isolamento
local turni = {}        -- [citizenid] = { fatti, riposoFino }
local colloquiAperti = {}

-- ---------------------------------------------------------------------------
--  Ufficio matricola
-- ---------------------------------------------------------------------------

--- Prende in carico il detenuto: gli lascia poco, gli tiene il resto.
local function ingresso(citizenid, minuti, motivo)
    local inv = exports.aurea_inventory:Inventario(citizenid)
    if not inv then return end

    local deposito = {}

    -- Si lavora su una copia dell'elenco: si sta rimuovendo mentre si legge
    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if not CAR.AmmessoInCella(riga.nome) then
            deposito[#deposito + 1] = {
                nome = riga.nome, quantita = riga.quantita, metadata = riga.metadata,
            }
        end
    end

    for _, r in ipairs(deposito) do
        inv:Rimuovi(r.nome, r.quantita)
    end

    local peculio = 0
    local g = AUREA.GetPlayerByCitizenId(citizenid)

    if CAR.Matricola.contantiInPeculio and g then
        local contanti = g:Saldo('contanti')
        if contanti > 0 and g:Sottrai('contanti', contanti, 'versamento sul peculio') then
            peculio = contanti
        end
    end

    MySQL.query.await([[
        INSERT INTO carcere_matricola (citizenid, peculio, deposito, motivo, entrato_il)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            peculio  = peculio + VALUES(peculio),
            deposito = VALUES(deposito),
            motivo   = VALUES(motivo),
            entrato_il = NOW(), uscito_il = NULL
    ]], { citizenid, peculio, json.encode(deposito), motivo or 'esecuzione pena' })

    if g then
        TriggerClientEvent('inv:aggiorna', g.source, inv:Pacchetto())
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'avviso', icona = '🔒', durata = 20000,
            titolo = 'Ufficio matricola',
            testo = ('%d effetti personali in deposito. %s versati sul peculio: dentro si spende solo al sopravvitto.')
                :format(#deposito, U.Euro(peculio)),
        })
    end
end

AddEventHandler('aurea:carcere:ingresso', ingresso)

--- Restituisce tutto. Se l'inventario non regge, il resto resta a deposito
--- e si ritira quando c'è posto: non si butta via la roba di nessuno.
local function uscita(citizenid, motivo)
    local riga = MySQL.single.await(
        'SELECT peculio, deposito FROM carcere_matricola WHERE citizenid = ? AND uscito_il IS NULL LIMIT 1',
        { citizenid })
    if not riga then return end

    isolati[citizenid] = nil
    turni[citizenid] = nil

    local inv = exports.aurea_inventory:Inventario(citizenid)
    local deposito = json.decode(riga.deposito or '[]') or {}
    local restanti = {}

    for _, r in ipairs(deposito) do
        if not (inv and inv:Aggiungi(r.nome, r.quantita, r.metadata)) then
            restanti[#restanti + 1] = r
        end
    end

    if riga.peculio > 0 then
        AUREA.Denaro.AggiungiOffline(citizenid, 'contanti', riga.peculio, 'saldo del peculio alla scarcerazione')
    end

    if #restanti > 0 then
        MySQL.update('UPDATE carcere_matricola SET peculio = 0, deposito = ? WHERE citizenid = ? AND uscito_il IS NULL',
            { json.encode(restanti), citizenid })
    else
        MySQL.update('UPDATE carcere_matricola SET peculio = 0, deposito = \'[]\', uscito_il = NOW() WHERE citizenid = ? AND uscito_il IS NULL',
            { citizenid })
    end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        if inv then TriggerClientEvent('inv:aggiorna', g.source, inv:Pacchetto()) end
        TriggerClientEvent('car:isolamento', g.source, false)
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'successo', icona = '🔓', durata = 18000,
            titolo = 'Scarcerazione',
            testo = #restanti > 0
                and ('Effetti restituiti in parte: %d pezzi restano a deposito, non avevi posto. Passa in matricola.'):format(#restanti)
                or ('Effetti personali e peculio restituiti (%s).'):format(U.Euro(riga.peculio)),
        })
    end

    AUREA.Log('giustizia', 'info', nil, ('%s: chiusura posizione matricola (%s)'):format(citizenid, motivo or 'fine pena'))
end

AddEventHandler('aurea:carcere:uscita', uscita)

--- Ritiro tardivo di quello che non c'era posto per riprendersi.
AUREA.Callback.Registra('car:ritiraDeposito', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAR.Matricola.coord) > 4.0 then
        return rispondi(false, 'Devi essere allo sportello della matricola.')
    end
    if g:Get('detenuto') then return rispondi(false, 'Sei ancora detenuto.') end

    uscita(g.citizenid, 'ritiro deposito')
    rispondi(true, 'Pratica chiusa allo sportello.')
end)

-- ---------------------------------------------------------------------------
--  Peculio
-- ---------------------------------------------------------------------------
local function peculioDi(citizenid)
    return MySQL.scalar.await(
        'SELECT peculio FROM carcere_matricola WHERE citizenid = ? AND uscito_il IS NULL LIMIT 1',
        { citizenid }) or 0
end

local function variaPeculio(citizenid, delta)
    local saldo = peculioDi(citizenid)
    if saldo + delta < 0 then return false, saldo end
    MySQL.update('UPDATE carcere_matricola SET peculio = peculio + ? WHERE citizenid = ? AND uscito_il IS NULL',
        { delta, citizenid })
    return true, saldo + delta
end

AUREA.Callback.Registra('car:peculio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(0) end
    rispondi(peculioDi(g.citizenid))
end)

--- Versamento dall'esterno: i familiari mandano soldi al detenuto.
AUREA.Callback.Registra('car:versa', function(src, rispondi, detenutoSrc, importo)
    local g = AUREA.GetPlayer(src)
    local d = AUREA.GetPlayer(tonumber(detenutoSrc))
    if not g or not d then return rispondi(false, 'Destinatario non trovato.') end
    if not d:Get('detenuto') then return rispondi(false, 'Il destinatario non risulta detenuto.') end

    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 or importo > 500000 then return rispondi(false, 'Importo non ammesso.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAR.Matricola.coord) > 5.0 then
        return rispondi(false, 'I versamenti si fanno allo sportello della matricola.')
    end

    if not g:SottraiOvunque(importo, ('versamento sul peculio di %s'):format(d:NomeCompleto())) then
        return rispondi(false, 'Non hai la somma.')
    end

    variaPeculio(d.citizenid, importo)

    TriggerClientEvent('aurea:ui:notifica', d.source, {
        tipo = 'successo', icona = '💶', durata = 14000,
        titolo = 'Versamento sul peculio',
        testo = ('%s ha versato %s a tuo favore.'):format(g:NomeCompleto(), U.Euro(importo)),
    })

    rispondi(true, ('%s versati sul peculio di %s.'):format(U.Euro(importo), d:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  Sopravvitto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:listino', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local ora = tonumber(os.date('%H'))
    local aperto = ora >= CAR.Sopravvitto.orario.da and ora < CAR.Sopravvitto.orario.a

    local voci = {}
    for _, r in ipairs(CAR.Sopravvitto.listino) do
        local dati = AUREA.Item[r.item]
        if dati then
            voci[#voci + 1] = { item = r.item, etichetta = dati.etichetta, prezzo = r.prezzo }
        end
    end

    rispondi(voci, peculioDi(g.citizenid), aperto)
end)

AUREA.Callback.Registra('car:compra', function(src, rispondi, item, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if not g:Get('detenuto') then return rispondi(false, 'Il sopravvitto è per i detenuti.') end

    local ora = tonumber(os.date('%H'))
    if ora < CAR.Sopravvitto.orario.da or ora >= CAR.Sopravvitto.orario.a then
        return rispondi(false, ('Il sopravvitto apre dalle %d alle %d.')
            :format(CAR.Sopravvitto.orario.da, CAR.Sopravvitto.orario.a))
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAR.Sopravvitto.coord) > 4.0 then
        return rispondi(false, 'Non sei allo sportello.')
    end

    local prezzo = CAR.PrezzoSopravvitto(item)
    if not prezzo then return rispondi(false, 'Non è a listino.') end

    quantita = math.max(1, math.min(10, math.floor(tonumber(quantita) or 1)))
    local totale = prezzo * quantita

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Aggiungi(item, quantita) then
        return rispondi(false, 'Non hai spazio.')
    end

    local ok, saldo = variaPeculio(g.citizenid, -totale)
    if not ok then
        inv:Rimuovi(item, quantita)
        return rispondi(false, ('Il peculio non copre la spesa: hai %s, servono %s.')
            :format(U.Euro(saldo), U.Euro(totale)))
    end

    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
    TriggerEvent('aurea:fisco:incasso', 'sopravvitto', totale, g.citizenid)

    rispondi(true, ('%dx %s. Sul peculio restano %s.')
        :format(quantita, AUREA.Item[item].etichetta, U.Euro(saldo)))
end)

-- ---------------------------------------------------------------------------
--  Lavorazione interna: la mercede va sul peculio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:lavora', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if not g:Get('detenuto') then return rispondi(false, 'Non risulti detenuto.') end
    if isolati[g.citizenid] then return rispondi(false, 'Sei in isolamento.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAR.Lavorazione.coord) > 5.0 then
        return rispondi(false, 'Non sei alla lavorazione.')
    end

    local t = turni[g.citizenid] or { fatti = 0, riposoFino = 0 }
    if t.riposoFino > os.time() then
        return rispondi(false, ('Turno di riposo: si riprende fra %d minuti.')
            :format(math.ceil((t.riposoFino - os.time()) / 60)))
    end

    rispondi(true, CAR.Lavorazione.durata)
end)

AUREA.Callback.Registra('car:concludiLavoro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not g:Get('detenuto') then return rispondi(false) end

    local t = turni[g.citizenid] or { fatti = 0, riposoFino = 0 }
    t.fatti = t.fatti + 1
    if t.fatti >= CAR.Lavorazione.turniPrimaDiRiposo then
        t.fatti = 0
        t.riposoFino = os.time() + CAR.Lavorazione.minutiRiposo * 60
    end
    turni[g.citizenid] = t

    local _, saldo = variaPeculio(g.citizenid, CAR.Lavorazione.mercede)

    rispondi(true, ('Mercede di %s accreditata. Peculio: %s.%s')
        :format(U.Euro(CAR.Lavorazione.mercede), U.Euro(saldo or 0),
                t.riposoFino > os.time() and ' Fine turno: adesso riposo.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Colloqui
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:chiediColloquio', function(src, rispondi, citizenidDetenuto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - CAR.Colloqui.salaAttesa) > 6.0 then
        return rispondi(false, 'Le richieste si presentano in sala d\'attesa.')
    end

    local detenuto = MySQL.single.await(
        'SELECT citizenid, nome, cognome FROM personaggi WHERE citizenid = ? LIMIT 1', { citizenidDetenuto })
    if not detenuto then return rispondi(false, 'Nessun detenuto con quel codice.') end

    local pendenti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM carcere_colloqui WHERE detenuto = ? AND stato = \'richiesto\'',
        { citizenidDetenuto }) or 0
    if pendenti >= CAR.Colloqui.massimoPendenti then
        return rispondi(false, 'Il detenuto ha già il massimo di richieste pendenti.')
    end

    -- Il difensore non ha bisogno di autorizzazione preventiva
    local diritto = U.Contiene(CAR.Colloqui.lavoriSenzaAutorizzazione, g.lavoro.nome)

    MySQL.insert.await([[
        INSERT INTO carcere_colloqui (detenuto, visitatore, visitatore_nome, stato, richiesto_il)
        VALUES (?, ?, ?, ?, NOW())
    ]], { citizenidDetenuto, g.citizenid, g:NomeCompleto(), diritto and 'autorizzato' or 'richiesto' })

    if not diritto then
        exports.aurea_ui:NotificaLavoro(CAR.Lavoro, {
            tipo = 'info', icona = '👥', durata = 14000,
            titolo = 'Richiesta di colloquio',
            testo = ('%s chiede colloquio con %s %s.')
                :format(g:NomeCompleto(), detenuto.nome, detenuto.cognome),
        }, true)
    end

    rispondi(true, diritto
        and 'Colloquio con il difensore: nessuna autorizzazione preventiva occorre (art. 104 c.p.p.). Accomodati in sala colloqui.'
        or 'Richiesta trasmessa alla direzione. Attendi l\'autorizzazione.')
end)

AUREA.Callback.Registra('car:colloquiPendenti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= CAR.Lavoro or not g.lavoro.servizio then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT c.id, c.visitatore_nome, c.stato, p.nome, p.cognome
        FROM carcere_colloqui c
        LEFT JOIN personaggi p ON p.citizenid = c.detenuto
        WHERE c.stato IN ('richiesto', 'autorizzato')
        ORDER BY c.id DESC LIMIT 25
    ]])
    rispondi(righe or {})
end)

AUREA.Callback.Registra('car:decidiColloquio', function(src, rispondi, id, autorizza)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= CAR.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio.')
    end

    local riga = MySQL.single.await('SELECT * FROM carcere_colloqui WHERE id = ? LIMIT 1', { id })
    if not riga or riga.stato ~= 'richiesto' then return rispondi(false, 'Richiesta non più pendente.') end

    MySQL.update('UPDATE carcere_colloqui SET stato = ?, deciso_da = ?, deciso_il = NOW() WHERE id = ?',
        { autorizza and 'autorizzato' or 'respinto', g:NomeCompleto(), id })

    local visitatore = AUREA.GetPlayerByCitizenId(riga.visitatore)
    if visitatore then
        TriggerClientEvent('aurea:ui:notifica', visitatore.source, {
            tipo = autorizza and 'successo' or 'errore', icona = '👥', durata = 15000,
            titolo = autorizza and 'Colloquio autorizzato' or 'Colloquio respinto',
            testo = autorizza
                and ('Puoi accedere alla sala colloqui per %d minuti.'):format(CAR.Colloqui.durataMinuti)
                or 'La direzione non ha autorizzato il colloquio.',
        })
    end

    rispondi(true, autorizza and 'Colloquio autorizzato.' or 'Richiesta respinta.')
end)

-- ---------------------------------------------------------------------------
--  Perquisizione e isolamento
-- ---------------------------------------------------------------------------
local function isola(g, minuti, motivo)
    isolati[g.citizenid] = os.time() + minuti * 60
    TriggerClientEvent('car:isolamento', g.source, true, CAR.Disciplina.cellaIsolamento, minuti, motivo)

    CreateThread(function()
        Wait(minuti * 60000)
        if isolati[g.citizenid] and isolati[g.citizenid] <= os.time() then
            isolati[g.citizenid] = nil
            local ancora = AUREA.GetPlayerByCitizenId(g.citizenid)
            if ancora then TriggerClientEvent('car:isolamento', ancora.source, false) end
        end
    end)
end

AUREA.Callback.Registra('car:perquisisci', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= CAR.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Soggetto non trovato.') end
    if not b:Get('detenuto') then return rispondi(false, 'Il soggetto non risulta detenuto.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 3.0 then
        return rispondi(false, 'Il detenuto deve essere davanti a te.')
    end

    local inv = exports.aurea_inventory:Inventario(b.citizenid)
    local irregolari, grave = {}, false

    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if not CAR.AmmessoInCella(riga.nome) then
            irregolari[#irregolari + 1] = { nome = riga.nome, etichetta = riga.etichetta, quantita = riga.quantita }
            if CAR.EGrave(riga.nome) then grave = true end
        end
    end

    if #irregolari == 0 then
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = 'info', icona = '🔍', durata = 8000,
            titolo = 'Perquisizione', testo = 'Nulla di rilevante.',
        })
        return rispondi(true, ('Perquisizione su %s: nulla da segnalare.'):format(b:NomeCompleto()))
    end

    local elenco = {}
    for _, r in ipairs(irregolari) do
        inv:Rimuovi(r.nome, r.quantita)
        elenco[#elenco + 1] = ('%dx %s'):format(r.quantita, r.etichetta)

        if r.nome == 'erba' or r.nome == 'hashish' or r.nome == 'cocaina'
            or r.nome == 'eroina' or r.nome == 'mdma' or r.nome == 'sostanza_raffinata' then
            exports.ita_giustizia:ApriFascicolo(b.citizenid, CAR.Disciplina.reatoStupefacenti,
                g:NomeCompleto(), 'Rinvenimento in sede di perquisizione presso l\'istituto')
        elseif r.nome == 'arma' or r.nome == 'cartuccia' then
            exports.ita_giustizia:ApriFascicolo(b.citizenid, CAR.Disciplina.reatoArmi,
                g:NomeCompleto(), 'Rinvenimento di arma presso l\'istituto')
        end
    end

    TriggerClientEvent('inv:aggiorna', b.source, inv:Pacchetto())

    local minuti = grave and CAR.Disciplina.minutiIsolamentoGrave or CAR.Disciplina.minutiIsolamento
    isola(b, minuti, table.concat(elenco, ', '))

    AUREA.Log('giustizia', 'avviso', g,
        ('perquisizione su %s: %s'):format(b:NomeCompleto(), table.concat(elenco, ', ')))

    rispondi(true, ('Rinvenuti: %s. %s in isolamento per %d minuti.')
        :format(table.concat(elenco, ', '), b:NomeCompleto(), minuti))
end)

AUREA.Callback.Registra('car:isolato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    local fino = isolati[g.citizenid]
    rispondi(fino ~= nil and fino > os.time(), fino and math.max(0, fino - os.time()) or 0)
end)

-- ---------------------------------------------------------------------------
--  Contrabbando
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:passa', function(src, rispondi, destinatarioSrc, item, quantita)
    local g = AUREA.GetPlayer(src)
    local d = AUREA.GetPlayer(tonumber(destinatarioSrc))
    if not g or not d then return rispondi(false, 'Destinatario non trovato.') end
    if g.citizenid == d.citizenid then return rispondi(false, 'Non ha senso.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local punto
    for _, p in ipairs(CAR.Contrabbando.punti) do
        if #(coord - p.coord) <= CAR.Contrabbando.raggio then punto = p break end
    end
    if not punto then return rispondi(false, 'Non sei a un punto della recinzione.') end

    if #(coord - GetEntityCoords(GetPlayerPed(d.source))) > CAR.Contrabbando.raggio * 2 then
        return rispondi(false, 'Il destinatario è troppo lontano dalla recinzione.')
    end

    if not AUREA.Item[item] then return rispondi(false, 'Oggetto sconosciuto.') end
    quantita = math.max(1, math.min(20, math.floor(tonumber(quantita) or 1)))

    local mio = exports.aurea_inventory:Inventario(g.citizenid)
    if not mio:Ha(item, quantita) then return rispondi(false, 'Non ne hai abbastanza.') end

    local suo = exports.aurea_inventory:Inventario(d.citizenid)
    if not suo:Aggiungi(item, quantita) then return rispondi(false, 'Dall\'altra parte non c\'è spazio.') end
    mio:Rimuovi(item, quantita)

    TriggerClientEvent('inv:aggiorna', src, mio:Pacchetto())
    TriggerClientEvent('inv:aggiorna', d.source, suo:Pacchetto())

    -- Le telecamere sulla recinzione
    if math.random(100) <= CAR.Contrabbando.probabilitaRipreso then
        exports.aurea_ui:NotificaLavoro(CAR.Lavoro, {
            tipo = 'errore', icona = '📹', durata = 16000,
            titolo = 'Passaggio alla recinzione',
            testo = ('Le telecamere hanno ripreso un passaggio: %s.'):format(punto.nome),
        }, true)

        -- Chi passa la roba dall'esterno risponde di favoreggiamento
        local esterno = d:Get('detenuto') and g or (g:Get('detenuto') and d or nil)
        if esterno then
            exports.ita_giustizia:ApriFascicolo(esterno.citizenid, CAR.Contrabbando.reatoComplice,
                'direzione dell\'istituto', ('Introduzione di oggetti in istituto penitenziario: %s.'):format(punto.nome))
        end
    end

    AUREA.Log('giustizia', 'debug', g,
        ('ha passato %dx %s a %s alla recinzione'):format(quantita, item, d:NomeCompleto()))

    rispondi(true, ('Passati %dx %s.'):format(quantita, AUREA.Item[item].etichetta))
end)

-- ---------------------------------------------------------------------------
--  Evasione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:varco', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if not g:Get('detenuto') then return rispondi(false, 'Non c\'è niente da fare qui.') end
    if isolati[g.citizenid] then return rispondi(false, 'Sei in isolamento.') end

    local v = CAR.GetVarco(id)
    if not v then return rispondi(false, 'Varco sconosciuto.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - v.coord) > 3.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(v.attrezzo, 1) then
        return rispondi(false, ('Serve %s, e qui dentro non si trova.'):format(AUREA.Item[v.attrezzo].etichetta))
    end

    rispondi(true, v.durata, v.nome)
end)

AUREA.Callback.Registra('car:evadi', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g or not g:Get('detenuto') then return rispondi(false) end

    local v = CAR.GetVarco(id)
    if not v then return rispondi(false) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(v.attrezzo, 1) then return rispondi(false, 'Non hai più l\'attrezzo.') end

    if CAR.Evasione.consumaAttrezzo then
        inv:Rimuovi(v.attrezzo, 1)
        TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
    end

    -- Gli agenti se ne possono accorgere mentre si lavora: la segnalazione
    -- parte comunque, il varco si apre lo stesso. È una corsa, non un dado
    -- che decide se puoi uscire.
    if math.random(100) <= v.probabilitaAvvistamento then
        exports.aurea_ui:NotificaLavoro(CAR.Lavoro, {
            tipo = 'errore', icona = '🚨', durata = 20000,
            titolo = 'EVASIONE IN CORSO',
            testo = ('Manomissione rilevata: %s.'):format(v.nome),
        }, true)
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'errore', icona = '🚨', durata = 20000,
            titolo = 'Evasione dalla Casa Circondariale',
            testo = ('%s si è allontanato dall\'istituto.'):format(g:NomeCompleto()),
        }, true)
    end

    exports.ita_giustizia:ApriFascicolo(g.citizenid, CAR.Evasione.reato,
        'direzione dell\'istituto', ('Evasione consumata attraverso: %s.'):format(v.nome))

    AUREA.Log('giustizia', 'avviso', g, ('è evaso dal varco %s'):format(v.nome))

    rispondi(true, CAR.Evasione.uscita)
end)

-- ---------------------------------------------------------------------------
--  Consultazione per gli agenti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:detenuti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene({ CAR.Lavoro, 'carabinieri', 'polizia' }, g.lavoro.nome) then
        return rispondi({})
    end

    local out = {}
    for _, altro in ipairs(AUREA.GetGiocatori()) do
        if altro:Get('detenuto') then
            local stato = exports.ita_giustizia:StatoDetenzione(altro.citizenid)
            out[#out + 1] = {
                nome = altro:NomeCompleto(),
                citizenid = altro.citizenid,
                source = altro.source,
                residui = stato and stato.residui or nil,
                isolamento = isolati[altro.citizenid] ~= nil,
            }
        end
    end
    rispondi(out)
end)

AddEventHandler('aurea:giocatore:scaricato', function(_, g)
    turni[g.citizenid] = nil
end)
