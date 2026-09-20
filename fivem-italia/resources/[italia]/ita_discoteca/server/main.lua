--[[
    AUREA · Locali notturni (server)

    Quattro controlli in fila prima di aprire, e ognuno chiede a una
    risorsa diversa. Se una di quelle risorse è ferma, il suo controllo
    salta: è il motivo per cui ogni chiamata è protetta. Un server senza
    Questura non è un server in cui le discoteche non aprono — è un
    server in cui quella licenza non esiste.
]]

local U = AUREA.Util
local dentro = {}       -- [codiceLocale] = { [citizenid] = true }

local function conta(codice)
    local n = 0
    for _ in pairs(dentro[codice] or {}) do n = n + 1 end
    return n
end

local function personale(g, grado)
    return g and g.lavoro.nome == DISCO.Lavoro and g.lavoro.servizio
       and g.lavoro.grado >= (grado or 0)
end

-- ---------------------------------------------------------------------------
--  Seminare i locali al primo avvio
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    for _, l in ipairs(DISCO.Locali) do
        MySQL.query.await([[
            INSERT IGNORE INTO locali_notturni (codice, nome, capienza) VALUES (?, ?, ?)
        ]], { l.codice, l.nome, l.capienza })
        dentro[l.codice] = {}
    end
end)

-- ---------------------------------------------------------------------------
--  I quattro controlli
-- ---------------------------------------------------------------------------
local function licenzaValida(codice)
    local r = MySQL.single.await([[
        SELECT licenza_scadenza, sospeso, motivo_sospensione FROM locali_notturni
        WHERE codice = ? AND licenza_scadenza IS NOT NULL AND licenza_scadenza >= CURDATE()
    ]], { codice })
    if not r then return false, 'la licenza di pubblico spettacolo manca o è scaduta (Questura)' end
    if r.sospeso == 1 then
        return false, ('la licenza è sospesa: %s'):format(r.motivo_sospensione or 'provvedimento')
    end
    return true
end

local function permessoSiae(codice)
    local ok, valido = pcall(function()
        return exports.ita_siae:PermessoValido(codice, 'trattenimento_danzante')
    end)
    if not ok then return true end      -- SIAE ferma: il controllo non esiste
    if valido ~= true then
        return false, 'manca il permesso SIAE per trattenimento danzante'
    end
    return true
end

--- Un addetto ai servizi di controllo in servizio, iscritto all'elenco
--- prefettizio, presente al locale.
local function filtroPresente(locale)
    for _, g in pairs(AUREA.GetGiocatoriPerLavoro(DISCO.Lavoro, true) or {}) do
        if g.lavoro.grado >= DISCO.Gestione.gradoFiltro
           and #(GetEntityCoords(GetPlayerPed(g.source)) - locale.ingresso) <= 40.0 then
            local ok, iscritto = pcall(function()
                return exports.ita_prefettura:IscrittoElenco(g.citizenid)
            end)
            if not ok or iscritto == true then return g end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Gestione del locale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('disco:stato', function(src, rispondi, codice)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local locale = DISCO.GetLocale(codice)
    if not locale then return rispondi(nil) end

    local riga = MySQL.single.await([[
        SELECT nome, gestore, capienza, licenza_scadenza, sospeso, motivo_sospensione,
               DATEDIFF(licenza_scadenza, CURDATE()) AS giorniLicenza
        FROM locali_notturni WHERE codice = ?
    ]], { codice })
    if not riga then return rispondi(nil) end

    local serata = MySQL.single.await([[
        SELECT id, nome, ingresso, presenze, picco, incasso,
               TIMESTAMPDIFF(MINUTE, aperta_il, NOW()) AS minuti
        FROM discoteca_serate WHERE locale = ? AND stato = 'aperta' LIMIT 1
    ]], { codice })

    local _, motivoLicenza = licenzaValida(codice)
    local _, motivoSiae = permessoSiae(codice)
    local filtro = filtroPresente(locale)

    rispondi({
        codice = codice,
        nome = riga.nome,
        capienza = riga.capienza,
        presenti = conta(codice),
        gestore = riga.gestore,
        sonoGestore = riga.gestore == g.citizenid,
        licenzaOk = motivoLicenza == nil,
        motivoLicenza = motivoLicenza,
        siaeOk = motivoSiae == nil,
        motivoSiae = motivoSiae,
        filtro = filtro and filtro:NomeCompleto() or nil,
        serata = serata,
        costoSubentro = DISCO.Gestione.costoSubentro,
    })
end)

AUREA.Callback.Registra('disco:subentra', function(src, rispondi, codice)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not personale(g, DISCO.Gestione.gradoGestore) then
        return rispondi(false, 'La gestione la prende chi è gestore, in servizio.')
    end

    local locale = DISCO.GetLocale(codice)
    if not locale then return rispondi(false, 'Locale inesistente.') end

    local attuale = MySQL.scalar.await('SELECT gestore FROM locali_notturni WHERE codice = ?', { codice })
    if attuale == g.citizenid then return rispondi(false, 'Lo gestisci già tu.') end

    if not g:Sottrai('banca', DISCO.Gestione.costoSubentro, ('subentro nella gestione di %s'):format(locale.nome)) then
        return rispondi(false, ('Servono %s sul conto.'):format(U.Euro(DISCO.Gestione.costoSubentro)))
    end
    if attuale then
        AUREA.Denaro.AggiungiOffline(attuale, 'banca',
            math.floor(DISCO.Gestione.costoSubentro * 0.6), 'cessione della gestione')
    end
    TriggerEvent('aurea:fisco:incasso', 'cessioni_attivita',
        math.floor(DISCO.Gestione.costoSubentro * 0.4), g.citizenid)

    MySQL.update.await('UPDATE locali_notturni SET gestore = ? WHERE codice = ?', { g.citizenid, codice })

    AUREA.Log('economia', 'info', g, ('subentra nella gestione di %s'):format(locale.nome))
    rispondi(true, ('Sei il gestore di %s.\nOra serve la licenza in Questura e il permesso SIAE.')
        :format(locale.nome))
end)

-- ---------------------------------------------------------------------------
--  Aprire la serata
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('disco:apri', function(src, rispondi, codice, nome, ingresso)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local locale = DISCO.GetLocale(codice)
    if not locale then return rispondi(false, 'Locale inesistente.') end

    local riga = MySQL.single.await('SELECT gestore FROM locali_notturni WHERE codice = ?', { codice })
    if not riga or riga.gestore ~= g.citizenid then
        return rispondi(false, 'La serata la apre il gestore del locale.')
    end

    local aperta = MySQL.scalar.await(
        'SELECT id FROM discoteca_serate WHERE locale = ? AND stato = ?', { codice, 'aperta' })
    if aperta then return rispondi(false, 'C\'è già una serata in corso.') end

    -- 1. La licenza
    local ok1, motivo1 = licenzaValida(codice)
    if not ok1 then return rispondi(false, ('Non si apre: %s.'):format(motivo1)) end

    -- 2. La SIAE
    local ok2, motivo2 = permessoSiae(codice)
    if not ok2 then return rispondi(false, ('Non si apre: %s.'):format(motivo2)) end

    -- 3. Il filtro all'ingresso
    if DISCO.Serata.richiedeFiltro and not filtroPresente(locale) then
        return rispondi(false, 'Non si apre: serve un addetto ai servizi di controllo in servizio e iscritto all\'elenco della Prefettura.')
    end

    ingresso = math.floor(tonumber(ingresso) or DISCO.Serata.ingressoMinimo)
    ingresso = U.Clamp(ingresso, DISCO.Serata.ingressoMinimo, DISCO.Serata.ingressoMassimo)

    nome = tostring(nome or 'Serata'):sub(1, 60)

    local id = MySQL.insert.await([[
        INSERT INTO discoteca_serate (locale, nome, organizzata_da, ingresso)
        VALUES (?, ?, ?, ?)
    ]], { codice, nome, g.citizenid, ingresso })

    dentro[codice] = {}

    -- La serata finisce sul borderò della SIAE come tutto il resto
    TriggerEvent('aurea:siae:serata', codice, g.citizenid, nome)

    exports.aurea_ui:NotificaTutti({
        tipo = 'info', icona = '🪩', durata = 18000,
        titolo = ('%s — %s'):format(locale.nome, nome),
        testo = ('Serata aperta. Ingresso %s, capienza %d.'):format(U.Euro(ingresso), locale.capienza),
    })

    AUREA.Log('economia', 'info', g, ('serata "%s" aperta a %s'):format(nome, locale.nome))

    -- Chiusura automatica
    CreateThread(function()
        Wait(DISCO.Serata.minutiMassimi * 60000)
        local ancora = MySQL.scalar.await(
            'SELECT id FROM discoteca_serate WHERE id = ? AND stato = ?', { id, 'aperta' })
        if ancora then
            MySQL.update.await(
                'UPDATE discoteca_serate SET stato = ?, chiusa_il = NOW() WHERE id = ?', { 'chiusa', id })
            dentro[codice] = {}
        end
    end)

    rispondi(true, ('Serata "%s" aperta. Ingresso %s.'):format(nome, U.Euro(ingresso)))
end)

-- ---------------------------------------------------------------------------
--  La porta
--
--  Il filtro decide, ma su due cose non decide: il DASPO e la capienza.
--  Quelle le decide il server, e chi prova a forzarle esce dall'elenco.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('disco:ammetti', function(src, rispondi, sorgenteCliente)
    local g = AUREA.GetPlayer(src)
    if not personale(g, DISCO.Gestione.gradoFiltro) then
        return rispondi(false, 'Il filtro lo fa un addetto ai servizi di controllo in servizio.')
    end

    local locale = DISCO.LocaleVicino(GetEntityCoords(GetPlayerPed(src)), 20.0)
    if not locale then return rispondi(false, 'Non sei alla porta di nessun locale.') end

    local iscrittoOk, iscritto = pcall(function()
        return exports.ita_prefettura:IscrittoElenco(g.citizenid)
    end)
    if iscrittoOk and iscritto == false then
        return rispondi(false, 'Non risulti iscritto all\'elenco prefettizio: il filtro non puoi farlo.')
    end

    local cliente = AUREA.GetPlayer(tonumber(sorgenteCliente))
    if not cliente then return rispondi(false, 'La persona non è collegata.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(cliente.source))) > 4.0 then
        return rispondi(false, 'È troppo lontano.')
    end

    local serata = MySQL.single.await([[
        SELECT id, ingresso, presenze, picco FROM discoteca_serate
        WHERE locale = ? AND stato = 'aperta' LIMIT 1
    ]], { locale.codice })
    if not serata then return rispondi(false, 'Non c\'è nessuna serata in corso qui.') end

    dentro[locale.codice] = dentro[locale.codice] or {}
    if dentro[locale.codice][cliente.citizenid] then
        return rispondi(false, 'È già dentro.')
    end

    -- Il DASPO: non è una valutazione, è un divieto
    local okD, daspo = pcall(function()
        return exports.ita_questura:DaspoAttivo(cliente.citizenid, nil)
    end)
    if okD and daspo then
        MySQL.insert.await([[
            INSERT INTO discoteca_ingressi (serata_id, citizenid, respinto, motivo)
            VALUES (?, ?, 1, ?)
        ]], { serata.id, cliente.citizenid, 'DASPO in corso' })

        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'errore', icona = '🚷', durata = 14000,
            titolo = 'Ingresso negato',
            testo = ('Risulta a tuo carico un divieto di accesso: %s.'):format(daspo.luogo or 'provvedimento'),
        })
        return rispondi(false, ('Respinto: ha un DASPO (%s).'):format(daspo.luogo or '—'))
    end

    -- La capienza
    local presenti = conta(locale.codice)
    if presenti >= math.floor(locale.capienza * DISCO.Serata.sogliaPienone) then
        MySQL.insert.await([[
            INSERT INTO discoteca_ingressi (serata_id, citizenid, respinto, motivo)
            VALUES (?, ?, 1, 'capienza raggiunta')
        ]], { serata.id, cliente.citizenid })
        return rispondi(false, ('Dentro ci sono già %d persone su %d: non entra nessun altro.')
            :format(presenti, locale.capienza))
    end

    if not cliente:SottraiOvunque(serata.ingresso, ('ingresso %s'):format(locale.nome)) then
        return rispondi(false, ('Non ha %s per l\'ingresso.'):format(U.Euro(serata.ingresso)))
    end

    dentro[locale.codice][cliente.citizenid] = true
    local ora = conta(locale.codice)

    MySQL.insert.await('INSERT INTO discoteca_ingressi (serata_id, citizenid) VALUES (?, ?)',
        { serata.id, cliente.citizenid })
    MySQL.update.await([[
        UPDATE discoteca_serate
        SET presenze = presenze + 1, incasso = incasso + ?, picco = GREATEST(picco, ?)
        WHERE id = ?
    ]], { serata.ingresso, ora, serata.id })

    local quota = math.floor(serata.ingresso * DISCO.Serata.quotaCassa)
    pcall(function()
        exports.aurea_azienda:VersaInCassa(DISCO.Lavoro, quota, ('ingressi %s'):format(locale.nome))
    end)
    g:Aggiungi('contanti', serata.ingresso - quota, 'quota sugli ingressi')

    TriggerClientEvent('aurea:ui:notifica', cliente.source, {
        tipo = 'successo', icona = '🪩', durata = 8000,
        titolo = locale.nome, testo = ('Ingresso pagato: %s.'):format(U.Euro(serata.ingresso)),
    })

    rispondi(true, ('Dentro. %d su %d.'):format(ora, locale.capienza))
end)

AUREA.Callback.Registra('disco:esci', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    for codice, elenco in pairs(dentro) do
        if elenco[g.citizenid] then
            elenco[g.citizenid] = nil
            return rispondi(true, 'Uscito.')
        end
    end
    rispondi(false, 'Non risulti dentro a nessun locale.')
end)

AddEventHandler('playerDropped', function()
    local g = AUREA.GetPlayer(source)
    if not g then return end
    for _, elenco in pairs(dentro) do elenco[g.citizenid] = nil end
end)

-- ---------------------------------------------------------------------------
--  Il controllo delle forze dell'ordine
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('disco:controllo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio or not U.Contiene(DISCO.Controllo.entiAbilitati, g.lavoro.nome) then
        return rispondi(false, 'Il controllo lo fanno le forze dell\'ordine in servizio.')
    end

    local locale = DISCO.LocaleVicino(GetEntityCoords(GetPlayerPed(src)), 45.0)
    if not locale then return rispondi(false, 'Qui non c\'è nessun locale censito.') end

    local serata = MySQL.single.await(
        'SELECT id, nome, organizzata_da FROM discoteca_serate WHERE locale = ? AND stato = ?',
        { locale.codice, 'aperta' })

    local presenti = conta(locale.codice)
    local eccedenza = math.max(0, presenti - locale.capienza - DISCO.Serata.tolleranzaCapienza)
    local filtro = filtroPresente(locale)
    local okLic, motivoLic = licenzaValida(locale.codice)

    local rilievi, sanzione, sospeso = {}, 0, false

    if not serata then
        rilievi[#rilievi + 1] = 'nessuna serata dichiarata'
    end

    if eccedenza > 0 then
        sanzione = sanzione + eccedenza * DISCO.Controllo.sanzionePerEccedenza
        rilievi[#rilievi + 1] = ('%d persone oltre la capienza di %d'):format(eccedenza, locale.capienza)
        sospeso = true
    end

    if DISCO.Controllo.sospendiSenzaFiltro and serata and not filtro then
        rilievi[#rilievi + 1] = 'nessun addetto ai servizi di controllo iscritto in servizio'
        sospeso = true
    end

    if not okLic then
        rilievi[#rilievi + 1] = motivoLic
        sospeso = true
    end

    if #rilievi == 0 then
        return rispondi(true, { locale = locale.nome, presenti = presenti, rilievi = {}, sanzione = 0 })
    end

    local gestore = MySQL.scalar.await('SELECT gestore FROM locali_notturni WHERE codice = ?',
        { locale.codice })

    if sospeso then
        MySQL.update.await([[
            UPDATE locali_notturni SET sospeso = 1, motivo_sospensione = ? WHERE codice = ?
        ]], { table.concat(rilievi, '; '):sub(1, 160), locale.codice })

        if serata then
            MySQL.update.await(
                'UPDATE discoteca_serate SET stato = ?, chiusa_il = NOW() WHERE id = ?',
                { 'interrotta', serata.id })
            dentro[locale.codice] = {}
        end
    end

    if sanzione > 0 and gestore then
        AUREA.Denaro.SottraiOffline(gestore, 'banca', sanzione, 'sanzione per sovraffollamento', true)
        TriggerEvent('aurea:fisco:incasso', 'sanzioni_tulps', sanzione, gestore)
    end

    -- Il buttafuori che ha fatto entrare più gente della capienza esce
    -- dall'elenco: è il provvedimento vero, non la multa.
    if eccedenza > 0 and filtro then
        TriggerEvent('aurea:prefettura:sospendiElenco', filtro.citizenid,
            ('sovraffollamento accertato a %s'):format(locale.nome))
    end

    if gestore then
        TriggerEvent('aurea:telefono:messaggioSistema', gestore, 'Questura',
            ('Controllo a %s: %s. Licenza sospesa%s.')
                :format(locale.nome, table.concat(rilievi, '; '),
                        sanzione > 0 and (', sanzione ' .. U.Euro(sanzione)) or ''))
    end

    AUREA.Log('giustizia', 'avviso', g, ('controllo a %s: %s'):format(locale.nome, table.concat(rilievi, '; ')))

    rispondi(true, {
        locale = locale.nome, presenti = presenti,
        rilievi = rilievi, sanzione = sanzione, sospeso = sospeso,
    })
end)
