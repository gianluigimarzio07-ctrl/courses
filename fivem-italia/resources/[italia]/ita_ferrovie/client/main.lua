--[[
    AUREA · Ferrovie (client)

    L'orario arriva dal server insieme alla corsa: ogni fermata ha un
    istante previsto, e qui si disegna soltanto quanto manca. Il ritardo
    non lo calcola il client.
]]

local corsa = nil
local chiuse = {}
local dentroPl = nil

RegisterNetEvent('fer:corsa', function(c)
    if c.aggiornamento and corsa and corsa.id == c.id then
        corsa.corrente = c.corrente
        return
    end
    corsa = c
end)

RegisterNetEvent('fer:corsaChiusa', function(id)
    if corsa and corsa.id == id then corsa = nil end
end)

RegisterNetEvent('fer:sbarre', function(elenco)
    chiuse = {}
    for _, id in ipairs(elenco or {}) do chiuse[id] = true end
end)

-- ---------------------------------------------------------------------------
--  La prossima fermata
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1500

        if corsa and corsa.fermate then
            local prossima = corsa.fermate[corsa.corrente + 1]
            if prossima then
                attesa = 0
                local coord = GetEntityCoords(PlayerPedId())
                local d = #(coord - vector3(prossima.x, prossima.y, prossima.z))

                if d < 120.0 then
                    DrawMarker(1, prossima.x, prossima.y, prossima.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        8.0, 8.0, 1.5, 70, 130, 200, 90, false, false, 2, false)
                end

                if d <= 30.0 then
                    exports.aurea_ui:Prompt(true, ('Ferma a %s'):format(prossima.nome), 'E')
                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        CreateThread(function()
                            local ok, messaggio = AUREA.Callback.Attendi('fer:fermata')
                            exports.aurea_ui:Notifica({
                                tipo = ok and 'successo' or 'errore', icona = '🚆',
                                titolo = 'Servizio', testo = tostring(messaggio), durata = 14000 })
                        end)
                        Wait(2000)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Passaggi a livello
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local coord = GetEntityCoords(PlayerPedId())
        local vicino = nil

        for _, pl in ipairs(FER.PassaggiLivello) do
            local d = #(coord - pl.coord)
            if d <= 80.0 then
                attesa = 0
                if chiuse[pl.id] then
                    -- Una barra rossa a terra: le sbarre vere sarebbero
                    -- props, e quelle stanno nella mappa, non qui
                    DrawMarker(43, pl.coord.x, pl.coord.y, pl.coord.z + 1.2, 0.0, 0.0, 0.0,
                        0.0, 0.0, 90.0, 10.0, 0.4, 2.0, 220, 40, 40, 160, false, false, 2, false)
                    if d <= FER.Sbarre.raggio then vicino = pl end
                end
            end
        end

        -- Entrare sul passaggio chiuso, in auto: una volta sola per
        -- attraversamento, non una multa ogni secondo
        if vicino and IsPedInAnyVehicle(PlayerPedId(), false) then
            if dentroPl ~= vicino.id then
                dentroPl = vicino.id
                CreateThread(function()
                    local ok = AUREA.Callback.Attendi('fer:forzato', vicino.id)
                    if ok then
                        exports.aurea_ui:Notifica({
                            tipo = 'errore', icona = '🚆', durata = 18000,
                            titolo = FER.Sbarre.articolo,
                            testo = ('Passaggio a livello con barriere chiuse: %s e %d punti.\nÈ la violazione che uccide più gente di tutte.')
                                :format(AUREA.Util.Euro(FER.Sbarre.sanzione), FER.Sbarre.punti) })
                    end
                end)
            end
        elseif not vicino then
            dentroPl = nil
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Stazione
-- ---------------------------------------------------------------------------
local function stazione(s)
    CreateThread(function()
        local linee = AUREA.Callback.Attendi('fer:linee') or {}

        local voci = {}
        for _, l in ipairs(linee) do
            voci[#voci + 1] = { id = 'b:' .. l.id, icona = '🎫',
                titolo = ('Biglietto — %s'):format(l.nome),
                descrizione = ('%s · %s · %d minuti di percorso'):format(
                    AUREA.Util.Euro(l.prezzo), table.concat(l.fermate, ' → '), l.minuti) }
        end

        voci[#voci + 1] = { id = 'oblitera', icona = '🖊', titolo = 'Oblitera il biglietto',
            descrizione = ('Vale %d minuti da adesso. Senza, il capotreno ti fa la sanzione.')
                :format(FER.Biglietti.validitaMinuti) }

        for _, l in ipairs(linee) do
            voci[#voci + 1] = { id = 'p:' .. l.id, icona = '🚆',
                titolo = ('Prendi servizio — %s'):format(l.nome),
                descrizione = l.occupata and 'C\'è già un convoglio su questa linea.'
                    or ('Compenso %s, più il premio se arrivi in orario.')
                        :format(AUREA.Util.Euro(l.compenso)),
                disattivata = l.occupata }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = s.nome, sottotitolo = 'Servizio ferroviario', voci = voci })
        if not scelta then return end

        if scelta == 'oblitera' then
            local ok, messaggio = AUREA.Callback.Attendi('fer:obliteraBiglietto')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🖊',
                titolo = 'Obliteratrice', testo = tostring(messaggio), durata = 12000 })
        end

        local biglietto = scelta:match('^b:(.+)$')
        if biglietto then
            local ok, messaggio = AUREA.Callback.Attendi('fer:biglietto', biglietto)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🎫',
                titolo = 'Biglietteria', testo = tostring(messaggio), durata = 14000 })
        end

        local linea = scelta:match('^p:(.+)$')
        if not linea then return end

        local ok, messaggio = AUREA.Callback.Attendi('fer:parti', linea)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚆',
            titolo = 'Deposito', testo = tostring(messaggio), durata = 20000,
        })
    end)
end

AddEventHandler('aurea:client:caricato', function()
    for _, s in ipairs(FER.Stazioni) do
        local b = AddBlipForCoord(s.coord)
        SetBlipSprite(b, 513)
        SetBlipColour(b, 4)
        SetBlipScale(b, 0.7)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(s.nome)
        EndTextCommandSetBlipName(b)

        exports.aurea_target:AggiungiZona('fer_' .. s.id, s.coord, 3.0, {
            { etichetta = 'Biglietteria', icona = '🚆', azione = function() stazione(s) end },
        })
    end
end)
