--[[
    AUREA · Previdenza sociale (server)

    Tutto quello che conta sta qui. Il client apre uno sportello e mostra
    dei numeri: non li calcola, non li decide e non può alterarli. Un
    client modificato può chiedere la pensione quanto vuole — se le
    settimane non ci sono, la risposta è no.

    Il montante è una scrittura contabile, non un deposito: cresce con le
    buste paga e serve solo a calcolare il rateo. Le prestazioni le paga
    l'erario. È il sistema a ripartizione, ed è il motivo per cui qui non
    esiste nessun fondo da cui prelevare.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Posizione contributiva
-- ---------------------------------------------------------------------------

--- Legge (creandola se non c'è) la posizione di un assicurato.
local function posizione(citizenid)
    local p = MySQL.single.await('SELECT * FROM previdenza_posizioni WHERE citizenid = ?', { citizenid })
    if p then return p end

    MySQL.insert.await('INSERT IGNORE INTO previdenza_posizioni (citizenid) VALUES (?)', { citizenid })
    return MySQL.single.await('SELECT * FROM previdenza_posizioni WHERE citizenid = ?', { citizenid })
        or { citizenid = citizenid, montante = 0, settimane = 0, ultimo_imponibile = 0, pensionato = 0 }
end

--- Accredita una busta paga alla posizione.
---@param citizenid string
---@param imponibile integer centesimi lordi della busta
local function accredita(citizenid, imponibile)
    imponibile = math.floor(tonumber(imponibile) or 0)
    if imponibile <= 0 then return end

    local quota = math.floor(imponibile * PRE.Contributi.aliquotaComputo)

    -- Sotto il minimale la settimana non matura: un lavoretto da pochi
    -- euro non deve costruire una carriera.
    local settimane = imponibile >= PRE.Contributi.minimaleSettimanale
        and PRE.Contributi.settimanePerBusta or 0

    MySQL.query.await([[
        INSERT INTO previdenza_posizioni (citizenid, montante, settimane, ultimo_imponibile, ultimo_contributo)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            montante = montante + VALUES(montante),
            settimane = settimane + VALUES(settimane),
            ultimo_imponibile = VALUES(ultimo_imponibile),
            ultimo_contributo = NOW()
    ]], { citizenid, quota, settimane, imponibile })
end

--- L'evento che le buste paga chiamano. Un solo punto di ingresso.
AddEventHandler('aurea:previdenza:contributo', function(citizenid, imponibile)
    if type(citizenid) == 'string' then accredita(citizenid, imponibile) end
end)

-- ---------------------------------------------------------------------------
--  Prestazioni in corso
-- ---------------------------------------------------------------------------

local function prestazioneAperta(citizenid, tipo)
    if tipo then
        return MySQL.single.await(
            'SELECT * FROM previdenza_prestazioni WHERE citizenid = ? AND tipo = ? AND stato = ? LIMIT 1',
            { citizenid, tipo, 'aperta' })
    end
    return MySQL.query.await(
        'SELECT * FROM previdenza_prestazioni WHERE citizenid = ? AND stato = ? ORDER BY id DESC',
        { citizenid, 'aperta' }) or {}
end

local function apriPrestazione(citizenid, tipo, importo, ratei, dati)
    return MySQL.insert.await([[
        INSERT INTO previdenza_prestazioni (citizenid, tipo, stato, importo_rateo, ratei_residui, dati)
        VALUES (?, ?, 'aperta', ?, ?, ?)
    ]], { citizenid, tipo, math.floor(importo), math.floor(ratei), json.encode(dati or {}) })
end

local function chiudiPrestazione(id, stato, motivo)
    MySQL.update('UPDATE previdenza_prestazioni SET stato = ?, motivo = ?, chiusa_il = NOW() WHERE id = ?',
        { stato or 'chiusa', motivo, id })
end

--- Notifica chi è connesso, e gli lascia un SMS se non lo è.
local function avvisa(citizenid, notifica, sms)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, notifica)
    end
    if sms then
        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'INPS', sms)
    end
end

-- ---------------------------------------------------------------------------
--  Il ciclo che paga
--
--  Un solo thread per tutte le prestazioni: hanno cadenze diverse ma la
--  logica è identica — scala un rateo, paga, e quando finisce chiude.
-- ---------------------------------------------------------------------------
local CADENZA = {
    pensione   = PRE.Pensione.minuti,
    malattia   = PRE.Malattia.minuti,
    infortunio = PRE.Infortunio.minuti,
    naspi      = PRE.NASpI.minuti,
}

local function erogaRateo(p)
    local importo = p.importo_rateo

    -- Il décalage della NASpI: dopo qualche mese l'assegno cala
    if p.tipo == 'naspi' then
        local dati = json.decode(p.dati or '{}') or {}
        local erogati = (dati.erogati or 0)
        if erogati >= PRE.NASpI.decalageDopo then
            local scalini = erogati - PRE.NASpI.decalageDopo + 1
            importo = math.floor(importo * math.max(0.4, 1 - PRE.NASpI.decalage * scalini))
        end
        dati.erogati = erogati + 1
        MySQL.update('UPDATE previdenza_prestazioni SET dati = ? WHERE id = ?', { json.encode(dati), p.id })
    end

    if importo <= 0 then return chiudiPrestazione(p.id, 'chiusa', 'importo azzerato') end

    AUREA.Denaro.AggiungiOffline(p.citizenid, 'banca', importo, ('INPS — %s'):format(p.tipo))
    TriggerEvent('aurea:fisco:erogazione', 'previdenza', importo, p.citizenid)

    local residui = p.ratei_residui - 1
    MySQL.update('UPDATE previdenza_prestazioni SET ratei_residui = ?, ratei_erogati = ratei_erogati + 1 WHERE id = ?',
        { residui, p.id })

    local ETICHETTA = {
        pensione = 'Rateo di pensione', malattia = 'Indennità di malattia',
        infortunio = 'Indennità INAIL', naspi = 'NASpI',
    }

    avvisa(p.citizenid, {
        tipo = 'successo', icona = '🏛', durata = 9000,
        titolo = ETICHETTA[p.tipo] or 'Prestazione INPS',
        testo = residui >= 0 and p.tipo == 'pensione'
            and ('%s accreditati.'):format(U.Euro(importo))
            or ('%s accreditati. Ratei residui: %d.'):format(U.Euro(importo), math.max(0, residui)),
    })

    if p.tipo ~= 'pensione' and residui <= 0 then
        chiudiPrestazione(p.id, 'chiusa', 'ratei esauriti')
        avvisa(p.citizenid, {
            tipo = 'info', icona = '🏛', durata = 12000,
            titolo = 'Prestazione conclusa',
            testo = ('La tua %s è terminata.'):format(p.tipo),
        }, ('La prestazione %s si è conclusa. Ratei esauriti.'):format(p.tipo))
    end
end

CreateThread(function()
    Wait(60000)
    while true do
        Wait(60000)   -- si sveglia ogni minuto e guarda chi è scaduto

        local aperte = MySQL.query.await([[
            SELECT * FROM previdenza_prestazioni WHERE stato = 'aperta'
        ]]) or {}

        local adesso = os.time()
        for _, p in ipairs(aperte) do
            local minuti = CADENZA[p.tipo] or 30
            local dati = json.decode(p.dati or '{}') or {}
            local prossimo = dati.prossimo or 0

            if adesso >= prossimo then
                -- La pensione non si esaurisce mai: i ratei residui restano
                if p.tipo == 'pensione' then p.ratei_residui = 999999 end
                erogaRateo(p)

                local d = json.decode(
                    MySQL.scalar.await('SELECT dati FROM previdenza_prestazioni WHERE id = ?', { p.id }) or '{}') or {}
                d.prossimo = adesso + minuti * 60
                MySQL.update('UPDATE previdenza_prestazioni SET dati = ? WHERE id = ?', { json.encode(d), p.id })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  DURC
--
--  Irregolare per due motivi: debito contributivo iscritto a ruolo, o un
--  infortunio che il datore non ha denunciato. Il secondo è quello che
--  fa male davvero, perché senza DURC il cantiere non apre.
-- ---------------------------------------------------------------------------
local function durc(citizenid)
    local motivi = {}

    local ok, tributi = pcall(function() return exports.ita_fisco:DebitoFiscale(citizenid) end)
    local debitoInps = 0
    for _, t in ipairs(ok and tributi or {}) do
        if t.tipo == 'inps' or t.tipo == 'contributi' then
            debitoInps = debitoInps + (t.dovuto or t.importo or 0)
        end
    end
    if debitoInps >= PRE.DURC.sogliaDebito then
        motivi[#motivi + 1] = ('debito contributivo di %s'):format(U.Euro(debitoInps))
    end

    if PRE.DURC.infortunioOmessoBlocca then
        local omessi = MySQL.scalar.await([[
            SELECT COUNT(*) FROM previdenza_infortuni
            WHERE datore = ? AND denunciato = 0 AND scaduto = 1
        ]], { citizenid }) or 0
        if omessi > 0 then
            motivi[#motivi + 1] = ('%d infortuni non denunciati'):format(omessi)
        end
    end

    return #motivi == 0, motivi, debitoInps
end

--- DURCRegolare(citizenid) -> regolare, elenco dei motivi
exports('DURCRegolare', function(citizenid)
    local regolare, motivi = durc(citizenid)
    return regolare, motivi
end)

--- La posizione contributiva, per chi la deve mostrare (il telefono).
exports('Posizione', function(citizenid)
    local p = posizione(citizenid)
    local regolare, motivi = durc(citizenid)
    return {
        montante = p.montante, settimane = p.settimane,
        ultimoImponibile = p.ultimo_imponibile,
        pensionato = p.pensionato == 1,
        durc = regolare, motiviDurc = motivi,
        prestazioni = prestazioneAperta(citizenid),
    }
end)

-- ---------------------------------------------------------------------------
--  Sportello: la propria posizione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pre:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = posizione(g.citizenid)
    local stato, spiegazione = PRE.StatoRequisito(p.settimane)
    local regolare, motivi = durc(g.citizenid)

    rispondi({
        montante = p.montante,
        settimane = p.settimane,
        ultimoImponibile = p.ultimo_imponibile,
        pensionato = p.pensionato == 1,
        requisito = stato,
        spiegazione = spiegazione,
        rateoStimato = PRE.RateoPensione(p.montante, stato == 'anticipata'),
        durc = regolare,
        motiviDurc = motivi,
        prestazioni = prestazioneAperta(g.citizenid),
    })
end)

-- ---------------------------------------------------------------------------
--  Pensione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pre:pensione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local p = posizione(g.citizenid)
    if p.pensionato == 1 then return rispondi(false, 'Risulti già pensionato.') end

    local stato = PRE.StatoRequisito(p.settimane)
    if stato == 'non_maturato' then
        return rispondi(false, ('Non hai il requisito: %d settimane su %d.')
            :format(p.settimane, PRE.Pensione.settimaneAnticipata))
    end

    local anticipata = stato == 'anticipata'
    local rateo = PRE.RateoPensione(p.montante, anticipata)

    MySQL.update.await('UPDATE previdenza_posizioni SET pensionato = 1, decorrenza = NOW() WHERE citizenid = ?',
        { g.citizenid })

    g:ImpostaLavoro(PRE.Pensione.lavoro, 0)
    apriPrestazione(g.citizenid, 'pensione', rateo, 999999, { anticipata = anticipata })

    AUREA.Log('economia', 'info', g, ('è andato in pensione (%d settimane, rateo %s)')
        :format(p.settimane, U.Euro(rateo)))

    rispondi(true, ('Pensione liquidata: %s ogni %d minuti.%s')
        :format(U.Euro(rateo), PRE.Pensione.minuti,
                anticipata and ' Trattandosi di pensione anticipata, è ridotta.' or ''))
end)

--- Tornare al lavoro sospende la pensione: le due cose non stanno insieme.
AddEventHandler('aurea:lavoro:cambiato', function(src, nuovoLavoro)
    if nuovoLavoro == PRE.Pensione.lavoro then return end

    local g = AUREA.GetPlayer(src)
    if not g then return end
    local citizenid = g.citizenid

    local p = MySQL.single.await('SELECT pensionato FROM previdenza_posizioni WHERE citizenid = ?', { citizenid })
    if not p or p.pensionato ~= 1 then return end

    MySQL.update('UPDATE previdenza_posizioni SET pensionato = 0 WHERE citizenid = ?', { citizenid })

    local aperta = prestazioneAperta(citizenid, 'pensione')
    if aperta then
        chiudiPrestazione(aperta.id, 'sospesa', 'rientro al lavoro')
        avvisa(citizenid, {
            tipo = 'avviso', icona = '🏛', durata = 14000,
            titolo = 'Pensione sospesa',
            testo = 'Hai ripreso a lavorare: il trattamento è sospeso finché resti occupato.',
        }, 'Pensione sospesa per rientro al lavoro. Riprendi allo sportello quando cessi l\'attività.')
    end
end)

-- ---------------------------------------------------------------------------
--  Malattia
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pre:malattia', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if prestazioneAperta(g.citizenid, 'malattia') then
        return rispondi(false, 'Hai già una malattia in corso.')
    end

    local ok, valido = pcall(function()
        return exports.aurea_ospedale:CertificatoValido(g.citizenid, 'malattia')
    end)
    if not ok or not valido then
        return rispondi(false, 'Serve un certificato di malattia rilasciato da un medico.')
    end

    local p = posizione(g.citizenid)
    if p.ultimo_imponibile <= 0 then
        return rispondi(false, 'Non risultano contributi versati: non hai diritto all\'indennità.')
    end

    local rateo = math.floor(p.ultimo_imponibile * PRE.Malattia.quota)
    local ratei = PRE.Malattia.ratei - PRE.Malattia.carenza

    local id = apriPrestazione(g.citizenid, 'malattia', rateo, ratei, {
        prossimo = os.time() + PRE.Malattia.minuti * 60 * (PRE.Malattia.carenza + 1),
    })

    -- Recidiva: alla quarta malattia arriva il medico fiscale
    local quante = MySQL.scalar.await(
        'SELECT COUNT(*) FROM previdenza_prestazioni WHERE citizenid = ? AND tipo = ?',
        { g.citizenid, 'malattia' }) or 0

    if quante > PRE.Malattia.primaDellaVisitaFiscale then
        MySQL.update('UPDATE previdenza_prestazioni SET visita_fiscale = 1 WHERE id = ?', { id })
        exports.aurea_ui:NotificaLavoro('118', {
            tipo = 'avviso', icona = '🩺', durata = 15000,
            titolo = 'Visita fiscale disposta',
            testo = ('%s è in malattia per la %d° volta. L\'INPS chiede un controllo domiciliare.')
                :format(g:NomeCompleto(), quante),
        }, true)
    end

    AUREA.Log('economia', 'info', g, ('si è messo in malattia (%s a rateo)'):format(U.Euro(rateo)))
    rispondi(true, ('Malattia aperta: %s per %d ratei, dopo %d di carenza.')
        :format(U.Euro(rateo), ratei, PRE.Malattia.carenza))
end)

--- Mettersi in servizio mentre si prende la malattia è indebita percezione.
AddEventHandler('aurea:servizio:cambiato', function(src, _, inServizio)
    if not inServizio then return end

    local g = AUREA.GetPlayer(src)
    if not g then return end
    local citizenid = g.citizenid

    local aperta = prestazioneAperta(citizenid, 'malattia')
    if not aperta then return end

    chiudiPrestazione(aperta.id, 'revocata', 'servizio durante la malattia')

    local recupero = aperta.importo_rateo * math.max(1, aperta.ratei_erogati or 1)
    if recupero > 0 then
        exports.ita_fisco:IscriviTributo(citizenid, 'inps', 'indebita percezione', recupero, 7)
    end

    avvisa(citizenid, {
        tipo = 'errore', icona = '🏛', durata = 18000,
        titolo = 'Indennità revocata',
        testo = ('Ti sei messo in servizio durante la malattia. L\'INPS revoca la prestazione e chiede la restituzione di %s.')
            :format(U.Euro(recupero)),
    }, ('Indennità di malattia revocata per attività lavorativa. Recupero di %s.'):format(U.Euro(recupero)))

    exports.aurea_ui:NotificaLavoro('guardia_finanza', {
        tipo = 'avviso', icona = '🏛', durata = 14000,
        titolo = 'Indebita percezione',
        testo = 'Un assicurato si è messo in servizio mentre percepiva l\'indennità di malattia.',
    }, true)

    AUREA.Log('economia', 'avviso', nil, ('%s: indebita percezione di malattia'):format(citizenid))
end)

-- ---------------------------------------------------------------------------
--  Infortunio sul lavoro
--
--  Lo apre chi causa l'infortunio — ita_edilizia quando si cade da un
--  ponteggio, ma qualunque modulo può farlo. Il datore ha un tempo per
--  denunciarlo, e se non lo fa paga e perde il DURC.
-- ---------------------------------------------------------------------------
local function apriInfortunio(citizenid, datore, descrizione, gravita)
    local g = PRE.Infortunio.gravita[gravita] or PRE.Infortunio.gravita.lieve
    local p = posizione(citizenid)
    local base = p.ultimo_imponibile > 0 and p.ultimo_imponibile or PRE.Contributi.minimaleSettimanale
    local rateo = math.floor(base * g.quota)

    local id = MySQL.insert.await([[
        INSERT INTO previdenza_infortuni (citizenid, datore, descrizione, gravita, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { citizenid, datore, descrizione, gravita, PRE.Infortunio.minutiDenuncia })

    apriPrestazione(citizenid, 'infortunio', rateo, g.ratei, { infortunio = id, gravita = gravita })

    avvisa(citizenid, {
        tipo = 'avviso', icona = '🦺', durata = 16000,
        titolo = g.etichetta,
        testo = ('%s. L\'INAIL ti riconosce %s per %d ratei.'):format(descrizione, U.Euro(rateo), g.ratei),
    }, ('Infortunio sul lavoro protocollato. Indennità %s per %d ratei.'):format(U.Euro(rateo), g.ratei))

    if datore then
        avvisa(datore, {
            tipo = 'errore', icona = '🦺', durata = 20000,
            titolo = 'Infortunio di un tuo dipendente',
            testo = ('%s. Hai %d minuti per denunciarlo all\'INAIL: usa /denunciainfortunio.')
                :format(descrizione, PRE.Infortunio.minutiDenuncia),
        }, ('INFORTUNIO. Denuncia entro %d minuti con /denunciainfortunio, altrimenti sanzione e DURC irregolare.')
            :format(PRE.Infortunio.minutiDenuncia))
    end

    AUREA.Log('economia', 'avviso', nil,
        ('Infortunio %s a carico di %s (%s): %s'):format(gravita, citizenid, datore or 'nessun datore', descrizione))

    return id
end

AddEventHandler('aurea:previdenza:infortunio', function(citizenid, datore, descrizione, gravita)
    if type(citizenid) ~= 'string' then return end
    apriInfortunio(citizenid, datore, tostring(descrizione or 'Infortunio sul lavoro'), gravita or 'lieve')
end)

exports('ApriInfortunio', apriInfortunio)

--- Il datore denuncia.
AUREA.Comando('denunciainfortunio', 'utente', 'Denuncia all\'INAIL un infortunio di un dipendente', {},
function(src, _, _, g)
    if not g then return end

    local aperti = MySQL.query.await([[
        SELECT i.*, p.nome, p.cognome
        FROM previdenza_infortuni i
        LEFT JOIN personaggi p ON p.citizenid = i.citizenid
        WHERE i.datore = ? AND i.denunciato = 0 AND i.scaduto = 0
        ORDER BY i.id ASC
    ]], { g.citizenid }) or {}

    if #aperti == 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🦺', titolo = 'INAIL',
            testo = 'Non risultano infortuni da denunciare a tuo carico.',
        })
    end

    for _, i in ipairs(aperti) do
        MySQL.update.await('UPDATE previdenza_infortuni SET denunciato = 1, denunciato_il = NOW() WHERE id = ?', { i.id })
        avvisa(i.citizenid, {
            tipo = 'info', icona = '🦺', durata = 12000,
            titolo = 'Infortunio denunciato',
            testo = 'Il tuo datore di lavoro ha trasmesso la denuncia all\'INAIL.',
        })
    end

    AUREA.Log('economia', 'info', g, ('ha denunciato %d infortuni'):format(#aperti))
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🦺', durata = 10000,
        titolo = 'Denuncia trasmessa',
        testo = ('%d infortuni denunciati all\'INAIL nei termini.'):format(#aperti),
    })
end)

--- Scaduto il termine, la denuncia omessa costa.
CreateThread(function()
    Wait(90000)
    while true do
        Wait(120000)

        local scaduti = MySQL.query.await([[
            SELECT * FROM previdenza_infortuni
            WHERE denunciato = 0 AND scaduto = 0 AND scade_il <= NOW()
        ]]) or {}

        for _, i in ipairs(scaduti) do
            MySQL.update.await('UPDATE previdenza_infortuni SET scaduto = 1 WHERE id = ?', { i.id })
            if i.datore then
                exports.ita_fisco:IscriviTributo(i.datore, 'inps', 'denuncia infortunio omessa',
                    PRE.Infortunio.sanzioneOmessa, 10)

                avvisa(i.datore, {
                    tipo = 'errore', icona = '🦺', durata = 20000,
                    titolo = 'Denuncia omessa',
                    testo = ('Art. 53 D.P.R. 1124/1965: sanzione di %s e DURC irregolare finché non la sani.')
                        :format(U.Euro(PRE.Infortunio.sanzioneOmessa)),
                }, ('Sanzione di %s per omessa denuncia di infortunio. Il tuo DURC è ora irregolare.')
                    :format(U.Euro(PRE.Infortunio.sanzioneOmessa)))

                -- Chi ne colleziona troppi non è sfortunato: è un metodo
                local quanti = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM previdenza_infortuni WHERE datore = ? AND scaduto = 1', { i.datore }) or 0

                if quanti >= PRE.Infortunio.sogliaIspezione then
                    for _, lavoro in ipairs(PRE.Vigilanza.lavori) do
                        exports.aurea_ui:NotificaLavoro(lavoro, {
                            tipo = 'avviso', icona = '🔎', durata = 18000,
                            titolo = 'Ispettorato del lavoro',
                            testo = ('Un datore ha %d infortuni non denunciati. Verificare con /verificacontributi.')
                                :format(quanti),
                        }, true)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  NASpI
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pre:naspi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if g.lavoro.nome ~= 'disoccupato' then
        return rispondi(false, 'La NASpI spetta a chi ha perso il lavoro, non a chi ce l\'ha.')
    end
    if prestazioneAperta(g.citizenid, 'naspi') then
        return rispondi(false, 'Hai già una NASpI in corso.')
    end

    local p = posizione(g.citizenid)
    if p.settimane < PRE.NASpI.settimaneMinime then
        return rispondi(false, ('Servono %d settimane di contribuzione: ne hai %d. Ti resta il sussidio del Centro per l\'Impiego.')
            :format(PRE.NASpI.settimaneMinime, p.settimane))
    end

    local rateo = math.floor(p.ultimo_imponibile * PRE.NASpI.quota)
    local ratei = PRE.RateiNASpI(p.settimane)

    apriPrestazione(g.citizenid, 'naspi', rateo, ratei, { erogati = 0 })

    AUREA.Log('economia', 'info', g, ('ha ottenuto la NASpI (%s x %d)'):format(U.Euro(rateo), ratei))
    rispondi(true, ('NASpI riconosciuta: %s per %d ratei. Dopo il %d° l\'importo cala del %d%% a rateo.')
        :format(U.Euro(rateo), ratei, PRE.NASpI.decalageDopo, math.floor(PRE.NASpI.decalage * 100)))
end)

-- ---------------------------------------------------------------------------
--  DURC allo sportello
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pre:durc', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local regolare, motivi = durc(g.citizenid)
    if not regolare then
        return rispondi(false, ('DURC irregolare: %s.'):format(table.concat(motivi, '; ')))
    end

    MySQL.query.await([[
        INSERT INTO previdenza_durc (citizenid, scade_il) VALUES (?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE rilasciato_il = NOW(), scade_il = VALUES(scade_il)
    ]], { g.citizenid, PRE.DURC.validitaMinuti })

    AUREA.Log('economia', 'info', g, 'ha ritirato il DURC')
    rispondi(true, ('DURC regolare rilasciato. Vale %d minuti.'):format(PRE.DURC.validitaMinuti))
end)

-- ---------------------------------------------------------------------------
--  Vigilanza: la posizione di un altro
-- ---------------------------------------------------------------------------
AUREA.Comando('verificacontributi', 'utente', 'Verifica la posizione contributiva di un soggetto', {
    { name = 'id', help = 'ID della persona che hai davanti' },
}, function(src, args, _, g)
    if not g then return end

    local ammesso = false
    for _, l in ipairs(PRE.Vigilanza.lavori) do
        if g.lavoro.nome == l and g.lavoro.servizio then ammesso = true end
    end
    if not ammesso then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🔎', titolo = 'Non autorizzato',
            testo = 'La verifica contributiva è riservata al personale ispettivo in servizio.',
        })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🔎', titolo = 'Nessuno', testo = 'ID non trovato.',
        })
    end

    local p = posizione(bersaglio.citizenid)
    local regolare, motivi = durc(bersaglio.citizenid)
    local omessi = MySQL.scalar.await(
        'SELECT COUNT(*) FROM previdenza_infortuni WHERE datore = ? AND scaduto = 1', { bersaglio.citizenid }) or 0

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = regolare and 'successo' or 'errore', icona = '🔎', durata = 22000,
        titolo = ('Posizione di %s'):format(bersaglio:NomeCompleto()),
        testo = ('%d settimane · montante %s · DURC %s%s%s'):format(
            p.settimane, U.Euro(p.montante),
            regolare and 'REGOLARE' or 'IRREGOLARE',
            regolare and '' or (' (' .. table.concat(motivi, '; ') .. ')'),
            omessi > 0 and ('\n%d infortuni non denunciati'):format(omessi) or ''),
    })

    AUREA.Log('giustizia', 'info', g, ('ha verificato la posizione contributiva di %s'):format(bersaglio:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  App del telefono
--
--  Solo la propria posizione, e in sola lettura: andare in pensione è un
--  atto che si fa allo sportello, come nella vita.
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'inps',
    nome = 'INPS',
    icona = '🏛',
    colore = 'linear-gradient(150deg,#3f6fa8,#22405f)',
    ordine = 130,

    badge = function(g)
        return #prestazioneAperta(g.citizenid)
    end,

    schermata = function(g)
        local p = posizione(g.citizenid)
        local stato, spiegazione = PRE.StatoRequisito(p.settimane)
        local regolare, motivi = durc(g.citizenid)

        local voci = {
            { icona = '📅', titolo = 'Settimane contribuite',
              valore = tostring(p.settimane), sottotitolo = spiegazione, inerte = true },
            { icona = '📈', titolo = 'Montante contributivo',
              valore = U.Euro(p.montante),
              sottotitolo = 'È una scrittura, non un deposito: serve a calcolare il rateo',
              inerte = true },
            { icona = '💼', titolo = 'Ultimo imponibile',
              valore = U.Euro(p.ultimo_imponibile), inerte = true },
            { icona = regolare and '✅' or '⛔', titolo = 'DURC',
              valore = regolare and 'Regolare' or 'Irregolare',
              sottotitolo = regolare and 'Puoi aprire cantieri e prendere appalti'
                                      or table.concat(motivi, '; '),
              tono = regolare and 'verde' or 'rosso', inerte = true },
        }

        for _, pr in ipairs(prestazioneAperta(g.citizenid)) do
            voci[#voci + 1] = {
                icona = '🏛',
                titolo = ('Prestazione in corso — %s'):format(pr.tipo),
                sottotitolo = pr.tipo == 'pensione' and 'A tempo indeterminato'
                    or ('Ratei residui: %d'):format(pr.ratei_residui),
                valore = U.Euro(pr.importo_rateo),
                tono = 'verde', inerte = true,
            }
        end

        return {
            tipo = 'saldo',
            etichetta = p.pensionato == 1 and 'Rateo di pensione' or 'Pensione stimata a oggi',
            valore = U.Euro(PRE.RateoPensione(p.montante, stato == 'anticipata')),
            nota = p.pensionato == 1 and 'Trattamento in pagamento'
                or ('Ogni %d minuti, una volta maturato il diritto'):format(PRE.Pensione.minuti),
            voci = voci,
        }
    end,
})

print('[AUREA] previdenza: INPS e INAIL attivi')
