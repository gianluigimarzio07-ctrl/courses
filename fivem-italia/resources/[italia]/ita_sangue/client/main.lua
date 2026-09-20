--[[
    AUREA · Donazione di sangue (client)

    Il centro trasfusionale: un lettino e un frigorifero. Al lettino si
    dona, al frigorifero il 118 ritira. La salute la muove il server con
    due eventi, perché anche la salute è una cosa che il client non deve
    decidere da sé.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Effetti sulla salute
-- ---------------------------------------------------------------------------
RegisterNetEvent('san:donato', function(quanta)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.max(101, GetEntityHealth(ped) - (tonumber(quanta) or 0)))
end)

RegisterNetEvent('san:trasfusione', function(delta, reazione)
    local ped = PlayerPedId()
    delta = tonumber(delta) or 0

    local massima = GetEntityMaxHealth(ped)
    local nuova = GetEntityHealth(ped) + delta
    SetEntityHealth(ped, math.max(101, math.min(massima, nuova)))

    if reazione then
        -- Una reazione emolitica non è una pacca sulla spalla: si vede
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.4)
        SetFlash(0, 0, 100, 500, 100)
    end
end)

-- ---------------------------------------------------------------------------
--  Il lettino
-- ---------------------------------------------------------------------------
local function centro()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('san:posizione')
        if not s then return end

        local voci = {
            { id = 'x', disattivata = true, icona = '🩸',
              titolo = ('Il tuo gruppo: %s'):format(s.gruppo),
              descrizione = ('Puoi ricevere da: %s\nDonazioni effettuate: %d')
                  :format(table.concat(SAN.Compatibile[s.gruppo] or {}, ', '), s.donazioni) },
        }

        if not s.idoneo then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '⛔',
                titolo = 'Non idoneo', descrizione = s.motivo or 'Sospensione in corso.' }
        elseif s.minutiAttesa > 0 then
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '⏳',
                titolo = 'Troppo presto',
                descrizione = ('Devono passare ancora %d minuti.'):format(s.minutiAttesa) }
        else
            voci[#voci + 1] = { id = 'dona', icona = '🩸', titolo = 'Dona il sangue',
                descrizione = ('Una sacca. Rimborso %s e un panino. Ci vogliono %d secondi e ti stanca.')
                    :format(U.Euro(SAN.Donazione.ristoro), SAN.Donazione.durataSecondi) }
        end

        for _, sc in ipairs(s.scorte) do
            voci[#voci + 1] = {
                id = s.sanitario and ('ritira:' .. sc.gruppo) or 'x',
                disattivata = not s.sanitario or sc.sacche <= 0,
                icona = sc.carenza and '⚠' or '✅',
                titolo = ('Gruppo %s — %d sacche'):format(sc.gruppo, sc.sacche),
                descrizione = s.sanitario
                    and ('Ritira una sacca: %s'):format(U.Euro(s.costoSacca))
                    or (sc.carenza and 'In esaurimento.' or 'Scorte sufficienti.'),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = SAN.Centro.nome,
            sottotitolo = 'Il sangue non si compra: si dona',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if scelta == 'dona' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Prelievo',
                durata = SAN.Donazione.durataSecondi * 1000, annullabile = true }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('san:dona')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🩸',
                titolo = 'Donazione', testo = tostring(messaggio), durata = 18000 })
        end

        local gruppo = scelta:match('^ritira:(.+)$')
        if gruppo then
            local ok, messaggio = AUREA.Callback.Attendi('san:ritira', gruppo)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🧊',
                titolo = 'Ritiro sacche', testo = tostring(messaggio), durata = 14000 })
        end
    end)
end

RegisterCommand('avis', centro, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SAN.Centro.coord)
    SetBlipSprite(b, SAN.Centro.blip.sprite)
    SetBlipColour(b, SAN.Centro.blip.colore)
    SetBlipScale(b, SAN.Centro.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Centro trasfusionale')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('san_centro', SAN.Centro.coord, SAN.Centro.raggio, {
        { etichetta = 'Centro trasfusionale', icona = '🩸', azione = centro },
    })
end)
