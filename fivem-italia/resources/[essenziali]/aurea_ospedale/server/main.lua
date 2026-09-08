--[[
    AUREA · Ospedale (server)

    Tutto quello che un esame rivela lo calcola il server e lo manda solo
    a chi ha titolo per saperlo: il medico che l'ha eseguito e il paziente.
    Il referto non passa in chiaro da nessun'altra parte.
]]

local U = AUREA.Util

local coda = {}         -- accettazioni in attesa
local contatore = 0
local assunzioni = {}   -- [citizenid] = { [sostanza] = scadenza }

-- ---------------------------------------------------------------------------
--  Cosa il paziente ha in corpo
--
--  Lo registra chi somministra: ita_droga quando si consuma, e chiunque
--  altro voglia lasciare una traccia rilevabile.
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:ospedale:assunzione', function(citizenid, sostanza)
    if not citizenid or not sostanza then return end
    local minuti = OSP.Tossicologia.minutiRilevabilita[sostanza] or OSP.Tossicologia.predefinito
    assunzioni[citizenid] = assunzioni[citizenid] or {}
    assunzioni[citizenid][sostanza] = os.time() + minuti * 60
end)

CreateThread(function()
    while true do
        Wait(120000)
        local ora = os.time()
        for cid, elenco in pairs(assunzioni) do
            local resta = false
            for s, scadenza in pairs(elenco) do
                if scadenza <= ora then elenco[s] = nil else resta = true end
            end
            if not resta then assunzioni[cid] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Chi è medico
-- ---------------------------------------------------------------------------
local function medico(g, gradoMinimo)
    if not g then return false end
    if not U.Contiene(OSP.Lavori, g.lavoro.nome) then return false end
    if not g.lavoro.servizio then return false end
    if gradoMinimo and g.lavoro.grado < gradoMinimo then return false end
    return true
end

-- ---------------------------------------------------------------------------
--  Accettazione e triage
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('osp:accetta', function(src, rispondi, idSintomo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not OSP.InReparto(GetEntityCoords(GetPlayerPed(src)), 'accettazione') then
        return rispondi(false, 'Devi essere all\'accettazione.')
    end

    for _, a in ipairs(coda) do
        if a.citizenid == g.citizenid then
            return rispondi(false, ('Sei già in attesa: %s, numero %d.')
                :format(OSP.GetCodice(a.codice).nome, a.numero))
        end
    end

    local sintomo
    for _, s in ipairs(OSP.Triage.sintomi) do
        if s.id == idSintomo then sintomo = s break end
    end
    if not sintomo then return rispondi(false, 'Sintomo non riconosciuto.') end

    -- Il codice proposto dal sintomo si corregge con lo stato reale: chi
    -- dice di avere la febbre ma è a un quarto di salute non è un bianco
    local codice = sintomo.suggerito
    local salute = GetEntityHealth(GetPlayerPed(src)) - 100
    if salute < 40 then codice = 'rosso'
    elseif salute < 90 and codice ~= 'rosso' then codice = 'giallo' end

    contatore = contatore + 1
    coda[#coda + 1] = {
        numero = contatore, citizenid = g.citizenid, nome = g:NomeCompleto(),
        sintomo = sintomo.nome, codice = codice, arrivo = os.time(),
    }

    table.sort(coda, function(a, b)
        local pa, pb = OSP.GetCodice(a.codice).priorita, OSP.GetCodice(b.codice).priorita
        if pa ~= pb then return pa < pb end
        return a.arrivo < b.arrivo
    end)

    exports.aurea_ui:NotificaLavoro('118', {
        tipo = codice == 'rosso' and 'errore' or 'info', icona = '🏥', durata = 12000,
        titolo = ('Accettazione — %s'):format(OSP.GetCodice(codice).nome),
        testo = ('%s: %s.'):format(g:NomeCompleto(), sintomo.nome),
    }, true)

    local avanti = 0
    for _, a in ipairs(coda) do
        if a.citizenid == g.citizenid then break end
        avanti = avanti + 1
    end

    rispondi(true, ('%s assegnato. Numero %d, %d pazienti prima di te.')
        :format(OSP.GetCodice(codice).nome, contatore, avanti))
end)

AUREA.Callback.Registra('osp:coda', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not medico(g) then return rispondi({}) end

    local out = {}
    for _, a in ipairs(coda) do
        local presente = AUREA.GetPlayerByCitizenId(a.citizenid)
        out[#out + 1] = {
            numero = a.numero, nome = a.nome, citizenid = a.citizenid,
            codice = a.codice, sintomo = a.sintomo,
            attesa = math.floor((os.time() - a.arrivo) / 60),
            presente = presente ~= nil,
        }
    end
    rispondi(out)
end)

AUREA.Callback.Registra('osp:chiama', function(src, rispondi, numero)
    local g = AUREA.GetPlayer(src)
    if not medico(g) then return rispondi(false, 'Non sei in servizio.') end

    for n, a in ipairs(coda) do
        if a.numero == numero then
            table.remove(coda, n)

            local ticket = OSP.Triage.ticket[a.codice] or 0
            local paziente = AUREA.GetPlayerByCitizenId(a.citizenid)

            if ticket > 0 then
                AUREA.Denaro.SottraiOffline(a.citizenid, 'banca', ticket, 'ticket di pronto soccorso', true)
                TriggerEvent('aurea:fisco:incasso', 'ticket_sanitario', ticket, a.citizenid)
            end

            if paziente then
                TriggerClientEvent('aurea:ui:notifica', paziente.source, {
                    tipo = 'successo', icona = '🏥', durata = 14000,
                    titolo = ('Chiamato il numero %d'):format(a.numero),
                    testo = ticket > 0
                        and ('Presentati all\'ambulatorio. Ticket %s addebitato.'):format(U.Euro(ticket))
                        or 'Presentati all\'ambulatorio. Nessun ticket dovuto.',
                })
            end

            return rispondi(true, ('Chiamato %s (%s).'):format(a.nome, a.sintomo))
        end
    end
    rispondi(false, 'Numero non in coda.')
end)

-- ---------------------------------------------------------------------------
--  Esami
-- ---------------------------------------------------------------------------

--- Cosa dice l'esame. Tutto calcolato qui, niente inferito dal client.
local function esegui(esame, paziente)
    local ped = GetPlayerPed(paziente.source)
    local salute = math.max(0, GetEntityHealth(ped) - 100)

    if esame.rivela == 'salute' then
        return {
            positivo = salute < 100,
            testo = ('Emoglobina e formula compatibili con %s. Valore di riferimento dello stato generale: %d su 100.')
                :format(salute >= 95 and 'un quadro nella norma'
                    or (salute >= 60 and 'un quadro alterato ma stabile' or 'un quadro compromesso'), salute),
        }
    end

    if esame.rivela == 'alcol' then
        -- Lo stato "alcol" va da 0 a 100; il tasso ematico si legge come
        -- grammi per litro, che è quello che conta per l'art. 186 CdS
        local grado = (paziente.stato and paziente.stato.alcol) or 0
        local tasso = U.Round(grado / 50.0, 2)

        return {
            positivo = tasso >= (esame.segnalaOltre or 0.5),
            valore = tasso,
            testo = tasso < 0.5
                and ('Alcolemia %.2f g/l: sotto il limite di legge.'):format(tasso)
                or ('Alcolemia %.2f g/l. %s'):format(tasso,
                    tasso >= 1.5 and 'Terza fascia dell\'art. 186 CdS.'
                    or (tasso >= 0.8 and 'Seconda fascia dell\'art. 186 CdS: è reato.'
                        or 'Prima fascia dell\'art. 186 CdS: illecito amministrativo.')),
        }
    end

    if esame.rivela == 'sostanze' then
        local trovate, dubbie = {}, {}
        local ora = os.time()

        for sostanza, scadenza in pairs(assunzioni[paziente.citizenid] or {}) do
            if scadenza > ora then
                local dati = AUREA.Item[sostanza]
                local etichetta = dati and dati.etichetta or sostanza
                local minutiResidui = math.floor((scadenza - ora) / 60)
                if minutiResidui <= OSP.Tossicologia.sogliaCerta then
                    dubbie[#dubbie + 1] = etichetta
                else
                    trovate[#trovate + 1] = etichetta
                end
            end
        end

        if #trovate == 0 and #dubbie == 0 then
            return { positivo = false, testo = 'Screening tossicologico negativo su tutte le classi ricercate.' }
        end

        local parti = {}
        if #trovate > 0 then
            parti[#parti + 1] = ('Positivo per: %s.'):format(table.concat(trovate, ', '))
        end
        if #dubbie > 0 then
            parti[#parti + 1] = ('Tracce al limite della soglia per: %s. Da confermare con esame di secondo livello.')
                :format(table.concat(dubbie, ', '))
        end

        return { positivo = #trovate > 0, testo = table.concat(parti, ' ') }
    end

    if esame.rivela == 'ferite' or esame.rivela == 'ferite_dettaglio' then
        local riga = MySQL.scalar.await('SELECT dati FROM ferite WHERE citizenid = ? LIMIT 1',
            { paziente.citizenid })
        local lesioni = riga and json.decode(riga) or {}

        local elenco = {}
        for parte, dati in pairs(lesioni) do
            if type(dati) == 'table' and (dati.gravita or 0) > 0 then
                elenco[#elenco + 1] = esame.rivela == 'ferite_dettaglio'
                    and ('%s: %s di grado %d'):format(parte, dati.tipo or 'lesione', dati.gravita)
                    or tostring(parte)
            end
        end

        if #elenco == 0 then
            return { positivo = false,
                     testo = salute >= 95
                         and 'Nessuna lesione ossea né corpo estraneo radiopaco.'
                         or 'Nessuna lesione ossea. Il quadro alterato non ha origine traumatica.' }
        end

        return {
            positivo = true,
            testo = ('Alterazioni rilevate a carico di: %s.'):format(table.concat(elenco, '; ')),
        }
    end

    return { positivo = false, testo = 'Esame non refertabile.' }
end

AUREA.Callback.Registra('osp:esame', function(src, rispondi, idEsame, pazienteSrc)
    local g = AUREA.GetPlayer(src)
    if not medico(g) then return rispondi(false, 'Non sei in servizio.') end

    local esame = OSP.GetEsame(idEsame)
    if not esame then return rispondi(false, 'Esame non previsto.') end

    if not OSP.InReparto(GetEntityCoords(GetPlayerPed(src)), esame.reparto) then
        return rispondi(false, ('Questo esame si esegue in %s.'):format(OSP.GetReparto(esame.reparto).nome))
    end

    local paziente = AUREA.GetPlayer(tonumber(pazienteSrc))
    if not paziente then return rispondi(false, 'Paziente non presente.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(paziente.source))) > 5.0 then
        return rispondi(false, 'Il paziente deve essere in reparto con te.')
    end

    rispondi(true, esame.durata, paziente.source, paziente:NomeCompleto())
end)

AUREA.Callback.Registra('osp:concludiEsame', function(src, rispondi, idEsame, pazienteSrc)
    local g = AUREA.GetPlayer(src)
    if not medico(g) then return rispondi(false) end

    local esame = OSP.GetEsame(idEsame)
    local paziente = AUREA.GetPlayer(tonumber(pazienteSrc))
    if not esame or not paziente then return rispondi(false, 'Esame interrotto.') end

    local esito = esegui(esame, paziente)

    if esame.ticket > 0 then
        AUREA.Denaro.SottraiOffline(paziente.citizenid, 'banca', esame.ticket,
            ('ticket: %s'):format(esame.nome), true)
        TriggerEvent('aurea:fisco:incasso', 'ticket_sanitario', esame.ticket, paziente.citizenid)
    end

    MySQL.insert('INSERT INTO cartelle_cliniche (citizenid, diagnosi, terapia, medico, ticket) VALUES (?, ?, ?, ?, ?)', {
        paziente.citizenid, esame.nome, esito.testo, g:NomeCompleto(), esame.ticket,
    })

    -- Il referto lo vedono il medico e il paziente. Nessun altro.
    TriggerClientEvent('osp:referto', paziente.source, {
        nome = esame.nome, icona = esame.icona, testo = esito.testo,
        positivo = esito.positivo, medico = g:NomeCompleto(),
    })

    -- Quando il referto è anche un fatto di rilievo penale, l'informativa
    -- parte: il medico è pubblico ufficiale e ha l'obbligo di referto
    -- (art. 365 c.p.). Non è una scelta del giocatore.
    if esito.positivo and (esame.segnala or (esame.segnalaOltre and (esito.valore or 0) >= esame.segnalaOltre)) then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'avviso', icona = '📄', durata = 16000,
            titolo = 'Referto sanitario trasmesso',
            testo = ('%s — %s: %s'):format(paziente:NomeCompleto(), esame.nome, esito.testo),
        }, true)
    end

    AUREA.Log('sanita', 'info', g, ('%s su %s: %s'):format(esame.nome, paziente:NomeCompleto(),
        esito.positivo and 'positivo' or 'negativo'))

    rispondi(true, esito.testo, esito.positivo)
end)

-- ---------------------------------------------------------------------------
--  Cartella clinica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('osp:cartella', function(src, rispondi, citizenid)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    -- Ognuno vede la propria. Quella altrui la vede solo il medico.
    local bersaglio = citizenid or g.citizenid
    if bersaglio ~= g.citizenid and not medico(g, OSP.GradoMedico) then
        return rispondi({}, 'La cartella clinica altrui è coperta dal segreto.')
    end

    local righe = MySQL.query.await([[
        SELECT diagnosi, terapia, medico, ticket, data
        FROM cartelle_cliniche WHERE citizenid = ?
        ORDER BY data DESC LIMIT 30
    ]], { bersaglio })

    rispondi(righe or {})
end)

-- ---------------------------------------------------------------------------
--  Certificazioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('osp:certifica', function(src, rispondi, idCertificato, pazienteSrc)
    local g = AUREA.GetPlayer(src)
    if not medico(g, OSP.GradoMedico) then
        return rispondi(false, 'Le certificazioni le firma il medico, non l\'infermiere di turno.')
    end

    local cert = OSP.GetCertificato(idCertificato)
    if not cert then return rispondi(false, 'Certificato non previsto.') end

    if not OSP.InReparto(GetEntityCoords(GetPlayerPed(src)), 'ambulatorio') then
        return rispondi(false, 'Le certificazioni si rilasciano in ambulatorio.')
    end

    local paziente = AUREA.GetPlayer(tonumber(pazienteSrc))
    if not paziente then return rispondi(false, 'Paziente non presente.') end

    -- Gli accertamenti richiesti devono essere stati fatti, e negativi
    for _, idEsame in ipairs(cert.richiedeEsami) do
        local esame = OSP.GetEsame(idEsame)
        local riga = MySQL.single.await([[
            SELECT terapia FROM cartelle_cliniche
            WHERE citizenid = ? AND diagnosi = ? AND data > DATE_SUB(NOW(), INTERVAL 3 HOUR)
            ORDER BY data DESC LIMIT 1
        ]], { paziente.citizenid, esame.nome })

        if not riga then
            return rispondi(false, ('Manca un accertamento recente: %s.'):format(esame.nome))
        end

        local esito = esegui(esame, paziente)
        if esito.positivo then
            return rispondi(false, ('Non si può certificare l\'idoneità: %s risulta alterato. %s')
                :format(esame.nome, esito.testo))
        end
    end

    if not paziente:SottraiOvunque(cert.costo, ('onorario: %s'):format(cert.nome)) then
        return rispondi(false, ('Il paziente non copre l\'onorario di %s.'):format(U.Euro(cert.costo)))
    end

    rispondi(true, cert.durata, paziente.source, paziente:NomeCompleto())
end)

AUREA.Callback.Registra('osp:concludiCertificato', function(src, rispondi, idCertificato, pazienteSrc)
    local g = AUREA.GetPlayer(src)
    if not medico(g, OSP.GradoMedico) then return rispondi(false) end

    local cert = OSP.GetCertificato(idCertificato)
    local paziente = AUREA.GetPlayer(tonumber(pazienteSrc))
    if not cert or not paziente then return rispondi(false, 'Rilascio interrotto.') end

    local inv = exports.aurea_inventory:Inventario(paziente.citizenid)
    local scadenza = U.DataPiuGiorni(cert.validitaGiorni)

    if not inv:Aggiungi(cert.item, 1, {
        tipoCertificato = cert.tipo,
        nomeCertificato = cert.nome,
        intestatario = paziente:NomeCompleto(),
        medico = g:NomeCompleto(),
        rilasciato = U.DataIT(os.time()),
        scadenza = scadenza,
    }) then
        return rispondi(false, 'Il paziente non ha spazio per il documento.')
    end

    TriggerClientEvent('inv:aggiorna', paziente.source, inv:Pacchetto())

    g:Aggiungi('banca', math.floor(cert.costo * 0.4), 'onorario per certificazione')
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(cert.costo * 0.6), paziente.citizenid)

    MySQL.insert('INSERT INTO cartelle_cliniche (citizenid, diagnosi, terapia, medico, ticket) VALUES (?, ?, ?, ?, ?)', {
        paziente.citizenid, cert.nome, ('Rilasciato, valido fino al %s.'):format(scadenza),
        g:NomeCompleto(), cert.costo,
    })

    TriggerClientEvent('aurea:ui:notifica', paziente.source, {
        tipo = 'successo', icona = '📋', durata = 15000,
        titolo = cert.nome,
        testo = ('Rilasciato da %s. Valido fino al %s.'):format(g:NomeCompleto(), scadenza),
    })

    AUREA.Log('sanita', 'info', g, ('ha rilasciato %s a %s'):format(cert.nome, paziente:NomeCompleto()))
    rispondi(true, ('%s rilasciato a %s.'):format(cert.nome, paziente:NomeCompleto()))
end)

--- Serve alle altre risorse: il certificato è valido?
exports('CertificatoValido', function(citizenid, tipo)
    local inv = exports.aurea_inventory:Inventario(citizenid)
    if not inv then return false end

    for _, riga in ipairs(inv:Pacchetto().item or {}) do
        if riga.nome == 'certificato_medico' and riga.metadata
            and riga.metadata.tipoCertificato == tipo then
            return true, riga.metadata.scadenza
        end
    end
    return false
end)

-- ---------------------------------------------------------------------------
--  Obitorio e riscontro diagnostico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('osp:salme', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not medico(g, OSP.GradoLegale) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT d.id, d.citizenid, d.nome, d.morto_il, d.epitaffio
        FROM defunti d
        LEFT JOIN riscontri r ON r.citizenid = d.citizenid
        WHERE r.id IS NULL
        ORDER BY d.morto_il DESC LIMIT 20
    ]])
    rispondi(righe or {})
end)

AUREA.Callback.Registra('osp:riscontro', function(src, rispondi, citizenid)
    local g = AUREA.GetPlayer(src)
    if not medico(g, OSP.GradoLegale) then
        return rispondi(false, 'Il riscontro diagnostico lo esegue il medico legale.')
    end

    if not OSP.InReparto(GetEntityCoords(GetPlayerPed(src)), 'obitorio') then
        return rispondi(false, 'Devi essere in obitorio.')
    end

    local defunto = MySQL.single.await('SELECT nome FROM defunti WHERE citizenid = ? LIMIT 1', { citizenid })
    if not defunto then return rispondi(false, 'Nessuna salma con quel codice.') end

    rispondi(true, OSP.Obitorio.durata, defunto.nome)
end)

AUREA.Callback.Registra('osp:concludiRiscontro', function(src, rispondi, citizenid)
    local g = AUREA.GetPlayer(src)
    if not medico(g, OSP.GradoLegale) then return rispondi(false) end

    local defunto = MySQL.single.await('SELECT nome FROM defunti WHERE citizenid = ? LIMIT 1', { citizenid })
    if not defunto then return rispondi(false, 'Salma non più in obitorio.') end

    -- La causa della morte si ricostruisce da quello che era già scritto:
    -- l'ultima cartella clinica e i fascicoli aperti nelle ore precedenti
    local ultimaFerita = MySQL.single.await([[
        SELECT diagnosi, terapia FROM cartelle_cliniche
        WHERE citizenid = ? ORDER BY data DESC LIMIT 1
    ]], { citizenid })

    local violenta = MySQL.scalar.await([[
        SELECT COUNT(*) FROM casellario
        WHERE citizenid = ? AND articolo LIKE '%%575%%'
    ]], { citizenid }) or 0

    local sostanze = assunzioni[citizenid] and next(assunzioni[citizenid]) ~= nil

    local causa
    if violenta > 0 then
        causa = 'Morte violenta. Lesioni non compatibili con evento accidentale.'
    elseif sostanze then
        causa = 'Quadro compatibile con intossicazione acuta da sostanze stupefacenti.'
    elseif ultimaFerita and ultimaFerita.terapia and ultimaFerita.terapia:find('Alterazioni') then
        causa = ('Esiti traumatici documentati in vita. %s'):format(ultimaFerita.terapia)
    else
        causa = 'Nessun elemento indicativo di causa violenta. Morte da causa naturale.'
    end

    local violentaEsito = violenta > 0 or sostanze

    MySQL.insert.await([[
        INSERT INTO riscontri (citizenid, nome, causa, violenta, medico_legale)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, defunto.nome, causa, violentaEsito and 1 or 0, g:NomeCompleto() })

    g:Aggiungi('banca', OSP.Obitorio.onorario, 'riscontro diagnostico')

    if violentaEsito then
        for _, lavoro in ipairs(OSP.Obitorio.avvisa) do
            exports.aurea_ui:NotificaLavoro(lavoro, {
                tipo = 'errore', icona = '⚰', durata = 20000,
                titolo = 'Informativa di reato — riscontro diagnostico',
                testo = ('%s: %s'):format(defunto.nome, causa),
            }, true)
        end
    end

    AUREA.Log('sanita', 'avviso', g, ('riscontro diagnostico su %s: %s'):format(defunto.nome, causa))
    rispondi(true, causa, violentaEsito)
end)

AUREA.Callback.Registra('osp:riscontriEmessi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end
    if not medico(g) and not U.Contiene({ 'carabinieri', 'polizia' }, g.lavoro.nome) then
        return rispondi({})
    end

    local righe = MySQL.query.await([[
        SELECT nome, causa, violenta, medico_legale, eseguito_il
        FROM riscontri ORDER BY eseguito_il DESC LIMIT 25
    ]])
    rispondi(righe or {})
end)

-- ---------------------------------------------------------------------------
--  Pulizia della coda
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(300000)
        for n = #coda, 1, -1 do
            -- Chi non c'è più, o aspetta da più di un'ora, esce dalla coda
            if not AUREA.GetPlayerByCitizenId(coda[n].citizenid)
                or (os.time() - coda[n].arrivo) > 3600 then
                table.remove(coda, n)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App sul telefono: il fascicolo sanitario
--
--  Solo la propria cartella. Quella altrui è coperta dal segreto e si
--  consulta in ambulatorio, dove il medico deve esserci di persona.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'sanita',
    nome = 'Fascicolo',
    icona = '🩺',
    colore = 'linear-gradient(150deg,#d1443f,#8d2724)',
    ordine = 130,

    schermata = function(g)
        local voci = {}

        for _, r in ipairs(MySQL.query.await([[
            SELECT diagnosi, terapia, medico, ticket, data
            FROM cartelle_cliniche WHERE citizenid = ?
            ORDER BY data DESC LIMIT 25
        ]], { g.citizenid }) or {}) do
            voci[#voci + 1] = {
                icona = '📄',
                titolo = r.diagnosi,
                sottotitolo = ('%s\nRefertato da %s'):format(
                    r.terapia or '', r.medico or 'n.d.'),
                valore = (r.ticket or 0) > 0 and U.Euro(r.ticket) or nil,
                inerte = true,
            }
        end

        if #voci == 0 then
            voci[1] = { icona = '🩺', titolo = 'Fascicolo vuoto',
                        sottotitolo = 'Nessun referto a tuo nome.', inerte = true }
        end

        return {
            tipo = 'lista',
            sottotitolo = 'Referti e certificazioni a tuo nome',
            voci = voci,
        }
    end,
})
