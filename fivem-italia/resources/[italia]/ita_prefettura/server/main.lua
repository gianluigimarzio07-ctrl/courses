--[[
    AUREA · Prefettura (server)

    Tre cose, e una sola idea sotto: lo Stato deve poter dire di no, ma
    deve anche poterselo sentire chiedere.

    La parte da guardare è il thread del silenzio-accoglimento in fondo.
    Non è un premio di consolazione: è la regola. Se in Prefettura non
    c'è nessuno, i ricorsi si accolgono, le multe spariscono e l'erario
    perde soldi veri. Un ufficio vuoto costa.
]]

local U = AUREA.Util

local function funzionario(g, permesso)
    return g and g.lavoro.nome == PREF.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso)
end

local function inSede(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - PREF.Sede.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Quali verbali si possono ancora impugnare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pref:impugnabili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT m.id, m.articolo, m.descrizione, m.importo, m.luogo, m.origine,
               m.punti_decurtati, TIMESTAMPDIFF(DAY, m.emessa_il, NOW()) AS giorni
        FROM multe m
        LEFT JOIN prefettura_ricorsi r ON r.multa_id = m.id
        WHERE m.citizenid = ?
          AND m.stato = 'aperta'
          AND r.id IS NULL
          AND TIMESTAMPDIFF(DAY, m.emessa_il, NOW()) <= ?
        ORDER BY m.emessa_il DESC
        LIMIT 20
    ]], { g.citizenid, PREF.Ricorso.giorniPerRicorrere }) or {}

    for _, m in ipairs(righe) do
        m.ingiunzione = PREF.Ingiunzione(m.importo)
        m.giorniRimasti = math.max(0, PREF.Ricorso.giorniPerRicorrere - (m.giorni or 0))
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Presentare il ricorso
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pref:ricorri', function(src, rispondi, multaId, sede, motivoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'Il ricorso si deposita in Prefettura.') end

    multaId = tonumber(multaId)
    if not multaId then return rispondi(false, 'Verbale non indicato.') end
    if sede ~= 'prefetto' and sede ~= 'giudice_pace' then
        return rispondi(false, 'Sede non valida.')
    end

    local motivo = PREF.GetMotivo(motivoId)
    if not motivo then return rispondi(false, 'Motivo non valido.') end

    local m = MySQL.single.await([[
        SELECT id, citizenid, importo, articolo, descrizione,
               TIMESTAMPDIFF(DAY, emessa_il, NOW()) AS giorni
        FROM multe WHERE id = ? AND stato = 'aperta'
    ]], { multaId })
    if not m then return rispondi(false, 'Verbale non trovato o già definito.') end
    if m.citizenid ~= g.citizenid then return rispondi(false, 'Non è un tuo verbale.') end
    if (m.giorni or 0) > PREF.Ricorso.giorniPerRicorrere then
        return rispondi(false, ('Sono passati più di %d giorni: il verbale è definitivo.')
            :format(PREF.Ricorso.giorniPerRicorrere))
    end

    local gia = MySQL.scalar.await('SELECT id FROM prefettura_ricorsi WHERE multa_id = ?', { multaId })
    if gia then return rispondi(false, 'Su questo verbale hai già ricorso: le due strade sono alternative.') end

    -- Il Giudice di Pace costa il contributo unificato, il Prefetto no
    if sede == 'giudice_pace' then
        if not g:SottraiOvunque(PREF.Ricorso.contributoUnificato, 'contributo unificato') then
            return rispondi(false, ('Servono %s di contributo unificato.')
                :format(U.Euro(PREF.Ricorso.contributoUnificato)))
        end
        TriggerEvent('aurea:fisco:incasso', 'contributo_unificato',
            PREF.Ricorso.contributoUnificato, g.citizenid)
    end

    MySQL.insert.await([[
        INSERT INTO prefettura_ricorsi
            (multa_id, citizenid, sede, motivo, importo_originario, decide_entro)
        VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { multaId, g.citizenid, sede, motivo.nome, m.importo, PREF.Ricorso.minutiPerDecidere })

    -- Finché pende il ricorso il verbale non si paga e non va a ruolo
    MySQL.update.await('UPDATE multe SET stato = ? WHERE id = ?', { 'ricorso', multaId })

    AUREA.Log('multe', 'info', g, ('ricorso %s sul verbale %d (%s)'):format(sede, multaId, motivo.id))

    if sede == 'prefetto' then
        exports.aurea_ui:NotificaLavoro(PREF.Lavoro, {
            tipo = 'info', icona = '📄', durata = 14000,
            titolo = 'Nuovo ricorso',
            testo = ('%s ha impugnato un verbale (%s). Coda con /ricorsi.')
                :format(g:NomeCompleto(), motivo.nome),
        }, true)

        return rispondi(true, ('Ricorso depositato. Il verbale è sospeso.\n\nAttenzione: se il Prefetto rigetta, l\'ordinanza-ingiunzione sarà di %s invece di %s.')
            :format(U.Euro(PREF.Ingiunzione(m.importo)), U.Euro(m.importo)))
    end

    return rispondi(true, ('Ricorso al Giudice di Pace depositato, contributo unificato %s versato. Il verbale è sospeso fino all\'udienza.')
        :format(U.Euro(PREF.Ricorso.contributoUnificato)))
end)

-- ---------------------------------------------------------------------------
--  La coda in istruttoria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('pref:coda', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'ricorsi') then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT r.id, r.multa_id, r.sede, r.motivo, r.importo_originario, r.citizenid,
               CONCAT(p.nome, ' ', p.cognome) AS ricorrente,
               m.articolo, m.descrizione, m.luogo, m.origine, m.prova,
               TIMESTAMPDIFF(MINUTE, NOW(), r.decide_entro) AS minutiResidui
        FROM prefettura_ricorsi r
        JOIN multe m ON m.id = r.multa_id
        LEFT JOIN personaggi p ON p.citizenid = r.citizenid
        WHERE r.stato = 'istruttoria'
        ORDER BY r.decide_entro ASC
        LIMIT 25
    ]]) or {}

    for _, r in ipairs(righe) do
        r.ingiunzione = PREF.Ingiunzione(r.importo_originario)
        r.minutiResidui = math.max(0, r.minutiResidui or 0)
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Decidere
--
--  Accoglimento: il verbale è annullato e, se aveva tolto punti, i punti
--  tornano. Rigetto: ordinanza-ingiunzione al doppio, e il verbale torna
--  esigibile con il nuovo importo.
-- ---------------------------------------------------------------------------
local function decidi(r, accoglie, decisoDa, nomeDecidente)
    local esito = accoglie and 'accolto' or 'rigettato'
    local ingiunto = 0

    if accoglie then
        MySQL.update.await('UPDATE multe SET stato = ? WHERE id = ?', { 'annullata', r.multa_id })

        -- I punti tolti da un verbale annullato non erano mai stati tolti
        local punti = MySQL.scalar.await('SELECT punti_decurtati FROM multe WHERE id = ?', { r.multa_id }) or 0
        if punti > 0 then
            pcall(function() exports.ita_codicestrada:PatenteRestituisci(r.citizenid, punti) end)
        end
    else
        if r.sede == 'giudice_pace' then
            -- Il giudice può ridurre invece di annullare o confermare
            ingiunto = math.floor(r.importo_originario * PREF.Ricorso.riduzioneGiudicePace)
            ingiunto = math.max(ingiunto, 100)
        else
            ingiunto = PREF.Ingiunzione(r.importo_originario)
        end

        MySQL.update.await(
            'UPDATE multe SET stato = ?, importo = ?, scadenza = DATE_ADD(NOW(), INTERVAL 30 DAY) WHERE id = ?',
            { 'aperta', ingiunto, r.multa_id })

        MySQL.insert.await([[
            INSERT INTO prefettura_ordinanze (citizenid, tipo, importo, motivo, emessa_da)
            VALUES (?, 'ingiunzione', ?, ?, ?)
        ]], { r.citizenid, ingiunto,
              ('Rigetto del ricorso sul verbale n. %d'):format(r.multa_id), decisoDa })
    end

    MySQL.update.await([[
        UPDATE prefettura_ricorsi
        SET stato = ?, deciso_da = ?, decisione = ?, importo_ingiunto = ?, deciso_il = NOW()
        WHERE id = ?
    ]], { esito, decisoDa, nomeDecidente, ingiunto, r.id })

    local testo
    if accoglie then
        testo = ('Ricorso ACCOLTO. Il verbale n. %d è annullato.'):format(r.multa_id)
    elseif r.sede == 'giudice_pace' then
        testo = ('Ricorso rigettato, sanzione ridotta al minimo: %s.'):format(U.Euro(ingiunto))
    else
        testo = ('Ricorso RIGETTATO. Ordinanza-ingiunzione di %s (art. 204 CdS, non meno del doppio del minimo). Hai 30 giorni.')
            :format(U.Euro(ingiunto))
    end

    TriggerEvent('aurea:telefono:messaggioSistema', r.citizenid, 'Prefettura', testo)

    local gr = AUREA.GetPlayerByCitizenId(r.citizenid)
    if gr then
        TriggerClientEvent('aurea:ui:notifica', gr.source, {
            tipo = accoglie and 'successo' or 'errore', icona = '📄', durata = 20000,
            titolo = accoglie and 'Ricorso accolto' or 'Ricorso rigettato', testo = testo,
        })
    end

    AUREA.Log('multe', accoglie and 'info' or 'avviso', nil,
        ('ricorso %d %s (verbale %d, %s)'):format(r.id, esito, r.multa_id, nomeDecidente))
end

AUREA.Callback.Registra('pref:decidi', function(src, rispondi, id, accoglie)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'ricorsi') then return rispondi(false, 'Non sei in servizio in Prefettura.') end
    if not inSede(src) then return rispondi(false, 'Le decisioni si prendono in ufficio.') end

    local r = MySQL.single.await(
        'SELECT * FROM prefettura_ricorsi WHERE id = ? AND stato = ?', { tonumber(id), 'istruttoria' })
    if not r then return rispondi(false, 'Ricorso non più in istruttoria.') end
    if r.citizenid == g.citizenid then
        return rispondi(false, 'Non puoi decidere sul tuo stesso ricorso.')
    end

    decidi(r, accoglie == true, g.citizenid, g:NomeCompleto())
    rispondi(true, accoglie and 'Ricorso accolto, verbale annullato.'
                            or 'Ricorso rigettato, ordinanza emessa.')
end)

-- ---------------------------------------------------------------------------
--  Silenzio-accoglimento
--
--  Art. 204 c. 1-bis: decorso il termine senza provvedimento, il ricorso
--  si intende accolto. Nessuno deve dichiararlo. È il motivo per cui una
--  Prefettura sguarnita è un problema dell'erario e non del cittadino.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(120000)

        local scaduti = MySQL.query.await([[
            SELECT * FROM prefettura_ricorsi
            WHERE stato = 'istruttoria' AND decide_entro <= NOW()
        ]]) or {}

        for _, r in ipairs(scaduti) do
            if r.sede == 'prefetto' then
                MySQL.update.await('UPDATE multe SET stato = ? WHERE id = ?', { 'annullata', r.multa_id })
                MySQL.update.await([[
                    UPDATE prefettura_ricorsi
                    SET stato = 'silenzio_accoglimento',
                        decisione = 'Termine decorso senza provvedimento (art. 204 c. 1-bis CdS)',
                        deciso_il = NOW()
                    WHERE id = ?
                ]], { r.id })

                TriggerEvent('aurea:telefono:messaggioSistema', r.citizenid, 'Prefettura',
                    ('Il termine per decidere sul ricorso è decorso: il verbale n. %d è annullato.')
                        :format(r.multa_id))

                AUREA.Log('multe', 'avviso', nil,
                    ('silenzio-accoglimento sul ricorso %d: verbale %d annullato, %s persi dall\'erario')
                        :format(r.id, r.multa_id, U.Euro(r.importo_originario)))
            else
                -- Il Giudice di Pace decide comunque: l'udienza si tiene
                -- anche se in servizio non c'è nessuno.
                decidi(r, math.random(100) <= PREF.Ricorso.probabilitaAccoglimentoGdP,
                       nil, 'Giudice di Pace')
            end
        end

        -- Se la coda si allunga, in Prefettura qualcuno dovrebbe saperlo
        local inCoda = MySQL.scalar.await(
            'SELECT COUNT(*) FROM prefettura_ricorsi WHERE stato = ? AND sede = ?',
            { 'istruttoria', 'prefetto' }) or 0
        if inCoda >= 5 then
            exports.aurea_ui:NotificaLavoro(PREF.Lavoro, {
                tipo = 'avviso', icona = '📄', durata = 14000,
                titolo = 'Coda dei ricorsi',
                testo = ('%d ricorsi in istruttoria. Quelli che scadono si accolgono da soli.')
                    :format(inCoda),
            }, true)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Elenco prefettizio degli addetti ai servizi di controllo
-- ---------------------------------------------------------------------------
local function iscrittoValido(citizenid)
    local r = MySQL.single.await([[
        SELECT scadenza FROM prefettura_elenco
        WHERE citizenid = ? AND sospeso = 0 AND scadenza >= CURDATE()
    ]], { citizenid })
    return r ~= nil
end

exports('IscrittoElenco', iscrittoValido)

AUREA.Callback.Registra('pref:elencoStato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local r = MySQL.single.await('SELECT * FROM prefettura_elenco WHERE citizenid = ?', { g.citizenid })
    if r then
        r.scadenzaIT = U.DataIT(math.floor((r.scadenza or 0) / 1000))
        r.valido = r.sospeso == 0
    end
    rispondi(r, PREF.Elenco.costoIstruttoria)
end)

AUREA.Callback.Registra('pref:elencoIscrivi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'L\'istanza si presenta in Prefettura.') end

    -- Il controllo che l'elenco esiste per fare
    local precedenti = exports.ita_giustizia:Precedenti(g.citizenid) or {}
    for _, p in ipairs(precedenti) do
        if U.Contiene(PREF.Elenco.reatiOstativi, tostring(p.articolo)) then
            return rispondi(false, ('Iscrizione negata: risulta a carico un procedimento per %s. Per legge è ostativo.')
                :format(p.reato or p.articolo))
        end
        if (p.gravita or 0) > PREF.Elenco.gravitaMassimaPrecedenti then
            return rispondi(false, 'Iscrizione negata: i precedenti a carico non consentono l\'iscrizione all\'elenco.')
        end
    end

    if not g:SottraiOvunque(PREF.Elenco.costoIstruttoria, 'istruttoria elenco prefettizio') then
        return rispondi(false, ('Servono %s per l\'istruttoria.'):format(U.Euro(PREF.Elenco.costoIstruttoria)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_prefettura', PREF.Elenco.costoIstruttoria, g.citizenid)

    MySQL.query.await([[
        INSERT INTO prefettura_elenco (citizenid, iscritto_il, scadenza, sospeso, motivo_sospensione)
        VALUES (?, CURDATE(), ?, 0, NULL)
        ON DUPLICATE KEY UPDATE scadenza = VALUES(scadenza), sospeso = 0, motivo_sospensione = NULL
    ]], { g.citizenid, U.DataPiuGiorni(PREF.Elenco.giorniValidita) })

    AUREA.Log('economia', 'info', g, 'iscritto all\'elenco prefettizio addetti ai servizi di controllo')
    rispondi(true, ('Iscrizione registrata, valida %d giorni. Da adesso puoi fare il filtro in un locale.')
        :format(PREF.Elenco.giorniValidita))
end)

--- Chi combina guai sulla porta di un locale esce dall'elenco, e senza
--- elenco quel mestiere non lo fa più.
AddEventHandler('aurea:prefettura:sospendiElenco', function(citizenid, motivo)
    if type(citizenid) ~= 'string' then return end

    local aggiornate = MySQL.update.await([[
        UPDATE prefettura_elenco SET sospeso = 1, motivo_sospensione = ?
        WHERE citizenid = ? AND sospeso = 0
    ]], { tostring(motivo or 'provvedimento del Prefetto'), citizenid })
    if (aggiornate or 0) == 0 then return end

    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Prefettura',
        ('Sei stato sospeso dall\'elenco degli addetti ai servizi di controllo. Motivo: %s.')
            :format(motivo or 'provvedimento'))

    AUREA.Log('economia', 'avviso', nil, ('%s sospeso dall\'elenco prefettizio (%s)')
        :format(citizenid, tostring(motivo)))
end)

-- ---------------------------------------------------------------------------
--  Ordinanze del Prefetto
-- ---------------------------------------------------------------------------
AUREA.Comando('sospendipatente', 'utente', 'Ordinanza di sospensione della patente (Prefetto)', {
    { name = 'id', help = 'ID del destinatario' },
    { name = 'giorni', help = 'giorni di sospensione' },
    { name = 'motivo', help = 'motivo dell\'ordinanza' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'ordinanze') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📄', titolo = 'Prefettura',
            testo = 'Solo il Prefetto o un viceprefetto in servizio possono emettere l\'ordinanza.' })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local giorni = math.floor(tonumber(args[2]) or 0)
    local motivo = table.concat(args, ' ', 3)

    if not bersaglio or giorni <= 0 or motivo == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📄', titolo = 'Uso',
            testo = '/sospendipatente <id> <giorni> <motivo>' })
    end
    if giorni > PREF.Ordinanze.sospensioneMassimaGiorni then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📄', titolo = 'Prefettura',
            testo = ('Il massimo è %d giorni.'):format(PREF.Ordinanze.sospensioneMassimaGiorni) })
    end

    exports.ita_codicestrada:PatenteSospendi(bersaglio.citizenid, giorni, motivo)

    MySQL.insert.await([[
        INSERT INTO prefettura_ordinanze (citizenid, tipo, giorni, motivo, emessa_da, eseguita)
        VALUES (?, 'sospensione_patente', ?, ?, ?, 1)
    ]], { bersaglio.citizenid, giorni, motivo, g.citizenid })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '📄', titolo = 'Ordinanza emessa',
        testo = ('Patente di %s sospesa per %d giorni.'):format(bersaglio:NomeCompleto(), giorni) })

    AUREA.Log('multe', 'avviso', g, ('ordinanza di sospensione patente su %s: %d giorni (%s)')
        :format(bersaglio.citizenid, giorni, motivo))
end)

AUREA.Comando('fogliovia', 'utente', 'Foglio di via obbligatorio (Prefetto)', {
    { name = 'id', help = 'ID del destinatario' },
    { name = 'ore', help = 'durata in ore' },
    { name = 'motivo', help = 'motivo' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not funzionario(g, 'ordinanze') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📄', titolo = 'Prefettura',
            testo = 'Non hai la competenza per emettere il provvedimento.' })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local ore = math.floor(tonumber(args[2]) or PREF.Ordinanze.foglioVia.oreDefault)
    local motivo = table.concat(args, ' ', 3)

    if not bersaglio or motivo == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '📄', titolo = 'Uso', testo = '/fogliovia <id> <ore> <motivo>' })
    end
    ore = U.Clamp(ore, 1, PREF.Ordinanze.foglioVia.oreMassime)

    MySQL.insert.await([[
        INSERT INTO prefettura_ordinanze (citizenid, tipo, giorni, motivo, emessa_da, eseguita)
        VALUES (?, 'foglio_via', ?, ?, ?, 1)
    ]], { bersaglio.citizenid, math.max(1, math.floor(ore / 24)), motivo, g.citizenid })

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'errore', icona = '📄', durata = 20000,
        titolo = 'Foglio di via obbligatorio',
        testo = ('Ti è stato notificato un foglio di via per %d ore. Motivo: %s.'):format(ore, motivo) })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '📄', titolo = 'Provvedimento notificato',
        testo = ('Foglio di via a %s per %d ore.'):format(bersaglio:NomeCompleto(), ore) })

    AUREA.Log('giustizia', 'avviso', g, ('foglio di via a %s per %d ore (%s)')
        :format(bersaglio.citizenid, ore, motivo))
end)

-- ---------------------------------------------------------------------------
--  App del telefono: lo stato dei propri ricorsi
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'prefettura',
    nome = 'Ricorsi',
    icona = '📄',
    colore = 'linear-gradient(150deg,#5c6f8f,#2f3c52)',
    ordine = 132,

    condizione = function(g)
        return (MySQL.scalar.await('SELECT COUNT(*) FROM prefettura_ricorsi WHERE citizenid = ?',
            { g.citizenid }) or 0) > 0
    end,

    badge = function(g)
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM prefettura_ricorsi WHERE citizenid = ? AND stato = ?',
            { g.citizenid, 'istruttoria' }) or 0
    end,

    schermata = function(g)
        local righe = MySQL.query.await([[
            SELECT r.stato, r.sede, r.motivo, r.multa_id, r.importo_originario,
                   r.importo_ingiunto, r.decisione,
                   TIMESTAMPDIFF(MINUTE, NOW(), r.decide_entro) AS minutiResidui
            FROM prefettura_ricorsi r
            WHERE r.citizenid = ? ORDER BY r.presentato_il DESC LIMIT 12
        ]], { g.citizenid }) or {}

        local voci = {}
        for _, r in ipairs(righe) do
            local stato, tono
            if r.stato == 'istruttoria' then
                stato = ('In istruttoria · %d minuti al termine')
                    :format(math.max(0, r.minutiResidui or 0))
                tono = nil
            elseif r.stato == 'silenzio_accoglimento' then
                stato = 'Accolto per silenzio: nessuno ha deciso entro il termine'
                tono = 'verde'
            elseif r.stato == 'accolto' then
                stato = r.decisione or 'Accolto, verbale annullato'
                tono = 'verde'
            else
                stato = ('Rigettato · ora dovuti %s'):format(U.Euro(r.importo_ingiunto or 0))
                tono = 'rosso'
            end

            voci[#voci + 1] = {
                icona = r.sede == 'prefetto' and '🏛' or '⚖',
                titolo = ('Verbale n. %d — %s'):format(r.multa_id,
                    r.sede == 'prefetto' and 'Prefetto' or 'Giudice di Pace'),
                sottotitolo = ('%s\n%s'):format(r.motivo, stato),
                valore = U.Euro(r.importo_originario),
                tono = tono, inerte = true,
            }
        end
        if #voci == 0 then
            voci[1] = { icona = '📄', titolo = 'Nessun ricorso',
                        sottotitolo = 'Si deposita in Prefettura, entro sessanta giorni dal verbale.',
                        inerte = true }
        end

        return {
            tipo = 'lista',
            sottotitolo = 'Ricorsi contro i verbali',
            voci = voci,
        }
    end,
})
