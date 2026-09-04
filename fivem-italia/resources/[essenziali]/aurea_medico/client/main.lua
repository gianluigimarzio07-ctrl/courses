--[[
    AUREA · Sanità (client)
    Incoscienza, soccorso, ospedale.
]]

local U = AUREA.Util
local incosciente = false
local inizioIncoscienza = 0
local trasportoAttivo = false

-- ---------------------------------------------------------------------------
--  Blip degli ospedali
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, o in ipairs(MED.Ospedali) do
        local blip = AddBlipForCoord(o.coord.x, o.coord.y, o.coord.z)
        SetBlipSprite(blip, o.blip.sprite)
        SetBlipColour(blip, o.blip.colore)
        SetBlipScale(blip, o.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(o.nome)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ---------------------------------------------------------------------------
--  Incoscienza
-- ---------------------------------------------------------------------------
local function entraInIncoscienza()
    if incosciente then return end
    incosciente = true
    inizioIncoscienza = GetGameTimer()

    local ped = PlayerPedId()
    SetEntityHealth(ped, MED.Regole.sogliaIncoscienza)
    SetPedToRagdoll(ped, 60000, 60000, 0, false, false, false)
    SetEntityInvincible(ped, false)

    TriggerServerEvent('med:incosciente', true)
    TriggerEvent('aurea:hud:mostra', false)

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '💀', durata = 15000,
        titolo = 'Hai perso conoscenza',
        testo = 'Attendi i soccorsi. Premi G per chiamare il 118, oppure attendi per il risveglio in ospedale.',
    })
end

local function esciDaIncoscienza(salute, ticket)
    incosciente = false
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, salute or MED.Regole.saluteRisveglio)
    TriggerServerEvent('med:incosciente', false)
    TriggerEvent('aurea:hud:mostra', true)
    ClearTimecycleModifier()

    if ticket and ticket > 0 then
        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🏥', durata = 11000,
            titolo = 'Dimesso dal pronto soccorso',
            testo = ('Ticket sanitario di %s addebitato.'):format(U.Euro(ticket)),
        })
    end
end

-- Sostituisce la morte con l'incoscienza
CreateThread(function()
    while true do
        Wait(200)
        local ped = PlayerPedId()

        if not incosciente then
            if IsEntityDead(ped) or GetEntityHealth(ped) <= MED.Regole.sogliaIncoscienza then
                if GetEntityHealth(ped) > 0 or IsEntityDead(ped) then
                    entraInIncoscienza()
                end
            end
        else
            -- si resta a terra
            local ped2 = PlayerPedId()
            if not IsPedRagdoll(ped2) and not trasportoAttivo then
                SetPedToRagdoll(ped2, 30000, 30000, 0, false, false, false)
            end

            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true) DisableControlAction(0, 22, true)

            local trascorso = (GetGameTimer() - inizioIncoscienza) / 1000
            local residuo = math.max(0, MED.Regole.secondiPrimaResa - trascorso)

            if residuo > 0 then
                AUREA.Testo3D(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z + 1.0,
                    ('Risveglio in ospedale fra %d s   ·   [G] chiama il 118'):format(math.ceil(residuo)), 0.4)
            else
                AUREA.Testo3D(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z + 1.0,
                    '[E] arrenditi e risvegliati in ospedale   ·   [G] chiama il 118', 0.4)

                if IsControlJustReleased(0, 38) then
                    CreateThread(function()
                        local ok, salute, ticket = AUREA.Callback.Attendi('med:risveglio')
                        if ok then
                            local ospedale = MED.OspedalePiuVicino(GetEntityCoords(PlayerPedId()))
                            local r = ospedale.risveglio
                            SetEntityCoords(PlayerPedId(), r.x, r.y, r.z, false, false, false, false)
                            SetEntityHeading(PlayerPedId(), r.w)
                            Ferite.Azzera()
                            esciDaIncoscienza(salute, ticket)
                        end
                    end)
                end
            end

            if IsControlJustReleased(0, 47) then
                local coord = GetEntityCoords(ped)
                TriggerServerEvent('nue:segnalazioneAutomatica', 'malore',
                    { x = coord.x, y = coord.y, z = coord.z }, AUREA.Indirizzo(coord))
                exports.aurea_ui:Notifica({ tipo = 'info', icona = '📞', titolo = '118 allertato', testo = 'Resta immobile, i soccorsi stanno arrivando.' })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Soccorso da parte di un altro giocatore
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        if not incosciente and AUREA.PG then
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)
            local ePersonaleSanitario = AUREA.HaLavoro('118') and AUREA.EInServizio()

            for _, altro in ipairs(GetActivePlayers()) do
                local altroPed = GetPlayerPed(altro)
                if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < 2.2 then
                    if IsEntityDead(altroPed) or GetEntityHealth(altroPed) <= MED.Regole.sogliaIncoscienza + 5 then
                        attesa = 0
                        exports.aurea_ui:Prompt(true,
                            ePersonaleSanitario and 'Presta soccorso [H] · trasporta [K]' or 'Prova a rianimare',
                            'H')

                        if IsControlJustReleased(0, 74) then
                            exports.aurea_ui:Prompt(false)
                            rianima(GetPlayerServerId(altro), ePersonaleSanitario)
                        elseif ePersonaleSanitario and IsControlJustReleased(0, 311) then
                            exports.aurea_ui:Prompt(false)
                            TriggerServerEvent('med:trasporta', GetPlayerServerId(altro))
                        end
                        break
                    end
                end
            end
        end
        Wait(attesa)
    end
end)

function rianima(bersaglio, professionale)
    CreateThread(function()
        local haKit = exports.aurea_inventory:Ha('kit_medico', 1)
        if professionale and not haKit and not exports.aurea_inventory:Ha('adrenalina', 1) then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', titolo = 'Materiale mancante',
                testo = 'Servono un kit medico o una fiala di adrenalina.',
            })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = professionale and 'Manovre di rianimazione...' or 'Tentativo di soccorso...',
            durata = MED.Regole.duratsRianimazione,
            annullabile = true,
            anim = { dizionario = 'mini@cpr@char_a@cpr_str', nome = 'cpr_pumpchest' },
            blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:rianima', bersaglio, professionale, haKit)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '✚', titolo = ok and 'Soccorso riuscito' or 'Tentativo fallito',
            testo = messaggio, durata = 9000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Eventi dal server
-- ---------------------------------------------------------------------------
RegisterNetEvent('med:rianimato', function(salute)
    if not incosciente then return end
    Ferite.emorragia = 0
    for parte, l in pairs(Ferite.lesioni) do
        if (l.emorragia or 0) > 0 then l.emorragia = 0 end
    end
    esciDaIncoscienza(salute)
    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '✚', durata = 11000,
        titolo = 'Hai ripreso conoscenza',
        testo = 'Le ferite gravi restano: fatti visitare in ospedale.',
    })
end)

RegisterNetEvent('med:trasportato', function(coord)
    trasportoAttivo = true
    SetEntityCoords(PlayerPedId(), coord.x, coord.y, coord.z, false, false, false, false)
    Wait(1500)
    trasportoAttivo = false
end)

RegisterNetEvent('med:bendaggio', function()
    CreateThread(function()
        local parte, lesione = Ferite.PrimaEmorragia()
        if not parte then
            return exports.aurea_ui:Notifica({ tipo = 'info', titolo = 'Nessuna emorragia', testo = 'Non hai ferite sanguinanti.' })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Medicazione — %s'):format(lesione.parte),
            durata = MED.Regole.duratsMedicazione,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_clipboard@male@idle_a', nome = 'idle_c' },
            blocca = { movimento = true },
        })
        if not completato then return end

        lesione.emorragia = 0
        Ferite.Ricalcola()
        TriggerServerEvent('med:aggiornaFerite', Ferite.lesioni)

        local ped = PlayerPedId()
        SetEntityHealth(ped, math.min(190, GetEntityHealth(ped) + 18))
        ClearTimecycleModifier()

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🩹', titolo = 'Emorragia tamponata',
            testo = ('%s medicata. La lesione resta e va curata.'):format(lesione.parte),
        })
    end)
end)

RegisterNetEvent('med:kitMedico', function()
    CreateThread(function()
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Medicazione con kit sanitario...',
            durata = MED.Regole.duratsMedicazione + 4000,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_clipboard@male@idle_a', nome = 'idle_c' },
            blocca = { movimento = true },
        })
        if not completato then return end

        -- Il kit chiude le emorragie e cura le lesioni lievi
        for parte, l in pairs(Ferite.lesioni) do
            if MED.Lesioni[l.tipo] and MED.Lesioni[l.tipo].curaBase then
                Ferite.lesioni[parte] = nil
            else
                l.emorragia = 0
            end
        end
        Ferite.Ricalcola()
        TriggerServerEvent('med:aggiornaFerite', Ferite.lesioni)

        SetEntityHealth(PlayerPedId(), 175)
        ClearTimecycleModifier()

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🧰', titolo = 'Medicazione completata',
            testo = 'Fratture e ferite gravi richiedono comunque l\'ospedale.',
        })
    end)
end)

RegisterNetEvent('med:antidolorifico', function()
    exports.aurea_ui:Notifica({ tipo = 'info', icona = '💊', titolo = 'Antidolorifico assunto', testo = 'Il dolore si attenua per qualche minuto.' })
    CreateThread(function()
        local salvate = Ferite.conseguenze
        Ferite.conseguenze = {}
        ClearTimecycleModifier()
        Wait(5 * 60000)
        -- l'effetto passa: le conseguenze non curate tornano
        for chiave, valore in pairs(salvate) do
            if Ferite.conseguenze[chiave] == nil then Ferite.conseguenze[chiave] = valore end
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Pronto soccorso: cura completa a pagamento
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        local coord = GetEntityCoords(PlayerPedId())

        for _, o in ipairs(MED.Ospedali) do
            if #(coord - o.prontoSoccorso) < 2.2 and not incosciente then
                attesa = 0
                exports.aurea_ui:Prompt(true, 'Pronto Soccorso', 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuProntoSoccorso(o)
                end
                break
            end
        end

        if attesa ~= 0 then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

function menuProntoSoccorso(ospedale)
    CreateThread(function()
        local elenco = Ferite.Elenco()

        local voci = {}
        if #elenco == 0 then
            voci[1] = { id = 'nulla', icona = '✅', titolo = 'Nessuna lesione rilevata', disattivata = true }
        else
            for _, e in ipairs(elenco) do
                voci[#voci + 1] = {
                    id = e.parte, icona = '🩺',
                    titolo = ('%s — %s'):format(e.dati.parte, e.dati.etichetta),
                    descrizione = e.dati.emorragia > 0 and 'Emorragia in atto' or 'Stabilizzata',
                    valore = ('gravità %d/5'):format(e.dati.gravita),
                    disattivata = true,
                }
            end
        end

        table.insert(voci, 1, {
            id = '__cura', icona = '🏥',
            titolo = 'Ricovero e cura completa',
            descrizione = 'Risolve ogni lesione e conseguenza.',
            valore = U.Euro(MED.Regole.ticketPronto),
            disattivata = #elenco == 0,
        })

        local scelta = exports.aurea_ui:Menu({
            titolo = ospedale.nome,
            sottotitolo = ('Cartella clinica · %d lesioni registrate'):format(#elenco),
            voci = voci,
        })
        if scelta ~= '__cura' then return end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Visita e trattamento in corso...',
            durata = 14000, annullabile = true, blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('med:curaCompleta')
        if ok then
            Ferite.Azzera()
            SetEntityHealth(PlayerPedId(), 200)
            ClearTimecycleModifier()
            ResetPedMovementClipset(PlayerPedId(), 0.0)
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🏥', titolo = ok and 'Dimesso' or 'Cura non erogata',
            testo = messaggio, durata = 9000,
        })
    end)
end

RegisterCommand('ferite', function()
    local elenco = Ferite.Elenco()
    if #elenco == 0 then
        return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🩺', titolo = 'Stai bene', testo = 'Nessuna lesione in corso.' })
    end
    local righe = {}
    for _, e in ipairs(elenco) do
        righe[#righe + 1] = ('%s: %s%s'):format(e.dati.parte, e.dati.etichetta, e.dati.emorragia > 0 and ' (sanguina)' or '')
    end
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🩺', durata = 13000,
        titolo = ('%d lesioni'):format(#elenco),
        testo = table.concat(righe, '\n'),
    })
end, false)
