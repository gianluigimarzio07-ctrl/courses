--[[
    AUREA · Ambulatorio veterinario (server)

    Lo stato dell'animale è già nel database di aurea_animali: fame e
    affetto sono numeri che scendono da soli. Qui non si duplica niente,
    si legge — e si trae la conseguenza che finora nessuno traeva.

    Il maltrattamento non è una scelta del giocatore: è una condizione
    misurabile dell'animale, e chi lo accerta legge quella.
]]

local U = AUREA.Util

local function veterinario(g, permesso)
    return g and g.lavoro.nome == VET.Lavoro and g.lavoro.servizio
       and g:HaPermessoLavoro(permesso or 'visita')
end

local function inAmbulatorio(src)
    return #(GetEntityCoords(GetPlayerPed(src)) - VET.Ambulatorio.coord) <= 8.0
end

-- ---------------------------------------------------------------------------
--  Lo stato degli animali di una persona
-- ---------------------------------------------------------------------------
local function animaliDi(citizenid)
    local righe = MySQL.query.await([[
        SELECT id, nome, razza, fame, affetto, microchip, fuggito
        FROM animali WHERE proprietario = ? AND fuggito = 0
    ]], { citizenid }) or {}

    for _, a in ipairs(righe) do
        a.malato = VET.Malato(a.fame, a.affetto)
        a.maltrattato = VET.Maltrattato(a.fame, a.affetto)

        a.vaccini = MySQL.query.await([[
            SELECT tipo, scadenza, DATEDIFF(scadenza, CURDATE()) AS giorni
            FROM vet_vaccinazioni WHERE animale_id = ?
        ]], { a.id }) or {}

        a.inRegola = false
        for _, v in ipairs(a.vaccini) do
            local vac = VET.GetVaccino(v.tipo)
            if vac and vac.obbligatorio and (v.giorni or -1) >= 0 then a.inRegola = true end
        end
    end
    return righe
end

--- Lo chiede chi deve sapere se un animale è in regola: senza
--- antirabbica valida, non lo è.
exports('InRegola', function(animaleId)
    local r = MySQL.single.await([[
        SELECT v.tipo FROM vet_vaccinazioni v
        WHERE v.animale_id = ? AND v.scadenza >= CURDATE()
    ]], { tonumber(animaleId) })
    if not r then return false end
    local vac = VET.GetVaccino(r.tipo)
    return vac ~= nil and vac.obbligatorio == true
end)

AUREA.Callback.Registra('vet:miei', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    rispondi({
        animali = animaliDi(g.citizenid),
        vaccini = VET.Vaccini,
        costoVisita = VET.Visita.costo,
        veterinario = veterinario(g),
    })
end)

-- ---------------------------------------------------------------------------
--  La visita
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vet:visita', function(src, rispondi, animaleId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inAmbulatorio(src) then return rispondi(false, 'La visita si fa in ambulatorio.') end

    local a = MySQL.single.await(
        'SELECT id, nome, razza, fame, affetto, proprietario FROM animali WHERE id = ?',
        { tonumber(animaleId) })
    if not a then return rispondi(false, 'Animale non trovato.') end
    if a.proprietario ~= g.citizenid then return rispondi(false, 'Non è tuo.') end

    if not g:SottraiOvunque(VET.Visita.costo, ('visita veterinaria — %s'):format(a.nome)) then
        return rispondi(false, ('La visita costa %s.'):format(U.Euro(VET.Visita.costo)))
    end

    -- Se c'è un veterinario in ambulatorio, una parte è sua
    local presente
    for _, v in pairs(AUREA.GetGiocatoriPerLavoro(VET.Lavoro, true) or {}) do
        if inAmbulatorio(v.source) then presente = v break end
    end
    if presente then
        presente:Aggiungi('banca',
            math.floor(VET.Visita.costo * VET.Visita.compensoVeterinario), 'visita veterinaria')
    end
    pcall(function()
        exports.aurea_azienda:VersaInCassa(VET.Lavoro,
            math.floor(VET.Visita.costo * (1 - VET.Visita.compensoVeterinario)), 'visite')
    end)

    -- La diagnosi dice quello che si vede
    local diagnosi
    if VET.Maltrattato(a.fame, a.affetto) then
        diagnosi = 'Grave stato di denutrizione e incuria.'
    elseif a.fame <= VET.Visita.fameCritica then
        diagnosi = 'Denutrizione: l\'animale non mangia da troppo.'
    elseif a.affetto <= VET.Visita.affettoCritico then
        diagnosi = 'Sofferenza da isolamento.'
    else
        diagnosi = 'Animale in buone condizioni.'
    end

    MySQL.insert.await([[
        INSERT INTO vet_cartelle (animale_id, citizenid, motivo, diagnosi, veterinario, costo)
        VALUES (?, 'visita generale', ?, ?, ?, ?)
    ]], { a.id, g.citizenid, diagnosi, presente and presente.citizenid or nil, VET.Visita.costo })

    -- La cura rimette a posto i bisogni
    MySQL.update.await([[
        UPDATE animali SET fame = GREATEST(fame, ?), affetto = GREATEST(affetto, ?)
        WHERE id = ?
    ]], { VET.Visita.fameDopoCura, VET.Visita.affettoDopoCura, a.id })

    -- Un veterinario che vede un animale maltrattato ha l'obbligo di
    -- segnalarlo. Anche se il proprietario è il suo cliente.
    if VET.Maltrattato(a.fame, a.affetto) and presente then
        MySQL.insert.await([[
            INSERT INTO vet_maltrattamenti (animale_id, citizenid, accertato_da, descrizione)
            VALUES (?, ?, ?, ?)
        ]], { a.id, g.citizenid, presente.citizenid, diagnosi })

        exports.ita_giustizia:ApriFascicolo(g.citizenid, VET.Maltrattamento.reato,
            presente:NomeCompleto(),
            ('Animale %s (%s) in grave stato di denutrizione e incuria'):format(a.nome, a.razza))

        exports.aurea_ui:NotificaEnte('carabinieri', {
            tipo = 'avviso', icona = '🐕', durata = 16000,
            titolo = 'Segnalazione di maltrattamento',
            testo = ('Un veterinario ha refertato un animale in gravi condizioni: %s.')
                :format(g:NomeCompleto()),
        }, true)
    end

    AUREA.Log('economia', 'info', g, ('visita veterinaria su %s: %s'):format(a.nome, diagnosi))

    rispondi(true, ('%s — %s\n%s')
        :format(a.nome, diagnosi,
                presente and ('Visitato da %s.'):format(presente:NomeCompleto())
                         or 'Nessun veterinario in sede: cure di base.'))
end)

-- ---------------------------------------------------------------------------
--  Vaccinazioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vet:vaccina', function(src, rispondi, animaleId, tipoId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not inAmbulatorio(src) then return rispondi(false, 'Si vaccina in ambulatorio.') end

    local vaccino = VET.GetVaccino(tipoId)
    if not vaccino then return rispondi(false, 'Vaccino non previsto.') end

    local a = MySQL.single.await(
        'SELECT id, nome, proprietario FROM animali WHERE id = ?', { tonumber(animaleId) })
    if not a then return rispondi(false, 'Animale non trovato.') end
    if a.proprietario ~= g.citizenid then return rispondi(false, 'Non è tuo.') end

    -- Serve un veterinario: un vaccino non se lo fa il proprietario
    local presente
    for _, v in pairs(AUREA.GetGiocatoriPerLavoro(VET.Lavoro, true) or {}) do
        if inAmbulatorio(v.source) then presente = v break end
    end
    if not presente then
        return rispondi(false, 'Serve un veterinario in servizio: il vaccino lo somministra lui.')
    end

    if not g:SottraiOvunque(vaccino.costo, ('vaccino %s — %s'):format(vaccino.nome, a.nome)) then
        return rispondi(false, ('Il vaccino costa %s.'):format(U.Euro(vaccino.costo)))
    end

    presente:Aggiungi('banca', math.floor(vaccino.costo * 0.3), 'vaccinazione')
    pcall(function()
        exports.aurea_azienda:VersaInCassa(VET.Lavoro, math.floor(vaccino.costo * 0.7), 'vaccinazioni')
    end)

    MySQL.query.await([[
        INSERT INTO vet_vaccinazioni (animale_id, tipo, somministrata_il, scadenza, veterinario)
        VALUES (?, ?, CURDATE(), ?, ?)
        ON DUPLICATE KEY UPDATE somministrata_il = CURDATE(), scadenza = VALUES(scadenza),
                                veterinario = VALUES(veterinario)
    ]], { a.id, vaccino.id, U.DataPiuGiorni(vaccino.giorni), presente.citizenid })

    rispondi(true, ('%s vaccinato: %s, valida %d giorni.%s')
        :format(a.nome, vaccino.nome, vaccino.giorni,
                vaccino.obbligatorio and '\nDa adesso è in regola.' or ''))
end)

-- ---------------------------------------------------------------------------
--  Accertamento di maltrattamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vet:accerta', function(src, rispondi, sorgente)
    local g = AUREA.GetPlayer(src)
    if not g or not g.lavoro.servizio
       or not U.Contiene(VET.Maltrattamento.lavoriAbilitati, g.lavoro.nome) then
        return rispondi(false, 'L\'accertamento lo fa un veterinario o una pattuglia in servizio.')
    end

    local soggetto = AUREA.GetPlayer(tonumber(sorgente))
    if not soggetto then return rispondi(false, 'La persona non è collegata.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source))) > 5.0 then
        return rispondi(false, 'È troppo lontano.')
    end

    local animali = animaliDi(soggetto.citizenid)
    if #animali == 0 then
        return rispondi(true, { nome = soggetto:NomeCompleto(), animali = 0 })
    end

    local maltrattati, nomi = 0, {}
    for _, a in ipairs(animali) do
        if a.maltrattato then
            maltrattati = maltrattati + 1
            nomi[#nomi + 1] = ('%s (%s)'):format(a.nome, a.razza)

            MySQL.insert.await([[
                INSERT INTO vet_maltrattamenti
                    (animale_id, citizenid, accertato_da, descrizione, sequestrato)
                VALUES (?, ?, ?, ?, ?)
            ]], { a.id, soggetto.citizenid, g.citizenid,
                  ('Fame %d, affetto %d'):format(a.fame, a.affetto),
                  VET.Maltrattamento.sequestro and 1 or 0 })

            if VET.Maltrattamento.sequestro then
                -- L'animale si toglie a chi lo ha ridotto così. Non si
                -- cancella la riga e non si azzera il proprietario — la
                -- colonna non ammette NULL e soprattutto serve sapere a
                -- chi era: si marca come non più in custodia, che è il
                -- meccanismo che aurea_animali usa già.
                MySQL.update.await([[
                    UPDATE animali SET fuggito = 1, fame = 80, affetto = 60 WHERE id = ?
                ]], { a.id })
            end
        end
    end

    if maltrattati == 0 then
        return rispondi(true, { nome = soggetto:NomeCompleto(), animali = #animali, maltrattati = 0 })
    end

    exports.ita_giustizia:ApriFascicolo(soggetto.citizenid, VET.Maltrattamento.reato,
        g:NomeCompleto(),
        ('Maltrattamento di %d animali: %s'):format(maltrattati, table.concat(nomi, ', ')))

    soggetto:SottraiOvunque(VET.Maltrattamento.sanzione, 'sanzione per maltrattamento di animali')
    TriggerEvent('aurea:fisco:incasso', 'sanzioni_amministrative',
        VET.Maltrattamento.sanzione, soggetto.citizenid)

    AUREA.Log('giustizia', 'avviso', g, ('accertato maltrattamento su %d animali di %s')
        :format(maltrattati, soggetto.citizenid))

    rispondi(true, {
        nome = soggetto:NomeCompleto(),
        animali = #animali,
        maltrattati = maltrattati,
        nomi = nomi,
        sanzione = VET.Maltrattamento.sanzione,
    })
end)
