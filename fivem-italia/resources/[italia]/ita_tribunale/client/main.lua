--[[
    AUREA · Tribunale (client)
]]

local U = AUREA.Util

CreateThread(function()
    local s = TRI.Sede
    local b = AddBlipForCoord(s.aula.x, s.aula.y, s.aula.z)
    SetBlipSprite(b, s.blip.sprite)
    SetBlipColour(b, s.blip.colore)
    SetBlipScale(b, s.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.nome)
    EndTextCommandSetBlipName(b)
end)

--- Il magistrato apre l'udienza su chi ha davanti.
RegisterCommand('udienza', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local imputato, distanza = nil, 8.0
        for _, altro in ipairs(GetActivePlayers()) do
            local p = GetPlayerPed(altro)
            if p ~= ped then
                local d = #(coord - GetEntityCoords(p))
                if d < distanza then imputato, distanza = GetPlayerServerId(altro), d end
            end
        end
        if not imputato then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '⚖', titolo = 'Nessun imputato',
                testo = 'Deve essere in aula davanti a te.',
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('tri:apri', imputato)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Udienza', testo = messaggio, durata = 14000,
        })
    end)
end, false)

--- L'imputato: gli si presentano i capi e le strade possibili.
RegisterNetEvent('tri:convocato', function(d)
    CreateThread(function()
        local righe = {}
        for _, c in ipairs(d.capi) do
            righe[#righe + 1] = {
                id = '_c' .. c.id, icona = '📋',
                titolo = ('%s (%s)'):format(c.reato, c.articolo),
                descrizione = ('%d minuti richiesti · ammenda %s')
                    :format(c.pena_mesi, U.Euro(c.ammenda)),
                disattivata = true,
            }
        end

        exports.aurea_ui:Menu({
            titolo = ('Sei a processo davanti a %s'):format(d.giudice),
            sottotitolo = ('%d capi d\'imputazione · %d minuti e %s richiesti')
                :format(#d.capi, d.pena, U.Euro(d.ammenda)),
            voci = righe,
        })

        -- La scelta del rito
        local voci = {}
        for id, r in pairs(d.riti) do
            local esito
            if r.sconto > 0 then
                esito = ('~%d minuti'):format(math.floor(d.pena * (1 - r.sconto)))
            else
                esito = ('fino a %d minuti'):format(d.pena)
            end
            voci[#voci + 1] = {
                id = id, icona = r.icona, titolo = r.nome,
                descrizione = r.descrizione, valore = esito,
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local rito = exports.aurea_ui:Menu({
            titolo = 'Come vuoi essere giudicato?',
            sottotitolo = 'Il patteggiamento è sicuro, il dibattimento è un rischio che può pagare',
            voci = voci,
        })
        if not rito then return end

        -- Il difensore
        local difensore = nil
        if d.riti[rito].richiedeAvvocato then
            local elenco = {}
            for _, a in ipairs(d.avvocati) do
                elenco[#elenco + 1] = {
                    id = tostring(a.src), icona = '👔', titolo = a.nome,
                    valore = U.Euro(d.onorario),
                }
            end
            elenco[#elenco + 1] = {
                id = 'ufficio', icona = '📎', titolo = 'Difensore d\'ufficio',
                descrizione = 'Fa il minimo, ma costa poco.',
                valore = U.Euro(d.onorarioUfficio),
            }

            local scelto = exports.aurea_ui:Menu({
                titolo = 'Chi ti difende?',
                sottotitolo = 'L\'onorario è a tuo carico', voci = elenco,
            })
            if not scelto then return end
            if scelto ~= 'ufficio' then difensore = tonumber(scelto) end
        end

        local ok, messaggio = AUREA.Callback.Attendi('tri:scegli', d.id, rito, difensore)
        exports.aurea_ui:Notifica({
            tipo = ok and 'info' or 'errore', icona = '⚖',
            titolo = 'Udienza', testo = messaggio, durata = 14000,
        })
    end)
end)

--- Il giudice decide.
RegisterNetEvent('tri:pronta', function(d)
    CreateThread(function()
        local voci = {}
        for _, c in ipairs(d.capi) do
            voci[#voci + 1] = {
                id = '_c' .. c.id, icona = '📋',
                titolo = ('%s (%s)'):format(c.reato, c.articolo),
                descrizione = ('%d minuti · %s'):format(c.pena_mesi, U.Euro(c.ammenda)),
                disattivata = true,
            }
        end

        voci[#voci + 1] = { id = 'condanna', icona = '⚖', titolo = 'Pronuncia la condanna',
                            descrizione = d.sconto > 0
                                and ('Lo sconto di rito porta la pena a ~%d minuti.')
                                    :format(math.floor(d.pena * (1 - d.sconto)))
                                or 'Nessuno sconto: si applica la pena che decidi.' }

        if d.ammetteAssoluzione then
            voci[#voci + 1] = { id = 'assoluzione', icona = '🕊', titolo = 'Assolvi',
                                descrizione = 'Tutti i capi cadono e il ricercato si azzera.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Udienza contro %s'):format(d.imputato),
            sottotitolo = ('%s · difeso da %s · richiesti %d minuti')
                :format(d.rito, d.difensore or 'nessuno', d.pena),
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local massimo = d.ammetteAggravio
            and math.floor(d.pena * (1 + (d.aggravioMassimo or 0))) or d.pena

        local mesi = d.pena
        if scelta == 'condanna' then
            local r = exports.aurea_ui:Dialogo('Pena base', {
                { etichetta = ('Minuti (richiesti %d, massimo %d)'):format(d.pena, massimo),
                  tipo = 'number', valore = d.pena, min = 0, max = massimo, obbligatorio = true },
            })
            if not r or not r[1] then return end
            mesi = r[1]
        end

        local m = exports.aurea_ui:Dialogo('Motivazione', {
            { etichetta = 'Motivazione della sentenza', tipo = 'textarea',
              segnaposto = 'Verrà letta all\'imputato' },
        })

        local ok, messaggio = AUREA.Callback.Attendi('tri:sentenza', d.id, scelta, mesi,
            m and m[1] or '')

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Sentenza', testo = messaggio, durata = 16000,
        })
    end)
end)

RegisterCommand('processi', function()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('tri:pendenti')
        if not elenco or #elenco == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚖', titolo = 'Tribunale',
                testo = 'Nessuna udienza che ti riguardi.',
            })
        end

        local voci = {}
        for _, u in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(u.id), icona = '⚖',
                titolo = ('Udienza %d — %s'):format(u.id, u.imputato),
                descrizione = ('Presiede %s · %d capi · %s')
                    :format(u.giudice, u.capi, u.rito),
                valore = ('%d min'):format(u.pena),
                disattivata = true,
            }
        end

        exports.aurea_ui:Menu({
            titolo = 'Udienze in corso', sottotitolo = TRI.Sede.nome, voci = voci,
        })
    end)
end, false)
