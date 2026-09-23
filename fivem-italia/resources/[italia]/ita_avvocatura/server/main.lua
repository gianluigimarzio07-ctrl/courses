--[[
    AUREA · Consiglio dell'Ordine degli Avvocati (server)

    Tre registri: l'albo, il turno delle difese d'ufficio, le ammissioni
    al patrocinio a spese dello Stato.

    Il pezzo che serve a chi sta fuori sono due export:

      DifensoreDiTurno()  → il primo avvocato reperibile online, o nil.
                            Lo chiama ita_tribunale quando un imputato si
                            presenta senza difensore.

      AmmessoAlPatrocinio(citizenid) → se l'onorario lo paga l'Erario.

    Entrambi vanno chiamati dentro un pcall: questa risorsa può non essere
    installata, e il processo deve andare avanti comunque.
]]

local U = AUREA.Util

local albo    = {}   -- [citizenid] = { iscritto, scade, sospesoFino, cancellato }
local turno   = {}   -- [citizenid] = { dal, scade, ultimaIndennita, incarichi }
local ammessi = {}   -- [citizenid] = { scade, reddito }

local function pulisci(s, massimo)
    return (tostring(s or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, massimo or 200)
end

-- ---------------------------------------------------------------------------
--  L'albo
-- ---------------------------------------------------------------------------
local function iscritto(citizenid)
    local a = albo[citizenid]
    if not a then return false, 'non iscritto all\'albo' end
    if a.scade <= os.time() then return false, 'iscrizione scaduta' end
    if a.sospesoFino and a.sospesoFino > os.time() then
        return false, ('sospeso dall\'esercizio per altri %d minuti')
            :format(math.ceil((a.sospesoFino - os.time()) / 60))
    end
    return true
end

exports('Iscritto', iscritto)

--- È avvocato, in servizio, e iscritto. Sono tre condizioni diverse e
--- servono tutte: si può essere iscritti e non timbrare, o timbrare con
--- l'iscrizione scaduta.
local function avvocatoAbilitato(g)
    if not g or g.lavoro.nome ~= AVV.Lavoro or not g.lavoro.servizio then
        return false, 'serve essere un avvocato in servizio'
    end
    if (g.lavoro.grado or 0) < AVV.Albo.gradoMinimo then
        return false, 'un praticante non patrocina da solo'
    end
    return iscritto(g.citizenid)
end

exports('Abilitato', function(citizenid)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if not g then return false, 'non collegato' end
    return avvocatoAbilitato(g)
end)

AUREA.Callback.Registra('avv:iscrivi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    if g.lavoro.nome ~= AVV.Lavoro then
        return rispondi(false, 'L\'albo è degli avvocati: serve lavorare in uno studio legale.')
    end
    if (g.lavoro.grado or 0) < AVV.Albo.gradoMinimo then
        return rispondi(false, 'Il praticante non si iscrive all\'albo: prima l\'abilitazione.')
    end

    local a = albo[g.citizenid]
    if a and not a.cancellato and a.scade > os.time() then
        return rispondi(false, ('Sei già iscritto. L\'iscrizione scade fra %d minuti.')
            :format(math.ceil((a.scade - os.time()) / 60)))
    end
    if a and a.sospesoFino and a.sospesoFino > os.time() then
        return rispondi(false, 'Sei sospeso: finché dura non ti si reiscrive.')
    end

    -- Il requisito della condotta. Non è una formalità morale: è la
    -- ragione per cui l'albo esiste.
    local okP, precedenti = pcall(function()
        return exports.ita_giustizia:Precedenti(g.citizenid, true)
    end)
    if okP and type(precedenti) == 'table' then
        for _, p in ipairs(precedenti) do
            if (tonumber(p.gravita) or 0) >= AVV.Albo.gravitaOstativa then
                return rispondi(false, ('Non ti si iscrive: hai un fascicolo aperto per %s.')
                    :format(p.reato or 'un reato grave'))
            end
        end
    end

    if not g:SottraiOvunque(AVV.Albo.tassaIscrizione, 'tassa di iscrizione all\'albo') then
        return rispondi(false, ('L\'iscrizione costa %s.'):format(U.Euro(AVV.Albo.tassaIscrizione)))
    end

    local scade = os.time() + AVV.Albo.minutiValidita * 60
    MySQL.insert.await([[
        INSERT INTO avvocatura_albo (citizenid, scade_il)
        VALUES (?, FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE scade_il = VALUES(scade_il),
                                sospeso_fino = NULL, cancellato = 0
    ]], { g.citizenid, scade })

    albo[g.citizenid] = { iscritto = os.time(), scade = scade }

    TriggerEvent('aurea:fisco:incasso', 'tasse_ordini_professionali',
        AVV.Albo.tassaIscrizione, g.citizenid)
    AUREA.Log('giustizia', 'info', g, 'iscritto all\'albo degli avvocati')

    rispondi(true, ('Iscritto all\'albo. Vale %d minuti. Ora puoi entrare nel turno delle difese d\'ufficio.')
        :format(AVV.Albo.minutiValidita))
end)

AUREA.Callback.Registra('avv:statoAlbo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local a = albo[g.citizenid]
    local ok, motivo = iscritto(g.citizenid)
    rispondi({
        iscritto = ok,
        motivo = motivo,
        minutiResidui = a and math.max(0, math.ceil((a.scade - os.time()) / 60)) or 0,
        sospeso = a and a.sospesoFino and a.sospesoFino > os.time() or false,
        inTurno = turno[g.citizenid] ~= nil,
        tassa = AVV.Albo.tassaIscrizione,
    })
end)

-- ---------------------------------------------------------------------------
--  Il turno
-- ---------------------------------------------------------------------------
local function quantiInTurno()
    local n = 0
    for _ in pairs(turno) do n = n + 1 end
    return n
end

AUREA.Callback.Registra('avv:turno', function(src, rispondi, entrare)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    if not entrare then
        if not turno[g.citizenid] then return rispondi(false, 'Non sei in turno.') end
        turno[g.citizenid] = nil
        MySQL.update.await(
            'UPDATE avvocatura_turni SET chiuso = 1, chiuso_il = NOW() WHERE citizenid = ? AND chiuso = 0',
            { g.citizenid })
        return rispondi(true, 'Sei uscito dal turno delle difese d\'ufficio.')
    end

    local ok, motivo = avvocatoAbilitato(g)
    if not ok then
        return rispondi(false, ('Non puoi entrare in turno: %s.'):format(motivo))
    end
    if turno[g.citizenid] then return rispondi(false, 'Sei già in turno.') end
    if quantiInTurno() >= AVV.Turno.massimoContemporanei then
        return rispondi(false, 'Il turno è già coperto dal numero massimo di difensori.')
    end

    local scade = os.time() + AVV.Turno.minutiDurata * 60
    MySQL.insert.await(
        'INSERT INTO avvocatura_turni (citizenid, scade_il) VALUES (?, FROM_UNIXTIME(?))',
        { g.citizenid, scade })

    turno[g.citizenid] = {
        dal = os.time(), scade = scade,
        ultimaIndennita = os.time(), incarichi = 0,
    }

    rispondi(true, ('In turno per %d minuti. Indennità di reperibilità %s ogni %d minuti, anche se non ti chiamano.')
        :format(AVV.Turno.minutiDurata, U.Euro(AVV.Turno.indennita), AVV.Turno.minutiFraIndennita))
end)

AUREA.Callback.Registra('avv:chiInTurno', function(src, rispondi)
    local out = {}
    for citizenid, t in pairs(turno) do
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        out[#out + 1] = {
            nome = g and g:NomeCompleto() or citizenid,
            online = g ~= nil,
            minutiResidui = math.max(0, math.ceil((t.scade - os.time()) / 60)),
            incarichi = t.incarichi,
        }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)
    rispondi(out)
end)

--- Il difensore di turno. Restituisce (citizenid, src, nome) oppure nil.
---
--- Deve essere ONLINE: un difensore d'ufficio che non c'è non difende
--- nessuno, e il processo dovrebbe fermarsi. Chi chiama questa funzione
--- deve saper gestire il nil.
local function difensoreDiTurno(escludiCid)
    local scelto, migliore = nil, nil
    for citizenid, t in pairs(turno) do
        if citizenid ~= escludiCid then
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            if g and g.lavoro.servizio then
                -- Si chiama chi ha avuto meno incarichi: il turno si
                -- distribuisce, non si scarica sempre sullo stesso.
                if not migliore or t.incarichi < migliore then
                    migliore = t.incarichi
                    scelto = { citizenid = citizenid, source = g.source, nome = g:NomeCompleto() }
                end
            end
        end
    end
    if not scelto then return nil end
    return scelto.citizenid, scelto.source, scelto.nome
end

exports('DifensoreDiTurno', difensoreDiTurno)

-- ---------------------------------------------------------------------------
--  Gratuito patrocinio
-- ---------------------------------------------------------------------------
local function ammesso(citizenid)
    local a = ammessi[citizenid]
    if not a then return false end
    if a.scade <= os.time() then
        ammessi[citizenid] = nil
        return false
    end
    return true, a.reddito
end

exports('AmmessoAlPatrocinio', ammesso)

--- L'onorario che lo Stato liquida al difensore di chi è ammesso.
exports('OnorarioLiquidato', function()
    return AVV.Patrocinio.onorarioLiquidato
end)

AUREA.Callback.Registra('avv:chiediPatrocinio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Errore.') end

    local gia, reddito = ammesso(g.citizenid)
    if gia then
        return rispondi(false, ('Sei già ammesso. Il reddito accertato è %s.')
            :format(U.Euro(reddito or 0)))
    end

    -- Il presupposto è il reddito imponibile dell'ultima dichiarazione.
    -- Chi non l'ha mai presentata non ha un reddito accertato, e senza
    -- quello non c'è niente da valutare: si va al CAF.
    local riga = MySQL.single.await([[
        SELECT reddito, periodo FROM dichiarazioni
        WHERE citizenid = ? ORDER BY presentata_il DESC LIMIT 1
    ]], { g.citizenid })

    if not riga then
        return rispondi(false,
            'Non risulta nessuna dichiarazione dei redditi a tuo nome. Senza quella il reddito non è accertabile: passa da un CAF e presentala.')
    end

    local imponibile = tonumber(riga.reddito) or 0
    if imponibile > AVV.Patrocinio.sogliaReddito then
        return rispondi(false, ('Domanda inammissibile: il reddito imponibile dichiarato è %s, la soglia è %s.')
            :format(U.Euro(imponibile), U.Euro(AVV.Patrocinio.sogliaReddito)))
    end

    if AVV.Patrocinio.escludiTitolariImpresa then
        local imprese = MySQL.scalar.await(
            'SELECT id FROM imprese WHERE titolare = ? AND attiva = 1 LIMIT 1', { g.citizenid })
        if imprese then
            return rispondi(false,
                'Risulti titolare di un\'impresa attiva: il reddito d\'impresa non sta nella dichiarazione da dipendente e il presupposto cade.')
        end
    end

    local scade = os.time() + AVV.Patrocinio.minutiValidita * 60
    local id = MySQL.insert.await([[
        INSERT INTO avvocatura_patrocini (citizenid, reddito, periodo, scade_il)
        VALUES (?, ?, ?, FROM_UNIXTIME(?))
    ]], { g.citizenid, imponibile, riga.periodo, scade })

    ammessi[g.citizenid] = { scade = scade, reddito = imponibile, id = id }

    AUREA.Log('giustizia', 'info', g,
        ('ammesso al patrocinio a spese dello Stato, imponibile %s'):format(U.Euro(imponibile)))

    rispondi(true, ('Ammesso al patrocinio a spese dello Stato (%s).\nReddito accertato %s, soglia %s.\nPer %d minuti l\'onorario del difensore lo paga l\'Erario.')
        :format(AVV.Patrocinio.articolo, U.Euro(imponibile),
                U.Euro(AVV.Patrocinio.sogliaReddito), AVV.Patrocinio.minutiValidita))
end)

-- ---------------------------------------------------------------------------
--  Gli incarichi
--
--  Li registra chi conferisce la difesa — oggi è ita_tribunale, domani
--  potrebbe essere la questura al momento dell'interrogatorio. Qui si
--  tiene il conto e si paga, perché è questa risorsa a sapere se
--  l'onorario lo deve l'assistito o lo Stato.
-- ---------------------------------------------------------------------------
local function registraIncarico(avvocatoCid, assistitoCid, tipo, riferimento)
    local i = AVV.GetIncarico(tipo)
    if not i then return nil end

    local aCarico = i.aCarico
    local onorario

    if tipo == 'patrocinio' then
        onorario = AVV.Patrocinio.onorarioLiquidato
    elseif tipo == 'ufficio' then
        onorario = AVV.Patrocinio.onorarioLiquidato
    else
        onorario = nil   -- la difesa di fiducia la prezza chi la conferisce
    end

    -- Se l'assistito è ammesso al patrocinio, paga lo Stato qualunque sia
    -- il tipo di incarico: è il senso dell'ammissione.
    if ammesso(assistitoCid) then
        aCarico = 'erario'
        onorario = AVV.Patrocinio.onorarioLiquidato
    end

    local id = MySQL.insert.await([[
        INSERT INTO avvocatura_incarichi
            (avvocato, assistito, tipo, riferimento, onorario, a_carico)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { avvocatoCid, assistitoCid, tipo, riferimento, onorario or 0, aCarico })

    local t = turno[avvocatoCid]
    if t then t.incarichi = t.incarichi + 1 end

    if aCarico == 'erario' and onorario and onorario > 0 then
        AUREA.Denaro.AggiungiOffline(avvocatoCid, 'banca', onorario,
            'liquidazione al patrocinio a spese dello Stato')
        TriggerEvent('aurea:fisco:erogazione', 'spese_giustizia', onorario, avvocatoCid)
        TriggerEvent('aurea:fisco:ritenuta', avvocatoCid,
            math.floor(onorario * 0.20), 'irpef')
    end

    return id, onorario, aCarico
end

exports('RegistraIncarico', registraIncarico)

--- Avvisa il difensore di turno che c'è un assistito che lo attende.
exports('ConvocaDifensore', function(assistitoCid, dove, motivo)
    local cid, src, nome = difensoreDiTurno(assistitoCid)
    if not cid then return nil end

    local assistito = AUREA.GetPlayerByCitizenId(assistitoCid)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '📞', durata = 26000,
        titolo = 'DIFESA D\'UFFICIO — sei di turno',
        testo = ('%s\n%s\n%s')
            :format(assistito and assistito:NomeCompleto() or 'Assistito non identificato',
                    pulisci(motivo or 'Nomina d\'ufficio', 140),
                    dove and ('Presso: ' .. pulisci(dove, 60)) or 'Presentati in tribunale.'),
    })

    if assistito then
        TriggerClientEvent('aurea:ui:notifica', assistito.source, {
            tipo = 'info', icona = '⚖', durata = 20000,
            titolo = 'Difensore d\'ufficio nominato',
            testo = ('Ti è stato nominato l\'avv. %s, di turno. Sta arrivando.'):format(nome),
        })
    end

    AUREA.Log('giustizia', 'info', nil,
        ('difensore d\'ufficio %s nominato per %s'):format(cid, assistitoCid))

    return cid, src, nome
end)

-- ---------------------------------------------------------------------------
--  Il disciplinare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('avv:disciplinare', function(src, rispondi, bersaglioSrc, sanzione, motivo)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio then return rispondi(false, 'Serve essere in servizio.') end

    if not U.Contiene(AVV.Disciplinare.chiPuoAgire, g.lavoro.nome) then
        return rispondi(false, 'Il disciplinare è materia del Consiglio dell\'Ordine e del giudice.')
    end
    if g.lavoro.nome == AVV.Lavoro and (g.lavoro.grado or 0) < AVV.Disciplinare.gradoMinimo then
        return rispondi(false, 'Serve il grado: il Consiglio non lo compone un praticante.')
    end

    local s = AVV.GetSanzione(sanzione)
    if not s then return rispondi(false, 'Sanzione non prevista.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc) or 0)
    if not b then return rispondi(false, 'Nessuno davanti a te.') end
    if b.citizenid == g.citizenid then return rispondi(false, 'Non ti si sanziona da solo.') end

    local ok = iscritto(b.citizenid)
    if not ok then return rispondi(false, 'Non è iscritto all\'albo: non c\'è nulla da sospendere.') end

    motivo = pulisci(motivo, 200)
    if #motivo < 4 then return rispondi(false, 'Serve una motivazione.') end

    local a = albo[b.citizenid]

    if s.minutiSospensione < 0 then
        a.cancellato = true
        a.scade = os.time()
        turno[b.citizenid] = nil
        MySQL.update.await(
            'UPDATE avvocatura_albo SET cancellato = 1, scade_il = NOW() WHERE citizenid = ?',
            { b.citizenid })
    elseif s.minutiSospensione > 0 then
        a.sospesoFino = os.time() + s.minutiSospensione * 60
        turno[b.citizenid] = nil
        MySQL.update.await(
            'UPDATE avvocatura_albo SET sospeso_fino = FROM_UNIXTIME(?) WHERE citizenid = ?',
            { a.sospesoFino, b.citizenid })
    end

    if s.sanzione > 0 then
        b:SottraiOvunque(s.sanzione, 'sanzione disciplinare del Consiglio dell\'Ordine')
        TriggerEvent('aurea:fisco:incasso', 'sanzioni_disciplinari', s.sanzione, b.citizenid)
    end

    MySQL.insert.await([[
        INSERT INTO avvocatura_disciplinare (citizenid, sanzione, motivo, deciso_da)
        VALUES (?, ?, ?, ?)
    ]], { b.citizenid, sanzione, motivo, g.citizenid })

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'errore', icona = s.icona, durata = 24000,
        titolo = ('Procedimento disciplinare — %s'):format(s.etichetta),
        testo = ('%s\n%s'):format(motivo, s.descrizione),
    })

    AUREA.Log('giustizia', 'avviso', g,
        ('%s a carico di %s: %s'):format(s.etichetta, b.citizenid, motivo))

    rispondi(true, ('%s inflitta a %s.'):format(s.etichetta, b:NomeCompleto()))
end)

AUREA.Callback.Registra('avv:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local incarichi = MySQL.query.await([[
        SELECT i.tipo, i.onorario, i.a_carico,
               TIMESTAMPDIFF(MINUTE, i.conferito_il, NOW()) AS minutiFa,
               CONCAT(p.nome, ' ', p.cognome) AS assistito
        FROM avvocatura_incarichi i
        LEFT JOIN personaggi p ON p.citizenid = i.assistito
        WHERE i.avvocato = ? ORDER BY i.id DESC LIMIT 20
    ]], { g.citizenid }) or {}
    rispondi(incarichi)
end)

-- ---------------------------------------------------------------------------
--  I cicli
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)
        local adesso = os.time()

        -- L'indennità di reperibilità
        for citizenid, t in pairs(turno) do
            if adesso >= t.scade then
                turno[citizenid] = nil
                MySQL.update.await(
                    'UPDATE avvocatura_turni SET chiuso = 1, chiuso_il = NOW() WHERE citizenid = ? AND chiuso = 0',
                    { citizenid })
                local g = AUREA.GetPlayerByCitizenId(citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'info', icona = '⚖', durata = 12000,
                        titolo = 'Turno concluso',
                        testo = ('Hai coperto %d incarichi d\'ufficio.'):format(t.incarichi),
                    })
                end
            elseif adesso - t.ultimaIndennita >= AVV.Turno.minutiFraIndennita * 60 then
                t.ultimaIndennita = adesso
                AUREA.Denaro.AggiungiOffline(citizenid, 'banca', AVV.Turno.indennita,
                    'indennità di reperibilità')
                TriggerEvent('aurea:fisco:erogazione', 'spese_giustizia',
                    AVV.Turno.indennita, citizenid)
            end
        end

        -- Le iscrizioni e le ammissioni scadono
        for citizenid, a in pairs(albo) do
            if a.scade <= adesso and not a.avvisato then
                a.avvisato = true
                turno[citizenid] = nil
                local g = AUREA.GetPlayerByCitizenId(citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '⚖', durata = 16000,
                        titolo = 'Iscrizione all\'albo scaduta',
                        testo = 'Fino al rinnovo non patrocini e non stai sul turno.',
                    })
                end
            end
        end

        for citizenid, a in pairs(ammessi) do
            if a.scade <= adesso then ammessi[citizenid] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('albo', 'utente', 'Verifica se una persona è iscritta all\'albo degli avvocati', {
    { name = 'nome', help = 'Nome o cognome dell\'avvocato' },
}, function(src, args)
    local cerca = tostring(args[1] or ''):lower()
    if #cerca < 2 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⚖', titolo = 'Albo', testo = 'Serve almeno un nome.' })
    end

    local trovati = {}
    for citizenid in pairs(albo) do
        if iscritto(citizenid) then
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            local nome = g and g:NomeCompleto() or nil
            if nome and nome:lower():find(cerca, 1, true) then
                trovati[#trovati + 1] = nome
            end
        end
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = #trovati > 0 and 'successo' or 'errore', icona = '⚖',
        titolo = 'Albo degli avvocati',
        testo = #trovati > 0
            and ('Iscritti: %s'):format(table.concat(trovati, ', '))
            or 'Nessun iscritto con questo nome. Attenzione a chi si spaccia per avvocato.',
        durata = 16000,
    })
end)

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    -- L'albo sopravvive al riavvio. I turni no: un turno è una presenza,
    -- e dopo un riavvio nessuno è presente.
    MySQL.update.await('UPDATE avvocatura_turni SET chiuso = 1, chiuso_il = NOW() WHERE chiuso = 0')

    local righe = MySQL.query.await([[
        SELECT citizenid, UNIX_TIMESTAMP(scade_il) AS scade,
               UNIX_TIMESTAMP(sospeso_fino) AS sospeso, cancellato
        FROM avvocatura_albo
        WHERE cancellato = 0 AND scade_il > NOW()
    ]]) or {}

    for _, r in ipairs(righe) do
        albo[r.citizenid] = {
            iscritto = os.time(), scade = r.scade or os.time(),
            sospesoFino = r.sospeso,
        }
    end

    if #righe > 0 then
        print(('[AUREA] avvocatura: %d iscritti all\'albo'):format(#righe))
    end
end)
