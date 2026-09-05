--[[
    AUREA · Concessionaria (client)
]]

local U = AUREA.Util
local inProva = nil     -- { veicolo, scadenza, centro, raggio }
local proposta = nil

-- ---------------------------------------------------------------------------
--  Blip e punti
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, s in ipairs(CON.Sedi) do
        local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
        SetBlipSprite(b, s.blip.sprite)
        SetBlipColour(b, s.blip.colore)
        SetBlipScale(b, s.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(s.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('conc_' .. s.id, s.coord, 2.5, {
            { etichetta = 'Listino e acquisto', icona = '🚗',
              azione = function() apriListino(s.id) end },
            { etichetta = 'Vendi un tuo veicolo', icona = '🤝',
              descrizione = 'Passaggio di proprietà fra privati.',
              azione = function() vendiUsato() end },
        })
    end
end)

-- ---------------------------------------------------------------------------
--  Listino
-- ---------------------------------------------------------------------------
function apriListino(idSede)
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('con:listino', idSede)
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Concessionaria', testo = errore })
        end

        -- Prima la categoria, poi il modello: un listino piatto di venti voci
        -- non si legge
        local categorie, viste = {}, {}
        for _, v in ipairs(dati.veicoli) do
            if not viste[v.categoria] then
                viste[v.categoria] = true
                local c = CON.Categorie[v.categoria]
                categorie[#categorie + 1] = { id = v.categoria, icona = c.icona, titolo = c.nome }
            end
        end

        local categoria = exports.aurea_ui:Menu({
            titolo = dati.sede,
            sottotitolo = ('Sul conto hai %s'):format(U.Euro(dati.saldo)),
            voci = categorie,
        })
        if not categoria then return end

        local voci = {}
        for _, v in ipairs(dati.veicoli) do
            if v.categoria == categoria then
                voci[#voci + 1] = {
                    id = v.modello, icona = CON.Categorie[v.categoria].icona,
                    titolo = v.nome,
                    descrizione = ('%d kW · listino %s + IVA %s + oneri %s')
                        :format(v.kw, U.Euro(v.prezzo), U.Euro(v.iva), U.Euro(v.oneri)),
                    valore = U.Euro(v.totale),
                }
            end
        end

        local modello = exports.aurea_ui:Menu({
            titolo = CON.Categorie[categoria].nome,
            sottotitolo = 'Il prezzo esposto comprende IVA, IPT, diritti e messa su strada',
            voci = voci,
        })
        if not modello then return end

        local azione = exports.aurea_ui:Menu({
            titolo = 'Cosa vuoi fare?',
            voci = {
                { id = 'prova', icona = '🔑', titolo = 'Prova su strada',
                  descrizione = ('%d secondi, cauzione %s restituita al rientro.')
                      :format(dati.prova.durata, U.Euro(dati.prova.cauzione)) },
                { id = 'compra', icona = '💶', titolo = 'Acquista',
                  descrizione = 'Si paga dal conto corrente.' },
            },
        })
        if not azione then return end

        if azione == 'prova' then return avviaProva(idSede, modello) end
        acquista(idSede, modello)
    end)
end

function acquista(idSede, modello)
    CreateThread(function()
        local ok, esito = AUREA.Callback.Attendi('con:acquista', idSede, modello)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🚗', titolo = 'Acquisto non concluso',
                testo = tostring(esito), durata = 13000,
            })
        end

        exports.aurea_ui:Notifica({
            tipo = 'successo', icona = '🚗', titolo = 'Immatricolata',
            testo = esito.messaggio, durata = 15000,
        })

        consegna(esito.modello, esito.consegna, esito.targa)
    end)
end

function consegna(modello, dove, targa)
    local hash = GetHashKey(modello)
    RequestModel(hash)
    local n = 0
    while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
    if not HasModelLoaded(hash) then return end

    local veicolo = CreateVehicle(hash, dove.x, dove.y, dove.z, dove.w, true, false)
    SetVehicleNumberPlateText(veicolo, targa)
    SetVehicleOnGroundProperly(veicolo)
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(PlayerPedId(), veicolo, -1)
end

-- ---------------------------------------------------------------------------
--  Prova su strada
-- ---------------------------------------------------------------------------
function avviaProva(idSede, modello)
    CreateThread(function()
        local ok, dati = AUREA.Callback.Attendi('con:prova', idSede, modello)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🔑', titolo = 'Prova non avviata',
                testo = tostring(dati), durata = 11000,
            })
        end

        local hash = GetHashKey(dati.modello)
        RequestModel(hash)
        local n = 0
        while not HasModelLoaded(hash) and n < 150 do Wait(20) n = n + 1 end
        if not HasModelLoaded(hash) then return end

        local veicolo = CreateVehicle(hash, dati.spawn.x, dati.spawn.y, dati.spawn.z, dati.spawn.w, true, false)
        SetVehicleNumberPlateText(veicolo, 'PROVA')
        SetModelAsNoLongerNeeded(hash)
        TaskWarpPedIntoVehicle(PlayerPedId(), veicolo, -1)

        inProva = {
            veicolo = veicolo,
            scadenza = GetGameTimer() + dati.durata * 1000,
            centro = vector3(dati.centro.x, dati.centro.y, dati.centro.z),
            raggio = dati.raggio,
        }

        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🔑', durata = 14000,
            titolo = 'Prova su strada',
            testo = ('Hai %d secondi e non devi allontanarti oltre %d metri. Se esci, la cauzione resta qui.')
                :format(dati.durata, math.floor(dati.raggio)),
        })
    end)
end

CreateThread(function()
    while true do
        local attesa = 800

        if inProva then
            attesa = 200
            local ped = PlayerPedId()
            local coord = GetEntityCoords(ped)
            local residuo = math.max(0, math.floor((inProva.scadenza - GetGameTimer()) / 1000))
            local distanza = #(coord - inProva.centro)

            AUREA.Testo3D(coord.x, coord.y, coord.z + 1.1,
                ('PROVA · %ds · %dm su %d'):format(residuo, math.floor(distanza), math.floor(inProva.raggio)), 0.36)

            if distanza > inProva.raggio then
                chiudiProva(true)
            elseif residuo <= 0 then
                chiudiProva(false)
            end
        end

        Wait(attesa)
    end
end)

function chiudiProva(fuoriZona)
    local sessione = inProva
    inProva = nil
    if not sessione then return end

    local danni = 0.0
    if DoesEntityExist(sessione.veicolo) then
        danni = 1.0 - (GetVehicleBodyHealth(sessione.veicolo) / 1000.0)
        local ped = PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == sessione.veicolo then
            TaskLeaveVehicle(ped, sessione.veicolo, 16)
            Wait(1500)
        end
        SetEntityAsMissionEntity(sessione.veicolo, true, true)
        DeleteVehicle(sessione.veicolo)
    end

    CreateThread(function()
        local _, messaggio = AUREA.Callback.Attendi('con:concludiProva', danni, fuoriZona == true)
        exports.aurea_ui:Notifica({
            tipo = fuoriZona and 'errore' or 'info', icona = '🔑',
            titolo = 'Prova conclusa', testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Usato fra privati
-- ---------------------------------------------------------------------------
function vendiUsato()
    CreateThread(function()
        local miei = AUREA.Callback.Attendi('con:mieiInVendita')
        if not miei or #miei == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🚗', titolo = 'Nessun veicolo',
                testo = 'Non hai mezzi intestati e trasferibili.',
            })
        end

        local voci = {}
        for _, v in ipairs(miei) do
            voci[#voci + 1] = {
                id = v.targa, icona = '🚗', titolo = ('%s — %s'):format(v.modello, v.targa),
                descrizione = ('%d km · usura motore %d%%'):format(v.km or 0, v.usura or 0),
            }
        end

        local targa = exports.aurea_ui:Menu({
            titolo = 'Quale vendi?', sottotitolo = 'Il passaggio di proprietà si fa qui, davanti a un impiegato',
            voci = voci,
        })
        if not targa then return end

        local acquirente = giocatoreVicino(CON.Usato.distanza)
        if not acquirente then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🤝', titolo = 'Nessun acquirente',
                testo = 'L\'altra parte deve essere accanto a te.',
            })
        end

        local risposta = exports.aurea_ui:Dialogo('Prezzo di vendita', {
            { etichetta = 'Prezzo in centesimi (es. 1500000 = 15.000,00 €)',
              tipo = 'number', valore = CON.Usato.prezzoMinimo, min = CON.Usato.prezzoMinimo,
              obbligatorio = true },
        })
        if not risposta or not risposta[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('con:proponiVendita', acquirente, targa, risposta[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'info' or 'errore', icona = '🤝',
            titolo = 'Proposta di vendita', testo = messaggio, durata = 12000,
        })
    end)
end

RegisterNetEvent('con:propostaRicevuta', function(dati)
    proposta = { scadenza = GetGameTimer() + 85000 }

    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = ('%s ti vende un veicolo'):format(dati.venditore),
            sottotitolo = ('%s targato %s'):format(dati.modello, dati.targa),
            voci = {
                { id = 'si', icona = '✅', titolo = ('Accetta — %s'):format(U.Euro(dati.prezzo + dati.oneri)),
                  descrizione = ('Prezzo %s + oneri di trascrizione %s. Si paga dal conto.')
                      :format(U.Euro(dati.prezzo), U.Euro(dati.oneri)) },
                { id = 'no', icona = '🚫', titolo = 'Rifiuta' },
            },
        })
        proposta = nil
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('con:rispondiVendita', scelta == 'si')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚗',
            titolo = 'Passaggio di proprietà', testo = messaggio, durata = 14000,
        })
    end)
end)

function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio

    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped then
            local d = #(coord - GetEntityCoords(altroPed))
            if d < distanza then migliore, distanza = GetPlayerServerId(altro), d end
        end
    end
    return migliore
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and inProva and DoesEntityExist(inProva.veicolo) then
        DeleteVehicle(inProva.veicolo)
    end
end)
