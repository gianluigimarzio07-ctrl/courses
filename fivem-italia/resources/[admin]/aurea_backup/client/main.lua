--[[
    AUREA · Copie di sicurezza (client)

    Solo la parte visibile: l'elenco delle copie e la consultazione. Il
    lavoro vero è tutto dall'altra parte.
]]

local ultimoElenco = {}

local function consulta(file)
    local dati, motivo = AUREA.Callback.Attendi('bck:consulta', file)
    if motivo then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💾', testo = motivo, durata = 11000 })
    end

    local voci = {}
    for _, t in ipairs(dati.tabelle or {}) do
        voci[#voci + 1] = {
            id = t.nome,
            icona = t.errore and '⛔' or (t.troncata and '⚠' or '🗄'),
            titolo = t.nome,
            descrizione = t.errore and 'Non è stato possibile copiarla.'
                or ('%d righe%s'):format(t.righe, t.troncata and ' · troncata' or ''),
            disattivata = t.errore or t.righe == 0,
        }
    end

    local tabella = exports.aurea_ui:Menu({
        titolo = ('Copia del %s'):format(dati.momento or '?'),
        sottotitolo = ('Motivo: %s'):format(dati.motivo or 'n.d.'),
        voci = voci,
    })
    if not tabella then return end

    local risposte = exports.aurea_ui:Dialogo(('Cerca in %s'):format(tabella), {
        { etichetta = 'Codice fiscale, targa, nome o id', tipo = 'text', obbligatorio = true },
    })
    if not risposte then return end

    local esito, avviso = AUREA.Callback.Attendi('bck:consulta', file, tabella, tostring(risposte[1]))
    if avviso then
        exports.aurea_ui:Notifica({ tipo = 'avviso', icona = '🔎', testo = avviso, durata = 10000 })
    end
    if not esito then return end

    local elenco = {}
    for _, riga in ipairs(esito.righe or {}) do
        -- Si mostrano i campi in ordine alfabetico: non sappiamo in anticipo
        -- quali colonne ha la tabella, e mettere ordine aiuta a leggere
        local chiavi = {}
        for k in pairs(riga) do chiavi[#chiavi + 1] = k end
        table.sort(chiavi)

        local pezzi = {}
        for _, k in ipairs(chiavi) do
            local v = riga[k]
            if type(v) ~= 'table' then
                pezzi[#pezzi + 1] = ('%s=%s'):format(k, tostring(v):sub(1, 40))
            end
        end

        elenco[#elenco + 1] = {
            id = 'r', icona = '📄',
            titolo = tostring(riga.citizenid or riga.targa or riga.id or 'riga'),
            descrizione = table.concat(pezzi, '  ·  '),
            disattivata = true,
        }
    end

    if #elenco == 0 then
        elenco[1] = { id = 'x', icona = '🔎',
                      titolo = 'Nessun riscontro',
                      descrizione = ('%d righe esaminate in questa copia.'):format(esito.totale or 0),
                      disattivata = true }
    end

    exports.aurea_ui:Menu({
        titolo = ('%s — copia del %s'):format(tabella, esito.momento or '?'),
        sottotitolo = 'Solo lettura: il ripristino si fa a mano, guardando.',
        voci = elenco,
    })
end

RegisterNetEvent('bck:elenco', function(righe, prossimoSlot, cadenza)
    ultimoElenco = righe or {}

    local voci = {}
    for _, r in ipairs(ultimoElenco) do
        voci[#voci + 1] = {
            id = r.file,
            icona = r.problemi and '⚠' or '💾',
            titolo = ('%s — %s'):format(r.momento or 'n.d.', r.motivo or 'n.d.'),
            descrizione = ('%s · %d righe · %s%s')
                :format(r.file, r.righe or 0, r.autore or 'n.d.',
                        r.problemi and ('  ⚠ ' .. r.problemi) or ''),
        }
    end

    if #voci == 0 then
        voci[1] = { id = 'x', icona = '💾', titolo = 'Nessuna copia ancora scritta',
                    descrizione = ('La prima parte %d minuti dopo l\'avvio.'):format(cadenza.ritardoAvvioMinuti),
                    disattivata = true }
    end

    local scelta = exports.aurea_ui:Menu({
        titolo = 'Copie di sicurezza',
        sottotitolo = ('Una ogni %d minuti · se ne tengono %d · prossimo slot: %d')
            :format(cadenza.minuti, cadenza.quante, prossimoSlot),
        voci = voci,
    })
    if not scelta or scelta == 'x' then return end

    consulta(scelta)
end)
