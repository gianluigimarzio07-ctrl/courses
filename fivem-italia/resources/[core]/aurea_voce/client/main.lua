--[[
    AUREA · Voce (client)
]]

local U = AUREA.Util
local portata = VOC.Predefinita
local inRadio = false

RegisterKeyMapping('voce', 'Cambia portata della voce', 'keyboard', VOC.Tasti.cambia)

RegisterCommand('voce', function()
    local prossima = VOC.Prossima(portata)
    portata = prossima.id
    TriggerServerEvent('voc:portata', portata)

    exports.aurea_ui:Notifica({
        tipo = 'info', icona = prossima.icona, durata = 3500,
        titolo = prossima.nome, testo = ('Ti si sente entro %d metri.'):format(prossima.metri),
    })
end, false)

RegisterNetEvent('voc:portataConfermata', function(id, metri)
    portata = id
    local p = VOC.GetPortata(id)
    TriggerEvent('aurea:hud:voce', {
        portata = id, metri = metri, nome = p.nome, icona = p.icona,
    })
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(3000)
        TriggerServerEvent('voc:portata', portata)
    end)
end)

-- ---------------------------------------------------------------------------
--  Radio
-- ---------------------------------------------------------------------------
RegisterCommand('radio', function(_, args)
    CreateThread(function()
        -- Con un argomento si sintonizza direttamente
        if args[1] then
            local f = tonumber((args[1]:gsub(',', '.')))
            if not f then
                return exports.aurea_ui:Notifica({
                    tipo = 'errore', icona = '📻', titolo = 'Radio',
                    testo = 'Uso: /radio 21.5 — oppure /radio senza numero per l\'elenco.',
                })
            end
            local ok, messaggio = AUREA.Callback.Attendi('voc:sintonizza', f)
            inRadio = ok and f > 0
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📻',
                titolo = 'Radio', testo = messaggio, durata = 10000,
            })
        end

        local dati = AUREA.Callback.Attendi('voc:frequenze')
        if not dati then return end

        if not dati.haRadio then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📻', titolo = 'Nessuna radio',
                testo = 'Ti serve una ricetrasmittente addosso.',
            })
        end

        local voci = {
            { id = '_a', icona = '📻',
              titolo = dati.attuale and ('Sei sulla %0.1f'):format(dati.attuale) or 'Radio spenta',
              descrizione = ('Le frequenze libere vanno dalla %0.1f alla %0.1f.')
                  :format(dati.liberaDa, dati.liberaA),
              disattivata = true },
            { id = 'libera', icona = '🔓', titolo = 'Sintonizza una frequenza libera' },
        }

        for _, f in ipairs(dati.riservate) do
            voci[#voci + 1] = {
                id = tostring(f.frequenza),
                icona = f.ammessa and '🔑' or '🔒',
                titolo = ('%0.1f — %s'):format(f.frequenza, f.nome),
                descrizione = f.ammessa and 'Puoi entrarci.' or 'Riservata: non è la tua.',
                disattivata = not f.ammessa,
            }
        end

        if dati.attuale then
            voci[#voci + 1] = { id = 'spegni', icona = '⏹', titolo = 'Spegni la radio' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Radio ricetrasmittente',
            sottotitolo = ('Si parla tenendo premuto %s'):format(VOC.Tasti.radio),
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local frequenza = 0
        if scelta == 'libera' then
            local r = exports.aurea_ui:Dialogo('Frequenza', {
                { etichetta = ('Da %0.1f a %0.1f'):format(dati.liberaDa, dati.liberaA),
                  tipo = 'text', segnaposto = 'Es. 21.5', obbligatorio = true },
            })
            if not r or not r[1] then return end
            frequenza = tonumber((tostring(r[1]):gsub(',', '.'))) or 0
        elseif scelta ~= 'spegni' then
            frequenza = tonumber(scelta) or 0
        end

        local ok, messaggio = AUREA.Callback.Attendi('voc:sintonizza', frequenza)
        inRadio = ok and frequenza > 0

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📻',
            titolo = 'Radio', testo = messaggio, durata = 11000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Chi sta parlando
-- ---------------------------------------------------------------------------
CreateThread(function()
    if not VOC.Regole.mostraChiParla then return end

    while true do
        local attesa = 400
        local ped = PlayerPedId()
        local coord = GetEntityCoords(ped)

        for _, altro in ipairs(GetActivePlayers()) do
            local altroPed = GetPlayerPed(altro)
            if altroPed ~= ped and NetworkIsPlayerTalking(altro) then
                local pos = GetEntityCoords(altroPed)
                if #(coord - pos) < VOC.Regole.distanzaIndicatore then
                    attesa = 0
                    DrawMarker(27, pos.x, pos.y, pos.z + 1.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.22, 0.22, 0.22, 200, 165, 90, 140, false, false, 2, nil, nil, false)
                end
            end
        end

        Wait(attesa)
    end
end)

--- Chi è incosciente non parla.
CreateThread(function()
    if not VOC.Regole.zittisciIncoscienti then return end

    local zittito = false
    while true do
        Wait(1200)
        local salute = GetEntityHealth(PlayerPedId())
        local giu = salute > 0 and salute <= 105

        if giu ~= zittito then
            zittito = giu
            NetworkSetTalkerProximity(giu and 0.0 or VOC.GetPortata(portata).metri)
        end
    end
end)

exports('Portata', function() return portata, VOC.GetPortata(portata).metri end)
exports('InRadio', function() return inRadio end)
