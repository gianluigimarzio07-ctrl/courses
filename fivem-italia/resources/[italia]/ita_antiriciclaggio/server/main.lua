--[[
    AUREA · Antiriciclaggio (server)

    Tre porte, in ordine di quanto sono fastidiose.

    1. L'adeguata verifica: un controllo che si fa una volta e vale
       quattro ore. Senza, le operazioni grosse non passano.
    2. Il frazionamento: una somma su finestra mobile. È l'unica cosa
       qui dentro che vede quello che una soglia secca non vede.
    3. Il congelamento: la Finanza blocca, e il blocco ha una scadenza.

    `Valuta` è l'unico punto di ingresso: lo chiama aurea_banca prima di
    eseguire un'operazione, e risponde se si può fare. Tutto il resto di
    questa risorsa serve a dare un senso a quella risposta.
]]

local U = AUREA.Util

local function finanza(g, permesso)
    return g and g.lavoro.nome == AML.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'uif')
end

-- ---------------------------------------------------------------------------
--  Adeguata verifica
-- ---------------------------------------------------------------------------
local function verificaDi(citizenid)
    return MySQL.single.await([[
        SELECT profilo, fonte_reddito, scade_il,
               TIMESTAMPDIFF(MINUTE, NOW(), scade_il) AS minuti
        FROM aml_verifiche WHERE citizenid = ? AND scade_il > NOW()
    ]], { citizenid })
end

exports('VerificaValida', function(citizenid)
    return verificaDi(citizenid) ~= nil
end)

AUREA.Callback.Registra('aml:verificaStato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local v = verificaDi(g.citizenid)
    rispondi({
        verifica = v,
        fonti = AML.Verifica.fonti,
        soglia = AML.Verifica.sogliaOperazione,
        minuti = AML.Verifica.minutiValidita,
    })
end)

AUREA.Callback.Registra('aml:verifica', function(src, rispondi, fonteId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local fonte = AML.GetFonte(fonteId)
    if not fonte then return rispondi(false, 'Fonte non valida.') end

    -- Il profilo lo decide quello che c'è sul conto, non quello che
    -- dice il cliente. Chi dichiara "reddito da lavoro" e ha movimenti
    -- da centomila euro non è a rischio basso.
    local _, saldo = AUREA.Denaro.Saldo(g.citizenid)
    local profilo = 'basso'
    if (saldo or 0) > 5000000 then
        profilo = 'alto'
    elseif (saldo or 0) > 1500000 then
        profilo = 'medio'
    end

    -- E se ha precedenti per reati contro il patrimonio, il profilo è
    -- alto comunque
    local precedenti = exports.ita_giustizia:Precedenti(g.citizenid) or {}
    for _, p in ipairs(precedenti) do
        if (p.gravita or 0) >= 3 then profilo = 'alto' break end
    end

    MySQL.query.await([[
        INSERT INTO aml_verifiche (citizenid, profilo, fonte_reddito, scade_il)
        VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE profilo = VALUES(profilo), fonte_reddito = VALUES(fonte_reddito),
                                scade_il = VALUES(scade_il)
    ]], { g.citizenid, profilo, fonte.nome, AML.Verifica.minutiValidita })

    AUREA.Log('denaro', 'info', g, ('adeguata verifica: profilo %s, fonte %s')
        :format(profilo, fonte.id))

    rispondi(true, ('Verifica completata. Profilo di rischio: %s.\nVale %d minuti, poi va rifatta.\nOltre %s le operazioni si fermano senza.')
        :format(profilo, AML.Verifica.minutiValidita,
                U.Euro(AML.Verifica.soglie[profilo] or AML.Verifica.sogliaOperazione)))
end)

-- ---------------------------------------------------------------------------
--  Segnalazione
-- ---------------------------------------------------------------------------
local function segnala(citizenid, tipo, importo, motivo, segnalataDa)
    local id = MySQL.insert.await([[
        INSERT INTO aml_segnalazioni (citizenid, tipo, importo, motivo, segnalata_da)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, tipo, importo, motivo, segnalataDa })

    local nome = MySQL.scalar.await(
        'SELECT CONCAT(nome, " ", cognome) FROM personaggi WHERE citizenid = ?', { citizenid })

    exports.aurea_ui:NotificaLavoro(AML.Lavoro, {
        tipo = 'avviso', icona = '💼', durata = 16000,
        titolo = 'Segnalazione di operazione sospetta',
        testo = ('%s — %s\n%s'):format(nome or citizenid, U.Euro(importo), motivo),
    }, true)

    AUREA.Log('denaro', 'avviso', nil, ('SOS su %s: %s (%s)')
        :format(citizenid, U.Euro(importo), motivo))

    return id
end

exports('Segnala', segnala)

-- ---------------------------------------------------------------------------
--  Il punto d'ingresso
--
--  Lo chiama aurea_banca prima di eseguire. Risponde tre cose: se si
--  può fare, perché no, e se va segnalata.
-- ---------------------------------------------------------------------------
exports('Valuta', function(citizenid, importo, tipoOperazione, sporco)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return true end

    -- 1. Somme congelate: su quel conto non si tocca niente
    local congelato = MySQL.scalar.await([[
        SELECT COALESCE(SUM(importo), 0) FROM aml_congelamenti
        WHERE citizenid = ? AND esito = 'in_corso' AND scade_il > NOW()
    ]], { citizenid }) or 0

    if congelato > 0 then
        local _, saldo = AUREA.Denaro.Saldo(citizenid)
        if importo > math.max(0, (saldo or 0) - congelato) then
            return false, ('Sul conto ci sono %s sotto provvedimento di congelamento: non sono disponibili.')
                :format(U.Euro(congelato))
        end
    end

    -- 2. Contante di provenienza illecita: si segnala sempre
    if sporco then
        segnala(citizenid, 'contante', importo,
            'Versamento di contante di provenienza non giustificata', nil)
    end

    -- 3. Adeguata verifica, per le operazioni rilevanti
    local v = verificaDi(citizenid)
    local soglia = v and (AML.Verifica.soglie[v.profilo] or AML.Verifica.sogliaOperazione)
                     or AML.Verifica.sogliaOperazione

    if importo >= soglia and not v then
        return false, ('Operazione sopra %s senza adeguata verifica della clientela. Si fa allo sportello, e poi vale %d minuti.')
            :format(U.Euro(soglia), AML.Verifica.minutiValidita)
    end

    if v and importo >= soglia then
        segnala(citizenid, 'profilo', importo,
            ('Operazione di %s su profilo di rischio %s, fonte dichiarata: %s')
                :format(U.Euro(importo), v.profilo, v.fonte_reddito or 'non dichiarata'), nil)
    end

    -- 4. Frazionamento: la somma sulla finestra mobile
    if tipoOperazione == 'versamento' then
        -- I movimenti stanno per IBAN, non per persona: il conto lo si
        -- ritrova passando da `conti`. È anche il motivo per cui il
        -- frazionamento su più conti intestati alla stessa persona si
        -- vede lo stesso.
        local finestra = MySQL.single.await([[
            SELECT COUNT(*) AS quante, COALESCE(SUM(m.importo), 0) AS totale
            FROM movimenti m
            JOIN conti c ON c.iban = m.iban
            WHERE c.intestatario = ? AND m.importo > 0
              AND m.causale LIKE '%versamento%'
              AND TIMESTAMPDIFF(MINUTE, m.momento, NOW()) <= ?
        ]], { citizenid, AML.Frazionamento.minutiFinestra }) or { quante = 0, totale = 0 }

        local cumulato = (finestra.totale or 0) + importo
        if (finestra.quante or 0) + 1 >= AML.Frazionamento.operazioniMinime
           and cumulato >= AML.Frazionamento.sogliaCumulata then

            local gia = MySQL.scalar.await([[
                SELECT id FROM aml_segnalazioni
                WHERE citizenid = ? AND tipo = 'frazionamento' AND stato = 'aperta'
                  AND TIMESTAMPDIFF(MINUTE, quando, NOW()) <= ?
            ]], { citizenid, AML.Frazionamento.minutiFinestra })

            if not gia then
                segnala(citizenid, 'frazionamento', cumulato,
                    ('%d versamenti per %s in %d minuti, tutti sotto soglia')
                        :format((finestra.quante or 0) + 1, U.Euro(cumulato),
                                AML.Frazionamento.minutiFinestra), nil)
            end
        end
    end

    return true
end)

-- ---------------------------------------------------------------------------
--  Limite al contante fra privati (art. 49)
-- ---------------------------------------------------------------------------
exports('ContanteAmmesso', function(importo)
    return (tonumber(importo) or 0) <= AML.Contante.limite, AML.Contante.limite
end)

AddEventHandler('aurea:antiriciclaggio:contante', function(daCitizenid, aCitizenid, importo)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= AML.Contante.limite then return end

    -- Art. 49: pagano tutti e due, chi dà e chi riceve
    for _, cid in ipairs({ daCitizenid, aCitizenid }) do
        if cid then
            AUREA.Denaro.SottraiOffline(cid, 'banca', AML.Contante.sanzione,
                'violazione del limite al contante (art. 49 D.Lgs. 231/2007)', true)
            TriggerEvent('aurea:fisco:incasso', 'sanzioni_valutarie', AML.Contante.sanzione, cid)

            TriggerEvent('aurea:telefono:messaggioSistema', cid, 'M.E.F.',
                ('Trasferimento in contanti di %s: oltre il limite di %s. Sanzione %s, a carico di entrambe le parti.')
                    :format(U.Euro(importo), U.Euro(AML.Contante.limite), U.Euro(AML.Contante.sanzione)))
        end
    end

    segnala(daCitizenid, 'contante', importo,
        ('Trasferimento di contante fra privati oltre il limite di legge'), nil)
end)

-- ---------------------------------------------------------------------------
--  La coda della Finanza
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('aml:coda', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not finanza(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT s.id, s.citizenid, s.tipo, s.importo, s.motivo, s.stato,
               CONCAT(p.nome, ' ', p.cognome) AS nominativo, p.codice_fiscale,
               TIMESTAMPDIFF(MINUTE, s.quando, NOW()) AS minutiFa,
               v.profilo, v.fonte_reddito
        FROM aml_segnalazioni s
        LEFT JOIN personaggi p ON p.citizenid = s.citizenid
        LEFT JOIN aml_verifiche v ON v.citizenid = s.citizenid
        WHERE s.stato = 'aperta'
        ORDER BY s.quando ASC LIMIT 25
    ]]) or {}

    local congelati = MySQL.query.await([[
        SELECT c.id, c.citizenid, c.importo,
               CONCAT(p.nome, ' ', p.cognome) AS nominativo,
               TIMESTAMPDIFF(MINUTE, NOW(), c.scade_il) AS minuti
        FROM aml_congelamenti c
        LEFT JOIN personaggi p ON p.citizenid = c.citizenid
        WHERE c.esito = 'in_corso'
    ]]) or {}

    rispondi({ segnalazioni = righe, congelamenti = congelati,
               puoCongelare = finanza(g, 'congelamento_conti') })
end)

AUREA.Callback.Registra('aml:archivia', function(src, rispondi, id, esito)
    local g = AUREA.GetPlayer(src)
    if not finanza(g) then return rispondi(false, 'Riservato al nucleo valutario.') end

    local s = MySQL.single.await('SELECT id, citizenid FROM aml_segnalazioni WHERE id = ? AND stato = ?',
        { tonumber(id), 'aperta' })
    if not s then return rispondi(false, 'Segnalazione non aperta.') end

    MySQL.update.await([[
        UPDATE aml_segnalazioni SET stato = 'archiviata', esito = ?, chiusa_da = ? WHERE id = ?
    ]], { tostring(esito or 'Nessun elemento di sospetto'):sub(1, 255), g.citizenid, s.id })

    rispondi(true, 'Segnalazione archiviata.')
end)

AUREA.Callback.Registra('aml:congela', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not finanza(g, 'congelamento_conti') then
        return rispondi(false, 'Il congelamento lo dispone un maresciallo o superiore.')
    end

    local s = MySQL.single.await(
        'SELECT id, citizenid, importo FROM aml_segnalazioni WHERE id = ? AND stato = ?',
        { tonumber(id), 'aperta' })
    if not s then return rispondi(false, 'Segnalazione non aperta.') end

    local _, saldo = AUREA.Denaro.Saldo(s.citizenid)
    local bloccabile = math.floor((saldo or 0) * AML.Congelamento.quotaMassima)
    local importo = math.min(bloccabile, s.importo)

    if importo <= 0 then
        return rispondi(false, 'Sul conto non c\'è niente da bloccare.')
    end

    MySQL.insert.await([[
        INSERT INTO aml_congelamenti (citizenid, importo, segnalazione_id, disposto_da, scade_il)
        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], { s.citizenid, importo, s.id, g.citizenid, AML.Congelamento.minutiDurata })

    MySQL.update.await([[
        UPDATE aml_segnalazioni SET stato = 'trasmessa', chiusa_da = ? WHERE id = ?
    ]], { g.citizenid, s.id })

    TriggerEvent('aurea:telefono:messaggioSistema', s.citizenid, 'Guardia di Finanza',
        ('Sospensione dell\'operazione: %s sul tuo conto sono bloccati per %d minuti. Se non si conferma, tornano disponibili.')
            :format(U.Euro(importo), AML.Congelamento.minutiDurata))

    AUREA.Log('denaro', 'avviso', g, ('congelati %s a %s'):format(U.Euro(importo), s.citizenid))

    rispondi(true, ('Congelati %s per %d minuti. Per confiscarli serve un fascicolo.')
        :format(U.Euro(importo), AML.Congelamento.minutiDurata))
end)

AUREA.Callback.Registra('aml:conferma', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not finanza(g, 'congelamento_conti') then return rispondi(false, 'Non hai la competenza.') end

    local c = MySQL.single.await(
        'SELECT id, citizenid, importo FROM aml_congelamenti WHERE id = ? AND esito = ?',
        { tonumber(id), 'in_corso' })
    if not c then return rispondi(false, 'Congelamento non in corso.') end

    -- La confisca senza un fascicolo aperto non si fa: è l'unica
    -- garanzia che separa un sequestro da un prelievo.
    local precedenti = exports.ita_giustizia:Precedenti(c.citizenid, true) or {}
    if #precedenti == 0 then
        return rispondi(false, 'Non risultano procedimenti aperti a suo carico: il congelamento non si può confermare.')
    end

    AUREA.Denaro.SottraiOffline(c.citizenid, 'banca', c.importo,
        'confisca di somme di provenienza illecita', true)
    TriggerEvent('aurea:fisco:incasso', 'confische', c.importo, c.citizenid)

    MySQL.update.await(
        'UPDATE aml_congelamenti SET esito = ?, chiuso_il = NOW() WHERE id = ?',
        { 'confiscato', c.id })

    exports.ita_giustizia:ApriFascicolo(c.citizenid, AML.Congelamento.reatoRiciclaggio,
        g:NomeCompleto(), ('Confisca di %s di provenienza non giustificata'):format(U.Euro(c.importo)))

    TriggerEvent('aurea:telefono:messaggioSistema', c.citizenid, 'Guardia di Finanza',
        ('Le somme congelate (%s) sono state confiscate.'):format(U.Euro(c.importo)))

    AUREA.Log('denaro', 'avviso', g, ('confiscati %s a %s'):format(U.Euro(c.importo), c.citizenid))
    rispondi(true, ('Confiscati %s.'):format(U.Euro(c.importo)))
end)

-- ---------------------------------------------------------------------------
--  I congelamenti scadono
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(120000)

        local scaduti = MySQL.query.await([[
            SELECT id, citizenid, importo FROM aml_congelamenti
            WHERE esito = 'in_corso' AND scade_il <= NOW()
        ]]) or {}

        for _, c in ipairs(scaduti) do
            MySQL.update.await(
                'UPDATE aml_congelamenti SET esito = ?, chiuso_il = NOW() WHERE id = ?',
                { 'restituito', c.id })

            TriggerEvent('aurea:telefono:messaggioSistema', c.citizenid, 'Guardia di Finanza',
                ('Il provvedimento sulle somme congelate (%s) è decaduto: sono di nuovo disponibili.')
                    :format(U.Euro(c.importo)))
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App del telefono
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'antiriciclaggio',
    nome = 'Verifica',
    icona = '💼',
    colore = 'linear-gradient(150deg,#4e6e5a,#243528)',
    ordine = 142,

    schermata = function(g)
        local v = verificaDi(g.citizenid)
        local soglia = v and (AML.Verifica.soglie[v.profilo] or AML.Verifica.sogliaOperazione)
                         or AML.Verifica.sogliaOperazione

        local voci = {
            { icona = v and '✅' or '⛔',
              titolo = 'Adeguata verifica',
              valore = v and 'Valida' or 'Assente',
              sottotitolo = v
                  and ('Profilo %s · fonte: %s · scade fra %d minuti')
                      :format(v.profilo, v.fonte_reddito or '—', math.max(0, v.minuti or 0))
                  or 'Si fa in banca. Senza, le operazioni rilevanti si fermano.',
              tono = v and 'verde' or 'rosso', inerte = true },
            { icona = '📏', titolo = 'Soglia per te',
              valore = U.Euro(soglia),
              sottotitolo = 'Sopra questa cifra ogni operazione viene guardata.',
              inerte = true },
            { icona = '💶', titolo = 'Limite al contante fra privati',
              valore = U.Euro(AML.Contante.limite),
              sottotitolo = 'Art. 49: oltre, pagano la sanzione entrambe le parti.',
              inerte = true },
        }

        local congelato = MySQL.scalar.await([[
            SELECT COALESCE(SUM(importo), 0) FROM aml_congelamenti
            WHERE citizenid = ? AND esito = 'in_corso' AND scade_il > NOW()
        ]], { g.citizenid }) or 0

        if congelato > 0 then
            voci[#voci + 1] = {
                icona = '🧊', titolo = 'Somme congelate',
                valore = U.Euro(congelato), tono = 'rosso',
                sottotitolo = 'Bloccate su disposizione della Guardia di Finanza.',
                inerte = true,
            }
        end

        return { tipo = 'lista', sottotitolo = 'Posizione antiriciclaggio', voci = voci }
    end,
})
