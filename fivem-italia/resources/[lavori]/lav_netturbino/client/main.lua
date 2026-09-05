--[[
    AUREA · Nettezza urbana (client)
]]

local U = AUREA.Util
local giro = nil    -- { punti, indice, blip }
local occupato = false

CreateThread(function()
    local d = NET.Deposito
    local b = AddBlipForCoord(d.coord.x, d.coord.y, d.coord.z)
    SetBlipSprite(b, d.blip.sprite)
    SetBlipColour(b, d.blip.colore)
    SetBlipScale(b, d.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(d.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('netturbino', d.coord, 4.0, {
        { etichetta = 'Prendi un giro', icona = '🗑',
          lavoro = NET.Lavoro, azione = function() apri() end },
    })

    exports.aurea_target:AggiungiZona('isola_ecologica', NET.Conferimento.coord, 6.0, {
        { etichetta = 'Conferisci differenziato', icona = '♻',
          azione = function() conferisci(true) end },
        { etichetta = 'Butta tutto insieme', icona = '🗑',
          descrizione = 'Vale la metà.',
          azione = function() conferisci(false) end },
    })
end)

function apri()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('net:giri')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Deposito', testo = errore })
        end

        local voci = {
            { id = 'mezzo', icona = '🚛', titolo = 'Prendi il compattatore' },
            { id = '_b', icona = '👥',
              titolo = ('Lavorare in squadra rende il %d%% in più a testa')
                  :format(math.floor(dati.bonus * 100)),
              descrizione = 'Per ogni collega in servizio entro venticinque metri.',
              disattivata = true },
        }

        for _, g in ipairs(dati.giri) do
            voci[#voci + 1] = {
                id = g.id, icona = '🗑', titolo = g.nome,
                descrizione = ('%d cassonetti'):format(g.cassonetti),
                valore = ('%s a cassonetto'):format(U.Euro(g.paga)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = NET.Deposito.nome, sottotitolo = 'Si paga a cassonetto svuotato', voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'mezzo' then
            local posto = dati.mezzi[math.random(#dati.mezzi)]
            local hash = GetHashKey(dati.modello)
            RequestModel(hash)
            local n = 0
            while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
            if not HasModelLoaded(hash) then return end
            local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
            SetVehicleNumberPlateText(v, 'AMBIENTE')
            SetModelAsNoLongerNeeded(hash)
            TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
            return
        end

        local ok, dati2 = AUREA.Callback.Attendi('net:avvia', scelta)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🗑', titolo = 'Giro', testo = tostring(dati2), durata = 10000,
            })
        end

        giro = { punti = dati2.punti, indice = 1 }
        segnaPunto()

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🗑', durata = 13000,
            titolo = dati2.nome,
            testo = ('%d cassonetti. Scendi dal mezzo e svuotali a mano.'):format(#dati2.punti),
        })
    end)
end

function segnaPunto()
    if not giro then return end
    if giro.blip then RemoveBlip(giro.blip) end

    local p = giro.punti[giro.indice]
    if not p then return end

    giro.blip = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(giro.blip, 1)
    SetBlipColour(giro.blip, 2)
    SetBlipRoute(giro.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(('Cassonetto %d di %d'):format(giro.indice, #giro.punti))
    EndTextCommandSetBlipName(giro.blip)
end

CreateThread(function()
    while true do
        local attesa = 900

        if giro and not occupato then
            local p = giro.punti[giro.indice]
            if p then
                local coord = GetEntityCoords(PlayerPedId())
                if #(coord - vector3(p.x, p.y, p.z)) < NET.Raccolta.distanzaPunto then
                    attesa = 0
                    exports.aurea_ui:Prompt(true, 'Svuota il cassonetto', 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        svuota()
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

function svuota()
    CreateThread(function()
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Svuotamento...', durata = NET.Raccolta.durataSvuotamento, annullabile = true,
            anim = { dizionario = 'anim@heists@narcotics@trash', nome = 'idle' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local ok, esito = AUREA.Callback.Attendi('net:svuota')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🗑', titolo = 'Raccolta', testo = tostring(esito), durata = 9000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🗑', durata = 8000,
            titolo = ('%d di %d'):format(esito.svuotati, esito.totale),
            testo = ('%s%s%s'):format(U.Euro(esito.paga),
                esito.colleghi > 0 and (' (bonus per %d colleghi)'):format(esito.colleghi) or '',
                esito.recuperato and (' · recuperato %s'):format(esito.recuperato) or ''),
        })

        if esito.finito then
            if giro and giro.blip then RemoveBlip(giro.blip) end
            giro = nil
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '✅', durata = 12000,
                titolo = 'Giro completato',
                testo = 'Porta il recuperabile all\'isola ecologica: differenziato vale il doppio.',
            })
        else
            giro.indice = giro.indice + 1
            segnaPunto()
        end
    end)
end

function conferisci(differenziato)
    CreateThread(function()
        local completato = exports.aurea_ui:Progresso({
            etichetta = differenziato and 'Separazione dei materiali...' or 'Scarico...',
            durata = differenziato and 10000 or 4000, annullabile = true,
            blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('net:conferisci', differenziato)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '♻',
            titolo = 'Isola ecologica', testo = messaggio, durata = 12000,
        })
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and giro and giro.blip then RemoveBlip(giro.blip) end
end)
