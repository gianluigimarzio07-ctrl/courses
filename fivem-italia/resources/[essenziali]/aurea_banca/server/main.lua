--[[
    AUREA · Banca (server)

    Il saldo autorevole del conto personale resta su personaggi.banca: la
    tabella conti tiene l'IBAN, i movimenti e i conti aziendali. Le due cose
    restano allineate perché ogni operazione passa da qui.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------

local function contoDi(citizenid)
    local conto = MySQL.single.await('SELECT * FROM conti WHERE intestatario = ? AND tipo = \'personale\' LIMIT 1', { citizenid })
    if conto then return conto end

    -- conto mancante (personaggi creati prima del modulo): lo si apre ora
    local saldo = MySQL.scalar.await('SELECT banca FROM personaggi WHERE citizenid = ?', { citizenid }) or 0
    local iban = AUREA.Anagrafe.NuovoIBAN(citizenid)
    MySQL.insert.await('INSERT INTO conti (iban, intestatario, tipo, nome, saldo) VALUES (?, ?, \'personale\', ?, ?)',
        { iban, citizenid, 'Conto corrente', saldo })
    return MySQL.single.await('SELECT * FROM conti WHERE iban = ?', { iban })
end

local function registraMovimento(iban, causale, importo, saldoDopo, controparte, categoria)
    MySQL.insert('INSERT INTO movimenti (iban, controparte, causale, importo, saldo_dopo, categoria) VALUES (?, ?, ?, ?, ?, ?)',
        { iban, controparte, causale, importo, saldoDopo, categoria or 'generico' })
end

--- Allinea il saldo del conto a quello del personaggio dopo ogni variazione.
AddEventHandler('aurea:denaro:variato', function(src, tipoConto, delta, causale)
    if tipoConto ~= 'banca' then return end
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local conto = contoDi(g.citizenid)
    MySQL.update('UPDATE conti SET saldo = ? WHERE iban = ?', { g.denaro.banca, conto.iban })
    registraMovimento(conto.iban, causale or 'operazione', delta, g.denaro.banca, nil,
        delta > 0 and 'accredito' or 'addebito')
end)

-- ---------------------------------------------------------------------------
--  Merito creditizio
-- ---------------------------------------------------------------------------
local function meritoCreditizio(citizenid)
    local punteggio = 1

    local verbali = exports.ita_codicestrada:TotaleVerbali(citizenid)
    if verbali > 100000 then punteggio = punteggio + 1 end
    if verbali > 500000 then punteggio = punteggio + 1 end

    local _, tributi = exports.ita_fisco:DebitoFiscale(citizenid)
    if tributi > 100000 then punteggio = punteggio + 1 end
    if tributi > 1000000 then punteggio = punteggio + 1 end

    local insoluti = MySQL.scalar.await(
        'SELECT COUNT(*) FROM mutui WHERE citizenid = ? AND stato IN (\'insoluto\',\'pignorato\')', { citizenid }) or 0
    punteggio = punteggio + math.min(2, insoluti)

    return math.min(5, punteggio)
end

-- ---------------------------------------------------------------------------
--  Callback
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('banca:situazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local conto = contoDi(g.citizenid)
    local movimenti = MySQL.query.await(
        'SELECT causale, importo, saldo_dopo, categoria, momento, controparte FROM movimenti WHERE iban = ? ORDER BY id DESC LIMIT 25',
        { conto.iban }) or {}

    for _, m in ipairs(movimenti) do
        m.quando = U.DataOraIT(math.floor((m.momento or 0) / 1000))
    end

    local mutui = MySQL.query.await(
        'SELECT * FROM mutui WHERE citizenid = ? AND stato != \'estinto\'', { g.citizenid }) or {}
    for _, m in ipairs(mutui) do
        m.prossimaIT = U.DataOraIT(math.floor((m.prossima_rata or 0) / 1000))
    end

    local merito = meritoCreditizio(g.citizenid)

    rispondi({
        iban = conto.iban,
        saldo = g.denaro.banca,
        contanti = g.denaro.contanti,
        movimenti = movimenti,
        mutui = mutui,
        merito = merito,
        meritoEtichetta = BANCA.Merito[merito].etichetta,
        tasso = BANCA.Mutui.tassoBase + BANCA.Merito[merito].maggiorazione,
    })
end)

AUREA.Callback.Registra('banca:versa', function(src, rispondi, euro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local importo = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end
    if importo > BANCA.Commissioni.massimaleOperazione then
        return rispondi(false, ('Il massimale per operazione è %s.'):format(U.Euro(BANCA.Commissioni.massimaleOperazione)))
    end

    if not g:Sottrai('contanti', importo, 'versamento in conto') then
        return rispondi(false, 'Non hai questi contanti.')
    end
    g:Aggiungi('banca', importo, 'versamento in conto')

    if importo >= BANCA.Commissioni.sogliaAntiriciclaggio then
        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '💼', durata = 12000,
            titolo = 'Segnalazione operazione sospetta',
            testo = ('%s (%s) ha versato %s in contanti.'):format(g:NomeCompleto(), g.cf, U.Euro(importo)),
        }, true)
        AUREA.Log('denaro', 'avviso', g, ('versamento contante rilevante: %s'):format(U.Euro(importo)))
    end

    rispondi(true, ('Versati %s. Nuovo saldo: %s.'):format(U.Euro(importo), U.Euro(g.denaro.banca)))
end)

AUREA.Callback.Registra('banca:preleva', function(src, rispondi, euro, daSportello)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local importo = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end

    local commissione = 0
    if daSportello and importo > BANCA.Commissioni.prelievoGratuitoFinoA then
        commissione = math.floor((importo - BANCA.Commissioni.prelievoGratuitoFinoA) * BANCA.Commissioni.prelievoPercentuale)
    end

    if not g:Sottrai('banca', importo + commissione, 'prelievo') then
        return rispondi(false, commissione > 0
            and ('Servono %s (%s + commissione %s).'):format(U.Euro(importo + commissione), U.Euro(importo), U.Euro(commissione))
            or 'Saldo insufficiente.')
    end
    g:Aggiungi('contanti', importo, 'prelievo')

    if commissione > 0 then
        exports.ita_fisco:ErarioIncassa('commissioni_bancarie', commissione, g.citizenid)
    end

    rispondi(true, commissione > 0
        and ('Prelevati %s (commissione %s).'):format(U.Euro(importo), U.Euro(commissione))
        or ('Prelevati %s.'):format(U.Euro(importo)))
end)

-- Un solo bonifico per tutto il server: lo sportello, lo sportello ATM e
-- l'app Banca del telefono passano tutti di qui, così i massimali, le
-- commissioni e la segnalazione antiriciclaggio non possono divergere.
-- L'importo è già in CENTESIMI.
local function eseguiBonifico(g, ibanDestinatario, importo, causale, istantaneo)
    if not g then return false, 'Sessione non valida.' end

    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false, 'Importo non valido.' end
    if importo > BANCA.Commissioni.massimaleOperazione then
        return false, ('Il massimale per bonifico è %s.'):format(U.Euro(BANCA.Commissioni.massimaleOperazione))
    end

    local iban = tostring(ibanDestinatario or ''):upper():gsub('%s+', '')
    local destinazione = MySQL.single.await('SELECT * FROM conti WHERE iban = ?', { iban })
    if not destinazione then return false, 'IBAN non riconosciuto.' end
    if destinazione.intestatario == g.citizenid then return false, 'Non puoi bonificare a te stesso.' end
    if destinazione.bloccato == 1 then return false, 'Il conto di destinazione è bloccato.' end

    local commissione = istantaneo and BANCA.Commissioni.bonificoIstantaneo or BANCA.Commissioni.bonifico
    if not g:Sottrai('banca', importo + commissione, ('bonifico a %s'):format(iban)) then
        return false, ('Servono %s comprensivi di commissione.'):format(U.Euro(importo + commissione))
    end

    exports.ita_fisco:ErarioIncassa('commissioni_bancarie', commissione, g.citizenid)
    causale = tostring(causale or 'bonifico'):sub(1, 100)

    if destinazione.tipo == 'impresa' and destinazione.impresa_id then
        MySQL.update.await('UPDATE imprese SET cassa = cassa + ? WHERE id = ?', { importo, destinazione.impresa_id })
        MySQL.update.await('UPDATE conti SET saldo = saldo + ? WHERE iban = ?', { importo, iban })
        registraMovimento(iban, causale, importo, destinazione.saldo + importo, g:NomeCompleto(), 'bonifico')
    else
        AUREA.Denaro.AggiungiOffline(destinazione.intestatario, 'banca', importo, ('bonifico da %s'):format(g:NomeCompleto()))
        local ricevente = AUREA.GetPlayerByCitizenId(destinazione.intestatario)
        if ricevente then
            TriggerClientEvent('aurea:ui:notifica', ricevente.source, {
                tipo = 'successo', icona = '🏦', durata = 10000,
                titolo = 'Bonifico ricevuto',
                testo = ('%s da %s — %s'):format(U.Euro(importo), g:NomeCompleto(), causale),
            })
        end
    end

    if importo >= BANCA.Commissioni.sogliaAntiriciclaggio then
        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '💼', durata = 12000,
            titolo = 'Bonifico di importo rilevante',
            testo = ('%s → %s: %s (%s)'):format(g:NomeCompleto(), iban, U.Euro(importo), causale),
        }, true)
    end

    AUREA.Log('denaro', 'info', g, ('bonifico di %s a %s'):format(U.Euro(importo), iban))
    return true, ('Bonifico di %s eseguito. Commissione %s.'):format(U.Euro(importo), U.Euro(commissione))
end

AUREA.Callback.Registra('banca:bonifico', function(src, rispondi, ibanDestinatario, euro, causale, istantaneo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    local importo = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    return rispondi(eseguiBonifico(g, ibanDestinatario, importo, causale, istantaneo))
end)

-- Bonifico(citizenid, iban, centesimi, causale) -> ok, messaggio
-- Usato dall'app Banca del telefono: stessi controlli dello sportello.
exports('Bonifico', function(citizenid, iban, centesimi, causale)
    return eseguiBonifico(AUREA.GetPlayerByCitizenId(citizenid), iban, centesimi, causale, false)
end)

-- ---------------------------------------------------------------------------
--  Mutui e finanziamenti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('banca:richiediMutuo', function(src, rispondi, euro, rate, oggetto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local capitale = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    rate = math.floor(tonumber(rate) or 12)

    if capitale <= 0 or capitale > BANCA.Mutui.importoMassimo then
        return rispondi(false, ('Importo finanziabile fino a %s.'):format(U.Euro(BANCA.Mutui.importoMassimo)))
    end
    if rate < 3 or rate > BANCA.Mutui.rateMassime then
        return rispondi(false, ('Il piano va da 3 a %d rate.'):format(BANCA.Mutui.rateMassime))
    end

    local attivi = MySQL.scalar.await('SELECT COUNT(*) FROM mutui WHERE citizenid = ? AND stato = \'attivo\'', { g.citizenid }) or 0
    if attivi >= 2 then return rispondi(false, 'Hai già due finanziamenti in corso.') end

    local merito = meritoCreditizio(g.citizenid)
    if merito >= 5 then
        return rispondi(false, 'La tua posizione creditizia è compromessa: sana i debiti pendenti prima di richiedere un finanziamento.')
    end

    local tasso = BANCA.Mutui.tassoBase + BANCA.Merito[merito].maggiorazione
    local montante = math.floor(capitale * (1 + (tasso / 100) * (rate / 12)))
    local rata = math.ceil(montante / rate)

    -- sostenibilità: la rata non può superare una quota del reddito da lavoro
    local grado = AUREA.GetGrado(g.lavoro.nome, g.lavoro.grado)
    local redditoStimato = (grado.stipendio or 0) * 2   -- due cicli di paga per periodo rata
    if redditoStimato > 0 and rata > redditoStimato * BANCA.Mutui.incidenzaMassima then
        return rispondi(false, ('Rata di %s non sostenibile con il tuo reddito. Allunga il piano o riduci l\'importo.'):format(U.Euro(rata)))
    end

    MySQL.insert.await([[
        INSERT INTO mutui (citizenid, oggetto, capitale, residuo, tasso, rata, rate_totali, prossima_rata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { g.citizenid, tostring(oggetto or 'finanziamento'):sub(1, 80), capitale, montante, tasso, rata, rate,
          U.DataOraPiuOre(BANCA.Mutui.minutiPerRata / 60) })

    g:Aggiungi('banca', capitale, 'erogazione finanziamento')

    AUREA.Log('denaro', 'info', g, ('mutuo di %s in %d rate al %.2f%%'):format(U.Euro(capitale), rate, tasso))
    rispondi(true, ('Finanziamento erogato: %s. %d rate da %s al %.2f%%.'):format(
        U.Euro(capitale), rate, U.Euro(rata), tasso))
end)

AUREA.Callback.Registra('banca:estingui', function(src, rispondi, idMutuo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local m = MySQL.single.await('SELECT * FROM mutui WHERE id = ? AND citizenid = ? AND stato != \'estinto\'', { idMutuo, g.citizenid })
    if not m then return rispondi(false, 'Finanziamento non trovato.') end

    -- estinzione anticipata: si sconta il 20% degli interessi residui
    local interessiResidui = math.max(0, m.residuo - (m.capitale * (m.rate_totali - m.rate_pagate) / m.rate_totali))
    local dovuto = math.floor(m.residuo - interessiResidui * 0.20)

    if not g:Sottrai('banca', dovuto, 'estinzione anticipata finanziamento') then
        return rispondi(false, ('Servono %s sul conto.'):format(U.Euro(dovuto)))
    end

    MySQL.update.await('UPDATE mutui SET residuo = 0, stato = \'estinto\' WHERE id = ?', { idMutuo })
    rispondi(true, ('Finanziamento estinto per %s (sconto sugli interessi residui applicato).'):format(U.Euro(dovuto)))
end)

-- Addebito automatico delle rate
CreateThread(function()
    Wait(120000)
    while true do
        Wait(BANCA.Mutui.minutiPerRata * 60000)

        local scadute = MySQL.query.await([[
            SELECT * FROM mutui WHERE stato IN ('attivo','insoluto') AND prossima_rata <= NOW()
        ]]) or {}

        for _, m in ipairs(scadute) do
            local pagata = AUREA.Denaro.SottraiOffline(m.citizenid, 'banca', m.rata, 'rata finanziamento')
            local g = AUREA.GetPlayerByCitizenId(m.citizenid)

            if pagata then
                local ratePagate = m.rate_pagate + 1
                local residuo = math.max(0, m.residuo - m.rata)
                local estinto = ratePagate >= m.rate_totali or residuo <= 0

                MySQL.update.await([[
                    UPDATE mutui SET rate_pagate = ?, residuo = ?, stato = ?, prossima_rata = ? WHERE id = ?
                ]], { ratePagate, residuo, estinto and 'estinto' or 'attivo',
                      U.DataOraPiuOre(BANCA.Mutui.minutiPerRata / 60), m.id })

                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = estinto and 'successo' or 'info', icona = '🏦', durata = 8000,
                        titolo = estinto and 'Finanziamento estinto' or 'Rata addebitata',
                        testo = estinto and ('Hai saldato %s.'):format(m.oggetto)
                            or ('%s — rata %d di %d. Residuo %s.'):format(U.Euro(m.rata), ratePagate, m.rate_totali, U.Euro(residuo)),
                    })
                end
            else
                local insolute = (m.rate_pagate >= 0) and 1 or 0
                local nuovoStato = 'insoluto'

                -- conteggio delle insolvenze consecutive nei metadata dell'oggetto
                local consecutive = tonumber(m.oggetto:match('#(%d+)$') or '0') + 1
                if consecutive >= BANCA.Mutui.rateInsoluteMassime then
                    nuovoStato = 'pignorato'
                    -- il pignoramento aggredisce prima i contanti, poi i veicoli
                    AUREA.Denaro.SottraiOffline(m.citizenid, 'contanti', m.rata, 'pignoramento rata')
                    MySQL.update('UPDATE veicoli SET stato = \'sequestrato\', garage = \'depositeria\' WHERE citizenid = ? AND stato = \'garage\' LIMIT 1', { m.citizenid })
                end

                MySQL.update.await([[
                    UPDATE mutui SET stato = ?, prossima_rata = ?, oggetto = ? WHERE id = ?
                ]], { nuovoStato, U.DataOraPiuOre(BANCA.Mutui.minutiPerRata / 60),
                      (m.oggetto:gsub('%s*#%d+$', '')) .. ' #' .. consecutive, m.id })

                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'errore', icona = '⚠', durata = 13000,
                        titolo = nuovoStato == 'pignorato' and 'Pignoramento avviato' or 'Rata insoluta',
                        testo = nuovoStato == 'pignorato'
                            and 'Le rate non pagate hanno attivato il recupero coattivo: un tuo bene è stato aggredito.'
                            or ('Non è stato possibile addebitare %s. Ricarica il conto.'):format(U.Euro(m.rata)),
                    })
                end
            end
        end
    end
end)

exports('IBANDi', function(citizenid) return contoDi(citizenid).iban end)
exports('MeritoCreditizio', meritoCreditizio)
