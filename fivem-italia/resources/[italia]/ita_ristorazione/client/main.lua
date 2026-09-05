--[[
    AUREA · Ristorazione (client)
]]

local U = AUREA.Util
local occupato = false

CreateThread(function()
    for _, l in ipairs(RIS.Locali) do
        local b = AddBlipForCoord(l.banco.x, l.banco.y, l.banco.z)
        SetBlipSprite(b, l.blip.sprite)
        SetBlipColour(b, l.blip.colore)
        SetBlipScale(b, l.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(l.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('ris_banco_' .. l.id, l.banco, 2.5, {
            { etichetta = 'Ordina', icona = '🍽', azione = function() menu(l.id) end },
            { etichetta = 'Comande in corso', icona = '📋',
              lavoro = l.lavoro, azione = function() comande() end },
        })

        exports.aurea_target:AggiungiZona('ris_cucina_' .. l.id, l.cucina, 2.5, {
            { etichetta = 'Cucina', icona = '👨‍🍳',
              lavoro = l.lavoro, inServizio = true,
              azione = function() comande() end },
        })
    end
end)

function menu(idLocale)
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('ris:menu', idLocale)
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Locale', testo = errore })
        end

        local voci = {}
        if dati.personale == 0 then
            voci[#voci + 1] = { id = '_p', icona = '🔒', titolo = 'Non c\'è nessuno in servizio',
                                descrizione = 'Senza personale non si può ordinare.', disattivata = true }
        end

        for _, p in ipairs(dati.piatti) do
            voci[#voci + 1] = {
                id = p.id, icona = p.icona, titolo = p.nome,
                valore = U.Euro(p.prezzo),
                disattivata = dati.personale == 0,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = dati.locale,
            sottotitolo = dati.personale > 0
                and ('%d in servizio · quello che ti preparano nutre di più'):format(dati.personale)
                or 'Chiuso: nessuno in servizio',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local ok, messaggio = AUREA.Callback.Attendi('ris:ordina', idLocale, scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🍽',
            titolo = 'Comanda', testo = messaggio, durata = 12000,
        })
    end)
end

function comande()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('ris:comande')
        if not elenco or #elenco == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '📋', titolo = 'Comande', testo = 'Nessuna comanda aperta.',
            })
        end

        local voci = {}
        for _, c in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(c.id), icona = c.pronta and '✅' or c.icona,
                titolo = ('%s — %s'):format(c.cliente, c.piatto),
                descrizione = c.pronta and 'Pronta: portala al cliente.' or 'Da preparare in cucina.',
                valore = ('%d min'):format(c.minuti),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Comande', sottotitolo = 'Un piatto freddo vale la metà', voci = voci,
        })
        if not scelta then return end

        local id = tonumber(scelta)
        local c
        for _, x in ipairs(elenco) do if x.id == id then c = x end end
        if not c then return end

        if c.pronta then return servi(id) end
        prepara(id)
    end)
end

function prepara(id)
    CreateThread(function()
        if occupato then return end

        local ok, dati = AUREA.Callback.Attendi('ris:prepara', id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '👨‍🍳', titolo = 'Cucina',
                testo = tostring(dati), durata = 11000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = ('Preparazione: %s'):format(dati.nome),
            durata = dati.durata, annullabile = true,
            anim = { dizionario = 'amb@prop_human_bbq@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local fatto, messaggio = AUREA.Callback.Attendi('ris:concludiPreparazione')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '👨‍🍳',
            titolo = 'Cucina', testo = messaggio, durata = 11000,
        })
    end)
end

function servi(id)
    CreateThread(function()
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Servizio al cliente...', durata = 4000, annullabile = true,
            anim = { dizionario = 'anim@heists@box_carry@', nome = 'idle' },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('ris:servi', id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🍽',
            titolo = 'Servizio', testo = messaggio, durata = 12000,
        })
    end)
end

RegisterCommand('comande', function() comande() end, false)
