--[[
    AUREA · Vigili del Fuoco (client)

    Disegna le fiamme e manda le richieste. Non decide niente: l'intensità
    di un focolaio, l'acqua rimasta e la chiusura dell'intervento stanno
    tutti sul server.

    Le fiamme sono script fire nativi. Vanno create e distrutte con
    attenzione: un fuoco lasciato acceso da un client che si disconnette
    resta lì a bruciare finché non si riavvia la risorsa.
]]

local incendi = {}          -- [id] = pacchetto dal server
local fuochi = {}           -- ['idIncendio:idFocolaio'] = handle dello script fire
local mezzoAttuale = nil    -- { targa, modello, litri, capacita }
local incastrato = false
local getto = false

local function chiave(idIncendio, idFocolaio)
    return ('%d:%d'):format(idIncendio, idFocolaio)
end

-- ---------------------------------------------------------------------------
--  Fiamme
-- ---------------------------------------------------------------------------
local function spegniTutti()
    for k, handle in pairs(fuochi) do
        if handle then RemoveScriptFire(handle) end
        fuochi[k] = nil
    end
end

local function aggiornaFiamme(inc)
    local presenti = {}

    for _, f in ipairs(inc.focolai) do
        local k = chiave(inc.id, f.id)
        presenti[k] = true

        -- Il numero di "figli" della fiamma scala con l'intensità: un
        -- focolaio quasi spento è una fiammella, uno all'ottanta è un
        -- rogo. Si vede a colpo d'occhio dove serve l'acqua.
        local figli = math.max(1, math.floor(f.intensita / 20))

        if not fuochi[k] then
            fuochi[k] = StartScriptFire(f.x, f.y, f.z, figli, inc.tipologia == 'gas')
        end
    end

    -- I focolai spenti vanno tolti
    for k, handle in pairs(fuochi) do
        if k:match('^' .. inc.id .. ':') and not presenti[k] then
            if handle then RemoveScriptFire(handle) end
            fuochi[k] = nil
        end
    end
end

RegisterNetEvent('vvf:incendio', function(pacchetto)
    incendi[pacchetto.id] = pacchetto
    aggiornaFiamme(pacchetto)
end)

RegisterNetEvent('vvf:incendioChiuso', function(id)
    for k, handle in pairs(fuochi) do
        if k:match('^' .. id .. ':') then
            if handle then RemoveScriptFire(handle) end
            fuochi[k] = nil
        end
    end
    incendi[id] = nil
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() then spegniTutti() end
end)

-- ---------------------------------------------------------------------------
--  Il calore
--
--  Stare dentro le fiamme fa male. Con i dispositivi di protezione fa
--  molto meno: è l'unica ragione per cui vale la pena metterseli.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local vicino = false

        for _, inc in pairs(incendi) do
            for _, f in ipairs(inc.focolai) do
                if #(coord - vector3(f.x, f.y, f.z)) < VVF.Fuoco.raggioDanno then
                    vicino = true break
                end
            end
            if vicino then break end
        end

        if vicino then
            local protetto = exports.aurea_inventory:Ha(VVF.Attrezzatura.dpi, 1)
            local danno = protetto and VVF.Fuoco.dannoConDPI or VVF.Fuoco.dannoPerTick
            SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - danno))

            if not protetto then
                exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '🔥', durata = 3000,
                    titolo = 'Ti stai bruciando',
                    testo = 'Senza dispositivi di protezione non si sta nelle fiamme.',
                })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il mezzo e l'acqua
-- ---------------------------------------------------------------------------
local function mezzoVicino()
    local coord = GetEntityCoords(PlayerPedId())
    local migliore, distanza = nil, 18.0

    for _, v in ipairs(GetGamePool('CVehicle')) do
        for _, m in ipairs(VVF.Mezzi) do
            if m.acqua > 0 and GetEntityModel(v) == GetHashKey(m.modello) then
                local d = #(coord - GetEntityCoords(v))
                if d < distanza then migliore, distanza = v, d end
            end
        end
    end

    return migliore
end

local function aggiornaMezzo()
    local v = mezzoVicino()
    if not v then mezzoAttuale = nil return end

    local targa = GetVehicleNumberPlateText(v):gsub('%s+', '')
    local modello = nil
    for _, m in ipairs(VVF.Mezzi) do
        if GetEntityModel(v) == GetHashKey(m.modello) and m.acqua > 0 then modello = m.modello break end
    end

    local litri, capacita = AUREA.Callback.Attendi('vvf:acqua', targa, modello)
    if litri then
        mezzoAttuale = { targa = targa, modello = modello, litri = litri, capacita = capacita }
    end
end

CreateThread(function()
    while true do
        Wait(3000)
        if AUREA.HaLavoro(VVF.Lavoro) and AUREA.EInServizio() then
            aggiornaMezzo()
        else
            mezzoAttuale = nil
        end
    end
end)

--- Il litraggio sullo schermo, quando serve saperlo.
CreateThread(function()
    while true do
        Wait(0)
        if mezzoAttuale and (getto or #(GetEntityCoords(PlayerPedId())
            - GetEntityCoords(mezzoVicino() or PlayerPedId())) < 18.0) then

            local percentuale = mezzoAttuale.capacita > 0
                and (mezzoAttuale.litri / mezzoAttuale.capacita) or 0

            SetTextFont(4)
            SetTextScale(0.0, 0.42)
            SetTextColour(percentuale < 0.2 and 220 or 200,
                          percentuale < 0.2 and 70 or 220,
                          percentuale < 0.2 and 70 or 230, 220)
            SetTextDropShadow()
            SetTextWrap(0.0, 0.97)
            SetTextRightJustify(true)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(
                ('💧 %d / %d litri — %s'):format(mezzoAttuale.litri, mezzoAttuale.capacita, mezzoAttuale.targa))
            EndTextCommandDisplayText(0.97, 0.86)
        else
            Wait(400)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Il getto
--
--  Si tiene premuto il tasto puntando un focolaio. Ogni secondo parte una
--  richiesta al server, che decide se e quanto abbassare l'intensità.
-- ---------------------------------------------------------------------------
local function focolaioPuntato()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local avanti = GetOffsetFromEntityInWorldCoords(ped, 0.0, 6.0, 0.0)

    local migliore, distanza, incendio = nil, 12.0, nil

    for _, inc in pairs(incendi) do
        for _, f in ipairs(inc.focolai) do
            local p = vector3(f.x, f.y, f.z)
            -- Deve essere davanti, non dietro: si valuta la distanza dal
            -- punto a sei metri in avanti
            local d = #(avanti - p)
            if d < distanza and #(coord - p) < 14.0 then
                migliore, distanza, incendio = f, d, inc
            end
        end
    end

    return migliore, incendio
end

CreateThread(function()
    while true do
        Wait(0)

        if not AUREA.HaLavoro(VVF.Lavoro) or not AUREA.EInServizio() then
            getto = false
            Wait(1000)
        else
            local f, inc = focolaioPuntato()

            if f and inc then
                local conEstintore = not exports.aurea_inventory:Ha(VVF.Attrezzatura.lancia, 1)

                if inc.senzaAcqua then
                    exports.aurea_ui:Prompt(true, 'Intercetta la valvola', 'G')
                    if IsControlJustReleased(0, 47) then
                        exports.aurea_ui:Prompt(false)
                        local ok, durata = AUREA.Callback.Attendi('vvf:intercetta', inc.id)
                        if ok then
                            if exports.aurea_ui:Progresso({
                                etichetta = 'Intercettazione della valvola...', durata = durata,
                                anim = { dizionario = 'amb@world_human_welding@male@base', nome = 'base' },
                                blocca = { movimento = true },
                            }) then
                                local fatto, messaggio = AUREA.Callback.Attendi('vvf:concludiIntercetta', inc.id)
                                exports.aurea_ui:Notifica({
                                    tipo = fatto and 'successo' or 'errore', icona = '💨',
                                    titolo = 'Fuga di gas', testo = messaggio, durata = 11000,
                                })
                            end
                        else
                            exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💨', testo = durata, durata = 9000 })
                        end
                    end
                else
                    exports.aurea_ui:Prompt(true,
                        conEstintore and ('Estintore su %d%%'):format(f.intensita)
                            or ('Getto su %d%%'):format(f.intensita), 'G')

                    if IsControlPressed(0, 47) then
                        if not getto then getto = true end
                        TriggerServerEvent('vvf:bagna', inc.id, f.id,
                            mezzoAttuale and mezzoAttuale.targa or '', conEstintore)

                        -- L'animazione e il tempo li scandisce il ciclo: una
                        -- richiesta al secondo, non una per fotogramma
                        TaskStartScenarioInPlace(PlayerPedId(),
                            conEstintore and 'WORLD_HUMAN_STAND_IMPATIENT' or 'WORLD_HUMAN_STAND_FIRE', 0, true)
                        Wait(1000)
                    elseif getto then
                        getto = false
                        ClearPedTasks(PlayerPedId())
                    end
                end
            else
                if getto then
                    getto = false
                    ClearPedTasks(PlayerPedId())
                end
                exports.aurea_ui:Prompt(false)
                Wait(200)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Idranti
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900

        if AUREA.HaLavoro(VVF.Lavoro) and AUREA.EInServizio() and mezzoAttuale then
            local coord = GetEntityCoords(PlayerPedId())

            for _, i in ipairs(VVF.Idranti) do
                if #(coord - i) < VVF.Ricarica.raggio then
                    attesa = 0
                    DrawMarker(21, i.x, i.y, i.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.5, 0.5, 0.5, 70, 140, 220, 160, true, false, 2, false, nil, nil, false)

                    if mezzoAttuale.litri >= mezzoAttuale.capacita then
                        exports.aurea_ui:Prompt(true, 'Serbatoio pieno', nil)
                    else
                        exports.aurea_ui:Prompt(true, 'Tieni premuto per caricare acqua', 'H')

                        if IsControlPressed(0, 74) then
                            local ok, litri, capacita = AUREA.Callback.Attendi(
                                'vvf:ricarica', mezzoAttuale.targa, mezzoAttuale.modello)
                            if ok then
                                mezzoAttuale.litri = litri
                                mezzoAttuale.capacita = capacita
                            end
                            Wait(1000)
                        end
                    end
                    break
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Quadro degli interventi
-- ---------------------------------------------------------------------------
local rottaVerso = nil

RegisterCommand('interventi', function()
    local righe = AUREA.Callback.Attendi('vvf:interventi')
    local voci = {}

    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = tostring(r.id), icona = r.icona,
            titolo = ('%s — %s'):format(r.nome, r.zona),
            descrizione = ('%d focolai · intensità media %d%% · aperto da %d minuti · %d operatori sul posto\n%s')
                :format(r.focolai, r.intensitaMedia, r.minuti, r.operatori, r.descrizione),
        }
    end

    if #voci == 0 then
        voci[1] = { id = 'x', icona = '🚒', titolo = 'Nessun intervento in corso', disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Sala operativa 115',
        sottotitolo = 'Scegli un intervento per avere la rotta',
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    for _, r in ipairs(righe) do
        if tostring(r.id) == scelta then
            if rottaVerso then RemoveBlip(rottaVerso) end
            rottaVerso = AddBlipForCoord(r.coord.x, r.coord.y, r.coord.z)
            SetBlipSprite(rottaVerso, 436)
            SetBlipColour(rottaVerso, 1)
            SetBlipScale(rottaVerso, 1.0)
            SetBlipRoute(rottaVerso, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(r.nome)
            EndTextCommandSetBlipName(rottaVerso)

            exports.aurea_ui:Notifica({
                tipo = 'info', icona = r.icona, durata = 10000,
                titolo = 'Rotta impostata', testo = ('%s — %s'):format(r.nome, r.zona),
            })
            return
        end
    end
end, false)

-- ---------------------------------------------------------------------------
--  Estricazione
-- ---------------------------------------------------------------------------
local function personaVicina()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, VVF.Estricazione.raggio

    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

RegisterCommand('estrica', function()
    local b = personaVicina()
    if not b then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚒', testo = 'Nessuno da estricare qui.' })
    end

    local ok, durata, bersaglioSrc, nome = AUREA.Callback.Attendi('vvf:estrica', b)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚒', testo = durata, durata = 11000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('Estricazione di %s...'):format(nome), durata = durata,
        anim = { dizionario = 'amb@world_human_welding@male@base', nome = 'base' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('vvf:concludiEstricazione', bersaglioSrc)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🚒',
            titolo = fatto and 'Estricazione riuscita' or 'Non riuscita',
            testo = messaggio, durata = 13000,
        })
    end
end, false)

--- Restare incastrati: un incidente violento a bordo, e non si esce.
CreateThread(function()
    local velocitaPrecedente = 0.0

    while true do
        Wait(500)
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local veicolo = GetVehiclePedIsIn(ped, false)
            local velocita = GetEntitySpeed(veicolo) * 3.6

            -- Una decelerazione brutale con il mezzo distrutto: sei dentro
            if velocitaPrecedente > 75.0 and velocita < 12.0
                and GetVehicleBodyHealth(veicolo) < 350.0
                and not incastrato then
                incastrato = true
                TriggerServerEvent('vvf:incastrato', true)
                exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '🚨', durata = 22000,
                    titolo = 'Sei incastrato',
                    testo = 'Le lamiere ti bloccano. Servono i vigili del fuoco: chiama il 112 e aspetta.',
                })
            end

            velocitaPrecedente = velocita
        else
            velocitaPrecedente = 0.0
        end

        if incastrato then
            -- Non si scende e non si guida
            DisableControlAction(0, 75, true)
            SetPedCanRagdoll(ped, false)
            if not IsPedInAnyVehicle(ped, false) then
                -- Se in qualche modo è uscito, non è più incastrato
                incastrato = false
                TriggerServerEvent('vvf:incastrato', false)
            end
        end
    end
end)

RegisterNetEvent('vvf:liberato', function()
    incastrato = false
    local ped = PlayerPedId()
    SetPedCanRagdoll(ped, true)
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
end)

RegisterNetEvent('vvf:dannoIncastro', function(danno)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - danno))
    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🩸', durata = 6000,
        titolo = 'Stai peggiorando',
        testo = 'Più resti incastrato, peggio è.',
    })
end)

-- ---------------------------------------------------------------------------
--  Armadio e CPI
-- ---------------------------------------------------------------------------
local function apriArmadio()
    local righe, motivo = AUREA.Callback.Attendi('vvf:armadio')
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧰', testo = motivo, durata = 9000 })
    end

    local voci = {}
    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = r.item, icona = r.gia > 0 and '✅' or '🧰',
            titolo = r.etichetta,
            descrizione = r.gia > 0 and 'Ce l\'hai — selezionalo per riporlo' or 'Preleva',
        }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Armadio di caserma', sottotitolo = 'Dotazione di servizio', voci = voci,
    })
    if not scelta then return end

    local ok, messaggio = AUREA.Callback.Attendi('vvf:preleva', scelta)
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🧰', testo = messaggio, durata = 9000,
    })
end

local function rilasciaCpi()
    local b = personaVicina()
    if not b then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋', testo = 'Il titolare deve essere qui.' })
    end

    local ok, durata, richiedenteSrc, nome = AUREA.Callback.Attendi('vvf:cpi', b)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋', testo = durata, durata = 12000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('Sopralluogo antincendio per %s...'):format(nome), durata = durata,
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('vvf:concludiCpi', richiedenteSrc)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '📋',
            titolo = fatto and 'CPI rilasciato' or 'Non rilasciato',
            testo = messaggio, durata = 13000,
        })
    end
end

-- ---------------------------------------------------------------------------
--  Punti sulla mappa
-- ---------------------------------------------------------------------------
CreateThread(function()
    for n, c in ipairs(VVF.Caserme) do
        local blip = AddBlipForCoord(c.coord)
        SetBlipSprite(blip, c.blip.sprite)
        SetBlipColour(blip, c.blip.colore)
        SetBlipScale(blip, c.blip.scala)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(c.nome)
        EndTextCommandSetBlipName(blip)

        exports.aurea_target:AggiungiZona('vvf_armadio_' .. n, c.armadio, 2.5, {
            { etichetta = 'Armadio di caserma', icona = '🧰',
              lavoro = VVF.Lavoro, inServizio = true, azione = apriArmadio },
            { etichetta = 'Rilascia un CPI', icona = '📋',
              lavoro = VVF.Lavoro, inServizio = true, azione = rilasciaCpi },
        })
    end
end)
