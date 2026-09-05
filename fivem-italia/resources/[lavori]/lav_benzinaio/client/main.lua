--[[
    AUREA · Rifornimento distributori (client)
]]

local U = AUREA.Util
local occupato = false

CreateThread(function()
    local r = BEN.Raffineria
    local b = AddBlipForCoord(r.coord.x, r.coord.y, r.coord.z)
    SetBlipSprite(b, r.blip.sprite)
    SetBlipColour(b, r.blip.colore)
    SetBlipScale(b, r.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(r.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('raffineria', r.coord, 5.0, {
        { etichetta = 'Turno di rifornimento', icona = '⛽',
          lavoro = BEN.Lavoro, azione = function() apri() end },
    })

    exports.aurea_target:AggiungiZona('raffineria_carico', r.carico, 8.0, {
        { etichetta = 'Carica la cisterna', icona = '🛢',
          lavoro = BEN.Lavoro, inServizio = true, azione = function() carica() end },
    })

    for _, d in ipairs(BEN.Distributori) do
        exports.aurea_target:AggiungiZona('rifornisci_' .. d.id, d.coord, 8.0, {
            { etichetta = ('Rifornisci %s'):format(d.nome), icona = '⛽',
              lavoro = BEN.Lavoro, inServizio = true,
              azione = function() rifornisci(d.id) end },
        })
    end
end)

function apri()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('ben:stato')
        if not dati then return end

        local voci = {
            { id = '_c', icona = '🛢',
              titolo = ('In cisterna: %d litri su %d'):format(dati.cisterna, dati.capienzaCisterna),
              descrizione = ('Si guadagna %s al litro consegnato.'):format(U.Euro(dati.pagaAlLitro)),
              disattivata = true },
            { id = 'mezzo', icona = '🚛', titolo = 'Prendi l\'autocisterna',
              disattivata = not dati.eBenzinaio },
        }

        for _, d in ipairs(dati.distributori) do
            voci[#voci + 1] = {
                id = 'd:' .. d.id,
                icona = d.inRiserva and '🔴' or '🟢',
                titolo = d.nome,
                descrizione = ('%d litri su %d'):format(d.litri, d.capienza),
                valore = ('%d%%'):format(d.percentuale),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = BEN.Raffineria.nome,
            sottotitolo = 'Un distributore a secco smette di erogare per tutti',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'mezzo' then
            local posto = dati.mezzi[1]
            local hash = GetHashKey(dati.modello)
            RequestModel(hash)
            local n = 0
            while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
            if not HasModelLoaded(hash) then return end
            local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
            SetVehicleNumberPlateText(v, 'CISTERNA')
            SetModelAsNoLongerNeeded(hash)
            TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
            return
        end

        local id = scelta:match('^d:(.+)$')
        if id then
            local d = BEN.GetDistributore(id)
            if d then
                SetNewWaypoint(d.coord.x, d.coord.y)
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '📍', titolo = d.nome,
                    testo = 'Segnato sulla mappa.', durata = 8000,
                })
            end
        end
    end)
end

function carica()
    CreateThread(function()
        if occupato then return end

        local ok, durata = AUREA.Callback.Attendi('ben:carica')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🛢', titolo = 'Carico', testo = tostring(durata), durata = 9000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Carico della cisterna...', durata = durata, annullabile = true,
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local fatto, messaggio = AUREA.Callback.Attendi('ben:concludiCarico')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🛢',
            titolo = 'Cisterna', testo = messaggio, durata = 10000,
        })
    end)
end

function rifornisci(id)
    CreateThread(function()
        if occupato then return end

        local ok, dati = AUREA.Callback.Attendi('ben:rifornisci', id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '⛽', titolo = 'Rifornimento',
                testo = tostring(dati), durata = 10000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Scarico di %d litri...'):format(dati.litri),
            durata = dati.durata, annullabile = true, blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local fatto, messaggio = AUREA.Callback.Attendi('ben:concludiScarico', id)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '⛽',
            titolo = 'Rifornimento', testo = messaggio, durata = 13000,
        })
    end)
end

RegisterCommand('distributori', function() apri() end, false)
