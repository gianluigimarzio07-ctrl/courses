--[[
    AUREA · Nucleo server
    Connessione, selezione personaggio, cicli di manutenzione, API pubblica.
]]

AUREA = AUREA or {}

local U = AUREA.Util
local C = AUREA.Config

local sessioni = {}     -- [source] = { license, account }

-- ===========================================================================
--  LOG
-- ===========================================================================

--- Scrive nel registro eventi (database + eventuale webhook).
---@param canale string
---@param livello 'debug'|'info'|'avviso'|'allarme'
---@param soggetto table|number|nil  Giocatore, source o nil
---@param messaggio string
---@param dati table|nil
function AUREA.Log(canale, livello, soggetto, messaggio, dati)
    local citizenid, license
    if type(soggetto) == 'table' then
        citizenid, license = soggetto.citizenid, soggetto.license
    elseif type(soggetto) == 'number' then
        local g = AUREA.GetPlayer(soggetto)
        if g then citizenid, license = g.citizenid, g.license end
    end

    if C.Log.suDatabase then
        MySQL.insert('INSERT INTO registro_eventi (canale, livello, citizenid, license, messaggio, dati) VALUES (?, ?, ?, ?, ?, ?)',
            { canale, livello, citizenid, license, messaggio, dati and json.encode(dati) or nil })
    end

    TriggerEvent('aurea:log', canale, livello, citizenid, messaggio, dati)
end

-- ===========================================================================
--  ACCESSO ACCOUNT
-- ===========================================================================

local function trovaIdentificatore(src, prefisso)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefisso + 1) == prefisso .. ':' then
            return id:sub(#prefisso + 2)
        end
    end
    return nil
end

AddEventHandler('playerConnecting', function(nomeUtente, _, deferrals)
    local src = source

    -- In modalità ESX l'accesso lo governa es_extended: due flussi di
    -- deferral in parallelo si bloccano a vicenda e il giocatore resta
    -- appeso in connessione.
    if C.Framework == 'esx' then return end

    deferrals.defer()
    Wait(0)
    deferrals.update(('Benvenuto su %s. Verifica dell\'accesso in corso...'):format(C.Server.nome))

    local license = trovaIdentificatore(src, 'license2') or trovaIdentificatore(src, 'license')
    if not license then
        deferrals.done('Impossibile leggere la tua licenza Rockstar. Riavvia FiveM e riprova.')
        return
    end

    -- Sanzioni attive
    local ban = MySQL.single.await([[
        SELECT tipo, motivo, fine FROM sanzioni_admin
        WHERE license = ? AND attiva = 1 AND tipo IN ('ban','ban_permanente')
          AND (fine IS NULL OR fine > NOW())
        ORDER BY id DESC LIMIT 1
    ]], { license })

    if ban then
        local scadenza = ban.fine and (' Scadenza: ' .. U.DataOraIT(math.floor(ban.fine / 1000))) or ' Sanzione permanente.'
        deferrals.done(('Accesso negato.\nMotivo: %s.%s'):format(ban.motivo, scadenza))
        return
    end

    deferrals.update('Caricamento del profilo...')

    local discord = trovaIdentificatore(src, 'discord')
    local steam = trovaIdentificatore(src, 'steam')

    local account = MySQL.single.await('SELECT * FROM account WHERE license = ?', { license })
    if not account then
        local id = MySQL.insert.await(
            'INSERT INTO account (license, discord, steam, nome_discord, slot_massimi) VALUES (?, ?, ?, ?, ?)',
            { license, discord, steam, nomeUtente, C.Server.slotBase })
        account = { id = id, license = license, gruppo = 'utente', slot_massimi = C.Server.slotBase, whitelist = 0 }
    else
        MySQL.update('UPDATE account SET discord = ?, steam = ?, nome_discord = ?, ultimo_accesso = NOW() WHERE id = ?',
            { discord, steam, nomeUtente, account.id })
    end

    local whitelistAttiva = GetConvarInt('aurea_whitelist', 0) == 1
    if whitelistAttiva and account.whitelist ~= 1 and (C.Gruppi[account.gruppo] or 0) < C.Gruppi.moderatore then
        deferrals.done('Il server è in whitelist. Candidati sul Discord ufficiale per ottenere l\'accesso.')
        return
    end

    sessioni[src] = { license = license, account = account }
    deferrals.done()
end)

-- ===========================================================================
--  SELEZIONE E CREAZIONE PERSONAGGIO
-- ===========================================================================

AUREA.Callback.Registra('core:personaggi', function(src, rispondi)
    if C.Framework == 'esx' then
        -- Il personaggio lo prepara aurea_esx a partire da esx:playerLoaded.
        return rispondi({ personaggi = {}, slot = 0, gestitoDaESX = true })
    end

    local sessione = sessioni[src]
    if not sessione then return rispondi({ personaggi = {}, slot = 0 }) end

    local righe = MySQL.query.await([[
        SELECT citizenid, slot, nome, cognome, data_nascita, sesso, lavoro, lavoro_grado,
               contanti, banca, minuti_gioco, ultimo_uso, aspetto
        FROM personaggi WHERE account_id = ? AND eliminato = 0 ORDER BY slot ASC
    ]], { sessione.account.id }) or {}

    for _, r in ipairs(righe) do
        r.lavoroEtichetta = AUREA.EtichettaLavoro(r.lavoro, r.lavoro_grado)
        r.aspetto = r.aspetto and json.decode(r.aspetto) or nil
    end

    rispondi({ personaggi = righe, slot = sessione.account.slot_massimi })
end)

AUREA.Callback.Registra('core:creaPersonaggio', function(src, rispondi, dati)
    local sessione = sessioni[src]
    if not sessione then return rispondi({ ok = false, errore = 'Sessione non valida.' }) end

    -- Validazione lato server: il client non è mai una fonte attendibile
    local nome = tostring(dati.nome or ''):gsub('[^%a%sàèéìòùÀÈÉÌÒÙ\']', ''):sub(1, 24)
    local cognome = tostring(dati.cognome or ''):gsub('[^%a%sàèéìòùÀÈÉÌÒÙ\']', ''):sub(1, 24)
    local sesso = (dati.sesso == 'F') and 'F' or 'M'
    local nascita = tostring(dati.dataNascita or '')

    if #nome < 2 or #cognome < 2 then
        return rispondi({ ok = false, errore = 'Nome e cognome devono avere almeno 2 lettere.' })
    end

    local anno, mese, giorno = nascita:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
    if not anno then
        return rispondi({ ok = false, errore = 'Data di nascita non valida (formato AAAA-MM-GG).' })
    end
    anno, mese, giorno = tonumber(anno), tonumber(mese), tonumber(giorno)
    local annoCorrente = tonumber(os.date('%Y'))
    local eta = annoCorrente - anno
    if eta < 18 or eta > 80 or mese < 1 or mese > 12 or giorno < 1 or giorno > 31 then
        return rispondi({ ok = false, errore = 'Devi avere tra i 18 e gli 80 anni.' })
    end

    local comuni = {}
    for _, p in ipairs(C.Province) do comuni[p.comune] = p end
    local comune = comuni[dati.luogoNascita] and dati.luogoNascita or C.Province[1].comune

    local quanti = MySQL.scalar.await('SELECT COUNT(*) FROM personaggi WHERE account_id = ? AND eliminato = 0', { sessione.account.id }) or 0
    if quanti >= (sessione.account.slot_massimi or 2) then
        return rispondi({ ok = false, errore = 'Hai esaurito gli slot personaggio disponibili.' })
    end

    local citizenid = AUREA.Anagrafe.NuovoCitizenId(comuni[comune].sigla)
    local cf = AUREA.Anagrafe.NuovoCodiceFiscale(cognome, nome, nascita, sesso, comune)
    local telefono = AUREA.Anagrafe.NuovoTelefono()

    MySQL.insert.await([[
        INSERT INTO personaggi
            (citizenid, account_id, slot, nome, cognome, data_nascita, luogo_nascita, sesso,
             codice_fiscale, telefono, contanti, banca, lavoro, posizione, stato, metadata, aspetto)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, sessione.account.id, quanti + 1, nome, cognome, nascita, comune, sesso,
        cf, telefono, C.Avvio.contanti, C.Avvio.banca, C.Avvio.lavoro,
        json.encode(C.Avvio.posizione),
        json.encode({ fame = 100, sete = 100, stress = 0, salute = 200, armatura = 0, alcol = 0, energia = 100 }),
        json.encode({}),
        dati.aspetto and json.encode(dati.aspetto) or nil,
    })

    -- Conto corrente
    local iban = AUREA.Anagrafe.NuovoIBAN(sessione.account.id)
    MySQL.insert.await('INSERT INTO conti (iban, intestatario, tipo, nome, saldo) VALUES (?, ?, ?, ?, ?)',
        { iban, citizenid, 'personale', 'Conto corrente', C.Avvio.banca })
    MySQL.update.await('UPDATE personaggi SET metadata = ? WHERE citizenid = ?',
        { json.encode({ iban = iban }), citizenid })

    -- Corredo iniziale
    TriggerEvent('aurea:inventario:corredoIniziale', citizenid, C.Avvio.corredo)

    AUREA.Log('connessioni', 'info', nil, ('Nuovo personaggio %s %s (%s) — CF %s'):format(nome, cognome, citizenid, cf))
    rispondi({ ok = true, citizenid = citizenid })
end)

AUREA.Callback.Registra('core:eliminaPersonaggio', function(src, rispondi, citizenid)
    local sessione = sessioni[src]
    if not sessione then return rispondi(false) end

    local proprietario = MySQL.scalar.await('SELECT account_id FROM personaggi WHERE citizenid = ?', { citizenid })
    if proprietario ~= sessione.account.id then
        AUREA.Log('anticheat', 'allarme', src, ('tentativo di eliminare un personaggio non proprio: %s'):format(citizenid))
        return rispondi(false)
    end

    MySQL.update.await('UPDATE personaggi SET eliminato = 1 WHERE citizenid = ?', { citizenid })
    AUREA.Log('connessioni', 'avviso', nil, ('Personaggio eliminato: %s'):format(citizenid))
    rispondi(true)
end)

--- Carica il personaggio e lo mette in gioco.
AUREA.Callback.Registra('core:selezionaPersonaggio', function(src, rispondi, citizenid)
    if C.Framework == 'esx' then return rispondi(nil) end

    local sessione = sessioni[src]
    if not sessione then return rispondi(nil) end

    local riga = MySQL.single.await('SELECT * FROM personaggi WHERE citizenid = ? AND account_id = ? AND eliminato = 0',
        { citizenid, sessione.account.id })
    if not riga then
        AUREA.Log('anticheat', 'allarme', src, ('selezione di un personaggio non proprio: %s'):format(tostring(citizenid)))
        return rispondi(nil)
    end

    -- Un personaggio già in gioco su un'altra sessione va espulso da quella
    local altroSrc = AUREA.PerCitizenId[citizenid]
    if altroSrc and altroSrc ~= src then
        DropPlayer(altroSrc, 'Il tuo personaggio è stato caricato da un\'altra sessione.')
    end

    local g = AUREA.CostruisciGiocatore(src, riga, sessione.account)
    AUREA.Giocatori[src] = g
    AUREA.PerCitizenId[citizenid] = src

    MySQL.update('UPDATE personaggi SET ultimo_uso = NOW() WHERE citizenid = ?', { citizenid })

    AUREA.Log('connessioni', 'info', g, ('%s è entrato in gioco'):format(g:NomeCompleto()))
    TriggerEvent('aurea:giocatore:caricato', src, g)
    TriggerClientEvent('aurea:giocatore:caricato', src, g:Pacchetto(), riga.aspetto and json.decode(riga.aspetto) or nil)

    rispondi({ pacchetto = g:Pacchetto(), posizione = g.posizione, aspetto = g.aspetto })
end)

-- ===========================================================================
--  DISCONNESSIONE
-- ===========================================================================

AddEventHandler('playerDropped', function(motivo)
    local src = source

    -- In modalità ESX il salvataggio e lo scarico li fa aurea_esx, che sa
    -- anche cosa NON salvare (il denaro, che è di ESX).
    if C.Framework == 'esx' then
        sessioni[src] = nil
        return
    end

    local g = AUREA.Giocatori[src]
    if g then
        TriggerEvent('aurea:giocatore:scaricato', src, g)
        g:Salva()
        AUREA.PerCitizenId[g.citizenid] = nil
        AUREA.Giocatori[src] = nil
        AUREA.Log('connessioni', 'info', g, ('%s è uscito (%s)'):format(g:NomeCompleto(), motivo or 'n.d.'))
    end
    sessioni[src] = nil
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for _, g in pairs(AUREA.Giocatori) do
        pcall(function() g:Salva() end)
    end
end)

-- ===========================================================================
--  API PUBBLICA
-- ===========================================================================

function AUREA.GetPlayer(src)
    return AUREA.Giocatori[tonumber(src)]
end

function AUREA.GetPlayerByCitizenId(citizenid)
    local src = AUREA.PerCitizenId[citizenid]
    return src and AUREA.Giocatori[src] or nil
end

function AUREA.GetPlayerByTelefono(numero)
    for _, g in pairs(AUREA.Giocatori) do
        if g.telefono == numero then return g end
    end
    return nil
end

function AUREA.GetGiocatori()
    local out = {}
    for _, g in pairs(AUREA.Giocatori) do out[#out + 1] = g end
    return out
end

--- Giocatori con un dato lavoro, opzionalmente solo quelli in servizio.
function AUREA.GetGiocatoriPerLavoro(lavoro, soloInServizio)
    local out = {}
    for _, g in pairs(AUREA.Giocatori) do
        if g.lavoro.nome == lavoro and (not soloInServizio or g.lavoro.servizio) then
            out[#out + 1] = g
        end
    end
    return out
end

--- Giocatori appartenenti a un ente di emergenza (carabinieri, 118, ...)
function AUREA.GetGiocatoriPerEnte(ente, soloInServizio)
    local out = {}
    for _, g in pairs(AUREA.Giocatori) do
        local l = AUREA.GetLavoro(g.lavoro.nome)
        if l.ente == ente and (not soloInServizio or g.lavoro.servizio) then
            out[#out + 1] = g
        end
    end
    return out
end

function AUREA.HaGruppo(src, gruppoMinimo)
    local g = AUREA.GetPlayer(src)
    local sessione = sessioni[src]
    local gruppo = (g and g.gruppo) or (sessione and sessione.account.gruppo) or 'utente'
    return (C.Gruppi[gruppo] or 0) >= (C.Gruppi[gruppoMinimo] or 0)
end

exports('GetPlayer', AUREA.GetPlayer)
exports('GetPlayerByCitizenId', AUREA.GetPlayerByCitizenId)
exports('GetGiocatori', AUREA.GetGiocatori)
exports('GetGiocatoriPerLavoro', AUREA.GetGiocatoriPerLavoro)
exports('GetGiocatoriPerEnte', AUREA.GetGiocatoriPerEnte)
exports('HaGruppo', AUREA.HaGruppo)
exports('Log', AUREA.Log)
exports('Config', function() return C end)

--- La tabella del framework, per le altre risorse.
--- Passa per riferimento fra risorse Lua: chi la riceve ha i metodi
--- dell'oggetto Giocatore e la tabella viva dei connessi, non una copia.
--- Si aggancia con '@aurea_core/bridge/aurea.lua'.
exports('Aurea', function() return AUREA end)


-- ===========================================================================
--  CICLI DI MANUTENZIONE
-- ===========================================================================

-- Salvataggio periodico
CreateThread(function()
    local intervallo = C.Salvataggio.intervalloMinuti * 60000
    while true do
        Wait(intervallo)
        local n = 0
        for _, g in pairs(AUREA.Giocatori) do
            local ok = pcall(function() g:Salva() end)
            if ok then n = n + 1 end
        end
        if n > 0 then print(('[AUREA] salvati %d personaggi'):format(n)) end
    end
end)

-- Tempo di gioco e bisogni primari
CreateThread(function()
    while true do
        Wait(C.Stato.tickSecondi * 1000)
        for src, g in pairs(AUREA.Giocatori) do
            g.metadata.minutiGioco = (g.metadata.minutiGioco or 0) + 1

            g:VariaStato('fame', -C.Stato.fame.decadimento)
            g:VariaStato('sete', -C.Stato.sete.decadimento)

            -- lo stress cala da solo quando si è fermi e sazi, sale a digiuno
            if g.stato.fame > 40 and g.stato.sete > 40 then
                g:VariaStato('stress', -C.Stato.stress.crescitaBase * 2)
            else
                g:VariaStato('stress', C.Stato.stress.crescitaBase * 4)
            end

            -- smaltimento alcolemico: circa 0,15 g/l per ora
            if (g.stato.alcol or 0) > 0 then
                g.stato.alcol = math.max(0, g.stato.alcol - 0.0025)
            end

            if g.stato.fame <= 0 or g.stato.sete <= 0 then
                TriggerClientEvent('aurea:stato:danno', src, C.Stato.dannoDigiuno)
            end

            TriggerClientEvent('aurea:stato:aggiorna', src, g.stato)
        end
    end
end)

-- Stipendi: ogni 30 minuti reali
CreateThread(function()
    while true do
        Wait(30 * 60000)
        for _, g in pairs(AUREA.Giocatori) do
            local grado = AUREA.GetGrado(g.lavoro.nome, g.lavoro.grado)
            local lordo = grado.stipendio or 0
            if lordo > 0 and not g.metadata.detenuto then
                -- Ritenuta IRPEF alla fonte, girata all'erario dal modulo fiscale
                local aliquota = lordo >= 25000 and 0.27 or 0.23
                local ritenuta = math.floor(lordo * aliquota)
                local netto = lordo - ritenuta

                g:Aggiungi('banca', netto, ('Stipendio %s'):format(AUREA.EtichettaLavoro(g.lavoro.nome, g.lavoro.grado)))
                TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'successo',
                    titolo = 'Stipendio accreditato',
                    testo = ('Netto %s · ritenuta %s'):format(U.Euro(netto), U.Euro(ritenuta)),
                })
            end
        end
    end
end)

print(('[AUREA] nucleo avviato · %s'):format(C.Server.nome))
