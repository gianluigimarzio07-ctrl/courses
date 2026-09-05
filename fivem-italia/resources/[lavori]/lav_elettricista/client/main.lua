--[[
    AUREA · Manutenzione rete elettrica (client)

    Il blackout è vero: nella zona senza corrente i lampioni si spengono
    per chiunque sia lì.
]]

local U = AUREA.Util
local alBuio = {}       -- [idCabina] = true
local occupato = false

CreateThread(function()
    local s = ELE.Sede
    local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
    SetBlipSprite(b, s.blip.sprite)
    SetBlipColour(b, s.blip.colore)
    SetBlipScale(b, s.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('elettricista', s.coord, 4.0, {
        { etichetta = 'Guasti aperti', icona = '⚡',
          lavoro = ELE.Lavoro, azione = function() apri() end },
        { etichetta = 'Prendi il furgone', icona = '🚐',
          lavoro = ELE.Lavoro, azione = function() prendiMezzo() end },
    })

    for _, c in ipairs(ELE.Cabine) do
        exports.aurea_target:AggiungiZona('cabina_' .. c.id, c.coord, 3.0, {
            { etichetta = ('Ripara %s'):format(c.nome), icona = '🔌',
              lavoro = ELE.Lavoro, inServizio = true,
              condizione = function() return alBuio[c.id] == true end,
              azione = function() ripara(c.id) end },
        })
    end
end)

RegisterNetEvent('ele:blackout', function(idCabina, attivo)
    alBuio[idCabina] = attivo or nil
end)

--- Finché una zona è al buio, i lampioni lì restano spenti.
CreateThread(function()
    while true do
        local spegnere = false

        local coord = GetEntityCoords(PlayerPedId())
        for id in pairs(alBuio) do
            local c = ELE.GetCabina(id)
            if c and #(coord - c.coord) < 350.0 then spegnere = true break end
        end

        if spegnere then
            SetArtificialLightsState(true)
            SetArtificialLightsStateAffectsVehicles(false)
            Wait(500)
        else
            SetArtificialLightsState(false)
            Wait(2500)
        end
    end
end)

function apri()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('ele:guasti')
        if not dati then return end

        if #dati.guasti == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚡', titolo = 'Rete elettrica',
                testo = 'Nessun guasto aperto. Va tutto bene.',
            })
        end

        local voci = {}
        for _, g in ipairs(dati.guasti) do
            voci[#voci + 1] = {
                id = g.id, icona = '⚡', titolo = ('%s — %s'):format(g.cabina, g.guasto),
                descrizione = ('%s senza corrente da %d minuti · serve %d× %s')
                    :format(g.zona, g.minuti, g.quantita, g.etichettaOggetto),
                valore = U.Euro(g.paga),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Guasti aperti',
            sottotitolo = 'Dopo mezz\'ora interviene una ditta esterna e non paga nessuno',
            voci = voci,
        })
        if not scelta then return end

        local c = ELE.GetCabina(scelta)
        if c then
            SetNewWaypoint(c.coord.x, c.coord.y)
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📍', titolo = c.nome,
                testo = 'Segnata sulla mappa.', durata = 8000,
            })
        end
    end)
end

function prendiMezzo()
    CreateThread(function()
        local posto = ELE.Sede.mezzi[1]
        local hash = GetHashKey(ELE.Sede.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end
        local v = CreateVehicle(hash, posto.x, posto.y, posto.z, posto.w, true, false)
        SetVehicleNumberPlateText(v, 'RETE')
        SetModelAsNoLongerNeeded(hash)
        TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)
    end)
end

function ripara(idCabina)
    CreateThread(function()
        if occupato then return end

        local ok, dati = AUREA.Callback.Attendi('ele:ripara', idCabina)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '⚡', titolo = 'Intervento',
                testo = tostring(dati), durata = 11000,
            })
        end

        -- Prima di mettere le mani dentro si decide se staccare
        local staccato = exports.aurea_ui:Menu({
            titolo = dati.nome,
            sottotitolo = 'Staccare la tensione richiede tempo, non staccarla richiede fortuna',
            voci = {
                { id = 'stacca', icona = '🔒', titolo = 'Stacca la tensione e poi intervieni',
                  descrizione = 'Più lento, ma sicuro.' },
                { id = 'diretto', icona = '⚠', titolo = 'Intervieni sotto tensione',
                  descrizione = 'Più veloce. Puoi prendere la scossa.' },
            },
        })
        if not staccato then return end

        local sicuro = staccato == 'stacca'
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = dati.nome,
            durata = sicuro and math.floor(dati.durata * 1.4) or dati.durata,
            annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local fatto, messaggio = AUREA.Callback.Attendi('ele:concludiRiparazione', idCabina, sicuro)
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '💡',
            titolo = 'Intervento', testo = messaggio, durata = 14000,
        })
    end)
end

RegisterNetEvent('ele:scossa', function(danno)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - danno))
    SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.6)
end)

RegisterCommand('guasti', function() apri() end, false)
