--[[
    AUREA · Carburante e usura (client)

    Il consumo dipende dalla classe del veicolo e dallo stile di guida:
    accelerare a tavoletta costa più che tenere un'andatura costante.
]]

local U = AUREA.Util
local kmParziali = 0.0
local ultimoInvio = 0

-- ---------------------------------------------------------------------------
--  Blip dei distributori
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, d in ipairs(GAR.Distributori) do
        local blip = AddBlipForCoord(d.x, d.y, d.z)
        SetBlipSprite(blip, 361)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.55)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Distributore')
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------------------
--  Consumo, odometro e usura
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 and GetPedInVehicleSeat(veicolo, -1) == ped and GetIsVehicleEngineRunning(veicolo) then
            local classe = GetVehicleClass(veicolo)
            local moltiplicatore = GAR.Carburante.moltiplicatoriClasse[classe] or 1.0

            if moltiplicatore > 0 then
                local kmh = GetEntitySpeed(veicolo) * 3.6
                -- una guida aggressiva consuma fino al doppio
                local stile = 1.0 + math.min(1.0, math.max(0.0, (kmh - 90) / 90))
                local consumo = (GAR.Carburante.consumoBase / 30) * moltiplicatore * stile

                -- al minimo il consumo è ridotto ma non nullo
                if kmh < 3 then consumo = consumo * 0.2 end

                local livello = math.max(0.0, GetVehicleFuelLevel(veicolo) - consumo)
                SetVehicleFuelLevel(veicolo, livello)
                DecorSetFloat(veicolo, 'AUREA_CARBURANTE', livello)

                if livello <= 0.5 then
                    SetVehicleEngineOn(veicolo, false, true, true)
                    SetVehicleUndriveable(veicolo, true)
                elseif livello < 12 and math.random(10) == 1 then
                    exports.aurea_ui:Notifica({
                        tipo = 'avviso', icona = '⛽', durata = 5000,
                        titolo = 'Riserva', testo = ('Carburante al %d%%. Cerca un distributore.'):format(math.floor(livello)),
                    })
                end

                -- odometro
                kmParziali = kmParziali + (kmh * (2 / 3600))
                LocalPlayer.state:set('kmVeicolo', math.floor(kmParziali), false)

                -- usura del motore proporzionale ai km
                if kmParziali > 0 and math.floor(kmParziali) % 100 == 0 then
                    local salute = GetVehicleEngineHealth(veicolo)
                    SetVehicleEngineHealth(veicolo, math.max(200.0, salute - GAR.Usura.degradoMotorePer100km))
                end
            end

            -- sincronizzazione periodica con il server
            if (GetGameTimer() - ultimoInvio) > 45000 then
                ultimoInvio = GetGameTimer()
                TriggerServerEvent('gar:sincronizza', {
                    targa = GetVehicleNumberPlateText(veicolo),
                    carburante = GetVehicleFuelLevel(veicolo),
                    motore = GetVehicleEngineHealth(veicolo),
                    carrozzeria = GetVehicleBodyHealth(veicolo),
                    km = math.floor(kmParziali),
                })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Rifornimento al distributore
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo == 0 then
            veicolo = GetClosestVehicle(coord.x, coord.y, coord.z, 5.0, 0, 71)
        end

        if veicolo ~= 0 then
            for _, d in ipairs(GAR.Distributori) do
                if #(coord - d) < 3.0 then
                    attesa = 0
                    local livello = GetVehicleFuelLevel(veicolo)
                    exports.aurea_ui:Prompt(true, ('Rifornisci (%d%%)'):format(math.floor(livello)), 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        rifornisci(veicolo)
                    end
                    break
                end
            end
        end

        if attesa ~= 0 then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

function rifornisci(veicolo)
    CreateThread(function()
        if GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Scendi dal veicolo', testo = 'Non si fa rifornimento a bordo.' })
        end

        local livello = GetVehicleFuelLevel(veicolo)
        local mancanti = math.ceil(((100 - livello) / 100) * GAR.Carburante.capienzaMedia)
        if mancanti < 1 then
            return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Serbatoio pieno', testo = 'Non serve rifornire.' })
        end

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Distributore',
            sottotitolo = ('Serbatoio al %d%% · mancano circa %d litri'):format(math.floor(livello), mancanti),
            voci = {
                { id = 'pieno', icona = '⛽', titolo = 'Fai il pieno',
                  descrizione = ('%d litri di benzina'):format(mancanti),
                  valore = U.Euro(mancanti * GAR.Carburante.prezzoLitro) },
                { id = 'premium', icona = '✨', titolo = 'Pieno con additivato',
                  descrizione = 'Migliora la resa del motore.',
                  valore = U.Euro(mancanti * GAR.Carburante.prezzoLitroPremium) },
                { id = 'parziale', icona = '🪙', titolo = 'Importo a scelta',
                  descrizione = 'Indica quanti litri metterci.' },
            },
        })
        if not tipo then return end

        local litri = mancanti
        if tipo == 'parziale' then
            local valori = exports.aurea_ui:Dialogo('Quanti litri?', {
                { etichetta = 'Litri', tipo = 'number', valore = math.min(20, mancanti), min = 1, max = mancanti },
            })
            if not valori then return end
            litri = math.min(mancanti, tonumber(valori[1]) or 1)
        end

        local premium = tipo == 'premium'
        local ok, messaggio, litriErogati = AUREA.Callback.Attendi('gar:rifornisci', litri, premium)
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Rifornimento rifiutato', testo = messaggio, durata = 8000 })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Rifornimento in corso — %d litri'):format(litriErogati),
            durata = 1200 + litriErogati * 220,
            annullabile = false,
            blocca = { movimento = true },
        })

        if completato then
            local nuovo = math.min(100.0, livello + (litriErogati / GAR.Carburante.capienzaMedia) * 100)
            SetVehicleFuelLevel(veicolo, nuovo)
            SetVehicleUndriveable(veicolo, false)
            if premium then
                SetVehicleEngineHealth(veicolo, math.min(1000.0, GetVehicleEngineHealth(veicolo) + 40.0))
            end
            exports.aurea_ui:Notifica({ tipo = 'successo', icona = '⛽', titolo = 'Rifornimento completato', testo = messaggio })
        end
    end)
end

-- Il carburante persiste anche quando il veicolo esce dallo scope
CreateThread(function()
    DecorRegister('AUREA_CARBURANTE', 1)
    while true do
        Wait(4000)
        local veicolo = GetVehiclePedIsIn(PlayerPedId(), false)
        if veicolo ~= 0 and DecorExistOn(veicolo, 'AUREA_CARBURANTE') then
            local salvato = DecorGetFloat(veicolo, 'AUREA_CARBURANTE')
            if math.abs(salvato - GetVehicleFuelLevel(veicolo)) > 5.0 then
                SetVehicleFuelLevel(veicolo, salvato)
            end
        end
    end
end)
