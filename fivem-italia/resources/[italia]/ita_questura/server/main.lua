--[[
    AUREA · Questura — Polizia Amministrativa (server)

    Tutto quello che qui si rilascia è una cosa che qualcun altro poi
    legge: il porto d'armi lo legge aurea_armi quando controlla se puoi
    girare armato, la licenza di pubblico spettacolo la legge
    ita_discoteca prima di aprire una serata, il DASPO lo legge il
    buttafuori sulla porta.

    Non si rilascia niente che non serva a nessuno.
]]

local U = AUREA.Util

local function amministrativa(g)
    return g and g.lavoro.nome == QUE.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(QUE.Permesso)
end

local function alloSportello(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - QUE.Sportello.coord) <= 8.0
end

--- I precedenti che bloccano, con il motivo.
local function ostacoli(citizenid, reatiOstativi, gravitaMassima)
    local precedenti = exports.ita_giustizia:Precedenti(citizenid) or {}
    for _, p in ipairs(precedenti) do
        if U.Contiene(reatiOstativi, tostring(p.articolo)) then
            return ('a carico risulta un procedimento per %s: è ostativo per legge.')
                :format(p.reato or p.articolo)
        end
        if (p.gravita or 0) > gravitaMassima then
            return 'i precedenti a carico non consentono il rilascio.'
        end
    end
    return nil
end

local function procedimentiAperti(citizenid)
    local aperti = exports.ita_giustizia:Precedenti(citizenid, true) or {}
    return #aperti
end

-- ---------------------------------------------------------------------------
--  Passaporto
-- ---------------------------------------------------------------------------
local function passaportoDi(citizenid)
    return MySQL.single.await([[
        SELECT numero, rilascio, scadenza, ritirato, motivo_ritiro
        FROM questura_passaporti
        WHERE citizenid = ?
    ]], { citizenid })
end

--- Valido davvero: esiste, non è ritirato, non è scaduto.
exports('PassaportoValido', function(citizenid)
    local p = MySQL.scalar.await([[
        SELECT numero FROM questura_passaporti
        WHERE citizenid = ? AND ritirato = 0 AND scadenza >= CURDATE()
    ]], { citizenid })
    return p ~= nil
end)

AUREA.Callback.Registra('que:passaportoStato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local p = passaportoDi(g.citizenid)
    if p then p.scadenzaIT = U.DataIT(math.floor((p.scadenza or 0) / 1000)) end

    rispondi({
        passaporto = p,
        pendenze = procedimentiAperti(g.citizenid),
        costo = QUE.Passaporto.costo,
    })
end)

AUREA.Callback.Registra('que:passaportoChiedi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'L\'istanza si presenta in Questura.') end

    local esistente = passaportoDi(g.citizenid)
    if esistente and esistente.ritirato == 0 then
        return rispondi(false, ('Hai già un passaporto valido, n. %s.'):format(esistente.numero))
    end

    -- Art. 3 L. 1185/1967
    if QUE.Passaporto.ostativoConProcedimentiAperti then
        local aperti = procedimentiAperti(g.citizenid)
        if aperti > 0 then
            MySQL.insert.await([[
                INSERT INTO questura_istanze (citizenid, tipo, stato, motivo, decisa_il)
                VALUES (?, 'passaporto', 'rigettata', ?, NOW())
            ]], { g.citizenid, ('%d procedimenti penali pendenti'):format(aperti) })

            return rispondi(false, ('Rilascio negato: risultano %d procedimenti penali pendenti a tuo carico (art. 3 L. 1185/1967). Finché sono aperti, non si parte.')
                :format(aperti))
        end
    end

    if not g:SottraiOvunque(QUE.Passaporto.costo, 'passaporto') then
        return rispondi(false, ('Servono %s fra contributo e bollo.'):format(U.Euro(QUE.Passaporto.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_questura', QUE.Passaporto.costo, g.citizenid)

    local numero = ('YA%s'):format(U.Random(7, '0123456789'))
    MySQL.query.await([[
        INSERT INTO questura_passaporti (citizenid, numero, rilascio, scadenza, ritirato, motivo_ritiro)
        VALUES (?, ?, CURDATE(), ?, 0, NULL)
        ON DUPLICATE KEY UPDATE numero = VALUES(numero), rilascio = CURDATE(),
                                scadenza = VALUES(scadenza), ritirato = 0, motivo_ritiro = NULL
    ]], { g.citizenid, numero, U.DataPiuGiorni(QUE.Passaporto.giorniValidita) })

    MySQL.insert.await([[
        INSERT INTO questura_istanze (citizenid, tipo, stato, motivo, decisa_il)
        VALUES (?, 'passaporto', 'accolta', 'nulla osta', NOW())
    ]], { g.citizenid })

    AUREA.Log('economia', 'info', g, ('passaporto rilasciato: %s'):format(numero))
    rispondi(true, ('Passaporto n. %s rilasciato.'):format(numero))
end)

--- Chi finisce indagato per qualcosa di serio si vede ritirare il
--- passaporto: è la stessa regola, applicata dopo invece che prima.
AddEventHandler('aurea:giustizia:fascicolo', function(citizenid, gravita, codice)
    if (tonumber(gravita) or 0) < 3 then return end

    local ritirati = MySQL.update.await([[
        UPDATE questura_passaporti SET ritirato = 1, motivo_ritiro = ?
        WHERE citizenid = ? AND ritirato = 0
    ]], { ('procedimento penale pendente (art. %s)'):format(tostring(codice)), citizenid })
    if (ritirati or 0) == 0 then return end

    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Questura',
        'Il tuo passaporto è stato ritirato: risulta un procedimento penale a tuo carico.')

    AUREA.Log('giustizia', 'avviso', nil, ('%s: passaporto ritirato (art. %s)')
        :format(citizenid, tostring(codice)))
end)

-- ---------------------------------------------------------------------------
--  Porto d'armi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('que:portoArmiStato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local titoli = MySQL.query.await([[
        SELECT tipo, rilascio, scadenza, revocato, motivo_revoca
        FROM porto_armi WHERE citizenid = ?
    ]], { g.citizenid }) or {}
    for _, t in ipairs(titoli) do
        t.scadenzaIT = U.DataIT(math.floor((t.scadenza or 0) / 1000))
    end

    -- Il certificato del Tiro a Segno, se c'è
    local ok, certificato = pcall(function()
        return exports.ita_tsn:CertificatoValido(g.citizenid)
    end)

    rispondi({ titoli = titoli, certificato = ok and certificato == true })
end)

AUREA.Callback.Registra('que:portoArmiChiedi', function(src, rispondi, tipoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'L\'istanza si presenta in Questura.') end

    local tipo = QUE.GetTipoPortoArmi(tipoId)
    if not tipo then return rispondi(false, 'Tipo di titolo non valido.') end

    -- Il certificato di idoneità al maneggio delle armi
    if QUE.PortoArmi.richiedeCertificatoTSN then
        local ok, certificato = pcall(function()
            return exports.ita_tsn:CertificatoValido(g.citizenid)
        end)
        if not ok or certificato ~= true then
            return rispondi(false, 'Manca il certificato di idoneità al maneggio delle armi. Si ottiene al Tiro a Segno Nazionale, non qui.')
        end
    end

    local ostacolo = ostacoli(g.citizenid, QUE.PortoArmi.reatiOstativi, QUE.PortoArmi.gravitaMassima)
    if ostacolo then
        MySQL.insert.await([[
            INSERT INTO questura_istanze (citizenid, tipo, dettaglio, stato, motivo, decisa_il)
            VALUES (?, 'porto_armi', ?, 'rigettata', ?, NOW())
        ]], { g.citizenid, tipo.id, ostacolo })
        return rispondi(false, ('Rilascio negato: %s'):format(ostacolo))
    end

    if not g:SottraiOvunque(tipo.costo, tipo.nome) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(tipo.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_questura', tipo.costo, g.citizenid)

    MySQL.query.await([[
        INSERT INTO porto_armi (citizenid, tipo, rilascio, scadenza, revocato, motivo_revoca)
        VALUES (?, ?, CURDATE(), ?, 0, NULL)
        ON DUPLICATE KEY UPDATE rilascio = CURDATE(), scadenza = VALUES(scadenza),
                                revocato = 0, motivo_revoca = NULL
    ]], { g.citizenid, tipo.id, U.DataPiuGiorni(tipo.giorni) })

    MySQL.insert.await([[
        INSERT INTO questura_istanze (citizenid, tipo, dettaglio, stato, motivo, decisa_il)
        VALUES (?, 'porto_armi', ?, 'accolta', 'nulla osta', NOW())
    ]], { g.citizenid, tipo.id })

    AUREA.Log('economia', 'info', g, ('porto d\'armi %s rilasciato'):format(tipo.id))
    rispondi(true, ('%s rilasciato, valido %d giorni.'):format(tipo.nome, tipo.giorni))
end)

AUREA.Comando('revocaportoarmi', 'utente', 'Revoca un titolo di porto d\'armi (Questura)', {
    { name = 'id', help = 'ID del destinatario' },
    { name = 'motivo', help = 'motivo della revoca' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not amministrativa(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🛂', titolo = 'Questura',
            testo = 'Riservato alla Polizia Amministrativa in servizio.' })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local motivo = table.concat(args, ' ', 2)
    if not bersaglio or motivo == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🛂', titolo = 'Uso', testo = '/revocaportoarmi <id> <motivo>' })
    end

    local n = MySQL.update.await(
        'UPDATE porto_armi SET revocato = 1, motivo_revoca = ? WHERE citizenid = ? AND revocato = 0',
        { motivo, bersaglio.citizenid })

    if (n or 0) == 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🛂', titolo = 'Questura',
            testo = 'Non risultano titoli validi da revocare.' })
    end

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'errore', icona = '🛂', durata = 18000,
        titolo = 'Porto d\'armi revocato',
        testo = ('Provvedimento del Questore. Motivo: %s.'):format(motivo) })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🛂', titolo = 'Revoca eseguita',
        testo = ('%d titoli revocati a %s.'):format(n, bersaglio:NomeCompleto()) })

    AUREA.Log('giustizia', 'avviso', g, ('revocato il porto d\'armi a %s (%s)')
        :format(bersaglio.citizenid, motivo))
end)

-- ---------------------------------------------------------------------------
--  Licenza di pubblico spettacolo (art. 68 TULPS)
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('que:licenzaLocali', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT codice, nome, capienza, licenza_scadenza, sospeso,
               DATEDIFF(licenza_scadenza, CURDATE()) AS giorni
        FROM locali_notturni WHERE gestore = ?
    ]], { g.citizenid }) or {}

    for _, l in ipairs(righe) do
        l.valida = l.licenza_scadenza ~= nil and (l.giorni or -1) >= 0 and l.sospeso == 0
        l.scadenzaIT = l.licenza_scadenza and U.DataIT(math.floor(l.licenza_scadenza / 1000)) or nil
    end
    rispondi(righe, QUE.LicenzaSpettacolo.costo, QUE.LicenzaSpettacolo.giorniValidita)
end)

AUREA.Callback.Registra('que:licenzaChiedi', function(src, rispondi, codiceLocale)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'L\'istanza si presenta in Questura.') end

    local locale = MySQL.single.await(
        'SELECT codice, nome, gestore, sospeso FROM locali_notturni WHERE codice = ?', { codiceLocale })
    if not locale then return rispondi(false, 'Locale non trovato.') end
    if QUE.LicenzaSpettacolo.richiedeGestione and locale.gestore ~= g.citizenid then
        return rispondi(false, 'La licenza la chiede chi gestisce il locale.')
    end
    if locale.sospeso == 1 then
        return rispondi(false, 'Il locale è sotto provvedimento di sospensione: prima si chiude quella partita.')
    end

    local ostacolo = ostacoli(g.citizenid, QUE.PortoArmi.reatiOstativi, 2)
    if ostacolo then
        return rispondi(false, ('Licenza negata: %s'):format(ostacolo))
    end

    if not g:Sottrai('banca', QUE.LicenzaSpettacolo.costo, 'licenza di pubblico spettacolo') then
        return rispondi(false, ('Servono %s sul conto.'):format(U.Euro(QUE.LicenzaSpettacolo.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_questura', QUE.LicenzaSpettacolo.costo, g.citizenid)

    MySQL.update.await('UPDATE locali_notturni SET licenza_scadenza = ? WHERE codice = ?',
        { U.DataPiuGiorni(QUE.LicenzaSpettacolo.giorniValidita), locale.codice })

    MySQL.insert.await([[
        INSERT INTO questura_istanze (citizenid, tipo, dettaglio, stato, motivo, decisa_il)
        VALUES (?, 'licenza_spettacolo', ?, 'accolta', 'art. 68 TULPS', NOW())
    ]], { g.citizenid, locale.codice })

    AUREA.Log('economia', 'info', g, ('licenza art. 68 TULPS per %s'):format(locale.nome))
    rispondi(true, ('Licenza rilasciata per %s, valida %d giorni.')
        :format(locale.nome, QUE.LicenzaSpettacolo.giorniValidita))
end)

-- ---------------------------------------------------------------------------
--  DASPO
-- ---------------------------------------------------------------------------
--- Il DASPO in corso su una persona. Con `luogo` si chiede di quel luogo
--- soltanto; senza, va bene qualunque provvedimento aperto.
local function daspoAttivo(citizenid, luogo)
    if luogo and luogo ~= '' then
        return MySQL.single.await([[
            SELECT id, luogo, motivo, scadenza FROM questura_daspo
            WHERE citizenid = ? AND revocato = 0 AND scadenza > NOW() AND luogo = ?
            ORDER BY scadenza DESC LIMIT 1
        ]], { citizenid, luogo })
    end

    return MySQL.single.await([[
        SELECT id, luogo, motivo, scadenza FROM questura_daspo
        WHERE citizenid = ? AND revocato = 0 AND scadenza > NOW()
        ORDER BY scadenza DESC LIMIT 1
    ]], { citizenid })
end

exports('DaspoAttivo', daspoAttivo)

AUREA.Comando('daspo', 'utente', 'Divieto di accesso a luoghi determinati (Questore)', {
    { name = 'id', help = 'ID del destinatario' },
    { name = 'ore', help = 'durata in ore' },
    { name = 'luogo', help = 'luogo interdetto' },
}, function(src, args)
    local g = AUREA.GetPlayer(src)
    if not amministrativa(g) then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚷', titolo = 'Questura',
            testo = 'Il provvedimento lo adotta il Questore, non chiunque.' })
    end

    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    local ore = math.floor(tonumber(args[2]) or QUE.Daspo.oreDefault)
    local luogo = table.concat(args, ' ', 3)

    if not bersaglio or luogo == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚷', titolo = 'Uso',
            testo = ('/daspo <id> <ore> <luogo>  ·  es. %s'):format(QUE.Daspo.luoghi[1]) })
    end
    ore = U.Clamp(ore, 1, QUE.Daspo.oreMassime)

    MySQL.insert.await([[
        INSERT INTO questura_daspo (citizenid, luogo, motivo, con_firma, emesso_da, scadenza)
        VALUES (?, ?, ?, 0, ?, ?)
    ]], { bersaglio.citizenid, luogo,
          ('Provvedimento del Questore su proposta di %s'):format(g:NomeCompleto()),
          g.citizenid, U.DataOraPiuOre(ore) })

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'errore', icona = '🚷', durata = 20000,
        titolo = 'DASPO notificato',
        testo = ('Ti è vietato l\'accesso a: %s. Per %d ore.'):format(luogo, ore) })

    TriggerEvent('aurea:telefono:messaggioSistema', bersaglio.citizenid, 'Questura',
        ('Divieto di accesso a "%s" per %d ore. Chi ti fa entrare risponde con te.'):format(luogo, ore))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🚷', titolo = 'DASPO emesso',
        testo = ('%s — %s per %d ore.'):format(bersaglio:NomeCompleto(), luogo, ore) })

    AUREA.Log('giustizia', 'avviso', g, ('DASPO a %s su "%s" per %d ore')
        :format(bersaglio.citizenid, luogo, ore))
end)

-- ---------------------------------------------------------------------------
--  App del telefono: i documenti di polizia
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'questura',
    nome = 'Documenti',
    icona = '🛂',
    colore = 'linear-gradient(150deg,#3d6ea8,#1f3a55)',
    ordine = 134,

    schermata = function(g)
        local voci = {}

        local p = passaportoDi(g.citizenid)
        if p then
            voci[#voci + 1] = {
                icona = '🛂', titolo = ('Passaporto n. %s'):format(p.numero),
                sottotitolo = p.ritirato == 1
                    and ('RITIRATO — %s'):format(p.motivo_ritiro or 'provvedimento')
                    or ('Scade il %s'):format(U.DataIT(math.floor((p.scadenza or 0) / 1000))),
                tono = p.ritirato == 1 and 'rosso' or 'verde', inerte = true,
            }
        else
            voci[#voci + 1] = { icona = '🛂', titolo = 'Nessun passaporto',
                sottotitolo = 'Si chiede in Questura. Con procedimenti aperti non si rilascia.',
                inerte = true }
        end

        local titoli = MySQL.query.await(
            'SELECT tipo, scadenza, revocato, motivo_revoca FROM porto_armi WHERE citizenid = ?',
            { g.citizenid }) or {}
        for _, t in ipairs(titoli) do
            local tipo = QUE.GetTipoPortoArmi(t.tipo)
            voci[#voci + 1] = {
                icona = '🔫', titolo = tipo and tipo.nome or t.tipo,
                sottotitolo = t.revocato == 1
                    and ('REVOCATO — %s'):format(t.motivo_revoca or 'provvedimento')
                    or ('Valido fino al %s'):format(U.DataIT(math.floor((t.scadenza or 0) / 1000))),
                tono = t.revocato == 1 and 'rosso' or 'verde', inerte = true,
            }
        end

        local daspo = MySQL.query.await([[
            SELECT luogo, motivo, scadenza FROM questura_daspo
            WHERE citizenid = ? AND revocato = 0 AND scadenza > NOW()
        ]], { g.citizenid }) or {}
        for _, d in ipairs(daspo) do
            voci[#voci + 1] = {
                icona = '🚷', titolo = ('DASPO — %s'):format(d.luogo),
                sottotitolo = ('Fino al %s'):format(U.DataOraIT(math.floor((d.scadenza or 0) / 1000))),
                tono = 'rosso', inerte = true,
            }
        end

        return {
            tipo = 'lista',
            sottotitolo = 'Licenze di polizia e provvedimenti a tuo carico',
            voci = voci,
        }
    end,
})
