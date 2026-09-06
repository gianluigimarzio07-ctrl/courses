--[[
    AUREA · Gestione dell'ente (server)

    Ogni verifica di permesso si fa qui sull'oggetto Giocatore, non sul
    grado che il client dichiara. E ogni movimento di cassa lascia una
    riga: un fondo comune senza registro è un fondo che sparisce.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Cassa
-- ---------------------------------------------------------------------------
local function saldo(lavoro)
    return MySQL.scalar.await('SELECT cassa FROM enti WHERE lavoro = ? LIMIT 1', { lavoro }) or 0
end

local function movimento(lavoro, delta, causale, autore)
    MySQL.query.await([[
        INSERT INTO enti (lavoro, cassa) VALUES (?, 0)
        ON DUPLICATE KEY UPDATE lavoro = lavoro
    ]], { lavoro })

    if delta < 0 and saldo(lavoro) + delta < 0 then return false, saldo(lavoro) end

    MySQL.update('UPDATE enti SET cassa = cassa + ? WHERE lavoro = ?', { delta, lavoro })
    MySQL.insert('INSERT INTO enti_movimenti (lavoro, importo, causale, autore) VALUES (?, ?, ?, ?)',
        { lavoro, delta, causale, autore })

    return true, saldo(lavoro)
end

--- Le altre risorse versano quote nella cassa dell'ente: la percentuale
--- dell'officina sulle riparazioni, la quota del soccorso, i premi.
exports('VersaInCassa', function(lavoro, importo, causale)
    if not AUREA.Lavori[lavoro] or (tonumber(importo) or 0) <= 0 then return false end
    return (movimento(lavoro, math.floor(importo), causale or 'versamento', 'sistema'))
end)

exports('SaldoCassa', saldo)

-- ---------------------------------------------------------------------------
--  Chi comanda
-- ---------------------------------------------------------------------------
local function responsabile(src, permesso)
    local g = AUREA.GetPlayer(src)
    if not g then return nil, 'Sessione non valida.' end

    local ufficio = AZI.UfficioVicino(GetEntityCoords(GetPlayerPed(src)))
    if not ufficio then return nil, 'Devi essere nell\'ufficio dell\'ente.' end
    if ufficio.lavoro ~= g.lavoro.nome then return nil, 'Questo non è il tuo ente.' end
    if not g:HaPermessoLavoro(permesso) then
        return nil, 'Il tuo grado non prevede questa facoltà.'
    end

    return g, ufficio
end

-- ---------------------------------------------------------------------------
--  Organico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('azi:organico', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local ufficio = AZI.UfficioVicino(GetEntityCoords(GetPlayerPed(src)))
    if not ufficio or ufficio.lavoro ~= g.lavoro.nome then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT citizenid, nome, cognome, lavoro_grado, lavoro_servizio
        FROM personaggi
        WHERE lavoro = ? AND eliminato = 0 AND attivo = 1
        ORDER BY lavoro_grado DESC, cognome ASC
    ]], { ufficio.lavoro })

    local presenze = MySQL.query.await([[
        SELECT citizenid, SUM(minuti) AS minuti
        FROM enti_presenze WHERE lavoro = ? GROUP BY citizenid
    ]], { ufficio.lavoro })

    local ore = {}
    for _, p in ipairs(presenze or {}) do ore[p.citizenid] = tonumber(p.minuti) or 0 end

    local dati = AUREA.Lavori[ufficio.lavoro]
    local out = {}

    for _, r in ipairs(righe or {}) do
        local grado = dati and dati.gradi[r.lavoro_grado]
        local presente = AUREA.GetPlayerByCitizenId(r.citizenid)
        out[#out + 1] = {
            citizenid = r.citizenid,
            nome = ('%s %s'):format(r.nome, r.cognome),
            grado = r.lavoro_grado,
            etichettaGrado = grado and grado.etichetta or ('grado %d'):format(r.lavoro_grado),
            stipendio = grado and grado.stipendio or 0,
            inServizio = r.lavoro_servizio == 1,
            connesso = presente ~= nil,
            source = presente and presente.source or nil,
            minutiPresenza = ore[r.citizenid] or 0,
        }
    end

    rispondi(out, saldo(ufficio.lavoro), g.lavoro.grado, AZI.Gradi(ufficio.lavoro))
end)

-- ---------------------------------------------------------------------------
--  Assunzione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('azi:assumi', function(src, rispondi, bersaglioSrc)
    local g, motivo = responsabile(src, AZI.Regole.permessoAssunzione)
    if not g then return rispondi(false, motivo) end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b then return rispondi(false, 'La persona da assumere deve essere davanti a te.') end
    if b.citizenid == g.citizenid then return rispondi(false, 'Non puoi assumere te stesso.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 4.0 then
        return rispondi(false, 'La persona deve essere in ufficio con te.')
    end

    if b.lavoro.nome == g.lavoro.nome then
        return rispondi(false, 'Fa già parte dell\'organico.')
    end

    local contributo = AZI.Regole.contributoAssunzione
    local ok, restante = movimento(g.lavoro.nome, -contributo,
        ('assunzione di %s'):format(b:NomeCompleto()), g:NomeCompleto())

    if not ok then
        return rispondi(false, ('La cassa dell\'ente non copre il contributo di attivazione (%s). Saldo: %s.')
            :format(U.Euro(contributo), U.Euro(restante)))
    end

    TriggerEvent('aurea:fisco:incasso', 'contributi_lavoro', contributo, b.citizenid)

    b:ImpostaLavoro(g.lavoro.nome, AZI.Regole.gradoIniziale)

    local dati = AUREA.Lavori[g.lavoro.nome]
    local grado = dati.gradi[AZI.Regole.gradoIniziale]

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'successo', icona = '📄', durata = 16000,
        titolo = 'Assunzione',
        testo = ('%s ti ha assunto presso %s come %s. Stipendio %s per ciclo.')
            :format(g:NomeCompleto(), dati.etichetta, grado.etichetta, U.Euro(grado.stipendio)),
    })

    AUREA.Log('lavoro', 'info', g, ('ha assunto %s in %s'):format(b:NomeCompleto(), g.lavoro.nome))
    rispondi(true, ('%s assunto come %s. Contributo di attivazione %s a carico della cassa.')
        :format(b:NomeCompleto(), grado.etichetta, U.Euro(contributo)))
end)

-- ---------------------------------------------------------------------------
--  Grado
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('azi:grado', function(src, rispondi, citizenid, nuovoGrado)
    local g, motivo = responsabile(src, AZI.Regole.permessoAssunzione)
    if not g then return rispondi(false, motivo) end

    nuovoGrado = math.floor(tonumber(nuovoGrado) or 0)

    local dati = AUREA.Lavori[g.lavoro.nome]
    if not dati.gradi[nuovoGrado] then return rispondi(false, 'Grado inesistente.') end

    local massimo = g.lavoro.grado + AZI.Regole.gradoMassimoConcedibile
    if nuovoGrado > massimo then
        return rispondi(false, ('Non puoi conferire un grado pari o superiore al tuo: il massimo è %s.')
            :format(dati.gradi[massimo] and dati.gradi[massimo].etichetta or ('grado %d'):format(massimo)))
    end

    local riga = MySQL.single.await(
        'SELECT nome, cognome, lavoro, lavoro_grado FROM personaggi WHERE citizenid = ? LIMIT 1', { citizenid })
    if not riga or riga.lavoro ~= g.lavoro.nome then return rispondi(false, 'Non è nel tuo organico.') end
    if riga.lavoro_grado >= g.lavoro.grado then
        return rispondi(false, 'Non puoi toccare il grado di chi è al tuo livello o sopra.')
    end
    if riga.lavoro_grado == nuovoGrado then return rispondi(false, 'Ha già quel grado.') end

    local salita = nuovoGrado > riga.lavoro_grado
    local b = AUREA.GetPlayerByCitizenId(citizenid)

    if b then
        b:ImpostaLavoro(g.lavoro.nome, nuovoGrado)
    else
        MySQL.update('UPDATE personaggi SET lavoro_grado = ? WHERE citizenid = ?', { nuovoGrado, citizenid })
    end

    local grado = dati.gradi[nuovoGrado]

    if b then
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = salita and 'successo' or 'avviso', icona = salita and '⬆' or '⬇', durata = 15000,
            titolo = salita and 'Promozione' or 'Retrocessione',
            testo = ('%s ti ha inquadrato come %s. Stipendio %s per ciclo.')
                :format(g:NomeCompleto(), grado.etichetta, U.Euro(grado.stipendio)),
        })
    end

    AUREA.Log('lavoro', 'info', g, ('ha portato %s %s a %s')
        :format(riga.nome, riga.cognome, grado.etichetta))

    rispondi(true, ('%s %s è ora %s.'):format(riga.nome, riga.cognome, grado.etichetta))
end)

-- ---------------------------------------------------------------------------
--  Licenziamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('azi:licenzia', function(src, rispondi, citizenid)
    local g, motivo = responsabile(src, AZI.Regole.permessoLicenziamento)
    if not g then return rispondi(false, motivo) end
    if citizenid == g.citizenid then return rispondi(false, 'Se vuoi andartene, dai le dimissioni.') end

    local riga = MySQL.single.await(
        'SELECT nome, cognome, lavoro, lavoro_grado, lavoro_servizio FROM personaggi WHERE citizenid = ? LIMIT 1',
        { citizenid })
    if not riga or riga.lavoro ~= g.lavoro.nome then return rispondi(false, 'Non è nel tuo organico.') end
    if riga.lavoro_grado >= g.lavoro.grado then
        return rispondi(false, 'Non puoi licenziare chi è al tuo livello o sopra.')
    end
    if AZI.Regole.vietaLicenziamentoInServizio and riga.lavoro_servizio == 1 then
        return rispondi(false, 'È in servizio: deve smontare prima che tu possa chiudere il rapporto.')
    end

    local b = AUREA.GetPlayerByCitizenId(citizenid)
    if b then
        b:ImpostaLavoro(AZI.Regole.lavoroDiRicaduta, 0)
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = 'errore', icona = '📄', durata = 16000,
            titolo = 'Licenziamento',
            testo = ('%s ha chiuso il tuo rapporto di lavoro presso %s.')
                :format(g:NomeCompleto(), AUREA.Lavori[g.lavoro.nome].etichetta),
        })
    else
        MySQL.update('UPDATE personaggi SET lavoro = ?, lavoro_grado = 0, lavoro_servizio = 0 WHERE citizenid = ?',
            { AZI.Regole.lavoroDiRicaduta, citizenid })
    end

    MySQL.update('DELETE FROM enti_presenze WHERE lavoro = ? AND citizenid = ?', { g.lavoro.nome, citizenid })

    AUREA.Log('lavoro', 'avviso', g, ('ha licenziato %s %s'):format(riga.nome, riga.cognome))
    rispondi(true, ('%s %s non fa più parte dell\'organico.'):format(riga.nome, riga.cognome))
end)

-- ---------------------------------------------------------------------------
--  Cassa: versamenti, prelievi, premi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('azi:cassa', function(src, rispondi, verso, importo)
    local g, motivo = responsabile(src, AZI.Regole.permessoCassa)
    if not g then return rispondi(false, motivo) end

    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end

    if verso == 'versa' then
        if not g:SottraiOvunque(importo, 'versamento in cassa dell\'ente') then
            return rispondi(false, 'Non hai la somma.')
        end
        local _, nuovo = movimento(g.lavoro.nome, importo, 'versamento del responsabile', g:NomeCompleto())
        return rispondi(true, ('Versati %s. Saldo di cassa: %s.'):format(U.Euro(importo), U.Euro(nuovo)))
    end

    if verso == 'preleva' then
        if importo > AZI.Cassa.prelievoMassimo then
            return rispondi(false, ('Il prelievo massimo per operazione è %s.'):format(U.Euro(AZI.Cassa.prelievoMassimo)))
        end
        local ok, nuovo = movimento(g.lavoro.nome, -importo, 'prelievo del responsabile', g:NomeCompleto())
        if not ok then return rispondi(false, ('In cassa ci sono %s.'):format(U.Euro(nuovo))) end

        g:Aggiungi('banca', importo, 'prelievo dalla cassa dell\'ente')
        return rispondi(true, ('Prelevati %s. Saldo di cassa: %s.'):format(U.Euro(importo), U.Euro(nuovo)))
    end

    rispondi(false, 'Operazione sconosciuta.')
end)

AUREA.Callback.Registra('azi:premio', function(src, rispondi, citizenid, importo)
    local g, motivo = responsabile(src, AZI.Regole.permessoCassa)
    if not g then return rispondi(false, motivo) end

    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 or importo > AZI.Cassa.premioMassimo then
        return rispondi(false, ('Il premio ammesso va da 1 centesimo a %s.'):format(U.Euro(AZI.Cassa.premioMassimo)))
    end

    local riga = MySQL.single.await(
        'SELECT nome, cognome, lavoro FROM personaggi WHERE citizenid = ? LIMIT 1', { citizenid })
    if not riga or riga.lavoro ~= g.lavoro.nome then return rispondi(false, 'Non è nel tuo organico.') end

    local ok, nuovo = movimento(g.lavoro.nome, -importo,
        ('premio a %s %s'):format(riga.nome, riga.cognome), g:NomeCompleto())
    if not ok then return rispondi(false, ('In cassa ci sono %s.'):format(U.Euro(nuovo))) end

    AUREA.Denaro.AggiungiOffline(citizenid, 'banca', importo, 'premio di produttività')
    TriggerEvent('aurea:fisco:erogazione', 'premi_ente', importo, citizenid)

    local b = AUREA.GetPlayerByCitizenId(citizenid)
    if b then
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = 'successo', icona = '💶', durata = 14000,
            titolo = 'Premio', testo = ('%s ti ha riconosciuto %s.'):format(g:NomeCompleto(), U.Euro(importo)),
        })
    end

    rispondi(true, ('%s riconosciuti a %s %s. Saldo di cassa: %s.')
        :format(U.Euro(importo), riga.nome, riga.cognome, U.Euro(nuovo)))
end)

AUREA.Callback.Registra('azi:movimenti', function(src, rispondi)
    local g, motivo = responsabile(src, AZI.Regole.permessoCassa)
    if not g then return rispondi({}, motivo) end

    local righe = MySQL.query.await([[
        SELECT importo, causale, autore, momento
        FROM enti_movimenti WHERE lavoro = ?
        ORDER BY id DESC LIMIT 30
    ]], { g.lavoro.nome })

    rispondi(righe or {})
end)

-- ---------------------------------------------------------------------------
--  Registro presenze
--
--  Ogni minuto passato in servizio si accumula. Serve al responsabile per
--  sapere chi lavora davvero e chi timbra e sparisce.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(60000)

        local perLavoro = {}
        for _, g in ipairs(AUREA.GetGiocatori()) do
            if g.lavoro.servizio and g.lavoro.nome ~= 'disoccupato' then
                perLavoro[g.lavoro.nome] = perLavoro[g.lavoro.nome] or {}
                table.insert(perLavoro[g.lavoro.nome], g.citizenid)
            end
        end

        for lavoro, elenco in pairs(perLavoro) do
            for _, citizenid in ipairs(elenco) do
                MySQL.query([[
                    INSERT INTO enti_presenze (lavoro, citizenid, minuti, giorno)
                    VALUES (?, ?, 1, CURDATE())
                    ON DUPLICATE KEY UPDATE minuti = minuti + 1
                ]], { lavoro, citizenid })
            end
        end
    end
end)
