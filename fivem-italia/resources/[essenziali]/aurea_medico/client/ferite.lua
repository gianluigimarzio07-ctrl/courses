--[[
    AUREA · Ferite localizzate (client)

    Ogni colpo ricevuto viene attribuito alla parte del corpo effettivamente
    colpita e produce una lesione con conseguenze proprie.
]]

Ferite = {
    lesioni = {},        -- [parte] = { tipo, gravita, emorragia, momento }
    emorragia = 0,
    conseguenze = {},
}

local ultimaSalute = 200

--- Aggiunge una lesione e ne propaga gli effetti.
function Ferite.Aggiungi(parte, tipoLesione)
    local lesione = MED.Lesioni[tipoLesione]
    local zona = MED.PartiCorpo[parte]
    if not lesione or not zona then return end

    Ferite.lesioni[parte] = {
        tipo = tipoLesione,
        etichetta = lesione.etichetta,
        parte = zona.etichetta,
        gravita = zona.gravita,
        emorragia = lesione.emorragia,
        immobilizza = lesione.immobilizza,
        momento = GetGameTimer(),
    }

    Ferite.Ricalcola()
    TriggerServerEvent('med:aggiornaFerite', Ferite.lesioni)

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🩸', durata = 7000,
        titolo = ('%s — %s'):format(zona.etichetta, lesione.etichetta),
        testo = lesione.emorragia > 0
            and 'Stai perdendo sangue: serve un bendaggio.'
            or (lesione.curaBase and 'Puoi medicarti da solo.' or 'Serve l\'intervento di personale sanitario.'),
    })

    -- Conseguenze durature per le lesioni agli arti
    if lesione.immobilizza then
        if parte:find('gamba') then Ferite.conseguenze.zoppia = true end
        if parte:find('braccio') then Ferite.conseguenze.tremore = true end
    end
    if parte == 'testa' and zona.gravita >= 5 then Ferite.conseguenze.offuscamento = true end
    if parte == 'torace' then Ferite.conseguenze.fiato_corto = true end
end

function Ferite.Ricalcola()
    local totale = 0
    for _, l in pairs(Ferite.lesioni) do totale = totale + (l.emorragia or 0) end
    Ferite.emorragia = totale
end

function Ferite.Rimuovi(parte)
    Ferite.lesioni[parte] = nil
    Ferite.Ricalcola()
    TriggerServerEvent('med:aggiornaFerite', Ferite.lesioni)
end

function Ferite.Azzera()
    Ferite.lesioni = {}
    Ferite.conseguenze = {}
    Ferite.emorragia = 0
    TriggerServerEvent('med:aggiornaFerite', {})
end

--- La prima lesione sanguinante trovata, per il bendaggio.
function Ferite.PrimaEmorragia()
    for parte, l in pairs(Ferite.lesioni) do
        if (l.emorragia or 0) > 0 then return parte, l end
    end
    return nil
end

function Ferite.Elenco()
    local out = {}
    for parte, l in pairs(Ferite.lesioni) do
        out[#out + 1] = { parte = parte, dati = l }
    end
    table.sort(out, function(a, b) return a.dati.gravita > b.dati.gravita end)
    return out
end

-- ---------------------------------------------------------------------------
--  Rilevamento dei danni subiti
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(250)
        local ped = PlayerPedId()
        local salute = GetEntityHealth(ped)

        if salute < ultimaSalute and salute > 0 then
            local danno = ultimaSalute - salute

            if danno >= 8 then
                local colpito, osso = GetPedLastDamageBone(ped)
                local parte = 'torace'
                if colpito then parte = MED.ParteDaOsso(osso) end

                local arma = `WEAPON_UNARMED`
                for _, hash in ipairs({ `WEAPON_PISTOL`, `WEAPON_SMG`, `WEAPON_ASSAULTRIFLE`, `WEAPON_KNIFE`,
                                        `WEAPON_BAT`, `WEAPON_HAMMER`, `WEAPON_MACHETE`, `WEAPON_MOLOTOV`,
                                        `WEAPON_RUN_OVER_BY_CAR`, `WEAPON_RAMMED_BY_CAR`, `WEAPON_FALL` }) do
                    if HasPedBeenDamagedByWeapon(ped, hash, 0) then arma = hash break end
                end

                local tipo = MED.LesioneDaArma(arma)
                -- un danno lieve non produce una ferita da arma da fuoco
                if danno < 20 and tipo == 'ferita_arma' then tipo = 'lacerazione' end
                -- una caduta rovinosa frattura
                if arma == `WEAPON_FALL` and danno > 35 then tipo = 'frattura' end

                Ferite.Aggiungi(parte, tipo)
                ClearEntityLastDamageEntity(ped)
            end
        end

        ultimaSalute = salute
    end
end)

-- ---------------------------------------------------------------------------
--  Effetti continui: emorragia, dolore, conseguenze
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()

        if Ferite.emorragia > 0 and not IsEntityDead(ped) then
            local salute = GetEntityHealth(ped)
            local nuovo = math.max(MED.Regole.sogliaIncoscienza, salute - MED.Regole.dannoEmorragia * Ferite.emorragia)
            SetEntityHealth(ped, math.floor(nuovo))

            -- effetto visivo del dissanguamento
            if Ferite.emorragia >= 3 then
                SetTimecycleModifier('Bank_HeistFlash')
                SetTimecycleModifierStrength(0.25)
            end

            if math.random(6) == 1 then
                exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '🩸', durata = 4000,
                    titolo = 'Stai perdendo sangue',
                    testo = 'Usa un bendaggio o chiedi soccorso al 118.',
                })
            end
        end

        -- Conseguenze durature
        if Ferite.conseguenze.zoppia then
            SetPedMoveRateOverride(ped, 0.72)
            DisableControlAction(0, 21, true)  -- niente scatto
        end
        if Ferite.conseguenze.fiato_corto then
            SetPlayerSprint(PlayerId(), false)
            RestorePlayerStamina(PlayerId(), 0.1)
        end
        if Ferite.conseguenze.tremore then
            ShakeGameplayCam('HAND_SHAKE', 0.35)
        end
        if Ferite.conseguenze.offuscamento then
            SetTimecycleModifier('drug_wobbly')
            SetTimecycleModifierStrength(0.35)
        end
    end
end)

--- Le lesioni salvate tornano al rientro in gioco.
RegisterNetEvent('med:ripristinaFerite', function(lesioni)
    if type(lesioni) ~= 'table' then return end
    Ferite.lesioni = lesioni
    Ferite.Ricalcola()

    for parte, l in pairs(lesioni) do
        if l.immobilizza then
            if tostring(parte):find('gamba') then Ferite.conseguenze.zoppia = true end
            if tostring(parte):find('braccio') then Ferite.conseguenze.tremore = true end
        end
    end

    local quante = 0
    for _ in pairs(lesioni) do quante = quante + 1 end
    if quante > 0 then
        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🩺', durata = 10000,
            titolo = 'Lesioni ancora presenti',
            testo = ('Hai %d lesioni non curate. Passa dal pronto soccorso.'):format(quante),
        })
    end
end)

exports('StatoFerite', function()
    return { lesioni = Ferite.lesioni, emorragia = Ferite.emorragia, conseguenze = Ferite.conseguenze }
end)
