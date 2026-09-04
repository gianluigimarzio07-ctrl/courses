--[[
    AUREA · Comune (server)
]]

local U = AUREA.Util
local propostaMatrimonio = {}   -- [destinatario] = { da, regime, momento }

-- ---------------------------------------------------------------------------
--  Stato dell'ente
-- ---------------------------------------------------------------------------
local function leggiStato(chiave, predefinito)
    local v = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?', { 'comune_' .. chiave })
    return v ~= nil and v or predefinito
end

local function scriviStato(chiave, valore)
    MySQL.query.await([[
        INSERT INTO economia_stato (chiave, valore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { 'comune_' .. chiave, tostring(valore) })
end

--- Le leve del sindaco, lette dagli altri moduli.
exports('Leva', function(nome)
    local def = COM.LeveSindaco[nome]
    if not def then return nil end
    local valore = leggiStato('leva_' .. nome, tostring(def.predefinito))
    return tonumber(valore) or valore
end)

--- L'addizionale comunale: una quota della ritenuta sugli stipendi resta al
--- Comune invece di finire allo Stato. Alzarla riempie la cassa comunale e
--- svuota quella dell'erario — è la leva politica per eccellenza.
AddEventHandler('aurea:fisco:ritenuta', function(citizenid, importo)
    local addizionale = tonumber(leggiStato('leva_addizionale', COM.LeveSindaco.addizionale.predefinito)) or 0
    if addizionale <= 0 then return end

    local quota = math.floor(importo * (addizionale / 100))
    if quota > 0 then
        scriviStato('cassa', (tonumber(leggiStato('cassa', 0)) or 0) + quota)
        TriggerEvent('aurea:fisco:erogazione', 'addizionale_comunale', quota, citizenid)
    end
end)

--- La fascia oraria della ZTL è una delibera: la si pubblica come stato
--- globale perché client e server la leggano identica.
local function pubblicaBandaZTL()
    local banda = leggiStato('leva_ztl', COM.LeveSindaco.ztl.predefinito)
    GlobalState.ztlBanda = banda
end

AddEventHandler('onResourceStart', function(risorsa)
    if risorsa == GetCurrentResourceName() then pubblicaBandaZTL() end
end)

-- ---------------------------------------------------------------------------
--  TARI: la tassa sui rifiuti, un'iscrizione a ruolo per ogni immobile
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(120000)
    while true do
        local importo = tonumber(leggiStato('leva_tari', COM.LeveSindaco.tari.predefinito)) or 0

        if importo > 0 then
            local immobili = MySQL.query.await([[
                SELECT COALESCE(inquilino, proprietario) AS soggetto, nome
                FROM immobili
                WHERE proprietario IS NOT NULL OR inquilino IS NOT NULL
            ]]) or {}

            local periodo = os.date('%Y-%m')
            for _, i in ipairs(immobili) do
                if i.soggetto then
                    exports.ita_fisco:IscriviTributo(i.soggetto, 'tari', ('%s %s'):format(periodo, i.nome), importo, 12)
                end
            end

            if #immobili > 0 then
                scriviStato('cassa', (tonumber(leggiStato('cassa', 0)) or 0) + importo * #immobili)
            end
        end

        Wait(COM.Tributi.intervalloTari)
    end
end)

-- ---------------------------------------------------------------------------
--  Sussidio di disoccupazione: lo paga la cassa comunale, non lo Stato
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(180000)
    while true do
        local importo = tonumber(leggiStato('leva_sussidio', COM.LeveSindaco.sussidio.predefinito)) or 0
        local disponibile = tonumber(leggiStato('cassa', 0)) or 0

        if importo > 0 then
            for src, g in pairs(AUREA.Giocatori) do
                if disponibile < importo then break end
                if g.lavoro.nome == COM.Tributi.lavoroDisoccupato then
                    g:Aggiungi('banca', importo, 'sussidio di disoccupazione')
                    disponibile = disponibile - importo

                    TriggerClientEvent('aurea:ui:notifica', src, {
                        tipo = 'info', icona = '🏛', durata = 11000,
                        titolo = 'Sussidio comunale',
                        testo = ('Il Comune ti ha accreditato %s.'):format(U.Euro(importo)),
                    })
                end
            end
            scriviStato('cassa', disponibile)
        end

        Wait(COM.Tributi.intervalloSussidio)
    end
end)

-- ---------------------------------------------------------------------------
--  Servizi anagrafici
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('com:servizi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local matrimonio = MySQL.single.await([[
        SELECT m.id, m.regime, m.celebrato_il,
               p.nome AS nome_c, p.cognome AS cognome_c, m.coniuge_a, m.coniuge_b
        FROM matrimoni m
        LEFT JOIN personaggi p ON p.citizenid = IF(m.coniuge_a = ?, m.coniuge_b, m.coniuge_a)
        WHERE (m.coniuge_a = ? OR m.coniuge_b = ?) AND m.sciolto = 0 AND m.stato = 'celebrato'
    ]], { g.citizenid, g.citizenid, g.citizenid })

    local out = {}
    for id, s in pairs(COM.Servizi) do
        out[#out + 1] = { id = id, nome = s.nome, descrizione = s.descrizione, costo = s.costo }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)

    rispondi({
        servizi = out,
        matrimonio = matrimonio and {
            coniuge = ('%s %s'):format(matrimonio.nome_c or '?', matrimonio.cognome_c or ''),
            regime = COM.Matrimonio.regimi[matrimonio.regime] and COM.Matrimonio.regimi[matrimonio.regime].nome or matrimonio.regime,
            quando = U.DataIT(math.floor((matrimonio.celebrato_il or 0) / 1000)),
        } or nil,
        sindaco = leggiStato('sindaco_nome', nil),
    })
end)

AUREA.Callback.Registra('com:richiediServizio', function(src, rispondi, id, dato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local servizio = COM.GetServizio(id)
    if not servizio then return rispondi(false, 'Servizio non previsto.') end

    if servizio.costo > 0 and not g:SottraiOvunque(servizio.costo, servizio.nome) then
        return rispondi(false, ('I diritti sono %s.'):format(U.Euro(servizio.costo)))
    end
    if servizio.costo > 0 then
        TriggerEvent('aurea:fisco:incasso', 'diritti_comunali', servizio.costo, g.citizenid)
    end

    if id == 'duplicato_ci' then
        TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'carta_identita', 1, {
            intestatario = g:NomeCompleto(), cf = g.cf,
        })
        return rispondi(true, 'Carta d\'identità ristampata.')

    elseif id == 'duplicato_ts' then
        TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'tessera_sanitaria', 1, {
            intestatario = g:NomeCompleto(), cf = g.cf,
        })
        return rispondi(true, 'Tessera sanitaria ristampata.')

    elseif id == 'residenza' then
        local immobile = MySQL.single.await([[
            SELECT nome, indirizzo FROM immobili
            WHERE proprietario = ? OR inquilino = ? LIMIT 1
        ]], { g.citizenid, g.citizenid })

        if not immobile then
            g:Aggiungi('contanti', servizio.costo, 'rimborso diritti')
            return rispondi(false, 'Non risulti titolare né locatario di alcun immobile.')
        end

        g:Set('residenza', immobile.indirizzo, true)
        MySQL.update('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
            { json.encode(g.metadata), g.citizenid })

        return rispondi(true, ('Residenza trasferita in %s.'):format(immobile.indirizzo))

    elseif id == 'certificato' then
        local matrimonio = MySQL.single.await([[
            SELECT regime FROM matrimoni WHERE (coniuge_a = ? OR coniuge_b = ?) AND sciolto = 0
        ]], { g.citizenid, g.citizenid })

        TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'visura', 1, {
            ragione = 'Stato di famiglia',
            intestatario = g:NomeCompleto(),
            cf = g.cf,
            stato = matrimonio and 'coniugato/a' or 'libero/a di stato',
            regime = matrimonio and matrimonio.regime or nil,
        })
        return rispondi(true, 'Certificato rilasciato.')

    elseif id == 'cambio_nome' then
        local nuovo = tostring(dato or ''):gsub('[^%a%sàèéìòù\']', ''):sub(1, 24)
        if #nuovo < 2 then
            g:Aggiungi('contanti', servizio.costo, 'rimborso diritti')
            return rispondi(false, 'Indica un nome valido.')
        end

        MySQL.insert.await([[
            INSERT INTO istanze_comunali (citizenid, tipo, contenuto, stato)
            VALUES (?, 'cambio_nome', ?, 'in_esame')
        ]], { g.citizenid, nuovo })

        exports.aurea_ui:NotificaLavoro('comune', {
            tipo = 'info', icona = '📋', durata = 14000,
            titolo = 'Istanza di cambio del nome',
            testo = ('%s chiede di assumere il nome "%s". Va esaminata con /istanze.'):format(g:NomeCompleto(), nuovo),
        }, false)

        return rispondi(true, 'Istanza protocollata. Sarà esaminata dagli uffici.')
    end

    rispondi(false, 'Servizio non gestito.')
end)

--- Esame delle istanze da parte degli uffici comunali.
AUREA.Callback.Registra('com:istanze', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not g:HaPermessoLavoro('anagrafe') then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT i.id, i.citizenid, i.tipo, i.contenuto, i.creata_il, p.nome, p.cognome
        FROM istanze_comunali i
        JOIN personaggi p ON p.citizenid = i.citizenid
        WHERE i.stato = 'in_esame' ORDER BY i.id ASC LIMIT 20
    ]]) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.creata_il or 0) / 1000))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('com:decidiIstanza', function(src, rispondi, id, accolta)
    local g = AUREA.GetPlayer(src)
    if not g or not g:HaPermessoLavoro('anagrafe') then return rispondi(false, 'Non autorizzato.') end

    local istanza = MySQL.single.await('SELECT * FROM istanze_comunali WHERE id = ? AND stato = \'in_esame\'', { id })
    if not istanza then return rispondi(false, 'Istanza non trovata.') end

    MySQL.update.await('UPDATE istanze_comunali SET stato = ?, decisa_da = ? WHERE id = ?',
        { accolta and 'accolta' or 'respinta', g:NomeCompleto(), id })

    if accolta and istanza.tipo == 'cambio_nome' then
        MySQL.update.await('UPDATE personaggi SET nome = ? WHERE citizenid = ?',
            { istanza.contenuto, istanza.citizenid })

        local soggetto = AUREA.GetPlayerByCitizenId(istanza.citizenid)
        if soggetto then
            soggetto.nome = istanza.contenuto
            soggetto:Sincronizza()
        end
    end

    local soggetto = AUREA.GetPlayerByCitizenId(istanza.citizenid)
    if soggetto then
        TriggerClientEvent('aurea:ui:notifica', soggetto.source, {
            tipo = accolta and 'successo' or 'errore',
            icona = '📋', durata = 12000,
            titolo = accolta and 'Istanza accolta' or 'Istanza respinta',
            testo = accolta and 'Gli uffici hanno accolto la tua richiesta.' or 'La tua richiesta non è stata accolta.',
        })
    end

    rispondi(true, accolta and 'Istanza accolta.' or 'Istanza respinta.')
end)

-- ---------------------------------------------------------------------------
--  Matrimonio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('com:proponi', function(src, rispondi, bersaglioSrc, regime)
    local g = AUREA.GetPlayer(src)
    local altro = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not altro or g.source == altro.source then return rispondi(false, 'Persona non trovata.') end

    if not COM.Matrimonio.regimi[regime] then return rispondi(false, 'Regime non valido.') end

    for _, citizenid in ipairs({ g.citizenid, altro.citizenid }) do
        local esistente = MySQL.scalar.await([[
            SELECT id FROM matrimoni WHERE (coniuge_a = ? OR coniuge_b = ?) AND sciolto = 0
        ]], { citizenid, citizenid })
        if esistente then return rispondi(false, 'Uno dei due è già coniugato.') end
    end

    propostaMatrimonio[altro.source] = { da = src, regime = regime, momento = os.time() }

    TriggerClientEvent('com:propostaRicevuta', altro.source, src, g:NomeCompleto(), regime)
    rispondi(true, ('Proposta inviata a %s.'):format(altro:NomeCompleto()))
end)

AUREA.Callback.Registra('com:rispondiProposta', function(src, rispondi, accettata)
    local proposta = propostaMatrimonio[src]
    if not proposta then return rispondi(false) end
    propostaMatrimonio[src] = nil

    if (os.time() - proposta.momento) > 60 then return rispondi(false, 'La proposta è scaduta.') end

    local promesso = AUREA.GetPlayer(proposta.da)
    local risposta = AUREA.GetPlayer(src)
    if not promesso or not risposta then return rispondi(false) end

    if not accettata then
        TriggerClientEvent('aurea:ui:notifica', promesso.source, {
            tipo = 'info', icona = '💔', durata = 10000,
            titolo = 'Proposta declinata',
            testo = ('%s ha risposto di no.'):format(risposta:NomeCompleto()),
        })
        return rispondi(true, 'Hai declinato.')
    end

    TriggerClientEvent('aurea:ui:notifica', promesso.source, {
        tipo = 'successo', icona = '💍', durata = 14000,
        titolo = 'Proposta accettata',
        testo = ('%s ha detto sì. Ora serve un celebrante degli uffici comunali.'):format(risposta:NomeCompleto()),
    })

    -- Si registra la promessa: il celebrante la troverà
    MySQL.query.await([[
        INSERT INTO matrimoni (coniuge_a, coniuge_b, regime, stato)
        VALUES (?, ?, ?, 'promesso')
    ]], { promesso.citizenid, risposta.citizenid, proposta.regime })

    rispondi(true, 'Hai accettato. Andate al Municipio.')
end)

AUREA.Callback.Registra('com:celebra', function(src, rispondi, aSrc, bSrc)
    local celebrante = AUREA.GetPlayer(src)
    local a = AUREA.GetPlayer(tonumber(aSrc))
    local b = AUREA.GetPlayer(tonumber(bSrc))
    if not celebrante or not a or not b then return rispondi(false, 'Serve la presenza di entrambi gli sposi.') end

    if celebrante.lavoro.nome ~= 'comune' or celebrante.lavoro.grado < COM.Matrimonio.gradoMinimoCelebrante then
        return rispondi(false, 'Non hai il titolo per celebrare.')
    end

    local promessa = MySQL.single.await([[
        SELECT * FROM matrimoni
        WHERE stato = 'promesso' AND sciolto = 0
          AND ((coniuge_a = ? AND coniuge_b = ?) OR (coniuge_a = ? AND coniuge_b = ?))
    ]], { a.citizenid, b.citizenid, b.citizenid, a.citizenid })

    if not promessa then return rispondi(false, 'Non risulta una promessa di matrimonio fra i due.') end

    local coordCelebrante = GetEntityCoords(GetPlayerPed(src))
    if #(coordCelebrante - GetEntityCoords(GetPlayerPed(a.source))) > COM.Matrimonio.distanzaSposi + 2.0
       or #(coordCelebrante - GetEntityCoords(GetPlayerPed(b.source))) > COM.Matrimonio.distanzaSposi + 2.0 then
        return rispondi(false, 'Gli sposi devono essere davanti a te.')
    end

    -- I diritti li paga chi ha proposto
    if not a:SottraiOvunque(COM.Matrimonio.costo, 'diritti di segreteria matrimonio') then
        return rispondi(false, ('Servono %s di diritti.'):format(U.Euro(COM.Matrimonio.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_comunali', COM.Matrimonio.costo, a.citizenid)

    MySQL.update.await([[
        UPDATE matrimoni SET stato = 'celebrato', celebrato_il = NOW(), celebrante = ? WHERE id = ?
    ]], { celebrante:NomeCompleto(), promessa.id })

    for _, sposo in ipairs({ a, b }) do
        TriggerEvent('aurea:inventario:aggiungi', sposo.citizenid, 'visura', 1, {
            ragione = 'Atto di matrimonio',
            intestatario = ('%s e %s'):format(a:NomeCompleto(), b:NomeCompleto()),
            regime = COM.Matrimonio.regimi[promessa.regime].nome,
            origine = celebrante:NomeCompleto(),
        })
        TriggerClientEvent('aurea:ui:notifica', sposo.source, {
            tipo = 'successo', icona = '💍', durata = 16000,
            titolo = 'Matrimonio celebrato',
            testo = ('Uniti in matrimonio con %s. Regime: %s.'):format(
                sposo.citizenid == a.citizenid and b:NomeCompleto() or a:NomeCompleto(),
                COM.Matrimonio.regimi[promessa.regime].nome),
        })
    end

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '💍', durata = 12000,
        titolo = 'Pubblicazione di matrimonio',
        testo = ('%s e %s si sono uniti in matrimonio.'):format(a:NomeCompleto(), b:NomeCompleto()),
    })

    AUREA.Log('staff', 'info', celebrante, ('ha celebrato il matrimonio fra %s e %s'):format(a.citizenid, b.citizenid))
    rispondi(true, 'Matrimonio celebrato e trascritto nei registri.')
end)

AUREA.Callback.Registra('com:divorzio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local matrimonio = MySQL.single.await([[
        SELECT * FROM matrimoni WHERE (coniuge_a = ? OR coniuge_b = ?) AND sciolto = 0 AND stato = 'celebrato'
    ]], { g.citizenid, g.citizenid })
    if not matrimonio then return rispondi(false, 'Non risulti coniugato.') end

    if not g:SottraiOvunque(COM.Matrimonio.costoDivorzio, 'spese di separazione') then
        return rispondi(false, ('Le spese sono %s.'):format(U.Euro(COM.Matrimonio.costoDivorzio)))
    end

    local altroId = matrimonio.coniuge_a == g.citizenid and matrimonio.coniuge_b or matrimonio.coniuge_a

    -- In comunione dei beni il saldo si divide
    if matrimonio.regime == 'comunione' and COM.Matrimonio.divideBanca then
        local saldoA = select(2, AUREA.Denaro.Saldo(g.citizenid))
        local saldoB = select(2, AUREA.Denaro.Saldo(altroId))
        local totale = saldoA + saldoB
        local meta = math.floor(totale / 2)

        if saldoA > meta then
            local differenza = saldoA - meta
            AUREA.Denaro.SottraiOffline(g.citizenid, 'banca', differenza, 'divisione dei beni')
            AUREA.Denaro.AggiungiOffline(altroId, 'banca', differenza, 'divisione dei beni')
        elseif saldoB > meta then
            local differenza = saldoB - meta
            AUREA.Denaro.SottraiOffline(altroId, 'banca', differenza, 'divisione dei beni')
            AUREA.Denaro.AggiungiOffline(g.citizenid, 'banca', differenza, 'divisione dei beni')
        end
    end

    MySQL.update.await('UPDATE matrimoni SET sciolto = 1, sciolto_il = NOW() WHERE id = ?', { matrimonio.id })

    local altro = AUREA.GetPlayerByCitizenId(altroId)
    if altro then
        TriggerClientEvent('aurea:ui:notifica', altro.source, {
            tipo = 'avviso', icona = '💔', durata = 14000,
            titolo = 'Matrimonio sciolto',
            testo = ('%s ha chiesto e ottenuto la separazione.'):format(g:NomeCompleto()),
        })
    end

    rispondi(true, matrimonio.regime == 'comunione'
        and 'Matrimonio sciolto. I saldi bancari sono stati divisi in parti uguali.'
        or 'Matrimonio sciolto.')
end)

-- ---------------------------------------------------------------------------
--  Elezioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('com:elezioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local fase = leggiStato('fase_elettorale', 'chiusa')
    local candidati = MySQL.query.await([[
        SELECT c.id, c.citizenid, c.programma, c.firme,
               p.nome, p.cognome,
               (SELECT COUNT(*) FROM voti v WHERE v.candidato_id = c.id) AS voti
        FROM candidati c JOIN personaggi p ON p.citizenid = c.citizenid
        WHERE c.tornata = ? ORDER BY voti DESC
    ]], { leggiStato('tornata', '1') }) or {}

    local giaVotato = MySQL.scalar.await([[
        SELECT v.id FROM voti v JOIN candidati c ON c.id = v.candidato_id
        WHERE v.elettore = ? AND c.tornata = ?
    ]], { g.citizenid, leggiStato('tornata', '1') })

    rispondi({
        fase = fase,
        candidati = candidati,
        giaVotato = giaVotato ~= nil,
        sindaco = leggiStato('sindaco_nome', nil),
        eCandidabile = g.lavoro.nome ~= 'carabinieri' and g.lavoro.nome ~= 'polizia',
        cauzione = COM.Elezioni.cauzioneCandidatura,
        firmeNecessarie = COM.Elezioni.firmeNecessarie,
    })
end)

AUREA.Callback.Registra('com:candidati', function(src, rispondi, programma)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if leggiStato('fase_elettorale', 'chiusa') ~= 'campagna' then
        return rispondi(false, 'Le candidature non sono aperte.')
    end

    local condanne = MySQL.scalar.await([[
        SELECT COUNT(*) FROM casellario
        WHERE citizenid = ? AND stato = 'condannato' AND gravita >= ?
    ]], { g.citizenid, COM.Elezioni.gravitaOstativa }) or 0

    if condanne > 0 then
        return rispondi(false, 'Risultano condanne ostative alla candidatura.')
    end

    local tornata = leggiStato('tornata', '1')
    local esistente = MySQL.scalar.await('SELECT id FROM candidati WHERE citizenid = ? AND tornata = ?',
        { g.citizenid, tornata })
    if esistente then return rispondi(false, 'Sei già candidato.') end

    if not g:SottraiOvunque(COM.Elezioni.cauzioneCandidatura, 'cauzione elettorale') then
        return rispondi(false, ('La cauzione è di %s.'):format(U.Euro(COM.Elezioni.cauzioneCandidatura)))
    end

    MySQL.insert.await('INSERT INTO candidati (citizenid, tornata, programma) VALUES (?, ?, ?)',
        { g.citizenid, tornata, tostring(programma or ''):sub(1, 500) })

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '🗳', durata = 13000,
        titolo = 'Nuova candidatura',
        testo = ('%s si candida a sindaco.'):format(g:NomeCompleto()),
    })

    rispondi(true, 'Candidatura depositata.')
end)

AUREA.Callback.Registra('com:vota', function(src, rispondi, idCandidato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if leggiStato('fase_elettorale', 'chiusa') ~= 'voto' then
        return rispondi(false, 'I seggi non sono aperti.')
    end

    local tornata = leggiStato('tornata', '1')
    local giaVotato = MySQL.scalar.await([[
        SELECT v.id FROM voti v JOIN candidati c ON c.id = v.candidato_id
        WHERE v.elettore = ? AND c.tornata = ?
    ]], { g.citizenid, tornata })
    if giaVotato then return rispondi(false, 'Hai già votato in questa tornata.') end

    local candidato = MySQL.single.await('SELECT id FROM candidati WHERE id = ? AND tornata = ?',
        { idCandidato, tornata })
    if not candidato then return rispondi(false, 'Candidato non valido.') end

    MySQL.insert.await('INSERT INTO voti (candidato_id, elettore) VALUES (?, ?)', { idCandidato, g.citizenid })
    rispondi(true, 'Voto registrato. Lo spoglio avverrà alla chiusura dei seggi.')
end)

--- Gestione della tornata da parte dello staff.
AUREA.Comando('elezioni', 'admin', 'Gestisce la tornata elettorale', {
    { name = 'azione', help = 'apri | voto | spoglio | chiudi' },
}, function(src, args)
    local azione = args[1]
    local tornata = tonumber(leggiStato('tornata', '1')) or 1

    if azione == 'apri' then
        scriviStato('tornata', tornata + 1)
        scriviStato('fase_elettorale', 'campagna')
        TriggerClientEvent('aurea:ui:notifica', -1, {
            tipo = 'info', icona = '🗳', durata = 18000,
            titolo = 'Elezioni comunali indette',
            testo = 'Le candidature sono aperte. Passa dal Municipio per depositare la tua.',
        })
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Campagna aperta' })

    elseif azione == 'voto' then
        scriviStato('fase_elettorale', 'voto')
        TriggerClientEvent('aurea:ui:notifica', -1, {
            tipo = 'info', icona = '🗳', durata = 18000,
            titolo = 'Seggi aperti',
            testo = 'Si vota al Municipio. Ogni cittadino ha un voto.',
        })
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Seggi aperti' })

    elseif azione == 'spoglio' then
        local vincitore = MySQL.single.await([[
            SELECT c.citizenid, p.nome, p.cognome, COUNT(v.id) AS voti
            FROM candidati c
            JOIN personaggi p ON p.citizenid = c.citizenid
            LEFT JOIN voti v ON v.candidato_id = c.id
            WHERE c.tornata = ?
            GROUP BY c.id ORDER BY voti DESC LIMIT 1
        ]], { leggiStato('tornata', '1') })

        scriviStato('fase_elettorale', 'chiusa')

        if not vincitore then
            return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'avviso', titolo = 'Nessun candidato' })
        end

        local nome = ('%s %s'):format(vincitore.nome, vincitore.cognome)
        scriviStato('sindaco', vincitore.citizenid)
        scriviStato('sindaco_nome', nome)
        scriviStato('sindaco_dal', os.time())

        local eletto = AUREA.GetPlayerByCitizenId(vincitore.citizenid)
        if eletto then eletto:ImpostaLavoro('comune', 3) end

        TriggerClientEvent('aurea:ui:notifica', -1, {
            tipo = 'successo', icona = '🗳', durata = 20000,
            titolo = 'Proclamazione',
            testo = ('%s è il nuovo sindaco con %d voti.'):format(nome, vincitore.voti or 0),
        })

        AUREA.Log('staff', 'info', nil, ('%s eletto sindaco con %d voti'):format(nome, vincitore.voti or 0))
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Spoglio concluso', testo = nome })

    elseif azione == 'chiudi' then
        scriviStato('fase_elettorale', 'chiusa')
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'info', titolo = 'Tornata chiusa' })
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'errore', titolo = 'Uso', testo = '/elezioni <apri|voto|spoglio|chiudi>',
    })
end)

-- ---------------------------------------------------------------------------
--  Leve del sindaco
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('com:leve', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local sindaco = leggiStato('sindaco', nil)
    local eSindaco = sindaco == g.citizenid

    local out = {}
    for id, def in pairs(COM.LeveSindaco) do
        out[#out + 1] = {
            id = id, nome = def.nome, descrizione = def.descrizione,
            valore = leggiStato('leva_' .. id, tostring(def.predefinito)),
            minimo = def.minimo, massimo = def.massimo, opzioni = def.opzioni,
        }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)

    rispondi({
        leve = out, eSindaco = eSindaco,
        sindaco = leggiStato('sindaco_nome', nil),
        cassa = tonumber(leggiStato('cassa', 0)) or 0,
    })
end)

AUREA.Callback.Registra('com:impostaLeva', function(src, rispondi, id, valore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if leggiStato('sindaco', nil) ~= g.citizenid then
        return rispondi(false, 'Solo il sindaco in carica può decidere.')
    end

    local def = COM.LeveSindaco[id]
    if not def then return rispondi(false, 'Leva non prevista.') end

    if def.opzioni then
        if not U.Contiene(def.opzioni, valore) then return rispondi(false, 'Valore non ammesso.') end
        scriviStato('leva_' .. id, valore)
        if id == 'ztl' then pubblicaBandaZTL() end
    else
        local n = math.floor(U.Clamp(tonumber(valore) or def.predefinito, def.minimo, def.massimo))
        scriviStato('leva_' .. id, n)
        valore = n
    end

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '🏛', durata = 14000,
        titolo = 'Delibera del Comune',
        testo = ('%s: nuovo valore %s.'):format(def.nome, tostring(valore)),
    })

    AUREA.Log('economia', 'info', g, ('delibera comunale: %s = %s'):format(id, tostring(valore)))
    rispondi(true, 'Delibera adottata.')
end)

AddEventHandler('playerDropped', function() propostaMatrimonio[source] = nil end)
