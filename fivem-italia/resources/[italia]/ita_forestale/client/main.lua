--[[
    AUREA · Carabinieri Forestali (client)

    I vincoli li vedono tutti sulla mappa, e devono vederli: un vincolo
    che nessuno sa dov'è non serve a niente, perché chi compra un terreno
    deve poter sapere prima che su quello non si costruisce.

    Il rilievo del perimetro invece lo vede solo chi lo sta facendo.
]]

local U = AUREA.Util

local vincoli = {}
local blipVincoli = {}
local rilievoCorrente = nil   -- { incendio, zona, centro }

-- ---------------------------------------------------------------------------
--  I vincoli sulla mappa
-- ---------------------------------------------------------------------------
local function pulisciVincoli()
    for _, b in ipairs(blipVincoli) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blipVincoli = {}
end

local function disegnaVincoli()
    pulisciVincoli()
    for _, v in ipairs(vincoli) do
        local area = AddBlipForRadius(v.centro.x, v.centro.y, 0.0, v.raggio + 0.0)
        SetBlipColour(area, 49)
        SetBlipAlpha(area, 110)
        blipVincoli[#blipVincoli + 1] = area

        local b = AddBlipForCoord(v.centro.x, v.centro.y, 0.0)
        SetBlipSprite(b, 442)
        SetBlipColour(b, 49)
        SetBlipScale(b, 0.6)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('Vincolo — %.2f ettari'):format(v.ettari))
        EndTextCommandSetBlipName(b)
        blipVincoli[#blipVincoli + 1] = b
    end
end

RegisterNetEvent('for:vincoli', function(lista)
    vincoli = lista or {}
    disegnaVincoli()
end)

-- ---------------------------------------------------------------------------
--  Il rilievo del perimetro
-- ---------------------------------------------------------------------------
local function rilevaPunto()
    CreateThread(function()
        if not rilievoCorrente then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Rilievo', testo = 'Nessun incendio preso in carico. Vai in caserma.', durata = 12000 })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Rilievo del perimetro percorso dal fuoco',
            durata = FOR.Rilievo.secondiPerPunto * 1000,
            annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('for:rilevaPunto', rilievoCorrente.incendio)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📐',
            titolo = 'Rilievo', testo = tostring(messaggio), durata = 14000 })
    end)
end

local function prendiInCarico()
    CreateThread(function()
        local lista = AUREA.Callback.Attendi('for:daRilevare')
        if not lista then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Forestale', testo = 'Riservato ai militari in servizio.', durata = 10000 })
        end

        local voci = {}
        for _, inc in ipairs(lista) do
            voci[#voci + 1] = {
                id = tostring(inc.id), icona = '🔥',
                titolo = inc.zona,
                descrizione = ('Il fuoco è durato %d minuti.\nPunti rilevati da te: %d su %d · restano %d minuti.')
                    :format(inc.durataMinuti, inc.puntiMiei, FOR.Rilievo.puntiRichiesti, inc.minutiResidui),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🌲',
                titolo = 'Nessun incendio in attesa di rilievo',
                descrizione = 'Gli accertamenti arrivano quando i Vigili del Fuoco chiudono un intervento su bosco.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Incendi boschivi', sottotitolo = 'Superfici da rilevare', voci = voci })
        if not scelta or scelta == 'x' then return end

        for _, inc in ipairs(lista) do
            if tostring(inc.id) == scelta then
                rilievoCorrente = { incendio = inc.id, zona = inc.zona, centro = inc.centro }

                SetNewWaypoint(inc.centro.x + 0.0, inc.centro.y + 0.0)
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '📐', durata = 20000,
                    titolo = ('Presa in carico — %s'):format(inc.zona),
                    testo = ('Vai sul posto e rileva %d punti sul perimetro con /rilievo.\nFra un punto e l\'altro almeno %d metri.')
                        :format(FOR.Rilievo.puntiRichiesti, FOR.Rilievo.metriFraPunti),
                })
                return
            end
        end
    end)
end

local function accerta()
    CreateThread(function()
        if not rilievoCorrente then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Accertamento', testo = 'Nessun incendio preso in carico.', durata = 10000 })
        end

        local origini = {}
        for id, o in pairs(FOR.Origini) do
            origini[#origini + 1] = {
                id = id, icona = o.icona, titolo = o.etichetta,
                descrizione = o.reato and ('Apre un fascicolo (%s). Serve identificare qualcuno.'):format(o.articolo)
                    or (o.sanzione > 0 and ('Sanzione %s.'):format(U.Euro(o.sanzione))
                        or 'Nessuna conseguenza a carico di nessuno.'),
            }
        end
        table.sort(origini, function(a, b) return a.titolo < b.titolo end)

        local origine = exports.aurea_ui:Menu({
            titolo = ('Accertamento — %s'):format(rilievoCorrente.zona),
            sottotitolo = 'Origine dell\'incendio', voci = origini })
        if not origine then return end

        -- Se l'origine è un reato serve un nome, e il nome è la persona
        -- più vicina: l'identificazione si fa di persona, non a memoria.
        local responsabile = nil
        local o = FOR.GetOrigine(origine)
        if o and o.reato then
            local mio, minima = PlayerPedId(), 6.0
            for _, p in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(p)
                if ped ~= mio and ped ~= 0 then
                    local d = #(GetEntityCoords(mio) - GetEntityCoords(ped))
                    if d < minima then
                        minima = d
                        responsabile = GetPlayerServerId(p)
                    end
                end
            end
            if not responsabile then
                return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚖',
                    titolo = 'Accertamento',
                    testo = 'Per attribuire dolo o colpa serve avere davanti la persona.', durata = 14000 })
            end
        end

        local note = exports.aurea_ui:Dialogo('Note del verbale di accertamento', {
            { etichetta = 'Che cosa hai trovato sul posto', tipo = 'textarea',
              segnaposto = 'Innesco multiplo sul margine della strada, tracce di accelerante' },
        })

        local ok, esito = AUREA.Callback.Attendi('for:accerta',
            rilievoCorrente.incendio, origine, responsabile, note and note[1] or nil)

        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Accertamento', testo = tostring(esito), durata = 14000 })
        end

        rilievoCorrente = nil

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '📐', durata = 24000,
            titolo = 'Verbale di accertamento',
            testo = ('%s — %.2f ettari percorsi.\n%s%s\nCompetenze: %s.')
                :format(esito.zona, esito.ettari, esito.origine,
                        esito.responsabile and ('\nA carico di %s.'):format(esito.responsabile) or '',
                        U.Euro(esito.compenso)),
        })

        -- Il vincolo si propone subito: è il senso di tutto il rilievo
        local metti = exports.aurea_ui:Menu({
            titolo = 'Vincolo decennale',
            sottotitolo = ('%s — raggio stimato %d metri'):format(FOR.Vincolo.articolo, esito.raggio),
            voci = {
                { id = 'si', icona = '⛔', titolo = 'Apporre il vincolo',
                  descrizione = ('Per %d anni su quel terreno non si edifica e non si pascola.\nServe il grado di maresciallo.')
                      :format(FOR.Vincolo.anniNominali) },
                { id = 'no', icona = '↩', titolo = 'Non ora',
                  descrizione = 'L\'accertamento resta agli atti e il vincolo si può mettere dopo.' },
            },
        })
        if metti ~= 'si' then return end

        local esitoV, messaggio = AUREA.Callback.Attendi('for:vincola', esito.idRiga)
        exports.aurea_ui:Notifica({
            tipo = esitoV and 'successo' or 'errore', icona = '⛔',
            titolo = 'Vincolo', testo = tostring(messaggio), durata = 18000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Gli accertamenti su persona
-- ---------------------------------------------------------------------------
local function contesta()
    CreateThread(function()
        local voci = {}
        for id, a in pairs(FOR.Accertamenti) do
            voci[#voci + 1] = {
                id = id, icona = a.icona, titolo = a.etichetta,
                descrizione = ('%s\n%s — %s'):format(a.descrizione, a.articolo, U.Euro(a.sanzione)),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Accertamento', sottotitolo = 'Alla persona che hai davanti', voci = voci })
        if not tipo then return end

        local mio, bersaglio, minima = PlayerPedId(), nil, 8.0
        for _, p in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= mio and ped ~= 0 then
                local d = #(GetEntityCoords(mio) - GetEntityCoords(ped))
                if d < minima then
                    minima = d
                    bersaglio = GetPlayerServerId(p)
                end
            end
        end
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Accertamento', testo = 'Non hai nessuno davanti.', durata = 10000 })
        end

        local ok, esito = AUREA.Callback.Attendi('for:accertamento', tipo, bersaglio)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Accertamento', testo = tostring(esito), durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '📋', durata = 20000,
            titolo = esito.etichetta,
            testo = ('A carico di %s.\nSanzione %s.%s')
                :format(esito.persona, U.Euro(esito.sanzione),
                        esito.sequestro and ('\nSequestrata: %s.'):format(esito.sequestro) or ''),
        })
    end)
end

local function registro()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('for:registro')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌲',
                titolo = 'Registro', testo = 'Riservato ai militari in servizio.', durata = 10000 })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            local a = FOR.GetAccertamento(r.tipo)
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = a and a.icona or '📋',
                titolo = ('%s — %s'):format(r.descrizione, r.persona or 'ignoto'),
                descrizione = ('%s · %s%s\n%d minuti fa')
                    :format(r.luogo or '—', U.Euro(r.sanzione or 0),
                            r.sequestro and (' · sequestro: ' .. r.sequestro) or '',
                            r.minutiFa or 0),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '📋', titolo = 'Nessun accertamento' }
        end

        exports.aurea_ui:Menu({ titolo = 'Registro degli accertamenti',
            sottotitolo = 'Gli ultimi venti', voci = voci })
    end)
end

local function elencoVincoli()
    CreateThread(function()
        local lista = AUREA.Callback.Attendi('for:vincoliAttivi') or {}

        local voci = {}
        for _, v in ipairs(lista) do
            voci[#voci + 1] = {
                id = tostring(v.id), icona = '⛔',
                titolo = ('%.2f ettari — raggio %d m'):format(v.ettari, v.raggio),
                descrizione = ('%s\nSeleziona per metterlo sul navigatore.'):format(FOR.Vincolo.articolo),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🌲',
                titolo = 'Nessun terreno vincolato',
                descrizione = 'Finché nessuno brucia, non c\'è niente da vincolare.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Vincoli in vigore',
            sottotitolo = 'Soprassuoli percorsi dal fuoco', voci = voci })
        if not scelta or scelta == 'x' then return end

        for _, v in ipairs(lista) do
            if tostring(v.id) == scelta then
                SetNewWaypoint(v.centro.x + 0.0, v.centro.y + 0.0)
                return
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
--  La caserma
-- ---------------------------------------------------------------------------
local function caserma(sede)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = sede.nome,
            sottotitolo = 'Tutela forestale, ambientale e agroalimentare',
            voci = {
                { id = 'incendi', icona = '🔥', titolo = 'Incendi da rilevare',
                  descrizione = 'Prendere in carico una superficie percorsa dal fuoco.' },
                { id = 'accerta', icona = '📐', titolo = 'Chiudere un accertamento',
                  descrizione = 'Origine, ettari, e il vincolo decennale.' },
                { id = 'vincoli', icona = '⛔', titolo = 'Vincoli in vigore',
                  descrizione = 'I terreni su cui non si costruisce.' },
                { id = 'registro', icona = '📋', titolo = 'Registro degli accertamenti',
                  descrizione = 'Riservato ai militari.' },
            },
        })
        if scelta == 'incendi' then return prendiInCarico() end
        if scelta == 'accerta' then return accerta() end
        if scelta == 'vincoli' then return elencoVincoli() end
        if scelta == 'registro' then return registro() end
    end)
end

RegisterCommand('forestale', function()
    caserma(FOR.SedePrincipale())
end, false)

RegisterCommand('rilievo', rilevaPunto, false)
RegisterCommand('accertamento', contesta, false)
RegisterCommand('vincoli', elencoVincoli, false)

AddEventHandler('aurea:client:caricato', function()
    for _, sede in ipairs(FOR.Sedi) do
        local b = AddBlipForCoord(sede.coord)
        SetBlipSprite(b, sede.blip.sprite)
        SetBlipColour(b, sede.blip.colore)
        SetBlipScale(b, sede.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Carabinieri Forestali')
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('for_' .. sede.id, sede.coord, sede.raggio, {
            { etichetta = 'Comando Carabinieri Forestali', icona = '🌲',
              azione = function() caserma(sede) end },
        })
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    pulisciVincoli()
end)
