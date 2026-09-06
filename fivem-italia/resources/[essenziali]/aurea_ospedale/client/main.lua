--[[
    AUREA · Ospedale (client)
]]

local function personaVicina(distanzaMax)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, distanzaMax or 5.0

    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

-- ---------------------------------------------------------------------------
--  Accettazione, lato paziente
-- ---------------------------------------------------------------------------
local function accettazione()
    local voci = {}
    for _, s in ipairs(OSP.Triage.sintomi) do
        voci[#voci + 1] = {
            id = s.id, icona = '🩺', titolo = s.nome,
            descrizione = 'Il codice lo assegna il triage, non la tua dichiarazione.',
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Accettazione',
        sottotitolo = 'Che cosa ti porta in pronto soccorso?',
        voci = voci,
    })
    if not scelta then return end

    if not exports.aurea_ui:Progresso({
        etichetta = 'Registrazione al triage...', durata = 6000, blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('osp:accetta', scelta)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🏥',
        titolo = ok and 'Accettato' or 'Non accettato',
        testo = messaggio, durata = 14000,
    })
end

-- ---------------------------------------------------------------------------
--  Coda, lato sanitario
-- ---------------------------------------------------------------------------
local function apriCoda()
    local righe = AUREA.Callback.Attendi('osp:coda')
    local voci = {}

    for _, r in ipairs(righe or {}) do
        local c = OSP.GetCodice(r.codice)
        voci[#voci + 1] = {
            id = tostring(r.numero),
            icona = r.codice == 'rosso' and '🟥' or (r.codice == 'giallo' and '🟨'
                or (r.codice == 'verde' and '🟩' or '⬜')),
            titolo = ('n. %d — %s'):format(r.numero, r.nome),
            descrizione = ('%s · %s · in attesa da %d minuti%s')
                :format(c.nome, r.sintomo, r.attesa, r.presente and '' or ' · non più presente'),
            disattivata = not r.presente,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🏥', titolo = 'Nessuno in attesa', disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Pronto soccorso',
        sottotitolo = 'Chiama il prossimo secondo il codice, non secondo l\'ordine di arrivo',
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    local ok, messaggio = AUREA.Callback.Attendi('osp:chiama', tonumber(scelta))
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '📢', testo = messaggio, durata = 10000,
    })
end

-- ---------------------------------------------------------------------------
--  Esami
-- ---------------------------------------------------------------------------
local function eseguiEsame(reparto)
    local voci = {}
    for id, e in pairs(OSP.Esami) do
        if e.reparto == reparto then
            voci[#voci + 1] = {
                id = id, icona = e.icona, titolo = e.nome,
                descrizione = ('Ticket %s a carico del paziente'):format(AUREA.Util.Euro(e.ticket)),
            }
        end
    end
    table.sort(voci, function(a, b) return a.titolo < b.titolo end)

    local scelta = exports.aurea_ui:Menu({
        titolo = OSP.GetReparto(reparto).nome, voci = voci,
    })
    if not scelta then return end

    local paziente = personaVicina()
    if not paziente then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🩺', testo = 'Nessun paziente in reparto con te.' })
    end

    local ok, durata, pazienteSrc, nome = AUREA.Callback.Attendi('osp:esame', scelta, paziente)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🩺', testo = durata, durata = 11000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('%s su %s...'):format(OSP.Esami[scelta].nome, nome), durata = durata,
        anim = { dizionario = 'amb@medic@standing@tendtodead@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, testo, positivo = AUREA.Callback.Attendi('osp:concludiEsame', scelta, pazienteSrc)
        exports.aurea_ui:Notifica({
            tipo = fatto and (positivo and 'avviso' or 'successo') or 'errore',
            icona = '📄', durata = 22000,
            titolo = fatto and ('Referto — %s'):format(OSP.Esami[scelta].nome) or 'Esame interrotto',
            testo = testo,
        })
    end
end

RegisterNetEvent('osp:referto', function(r)
    exports.aurea_ui:Notifica({
        tipo = r.positivo and 'avviso' or 'info', icona = r.icona or '📄', durata = 24000,
        titolo = ('Referto — %s'):format(r.nome),
        testo = ('%s\nRefertato da %s.'):format(r.testo, r.medico),
    })
end)

-- ---------------------------------------------------------------------------
--  Cartella clinica
-- ---------------------------------------------------------------------------
local function apriCartella(altrui)
    local citizenid
    if altrui then
        local risposte = exports.aurea_ui:Dialogo('Cartella clinica', {
            { etichetta = 'Codice fiscale del paziente', tipo = 'text', obbligatorio = true },
        })
        if not risposte then return end
        citizenid = tostring(risposte[1])
    end

    local righe, motivo = AUREA.Callback.Attendi('osp:cartella', citizenid)
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔒', testo = motivo, durata = 10000 })
    end

    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = 'r', icona = '📄', titolo = r.diagnosi,
            descrizione = ('%s · %s'):format(r.terapia or '', r.medico or 'n.d.'),
            disattivata = true,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '📄', titolo = 'Cartella vuota', disattivata = true }
    end

    exports.aurea_ui:Menu({ titolo = 'Cartella clinica', voci = voci })
end

-- ---------------------------------------------------------------------------
--  Certificazioni
-- ---------------------------------------------------------------------------
local function certifica()
    local voci = {}
    for _, c in ipairs(OSP.Certificati) do
        voci[#voci + 1] = {
            id = c.id, icona = '📋', titolo = c.nome,
            descrizione = ('%s · valido %d giorni%s'):format(
                AUREA.Util.Euro(c.costo), c.validitaGiorni,
                #c.richiedeEsami > 0 and ' · richiede accertamenti recenti' or ''),
        }
    end

    local scelta = exports.aurea_ui:Menu({ titolo = 'Certificazioni', voci = voci })
    if not scelta then return end

    local paziente = personaVicina()
    if not paziente then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋', testo = 'Nessun paziente in ambulatorio.' })
    end

    local ok, durata, pazienteSrc, nome = AUREA.Callback.Attendi('osp:certifica', scelta, paziente)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋', testo = durata, durata = 15000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('Visita di %s...'):format(nome), durata = durata,
        anim = { dizionario = 'amb@medic@standing@tendtodead@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('osp:concludiCertificato', scelta, pazienteSrc)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '📋',
            titolo = fatto and 'Certificato rilasciato' or 'Non rilasciato',
            testo = messaggio, durata = 13000,
        })
    end
end

-- ---------------------------------------------------------------------------
--  Obitorio
-- ---------------------------------------------------------------------------
local function apriObitorio()
    local salme = AUREA.Callback.Attendi('osp:salme')
    local voci = {}

    for _, s in ipairs(salme or {}) do
        voci[#voci + 1] = {
            id = s.citizenid, icona = '⚰', titolo = s.nome,
            descrizione = 'Riscontro diagnostico non ancora eseguito.',
        }
    end
    voci[#voci + 1] = { id = 'archivio', icona = '📚', titolo = 'Riscontri già eseguiti' }

    local scelta = exports.aurea_ui:Menu({ titolo = 'Obitorio', voci = voci })
    if not scelta then return end

    if scelta == 'archivio' then
        local righe = AUREA.Callback.Attendi('osp:riscontriEmessi')
        local elenco = {}
        for _, r in ipairs(righe or {}) do
            elenco[#elenco + 1] = {
                id = 'r', icona = r.violenta == 1 and '🟥' or '⬜',
                titolo = r.nome, descrizione = ('%s · %s'):format(r.causa, r.medico_legale or 'n.d.'),
                disattivata = true,
            }
        end
        if #elenco == 0 then
            elenco[1] = { id = 'x', icona = '📚', titolo = 'Nessun riscontro agli atti', disattivata = true }
        end
        exports.aurea_ui:Menu({ titolo = 'Riscontri diagnostici', voci = elenco })
        return
    end

    local ok, durata, nome = AUREA.Callback.Attendi('osp:riscontro', scelta)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚰', testo = durata, durata = 11000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('Riscontro diagnostico su %s...'):format(nome), durata = durata,
        anim = { dizionario = 'amb@medic@standing@tendtodead@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, causa, violenta = AUREA.Callback.Attendi('osp:concludiRiscontro', scelta)
        exports.aurea_ui:Notifica({
            tipo = fatto and (violenta and 'errore' or 'info') or 'errore',
            icona = '⚰', durata = 24000,
            titolo = fatto and 'Riscontro concluso' or 'Riscontro interrotto',
            testo = causa,
        })
    end
end

-- ---------------------------------------------------------------------------
--  Punti sulla mappa e terzo occhio
-- ---------------------------------------------------------------------------
CreateThread(function()
    local R = OSP.Reparti

    exports.aurea_target:AggiungiZona('osp_accettazione', R.accettazione.coord, R.accettazione.raggio, {
        { etichetta = 'Presentati all\'accettazione', icona = '🏥', azione = accettazione },
        { etichetta = 'Coda del pronto soccorso', icona = '📋',
          lavori = OSP.Lavori, inServizio = true, azione = apriCoda },
        { etichetta = 'La mia cartella clinica', icona = '📄',
          azione = function() apriCartella(false) end },
    })

    exports.aurea_target:AggiungiZona('osp_laboratorio', R.laboratorio.coord, R.laboratorio.raggio, {
        { etichetta = 'Esegui un esame di laboratorio', icona = '🧪',
          lavori = OSP.Lavori, inServizio = true,
          azione = function() eseguiEsame('laboratorio') end },
    })

    exports.aurea_target:AggiungiZona('osp_diagnostica', R.diagnostica.coord, R.diagnostica.raggio, {
        { etichetta = 'Diagnostica per immagini', icona = '🦴',
          lavori = OSP.Lavori, inServizio = true,
          azione = function() eseguiEsame('diagnostica') end },
    })

    exports.aurea_target:AggiungiZona('osp_ambulatorio', R.ambulatorio.coord, R.ambulatorio.raggio, {
        { etichetta = 'Rilascia una certificazione', icona = '📋',
          lavori = OSP.Lavori, inServizio = true, azione = certifica },
        { etichetta = 'Consulta una cartella clinica', icona = '🗂',
          lavori = OSP.Lavori, inServizio = true,
          azione = function() apriCartella(true) end },
    })

    exports.aurea_target:AggiungiZona('osp_obitorio', R.obitorio.coord, R.obitorio.raggio, {
        { etichetta = 'Obitorio', icona = '⚰',
          lavori = OSP.Lavori, inServizio = true, azione = apriObitorio },
    })
end)
