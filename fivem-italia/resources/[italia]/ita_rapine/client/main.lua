--[[
    AUREA · Rapine (client)
]]

local U = AUREA.Util
local inRapina = false
local portavalori = nil
local blipPortavalori = nil

-- ---------------------------------------------------------------------------
--  Volto coperto: il passamontagna cambia le probabilità di identificazione
-- ---------------------------------------------------------------------------
local function mascherato()
    local ped = PlayerPedId()
    local maschera = GetPedDrawableVariation(ped, 1)
    local cappello = GetPedPropIndex(ped, 0)
    return maschera > 0 or cappello > 0
end

-- ---------------------------------------------------------------------------
--  Interazione con i bersagli
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local bersaglio = RAP.BersaglioVicino(coord)

        if bersaglio and not inRapina then
            attesa = 0

            if AUREA.EInServizio() and AUREA.HaLavoro('carabinieri', 'polizia', 'guardia_finanza') then
                exports.aurea_ui:Prompt(true, ('%s — interrompi il colpo'):format(bersaglio.nome), 'G')
                if IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    interrompi(bersaglio)
                end
            else
                local armato = IsPedArmed(ped, 4)
                exports.aurea_ui:Prompt(true,
                    armato and ('Rapina — %s'):format(bersaglio.nome) or 'Serve un\'arma per minacciare',
                    'G')

                if armato and IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    avvia(bersaglio)
                end
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Svolgimento
-- ---------------------------------------------------------------------------
function avvia(bersaglio)
    CreateThread(function()
        if inRapina then return end

        local conferma = exports.aurea_ui:Menu({
            titolo = bersaglio.nome,
            sottotitolo = ('%s — chi è nel raggio partecipa e divide'):format(RAP.Livelli[bersaglio.livello].nome),
            voci = {
                { id = 'si', icona = '🔫', titolo = 'Procedi con la rapina',
                  descrizione = mascherato()
                      and 'Hai il volto coperto: più difficile essere identificato.'
                      or 'Sei a volto scoperto: le telecamere ti riconosceranno.' },
                { id = 'no', icona = '↩', titolo = 'Lascia perdere' },
            },
        })
        if conferma ~= 'si' then return end

        local dati, errore = AUREA.Callback.Attendi('rap:avvia', bersaglio.id, mascherato())
        if not dati then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚫', durata = 13000,
                titolo = 'Colpo non avviabile', testo = errore,
            })
        end

        inRapina = true

        exports.aurea_ui:Notifica({
            tipo = 'avviso', icona = '🚨', durata = 12000,
            titolo = 'Allarme scattato',
            testo = ('%d persone partecipano. Restate nel raggio o il colpo salta.'):format(dati.partecipanti),
        })

        local riuscita = false

        if dati.fasi then
            -- Colpo a fasi: ognuna può fallire
            riuscita = true
            for n, fase in ipairs(dati.fasi) do
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '⏱', durata = 6000,
                    titolo = ('Fase %d di %d'):format(n, #dati.fasi), testo = fase.nome,
                })

                local completata = exports.aurea_ui:Progresso({
                    etichetta = fase.nome,
                    durata = fase.durata,
                    annullabile = true,
                    blocca = { movimento = true },
                })

                if not completata then riuscita = false break end
            end

        elseif dati.vetrine then
            -- Gioielleria: una vetrina alla volta
            local aperte = 0
            for n = 1, dati.vetrine do
                local completata = exports.aurea_ui:Progresso({
                    etichetta = ('Vetrina %d di %d'):format(n, dati.vetrine),
                    durata = dati.durataVetrina,
                    annullabile = true,
                    anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
                    blocca = { movimento = true },
                })
                if not completata then break end
                aperte = aperte + 1
            end
            riuscita = aperte >= math.ceil(dati.vetrine / 2)

        else
            riuscita = exports.aurea_ui:Progresso({
                etichetta = ('Rapina in corso — %s'):format(dati.nome),
                durata = dati.durata,
                annullabile = true,
                blocca = { movimento = true },
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('rap:concludi', bersaglio.id, riuscita)
        inRapina = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = ok and '💰' or '🚫',
            titolo = ok and 'Colpo riuscito' or 'Colpo fallito',
            testo = messaggio, durata = 14000,
        })
    end)
end

function interrompi(bersaglio)
    CreateThread(function()
        local ok, messaggio = AUREA.Callback.Attendi('rap:interrompi', bersaglio.id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'info',
            icona = '🚔', titolo = ok and 'Colpo sventato' or 'Nulla da interrompere',
            testo = messaggio, durata = 9000,
        })
    end)
end

RegisterNetEvent('rap:interrotta', function()
    inRapina = false
end)

-- ---------------------------------------------------------------------------
--  Portavalori
-- ---------------------------------------------------------------------------
RegisterNetEvent('rap:portavaloriComparso', function(coord)
    portavalori = coord

    if blipPortavalori then RemoveBlip(blipPortavalori) end
    blipPortavalori = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(blipPortavalori, 67)
    SetBlipColour(blipPortavalori, 5)
    SetBlipScale(blipPortavalori, 0.8)
    SetBlipAsShortRange(blipPortavalori, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Furgone portavalori')
    EndTextCommandSetBlipName(blipPortavalori)
end)

RegisterNetEvent('rap:portavaloriSparito', function()
    portavalori = nil
    if blipPortavalori then RemoveBlip(blipPortavalori) blipPortavalori = nil end
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(6000)
        local coord = AUREA.Callback.Attendi('rap:portavaloriDove')
        if coord then TriggerEvent('rap:portavaloriComparso', coord) end
    end)
end)

CreateThread(function()
    while true do
        local attesa = 1200

        if portavalori and not inRapina then
            local coord = GetEntityCoords(PlayerPedId())
            local pos = vector3(portavalori.x, portavalori.y, portavalori.z)

            if #(coord - pos) < 4.0 then
                attesa = 0
                exports.aurea_ui:Prompt(true, 'Forza il portellone', 'G')
                if IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    assaltaPortavalori()
                end
            end
        end

        Wait(attesa)
    end
end)

function assaltaPortavalori()
    CreateThread(function()
        if inRapina then return end
        inRapina = true

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Forzatura del portellone...',
            durata = RAP.Livelli.portavalori.durata,
            annullabile = true,
            anim = { dizionario = 'mini@repair', nome = 'fixing_a_ped' },
            blocca = { movimento = true },
        })
        if not completata then inRapina = false return end

        local ok, messaggio = AUREA.Callback.Attendi('rap:portavalori')
        inRapina = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '💰', titolo = ok and 'Furgone svuotato' or 'Assalto fallito',
            testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Consultazione dei bersagli
-- ---------------------------------------------------------------------------
RegisterCommand('colpi', function()
    CreateThread(function()
        local stato = AUREA.Callback.Attendi('rap:stato')
        if not stato then return end

        local voci = {
            { id = 'agenti', icona = '🚔',
              titolo = ('Agenti in servizio: %d'):format(stato.agenti),
              descrizione = 'Senza qualcuno che possa rispondere, i colpi non partono.',
              disattivata = true },
        }

        for _, b in ipairs(RAP.Bersagli) do
            local s = stato.bersagli[b.id]
            if s then
                local nota
                if s.inCorso then nota = 'colpo in corso'
                elseif s.minutiAttesa > 0 then nota = ('sorvegliato ancora %d min'):format(s.minutiAttesa)
                elseif stato.agenti < s.agentiRichiesti then nota = ('servono %d agenti'):format(s.agentiRichiesti)
                else nota = 'praticabile' end

                voci[#voci + 1] = {
                    id = b.id,
                    icona = s.disponibile and '🟢' or '🔴',
                    titolo = b.nome,
                    descrizione = RAP.Livelli[b.livello].nome,
                    valore = nota,
                    disattivata = true,
                }
            end
        end

        exports.aurea_ui:Menu({
            titolo = 'Bersagli',
            sottotitolo = 'La difficoltà scala con il valore del colpo',
            voci = voci,
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and blipPortavalori then RemoveBlip(blipPortavalori) end
end)
