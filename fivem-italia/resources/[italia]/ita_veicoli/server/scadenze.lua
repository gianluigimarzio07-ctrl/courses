--[[
    AUREA · Scadenze automatiche dei veicoli

    Ogni ciclo controlla bollo, RCA e revisione di tutti i veicoli e produce
    le conseguenze previste: avviso, tributo iscritto, fermo amministrativo.
]]

local U = AUREA.Util

--- Notifica al proprietario, se online, altrimenti lascia un SMS.
local function avvisa(citizenid, dati, testoSMS)
    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, dati)
    end
    if testoSMS then
        TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'ACI', testoSMS)
    end
end

CreateThread(function()
    Wait(30000)   -- lascia partire il resto del server

    while true do
        -- =====================================================================
        --  Preavviso: scadenze entro 7 giorni
        -- =====================================================================
        local inScadenza = MySQL.query.await([[
            SELECT targa, citizenid, modello, bollo_scadenza, assicurazione_scadenza, revisione_scadenza
            FROM veicoli
            WHERE stato != 'demolito'
              AND (
                (bollo_scadenza BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)) OR
                (assicurazione_scadenza BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)) OR
                (revisione_scadenza BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY))
              )
        ]]) or {}

        for _, v in ipairs(inScadenza) do
            avvisa(v.citizenid, {
                tipo = 'avviso', icona = '📅', durata = 10000,
                titolo = ('Scadenze in arrivo — %s'):format(v.targa),
                testo = 'Controlla bollo, assicurazione e revisione presso gli sportelli competenti.',
            }, ('Il veicolo targato %s ha una scadenza entro 7 giorni. Regolarizza per evitare sanzioni.'):format(v.targa))
        end

        -- =====================================================================
        --  Bollo scaduto: iscrizione del tributo e mora
        -- =====================================================================
        local bolloScaduto = MySQL.query.await([[
            SELECT v.targa, v.citizenid, v.modello, v.classe_ambientale,
                   DATEDIFF(CURDATE(), v.bollo_scadenza) AS giorni
            FROM veicoli v
            WHERE v.stato IN ('garage','fuori')
              AND v.bollo_scadenza IS NOT NULL
              AND v.bollo_scadenza < CURDATE()
              AND NOT EXISTS (
                SELECT 1 FROM tributi t
                WHERE t.citizenid = v.citizenid AND t.tipo = 'bollo_auto'
                  AND t.stato IN ('dovuto','cartella') AND t.periodo = v.targa
              )
        ]]) or {}

        for _, v in ipairs(bolloScaduto) do
            local catalogo = VEI.GetVeicoloCatalogo(v.modello)
            local importo = VEI.CalcolaBollo(catalogo and catalogo.kw or 100, v.classe_ambientale)
            importo = math.floor(importo * (1 + VEI.Bollo.moraPercentuale))

            MySQL.insert.await([[
                INSERT INTO tributi (citizenid, tipo, periodo, importo, scadenza, stato)
                VALUES (?, 'bollo_auto', ?, ?, ?, 'dovuto')
            ]], { v.citizenid, v.targa, importo, U.DataOraPiuOre(30 * 24) })

            avvisa(v.citizenid, {
                tipo = 'errore', icona = '🧾', durata = 12000,
                titolo = ('Bollo scaduto — %s'):format(v.targa),
                testo = ('Importo con mora: %s. Paga allo sportello veicoli.'):format(U.Euro(importo)),
            }, ('Bollo auto scaduto per il veicolo %s. Dovuto %s con mora del 30%%.'):format(v.targa, U.Euro(importo)))

            -- Oltre la soglia scatta il fermo amministrativo
            if (v.giorni or 0) > VEI.Bollo.giorniFermo then
                MySQL.update.await('UPDATE veicoli SET stato = \'sequestrato\', garage = \'depositeria\' WHERE targa = ?', { v.targa })
                avvisa(v.citizenid, {
                    tipo = 'errore', icona = '🚫', durata = 14000,
                    titolo = ('Fermo amministrativo — %s'):format(v.targa),
                    testo = 'Il veicolo è stato posto in fermo per omesso pagamento del bollo.',
                })
                AUREA.Log('veicoli', 'avviso', nil, ('Fermo amministrativo su %s (bollo scaduto da %d giorni)'):format(v.targa, v.giorni))
            end
        end

        -- =====================================================================
        --  RCA scaduta: il veicolo non può circolare
        -- =====================================================================
        local rcaScaduta = MySQL.query.await([[
            SELECT targa, citizenid FROM veicoli
            WHERE assicurazione_tipo != 'nessuna'
              AND assicurazione_scadenza IS NOT NULL
              AND assicurazione_scadenza < CURDATE()
        ]]) or {}

        for _, v in ipairs(rcaScaduta) do
            MySQL.update.await('UPDATE veicoli SET assicurazione_tipo = \'nessuna\' WHERE targa = ?', { v.targa })
            avvisa(v.citizenid, {
                tipo = 'errore', icona = '⚠', durata = 12000,
                titolo = ('Polizza scaduta — %s'):format(v.targa),
                testo = 'Circolare senza RCA comporta sanzione e sequestro (art. 193 CdS).',
            }, ('La polizza RCA del veicolo %s è scaduta. Rinnovala prima di circolare.'):format(v.targa))
        end

        -- =====================================================================
        --  Classe di merito: chi non fa sinistri scende di classe (paga meno)
        -- =====================================================================
        local assicurati = MySQL.query.await([[
            SELECT targa, proprieta FROM veicoli
            WHERE assicurazione_tipo != 'nessuna' AND stato != 'demolito'
        ]]) or {}

        for _, v in ipairs(assicurati) do
            local proprieta = v.proprieta and json.decode(v.proprieta) or {}
            local classe = proprieta.classeMerito or VEI.Assicurazione.classeIngresso
            if classe > 1 then
                proprieta.classeMerito = classe - 1
                MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(proprieta), v.targa })
            end
        end

        Wait(VEI.Assicurazione.minutiPerClasse * 60000)
    end
end)

-- ---------------------------------------------------------------------------
--  Sinistro: peggiora la classe di merito e attiva l'eventuale kasko
-- ---------------------------------------------------------------------------
RegisterNetEvent('vei:sinistro', function(targa, danniStimati)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    targa = (targa or ''):upper():gsub('%s+', '')
    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ? AND citizenid = ?', { targa, g.citizenid })
    if not v then return end

    local proprieta = v.proprieta and json.decode(v.proprieta) or {}
    proprieta.classeMerito = math.min(11, (proprieta.classeMerito or VEI.Assicurazione.classeIngresso) + 2)
    proprieta.sinistri = (proprieta.sinistri or 0) + 1
    MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(proprieta), targa })

    local polizza = VEI.Assicurazione.tipi[v.assicurazione_tipo]
    if polizza and polizza.rimborsoDanni > 0 and danniStimati then
        local rimborso = math.floor(tonumber(danniStimati) * polizza.rimborsoDanni)
        if rimborso > 0 then
            g:Aggiungi('banca', rimborso, ('rimborso kasko %s'):format(targa))
            TriggerClientEvent('aurea:ui:notifica', src, {
                tipo = 'successo', icona = '🛡', durata = 9000,
                titolo = 'Sinistro liquidato',
                testo = ('Rimborso kasko %s. Classe di merito ora %d: il prossimo premio sarà più alto.'):format(
                    U.Euro(rimborso), proprieta.classeMerito),
            })
            return
        end
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '📋', durata = 9000,
        titolo = 'Sinistro registrato',
        testo = ('Classe di merito peggiorata a %d. Il prossimo premio RCA sarà più alto.'):format(proprieta.classeMerito),
    })
end)
