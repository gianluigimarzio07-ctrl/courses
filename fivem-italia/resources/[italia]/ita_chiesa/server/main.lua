--[[
    AUREA · Parrocchia (server)

    Tre cose, e la terza è quella per cui il modulo esiste.

    I riti si celebrano davanti al parroco, con chi deve esserci presente
    sul serio. La mensa distribuisce quello che qualcuno ha portato, e
    quando finisce finisce.

    E la confessione non si salva. In tutto questo file non c'è una sola
    query che scriva quello che qualcuno ha detto in confessionale: si
    conta che è avvenuta, si toglie stress, e basta. Art. 200 c.p.p. non
    è una regola che si applica ai dati — è il motivo per cui i dati non
    ci sono.
]]

local U = AUREA.Util

local ultimaConfessione = {}    -- [citizenid] = os.time()
local ultimoPasto = {}          -- [citizenid] = os.time()
local scorta = 0                -- porzioni disponibili alla mensa

-- ---------------------------------------------------------------------------
--  Chi è in parrocchia
-- ---------------------------------------------------------------------------
local function clero(g, permesso)
    if not g or g.lavoro.nome ~= CHI.Lavoro then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

local function inParrocchia(src, punto)
    return #(GetEntityCoords(GetPlayerPed(src)) - (punto or CHI.Parrocchia.coord)) <= 8.0
end

local function caricaScorta()
    scorta = tonumber(MySQL.scalar.await(
        'SELECT valore FROM economia_stato WHERE chiave = ?', { 'chiesa_scorta' })) or 0
end

local function salvaScorta()
    MySQL.query([[
        INSERT INTO economia_stato (chiave, valore) VALUES ('chiesa_scorta', ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { tostring(math.floor(scorta)) })
end

CreateThread(function() Wait(3000) caricaScorta() end)

-- ---------------------------------------------------------------------------
--  Riti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('chi:celebra', function(src, rispondi, ritoId, sorgenteA, sorgenteB)
    local p = AUREA.GetPlayer(src)
    if not clero(p, 'rito') then return rispondi(false, 'I riti li celebra chi ne ha facoltà.') end
    if not inParrocchia(src, CHI.Parrocchia.altare) then
        return rispondi(false, 'Si celebra all\'altare.')
    end

    local r = CHI.GetRito(ritoId)
    if not r then return rispondi(false, 'Rito sconosciuto.') end

    local a = AUREA.GetPlayer(tonumber(sorgenteA))
    if not a then return rispondi(false, 'La persona non è presente.') end
    if not inParrocchia(a.source, CHI.Parrocchia.altare) then
        return rispondi(false, ('%s deve essere all\'altare.'):format(a:NomeCompleto()))
    end

    local b
    if r.partecipanti >= 2 or r.richiedePadrino then
        b = AUREA.GetPlayer(tonumber(sorgenteB))
        if not b then return rispondi(false, r.richiedePadrino and 'Serve il padrino.' or 'Servono due persone.') end
        if not inParrocchia(b.source, CHI.Parrocchia.altare) then
            return rispondi(false, ('%s deve essere all\'altare.'):format(b:NomeCompleto()))
        end
    end

    -- Il matrimonio religioso non sostituisce quello civile: lo segue.
    if r.richiedeMatrimonioCivile then
        local civile = MySQL.single.await([[
            SELECT id FROM matrimoni
            WHERE ((coniuge_a = ? AND coniuge_b = ?) OR (coniuge_a = ? AND coniuge_b = ?))
              AND stato = 'celebrato' AND sciolto = 0 LIMIT 1
        ]], { a.citizenid, b.citizenid, b.citizenid, a.citizenid })
        if not civile then
            return rispondi(false, 'Non risultano sposati civilmente. Il rito non produce effetti sui beni: prima il Comune, poi qui.')
        end
    end

    if r.richiedeDefunto then
        local defunto = MySQL.scalar.await(
            'SELECT id FROM funerali WHERE citizenid = ? ORDER BY id DESC LIMIT 1', { a.citizenid })
        if not defunto then
            return rispondi(false, 'Non risulta nessuna pratica funebre a nome di quella persona.')
        end
    end

    MySQL.insert('INSERT INTO chiesa_riti (tipo, celebrante, soggetto_a, soggetto_b) VALUES (?, ?, ?, ?)',
        { ritoId, p:NomeCompleto(), a.citizenid, b and b.citizenid or nil })

    for _, chi in ipairs({ a, b }) do
        if chi then
            if r.stress then chi:VariaStato('stress', r.stress) end
            TriggerClientEvent('aurea:ui:notifica', chi.source, {
                tipo = 'successo', icona = r.icona, durata = 16000,
                titolo = r.nome,
                testo = ('Celebrato da %s.%s'):format(p:NomeCompleto(),
                    r.offertaSuggerita > 0
                        and ('\nL\'offerta suggerita è %s, e resta un\'offerta.'):format(U.Euro(r.offertaSuggerita))
                        or ''),
            })
        end
    end

    AUREA.Log('economia', 'info', p, ('ha celebrato %s'):format(r.nome))
    rispondi(true, ('%s celebrato.'):format(r.nome))
end)

-- ---------------------------------------------------------------------------
--  Confessione
--
--  Quello che segue è l'unica parte del server scritta per NON registrare
--  qualcosa. Il testo arriva, produce un effetto, e finisce lì.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('chi:confessa', function(src, rispondi, sacerdoteSrc)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inParrocchia(src, CHI.Parrocchia.confessionale) then
        return rispondi(false, 'Il confessionale è dall\'altra parte.')
    end

    local s = AUREA.GetPlayer(tonumber(sacerdoteSrc))
    if not clero(s, CHI.Confessione.permesso) then
        return rispondi(false, 'Dall\'altra parte non c\'è un confessore.')
    end
    if not inParrocchia(s.source, CHI.Parrocchia.confessionale) then
        return rispondi(false, 'Il confessore non è al suo posto.')
    end

    local attesa = CHI.Confessione.attesaMinuti * 60
    if ultimaConfessione[g.citizenid] and os.time() - ultimaConfessione[g.citizenid] < attesa then
        return rispondi(false, ('Ci sei già stato da poco. Riprova fra %d minuti.')
            :format(math.ceil((attesa - (os.time() - ultimaConfessione[g.citizenid])) / 60)))
    end

    ultimaConfessione[g.citizenid] = os.time()
    g:VariaStato('stress', CHI.Confessione.stress)

    -- Si conta che è avvenuta. Non CHI, non COSA: solo quante ne sono
    -- state ascoltate, perché il parroco possa sapere se ha lavorato.
    MySQL.query('UPDATE chiesa_stato SET confessioni = confessioni + 1 WHERE id = 1')

    rispondi(true, s.source)
end)

--- Il testo passa da un evento diretto fra le due sessioni. Non tocca il
--- database, non tocca il brogliaccio delle intercettazioni, e nemmeno
--- il registro eventi: è l'unico canale del server fatto così.
RegisterNetEvent('chi:dico', function(sacerdoteSrc, testo)
    local src = source
    local g = AUREA.GetPlayer(src)
    local s = AUREA.GetPlayer(tonumber(sacerdoteSrc))
    if not g or not s or not clero(s, CHI.Confessione.permesso) then return end
    if not inParrocchia(src, CHI.Parrocchia.confessionale)
        or not inParrocchia(s.source, CHI.Parrocchia.confessionale) then return end

    TriggerClientEvent('chi:ascolto', s.source, tostring(testo or ''):sub(1, CHI.Confessione.caratteriMassimi))
end)

--- Chi prova ad acquisire qualcosa dal confessionale trova questo.
exports('AcquisisciConfessioni', function()
    return nil, CHI.Segreto.rifiuto
end)

AUREA.Comando('acquisisciconfessioni', 'utente', 'Tenta di acquisire il contenuto delle confessioni', {},
function(src, _, _, g)
    if not g then return end
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'errore', icona = '🕊', durata = 20000,
        titolo = CHI.Segreto.articolo,
        testo = CHI.Segreto.rifiuto,
    })
    AUREA.Log('giustizia', 'info', g, 'ha tentato di acquisire il contenuto delle confessioni')
end)

-- ---------------------------------------------------------------------------
--  Mensa
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('chi:mensa', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inParrocchia(src, CHI.Parrocchia.mensa) then
        return rispondi(false, 'La mensa è dietro la chiesa.')
    end

    local ammesso = (g.stato and (g.stato.fame or 100) <= CHI.Mensa.fameSotto)
    for _, l in ipairs(CHI.Mensa.lavoriAmmessi) do
        if g.lavoro.nome == l then ammesso = true end
    end
    if not ammesso then
        return rispondi(false, 'La mensa è per chi ne ha bisogno. Tu un pasto te lo puoi pagare.')
    end

    local attesa = CHI.Mensa.attesaMinuti * 60
    if ultimoPasto[g.citizenid] and os.time() - ultimoPasto[g.citizenid] < attesa then
        return rispondi(false, ('Hai già mangiato. Torna fra %d minuti.')
            :format(math.ceil((attesa - (os.time() - ultimoPasto[g.citizenid])) / 60)))
    end

    if scorta < CHI.Mensa.porzioniPerPasto then
        return rispondi(false, 'La dispensa è vuota. La mensa vive di offerte, e in questo periodo non ne arrivano.')
    end

    scorta = scorta - CHI.Mensa.porzioniPerPasto
    salvaScorta()
    ultimoPasto[g.citizenid] = os.time()

    exports.aurea_inventory:Aggiungi(g.citizenid, CHI.Mensa.piatto, 1)
    exports.aurea_inventory:Aggiungi(g.citizenid, CHI.Mensa.bevanda, 1)

    rispondi(true, ('Un pasto e qualcosa da bere. Restano %d porzioni nella dispensa.')
        :format(math.floor(scorta)))
end)

AUREA.Callback.Registra('chi:offri', function(src, rispondi, tipo, valore)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inParrocchia(src, CHI.Parrocchia.offertorio) then
        return rispondi(false, 'L\'offertorio è all\'ingresso.')
    end

    if tipo == 'denaro' then
        local importo = U.ACentesimi(tonumber(tostring(valore):gsub(',', '.')) or 0)
        if importo < CHI.Offertorio.minimo then
            return rispondi(false, 'Un\'offerta è un\'offerta, ma almeno un euro.')
        end
        if not g:SottraiOvunque(importo, 'offerta alla parrocchia') then
            return rispondi(false, 'Non hai quei soldi.')
        end

        local allaMensa = math.floor(importo * CHI.Offertorio.quotaAllaMensa)
        scorta = scorta + math.floor(allaMensa * CHI.Mensa.porzioniPerEuro)
        salvaScorta()

        pcall(function()
            exports.aurea_azienda:VersaInCassa(CHI.Lavoro, importo - allaMensa, 'offerta')
        end)

        MySQL.query('UPDATE chiesa_stato SET offerte = offerte + ? WHERE id = 1', { importo })

        return rispondi(true, ('Grazie. %s vanno alla mensa: fanno %d porzioni.')
            :format(U.Euro(allaMensa), math.floor(allaMensa * CHI.Mensa.porzioniPerEuro)))
    end

    -- Offerta in natura
    local porzioni = CHI.Mensa.offerteInNatura[tipo]
    if not porzioni then return rispondi(false, 'Alla mensa quello non serve.') end

    local quanti = math.floor(U.Clamp(tonumber(valore) or 1, 1, 20))
    if not exports.aurea_inventory:Ha(g.citizenid, tipo, quanti) then
        return rispondi(false, 'Non ne hai abbastanza.')
    end
    exports.aurea_inventory:Rimuovi(g.citizenid, tipo, quanti)

    scorta = scorta + porzioni * quanti
    salvaScorta()

    rispondi(true, ('%d × %s: %d porzioni in dispensa. Adesso sono %d.')
        :format(quanti, AUREA.Item[tipo].etichetta, porzioni * quanti, math.floor(scorta)))
end)

AUREA.Callback.Registra('chi:stato', function(src, rispondi)
    local s = MySQL.single.await('SELECT * FROM chiesa_stato WHERE id = 1') or {}
    rispondi({
        scorta = math.floor(scorta),
        confessioni = s.confessioni or 0,
        offerte = s.offerte or 0,
    })
end)

print('[AUREA] parrocchia: riti, mensa e un canale che non si registra')
