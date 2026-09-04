--[[
    AUREA · Organizzazioni criminali (client)
]]

local U = AUREA.Util
local blipContesa = nil

-- ---------------------------------------------------------------------------
--  Lavanderie
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local coord = GetEntityCoords(PlayerPedId())

        for _, l in ipairs(FAM.Riciclaggio.lavanderie) do
            if #(coord - l.coord) < 2.5 then
                attesa = 0
                exports.aurea_ui:Prompt(true, l.nome, 'E')
                if IsControlJustReleased(0, 38) then
                    exports.aurea_ui:Prompt(false)
                    ricicla()
                end
                break
            end
        end

        if attesa ~= 0 then exports.aurea_ui:Prompt(false) end
        Wait(attesa)
    end
end)

function ricicla()
    CreateThread(function()
        local valori = exports.aurea_ui:Dialogo('Operazione di lavaggio', {
            { etichetta = ('Unità da ripulire (max %d, 100 € cadauna)'):format(FAM.Riciclaggio.massimoOperazione),
              tipo = 'number', valore = 10, min = 1, max = FAM.Riciclaggio.massimoOperazione },
        })
        if not valori then return end

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Operazione in corso...',
            durata = FAM.Riciclaggio.durata,
            annullabile = true,
            blocca = { movimento = true },
        })
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('fam:ricicla', valori[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '💵', titolo = ok and 'Denaro ripulito' or 'Operazione non riuscita',
            testo = messaggio, durata = 11000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Pannello dell'organizzazione
-- ---------------------------------------------------------------------------
RegisterNetEvent('fam:apriPannello', function()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('fam:situazione')

        if not s then
            -- Non affiliato: si può fondare o denunciare un'estorsione
            local scelta = exports.aurea_ui:Menu({
                titolo = 'Nessuna affiliazione',
                sottotitolo = 'Non fai parte di alcuna organizzazione',
                voci = {
                    { id = 'fonda', icona = '🩸', titolo = 'Costituisci un\'organizzazione',
                      descrizione = 'Richiede contanti e una struttura da guidare.',
                      valore = U.Euro(FAM.Regole.costoFondazione) },
                    { id = 'denuncia', icona = '📋', titolo = 'Denuncia un\'estorsione',
                      descrizione = 'Se la tua attività è sottoposta al pizzo.' },
                    { id = 'territori', icona = '🗺', titolo = 'Mappa dei territori',
                      descrizione = 'Chi controlla cosa in città.' },
                },
            })
            if not scelta then return end

            if scelta == 'fonda' then
                local valori = exports.aurea_ui:Dialogo('Costituzione', {
                    { etichetta = 'Sigla (3-16 caratteri)', tipo = 'text', segnaposto = 'ES. CORLEONE', obbligatorio = true },
                    { etichetta = 'Nome esteso', tipo = 'text', segnaposto = 'Famiglia Corleone', obbligatorio = true },
                    { etichetta = 'Tipo', tipo = 'select', opzioni = {
                        { valore = 'famiglia', etichetta = 'Famiglia' },
                        { valore = 'clan', etichetta = 'Clan' },
                        { valore = 'cosca', etichetta = 'Cosca' },
                        { valore = 'banda', etichetta = 'Banda' },
                        { valore = 'sindacato', etichetta = 'Sindacato' },
                    } },
                })
                if not valori then return end

                local ok, messaggio = AUREA.Callback.Attendi('fam:fonda', valori[1], valori[2], valori[3])
                exports.aurea_ui:Notifica({
                    tipo = ok and 'successo' or 'errore',
                    icona = '🩸', titolo = ok and 'Organizzazione costituita' or 'Costituzione rifiutata',
                    testo = messaggio, durata = 11000,
                })

            elseif scelta == 'denuncia' then
                local ok, messaggio = AUREA.Callback.Attendi('fam:denunciaPizzo')
                exports.aurea_ui:Notifica({
                    tipo = ok and 'successo' or 'errore',
                    icona = '📋', titolo = ok and 'Denuncia presentata' or 'Denuncia non accettata',
                    testo = messaggio, durata = 14000,
                })

            elseif scelta == 'territori' then
                mostraTerritori()
            end
            return
        end

        -- Affiliato
        local statoCalore = s.calore >= FAM.Calore.sogliaIndagine and 'INDAGINE IN CORSO'
            or s.calore >= FAM.Calore.sogliaControlli and 'sotto osservazione'
            or 'tranquilla'

        local voci = {
            { id = 'info', icona = '🩸', titolo = s.nome,
              descrizione = ('%s · %d affiliati · situazione %s'):format(
                  s.mioGradoEtichetta, #s.membri, statoCalore),
              valore = ('cassa %s'):format(U.Euro(s.cassa)), disattivata = true },
            { id = 'calore', icona = s.calore >= FAM.Calore.sogliaIndagine and '🔴' or s.calore >= FAM.Calore.sogliaControlli and '🟡' or '🟢',
              titolo = 'Attenzione delle forze dell\'ordine',
              descrizione = 'Ogni attività illecita la alza. Fermarsi la fa scendere.',
              valore = ('%d/100'):format(s.calore), disattivata = true },
            { id = 'organico', icona = '👥', titolo = 'Organico', descrizione = ('%d affiliati'):format(#s.membri) },
            { id = 'cassa', icona = '💰', titolo = 'Cassa comune', valore = U.Euro(s.cassa) },
            { id = 'territori', icona = '🗺', titolo = 'Territori',
              descrizione = ('Ne controllate %d'):format(#s.territori) },
        }

        if FAM.GradoHaPermesso(s.mioGrado, 'pizzo') then
            voci[#voci + 1] = { id = 'pizzo', icona = '💼', titolo = 'Imponi il pizzo alla persona vicina',
                descrizione = ('Attività sotto protezione: %d'):format(#s.pizzo) }
        end
        if FAM.GradoHaPermesso(s.mioGrado, 'recluta') then
            voci[#voci + 1] = { id = 'recluta', icona = '➕', titolo = 'Affilia la persona vicina' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome,
            sottotitolo = ('%s · sigla %s'):format(s.tipo:gsub('^%l', string.upper), s.tag),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'organico' then
            local voci2 = {}
            for _, m in ipairs(s.membri) do
                voci2[#voci2 + 1] = {
                    id = m.citizenid, icona = m.online and '🟢' or '⚫',
                    titolo = ('%s %s'):format(m.nome, m.cognome),
                    descrizione = m.gradoEtichetta,
                    valore = m.online and 'in zona' or 'assente',
                }
            end

            local citizenid = exports.aurea_ui:Menu({
                titolo = 'Organico',
                sottotitolo = s.eCapo and 'Seleziona per cambiare grado' or 'Sola consultazione',
                voci = voci2,
            })
            if not citizenid or not s.eCapo then return end

            local gradiVoci = {}
            for n = 0, 3 do
                gradiVoci[#gradiVoci + 1] = { id = n, icona = '🎖', titolo = FAM.EtichettaGrado(n) }
            end
            local grado = exports.aurea_ui:Menu({ titolo = 'Assegna il grado', voci = gradiVoci })
            if grado == nil then return end

            local ok, messaggio = AUREA.Callback.Attendi('fam:grado', citizenid, grado)
            exports.aurea_ui:Notifica({ tipo = ok and 'successo' or 'errore', icona = '🎖', titolo = 'Gerarchia', testo = messaggio })

        elseif scelta == 'cassa' then
            local verso = exports.aurea_ui:Menu({
                titolo = 'Cassa comune',
                sottotitolo = ('Disponibili %s'):format(U.Euro(s.cassa)),
                voci = {
                    { id = 'versa', icona = '⬆', titolo = 'Versa contanti' },
                    { id = 'preleva', icona = '⬇', titolo = 'Preleva',
                      disattivata = not FAM.GradoHaPermesso(s.mioGrado, 'cassa_preleva') },
                },
            })
            if not verso then return end

            local valori = exports.aurea_ui:Dialogo('Importo', {
                { etichetta = 'Euro', tipo = 'text', segnaposto = '1000.00', obbligatorio = true },
            })
            if not valori then return end

            local ok, messaggio = AUREA.Callback.Attendi('fam:cassa', verso, valori[1])
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '💰', titolo = 'Cassa comune', testo = messaggio, durata = 8000,
            })

        elseif scelta == 'territori' then
            mostraTerritori()

        elseif scelta == 'pizzo' then
            local bersaglio = giocatoreVicino()
            if not bersaglio then
                return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati al titolare.' })
            end
            local valori = exports.aurea_ui:Dialogo('Richiesta estorsiva', {
                { etichetta = ('Percentuale (%d-%d)'):format(FAM.Pizzo.percentualeMinima, FAM.Pizzo.percentualeMassima),
                  tipo = 'number', valore = 10, min = FAM.Pizzo.percentualeMinima, max = FAM.Pizzo.percentualeMassima },
            })
            if not valori then return end

            local ok, messaggio = AUREA.Callback.Attendi('fam:impostaPizzo', bersaglio, valori[1])
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '🩸', titolo = ok and 'Attività sotto protezione' or 'Imposizione fallita',
                testo = messaggio, durata = 11000,
            })

        elseif scelta == 'recluta' then
            local bersaglio = giocatoreVicino()
            if not bersaglio then
                return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
            end
            local ok, messaggio = AUREA.Callback.Attendi('fam:recluta', bersaglio)
            exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore',
                icona = '🩸', titolo = ok and 'Affiliazione' or 'Affiliazione rifiutata',
                testo = messaggio, durata = 9000,
            })
        end
    end)
end)

function giocatoreVicino()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped and #(coord - GetEntityCoords(altroPed)) < 3.0 then
            return GetPlayerServerId(altro)
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  Mappa dei territori
-- ---------------------------------------------------------------------------
function mostraTerritori()
    CreateThread(function()
        local territori = AUREA.Callback.Attendi('fam:territori') or {}

        local voci = {}
        for _, t in ipairs(territori) do
            voci[#voci + 1] = {
                id = t.codice,
                icona = t.inContesa and '⚔' or (t.organizzazione and '🩸' or '⬜'),
                titolo = t.nome,
                descrizione = t.organizzazione
                    and ('Controllato da %s · %d%%'):format(t.organizzazione, t.controllo)
                    or 'Nessuno lo controlla',
                valore = ('%s/h'):format(U.Euro(t.rendita_oraria)),
            }
        end

        local codice = exports.aurea_ui:Menu({
            titolo = 'Territori',
            sottotitolo = 'Seleziona per navigare o aprire una contesa',
            voci = voci,
        })
        if not codice then return end

        local territorio
        for _, t in ipairs(territori) do
            if t.codice == codice then territorio = t break end
        end
        if not territorio then return end

        local azione = exports.aurea_ui:Menu({
            titolo = territorio.nome,
            sottotitolo = territorio.organizzazione and ('Attualmente di %s'):format(territorio.organizzazione) or 'Territorio libero',
            voci = {
                { id = 'gps', icona = '📍', titolo = 'Imposta il navigatore' },
                { id = 'contendi', icona = '⚔', titolo = 'Apri una contesa',
                  descrizione = ('Servono %d affiliati sul posto per %d minuti.'):format(
                      FAM.Contesa.minimoPartecipanti, FAM.Contesa.durataMinuti),
                  disattivata = territorio.inContesa },
            },
        })
        if not azione then return end

        if azione == 'gps' and territorio.coord then
            SetNewWaypoint(territorio.coord.x, territorio.coord.y)
            exports.aurea_ui:Notifica({ tipo = 'info', icona = '📍', titolo = 'Navigatore impostato', testo = territorio.nome })
        elseif azione == 'contendi' then
            local ok, messaggio = AUREA.Callback.Attendi('fam:contendi', codice)
            exports.aurea_ui:Notifica({
                tipo = ok and 'avviso' or 'errore',
                icona = '⚔', titolo = ok and 'Contesa avviata' or 'Contesa non avviata',
                testo = messaggio, durata = 13000,
            })
        end
    end)
end

-- ---------------------------------------------------------------------------
--  Contese in corso
-- ---------------------------------------------------------------------------
RegisterNetEvent('fam:contesaAvviata', function(dati)
    if blipContesa then RemoveBlip(blipContesa) end

    blipContesa = AddBlipForRadius(dati.coord.x, dati.coord.y, dati.coord.z, dati.raggio)
    SetBlipColour(blipContesa, 1)
    SetBlipAlpha(blipContesa, 110)

    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '⚔', durata = 15000,
        titolo = ('Contesa su %s'):format(dati.nome),
        testo = ('%s rivendica la zona. Durata %d minuti: chi tiene il territorio con più uomini lo prende.'):format(
            dati.attaccante, dati.minuti),
    })

    SetTimeout(dati.minuti * 60000 + 5000, function()
        if blipContesa then RemoveBlip(blipContesa) blipContesa = nil end
    end)
end)

RegisterNetEvent('fam:contesaConclusa', function(dati)
    if blipContesa then RemoveBlip(blipContesa) blipContesa = nil end

    exports.aurea_ui:Notifica({
        tipo = dati.vincitore and 'info' or 'avviso',
        icona = '⚔', durata = 13000,
        titolo = ('Contesa conclusa — %s'):format(dati.nome),
        testo = dati.vincitore
            and ('%s controlla ora la zona al %d%%.'):format(dati.vincitore, dati.controllo)
            or 'Nessuno ha raggiunto il controllo necessario. La zona resta come prima.',
    })
end)

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa == GetCurrentResourceName() and blipContesa then RemoveBlip(blipContesa) end
end)
