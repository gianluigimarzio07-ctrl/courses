--[[
    AUREA · Farmacia (client)
]]

local U = AUREA.Util

CreateThread(function()
    for n, f in ipairs(FAR.Farmacie) do
        local b = AddBlipForCoord(f.coord.x, f.coord.y, f.coord.z)
        SetBlipSprite(b, FAR.Blip.sprite)
        SetBlipColour(b, FAR.Blip.colore)
        SetBlipScale(b, FAR.Blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(f.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('farmacia_' .. n, f.coord, 2.5, {
            { etichetta = 'Banco farmaci', icona = '💊', azione = function() banco() end },
        })
    end
end)

function banco()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('far:banco')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Farmacia', testo = errore })
        end

        local voci = {}
        for _, f in ipairs(dati.catalogo) do
            local nota = f.descrizione
            if f.ricetta and f.haRicetta then
                nota = ('%s · ricetta di %s, %d confezioni')
                    :format(f.descrizione, f.medico, f.confezioni)
            elseif f.ricetta then
                nota = ('%s · SERVE LA RICETTA'):format(f.descrizione)
            end

            voci[#voci + 1] = {
                id = f.item,
                icona = f.ricetta and (f.haRicetta and '📋' or '🔒') or '💊',
                titolo = f.nome, descrizione = nota,
                valore = f.ricetta and f.haRicetta
                    and ('ticket %s'):format(U.Euro(f.prezzo))
                    or U.Euro(f.prezzo),
                disattivata = f.ricetta and not f.haRicetta,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Farmacia',
            sottotitolo = ('Con ricetta paghi il ticket, il %d%% del prezzo pieno')
                :format(math.floor(dati.quotaTicket * 100)),
            voci = voci,
        })
        if not scelta then return end

        local r = exports.aurea_ui:Dialogo('Quante confezioni?', {
            { etichetta = 'Confezioni', tipo = 'number', valore = 1, min = 1, max = 10,
              obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('far:acquista', scelta, r[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💊',
            titolo = 'Farmacia', testo = messaggio, durata = 12000,
        })
    end)
end

--- Il medico prescrive a chi ha davanti.
RegisterCommand('ricetta', function()
    CreateThread(function()
        local prescrivibili = AUREA.Callback.Attendi('far:prescrivibili')
        if not prescrivibili or #prescrivibili == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📋', titolo = 'Ricetta',
                testo = 'Non sei abilitato a prescrivere.',
            })
        end

        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local paziente, distanza = nil, 4.0
        for _, altro in ipairs(GetActivePlayers()) do
            local p = GetPlayerPed(altro)
            if p ~= ped then
                local d = #(coord - GetEntityCoords(p))
                if d < distanza then paziente, distanza = GetPlayerServerId(altro), d end
            end
        end
        if not paziente then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📋', titolo = 'Nessun paziente',
                testo = 'Deve essere davanti a te.',
            })
        end

        local voci = {}
        for _, f in ipairs(prescrivibili) do
            voci[#voci + 1] = { id = f.item, icona = '💊', titolo = f.nome, descrizione = f.descrizione }
        end

        local farmaco = exports.aurea_ui:Menu({
            titolo = 'Prescrizione', sottotitolo = 'Vale 48 ore e va portata in farmacia', voci = voci,
        })
        if not farmaco then return end

        local r = exports.aurea_ui:Dialogo('Confezioni', {
            { etichetta = ('Quante (max %d)'):format(FAR.Ricette.confezioniMassime),
              tipo = 'number', valore = 1, min = 1, max = FAR.Ricette.confezioniMassime,
              obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('far:prescrivi', paziente, farmaco, r[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📋',
            titolo = 'Ricetta', testo = messaggio, durata = 12000,
        })
    end)
end, false)
