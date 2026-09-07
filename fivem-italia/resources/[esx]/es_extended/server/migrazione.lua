--[[
    ESX su AUREA — migrazione dal database ESX

    Serve a chi passa da un server ESX vero ad AUREA (strada A di
    docs/ESX.md) e non vuole buttare via i personaggi che ha.

    Legge la tabella `users` di ESX e crea le righe `personaggi` di AUREA,
    generando quello che ESX non ha: codice cittadino, codice fiscale,
    telefono, IBAN, conto corrente.

    Tre cose sono state decise apposta e vanno sapute prima di premere:

      · È IDEMPOTENTE. Un utente già migrato non viene rifatto: la colonna
        esx_identifier ricorda chi è arrivato da dove. Puoi rilanciarla
        dopo aver sistemato due righe a mano senza duplicare niente.

      · PARTE IN PROVA. /migraesx da solo non scrive niente: dice cosa
        farebbe. Per scrivere davvero serve /migraesx esegui, che è una
        parola in più che vale la pena digitare.

      · IL DENARO ARRIVA INTERO. ESX tiene gli accounts in JSON con gli
        euro; qui diventano centesimi moltiplicando per cento e
        arrotondando. Da euro a centesimi non si perde niente: si guadagna
        precisione.

    L'inventario ESX non si migra. In ESX un oggetto è un nome e un numero,
    in AUREA ha slot, peso e metadata per istanza: convertire alla cieca
    riempirebbe gli zaini di roba senza identità. Meglio consegnare il
    corredo iniziale e lasciare che il resto se lo rifacciano.
]]

local U = AUREA.Util
local C = AUREA.Config

local function tabellaEsiste(nome)
    local riga = MySQL.single.await([[
        SELECT COUNT(*) AS quante FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = ?
    ]], { nome })
    return riga and tonumber(riga.quante or 0) > 0
end

--- Da "John Doe" a nome e cognome accettabili per l'anagrafe.
local function spezzaNome(riga)
    local nome = riga.firstname or riga.first_name
    local cognome = riga.lastname or riga.last_name

    if (not nome or #tostring(nome) < 2) and riga.name then
        nome, cognome = tostring(riga.name):match('^(%S+)%s+(.+)$')
        if not nome then nome = tostring(riga.name) end
    end

    nome = tostring(nome or ''):gsub('[^%a]', ''):sub(1, 24)
    cognome = tostring(cognome or ''):gsub('[^%a]', ''):sub(1, 24)

    if #nome < 2 then nome = 'Mario' end
    if #cognome < 2 then cognome = 'Rossi' end

    -- Prima lettera maiuscola: in anagrafe non si scrive tutto minuscolo
    nome = nome:sub(1, 1):upper() .. nome:sub(2):lower()
    cognome = cognome:sub(1, 1):upper() .. cognome:sub(2):lower()

    return nome, cognome
end

local function dataValida(grezza)
    local d = tostring(grezza or '')
    local anno, mese, giorno = d:match('^(%d%d%d%d)-(%d%d)-(%d%d)')
    if anno then
        local eta = tonumber(os.date('%Y')) - tonumber(anno)
        if eta >= 18 and eta <= 90 then return ('%s-%s-%s'):format(anno, mese, giorno) end
    end
    -- ESX salva spesso in gg/mm/aaaa
    local g2, m2, a2 = d:match('^(%d%d)/(%d%d)/(%d%d%d%d)$')
    if a2 then return ('%s-%s-%s'):format(a2, m2, g2) end
    return '1995-06-15'
end

local function saldiDa(riga)
    local contanti, banca, nero = 0, 0, 0

    -- ESX 1.9+: colonne separate. ESX legacy: JSON in `accounts`.
    if riga.money ~= nil then contanti = math.floor((tonumber(riga.money) or 0) * 100) end
    if riga.bank ~= nil then banca = math.floor((tonumber(riga.bank) or 0) * 100) end

    if riga.accounts then
        local ok, conti = pcall(json.decode, riga.accounts)
        if ok and type(conti) == 'table' then
            if conti.money then contanti = math.floor((tonumber(conti.money) or 0) * 100) end
            if conti.bank then banca = math.floor((tonumber(conti.bank) or 0) * 100) end
            if conti.black_money then nero = math.floor((tonumber(conti.black_money) or 0) * 100) end
        end
    end

    return contanti, banca, nero
end

-- ---------------------------------------------------------------------------
--  La migrazione
-- ---------------------------------------------------------------------------
local function migra(esegui, stampa)
    if not tabellaEsiste('users') then
        return stampa('Non trovo la tabella `users`: qui non c\'è un database ESX da migrare.')
    end

    -- La colonna di aggancio deve esserci
    local haColonna = MySQL.single.await([[
        SELECT COUNT(*) AS quante FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'personaggi' AND column_name = 'esx_identifier'
    ]])
    if not haColonna or tonumber(haColonna.quante or 0) == 0 then
        return stampa('Manca la colonna personaggi.esx_identifier: esegui prima sql/esx/01_lavori.sql.')
    end

    local utenti = MySQL.query.await('SELECT * FROM users LIMIT 5000') or {}
    if #utenti == 0 then return stampa('La tabella `users` è vuota: niente da migrare.') end

    local comuni = {}
    for _, p in ipairs(C.Province) do comuni[#comuni + 1] = p end

    local fatti, saltati, errori = 0, 0, 0

    for _, u in ipairs(utenti) do
        local identificatore = u.identifier
        if not identificatore or identificatore == '' then
            errori = errori + 1
        else
            local gia = MySQL.scalar.await(
                'SELECT citizenid FROM personaggi WHERE esx_identifier = ? LIMIT 1', { identificatore })

            if gia then
                saltati = saltati + 1
            else
                local nome, cognome = spezzaNome(u)
                local nascita = dataValida(u.dateofbirth)
                local sesso = (tostring(u.sex or 'm'):lower() == 'f') and 'F' or 'M'
                local contanti, banca, nero = saldiDa(u)

                local provincia = comuni[math.random(#comuni)]
                local lavoro = AUREA.Lavori[u.job] and u.job or 'disoccupato'
                local grado = tonumber(u.job_grade) or 0
                if not (AUREA.Lavori[lavoro].gradi[grado]) then grado = 0 end

                if not esegui then
                    fatti = fatti + 1
                else
                    local ok, errore = pcall(function()
                        local license = tostring(identificatore):gsub('^license2?:', '')

                        local account = MySQL.single.await('SELECT * FROM account WHERE license = ?', { license })
                        if not account then
                            local id = MySQL.insert.await(
                                'INSERT INTO account (license, nome_discord, slot_massimi) VALUES (?, ?, ?)',
                                { license, ('%s %s'):format(nome, cognome), C.Server.slotBase })
                            account = { id = id }
                        end

                        local citizenid = AUREA.Anagrafe.NuovoCitizenId(provincia.sigla)
                        local cf = AUREA.Anagrafe.NuovoCodiceFiscale(cognome, nome, nascita, sesso, provincia.comune)
                        local telefono = AUREA.Anagrafe.NuovoTelefono()
                        local iban = AUREA.Anagrafe.NuovoIBAN(account.id)

                        local quanti = MySQL.scalar.await(
                            'SELECT COUNT(*) FROM personaggi WHERE account_id = ? AND eliminato = 0',
                            { account.id }) or 0

                        MySQL.insert.await([[
                            INSERT INTO personaggi
                                (citizenid, account_id, slot, nome, cognome, data_nascita, luogo_nascita,
                                 sesso, codice_fiscale, telefono, contanti, banca, lavoro, lavoro_grado,
                                 posizione, stato, metadata, esx_identifier)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ]], {
                            citizenid, account.id, quanti + 1, nome, cognome, nascita, provincia.comune,
                            sesso, cf, telefono, contanti, banca, lavoro, grado,
                            json.encode(C.Avvio.posizione),
                            json.encode({ fame = 100, sete = 100, stress = 0, salute = 200,
                                          armatura = 0, alcol = 0, energia = 100 }),
                            json.encode({ iban = iban }),
                            identificatore,
                        })

                        MySQL.insert.await(
                            'INSERT INTO conti (iban, intestatario, tipo, nome, saldo) VALUES (?, ?, ?, ?, ?)',
                            { iban, citizenid, 'personale', 'Conto corrente', banca })

                        TriggerEvent('aurea:inventario:corredoIniziale', citizenid, C.Avvio.corredo)

                        -- Il nero ESX diventa banconote, arrotondate per difetto
                        local unita = math.floor(nero / ESXC.Nero.valoreUnita)
                        if unita > 0 then
                            TriggerEvent('aurea:inventario:aggiungi', citizenid, ESXC.Nero.oggetto, unita)
                        end
                    end)

                    if ok then fatti = fatti + 1 else errori = errori + 1
                        print(('[es_extended] migrazione di %s fallita: %s'):format(identificatore, tostring(errore)))
                    end

                    -- Un utente per volta, con respiro: la migrazione non
                    -- deve inchiodare il server se ce ne sono migliaia
                    Wait(20)
                end
            end
        end
    end

    stampa(('%s — %d utenti in `users`: %d %s, %d già migrati, %d errori.'):format(
        esegui and 'MIGRAZIONE ESEGUITA' or 'PROVA (nessuna scrittura)',
        #utenti, fatti, esegui and 'creati' or 'da creare', saltati, errori))

    if not esegui then
        stampa('Per scrivere davvero: /migraesx esegui — e fai un backup del database prima.')
    end
end

-- ---------------------------------------------------------------------------
--  Comando
-- ---------------------------------------------------------------------------
AUREA.Comando('migraesx', 'gestore',
    'Migra i personaggi dal database ESX (users) ad AUREA', {
        { name = 'esegui', help = 'scrivi "esegui" per procedere davvero' },
    },
    function(src, args)
        local esegui = args[1] == 'esegui'

        local function stampa(testo)
            if src > 0 then
                TriggerClientEvent('aurea:ui:notifica', src, {
                    tipo = esegui and 'successo' or 'info', icona = '🗃', durata = 22000,
                    titolo = 'Migrazione da ESX', testo = testo,
                })
            end
            print('[es_extended] ' .. testo)
        end

        -- migra() aspetta fra un utente e l'altro: gli serve un thread suo
        CreateThread(function() migra(esegui, stampa) end)
    end)
