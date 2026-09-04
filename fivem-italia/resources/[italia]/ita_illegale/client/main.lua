--[[
    AUREA · Attività illecite (client)
]]

local U = AUREA.Util
local piante = {}
local mercato = nil
local inAzione = false

-- ---------------------------------------------------------------------------
--  Stato iniziale
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(4000)
        piante = {}
        for _, p in ipairs(AUREA.Callback.Attendi('ill:piante') or {}) do
            piante[p.id] = p
        end
        mercato = AUREA.Callback.Attendi('ill:mercatoDove')
    end)
end)

RegisterNetEvent('ill:piantaCreata', function(id, coord, matura)
    piante[id] = { id = id, coord = coord, matura = matura, percentuale = 0 }
end)

RegisterNetEvent('ill:piantaRimossa', function(id)
    piante[id] = nil
end)

RegisterNetEvent('ill:incendio', function()
    local coord = GetEntityCoords(PlayerPedId())
    StartScriptFire(coord.x, coord.y, coord.z, 25, false)
    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🔥', durata = 10000,
        titolo = 'La miscela ha preso fuoco',
        testo = 'Allontanati prima che si propaghi.',
    })
end)

-- ---------------------------------------------------------------------------
--  Piante nel mondo
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 800
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local vicina = nil

        for id, p in pairs(piante) do
            local pos = vector3(p.coord.x, p.coord.y, p.coord.z)
            local d = #(coord - pos)

            if d < 20.0 then
                attesa = 0
                DrawMarker(1, pos.x, pos.y, pos.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.5, 0.5, 0.6,
                    p.matura and 31 or 180, p.matura and 157 or 160, p.matura and 85 or 60, 130,
                    false, false, 2, false, nil, nil, false)

                if d < 2.5 then vicina = p end
            end
        end

        if vicina then
            local etichetta = vicina.matura
                and 'Raccogli [E] · sequestra [G]'
                or ('Cura la pianta [E] · sequestra [G]')
            exports.aurea_ui:Prompt(true, etichetta, 'E')

            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                if vicina.matura then raccogliPianta(vicina.id) else curaPianta(vicina.id) end
            elseif IsControlJustReleased(0, 47) then
                exports.aurea_ui:Prompt(false)
                sequestraPianta(vicina.id)
            end
        end

        Wait(attesa)
    end
end)

function curaPianta(id)
    CreateThread(function()
        if inAzione then return end
        inAzione = true

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Cura della pianta...',
            durata = 6000, annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:cura', id)
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🌱', titolo = ok and 'Pianta curata' or 'Non riuscito',
            testo = messaggio, durata = 8000,
        })
    end)
end

function raccogliPianta(id)
    CreateThread(function()
        if inAzione then return end
        inAzione = true

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Raccolta...',
            durata = 9000, annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:raccogli', id)
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🌿', titolo = ok and 'Raccolto' or 'Non riuscito',
            testo = messaggio, durata = 9000,
        })
    end)
end

function sequestraPianta(id)
    CreateThread(function()
        if not AUREA.EInServizio() then return end

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Sequestro e verbalizzazione...',
            durata = 8000, annullabile = true, blocca = { movimento = true },
        })
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:sequestraPianta', id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🚔', titolo = ok and 'Sequestro eseguito' or 'Sequestro rifiutato',
            testo = messaggio, durata = 9000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Piantare
-- ---------------------------------------------------------------------------
RegisterCommand('pianta', function()
    CreateThread(function()
        if inAzione then return end
        if not exports.aurea_inventory:Ha('seme', 1) then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🌱', titolo = 'Nessun seme', testo = 'Ne trovi al mercato nero.' })
        end

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Interro il seme...',
            durata = 8000, annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:pianta')
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🌱', titolo = ok and 'Seme interrato' or 'Non si può piantare qui',
            testo = messaggio, durata = 10000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Laboratori
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        local coord = GetEntityCoords(PlayerPedId())
        local lab = ILL.LaboratorioVicino(coord)

        if lab and not inAzione then
            attesa = 0
            exports.aurea_ui:Prompt(true, lab.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                raffina()
            end
        elseif #(coord - ILL.Smontaggio.coord) < ILL.Smontaggio.raggio then
            local veicolo = GetVehiclePedIsIn(PlayerPedId(), false)
            if veicolo ~= 0 then
                attesa = 0
                exports.aurea_ui:Prompt(true, ILL.Smontaggio.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    smonta(veicolo)
                end
            end
        elseif mercato and #(coord - vector3(mercato.x, mercato.y, mercato.z)) < 3.0 then
            attesa = 0
            exports.aurea_ui:Prompt(true, ILL.MercatoNero.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuMercato()
            end
        end

        Wait(attesa)
    end
end)

function raffina()
    CreateThread(function()
        if inAzione then return end

        local dati, errore = AUREA.Callback.Attendi('ill:raffina')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚗', titolo = 'Non si può lavorare', testo = errore })
        end

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = ('Lavorazione — %s'):format(dati.nome),
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', nome = 'weed_crouch_checkingleaves_idle_01_inspector' },
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:concludiRaffina')
        inAzione = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '⚗', titolo = ok and 'Lavorazione riuscita' or 'Lavorazione fallita',
            testo = messaggio, durata = 11000,
        })
    end)
end

function smonta(veicolo)
    CreateThread(function()
        if inAzione then return end

        local targa = GetVehicleNumberPlateText(veicolo):gsub('%s+', '')
        local dati, errore = AUREA.Callback.Attendi('ill:smonta', targa)
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔩', titolo = 'Non ora', testo = errore })
        end

        -- Si scende prima di smontare
        TaskLeaveVehicle(PlayerPedId(), veicolo, 0)
        Wait(2000)

        inAzione = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Smontaggio del veicolo...',
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:concludiSmontaggio')
        inAzione = false

        if ok and DoesEntityExist(veicolo) then DeleteEntity(veicolo) end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🔩', titolo = ok and 'Veicolo smontato' or 'Smontaggio fallito',
            testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Spaccio
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()

        if not inAzione and exports.aurea_inventory:Ha('sostanza_raffinata', 1)
           and not IsPedInAnyVehicle(ped, false) then
            local coord = GetEntityCoords(ped)
            local cliente = GetClosestPed(coord.x, coord.y, coord.z, ILL.Spaccio.distanza,
                1, 0, 0, 0, -1)

            if cliente and cliente ~= 0 and DoesEntityExist(cliente)
               and not IsPedAPlayer(cliente) and not IsEntityDead(cliente) then
                attesa = 0
                exports.aurea_ui:Prompt(true, 'Proponi al passante', 'G')
                if IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    spaccia(cliente)
                end
            end
        end

        Wait(attesa)
    end
end)

function spaccia(cliente)
    CreateThread(function()
        if inAzione then return end
        inAzione = true

        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, cliente, 1500)
        TaskTurnPedToFaceEntity(cliente, ped, 1500)

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Trattativa...',
            durata = ILL.Spaccio.durata, annullabile = true,
            blocca = { movimento = true },
        })
        if not completata then inAzione = false return end

        local ok, messaggio = AUREA.Callback.Attendi('ill:spaccia')
        inAzione = false

        if not ok then
            TaskSmartFleePed(cliente, ped, 100.0, -1, false, false)
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '💊', titolo = ok and 'Cessione effettuata' or 'Cessione fallita',
            testo = messaggio, durata = 10000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Mercato nero
-- ---------------------------------------------------------------------------
function menuMercato()
    CreateThread(function()
        local catalogo, errore = AUREA.Callback.Attendi('ill:mercatoCatalogo')
        if not catalogo then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Chiuso', testo = errore })
        end

        local sezione = exports.aurea_ui:Menu({
            titolo = ILL.MercatoNero.nome,
            sottotitolo = ('Hai %d banconote non tracciate · qui non si accettano bonifici'):format(catalogo.banconote),
            voci = {
                { id = 'oggetti', icona = '📦', titolo = 'Attrezzatura', descrizione = ('%d articoli'):format(#catalogo.oggetti) },
                { id = 'armi', icona = '🔫', titolo = 'Armi senza matricola', descrizione = 'Nessun registro, nessuna domanda.' },
            },
        })
        if not sezione then return end

        local voci = {}
        if sezione == 'oggetti' then
            for _, o in ipairs(catalogo.oggetti) do
                voci[#voci + 1] = {
                    id = o.item, icona = '📦', titolo = o.etichetta,
                    valore = ('%d banconote'):format(o.banconote),
                }
            end
        else
            for _, a in ipairs(catalogo.armi) do
                local nome = a.arma:gsub('^WEAPON_', ''):lower():gsub('^%l', string.upper)
                voci[#voci + 1] = {
                    id = a.arma, icona = '🔫', titolo = nome,
                    descrizione = 'Matricola abrasa: detenerla è reato in sé.',
                    valore = ('%d banconote'):format(a.banconote),
                }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = sezione == 'oggetti' and 'Attrezzatura' or 'Armi',
            sottotitolo = 'Pagamento in contanti non tracciati',
            voci = voci,
        })
        if not scelta then return end

        local quantita = 1
        if sezione == 'oggetti' then
            local valori = exports.aurea_ui:Dialogo('Quantità', {
                { etichetta = 'Quante unità?', tipo = 'number', valore = 1, min = 1, max = 50 },
            })
            if not valori then return end
            quantita = valori[1]
        end

        local ok, messaggio = AUREA.Callback.Attendi('ill:mercatoAcquista',
            sezione == 'oggetti' and 'oggetto' or 'arma', scelta, quantita)

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🕶', titolo = ok and 'Affare concluso' or 'Affare saltato',
            testo = messaggio, durata = 10000,
        })
    end)
end
