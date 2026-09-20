--[[
    AUREA · Questura — Polizia Amministrativa (client)

    Uno sportello con tre code. Nessuna di queste code decide qualcosa
    qui: il no, quando arriva, arriva dal server e con la ragione scritta.
]]

local U = AUREA.Util

local function passaporto()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('que:passaportoStato')
        if not s then return end

        local descrizione
        if s.passaporto and s.passaporto.ritirato == 0 then
            descrizione = ('Passaporto n. %s, scade il %s.')
                :format(s.passaporto.numero, s.passaporto.scadenzaIT or '—')
        elseif s.passaporto then
            descrizione = ('Ritirato — %s'):format(s.passaporto.motivo_ritiro or 'provvedimento')
        else
            descrizione = 'Non risulti titolare di passaporto.'
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Ufficio passaporti',
            sottotitolo = s.pendenze > 0
                and ('Attenzione: %d procedimenti pendenti a tuo carico'):format(s.pendenze)
                or 'Nessuna pendenza risultante',
            voci = {
                { id = 'stato', icona = 'ℹ', titolo = 'La tua posizione',
                  descrizione = descrizione, disattivata = true },
                { id = 'chiedi', icona = '🛂', titolo = 'Chiedi il rilascio',
                  descrizione = ('%s fra contributo e bollo. Con procedimenti penali pendenti non si rilascia (art. 3 L. 1185/1967).')
                      :format(U.Euro(s.costo or 0)) },
            },
        })
        if scelta ~= 'chiedi' then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Istruttoria della domanda',
            durata = QUE.Passaporto.secondiIstruttoria * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('que:passaportoChiedi')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🛂',
            titolo = 'Ufficio passaporti', testo = tostring(messaggio), durata = 20000 })
    end)
end

local function portoArmi()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('que:portoArmiStato')
        if not s then return end

        local voci = {}
        for _, t in ipairs(s.titoli) do
            local tipo = QUE.GetTipoPortoArmi(t.tipo)
            voci[#voci + 1] = {
                id = 'x', disattivata = true, icona = t.revocato == 1 and '⛔' or '✅',
                titolo = tipo and tipo.nome or t.tipo,
                descrizione = t.revocato == 1
                    and ('Revocato — %s'):format(t.motivo_revoca or 'provvedimento')
                    or ('Valido fino al %s'):format(t.scadenzaIT or '—'),
            }
        end

        for _, tipo in ipairs(QUE.PortoArmi.tipi) do
            voci[#voci + 1] = {
                id = tipo.id, icona = '📝',
                titolo = ('Chiedi: %s'):format(tipo.nome),
                descrizione = ('%s · %s · %d giorni%s'):format(
                    tipo.descrizione, U.Euro(tipo.costo), tipo.giorni,
                    s.certificato and '' or '\nManca il certificato del Tiro a Segno.'),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Titoli di porto d\'armi',
            sottotitolo = s.certificato
                and 'Certificato di idoneità al maneggio: valido'
                or 'Certificato di idoneità al maneggio: assente',
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Istruttoria e accertamenti',
            durata = QUE.PortoArmi.secondiIstruttoria * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('que:portoArmiChiedi', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🔫',
            titolo = 'Porto d\'armi', testo = tostring(messaggio), durata = 20000 })
    end)
end

local function licenzaSpettacolo()
    CreateThread(function()
        local locali, costo, giorni = AUREA.Callback.Attendi('que:licenzaLocali')
        locali = locali or {}

        if #locali == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🎫',
                titolo = 'Licenza di pubblico spettacolo',
                testo = 'Non gestisci nessun locale notturno.', durata = 12000 })
        end

        local voci = {}
        for _, l in ipairs(locali) do
            voci[#voci + 1] = {
                id = l.codice, icona = l.valida and '✅' or '⛔',
                titolo = l.nome,
                descrizione = ('Capienza %d · %s\nRinnovo: %s per %d giorni'):format(
                    l.capienza,
                    l.valida and ('licenza valida fino al %s'):format(l.scadenzaIT or '—')
                              or 'licenza assente o scaduta',
                    U.Euro(costo or 0), giorni or 0),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Licenza art. 68 TULPS',
            sottotitolo = 'Senza, il locale non fa serate',
            voci = voci,
        })
        if not scelta then return end

        if not exports.aurea_ui:Progresso({ etichetta = 'Istruttoria della licenza',
            durata = QUE.LicenzaSpettacolo.secondiIstruttoria * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('que:licenzaChiedi', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🎫',
            titolo = 'Licenza di pubblico spettacolo', testo = tostring(messaggio), durata = 18000 })
    end)
end

local function sportello()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = QUE.Sportello.nome,
            sottotitolo = 'Passaporti, porto d\'armi, licenze di pubblico spettacolo',
            voci = {
                { id = 'passaporto', icona = '🛂', titolo = 'Passaporto',
                  descrizione = 'Non si rilascia a chi ha procedimenti penali pendenti.' },
                { id = 'armi', icona = '🔫', titolo = 'Porto d\'armi',
                  descrizione = 'Serve prima il certificato del Tiro a Segno Nazionale.' },
                { id = 'licenza', icona = '🎫', titolo = 'Licenza di pubblico spettacolo',
                  descrizione = 'Art. 68 TULPS, per chi gestisce un locale notturno.' },
            },
        })
        if scelta == 'passaporto' then return passaporto() end
        if scelta == 'armi' then return portoArmi() end
        if scelta == 'licenza' then return licenzaSpettacolo() end
    end)
end

RegisterCommand('questura', sportello, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(QUE.Sportello.coord)
    SetBlipSprite(b, QUE.Sportello.blip.sprite)
    SetBlipColour(b, QUE.Sportello.blip.colore)
    SetBlipScale(b, QUE.Sportello.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Questura — Polizia Amministrativa')
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('que_sportello', QUE.Sportello.coord, QUE.Sportello.raggio, {
        { etichetta = 'Sportello licenze', icona = '🛂', azione = sportello },
    })
end)
