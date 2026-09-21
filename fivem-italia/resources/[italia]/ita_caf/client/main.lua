--[[
    AUREA · C.A.F. (client)

    Una schermata che mostra un conto già fatto e chiede una cosa sola:
    hai altre spese da aggiungere? Quella domanda è tutto il gioco.
]]

local U = AUREA.Util

local function dichiarazione()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('caf:precompilata')
        if not s then return end

        if s.gia then
            local d = s.gia
            return exports.aurea_ui:Menu({
                titolo = ('Dichiarazione %s'):format(s.periodo),
                sottotitolo = ('Già presentata — %s'):format(d.stato),
                voci = {
                    { id = 'x', disattivata = true, icona = '💼', titolo = 'Reddito del periodo',
                      descrizione = U.Euro(d.reddito) },
                    { id = 'x', disattivata = true, icona = '📉', titolo = 'Detrazioni riconosciute',
                      descrizione = U.Euro(d.detrazioni) },
                    { id = 'x', disattivata = true, icona = '🧾', titolo = 'Imposta dovuta',
                      descrizione = U.Euro(d.imposta) },
                    { id = 'x', disattivata = true, icona = '💶', titolo = 'Già trattenuto in busta',
                      descrizione = U.Euro(d.ritenute) },
                    { id = 'x', disattivata = true,
                      icona = d.saldo >= 0 and '✅' or '⚠',
                      titolo = d.saldo >= 0 and 'A credito' or 'A debito',
                      descrizione = U.Euro(math.abs(d.saldo)) },
                },
            })
        end

        local voci = {
            { id = 'x', disattivata = true, icona = '💼',
              titolo = 'Reddito del periodo',
              descrizione = ('%s — ricostruito dalle ritenute già versate, non da quello che dichiari.')
                  :format(U.Euro(s.reddito)) },
            { id = 'x', disattivata = true, icona = '👤',
              titolo = 'Detrazione da lavoro dipendente',
              descrizione = ('%s — scende man mano che il reddito sale.')
                  :format(U.Euro(s.detrazioneLavoro)) },
        }

        for _, v in ipairs(s.voci) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '📄',
                titolo = v.descrizione,
                descrizione = ('Spesa %s · detrazione %s')
                    :format(U.Euro(v.spesa), U.Euro(v.detrazione)),
            }
        end

        voci[#voci + 1] = {
            id = 'x', disattivata = true, icona = '🧮',
            titolo = ('Imposta dovuta: %s'):format(U.Euro(s.imposta)),
            descrizione = ('Già trattenuto: %s.\n%s'):format(U.Euro(s.ritenute),
                s.saldo >= 0
                    and ('Ti tornerebbero %s.'):format(U.Euro(s.saldo))
                    or ('Dovresti versare %s.'):format(U.Euro(-s.saldo))),
        }

        voci[#voci + 1] = {
            id = 'presenta', icona = '✍',
            titolo = 'Presenta la dichiarazione',
            descrizione = ('Assistenza %s. Puoi aggiungere spese sanitarie: nessuno te le chiede adesso, ma il controllo formale può arrivare dopo.')
                :format(U.Euro(s.compenso)),
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Dichiarazione precompilata — %s'):format(s.periodo),
            sottotitolo = 'La ritenuta in busta paga era solo un acconto',
            voci = voci,
        })
        if scelta ~= 'presenta' then return end

        local r = exports.aurea_ui:Dialogo('Altre spese detraibili', {
            { etichetta = 'Spese sanitarie sostenute (centesimi, 0 se nessuna)', tipo = 'number' },
        })
        if not r then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Compilazione e visto di conformità',
            durata = CAF.Periodo.secondiCompilazione * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('caf:presenta', tonumber(r[1]) or 0)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧾',
            titolo = 'C.A.F.', testo = tostring(messaggio), durata = 26000 })
    end)
end

RegisterCommand('caf', dichiarazione, false)
RegisterCommand('dichiarazione', dichiarazione, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(CAF.Sede.coord)
    SetBlipSprite(b, CAF.Sede.blip.sprite)
    SetBlipColour(b, CAF.Sede.blip.colore)
    SetBlipScale(b, CAF.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('C.A.F. e patronato')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('caf_sede', CAF.Sede.coord, CAF.Sede.raggio, {
        { etichetta = 'Sportello del CAF', icona = '🧾', azione = dichiarazione },
    })
end)
