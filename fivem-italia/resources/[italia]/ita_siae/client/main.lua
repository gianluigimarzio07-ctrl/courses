--[[
    AUREA · S.I.A.E. (client)

    Due lati: il gestore che chiede il permesso, e l'ispettore che passa
    a vedere se ce l'ha. Non si incontrano quasi mai, ed è il motivo per
    cui il borderò esiste.
]]

local U = AUREA.Util

local function permessi()
    CreateThread(function()
        local locali = AUREA.Callback.Attendi('siae:locali') or {}

        local voci = {}
        for _, l in ipairs(locali) do
            local attivi = {}
            for _, p in ipairs(l.permessi) do
                local t = SIAE.GetPermesso(p.tipo)
                attivi[#attivi + 1] = ('%s (%d min)'):format(t and t.nome or p.tipo, p.minuti or 0)
            end

            voci[#voci + 1] = {
                id = l.id,
                icona = #attivi > 0 and '✅' or (l.abusive > 0 and '⚠' or '🎵'),
                titolo = l.nome,
                descrizione = ('%s%s'):format(
                    #attivi > 0 and table.concat(attivi, ', ') or 'nessun permesso attivo',
                    l.abusive > 0 and ('\n%d esecuzioni non coperte negli ultimi %d minuti')
                        :format(l.abusive, SIAE.Ispezione.minutiRetroattivi) or ''),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Permessi per pubblica esecuzione',
            sottotitolo = 'La musica in un locale non è mai gratis',
            voci = voci,
        })
        if not scelta then return end

        local vociTipo = {}
        for _, t in ipairs(SIAE.Permessi) do
            vociTipo[#vociTipo + 1] = {
                id = t.id, icona = '🎼', titolo = t.nome,
                descrizione = ('%s\n%s · %d minuti'):format(t.descrizione, U.Euro(t.costo), t.minutiValidita),
            }
        end

        local tipo = exports.aurea_ui:Menu({
            titolo = 'Che permesso serve',
            sottotitolo = 'Quello più alto copre anche quelli sotto',
            voci = vociTipo })
        if not tipo then return end

        local ok, messaggio = AUREA.Callback.Attendi('siae:chiedi', scelta, tipo)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎼',
            titolo = 'S.I.A.E.', testo = tostring(messaggio), durata = 20000 })
    end)
end

local function verbali()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('siae:mieiVerbali') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🎵',
                titolo = 'S.I.A.E.', testo = 'Non hai verbali in sospeso.', durata = 10000 })
        end

        local voci = {}
        for _, v in ipairs(righe) do
            voci[#voci + 1] = {
                id = tostring(v.id), icona = '⚠',
                titolo = ('%s — %s'):format(v.nomeLocale or v.locale, U.Euro(v.importo)),
                descrizione = v.motivo,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Verbali SIAE', sottotitolo = 'Si pagano in sede', voci = voci })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('siae:paga', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎼',
            titolo = 'S.I.A.E.', testo = tostring(messaggio), durata = 14000 })
    end)
end

local function ispeziona()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({
            etichetta = 'Controllo del borderò',
            durata = SIAE.Ispezione.durataSecondi * 1000, annullabile = true }) then return end

        local ok, esito = AUREA.Callback.Attendi('siae:ispeziona')
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🎼',
                titolo = 'S.I.A.E.', testo = tostring(esito), durata = 12000 })
        end

        if esito.brani == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'successo', icona = '✅',
                titolo = ('Controllo — %s'):format(esito.locale),
                testo = esito.permesso
                    and ('In regola: permesso "%s" attivo.'):format(esito.permesso)
                    or 'Nessuna esecuzione da contestare.',
                durata = 14000 })
        end

        exports.aurea_ui:Notifica({
            tipo = 'errore', icona = '⚠',
            titolo = ('Verbale — %s'):format(esito.locale),
            testo = ('%d esecuzioni senza permesso. Sanzione %s.%s')
                :format(esito.brani, U.Euro(esito.sanzione),
                        esito.intestatario and '' or '\nNessun gestore registrato: il verbale va a chi suonava.'),
            durata = 20000 })
    end)
end

local function sede()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = SIAE.Sede.nome,
            sottotitolo = 'Permessi per pubblica esecuzione e verbali',
            voci = {
                { id = 'permessi', icona = '🎼', titolo = 'Chiedi un permesso',
                  descrizione = 'Musica d\'ambiente, dal vivo, trattenimento danzante.' },
                { id = 'verbali', icona = '⚠', titolo = 'I tuoi verbali',
                  descrizione = 'Quelli che hai preso per aver suonato senza.' },
            },
        })
        if scelta == 'permessi' then return permessi() end
        if scelta == 'verbali' then return verbali() end
    end)
end

RegisterCommand('siae', sede, false)
RegisterCommand('controllosiae', ispeziona, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SIAE.Sede.coord)
    SetBlipSprite(b, SIAE.Sede.blip.sprite)
    SetBlipColour(b, SIAE.Sede.blip.colore)
    SetBlipScale(b, SIAE.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('S.I.A.E.')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('siae_sede', SIAE.Sede.coord, SIAE.Sede.raggio, {
        { etichetta = 'Sportello SIAE', icona = '🎼', azione = sede },
    })
end)
