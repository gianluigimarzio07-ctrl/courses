--[[
    AUREA · Protezione Civile (client)

    Disegna i punti dello scenario e chiede al server di lavorarci. La
    posizione dei punti arriva dal server a scenario aperto: prima non
    esiste da nessuna parte, nemmeno in configurazione.
]]

local stato = { allerta = 'verde', coc = false, emergenza = nil }
local blipScenario, blipPunti = nil, {}

-- ---------------------------------------------------------------------------
--  Blip
-- ---------------------------------------------------------------------------
local function pulisciBlip()
    if blipScenario then RemoveBlip(blipScenario) blipScenario = nil end
    for _, b in ipairs(blipPunti) do RemoveBlip(b) end
    blipPunti = {}
end

local function disegna()
    pulisciBlip()
    local e = stato.emergenza
    if not e then return end

    local def = PC.GetEmergenza(e.tipo)
    if not def then return end

    blipScenario = AddBlipForRadius(e.centro.x, e.centro.y, e.centro.z, def.raggio + 25.0)
    SetBlipColour(blipScenario, 1)
    SetBlipAlpha(blipScenario, 90)

    for _, c in ipairs(e.compiti or {}) do
        if not c.fatto then
            local b = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(b, 1)
            SetBlipColour(b, 46)
            SetBlipScale(b, 0.55)
            SetBlipAsShortRange(b, false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(PC.Compiti[c.tipo].etichetta)
            EndTextCommandSetBlipName(b)
            blipPunti[#blipPunti + 1] = b
        end
    end
end

RegisterNetEvent('pc:sincronizza', function(nuovo)
    stato = nuovo or stato
    disegna()
end)

-- ---------------------------------------------------------------------------
--  Lavorare un punto
-- ---------------------------------------------------------------------------
local function lavoraPunto(c)
    CreateThread(function()
        local def = PC.Compiti[c.tipo]
        local anim = def.animazione

        if anim then
            RequestAnimDict(anim.dizionario)
            local scadenza = GetGameTimer() + 3000
            while not HasAnimDictLoaded(anim.dizionario) and GetGameTimer() < scadenza do Wait(20) end
            if HasAnimDictLoaded(anim.dizionario) then
                TaskPlayAnim(PlayerPedId(), anim.dizionario, anim.nome, 4.0, -4.0, -1, 1, 0, false, false, false)
            end
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = def.etichetta,
            durata = def.secondi * 1000,
            annullabile = true,
        })

        ClearPedTasks(PlayerPedId())
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('pc:compito', c.n)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚨',
            titolo = 'Protezione Civile', testo = tostring(messaggio), durata = 14000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Il marker a terra e il tasto per lavorarci
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local e = stato.emergenza

        if e and e.compiti then
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)
            local vicino = nil

            for _, c in ipairs(e.compiti) do
                if not c.fatto then
                    local d = #(coord - vector3(c.x, c.y, c.z))
                    if d < 40.0 then
                        attesa = 0
                        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            1.6, 1.6, 0.8, 240, 140, 40, 120, false, false, 2, false)
                        if d < 2.2 and not vicino then vicino = c end
                    end
                end
            end

            if vicino then
                exports.aurea_ui:Prompt(true, PC.Compiti[vicino.tipo].etichetta, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    lavoraPunto(vicino)
                    Wait(1500)
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Il pannello
-- ---------------------------------------------------------------------------
local function pannello()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('pc:stato')
        if not s then return end

        local voci = {
            { id = 'x', disattivata = true, icona = '🚨',
              titolo = s.nomeAllerta,
              descrizione = s.coc and 'Centro Operativo Comunale aperto.'
                                  or 'Centro operativo in sonno.' },
        }

        if s.emergenza then
            local e = s.emergenza
            voci[#voci + 1] = {
                id = 'x2', disattivata = true, icona = e.icona,
                titolo = ('%s — %s'):format(e.nome, e.zona),
                descrizione = ('%s\n%d punti su %d ancora da lavorare · %d minuti · tuoi: %d')
                    :format(e.descrizione, e.restanti, e.totali, e.minutiResidui, e.miei),
            }
            voci[#voci + 1] = {
                id = 'rotta', icona = '🧭', titolo = 'Imposta la rotta verso lo scenario',
            }
            if s.volontario then
                voci[#voci + 1] = {
                    id = 'dotazione', icona = '📦', titolo = 'Ritira la dotazione',
                    descrizione = 'Sabbia e gilet dal magazzino del centro operativo. Si ritira alla sede.',
                }
            end
        else
            voci[#voci + 1] = { id = 'x3', disattivata = true, icona = '☑',
                titolo = 'Nessuno scenario in corso',
                descrizione = 'Quando si apre, chi è iscritto viene attivato.' }
        end

        if not s.volontario then
            voci[#voci + 1] = { id = 'iscriviti', icona = '🦺',
                titolo = 'Iscriviti al gruppo comunale',
                descrizione = 'Aperto a chiunque. Ti danno il gilet: senza non si entra in uno scenario.' }
        else
            voci[#voci + 1] = { id = 'x4', disattivata = true, icona = '🦺',
                titolo = 'Sei nel gruppo comunale',
                descrizione = ('%d interventi conclusi.'):format(s.interventi) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = PC.Sede.nome,
            sottotitolo = 'Sistema di allertamento e volontariato',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'rotta' and s.emergenza then
            SetNewWaypoint(s.emergenza.centro.x, s.emergenza.centro.y)
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🧭', titolo = 'Rotta impostata',
                testo = s.emergenza.zona,
            })
        end

        if scelta == 'iscriviti' or scelta == 'dotazione' then
            local ok, messaggio = AUREA.Callback.Attendi(
                scelta == 'iscriviti' and 'pc:iscriviti' or 'pc:dotazione')
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = scelta == 'iscriviti' and '🦺' or '📦',
                titolo = 'Protezione Civile', testo = tostring(messaggio), durata = 14000,
            })
        end
    end)
end

RegisterCommand('pc', pannello, false)

-- ---------------------------------------------------------------------------
--  Sede
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(PC.Sede.coord)
    SetBlipSprite(b, PC.Sede.blip.sprite)
    SetBlipColour(b, PC.Sede.blip.colore)
    SetBlipScale(b, PC.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(PC.Sede.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('pc_sede', PC.Sede.coord, PC.Sede.raggio, {
        { etichetta = 'Gruppo comunale di protezione civile', icona = '🚨', azione = pannello },
    })
end)
