--[[
    AUREA · Corse clandestine (client)

    Disegna il checkpoint successivo e chiede al server di validarlo. Il
    server ricontrolla la posizione: passare un checkpoint scrivendo al
    client non serve a niente.
]]

local gara = nil
local mio = { checkpoint = 0, giro = 1 }
local blipCp = nil

RegisterNetEvent('cor:gara', function(g)
    gara = g
    if not g then
        mio = { checkpoint = 0, giro = 1 }
        if blipCp then RemoveBlip(blipCp) blipCp = nil end
    end
end)

--- Il prossimo checkpoint che tocca a me.
local function prossimo()
    if not gara or gara.stato ~= 'corsa' then return nil end
    local t = COR.GetTracciato(gara.tracciato)
    if not t then return nil end
    local indice = (mio.checkpoint % #t.checkpoint) + 1
    return indice, t.checkpoint[indice], t
end

local function segnaBlip(coord)
    if blipCp then RemoveBlip(blipCp) end
    blipCp = AddBlipForCoord(coord)
    SetBlipSprite(blipCp, 1)
    SetBlipColour(blipCp, 5)
    SetBlipScale(blipCp, 0.9)
    SetBlipRoute(blipCp, true)
    SetBlipRouteColour(blipCp, 5)
end

CreateThread(function()
    while true do
        local attesa = 700
        local indice, coord, t = prossimo()

        if indice and coord then
            attesa = 0
            DrawMarker(1, coord.x, coord.y, coord.z - 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                COR.RaggioCheckpoint, COR.RaggioCheckpoint, 3.0, 240, 190, 40, 90, false, false, 2, false)

            if not blipCp or mio.segnato ~= indice then
                mio.segnato = indice
                segnaBlip(coord)
            end

            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false)
                and #(GetEntityCoords(ped) - coord) <= COR.RaggioCheckpoint then

                local ok, esito = AUREA.Callback.Attendi('cor:checkpoint', indice)
                if ok and esito then
                    if esito.arrivato then
                        mio = { checkpoint = 0, giro = 1 }
                        exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🏁',
                            titolo = 'Arrivato', testo = ('%d° al traguardo.'):format(esito.posizione), durata = 12000 })
                        if blipCp then RemoveBlip(blipCp) blipCp = nil end
                    else
                        mio.checkpoint, mio.giro = esito.checkpoint, esito.giro
                        exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏁', durata = 3500,
                            titolo = ('Giro %d di %d'):format(esito.giro, t.giri),
                            testo = ('Checkpoint %d'):format((esito.checkpoint - 1) % #t.checkpoint + 1) })
                    end
                    Wait(900)
                end
            end
        elseif blipCp then
            RemoveBlip(blipCp) blipCp = nil
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Il pannello
-- ---------------------------------------------------------------------------
RegisterCommand('corsa', function()
    CreateThread(function()
        if gara and gara.stato == 'iscrizioni' then
            local t = COR.GetTracciato(gara.tracciato)
            local scelta = exports.aurea_ui:Menu({
                titolo = ('Iscrizioni aperte — %s'):format(t.nome),
                sottotitolo = ('%s di quota · %d iscritti · %d giri'):format(
                    AUREA.Util.Euro(gara.quota), gara.iscritti, t.giri),
                voci = {
                    { id = 'iscriviti', icona = '🏁', titolo = 'Iscriviti',
                      descrizione = 'Devi essere al volante, in griglia, e avere i contanti.' },
                    { id = 'x', disattivata = true, icona = '⚠',
                      titolo = 'Art. 9-ter Codice della Strada',
                      descrizione = ('Sanzione %s, %d punti, sospensione della patente e CONFISCA del veicolo.')
                          :format(AUREA.Util.Euro(COR.Rischio.sanzione), COR.Rischio.puntiPatente) },
                },
            })
            if scelta ~= 'iscriviti' then return end

            local ok, messaggio = AUREA.Callback.Attendi('cor:iscriviti')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🏁',
                titolo = 'Corsa', testo = tostring(messaggio), durata = 16000 })
        end

        if gara and gara.stato == 'corsa' then
            local voci = {}
            for i, c in ipairs(gara.classifica or {}) do
                voci[#voci + 1] = { id = 'x', disattivata = true,
                    icona = c.arrivato and '🏆' or (c.ritirato and '⛔' or '🚗'),
                    titolo = ('%d. %s'):format(i, c.nome),
                    descrizione = c.ritirato and 'Fermato dalla polizia'
                        or ('Giro %d · checkpoint %d'):format(c.giro, c.checkpoint) }
            end
            return exports.aurea_ui:Menu({ titolo = 'Gara in corso', sottotitolo = 'Situazione', voci = voci })
        end

        -- Nessuna gara: se ne può aprire una
        local voci = {}
        for _, t in ipairs(COR.Tracciati) do
            voci[#voci + 1] = { id = t.id, icona = '🏁', titolo = t.nome,
                descrizione = ('%s · %d giri · %d checkpoint\n%s')
                    :format(t.zona, t.giri, #t.checkpoint, t.descrizione) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Apri una corsa',
            sottotitolo = 'Devi essere al volante, sul primo checkpoint',
            voci = voci,
        })
        if not scelta then return end

        local r = exports.aurea_ui:Dialogo('Quota di iscrizione', {
            { etichetta = 'Quota in euro, per ciascuno', tipo = 'number',
              min = math.floor(COR.Gara.quotaMinima / 100),
              max = math.floor(COR.Gara.quotaMassima / 100), obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('cor:apri', scelta, tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏁',
            titolo = 'Corsa', testo = tostring(messaggio), durata = 20000,
        })
    end)
end, false)
