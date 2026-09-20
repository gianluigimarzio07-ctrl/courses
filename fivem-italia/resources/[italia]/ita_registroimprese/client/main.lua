--[[
    AUREA · Registro delle Imprese (client)

    Uno sportello con tre cose: iscrivere la propria impresa, guardare
    dentro quella di qualcun altro, e cedere quote. La seconda è la più
    interessante e costa cinquantacinque euro.
]]

local U = AUREA.Util

local function mieImprese()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('reg:mieImprese') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🏢',
                titolo = 'Registro delle Imprese',
                testo = 'Non risulti titolare di nessuna impresa attiva. Si apre all\'Agenzia delle Entrate.',
                durata = 14000 })
        end

        local voci = {}
        for _, i in ipairs(righe) do
            local stato
            if not i.rea then
                stato = ('NON ISCRITTA · iscrizione %s'):format(U.Euro(i.iscrizione))
            elseif i.stato_registro == 'sospesa' then
                stato = 'SOSPESA dal Registro per omesso diritto annuale'
            else
                stato = ('REA %s · attiva'):format(i.rea)
            end

            local dovuto = i.dirittoDovuto
                and ('\nDiritto annuale %s da pagare: %s')
                    :format(i.dirittoDovuto.periodo, U.Euro(i.dirittoDovuto.importo))
                or ''

            voci[#voci + 1] = {
                id = tostring(i.id),
                icona = i.rea and (i.stato_registro == 'attiva' and '✅' or '⛔') or '📝',
                titolo = i.ragione_sociale,
                descrizione = ('%s · P.IVA %s\n%s%s'):format(i.forma, i.piva, stato, dovuto),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Le tue imprese',
            sottotitolo = 'La P.IVA la dà il fisco, il REA lo diamo noi',
            voci = voci,
        })
        if not scelta then return end

        local id = tonumber(scelta)
        local impresa
        for _, i in ipairs(righe) do if i.id == id then impresa = i break end end
        if not impresa then return end

        local azioni = {}
        if not impresa.rea then
            azioni[#azioni + 1] = { id = 'iscrivi', icona = '📝', titolo = 'Iscrivi al Registro',
                descrizione = ('%s fra diritti di segreteria e bollo.'):format(U.Euro(impresa.iscrizione)) }
        else
            azioni[#azioni + 1] = { id = 'soci', icona = '👥', titolo = 'Compagine sociale',
                descrizione = 'Chi risulta socio, e con quale quota.' }
        end
        if impresa.dirittoDovuto then
            azioni[#azioni + 1] = { id = 'diritto', icona = '💶', titolo = 'Paga il diritto annuale',
                descrizione = ('%s per il periodo %s.')
                    :format(U.Euro(impresa.dirittoDovuto.importo), impresa.dirittoDovuto.periodo) }
        end

        local azione = exports.aurea_ui:Menu({
            titolo = impresa.ragione_sociale, sottotitolo = impresa.settore or '', voci = azioni })
        if not azione then return end

        if azione == 'iscrivi' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Istruttoria dell\'iscrizione',
                durata = REG.Iscrizione.secondiIstruttoria * 1000, annullabile = true }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('reg:iscrivi', impresa.id)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🏢',
                titolo = 'Registro delle Imprese', testo = tostring(messaggio), durata = 20000 })
        end

        if azione == 'diritto' then
            local ok, messaggio = AUREA.Callback.Attendi('reg:pagaDiritto', impresa.dirittoDovuto.id)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '💶',
                titolo = 'Diritto annuale', testo = tostring(messaggio), durata = 16000 })
        end

        if azione == 'soci' then
            local s = AUREA.Callback.Attendi('reg:soci', impresa.id)
            if not s then return end

            local vociSoci = {}
            for _, socio in ipairs(s.soci) do
                vociSoci[#vociSoci + 1] = {
                    id = 'x', disattivata = true,
                    icona = socio.amministratore == 1 and '★' or '👤',
                    titolo = socio.nominativo or '—',
                    descrizione = ('Quota %d%%%s'):format(socio.quota,
                        socio.amministratore == 1 and ' · amministratore' or ''),
                }
            end
            vociSoci[#vociSoci + 1] = { id = 'cedi', icona = '➕', titolo = 'Cedi una quota',
                descrizione = ('Deposito dell\'atto %s. La quota esce dalla tua.')
                    :format(U.Euro(s.costo)) }

            local sc = exports.aurea_ui:Menu({
                titolo = ('Soci di %s'):format(s.impresa),
                sottotitolo = ('Quote depositate: %d%%'):format(s.totale),
                voci = vociSoci })
            if sc ~= 'cedi' then return end

            local r = exports.aurea_ui:Dialogo('Cessione di quota', {
                { etichetta = 'ID della persona', tipo = 'number', obbligatorio = true },
                { etichetta = 'Quota da cedere (1-99)', tipo = 'number', obbligatorio = true },
            })
            if not r or not r[1] or not r[2] then return end

            local ok, messaggio = AUREA.Callback.Attendi('reg:depositaSocio',
                impresa.id, tonumber(r[1]), tonumber(r[2]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '👥',
                titolo = 'Compagine sociale', testo = tostring(messaggio), durata = 18000 })
        end
    end)
end

local function visura()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Visura camerale', {
            { etichetta = 'Ragione sociale, P.IVA o numero REA', tipo = 'text', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local righe, errore = AUREA.Callback.Attendi('reg:visura', r[1])
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔎',
                titolo = 'Visura', testo = errore or 'Nessun risultato.', durata = 14000 })
        end

        local voci = {}
        for _, i in ipairs(righe) do
            local soci = {}
            for _, s in ipairs(i.soci or {}) do
                soci[#soci + 1] = ('%s %d%%%s'):format(s.nominativo or '—', s.quota,
                    s.amministratore == 1 and ' (amm.)' or '')
            end

            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = i.stato_registro == 'attiva' and '🏢' or '⛔',
                titolo = ('%s — REA %s'):format(i.ragione_sociale, i.rea),
                descrizione = ('%s · %s · P.IVA %s\nSede: %s\nTitolare: %s\nSoci: %s\nDipendenti: %d · fatturato %s\nIscritta il %s · %s')
                    :format(i.forma, i.settore, i.piva, i.sede or '—', i.titolare or '—',
                            #soci > 0 and table.concat(soci, ', ') or 'nessuno depositato',
                            i.dipendenti or 0, U.Euro(i.fatturato_anno or 0),
                            i.iscrittaIT or '—', i.stato_registro),
            }
        end

        exports.aurea_ui:Menu({ titolo = 'Visura camerale',
            sottotitolo = 'È pubblica: chiunque può sapere chi c\'è dietro', voci = voci })
    end)
end

local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = REG.Sportello.nome,
            sottotitolo = 'Iscrizioni, visure, atti societari',
            voci = {
                { id = 'mie', icona = '🏢', titolo = 'Le tue imprese',
                  descrizione = 'Iscrizione, soci, diritto annuale.' },
                { id = 'visura', icona = '🔎', titolo = 'Chiedi una visura',
                  descrizione = ('%s. Di chiunque: il Registro è pubblico.')
                      :format(U.Euro(REG.Visura.costo)) },
            },
        })
        if scelta == 'mie' then return mieImprese() end
        if scelta == 'visura' then return visura() end
    end)
end

RegisterCommand('registroimprese', sportello, false)
RegisterCommand('visuracamerale', visura, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(REG.Sportello.coord)
    SetBlipSprite(b, REG.Sportello.blip.sprite)
    SetBlipColour(b, REG.Sportello.blip.colore)
    SetBlipScale(b, REG.Sportello.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Camera di Commercio')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('reg_sportello', REG.Sportello.coord, REG.Sportello.raggio, {
        { etichetta = 'Sportello del Registro Imprese', icona = '🏢', azione = sportello },
    })
end)
