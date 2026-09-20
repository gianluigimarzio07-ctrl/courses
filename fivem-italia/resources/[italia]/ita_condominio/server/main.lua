--[[
    AUREA · Condominio (server)

    La cosa da guardare è come si calcolano i millesimi: non li assegna
    nessuno, escono dalla rendita catastale che ita_catasto già tiene. La
    somma fa mille e si ricalcola ogni volta che una unità entra o esce
    dal condominio.

    Questo ha una conseguenza che mi piace: chi accatasta il proprio
    appartamento con una rendita alta paga più IMU e ha più peso in
    assemblea. Sono la stessa cosa vista da due lati, e nel server sono
    davvero lo stesso numero.
]]

local U = AUREA.Util

local function inCondominio(src, c)
    return #(GetEntityCoords(GetPlayerPed(src)) - c.coord) <= c.raggio
end

-- ---------------------------------------------------------------------------
--  Semina
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    for _, c in ipairs(CON.Condomini) do
        MySQL.query.await([[
            INSERT IGNORE INTO condomini (codice, nome, indirizzo, compenso)
            VALUES (?, ?, ?, ?)
        ]], { c.codice, c.nome, c.indirizzo, c.compensoAnnuo })
    end
end)

-- ---------------------------------------------------------------------------
--  Millesimi
-- ---------------------------------------------------------------------------
local function ricalcolaMillesimi(condominioId)
    local unita = MySQL.query.await([[
        SELECT u.id, u.immobile_id, COALESCE(i.rendita_catastale, 0) AS rendita
        FROM condominio_unita u
        JOIN immobili i ON i.id = u.immobile_id
        WHERE u.condominio_id = ?
    ]], { condominioId }) or {}
    if #unita == 0 then return end

    local totaleRendita = 0
    for _, u in ipairs(unita) do totaleRendita = totaleRendita + math.max(1, u.rendita) end

    local assegnati = 0
    for i, u in ipairs(unita) do
        local m
        if i == #unita then
            -- All'ultima va il resto: la somma deve fare esattamente mille
            m = CON.Millesimi.totale - assegnati
        else
            m = math.max(CON.Millesimi.minimo,
                math.floor((math.max(1, u.rendita) / totaleRendita) * CON.Millesimi.totale))
            assegnati = assegnati + m
        end
        MySQL.update.await('UPDATE condominio_unita SET millesimi = ? WHERE id = ?',
            { math.max(0, m), u.id })
    end
end

--- Il decoro del condominio a cui appartiene un immobile, se ce n'è uno.
--- Lo chiede ita_immobiliare quando stima un appartamento.
exports('DecoroDi', function(immobileId)
    local r = MySQL.single.await([[
        SELECT c.decoro, c.nome FROM condominio_unita u
        JOIN condomini c ON c.id = u.condominio_id
        WHERE u.immobile_id = ?
    ]], { tonumber(immobileId) })
    if not r then return nil end
    return r.decoro, CON.Moltiplicatore(r.decoro), r.nome
end)

exports('MillesimiDi', function(citizenid, codice)
    return MySQL.scalar.await([[
        SELECT COALESCE(SUM(u.millesimi), 0)
        FROM condominio_unita u
        JOIN condomini c ON c.id = u.condominio_id
        JOIN immobili i ON i.id = u.immobile_id
        WHERE i.proprietario = ? AND c.codice = ?
    ]], { citizenid, codice }) or 0
end)

-- ---------------------------------------------------------------------------
--  Lo stato del condominio
-- ---------------------------------------------------------------------------
local function millesimiDi(condominioId, citizenid)
    return MySQL.scalar.await([[
        SELECT COALESCE(SUM(u.millesimi), 0) FROM condominio_unita u
        JOIN immobili i ON i.id = u.immobile_id
        WHERE u.condominio_id = ? AND i.proprietario = ?
    ]], { condominioId, citizenid }) or 0
end

AUREA.Callback.Registra('con:stato', function(src, rispondi, codice)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local c = CON.GetCondominio(codice)
    if not c then return rispondi(nil) end

    local riga = MySQL.single.await(
        'SELECT id, nome, amministratore, fondo, decoro, compenso FROM condomini WHERE codice = ?',
        { codice })
    if not riga then return rispondi(nil) end

    local unita = MySQL.query.await([[
        SELECT u.millesimi, i.nome AS immobile, i.codice,
               CONCAT(p.nome, ' ', p.cognome) AS proprietario, i.proprietario AS cid
        FROM condominio_unita u
        JOIN immobili i ON i.id = u.immobile_id
        LEFT JOIN personaggi p ON p.citizenid = i.proprietario
        WHERE u.condominio_id = ? ORDER BY u.millesimi DESC
    ]], { riga.id }) or {}

    -- Gli immobili del giocatore che stanno qui intorno e non sono ancora
    -- censiti nel condominio
    local iscrivibili = MySQL.query.await([[
        SELECT i.id, i.codice, i.nome, i.rendita_catastale, i.ingresso
        FROM immobili i
        WHERE i.proprietario = ?
          AND i.id NOT IN (SELECT immobile_id FROM condominio_unita)
    ]], { g.citizenid }) or {}

    local candidati = {}
    for _, i in ipairs(iscrivibili) do
        local ok, pos = pcall(json.decode, i.ingresso or '{}')
        if ok and pos and pos.x then
            if #(vector3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0) - c.coord) <= c.raggio then
                candidati[#candidati + 1] = i
            end
        end
    end

    local spese = MySQL.query.await([[
        SELECT s.id, s.descrizione, s.importo, s.tipo, s.stato,
               s.millesimi_favorevoli, s.millesimi_contrari,
               TIMESTAMPDIFF(MINUTE, s.proposta_il, NOW()) AS minuti,
               (SELECT COUNT(*) FROM condominio_voti v WHERE v.spesa_id = s.id AND v.citizenid = ?) AS votata
        FROM condominio_spese s
        WHERE s.condominio_id = ? AND s.stato IN ('proposta','deliberata')
        ORDER BY s.proposta_il DESC LIMIT 12
    ]], { g.citizenid, riga.id }) or {}

    local quote = MySQL.query.await([[
        SELECT q.id, q.importo, q.pagata, q.ingiunta, s.descrizione,
               TIMESTAMPDIFF(MINUTE, NOW(), q.scadenza) AS minutiResidui
        FROM condominio_quote q
        JOIN condominio_spese s ON s.id = q.spesa_id
        WHERE q.citizenid = ? AND s.condominio_id = ? AND q.pagata = 0
    ]], { g.citizenid, riga.id }) or {}

    local morosi = {}
    if riga.amministratore == g.citizenid then
        morosi = MySQL.query.await([[
            SELECT q.id, q.importo, q.citizenid, q.ingiunta, s.descrizione,
                   CONCAT(p.nome, ' ', p.cognome) AS nominativo,
                   TIMESTAMPDIFF(MINUTE, q.scadenza, NOW()) AS ritardo
            FROM condominio_quote q
            JOIN condominio_spese s ON s.id = q.spesa_id
            LEFT JOIN personaggi p ON p.citizenid = q.citizenid
            WHERE s.condominio_id = ? AND q.pagata = 0 AND q.scadenza < NOW()
        ]], { riga.id }) or {}
    end

    rispondi({
        id = riga.id, codice = codice, nome = riga.nome,
        fondo = riga.fondo, decoro = riga.decoro, compenso = riga.compenso,
        amministratore = riga.amministratore,
        sonoAmministratore = riga.amministratore == g.citizenid,
        mieiMillesimi = millesimiDi(riga.id, g.citizenid),
        unita = unita, candidati = candidati,
        spese = spese, quote = quote, morosi = morosi,
        moltiplicatore = CON.Moltiplicatore(riga.decoro),
    })
end)

-- ---------------------------------------------------------------------------
--  Iscrivere la propria unità
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:iscrivi', function(src, rispondi, codice, immobileId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local c = CON.GetCondominio(codice)
    if not c then return rispondi(false, 'Condominio inesistente.') end
    if not inCondominio(src, c) then return rispondi(false, 'L\'unità si censisce sul posto.') end

    local riga = MySQL.single.await('SELECT id FROM condomini WHERE codice = ?', { codice })
    if not riga then return rispondi(false, 'Condominio non registrato.') end

    local i = MySQL.single.await(
        'SELECT id, nome, proprietario, rendita_catastale FROM immobili WHERE id = ?',
        { tonumber(immobileId) })
    if not i then return rispondi(false, 'Immobile non trovato.') end
    if i.proprietario ~= g.citizenid then return rispondi(false, 'Non è tuo.') end

    local gia = MySQL.scalar.await('SELECT id FROM condominio_unita WHERE immobile_id = ?', { i.id })
    if gia then return rispondi(false, 'L\'unità è già censita in un condominio.') end

    MySQL.insert.await(
        'INSERT INTO condominio_unita (condominio_id, immobile_id, millesimi) VALUES (?, ?, 0)',
        { riga.id, i.id })
    ricalcolaMillesimi(riga.id)

    local miei = millesimiDi(riga.id, g.citizenid)

    AUREA.Log('economia', 'info', g, ('censita l\'unità %s in %s'):format(i.nome, c.nome))
    rispondi(true, ('%s censita in %s.\nTi spettano %d millesimi: sono calcolati sulla rendita catastale, non li decide nessuno.')
        :format(i.nome, c.nome, miei))
end)

-- ---------------------------------------------------------------------------
--  L'amministratore
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:nomina', function(src, rispondi, codice)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local riga = MySQL.single.await(
        'SELECT id, nome, amministratore FROM condomini WHERE codice = ?', { codice })
    if not riga then return rispondi(false, 'Condominio inesistente.') end

    local miei = millesimiDi(riga.id, g.citizenid)
    if miei <= 0 then return rispondi(false, 'Non hai unità in questo condominio.') end

    if riga.amministratore and riga.amministratore ~= g.citizenid then
        -- Per sostituire chi c'è servono cinquecento millesimi
        if miei < CON.Maggioranze.straordinaria.millesimiMinimi then
            return rispondi(false, ('Per revocare l\'amministratore in carica servono %d millesimi, ne hai %d.')
                :format(CON.Maggioranze.straordinaria.millesimiMinimi, miei))
        end
    elseif riga.amministratore == g.citizenid then
        return rispondi(false, 'Lo sei già.')
    end

    MySQL.update.await('UPDATE condomini SET amministratore = ?, nominato_il = NOW() WHERE id = ?',
        { g.citizenid, riga.id })

    AUREA.Log('economia', 'info', g, ('nominato amministratore di %s'):format(riga.nome))
    rispondi(true, ('Sei l\'amministratore di %s.\nDa adesso le spese le proponi tu, e i morosi sono un tuo problema.')
        :format(riga.nome))
end)

-- ---------------------------------------------------------------------------
--  Proporre una spesa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:proponi', function(src, rispondi, codice, voceId, importo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local riga = MySQL.single.await(
        'SELECT id, nome, amministratore FROM condomini WHERE codice = ?', { codice })
    if not riga then return rispondi(false, 'Condominio inesistente.') end
    if riga.amministratore ~= g.citizenid then
        return rispondi(false, 'Le spese le propone l\'amministratore.')
    end

    local voce = CON.GetVoce(voceId)
    if not voce then return rispondi(false, 'Voce di spesa non prevista.') end

    importo = math.floor(tonumber(importo) or 0)
    if importo < CON.Spese.importoMinimo or importo > CON.Spese.importoMassimo then
        return rispondi(false, ('L\'importo va da %s a %s.')
            :format(U.Euro(CON.Spese.importoMinimo), U.Euro(CON.Spese.importoMassimo)))
    end

    local id = MySQL.insert.await([[
        INSERT INTO condominio_spese (condominio_id, descrizione, importo, tipo)
        VALUES (?, ?, ?, ?)
    ]], { riga.id, voce.nome, importo, voce.tipo })

    -- Tutti i condomini vengono avvisati: è la convocazione
    local proprietari = MySQL.query.await([[
        SELECT DISTINCT i.proprietario FROM condominio_unita u
        JOIN immobili i ON i.id = u.immobile_id
        WHERE u.condominio_id = ? AND i.proprietario IS NOT NULL
    ]], { riga.id }) or {}

    local soglia = CON.Maggioranze[voce.tipo].millesimiMinimi
    for _, p in ipairs(proprietari) do
        TriggerEvent('aurea:telefono:messaggioSistema', p.proprietario, 'Amministratore',
            ('Convocazione: %s — %s, %s. Servono %d millesimi per deliberare. Hai %d minuti per votare.')
                :format(riga.nome, voce.nome, U.Euro(importo), soglia,
                        CON.Maggioranze.minutiVotazione))
    end

    AUREA.Log('economia', 'info', g, ('propone "%s" per %s a %s')
        :format(voce.nome, U.Euro(importo), riga.nome))

    rispondi(true, ('Spesa proposta: %s, %s.\nServono %d millesimi favorevoli. I condomini sono stati convocati.')
        :format(voce.nome, U.Euro(importo), soglia), id)
end)

-- ---------------------------------------------------------------------------
--  Votare
-- ---------------------------------------------------------------------------
local function delibera(spesa, condominio)
    MySQL.update.await([[
        UPDATE condominio_spese SET stato = 'deliberata', deliberata_il = NOW() WHERE id = ?
    ]], { spesa.id })

    -- Le quote: a millesimi, e all'ultimo il resto
    local unita = MySQL.query.await([[
        SELECT u.millesimi, i.proprietario FROM condominio_unita u
        JOIN immobili i ON i.id = u.immobile_id
        WHERE u.condominio_id = ? AND i.proprietario IS NOT NULL
        ORDER BY u.millesimi DESC
    ]], { condominio.id }) or {}

    local somma = {}
    for _, u in ipairs(unita) do
        somma[u.proprietario] = (somma[u.proprietario] or 0) + u.millesimi
    end

    local assegnato, ordinati = 0, {}
    for cid, m in pairs(somma) do ordinati[#ordinati + 1] = { cid = cid, m = m } end
    table.sort(ordinati, function(a, b) return a.m > b.m end)

    for i, o in ipairs(ordinati) do
        local quota
        if i == #ordinati then
            quota = spesa.importo - assegnato
        else
            quota = math.floor(spesa.importo * (o.m / CON.Millesimi.totale))
            assegnato = assegnato + quota
        end
        if quota > 0 then
            MySQL.query.await([[
                INSERT INTO condominio_quote (spesa_id, citizenid, importo, scadenza)
                VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
                ON DUPLICATE KEY UPDATE importo = VALUES(importo)
            ]], { spesa.id, o.cid, quota, CON.Spese.minutiPerPagare })

            TriggerEvent('aurea:telefono:messaggioSistema', o.cid, 'Amministratore',
                ('Delibera approvata: %s. La tua quota è %s (%d millesimi), da pagare in %d minuti.')
                    :format(spesa.descrizione, U.Euro(quota), o.m, CON.Spese.minutiPerPagare))
        end
    end

    AUREA.Log('economia', 'info', nil, ('delibera su %s: %s per %s')
        :format(condominio.nome, spesa.descrizione, U.Euro(spesa.importo)))
end

AUREA.Callback.Registra('con:vota', function(src, rispondi, spesaId, favorevole)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = MySQL.single.await([[
        SELECT s.*, c.codice, c.nome AS nome_condominio
        FROM condominio_spese s JOIN condomini c ON c.id = s.condominio_id
        WHERE s.id = ? AND s.stato = 'proposta'
    ]], { tonumber(spesaId) })
    if not s then return rispondi(false, 'Non c\'è nessuna votazione aperta su questa spesa.') end

    local miei = millesimiDi(s.condominio_id, g.citizenid)
    if miei <= 0 then return rispondi(false, 'Non hai unità in questo condominio: non voti.') end

    local gia = MySQL.scalar.await(
        'SELECT id FROM condominio_voti WHERE spesa_id = ? AND citizenid = ?',
        { s.id, g.citizenid })
    if gia then return rispondi(false, 'Hai già votato.') end

    MySQL.insert.await([[
        INSERT INTO condominio_voti (spesa_id, citizenid, millesimi, favorevole)
        VALUES (?, ?, ?, ?)
    ]], { s.id, g.citizenid, miei, favorevole and 1 or 0 })

    local colonna = favorevole and 'millesimi_favorevoli' or 'millesimi_contrari'
    MySQL.update.await(('UPDATE condominio_spese SET %s = %s + ? WHERE id = ?'):format(colonna, colonna),
        { miei, s.id })

    local aggiornata = MySQL.single.await(
        'SELECT id, importo, descrizione, tipo, millesimi_favorevoli, millesimi_contrari FROM condominio_spese WHERE id = ?',
        { s.id })

    local regola = CON.Maggioranze[aggiornata.tipo] or CON.Maggioranze.ordinaria
    local raggiunta = aggiornata.millesimi_favorevoli >= regola.millesimiMinimi
        and (not regola.richiedeMaggioranzaVotanti
             or aggiornata.millesimi_favorevoli > aggiornata.millesimi_contrari)

    if raggiunta then
        delibera(aggiornata, { id = s.condominio_id, nome = s.nome_condominio })
        return rispondi(true, ('Voto registrato con %d millesimi.\nLa delibera è passata: %d favorevoli contro %d.')
            :format(miei, aggiornata.millesimi_favorevoli, aggiornata.millesimi_contrari))
    end

    rispondi(true, ('Voto registrato con %d millesimi.\nFavorevoli %d, contrari %d. Servono %d millesimi.')
        :format(miei, aggiornata.millesimi_favorevoli, aggiornata.millesimi_contrari,
                regola.millesimiMinimi))
end)

--- Le votazioni non restano aperte per sempre.
CreateThread(function()
    while true do
        Wait(120000)

        local scadute = MySQL.query.await([[
            SELECT id, descrizione, condominio_id FROM condominio_spese
            WHERE stato = 'proposta' AND TIMESTAMPDIFF(MINUTE, proposta_il, NOW()) > ?
        ]], { CON.Maggioranze.minutiVotazione }) or {}

        for _, s in ipairs(scadute) do
            MySQL.update.await('UPDATE condominio_spese SET stato = ? WHERE id = ?',
                { 'respinta', s.id })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Pagare la quota
-- ---------------------------------------------------------------------------
local function alzaDecoro(condominioId, punti)
    MySQL.update.await('UPDATE condomini SET decoro = LEAST(100, decoro + ?) WHERE id = ?',
        { punti, condominioId })
end

AUREA.Callback.Registra('con:pagaQuota', function(src, rispondi, quotaId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local q = MySQL.single.await([[
        SELECT q.id, q.importo, q.spesa_id, s.condominio_id, s.descrizione
        FROM condominio_quote q
        JOIN condominio_spese s ON s.id = q.spesa_id
        WHERE q.id = ? AND q.citizenid = ? AND q.pagata = 0
    ]], { tonumber(quotaId), g.citizenid })
    if not q then return rispondi(false, 'Quota non trovata o già pagata.') end

    if not g:SottraiOvunque(q.importo, ('quota condominiale — %s'):format(q.descrizione)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(q.importo)))
    end

    MySQL.update.await('UPDATE condominio_quote SET pagata = 1 WHERE id = ?', { q.id })
    MySQL.update.await('UPDATE condomini SET fondo = fondo + ? WHERE id = ?',
        { q.importo, q.condominio_id })

    -- Se tutte le quote sono rientrate, la spesa si chiude e il palazzo
    -- ne guadagna: il decoro sale per davvero solo quando i lavori sono
    -- pagati, non quando sono deliberati.
    local mancanti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM condominio_quote WHERE spesa_id = ? AND pagata = 0', { q.spesa_id }) or 0

    if mancanti == 0 then
        MySQL.update.await('UPDATE condominio_spese SET stato = ? WHERE id = ?', { 'chiusa', q.spesa_id })

        for _, v in ipairs(CON.Spese.voci) do
            if v.nome == q.descrizione then
                alzaDecoro(q.condominio_id, v.decoro)
                break
            end
        end
    end

    rispondi(true, ('Quota di %s versata.%s'):format(U.Euro(q.importo),
        mancanti == 0 and ' Erano le ultime: i lavori si fanno.' or (' Ne mancano %d.'):format(mancanti)))
end)

-- ---------------------------------------------------------------------------
--  Il decreto ingiuntivo (art. 63 disp. att. c.c.)
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('con:ingiungi', function(src, rispondi, quotaId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local q = MySQL.single.await([[
        SELECT q.id, q.importo, q.citizenid, q.ingiunta, s.condominio_id, s.descrizione,
               c.amministratore, c.nome AS nome_condominio,
               TIMESTAMPDIFF(MINUTE, q.scadenza, NOW()) AS ritardo
        FROM condominio_quote q
        JOIN condominio_spese s ON s.id = q.spesa_id
        JOIN condomini c ON c.id = s.condominio_id
        WHERE q.id = ? AND q.pagata = 0
    ]], { tonumber(quotaId) })
    if not q then return rispondi(false, 'Quota non trovata o già pagata.') end
    if q.amministratore ~= g.citizenid then
        return rispondi(false, 'Il decreto lo chiede l\'amministratore.')
    end
    if (q.ritardo or 0) < CON.Morosita.minutiPerIngiungere then
        return rispondi(false, ('Sono passati %d minuti dalla scadenza: ne servono %d.')
            :format(math.max(0, q.ritardo or 0), CON.Morosita.minutiPerIngiungere))
    end
    if q.ingiunta == 1 then return rispondi(false, 'Il decreto è già stato eseguito su questa quota.') end

    local dovuto = q.importo + CON.Morosita.speseLegali

    -- Immediatamente esecutivo: si va sul conto e si prende, anche se va
    -- sotto. È l'unico creditore del server che può farlo.
    local preso = AUREA.Denaro.SottraiOffline(q.citizenid, 'banca', dovuto,
        ('decreto ingiuntivo — %s'):format(q.descrizione), CON.Morosita.esecuzioneImmediata)

    if not preso then
        return rispondi(false, 'Esecuzione non riuscita: il conto non regge nemmeno lo scoperto.')
    end

    MySQL.update.await('UPDATE condominio_quote SET pagata = 1, ingiunta = 1 WHERE id = ?', { q.id })
    MySQL.update.await('UPDATE condomini SET fondo = fondo + ? WHERE id = ?',
        { q.importo, q.condominio_id })
    g:Aggiungi('banca', CON.Morosita.speseLegali, 'spese legali recuperate')

    TriggerEvent('aurea:telefono:messaggioSistema', q.citizenid, 'Amministratore',
        ('Decreto ingiuntivo eseguito: prelevati %s dal conto per la quota "%s" più spese legali. Art. 63 disp. att. c.c.: era immediatamente esecutivo.')
            :format(U.Euro(dovuto), q.descrizione))

    AUREA.Log('economia', 'avviso', g, ('decreto ingiuntivo su %s per %s')
        :format(q.citizenid, U.Euro(dovuto)))

    rispondi(true, ('Prelevati %s: %s di quota e %s di spese legali.')
        :format(U.Euro(dovuto), U.Euro(q.importo), U.Euro(CON.Morosita.speseLegali)))
end)

-- ---------------------------------------------------------------------------
--  Compenso dell'amministratore e degrado
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(CON.Decoro.minutiDegrado * 60000)

        -- Il palazzo si consuma da solo. Nessun palazzo resta come nuovo
        -- perché nessuno ha fatto niente.
        MySQL.update.await('UPDATE condomini SET decoro = GREATEST(0, decoro - ?)',
            { CON.Decoro.puntiDegrado })

        -- E l'amministratore si paga dal fondo, se il fondo c'è.
        local righe = MySQL.query.await([[
            SELECT id, nome, amministratore, fondo, compenso FROM condomini
            WHERE amministratore IS NOT NULL AND fondo >= compenso
        ]]) or {}

        for _, c in ipairs(righe) do
            MySQL.update.await('UPDATE condomini SET fondo = fondo - ? WHERE id = ?',
                { c.compenso, c.id })
            AUREA.Denaro.AggiungiOffline(c.amministratore, 'banca', c.compenso,
                ('compenso di amministrazione — %s'):format(c.nome))
        end
    end
end)
