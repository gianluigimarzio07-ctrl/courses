--[[
    AUREA · Palestra (client)

    Le statistiche arrivano dal server e qui diventano quello che si sente
    giocando: la corsa che non finisce, il pugno che fa male.
]]

local U = AUREA.Util
local mie = { forza = 0, resistenza = 0 }
local occupato = false

CreateThread(function()
    for n, s in ipairs(PAL.Sedi) do
        local b = AddBlipForCoord(s.coord.x, s.coord.y, s.coord.z)
        SetBlipSprite(b, PAL.Blip.sprite)
        SetBlipColour(b, PAL.Blip.colore)
        SetBlipScale(b, PAL.Blip.scala)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(s.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('palestra_' .. n, s.coord, 3.0, {
            { etichetta = 'Allenati', icona = '🏋', azione = function() apri() end },
        })
    end
end)

RegisterNetEvent('pal:aggiorna', function(dati)
    mie = dati or mie
    applica()
end)

--- La resistenza è la stamina del gioco; la forza il danno a mani nude.
function applica()
    local giocatore = PlayerId()

    -- La resistenza mappa direttamente sulla stamina nativa
    StatSetInt(GetHashKey('MP0_STAMINA'), math.floor(mie.resistenza or 0), true)
    StatSetInt(GetHashKey('MP0_STRENGTH'), math.floor(mie.forza or 0), true)

    -- Il moltiplicatore di danno in mischia scala con la forza
    local s = PAL.Statistiche.forza
    local fattore = 1.0 + ((mie.forza or 0) / s.massimo) * (s.moltiplicatoreDanno - 1.0)
    SetPlayerMeleeWeaponDamageModifier(giocatore, fattore)

    -- Chi è allenato incassa un po' meglio
    SetPlayerWeaponDamageModifier(giocatore, 1.0)
    SetPlayerHealthRechargeMultiplier(giocatore, 1.0 + ((mie.resistenza or 0) / 400))
end

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function() Wait(3000) applica() end)
end)

function apri()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('pal:stato')
        if not dati then return end

        local voci = {}
        for _, s in ipairs(dati.statistiche) do
            voci[#voci + 1] = {
                id = '_' .. s.id, icona = s.icona,
                titolo = ('%s — %d su %d'):format(s.nome, s.valore, s.massimo),
                descrizione = s.descrizione, disattivata = true,
            }
        end

        voci[#voci + 1] = {
            id = 'abbonamento', icona = '🎫',
            titolo = ('Ingressi: %d'):format(dati.ingressi),
            descrizione = ('Rinnova: %d ingressi.'):format(PAL.Regole.ingressiPerAbbonamento),
            valore = U.Euro(dati.costo * PAL.Regole.ingressiPerAbbonamento),
        }

        for _, e in ipairs(dati.esercizi) do
            voci[#voci + 1] = {
                id = e.id, icona = e.icona, titolo = e.nome,
                descrizione = ('Allena %s.'):format(e.statistica),
                valore = ('+%d'):format(e.punti),
                disattivata = dati.ingressi <= 0,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Palestra',
            sottotitolo = 'Quello che guadagni qui si sente in strada — e si perde stando fermi',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        if scelta == 'abbonamento' then
            local ok, messaggio = AUREA.Callback.Attendi('pal:abbonamento')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🎫',
                titolo = 'Abbonamento', testo = messaggio, durata = 11000,
            })
        end

        allena(scelta)
    end)
end

function allena(id)
    CreateThread(function()
        if occupato then return end

        local ok, dati = AUREA.Callback.Attendi('pal:allena', id)
        if not ok then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🏋', titolo = 'Palestra',
                testo = tostring(dati), durata = 10000,
            })
        end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = dati.nome, durata = dati.durata, annullabile = true,
            anim = dati.anim, blocca = { movimento = true },
        })
        occupato = false
        if not completato then
            return exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '🏋', titolo = 'Serie interrotta',
                testo = 'Non conta.', durata = 8000,
            })
        end

        local fatto, messaggio = AUREA.Callback.Attendi('pal:concludi')
        exports.aurea_ui:Notifica({
            tipo = fatto and 'successo' or 'errore', icona = '💪',
            titolo = 'Allenamento', testo = messaggio, durata = 12000,
        })
    end)
end

RegisterCommand('forma', function()
    exports.aurea_ui:Notifica({
        tipo = 'info', icona = '💪', durata = 11000,
        titolo = 'La tua forma',
        testo = ('Forza %d · Resistenza %d'):format(mie.forza or 0, mie.resistenza or 0),
    })
end, false)
