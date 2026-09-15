--[[
    AUREA · Traffico di rifiuti (server)

    Il registro di carico e scarico è la cosa che regge tutto: quanti
    chili hai prodotto, quanti ne hai smaltiti con un formulario. La
    differenza fra i due numeri è quello che hai buttato da qualche parte,
    e non si può cancellare — si può solo non farla crescere.

    Chi indaga non trova i rifiuti: trova il buco nel registro. È così
    che funziona, ed è molto più difficile da nascondere di un camion.
]]

local U = AUREA.Util

local siti = {}         -- [sitoId] = { chili, contaminazione, ultimoScarico }

-- ---------------------------------------------------------------------------
--  Registro del produttore
-- ---------------------------------------------------------------------------
local function registro(citizenid)
    local r = MySQL.single.await('SELECT * FROM rifiuti_registro WHERE citizenid = ?', { citizenid })
    if r then return r end
    MySQL.insert.await('INSERT IGNORE INTO rifiuti_registro (citizenid) VALUES (?)', { citizenid })
    return { citizenid = citizenid, prodotti = 0, smaltiti = 0, in_carico = 0, scaricati = 0 }
end

local function produci(citizenid, chili, codice)
    MySQL.query.await([[
        INSERT INTO rifiuti_registro (citizenid, prodotti, in_carico, ultimo_codice)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            prodotti = prodotti + VALUES(prodotti),
            in_carico = in_carico + VALUES(in_carico),
            ultimo_codice = VALUES(ultimo_codice)
    ]], { citizenid, chili, chili, codice })
end

--- I moduli che fanno lavorare qualcuno chiamano questo. Non sanno cosa
--- sia un formulario, e non devono saperlo.
AddEventHandler('aurea:rifiuti:prodotti', function(citizenid, lavoro, moltiplicatore)
    local p = RIF.ProduzionePer(lavoro)
    if not p or type(citizenid) ~= 'string' then return end
    produci(citizenid, math.ceil(p.chiliPerAzione * (tonumber(moltiplicatore) or 1)), p.codice)
end)

exports('RegistroDi', function(citizenid)
    local r = registro(citizenid)
    return {
        prodotti = r.prodotti, smaltiti = r.smaltiti,
        inCarico = r.in_carico, scaricati = r.scaricati,
        codice = r.ultimo_codice,
        buco = math.max(0, r.prodotti - r.smaltiti - r.in_carico),
    }
end)

-- ---------------------------------------------------------------------------
--  Siti
-- ---------------------------------------------------------------------------
local function sito(id)
    if siti[id] then return siti[id] end
    local r = MySQL.single.await('SELECT * FROM rifiuti_siti WHERE sito = ?', { id })
    siti[id] = {
        chili = r and tonumber(r.chili) or 0,
        contaminazione = r and tonumber(r.contaminazione) or 0,
        segnalato = r and r.segnalato == 1 or false,
    }
    return siti[id]
end

local function salvaSito(id)
    local s = siti[id]
    MySQL.query.await([[
        INSERT INTO rifiuti_siti (sito, chili, contaminazione, segnalato) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE chili = VALUES(chili),
                                contaminazione = VALUES(contaminazione),
                                segnalato = VALUES(segnalato)
    ]], { id, math.floor(s.chili), math.floor(s.contaminazione), s.segnalato and 1 or 0 })
end

local function sitoVicino(coord)
    for _, s in ipairs(RIF.Siti) do
        if #(coord - s.coord) <= 12.0 then return s end
    end
end

local function pubblica()
    local elenco = {}
    for _, s in ipairs(RIF.Siti) do
        local st = sito(s.id)
        if st.chili >= RIF.Discarica.chiliVisibile then
            elenco[#elenco + 1] = { id = s.id, contaminazione = math.floor(st.contaminazione) }
        end
    end
    TriggerClientEvent('rif:siti', -1, elenco)
end

-- ---------------------------------------------------------------------------
--  Smaltimento regolare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rif:smaltisci', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - RIF.Impianto.coord) > RIF.Impianto.raggio + 4.0 then
        return rispondi(false, 'Devi essere all\'impianto.')
    end

    local r = registro(g.citizenid)
    local chili = math.min(r.in_carico, RIF.Formulario.chiliMassimiAddosso)
    if chili < RIF.Formulario.chiliMinimi then
        return rispondi(false, ('Hai %d kg in carico: sotto i %d non si apre un formulario.')
            :format(r.in_carico, RIF.Formulario.chiliMinimi))
    end

    local costo = chili * RIF.Impianto.costoAlChilo
    if not g:Sottrai('banca', costo, 'smaltimento rifiuti speciali') then
        return rispondi(false, ('Lo smaltimento costa %s per %d kg.'):format(U.Euro(costo), chili))
    end
    TriggerEvent('aurea:fisco:incasso', 'ambiente', costo, g.citizenid)

    MySQL.update.await([[
        UPDATE rifiuti_registro SET smaltiti = smaltiti + ?, in_carico = in_carico - ?
        WHERE citizenid = ?
    ]], { chili, chili, g.citizenid })

    local numero = MySQL.insert.await(
        'INSERT INTO rifiuti_formulari (produttore, chili, codice, costo) VALUES (?, ?, ?, ?)',
        { g.citizenid, chili, r.ultimo_codice or 'CER 20', costo })

    AUREA.Log('economia', 'info', g, ('ha smaltito %d kg con formulario %d'):format(chili, numero))
    rispondi(true, ('Formulario n. %d.\n%d kg conferiti, %s.\nIl registro è in pari per questo carico.')
        :format(numero, chili, U.Euro(costo)))
end)

-- ---------------------------------------------------------------------------
--  Scarico abusivo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rif:scarica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = sitoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not s then return rispondi(false, 'Qui non c\'è dove scaricare.') end

    local r = registro(g.citizenid)
    local chili = math.min(r.in_carico, RIF.Formulario.chiliMassimiAddosso)
    if chili <= 0 then return rispondi(false, 'Non hai niente in carico.') end

    local compenso = chili * RIF.Discarica.compensoAlChilo
    local st = sito(s.id)

    st.chili = st.chili + chili
    st.contaminazione = math.min(100,
        st.contaminazione + (chili / 100) * RIF.Discarica.contaminazionePerCentoChili)
    salvaSito(s.id)

    MySQL.update.await([[
        UPDATE rifiuti_registro SET in_carico = in_carico - ?, scaricati = scaricati + ?
        WHERE citizenid = ?
    ]], { chili, chili, g.citizenid })

    MySQL.insert('INSERT INTO rifiuti_scarichi (sito, autore, chili) VALUES (?, ?, ?)',
        { s.id, g.citizenid, chili })

    -- Chi risparmia sullo smaltimento incassa la differenza
    g:Aggiungi('contanti', compenso, 'smaltimento fuori impianto')

    TriggerEvent('aurea:famiglie:calore', g.citizenid, RIF.Reati.calorePerScarico, 'traffico di rifiuti')

    pubblica()
    AUREA.Log('giustizia', 'avviso', g,
        ('ha scaricato %d kg di rifiuti speciali su %s'):format(chili, s.id))

    rispondi(true, ('%d kg lasciati a %s. Risparmiati %s, e il registro adesso non torna.')
        :format(chili, s.nome, U.Euro(compenso)))
end)

-- ---------------------------------------------------------------------------
--  Il controllo: si legge il registro, non si cercano i sacchi
-- ---------------------------------------------------------------------------
AUREA.Comando('controlloregistro', 'utente', 'Verifica il registro di carico e scarico di un soggetto', {
    { name = 'id', help = 'ID della persona' },
}, function(src, args, _, g)
    local ammesso = false
    for _, l in ipairs(RIF.Vigilanza) do
        if g and g.lavoro.nome == l and g.lavoro.servizio then ammesso = true end
    end
    if not ammesso then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '♻', titolo = 'Non autorizzato',
            testo = 'Il controllo lo fa il Nucleo Tutela Ambientale in servizio.' })
    end

    local b = AUREA.GetPlayer(tonumber(args[1]))
    if not b then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '♻', titolo = 'Nessuno', testo = 'ID non trovato.' })
    end

    local r = registro(b.citizenid)
    local buco = math.max(0, r.prodotti - r.smaltiti - r.in_carico)

    if buco <= 0 then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '♻', durata = 18000,
            titolo = ('Registro di %s'):format(b:NomeCompleto()),
            testo = ('Prodotti %d kg · smaltiti %d kg · in carico %d kg.\nIl registro torna.')
                :format(r.prodotti, r.smaltiti, r.in_carico),
        })
    end

    local organizzato = r.scaricati >= RIF.Reati.sogliaOrganizzato
    local reato = organizzato and RIF.Reati.organizzato or RIF.Reati.gestione
    local sanzione = buco * RIF.Reati.sanzioneAlChilo

    TriggerEvent('aurea:giustizia:apriFascicolo', b.citizenid, reato, g:NomeCompleto(),
        ('Registro di carico e scarico: %d kg prodotti, %d smaltiti con formulario. Differenza non tracciata %d kg.')
            :format(r.prodotti, r.smaltiti, buco))

    exports.ita_fisco:IscriviTributo(b.citizenid, 'sanzione',
        'gestione non autorizzata di rifiuti', sanzione, 7)

    AUREA.Log('giustizia', 'avviso', g,
        ('ha contestato %d kg non tracciati a %s'):format(buco, b:NomeCompleto()))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '♻', durata = 25000,
        titolo = ('Registro di %s'):format(b:NomeCompleto()),
        testo = ('Prodotti %d kg · smaltiti %d · in carico %d.\nNON TRACCIATI: %d kg.\n%s\nSanzione %s.')
            :format(r.prodotti, r.smaltiti, r.in_carico, buco,
                    organizzato and 'Volume tale da configurare il traffico organizzato (art. 452-quaterdecies c.p.).'
                        or 'Gestione non autorizzata (art. 256 D.Lgs. 152/2006).',
                    U.Euro(sanzione)),
    })
end)

-- ---------------------------------------------------------------------------
--  Sopralluogo su un sito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rif:sopralluogo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local s = sitoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not s then return rispondi(nil) end
    local st = sito(s.id)

    local ammesso = false
    for _, l in ipairs(RIF.Vigilanza) do
        if g.lavoro.nome == l and g.lavoro.servizio then ammesso = true end
    end

    -- Gli autori li vede solo chi indaga: per gli altri è solo immondizia
    local autori = {}
    if ammesso then
        autori = MySQL.query.await([[
            SELECT CONCAT(p.nome, ' ', p.cognome) AS nome, SUM(x.chili) AS chili
            FROM rifiuti_scarichi x
            LEFT JOIN personaggi p ON p.citizenid = x.autore
            WHERE x.sito = ? GROUP BY x.autore ORDER BY chili DESC LIMIT 8
        ]], { s.id }) or {}
    end

    rispondi({
        id = s.id, nome = s.nome,
        chili = math.floor(st.chili), contaminazione = math.floor(st.contaminazione),
        costoBonifica = math.floor(st.chili) * RIF.Bonifica.costoAlChilo,
        ammesso = ammesso, autori = autori,
    })
end)

-- ---------------------------------------------------------------------------
--  Bonifica
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rif:bonifica', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local s = sitoVicino(GetEntityCoords(GetPlayerPed(src)))
    if not s then return rispondi(false, 'Non sei su un sito.') end

    local st = sito(s.id)
    if st.chili <= 0 then return rispondi(false, 'Il sito è pulito.') end

    local chili = math.min(st.chili, RIF.Bonifica.chiliPerLotto)
    st.chili = st.chili - chili
    st.contaminazione = math.max(0,
        st.contaminazione - (chili / 100) * RIF.Discarica.contaminazionePerCentoChili)
    if st.chili < RIF.Discarica.chiliVisibile then st.segnalato = false end
    salvaSito(s.id)

    g:Aggiungi('banca', RIF.Bonifica.compensoPerLotto, 'bonifica ambientale')
    TriggerEvent('aurea:fisco:erogazione', 'bonifiche',
        RIF.Bonifica.compensoPerLotto + chili * RIF.Bonifica.costoAlChilo, g.citizenid)

    pubblica()

    rispondi(true, ('%d kg rimossi. Restano %d kg, contaminazione %d%%.\nCompenso %s.')
        :format(chili, math.floor(st.chili), math.floor(st.contaminazione),
                U.Euro(RIF.Bonifica.compensoPerLotto)))
end)

-- ---------------------------------------------------------------------------
--  Le segnalazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(60000)
    while true do
        Wait(RIF.Discarica.controlloMinuti * 60000)

        for _, s in ipairs(RIF.Siti) do
            local st = sito(s.id)
            if st.chili >= RIF.Discarica.chiliVisibile and not st.segnalato
                and math.random() < RIF.Discarica.probabilitaSegnalazione then

                st.segnalato = true
                salvaSito(s.id)

                for _, lavoro in ipairs(RIF.Vigilanza) do
                    exports.aurea_ui:NotificaLavoro(lavoro, {
                        tipo = 'avviso', icona = '♻', durata = 20000,
                        titolo = 'Segnalazione di abbandono di rifiuti',
                        testo = ('%s: cumulo visibile, contaminazione stimata %d%%. Sopralluogo sul posto.')
                            :format(s.nome, math.floor(st.contaminazione)),
                    }, true)
                end

                exports.aurea_ui:NotificaLavoro('comune', {
                    tipo = 'avviso', icona = '♻', durata = 18000,
                    titolo = 'Sito da bonificare',
                    testo = ('%s. Costo stimato della bonifica: %s.')
                        :format(s.nome, U.Euro(math.floor(st.chili) * RIF.Bonifica.costoAlChilo)),
                }, false)

                AUREA.Log('economia', 'avviso', nil,
                    ('Discarica abusiva segnalata su %s (%d kg)'):format(s.id, math.floor(st.chili)))
            end
        end

        pubblica()
    end
end)

-- ---------------------------------------------------------------------------
--  Il proprio registro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('rif:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local r = registro(g.citizenid)
    local formulari = MySQL.query.await(
        'SELECT id, chili, codice, costo, emesso_il FROM rifiuti_formulari WHERE produttore = ? ORDER BY id DESC LIMIT 10',
        { g.citizenid }) or {}

    for _, x in ipairs(formulari) do
        x.quando = U.DataOraIT(math.floor((x.emesso_il or 0) / 1000))
    end

    rispondi({
        prodotti = r.prodotti, smaltiti = r.smaltiti,
        inCarico = r.in_carico, scaricati = r.scaricati,
        codice = r.ultimo_codice,
        buco = math.max(0, r.prodotti - r.smaltiti - r.in_carico),
        formulari = formulari,
    })
end)

AureaApp({
    id = 'rifiuti',
    nome = 'Rifiuti',
    icona = '♻',
    colore = 'linear-gradient(150deg,#4e8f74,#27483c)',
    ordine = 142,

    condizione = function(g) return RIF.ProduzionePer(g.lavoro.nome) ~= nil end,

    schermata = function(g)
        local r = registro(g.citizenid)
        local buco = math.max(0, r.prodotti - r.smaltiti - r.in_carico)

        local voci = {
            { icona = '🏭', titolo = 'Prodotti', valore = ('%d kg'):format(r.prodotti), inerte = true },
            { icona = '✅', titolo = 'Smaltiti con formulario', valore = ('%d kg'):format(r.smaltiti),
              tono = 'verde', inerte = true },
            { icona = '📦', titolo = 'In carico adesso', valore = ('%d kg'):format(r.in_carico),
              sottotitolo = ('Smaltirli costa %s'):format(U.Euro(r.in_carico * RIF.Impianto.costoAlChilo)),
              inerte = true },
        }

        if buco > 0 then
            voci[#voci + 1] = {
                icona = '⚠', titolo = 'Non tracciati', valore = ('%d kg'):format(buco),
                sottotitolo = 'La differenza fra prodotto e smaltito. Un controllo la vede.',
                tono = 'rosso', inerte = true,
            }
        end

        for _, x in ipairs(MySQL.query.await(
            'SELECT id, chili, codice FROM rifiuti_formulari WHERE produttore = ? ORDER BY id DESC LIMIT 6',
            { g.citizenid }) or {}) do
            voci[#voci + 1] = { icona = '📄', titolo = ('Formulario n. %d'):format(x.id),
                sottotitolo = ('%s · %d kg'):format(x.codice or 'CER', x.chili), inerte = true }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Rifiuti speciali in carico',
            valore = ('%d kg'):format(r.in_carico),
            nota = buco > 0 and ('%d kg non tracciati'):format(buco) or 'Registro in pari',
            voci = voci,
        }
    end,
})

AddEventHandler('aurea:giocatore:caricato', function(src)
    CreateThread(function() Wait(6000) pubblica() end)
end)

print('[AUREA] rifiuti: registro di carico e scarico attivo')
