--[[
    AUREA · Gestione dell'ente (client)
]]

local function personaVicina()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, 4.0
    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

local function avviso(ok, messaggio, icona)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = icona or '🏢',
        testo = messaggio, durata = 12000,
    })
end

-- ---------------------------------------------------------------------------
--  Scheda del dipendente
-- ---------------------------------------------------------------------------
local function schedaDipendente(d, mioGrado, gradi)
    local voci = {
        { id = 'grado', icona = '🎖', titolo = 'Cambia inquadramento',
          descrizione = ('Attuale: %s'):format(d.etichettaGrado) },
        { id = 'premio', icona = '💶', titolo = 'Riconosci un premio',
          descrizione = 'Esce dalla cassa dell\'ente.' },
        { id = 'licenzia', icona = '⛔', titolo = 'Chiudi il rapporto di lavoro',
          descrizione = d.inServizio and 'È in servizio: deve smontare prima.' or nil,
          disattivata = d.inServizio },
    }

    local scelta = exports.aurea_ui:Menu({
        titolo = d.nome,
        sottotitolo = ('%s · %s · %d minuti di presenza registrati')
            :format(d.etichettaGrado, d.connesso and 'connesso' or 'non connesso', d.minutiPresenza),
        voci = voci,
    })
    if not scelta then return end

    if scelta == 'grado' then
        local elenco = {}
        for _, gr in ipairs(gradi or {}) do
            local troppoAlto = gr.grado >= mioGrado
            elenco[#elenco + 1] = {
                id = tostring(gr.grado), icona = '🎖', titolo = gr.etichetta,
                descrizione = troppoAlto and 'Pari o superiore al tuo grado.'
                    or ('Stipendio %s per ciclo'):format(AUREA.Util.Euro(gr.stipendio)),
                disattivata = troppoAlto or gr.grado == d.grado,
            }
        end

        local nuovo = exports.aurea_ui:Menu({ titolo = 'Inquadramento', voci = elenco })
        if not nuovo then return end

        local ok, messaggio = AUREA.Callback.Attendi('azi:grado', d.citizenid, tonumber(nuovo))
        avviso(ok, messaggio, '🎖')

    elseif scelta == 'premio' then
        local risposte = exports.aurea_ui:Dialogo('Premio di produttività', {
            { etichetta = 'Importo in euro', tipo = 'number', min = 1, max = 2000, obbligatorio = true },
        })
        if not risposte then return end
        local ok, messaggio = AUREA.Callback.Attendi('azi:premio', d.citizenid,
            AUREA.Util.ACentesimi(tonumber(risposte[1]) or 0))
        avviso(ok, messaggio, '💶')

    elseif scelta == 'licenzia' then
        local conferma = exports.aurea_ui:Menu({
            titolo = ('Licenziare %s?'):format(d.nome),
            sottotitolo = 'Tornerà disoccupato.',
            voci = {
                { id = 'no', icona = '↩', titolo = 'No, torna indietro' },
                { id = 'si', icona = '⛔', titolo = 'Sì, chiudi il rapporto' },
            },
        })
        if conferma ~= 'si' then return end
        local ok, messaggio = AUREA.Callback.Attendi('azi:licenzia', d.citizenid)
        avviso(ok, messaggio, '⛔')
    end
end

-- ---------------------------------------------------------------------------
--  Cassa
-- ---------------------------------------------------------------------------
local function apriCassa(saldo)
    local scelta = exports.aurea_ui:Menu({
        titolo = 'Cassa dell\'ente',
        sottotitolo = ('Saldo: %s'):format(AUREA.Util.Euro(saldo or 0)),
        voci = {
            { id = 'versa', icona = '⬇', titolo = 'Versa in cassa' },
            { id = 'preleva', icona = '⬆', titolo = 'Preleva dalla cassa' },
            { id = 'movimenti', icona = '📒', titolo = 'Registro dei movimenti' },
        },
    })
    if not scelta then return end

    if scelta == 'movimenti' then
        local righe, motivo = AUREA.Callback.Attendi('azi:movimenti')
        if motivo then return avviso(false, motivo, '📒') end

        local elenco = {}
        for _, m in ipairs(righe or {}) do
            elenco[#elenco + 1] = {
                id = 'm', icona = m.importo >= 0 and '＋' or '－',
                titolo = ('%s%s'):format(m.importo >= 0 and '+' or '', AUREA.Util.Euro(m.importo)),
                descrizione = ('%s · %s'):format(m.causale, m.autore or 'n.d.'),
                disattivata = true,
            }
        end
        if #elenco == 0 then
            elenco[1] = { id = 'x', icona = '📒', titolo = 'Nessun movimento', disattivata = true }
        end
        exports.aurea_ui:Menu({ titolo = 'Registro di cassa', voci = elenco })
        return
    end

    local risposte = exports.aurea_ui:Dialogo(
        scelta == 'versa' and 'Versamento in cassa' or 'Prelievo dalla cassa', {
            { etichetta = 'Importo in euro', tipo = 'number', min = 1, max = 5000, obbligatorio = true },
        })
    if not risposte then return end

    local ok, messaggio = AUREA.Callback.Attendi('azi:cassa', scelta,
        AUREA.Util.ACentesimi(tonumber(risposte[1]) or 0))
    avviso(ok, messaggio, '💶')
end

-- ---------------------------------------------------------------------------
--  Ufficio
-- ---------------------------------------------------------------------------
local function apriUfficio(ufficio)
    local organico, saldo, mioGrado, gradi = AUREA.Callback.Attendi('azi:organico')

    local voci = {
        { id = 'assumi', icona = '➕', titolo = 'Assumi chi hai davanti',
          descrizione = ('Contributo di attivazione %s a carico della cassa.')
              :format(AUREA.Util.Euro(AZI.Regole.contributoAssunzione)) },
        { id = 'cassa', icona = '💶', titolo = 'Cassa dell\'ente',
          descrizione = ('Saldo: %s'):format(AUREA.Util.Euro(saldo or 0)) },
    }

    for _, d in ipairs(organico or {}) do
        voci[#voci + 1] = {
            id = 'p:' .. d.citizenid,
            icona = d.inServizio and '🟢' or (d.connesso and '🟡' or '⚪'),
            titolo = d.nome,
            descrizione = ('%s · %s'):format(d.etichettaGrado,
                d.inServizio and 'in servizio' or (d.connesso and 'connesso' or 'assente')),
        }
    end

    if #(organico or {}) == 0 then
        table.insert(voci, { id = 'x', icona = '👥', titolo = 'Organico vuoto', disattivata = true })
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = ufficio.nome,
        sottotitolo = ('Organico: %d · il tuo grado consente fino a %d')
            :format(#(organico or {}), math.max(0, (mioGrado or 0) - 1)),
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    if scelta == 'assumi' then
        local b = personaVicina()
        if not b then return avviso(false, 'Non c\'è nessuno in ufficio con te.', '➕') end
        local ok, messaggio = AUREA.Callback.Attendi('azi:assumi', b)
        return avviso(ok, messaggio, '➕')
    end

    if scelta == 'cassa' then return apriCassa(saldo) end

    local citizenid = scelta:sub(3)
    for _, d in ipairs(organico or {}) do
        if d.citizenid == citizenid then
            return schedaDipendente(d, mioGrado or 0, gradi)
        end
    end
end

-- ---------------------------------------------------------------------------
--  Punti
-- ---------------------------------------------------------------------------
CreateThread(function()
    for n, u in ipairs(AZI.Uffici) do
        exports.aurea_target:AggiungiZona('azi_' .. n, u.coord, AZI.Raggio, {
            {
                etichetta = 'Gestione del personale', icona = '🏢',
                lavoro = u.lavoro,
                azione = function() apriUfficio(u) end,
            },
        })
    end
end)
