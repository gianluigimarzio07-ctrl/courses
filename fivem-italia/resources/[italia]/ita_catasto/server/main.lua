--[[
    AUREA · Catasto (server)

    Due pratiche e una consultazione. La parte che conta è che la scheda
    catastale è una cosa DIVERSA dalla proprietà: `immobili.proprietario`
    dice chi possiede, `catasto_schede.intestato_a` dice chi risulta. Fra
    i due c'è la voltura, e finché non la presenti l'imposta la paga chi
    ha venduto.

    È l'unico posto del server in cui essere in ritardo con un modulo non
    è un fastidio: è una bolletta che arriva a qualcun altro.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Chi sta allo sportello
-- ---------------------------------------------------------------------------
local function impiegato(g)
    return g and g.lavoro.nome == CAT.Lavoro and g:HaPermessoLavoro(CAT.Permesso)
end

local function alloSportello(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - CAT.Sportello.coord) <= 6.0
end

-- ---------------------------------------------------------------------------
--  Accatastamento: l'opera consegnata diventa un immobile
--
--  ita_edilizia ci manda l'evento alla consegna. Da qui in poi il
--  fabbricato esiste come pratica in attesa, non ancora come immobile.
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:edilizia:consegnato', function(lotto, nome, destinazione, volumetria, direttore, impresa)
    if type(lotto) ~= 'string' then return end

    local categoria = CAT.CategoriaPer(destinazione, volumetria)
    MySQL.insert.await([[
        INSERT INTO catasto_pratiche
            (tipo, lotto, denominazione, categoria, volumetria, richiedente, impresa, scade_il)
        VALUES ('accatastamento', ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { lotto, nome, categoria, volumetria, direttore, impresa, CAT.Docfa.minutiPerPresentare })

    TriggerEvent('aurea:telefono:messaggioSistema', direttore, 'Catasto',
        ('%s è ultimato ma non accatastato. Presenta il DOCFA entro %d minuti, altrimenti è sanzione.')
            :format(nome, CAT.Docfa.minutiPerPresentare))

    AUREA.Log('economia', 'info', nil, ('Fabbricato %s in attesa di accatastamento'):format(lotto))
end)

AUREA.Callback.Registra('cat:pratiche', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    -- Le proprie pratiche; l'impiegato le vede tutte
    local righe
    if impiegato(g) then
        righe = MySQL.query.await([[
            SELECT p.*, CONCAT(x.nome, ' ', x.cognome) AS nome_richiedente
            FROM catasto_pratiche p
            LEFT JOIN personaggi x ON x.citizenid = p.richiedente
            WHERE p.stato = 'da_presentare' ORDER BY p.id ASC LIMIT 25
        ]]) or {}
    else
        righe = MySQL.query.await([[
            SELECT * FROM catasto_pratiche
            WHERE richiedente = ? AND stato = 'da_presentare' ORDER BY id ASC
        ]], { g.citizenid }) or {}
    end

    for _, r in ipairs(righe) do
        r.categoriaNome = CAT.Categorie[r.categoria] and CAT.Categorie[r.categoria].nome or r.categoria
        r.rendita = CAT.Rendita(r.categoria, r.volumetria or 0)
        r.tributi = r.tipo == 'accatastamento' and CAT.Docfa.tributi or CAT.Voltura.tributi
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('cat:presenta', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alloSportello(src) then return rispondi(false, 'La pratica si presenta allo sportello.') end

    local p = MySQL.single.await(
        'SELECT * FROM catasto_pratiche WHERE id = ? AND stato = ?', { id, 'da_presentare' })
    if not p then return rispondi(false, 'Pratica non trovata.') end
    if p.richiedente ~= g.citizenid then return rispondi(false, 'Non è una tua pratica.') end

    local tributi = p.tipo == 'accatastamento' and CAT.Docfa.tributi or CAT.Voltura.tributi
    if not g:Sottrai('banca', tributi, 'tributi speciali catastali') then
        return rispondi(false, ('Servono %s di tributi.'):format(U.Euro(tributi)))
    end
    TriggerEvent('aurea:fisco:incasso', 'tributi_catastali', tributi, g.citizenid)

    if p.tipo == 'voltura' then
        MySQL.update.await('UPDATE catasto_schede SET intestato_a = ?, aggiornata_il = NOW() WHERE immobile_id = ?',
            { p.richiedente, p.immobile_id })
        MySQL.update.await('UPDATE catasto_pratiche SET stato = ?, evasa_il = NOW() WHERE id = ?',
            { 'evasa', p.id })

        AUREA.Log('economia', 'info', g, ('ha volturato l\'immobile %d'):format(p.immobile_id or 0))
        return rispondi(true, 'Voltura registrata. Da adesso l\'immobile risulta intestato a te, imposte comprese.')
    end

    -- Accatastamento: nasce l'immobile
    local rendita = CAT.Rendita(p.categoria, p.volumetria or 0)
    local prezzo = rendita * CAT.Docfa.coefficienteMercato
    local tipo = CAT.TipoImmobile[p.categoria] or 'appartamento'

    local codice = ('%s-%s'):format(tostring(p.lotto):upper():sub(1, 4), U.Random(4))
    local immobileId = MySQL.insert.await([[
        INSERT INTO immobili
            (codice, nome, tipo, indirizzo, prezzo, rendita_catastale, proprietario,
             ingresso, interno, in_vendita, chiavi)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], { codice, p.denominazione, tipo, p.denominazione, prezzo, rendita, g.citizenid,
          json.encode({ x = 0.0, y = 0.0, z = 0.0 }), 'shell_medio', json.encode({ g.citizenid }) })

    MySQL.insert.await([[
        INSERT INTO catasto_schede (immobile_id, categoria, rendita, intestato_a, lotto)
        VALUES (?, ?, ?, ?, ?)
    ]], { immobileId, p.categoria, rendita, g.citizenid, p.lotto })

    MySQL.update.await('UPDATE catasto_pratiche SET stato = ?, immobile_id = ?, evasa_il = NOW() WHERE id = ?',
        { 'evasa', immobileId, p.id })

    exports.aurea_inventory:Aggiungi(g.citizenid, 'chiavi_casa', 1,
        { immobile = immobileId, nome = p.denominazione })

    AUREA.Log('economia', 'info', g,
        ('ha accatastato %s (%s, rendita %s)'):format(p.denominazione, p.categoria, U.Euro(rendita)))

    rispondi(true, ('%s accatastato in categoria %s.\nRendita %s · valore di listino %s.\nLe chiavi sono tue: adesso si può vendere.')
        :format(p.denominazione, p.categoria, U.Euro(rendita), U.Euro(prezzo)))
end)

-- ---------------------------------------------------------------------------
--  La voltura nasce dal rogito
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:notaio:trasferito', function(immobileId, nome, venditore, compratore)
    if not immobileId then return end

    MySQL.query.await([[
        INSERT IGNORE INTO catasto_schede (immobile_id, categoria, rendita, intestato_a)
        SELECT id, 'A2', rendita_catastale, ? FROM immobili WHERE id = ?
    ]], { venditore, immobileId })

    MySQL.insert.await([[
        INSERT INTO catasto_pratiche (tipo, immobile_id, denominazione, richiedente, scade_il)
        VALUES ('voltura', ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { immobileId, nome, compratore, CAT.Voltura.minutiPerPresentare })

    TriggerEvent('aurea:telefono:messaggioSistema', compratore, 'Catasto',
        ('%s risulta ancora intestato a chi te l\'ha venduto. Presenta la voltura entro %d minuti: finché non lo fai, l\'IMU la paga lui e la sanzione poi la paghi tu.')
            :format(nome, CAT.Voltura.minutiPerPresentare))
end)

-- ---------------------------------------------------------------------------
--  Visura
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cat:visura', function(src, rispondi, chiave)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if not alloSportello(src) then return rispondi(nil, 'La visura si chiede allo sportello.') end

    if not impiegato(g) and not g:Sottrai('banca', CAT.Visura.costo, 'visura catastale') then
        return rispondi(nil, ('La visura costa %s.'):format(U.Euro(CAT.Visura.costo)))
    end
    if not impiegato(g) then
        TriggerEvent('aurea:fisco:incasso', 'tributi_catastali', CAT.Visura.costo, g.citizenid)
    end

    local righe = MySQL.query.await([[
        SELECT i.id, i.nome, i.tipo, i.indirizzo, i.rendita_catastale, i.proprietario,
               s.categoria, s.intestato_a,
               CONCAT(pp.nome, ' ', pp.cognome) AS nome_proprietario,
               CONCAT(pi.nome, ' ', pi.cognome) AS nome_intestatario
        FROM immobili i
        LEFT JOIN catasto_schede s ON s.immobile_id = i.id
        LEFT JOIN personaggi pp ON pp.citizenid = i.proprietario
        LEFT JOIN personaggi pi ON pi.citizenid = s.intestato_a
        WHERE i.nome LIKE ? OR i.indirizzo LIKE ? OR i.codice = ?
        ORDER BY i.id LIMIT 12
    ]], { '%' .. tostring(chiave or '') .. '%', '%' .. tostring(chiave or '') .. '%', tostring(chiave or '') }) or {}

    for _, r in ipairs(righe) do
        r.categoriaNome = CAT.Categorie[r.categoria] and CAT.Categorie[r.categoria].nome or (r.categoria or 'non accatastato')
        -- Il disallineamento è la cosa interessante: chi possiede non è
        -- sempre chi risulta, e la differenza si legge qui.
        r.disallineata = r.intestato_a ~= nil and r.intestato_a ~= r.proprietario
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Chi risulta intestatario: lo chiede il fisco per l'IMU
-- ---------------------------------------------------------------------------
exports('IntestatarioDi', function(immobileId)
    local s = MySQL.scalar.await('SELECT intestato_a FROM catasto_schede WHERE immobile_id = ?', { immobileId })
    return s
end)

exports('SchedaDi', function(immobileId)
    return MySQL.single.await('SELECT * FROM catasto_schede WHERE immobile_id = ?', { immobileId })
end)

-- ---------------------------------------------------------------------------
--  Le pratiche scadute
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(90000)
    while true do
        Wait(120000)

        -- Il termine scade una volta sola: la sanzione arriva, e poi la
        -- pratica resta lì finché non la presenti. `sanzionata` è quello
        -- che impedisce a questo ciclo di multare la stessa persona
        -- ogni due minuti per sempre.
        local scadute = MySQL.query.await([[
            SELECT * FROM catasto_pratiche
            WHERE stato = 'da_presentare' AND sanzionata = 0 AND scade_il <= NOW()
        ]]) or {}

        for _, p in ipairs(scadute) do
            MySQL.update.await('UPDATE catasto_pratiche SET sanzionata = 1 WHERE id = ?', { p.id })

            local sanzione = p.tipo == 'accatastamento' and CAT.Docfa.sanzioneTardiva or CAT.Voltura.sanzioneTardiva
            exports.ita_fisco:IscriviTributo(p.richiedente, 'sanzione',
                ('%s tardivo — %s'):format(p.tipo, p.denominazione or ''), sanzione, 7)

            TriggerEvent('aurea:telefono:messaggioSistema', p.richiedente, 'Catasto',
                ('Termine scaduto per %s: sanzione %s. La pratica resta valida, presentala quando vuoi.')
                    :format(p.tipo, U.Euro(sanzione)))
        end
    end
end)

print('[AUREA] catasto: accatastamenti e volture attivi')
