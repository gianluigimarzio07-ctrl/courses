--[[
    AUREA · Poste (client)
]]

local U = AUREA.Util

CreateThread(function()
    for n, u in ipairs(POS.Uffici) do
        local b = AddBlipForCoord(u.coord.x, u.coord.y, u.coord.z)
        SetBlipSprite(b, POS.Blip.sprite)
        SetBlipColour(b, POS.Blip.colore)
        SetBlipScale(b, POS.Blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(u.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('poste_' .. n, u.coord, 2.5, {
            { etichetta = 'Sportello', icona = '📮', azione = function() sportello() end },
        })
    end
end)

function sportello()
    CreateThread(function()
        local dati, errore = AUREA.Callback.Attendi('pos:sportello')
        if not dati then
            return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Poste', testo = errore })
        end

        local voci = {
            { id = 'spedisci', icona = '✉', titolo = 'Spedisci',
              descrizione = 'Lettera, raccomandata A/R o pacco.' },
            { id = 'ritira', icona = '📦',
              titolo = ('Ritira la corrispondenza (%d)'):format(#dati.corrispondenza),
              descrizione = #dati.corrispondenza > 0 and 'Hai roba in giacenza.'
                  or 'Non hai nulla in giacenza.',
              disattivata = #dati.corrispondenza == 0 },
            { id = 'bollettini', icona = '🧾',
              titolo = ('Paga un bollettino (%d)'):format(#dati.tributi),
              descrizione = ('Commissione %s per bollettino.'):format(U.Euro(dati.commissione)),
              disattivata = #dati.tributi == 0 },
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Poste', sottotitolo = 'Sportello unico', voci = voci,
        })
        if not scelta then return end

        if scelta == 'spedisci' then return spedisci(dati.tariffe) end
        if scelta == 'ritira' then return ritira(dati.corrispondenza) end
        bollettini(dati.tributi, dati.commissione)
    end)
end

function spedisci(tariffe)
    CreateThread(function()
        local voci = {}
        for id, t in pairs(tariffe) do
            voci[#voci + 1] = {
                id = id, icona = id == 'pacco' and '📦' or (id == 'raccomandata' and '📋' or '✉'),
                titolo = t.nome,
                descrizione = t.ricevuta and 'Il mittente riceve l\'avviso di ricevimento.'
                    or (t.slot and 'Ci si mette dentro della roba.' or 'Arriva subito.'),
                valore = U.Euro(t.costo),
            }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Spedizione', sottotitolo = 'Serve il codice fiscale del destinatario', voci = voci,
        })
        if not tipo then return end

        local r = exports.aurea_ui:Dialogo('Destinatario e contenuto', {
            { etichetta = 'Codice fiscale del destinatario', tipo = 'text',
              segnaposto = 'RSSMRA80A01H501U', obbligatorio = true },
            { etichetta = 'Oggetto', tipo = 'text', segnaposto = 'Es. Diffida', obbligatorio = true },
            { etichetta = 'Testo', tipo = 'textarea', segnaposto = 'Quello che vuoi scrivere' },
        })
        if not r or not r[1] or not r[2] then return end

        local ok, esito = AUREA.Callback.Attendi('pos:spedisci', tipo, r[1], r[2], r[3] or '')
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📮', titolo = 'Spedizione', testo = tostring(esito), durata = 12000,
            })
        end

        -- Il pacco si riempie subito, prima che parta
        if type(esito) == 'table' and esito.contenitore then
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '📦', titolo = 'Pacco accettato',
                testo = 'Mettici dentro quello che vuoi spedire.', durata = 11000,
            })
            exports.aurea_inventory:Apri({
                tipo = 'esterno', id = esito.contenitore,
                tipoContenitore = 'pacco',
                capienza = esito.capienza, pesoMax = esito.pesoMax,
                etichettaSecondaria = 'Pacco in partenza',
            })
        else
            exports.aurea_ui:Notifica({
                tipo = 'successo', icona = '📮', titolo = 'Spedito',
                testo = tostring(esito), durata = 12000,
            })
        end
    end)
end

function ritira(elenco)
    CreateThread(function()
        local voci = {}
        for _, c in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(c.id),
                icona = c.tipo == 'pacco' and '📦' or (c.tipo == 'raccomandata' and '📋' or '✉'),
                titolo = c.oggetto ~= '' and c.oggetto or POS.Tariffe[c.tipo].nome,
                descrizione = ('Da %s'):format(c.mittente_nome),
                valore = c.quando,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Corrispondenza in giacenza',
            sottotitolo = 'Quello che non ritiri torna al mittente', voci = voci,
        })
        if not scelta then return end

        local c, errore = AUREA.Callback.Attendi('pos:ritira', tonumber(scelta))
        if not c then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '📮', titolo = 'Ritiro', testo = tostring(errore), durata = 10000,
            })
        end

        if c.contenitore then
            exports.aurea_inventory:Apri({
                tipo = 'esterno', id = c.contenitore,
                tipoContenitore = 'pacco',
                capienza = POS.Tariffe.pacco.slot, pesoMax = POS.Tariffe.pacco.peso,
                etichettaSecondaria = ('Pacco da %s'):format(c.mittente),
            })
            return
        end

        local righe = {
            { id = '_m', icona = '✍', titolo = ('Da %s'):format(c.mittente),
              descrizione = c.quando, disattivata = true },
        }
        for riga in tostring(c.testo or ''):gmatch('[^\n]+') do
            righe[#righe + 1] = { id = '_r' .. #righe, icona = '·', titolo = riga, disattivata = true }
        end
        if #righe == 1 then
            righe[2] = { id = '_v', icona = '·', titolo = '(nessun testo)', disattivata = true }
        end

        exports.aurea_ui:Menu({
            titolo = c.oggetto ~= '' and c.oggetto or POS.Tariffe[c.tipo].nome,
            sottotitolo = POS.Tariffe[c.tipo].nome, voci = righe,
        })
    end)
end

function bollettini(elenco, commissione)
    CreateThread(function()
        local voci = {}
        for _, t in ipairs(elenco) do
            voci[#voci + 1] = {
                id = tostring(t.id), icona = '🧾',
                titolo = ('%s — %s'):format(t.tipo:upper(), t.periodo or ''),
                descrizione = ('Scadenza %s'):format(t.entro),
                valore = U.Euro(tonumber(t.importo) + commissione),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Bollettini da pagare',
            sottotitolo = 'Quello che non paghi diventa cartella esattoriale', voci = voci,
        })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('pos:paga', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧾',
            titolo = 'Pagamento', testo = messaggio, durata = 13000,
        })
    end)
end

RegisterCommand('poste', function() sportello() end, false)
