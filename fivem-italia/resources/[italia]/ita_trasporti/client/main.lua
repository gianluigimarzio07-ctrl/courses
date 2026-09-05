--[[
    AUREA · Trasporto pubblico (client)
]]

local U = AUREA.Util
local corsa = nil       -- { fermate, indice, blip }
local occupato = false

CreateThread(function()
    local d = TRA.Deposito
    local b = AddBlipForCoord(d.coord.x, d.coord.y, d.coord.z)
    SetBlipSprite(b, d.blip.sprite)
    SetBlipColour(b, d.blip.colore)
    SetBlipScale(b, d.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(d.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('deposito_atm', d.coord, 5.0, {
        { etichetta = 'Prendi una linea', icona = '🚌',
          lavoro = TRA.Lavoro, azione = function() apriLinee() end },
    })

    -- Ogni fermata è anche una biglietteria e un'obliteratrice
    local viste = {}
    for _, l in ipairs(TRA.Linee) do
        for _, f in ipairs(l.fermate) do
            local chiave = ('%.0f_%.0f'):format(f.coord.x, f.coord.y)
            if not viste[chiave] then
                viste[chiave] = true

                local bf = AddBlipForCoord(f.coord.x, f.coord.y, f.coord.z)
                SetBlipSprite(bf, 513)
                SetBlipColour(bf, 3)
                SetBlipScale(bf, 0.4)
                SetBlipAsShortRange(bf, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(f.nome)
                EndTextCommandSetBlipName(bf)

                exports.aurea_target:AggiungiZona('fermata_' .. chiave, f.coord, 4.0, {
                    { etichetta = 'Biglietteria', icona = '🎫',
                      azione = function() biglietteria() end },
                    { etichetta = 'Obliteratrice', icona = '✅',
                      azione = function() oblitera() end },
                })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Biglietti
-- ---------------------------------------------------------------------------
function biglietteria()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('tra:biglietti')
        if not dati then return end

        local voci = {}
        if dati.titolo then
            voci[#voci + 1] = { id = '_t', icona = '🎫',
                titolo = ('Hai %s'):format(dati.titolo.tipo),
                descrizione = ('Valido ancora %d minuti · %s'):format(dati.titolo.minuti,
                    dati.titolo.obliterato and 'obliterato' or 'DA OBLITERARE'),
                disattivata = true }
        end

        for _, b in ipairs(dati.biglietti) do
            voci[#voci + 1] = {
                id = b.id, icona = '🎫', titolo = b.nome,
                descrizione = ('Vale %d minuti dall\'acquisto.'):format(b.validitaMinuti),
                valore = U.Euro(b.prezzo),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Biglietteria',
            sottotitolo = 'Il biglietto va obliterato salendo, altrimenti non vale niente',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local ok, messaggio = AUREA.Callback.Attendi('tra:compra', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎫',
            titolo = 'Biglietto', testo = messaggio, durata = 12000,
        })
    end)
end

function oblitera()
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('tra:oblitera')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '✅',
            titolo = 'Obliterazione', testo = messaggio, durata = 10000,
        })
    end)
end

RegisterCommand('controllobiglietti', function()
    CreateThread(function()
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local bersaglio, distanza = nil, 4.0
        for _, altro in ipairs(GetActivePlayers()) do
            local p = GetPlayerPed(altro)
            if p ~= ped then
                local d = #(coord - GetEntityCoords(p))
                if d < distanza then bersaglio, distanza = GetPlayerServerId(altro), d end
            end
        end
        if not bersaglio then return end

        local esito, messaggio = AUREA.Callback.Attendi('tra:controlla', bersaglio)
        exports.aurea_ui:Notifica({
            tipo = esito and (esito.regolare and 'successo' or 'errore') or 'info',
            icona = '🎫', titolo = 'Controllo', testo = tostring(messaggio), durata = 13000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Servizio di linea
-- ---------------------------------------------------------------------------
function apriLinee()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('tra:linee')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Deposito', testo = errore })
        end

        local voci = { { id = 'mezzo', icona = '🚌', titolo = 'Prendi un autobus' } }
        for _, l in ipairs(dati.linee) do
            voci[#voci + 1] = {
                id = l.id, icona = '🚏', titolo = l.nome,
                descrizione = ('%d fermate'):format(l.fermate),
                valore = ('%s a fermata'):format(U.Euro(l.pagaFermata)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = TRA.Deposito.nome,
            sottotitolo = 'Si guadagna di più con passeggeri veri a bordo', voci = voci,
        })
        if not scelta then return end

        if scelta == 'mezzo' then
            local posto = dati.mezzi[math.random(#dati.mezzi)]
            local hash = GetHashKey(dati.modello)
            RequestModel(hash)
            local n = 0
            while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
            if not HasModelLoaded(hash) then return end
            local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
            SetVehicleNumberPlateText(v, 'ATM')
            SetModelAsNoLongerNeeded(hash)
            TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
            return
        end

        local ok, d2 = AUREA.Callback.Attendi('tra:avvia', scelta)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚌', titolo = 'Linea', testo = tostring(d2), durata = 10000,
            })
        end

        corsa = { fermate = d2.fermate, indice = 1 }
        segnaFermata()

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🚌', durata = 13000,
            titolo = d2.nome,
            testo = ('%d fermate. Fermati e aspetta che salgano.'):format(#d2.fermate),
        })
    end)
end

function segnaFermata()
    if not corsa then return end
    if corsa.blip then RemoveBlip(corsa.blip) end

    local f = corsa.fermate[corsa.indice]
    if not f then return end

    corsa.blip = AddBlipForCoord(f.x, f.y, f.z)
    SetBlipSprite(corsa.blip, 1)
    SetBlipColour(corsa.blip, 3)
    SetBlipRoute(corsa.blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(f.nome)
    EndTextCommandSetBlipName(corsa.blip)
end

CreateThread(function()
    while true do
        local attesa = 800

        if corsa and not occupato then
            local f = corsa.fermate[corsa.indice]
            if f then
                local ped = PlayerPedId()
                local v = GetVehiclePedIsIn(ped, false)

                if v ~= 0 then
                    local coord = GetEntityCoords(v)
                    if #(coord - vector3(f.x, f.y, f.z)) < TRA.Servizio.distanzaFermata
                       and GetEntitySpeed(v) < TRA.Servizio.velocitaMassimaFermata then
                        attesa = 0
                        exports.aurea_ui:Prompt(true, ('Fermata: %s'):format(f.nome), 'E')
                        if IsControlJustReleased(0, 38) then
                            exports.aurea_ui:Prompt(false)
                            fermata(v)
                        end
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

function fermata(veicolo)
    CreateThread(function()
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Salita e discesa passeggeri...',
            durata = TRA.Servizio.secondiFermata * 1000, annullabile = false,
        })
        occupato = false
        if not completato then return end

        -- Quanti giocatori veri sono a bordo
        local passeggeri = 0
        for posto = 0, 15 do
            local p = GetPedInVehicleSeat(veicolo, posto)
            if p ~= 0 and p ~= PlayerPedId() and IsPedAPlayer(p) then
                passeggeri = passeggeri + 1
            end
        end

        local ok, esito = AUREA.Callback.Attendi('tra:fermata', passeggeri)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚏', titolo = 'Fermata',
                testo = tostring(esito), durata = 9000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚏', durata = 8000,
            titolo = ('Fermata %d di %d'):format(esito.fermata, esito.totale),
            testo = ('%s%s'):format(U.Euro(esito.paga),
                esito.passeggeri > 0 and (' — %d passeggeri a bordo'):format(esito.passeggeri) or ''),
        })

        if esito.finita then
            if corsa and corsa.blip then RemoveBlip(corsa.blip) end
            corsa = nil
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '✅', titolo = 'Corsa conclusa',
                testo = ('Incassato in tutto %s.'):format(U.Euro(esito.incassato)), durata = 12000,
            })
        else
            corsa.indice = corsa.indice + 1
            segnaFermata()
        end
    end)
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and corsa and corsa.blip then RemoveBlip(corsa.blip) end
end)
