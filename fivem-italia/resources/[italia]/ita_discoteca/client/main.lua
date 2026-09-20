--[[
    AUREA · Locali notturni (client)

    Tre punti dentro ogni locale: la porta, la cassa, la consolle. Alla
    porta si decide chi entra, alla cassa si guarda com'è messa la serata,
    alla consolle si apre.
]]

local U = AUREA.Util

local function stato(codice)
    return AUREA.Callback.Attendi('disco:stato', codice)
end

-- ---------------------------------------------------------------------------
--  La cassa: lo stato del locale
-- ---------------------------------------------------------------------------
local function cassa(codice)
    CreateThread(function()
        local s = stato(codice)
        if not s then return end

        local voci = {
            { id = 'x', disattivata = true,
              icona = s.licenzaOk and '✅' or '⛔',
              titolo = 'Licenza di pubblico spettacolo',
              descrizione = s.licenzaOk and 'Valida (art. 68 TULPS).'
                  or ('%s\nSi chiede in Questura.'):format(s.motivoLicenza or '—') },
            { id = 'x', disattivata = true,
              icona = s.siaeOk and '✅' or '⛔',
              titolo = 'Permesso SIAE',
              descrizione = s.siaeOk and 'Trattenimento danzante coperto.'
                  or ('%s\nSi chiede alla SIAE.'):format(s.motivoSiae or '—') },
            { id = 'x', disattivata = true,
              icona = s.filtro and '✅' or '⛔',
              titolo = 'Addetto ai servizi di controllo',
              descrizione = s.filtro
                  or 'Nessuno in servizio e iscritto all\'elenco della Prefettura.' },
            { id = 'x', disattivata = true, icona = '👥',
              titolo = ('Presenti: %d su %d'):format(s.presenti, s.capienza),
              descrizione = 'Oltre la capienza la licenza si sospende, e la serata finisce.' },
        }

        if s.serata then
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🪩',
                titolo = ('Serata in corso — %s'):format(s.serata.nome),
                descrizione = ('Ingresso %s · %d entrati · picco %d · incasso %s · da %d minuti')
                    :format(U.Euro(s.serata.ingresso), s.serata.presenze,
                            s.serata.picco, U.Euro(s.serata.incasso), s.serata.minuti or 0),
            }
        elseif s.sonoGestore then
            voci[#voci + 1] = { id = 'apri', icona = '▶', titolo = 'Apri la serata',
                descrizione = 'Servono tutte e tre le voci sopra in verde.' }
        end

        if not s.sonoGestore then
            voci[#voci + 1] = { id = 'subentra', icona = '🔑', titolo = 'Subentra nella gestione',
                descrizione = ('%s. Serve il grado di gestore, in servizio.')
                    :format(U.Euro(s.costoSubentro)) }
        end

        voci[#voci + 1] = { id = 'esci', icona = '🚪', titolo = 'Segna che esci',
            descrizione = 'Liberi un posto: la capienza conta le persone, non i biglietti.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome, sottotitolo = 'Cassa del locale', voci = voci })
        if not scelta or scelta == 'x' then return end

        if scelta == 'subentra' then
            local ok, messaggio = AUREA.Callback.Attendi('disco:subentra', codice)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🔑',
                titolo = 'Gestione', testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'esci' then
            local ok, messaggio = AUREA.Callback.Attendi('disco:esci')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'info', icona = '🚪',
                titolo = s.nome, testo = tostring(messaggio) })
        end

        if scelta == 'apri' then
            local r = exports.aurea_ui:Dialogo('Apertura della serata', {
                { etichetta = 'Nome della serata', tipo = 'text', obbligatorio = true },
                { etichetta = ('Ingresso in centesimi (%d-%d)')
                    :format(DISCO.Serata.ingressoMinimo, DISCO.Serata.ingressoMassimo),
                  tipo = 'number', obbligatorio = true },
            })
            if not r or not r[1] then return end

            local ok, messaggio = AUREA.Callback.Attendi('disco:apri', codice, r[1], tonumber(r[2]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🪩',
                titolo = 'Serata', testo = tostring(messaggio), durata = 20000 })
        end
    end)
end

-- ---------------------------------------------------------------------------
--  La porta
-- ---------------------------------------------------------------------------
local function porta()
    CreateThread(function()
        local r = exports.aurea_ui:Dialogo('Filtro all\'ingresso', {
            { etichetta = 'ID della persona', tipo = 'number', obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('disco:ammetti', tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚪',
            titolo = 'Ingresso', testo = tostring(messaggio), durata = 14000 })
    end)
end

-- ---------------------------------------------------------------------------
--  Il controllo
-- ---------------------------------------------------------------------------
local function controllo()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({
            etichetta = 'Controllo del locale',
            durata = DISCO.Controllo.durataSecondi * 1000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('disco:controllo')
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🔦',
                titolo = 'Controllo', testo = tostring(esito), durata = 12000 })
        end

        if #esito.rilievi == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '✅',
                titolo = ('Controllo — %s'):format(esito.locale),
                testo = ('%d persone presenti, nessun rilievo.'):format(esito.presenti),
                durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '🔦',
            titolo = ('Verbale — %s'):format(esito.locale),
            testo = ('%s\n%d presenti.%s%s')
                :format(table.concat(esito.rilievi, '\n'), esito.presenti,
                        esito.sanzione > 0 and ('\nSanzione ' .. U.Euro(esito.sanzione)) or '',
                        esito.sospeso and '\nLICENZA SOSPESA, serata interrotta.' or ''),
            durata = 24000 })
    end)
end

RegisterCommand('controllolocale', controllo, false)

AddEventHandler('aurea:client:caricato', function()
    for _, l in ipairs(DISCO.Locali) do
        local b = AddBlipForCoord(l.ingresso)
        SetBlipSprite(b, l.blip.sprite)
        SetBlipColour(b, l.blip.colore)
        SetBlipScale(b, l.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(l.nome)
        EndTextCommandSetBlipName(b)

        local codice = l.codice

        exports.aurea_target:AggiungiZona('disco_porta_' .. codice, l.ingresso, 2.6, {
            { etichetta = 'Fai entrare qualcuno', icona = '🚪',
              lavoro = DISCO.Lavoro, inServizio = true, azione = porta },
            { etichetta = 'Controllo del locale', icona = '🔦',
              lavori = DISCO.Controllo.entiAbilitati, inServizio = true, azione = controllo },
        })

        exports.aurea_target:AggiungiZona('disco_cassa_' .. codice, l.cassa, 2.2, {
            { etichetta = 'Cassa del locale', icona = '💶',
              azione = function() cassa(codice) end },
        })

        exports.aurea_target:AggiungiZona('disco_consolle_' .. codice, l.consolle, 2.2, {
            { etichetta = 'Consolle', icona = '🪩',
              azione = function() cassa(codice) end },
        })
    end
end)
