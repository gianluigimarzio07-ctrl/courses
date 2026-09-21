--[[
    AUREA · Antiriciclaggio (client)

    Due sportelli: quello dove il cittadino si fa verificare, e quello
    dove la Finanza legge le segnalazioni. Il primo è noioso di
    proposito — nella realtà lo è.
]]

local U = AUREA.Util

local function verifica()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('aml:verificaStato')
        if not s then return end

        local descrizione
        if s.verifica then
            descrizione = ('Valida, profilo %s. Fonte dichiarata: %s.\nScade fra %d minuti.')
                :format(s.verifica.profilo, s.verifica.fonte_reddito or '—',
                        math.max(0, s.verifica.minuti or 0))
        else
            descrizione = ('Assente. Le operazioni sopra %s non passano.')
                :format(U.Euro(s.soglia))
        end

        local voci = {
            { id = 'x', disattivata = true, icona = 'ℹ',
              titolo = 'Adeguata verifica della clientela', descrizione = descrizione },
        }
        for _, f in ipairs(s.fonti) do
            voci[#voci + 1] = {
                id = f.id, icona = '📝', titolo = f.nome,
                descrizione = ('Dichiari che i tuoi soldi vengono da qui. Vale %d minuti.')
                    :format(s.minuti),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Adeguata verifica',
            sottotitolo = 'Il profilo di rischio lo assegna il conto, non quello che dichiari',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Acquisizione dei dati',
            durata = 14000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('aml:verifica', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💼',
            titolo = 'Verifica', testo = tostring(messaggio), durata = 20000 })
    end)
end

local function nucleo()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('aml:coda')
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '💼',
                titolo = 'Nucleo valutario', testo = 'Riservato alla Guardia di Finanza in servizio.' })
        end

        local voci = {}

        for _, r in ipairs(s.segnalazioni) do
            local etichette = {
                contante = 'Contante', frazionamento = 'Frazionamento',
                profilo = 'Fuori profilo', terzi = 'Operazione per conto terzi', cripto = 'Cripto',
            }
            voci[#voci + 1] = {
                id = tostring(r.id),
                icona = r.tipo == 'frazionamento' and '🧩' or '💼',
                titolo = ('%s — %s'):format(r.nominativo or r.citizenid, U.Euro(r.importo)),
                descrizione = ('%s · %s\n%s\nProfilo: %s · fonte: %s · %d minuti fa')
                    :format(etichette[r.tipo] or r.tipo, r.codice_fiscale or '—',
                            r.motivo, r.profilo or 'non verificato',
                            r.fonte_reddito or '—', r.minutiFa or 0),
            }
        end

        for _, c in ipairs(s.congelamenti) do
            voci[#voci + 1] = {
                id = 'conf:' .. tostring(c.id),
                icona = '🧊',
                titolo = ('Congelato: %s — %s'):format(c.nominativo or c.citizenid, U.Euro(c.importo)),
                descrizione = ('Cadono fra %d minuti se non si conferma.\nLa conferma richiede un procedimento aperto.')
                    :format(math.max(0, c.minuti or 0)),
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '✅',
                        titolo = 'Nessuna segnalazione aperta' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Segnalazioni di operazione sospetta',
            sottotitolo = 'Quello che una soglia secca non vede',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local idConferma = scelta:match('^conf:(%d+)$')
        if idConferma then
            local ok, messaggio = AUREA.Callback.Attendi('aml:conferma', tonumber(idConferma))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🧊',
                titolo = 'Congelamento', testo = tostring(messaggio), durata = 18000 })
        end

        local azioni = {
            { id = 'archivia', icona = '📁', titolo = 'Archivia',
              descrizione = 'Nessun elemento di sospetto: si chiude e basta.' },
        }
        if s.puoCongelare then
            azioni[#azioni + 1] = { id = 'congela', icona = '🧊', titolo = 'Congela le somme',
                descrizione = ('Blocco a termine. Cade da solo se non lo confermi, e confermarlo richiede un procedimento.') }
        end

        local azione = exports.aurea_ui:Menu({
            titolo = 'Che cosa fare', sottotitolo = 'Segnalazione n. ' .. scelta, voci = azioni })
        if not azione then return end

        if azione == 'archivia' then
            local r = exports.aurea_ui:Dialogo('Archiviazione', {
                { etichetta = 'Esito degli accertamenti', tipo = 'text' },
            })
            local ok, messaggio = AUREA.Callback.Attendi('aml:archivia', tonumber(scelta), r and r[1])
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📁',
                titolo = 'Segnalazione', testo = tostring(messaggio), durata = 14000 })
        end

        local ok, messaggio = AUREA.Callback.Attendi('aml:congela', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧊',
            titolo = 'Congelamento', testo = tostring(messaggio), durata = 20000 })
    end)
end

RegisterCommand('adeguataverifica', verifica, false)
RegisterCommand('sos', nucleo, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(AML.Nucleo.coord)
    SetBlipSprite(b, AML.Nucleo.blip.sprite)
    SetBlipColour(b, AML.Nucleo.blip.colore)
    SetBlipScale(b, AML.Nucleo.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Nucleo valutario')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('aml_nucleo', AML.Nucleo.coord, AML.Nucleo.raggio, {
        { etichetta = 'Segnalazioni sospette', icona = '💼',
          lavoro = AML.Lavoro, inServizio = true, azione = nucleo },
    })

    -- La verifica si fa dove serve: allo sportello
    exports.aurea_target:AggiungiZona('aml_sportello', AML.Sportello.coord, AML.Sportello.raggio, {
        { etichetta = 'Adeguata verifica della clientela', icona = '📝', azione = verifica },
    })
end)
