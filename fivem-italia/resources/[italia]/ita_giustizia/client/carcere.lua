--[[
    AUREA · Casa Circondariale (client)
]]

local U = AUREA.Util
local detenuto = false
local residui, totali = 0, 0

-- ---------------------------------------------------------------------------
--  Ingresso in istituto
-- ---------------------------------------------------------------------------
RegisterNetEvent('giu:incarcerato', function(dati)
    detenuto = true
    residui = dati.minuti
    totali = dati.minuti

    DoScreenFadeOut(700)
    Wait(750)

    local cella = GIU.CellaCasuale()
    local ped = PlayerPedId()
    SetEntityCoords(ped, cella.x, cella.y, cella.z, false, false, false, false)
    SetEntityHeading(ped, cella.w)
    SetEntityHealth(ped, 200)
    ClearPedTasksImmediately(ped)
    RemoveAllPedWeapons(ped, true)

    Wait(500)
    DoScreenFadeIn(900)

    exports.aurea_ui:Notifica({
        tipo = 'errore', icona = '🔒', durata = 16000,
        titolo = dati.ripresa and 'Detenzione in corso' or 'Ingresso in istituto',
        testo = ('%s\n\nPena residua: %d minuti. Le attività trattamentali riducono la pena.'):format(
            dati.motivo or 'provvedimento dell\'Autorità Giudiziaria', dati.minuti),
    })
end)

RegisterNetEvent('giu:scarcerato', function(motivo)
    detenuto = false

    DoScreenFadeOut(700)
    Wait(750)

    local r = GIU.Carcere.rilascio
    local ped = PlayerPedId()
    SetEntityCoords(ped, r.x, r.y, r.z, false, false, false, false)
    SetEntityHeading(ped, r.w)
    SetEntityHealth(ped, 200)

    Wait(500)
    DoScreenFadeIn(900)

    exports.aurea_ui:Notifica({
        tipo = 'successo', icona = '🔓', durata = 13000,
        titolo = 'Scarcerazione',
        testo = ('%s. I precedenti restano iscritti nel casellario giudiziale.'):format(motivo or 'Fine pena'),
    })
end)

RegisterNetEvent('giu:aggiornaPena', function(nuoviResidui, nuoviTotali)
    residui = nuoviResidui
    totali = nuoviTotali or totali
end)

-- ---------------------------------------------------------------------------
--  Vita in istituto
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000

        if detenuto then
            attesa = 0
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)

            -- Nessuna arma, nessun veicolo
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true) DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)

            if GetVehiclePedIsIn(ped, false) ~= 0 then
                TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
            end

            -- Perimetro: si viene riportati dentro
            local distanza = #(coord - GIU.Carcere.perimetro.centro)
            if distanza > GIU.Carcere.perimetro.raggio + 40.0 then
                local cortile = GIU.Carcere.cortile
                SetEntityCoords(ped, cortile.x, cortile.y, cortile.z, false, false, false, false)
                exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '🚨', durata = 8000,
                    titolo = 'Riportato in istituto',
                    testo = 'Ti sei allontanato troppo: sei stato ricondotto dentro.',
                })
            end

            -- Attività trattamentali
            local vicina = nil
            for _, a in ipairs(GIU.Attivita) do
                if #(coord - a.coord) < 12.0 then
                    DrawMarker(2, a.coord.x, a.coord.y, a.coord.z + 0.4, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                        0.3, 0.3, 0.2, 31, 157, 85, 160, false, false, 2, true, nil, nil, false)
                    if #(coord - a.coord) < 2.0 then vicina = a end
                end
            end

            if vicina then
                exports.aurea_ui:Prompt(true, ('%s — riduci la pena di %d minuti'):format(vicina.nome, vicina.sconto), 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    svolgiAttivita(vicina)
                end
            else
                exports.aurea_ui:Prompt(false)
                attesa = 200
            end
        end

        Wait(attesa)
    end
end)

function svolgiAttivita(attivita)
    CreateThread(function()
        local completata = exports.aurea_ui:Progresso({
            etichetta = ('%s in corso...'):format(attivita.nome),
            durata = GIU.Regole.duratsAttivita,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_janitor@male@idle_a', nome = 'idle_a' },
            blocca = { movimento = true },
        })
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('giu:attivita', attivita.id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '⏳', titolo = ok and 'Attività completata' or 'Attività non conteggiata',
            testo = messaggio, durata = 9000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Comando per il detenuto
-- ---------------------------------------------------------------------------
RegisterCommand('pena', function()
    CreateThread(function()
        local stato = AUREA.Callback.Attendi('giu:statoDetenzione')
        if not stato then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '⚖', titolo = 'Nessuna detenzione', testo = 'Non stai scontando alcuna pena.' })
        end

        local voci = {
            { id = 'stato', icona = '⏳', titolo = 'Pena in esecuzione',
              descrizione = ('%d minuti scontati su %d'):format(stato.scontati, stato.totali),
              valore = ('%d residui'):format(stato.residui), disattivata = true },
        }

        if stato.cauzionePossibile then
            voci[#voci + 1] = {
                id = 'cauzione', icona = '💶',
                titolo = 'Chiedi la liberazione su cauzione',
                descrizione = 'Ammessa solo per reati di gravità non elevata.',
                valore = U.Euro(stato.cauzione),
            }
        else
            voci[#voci + 1] = {
                id = 'nocauzione', icona = '🚫',
                titolo = 'Cauzione non ammessa',
                descrizione = 'La gravità dei reati contestati non la consente.',
                disattivata = true,
            }
        end

        voci[#voci + 1] = {
            id = 'patteggia', icona = '⚖',
            titolo = 'Patteggia con il tuo legale',
            descrizione = ('Riduzione di un terzo della pena residua. Onorario %s.'):format(U.Euro(GIU.Tribunale.onorarioAvvocato)),
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = GIU.Carcere.nome,
            sottotitolo = 'Posizione giuridica',
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'cauzione' then
            local ok, messaggio = AUREA.Callback.Attendi('giu:cauzione')
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '💶', titolo = ok and 'Liberazione su cauzione' or 'Istanza respinta',
                testo = messaggio, durata = 11000,
            })

        elseif scelta == 'patteggia' then
            local avvocato = giocatoreVicino(4.0)
            if not avvocato then
                return exports.aurea_ui:Notifica({
                    tipo = 'errore', titolo = 'Nessun legale presente',
                    testo = 'Il patteggiamento richiede la presenza fisica del tuo avvocato.',
                })
            end
            local ok, messaggio = AUREA.Callback.Attendi('giu:patteggia', avvocato)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '⚖', titolo = ok and 'Patteggiamento accolto' or 'Patteggiamento respinto',
                testo = messaggio, durata = 11000,
            })
        end
    end)
end, false)

exports('EDetenuto', function() return detenuto end)
