--[[
    AUREA · Polizia Scientifica (client)

    Qui si disegna la scena e si comandano i rilievi. Nessun dato
    riservato passa da questa parte: il client sa che in un certo punto
    c'è una traccia ematica, non sa di chi sia. Lo scoprirà, se lo
    scoprirà, dal referto del laboratorio.
]]

local sopralluogoAttivo = false
local tracceViste = {}          -- elenco ricevuto dall'ultimo sopralluogo
local armiConosciute = {}       -- [hash] = nome tecnico, imparato impugnando

-- ---------------------------------------------------------------------------
--  Che arma ho in mano
--
--  Il server ci dirà lui se la matricola combacia: a noi serve solo il
--  nome tecnico per potergli dire con cosa abbiamo sparato.
-- ---------------------------------------------------------------------------
RegisterNetEvent('arm:impugna', function(metadata)
    if metadata and metadata.arma then
        armiConosciute[GetHashKey(metadata.arma)] = metadata.arma
    end
end)

CreateThread(function()
    local eraSparando = false

    while true do
        Wait(0)
        local ped = PlayerPedId()

        if IsPedShooting(ped) then
            if not eraSparando then
                eraSparando = true
                local _, hash = GetCurrentPedWeapon(ped, true)
                local nome = armiConosciute[hash]

                if nome then
                    local c = GetEntityCoords(ped)
                    -- Il bossolo cade dietro e a destra di chi spara
                    local dietro = GetOffsetFromEntityInWorldCoords(ped, 0.45, -0.35, 0.0)
                    TriggerServerEvent('sci:sparo', nome, dietro.x, dietro.y, c.z - 0.95)
                end
            end
        else
            eraSparando = false
            Wait(50)
        end
    end
end)

--- L'acqua toglie i residui dalle mani.
CreateThread(function()
    while true do
        Wait(4000)
        local ped = PlayerPedId()
        if IsEntityInWater(ped) then
            TriggerServerEvent('sci:lavaMani')
            Wait(30000)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Sopralluogo: le tracce si vedono a terra finché il rilievo è attivo
-- ---------------------------------------------------------------------------
local function disegnaTracce()
    CreateThread(function()
        while sopralluogoAttivo do
            Wait(0)
            local coord = GetEntityCoords(PlayerPedId())
            local vicina, distanzaVicina = nil, 99.0

            for _, t in ipairs(tracceViste) do
                local p = vector3(t.coord.x, t.coord.y, t.coord.z)
                local d = #(coord - p)

                if d < 30.0 then
                    local col = t.fotografata and { 90, 200, 120 } or { 220, 170, 60 }
                    DrawMarker(28, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.16, 0.16, 0.16, col[1], col[2], col[3], 190,
                        false, false, 2, false, nil, nil, false)

                    if d < 6.0 then
                        AUREA.Testo3D(p.x, p.y, p.z + 0.25, ('%s %s%s'):format(
                            t.icona, t.nome, t.fotografata and ' · fotografata' or ''))
                    end

                    if d < distanzaVicina then vicina, distanzaVicina = t, d end
                end
            end

            if vicina and distanzaVicina <= 2.0 then
                exports.aurea_ui:Prompt(true, ('Rilievi su: %s'):format(vicina.nome), 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    menuTraccia(vicina)
                end
            else
                exports.aurea_ui:Prompt(false)
            end
        end
        exports.aurea_ui:Prompt(false)
    end)
end

function menuTraccia(t)
    local dt = SCI.GetTraccia(t.tipo)

    local scelta = exports.aurea_ui:Menu({
        titolo = ('%s %s'):format(t.icona, t.nome),
        sottotitolo = dt and dt.descrizione or nil,
        voci = {
            { id = 'foto', icona = '📷', titolo = 'Documenta la traccia',
              descrizione = t.fotografata and 'Già fotografata.' or 'Va fatto prima di toccarla.',
              disattivata = t.fotografata },
            { id = 'reperta', icona = '🧪', titolo = 'Reperta',
              descrizione = t.fotografata
                  and 'Prelievo e sigillo. Poi va portata in laboratorio.'
                  or 'Prima serve la documentazione fotografica.',
              disattivata = not t.fotografata },
        },
    })

    if scelta == 'foto' then
        local ok, risposta = AUREA.Callback.Attendi('sci:fotografa', t.id)
        if not ok then return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📷', testo = risposta }) end

        if exports.aurea_ui:Progresso({
            etichetta = 'Rilievi fotografici...', durata = risposta,
            anim = { dizionario = 'amb@world_human_paparazzi@male@base', nome = 'base' },
            blocca = { movimento = true },
        }) then
            t.fotografata = true
            exports.aurea_ui:Notifica({ tipo = 'successo', icona = '📷',
                titolo = 'Traccia documentata', testo = 'Ora si può repertare.' })
        end

    elseif scelta == 'reperta' then
        local ok, risposta = AUREA.Callback.Attendi('sci:reperta', t.id)
        if not ok then return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🧪', testo = risposta }) end

        if exports.aurea_ui:Progresso({
            etichetta = 'Prelievo e repertazione...', durata = risposta,
            anim = { dizionario = 'amb@medic@standing@kneel@base', nome = 'base' },
            blocca = { movimento = true },
        }) then
            local fatto, messaggio = AUREA.Callback.Attendi('sci:concludiReperto', t.id)
            exports.aurea_ui:Notifica({
                tipo = fatto and 'successo' or 'errore', icona = '🧪',
                titolo = fatto and 'Reperto acquisito' or 'Repertazione fallita',
                testo = messaggio, durata = 12000,
            })
            if fatto then sopralluogo() end
        end
    end
end

function sopralluogo()
    local tracce, conKit = AUREA.Callback.Attendi('sci:sopralluogo')
    tracceViste = tracce or {}

    if #tracceViste == 0 then
        sopralluogoAttivo = false
        return exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🔬', titolo = 'Sopralluogo',
            durata = 9000,
            testo = conKit and 'Nessuna traccia utile nel raggio del rilievo.'
                or 'Nessuna traccia visibile a occhio nudo. Senza la valigetta non vedi le latenti.',
        })
    end

    if not sopralluogoAttivo then
        sopralluogoAttivo = true
        disegnaTracce()
    end

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🔬', titolo = 'Sopralluogo in corso',
        testo = ('%d tracce sulla scena. /rilievi di nuovo per chiudere.'):format(#tracceViste),
        durata = 9000,
    })
end

RegisterCommand('rilievi', function()
    if sopralluogoAttivo then
        sopralluogoAttivo = false
        tracceViste = {}
        return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🔬', titolo = 'Sopralluogo chiuso' })
    end
    sopralluogo()
end, false)

-- ---------------------------------------------------------------------------
--  Fotosegnalamento e stub sul soggetto
-- ---------------------------------------------------------------------------
local function personaVicina()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, 4.0

    for _, id in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(id)
        if altro ~= ped then
            local d = #(coord - GetEntityCoords(altro))
            if d < distanza then migliore, distanza = GetPlayerServerId(id), d end
        end
    end
    return migliore
end

RegisterCommand('fotosegnala', function()
    local bersaglio = personaVicina()
    if not bersaglio then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🖐', testo = 'Nessuno davanti a te.' })
    end

    local ok, durata, soggettoSrc, nome = AUREA.Callback.Attendi('sci:fotosegnala', bersaglio)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🖐', testo = durata, durata = 10000 })
    end

    if exports.aurea_ui:Progresso({
        etichetta = ('Fotosegnalamento di %s...'):format(nome), durata = durata,
        anim = { dizionario = 'anim@heists@prison_heiststation@cop_reactions', nome = 'cop_a_idle' },
        blocca = { movimento = true },
    }) then
        local fatto, messaggio = AUREA.Callback.Attendi('sci:concludiFotosegnalamento', soggettoSrc)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '🖐',
            titolo = fatto and 'Cartellino acquisito' or 'Non riuscito',
            testo = messaggio, durata = 12000,
        })
    end
end, false)

RegisterCommand('stub', function()
    local bersaglio = personaVicina()
    if not bersaglio then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💨', testo = 'Nessuno davanti a te.' })
    end

    if not exports.aurea_ui:Progresso({
        etichetta = 'Prelievo con stub sulle mani...', durata = 6000,
        blocca = { movimento = true },
    }) then return end

    local ok, messaggio = AUREA.Callback.Attendi('sci:stub', bersaglio)
    exports.aurea_ui:Notifica({
        tipo = ok and 'avviso' or 'errore', icona = '💨',
        titolo = ok and 'Esito dello stub' or 'Non riuscito',
        testo = messaggio, durata = 15000,
    })
end, false)

-- ---------------------------------------------------------------------------
--  Laboratorio
-- ---------------------------------------------------------------------------
local function apriLaboratorio()
    local reperti = exports.aurea_inventory:Righe('reperto') or {}
    local voci = {}

    for _, riga in ipairs(reperti) do
        local m = riga.metadata or {}
        voci[#voci + 1] = {
            id = tostring(m.repertoId),
            icona = SCI.Tracce[m.tipo] and SCI.Tracce[m.tipo].icona or '🧪',
            titolo = ('Reperto n. %s — %s'):format(m.repertoId or '?', m.nomeTraccia or 'ignoto'),
            descrizione = ('Zona %s · repertato da %s'):format(m.luogo or 'n.d.', m.repertatoDa or 'n.d.'),
            disattivata = m.analizzato == true,
        }
    end

    voci[#voci + 1] = { id = 'referti', icona = '📄', titolo = 'Consulta i referti emessi',
                        descrizione = 'Gli ultimi esiti del gabinetto.' }

    if #voci == 1 then
        table.insert(voci, 1, { id = 'x', icona = '📦', titolo = 'Nessun reperto in consegna',
                                descrizione = 'Vai sulla scena e reperta qualcosa.', disattivata = true })
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = SCI.Laboratorio.nome,
        sottotitolo = 'Accettazione reperti',
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    if scelta == 'referti' then
        local righe = AUREA.Callback.Attendi('sci:referti', 25)
        local elenco = {}
        for _, r in ipairs(righe or {}) do
            elenco[#elenco + 1] = {
                id = tostring(r.id), icona = r.esito == 'positivo' and '🟥' or (r.esito == 'negativo' and '⬜' or '🟨'),
                titolo = ('n. %d — %s (zona %s)'):format(r.id, r.tipo, r.luogo),
                descrizione = r.referto,
                disattivata = true,
            }
        end
        if #elenco == 0 then
            elenco[1] = { id = 'x', icona = '📄', titolo = 'Nessun referto emesso', disattivata = true }
        end
        exports.aurea_ui:Menu({ titolo = 'Referti del gabinetto', voci = elenco })
        return
    end

    local ok, messaggio = AUREA.Callback.Attendi('sci:avviaAnalisi', tonumber(scelta))
    exports.aurea_ui:Notifica({
        tipo = ok and 'successo' or 'errore', icona = '🔬',
        titolo = ok and 'Analisi avviata' or 'Non accettato',
        testo = messaggio, durata = 12000,
    })
end

RegisterNetEvent('sci:referto', function(r)
    exports.aurea_ui:Notifica({
        tipo = r.esito == 'positivo' and 'successo' or (r.esito == 'negativo' and 'avviso' or 'info'),
        icona = '📄', durata = 22000,
        titolo = ('Referto reperto n. %d — %s'):format(r.repertoId, r.nomeTraccia),
        testo = r.testo,
    })
end)

-- ---------------------------------------------------------------------------
--  Punti sulla mappa e terzo occhio
-- ---------------------------------------------------------------------------
CreateThread(function()
    local b = SCI.Laboratorio.blip
    local blip = AddBlipForCoord(SCI.Laboratorio.coord)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.colore)
    SetBlipScale(blip, b.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(SCI.Laboratorio.nome)
    EndTextCommandSetBlipName(blip)

    exports.aurea_target:AggiungiZona('scientifica_lab', SCI.Laboratorio.coord, SCI.Laboratorio.raggio, {
        {
            etichetta = 'Accettazione reperti', icona = '🔬',
            lavori = SCI.Lavori, inServizio = true,
            azione = apriLaboratorio,
        },
    })

    for n, p in ipairs(SCI.Fotosegnalamento.postazioni) do
        exports.aurea_target:AggiungiZona('scientifica_segn_' .. n, p.coord, 2.5, {
            {
                etichetta = 'Fotosegnalamento (art. 349 c.p.p.)', icona = '🖐',
                lavori = SCI.Lavori, inServizio = true,
                azione = function() ExecuteCommand('fotosegnala') end,
            },
        })
    end
end)
