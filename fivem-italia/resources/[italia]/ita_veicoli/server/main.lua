--[[
    AUREA · Veicoli (server)
    Immatricolazione, compravendita, bollo, RCA, revisione, sequestro.
]]

local U = AUREA.Util

Veicoli = {}

-- ---------------------------------------------------------------------------
--  Immatricolazione
-- ---------------------------------------------------------------------------

--- Registra un nuovo veicolo intestato a un personaggio.
---@return string|nil targa
function Veicoli.Immatricola(citizenid, modello, opzioni)
    opzioni = opzioni or {}
    local catalogo = VEI.GetVeicoloCatalogo(modello)
    local targa = AUREA.Anagrafe.NuovaTarga()

    MySQL.insert.await([[
        INSERT INTO veicoli
            (targa, citizenid, modello, hash, categoria, proprieta, garage, stato,
             bollo_scadenza, assicurazione_tipo, assicurazione_scadenza,
             revisione_scadenza, classe_ambientale)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'garage', ?, ?, ?, ?, ?)
    ]], {
        targa, citizenid, modello, GetHashKey(modello),
        opzioni.categoria or (catalogo and catalogo.categoria) or 'auto',
        opzioni.proprieta and json.encode(opzioni.proprieta) or nil,
        opzioni.garage or 'centrale',
        -- Il bollo del primo anno è compreso nel prezzo di acquisto
        U.DataPiuGiorni(VEI.Bollo.validitaGiorni),
        opzioni.assicurazione or 'nessuna',
        opzioni.assicurazione and U.DataPiuGiorni(VEI.Assicurazione.validitaGiorni) or nil,
        U.DataPiuGiorni(VEI.Revisione.primaRevisioneGiorni),
        (catalogo and catalogo.classe) or 'Euro 5',
    })

    -- Libretto di circolazione nell'inventario
    TriggerEvent('aurea:inventario:aggiungi', citizenid, 'libretto', 1, {
        targa = targa,
        modello = catalogo and catalogo.nome or modello,
        kw = catalogo and catalogo.kw or 0,
        classe = catalogo and catalogo.classe or 'Euro 5',
    })

    AUREA.Log('veicoli', 'info', nil, ('Immatricolato %s (%s) a %s'):format(targa, modello, citizenid))
    return targa
end

exports('Immatricola', Veicoli.Immatricola)

--- Dati completi di un veicolo, con stato di bollo/RCA/revisione già valutato.
function Veicoli.Get(targa)
    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ?', { targa })
    if not v then return nil end

    local adesso = os.time()
    local function scaduta(campo)
        if not v[campo] then return true end
        return (v[campo] / 1000) < adesso
    end

    v.bolloScaduto = scaduta('bollo_scadenza')
    v.revisioneScaduta = scaduta('revisione_scadenza')
    v.assicurato = v.assicurazione_tipo ~= 'nessuna' and not scaduta('assicurazione_scadenza')
    v.regolare = not v.bolloScaduto and not v.revisioneScaduta and v.assicurato

    return v
end

exports('GetVeicolo', Veicoli.Get)

-- ---------------------------------------------------------------------------
--  Callback: parco veicoli del giocatore
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vei:mieiVeicoli', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT targa, modello, categoria, garage, stato, km, carburante,
               bollo_scadenza, assicurazione_tipo, assicurazione_scadenza,
               revisione_scadenza, classe_ambientale
        FROM veicoli WHERE citizenid = ? ORDER BY acquistato_il DESC
    ]], { g.citizenid }) or {}

    local adesso = os.time()
    for _, v in ipairs(righe) do
        local catalogo = VEI.GetVeicoloCatalogo(v.modello)
        v.nome = catalogo and catalogo.nome or v.modello
        v.kw = catalogo and catalogo.kw or 100
        v.bolloScaduto = not v.bollo_scadenza or (v.bollo_scadenza / 1000) < adesso
        v.revisioneScaduta = not v.revisione_scadenza or (v.revisione_scadenza / 1000) < adesso
        v.assicurato = v.assicurazione_tipo ~= 'nessuna'
            and v.assicurazione_scadenza and (v.assicurazione_scadenza / 1000) >= adesso
        v.bolloData = v.bollo_scadenza and U.DataIT(math.floor(v.bollo_scadenza / 1000)) or '—'
        v.revisioneData = v.revisione_scadenza and U.DataIT(math.floor(v.revisione_scadenza / 1000)) or '—'
        v.rcaData = v.assicurazione_scadenza and U.DataIT(math.floor(v.assicurazione_scadenza / 1000)) or '—'
        v.costoBollo = VEI.CalcolaBollo(v.kw, v.classe_ambientale)
    end

    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Concessionaria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vei:catalogo', function(src, rispondi, idConcessionaria)
    local concessionaria
    for _, c in ipairs(VEI.Concessionarie) do
        if c.id == idConcessionaria then concessionaria = c break end
    end
    if not concessionaria then return rispondi({}) end

    local out = {}
    for _, v in ipairs(VEI.Catalogo) do
        if U.Contiene(concessionaria.categorie, v.categoria) then
            out[#out + 1] = {
                modello = v.modello, nome = v.nome, categoria = v.categoria,
                prezzo = v.prezzo, kw = v.kw, classe = v.classe,
                -- IPT (imposta provinciale di trascrizione) e messa su strada
                ipt = math.floor(v.prezzo * 0.03),
                bolloPrimoAnno = VEI.CalcolaBollo(v.kw, v.classe),
            }
        end
    end
    rispondi(out)
end)

AUREA.Callback.Registra('vei:acquista', function(src, rispondi, modello, conAssicurazione)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local catalogo = VEI.GetVeicoloCatalogo(modello)
    if not catalogo then return rispondi(false, 'Modello non disponibile.') end

    -- Serve la patente della categoria corretta
    local categoriaRichiesta = (catalogo.categoria == 'moto') and 'A'
        or (catalogo.categoria == 'camion') and 'C' or 'B'
    if not exports.ita_codicestrada:PatenteHaCategoria(g.citizenid, categoriaRichiesta) then
        return rispondi(false, ('Serve la patente di categoria %s per immatricolare questo veicolo.'):format(categoriaRichiesta))
    end

    local ipt = math.floor(catalogo.prezzo * 0.03)
    local premio = conAssicurazione
        and VEI.CalcolaPremio('rca', catalogo.kw, VEI.Assicurazione.classeIngresso) or 0
    local totale = catalogo.prezzo + ipt + premio

    if not g:SottraiOvunque(totale, ('acquisto %s'):format(catalogo.nome)) then
        return rispondi(false, ('Servono %s (veicolo %s + IPT %s%s).'):format(
            U.Euro(totale), U.Euro(catalogo.prezzo), U.Euro(ipt),
            premio > 0 and (' + RCA ' .. U.Euro(premio)) or ''))
    end

    local targa = Veicoli.Immatricola(g.citizenid, modello, {
        categoria = catalogo.categoria,
        assicurazione = conAssicurazione and 'rca' or nil,
    })

    -- IPT e IVA vanno all'erario
    TriggerEvent('aurea:fisco:incasso', 'ipt', ipt, g.citizenid)

    rispondi(true, ('Immatricolato con targa %s. Lo trovi nel garage centrale.'):format(targa), targa)
end)

-- ---------------------------------------------------------------------------
--  Bollo, RCA, revisione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vei:pagaBollo', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local v = Veicoli.Get(targa)
    if not v or v.citizenid ~= g.citizenid then return rispondi(false, 'Veicolo non intestato a te.') end

    local catalogo = VEI.GetVeicoloCatalogo(v.modello)
    local importo = VEI.CalcolaBollo(catalogo and catalogo.kw or 100, v.classe_ambientale)

    -- Mora se il bollo era già scaduto
    if v.bolloScaduto then
        importo = math.floor(importo * (1 + VEI.Bollo.moraPercentuale))
    end

    if importo > 0 and not g:SottraiOvunque(importo, ('bollo auto %s'):format(targa)) then
        return rispondi(false, ('Servono %s.'):format(U.Euro(importo)))
    end

    -- Se non era scaduto, il nuovo bollo parte dalla scadenza precedente
    local base = (not v.bolloScaduto and v.bollo_scadenza) and math.floor(v.bollo_scadenza / 1000) or os.time()
    MySQL.update.await('UPDATE veicoli SET bollo_scadenza = ? WHERE targa = ?',
        { U.DataPiuGiorni(VEI.Bollo.validitaGiorni, base), targa })

    TriggerEvent('aurea:fisco:incasso', 'bollo_auto', importo, g.citizenid)
    rispondi(true, importo > 0
        and ('Bollo pagato: %s. Valido fino al %s.'):format(U.Euro(importo), U.DataIT(base + VEI.Bollo.validitaGiorni * 86400))
        or 'Veicolo elettrico: esente dal bollo.')
end)

AUREA.Callback.Registra('vei:assicura', function(src, rispondi, targa, tipo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not VEI.Assicurazione.tipi[tipo] then return rispondi(false, 'Polizza non disponibile.') end

    local v = Veicoli.Get(targa)
    if not v or v.citizenid ~= g.citizenid then return rispondi(false, 'Veicolo non intestato a te.') end

    local catalogo = VEI.GetVeicoloCatalogo(v.modello)
    local proprieta = v.proprieta and json.decode(v.proprieta) or {}
    local classeMerito = proprieta.classeMerito or VEI.Assicurazione.classeIngresso
    local premio = VEI.CalcolaPremio(tipo, catalogo and catalogo.kw or 100, classeMerito)

    if not g:SottraiOvunque(premio, ('polizza %s %s'):format(tipo, targa)) then
        return rispondi(false, ('Il premio è di %s (classe di merito %d).'):format(U.Euro(premio), classeMerito))
    end

    MySQL.update.await('UPDATE veicoli SET assicurazione_tipo = ?, assicurazione_scadenza = ? WHERE targa = ?',
        { tipo, U.DataPiuGiorni(VEI.Assicurazione.validitaGiorni), targa })

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'assicurazione', 1, {
        targa = targa, tipo = VEI.Assicurazione.tipi[tipo].etichetta,
        scadenza = U.DataIT(os.time() + VEI.Assicurazione.validitaGiorni * 86400),
        classe = classeMerito,
    })

    rispondi(true, ('%s attivata per %s. Premio %s, classe di merito %d.'):format(
        VEI.Assicurazione.tipi[tipo].etichetta, targa, U.Euro(premio), classeMerito))
end)

AUREA.Callback.Registra('vei:revisione', function(src, rispondi, targa, motore, carrozzeria)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local v = Veicoli.Get(targa)
    if not v or v.citizenid ~= g.citizenid then return rispondi(false, 'Veicolo non intestato a te.') end

    if not g:SottraiOvunque(VEI.Revisione.costo, ('revisione %s'):format(targa)) then
        return rispondi(false, ('La revisione costa %s.'):format(U.Euro(VEI.Revisione.costo)))
    end

    motore = tonumber(motore) or v.motore
    carrozzeria = tonumber(carrozzeria) or v.carrozzeria

    if motore < VEI.Revisione.sogliaMotore or carrozzeria < VEI.Revisione.sogliaCarrozzeria then
        return rispondi(false, 'Revisione non superata: il veicolo va prima riparato in officina. La quota non è rimborsabile.')
    end

    MySQL.update.await('UPDATE veicoli SET revisione_scadenza = ? WHERE targa = ?',
        { U.DataPiuGiorni(VEI.Revisione.intervalloGiorni), targa })

    TriggerEvent('aurea:fisco:incasso', 'revisione', VEI.Revisione.costo, g.citizenid)
    rispondi(true, ('Revisione superata. Prossima scadenza: %s.'):format(
        U.DataIT(os.time() + VEI.Revisione.intervalloGiorni * 86400)))
end)

-- ---------------------------------------------------------------------------
--  Sequestro e dissequestro
-- ---------------------------------------------------------------------------

--- Un agente sequestra un veicolo: sparisce dalla circolazione e va in depositeria.
function Veicoli.Sequestra(targa, motivo, agente)
    MySQL.update.await('UPDATE veicoli SET stato = \'sequestrato\', garage = ? WHERE targa = ?',
        { 'depositeria', targa })

    local proprietario = MySQL.scalar.await('SELECT citizenid FROM veicoli WHERE targa = ?', { targa })
    if proprietario then
        local g = AUREA.GetPlayerByCitizenId(proprietario)
        if g then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🚔', durata = 13000,
                titolo = 'Veicolo sequestrato',
                testo = ('%s — %s. Ritiro presso la Depositeria Giudiziaria.'):format(targa, motivo or 'provvedimento'),
            })
        end
    end

    AUREA.Log('veicoli', 'avviso', nil, ('Sequestro di %s (%s) da %s'):format(targa, motivo or 'n.d.', agente or 'sistema'))
end

exports('SequestraVeicolo', Veicoli.Sequestra)

AUREA.Callback.Registra('vei:sequestrati', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT targa, modello, TIMESTAMPDIFF(DAY, acquistato_il, NOW()) AS giorni
        FROM veicoli WHERE citizenid = ? AND stato = 'sequestrato'
    ]], { g.citizenid }) or {}

    for _, v in ipairs(righe) do
        local catalogo = VEI.GetVeicoloCatalogo(v.modello)
        v.nome = catalogo and catalogo.nome or v.modello
        -- custodia calcolata su un massimo di 30 giorni
        v.costo = VEI.Depositeria.dissequestroBase
            + math.min(30, math.max(1, v.giorni or 1)) * VEI.Depositeria.custodiaGiornaliera
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('vei:dissequestra', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local v = MySQL.single.await('SELECT * FROM veicoli WHERE targa = ? AND citizenid = ? AND stato = \'sequestrato\'',
        { targa, g.citizenid })
    if not v then return rispondi(false, 'Veicolo non in depositeria.') end

    -- Il dissequestro richiede la posizione regolare: niente verbali aperti
    local dovuto = exports.ita_codicestrada:TotaleVerbali(g.citizenid)
    if dovuto > 0 then
        return rispondi(false, ('Prima devi saldare i verbali aperti: %s.'):format(U.Euro(dovuto)))
    end

    local costo = VEI.Depositeria.dissequestroBase + VEI.Depositeria.custodiaGiornaliera
    if not g:SottraiOvunque(costo, ('dissequestro %s'):format(targa)) then
        return rispondi(false, ('Servono %s per il dissequestro e la custodia.'):format(U.Euro(costo)))
    end

    MySQL.update.await('UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ?', { targa })
    TriggerEvent('aurea:fisco:incasso', 'depositeria', costo, g.citizenid)
    rispondi(true, ('Veicolo dissequestrato per %s. Lo trovi nel garage centrale.'):format(U.Euro(costo)))
end)

-- ---------------------------------------------------------------------------
--  Controllo documenti da parte di un agente
-- ---------------------------------------------------------------------------
AUREA.Comando('controllo', 'utente', 'Verifica documenti e regolarità di un veicolo', {
    { name = 'targa', help = 'Targa da controllare' },
}, function(src, args, _, g)
    if not g or not g:HaPermessoLavoro('mdt') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato alle forze dell\'ordine.' })
    end

    local targa = (args[1] or ''):upper():gsub('%s+', '')
    local v = Veicoli.Get(targa)
    if not v then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'avviso', titolo = 'Targa non trovata', testo = ('%s non risulta immatricolata. Possibile targa clonata.'):format(targa) })
    end

    local intestatario = MySQL.single.await('SELECT nome, cognome, codice_fiscale FROM personaggi WHERE citizenid = ?', { v.citizenid })
    local problemi = {}
    if v.bolloScaduto then problemi[#problemi + 1] = 'bollo scaduto' end
    if v.revisioneScaduta then problemi[#problemi + 1] = 'revisione scaduta' end
    if not v.assicurato then problemi[#problemi + 1] = 'SENZA RCA' end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = #problemi > 0 and 'errore' or 'successo',
        icona = '🔍', durata = 15000,
        titolo = ('%s — %s'):format(targa, v.modello),
        testo = ('Intestatario: %s %s (%s)\nStato: %s\n%s'):format(
            intestatario and intestatario.nome or '?',
            intestatario and intestatario.cognome or '?',
            intestatario and intestatario.codice_fiscale or '?',
            v.stato,
            #problemi > 0 and ('IRREGOLARE — ' .. table.concat(problemi, ', ')) or 'Tutto regolare'),
    })
end)

AUREA.Comando('sequestra', 'utente', 'Sequestra il veicolo indicato', {
    { name = 'targa', help = 'Targa del veicolo' },
    { name = 'motivo', help = 'Motivo del provvedimento' },
}, function(src, args, raw, g)
    if not g or not g:HaPermessoLavoro('sequestro') or not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Serve il grado adeguato e il servizio attivo.' })
    end

    local targa = (args[1] or ''):upper():gsub('%s+', '')
    local motivo = table.concat(args, ' ', 2)
    if targa == '' then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/sequestra <targa> <motivo>' })
    end

    local esiste = MySQL.scalar.await('SELECT targa FROM veicoli WHERE targa = ?', { targa })
    if not esiste then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Targa sconosciuta', testo = targa })
    end

    Veicoli.Sequestra(targa, motivo ~= '' and motivo or 'provvedimento di polizia giudiziaria', g:NomeCompleto())
    TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'successo', titolo = 'Sequestro registrato', testo = targa })
end)
