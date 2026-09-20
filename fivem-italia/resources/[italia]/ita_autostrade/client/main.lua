--[[
    AUREA · Autostrade (client)

    Un casello ha tre pulsanti: entra, esci, forza. Il terzo esiste perché
    doveva esistere: se la sbarra non si potesse forzare, il pedaggio non
    sarebbe una scelta.
]]

local U = AUREA.Util

local function targaDelMezzo()
    local ped = PlayerPedId()
    local v = GetVehiclePedIsIn(ped, false)
    if v == 0 then return nil end
    return (GetVehicleNumberPlateText(v) or ''):gsub('%s+$', '')
end

local function casello(c)
    CreateThread(function()
        local targa = targaDelMezzo()
        if not targa then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🛣',
                titolo = c.nome, testo = 'Al casello ci si arriva in macchina.' })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = c.nome,
            sottotitolo = ('Km %d della rete · targa %s'):format(c.km, targa),
            voci = {
                { id = 'entra', icona = '🎟', titolo = 'Ritira il biglietto ed entra',
                  descrizione = 'Il pedaggio si paga all\'uscita, sulla distanza.' },
                { id = 'esce', icona = '💶', titolo = 'Consegna il biglietto ed esci',
                  descrizione = 'Con il Telepass l\'addebito è automatico.' },
                { id = 'forza', icona = '💥', titolo = 'Passa senza pagare',
                  descrizione = 'Art. 176 CdS. La sbarra si rompe, il pedaggio resta dovuto.' },
            },
        })
        if not scelta then return end

        if scelta == 'entra' then
            local ok, messaggio = AUREA.Callback.Attendi('aut:entra', c.id, targa, nil)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🎟',
                titolo = c.nome, testo = tostring(messaggio), durata = 14000 })
        end

        if scelta == 'esce' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Esazione',
                durata = 4000, annullabile = false }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('aut:esce', c.id, targa)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💶',
                titolo = c.nome, testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'forza' then
            local ok, messaggio = AUREA.Callback.Attendi('aut:forza', c.id, targa)
            if ok then
                local v = GetVehiclePedIsIn(PlayerPedId(), false)
                if v ~= 0 then SetVehicleBodyHealth(v, math.max(200.0, GetVehicleBodyHealth(v) - 120.0)) end
            end
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '💥',
                titolo = c.nome, testo = tostring(messaggio) or 'Passato.', durata = 18000 })
        end
    end)
end

local function telepass()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('aut:telepass')
        if not s then return end

        local voci = {}
        for _, a in ipairs(s.apparati) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = a.attivo == 1 and '✅' or '⛔',
                titolo = ('%s — %s'):format(a.targa, a.codice),
                descrizione = a.attivo == 1
                    and (a.insoluto > 0 and ('Attivo · insoluto %s'):format(U.Euro(a.insoluto))
                                         or 'Attivo e in regola')
                    or ('Disattivato per insoluto di %s'):format(U.Euro(a.insoluto)),
            }
        end

        for _, v in ipairs(s.veicoli) do
            voci[#voci + 1] = {
                id = v.targa, icona = '➕',
                titolo = ('Attiva su %s'):format(v.targa),
                descrizione = ('%s · %s di canone, sconto %d%% sul pedaggio')
                    :format(v.modello, U.Euro(s.canone), math.floor(s.sconto * 100)),
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🛣',
                        titolo = 'Nessun veicolo intestato a te' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Telepass', sottotitolo = 'Si passa e si paga dopo', voci = voci })
        if not scelta or scelta == 'x' then return end

        local ok, messaggio = AUREA.Callback.Attendi('aut:attivaTelepass', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🛣',
            titolo = 'Telepass', testo = tostring(messaggio), durata = 16000 })
    end)
end

local function tratta()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('aut:tratta')
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🛣',
                titolo = 'Concessionaria', testo = 'Riservato al personale in servizio.' })
        end

        exports.aurea_ui:Menu({
            titolo = 'Stato della tratta',
            sottotitolo = 'Quello che è dentro e quello che manca',
            voci = {
                { id = 'x', disattivata = true, icona = '🚗', titolo = 'Transiti aperti',
                  descrizione = tostring(s.aperti) },
                { id = 'x', disattivata = true, icona = '⚠', titolo = 'Insoluti',
                  descrizione = ('%d transiti · %s'):format(s.insolutiQuanti, U.Euro(s.insolutiTotale)) },
                { id = 'x', disattivata = true, icona = '💶', titolo = 'Incassato',
                  descrizione = U.Euro(s.incassato) },
            },
        })
    end)
end

RegisterCommand('telepass', telepass, false)
RegisterCommand('tratta', tratta, false)

AddEventHandler('aurea:client:caricato', function()
    for _, c in ipairs(AUT.Caselli) do
        local b = AddBlipForCoord(c.coord)
        SetBlipSprite(b, c.blip.sprite)
        SetBlipColour(b, c.blip.colore)
        SetBlipScale(b, 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(c.nome)
        EndTextCommandSetBlipName(b)

        local casellino = c
        exports.aurea_target:AggiungiZona('aut_' .. c.id, c.coord, 4.0, {
            { etichetta = 'Casello', icona = '🛣', azione = function() casello(casellino) end },
            { etichetta = 'Stato della tratta', icona = '📊',
              lavoro = AUT.Lavoro, inServizio = true, azione = tratta },
        })
    end
end)
