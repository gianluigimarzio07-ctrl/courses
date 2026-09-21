--[[
    AUREA · Taxi (client)

    Il tassametro sullo schermo è solo un numero che il server rimanda
    indietro. Il client manda la posizione, il server misura: se fosse
    il contrario, ogni corsa costerebbe quello che dice il tassista.
]]

local U = AUREA.Util

local corsaAttiva = nil

RegisterNetEvent('tax:tassametro', function(id, attivo)
    corsaAttiva = attivo and id or nil
end)

--- Il campionamento della posizione, finché il tassametro gira.
CreateThread(function()
    while true do
        Wait(TAX.Tariffa.secondiAggiornamento * 1000)

        if corsaAttiva then
            local veicolo = GetVehiclePedIsIn(PlayerPedId(), false)
            local fermo = veicolo == 0
                or (GetEntitySpeed(veicolo) * 3.6) < TAX.Tariffa.sogliaFermo
            TriggerServerEvent('tax:posizione', corsaAttiva, fermo)
        end
    end
end)

local function avvia()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Corsa', {
            { etichetta = 'ID del cliente a bordo', tipo = 'number', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('tax:avvia', tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚕',
            titolo = 'Tassametro', testo = tostring(messaggio), durata = 14000 })
    end)
end

local function stato()
    CreateThread(function()
        if not corsaAttiva then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🚕',
                titolo = 'Tassametro', testo = 'Nessuna corsa in corso.' })
        end

        local s = AUREA.Callback.Attendi('tax:stato', corsaAttiva)
        if not s then return end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Tassametro',
            sottotitolo = s.licenza and ('Licenza %s'):format(s.licenza)
                                    or 'SENZA LICENZA — trasporto abusivo',
            voci = {
                { id = 'x', disattivata = true, icona = '📏',
                  titolo = ('%.2f km'):format(s.metri / 1000),
                  descrizione = ('Fermo per %d secondi'):format(s.secondiFermo) },
                { id = 'x', disattivata = true, icona = '💶',
                  titolo = ('Al momento: %s'):format(U.Euro(s.importo)),
                  descrizione = s.moltiplicatore > 1.0
                      and ('Supplemento attivo: x%.2f'):format(s.moltiplicatore)
                      or 'Tariffa ordinaria.' },
                { id = 'chiudi', icona = '🏁', titolo = 'Chiudi la corsa',
                  descrizione = 'Il cliente paga quello che segna il tassametro.' },
            },
        })
        if scelta ~= 'chiudi' then return end

        local ok, messaggio = AUREA.Callback.Attendi('tax:chiudi', corsaAttiva)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏁',
            titolo = 'Corsa conclusa', testo = tostring(messaggio), durata = 18000 })
    end)
end

local function rimessa()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('tax:licenze')
        if not s then return end

        local voci = {
            { id = 'x', disattivata = true, icona = '🪪',
              titolo = s.mia and ('Licenza %s'):format(s.mia.numero) or 'Nessuna licenza',
              descrizione = s.mia
                  and ('Valida ancora %d giorni.'):format(s.mia.giorni or 0)
                  or ('Rilasciate %d su %d. Senza, le corse sono abusive.')
                      :format(s.rilasciate, s.contingente) },
        }

        if not s.mia then
            voci[#voci + 1] = {
                id = 'licenza', icona = '📝', titolo = 'Chiedi la licenza comunale',
                descrizione = ('%s, vale %d giorni. Il contingente è di %d licenze in tutto.')
                    :format(U.Euro(s.costo), s.giorni, s.contingente),
            }
        end

        voci[#voci + 1] = { id = 'mezzo', icona = '🚕', titolo = 'Prendi un taxi',
            descrizione = 'Dalla rimessa.' }
        voci[#voci + 1] = { id = 'registro', icona = '📋', titolo = 'Le tue corse',
            descrizione = 'Le ultime quindici.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = TAX.Rimessa.nome,
            sottotitolo = 'Licenza, mezzo, registro',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if scelta == 'licenza' then
            local ok, messaggio = AUREA.Callback.Attendi('tax:chiediLicenza')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🪪',
                titolo = 'Licenza taxi', testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'registro' then
            local righe = AUREA.Callback.Attendi('tax:registro') or {}
            local v = {}
            for _, c in ipairs(righe) do
                v[#v + 1] = {
                    id = 'x', disattivata = true,
                    icona = c.licenza and '🚕' or '⚠',
                    titolo = ('%.1f km — %s'):format((c.metri or 0) / 1000, U.Euro(c.importo)),
                    descrizione = ('%s → %s\n%s · %d minuti fa')
                        :format(c.partenza or '—', c.arrivo or '—',
                                c.pagata == 1 and 'pagata' or 'NON PAGATA', c.minutiFa or 0),
                }
            end
            if #v == 0 then
                v[1] = { id = 'x', disattivata = true, icona = '🚕', titolo = 'Nessuna corsa' }
            end
            return exports.aurea_ui:Menu({ titolo = 'Registro delle corse',
                sottotitolo = 'Quello che hai fatto oggi', voci = v })
        end

        if scelta == 'mezzo' then
            local modello = GetHashKey(TAX.Rimessa.modello)
            RequestModel(modello)
            local scadenza = GetGameTimer() + 8000
            while not HasModelLoaded(modello) and GetGameTimer() < scadenza do Wait(50) end
            if not HasModelLoaded(modello) then
                return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚕',
                    titolo = 'Rimessa', testo = 'Nessun mezzo disponibile adesso.' })
            end

            local p = TAX.Rimessa.spawn
            local v = CreateVehicle(modello, p.x, p.y, p.z, p.w, true, false)
            SetVehicleNumberPlateText(v, 'TAXI' .. math.random(100, 999))
            SetModelAsNoLongerNeeded(modello)
            TaskWarpPedIntoVehicle(PlayerPedId(), v, -1)

            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🚕',
                titolo = 'Taxi in servizio',
                testo = 'Usa /cliente con il passeggero a bordo per avviare il tassametro.' })
        end
    end)
end

RegisterCommand('taxi', rimessa, false)
RegisterCommand('cliente', avvia, false)
RegisterCommand('tassametro', stato, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(TAX.Rimessa.coord)
    SetBlipSprite(b, TAX.Rimessa.blip.sprite)
    SetBlipColour(b, TAX.Rimessa.blip.colore)
    SetBlipScale(b, TAX.Rimessa.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Rimessa taxi')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('tax_rimessa', TAX.Rimessa.coord, TAX.Rimessa.raggio, {
        { etichetta = 'Rimessa taxi', icona = '🚕', azione = rimessa },
    })
end)
