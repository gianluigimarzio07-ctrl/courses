--[[
    AUREA · Segnalazioni automatiche al 112

    Alcuni eventi generano da soli una chiamata: uno sparo in strada, un
    incidente violento, un incendio. È ciò che rende il mondo reattivo anche
    senza un cittadino che componga il numero.
]]

local ultimaSegnalazione = {}

local function puoSegnalare(chiave, secondi)
    local adesso = GetGameTimer()
    if (adesso - (ultimaSegnalazione[chiave] or 0)) < (secondi * 1000) then return false end
    ultimaSegnalazione[chiave] = adesso
    return true
end

--- Un ente in servizio non genera segnalazioni su di sé.
local function eOperatore()
    if not AUREA.PG then return false end
    local lavoro = AUREA.PG.lavoro.nome
    return lavoro == 'carabinieri' or lavoro == 'polizia' or lavoro == '118'
        or lavoro == 'vigili_fuoco' or lavoro == 'guardia_finanza'
end

-- ---------------------------------------------------------------------------
--  Colpi d'arma da fuoco
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(300)
        local ped = PlayerPedId()

        if IsPedShooting(ped) and not eOperatore() then
            local arma = GetSelectedPedWeapon(ped)
            -- taser e armi non letali non allertano la centrale
            if arma ~= `WEAPON_STUNGUN` and arma ~= `WEAPON_UNARMED` and arma ~= `WEAPON_PETROLCAN` then
                local coord = GetEntityCoords(ped)

                -- Solo se ci sono testimoni: pedoni o altri giocatori nei paraggi
                local testimoni = 0
                for _, altro in ipairs(GetActivePlayers()) do
                    local altroPed = GetPlayerPed(altro)
                    if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < 80.0 then
                        testimoni = testimoni + 1
                    end
                end

                local silenziata = GetPedWeaponTintIndex and IsPedCurrentWeaponSilenced(ped)
                local raggio = silenziata and 25.0 or 90.0

                if (testimoni > 0 or math.random(100) <= 55) and puoSegnalare('spari', 90) then
                    TriggerServerEvent('nue:segnalazioneAutomatica', 'spari', {
                        x = coord.x, y = coord.y, z = coord.z,
                    }, AUREA.Indirizzo(coord), silenziata)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Incidenti stradali gravi
-- ---------------------------------------------------------------------------
CreateThread(function()
    local ultimaVelocita = 0

    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veicolo = GetVehiclePedIsIn(ped, false)

        if veicolo ~= 0 then
            local kmh = GetEntitySpeed(veicolo) * 3.6

            -- decelerazione brusca da velocità elevata: impatto
            if ultimaVelocita > 70 and kmh < 20 and puoSegnalare('incidente', 120) then
                local coord = GetEntityCoords(veicolo)
                local salute = GetEntityHealth(ped)
                local grave = salute < 140 or ultimaVelocita > 110

                TriggerServerEvent('nue:segnalazioneAutomatica',
                    grave and 'incidente_grave' or 'incidente',
                    { x = coord.x, y = coord.y, z = coord.z },
                    AUREA.Indirizzo(coord))

                exports.aurea_ui:Notifica({
                    tipo = 'avviso', icona = '🚨', durata = 9000,
                    titolo = 'Sinistro rilevato',
                    testo = 'Il sistema eCall ha allertato automaticamente il 112.',
                })
            end

            ultimaVelocita = kmh
        else
            ultimaVelocita = 0
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Incendi nei paraggi
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(4000)
        if not eOperatore() then
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)

            if IsEntityOnFire(ped) or GetNumberOfFiresInRange(coord.x, coord.y, coord.z, 40.0) > 0 then
                if puoSegnalare('incendio', 180) then
                    TriggerServerEvent('nue:segnalazioneAutomatica', 'incendio',
                        { x = coord.x, y = coord.y, z = coord.z }, AUREA.Indirizzo(coord))
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Persona a terra: chi assiste può far partire la chiamata con un tasto
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)

        for _, altro in ipairs(GetActivePlayers()) do
            local altroPed = GetPlayerPed(altro)
            if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < 3.0 then
                if IsEntityDead(altroPed) or IsPedRagdoll(altroPed) then
                    attesa = 0
                    exports.aurea_ui:Prompt(true, 'Chiama il 118 per questa persona', 'G')
                    if IsControlJustReleased(0, 47) and puoSegnalare('soccorso', 60) then
                        exports.aurea_ui:Prompt(false)
                        local c = GetEntityCoords(altroPed)
                        TriggerServerEvent('nue:segnalazioneAutomatica', 'trauma',
                            { x = c.x, y = c.y, z = c.z }, AUREA.Indirizzo(c))
                        exports.aurea_ui:Notifica({
                            tipo = 'info', icona = '🚑',
                            titolo = '112 allertato', testo = 'I soccorsi sono in arrivo. Resta con la persona.',
                        })
                    end
                    break
                end
            end
        end

        if attesa ~= 0 then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)
