--[[
    AUREA · Ispettorato del Lavoro (client)

    L'accesso ispettivo si fa dove si lavora, non in ufficio: è tutto il
    senso della cosa. Il client chiede, il server conta.
]]

local U = AUREA.Util

local function accesso()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({
            etichetta = 'Accesso ispettivo — identificazione dei presenti',
            durata = ISP.Accesso.durataSecondi * 1000,
            annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('isp:accesso')
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋',
                titolo = 'Ispettorato', testo = tostring(esito), durata = 12000 })
        end

        local testo
        if esito.inNero == 0 then
            testo = ('%s — %d lavoratori presenti, tutti in regola. Nessun rilievo.')
                :format(esito.lavoro, esito.presenti)
        else
            testo = ('%s — %d presenti, %d senza contratto.\n%s\nMaxisanzione: %s%s')
                :format(esito.lavoro, esito.presenti, esito.inNero,
                        table.concat(esito.nomi, ', '),
                        U.Euro(esito.sanzione),
                        esito.sospensione and '\n\nATTIVITÀ SOSPESA (art. 14 D.Lgs. 81/2008).' or '')
        end

        exports.aurea_ui:Notifica({
            tipo = esito.inNero == 0 and 'successo' or 'errore',
            icona = '📋', titolo = 'Verbale di accesso',
            testo = testo, durata = 26000,
        })
    end)
end

local function sospensioni()
    CreateThread(function()
        local righe, puoRevocare = AUREA.Callback.Attendi('isp:sospensioni')
        righe = righe or {}

        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '⛔',
                titolo = 'Ispettorato', testo = 'Nessuna attività sospesa.', durata = 10000 })
        end

        local voci = {}
        for _, s in ipairs(righe) do
            local azionabile = puoRevocare or s.mia
            voci[#voci + 1] = {
                id = azionabile and s.lavoro or 'x',
                disattivata = not azionabile,
                icona = '⛔',
                titolo = s.etichetta,
                descrizione = ('%s\nSospesa da %d minuti.%s'):format(
                    s.motivo, s.minuti,
                    puoRevocare and '\nPuoi revocare d\'ufficio.'
                        or (s.mia and ('\nRevoca: %s dalla cassa o di tasca tua.')
                            :format(U.Euro(s.importoRevoca)) or '')),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Provvedimenti di sospensione',
            sottotitolo = 'Finché durano, quel mestiere non si esercita',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local ok, messaggio = AUREA.Callback.Attendi('isp:revoca', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⛔',
            titolo = 'Ispettorato', testo = tostring(messaggio), durata = 16000 })
    end)
end

local function registro()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('isp:registro')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '📋',
                titolo = 'Ispettorato', testo = 'Riservato agli ispettori in servizio.' })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = r.esito == 'regolare' and '✅' or (r.esito == 'sospensione' and '⛔' or '⚠'),
                titolo = ('%s — %s'):format(r.etichetta, r.esito),
                descrizione = ('%s\n%d presenti · %d irregolari · %s\n%d minuti fa, %s')
                    :format(r.verbale or '—', r.presenti or 0, r.in_nero or 0,
                            U.Euro(r.sanzione or 0), r.minutiFa or 0, r.nome_ispettore or '—'),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '📋', titolo = 'Nessun accesso registrato' }
        end

        exports.aurea_ui:Menu({ titolo = 'Registro degli accessi ispettivi',
            sottotitolo = 'Gli ultimi venti', voci = voci })
    end)
end

local function ufficio()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = ISP.Sede.nome,
            sottotitolo = 'Vigilanza sul lavoro',
            voci = {
                { id = 'sospensioni', icona = '⛔', titolo = 'Provvedimenti in corso',
                  descrizione = 'Le attività sospese e come si riaprono.' },
                { id = 'registro', icona = '📋', titolo = 'Registro degli accessi',
                  descrizione = 'Riservato agli ispettori.' },
            },
        })
        if scelta == 'sospensioni' then return sospensioni() end
        if scelta == 'registro' then return registro() end
    end)
end

RegisterCommand('ispettorato', ufficio, false)
RegisterCommand('accessoispettivo', accesso, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(ISP.Sede.coord)
    SetBlipSprite(b, ISP.Sede.blip.sprite)
    SetBlipColour(b, ISP.Sede.blip.colore)
    SetBlipScale(b, ISP.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Ispettorato del Lavoro')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('isp_sede', ISP.Sede.coord, ISP.Sede.raggio, {
        { etichetta = 'Ufficio dell\'Ispettorato', icona = '📋', azione = ufficio },
    })
end)
