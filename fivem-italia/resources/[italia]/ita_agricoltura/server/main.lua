--[[
    AUREA · Agricoltura (server)

    Lo stato del solco sta qui, e ci sta per intero: cosa c'è seminato, da
    quando, quante volte è stato irrigato. Il client disegna un campo e
    chiede di lavorarci sopra.

    La fertilità è la parte che rende il modulo un modulo e non un
    pulsante: scende a ogni raccolto e risale col tempo, quindi un campo
    spremuto rende meno e non c'è modo di barare — il tempo lo tiene il
    server.
]]

local U = AUREA.Util

local solchi = {}       -- [podere][n] = { coltura, seminato, irrigazioni, fertilita }
local poderi = {}       -- [podereId] = { conduttore, canoniSaltati, prossimoCanone }

-- ---------------------------------------------------------------------------
--  Stagione
-- ---------------------------------------------------------------------------
local function stagione()
    local ok, id = pcall(function() return exports.ita_ambiente:StagioneCorrente() end)
    return (ok and id) or 'primavera'
end

-- ---------------------------------------------------------------------------
--  Caricamento
-- ---------------------------------------------------------------------------
local function carica()
    for _, p in ipairs(AGR.Poderi) do
        solchi[p.id] = {}
        for n = 1, p.solchi do
            solchi[p.id][n] = { fertilita = AGR.Suolo.iniziale, tocco = os.time() }
        end
    end

    for _, r in ipairs(MySQL.query.await('SELECT * FROM agri_solchi') or {}) do
        if solchi[r.podere] and solchi[r.podere][r.solco] then
            solchi[r.podere][r.solco] = {
                coltura = r.coltura, arato = r.arato == 1,
                seminato = r.seminato_il and math.floor((r.seminato_il or 0) / 1000) or nil,
                irrigazioni = r.irrigazioni or 0,
                fertilita = r.fertilita or AGR.Suolo.iniziale,
                tocco = os.time(),
            }
        end
    end

    for _, r in ipairs(MySQL.query.await('SELECT * FROM agri_poderi') or {}) do
        poderi[r.podere] = {
            conduttore = r.conduttore, canoniSaltati = r.canoni_saltati or 0,
            prossimoCanone = os.time() + AGR.Affitto.minuti * 60,
        }
    end
end

AddEventHandler('onResourceStart', function(risorsa)
    if risorsa == GetCurrentResourceName() then
        CreateThread(function() Wait(2500) carica() end)
    end
end)

local function salvaSolco(podereId, n)
    local s = solchi[podereId][n]
    MySQL.query([[
        INSERT INTO agri_solchi (podere, solco, coltura, arato, seminato_il, irrigazioni, fertilita)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE coltura = VALUES(coltura), arato = VALUES(arato),
                                seminato_il = VALUES(seminato_il),
                                irrigazioni = VALUES(irrigazioni), fertilita = VALUES(fertilita)
    ]], { podereId, n, s.coltura, s.arato and 1 or 0,
          s.seminato and os.date('%Y-%m-%d %H:%M:%S', s.seminato) or nil,
          s.irrigazioni or 0, math.floor(s.fertilita) })
end

--- Il suolo si riprende da solo: recupero calcolato al momento in cui lo
--- si guarda, non da un thread che gira a vuoto su cento solchi.
local function fertilita(podereId, n)
    local s = solchi[podereId][n]
    if not s then return 0 end
    local ore = (os.time() - (s.tocco or os.time())) / 3600
    if ore > 0 then
        s.fertilita = math.min(AGR.Suolo.iniziale, s.fertilita + ore * AGR.Suolo.recuperoPerOra)
        s.tocco = os.time()
    end
    return s.fertilita
end

-- ---------------------------------------------------------------------------
--  Chi lavora dove
-- ---------------------------------------------------------------------------
local function agricoltore(g, permesso)
    if not g or g.lavoro.nome ~= AGR.Lavoro then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

local function podereVicino(coord)
    for _, p in ipairs(AGR.Poderi) do
        if #(coord - p.centro) <= p.raggio then return p end
    end
end

local function condotto(podereId, citizenid)
    local p = poderi[podereId]
    return p ~= nil and p.conduttore == citizenid
end

-- ---------------------------------------------------------------------------
--  Affitto del podere
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('agr:poderi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local fuori = {}
    for _, p in ipairs(AGR.Poderi) do
        local stato = poderi[p.id]
        fuori[#fuori + 1] = {
            id = p.id, nome = p.nome, ettari = p.ettari, solchi = p.solchi,
            canone = p.canone, soloVite = p.soloVite or false,
            libero = stato == nil,
            mio = g and stato ~= nil and stato.conduttore == g.citizenid or false,
        }
    end
    rispondi(fuori, stagione())
end)

AUREA.Callback.Registra('agr:affitta', function(src, rispondi, podereId)
    local g = AUREA.GetPlayer(src)
    if not agricoltore(g, 'affitta_podere') then
        return rispondi(false, 'Il podere lo prende in conduzione chi ha il grado per farlo.')
    end

    local p = AGR.GetPodere(podereId)
    if not p then return rispondi(false, 'Podere sconosciuto.') end
    if poderi[podereId] then return rispondi(false, 'Quel podere è già condotto da qualcuno.') end

    for _, x in pairs(poderi) do
        if x.conduttore == g.citizenid then return rispondi(false, 'Conduci già un podere.') end
    end

    if not g:Sottrai('banca', p.canone, ('canone %s'):format(p.nome)) then
        return rispondi(false, ('Il primo canone è %s.'):format(U.Euro(p.canone)))
    end
    TriggerEvent('aurea:fisco:incasso', 'canoni_agricoli', p.canone, g.citizenid)

    poderi[podereId] = {
        conduttore = g.citizenid, canoniSaltati = 0,
        prossimoCanone = os.time() + AGR.Affitto.minuti * 60,
    }
    MySQL.query.await([[
        INSERT INTO agri_poderi (podere, conduttore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE conduttore = VALUES(conduttore), canoni_saltati = 0
    ]], { podereId, g.citizenid })

    AUREA.Log('economia', 'info', g, ('ha preso in conduzione %s'):format(podereId))
    rispondi(true, ('%s è tuo. %d ettari, %d solchi. Canone %s ogni %d minuti.')
        :format(p.nome, p.ettari, p.solchi, U.Euro(p.canone), AGR.Affitto.minuti))
end)

-- ---------------------------------------------------------------------------
--  Lo stato dei solchi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('agr:solchi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = podereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not p then return rispondi(nil) end

    local st = stagione()
    local fuori = {}
    for n = 1, p.solchi do
        local s = solchi[p.id][n]
        local c = s.coltura and AGR.GetColtura(s.coltura)
        local maturo = false
        if s.seminato and c then
            maturo = (os.time() - s.seminato) >= c.minutiMaturazione * 60
        end

        fuori[n] = {
            n = n,
            coltura = s.coltura, nomeColtura = c and c.nome or nil, icona = c and c.icona or nil,
            arato = s.arato or false,
            irrigazioni = s.irrigazioni or 0,
            ottimali = c and c.irrigazioniOttimali or 0,
            maturo = maturo,
            minutiResidui = (s.seminato and c)
                and math.max(0, math.ceil((s.seminato + c.minutiMaturazione * 60 - os.time()) / 60)) or 0,
            fertilita = math.floor(fertilita(p.id, n)),
            inStagione = s.coltura and AGR.InStagione(s.coltura, st) or nil,
        }
    end

    rispondi({
        podere = p.id, nome = p.nome, stagione = st,
        mio = condotto(p.id, g.citizenid),
        solchi = fuori,
    })
end)

-- ---------------------------------------------------------------------------
--  Le lavorazioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('agr:lavora', function(src, rispondi, n, azione, coltura)
    local g = AUREA.GetPlayer(src)
    if not agricoltore(g, 'coltiva') then return rispondi(false, 'Non lavori la terra.') end

    local p = podereVicino(GetEntityCoords(GetPlayerPed(src)))
    if not p then return rispondi(false, 'Non sei su un podere.') end
    if not condotto(p.id, g.citizenid) then
        -- Chi lavora per il conduttore va bene, chi passa di lì no
        local capo = poderi[p.id] and AUREA.GetPlayerByCitizenId(poderi[p.id].conduttore)
        if not capo or capo.lavoro.nome ~= AGR.Lavoro then
            return rispondi(false, 'Questo podere non è condotto da te.')
        end
    end

    n = tonumber(n) or 0
    local s = solchi[p.id][n]
    if not s then return rispondi(false, 'Solco inesistente.') end

    if azione == 'aratura' then
        if s.coltura then return rispondi(false, 'C\'è ancora una coltura in piedi.') end
        local v = GetVehiclePedIsIn(GetPlayerPed(src), false)
        local modello = v ~= 0 and GetEntityModel(v) or 0
        local ok = false
        for _, m in ipairs(AGR.Trattori) do
            if modello == GetHashKey(m) then ok = true end
        end
        if not ok then return rispondi(false, 'A mano non si ara. Serve il trattore.') end

        s.arato = true
        salvaSolco(p.id, n)
        return rispondi(true, 'Solco arato. Adesso si può seminare.')
    end

    if azione == 'semina' then
        if not s.arato then return rispondi(false, 'Prima si ara.') end
        if s.coltura then return rispondi(false, 'Qui è già seminato.') end

        local c = AGR.GetColtura(coltura)
        if not c then return rispondi(false, 'Coltura sconosciuta.') end
        if c.soloVigneto and not p.soloVite then
            return rispondi(false, 'La vite si pianta nel vigneto, non in un campo.')
        end
        if p.soloVite and not c.soloVigneto then
            return rispondi(false, 'Quello è un vigneto: ci va la vite.')
        end

        if not exports.aurea_inventory:Ha(g.citizenid, c.seme, 1) then
            return rispondi(false, ('Serve %s.'):format(AUREA.Item[c.seme].etichetta))
        end
        exports.aurea_inventory:Rimuovi(g.citizenid, c.seme, 1)

        s.coltura, s.seminato, s.irrigazioni, s.arato = coltura, os.time(), 0, false
        salvaSolco(p.id, n)

        local st = stagione()
        return rispondi(true, ('%s seminato.%s\nMatura in %d minuti, e vuole %d irrigazioni.')
            :format(c.nome,
                    AGR.InStagione(coltura, st) and '' or ' FUORI STAGIONE: la resa sarà una miseria.',
                    c.minutiMaturazione, c.irrigazioniOttimali))
    end

    if azione == 'irrigazione' then
        if not s.coltura then return rispondi(false, 'Non c\'è niente da irrigare.') end
        if not exports.aurea_inventory:Ha(g.citizenid, AGR.Lavorazioni.irrigazione.oggetto, 1) then
            return rispondi(false, ('Serve %s.'):format(AUREA.Item[AGR.Lavorazioni.irrigazione.oggetto].etichetta))
        end

        s.irrigazioni = (s.irrigazioni or 0) + 1
        salvaSolco(p.id, n)

        local c = AGR.GetColtura(s.coltura)
        return rispondi(true, ('Irrigato %d volte su %d. %s')
            :format(s.irrigazioni, c.irrigazioniOttimali,
                    s.irrigazioni > c.irrigazioniOttimali
                        and 'Stai esagerando: l\'acqua in più non serve.' or 'Va bene così.'))
    end

    if azione == 'concime' then
        if not exports.aurea_inventory:Ha(g.citizenid, AGR.Suolo.concime, 1) then
            return rispondi(false, ('Serve %s.'):format(AUREA.Item[AGR.Suolo.concime].etichetta))
        end
        exports.aurea_inventory:Rimuovi(g.citizenid, AGR.Suolo.concime, 1)

        fertilita(p.id, n)
        s.fertilita = math.min(AGR.Suolo.iniziale, s.fertilita + AGR.Suolo.recuperoConcime)
        salvaSolco(p.id, n)
        return rispondi(true, ('Concimato. Fertilità al %d%%.'):format(math.floor(s.fertilita)))
    end

    if azione == 'raccolta' then
        if not s.coltura or not s.seminato then return rispondi(false, 'Non c\'è niente da raccogliere.') end
        local c = AGR.GetColtura(s.coltura)
        if (os.time() - s.seminato) < c.minutiMaturazione * 60 then
            return rispondi(false, ('Non è maturo: mancano %d minuti.')
                :format(math.ceil((s.seminato + c.minutiMaturazione * 60 - os.time()) / 60)))
        end

        local f = fertilita(p.id, n)
        local m = AGR.Moltiplicatore(s.coltura, stagione(), s.irrigazioni, f)
        local quanti = math.max(1, math.floor(c.resaBase * m + 0.5))

        local resa = c.resa
        if c.resaAlternativa and math.random() < 0.35 then resa = c.resaAlternativa end
        exports.aurea_inventory:Aggiungi(g.citizenid, resa, quanti)

        s.coltura, s.seminato, s.irrigazioni, s.arato = nil, nil, 0, false
        s.fertilita = math.max(0, f - c.consumoSuolo)
        salvaSolco(p.id, n)

        TriggerEvent('aurea:rifiuti:prodotti', g.citizenid, AGR.Lavoro, 0)

        return rispondi(true, ('%d × %s.\nResa al %d%% — fertilità del solco %d%%.')
            :format(quanti, AUREA.Item[resa].etichetta, math.floor(m * 100), math.floor(s.fertilita)))
    end

    rispondi(false, 'Lavorazione sconosciuta.')
end)

-- ---------------------------------------------------------------------------
--  Consorzio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('agr:compra', function(src, rispondi, item, quanti)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - AGR.Consorzio.coord) > 6.0 then
        return rispondi(false, 'Devi essere al consorzio.')
    end

    local prezzo = AGR.Listino[item]
    if not prezzo then return rispondi(false, 'Non a listino.') end

    quanti = math.floor(U.Clamp(tonumber(quanti) or 1, 1, 30))
    local costo = prezzo * quanti

    if not g:Sottrai('banca', costo, 'acquisto al consorzio') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'iva_materiali',
        math.floor(costo * 0.04 / 1.04), g.citizenid)

    if not exports.aurea_inventory:Aggiungi(g.citizenid, item, quanti) then
        g:Aggiungi('banca', costo, 'storno consorzio')
        return rispondi(false, 'Non hai spazio addosso.')
    end

    rispondi(true, ('%d × %s per %s.'):format(quanti, AUREA.Item[item].etichetta, U.Euro(costo)))
end)

-- ---------------------------------------------------------------------------
--  PAC — domanda unica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('agr:pac', function(src, rispondi, ettariDichiarati)
    local g = AUREA.GetPlayer(src)
    if not agricoltore(g, 'pac') then
        return rispondi(false, 'La domanda unica la presenta il titolare dell\'azienda.')
    end

    local ettari = math.floor(U.Clamp(tonumber(ettariDichiarati) or 0, 1, 100))

    MySQL.query.await([[
        INSERT INTO agri_pac (citizenid, ettari_dichiarati, scade_il)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE ettari_dichiarati = VALUES(ettari_dichiarati),
                                presentata_il = NOW(), scade_il = VALUES(scade_il)
    ]], { g.citizenid, ettari, AGR.Pac.validitaMinuti })

    AUREA.Log('economia', 'info', g, ('ha presentato la domanda unica per %d ettari'):format(ettari))
    rispondi(true, ('Domanda unica presentata per %d ettari.\nContributo %s a ettaro, ogni %d minuti.\nL\'organismo pagatore controlla a campione: dichiarare più di quello che coltivi è truffa.')
        :format(ettari, U.Euro(AGR.Pac.perEttaro), AGR.Pac.minuti))
end)

--- Gli ettari davvero coltivati: quelli con qualcosa dentro.
local function ettariColtivatiDa(citizenid)
    local totale = 0
    for podereId, stato in pairs(poderi) do
        if stato.conduttore == citizenid then
            local p = AGR.GetPodere(podereId)
            local pieni = 0
            for n = 1, p.solchi do
                if solchi[podereId][n].coltura then pieni = pieni + 1 end
            end
            totale = totale + math.floor(p.ettari * (pieni / p.solchi))
        end
    end
    return totale
end

CreateThread(function()
    Wait(120000)
    while true do
        Wait(AGR.Pac.minuti * 60000)

        for _, d in ipairs(MySQL.query.await(
            'SELECT * FROM agri_pac WHERE scade_il > NOW()') or {}) do

            local veri = ettariColtivatiDa(d.citizenid)
            local controllo = math.random() < AGR.Pac.probabilitaControllo

            if controllo and d.ettari_dichiarati > veri then
                local indebito = (d.ettari_dichiarati - veri) * AGR.Pac.perEttaro
                local sanzione = indebito * AGR.Pac.sanzioneMoltiplicatore

                MySQL.update('UPDATE agri_pac SET scade_il = NOW() WHERE citizenid = ?', { d.citizenid })
                exports.ita_fisco:IscriviTributo(d.citizenid, 'sanzione',
                    'contributi agricoli indebitamente percepiti', sanzione, 7)
                TriggerEvent('aurea:giustizia:apriFascicolo', d.citizenid, AGR.Pac.reatoFrode,
                    'organismo pagatore',
                    ('Domanda unica per %d ettari a fronte di %d effettivamente coltivati.')
                        :format(d.ettari_dichiarati, veri))

                TriggerEvent('aurea:telefono:messaggioSistema', d.citizenid, 'AGEA',
                    ('Controllo in loco: dichiarati %d ettari, accertati %d. Domanda decaduta, sanzione %s.')
                        :format(d.ettari_dichiarati, veri, U.Euro(sanzione)))

                AUREA.Log('giustizia', 'avviso', nil,
                    ('Frode PAC: %s ha dichiarato %d ettari su %d'):format(d.citizenid, d.ettari_dichiarati, veri))
            else
                local pagabili = math.min(d.ettari_dichiarati, veri)
                if pagabili > 0 then
                    local contributo = pagabili * AGR.Pac.perEttaro
                    AUREA.Denaro.AggiungiOffline(d.citizenid, 'banca', contributo, 'contributo PAC')
                    TriggerEvent('aurea:fisco:erogazione', 'pac', contributo, d.citizenid)
                    TriggerEvent('aurea:telefono:messaggioSistema', d.citizenid, 'AGEA',
                        ('Contributo erogato su %d ettari: %s.'):format(pagabili, U.Euro(contributo)))
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Canoni
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(180000)
    while true do
        Wait(60000)

        for podereId, stato in pairs(poderi) do
            if os.time() >= stato.prossimoCanone then
                local p = AGR.GetPodere(podereId)
                stato.prossimoCanone = os.time() + AGR.Affitto.minuti * 60

                -- SottraiOffline funziona anche su chi non è collegato e
                -- non porta mai il saldo sotto zero: se non c'è, non paga.
                local pagato = AUREA.Denaro.SottraiOffline(stato.conduttore, 'banca', p.canone,
                    ('canone %s'):format(p.nome))

                if pagato then
                    stato.canoniSaltati = 0
                    TriggerEvent('aurea:fisco:incasso', 'canoni_agricoli', p.canone, stato.conduttore)
                else
                    stato.canoniSaltati = stato.canoniSaltati + 1
                    TriggerEvent('aurea:telefono:messaggioSistema', stato.conduttore, 'Consorzio',
                        ('Canone di %s non pagato (%d su %d).')
                            :format(p.nome, stato.canoniSaltati, AGR.Affitto.canoniPrimaDelloSfratto))

                    if stato.canoniSaltati >= AGR.Affitto.canoniPrimaDelloSfratto then
                        poderi[podereId] = nil
                        MySQL.query('DELETE FROM agri_poderi WHERE podere = ?', { podereId })
                        TriggerEvent('aurea:telefono:messaggioSistema', stato.conduttore, 'Consorzio',
                            ('La conduzione di %s è revocata. Il podere torna libero.'):format(p.nome))
                    end
                end
                MySQL.query('UPDATE agri_poderi SET canoni_saltati = ? WHERE podere = ?',
                    { stato.canoniSaltati, podereId })
            end
        end
    end
end)

print('[AUREA] agricoltura: poderi e stagioni attivi')
