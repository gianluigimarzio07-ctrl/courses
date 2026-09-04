--[[
    AUREA · Verbali di contestazione (server)

    Ciclo di vita di un verbale:
      aperta  →  pagata                 (entro la scadenza)
              →  ruolo                  (scaduta: iscritta a ruolo, +50%)
              →  ricorso / annullata    (decide il Giudice di Pace)
]]

Verbali = {}

local U = AUREA.Util

--- Emette un verbale e lo notifica al trasgressore se online.
---@param dati table { citizenid, targa, articolo, descrizione, importo, punti, origine, agente, luogo, prova }
---@return integer id
function Verbali.Emetti(dati)
    local id = MySQL.insert.await([[
        INSERT INTO multe
            (citizenid, targa, articolo, descrizione, importo, punti_decurtati,
             origine, agente, luogo, prova, scadenza)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        dati.citizenid, dati.targa, dati.articolo, dati.descrizione,
        dati.importo, dati.punti or 0, dati.origine, dati.agente, dati.luogo,
        dati.prova and json.encode(dati.prova) or nil,
        U.DataOraPiuOre(CDS.Regole.scadenzaGiorni * 24),
    })

    if (dati.punti or 0) > 0 then
        Patente.Decurta(dati.citizenid, dati.punti, dati.articolo)
    end

    local g = AUREA.GetPlayerByCitizenId(dati.citizenid)
    if g then
        TriggerClientEvent('cds:verbaleNotificato', g.source, {
            articolo = dati.articolo,
            descrizione = dati.descrizione,
            luogo = dati.luogo or 'luogo non indicato',
            importo = dati.importo,
            scontato = math.floor(dati.importo * (1 - CDS.Regole.scontoPercentuale)),
            punti = dati.punti or 0,
        })
        -- copia digitale nel telefono
        TriggerEvent('aurea:telefono:messaggioSistema', dati.citizenid, 'Verbali',
            ('%s — %s. Importo %s (ridotto %s entro %d giorni). Luogo: %s.'):format(
                dati.articolo, dati.descrizione, U.Euro(dati.importo),
                U.Euro(math.floor(dati.importo * 0.7)), CDS.Regole.scontoGiorni, dati.luogo or 'n.d.'))
    end

    AUREA.Log('multe', 'info', nil, ('Verbale #%d a %s: %s — %s'):format(id, dati.citizenid, dati.articolo, U.Euro(dati.importo)))
    return id
end

--- Verbali aperti di un personaggio, con importo effettivamente dovuto.
function Verbali.Aperti(citizenid)
    local righe = MySQL.query.await([[
        SELECT id, articolo, descrizione, importo, punti_decurtati, origine, luogo,
               emessa_il, scadenza, stato,
               TIMESTAMPDIFF(DAY, emessa_il, NOW()) AS giorni
        FROM multe
        WHERE citizenid = ? AND stato IN ('aperta','ruolo')
        ORDER BY emessa_il ASC
    ]], { citizenid }) or {}

    for _, m in ipairs(righe) do
        m.scontato = false
        m.dovuto = m.importo

        if m.stato == 'ruolo' then
            m.dovuto = math.floor(m.importo * (1 + CDS.Regole.maggiorazioneRuolo))
        elseif (m.giorni or 0) < CDS.Regole.scontoGiorni then
            m.scontato = true
            m.dovuto = math.floor(m.importo * (1 - CDS.Regole.scontoPercentuale))
        end

        m.emessa = U.DataOraIT(math.floor((m.emessa_il or 0) / 1000))
    end
    return righe
end

--- Somma dovuta complessiva.
function Verbali.TotaleDovuto(citizenid)
    local totale = 0
    for _, m in ipairs(Verbali.Aperti(citizenid)) do totale = totale + m.dovuto end
    return totale
end

--- Paga uno o tutti i verbali. Restituisce (ok, messaggio).
function Verbali.Paga(citizenid, idVerbale)
    local aperti = Verbali.Aperti(citizenid)
    if #aperti == 0 then return false, 'Non hai verbali da pagare.' end

    local daPagare = {}
    if idVerbale == 'tutte' then
        daPagare = aperti
    else
        for _, m in ipairs(aperti) do
            if m.id == tonumber(idVerbale) then daPagare = { m } break end
        end
    end
    if #daPagare == 0 then return false, 'Verbale non trovato.' end

    local totale = 0
    for _, m in ipairs(daPagare) do totale = totale + m.dovuto end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if not g then return false, 'Devi essere in gioco per pagare.' end
    if not g:SottraiOvunque(totale, 'pagamento verbali') then
        return false, ('Servono %s fra contanti e conto.'):format(U.Euro(totale))
    end

    local ids = {}
    for _, m in ipairs(daPagare) do ids[#ids + 1] = m.id end
    MySQL.update.await(
        ('UPDATE multe SET stato = \'pagata\', pagata_il = NOW() WHERE id IN (%s)')
            :format(table.concat(ids, ',')))

    -- Il gettito finisce all'erario, non nel nulla
    TriggerEvent('aurea:fisco:incasso', 'sanzioni', totale, citizenid)

    AUREA.Log('multe', 'info', nil, ('%s ha pagato %d verbali per %s'):format(citizenid, #daPagare, U.Euro(totale)))
    return true, ('Pagati %d verbali per %s.'):format(#daPagare, U.Euro(totale))
end

--- Annulla un verbale (accoglimento del ricorso).
function Verbali.Annulla(idVerbale, motivo, staff)
    MySQL.update.await('UPDATE multe SET stato = \'annullata\' WHERE id = ?', { idVerbale })
    AUREA.Log('multe', 'avviso', nil, ('Verbale #%s annullato da %s: %s'):format(idVerbale, staff or 'sistema', motivo or 'n.d.'))
end

-- ---------------------------------------------------------------------------
--  Iscrizione a ruolo dei verbali scaduti
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(15 * 60000)

        local scaduti = MySQL.query.await([[
            SELECT id, citizenid, importo FROM multe
            WHERE stato = 'aperta' AND scadenza < NOW()
        ]]) or {}

        for _, m in ipairs(scaduti) do
            MySQL.update.await('UPDATE multe SET stato = \'ruolo\' WHERE id = ?', { m.id })

            -- L'Agenzia delle Entrate Riscossione apre una cartella
            MySQL.insert.await([[
                INSERT INTO tributi (citizenid, tipo, periodo, importo, scadenza, stato)
                VALUES (?, 'sanzioni', ?, ?, ?, 'cartella')
            ]], {
                m.citizenid, os.date('%Y-Q') .. math.ceil(tonumber(os.date('%m')) / 3),
                math.floor(m.importo * (1 + CDS.Regole.maggiorazioneRuolo)),
                U.DataOraPiuOre(30 * 24),
            })

            local g = AUREA.GetPlayerByCitizenId(m.citizenid)
            if g then
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'errore', icona = '📮', durata = 12000,
                    titolo = 'Cartella esattoriale',
                    testo = ('Verbale #%d non pagato: iscritto a ruolo con maggiorazione del 50%%.'):format(m.id),
                })
            end
        end

        if #scaduti > 0 then
            AUREA.Log('multe', 'avviso', nil, ('%d verbali iscritti a ruolo'):format(#scaduti))
        end
    end
end)

exports('EmettiVerbale', Verbali.Emetti)
exports('VerbaliAperti', Verbali.Aperti)
exports('TotaleVerbali', Verbali.TotaleDovuto)
