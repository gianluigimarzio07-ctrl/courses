--[[
    AUREA · Consiglio dell'Ordine degli Avvocati (client)

    Uno sportello e quattro voci. Non c'è niente da disegnare sulla mappa
    oltre al blip: l'avvocatura è un mestiere di stanze.
]]

local U = AUREA.Util

local function statoAlbo()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('avv:statoAlbo')
        if not s then return end

        local voci = {}

        if s.iscritto then
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = '✅',
                titolo = 'Iscritto all\'albo',
                descrizione = ('L\'iscrizione scade fra %d minuti.'):format(s.minutiResidui),
            }
            voci[#voci + 1] = {
                id = 'turno', icona = s.inTurno and '⏹' or '📞',
                titolo = s.inTurno and 'Uscire dal turno' or 'Entrare nel turno delle difese d\'ufficio',
                descrizione = s.inTurno
                    and 'Non verrai più chiamato per le nomine d\'ufficio.'
                    or ('Ti si chiama quando qualcuno arriva davanti al giudice senza difensore.\nIndennità %s ogni %d minuti, anche senza incarichi.')
                        :format(U.Euro(AVV.Turno.indennita), AVV.Turno.minutiFraIndennita),
            }
        else
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = s.sospeso and '⏸' or '⚠',
                titolo = s.sospeso and 'Sospeso dall\'esercizio' or 'Non iscritto',
                descrizione = tostring(s.motivo or ''),
            }
            if not s.sospeso then
                voci[#voci + 1] = {
                    id = 'iscrivi', icona = '✍', titolo = 'Iscriversi all\'albo',
                    descrizione = ('Tassa %s. Serve l\'abilitazione — il praticante non si iscrive — e nessun fascicolo grave aperto.')
                        :format(U.Euro(s.tassa)),
                }
            end
        end

        voci[#voci + 1] = {
            id = 'chi', icona = '📋', titolo = 'Chi è di turno adesso',
            descrizione = 'L\'elenco dei difensori reperibili.',
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Albo degli avvocati', sottotitolo = 'La tua posizione', voci = voci })
        if not scelta or scelta == 'x' then return end

        if scelta == 'iscrivi' then
            local ok, messaggio = AUREA.Callback.Attendi('avv:iscrivi')
            return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                icona = '⚖', titolo = 'Albo', testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'turno' then
            local ok, messaggio = AUREA.Callback.Attendi('avv:turno', not s.inTurno)
            return exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
                icona = '📞', titolo = 'Turno', testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'chi' then
            local lista = AUREA.Callback.Attendi('avv:chiInTurno') or {}
            local v = {}
            for _, a in ipairs(lista) do
                v[#v + 1] = {
                    id = 'x', disattivata = true, icona = a.online and '🟢' or '⚪',
                    titolo = a.nome,
                    descrizione = ('%d incarichi in questo turno · restano %d minuti')
                        :format(a.incarichi, a.minutiResidui),
                }
            end
            if #v == 0 then
                v[1] = { id = 'x', disattivata = true, icona = '📞',
                    titolo = 'Nessun difensore in turno',
                    descrizione = 'Chi finisce davanti al giudice senza avvocato si arrangia con un difensore d\'ufficio d\'archivio.' }
            end
            exports.aurea_ui:Menu({ titolo = 'Turno delle difese d\'ufficio', voci = v })
        end
    end)
end

local function patrocinio()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Patrocinio a spese dello Stato',
            sottotitolo = AVV.Patrocinio.articolo,
            voci = {
                { id = 'x', disattivata = true, icona = 'ℹ',
                  titolo = 'Come funziona',
                  descrizione = ('Sotto %s di reddito imponibile l\'onorario del difensore lo paga l\'Erario.\nIl reddito si legge dall\'ultima dichiarazione: senza dichiarazione non è accertabile.')
                      :format(U.Euro(AVV.Patrocinio.sogliaReddito)) },
                { id = 'chiedi', icona = '🏛', titolo = 'Presentare la domanda',
                  descrizione = ('Se ammessa vale %d minuti.'):format(AVV.Patrocinio.minutiValidita) },
            },
        })
        if scelta ~= 'chiedi' then return end

        local ok, messaggio = AUREA.Callback.Attendi('avv:chiediPatrocinio')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏛',
            titolo = 'Gratuito patrocinio', testo = tostring(messaggio), durata = 24000 })
    end)
end

--- La motivazione del provvedimento: senza, il server rifiuta.
local function chiediMotivazione()
    local r = exports.aurea_ui:Dialogo('Motivazione del provvedimento', {
        { etichetta = 'Che cosa ha fatto', tipo = 'textarea', obbligatorio = true,
          segnaposto = 'Ha rifiutato una nomina d\'ufficio senza giustificato motivo' },
    })
    return r and r[1] or nil
end

local function disciplinare()
    CreateThread(function()
        local voci = {}
        for id, s in pairs(AVV.Disciplinare) do
            if type(s) == 'table' and s.etichetta then
                voci[#voci + 1] = {
                    id = id, icona = s.icona, titolo = s.etichetta,
                    descrizione = ('%s%s'):format(s.descrizione,
                        s.sanzione > 0 and ('\nSanzione pecuniaria %s.'):format(U.Euro(s.sanzione)) or ''),
                }
            end
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local sanzione = exports.aurea_ui:Menu({
            titolo = 'Procedimento disciplinare',
            sottotitolo = 'A carico dell\'avvocato che hai davanti', voci = voci })
        if not sanzione then return end

        local mio, bersaglio, minima = PlayerPedId(), nil, 6.0
        for _, p in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= mio and ped ~= 0 then
                local d = #(GetEntityCoords(mio) - GetEntityCoords(ped))
                if d < minima then
                    minima = d
                    bersaglio = GetPlayerServerId(p)
                end
            end
        end
        if not bersaglio then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚖',
                titolo = 'Disciplinare', testo = 'Non hai nessuno davanti.', durata = 10000 })
        end

        local motivo = chiediMotivazione()
        if not motivo then return end

        local ok, messaggio = AUREA.Callback.Attendi('avv:disciplinare', bersaglio, sanzione, motivo)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Disciplinare', testo = tostring(messaggio), durata = 18000 })
    end)
end

local function registro()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('avv:registro')
        if not righe then return end

        local voci = {}
        for _, i in ipairs(righe) do
            local t = AVV.GetIncarico(i.tipo)
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = t and t.icona or '📄',
                titolo = ('%s — %s'):format(t and t.etichetta or i.tipo, i.assistito or 'ignoto'),
                descrizione = ('%s a carico %s · %d minuti fa')
                    :format(U.Euro(i.onorario or 0),
                            i.a_carico == 'erario' and 'dello Stato' or 'dell\'assistito',
                            i.minutiFa or 0),
            }
        end
        if #voci == 0 then
            voci[1] = { id = 'x', disattivata = true, icona = '📄',
                titolo = 'Nessun incarico registrato' }
        end

        exports.aurea_ui:Menu({ titolo = 'I tuoi incarichi',
            sottotitolo = 'Gli ultimi venti', voci = voci })
    end)
end

local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = AVV.Sede.nome,
            sottotitolo = 'Albo, turno delle difese d\'ufficio, patrocinio',
            voci = {
                { id = 'albo', icona = '⚖', titolo = 'La tua posizione all\'albo',
                  descrizione = 'Iscrizione, rinnovo, turno di reperibilità.' },
                { id = 'patrocinio', icona = '🏛', titolo = 'Patrocinio a spese dello Stato',
                  descrizione = 'Aperto a tutti: si presenta la domanda e si vede.' },
                { id = 'registro', icona = '📄', titolo = 'I tuoi incarichi',
                  descrizione = 'Quanto hai preso e chi lo ha pagato.' },
                { id = 'disciplinare', icona = '📋', titolo = 'Procedimento disciplinare',
                  descrizione = 'Riservato al Consiglio e al giudice.' },
            },
        })
        if scelta == 'albo' then return statoAlbo() end
        if scelta == 'patrocinio' then return patrocinio() end
        if scelta == 'registro' then return registro() end
        if scelta == 'disciplinare' then return disciplinare() end
    end)
end

RegisterCommand('ordine', sportello, false)
RegisterCommand('patrocinio', patrocinio, false)
RegisterCommand('turnoufficio', function()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('avv:statoAlbo')
        if not s then return end
        local ok, messaggio = AUREA.Callback.Attendi('avv:turno', not s.inTurno)
        exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore',
            icona = '📞', titolo = 'Turno', testo = tostring(messaggio), durata = 16000 })
    end)
end, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(AVV.Sede.coord)
    SetBlipSprite(b, AVV.Sede.blip.sprite)
    SetBlipColour(b, AVV.Sede.blip.colore)
    SetBlipScale(b, AVV.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Ordine degli Avvocati')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('avv_sede', AVV.Sede.coord, AVV.Sede.raggio, {
        { etichetta = 'Consiglio dell\'Ordine degli Avvocati', icona = '⚖', azione = sportello },
    })
end)
