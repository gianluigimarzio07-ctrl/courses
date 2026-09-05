--[[
    AUREA · Organizzazioni criminali (server)
]]

local U = AUREA.Util

Famiglie = {}

-- ---------------------------------------------------------------------------
--  Accesso
-- ---------------------------------------------------------------------------
function Famiglie.Get(tag)
    return MySQL.single.await('SELECT * FROM organizzazioni WHERE tag = ? AND attiva = 1', { tag })
end

function Famiglie.Di(giocatore)
    if not giocatore or giocatore.organizzazione.tag == 'nessuna' then return nil end
    return Famiglie.Get(giocatore.organizzazione.tag)
end

--- Alza il calore investigativo e produce le conseguenze previste.
function Famiglie.Calore(tag, delta, motivo)
    local org = Famiglie.Get(tag)
    if not org then return end

    local nuovo = U.Clamp(org.calore + delta, 0, 100)
    MySQL.update('UPDATE organizzazioni SET calore = ? WHERE id = ?', { nuovo, org.id })

    -- Superata la soglia di indagine si apre il fascicolo associativo
    if org.calore < FAM.Calore.sogliaIndagine and nuovo >= FAM.Calore.sogliaIndagine then
        local membri = MySQL.query.await('SELECT citizenid FROM personaggi WHERE organizzazione = ?', { tag }) or {}
        for _, m in ipairs(membri) do
            exports.ita_giustizia:ApriFascicolo(m.citizenid, '416b', 'DDA — indagine d\'ufficio',
                ('Appartenenza a %s'):format(org.nome))
        end

        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'errore', icona = '🕵', durata = 18000,
            titolo = 'Apertura di indagine associativa',
            testo = ('%s: livello di attenzione critico. Aperto fascicolo ex art. 416-bis c.p. su %d soggetti.'):format(
                org.nome, #membri),
        }, true)

        AUREA.Log('giustizia', 'allarme', nil, ('Indagine 416-bis aperta su %s (%d membri)'):format(org.nome, #membri))

    elseif org.calore < FAM.Calore.sogliaControlli and nuovo >= FAM.Calore.sogliaControlli then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'avviso', icona = '🕵', durata = 13000,
            titolo = 'Attenzione investigativa in aumento',
            testo = ('%s: segnalata intensificazione delle attività illecite.'):format(org.nome),
        }, true)
    end

    if delta > 0 then
        AUREA.Log('giustizia', 'debug', nil, ('%s: calore %d -> %d (%s)'):format(org.tag, org.calore, nuovo, motivo or 'n.d.'))
    end
end

exports('CaloreOrganizzazione', Famiglie.Calore)

--- Chi controlla un territorio, e con quanta presa. Serve a chi vuole sapere
--- se sta lavorando in casa propria: le piazze di spaccio rendono di più
--- dove l'organizzazione ha già il controllo.
---@return string|nil tag, integer controllo 0-100
function Famiglie.ControlloTerritorio(codice)
    local riga = MySQL.single.await([[
        SELECT o.tag, t.controllo
        FROM territori t JOIN organizzazioni o ON o.id = t.org_id
        WHERE t.codice = ? AND o.attiva = 1
    ]], { codice })
    if not riga then return nil, 0 end
    return riga.tag, tonumber(riga.controllo) or 0
end

exports('ControllaTerritorio', function(codice)
    return (Famiglie.ControlloTerritorio(codice))
end)

-- Raffreddamento periodico
CreateThread(function()
    while true do
        Wait(FAM.Calore.minutiRaffreddamento * 60000)
        MySQL.update('UPDATE organizzazioni SET calore = GREATEST(0, calore - ?) WHERE attiva = 1',
            { FAM.Calore.raffreddamento })
    end
end)

-- ---------------------------------------------------------------------------
--  Fondazione e organico
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:fonda', function(src, rispondi, tag, nome, tipo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if g.organizzazione.tag ~= 'nessuna' then return rispondi(false, 'Fai già parte di un\'organizzazione.') end

    tag = tostring(tag or ''):upper():gsub('[^A-Z0-9_]', ''):sub(1, 16)
    nome = tostring(nome or ''):gsub('[^%w%s\'àèéìòù-]', ''):sub(1, 60)
    if #tag < 3 or #nome < 3 then return rispondi(false, 'Sigla e nome devono avere almeno 3 caratteri.') end

    if Famiglie.Get(tag) then return rispondi(false, 'Sigla già in uso.') end

    if not g:Sottrai('contanti', FAM.Regole.costoFondazione, 'fondazione organizzazione') then
        return rispondi(false, ('Servono %s in contanti.'):format(U.Euro(FAM.Regole.costoFondazione)))
    end

    local tipiAmmessi = { famiglia = true, clan = true, cosca = true, banda = true, sindacato = true }
    tipo = tipiAmmessi[tipo] and tipo or 'famiglia'

    MySQL.insert.await('INSERT INTO organizzazioni (tag, nome, tipo, capo, cassa) VALUES (?, ?, ?, ?, ?)',
        { tag, nome, tipo, g.citizenid, 0 })

    g:ImpostaOrganizzazione(tag, 4)
    AUREA.Log('giustizia', 'avviso', g, ('ha fondato l\'organizzazione %s (%s)'):format(nome, tag))

    rispondi(true, ('%s costituita. Sei il capo.'):format(nome))
end)

AUREA.Callback.Registra('fam:recluta', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local bersaglio = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not bersaglio then return rispondi(false, 'Persona non trovata.') end

    local org = Famiglie.Di(g)
    if not org then return rispondi(false, 'Non fai parte di alcuna organizzazione.') end
    if not FAM.GradoHaPermesso(g.organizzazione.grado, 'recluta') then
        return rispondi(false, 'Il tuo grado non consente di affiliare.')
    end
    if bersaglio.organizzazione.tag ~= 'nessuna' then return rispondi(false, 'Il soggetto è già affiliato altrove.') end

    local membri = MySQL.scalar.await('SELECT COUNT(*) FROM personaggi WHERE organizzazione = ?', { org.tag }) or 0
    if membri >= FAM.Regole.membriMassimi then
        return rispondi(false, ('L\'organico massimo è di %d affiliati.'):format(FAM.Regole.membriMassimi))
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(bersaglio.source)))
    if d > 3.0 then return rispondi(false, 'Avvicinati alla persona.') end

    bersaglio:ImpostaOrganizzazione(org.tag, 0)
    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'avviso', icona = '🩸', durata = 12000,
        titolo = ('Affiliato a %s'):format(org.nome),
        testo = ('%s ti ha preso dentro come %s.'):format(g:NomeCompleto(), FAM.EtichettaGrado(0)),
    })

    rispondi(true, ('%s è stato affiliato.'):format(bersaglio:NomeCompleto()))
end)

AUREA.Callback.Registra('fam:grado', function(src, rispondi, citizenid, grado)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local org = Famiglie.Di(g)
    if not org or org.capo ~= g.citizenid then return rispondi(false, 'Solo il capo può assegnare i gradi.') end

    grado = math.floor(U.Clamp(tonumber(grado) or 0, 0, 4))
    if grado == 4 and citizenid ~= g.citizenid then
        return rispondi(false, 'Il grado di capo si trasmette solo cedendo l\'organizzazione.')
    end

    local bersaglio = AUREA.GetPlayerByCitizenId(citizenid)
    if bersaglio then
        bersaglio:ImpostaOrganizzazione(org.tag, grado)
        TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
            tipo = 'info', icona = '🩸', titolo = 'Grado aggiornato',
            testo = ('Ora sei %s.'):format(FAM.EtichettaGrado(grado)),
        })
    else
        MySQL.update('UPDATE personaggi SET org_grado = ? WHERE citizenid = ? AND organizzazione = ?',
            { grado, citizenid, org.tag })
    end

    rispondi(true, ('Grado aggiornato a %s.'):format(FAM.EtichettaGrado(grado)))
end)

AUREA.Callback.Registra('fam:situazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local org = Famiglie.Di(g)
    if not org then return rispondi(nil) end

    local membri = MySQL.query.await([[
        SELECT citizenid, nome, cognome, org_grado FROM personaggi WHERE organizzazione = ? ORDER BY org_grado DESC
    ]], { org.tag }) or {}
    for _, m in ipairs(membri) do
        m.gradoEtichetta = FAM.EtichettaGrado(m.org_grado)
        m.online = AUREA.GetPlayerByCitizenId(m.citizenid) ~= nil
    end

    local territori = MySQL.query.await([[
        SELECT codice, nome, controllo, rendita_oraria FROM territori WHERE org_id = ?
    ]], { org.id }) or {}

    local pizzo = MySQL.query.await([[
        SELECT p.percentuale, i.ragione_sociale, i.settore
        FROM pizzo p JOIN imprese i ON i.id = p.impresa_id
        WHERE p.org_id = ? AND p.attivo = 1
    ]], { org.id }) or {}

    rispondi({
        tag = org.tag, nome = org.nome, tipo = org.tipo,
        cassa = org.cassa, calore = org.calore, reputazione = org.reputazione,
        eCapo = org.capo == g.citizenid,
        mioGrado = g.organizzazione.grado,
        mioGradoEtichetta = FAM.EtichettaGrado(g.organizzazione.grado),
        membri = membri, territori = territori, pizzo = pizzo,
    })
end)

-- ---------------------------------------------------------------------------
--  Cassa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:cassa', function(src, rispondi, verso, euro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local org = Famiglie.Di(g)
    if not org then return rispondi(false, 'Non fai parte di alcuna organizzazione.') end

    local importo = U.ACentesimi(tonumber(tostring(euro):gsub(',', '.')) or 0)
    if importo <= 0 then return rispondi(false, 'Importo non valido.') end

    if verso == 'versa' then
        if not g:Sottrai('contanti', importo, ('versamento cassa %s'):format(org.tag)) then
            return rispondi(false, 'Non hai questi contanti.')
        end
        MySQL.update.await('UPDATE organizzazioni SET cassa = cassa + ? WHERE id = ?', { importo, org.id })
        return rispondi(true, ('Versati %s nella cassa comune.'):format(U.Euro(importo)))
    end

    if not FAM.GradoHaPermesso(g.organizzazione.grado, 'cassa_preleva') then
        return rispondi(false, 'Il tuo grado non consente prelievi dalla cassa.')
    end

    local massimo = math.floor(org.cassa * FAM.Regole.prelievoMassimo)
    if org.capo == g.citizenid then massimo = org.cassa end
    if importo > massimo then
        return rispondi(false, ('Puoi prelevare al massimo %s per volta.'):format(U.Euro(massimo)))
    end

    MySQL.update.await('UPDATE organizzazioni SET cassa = cassa - ? WHERE id = ?', { importo, org.id })
    g:Aggiungi('contanti', importo, ('prelievo cassa %s'):format(org.tag))
    AUREA.Log('denaro', 'avviso', g, ('prelievo di %s dalla cassa di %s'):format(U.Euro(importo), org.tag))

    rispondi(true, ('Prelevati %s.'):format(U.Euro(importo)))
end)

-- ---------------------------------------------------------------------------
--  Pizzo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:impostaPizzo', function(src, rispondi, bersaglioSrc, percentuale)
    local g = AUREA.GetPlayer(src)
    local titolare = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not titolare then return rispondi(false, 'Persona non trovata.') end

    local org = Famiglie.Di(g)
    if not org then return rispondi(false, 'Non fai parte di alcuna organizzazione.') end
    if not FAM.GradoHaPermesso(g.organizzazione.grado, 'pizzo') then
        return rispondi(false, 'Il tuo grado non consente di imporre il pizzo.')
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(titolare.source)))
    if d > 3.0 then return rispondi(false, 'Devi essere davanti al titolare.') end

    local impresa = MySQL.single.await('SELECT id, ragione_sociale FROM imprese WHERE titolare = ? AND attiva = 1 LIMIT 1',
        { titolare.citizenid })
    if not impresa then return rispondi(false, 'Questa persona non ha un\'impresa attiva.') end

    local giaImposto = MySQL.single.await('SELECT org_id FROM pizzo WHERE impresa_id = ? AND attivo = 1', { impresa.id })
    if giaImposto then
        return rispondi(false, giaImposto.org_id == org.id
            and 'L\'attività paga già a voi.'
            or 'L\'attività è già sotto un\'altra organizzazione.')
    end

    percentuale = math.floor(U.Clamp(tonumber(percentuale) or 10, FAM.Pizzo.percentualeMinima, FAM.Pizzo.percentualeMassima))

    MySQL.insert.await('INSERT INTO pizzo (impresa_id, org_id, percentuale) VALUES (?, ?, ?)',
        { impresa.id, org.id, percentuale })

    Famiglie.Calore(org.tag, FAM.Calore.perAttivita.pizzo_imposto, 'imposizione del pizzo')

    TriggerClientEvent('aurea:ui:notifica', titolare.source, {
        tipo = 'errore', icona = '🩸', durata = 16000,
        titolo = 'Richiesta estorsiva',
        testo = ('%s pretende il %d%% sugli incassi di %s. Puoi cedere o denunciare al 112.'):format(
            org.nome, percentuale, impresa.ragione_sociale),
    })

    AUREA.Log('giustizia', 'avviso', g, ('pizzo del %d%% imposto a %s'):format(percentuale, impresa.ragione_sociale))
    rispondi(true, ('%s paga il %d%% a %s.'):format(impresa.ragione_sociale, percentuale, org.nome))
end)

--- Il titolare denuncia: il pizzo cade e il calore schizza.
AUREA.Callback.Registra('fam:denunciaPizzo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local riga = MySQL.single.await([[
        SELECT p.id, p.org_id, o.tag, o.nome, i.ragione_sociale
        FROM pizzo p
        JOIN imprese i ON i.id = p.impresa_id
        JOIN organizzazioni o ON o.id = p.org_id
        WHERE i.titolare = ? AND p.attivo = 1
    ]], { g.citizenid })
    if not riga then return rispondi(false, 'Non risulti sottoposto ad alcuna estorsione.') end

    MySQL.update.await('UPDATE pizzo SET attivo = 0 WHERE id = ?', { riga.id })
    Famiglie.Calore(riga.tag, FAM.Pizzo.calorePerDenuncia, 'denuncia per estorsione')

    exports.ita_giustizia:ApriFascicolo(
        MySQL.scalar.await('SELECT capo FROM organizzazioni WHERE id = ?', { riga.org_id }),
        '629', 'denuncia della parte offesa', ('Estorsione ai danni di %s'):format(riga.ragione_sociale))

    exports.aurea_ui:NotificaLavoro('carabinieri', {
        tipo = 'errore', icona = '📋', durata = 16000,
        titolo = 'Denuncia per estorsione',
        testo = ('%s ha denunciato %s. Fascicolo aperto ex art. 629 c.p.'):format(g:NomeCompleto(), riga.nome),
    }, true)

    rispondi(true, ('Hai denunciato %s. Le forze dell\'ordine sono state allertate: preparati a ritorsioni.'):format(riga.nome))
end)

--- Prelievo automatico del pizzo sugli incassi delle imprese.
AddEventHandler('aurea:famiglie:incassoImpresa', function(impresaId, imponibile)
    local riga = MySQL.single.await([[
        SELECT p.percentuale, p.org_id, o.tag FROM pizzo p
        JOIN organizzazioni o ON o.id = p.org_id
        WHERE p.impresa_id = ? AND p.attivo = 1
    ]], { impresaId })
    if not riga then return end

    local quota = math.floor(imponibile * riga.percentuale / 100)
    if quota <= 0 then return end

    MySQL.update('UPDATE imprese SET cassa = cassa - ? WHERE id = ?', { quota, impresaId })
    MySQL.update('UPDATE organizzazioni SET cassa = cassa + ? WHERE id = ?', { quota, riga.org_id })
    Famiglie.Calore(riga.tag, FAM.Calore.perAttivita.pizzo_riscosso, 'riscossione del pizzo')

    local titolare = MySQL.scalar.await('SELECT titolare FROM imprese WHERE id = ?', { impresaId })
    local g = titolare and AUREA.GetPlayerByCitizenId(titolare)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'avviso', icona = '🩸', durata = 8000,
            titolo = 'Trattenuta sull\'incasso',
            testo = ('%s prelevati dalla cassa aziendale (%d%%).'):format(U.Euro(quota), riga.percentuale),
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Riciclaggio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fam:ricicla', function(src, rispondi, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local vicino = false
    for _, l in ipairs(FAM.Riciclaggio.lavanderie) do
        if #(coord - l.coord) < 5.0 then vicino = true break end
    end
    if not vicino then return rispondi(false, 'Non sei in un esercizio adatto.') end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 0, 1, FAM.Riciclaggio.massimoOperazione))

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha('contanti_sporchi', quantita) then
        return rispondi(false, 'Non hai abbastanza contanti non tracciati.')
    end

    -- Un'impresa propria abbassa la commissione: si giustifica l'incasso
    local haImpresa = MySQL.scalar.await('SELECT id FROM imprese WHERE titolare = ? AND attiva = 1 LIMIT 1', { g.citizenid })
    local commissione = haImpresa and FAM.Riciclaggio.commissioneConImpresa or FAM.Riciclaggio.commissione

    -- Ogni unità di contante sporco vale 100 € nominali
    local nominale = quantita * 10000
    local netto = math.floor(nominale * (1 - commissione))

    inventario:Rimuovi('contanti_sporchi', quantita)
    g:Aggiungi('contanti', netto, 'proventi ripuliti')
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local org = Famiglie.Di(g)
    if org then Famiglie.Calore(org.tag, FAM.Riciclaggio.calore, 'riciclaggio') end

    -- Operazioni grosse finiscono sotto la lente della Guardia di Finanza
    if nominale >= 2000000 then
        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '💼', durata = 13000,
            titolo = 'Movimentazione anomala di contante',
            testo = ('Rilevata un\'operazione sospetta riconducibile a %s.'):format(g:NomeCompleto()),
        }, true)
    end

    AUREA.Log('denaro', 'avviso', g, ('riciclaggio di %s, netto %s'):format(U.Euro(nominale), U.Euro(netto)))
    rispondi(true, ('%s ripuliti su %s nominali (commissione %d%%).'):format(
        U.Euro(netto), U.Euro(nominale), math.floor(commissione * 100)))
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('org', 'utente', 'Apre il pannello dell\'organizzazione', {}, function(src)
    TriggerClientEvent('fam:apriPannello', src)
end)
