--[[
    AUREA · Pesca professionale (client)

    Le zone di pesca sono cerchi in mare. Il pescato arriva dal server,
    che tiene le quote: quando una specie è finita, viene su meno roba, e
    non c'è modo di accorgersene se non pescando.
]]

local zonaCorrente = nil

-- ---------------------------------------------------------------------------
--  Dove sono
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 2500
        local coord = GetEntityCoords(PlayerPedId())
        local dentro = nil

        for _, z in ipairs(PES.Zone) do
            if #(vector2(coord.x, coord.y) - vector2(z.coord.x, z.coord.y)) <= z.raggio then
                dentro = z
            end
        end

        if dentro ~= zonaCorrente then
            zonaCorrente = dentro
            if dentro then
                exports.aurea_ui:Notifica({
                    tipo = 'info', icona = '🐟', durata = 9000,
                    titolo = dentro.nome,
                    testo = ('Resa ×%.1f. Cala la rete con /cala.'):format(dentro.moltiplicatore),
                })
            end
        end

        if dentro then attesa = 1200 end
        Wait(attesa)
    end
end)

RegisterCommand('cala', function()
    CreateThread(function()
        if not zonaCorrente then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🐟',
                titolo = 'Pesca', testo = 'Non sei sopra una zona di pesca.' })
        end

        if not exports.aurea_ui:Progresso({
            etichetta = ('Calata — %s'):format(zonaCorrente.nome),
            durata = zonaCorrente.minutiCalata * 60000 / 4,
            annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('pes:cala')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🐟',
            titolo = 'Rete salpata', testo = tostring(messaggio), durata = 16000,
        })
    end)
end, false)

RegisterCommand('rammenda', function()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({ etichetta = 'Rammendo della rete',
                                            durata = PES.Calata.secondiRammendo * 1000,
                                            annullabile = true }) then return end
        local ok, messaggio = AUREA.Callback.Attendi('pes:rammenda')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧵',
            titolo = 'Rete', testo = tostring(messaggio), durata = 10000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Mercato
-- ---------------------------------------------------------------------------
local function mercato(inNero)
    CreateThread(function()
        local listino, minuti = AUREA.Callback.Attendi('pes:listino')
        listino = listino or {}

        local voci = {}
        for _, s in ipairs(listino) do
            local frazione = s.quota > 0 and (s.consumata / s.quota) or 0
            voci[#voci + 1] = {
                id = s.id,
                icona = frazione >= 1 and '⛔' or (frazione >= 0.6 and '⚠' or '🐟'),
                titolo = ('%s — %s'):format(s.nome,
                    AUREA.Util.Euro(inNero and math.floor(s.prezzo * PES.Mercato.quotaNero) or s.prezzo)),
                descrizione = inNero
                    and ('Contanti, subito, e non risulta da nessuna parte.')
                    or ('Quota %d su %d%s'):format(s.consumata, s.quota,
                        s.prezzo < s.base and (' · prezzo giù dal listino di %s'):format(
                            AUREA.Util.Euro(s.base - s.prezzo)) or ''),
            }
        end

        if not inNero then
            voci[#voci + 1] = { id = 'licenza', icona = '📜',
                titolo = 'Rinnova la licenza di pesca',
                descrizione = ('%s · vale %d minuti')
                    :format(AUREA.Util.Euro(PES.Licenza.costo), PES.Licenza.validitaMinuti) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = inNero and 'Compratore' or PES.Porto.nome,
            sottotitolo = inNero and 'Paga meno, ma non chiede niente'
                or ('Asta del pescato · nuovo periodo fra %d minuti'):format(minuti or 0),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'licenza' then
            local ok, messaggio = AUREA.Callback.Attendi('pes:licenza')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📜',
                titolo = 'Capitaneria', testo = tostring(messaggio), durata = 16000 })
        end

        local ok, messaggio = AUREA.Callback.Attendi('pes:vendi', scelta, inNero or false)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🐟',
            titolo = inNero and 'Venduto' or 'Mercato ittico',
            testo = tostring(messaggio), durata = 20000,
        })
    end)
end

RegisterCommand('mercatoittico', function() mercato(false) end, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(PES.Porto.coord)
    SetBlipSprite(b, PES.Porto.blip.sprite)
    SetBlipColour(b, PES.Porto.blip.colore)
    SetBlipScale(b, PES.Porto.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(PES.Porto.nome)
    EndTextCommandSetBlipName(b)

    -- Le zone di pesca si vedono: sono banchi noti, non un segreto
    for _, z in ipairs(PES.Zone) do
        local zb = AddBlipForRadius(z.coord.x, z.coord.y, z.coord.z, z.raggio)
        SetBlipColour(zb, 3)
        SetBlipAlpha(zb, 70)
    end

    exports.aurea_target:AggiungiZona('pes_mercato', PES.Porto.coord, PES.Porto.raggio, {
        { etichetta = 'Mercato ittico', icona = '🐟', azione = function() mercato(false) end },
    })
    exports.aurea_target:AggiungiZona('pes_nero', PES.Mercato.ricettatore, 3.0, {
        { etichetta = 'Chiedi se compra', icona = '🤝', azione = function() mercato(true) end },
    })
end)
