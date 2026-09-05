--[[
    AUREA · Sosta a pagamento (client)
]]

local U = AUREA.Util

CreateThread(function()
    for n, p in ipairs(SOS.Parcometri) do
        local b = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
        SetBlipSprite(b, 606)
        SetBlipColour(b, 38)
        SetBlipScale(b, 0.45)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Parcometro')
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('parcometro_' .. n, p.coord, 2.0, {
            { etichetta = 'Parcometro', icona = '🅿', azione = function() parcometro() end },
        })
    end
end)

function targaVicina()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehicleNumberPlateText(GetVehiclePedIsIn(ped, false)):gsub('%s+', ''):upper()
    end
    local c = GetEntityCoords(ped)
    local v = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 71)
    if v ~= 0 then return GetVehicleNumberPlateText(v):gsub('%s+', ''):upper() end
    return ''
end

function parcometro()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('sos:parcometro', targaVicina())
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Parcometro', testo = errore })
        end

        if dati.gratuita then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🅿', durata = 11000,
                titolo = ('%s — sosta libera'):format(dati.zona),
                testo = 'In questa fascia oraria non si paga.',
            })
        end

        local voci = {
            { id = '_z', icona = '🅿', titolo = dati.zona,
              descrizione = dati.sostaAttiva
                  and ('Il veicolo %s ha già sosta per altri %d minuti.')
                      :format(dati.targa, dati.sostaAttiva)
                  or ('Tariffa %s l\'ora, frazioni da %d minuti.')
                      :format(U.Euro(dati.tariffa), dati.frazione),
              disattivata = true },
        }

        for ore = 1, dati.oreMassime do
            local minuti = ore * 60
            voci[#voci + 1] = {
                id = tostring(minuti), icona = '⏱',
                titolo = ('%d ora%s'):format(ore, ore > 1 and 'e' or ''),
                valore = U.Euro(math.floor(dati.tariffa * ore)),
            }
        end
        table.insert(voci, 2, {
            id = tostring(dati.frazione), icona = '⏱',
            titolo = ('%d minuti'):format(dati.frazione),
            valore = U.Euro(math.floor(dati.tariffa * dati.frazione / 60)),
        })

        if not dati.haPass then
            voci[#voci + 1] = { id = 'pass', icona = '🪪', titolo = 'Pass residenti',
                                descrizione = ('Vale %d giorni in questa zona. Serve la residenza.')
                                    :format(SOS.Regole.validitaPassGiorni),
                                valore = U.Euro(dati.costoPass) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Parcometro',
            sottotitolo = ('Veicolo %s'):format(dati.targa ~= '' and dati.targa or 'non rilevato'),
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'pass' then
            local ok, messaggio = AUREA.Callback.Attendi('sos:pass', dati.idZona)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🪪',
                titolo = 'Pass residenti', testo = messaggio, durata = 12000,
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('sos:paga', dati.targa, tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🅿',
            titolo = 'Sosta', testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Ausiliario del traffico
-- ---------------------------------------------------------------------------
RegisterCommand('controllosos', function()
    CreateThread(function()
        local targa = targaVicina()
        if targa == '' then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🅿', titolo = 'Nessun veicolo vicino',
            })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Verifica del titolo di sosta...', durata = 5000, annullabile = true,
        })
        if not completato then return end

        local esito, messaggio = AUREA.Callback.Attendi('sos:verifica', targa)
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🅿', titolo = 'Verifica', testo = tostring(messaggio), durata = 10000,
            })
        end

        if esito.regolare or esito.giaSanzionato then
            return exports.aurea_ui:Notifica({
                tipo = esito.regolare and 'successo' or 'info', icona = '🅿',
                titolo = targa, testo = messaggio, durata = 11000,
            })
        end

        local conferma = exports.aurea_ui:Menu({
            titolo = ('%s — nessun titolo valido'):format(targa),
            sottotitolo = ('%s · %s'):format(esito.zona, U.Euro(esito.importo)),
            voci = {
                { id = 'si', icona = '🧾', titolo = 'Eleva il preavviso' },
                { id = 'no', icona = '↩', titolo = 'Lascia stare' },
            },
        })
        if conferma ~= 'si' then return end

        local fatto = exports.aurea_ui:Progresso({
            etichetta = 'Compilazione del preavviso...', durata = 8000, annullabile = true,
            blocca = { movimento = true },
        })
        if not fatto then return end

        local ok, risposta = AUREA.Callback.Attendi('sos:sanziona', targa)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧾',
            titolo = 'Preavviso', testo = risposta, durata = 13000,
        })
    end)
end, false)

--- In zona blu si vede a colpo d'occhio dove si è.
CreateThread(function()
    while true do
        Wait(8000)
        local zona = SOS.ZonaDi(GetEntityCoords(PlayerPedId()))
        if zona and AUREA.EInServizio() and AUREA.HaLavoro(SOS.Lavoro) then
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🅿', durata = 5000,
                titolo = zona.nome, testo = 'Zona a sosta regolamentata. Usa /controllosos.',
            })
            Wait(180000)
        end
    end
end)
