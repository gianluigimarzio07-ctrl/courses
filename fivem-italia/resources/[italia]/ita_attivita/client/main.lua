--[[
    AUREA · Attività di raccolta (client)
]]

local U = AUREA.Util
local inAzione = false

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
CreateThread(function()
    local function area(coord, raggio, sprite, colore, nome)
        local b = AddBlipForCoord(coord.x, coord.y, coord.z)
        SetBlipSprite(b, sprite) SetBlipColour(b, colore)
        SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(nome) EndTextCommandSetBlipName(b)

        local a = AddBlipForRadius(coord.x, coord.y, coord.z, raggio)
        SetBlipColour(a, colore) SetBlipAlpha(a, 45)
    end

    for _, z in ipairs(ATT.Pesca.zone) do area(z.coord, z.raggio, 68, 3, z.nome) end
    for _, z in ipairs(ATT.Caccia.zone) do area(z.coord, z.raggio, 141, 2, z.nome) end
    for _, z in ipairs(ATT.Raccolta.zone) do area(z.coord, z.raggio, 478, 2, z.nome) end
    area(ATT.Cava.coord, ATT.Cava.raggio, 527, 46, ATT.Cava.nome)

    local m = AddBlipForCoord(ATT.Pesca.mercatoIttico.coord.x, ATT.Pesca.mercatoIttico.coord.y, ATT.Pesca.mercatoIttico.coord.z)
    SetBlipSprite(m, 496) SetBlipColour(m, 3) SetBlipScale(m, 0.65) SetBlipAsShortRange(m, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(ATT.Pesca.mercatoIttico.nome) EndTextCommandSetBlipName(m)

    local s = AddBlipForCoord(ATT.Sportello.coord.x, ATT.Sportello.coord.y, ATT.Sportello.coord.z)
    SetBlipSprite(s, 498) SetBlipColour(s, 5) SetBlipScale(s, 0.7) SetBlipAsShortRange(s, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(ATT.Sportello.nome) EndTextCommandSetBlipName(s)
end)

-- ---------------------------------------------------------------------------
--  Interazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local trovato = false

        if #(coord - ATT.Sportello.coord) < 2.2 then
            trovato = true attesa = 0
            exports.aurea_ui:Prompt(true, ATT.Sportello.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuLicenze()
            end
        end

        if not trovato and not inAzione and not IsPedInAnyVehicle(ped, false) then
            local zonaPesca = ATT.ZonaPesca(coord)
            if zonaPesca then
                trovato = true attesa = 0
                exports.aurea_ui:Prompt(true, ('Pesca — %s'):format(zonaPesca.nome), 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    pesca()
                end
            end

            if not trovato and #(coord - ATT.Cava.coord) < ATT.Cava.raggio then
                trovato = true attesa = 0
                exports.aurea_ui:Prompt(true, ATT.Cava.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    cava()
                end
            end

            if not trovato then
                local zonaRaccolta = ATT.ZonaRaccolta(coord)
                if zonaRaccolta then
                    trovato = true attesa = 0
                    exports.aurea_ui:Prompt(true, ('Raccogli — %s'):format(zonaRaccolta.nome), 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        raccolta()
                    end
                end
            end
        end

        if not trovato then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Sportello licenze
-- ---------------------------------------------------------------------------
function menuLicenze()
    CreateThread(function()
        local licenze = AUREA.Callback.Attendi('att:licenze') or {}

        local voci = {}
        for _, l in ipairs(licenze) do
            voci[#voci + 1] = {
                id = l.tipo,
                icona = l.attiva and '✅' or '📄',
                titolo = l.etichetta,
                descrizione = l.attiva
                    and ('Valida fino al %s'):format(l.scadenza)
                    or ('Rilasciata da: %s'):format(l.rilasciata),
                valore = l.attiva and 'in corso' or U.Euro(l.costo),
                disattivata = l.attiva,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ATT.Sportello.nome,
            sottotitolo = 'Pesca, caccia e raccolta richiedono un titolo',
            voci = voci,
        })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('att:richiediLicenza', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '📄', titolo = ok and 'Licenza rilasciata' or 'Rilascio negato',
            testo = messaggio, durata = 11000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Pesca
-- ---------------------------------------------------------------------------
function pesca()
    CreateThread(function()
        if inAzione then return end

        local dati, errore = AUREA.Callback.Attendi('att:pesca')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🎣', titolo = 'Non si può pescare', testo = errore })
        end

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = ('Pesca in corso — %s'):format(dati.zona),
            durata = dati.durata,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_stand_fishing@idle_a', nome = 'idle_c' },
            blocca = { movimento = true },
        })

        if not completata then
            inAzione = false
            return
        end

        local ok, messaggio = AUREA.Callback.Attendi('att:concludiPesca')
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🎣', titolo = ok and 'Battuta di pesca' or 'Problema',
            testo = messaggio, durata = 10000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Caccia: si registra l'abbattimento della selvaggina
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1500)
        local ped = PlayerPedId()

        if IsPedShooting(ped) or IsPedArmed(ped, 4) then
            local animali = GetGamePool('CPed')
            local coord = GetEntityCoords(ped)

            for _, animale in ipairs(animali) do
                if IsEntityDead(animale) and IsPedAPlayer(animale) == false
                   and not DecorExistOn(animale, 'AUREA_ABBATTUTO') then
                    if #(coord - GetEntityCoords(animale)) < 30.0
                       and HasEntityBeenDamagedByEntity(animale, ped, true) then

                        DecorSetBool(animale, 'AUREA_ABBATTUTO', true)
                        local modello = GetEntityModel(animale)

                        -- si risale al nome del modello confrontando gli hash
                        local nome = nil
                        for _, s in ipairs(ATT.Caccia.specie) do
                            if GetHashKey(s.modello) == modello then nome = s.modello break end
                        end
                        if not nome then
                            for _, p in ipairs(ATT.Caccia.protette) do
                                if GetHashKey(p.modello) == modello then nome = p.modello break end
                            end
                        end

                        if nome then
                            CreateThread(function()
                                local ok, messaggio = AUREA.Callback.Attendi('att:abbattimento', nome)
                                exports.aurea_ui:Notifica({
                                    tipo = ok and 'successo' or 'errore',
                                    icona = '🦌', titolo = ok and 'Capo abbattuto' or 'Abbattimento illecito',
                                    testo = messaggio, durata = 12000,
                                })
                            end)
                        end
                    end
                end
            end
        end
    end
end)

CreateThread(function() DecorRegister('AUREA_ABBATTUTO', 2) end)

-- ---------------------------------------------------------------------------
--  Cava
-- ---------------------------------------------------------------------------
function cava()
    CreateThread(function()
        if inAzione then return end

        local dati, errore = AUREA.Callback.Attendi('att:cava')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⛏', titolo = 'Non si può scavare', testo = errore })
        end

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Estrazione in corso...',
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'melee@hatchet@streamed_core', nome = 'plyr_front_takedown' },
            blocca = { movimento = true },
        })

        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('att:concludiCava')
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '⛏', titolo = ok and 'Materiale estratto' or 'Estrazione fallita',
            testo = messaggio, durata = 9000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Raccolta
-- ---------------------------------------------------------------------------
function raccolta()
    CreateThread(function()
        if inAzione then return end

        local dati, errore = AUREA.Callback.Attendi('att:raccolta')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🍄', titolo = 'Raccolta non consentita', testo = errore })
        end

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = ('Raccolta — %s'):format(dati.zona),
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })

        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('att:concludiRaccolta')
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🍄', titolo = ok and 'Raccolto' or 'Raccolta fallita',
            testo = messaggio, durata = 9000,
        })
    end)
end

RegisterCommand('licenze', function() menuLicenze() end, false)
