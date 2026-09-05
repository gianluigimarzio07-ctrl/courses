--[[
    AUREA · Onoranze funebri (client)
]]

local U = AUREA.Util
local lapidi = {}

CreateThread(function()
    for _, p in ipairs({ FUN.Impresa, FUN.Cimitero }) do
        local b = AddBlipForCoord(p.coord.x, p.coord.y, p.coord.z)
        SetBlipSprite(b, p.blip.sprite)
        SetBlipColour(b, p.blip.colore)
        SetBlipScale(b, p.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(p.nome)
        EndTextCommandSetBlipName(b)
    end

    exports.aurea_target:AggiungiZona('onoranze', FUN.Impresa.coord, 3.0, {
        { etichetta = 'Onoranze funebri', icona = '⚰', azione = function() sportello() end },
    })

    exports.aurea_target:AggiungiZona('cimitero', FUN.Cimitero.celebrazione, 8.0, {
        { etichetta = 'Celebra un funerale', icona = '⚰',
          lavoro = FUN.Lavoro, azione = function() celebra() end },
        { etichetta = 'Consulta le lapidi', icona = '🪦',
          azione = function() consulta() end },
    })
end)

function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = FUN.Impresa.nome,
            sottotitolo = 'Qui si chiude una storia, non si perde una partita',
            voci = {
                { id = 'richiedi', icona = '⚰', titolo = 'Deposita la richiesta di sepoltura',
                  descrizione = 'Per chiudere definitivamente il personaggio. È irreversibile.' },
                { id = 'lapidi', icona = '🪦', titolo = 'Chi riposa al cimitero' },
            },
        })
        if not scelta then return end

        if scelta == 'lapidi' then return consulta() end

        -- Doppia conferma, perché non si torna indietro
        local prima = exports.aurea_ui:Menu({
            titolo = 'Sei sicuro?',
            sottotitolo = 'Il personaggio non tornerà. I beni passano agli eredi e allo Stato.',
            voci = {
                { id = 'si', icona = '⚠', titolo = 'Sì, voglio chiudere questa storia' },
                { id = 'no', icona = '↩', titolo = 'No, ci ripenso' },
            },
        })
        if prima ~= 'si' then return end

        local seconda = exports.aurea_ui:Menu({
            titolo = 'Te lo chiedo un\'ultima volta',
            sottotitolo = 'Non c\'è modo di annullarlo dopo la cerimonia',
            voci = {
                { id = 'no', icona = '↩', titolo = 'Lascia perdere' },
                { id = 'si', icona = '⚰', titolo = 'Procedi' },
            },
        })
        if seconda ~= 'si' then return end

        local r = exports.aurea_ui:Dialogo('Ultime volontà', {
            { etichetta = 'Epitaffio, sulla lapide', tipo = 'text',
              segnaposto = 'Poche parole che restano' },
            { etichetta = 'Codice fiscale dell\'erede (facoltativo)', tipo = 'text',
              segnaposto = 'Chi riceve metà del patrimonio' },
        })
        if not r then return end

        local ok, messaggio = AUREA.Callback.Attendi('fun:richiedi', r[1] or '', r[2] or '')
        exports.aurea_ui:Notifica({
            tipo = ok and 'info' or 'errore', icona = '⚰',
            titolo = 'Onoranze funebri', testo = messaggio, durata = 18000,
        })
    end)
end

function celebra()
    CreateThread(function()
        local elenco = AUREA.Callback.Attendi('fun:pendenti')
        if not elenco or #elenco == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚰', titolo = 'Nessun funerale',
                testo = 'Non ci sono richieste in attesa.',
            })
        end

        local voci = {}
        for _, f in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(f.id), icona = f.inLinea and '⚰' or '🔒',
                titolo = f.nome,
                descrizione = ('%s%s'):format(
                    f.epitaffio ~= '' and ('"%s" · '):format(f.epitaffio) or '',
                    f.erede and ('erede: %s'):format(f.erede) or 'nessun erede designato'),
                valore = f.inLinea and 'presente' or 'assente',
                disattivata = not f.inLinea,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Funerali da celebrare',
            sottotitolo = 'Chi è presente alla cerimonia resta scritto sulla lapide',
            voci = voci,
        })
        if not scelta then return end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Cerimonia funebre...', durata = FUN.Regole.durataCerimonia,
            annullabile = true, blocca = { movimento = true },
        })
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('fun:celebra', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚰',
            titolo = 'Cerimonia', testo = messaggio, durata = 16000,
        })
        consulta()
    end)
end

function consulta()
    CreateThread(function()
        lapidi = AUREA.Callback.Attendi('fun:lapidi') or {}

        if #lapidi == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🪦', titolo = 'Cimitero',
                testo = 'Non c\'è ancora nessuno qui.',
            })
        end

        local voci = {}
        for _, l in ipairs(lapidi) do
            voci[#voci + 1] = {
                id = tostring(l.id), icona = '🪦', titolo = l.nome,
                descrizione = l.epitaffio ~= '' and l.epitaffio or 'Nessun epitaffio.',
                valore = l.quando,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = FUN.Cimitero.nome,
            sottotitolo = ('%d lapidi'):format(#lapidi), voci = voci,
        })
        if not scelta then return end

        local l
        for _, x in ipairs(lapidi) do if tostring(x.id) == scelta then l = x end end
        if not l then return end

        exports.aurea_ui:Menu({
            titolo = l.nome,
            sottotitolo = l.epitaffio ~= '' and l.epitaffio or l.quando,
            voci = {
                { id = '_d', icona = '📅', titolo = ('Sepolto il %s'):format(l.quando),
                  disattivata = true },
                { id = '_p', icona = '👥', titolo = 'Presenti alla cerimonia',
                  descrizione = l.presenti ~= '' and l.presenti or 'Nessuno.',
                  disattivata = true },
            },
        })
    end)
end

--- Le lapidi si vedono, camminando in mezzo al cimitero.
CreateThread(function()
    while true do
        local attesa = 2000
        local coord = GetEntityCoords(PlayerPedId())

        if #(coord - FUN.Cimitero.coord) < 60.0 then
            attesa = 0
            for _, l in ipairs(lapidi) do
                local pos = vector3(l.coord.x, l.coord.y, l.coord.z)
                if #(coord - pos) < 12.0 then
                    AUREA.Testo3D(pos.x, pos.y, pos.z + 1.0, l.nome, 0.34)
                end
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('fun:sepolto', function()
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '⚰', durata = 25000,
        titolo = 'Fine',
        testo = 'La storia di questo personaggio finisce qui. Grazie di averla raccontata.',
    })
end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(8000)
        lapidi = AUREA.Callback.Attendi('fun:lapidi') or {}
    end)
end)
