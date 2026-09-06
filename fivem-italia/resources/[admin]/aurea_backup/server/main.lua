--[[
    AUREA · Copie di sicurezza (server)

    SaveResourceFile scrive dentro la cartella della risorsa. La rotazione
    è a slot numerati: la copia n scrive su copia_N.json, dove N gira da 1
    a BCK.Cadenza.quante. Non si cancella niente — in Lua non si può
    cancellare un file — si riscrive sopra, che ai fini della rotazione è
    la stessa cosa e in più garantisce che lo spazio occupato non cresca.

    Un indice separato tiene traccia di quale slot contiene cosa e quando,
    così una copia si trova senza aprirle tutte.
]]

local U = AUREA.Util
local risorsa = GetCurrentResourceName()
local inCorso = false

local function percorso(nome)
    return ('%s/%s'):format(BCK.Cartella, nome)
end

--- Avvisa chi è in gioco e ha i permessi. Non c'è un canale staff
--- generale nel core, quindi si scorrono i connessi.
local function avvisaStaff(tipo, testo)
    for _, g in ipairs(AUREA.GetGiocatori()) do
        if AUREA.HaGruppo(g.source, BCK.Permessi.gruppo) then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = tipo, icona = '💾', durata = 15000,
                titolo = 'Copia di sicurezza', testo = testo,
            })
        end
    end
end

-- ---------------------------------------------------------------------------
--  Indice
-- ---------------------------------------------------------------------------
local function leggiIndice()
    local grezzo = LoadResourceFile(risorsa, percorso('indice.json'))
    if not grezzo then return { prossimoSlot = 1, copie = {} } end

    local ok, dati = pcall(json.decode, grezzo)
    if not ok or type(dati) ~= 'table' then return { prossimoSlot = 1, copie = {} } end

    dati.prossimoSlot = dati.prossimoSlot or 1
    dati.copie = dati.copie or {}
    return dati
end

local function scriviIndice(indice)
    SaveResourceFile(risorsa, percorso('indice.json'), json.encode(indice, { indent = true }), -1)
end

-- ---------------------------------------------------------------------------
--  La copia
-- ---------------------------------------------------------------------------
local function esegui(motivo, autore)
    if inCorso then return false, 'Una copia è già in corso.' end
    inCorso = true

    local avvio = GetGameTimer()
    local indice = leggiIndice()
    local slot = indice.prossimoSlot

    local contenuto = {
        versione = 1,
        momento = os.date('%Y-%m-%d %H:%M:%S'),
        motivo = motivo,
        autore = autore,
        giocatoriConnessi = #AUREA.GetGiocatori(),
        tabelle = {},
    }

    local problemi = {}
    local righeTotali = 0

    for _, t in ipairs(BCK.Tabelle) do
        local ok, righe = pcall(function()
            return MySQL.query.await(
                ('SELECT * FROM `%s` ORDER BY %s LIMIT %d'):format(t.nome, t.ordine, t.righeMassime))
        end)

        if not ok or type(righe) ~= 'table' then
            problemi[#problemi + 1] = t.nome
            contenuto.tabelle[t.nome] = { errore = true, righe = {} }
        else
            righeTotali = righeTotali + #righe
            contenuto.tabelle[t.nome] = {
                righe = righe,
                -- Se abbiamo preso esattamente il massimo, molto
                -- probabilmente ne sono rimaste fuori: va detto
                troncata = #righe >= t.righeMassime,
            }
            if #righe >= t.righeMassime then
                problemi[#problemi + 1] = ('%s (troncata a %d righe)'):format(t.nome, t.righeMassime)
            end
        end

        -- Una tabella per volta, con respiro: il server non deve
        -- inchiodarsi mentre fa la copia
        Wait(250)
    end

    local nomeFile = ('copia_%02d.json'):format(slot)
    local scritto = SaveResourceFile(risorsa, percorso(nomeFile), json.encode(contenuto), -1)

    inCorso = false

    if not scritto then
        AUREA.Log('staff', 'allarme', nil, ('Copia di sicurezza FALLITA: impossibile scrivere %s'):format(nomeFile))

        if BCK.Avvisi.suErrore then
            avvisaStaff('errore',
                ('Copia fallita: non si riesce a scrivere %s. Controlla i permessi della cartella.')
                    :format(nomeFile))
        end
        return false, 'Scrittura del file non riuscita.'
    end

    indice.copie[tostring(slot)] = {
        file = nomeFile,
        momento = contenuto.momento,
        motivo = motivo,
        autore = autore,
        righe = righeTotali,
        problemi = #problemi > 0 and table.concat(problemi, ', ') or nil,
    }
    indice.prossimoSlot = (slot % BCK.Cadenza.quante) + 1
    indice.ultima = contenuto.momento
    scriviIndice(indice)

    local secondi = U.Round((GetGameTimer() - avvio) / 1000, 1)

    AUREA.Log('staff', #problemi > 0 and 'avviso' or 'info', nil,
        ('Copia di sicurezza %s: %d righe in %s secondi%s')
            :format(nomeFile, righeTotali, secondi,
                    #problemi > 0 and (' — attenzione: ' .. table.concat(problemi, ', ')) or ''))

    if #problemi > 0 or BCK.Avvisi.aOgniCopia then
        avvisaStaff(#problemi > 0 and 'avviso' or 'info',
            ('%s: %d righe.%s'):format(nomeFile, righeTotali,
                #problemi > 0 and (' Problemi su: ' .. table.concat(problemi, ', ')) or ''))
    end

    return true, ('%s scritta: %d righe in %s secondi.'):format(nomeFile, righeTotali, secondi)
end

-- ---------------------------------------------------------------------------
--  Automatismo
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(BCK.Cadenza.ritardoAvvioMinuti * 60000)

    while true do
        esegui('automatica', 'sistema')
        Wait(BCK.Cadenza.minuti * 60000)
    end
end)

--- Una copia si fa anche allo spegnimento ordinato del server: è il
--- momento in cui i dati sono più freschi e più a rischio.
AddEventHandler('txAdmin:events:scheduledRestart', function(dati)
    if type(dati) == 'table' and dati.secondsRemaining == 60 then
        CreateThread(function() esegui('riavvio programmato', 'sistema') end)
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('backup', BCK.Permessi.gruppo, 'Esegue subito una copia di sicurezza', {},
    function(src)
        local g = src > 0 and AUREA.GetPlayer(src) or nil

        if src > 0 then
            TriggerClientEvent('aurea:ui:notifica', src, {
                tipo = 'info', icona = '💾', titolo = 'Copia avviata',
                testo = 'Può volerci qualche secondo.', durata = 8000,
            })
        end

        -- esegui() aspetta fra una tabella e l'altra: va in un thread suo,
        -- il gestore di un comando non può cedere il passo
        CreateThread(function()
            local ok, messaggio = esegui('manuale', g and g:NomeCompleto() or 'console')

            if src > 0 then
                TriggerClientEvent('aurea:ui:notifica', src, {
                    tipo = ok and 'successo' or 'errore', icona = '💾',
                    titolo = ok and 'Copia eseguita' or 'Copia fallita',
                    testo = messaggio, durata = 14000,
                })
            else
                print(('[aurea_backup] %s'):format(messaggio))
            end
        end)
    end)

AUREA.Comando('backups', BCK.Permessi.gruppo, 'Elenca le copie di sicurezza presenti', {},
    function(src)
        local indice = leggiIndice()

        local righe = {}
        for slot, c in pairs(indice.copie) do
            righe[#righe + 1] = {
                slot = tonumber(slot), file = c.file, momento = c.momento,
                motivo = c.motivo, autore = c.autore, righe = c.righe, problemi = c.problemi,
            }
        end
        table.sort(righe, function(a, b) return (a.momento or '') > (b.momento or '') end)

        if src > 0 then
            TriggerClientEvent('bck:elenco', src, righe, indice.prossimoSlot, BCK.Cadenza)
        else
            print(('[aurea_backup] %d copie in archivio, prossimo slot %d')
                :format(#righe, indice.prossimoSlot))
            for _, r in ipairs(righe) do
                print(('  %s  %s  %d righe  (%s)%s'):format(
                    r.file, r.momento or 'n.d.', r.righe or 0, r.motivo or 'n.d.',
                    r.problemi and ('  ATTENZIONE: ' .. r.problemi) or ''))
            end
        end
    end)

-- ---------------------------------------------------------------------------
--  Consultazione di una copia
--
--  Non ripristina niente: mostra cosa c'era. Il ripristino di un dato si
--  fa a mano, guardando, perché reinserire alla cieca una riga vecchia
--  sopra una nuova crea più danni di quanti ne ripari.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bck:consulta', function(src, rispondi, file, tabella, chiave)
    if not AUREA.HaGruppo(src, BCK.Permessi.gruppoLettura) then
        return rispondi(nil, 'Non hai i permessi per leggere il contenuto di una copia.')
    end

    -- Il nome del file non arriva mai grezzo dal client: si accetta solo
    -- la forma esatta che generiamo noi
    if type(file) ~= 'string' or not file:match('^copia_%d%d%.json$') then
        return rispondi(nil, 'Nome di copia non valido.')
    end

    local grezzo = LoadResourceFile(risorsa, percorso(file))
    if not grezzo then return rispondi(nil, 'Copia non trovata.') end

    local ok, dati = pcall(json.decode, grezzo)
    if not ok or type(dati) ~= 'table' then return rispondi(nil, 'Copia illeggibile.') end

    if not tabella then
        local elenco = {}
        for nome, t in pairs(dati.tabelle or {}) do
            elenco[#elenco + 1] = {
                nome = nome, righe = #(t.righe or {}),
                troncata = t.troncata or false, errore = t.errore or false,
            }
        end
        table.sort(elenco, function(a, b) return a.nome < b.nome end)
        return rispondi({ momento = dati.momento, motivo = dati.motivo, tabelle = elenco })
    end

    local t = (dati.tabelle or {})[tabella]
    if not t then return rispondi(nil, 'Quella tabella non è in questa copia.') end

    if not chiave or chiave == '' then
        return rispondi({ momento = dati.momento, righe = {}, totale = #(t.righe or {}) },
            'Indica un codice fiscale, una targa o un id da cercare.')
    end

    chiave = tostring(chiave):lower()
    local trovate = {}

    for _, riga in ipairs(t.righe or {}) do
        for _, valore in pairs(riga) do
            if type(valore) == 'string' and valore:lower():find(chiave, 1, true) then
                trovate[#trovate + 1] = riga
                break
            end
        end
        if #trovate >= 10 then break end
    end

    AUREA.Log('staff', 'avviso', src,
        ('ha consultato la copia %s, tabella %s, chiave "%s"'):format(file, tabella, chiave))

    rispondi({ momento = dati.momento, righe = trovate, totale = #(t.righe or {}) })
end)

exports('EseguiCopia', function(motivo)
    return esegui(motivo or 'richiesta esterna', 'risorsa')
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    CreateThread(function() esegui('spegnimento del server', 'sistema') end)
end)
