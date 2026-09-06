--[[
    AUREA · Serrature (client)

    Applica alle porte in scena lo stato che arriva dal server, e mostra
    il prompt a chi ci sta davanti. Non decide niente.
]]

local stato = {}
local occupato = false

local function applica(p, bloccata)
    local modello = type(p.modello) == 'string' and GetHashKey(p.modello) or p.modello
    local porta = GetClosestObjectOfType(p.coord.x, p.coord.y, p.coord.z, 2.5, modello, false, false, false)

    if porta ~= 0 and DoesEntityExist(porta) then
        FreezeEntityPosition(porta, bloccata)
        SetEntityHeading(porta, GetEntityHeading(porta))
        if bloccata then SetEntityAsMissionEntity(porta, true, true) end
    end

    -- Il cancello vero e proprio si blocca anche come porta della mappa
    if p.doppia then
        local secondaria = GetClosestObjectOfType(p.doppia.x, p.doppia.y, p.doppia.z,
            2.5, modello, false, false, false)
        if secondaria ~= 0 then FreezeEntityPosition(secondaria, bloccata) end
    end
end

local function applicaTutte()
    local coord = GetEntityCoords(PlayerPedId())
    for _, p in ipairs(POR.Porte) do
        if #(coord - p.coord) < 40.0 then
            applica(p, stato[p.id] ~= false)
        end
    end
end

RegisterNetEvent('por:stato', function(nuovo)
    stato = nuovo or stato
    applicaTutte()
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(4000)
        stato = AUREA.Callback.Attendi('por:stato') or {}
        applicaTutte()
    end)
end)

--- Le porte vanno riapplicate quando si entra nella zona: prima non
--- esistono come entità in scena.
CreateThread(function()
    while true do
        Wait(2000)
        applicaTutte()
    end
end)

CreateThread(function()
    while true do
        local attesa = 700
        local coord = GetEntityCoords(PlayerPedId())
        local p = POR.PortaVicina(coord)

        if p and not occupato then
            attesa = 0
            local bloccata = stato[p.id] ~= false

            exports.aurea_ui:Prompt(true,
                ('%s — %s'):format(p.nome, bloccata and 'chiusa' or 'aperta'), 'E')

            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                usa(p)
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

function usa(p)
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('por:usa', p.id)

        if ok then
            return exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '🔑', titolo = 'Serratura',
                testo = messaggio, durata = 6000,
            })
        end

        -- Se non hai le chiavi, resta il grimaldello
        if p.scassinabile ~= false and stato[p.id] ~= false then
            local scelta = exports.aurea_ui:Menu({
                titolo = p.nome,
                sottotitolo = tostring(messaggio),
                voci = {
                    { id = 'scassina', icona = '🗝', titolo = 'Prova a forzarla',
                      descrizione = 'Serve un grimaldello. Fa rumore e spesso non riesce.' },
                    { id = 'no', icona = '↩', titolo = 'Lascia perdere' },
                },
            })
            if scelta == 'scassina' then return scassina(p) end
            return
        end

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🔒', titolo = 'Serratura',
            testo = tostring(messaggio), durata = 9000,
        })
    end)
end

function scassina(p)
    CreateThread(function()
        local ok, durata = AUREA.Callback.Attendi('por:scassina', p.id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🗝', titolo = 'Effrazione',
                testo = tostring(durata), durata = 10000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Forzatura: %s'):format(p.nome),
            durata = durata, annullabile = true,
            anim = { dizionario = 'veh@break_in@0h@p_m_one@', nome = 'low_force_entry_ds' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local riuscito, messaggio = AUREA.Callback.Attendi('por:concludiScasso', p.id)
        exports.aurea_ui:Notifica({
            tipo = riuscito and 'successo' or 'errore', icona = '🗝',
            titolo = riuscito and 'Porta forzata' or 'Non ha ceduto',
            testo = messaggio, durata = 12000,
        })
    end)
end
