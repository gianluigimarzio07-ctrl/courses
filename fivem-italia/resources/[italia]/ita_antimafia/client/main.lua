--[[
    AUREA · Misure di prevenzione (client)

    Tre schermate: l'accertamento patrimoniale, la proposta, e la
    destinazione dei beni confiscati. Nessun numero nasce qui.
]]

local function vicini(titolo)
    local elenco, ped = {}, PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= 6.0 then
            elenco[#elenco + 1] = { id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)) }
        end
    end
    if #elenco == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚖', titolo = titolo,
            testo = 'Non c\'è nessuno vicino.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, voci = elenco })
end

local function accertamento()
    CreateThread(function()
        local chi = vicini('Su chi accerti')
        if not chi then return end

        local a, errore = AUREA.Callback.Attendi('ant:accerta', tonumber(chi))
        if not a then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⚖',
                titolo = 'Accertamento', testo = errore or 'Non disponibile.', durata = 12000 })
        end

        local voci = {
            { id = 'x', disattivata = true, icona = '💼',
              titolo = ('Patrimonio: %s'):format(AUREA.Util.Euro(a.patrimonio)),
              descrizione = ('Redditi dichiarati %s%s'):format(
                  AUREA.Util.Euro(a.reddito),
                  a.rapporto and (' · rapporto %.1f su una soglia di %.1f'):format(a.rapporto, a.soglia)
                      or ' · nessun reddito dichiarato') },
            { id = 'x', disattivata = true, icona = a.presupposti and '🔥' or '⚪',
              titolo = 'Presupposti soggettivi',
              descrizione = ('Calore dell\'organizzazione %d · gravità cumulata %d')
                  :format(a.calore, a.gravita) },
        }

        for _, v in ipairs(a.voci or {}) do
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '▪',
                titolo = v.descrizione, descrizione = AUREA.Util.Euro(v.valore) }
        end

        if a.proponibile then
            voci[#voci + 1] = { id = 'proponi', icona = '⚖',
                titolo = 'Proponi la misura di prevenzione',
                descrizione = 'Solo la magistratura. Apre il contraddittorio.' }
        else
            voci[#voci + 1] = { id = 'x', disattivata = true, icona = '⛔',
                titolo = 'Non proponibile',
                descrizione = a.sproporzionato and 'Mancano i presupposti soggettivi.'
                    or 'Il patrimonio è coerente con i redditi.' }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Accertamento — %s'):format(a.nome),
            sottotitolo = 'D.Lgs. 159/2011',
            voci = voci,
        })
        if scelta ~= 'proponi' then return end

        local ok, messaggio = AUREA.Callback.Attendi('ant:proponi', tonumber(chi))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'DDA', testo = tostring(messaggio), durata = 24000,
        })
    end)
end

local function beni()
    CreateThread(function()
        local righe = AUREA.Callback.Attendi('ant:beni') or {}
        if #righe == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '⚖',
                titolo = 'Beni confiscati', testo = 'Nessun bene in attesa di destinazione.' })
        end

        local voci = {}
        for _, b in ipairs(righe) do
            voci[#voci + 1] = { id = tostring(b.id), icona = '🏛',
                titolo = b.descrizione,
                descrizione = ('Valore %s · in attesa di destinazione'):format(AUREA.Util.Euro(b.valore)) }
        end

        local bene = exports.aurea_ui:Menu({
            titolo = 'Beni confiscati',
            sottotitolo = 'Riutilizzo sociale — legge Rognoni-La Torre',
            voci = voci,
        })
        if not bene then return end

        local scelte = {}
        for _, d in ipairs(ANT.Riutilizzo) do
            scelte[#scelte + 1] = { id = d.id, icona = '🏛', titolo = d.nome, descrizione = d.descrizione }
        end

        local destinazione = exports.aurea_ui:Menu({
            titolo = 'A cosa lo destini', sottotitolo = 'La scelta è del Comune', voci = scelte })
        if not destinazione then return end

        local ok, messaggio = AUREA.Callback.Attendi('ant:destina', tonumber(bene), destinazione)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🏛',
            titolo = 'Comune', testo = tostring(messaggio), durata = 20000,
        })
    end)
end

local function sede()
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = ANT.Sede.nome,
            sottotitolo = 'Misure di prevenzione patrimoniali',
            voci = {
                { id = 'accerta', icona = '💼', titolo = 'Accertamento patrimoniale',
                  descrizione = 'Su chi hai davanti. Mette in fila quello che ha e quello che ha dichiarato.' },
                { id = 'beni', icona = '🏛', titolo = 'Destina i beni confiscati',
                  descrizione = 'Riservato al Comune.' },
            },
        })
        if scelta == 'accerta' then return accertamento() end
        if scelta == 'beni' then return beni() end
    end)
end

RegisterCommand('prevenzione', sede, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(ANT.Sede.coord)
    SetBlipSprite(b, ANT.Sede.blip.sprite)
    SetBlipColour(b, ANT.Sede.blip.colore)
    SetBlipScale(b, ANT.Sede.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(ANT.Sede.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('ant_sede', ANT.Sede.coord, ANT.Sede.raggio, {
        { etichetta = 'Direzione Distrettuale Antimafia', icona = '⚖',
          lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'giudice', 'comune' },
          azione = sede },
    })
end)
