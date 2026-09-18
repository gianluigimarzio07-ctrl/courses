--[[
    AUREA · Parrocchia (client)

    Quattro punti dentro la chiesa e un canale che non lascia traccia. La
    confessione passa da un evento diretto: quello che scrivi arriva al
    confessore e a nessun altro, e quando la finestra si chiude non esiste
    più da nessuna parte.
]]

local confessoreDi = nil    -- a chi sto confessando, se sono il penitente

-- ---------------------------------------------------------------------------
--  Il confessore riceve
-- ---------------------------------------------------------------------------
RegisterNetEvent('chi:ascolto', function(testo)
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🕊', durata = 25000,
        titolo = 'Dall\'altra parte della grata',
        testo = testo,
    })
end)

local function vicini(titolo, distanza)
    local elenco, ped = {}, PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= (distanza or 5.0) then
            elenco[#elenco + 1] = { id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)) }
        end
    end
    if #elenco == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '⛪', titolo = titolo,
            testo = 'Non c\'è nessuno abbastanza vicino.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, voci = elenco })
end

-- ---------------------------------------------------------------------------
--  Altare
-- ---------------------------------------------------------------------------
local function altare()
    CreateThread(function()
        local voci = {}
        for id, r in pairs(CHI.Riti) do
            voci[#voci + 1] = { id = id, icona = r.icona, titolo = r.nome,
                descrizione = ('%s%s'):format(
                    r.richiedeMatrimonioCivile and 'Serve il matrimonio civile già celebrato. ' or '',
                    r.offertaSuggerita > 0
                        and ('Offerta suggerita %s.'):format(AUREA.Util.Euro(r.offertaSuggerita))
                        or 'Nessuna offerta prevista.') }
        end

        local rito = exports.aurea_ui:Menu({
            titolo = 'Altare', sottotitolo = 'Chi partecipa deve essere qui', voci = voci })
        if not rito then return end

        local r = CHI.GetRito(rito)
        local a = vicini('Per chi si celebra')
        if not a then return end

        local b
        if r.partecipanti >= 2 or r.richiedePadrino then
            b = vicini(r.richiedePadrino and 'Chi fa da padrino' or 'E l\'altra parte')
            if not b then return end
        end

        if not exports.aurea_ui:Progresso({ etichetta = r.nome,
                                            durata = r.secondi * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('chi:celebra', rito, tonumber(a), b and tonumber(b) or nil)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⛪',
            titolo = 'Parrocchia', testo = tostring(messaggio), durata = 18000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Confessionale
-- ---------------------------------------------------------------------------
local function confessionale()
    CreateThread(function()
        local chi = vicini('Chi c\'è dall\'altra parte', 4.0)
        if not chi then return end

        local ok, esito = AUREA.Callback.Attendi('chi:confessa', tonumber(chi))
        if not ok then
            return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🕊',
                titolo = 'Confessionale', testo = tostring(esito), durata = 14000 })
        end

        confessoreDi = esito
        exports.aurea_ui:Notifica({
            tipo = 'info', icona = '🕊', durata = 16000,
            titolo = 'Confessionale',
            testo = ('Scrivi con /dico. Quello che dici non finisce da nessuna parte: %s.')
                :format(CHI.Segreto.articolo),
        })
    end)
end

RegisterCommand('dico', function(_, args)
    if not confessoreDi then
        return exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🕊',
            titolo = 'Confessionale', testo = 'Non sei in confessionale.' })
    end
    local testo = table.concat(args, ' ')
    if #testo < 1 then return end

    TriggerServerEvent('chi:dico', confessoreDi, testo:sub(1, CHI.Confessione.caratteriMassimi))
    exports.aurea_ui:Notifica({ tipo = 'successo', icona = '🕊', durata = 6000,
        titolo = 'Detto', testo = 'Resta fra voi due.' })
end, false)

-- ---------------------------------------------------------------------------
--  Mensa e offertorio
-- ---------------------------------------------------------------------------
local function mensa()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('chi:stato') or {}
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Mensa parrocchiale',
            sottotitolo = ('%d porzioni in dispensa'):format(s.scorta or 0),
            voci = {
                { id = 'mangia', icona = '🍲', titolo = 'Chiedi un pasto',
                  descrizione = 'Per chi non ha lavoro, o per chi ha fame davvero.' },
            },
        })
        if scelta ~= 'mangia' then return end

        local ok, messaggio = AUREA.Callback.Attendi('chi:mensa')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🍲',
            titolo = 'Mensa', testo = tostring(messaggio), durata = 16000,
        })
    end)
end

local function offertorio()
    CreateThread(function()
        local s = AUREA.Callback.Attendi('chi:stato') or {}

        local voci = { { id = 'denaro', icona = '💶', titolo = 'Offri del denaro',
            descrizione = ('Il %d%% va alla mensa e diventa porzioni.')
                :format(math.floor(CHI.Offertorio.quotaAllaMensa * 100)) } }

        for item, porzioni in pairs(CHI.Mensa.offerteInNatura) do
            voci[#voci + 1] = { id = 'n:' .. item, icona = '🧺',
                titolo = AUREA.Item[item] and AUREA.Item[item].etichetta or item,
                descrizione = ('%d porzioni per unità'):format(porzioni) }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Offertorio',
            sottotitolo = ('Dispensa: %d porzioni'):format(s.scorta or 0),
            voci = voci,
        })
        if not scelta then return end

        local item = scelta:match('^n:(.+)$')
        local r = exports.aurea_ui:Dialogo(item and 'Quante unità' or 'Quanto offri', {
            { etichetta = item and 'Quantità' or 'Euro', tipo = 'number',
              valore = 1, min = 1, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('chi:offri', item or 'denaro', tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧺',
            titolo = 'Offertorio', testo = tostring(messaggio), durata = 16000,
        })
    end)
end

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(CHI.Parrocchia.coord)
    SetBlipSprite(b, CHI.Parrocchia.blip.sprite)
    SetBlipColour(b, CHI.Parrocchia.blip.colore)
    SetBlipScale(b, CHI.Parrocchia.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(CHI.Parrocchia.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('chi_altare', CHI.Parrocchia.altare, 2.5, {
        { etichetta = 'Altare', icona = '⛪', lavoro = CHI.Lavoro, azione = altare },
    })
    exports.aurea_target:AggiungiZona('chi_confessionale', CHI.Parrocchia.confessionale, 2.2, {
        { etichetta = 'Confessionale', icona = '🕊', azione = confessionale },
    })
    exports.aurea_target:AggiungiZona('chi_mensa', CHI.Parrocchia.mensa, 2.5, {
        { etichetta = 'Mensa parrocchiale', icona = '🍲', azione = mensa },
    })
    exports.aurea_target:AggiungiZona('chi_offertorio', CHI.Parrocchia.offertorio, 2.0, {
        { etichetta = 'Offertorio', icona = '🧺', azione = offertorio },
    })
end)
