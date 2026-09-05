--[[
    AUREA · Casinò (client)
]]

local U = AUREA.Util

CreateThread(function()
    local s = CAS.Sede
    local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
    SetBlipSprite(b, s.blip.sprite)
    SetBlipColour(b, s.blip.colore)
    SetBlipScale(b, s.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(s.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('casino_cassa', s.cassa, 2.5, {
        { etichetta = 'Cassa — cambia le fiches', icona = '🪙',
          azione = function() cassa() end },
    })

    for id, t in pairs(CAS.Tavoli) do
        for n, c in ipairs(t.coord) do
            exports.aurea_target:AggiungiZona(('casino_%s_%d'):format(id, n), c, 2.0, {
                { etichetta = t.nome, icona = t.icona,
                  azione = function() apriTavolo(id) end },
            })
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Cassa
-- ---------------------------------------------------------------------------
function cassa()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('cas:cassa')
        if not dati then return end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Cassa del casinò',
            sottotitolo = ('Hai %d fiches · una fiche vale %s · commissione %d%%')
                :format(dati.fiches, U.Euro(dati.valore), math.floor(dati.commissione * 100)),
            voci = {
                { id = 'compra', icona = '🪙', titolo = 'Compra fiches' },
                { id = 'vendi', icona = '💶', titolo = 'Cambia le fiches in denaro',
                  descrizione = 'Sulle vincite si paga il 20% di imposta.' },
                { id = '_b', icona = '📊',
                  titolo = ('Bilancio di oggi: %s'):format(U.Euro(dati.netto)),
                  descrizione = ('Il banco chiude i tavoli oltre %s di vincite.')
                      :format(U.Euro(dati.tetto)),
                  disattivata = true },
            },
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local r = exports.aurea_ui:Dialogo(scelta == 'compra' and 'Quante fiches?' or 'Quante ne cambi?', {
            { etichetta = 'Numero di fiches', tipo = 'number', valore = 10, min = 1, max = 500,
              obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('cas:cambia', scelta, r[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🪙',
            titolo = 'Cassa', testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Tavoli
-- ---------------------------------------------------------------------------
function apriTavolo(id)
    if id == 'roulette' then return roulette() end
    if id == 'slot' then return slot() end
    if id == 'blackjack' then return blackjack() end
end

function chiediPuntata(t)
    local r = exports.aurea_ui:Dialogo('Puntata', {
        { etichetta = ('Fiches (da %d a %d)'):format(t.puntataMinima, t.puntataMassima),
          tipo = 'number', valore = t.puntataMinima,
          min = t.puntataMinima, max = t.puntataMassima, obbligatorio = true },
    })
    return r and r[1] or nil
end

function roulette()
    CreateThread(function()
        local t = CAS.Tavoli.roulette

        local voci = {}
        for _, s in ipairs(t.scommesse) do
            voci[#voci + 1] = {
                id = s.id, icona = '🎡', titolo = s.nome,
                valore = ('paga %d a 1'):format(s.quota),
            }
        end

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Roulette',
            sottotitolo = 'Ruota europea: un solo zero, e lo zero è del banco',
            voci = voci,
        })
        if not tipo then return end

        local numero = nil
        if tipo == 'pieno' then
            local r = exports.aurea_ui:Dialogo('Su che numero?', {
                { etichetta = 'Numero (0-36)', tipo = 'number', valore = 7, min = 0, max = 36,
                  obbligatorio = true },
            })
            if not r then return end
            numero = r[1]
        elseif tipo == 'dozzina' then
            local r = exports.aurea_ui:Dialogo('Quale dozzina?', {
                { etichetta = 'Dozzina (1 = 1-12, 2 = 13-24, 3 = 25-36)',
                  tipo = 'number', valore = 1, min = 1, max = 3, obbligatorio = true },
            })
            if not r then return end
            numero = r[1]
        end

        local puntata = chiediPuntata(t)
        if not puntata then return end

        local esito, errore = AUREA.Callback.Attendi('cas:roulette', tipo, puntata, numero)
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🎡', titolo = 'Roulette', testo = tostring(errore), durata = 10000,
            })
        end

        exports.aurea_ui:Progresso({ etichetta = 'La pallina gira...', durata = 5000 })

        exports.aurea_ui:Notifica({
            tipo = esito.vinta and 'successo' or 'errore',
            icona = '🎡', durata = 13000,
            titolo = ('È uscito %d %s'):format(esito.numero, esito.colore),
            testo = esito.vinta
                and ('Hai vinto %d fiches.'):format(esito.vincita)
                or ('Hai perso %d fiches.'):format(esito.puntata),
        })
    end)
end

function slot()
    CreateThread(function()
        local t = CAS.Tavoli.slot
        local puntata = chiediPuntata(t)
        if not puntata then return end

        local esito, errore = AUREA.Callback.Attendi('cas:slot', puntata)
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🎰', titolo = 'Slot', testo = tostring(errore), durata = 10000,
            })
        end

        exports.aurea_ui:Progresso({ etichetta = 'I rulli girano...', durata = 3500 })

        exports.aurea_ui:Notifica({
            tipo = esito.vinta and 'successo' or 'info',
            icona = '🎰', durata = 12000,
            titolo = table.concat(esito.rulli, '  '),
            testo = esito.vinta
                and ('Hai vinto %d fiches.'):format(esito.vincita)
                or ('Niente. Hai perso %d fiches.'):format(esito.puntata),
        })
    end)
end

function blackjack()
    CreateThread(function()
        local t = CAS.Tavoli.blackjack
        local puntata = chiediPuntata(t)
        if not puntata then return end

        local mano, errore = AUREA.Callback.Attendi('cas:blackjackApri', puntata)
        if not mano then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🃏', titolo = 'Blackjack', testo = tostring(errore), durata = 10000,
            })
        end

        while true do
            if mano.sballato or mano.punteggio >= 21 then break end

            local scelta = exports.aurea_ui:Menu({
                titolo = ('Le tue carte: %d'):format(mano.punteggio),
                sottotitolo = ('%s   ·   il banco mostra %d')
                    :format(table.concat(mano.giocatore, ' '), mano.puntoBanco or 0),
                voci = {
                    { id = 'carta', icona = '🃏', titolo = 'Chiedi carta' },
                    { id = 'sto', icona = '✋', titolo = 'Sto' },
                },
            })
            if scelta ~= 'carta' then break end

            local nuova = AUREA.Callback.Attendi('cas:blackjackCarta')
            if not nuova then break end
            mano.giocatore = nuova.giocatore
            mano.punteggio = nuova.punteggio
            mano.sballato = nuova.sballato
        end

        local finale = AUREA.Callback.Attendi('cas:blackjackChiudi')
        if not finale then return end

        exports.aurea_ui:Notifica({
            tipo = finale.vincita > finale.puntata and 'successo'
                or (finale.vincita == finale.puntata and 'info' or 'errore'),
            icona = '🃏', durata = 15000,
            titolo = finale.esito,
            testo = ('Tu %d (%s) · Banco %d (%s) — %s')
                :format(finale.punteggio, table.concat(finale.giocatore, ' '),
                        finale.puntoBanco, table.concat(finale.banco, ' '),
                        finale.vincita > 0 and ('recuperi %d fiches'):format(finale.vincita)
                            or ('perdi %d fiches'):format(finale.puntata)),
        })
    end)
end
