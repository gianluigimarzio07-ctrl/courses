--[[
    AUREA · Studio notarile (server)

    Un rogito è l'unico punto del server in cui tre persone devono essere
    d'accordo nello stesso momento: chi vende, chi compra e chi riceve
    l'atto. Il server verifica tutte e tre le posizioni — non si roga per
    telefono.

    E verifica la proprietà al momento della firma, non al momento della
    proposta: fra l'una e l'altra il venditore potrebbe aver venduto la
    casa a qualcun altro, ed è esattamente il tipo di corsa che un atto
    pubblico esiste per impedire.
]]

local U = AUREA.Util

local proposte = {}     -- [idNotaio] = { immobile, venditore, compratore, prezzo }

-- ---------------------------------------------------------------------------
--  Chi roga
-- ---------------------------------------------------------------------------
local function notaio(g)
    return g and g.lavoro.nome == NOT.Lavoro and g:HaPermessoLavoro(NOT.Permesso)
end

local function vicino(a, b, distanza)
    return #(GetEntityCoords(GetPlayerPed(a)) - GetEntityCoords(GetPlayerPed(b))) <= distanza
end

--- Ha già un'abitazione? Decide l'agevolazione prima casa.
local function haAbitazione(citizenid)
    local righe = MySQL.query.await('SELECT tipo FROM immobili WHERE proprietario = ?', { citizenid }) or {}
    for _, r in ipairs(righe) do
        if NOT.EAbitativo(r.tipo) then return true end
    end
    return false
end

--- Chi può disporre dell'immobile: il proprietario, o chi ha procura.
local function puoVendere(citizenid, idImmobile)
    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { idImmobile })
    if not i then return nil, 'Immobile inesistente.' end
    if i.proprietario == citizenid then return i, nil, false end

    local p = MySQL.single.await([[
        SELECT id FROM notaio_procure
        WHERE immobile_id = ? AND delegato = ? AND revocata = 0 AND scade_il > NOW() LIMIT 1
    ]], { idImmobile, citizenid })
    if p then return i, nil, true end

    return nil, 'Non sei il proprietario e non hai una procura su questo immobile.'
end

--- Di cosa può disporre una persona: quello che possiede più quello su
--- cui ha una procura viva. Serve a due callback diverse e non vale la
--- pena scriverla due volte.
local function disponibiliPer(citizenid)
    local propri = MySQL.query.await([[
        SELECT id, codice, nome, tipo, indirizzo, prezzo, inquilino
        FROM immobili WHERE proprietario = ?
    ]], { citizenid }) or {}

    local perProcura = MySQL.query.await([[
        SELECT i.id, i.codice, i.nome, i.tipo, i.indirizzo, i.prezzo, i.inquilino
        FROM notaio_procure p
        JOIN immobili i ON i.id = p.immobile_id
        WHERE p.delegato = ? AND p.revocata = 0 AND p.scade_il > NOW()
    ]], { citizenid }) or {}

    for _, r in ipairs(perProcura) do
        r.perProcura = true
        propri[#propri + 1] = r
    end
    return propri
end

-- ---------------------------------------------------------------------------
--  Gli immobili disponibili per un rogito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('not:vendibili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    rispondi(disponibiliPer(g.citizenid))
end)

--- Gli immobili di un'altra persona: la chiede il notaio quando le parti
--- sono davanti a lui. Non è una fuga di dati — chi sta al banco ha già
--- detto al notaio cosa vuole vendere.
AUREA.Callback.Registra('not:vendibiliDi', function(src, rispondi, bersaglioSrc)
    local n = AUREA.GetPlayer(src)
    if not notaio(n) then return rispondi({}) end

    local v = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not v or not vicino(src, v.source, NOT.Studio.distanzaParti) then return rispondi({}) end

    rispondi(disponibiliPer(v.citizenid))
end)

-- ---------------------------------------------------------------------------
--  Il rogito
--
--  Lo avvia il notaio, con le due parti davanti.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('not:preparaRogito', function(src, rispondi, venditoreSrc, compratoreSrc, idImmobile, prezzoEuro)
    local n = AUREA.GetPlayer(src)
    if not notaio(n) then return rispondi(false, 'L\'atto pubblico lo riceve un notaio.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - NOT.Studio.coord) > 6.0 then
        return rispondi(false, 'L\'atto si riceve in studio.')
    end

    local v = AUREA.GetPlayer(tonumber(venditoreSrc))
    local c = AUREA.GetPlayer(tonumber(compratoreSrc))
    if not v or not c then return rispondi(false, 'Una delle parti non è collegata.') end
    if v.citizenid == c.citizenid then return rispondi(false, 'Non si vende a sé stessi.') end

    if not vicino(src, v.source, NOT.Studio.distanzaParti)
        or not vicino(src, c.source, NOT.Studio.distanzaParti) then
        return rispondi(false, 'Le parti devono essere entrambe davanti a te.')
    end

    local i, errore = puoVendere(v.citizenid, tonumber(idImmobile))
    if not i then return rispondi(false, errore) end
    if i.inquilino then return rispondi(false, 'L\'immobile è locato: prima si risolve il contratto.') end

    local prezzo = U.ACentesimi(tonumber(tostring(prezzoEuro):gsub(',', '.')) or 0)
    if prezzo <= 0 then return rispondi(false, 'Prezzo non valido.') end

    local primaCasa = NOT.EAbitativo(i.tipo) and not haAbitazione(c.citizenid)
    local q = NOT.Conteggio(prezzo, primaCasa)

    proposte[n.citizenid] = {
        immobile = i.id, nomeImmobile = i.nome,
        venditore = v.citizenid, compratore = c.citizenid,
        prezzo = prezzo, primaCasa = primaCasa, conteggio = q,
        notaio = n.citizenid, nomeNotaio = n:NomeCompleto(),
        creata = os.time(),
    }

    -- Le parti devono sapere cosa stanno per firmare, con i numeri veri
    local riepilogo = ('%s\nPrezzo %s\nImposta di registro %s%s\nIpocatastali %s\nOnorario %s + IVA %s\n\nIl compratore versa in tutto %s.')
        :format(i.nome, U.Euro(prezzo), U.Euro(q.registro),
                primaCasa and ' (agevolazione prima casa)' or '',
                U.Euro(q.ipocatastali), U.Euro(q.onorario), U.Euro(q.ivaOnorario),
                U.Euro(q.totaleCompratore))

    TriggerClientEvent('not:proposta', c.source, { ruolo = 'compratore', notaio = n.citizenid, testo = riepilogo })
    TriggerClientEvent('not:proposta', v.source, { ruolo = 'venditore', notaio = n.citizenid, testo = riepilogo })

    rispondi(true, ('Atto predisposto. Le parti devono accettare.\n\n%s'):format(riepilogo))
end)

-- ---------------------------------------------------------------------------
--  Le parti firmano
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('not:firma', function(src, rispondi, idNotaio, accetta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local p = proposte[idNotaio]
    if not p then return rispondi(false, 'Nessun atto in corso.') end

    if not accetta then
        proposte[idNotaio] = nil
        local altro = AUREA.GetPlayerByCitizenId(
            g.citizenid == p.venditore and p.compratore or p.venditore)
        if altro then
            TriggerClientEvent('aurea:ui:notifica', altro.source, {
                tipo = 'errore', icona = '📜', titolo = 'Atto non concluso',
                testo = 'L\'altra parte si è ritirata.', durata = 12000 })
        end
        return rispondi(true, 'Ti sei ritirato dall\'atto.')
    end

    if g.citizenid == p.venditore then p.firmaVenditore = true
    elseif g.citizenid == p.compratore then p.firmaCompratore = true
    else return rispondi(false, 'Non sei parte di questo atto.') end

    if not (p.firmaVenditore and p.firmaCompratore) then
        return rispondi(true, 'Firma registrata. Si attende l\'altra parte.')
    end

    -- Da qui in poi è la stipula. Si ricontrolla tutto: fra la proposta e
    -- la firma può essere cambiato tutto.
    local notaioG = AUREA.GetPlayerByCitizenId(p.notaio)
    local v = AUREA.GetPlayerByCitizenId(p.venditore)
    local c = AUREA.GetPlayerByCitizenId(p.compratore)
    proposte[idNotaio] = nil

    if not notaioG or not v or not c then
        return rispondi(false, 'Una delle parti si è scollegata: l\'atto non si può ricevere.')
    end

    local i = puoVendere(p.venditore, p.immobile)
    if not i then
        return rispondi(false, 'Il venditore non ha più la disponibilità dell\'immobile.')
    end

    local q = p.conteggio
    if not c:Sottrai('banca', q.totaleCompratore, ('acquisto %s'):format(p.nomeImmobile)) then
        TriggerClientEvent('aurea:ui:notifica', notaioG.source, {
            tipo = 'errore', icona = '📜', titolo = 'Atto non ricevuto',
            testo = 'Il compratore non ha la provvista.', durata = 14000 })
        return rispondi(false, ('Ti servono %s sul conto.'):format(U.Euro(q.totaleCompratore)))
    end

    -- Il prezzo al venditore
    AUREA.Denaro.AggiungiOffline(p.venditore, 'banca', p.prezzo, ('vendita %s'):format(p.nomeImmobile))

    -- Le imposte all'erario
    TriggerEvent('aurea:fisco:incasso', 'imposta_registro', q.registro + q.ipocatastali, p.compratore)
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', q.ivaOnorario, p.compratore)

    -- L'onorario si divide fra il professionista e la cassa dello studio
    local alNotaio = math.floor(q.onorario * NOT.Onorario.quotaAlProfessionista)
    AUREA.Denaro.AggiungiOffline(p.notaio, 'banca', alNotaio, ('onorario rogito %s'):format(p.nomeImmobile))
    pcall(function()
        exports.aurea_azienda:VersaInCassa(NOT.Lavoro, q.onorario - alNotaio,
            ('rogito %s'):format(p.nomeImmobile))
    end)

    -- Il trasferimento
    MySQL.update.await([[
        UPDATE immobili SET proprietario = ?, inquilino = NULL, in_vendita = 0, chiavi = ?
        WHERE id = ?
    ]], { p.compratore, json.encode({ p.compratore }), p.immobile })

    -- Le procure sull'immobile decadono con la vendita
    MySQL.update('UPDATE notaio_procure SET revocata = 1 WHERE immobile_id = ?', { p.immobile })

    exports.aurea_inventory:Rimuovi(p.venditore, 'chiavi_casa', 1)
    exports.aurea_inventory:Aggiungi(p.compratore, 'chiavi_casa', 1,
        { immobile = p.immobile, nome = p.nomeImmobile })

    MySQL.insert('INSERT INTO notaio_atti (tipo, immobile_id, venditore, compratore, prezzo, imposte, onorario, notaio, prima_casa) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { 'compravendita', p.immobile, p.venditore, p.compratore, p.prezzo,
          q.registro + q.ipocatastali, q.onorario, p.nomeNotaio, p.primaCasa and 1 or 0 })

    -- Il notaio trasferisce la proprietà, non aggiorna il catasto: quella
    -- è la voltura, e la presenta chi ha comprato.
    TriggerEvent('aurea:notaio:trasferito', p.immobile, p.nomeImmobile, p.venditore, p.compratore)

    local messaggio = ('%s trasferito.\nPrezzo %s · imposte %s · onorario %s.')
        :format(p.nomeImmobile, U.Euro(p.prezzo),
                U.Euro(q.registro + q.ipocatastali), U.Euro(q.onorario))

    for _, giocatore in ipairs({ v, c, notaioG }) do
        TriggerClientEvent('aurea:ui:notifica', giocatore.source, {
            tipo = 'successo', icona = '📜', durata = 20000,
            titolo = 'Atto ricevuto', testo = messaggio,
        })
    end

    AUREA.Log('economia', 'info', notaioG,
        ('ha rogato la vendita di %s da %s a %s per %s')
            :format(p.nomeImmobile, v:NomeCompleto(), c:NomeCompleto(), U.Euro(p.prezzo)))

    rispondi(true, messaggio)
end)

-- ---------------------------------------------------------------------------
--  Procura a vendere
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('not:procura', function(src, rispondi, delegatoSrc, idImmobile)
    local n = AUREA.GetPlayer(src)
    if not notaio(n) then return rispondi(false, 'L\'autentica la fa il notaio.') end

    local d = AUREA.GetPlayer(tonumber(delegatoSrc))
    if not d then return rispondi(false, 'Il delegato non è collegato.') end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { idImmobile })
    if not i or not i.proprietario then return rispondi(false, 'Immobile senza proprietario.') end

    local p = AUREA.GetPlayerByCitizenId(i.proprietario)
    if not p then return rispondi(false, 'Il proprietario non è collegato.') end
    if not vicino(src, p.source, NOT.Studio.distanzaParti)
        or not vicino(src, d.source, NOT.Studio.distanzaParti) then
        return rispondi(false, 'Proprietario e delegato devono essere entrambi davanti a te.')
    end
    if p.citizenid == d.citizenid then return rispondi(false, 'Non si dà procura a sé stessi.') end

    if not p:Sottrai('banca', NOT.Procura.onorario, 'onorario procura') then
        return rispondi(false, ('Il proprietario non ha %s per l\'onorario.'):format(U.Euro(NOT.Procura.onorario)))
    end
    AUREA.Denaro.AggiungiOffline(n.citizenid, 'banca',
        math.floor(NOT.Procura.onorario * NOT.Onorario.quotaAlProfessionista), 'onorario procura')
    TriggerEvent('aurea:fisco:incasso', 'iva_servizi',
        math.floor(NOT.Procura.onorario * NOT.Onorario.iva / (1 + NOT.Onorario.iva)), p.citizenid)

    MySQL.insert.await([[
        INSERT INTO notaio_procure (immobile_id, concedente, delegato, notaio, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { i.id, p.citizenid, d.citizenid, n:NomeCompleto(), NOT.Procura.durataMinuti })

    TriggerClientEvent('aurea:ui:notifica', d.source, {
        tipo = 'avviso', icona = '📜', durata = 20000,
        titolo = 'Procura a vendere ricevuta',
        testo = ('%s ti ha dato il potere di vendere %s. Vale %d minuti.')
            :format(p:NomeCompleto(), i.nome, NOT.Procura.durataMinuti),
    })
    TriggerClientEvent('aurea:ui:notifica', p.source, {
        tipo = 'avviso', icona = '📜', durata = 22000,
        titolo = 'Procura conferita',
        testo = ('%s può vendere %s al posto tuo, e incassare. La revochi con /revocaprocura.')
            :format(d:NomeCompleto(), i.nome),
    })

    AUREA.Log('economia', 'info', n,
        ('ha autenticato una procura a vendere %s da %s a %s'):format(i.nome, p:NomeCompleto(), d:NomeCompleto()))
    rispondi(true, ('Procura autenticata su %s.'):format(i.nome))
end)

AUREA.Comando('revocaprocura', 'utente', 'Revoca le procure che hai conferito', {},
function(src, _, _, g)
    if not g then return end

    local quante = MySQL.update.await([[
        UPDATE notaio_procure SET revocata = 1
        WHERE concedente = ? AND revocata = 0 AND scade_il > NOW()
    ]], { g.citizenid }) or 0

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = quante > 0 and 'successo' or 'info', icona = '📜', durata = 12000,
        titolo = 'Procure',
        testo = quante > 0 and ('Revocate %d procure. Da adesso nessuno può vendere al posto tuo.'):format(quante)
            or 'Non hai procure in corso.',
    })
    if quante > 0 then AUREA.Log('economia', 'info', g, ('ha revocato %d procure'):format(quante)) end
end)

-- ---------------------------------------------------------------------------
--  Repertorio: gli atti ricevuti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('not:repertorio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not notaio(g) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT a.tipo, a.prezzo, a.imposte, a.onorario, a.prima_casa, a.stipulato_il,
               i.nome AS immobile,
               CONCAT(v.nome, ' ', v.cognome) AS venditore,
               CONCAT(c.nome, ' ', c.cognome) AS compratore
        FROM notaio_atti a
        LEFT JOIN immobili i ON i.id = a.immobile_id
        LEFT JOIN personaggi v ON v.citizenid = a.venditore
        LEFT JOIN personaggi c ON c.citizenid = a.compratore
        ORDER BY a.id DESC LIMIT 25
    ]]) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.stipulato_il or 0) / 1000))
    end
    rispondi(righe)
end)

print('[AUREA] studio notarile: rogiti e procure attivi')
