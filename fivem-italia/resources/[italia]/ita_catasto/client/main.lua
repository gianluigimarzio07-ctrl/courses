--[[
    AUREA · Catasto (client)

    Uno sportello con tre sportellini: le pratiche da presentare, la
    visura, e basta. Tutto quello che decide qualcosa sta sul server.
]]

local function pratiche()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('cat:pratiche') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🗂',
                titolo = 'Catasto', testo = 'Non hai pratiche in sospeso.' })
        end

        local voci = {}
        for _, p in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(p.id),
                icona = p.tipo == 'accatastamento' and '🏢' or '🔁',
                titolo = ('%s — %s'):format(
                    p.tipo == 'accatastamento' and 'Accatastamento' or 'Voltura',
                    p.denominazione or '—'),
                descrizione = p.tipo == 'accatastamento'
                    and ('%s · rendita stimata %s · tributi %s%s'):format(
                        p.categoriaNome, AUREA.Util.Euro(p.rendita), AUREA.Util.Euro(p.tributi),
                        p.sanzionata == 1 and ' · TERMINE SCADUTO' or '')
                    or ('Tributi %s%s'):format(AUREA.Util.Euro(p.tributi),
                        p.sanzionata == 1 and ' · TERMINE SCADUTO' or ''),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Pratiche catastali',
            sottotitolo = 'Presentarle costa; non presentarle costa di più',
            voci = voci,
        })
        if not scelta then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Istruttoria della pratica',
                                            durata = CAT.Docfa.secondiIstruttoria * 1000,
                                            annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('cat:presenta', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🗂',
            titolo = 'Catasto', testo = tostring(messaggio), durata = 20000,
        })
    end)
end

local function visura()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Visura catastale', {
            { etichetta = 'Nome, indirizzo o codice dell\'immobile', tipo = 'text', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local righe, errore = AUREA.Callback.Attendi('cat:visura', r[1])
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🗂',
                titolo = 'Visura', testo = errore or 'Nessun risultato.', durata = 12000 })
        end

        local voci = {}
        for _, i in ipairs(righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = i.disallineata and '⚠' or '🏠',
                titolo = ('%s — %s'):format(i.nome, i.categoriaNome),
                descrizione = ('%s · rendita %s\nProprietario: %s\nIntestato al catasto: %s%s'):format(
                    i.indirizzo or '—', AUREA.Util.Euro(i.rendita_catastale or 0),
                    i.nome_proprietario or '—',
                    i.nome_intestatario or 'nessuno',
                    i.disallineata and '\nDISALLINEATO: le imposte le paga ancora l\'intestatario.' or ''),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🗂', titolo = 'Nessun immobile trovato' }
        end

        exports.aurea_ui:Menu({ titolo = 'Visura', sottotitolo = 'Dati catastali', voci = voci })
    end)
end

local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = CAT.Sportello.nome,
            sottotitolo = 'Accatastamenti, volture, visure',
            voci = {
                { id = 'pratiche', icona = '🗂', titolo = 'Le tue pratiche in sospeso',
                  descrizione = 'Un fabbricato nuovo non esiste finché non lo accatasti.' },
                { id = 'visura', icona = '🔎', titolo = 'Chiedi una visura',
                  descrizione = ('%s. È pubblica: di chi è una casa lo può sapere chiunque.')
                      :format(AUREA.Util.Euro(CAT.Visura.costo)) },
            },
        })
        if scelta == 'pratiche' then return pratiche() end
        if scelta == 'visura' then return visura() end
    end)
end

RegisterCommand('catasto', sportello, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(CAT.Sportello.coord)
    SetBlipSprite(b, CAT.Sportello.blip.sprite)
    SetBlipColour(b, CAT.Sportello.blip.colore)
    SetBlipScale(b, CAT.Sportello.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(CAT.Sportello.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('cat_sportello', CAT.Sportello.coord, CAT.Sportello.raggio, {
        { etichetta = 'Sportello catastale', icona = '🗂', azione = sportello },
    })
end)
