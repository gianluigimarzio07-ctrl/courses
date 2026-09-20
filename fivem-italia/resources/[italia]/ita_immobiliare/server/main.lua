--[[
    AUREA · Agenzia immobiliare (server)

    La vetrina è pubblica, le proposte no. Un annuncio lo vedono tutti —
    è il senso di metterlo — ma chi ha offerto quanto lo sa solo il
    venditore, e questo è il motivo per cui l'asta al rialzo funziona.

    La provvigione si addebita alla conclusione dell'affare, cioè quando
    la proposta viene accettata. Non al rogito: art. 1755 c.c.
]]

local U = AUREA.Util

local visite = {}       -- [citizenid] = { immobile, scade }

-- ---------------------------------------------------------------------------
--  Chi lavora in agenzia
-- ---------------------------------------------------------------------------
local function agente(g, permesso)
    if not g or g.lavoro.nome ~= IMM.Lavoro then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

--- Il mediatore abilitato.
---
--- Dal 2010 il ruolo degli agenti d'affari in mediazione non esiste più
--- come albo a sé: è una sezione del Registro delle Imprese. Significa
--- che chi media senza impresa iscritta non è un agente con una pendenza
--- burocratica — è un abusivo, e la provvigione non gli spetta
--- (art. 1755 c.c. presuppone il mediatore, non chiunque presenti due
--- persone).
---
--- Chiamata protetta: se ita_registroimprese è fermo, si media lo stesso.
local function mediatoreAbilitato(g)
    if not g then return false, 'sessione non valida' end
    local ok, iscritta, perche = pcall(function()
        return exports.ita_registroimprese:IscrittaAlRegistro(g.citizenid)
    end)
    if ok and iscritta == false then
        return false, perche or 'impresa non iscritta al Registro'
    end
    return true
end

local function immobile(id)
    return MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { id })
end

--- Quanto ha pagato davvero il mercato per immobili dello stesso tipo.
local function valoreDiMercato(tipo)
    return MySQL.scalar.await([[
        SELECT AVG(a.prezzo) FROM notaio_atti a
        JOIN immobili i ON i.id = a.immobile_id
        WHERE i.tipo = ? AND a.tipo = 'compravendita'
    ]], { tipo })
end

-- ---------------------------------------------------------------------------
--  Vetrina
-- ---------------------------------------------------------------------------
local function vetrina()
    local righe = MySQL.query.await([[
        SELECT n.id, n.immobile_id, n.prezzo, n.nota, n.pubblicato_il,
               i.nome, i.tipo, i.indirizzo, i.prezzo AS listino,
               CONCAT(p.nome, ' ', p.cognome) AS venditore
        FROM imm_annunci n
        JOIN immobili i ON i.id = n.immobile_id
        LEFT JOIN personaggi p ON p.citizenid = n.venditore
        WHERE n.stato = 'aperto' AND n.scade_il > NOW()
        ORDER BY n.id DESC LIMIT 40
    ]]) or {}

    for _, r in ipairs(righe) do
        local giudizio, spiegazione = IMM.GiudizioPrezzo(r.prezzo, r.listino)
        r.giudizio, r.spiegazione = giudizio, spiegazione
    end
    return righe
end

AUREA.Callback.Registra('imm:vetrina', function(src, rispondi)
    rispondi(vetrina())
end)

-- ---------------------------------------------------------------------------
--  Pubblicazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('imm:pubblica', function(src, rispondi, idImmobile, prezzoEuro, nota)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - IMM.Agenzia.coord) > 6.0 then
        return rispondi(false, 'L\'incarico si conferisce in agenzia.')
    end

    local i = immobile(tonumber(idImmobile))
    if not i or i.proprietario ~= g.citizenid then
        return rispondi(false, 'Non sei il proprietario di questo immobile.')
    end
    if i.inquilino then return rispondi(false, 'C\'è un inquilino: prima si risolve la locazione.') end

    local quanti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM imm_annunci WHERE venditore = ? AND stato = ? AND scade_il > NOW()',
        { g.citizenid, 'aperto' }) or 0
    if quanti >= IMM.Annunci.massimiPerPersona then
        return rispondi(false, ('Hai già %d annunci in vetrina.'):format(quanti))
    end

    local aperto = MySQL.scalar.await(
        'SELECT id FROM imm_annunci WHERE immobile_id = ? AND stato = ? AND scade_il > NOW()',
        { i.id, 'aperto' })
    if aperto then return rispondi(false, 'Quell\'immobile è già in vetrina.') end

    local prezzo = U.ACentesimi(tonumber(tostring(prezzoEuro):gsub(',', '.')) or 0)
    if prezzo <= 0 then return rispondi(false, 'Prezzo non valido.') end

    if not g:Sottrai('banca', IMM.Annunci.dirittiPubblicazione, 'diritti di pubblicazione') then
        return rispondi(false, ('Servono %s di diritti.'):format(U.Euro(IMM.Annunci.dirittiPubblicazione)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(IMM.Lavoro, IMM.Annunci.dirittiPubblicazione, 'diritti di pubblicazione')
    end)

    MySQL.insert.await([[
        INSERT INTO imm_annunci (immobile_id, venditore, prezzo, nota, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { i.id, g.citizenid, prezzo, tostring(nota or ''):sub(1, 160), IMM.Annunci.durataMinuti })

    local giudizio, spiegazione = IMM.GiudizioPrezzo(prezzo, i.prezzo)

    exports.aurea_ui:NotificaLavoro(IMM.Lavoro, {
        tipo = 'info', icona = '🏠', durata = 14000,
        titolo = 'Nuovo incarico',
        testo = ('%s — %s a %s.'):format(i.nome, i.tipo, U.Euro(prezzo)),
    }, false)

    AUREA.Log('economia', 'info', g, ('ha messo in vendita %s a %s'):format(i.nome, U.Euro(prezzo)))
    rispondi(true, ('%s in vetrina a %s per %d minuti.\n%s')
        :format(i.nome, U.Euro(prezzo), IMM.Annunci.durataMinuti, spiegazione))
end)

AUREA.Comando('ritiraannuncio', 'utente', 'Ritira i tuoi immobili dalla vetrina', {},
function(src, _, _, g)
    if not g then return end
    local quanti = MySQL.update.await(
        'UPDATE imm_annunci SET stato = ? WHERE venditore = ? AND stato = ?',
        { 'ritirato', g.citizenid, 'aperto' }) or 0

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = quanti > 0 and 'successo' or 'info', icona = '🏠', durata = 11000,
        titolo = 'Vetrina',
        testo = quanti > 0 and ('Ritirati %d annunci. I diritti non si restituiscono.'):format(quanti)
            or 'Non hai annunci in vetrina.',
    })
end)

-- ---------------------------------------------------------------------------
--  Visita
--
--  L'agente apre la porta. Il permesso dura pochi minuti e non dà le
--  chiavi: si entra, si guarda, si esce.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('imm:visita', function(src, rispondi, idAnnuncio, visitatoreSrc)
    local g = AUREA.GetPlayer(src)
    if not agente(g, 'visita') then return rispondi(false, 'La visita la accompagna un agente abilitato.') end

    local abilitato, perche = mediatoreAbilitato(g)
    if not abilitato then
        return rispondi(false, ('Non risulti mediatore abilitato: %s. Si sistema alla Camera di Commercio.')
            :format(perche))
    end

    local v = AUREA.GetPlayer(tonumber(visitatoreSrc))
    if not v then return rispondi(false, 'Il visitatore non è collegato.') end

    local a = MySQL.single.await(
        'SELECT * FROM imm_annunci WHERE id = ? AND stato = ? AND scade_il > NOW()',
        { idAnnuncio, 'aperto' })
    if not a then return rispondi(false, 'Annuncio non più valido.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(v.source))) > IMM.Visite.distanzaAgente then
        return rispondi(false, 'Il visitatore deve essere con te.') end

    visite[v.citizenid] = { immobile = a.immobile_id, scade = os.time() + IMM.Visite.durataMinuti * 60 }

    local i = immobile(a.immobile_id)
    TriggerClientEvent('aurea:ui:notifica', v.source, {
        tipo = 'successo', icona = '🔑', durata = 16000,
        titolo = 'Visita autorizzata',
        testo = ('Puoi entrare in %s per %d minuti. Poi la porta torna chiusa.')
            :format(i.nome, IMM.Visite.durataMinuti),
    })

    rispondi(true, ('Visita aperta su %s per %s.'):format(i.nome, v:NomeCompleto()))
end)

--- aurea_case chiede a noi se una persona può entrare senza chiavi.
exports('VisitaAperta', function(citizenid, idImmobile)
    local v = visite[citizenid]
    if not v then return false end
    if os.time() >= v.scade then visite[citizenid] = nil return false end
    return v.immobile == tonumber(idImmobile)
end)

-- ---------------------------------------------------------------------------
--  Proposta d'acquisto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('imm:proponi', function(src, rispondi, idAnnuncio, offertaEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local a = MySQL.single.await(
        'SELECT * FROM imm_annunci WHERE id = ? AND stato = ? AND scade_il > NOW()',
        { idAnnuncio, 'aperto' })
    if not a then return rispondi(false, 'Annuncio non più valido.') end
    if a.venditore == g.citizenid then return rispondi(false, 'Non si compra da sé stessi.') end

    local aperte = MySQL.scalar.await(
        'SELECT COUNT(*) FROM imm_proposte WHERE compratore = ? AND stato = ? AND scade_il > NOW()',
        { g.citizenid, 'aperta' }) or 0
    if aperte >= IMM.Proposte.massimeAperte then
        return rispondi(false, ('Hai già %d proposte in piedi.'):format(aperte))
    end

    local offerta = U.ACentesimi(tonumber(tostring(offertaEuro):gsub(',', '.')) or 0)
    if offerta <= 0 then return rispondi(false, 'Offerta non valida.') end

    local caparra = math.floor(offerta * IMM.Proposte.caparra)
    if not g:Sottrai('banca', caparra, 'caparra confirmatoria') then
        return rispondi(false, ('Serve una caparra di %s (%d%% dell\'offerta).')
            :format(U.Euro(caparra), math.floor(IMM.Proposte.caparra * 100)))
    end

    MySQL.insert.await([[
        INSERT INTO imm_proposte (annuncio_id, compratore, offerta, caparra, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { a.id, g.citizenid, offerta, caparra, IMM.Proposte.validitaMinuti })

    local i = immobile(a.immobile_id)
    TriggerEvent('aurea:telefono:messaggioSistema', a.venditore, 'Agenzia',
        ('Proposta su %s: %s. Hai %d minuti per rispondere (/proposte).')
            :format(i.nome, U.Euro(offerta), IMM.Proposte.validitaMinuti))

    local venditore = AUREA.GetPlayerByCitizenId(a.venditore)
    if venditore then
        TriggerClientEvent('aurea:ui:notifica', venditore.source, {
            tipo = 'avviso', icona = '🏠', durata = 20000,
            titolo = 'Proposta d\'acquisto',
            testo = ('%s su %s. Rispondi con /proposte entro %d minuti.')
                :format(U.Euro(offerta), i.nome, IMM.Proposte.validitaMinuti),
        })
    end

    rispondi(true, ('Proposta di %s trasmessa. Caparra versata: %s — la perdi se ti tiri indietro dopo l\'accettazione.')
        :format(U.Euro(offerta), U.Euro(caparra)))
end)

AUREA.Callback.Registra('imm:proposte', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT p.id, p.offerta, p.caparra, p.stato,
               i.nome AS immobile, n.prezzo AS richiesto,
               CONCAT(c.nome, ' ', c.cognome) AS compratore
        FROM imm_proposte p
        JOIN imm_annunci n ON n.id = p.annuncio_id
        JOIN immobili i ON i.id = n.immobile_id
        LEFT JOIN personaggi c ON c.citizenid = p.compratore
        WHERE n.venditore = ? AND p.stato = 'aperta' AND p.scade_il > NOW()
        ORDER BY p.offerta DESC
    ]], { g.citizenid }) or {}
    rispondi(righe)
end)

AUREA.Callback.Registra('imm:rispondi', function(src, rispondi, idProposta, accetta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local p = MySQL.single.await([[
        SELECT p.*, n.venditore, n.immobile_id, n.id AS annuncio
        FROM imm_proposte p JOIN imm_annunci n ON n.id = p.annuncio_id
        WHERE p.id = ? AND p.stato = 'aperta'
    ]], { idProposta })
    if not p then return rispondi(false, 'Proposta non trovata.') end
    if p.venditore ~= g.citizenid then return rispondi(false, 'Non è una proposta sul tuo immobile.') end

    local i = immobile(p.immobile_id)

    if not accetta then
        MySQL.update('UPDATE imm_proposte SET stato = ? WHERE id = ?', { 'rifiutata', p.id })
        AUREA.Denaro.AggiungiOffline(p.compratore, 'banca', p.caparra, 'restituzione caparra')
        TriggerEvent('aurea:telefono:messaggioSistema', p.compratore, 'Agenzia',
            ('Proposta su %s rifiutata. Caparra restituita.'):format(i.nome))
        return rispondi(true, 'Proposta rifiutata. La caparra torna al proponente.')
    end

    -- Affare concluso: da qui la provvigione è dovuta da entrambi
    local provvigione = IMM.ProvvigioneSu(p.offerta)

    MySQL.update.await('UPDATE imm_proposte SET stato = ? WHERE id = ?', { 'accettata', p.id })
    MySQL.update.await('UPDATE imm_annunci SET stato = ? WHERE id = ?', { 'concluso', p.annuncio })
    MySQL.update.await('UPDATE imm_proposte SET stato = ? WHERE annuncio_id = ? AND stato = ?',
        { 'decaduta', p.annuncio, 'aperta' })

    -- Le caparre delle proposte decadute tornano indietro
    for _, altra in ipairs(MySQL.query.await(
        'SELECT compratore, caparra FROM imm_proposte WHERE annuncio_id = ? AND stato = ?',
        { p.annuncio, 'decaduta' }) or {}) do
        AUREA.Denaro.AggiungiOffline(altra.compratore, 'banca', altra.caparra, 'restituzione caparra')
    end

    -- Provvigione: la paga chi vende e chi compra, art. 1755 c.c.
    local incassata = 0
    if g:Sottrai('banca', provvigione, 'provvigione di mediazione') then incassata = incassata + provvigione end
    local compratore = AUREA.GetPlayerByCitizenId(p.compratore)
    if compratore and compratore:Sottrai('banca', provvigione, 'provvigione di mediazione') then
        incassata = incassata + provvigione
    else
        exports.ita_fisco:IscriviTributo(p.compratore, 'sanzione', 'provvigione di mediazione', provvigione, 3)
    end

    if incassata > 0 then
        pcall(function()
            exports.aurea_azienda:VersaInCassa(IMM.Lavoro, incassata, ('mediazione %s'):format(i.nome))
        end)
        TriggerEvent('aurea:fisco:incasso', 'iva_servizi',
            math.floor(incassata * IMM.Provvigione.iva / (1 + IMM.Provvigione.iva)), g.citizenid)
    end

    MySQL.insert('INSERT INTO imm_affari (immobile_id, venditore, compratore, prezzo, provvigione) VALUES (?, ?, ?, ?, ?)',
        { p.immobile_id, g.citizenid, p.compratore, p.offerta, incassata })

    TriggerEvent('aurea:telefono:messaggioSistema', p.compratore, 'Agenzia',
        ('Proposta ACCETTATA su %s a %s. Andate dal notaio: la caparra si scala dal prezzo.')
            :format(i.nome, U.Euro(p.offerta)))

    if compratore then
        TriggerClientEvent('aurea:ui:notifica', compratore.source, {
            tipo = 'successo', icona = '🏠', durata = 22000,
            titolo = 'Proposta accettata',
            testo = ('%s è tua a %s, appena rogate.\nProvvigione versata: %s.')
                :format(i.nome, U.Euro(p.offerta), U.Euro(provvigione)),
        })
    end

    exports.aurea_ui:NotificaLavoro(IMM.Lavoro, {
        tipo = 'successo', icona = '💼', durata = 14000,
        titolo = 'Affare concluso',
        testo = ('%s a %s. In cassa %s di provvigioni.'):format(i.nome, U.Euro(p.offerta), U.Euro(incassata)),
    }, false)

    AUREA.Log('economia', 'info', g,
        ('ha accettato una proposta di %s su %s'):format(U.Euro(p.offerta), i.nome))

    rispondi(true, ('Affare concluso a %s. Provvigione %s a testa. Adesso serve il rogito.')
        :format(U.Euro(p.offerta), U.Euro(provvigione)))
end)

-- ---------------------------------------------------------------------------
--  Stima
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('imm:stima', function(src, rispondi, idImmobile)
    local g = AUREA.GetPlayer(src)
    if not agente(g, 'stima') then return rispondi(nil) end

    local i = immobile(tonumber(idImmobile))
    if not i then return rispondi(nil) end

    local mercato = valoreDiMercato(i.tipo)

    -- Il palazzo conta. Un appartamento identico in un condominio tenuto
    -- bene vale di più, e in uno con la facciata che cade vale di meno:
    -- ita_condominio tiene il numero, qui si applica alla stima.
    --
    -- Chiamata protetta: un immobile che non sta in nessun condominio, o
    -- un server senza ita_condominio, valgono quello che valgono.
    local decoro, moltiplicatore, nomeCondominio
    local okC, d, m, n = pcall(function()
        return exports.ita_condominio:DecoroDi(i.id)
    end)
    if okC and d then decoro, moltiplicatore, nomeCondominio = d, m, n end

    if mercato and moltiplicatore then mercato = mercato * moltiplicatore end

    rispondi({
        nome = i.nome, tipo = i.tipo, listino = i.prezzo,
        mercato = mercato and math.floor(mercato) or nil,
        rendita = i.rendita_catastale,
        decoro = decoro,
        condominio = nomeCondominio,
        scartoDecoro = moltiplicatore and math.floor((moltiplicatore - 1) * 100) or nil,
    })
end)

-- ---------------------------------------------------------------------------
--  Scadenze
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)

        -- Le proposte scadute restituiscono la caparra
        local scadute = MySQL.query.await(
            'SELECT id, compratore, caparra FROM imm_proposte WHERE stato = ? AND scade_il <= NOW()',
            { 'aperta' }) or {}
        for _, p in ipairs(scadute) do
            MySQL.update('UPDATE imm_proposte SET stato = ? WHERE id = ?', { 'scaduta', p.id })
            AUREA.Denaro.AggiungiOffline(p.compratore, 'banca', p.caparra, 'caparra su proposta scaduta')
            TriggerEvent('aurea:telefono:messaggioSistema', p.compratore, 'Agenzia',
                'Proposta scaduta senza risposta. Caparra restituita.')
        end

        MySQL.update('UPDATE imm_annunci SET stato = ? WHERE stato = ? AND scade_il <= NOW()',
            { 'scaduto', 'aperto' })

        for citizenid, v in pairs(visite) do
            if os.time() >= v.scade then visite[citizenid] = nil end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App del telefono: la vetrina si guarda anche dal divano
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'immobiliare',
    nome = 'Immobili',
    icona = '🏠',
    colore = 'linear-gradient(150deg,#4e8c6a,#2b4f3c)',
    ordine = 138,

    schermata = function()
        local voci = {}
        for _, a in ipairs(vetrina()) do
            voci[#voci + 1] = {
                icona = a.giudizio == 'basso' and '⚠' or '🏠',
                titolo = a.nome,
                sottotitolo = ('%s · %s · %s\n%s'):format(a.tipo, a.indirizzo, a.venditore or '—', a.spiegazione),
                valore = U.Euro(a.prezzo),
                tono = a.giudizio == 'congruo' and 'verde' or (a.giudizio == 'alto' and 'rosso' or 'giallo'),
                inerte = true,
            }
        end
        if #voci == 0 then
            voci[1] = { icona = '🏠', titolo = 'Vetrina vuota',
                        sottotitolo = 'Nessun immobile in vendita fra privati.', inerte = true }
        end
        return { tipo = 'lista', sottotitolo = 'Vetrina dell\'agenzia', voci = voci }
    end,
})

print('[AUREA] agenzia immobiliare: vetrina e proposte attive')
