--[[
    AUREA · S.I.A.E. (server)

    Il borderò si riempie da solo. Ogni volta che aurea_musica dice che
    qualcuno ha acceso uno stereo, qui si guarda se quel punto è dentro
    un locale e se quel locale ha un permesso valido. Se non ce l'ha, la
    riga resta lì marcata abusiva.

    Nessuno se ne accorge subito — ed è giusto così. Se ne accorge
    l'ispettore che passa dopo, e trova tutto scritto.
]]

local U = AUREA.Util
local raffreddamenti = {}   -- [idLocale] = timestamp

local function mandatario(g, permesso)
    return g and g.lavoro.nome == SIAE.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'permessi_musica')
end

local function inSede(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - SIAE.Sede.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Il permesso valido su un locale
-- ---------------------------------------------------------------------------
local function permessoValido(idLocale, tipoRichiesto)
    local righe = MySQL.query.await([[
        SELECT id, tipo, richiedente, scadenza FROM siae_permessi
        WHERE locale = ? AND revocato = 0 AND scadenza > NOW()
    ]], { idLocale }) or {}

    local livelloRichiesto = SIAE.Gerarchia[tipoRichiesto] or 1
    for _, p in ipairs(righe) do
        if (SIAE.Gerarchia[p.tipo] or 0) >= livelloRichiesto then return p end
    end
    return nil
end

--- Lo chiede ita_discoteca prima di aprire una serata: senza il
--- trattenimento danzante non si balla.
exports('PermessoValido', function(idLocale, tipo)
    local p = permessoValido(idLocale, tipo or 'musica_ambiente')
    return p ~= nil, p and p.tipo or nil
end)

-- ---------------------------------------------------------------------------
--  Il borderò: si riempie da solo
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:siae:esecuzione', function(citizenid, coord, brano, tipoSorgente)
    if type(coord) ~= 'table' then return end

    local locale = SIAE.LocaleIn(vector3(coord.x + 0.0, coord.y + 0.0, coord.z + 0.0))
    if not locale then return end     -- fuori da un locale non è pubblica esecuzione

    -- L'autoradio di passaggio non è una pubblica esecuzione: è una
    -- macchina che passa. Solo quello che sta e suona conta.
    if tipoSorgente == 'autoradio' then return end

    local p = permessoValido(locale.id, 'musica_ambiente')

    MySQL.insert.await([[
        INSERT INTO siae_bordero (permesso_id, locale, brano, esecutore, abusiva)
        VALUES (?, ?, ?, ?, ?)
    ]], { p and p.id or nil, locale.id, tostring(brano):sub(1, 160), citizenid, p and 0 or 1 })

    if not p then
        AUREA.Log('economia', 'info', nil,
            ('esecuzione senza permesso in %s'):format(locale.nome))
    end
end)

--- Le serate di ita_discoteca finiscono anche loro sul borderò: lì la
--- musica è il motivo per cui la gente paga l'ingresso.
AddEventHandler('aurea:siae:serata', function(idLocale, citizenid, nomeSerata)
    local esiste = false
    for _, l in ipairs(SIAE.Locali) do if l.id == idLocale then esiste = true break end end
    if not esiste then return end

    local p = permessoValido(idLocale, 'trattenimento_danzante')
    MySQL.insert.await([[
        INSERT INTO siae_bordero (permesso_id, locale, brano, esecutore, abusiva)
        VALUES (?, ?, ?, ?, ?)
    ]], { p and p.id or nil, idLocale,
          ('Serata danzante — %s'):format(tostring(nomeSerata):sub(1, 120)),
          citizenid, p and 0 or 1 })
end)

-- ---------------------------------------------------------------------------
--  Chiedere un permesso
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('siae:locali', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for _, l in ipairs(SIAE.Locali) do
        local attivi = MySQL.query.await([[
            SELECT tipo, TIMESTAMPDIFF(MINUTE, NOW(), scadenza) AS minuti
            FROM siae_permessi
            WHERE locale = ? AND revocato = 0 AND scadenza > NOW()
        ]], { l.id }) or {}

        local abusive = MySQL.scalar.await([[
            SELECT COUNT(*) FROM siae_bordero
            WHERE locale = ? AND abusiva = 1
              AND TIMESTAMPDIFF(MINUTE, quando, NOW()) <= ?
        ]], { l.id, SIAE.Ispezione.minutiRetroattivi }) or 0

        out[#out + 1] = {
            id = l.id, nome = l.nome, permessi = attivi, abusive = abusive,
        }
    end
    rispondi(out)
end)

AUREA.Callback.Registra('siae:chiedi', function(src, rispondi, idLocale, tipoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inSede(src) then return rispondi(false, 'Il permesso si chiede in sede.') end

    local tipo = SIAE.GetPermesso(tipoId)
    if not tipo then return rispondi(false, 'Tipo di permesso non valido.') end

    local locale
    for _, l in ipairs(SIAE.Locali) do if l.id == idLocale then locale = l break end end
    if not locale then return rispondi(false, 'Locale non censito.') end

    if permessoValido(locale.id, tipo.id) then
        return rispondi(false, 'Su questo locale c\'è già un permesso che copre quel tipo di esecuzione.')
    end

    if not g:SottraiOvunque(tipo.costo, ('diritti d\'autore — %s'):format(tipo.nome)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(tipo.costo)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(SIAE.Lavoro, tipo.costo, 'diritti d\'autore')
    end)

    MySQL.insert.await([[
        INSERT INTO siae_permessi (locale, tipo, richiedente, scadenza, importo)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE), ?)
    ]], { locale.id, tipo.id, g.citizenid, tipo.minutiValidita, tipo.costo })

    -- Le esecuzioni già registrate come abusive restano abusive: il
    -- permesso non sana il passato, e questo è esattamente il punto.
    AUREA.Log('economia', 'info', g, ('permesso SIAE %s per %s'):format(tipo.id, locale.nome))

    rispondi(true, ('%s per %s: rilasciato, vale %d minuti.\nQuello che hai già suonato senza permesso resta agli atti.')
        :format(tipo.nome, locale.nome, tipo.minutiValidita))
end)

-- ---------------------------------------------------------------------------
--  L'ispezione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('siae:ispeziona', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not mandatario(g, 'ispezione') then
        return rispondi(false, 'Serve essere ispettore SIAE in servizio.')
    end

    local locale = SIAE.LocaleIn(GetEntityCoords(GetPlayerPed(src)))
    if not locale then return rispondi(false, 'Qui non c\'è nessun locale censito.') end

    if (raffreddamenti[locale.id] or 0) > os.time() then
        return rispondi(false, ('Su %s c\'è già stato un controllo di recente.'):format(locale.nome))
    end
    raffreddamenti[locale.id] = os.time() + SIAE.Ispezione.minutiRaffreddamento * 60

    local abusive = MySQL.query.await([[
        SELECT id, brano, esecutore FROM siae_bordero
        WHERE locale = ? AND abusiva = 1
          AND TIMESTAMPDIFF(MINUTE, quando, NOW()) <= ?
    ]], { locale.id, SIAE.Ispezione.minutiRetroattivi }) or {}

    if #abusive == 0 then
        local p = permessoValido(locale.id, 'musica_ambiente')
        return rispondi(true, {
            locale = locale.nome, brani = 0, sanzione = 0,
            permesso = p and (SIAE.GetPermesso(p.tipo) or {}).nome or nil,
        })
    end

    -- Chi paga: il gestore del locale, se ce n'è uno registrato;
    -- altrimenti chi ha materialmente suonato di più.
    local gestore = MySQL.scalar.await('SELECT gestore FROM locali_notturni WHERE codice = ?',
        { locale.id })
    if not gestore then
        local conteggio = {}
        for _, b in ipairs(abusive) do
            conteggio[b.esecutore] = (conteggio[b.esecutore] or 0) + 1
        end
        local quanti = 0
        for cid, n in pairs(conteggio) do
            if n > quanti then gestore, quanti = cid, n end
        end
    end

    local sanzione = SIAE.Sanzione(#abusive)

    MySQL.insert.await([[
        INSERT INTO siae_verbali (locale, intestatario, ispettore, motivo, importo)
        VALUES (?, ?, ?, ?, ?)
    ]], { locale.id, gestore, g.citizenid,
          ('Pubblica esecuzione senza permesso: %d esecuzioni accertate'):format(#abusive),
          sanzione })

    -- Le righe contestate non si contestano due volte
    for _, b in ipairs(abusive) do
        MySQL.update.await('UPDATE siae_bordero SET abusiva = 2 WHERE id = ?', { b.id })
    end

    if gestore then
        TriggerEvent('aurea:telefono:messaggioSistema', gestore, 'SIAE',
            ('Verbale per pubblica esecuzione senza permesso in %s: %d esecuzioni, %s. Si paga in sede.')
                :format(locale.nome, #abusive, U.Euro(sanzione)))
    end

    AUREA.Log('economia', 'avviso', g, ('verbale SIAE su %s: %d esecuzioni abusive, %s')
        :format(locale.nome, #abusive, U.Euro(sanzione)))

    rispondi(true, {
        locale = locale.nome, brani = #abusive, sanzione = sanzione,
        intestatario = gestore ~= nil,
    })
end)

-- ---------------------------------------------------------------------------
--  Pagare il verbale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('siae:mieiVerbali', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, locale, motivo, importo, quando FROM siae_verbali
        WHERE intestatario = ? AND pagato = 0 ORDER BY quando ASC
    ]], { g.citizenid }) or {}

    for _, v in ipairs(righe) do
        for _, l in ipairs(SIAE.Locali) do
            if l.id == v.locale then v.nomeLocale = l.nome break end
        end
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('siae:paga', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local v = MySQL.single.await(
        'SELECT id, importo, locale FROM siae_verbali WHERE id = ? AND intestatario = ? AND pagato = 0',
        { tonumber(id), g.citizenid })
    if not v then return rispondi(false, 'Verbale non trovato.') end

    if not g:SottraiOvunque(v.importo, 'verbale SIAE') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(v.importo)))
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(SIAE.Lavoro,
            math.floor(v.importo * SIAE.Ispezione.quotaIstituto), 'sanzioni')
    end)
    TriggerEvent('aurea:fisco:incasso', 'diritti_autore',
        v.importo - math.floor(v.importo * SIAE.Ispezione.quotaIstituto), g.citizenid)

    MySQL.update.await('UPDATE siae_verbali SET pagato = 1 WHERE id = ?', { v.id })
    rispondi(true, ('Verbale pagato: %s.'):format(U.Euro(v.importo)))
end)
