--[[
    AUREA · Donazione di sangue (server)

    Le scorte sono una tabella sola, condivisa da tutti. Non c'è una copia
    per giocatore e non c'è un numero nascosto: se il gruppo 0 negativo è
    a zero, è a zero per chiunque, e resta a zero finché qualcuno non
    dona. È l'unica risorsa del server in cui la scarsità è letteralmente
    la somma di quello che la gente ha dato.
]]

local U = AUREA.Util

local function sanitario(g)
    return g and g.lavoro.servizio and U.Contiene(SAN.Trasfusione.lavoriAbilitati, g.lavoro.nome)
end

local function alCentro(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - SAN.Centro.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Il donatore
-- ---------------------------------------------------------------------------
local function donatore(citizenid)
    local d = MySQL.single.await('SELECT * FROM donatori WHERE citizenid = ?', { citizenid })
    if d then return d end

    -- Prima volta: il gruppo si scopre qui, e da qui in poi è quello
    local gruppo = SAN.GruppoDi(citizenid)
    MySQL.insert.await([[
        INSERT INTO donatori (citizenid, gruppo, iscritto_il, idoneo, prossima_donazione, donazioni)
        VALUES (?, ?, CURDATE(), 1, NULL, 0)
    ]], { citizenid, gruppo })

    return MySQL.single.await('SELECT * FROM donatori WHERE citizenid = ?', { citizenid })
end

--- Il gruppo di una persona. Lo chiede chi deve fare una trasfusione.
exports('GruppoDi', function(citizenid)
    local d = MySQL.scalar.await('SELECT gruppo FROM donatori WHERE citizenid = ?', { citizenid })
    return d or SAN.GruppoDi(citizenid)
end)

local function scorte()
    local righe = MySQL.query.await('SELECT gruppo, sacche FROM scorte_sangue ORDER BY gruppo') or {}
    local out = {}
    for _, r in ipairs(righe) do
        out[#out + 1] = { gruppo = r.gruppo, sacche = r.sacche,
                          carenza = r.sacche <= SAN.Scorte.sogliaCarenza }
    end
    return out
end

exports('Scorte', scorte)

-- ---------------------------------------------------------------------------
--  Donare
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('san:posizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local d = donatore(g.citizenid)
    local attesa = 0
    if d.prossima_donazione then
        attesa = math.max(0, math.floor((d.prossima_donazione / 1000 - os.time()) / 60))
    end

    rispondi({
        gruppo = d.gruppo,
        idoneo = d.idoneo == 1,
        motivo = d.motivo_sospensione,
        donazioni = d.donazioni,
        minutiAttesa = attesa,
        scorte = scorte(),
        costoSacca = SAN.Scorte.costoSacca,
        sanitario = sanitario(g),
    })
end)

AUREA.Callback.Registra('san:dona', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not alCentro(src) then return rispondi(false, 'Si dona al centro trasfusionale.') end

    local d = donatore(g.citizenid)
    if d.idoneo ~= 1 then
        return rispondi(false, ('Non sei idoneo: %s'):format(d.motivo_sospensione or 'sospensione in corso'))
    end
    if d.prossima_donazione and (d.prossima_donazione / 1000) > os.time() then
        local minuti = math.ceil((d.prossima_donazione / 1000 - os.time()) / 60)
        return rispondi(false, ('Devono passare ancora %d minuti dall\'ultima donazione.'):format(minuti))
    end

    local salute = GetEntityHealth(GetPlayerPed(src))
    if salute < (100 + SAN.Donazione.saluteMinima) then
        return rispondi(false, 'Non sei in condizioni di donare: torna quando stai meglio.')
    end

    MySQL.update.await([[
        UPDATE donatori
        SET donazioni = donazioni + 1,
            prossima_donazione = DATE_ADD(NOW(), INTERVAL ? MINUTE)
        WHERE citizenid = ?
    ]], { SAN.Donazione.minutiIntervallo, g.citizenid })

    MySQL.insert.await(
        'INSERT INTO donazioni_sangue (citizenid, gruppo, centro) VALUES (?, ?, ?)',
        { g.citizenid, d.gruppo, SAN.Centro.nome })

    MySQL.query.await([[
        INSERT INTO scorte_sangue (gruppo, sacche) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE sacche = LEAST(sacche + VALUES(sacche), ?)
    ]], { d.gruppo, SAN.Scorte.sacchePerDonazione, SAN.Scorte.massimoPerGruppo })

    g:Aggiungi('banca', SAN.Donazione.ristoro, 'rimborso per donazione')
    TriggerEvent('aurea:fisco:erogazione', 'sanita', SAN.Donazione.ristoro, g.citizenid)
    exports.aurea_inventory:Aggiungi(g.citizenid, SAN.Donazione.itemRistoro, 1)

    TriggerClientEvent('san:donato', src, SAN.Donazione.saluteSottratta)

    local ora = MySQL.scalar.await('SELECT sacche FROM scorte_sangue WHERE gruppo = ?', { d.gruppo }) or 0

    AUREA.Log('economia', 'info', g, ('donazione di sangue, gruppo %s'):format(d.gruppo))

    rispondi(true, ('Donazione registrata. Gruppo %s: in magazzino ci sono ora %d sacche.\nRimborso %s e un panino.')
        :format(d.gruppo, ora, U.Euro(SAN.Donazione.ristoro)))
end)

-- ---------------------------------------------------------------------------
--  Ritiro delle sacche
--
--  Il sangue non si vende. Quello che il 118 paga è la lavorazione, e
--  la differenza fra le due cose in Italia è sacra.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('san:ritira', function(src, rispondi, gruppo)
    local g = AUREA.GetPlayer(src)
    if not sanitario(g) then
        return rispondi(false, 'Le sacche le ritira chi è in servizio nella sanità.')
    end
    if not alCentro(src) then return rispondi(false, 'Si ritira al centro trasfusionale.') end

    local disponibili = MySQL.scalar.await('SELECT sacche FROM scorte_sangue WHERE gruppo = ?',
        { gruppo }) or 0
    if disponibili <= 0 then
        return rispondi(false, ('Del gruppo %s non c\'è una sacca. Serve che qualcuno doni.')
            :format(tostring(gruppo)))
    end

    local pagato = false
    pcall(function()
        pagato = exports.aurea_azienda:PrelevaDaCassa(g.lavoro.nome, SAN.Scorte.costoSacca,
            ('ritiro sacca %s'):format(gruppo)) == true
    end)
    if not pagato then
        if not g:Sottrai('banca', SAN.Scorte.costoSacca, 'ritiro di sacca di sangue') then
            return rispondi(false, ('Servono %s, dalla cassa del servizio o di tasca tua.')
                :format(U.Euro(SAN.Scorte.costoSacca)))
        end
    end
    TriggerEvent('aurea:fisco:incasso', 'sanita', SAN.Scorte.costoSacca, g.citizenid)

    MySQL.update.await('UPDATE scorte_sangue SET sacche = sacche - 1 WHERE gruppo = ? AND sacche > 0',
        { gruppo })

    exports.aurea_inventory:Aggiungi(g.citizenid, SAN.Trasfusione.item, 1, { gruppo = gruppo })

    rispondi(true, ('Ritirata una sacca di gruppo %s. Ne restano %d.')
        :format(gruppo, disponibili - 1))
end)

-- ---------------------------------------------------------------------------
--  La trasfusione
--
--  La sacca si usa dall'inventario. Il gruppo che porta nei metadata
--  deve essere compatibile con quello di chi la riceve, e chi la fa deve
--  saperla fare.
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(3000)

    exports.aurea_inventory:RegistraUso(SAN.Trasfusione.item, function(g, riga)
        local gruppoSacca = (riga.metadata or {}).gruppo
        if not gruppoSacca then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🩸', titolo = 'Sacca non identificata',
                testo = 'Nessun gruppo sull\'etichetta: non si trasfonde alla cieca.' })
            return false
        end

        local d = donatore(g.citizenid)
        local compatibile = SAN.Compatibili(d.gruppo, gruppoSacca)
        local qualificato = sanitario(g)

        if not compatibile then
            TriggerClientEvent('san:trasfusione', g.source, -SAN.Trasfusione.dannoReazione, true)
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🩸', durata = 18000,
                titolo = 'Reazione emolitica',
                testo = ('Il tuo gruppo è %s, la sacca è %s. Non erano compatibili, e adesso stai peggio.')
                    :format(d.gruppo, gruppoSacca) })
            AUREA.Log('giustizia', 'avviso', g, ('trasfusione incompatibile: %s con sacca %s')
                :format(d.gruppo, gruppoSacca))
            return true
        end

        if not qualificato then
            TriggerClientEvent('san:trasfusione', g.source, -SAN.Trasfusione.dannoSenzaQualifica, true)
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🩸', durata = 16000,
                titolo = 'Non sai farla',
                testo = 'Il gruppo era giusto. L\'ago no.' })
            return true
        end

        TriggerClientEvent('san:trasfusione', g.source, SAN.Trasfusione.saluteCompatibile, false)
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'successo', icona = '🩸', durata = 12000,
            titolo = 'Trasfusione',
            testo = ('Sacca %s su ricevente %s: compatibile.'):format(gruppoSacca, d.gruppo) })
        return true
    end)
end)

-- ---------------------------------------------------------------------------
--  Scadenze e carenze
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(SAN.Scorte.minutiScadenza * 60000)

        -- Il sangue scade. Quello che nessuno usa si butta, e i gruppi
        -- comuni sono quelli che si buttano di più.
        MySQL.update.await([[
            UPDATE scorte_sangue SET sacche = GREATEST(0, sacche - ?) WHERE sacche > 0
        ]], { SAN.Scorte.scaduteAlGiro })

        local carenti = MySQL.query.await('SELECT gruppo, sacche FROM scorte_sangue WHERE sacche <= ?',
            { SAN.Scorte.sogliaCarenza }) or {}
        if #carenti > 0 then
            local nomi = {}
            for _, c in ipairs(carenti) do
                nomi[#nomi + 1] = ('%s (%d)'):format(c.gruppo, c.sacche)
            end

            exports.aurea_ui:NotificaTutti({
                tipo = 'avviso', icona = '🩸', durata = 18000,
                titolo = 'Appello del centro trasfusionale',
                testo = ('Scorte in esaurimento: %s. Si dona al centro AVIS.')
                    :format(table.concat(nomi, ', ')),
            })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  App del telefono: la tessera del donatore
-- ---------------------------------------------------------------------------
AureaApp({
    id = 'avis',
    nome = 'Donatore',
    icona = '🩸',
    colore = 'linear-gradient(150deg,#a83a3a,#5c1d1d)',
    ordine = 138,

    condizione = function(g)
        return MySQL.scalar.await('SELECT citizenid FROM donatori WHERE citizenid = ?',
            { g.citizenid }) ~= nil
    end,

    schermata = function(g)
        local d = donatore(g.citizenid)
        local voci = {
            { icona = '🩸', titolo = 'Gruppo sanguigno', valore = d.gruppo,
              sottotitolo = ('Puoi ricevere da: %s'):format(
                  table.concat(SAN.Compatibile[d.gruppo] or {}, ', ')),
              inerte = true },
            { icona = '📈', titolo = 'Donazioni effettuate', valore = tostring(d.donazioni),
              inerte = true },
        }

        for _, s in ipairs(scorte()) do
            voci[#voci + 1] = {
                icona = s.carenza and '⚠' or '✅',
                titolo = ('Scorte %s'):format(s.gruppo),
                valore = tostring(s.sacche),
                tono = s.carenza and 'rosso' or 'verde',
                sottotitolo = s.carenza and 'In esaurimento' or nil,
                inerte = true,
            }
        end

        return {
            tipo = 'tessera',
            tessera = {
                etichetta = 'Tessera del donatore',
                nome = g:NomeCompleto(),
                righe = {
                    { chiave = 'Gruppo sanguigno', valore = d.gruppo },
                    { chiave = 'Donazioni', valore = tostring(d.donazioni) },
                    { chiave = 'Idoneità', valore = d.idoneo == 1 and 'Idoneo' or 'Sospesa' },
                },
            },
            voci = voci,
        }
    end,
})
