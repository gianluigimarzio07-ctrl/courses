--[[
    AUREA · Polizia Scientifica (server)

    Le tracce vivono qui, in memoria, e scadono da sole. Il client le
    disegna soltanto: non le crea, non le sposta, non ne conosce il
    contenuto finché non le reperta.

    Questo è importante più del solito. Una traccia contiene il citizenid
    di chi l'ha lasciata: se la mandassimo al client insieme alla
    posizione, chiunque con un client modificato leggerebbe il nome
    dell'assassino guardando la scena. Al client va solo dove si trova la
    traccia e che tipo è. Il nome esce dal laboratorio, e solo se il
    confronto in banca dati riesce.
]]

local U = AUREA.Util

local tracce = {}       -- [id] = { tipo, coord, citizenid, dati, scade }
local contatore = 0
local analisi = {}      -- [id reperto] = { fine, richiedente }
local residui = {}      -- [citizenid] = os.time() di scadenza

-- ---------------------------------------------------------------------------
--  Deposito delle tracce
-- ---------------------------------------------------------------------------

--- Lascia una traccia sulla scena.
---@param tipo string chiave di SCI.Tracce
---@param coord vector3|table
---@param citizenid string|nil chi l'ha lasciata (può essere ignoto)
---@param dati table|nil informazioni che emergeranno solo dall'analisi
local function deposita(tipo, coord, citizenid, dati)
    local t = SCI.GetTraccia(tipo)
    if not t then return nil end

    -- La scena non può crescere all'infinito: se è satura, la più vecchia cade
    local quante, piuVecchia, quandoVecchia = 0, nil, math.huge
    for id, tr in pairs(tracce) do
        quante = quante + 1
        if tr.creata < quandoVecchia then quandoVecchia, piuVecchia = tr.creata, id end
    end
    if quante >= SCI.Rilievi.massimoTracceScena and piuVecchia then
        tracce[piuVecchia] = nil
    end

    contatore = contatore + 1
    local id = contatore

    tracce[id] = {
        id = id, tipo = tipo,
        coord = vector3(coord.x, coord.y, coord.z),
        citizenid = citizenid,
        dati = dati or {},
        creata = os.time(),
        scade = os.time() + t.durata * 60,
    }

    return id
end

exports('DepositaTraccia', deposita)

--- Le altre risorse segnalano che qualcosa è successo lì.
--- Il sangue non resta sempre: una ferita superficiale, la pioggia, un
--- pavimento assorbente, e sulla scena non c'è niente da repertare.
AddEventHandler('aurea:scientifica:traccia', function(tipo, coord, citizenid, dati)
    if tipo == 'sangue' and math.random(100) > SCI.Regole.probabilitaSangue then return end
    deposita(tipo, coord, citizenid, dati)
end)

--- Pulizia periodica: le tracce scadute non esistono più.
CreateThread(function()
    while true do
        Wait(60000)
        local ora = os.time()
        for id, t in pairs(tracce) do
            if t.scade <= ora then tracce[id] = nil end
        end
        for cid, fino in pairs(residui) do
            if fino <= ora then residui[cid] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Lo sparo
--
--  Il client dice "ho sparato con quest'arma, qui". La matricola non gliela
--  chiediamo: la ricaviamo dall'inventario, che è roba nostra.
-- ---------------------------------------------------------------------------
local ultimoSparo = {}

RegisterNetEvent('sci:sparo', function(nomeArma, x, y, z)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    -- Un colpo ogni 400 ms al massimo genera traccia: le raffiche non
    -- devono riempire la memoria del server
    local ora = GetGameTimer()
    if ultimoSparo[src] and ora - ultimoSparo[src] < 400 then return end
    ultimoSparo[src] = ora

    if type(nomeArma) ~= 'string' or #nomeArma > 48 then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    -- Se il client dice di aver sparato a cento metri da dove sta, mente
    if type(x) ~= 'number' or #(coord - vector3(x + 0.0, y + 0.0, z + 0.0)) > 8.0 then
        x, y, z = coord.x, coord.y, coord.z
    end

    -- Quale arma ha davvero in tasca?
    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local matricola, clandestina
    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if riga.nome == 'arma' and riga.metadata and riga.metadata.arma == nomeArma then
            matricola = riga.metadata.matricola
            clandestina = matricola == SCI.Regole.matricolaAbrasa
            break
        end
    end

    -- Nessuna arma corrispondente: o è un'arma di servizio data dal ped,
    -- o qualcuno sta provando a sporcare la scena. In entrambi i casi
    -- niente bossolo intestabile.
    if math.random(100) <= SCI.Regole.probabilitaBossolo then
        deposita('bossolo', vector3(x, y, z), g.citizenid, {
            arma = nomeArma,
            matricola = matricola or SCI.Regole.matricolaAbrasa,
            clandestina = clandestina or matricola == nil,
        })
    end

    if math.random(100) <= SCI.Regole.probabilitaResidui then
        residui[g.citizenid] = os.time() + SCI.Regole.minutiResiduiSulleMani * 60
    end
end)

--- Lavarsi le mani toglie i residui. L'autolavaggio, la doccia, il mare.
AddEventHandler('aurea:scientifica:lavaMani', function(citizenid)
    residui[citizenid] = nil
end)

RegisterNetEvent('sci:lavaMani', function()
    local g = AUREA.GetPlayer(source)
    if g then residui[g.citizenid] = nil end
end)

--- La porta forzata: chiamata da aurea_porte e da ita_furti.
AddEventHandler('aurea:scientifica:effrazione', function(citizenid, coord, conGuanti)
    if conGuanti then return end
    if math.random(100) <= SCI.Regole.probabilitaImpronteScasso then
        deposita('impronte', coord, citizenid, {})
    end
end)

-- ---------------------------------------------------------------------------
--  Sopralluogo
--
--  Al client va la posizione e il tipo. Niente altro.
-- ---------------------------------------------------------------------------
local function inReparto(g, richiedeGrado)
    if not g then return false end
    if not U.Contiene(SCI.Lavori, g.lavoro.nome) then return false end
    if not g.lavoro.servizio then return false end
    if richiedeGrado and g.lavoro.grado < SCI.GradoLaboratorio then return false end
    return true
end

AUREA.Callback.Registra('sci:sopralluogo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi({}) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local conKit = inv:Ha(SCI.Rilievi.kit, 1)

    local coord = GetEntityCoords(GetPlayerPed(src))
    local out = {}

    for _, t in pairs(tracce) do
        local dt = SCI.GetTraccia(t.tipo)
        local visibile = dt.visibileSenzaKit or conKit
        if visibile and #(coord - t.coord) <= SCI.Rilievi.raggio then
            out[#out + 1] = {
                id = t.id, tipo = t.tipo,
                nome = dt.nome, icona = dt.icona,
                coord = { x = t.coord.x, y = t.coord.y, z = t.coord.z },
                fotografata = t.fotografata or false,
                minuti = math.floor((os.time() - t.creata) / 60),
            }
        end
    end

    rispondi(out, conKit)
end)

AUREA.Callback.Registra('sci:fotografa', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false, 'Non sei in servizio.') end

    local t = tracce[id]
    if not t then return rispondi(false, 'La traccia non c\'è più.') end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(SCI.Rilievi.fotocamera, 1) then
        return rispondi(false, 'Serve la macchina fotografica.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - t.coord) > SCI.Rilievi.raggioReperto + 1.0 then
        return rispondi(false, 'Sei troppo lontano dalla traccia.')
    end

    t.fotografata = true
    rispondi(true, SCI.Rilievi.durataFoto)
end)

AUREA.Callback.Registra('sci:reperta', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false, 'Non sei in servizio.') end

    local t = tracce[id]
    if not t then return rispondi(false, 'La traccia non c\'è più.') end

    local dt = SCI.GetTraccia(t.tipo)

    if not t.fotografata then
        return rispondi(false, 'Va fotografata prima di essere rimossa: senza documentazione il reperto è inutilizzabile.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(SCI.Rilievi.kit, 1) then
        return rispondi(false, 'Serve la valigetta per i rilievi.')
    end
    if dt.analizzabile == 'dna' and not inv:Ha(SCI.Rilievi.tampone, 1) then
        return rispondi(false, 'Per il prelievo biologico serve un tampone sterile.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - t.coord) > SCI.Rilievi.raggioReperto + 1.0 then
        return rispondi(false, 'Sei troppo lontano dalla traccia.')
    end

    rispondi(true, SCI.Rilievi.durataReperto)
end)

AUREA.Callback.Registra('sci:concludiReperto', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false) end

    local t = tracce[id]
    if not t or not t.fotografata then return rispondi(false, 'Reperto non più disponibile.') end

    local dt = SCI.GetTraccia(t.tipo)
    local inv = exports.aurea_inventory:Inventario(g.citizenid)

    if dt.analizzabile == 'dna' then
        if not inv:Ha(SCI.Rilievi.tampone, 1) then return rispondi(false, 'Il tampone è finito.') end
        inv:Rimuovi(SCI.Rilievi.tampone, 1)
    end

    -- Il luogo va scritto sul cartellino del reperto: le coordinate sono
    -- brutte ma sono l'unica cosa che non mente
    local luogo = ('%.0f, %.0f'):format(t.coord.x, t.coord.y)

    local repertoId = MySQL.insert.await([[
        INSERT INTO reperti (tipo, luogo, coord, citizenid_origine, dati, repertato_da)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        t.tipo, luogo,
        json.encode({ x = t.coord.x, y = t.coord.y, z = t.coord.z }),
        t.citizenid, json.encode(t.dati), g:NomeCompleto(),
    })

    inv:Aggiungi('reperto', 1, {
        repertoId = repertoId,
        tipo = t.tipo,
        nomeTraccia = dt.nome,
        luogo = luogo,
        repertatoDa = g:NomeCompleto(),
        analizzato = false,
    })
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())

    tracce[id] = nil

    AUREA.Log('giustizia', 'info', g, ('ha repertato %s in zona %s (reperto %d)'):format(dt.nome, luogo, repertoId))
    rispondi(true, ('%s repertato. Numero di reperto %d: portalo in laboratorio.'):format(dt.nome, repertoId))
end)

-- ---------------------------------------------------------------------------
--  Fotosegnalamento (art. 349 c.p.p.)
--
--  Senza questo passaggio la banca dati resta vuota e ogni confronto
--  successivo darà esito negativo. È il vero costo del sistema: la
--  Scientifica identifica chi la polizia ha già identificato una volta.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sci:fotosegnala', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false, 'Non sei in servizio.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Soggetto non trovato.') end

    local postazione = SCI.PostazioneVicina(GetEntityCoords(GetPlayerPed(src)), 3.5)
    if not postazione then return rispondi(false, 'Il fotosegnalamento si fa al gabinetto di segnalamento.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 4.0 then
        return rispondi(false, 'Il soggetto deve essere davanti a te.') end

    if SCI.Fotosegnalamento.soloSeAmmanettato then
        local ok, ammanettato = pcall(function()
            return exports.ita_giustizia:EAmmanettato(b.citizenid)
        end)
        if ok and ammanettato == false then
            return rispondi(false, 'L\'art. 349 c.p.p. si applica al soggetto in stato di fermo o di arresto.')
        end
    end

    rispondi(true, SCI.Fotosegnalamento.durata, b.source, b:NomeCompleto())
end)

AUREA.Callback.Registra('sci:concludiFotosegnalamento', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false) end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Il soggetto se n\'è andato.') end

    MySQL.query.await([[
        INSERT INTO banca_dati_biometrica (citizenid, nome, dna, impronte, rilevato_da)
        VALUES (?, ?, 1, 1, ?)
        ON DUPLICATE KEY UPDATE dna = 1, impronte = 1, rilevato_da = VALUES(rilevato_da), rilevato_il = NOW()
    ]], { b.citizenid, b:NomeCompleto(), g:NomeCompleto() })

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'avviso', icona = '🖐', durata = 14000,
        titolo = 'Fotosegnalamento',
        testo = 'Ti hanno preso impronte e campione salivare. Restano al fascicolo.',
    })

    AUREA.Log('giustizia', 'info', g, ('ha fotosegnalato %s'):format(b:NomeCompleto()))
    rispondi(true, ('%s è ora in banca dati: impronte e profilo genetico.'):format(b:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  Laboratorio
-- ---------------------------------------------------------------------------

--- Il confronto vero e proprio. Qui esce un nome, o non esce niente.
local function confronta(reperto, dati)
    local tipo = reperto.tipo
    local origine = reperto.citizenid_origine

    if tipo == 'bossolo' then
        if math.random(100) > SCI.Esiti.probabilitaBalisticaUtile then
            return { esito = 'inutilizzabile', testo = 'Il bossolo è deformato dall\'impatto: le microstriature non sono leggibili.' }
        end

        local matricola = dati.matricola
        if not matricola or matricola == SCI.Regole.matricolaAbrasa then
            return { esito = 'parziale', testo = 'Arma da fuoco corta, matricola abrasa. Nessun riscontro nel registro nazionale: si tratta di arma clandestina.' }
        end

        local arma = MySQL.single.await(
            'SELECT nome, matricola, intestatario, denunciata, sequestrata FROM armi WHERE matricola = ? LIMIT 1',
            { matricola })
        if not arma then
            return { esito = 'parziale', testo = ('Matricola %s non presente nel registro nazionale.'):format(matricola) }
        end

        local intestatario = arma.intestatario and MySQL.single.await(
            'SELECT nome, cognome FROM personaggi WHERE citizenid = ? LIMIT 1', { arma.intestatario })

        if not intestatario then
            return { esito = 'parziale', citizenid = nil,
                     testo = ('%s, matricola %s. Nel registro non risulta un intestatario attuale.')
                         :format(arma.nome, arma.matricola) }
        end

        return {
            esito = 'positivo', citizenid = arma.intestatario,
            testo = ('%s, matricola %s, intestata a %s %s.%s')
                :format(arma.nome, arma.matricola, intestatario.nome, intestatario.cognome,
                        arma.denunciata == 1 and ' Risulta denunciata come rubata o smarrita.' or ''),
        }
    end

    if tipo == 'sangue' then
        if math.random(100) > SCI.Esiti.probabilitaProfiloUtile then
            return { esito = 'inutilizzabile', testo = 'Campione degradato: non si estrae un profilo genetico utile al confronto.' }
        end
        if not origine then
            return { esito = 'negativo', testo = 'Profilo genetico estratto, ma non attribuibile.' }
        end

        local riga = MySQL.single.await(
            'SELECT nome FROM banca_dati_biometrica WHERE citizenid = ? AND dna = 1 LIMIT 1', { origine })
        if not riga then
            return { esito = 'negativo',
                     testo = 'Profilo genetico completo estratto. Il confronto con la banca dati nazionale è negativo: il soggetto non è mai stato fotosegnalato.' }
        end

        return { esito = 'positivo', citizenid = origine,
                 testo = ('Profilo genetico corrispondente al cartellino di %s.'):format(riga.nome) }
    end

    if tipo == 'impronte' then
        if math.random(100) > SCI.Esiti.probabilitaImprontaUtile then
            return { esito = 'inutilizzabile', testo = 'Impronta parziale: i punti caratteristici sono insufficienti per il confronto.' }
        end
        if not origine then
            return { esito = 'negativo', testo = 'Impronta utile rilevata, ma non attribuibile.' }
        end

        local riga = MySQL.single.await(
            'SELECT nome FROM banca_dati_biometrica WHERE citizenid = ? AND impronte = 1 LIMIT 1', { origine })
        if not riga then
            return { esito = 'negativo',
                     testo = 'Impronta utile con sedici punti caratteristici. Nessuna corrispondenza in AFIS: il soggetto non è mai stato segnalato.' }
        end

        return { esito = 'positivo', citizenid = origine,
                 testo = ('Impronta corrispondente al cartellino dattiloscopico di %s.'):format(riga.nome) }
    end

    if tipo == 'residui' then
        return { esito = origine and 'positivo' or 'negativo', citizenid = origine,
                 testo = origine
                     and 'Lo stub ha dato esito positivo per piombo, bario e antimonio: il soggetto ha esploso colpi o si trovava nelle immediate vicinanze di uno sparo.'
                     or 'Lo stub ha dato esito negativo.' }
    end

    if tipo == 'pneumatici' then
        return { esito = 'parziale',
                 testo = dati.veicolo
                     and ('Battistrada compatibile con pneumatici di primo equipaggiamento di %s.'):format(dati.veicolo)
                     or 'Battistrada di misura commerciale: compatibile con un numero molto ampio di veicoli.' }
    end

    return { esito = 'inutilizzabile', testo = 'Reperto non analizzabile.' }
end

AUREA.Callback.Registra('sci:avviaAnalisi', function(src, rispondi, repertoId)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g, true) then
        return rispondi(false, 'Al laboratorio accede il personale del reparto scientifico.')
    end

    if not SCI.InLaboratorio(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Devi essere in laboratorio.')
    end

    local quante = 0
    for _ in pairs(analisi) do quante = quante + 1 end
    if quante >= SCI.Laboratorio.postazioni then
        return rispondi(false, 'Tutte le postazioni sono occupate: aspetta che si liberi un banco.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local slot
    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if riga.nome == 'reperto' and riga.metadata and riga.metadata.repertoId == repertoId then
            slot = riga
            break
        end
    end
    if not slot then return rispondi(false, 'Non hai quel reperto.') end
    if slot.metadata.analizzato then return rispondi(false, 'Questo reperto è già stato analizzato.') end

    local reperto = MySQL.single.await('SELECT * FROM reperti WHERE id = ? LIMIT 1', { repertoId })
    if not reperto then return rispondi(false, 'Reperto non a registro.') end

    local dt = SCI.GetTraccia(reperto.tipo)
    if not dt then return rispondi(false, 'Reperto non analizzabile.') end

    analisi[repertoId] = { richiedente = g.citizenid, fine = os.time() + dt.minutiAnalisi * 60 }

    local minuti = dt.minutiAnalisi

    CreateThread(function()
        Wait(minuti * 60000)
        analisi[repertoId] = nil

        local dati = json.decode(reperto.dati or '{}') or {}
        local esito = confronta(reperto, dati)

        MySQL.update('UPDATE reperti SET analizzato = 1, esito = ?, referto = ?, analizzato_da = ?, analizzato_il = NOW() WHERE id = ?',
            { esito.esito, esito.testo, g:NomeCompleto(), repertoId })

        local richiedente = AUREA.GetPlayerByCitizenId(g.citizenid)
        if richiedente then
            TriggerClientEvent('sci:referto', richiedente.source, {
                repertoId = repertoId,
                tipo = reperto.tipo,
                nomeTraccia = dt.nome,
                luogo = reperto.luogo,
                esito = esito.esito,
                testo = esito.testo,
            })
        end

        -- Il referto positivo entra nel fascicolo, ma non è una condanna:
        -- dice che quella traccia è di quella persona, non cosa ha fatto.
        AUREA.Log('giustizia', 'info', nil,
            ('Referto reperto %d (%s, %s): %s'):format(repertoId, reperto.tipo, reperto.luogo, esito.esito))
    end)

    rispondi(true, ('Analisi avviata. Il referto sarà pronto fra %d minuti.'):format(minuti))
end)

--- Elenco dei referti già emessi, consultabile dal MDT.
AUREA.Callback.Registra('sci:referti', function(src, rispondi, quanti)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, tipo, luogo, esito, referto, analizzato_da, analizzato_il
        FROM reperti WHERE analizzato = 1
        ORDER BY analizzato_il DESC LIMIT ?
    ]], { math.max(1, math.min(50, tonumber(quanti) or 25)) })

    rispondi(righe or {})
end)

--- Lo stub sulle mani: si fa sul posto, sul soggetto fermato.
AUREA.Callback.Registra('sci:stub', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not inReparto(g) then return rispondi(false, 'Non sei in servizio.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'Soggetto non trovato.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 3.0 then
        return rispondi(false, 'Il soggetto deve essere davanti a te.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(SCI.Rilievi.kit, 1) then return rispondi(false, 'Serve la valigetta per i rilievi.') end

    local positivo = residui[b.citizenid] ~= nil and residui[b.citizenid] > os.time()

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'info', icona = '🖐', durata = 10000,
        titolo = 'Prelievo con stub',
        testo = 'Ti hanno passato un adesivo sulle mani.',
    })

    AUREA.Log('giustizia', 'debug', g, ('stub su %s: %s'):format(b:NomeCompleto(), positivo and 'positivo' or 'negativo'))

    rispondi(true, positivo
        and ('Stub positivo su %s: residui di piombo, bario e antimonio sul dorso della mano.'):format(b:NomeCompleto())
        or ('Stub negativo su %s.'):format(b:NomeCompleto()))
end)

AddEventHandler('playerDropped', function()
    ultimoSparo[source] = nil
end)
