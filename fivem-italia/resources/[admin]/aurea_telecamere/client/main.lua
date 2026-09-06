--[[
    AUREA · Videosorveglianza (client)

    La visuale è una telecamera di gioco piazzata dove sta l'obiettivo.
    Ruota e zooma entro i limiti dell'impianto: non è una telecamera
    libera, e non si può portare a spasso per la mappa.
]]

local inSala = false
local telecamere = {}
local indice = 1
local cam = nil
local nomeSala = ''

-- ---------------------------------------------------------------------------
--  Disegno del monitor
-- ---------------------------------------------------------------------------
local function testo(x, y, scala, contenuto, allineaDestra)
    SetTextFont(4)
    SetTextScale(0.0, scala)
    SetTextColour(220, 220, 220, 230)
    SetTextDropShadow()
    if allineaDestra then
        SetTextWrap(0.0, x)
        SetTextRightJustify(true)
    end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(contenuto)
    EndTextCommandDisplayText(x, y)
end

local function disegnaInterfaccia(t, inquadrati)
    -- Bande nere sopra e sotto: è un monitor, non il gioco
    DrawRect(0.5, 0.045, 1.0, 0.09, 0, 0, 0, 220)
    DrawRect(0.5, 0.955, 1.0, 0.09, 0, 0, 0, 220)

    testo(0.03, 0.02, 0.45, ('~y~%s'):format(nomeSala))
    testo(0.03, 0.05, 0.55, t.nome)
    testo(0.97, 0.02, 0.42, os.date('%d/%m/%Y  %H:%M:%S'), true)
    testo(0.97, 0.05, 0.40, ('impianto %d di %d'):format(indice, #telecamere), true)

    testo(0.03, 0.925, 0.38,
        '~w~A / D~s~ ruota    ~w~W / S~s~ inclina    ~w~rotella~s~ zoom    ~w~FRECCE~s~ cambia impianto    ~w~E~s~ fermo immagine    ~w~ESC~s~ esci')

    if #inquadrati > 0 then
        local righe = {}
        for n, p in ipairs(inquadrati) do
            if n > 4 then break end
            righe[#righe + 1] = ('%s (%d m)'):format(p.nome, p.metri)
        end
        testo(0.97, 0.905, 0.38, ('~y~Inquadrati: ~s~%s'):format(table.concat(righe, ' · ')), true)
    end

    -- Il puntino rosso di registrazione
    DrawRect(0.93, 0.115, 0.006, 0.011, 200, 50, 50, math.floor(math.abs(math.sin(GetGameTimer() / 400.0)) * 255))
    testo(0.965, 0.10, 0.40, 'REC', true)
end

-- ---------------------------------------------------------------------------
--  Collegamento a una telecamera
-- ---------------------------------------------------------------------------
local function collega(n)
    indice = ((n - 1) % #telecamere) + 1
    local t = telecamere[indice]

    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        RenderScriptCams(true, false, 500, true, true)
    end

    SetCamCoord(cam, t.coord.x, t.coord.y, t.coord.z)
    SetCamRot(cam, -12.0, 0.0, t.guarda, 2)
    SetCamFov(cam, 50.0)

    t.rot = t.guarda
    t.pitch = -12.0
    t.fov = 50.0
end

local function stacca()
    inSala = false
    if cam then
        RenderScriptCams(false, false, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    SetTimecycleModifier('default')
    ClearTimecycleModifier()
    DisplayRadar(true)
end

-- ---------------------------------------------------------------------------
--  Sala di controllo
-- ---------------------------------------------------------------------------
local function entra()
    local elenco, motivo, sala = AUREA.Callback.Attendi('tvc:circuito')
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📹', testo = motivo, durata = 10000 })
    end

    telecamere = {}
    for _, t in ipairs(elenco or {}) do
        t.coord = vector3(t.coord.x, t.coord.y, t.coord.z)
        telecamere[#telecamere + 1] = t
    end

    if #telecamere == 0 then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📹', testo = 'Nessun impianto sul circuito.' })
    end

    nomeSala = sala or 'Sala operativa'
    inSala = true
    DisplayRadar(false)
    SetTimecycleModifier('scanline_cam_cheap')
    collega(1)

    -- Chi c'è nell'inquadratura lo chiede un thread a parte: interrogare
    -- il server dentro il ciclo di disegno costerebbe un fotogramma a ogni
    -- risposta, e su un monitor si vedrebbe
    local inquadrati = {}

    CreateThread(function()
        while inSala do
            local t = telecamere[indice]
            if t and t.attiva and not (GlobalState.telecamereGuaste or {})[t.id] then
                inquadrati = AUREA.Callback.Attendi('tvc:inquadrati', t.id) or {}
            else
                inquadrati = {}
            end
            Wait(2000)
        end
    end)

    CreateThread(function()
        local guasteNote = GlobalState.telecamereGuaste or {}

        while inSala do
            Wait(0)
            local t = telecamere[indice]

            -- La telecamera spenta non mostra niente
            guasteNote = GlobalState.telecamereGuaste or {}
            local viva = t.attiva and not guasteNote[t.id]

            for _, controllo in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 21, 22, 24, 25, 30, 31, 32, 33, 34, 35, 44, 71, 72 }) do
                DisableControlAction(0, controllo, true)
            end

            if viva then
                if IsDisabledControlPressed(0, 34) then   -- A
                    t.rot = t.rot + TVC.Ottica.velocitaRotazione * GetFrameTime()
                elseif IsDisabledControlPressed(0, 35) then -- D
                    t.rot = t.rot - TVC.Ottica.velocitaRotazione * GetFrameTime()
                end

                if IsDisabledControlPressed(0, 32) then   -- W
                    t.pitch = math.min(TVC.Ottica.inclinazioneMax,
                        t.pitch + TVC.Ottica.velocitaRotazione * GetFrameTime())
                elseif IsDisabledControlPressed(0, 33) then -- S
                    t.pitch = math.max(TVC.Ottica.inclinazioneMin,
                        t.pitch - TVC.Ottica.velocitaRotazione * GetFrameTime())
                end

                -- Il brandeggio ha un fine corsa: non gira su se stessa
                local delta = t.rot - t.guarda
                if delta > 180.0 then delta = delta - 360.0 elseif delta < -180.0 then delta = delta + 360.0 end
                if delta > t.rotazione then t.rot = t.guarda + t.rotazione end
                if delta < -t.rotazione then t.rot = t.guarda - t.rotazione end

                if IsDisabledControlJustPressed(0, 241) then
                    t.fov = math.max(TVC.Ottica.fovMinimo, t.fov - 5.0)
                elseif IsDisabledControlJustPressed(0, 242) then
                    t.fov = math.min(TVC.Ottica.fovMassimo, t.fov + 5.0)
                end

                SetCamRot(cam, t.pitch, 0.0, t.rot, 2)
                SetCamFov(cam, t.fov)

                disegnaInterfaccia(t, inquadrati)
            else
                DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 235)
                testo(0.36, 0.47, 0.7, '~r~NESSUN SEGNALE')
                testo(0.30, 0.53, 0.42, ('~s~%s non trasmette. Guasto o disturbo in corso.'):format(t.nome))
                testo(0.03, 0.925, 0.38, '~w~FRECCE~s~ cambia impianto    ~w~ESC~s~ esci')
            end

            if IsDisabledControlJustPressed(0, 174) then collega(indice - 1) inquadrati = {} end
            if IsDisabledControlJustPressed(0, 175) then collega(indice + 1) inquadrati = {} end

            if viva and IsDisabledControlJustPressed(0, 38) then    -- E
                local ok, messaggio = AUREA.Callback.Attendi('tvc:fermo', t.id, t.nome)
                exports.aurea_ui:Notifica({
                    tipo = ok and 'successo' or 'errore', icona = '📸',
                    titolo = ok and 'Fermo immagine' or 'Non acquisito',
                    testo = messaggio, durata = 13000,
                })
            end

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) then
                stacca()
            end
        end

        stacca()
    end)
end

-- ---------------------------------------------------------------------------
--  Archivio dei fermi immagine
-- ---------------------------------------------------------------------------
local function archivio()
    local righe = AUREA.Callback.Attendi('tvc:fermi')
    local voci = {}

    for _, r in ipairs(righe or {}) do
        voci[#voci + 1] = {
            id = 'f', icona = '📸', titolo = r.nome_telecamera,
            descrizione = ('%s · operatore %s%s')
                :format(r.momento or '', r.operatore or 'n.d.',
                        r.presenti ~= '' and (' · inquadrati: ' .. r.presenti) or ' · nessuno riconoscibile'),
            disattivata = true,
        }
    end
    if #voci == 0 then
        voci[1] = { id = 'x', icona = '📸', titolo = 'Nessun fermo immagine agli atti', disattivata = true }
    end

    exports.aurea_ui:Menu({ titolo = 'Archivio dei fermi immagine', voci = voci })
end

-- ---------------------------------------------------------------------------
--  Il disturbatore, dall'altra parte
-- ---------------------------------------------------------------------------
RegisterNetEvent('tvc:usaJammer', function()
    if not exports.aurea_ui:Progresso({
        etichetta = 'Attivazione del disturbatore...', durata = 9000,
        blocca = { movimento = true },
    }) then return end

    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('tvc:jammer', c.x, c.y, c.z)
end)

-- ---------------------------------------------------------------------------
--  Punti
-- ---------------------------------------------------------------------------
CreateThread(function()
    for n, s in ipairs(TVC.Sale) do
        exports.aurea_target:AggiungiZona('tvc_sala_' .. n, s.coord, s.raggio, {
            { etichetta = 'Collegati al circuito', icona = '📹',
              lavori = s.lavori or TVC.Lavori, inServizio = true, azione = entra },
            { etichetta = 'Archivio fermi immagine', icona = '📸',
              lavori = s.lavori or TVC.Lavori, inServizio = true, azione = archivio },
        })
    end
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and inSala then stacca() end
end)
