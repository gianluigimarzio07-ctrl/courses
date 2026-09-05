--[[
    AUREA · Terzo occhio (client)

    Un registro di zone e modelli, un raggio che parte dalla telecamera, e
    un menu che raccoglie tutte le opzioni valide sul punto mirato. Le
    condizioni (lavoro, servizio, oggetto in tasca) le valuta qui perché
    servono solo a decidere cosa MOSTRARE: quello che l'azione poi fa
    davvero lo verifica il server, come sempre.
]]

local zone = {}         -- [nome] = { coord, raggio, voci }
local modelli = {}      -- [hash] = voci
local attivo = false
local mirato = nil      -- { tipo, entita, zona, voci }

-- ---------------------------------------------------------------------------
--  Registro
-- ---------------------------------------------------------------------------
local function AggiungiZona(nome, coord, raggio, voci)
    zone[nome] = { coord = coord, raggio = raggio or 2.0, voci = voci or {} }
end

local function RimuoviZona(nome) zone[nome] = nil end

local function AggiungiModello(elenco, voci)
    for _, m in ipairs(elenco) do
        local hash = type(m) == 'string' and GetHashKey(m) or m
        modelli[hash] = modelli[hash] or {}
        for _, v in ipairs(voci) do modelli[hash][#modelli[hash] + 1] = v end
    end
end

exports('AggiungiZona', AggiungiZona)
exports('RimuoviZona', RimuoviZona)
exports('AggiungiModello', AggiungiModello)

-- ---------------------------------------------------------------------------
--  Condizioni
-- ---------------------------------------------------------------------------
local function ammessa(voce)
    if voce.lavoro and not AUREA.HaLavoro(voce.lavoro) then return false end
    if voce.lavori and not AUREA.HaLavoro(table.unpack(voce.lavori)) then return false end
    if voce.inServizio and not AUREA.EInServizio() then return false end
    if voce.oggetto and not exports.aurea_inventory:Ha(voce.oggetto, 1) then return false end
    if voce.condizione and not voce.condizione() then return false end
    return true
end

local function vociAmmesse(elenco, entita)
    local out = {}
    for _, v in ipairs(elenco or {}) do
        if ammessa(v) then out[#out + 1] = v end
    end
    return out
end

-- ---------------------------------------------------------------------------
--  Raggio
-- ---------------------------------------------------------------------------
local function puntato()
    local cam = GetGameplayCamCoord()
    local direzione = RotazioneInDirezione(GetGameplayCamRot(2))
    local fine = cam + direzione * TGT.Distanza

    local raggio = StartShapeTestRay(cam.x, cam.y, cam.z, fine.x, fine.y, fine.z,
        -1, PlayerPedId(), 4)
    local _, colpito, punto, _, entita = GetShapeTestResult(raggio)

    if colpito == 0 then return nil end
    return entita, vector3(punto.x, punto.y, punto.z)
end

function RotazioneInDirezione(rot)
    local rz = math.rad(rot.z)
    local rx = math.rad(rot.x)
    local coseno = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * coseno, math.cos(rz) * coseno, math.sin(rx))
end

--- Che cosa c'è sotto il puntatore, e quali voci valgono lì.
local function analizza()
    local ped = PlayerPedId()
    local mio = GetEntityCoords(ped)
    local entita, punto = puntato()

    -- 1. Zone fisse: vincono se il punto mirato ci cade dentro
    if punto then
        for nome, z in pairs(zone) do
            if #(punto - z.coord) < z.raggio and #(mio - z.coord) < (z.raggio + TGT.Distanza) then
                local voci = vociAmmesse(z.voci)
                if #voci > 0 then
                    return { tipo = 'zona', zona = nome, punto = z.coord, voci = voci }
                end
            end
        end
    end

    if not entita or entita == 0 or not DoesEntityExist(entita) then return nil end

    local coordEntita = GetEntityCoords(entita)
    if #(mio - coordEntita) > TGT.Distanza then return nil end

    -- 2. Modelli registrati (bancomat, distributori, casse...)
    local hash = GetEntityModel(entita)
    if modelli[hash] then
        local voci = vociAmmesse(modelli[hash], entita)
        if #voci > 0 then
            return { tipo = 'modello', entita = entita, punto = coordEntita, voci = voci }
        end
    end

    -- 3. Veicoli
    if IsEntityAVehicle(entita) then
        local voci = vociAmmesse(TGT.VociVeicolo, entita)
        if modelli[hash] then
            for _, v in ipairs(vociAmmesse(modelli[hash], entita)) do voci[#voci + 1] = v end
        end
        if #voci > 0 and #(mio - coordEntita) < TGT.DistanzaEntita + 2.0 then
            return { tipo = 'veicolo', entita = entita, punto = coordEntita, voci = voci }
        end
    end

    -- 4. Persone
    if IsEntityAPed(entita) and IsPedAPlayer(entita) and entita ~= ped then
        if #(mio - coordEntita) > TGT.DistanzaEntita then return nil end
        local voci = vociAmmesse(TGT.VociPersona, entita)
        if #voci > 0 then
            return { tipo = 'persona', entita = entita, punto = coordEntita, voci = voci }
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
--  Ciclo di mira
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 250

        if IsControlPressed(0, TGT.Tasto) and not IsPedInAnyVehicle(PlayerPedId(), false)
           and not IsPauseMenuActive() then

            if not attivo then
                attivo = true
                SetCursorLocation(0.5, 0.5)
            end

            attesa = TGT.Frequenza
            mirato = analizza()

            if mirato then
                local c = TGT.Colori.attivo
                DrawMarker(28, mirato.punto.x, mirato.punto.y, mirato.punto.z,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12,
                    c[1], c[2], c[3], c[4], false, true, 2, nil, nil, false)

                AUREA.Testo3D(mirato.punto.x, mirato.punto.y, mirato.punto.z + 0.28,
                    #mirato.voci == 1 and mirato.voci[1].etichetta
                        or ('%d azioni'):format(#mirato.voci), 0.34)

                if IsControlJustReleased(0, TGT.TastoSelezione) then
                    apri(mirato)
                end
            end

        elseif attivo then
            attivo = false
            mirato = nil
        end

        Wait(attesa)
    end
end)

function apri(bersaglio)
    local voci = bersaglio.voci

    -- Una sola opzione: si esegue, senza far aprire un menu per niente
    if #voci == 1 then return esegui(voci[1], bersaglio) end

    CreateThread(function()
        local elenco = {}
        for n, v in ipairs(voci) do
            elenco[n] = { id = tostring(n), icona = v.icona or '•',
                          titolo = v.etichetta, descrizione = v.descrizione }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Azioni', sottotitolo = nil, voci = elenco,
        })
        if not scelta then return end
        esegui(voci[tonumber(scelta)], bersaglio)
    end)
end

function esegui(voce, bersaglio)
    if not voce then return end

    if voce.azione then
        return voce.azione(bersaglio.entita, bersaglio)
    end

    -- Voci integrate
    if voce.id == 'bagagliaio' and bersaglio.entita then
        if GetVehicleDoorAngleRatio(bersaglio.entita, 5) > 0.1 then
            SetVehicleDoorShut(bersaglio.entita, 5, false)
        else
            SetVehicleDoorOpen(bersaglio.entita, 5, false, false)
        end

    elseif voce.id == 'cofano' and bersaglio.entita then
        if GetVehicleDoorAngleRatio(bersaglio.entita, 4) > 0.1 then
            SetVehicleDoorShut(bersaglio.entita, 4, false)
        else
            SetVehicleDoorOpen(bersaglio.entita, 4, false, false)
        end

    elseif voce.id == 'documenti' and bersaglio.entita then
        local altro = NetworkGetPlayerIndexFromPed(bersaglio.entita)
        TriggerServerEvent('tgt:chiediDocumenti', GetPlayerServerId(altro))

    elseif voce.id == 'perquisisci' and bersaglio.entita then
        -- La perquisizione è l'apertura dell'inventario altrui: permesso e
        -- prossimità li verifica il server prima di aprirlo.
        local altro = NetworkGetPlayerIndexFromPed(bersaglio.entita)
        exports.aurea_inventory:Apri({ tipo = 'persona', bersaglio = GetPlayerServerId(altro) })
    end
end

RegisterNetEvent('tgt:documentiRichiesti', function(daNome, daSrc)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🪪', durata = 12000,
        titolo = ('%s ti chiede i documenti'):format(daNome),
        testo = 'Apri l\'inventario e mostraglieli, oppure rifiuta.',
    })
end)
