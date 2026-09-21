--[[
    AUREA · Rimozione e depositeria (server)

    La diurnaria è un contatore, non un prezzo: si calcola al riscatto
    sui minuti effettivamente trascorsi. Nessuno la aggiorna, nessun
    thread la incrementa. È solo una sottrazione fra due date, ed è il
    motivo per cui non può mai andare fuori sincrono.

    L'alienazione invece è un evento, e quello sì ha bisogno di un giro
    periodico: c'è un momento preciso in cui la macchina smette di
    essere tua.
]]

local U = AUREA.Util

local function operatore(g)
    return g and g.lavoro.nome == CAR.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(CAR.Permesso)
end

local function autorita(g)
    return g and g.lavoro.servizio and U.Contiene(CAR.Dispone, g.lavoro.nome)
end

local function inDepositeria(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - CAR.Deposito.coord) <= 12.0
end

-- ---------------------------------------------------------------------------
--  Lettura
-- ---------------------------------------------------------------------------
local function rimozioneAperta(targa)
    return MySQL.single.await([[
        SELECT id, targa, citizenid, motivo, costo_rimozione, deposito,
               TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
        FROM rimozioni WHERE targa = ? AND stato = 'in_deposito'
    ]], { targa })
end

--- Lo chiede aurea_garage: un veicolo in depositeria non si tira fuori
--- dal garage, si riscatta.
exports('InDepositeria', function(targa)
    local r = rimozioneAperta(targa)
    if not r then return false end
    return true, CAR.Riscatto(r.costo_rimozione, r.minuti), r.motivo
end)

exports('RimozioniDi', function(citizenid)
    local righe = MySQL.query.await([[
        SELECT id, targa, motivo, costo_rimozione,
               TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
        FROM rimozioni WHERE citizenid = ? AND stato = 'in_deposito'
    ]], { citizenid }) or {}
    for _, r in ipairs(righe) do
        r.dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)
    end
    return righe
end)

-- ---------------------------------------------------------------------------
--  Disporre la rimozione
--
--  L'ordine lo dà l'autorità, e l'ordine resta anche se il carro
--  attrezzi arriva mezz'ora dopo. Qui le due cose sono un'azione sola
--  perché al momento della rimozione chi guida il carro c'è per forza.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:rimuovi', function(src, rispondi, targa, motivoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local puo = operatore(g) or autorita(g)
    if not puo then
        return rispondi(false, 'La rimozione la fa il carro attrezzi, su ordine dell\'autorità.')
    end

    local motivo = CAR.GetMotivo(motivoId)
    if not motivo then return rispondi(false, 'Motivo non previsto.') end

    targa = tostring(targa or ''):upper():gsub('%s+', '')
    if targa == '' then return rispondi(false, 'Targa non leggibile.') end

    if rimozioneAperta(targa) then
        return rispondi(false, 'Questo veicolo risulta già in depositeria.')
    end

    local v = MySQL.single.await(
        'SELECT targa, citizenid, modello, categoria, stato FROM veicoli WHERE targa = ?', { targa })
    if not v then return rispondi(false, 'Veicolo non immatricolato: non si rimuove, si segnala.') end
    if v.stato == 'sequestrato' then
        return rispondi(false, 'Il veicolo è già sotto provvedimento.')
    end

    local costo = CAR.CostoRimozione(v.categoria)

    -- Il verbale che accompagna la rimozione. La rimozione non lo
    -- sostituisce: chi ha parcheggiato male paga tutte e due le cose.
    local infrazione = AUREA.Infrazioni[motivo.infrazione]
    local verbaleId
    if infrazione then
        verbaleId = exports.ita_codicestrada:EmettiVerbale({
            citizenid = v.citizenid,
            targa = targa,
            articolo = infrazione.articolo,
            descrizione = ('%s — rimozione forzata (art. 159 CdS)'):format(motivo.nome),
            importo = infrazione.importo,
            punti = infrazione.punti,
            origine = 'sosta',
            agente = g:NomeCompleto(),
            luogo = motivo.nome,
        })
    end

    MySQL.insert.await([[
        INSERT INTO rimozioni
            (targa, citizenid, motivo, multa_id, operatore, deposito, costo_rimozione, diurnaria)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { targa, v.citizenid, motivo.nome, verbaleId, g.citizenid,
          CAR.Deposito.garage, costo, CAR.Costi.diurnaria })

    MySQL.update.await([[
        UPDATE veicoli SET stato = 'sequestrato', garage = ? WHERE targa = ?
    ]], { CAR.Deposito.garage, targa })

    -- Quota all'operatore, il resto alla ditta
    local quota = math.floor(costo * CAR.Costi.quotaOperatore)
    g:Aggiungi('banca', quota, ('rimozione %s'):format(targa))
    pcall(function()
        exports.aurea_azienda:VersaInCassa(CAR.Lavoro, costo - quota, 'rimozioni')
    end)

    TriggerEvent('aurea:telefono:messaggioSistema', v.citizenid, 'Depositeria',
        ('Il veicolo %s è stato rimosso: %s. Rimozione %s più %s al giorno di custodia. Si riscatta in depositeria.')
            :format(targa, motivo.nome, U.Euro(costo), U.Euro(CAR.Costi.diurnaria)))

    local proprietario = AUREA.GetPlayerByCitizenId(v.citizenid)
    if proprietario then
        TriggerClientEvent('aurea:ui:notifica', proprietario.source, {
            tipo = 'errore', icona = '🚛', durata = 20000,
            titolo = ('Veicolo rimosso — %s'):format(targa),
            testo = ('%s.\nOgni %d minuti in deposito costano %s. Non lasciarlo lì.')
                :format(motivo.nome, CAR.Costi.minutiPerGiorno, U.Euro(CAR.Costi.diurnaria)),
        })
    end

    AUREA.Log('veicoli', 'avviso', g, ('rimosso %s: %s'):format(targa, motivo.nome))

    rispondi(true, ('%s rimosso e portato in depositeria.\nRimozione %s, la tua quota è %s.')
        :format(targa, U.Euro(costo), U.Euro(quota)))
end)

-- ---------------------------------------------------------------------------
--  Riscatto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('car:deposito', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local miei = MySQL.query.await([[
        SELECT id, targa, motivo, costo_rimozione, diurnaria,
               TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
        FROM rimozioni WHERE citizenid = ? AND stato = 'in_deposito'
        ORDER BY rimossa_il ASC
    ]], { g.citizenid }) or {}

    for _, r in ipairs(miei) do
        r.giorni = CAR.Giorni(r.minuti)
        r.dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)
        r.custodia = r.giorni * r.diurnaria
        r.giorniAllAlienazione = math.max(0, CAR.Costi.giorniPrimaDellAlienazione - r.giorni)
    end

    -- Chi lavora in depositeria vede tutto il piazzale
    local tutti = {}
    if operatore(g) then
        tutti = MySQL.query.await([[
            SELECT r.targa, r.motivo, r.costo_rimozione, r.diurnaria,
                   TIMESTAMPDIFF(MINUTE, r.rimossa_il, NOW()) AS minuti,
                   CONCAT(p.nome, ' ', p.cognome) AS intestatario
            FROM rimozioni r
            LEFT JOIN personaggi p ON p.citizenid = r.citizenid
            WHERE r.stato = 'in_deposito' ORDER BY r.rimossa_il ASC LIMIT 30
        ]]) or {}
        for _, r in ipairs(tutti) do
            r.giorni = CAR.Giorni(r.minuti)
            r.dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)
        end
    end

    rispondi({ miei = miei, piazzale = tutti, operatore = operatore(g) })
end)

AUREA.Callback.Registra('car:riscatta', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inDepositeria(src) then return rispondi(false, 'Il veicolo si riscatta in depositeria.') end

    local r = MySQL.single.await([[
        SELECT id, targa, citizenid, costo_rimozione, motivo,
               TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
        FROM rimozioni WHERE id = ? AND stato = 'in_deposito'
    ]], { tonumber(id) })
    if not r then return rispondi(false, 'Non risulta in deposito.') end
    if r.citizenid ~= g.citizenid then return rispondi(false, 'Non è intestato a te.') end

    local dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)

    -- Sopra una certa cifra non si paga allo sportello: il conto va a
    -- ruolo, il veicolo esce lo stesso, e da lì se ne occupa la
    -- riscossione. È come funziona, ed è anche l'unico modo perché
    -- qualcuno non perda la macchina per sempre.
    if dovuto >= CAR.Costi.sogliaRuolo then
        local iscritto
        pcall(function()
            iscritto = exports.ita_riscossione:IscriviARuolo(g.citizenid, 'sanzione', r.id,
                ('Rimozione e custodia del veicolo %s'):format(r.targa), dovuto)
        end)

        if iscritto then
            MySQL.update.await([[
                UPDATE rimozioni SET stato = 'riscattato', riscattata_il = NOW(), pagato = 0 WHERE id = ?
            ]], { r.id })
            MySQL.update.await(
                'UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ?', { r.targa })

            return rispondi(true, ('Il debito di %s è stato messo a ruolo: il veicolo esce, la cartella arriva.\nNon è un condono.')
                :format(U.Euro(dovuto)))
        end
    end

    if not g:SottraiOvunque(dovuto, ('riscatto del veicolo %s'):format(r.targa)) then
        return rispondi(false, ('Servono %s: %s di rimozione e %s di custodia per %d giorni.')
            :format(U.Euro(dovuto), U.Euro(r.costo_rimozione),
                    U.Euro(dovuto - r.costo_rimozione), CAR.Giorni(r.minuti)))
    end

    pcall(function()
        exports.aurea_azienda:VersaInCassa(CAR.Lavoro, math.floor(dovuto * 0.4), 'custodia')
    end)
    TriggerEvent('aurea:fisco:incasso', 'depositeria', math.floor(dovuto * 0.6), g.citizenid)

    MySQL.update.await([[
        UPDATE rimozioni SET stato = 'riscattato', riscattata_il = NOW(), pagato = ? WHERE id = ?
    ]], { dovuto, r.id })
    MySQL.update.await(
        'UPDATE veicoli SET stato = \'garage\', garage = \'centrale\' WHERE targa = ?', { r.targa })

    AUREA.Log('veicoli', 'info', g, ('riscattato %s per %s'):format(r.targa, U.Euro(dovuto)))

    rispondi(true, ('%s riscattato per %s. Lo trovi al garage centrale.'):format(r.targa, U.Euro(dovuto)))
end)

-- ---------------------------------------------------------------------------
--  Alienazione
--
--  Il momento in cui la macchina smette di essere tua. Non è un
--  sequestro e non è una confisca: è che è rimasta lì troppo a lungo e
--  la custodia è costata più di quanto vale.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(180000)

        local scadute = MySQL.query.await([[
            SELECT id, targa, citizenid, costo_rimozione,
                   TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
            FROM rimozioni WHERE stato = 'in_deposito'
              AND TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) >= ?
        ]], { CAR.Costi.giorniPrimaDellAlienazione * CAR.Costi.minutiPerGiorno }) or {}

        for _, r in ipairs(scadute) do
            MySQL.update.await('UPDATE rimozioni SET stato = ? WHERE id = ?', { 'alienato', r.id })
            MySQL.update.await('UPDATE veicoli SET stato = ? WHERE targa = ?', { 'demolito', r.targa })

            -- Quello che la vendita non copre resta un debito
            local dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)
            local ricavo = 0
            pcall(function()
                ricavo = math.floor((exports.ita_veicoli:ValoreVeicolo(r.targa) or 0) * 0.35)
            end)

            local residuo = dovuto - ricavo
            if residuo > 0 and r.citizenid then
                pcall(function()
                    exports.ita_riscossione:IscriviARuolo(r.citizenid, 'sanzione', r.id,
                        ('Custodia non pagata del veicolo %s'):format(r.targa), residuo)
                end)
            end

            TriggerEvent('aurea:telefono:messaggioSistema', r.citizenid, 'Depositeria',
                ('Il veicolo %s è stato alienato: era in custodia da troppo tempo. Ricavo %s a scomputo, resta %s.')
                    :format(r.targa, U.Euro(ricavo), U.Euro(math.max(0, residuo))))

            AUREA.Log('veicoli', 'avviso', nil, ('alienato %s dopo %d minuti di custodia')
                :format(r.targa, r.minuti))
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App del telefono
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'depositeria',
    nome = 'Depositeria',
    icona = '🚛',
    colore = 'linear-gradient(150deg,#7a6a4a,#3c3324)',
    ordine = 140,

    condizione = function(g)
        return (MySQL.scalar.await(
            'SELECT COUNT(*) FROM rimozioni WHERE citizenid = ? AND stato = ?',
            { g.citizenid, 'in_deposito' }) or 0) > 0
    end,

    badge = function(g)
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM rimozioni WHERE citizenid = ? AND stato = ?',
            { g.citizenid, 'in_deposito' }) or 0
    end,

    schermata = function(g)
        local righe = MySQL.query.await([[
            SELECT targa, motivo, costo_rimozione, diurnaria,
                   TIMESTAMPDIFF(MINUTE, rimossa_il, NOW()) AS minuti
            FROM rimozioni WHERE citizenid = ? AND stato = 'in_deposito'
        ]], { g.citizenid }) or {}

        local voci, totale = {}, 0
        for _, r in ipairs(righe) do
            local giorni = CAR.Giorni(r.minuti)
            local dovuto = CAR.Riscatto(r.costo_rimozione, r.minuti)
            totale = totale + dovuto

            voci[#voci + 1] = {
                icona = '🚛', titolo = r.targa,
                sottotitolo = ('%s\n%d giorni di custodia · ne restano %d prima dell\'alienazione')
                    :format(r.motivo, giorni,
                            math.max(0, CAR.Costi.giorniPrimaDellAlienazione - giorni)),
                valore = U.Euro(dovuto), tono = 'rosso', inerte = true,
            }
        end

        return {
            tipo = 'saldo',
            etichetta = 'Da pagare per riavere i veicoli',
            valore = U.Euro(totale),
            nota = ('La custodia costa %s ogni %d minuti, e non smette da sola.')
                :format(U.Euro(CAR.Costi.diurnaria), CAR.Costi.minutiPerGiorno),
            voci = voci,
        }
    end,
})
