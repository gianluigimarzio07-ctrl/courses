--[[
    AUREA · Economia (client) — bacheca del listino
]]

local U = AUREA.Util

CreateThread(function()
    local b = ECO.Bacheca
    local blip = AddBlipForCoord(b.coord.x, b.coord.y, b.coord.z)
    SetBlipSprite(blip, b.blip.sprite)
    SetBlipColour(blip, b.blip.colore)
    SetBlipScale(blip, b.blip.scala)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(b.nome)
    EndTextCommandSetBlipName(blip)
end)

CreateThread(function()
    while true do
        local attesa = 1000
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - ECO.Bacheca.coord) < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, ECO.Bacheca.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                TriggerEvent('eco:apriListino')
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('eco:apriListino', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('eco:listino')
        if not dati then return end

        local categorie = {}
        for _, b in ipairs(dati.beni) do
            categorie[b.categoria] = (categorie[b.categoria] or 0) + 1
        end

        local vociCategorie = {
            { id = '__tutti', icona = '📊', titolo = 'Tutti i beni',
              descrizione = ('%d voci a listino'):format(#dati.beni) },
        }
        for categoria, quanti in pairs(categorie) do
            vociCategorie[#vociCategorie + 1] = {
                id = categoria, icona = '📦',
                titolo = categoria:gsub('^%l', string.upper),
                descrizione = ('%d voci'):format(quanti),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ECO.Bacheca.nome,
            sottotitolo = ('Indice dei prezzi %.2f · aggiornamento ogni %d minuti'):format(dati.indice, dati.prossimoCiclo),
            voci = vociCategorie,
        })
        if not scelta then return end

        local voci = {}
        for _, b in ipairs(dati.beni) do
            if scelta == '__tutti' or b.categoria == scelta then
                local freccia = b.variazione > 1 and '▲' or (b.variazione < -1 and '▼' or '▬')
                voci[#voci + 1] = {
                    id = b.item,
                    icona = freccia,
                    titolo = b.etichetta,
                    descrizione = ('Riferimento %s · tensione sulla %s'):format(U.Euro(b.prezzoBase), b.tensione),
                    valore = ('%s  %s%.1f%%'):format(U.Euro(b.prezzo), b.variazione >= 0 and '+' or '', b.variazione),
                    disattivata = true,
                }
            end
        end

        if #voci == 0 then
            voci[1] = { id = 'v', icona = '—', titolo = 'Nessuna voce in questa categoria', disattivata = true }
        end

        exports.aurea_ui:Menu({
            titolo = 'Listino',
            sottotitolo = 'Il prezzo si muove solo per effetto degli scambi reali',
            voci = voci,
        })
    end)
end)
