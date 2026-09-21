--[[
    AUREA · Tabaccheria (client)

    Un banco con quattro cose sopra. La quarta — la marca da bollo — è
    quella che nessuno compra per scelta.
]]

local U = AUREA.Util

local function giocaLotto(s)
    CreateThread(function()
        local vociRuota = {}
        for _, r in ipairs(s.ruote) do
            vociRuota[#vociRuota + 1] = { id = r, icona = '🎰', titolo = r,
                descrizione = 'Cinque numeri per ruota, ogni estrazione.' }
        end

        local ruota = exports.aurea_ui:Menu({
            titolo = 'Su quale ruota', sottotitolo = 'Le ruote sono dieci, e sono quelle',
            voci = vociRuota })
        if not ruota then return end

        local vociSorte = {}
        for id, so in pairs(s.sorti) do
            vociSorte[#vociSorte + 1] = {
                id = id, icona = '🔢', titolo = so.nome,
                descrizione = ('%d numer%s · quota %.2f volte la giocata')
                    :format(so.numeri, so.numeri == 1 and 'o' or 'i', so.quota),
                ordine = so.numeri,
            }
        end
        table.sort(vociSorte, function(a, b) return a.ordine < b.ordine end)

        local sorte = exports.aurea_ui:Menu({
            titolo = 'Che sorte', sottotitolo = 'Più numeri, più paga, meno esce',
            voci = vociSorte })
        if not sorte then return end

        local r = exports.aurea_ui:Dialogo(('Giocata — %s su %s'):format(sorte, ruota), {
            { etichetta = 'I numeri, separati da spazio (1-90)', tipo = 'text', obbligatorio = true },
            { etichetta = 'Importo in centesimi', tipo = 'number', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('tab:gioca', ruota, sorte, r[1], tonumber(r[2]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎰',
            titolo = 'Lotto', testo = tostring(messaggio), durata = 20000 })
    end)
end

local function banco()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('tab:banco')
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🚬',
                titolo = 'Tabaccheria', testo = 'Non sei davanti a un banco.' })
        end

        local voci = {}

        for _, b in ipairs(s.banco) do
            voci[#voci + 1] = {
                id = 'item:' .. b.item, icona = '🛒',
                titolo = b.nome, descrizione = U.Euro(b.prezzo),
            }
        end

        for _, b in ipairs(s.bolli) do
            voci[#voci + 1] = {
                id = 'bollo:' .. tostring(b.valore), icona = '🧾',
                titolo = b.nome,
                descrizione = 'Serve per le pratiche. Non si compra altrove.',
            }
        end

        if #s.mieiBolli > 0 then
            local elenco = {}
            for _, b in ipairs(s.mieiBolli) do
                elenco[#elenco + 1] = ('%s — %s'):format(b.codice, U.Euro(b.valore))
            end
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📄',
                titolo = ('Valori bollati che hai (%d)'):format(#s.mieiBolli),
                descrizione = table.concat(elenco, '\n'),
            }
        end

        voci[#voci + 1] = {
            id = 'lotto', icona = '🎰', titolo = 'Gioca al Lotto',
            descrizione = ('Estrazione ogni %d minuti su tutte le ruote.\n%s')
                :format(s.minuti,
                    s.ultima and ('Ultima: %s — %s'):format(s.ultima.ruota, s.ultima.numeri)
                             or 'Nessuna estrazione ancora.'),
        }

        voci[#voci + 1] = { id = 'estrazioni', icona = '📋', titolo = 'Ultime estrazioni',
            descrizione = 'Tutte le ruote.' }

        for _, gi in ipairs(s.giocate) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = gi.stato == 'vinta' and '🏆' or (gi.stato == 'aperta' and '⏳' or '❌'),
                titolo = ('%s su %s — %s'):format(
                    (s.sorti[gi.sorte] or {}).nome or gi.sorte, gi.ruota, gi.numeri),
                descrizione = ('Giocati %s · %s'):format(U.Euro(gi.importo),
                    gi.stato == 'vinta' and ('VINTA: %s'):format(U.Euro(gi.vincita))
                        or (gi.stato == 'aperta' and 'in attesa dell\'estrazione' or 'non vincente')),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.rivendita.nome,
            sottotitolo = 'Monopolio di Stato',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if scelta == 'lotto' then return giocaLotto(s) end

        if scelta == 'estrazioni' then
            local righe = AUREA.Callback.Attendi('tab:estrazioni') or {}
            local v = {}
            for _, e in ipairs(righe) do
                v[#v + 1] = { id = 'x', disattivata = true, icona = '🎰',
                    titolo = e.ruota,
                    descrizione = ('%s · %d minuti fa'):format(e.numeri, e.minutiFa or 0) }
            end
            if #v == 0 then
                v[1] = { id = 'x', disattivata = true, icona = '🎰',
                         titolo = 'Nessuna estrazione ancora' }
            end
            return exports.aurea_ui:Menu({ titolo = 'Ultime estrazioni',
                sottotitolo = 'Cinque numeri per ruota', voci = v })
        end

        local item = scelta:match('^item:(.+)$')
        if item then
            local r = exports.aurea_ui:Dialogo('Quanti', {
                { etichetta = 'Quantità (1-10)', tipo = 'number', obbligatorio = true },
            })
            if not r or not r[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('tab:compra', item, tonumber(r[1]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🚬',
                titolo = 'Tabaccheria', testo = tostring(messaggio), durata = 12000 })
        end

        local valore = scelta:match('^bollo:(%d+)$')
        if valore then
            local ok, messaggio = AUREA.Callback.Attendi('tab:bollo', tonumber(valore))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🧾',
                titolo = 'Valori bollati', testo = tostring(messaggio), durata = 18000 })
        end
    end)
end

RegisterCommand('tabaccheria', banco, false)

AddEventHandler('aurea:client:caricato', function()
    for _, r in ipairs(TAB.Rivendite) do
        local b = AddBlipForCoord(r.coord)
        SetBlipSprite(b, r.blip.sprite)
        SetBlipColour(b, r.blip.colore)
        SetBlipScale(b, 0.6)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Tabaccheria')
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('tab_' .. r.codice, r.coord, TAB.raggio, {
            { etichetta = 'Banco della tabaccheria', icona = '🚬', azione = banco },
        })
    end
end)
