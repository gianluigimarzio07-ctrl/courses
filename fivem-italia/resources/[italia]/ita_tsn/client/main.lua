--[[
    AUREA · Tiro a Segno Nazionale (client)

    Il poligono: un banco all'ingresso e tre linee di tiro. Sparare qui
    non spara davvero — la serie è un progresso e un numero che decide il
    server. Quello che conta non è l'animazione: è il certificato in fondo.
]]

local U = AUREA.Util

local function lezione()
    CreateThread(function()
        if not exports.aurea_ui:Progresso({
            etichetta = ('Serie di %d colpi'):format(TSN.Lezione.colpi),
            durata = TSN.Lezione.durataSecondi * 1000,
            annullabile = true }) then return end

        local ok, messaggio, punteggio, valida = AUREA.Callback.Attendi('tsn:lezione')
        exports.aurea_ui:Notifica({
            tipo = (ok and valida) and 'successo' or (ok and 'avviso' or 'errore'),
            icona = '🎯',
            titolo = ok and ('Serie chiusa — %d/100'):format(punteggio or 0) or 'Linea di tiro',
            testo = tostring(messaggio), durata = 18000,
        })
    end)
end

local function banco()
    CreateThread(function()
        local p, nomeIstruttore = AUREA.Callback.Attendi('tsn:posizione')

        local voci = {}

        if not p then
            voci[#voci + 1] = { id = 'iscrivi', icona = '📝', titolo = 'Iscriviti alla sezione',
                descrizione = ('Quota %s, validità %d giorni.')
                    :format(U.Euro(TSN.Iscrizione.quota), TSN.Iscrizione.giorniValidita) }
        else
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '🪪',
                titolo = ('Tessera %s'):format(p.tessera),
                descrizione = ('Scade il %s · lezioni valide %d di %d%s'):format(
                    p.tesseraIT or '—', p.lezioni or 0, TSN.Lezione.lezioniPerCertificato,
                    p.valido and ('\nCertificato valido fino al %s'):format(p.certificatoIT or '—')
                              or '\nCertificato assente o scaduto'),
            }

            if not p.tesseraValida then
                voci[#voci + 1] = { id = 'iscrivi', icona = '🔁', titolo = 'Rinnova la tessera',
                    descrizione = ('%s'):format(U.Euro(TSN.Iscrizione.quota)) }
            end

            if (p.lezioni or 0) >= TSN.Lezione.lezioniPerCertificato then
                voci[#voci + 1] = { id = 'certificato', icona = '📜',
                    titolo = 'Ritira il certificato di idoneità',
                    descrizione = ('%s. Serve un istruttore in sezione: %s')
                        :format(U.Euro(TSN.Certificato.costo),
                                nomeIstruttore or 'in questo momento non c\'è nessuno.') }
            end
        end

        voci[#voci + 1] = { id = 'info', disattivata = true, icona = 'ℹ',
            titolo = 'A cosa serve',
            descrizione = 'Senza questo certificato la Questura non rilascia il porto d\'armi e non si diventa guardia giurata.' }

        local scelta = exports.aurea_ui:Menu({
            titolo = TSN.Sezione.nome,
            sottotitolo = nomeIstruttore and ('Istruttore in sezione: %s'):format(nomeIstruttore)
                                          or 'Nessun istruttore in sezione',
            voci = voci,
        })
        if not scelta or scelta == 'x' or scelta == 'info' then return end

        if scelta == 'iscrivi' then
            local ok, messaggio = AUREA.Callback.Attendi('tsn:iscrivi')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📝',
                titolo = 'Tiro a Segno', testo = tostring(messaggio), durata = 16000 })
        end

        if scelta == 'certificato' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Rilascio del certificato',
                durata = TSN.Certificato.secondiRilascio * 1000, annullabile = true }) then return end

            local ok, messaggio = AUREA.Callback.Attendi('tsn:certificato')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📜',
                titolo = 'Certificato di idoneità', testo = tostring(messaggio), durata = 22000 })
        end
    end)
end

local function registro()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('tsn:registro')
        if not righe then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🎯',
                titolo = 'Tiro a Segno', testo = 'Riservato agli istruttori in servizio.' })
        end

        local voci = {}
        for _, r in ipairs(righe) do
            voci[#voci + 1] = {
                id = 'x', disattivata = true,
                icona = r.certificatoIT and '📜' or '🎯',
                titolo = ('%s — %s'):format(r.nominativo or '—', r.tessera),
                descrizione = ('Lezioni valide %d · media %d/100%s'):format(
                    r.lezioni or 0, r.media or 0,
                    r.certificatoIT and ('\nCertificato fino al %s'):format(r.certificatoIT) or ''),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '🎯', titolo = 'Nessun iscritto in corso' }
        end

        exports.aurea_ui:Menu({ titolo = 'Registro della sezione',
            sottotitolo = 'Iscritti con tessera valida', voci = voci })
    end)
end

RegisterCommand('tsn', banco, false)
RegisterCommand('registrotsn', registro, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(TSN.Sezione.coord)
    SetBlipSprite(b, TSN.Sezione.blip.sprite)
    SetBlipColour(b, TSN.Sezione.blip.colore)
    SetBlipScale(b, TSN.Sezione.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Tiro a Segno Nazionale')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('tsn_banco', TSN.Sezione.coord, TSN.Sezione.raggio, {
        { etichetta = 'Banco della sezione', icona = '🪪', azione = banco },
        { etichetta = 'Registro iscritti', icona = '📋',
          lavoro = TSN.Lavoro, inServizio = true, azione = registro },
    })

    for i, linea in ipairs(TSN.Sezione.linee) do
        exports.aurea_target:AggiungiZona(('tsn_linea_%d'):format(i), linea, TSN.Sezione.raggioLinea, {
            { etichetta = ('Linea di tiro %d'):format(i), icona = '🎯', azione = lezione },
        })
    end
end)
