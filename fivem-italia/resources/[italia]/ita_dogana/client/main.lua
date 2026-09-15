--[[
    AUREA · Dogane (client)

    Disegna i container sul piazzale e apre lo sportello. Il valore che
    scrivi nella bolletta lo scrivi tu: è l'unico numero che il client
    manda al server, ed è giusto che sia così — la dichiarazione è tua.
]]

local container = {}

RegisterNetEvent('dog:container', function(elenco)
    container = elenco or {}
end)

-- ---------------------------------------------------------------------------
--  Sportello doganale
-- ---------------------------------------------------------------------------
local function sportello()
    CreateThread(function()
        local voci = {}
        for _, p in ipairs(DOG.Partite) do
            voci[#voci + 1] = {
                id = p.id, icona = p.icona, titolo = p.nome,
                descrizione = ('Costo %s · dazio %d%%%s\n%s'):format(
                    AUREA.Util.Euro(p.costo), math.floor(p.dazio * 100),
                    (p.accisa or 0) > 0 and (' · accisa %d%%'):format(math.floor(p.accisa * 100)) or '',
                    p.descrizione),
            }
        end
        voci[#voci + 1] = { id = 'licenza', icona = '📜', titolo = 'Licenza di importazione',
            descrizione = ('%s · apre le partite soggette a monopolio')
                :format(AUREA.Util.Euro(DOG.Licenza.costo)) }
        voci[#voci + 1] = { id = 'miei', icona = '📦', titolo = 'I tuoi container in attesa' }

        local scelta = exports.aurea_ui:Menu({
            titolo = DOG.Ufficio.nome,
            sottotitolo = 'Presentazione della bolletta doganale',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'licenza' then
            local ok, messaggio = AUREA.Callback.Attendi('dog:licenza')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📜',
                titolo = 'Dogane', testo = tostring(messaggio), durata = 14000 })
        end

        if scelta == 'miei' then
            local miei = AUREA.Callback.Attendi('dog:miei') or {}
            local righe = {}
            for _, c in ipairs(miei) do
                righe[#righe + 1] = { id = 'x', disattivata = true,
                    icona = DOG.Canali[c.canale].icona,
                    titolo = ('%s — posto %d'):format(c.nome, c.posto),
                    descrizione = ('%s · dichiarati %s · tributi %s%s'):format(
                        DOG.Canali[c.canale].nome, AUREA.Util.Euro(c.dichiarato),
                        AUREA.Util.Euro(c.tributi),
                        (DOG.Canali[c.canale].controlla and not c.controllato)
                            and ' · IN ATTESA DI CONTROLLO' or ' · svincolabile') }
            end
            if #righe == 0 then
                righe[1] = { id = 'x', disattivata = true, icona = '📦',
                    titolo = 'Nessun container in attesa' }
            end
            return exports.aurea_ui:Menu({ titolo = 'Container', sottotitolo = 'Terminal container', voci = righe })
        end

        local p = DOG.GetPartita(scelta)
        local r = exports.aurea_ui:Dialogo(('Bolletta — %s'):format(p.nome), {
            { etichetta = 'Valore dichiarato in euro', tipo = 'number', min = 0,
              segnaposto = 'quanto dichiari che valga la merce', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('dog:importa', p.id, tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🛃',
            titolo = 'Dogane', testo = tostring(messaggio), durata = 22000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Il piazzale
-- ---------------------------------------------------------------------------
local function svincola(id)
    CreateThread(function()
        if not exports.aurea_ui:Progresso({ etichetta = 'Ritiro della merce',
                                            durata = 8000, annullabile = true }) then return end
        local ok, messaggio = AUREA.Callback.Attendi('dog:svincola', id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📦',
            titolo = 'Terminal', testo = tostring(messaggio), durata = 14000,
        })
    end)
end

CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())
        local vicino

        for _, c in ipairs(container) do
            local p = DOG.Terminal.piazzale[c.posto]
            if p then
                local d = #(coord - p)
                if d < 30.0 then
                    attesa = 0
                    local canale = DOG.Canali[c.canale]
                    local r, v, b = 200, 200, 200
                    if c.canale == 'rosso' then r, v, b = 220, 60, 50
                    elseif c.canale == 'arancione' then r, v, b = 230, 140, 40
                    elseif c.canale == 'giallo' then r, v, b = 230, 210, 60
                    else r, v, b = 70, 190, 90 end

                    DrawMarker(1, p.x, p.y, p.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        2.4, 2.4, 1.0, r, v, b, 110, false, false, 2, false)
                    if d < 2.5 and not vicino then vicino = c end
                end
            end
        end

        if vicino then
            exports.aurea_ui:Prompt(true,
                ('%s — ritira la merce'):format(DOG.Canali[vicino.canale].nome), 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                svincola(vicino.id)
                Wait(1500)
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Blip e punto di interazione
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    for _, p in ipairs({ DOG.Ufficio, DOG.Terminal }) do
        local b = AddBlipForCoord(p.coord)
        SetBlipSprite(b, p.blip.sprite)
        SetBlipColour(b, p.blip.colore)
        SetBlipScale(b, p.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(p.nome)
        EndTextCommandSetBlipName(b)
    end

    exports.aurea_target:AggiungiZona('dogana_sportello', DOG.Ufficio.coord, DOG.Ufficio.raggio, {
        { etichetta = 'Sportello doganale', icona = '🛃', azione = sportello },
    })
end)

RegisterCommand('dogana', sportello, false)
