--[[
    AUREA · ASL (client)

    Una schermata sola: lo stato igienico del locale in cui ti trovi, e i
    due gesti che lo cambiano — pulire e depositare il piano.
]]

local function pannello()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('asl:stato')
        if not s then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🧪',
                titolo = 'ASL', testo = 'Non sei in un esercizio pubblico.' })
        end

        local voci = {
            { id = 'x', disattivata = true,
              icona = s.igiene >= 65 and '✅' or (s.igiene >= 45 and '⚠' or '⛔'),
              titolo = ('Igiene: %d%%'):format(s.igiene),
              descrizione = s.spiegazione },
            { id = 'x2', disattivata = true, icona = s.haccp and '📋' or '📭',
              titolo = s.haccp and 'Piano HACCP depositato' or 'Piano HACCP assente',
              descrizione = s.haccp and 'In regola con il Reg. CE 852/2004.'
                  or 'Senza, l\'ispezione parte già con una violazione grave.' },
        }

        if s.sospeso then
            voci[#voci + 1] = { id = 'riapri', icona = '🔓',
                titolo = 'Chiedi la riapertura',
                descrizione = ('Sospeso per altri %d minuti. Servono igiene sopra il %d%% e i diritti.')
                    :format(s.minutiSospensione, ASL.Igiene.sogliaAvviso) }
        end

        voci[#voci + 1] = { id = 'sanifica', icona = '🧽', titolo = 'Sanifica',
            descrizione = ('Serve %s. Recupera %d punti.')
                :format(AUREA.Item[ASL.Igiene.prodotto].etichetta, ASL.Igiene.sanificazioneRecupero) }

        if not s.haccp then
            voci[#voci + 1] = { id = 'haccp', icona = '📋', titolo = 'Deposita il piano HACCP',
                descrizione = ('%s · vale %d minuti')
                    :format(AUREA.Util.Euro(ASL.Haccp.costo), ASL.Haccp.validitaMinuti) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome, sottotitolo = 'Igiene e autocontrollo', voci = voci })
        if not scelta or scelta:sub(1, 1) == 'x' then return end

        if scelta == 'sanifica' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Sanificazione delle superfici',
                                                durata = ASL.Igiene.sanificazioneSecondi * 1000,
                                                annullabile = true }) then return end
        end

        local ok, messaggio = AUREA.Callback.Attendi(
            scelta == 'sanifica' and 'asl:sanifica'
            or (scelta == 'haccp' and 'asl:haccp' or 'asl:riapri'))

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧪',
            titolo = 'ASL', testo = tostring(messaggio), durata = 16000,
        })
    end)
end

RegisterCommand('igiene', pannello, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(ASL.Sede.coord)
    SetBlipSprite(b, ASL.Sede.blip.sprite)
    SetBlipColour(b, ASL.Sede.blip.colore)
    SetBlipScale(b, ASL.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(ASL.Sede.nome)
    EndTextCommandSetBlipName(b)
end)
