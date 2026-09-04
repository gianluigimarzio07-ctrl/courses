--[[
    AUREA · Made in Italy (client)
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Blip delle postazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    for _, f in pairs(MIT.Filiere) do
        local prima = f.postazioni[1]
        if prima then
            local blip = AddBlipForCoord(prima.coord.x, prima.coord.y, prima.coord.z)
            SetBlipSprite(blip, 478)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(f.etichetta)
            EndTextCommandSetBlipName(blip)
        end
    end

    local c = MIT.Consorzio
    local blip = AddBlipForCoord(c.coord.x, c.coord.y, c.coord.z)
    SetBlipSprite(blip, c.blip.sprite) SetBlipColour(blip, c.blip.colore)
    SetBlipScale(blip, c.blip.scala) SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentString(c.nome) EndTextCommandSetBlipName(blip)
end)

-- ---------------------------------------------------------------------------
--  Interazione con le postazioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        local coord = GetEntityCoords(PlayerPedId())
        local trovata = nil

        for idFiliera, f in pairs(MIT.Filiere) do
            for _, p in ipairs(f.postazioni) do
                local d = #(coord - p.coord)
                if d < 18.0 then
                    attesa = 0
                    DrawMarker(2, p.coord.x, p.coord.y, p.coord.z + 0.5, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                        0.28, 0.28, 0.2, 212, 175, 55, 150, false, false, 2, true, nil, nil, false)
                    if d < 2.2 then trovata = { filiera = idFiliera, f = f, p = p } end
                end
            end
        end

        if trovata then
            exports.aurea_ui:Prompt(true, ('%s %s'):format(trovata.f.icona, trovata.p.nome), 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuPostazione(trovata.filiera, trovata.f, trovata.p)
            end
        else
            exports.aurea_ui:Prompt(false)
            if attesa == 0 then attesa = 300 end
        end

        if #(coord - MIT.Consorzio.coord) < 2.2 then
            attesa = 0
            exports.aurea_ui:Prompt(true, MIT.Consorzio.nome, 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                menuConsorzio()
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Menu della postazione
-- ---------------------------------------------------------------------------
function menuPostazione(idFiliera, filiera, postazione)
    CreateThread(function()
        local voci = {}

        local richieste = {}
        for _, r in ipairs(postazione.richiede or {}) do
            local dati = AUREA.Item[r.item]
            richieste[#richieste + 1] = ('%d× %s'):format(r.quantita, dati and dati.etichetta or r.item)
        end

        voci[#voci + 1] = {
            id = 'lavora', icona = filiera.icona,
            titolo = postazione.azione,
            descrizione = #richieste > 0 and ('Richiede: %s'):format(table.concat(richieste, ', ')) or 'Nessuna materia prima necessaria.',
            valore = postazione.affinamentoMinuti and ('affina %d min'):format(postazione.affinamentoMinuti) or nil,
        }

        if postazione.affinamentoMinuti then
            voci[#voci + 1] = { id = 'ritira', icona = '⏳', titolo = 'Ritira i lotti in affinamento' }
        end

        voci[#voci + 1] = { id = 'maestria', icona = '🏅', titolo = 'La tua maestria',
            descrizione = ('Disciplina: %s'):format(filiera.disciplina) }

        local scelta = exports.aurea_ui:Menu({
            titolo = postazione.nome,
            sottotitolo = filiera.etichetta,
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'lavora' then
            lavora(idFiliera, filiera, postazione)
        elseif scelta == 'ritira' then
            ritiraLotti(idFiliera)
        elseif scelta == 'maestria' then
            mostraMaestria()
        end
    end)
end

function lavora(idFiliera, filiera, postazione)
    local ok, errore, dati = AUREA.Callback.Attendi('mit:avvia', idFiliera, postazione.id)
    if not ok then
        return exports.aurea_ui:Notifica({ tipo = 'errore', titolo = 'Lavorazione non avviata', testo = errore, durata = 9000 })
    end

    local precisione = 0.7

    if dati.precisione then
        -- Le lavorazioni delicate richiedono di fermarsi al momento giusto:
        -- si tiene premuto E e si rilascia quando la barra è nella finestra.
        precisione = provaPrecisione(dati)
    else
        local completata = exports.aurea_ui:Progresso({
            etichetta = ('%s in corso...'):format(dati.azione),
            durata = dati.durata,
            annullabile = true,
            anim = dati.anim,
            blocca = { movimento = true },
        })
        if not completata then
            return exports.aurea_ui:Notifica({ tipo = 'avviso', titolo = 'Lavorazione interrotta', testo = 'Le materie prime non sono state consumate.' })
        end
        precisione = 0.72 + math.random() * 0.18
    end

    local esito, messaggio = AUREA.Callback.Attendi('mit:concludi', precisione)
    exports.aurea_ui:Notifica({
        tipo = esito and 'successo' or 'errore',
        icona = filiera.icona,
        titolo = esito and 'Lavorazione completata' or 'Lavorazione non riuscita',
        testo = messaggio, durata = 13000,
    })
end

--- Minigioco di precisione: fermare l'indicatore nella zona verde.
function provaPrecisione(dati)
    local durata = dati.durata
    local inizio = GetGameTimer()
    local finestraCentro = 0.55 + math.random() * 0.2
    local finestraAmpiezza = 0.14
    local fermato = nil

    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '🎯', durata = 4000,
        titolo = 'Lavorazione delicata',
        testo = 'Premi SPAZIO quando l\'indicatore entra nella zona verde.',
    })

    AUREA.Anima(dati.anim and dati.anim.dizionario or 'amb@world_human_hammering@male@base',
        dati.anim and dati.anim.nome or 'base', durata, 49)

    while GetGameTimer() - inizio < durata do
        Wait(0)
        local avanzamento = (GetGameTimer() - inizio) / durata

        -- barra disegnata a schermo
        DrawRect(0.5, 0.86, 0.34, 0.028, 12, 13, 18, 200)
        DrawRect(0.5 - 0.17 + (finestraCentro * 0.34), 0.86, finestraAmpiezza * 0.34, 0.028, 31, 157, 85, 190)
        DrawRect(0.5 - 0.17 + (avanzamento * 0.34), 0.86, 0.004, 0.036, 244, 244, 244, 240)

        DisableControlAction(0, 22, true)
        if IsDisabledControlJustPressed(0, 22) then
            fermato = avanzamento
            break
        end
    end

    ClearPedTasks(PlayerPedId())

    if not fermato then return 0.25 end

    local scarto = math.abs(fermato - finestraCentro)
    if scarto <= finestraAmpiezza / 2 then
        return 1.0 - (scarto / (finestraAmpiezza / 2)) * 0.15
    end
    return math.max(0.15, 0.6 - scarto)
end

-- ---------------------------------------------------------------------------
--  Lotti in affinamento
-- ---------------------------------------------------------------------------
function ritiraLotti(idFiliera)
    CreateThread(function()
        local lotti = AUREA.Callback.Attendi('mit:lottiPronti', idFiliera) or {}
        if #lotti == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '⏳', titolo = 'Nessun lotto', testo = 'Non hai lotti in affinamento per questa filiera.' })
        end

        local voci = {}
        for _, l in ipairs(lotti) do
            voci[#voci + 1] = {
                id = l.id,
                icona = l.pronto and '✅' or '⏳',
                titolo = ('%s — lotto %s'):format(l.etichetta, l.lotto),
                descrizione = l.pronto and 'Pronto per il ritiro'
                    or ('Mancano %d minuti'):format(l.minuti_mancanti or 0),
                valore = ('qualità %d'):format(l.qualita),
                disattivata = not l.pronto,
            }
        end

        local id = exports.aurea_ui:Menu({ titolo = 'Lotti in affinamento', sottotitolo = 'L\'attesa migliora il prodotto', voci = voci })
        if not id then return end

        local ok, messaggio = AUREA.Callback.Attendi('mit:ritira', id)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '⏳', titolo = ok and 'Lotto ritirato' or 'Ritiro non riuscito',
            testo = messaggio, durata = 12000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Consorzio di tutela
-- ---------------------------------------------------------------------------
function menuConsorzio()
    CreateThread(function()
        local lotti = AUREA.Callback.Attendi('mit:certificabili') or {}

        if #lotti == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🏛', durata = 11000,
                titolo = MIT.Consorzio.nome,
                testo = 'Nessun lotto certificabile. Serve qualità almeno 60 per la IGP, 78 per la DOP, 88 per la DOCG.',
            })
        end

        local voci = {}
        for _, l in ipairs(lotti) do
            voci[#voci + 1] = {
                id = l.slot, icona = '🏅',
                titolo = ('%s — lotto %s'):format(l.etichetta, l.lotto),
                descrizione = ('Qualità %d/100 · certificabile %s (+%d%% di valore)'):format(
                    l.qualita, l.certificazioneEtichetta, math.floor((l.moltiplicatore - 1) * 100)),
                valore = U.Euro(l.costo),
            }
        end

        local slot = exports.aurea_ui:Menu({
            titolo = MIT.Consorzio.nome,
            sottotitolo = 'La certificazione è definitiva e segue il lotto',
            voci = voci,
        })
        if not slot then return end

        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Analisi organolettica e pratica di certificazione...',
            durata = 12000, annullabile = true, blocca = { movimento = true },
        })
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('mit:certifica', slot)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = '🏅', titolo = ok and 'Certificazione rilasciata' or 'Certificazione negata',
            testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Maestria
-- ---------------------------------------------------------------------------
function mostraMaestria()
    CreateThread(function()
        local discipline = AUREA.Callback.Attendi('mit:maestria') or {}

        local voci = {}
        for _, d in ipairs(discipline) do
            voci[#voci + 1] = {
                id = d.disciplina, icona = '🏅',
                titolo = ('%s — %s'):format(d.disciplina:gsub('^%l', string.upper), d.titolo),
                descrizione = d.prossima
                    and ('%d XP · mancano %d al livello successivo'):format(d.xp, d.prossima - d.xp)
                    or ('%d XP · livello massimo raggiunto'):format(d.xp),
                valore = ('liv. %d'):format(d.livello),
                disattivata = true,
            }
        end

        if #voci == 0 then
            voci[1] = { id = 'v', icona = '—', titolo = 'Nessuna disciplina avviata',
                descrizione = 'Lavora in una filiera per iniziare ad accumulare maestria.', disattivata = true }
        end

        exports.aurea_ui:Menu({
            titolo = 'La tua maestria',
            sottotitolo = 'Ogni livello aggiunge 4 punti di qualità ai tuoi lotti',
            voci = voci,
        })
    end)
end

RegisterCommand('maestria', function() mostraMaestria() end, false)
