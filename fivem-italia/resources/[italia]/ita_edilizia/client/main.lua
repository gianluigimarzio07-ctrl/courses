--[[
    AUREA · Edilizia (client)

    Disegna il cantiere e chiede al server di lavorarci. L'unica cosa che
    decide da solo è quale animazione far fare al ped, e quanto dura la
    barra di progresso — che è comunque il server a ricontrollare quando
    arriva la richiesta.
]]

local cantieri = {}     -- [lottoId] = pacchetto pubblicato dal server
local blipCantiere = {}

-- ---------------------------------------------------------------------------
--  Ricezione dello stato
-- ---------------------------------------------------------------------------
local function disegnaBlip(lottoId)
    local c = cantieri[lottoId]
    local l = EDI.GetLotto(lottoId)
    if not l then return end

    if blipCantiere[lottoId] then RemoveBlip(blipCantiere[lottoId]) end
    if not c then blipCantiere[lottoId] = nil return end

    local b = AddBlipForCoord(l.coord)
    SetBlipSprite(b, 566)
    SetBlipColour(b, c.stato == 'sospeso' and 1 or 46)
    SetBlipScale(b, 0.7)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(
        c.stato == 'sospeso' and ('%s (sospeso)'):format(l.nome) or l.nome)
    EndTextCommandSetBlipName(b)
    blipCantiere[lottoId] = b
end

RegisterNetEvent('edi:cantiere', function(c)
    cantieri[c.lotto] = c
    disegnaBlip(c.lotto)
end)

RegisterNetEvent('edi:cantiereChiuso', function(lottoId)
    cantieri[lottoId] = nil
    disegnaBlip(lottoId)
end)

-- ---------------------------------------------------------------------------
--  La lavorazione
-- ---------------------------------------------------------------------------
local function lavora()
    CreateThread(function()
        local stato = AUREA.Callback.Attendi('edi:stato')
        if not stato then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🏗', titolo = 'Cantiere', testo = 'Non sei in un cantiere.' })
        end

        local fase = EDI.GetFase(stato.fase)
        local anim = fase and fase.animazione

        if anim then
            RequestAnimDict(anim.dizionario)
            local scadenza = GetGameTimer() + 3000
            while not HasAnimDictLoaded(anim.dizionario) and GetGameTimer() < scadenza do Wait(20) end
            if HasAnimDictLoaded(anim.dizionario) then
                TaskPlayAnim(PlayerPedId(), anim.dizionario, anim.nome, 4.0, -4.0, -1, 1, 0, false, false, false)
            end
        end

        local completata = exports.aurea_ui:Progresso({
            etichetta = fase and fase.nome or 'Lavorazione',
            durata = (fase and fase.secondi or 10) * 1000,
            annullabile = true,
        })

        ClearPedTasks(PlayerPedId())
        if not completata then return end

        local ok, messaggio, finito = AUREA.Callback.Attendi('edi:lavora')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏗',
            titolo = 'Cantiere', testo = tostring(messaggio), durata = 12000,
        })

        if finito then
            exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🏗', durata = 14000,
                titolo = 'Opera ultimata',
                testo = 'Il direttore di cantiere può firmare la consegna.',
            })
        end
    end)
end

--- Elenco leggibile di item a partire dai nomi interni.
local function descriviItem(elenco)
    local fuori = {}
    for _, nome in ipairs(elenco) do
        fuori[#fuori + 1] = (AUREA.Item[nome] and AUREA.Item[nome].etichetta) or nome
    end
    return table.concat(fuori, ', ')
end

-- ---------------------------------------------------------------------------
--  Apertura di un cantiere sul lotto in cui ti trovi
-- ---------------------------------------------------------------------------
local function apriPannelloLotto()
    CreateThread(function()
        local coord = GetEntityCoords(PlayerPedId())
        local lotto

        for _, l in ipairs(EDI.Lotti) do
            if #(coord - l.coord) <= 30.0 then lotto = l end
        end

        if not lotto then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🏗', titolo = 'Nessun cantiere',
                testo = 'Qui non c\'è un cantiere né un lotto edificabile.' })
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = lotto.nome,
            sottotitolo = ('%d m³ · destinazione %s'):format(lotto.volumetria, lotto.destinazione),
            voci = {
                { id = 'apri', icona = '🏗', titolo = 'Apri il cantiere',
                  descrizione = 'Serve un permesso a costruire valido e il DURC regolare.' },
                { id = 'abusivo', icona = '⚠', titolo = 'Apri senza titolo edilizio',
                  descrizione = 'Abuso edilizio, art. 44 D.P.R. 380/2001. Se ti trovano, sequestrano.' },
            },
        })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('edi:apri', lotto.id, scelta == 'abusivo')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏗',
            titolo = 'Cantiere', testo = tostring(messaggio), durata = 16000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Il pannello del cantiere
-- ---------------------------------------------------------------------------
local function pannello()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('edi:stato')

        if not s then
            -- Nessun cantiere qui: se sei sul lotto e hai i galloni, puoi aprirlo
            return apriPannelloLotto()
        end

        local voci = {
            { id = 'x', disattivata = true, icona = '📐',
              titolo = ('%s — %d%%'):format(s.nomeFase, s.avanzamento),
              descrizione = ('Lavorazione %d di %d · rischio %d%%%s%s')
                  :format(s.lavorazioni, s.lavorazioniTotali, s.rischio,
                          s.pos and '' or ' · POS mancante',
                          s.abusivo and ' · SENZA TITOLO EDILIZIO' or '') },
        }

        if s.stato == 'sospeso' then
            voci[#voci + 1] = { id = 'x2', disattivata = true, icona = '⛔',
                titolo = 'Cantiere sospeso',
                descrizione = 'Provvedimento dell\'ispettorato. Finché non decade non si lavora.' }
        end

        if s.tua and s.stato ~= 'sospeso' then
            voci[#voci + 1] = {
                id = 'lavora', icona = '🧱', titolo = 'Esegui una lavorazione',
                descrizione = #s.dpi > 0 and ('DPI previsti: %s'):format(descriviItem(s.dpi)) or nil,
            }
        end

        if s.tua then
            if not s.pos then
                voci[#voci + 1] = { id = 'pos', icona = '📋', titolo = 'Deposita il POS',
                    descrizione = 'Piano operativo di sicurezza. Abbassa il rischio e toglie un capo d\'accusa.' }
            end
            if not s.ponteggio then
                voci[#voci + 1] = { id = 'ponteggio', icona = '🪜', titolo = 'Monta il ponteggio',
                    descrizione = ('Servono %d tubi. Senza, i lavori in quota sono una violazione.')
                        :format(EDI.Ponteggio.tubiNecessari) }
            end
            if s.avanzamento >= 100 then
                voci[#voci + 1] = { id = 'consegna', icona = '🔑', titolo = 'Firma la consegna',
                    descrizione = 'Il compenso va nella cassa dell\'impresa. Il collaudo lo paghi tu.' }
            end
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome,
            sottotitolo = ('Impresa: %s'):format(s.impresa),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'lavora' then return lavora() end

        local ok, messaggio

        if scelta == 'pos' then
            if not exports.aurea_ui:Progresso({ etichetta = 'Redazione del POS',
                                                durata = EDI.Sicurezza.posSecondi * 1000,
                                                annullabile = true }) then return end
            ok, messaggio = AUREA.Callback.Attendi('edi:pos')

        elseif scelta == 'ponteggio' then
            for i = 1, EDI.Ponteggio.campate do
                if not exports.aurea_ui:Progresso({
                    etichetta = ('Ponteggio — campata %d di %d'):format(i, EDI.Ponteggio.campate),
                    durata = EDI.Ponteggio.secondiPerCampata * 1000, annullabile = true }) then return end
            end
            ok, messaggio = AUREA.Callback.Attendi('edi:ponteggio')

        elseif scelta == 'consegna' then
            ok, messaggio = AUREA.Callback.Attendi('edi:consegna')
        else
            return
        end

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏗',
            titolo = 'Cantiere', testo = tostring(messaggio), durata = 15000,
        })
    end)
end

RegisterCommand('cantiere', pannello, false)

-- ---------------------------------------------------------------------------
--  Sportello Unico per l'Edilizia
-- ---------------------------------------------------------------------------
local function sportello()
    CreateThread(function()
        local voci = {}
        for _, l in ipairs(EDI.Lotti) do
            local oneri = math.floor(l.volumetria * EDI.Permesso.onerePerMetroCubo)
            voci[#voci + 1] = {
                id = l.id, icona = '📐', titolo = l.nome,
                descrizione = ('%d m³ · oneri di urbanizzazione %s · diritti %s')
                    :format(l.volumetria, AUREA.Util.Euro(oneri),
                            AUREA.Util.Euro(EDI.Permesso.dirittiSegreteria)),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = EDI.Sportello.nome,
            sottotitolo = ('Istanza di permesso a costruire · silenzio-assenso dopo %d minuti')
                :format(EDI.Permesso.silenzioAssensoMinuti),
            voci = voci,
        })
        if not scelta then return end

        local ok, messaggio = AUREA.Callback.Attendi('edi:chiediPermesso', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📐',
            titolo = 'SUE', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Rivendita di materiali
-- ---------------------------------------------------------------------------
local function rivendita()
    CreateThread(function()
        local voci = {}
        for i, v in ipairs(EDI.Fornitore.listino) do
            voci[#voci + 1] = {
                id = tostring(i),
                icona = v.dpi and '🦺' or '📦',
                titolo = ('%d × %s'):format(v.quantita, AUREA.Item[v.item].etichetta),
                descrizione = ('%s a confezione%s'):format(AUREA.Util.Euro(v.prezzo),
                    v.dpi and ' · DPI: lo compra il datore, art. 18 D.Lgs. 81/2008' or ''),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = EDI.Fornitore.nome,
            sottotitolo = 'Si paga dalla cassa dell\'impresa',
            voci = voci,
        })
        if not scelta then return end

        local r = exports.aurea_ui:Dialogo('Quante confezioni', {
            { etichetta = 'Confezioni', tipo = 'number', valore = 1, min = 1, max = 20, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('edi:acquista', tonumber(scelta), tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '📦',
            titolo = 'Rivendita', testo = tostring(messaggio), durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Blip e punti di interazione
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:client:caricato', function()
    for _, p in ipairs({ EDI.Sportello, EDI.Fornitore }) do
        local b = AddBlipForCoord(p.coord)
        SetBlipSprite(b, p.blip.sprite)
        SetBlipColour(b, p.blip.colore)
        SetBlipScale(b, p.blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(p.nome)
        EndTextCommandSetBlipName(b)
    end

    exports.aurea_target:AggiungiZona('edilizia_sue', EDI.Sportello.coord, EDI.Sportello.raggio, {
        { etichetta = 'Sportello Unico per l\'Edilizia', icona = '📐',
          lavoro = EDI.Lavoro, azione = sportello },
    })

    exports.aurea_target:AggiungiZona('edilizia_fornitore', EDI.Fornitore.coord, EDI.Fornitore.raggio, {
        { etichetta = 'Rivendita di materiali', icona = '📦',
          lavoro = EDI.Lavoro, azione = rivendita },
    })

    for _, l in ipairs(EDI.Lotti) do
        exports.aurea_target:AggiungiZona('edilizia_lotto_' .. l.id, l.coord, 6.0, {
            { etichetta = 'Cantiere', icona = '🏗', lavoro = EDI.Lavoro, azione = pannello },
        })
    end
end)
