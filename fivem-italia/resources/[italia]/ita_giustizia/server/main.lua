--[[
    AUREA · Giustizia (server) — casellario, fermo, arresto, MDT
]]

local U = AUREA.Util
local ammanettati = {}      -- [citizenid] = { da = os.time(), agente }

-- ---------------------------------------------------------------------------
--  Casellario giudiziale
-- ---------------------------------------------------------------------------
Casellario = {}

--- Apre un fascicolo a carico di un soggetto.
function Casellario.Apri(citizenid, codiceReato, agente, note)
    local reato = AUREA.Reati[codiceReato]
    if not reato then return nil end

    local id = MySQL.insert.await([[
        INSERT INTO casellario (citizenid, reato, articolo, gravita, pena_mesi, ammenda, agente, note)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, reato.nome, reato.articolo, reato.gravita, reato.pena, reato.ammenda, agente, note })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        g:Set('ricercato', (g:Get('ricercato') or 0) + reato.gravita, true)
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '⚖', durata = 12000,
            titolo = 'Fascicolo aperto a tuo carico',
            testo = ('%s (%s). Ti conviene rivolgerti a un avvocato.'):format(reato.nome, reato.articolo),
        })
    end

    AUREA.Log('giustizia', 'info', nil, ('Fascicolo %s a carico di %s (%s)'):format(reato.articolo, citizenid, agente or 'ufficio'))
    return id
end

exports('ApriFascicolo', Casellario.Apri)

AddEventHandler('aurea:giustizia:apriFascicolo', function(citizenid, codiceReato, agente, note)
    Casellario.Apri(citizenid, codiceReato, agente, note)
end)

--- Precedenti di un soggetto.
function Casellario.Precedenti(citizenid, soloAperti)
    local condizione = soloAperti and " AND stato IN ('indagato','imputato')" or ''
    local righe = MySQL.query.await(([[
        SELECT id, reato, articolo, gravita, pena_mesi, ammenda, stato, agente, aperto_il
        FROM casellario WHERE citizenid = ?%s ORDER BY aperto_il DESC LIMIT 40
    ]]):format(condizione), { citizenid }) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.aperto_il or 0) / 1000))
    end
    return righe
end

exports('Precedenti', Casellario.Precedenti)

-- ---------------------------------------------------------------------------
--  Fermo e arresto
-- ---------------------------------------------------------------------------
RegisterNetEvent('giu:ammanettato', function(stato)
    local g = AUREA.GetPlayer(source)
    if not g then return end
    if stato then
        ammanettati[g.citizenid] = { da = os.time() }
    else
        ammanettati[g.citizenid] = nil
    end
end)

--- Accompagnamento coattivo: solo su soggetti già ammanettati e vicini.
RegisterNetEvent('giu:trascinaRichiesta', function(bersaglioSrc)
    local src = source
    local agente = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not agente or not soggetto then return end

    if not agente:HaPermessoLavoro('fermo') or not agente.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale in servizio.',
        })
    end
    if not ammanettati[soggetto.citizenid] then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Soggetto libero', testo = 'Devi prima ammanettarlo.',
        })
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source)))
    if d > 3.0 then return end

    TriggerClientEvent('giu:trascina', soggetto.source, src)
end)

AUREA.Callback.Registra('giu:arresta', function(src, rispondi, bersaglioSrc, codici, note)
    local agente = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not agente or not soggetto then return rispondi(false, 'Soggetto non trovato.') end

    if not agente:HaPermessoLavoro('arresto') or not agente.lavoro.servizio then
        AUREA.Log('anticheat', 'allarme', src, 'tentativo di arresto senza permesso')
        return rispondi(false, 'Non hai il grado per procedere all\'arresto.')
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source)))
    if d > 5.0 then return rispondi(false, 'Il soggetto è troppo lontano.') end

    if type(codici) ~= 'table' or #codici == 0 then return rispondi(false, 'Nessun capo d\'imputazione indicato.') end

    local minuti, ammenda, capi = AUREA.CalcolaPena(codici)
    if minuti <= 0 then return rispondi(false, 'Capi d\'imputazione non validi.') end

    for _, codice in ipairs(codici) do
        Casellario.Apri(soggetto.citizenid, codice, agente:NomeCompleto(), note)
    end

    -- L'ammenda diventa un tributo, non un prelievo immediato dal conto
    if ammenda > 0 then
        exports.ita_fisco:IscriviTributo(soggetto.citizenid, 'sanzioni', os.date('%Y-%m'), ammenda, 20)
    end

    Detenzione.Avvia(soggetto, minuti, table.concat(capi, '; '), agente:NomeCompleto())

    -- Sequestro degli oggetti illeciti trovati addosso
    local inventario = exports.aurea_inventory:Inventario(soggetto.citizenid)
    local sequestrati = 0
    for _, riga in ipairs(U.CopiaProfonda(inventario.item)) do
        local dati = AUREA.Item[riga.nome]
        if dati and dati.categoria == 'illegale' then
            inventario:Rimuovi(riga.nome, riga.quantita, riga.slot)
            sequestrati = sequestrati + riga.quantita
        end
    end
    if sequestrati > 0 then
        TriggerClientEvent('inv:aggiorna', soggetto.source, inventario:Pacchetto())
    end

    AUREA.Log('giustizia', 'avviso', agente, ('ha arrestato %s: %s (%d minuti)'):format(
        soggetto.citizenid, table.concat(capi, '; '), minuti))

    rispondi(true, ('%s condannato a %d minuti. Ammenda %s.%s'):format(
        soggetto:NomeCompleto(), minuti, U.Euro(ammenda),
        sequestrati > 0 and (' Sequestrati %d oggetti illeciti.'):format(sequestrati) or ''))
end)

-- ---------------------------------------------------------------------------
--  MDT: consultazione dei precedenti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('giu:consulta', function(src, rispondi, chiave)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if not (g:HaPermessoLavoro('mdt') or g:HaPermessoLavoro('consulta_casellario')) then
        return rispondi(nil, 'Non sei autorizzato a consultare il casellario.')
    end

    chiave = tostring(chiave or ''):upper():gsub('%s+', '')
    local pg = MySQL.single.await([[
        SELECT citizenid, nome, cognome, codice_fiscale, data_nascita, luogo_nascita, telefono
        FROM personaggi WHERE codice_fiscale = ? OR citizenid = ?
    ]], { chiave, chiave })

    if not pg then return rispondi(nil, 'Nessun soggetto corrisponde alla ricerca.') end

    local precedenti = Casellario.Precedenti(pg.citizenid)
    local verbali = exports.ita_codicestrada:VerbaliAperti(pg.citizenid)
    local patente = exports.ita_codicestrada:PatenteGet(pg.citizenid)
    local veicoli = MySQL.query.await('SELECT targa, modello, stato FROM veicoli WHERE citizenid = ?', { pg.citizenid }) or {}
    local detenzione = MySQL.single.await('SELECT minuti_totali, minuti_scontati, motivo FROM detenzioni WHERE citizenid = ? AND attiva = 1', { pg.citizenid })

    AUREA.Log('giustizia', 'debug', g, ('consultazione MDT su %s'):format(pg.citizenid))

    rispondi({
        anagrafica = {
            nome = pg.nome, cognome = pg.cognome, cf = pg.codice_fiscale,
            citizenid = pg.citizenid, telefono = pg.telefono,
            nascita = U.DataIT(math.floor((pg.data_nascita or 0) / 1000)),
            luogo = pg.luogo_nascita,
        },
        precedenti = precedenti,
        verbali = verbali,
        patente = patente and {
            numero = patente.numero, punti = patente.punti,
            categorie = patente.categorie, ritirata = patente.ritirata == 1,
        } or nil,
        veicoli = veicoli,
        detenzione = detenzione,
        online = AUREA.GetPlayerByCitizenId(pg.citizenid) ~= nil,
    })
end)

-- ---------------------------------------------------------------------------
--  Denunce
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('giu:denuncia', function(src, rispondi, oggetto, corpo, cfDenunciato)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    oggetto = tostring(oggetto or ''):sub(1, 120)
    corpo = tostring(corpo or ''):sub(1, 1500)
    if #oggetto < 5 or #corpo < 20 then
        return rispondi(false, 'La denuncia deve essere circostanziata: indica oggetto e fatti.')
    end

    local denunciato = nil
    if cfDenunciato and cfDenunciato ~= '' then
        denunciato = MySQL.scalar.await('SELECT citizenid FROM personaggi WHERE codice_fiscale = ?', { cfDenunciato:upper() })
    end

    local id = MySQL.insert.await(
        'INSERT INTO denunce (denunciante, denunciato, oggetto, corpo) VALUES (?, ?, ?, ?)',
        { g.citizenid, denunciato, oggetto, corpo })

    exports.aurea_ui:NotificaLavoro('carabinieri', {
        tipo = 'polizia', icona = '📋', durata = 12000,
        titolo = ('Denuncia protocollata n. %d'):format(id),
        testo = ('%s — %s'):format(g:NomeCompleto(), oggetto),
    }, true)

    rispondi(true, ('Denuncia protocollata con numero %d. Sarai ricontattato.'):format(id))
end)

AUREA.Callback.Registra('giu:denunce', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not g:HaPermessoLavoro('mdt') then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT d.id, d.oggetto, d.corpo, d.stato, d.creata_il,
               p.nome AS nome_d, p.cognome AS cognome_d,
               q.nome AS nome_s, q.cognome AS cognome_s
        FROM denunce d
        LEFT JOIN personaggi p ON p.citizenid = d.denunciante
        LEFT JOIN personaggi q ON q.citizenid = d.denunciato
        WHERE d.stato IN ('protocollata','in_indagine')
        ORDER BY d.creata_il DESC LIMIT 25
    ]]) or {}

    for _, d in ipairs(righe) do
        d.quando = U.DataOraIT(math.floor((d.creata_il or 0) / 1000))
    end
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Prescrizione dei reati lievi
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(120000)
    while true do
        Wait(20 * 60000)

        for gravita, minuti in pairs(GIU.Regole.prescrizioneMinuti) do
            if minuti > 0 then
                MySQL.update([[
                    UPDATE casellario SET stato = 'prescritto', chiuso_il = NOW()
                    WHERE gravita = ? AND stato = 'indagato'
                      AND aperto_il < DATE_SUB(NOW(), INTERVAL ? MINUTE)
                ]], { gravita, minuti })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('reati', 'utente', 'Elenca i codici reato disponibili', {}, function(src, _, _, g)
    if not g or not g:HaPermessoLavoro('mdt') then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato alle forze dell\'ordine.' })
    end

    local righe = {}
    for codice, r in pairs(AUREA.Reati) do
        righe[#righe + 1] = ('%s = %s (%s, %d min)'):format(codice, r.nome, r.articolo, r.pena)
    end
    table.sort(righe)

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '⚖', durata = 30000,
        titolo = 'Codice penale', testo = table.concat(righe, '\n'),
    })
end)

AUREA.Comando('precedenti', 'utente', 'Consulta i tuoi precedenti', {}, function(src, _, _, g)
    if not g then return end
    local precedenti = Casellario.Precedenti(g.citizenid)

    if #precedenti == 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '⚖', titolo = 'Casellario immacolato', testo = 'Nessun precedente a tuo carico.',
        })
    end

    local righe = {}
    for i = 1, math.min(8, #precedenti) do
        local p = precedenti[i]
        righe[#righe + 1] = ('%s — %s (%s)'):format(p.articolo, p.reato, p.stato)
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '⚖', durata = 16000,
        titolo = ('Casellario — %d iscrizioni'):format(#precedenti),
        testo = table.concat(righe, '\n'),
    })
end)
