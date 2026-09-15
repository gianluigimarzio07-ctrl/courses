--[[
    AUREA · Vigilanza privata (client)

    Il servizio in corso lo vedi tu; il furgone lo vedono tutti, perché è
    un furgone blindato in mezzo alla strada. L'unica cosa che il client
    riceve e gli altri no è la destinazione precisa.
]]

local servizio = nil
local blipDa, blipA = nil, nil

local function pulisci()
    if blipDa then RemoveBlip(blipDa) blipDa = nil end
    if blipA then RemoveBlip(blipA) blipA = nil end
end

local function segna(coord, colore, testo)
    local b = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(b, 67)
    SetBlipColour(b, colore)
    SetBlipScale(b, 0.85)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, colore)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(testo)
    EndTextCommandSetBlipName(b)
    return b
end

RegisterNetEvent('sic:servizio', function(s)
    pulisci()
    servizio = s
    if not s then return end

    if s.stato == 'da_caricare' then
        blipDa = segna(s.da, 5, ('Carico — %s'):format(s.da.nome))
    else
        blipA = segna(s.a, 2, ('Consegna — %s'):format(s.a.nome))
    end
end)

RegisterNetEvent('sic:avviso', function(a)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🚚', durata = 18000,
        titolo = 'Portavalori in transito',
        testo = ('Un furgone blindato è uscito da una filiale con %s a bordo, diretto a %s.')
            :format(AUREA.Util.Euro(a.valore), a.verso),
    })
end)

-- ---------------------------------------------------------------------------
--  Carico e consegna
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 900

        if servizio then
            local coord = GetEntityCoords(PlayerPedId())
            local punto = servizio.stato == 'da_caricare' and servizio.da or servizio.a
            local d = #(coord - vector3(punto.x, punto.y, punto.z))

            if d < 40.0 then
                attesa = 0
                DrawMarker(1, punto.x, punto.y, punto.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    2.0, 2.0, 1.0, 60, 120, 200, 110, false, false, 2, false)

                if d < 3.0 then
                    local etichetta = servizio.stato == 'da_caricare'
                        and 'Carica i valori' or 'Consegna i valori'
                    exports.aurea_ui:Prompt(true, etichetta, 'E')

                    if IsControlJustReleased(0, 38) then
                        exports.aurea_ui:Prompt(false)
                        CreateThread(function()
                            if not exports.aurea_ui:Progresso({ etichetta = etichetta,
                                                                durata = 8000, annullabile = true }) then return end
                            local ok, messaggio = AUREA.Callback.Attendi(
                                servizio.stato == 'da_caricare' and 'sic:carica' or 'sic:consegna',
                                servizio.id)
                            if ok and servizio and servizio.stato == 'da_caricare' then
                                servizio.stato = 'in_viaggio'
                                pulisci()
                                blipA = segna(servizio.a, 2, ('Consegna — %s'):format(servizio.a.nome))
                            end
                            exports.aurea_ui:Notifica({
                                tipo = ok and 'successo' or 'errore', icona = '🚚',
                                titolo = 'Portavalori', testo = tostring(messaggio), durata = 16000 })
                        end)
                        Wait(1200)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  L'assalto: davanti al portellone di un furgone in viaggio
-- ---------------------------------------------------------------------------
RegisterCommand('forzaportellone', function()
    CreateThread(function()
        local inStrada = AUREA.Callback.Attendi('sic:inStrada') or {}
        if #inStrada == 0 then
            return exports.aurea_ui:Notifica({ tipo = 'info', icona = '🚚',
                titolo = 'Niente', testo = 'Nessun furgone carico in giro.' })
        end

        local voci = {}
        for _, s in ipairs(inStrada) do
            voci[#voci + 1] = { id = tostring(s.id), icona = '🚚',
                titolo = ('Furgone diretto a %s'):format(s.verso),
                descrizione = ('A bordo %s. Devi averlo davanti.'):format(AUREA.Util.Euro(s.valore)) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Portellone', sottotitolo = 'Ci vuole tempo, e si sente', voci = voci })
        if not scelta then return end

        if not exports.aurea_ui:Progresso({
            etichetta = 'Forzatura del portellone',
            durata = SIC.Portavalori.secondiScasso * 1000, annullabile = true }) then return end

        local ok, messaggio = AUREA.Callback.Attendi('sic:assalta', tonumber(scelta))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🚚',
            titolo = 'Portavalori', testo = tostring(messaggio), durata = 18000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  L'istituto
-- ---------------------------------------------------------------------------
local function vicini(titolo)
    local elenco, ped = {}, PlayerPedId()
    local coord = GetEntityCoords(ped)
    for _, p in ipairs(GetActivePlayers()) do
        local altro = GetPlayerPed(p)
        if altro ~= ped and #(coord - GetEntityCoords(altro)) <= 4.0 then
            elenco[#elenco + 1] = { id = tostring(GetPlayerServerId(p)), icona = '👤',
                titolo = ('ID %d'):format(GetPlayerServerId(p)) }
        end
    end
    if #elenco == 0 then
        exports.aurea_ui:Notifica({ tipo = 'errore', icona = '🛡', titolo = titolo,
            testo = 'Non c\'è nessuno davanti a te.' })
        return nil
    end
    return exports.aurea_ui:Menu({ titolo = titolo, voci = elenco })
end

local function istituto()
    CreateThread(function()
        local voci = {
            { id = 'portavalori', icona = '🚚', titolo = 'Prendi un servizio portavalori',
              descrizione = ('Da filiale a filiale. %d minuti di tempo.'):format(SIC.Portavalori.limiteMinuti) },
            { id = 'presidio', icona = '🛡', titolo = 'Assegnati a un presidio',
              descrizione = ('%s ogni %d minuti sul posto.')
                  :format(AUREA.Util.Euro(SIC.Piantonamento.compensoPerTurno), SIC.Piantonamento.minutiPerTurno) },
            { id = 'giura', icona = '⚖', titolo = 'Fai giurare una guardia',
              descrizione = 'Solo per ufficiali di pubblica sicurezza in servizio.' },
        }

        local scelta = exports.aurea_ui:Menu({
            titolo = SIC.Istituto.nome, sottotitolo = 'Servizi di vigilanza', voci = voci })
        if not scelta then return end

        if scelta == 'giura' then
            local chi = vicini('Chi presta giuramento')
            if not chi then return end
            local ok, messaggio = AUREA.Callback.Attendi('sic:giura', tonumber(chi))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '⚖',
                titolo = 'Questura', testo = tostring(messaggio), durata = 18000 })
        end

        if scelta == 'portavalori' then
            local ok, messaggio = AUREA.Callback.Attendi('sic:portavalori')
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🚚',
                titolo = 'Portavalori', testo = tostring(messaggio), durata = 20000 })
        end

        local obiettivi = {}
        for _, o in ipairs(SIC.Obiettivi) do
            obiettivi[#obiettivi + 1] = { id = o.id, icona = '🛡', titolo = o.nome }
        end
        local o = exports.aurea_ui:Menu({
            titolo = 'Presidio', sottotitolo = 'Devi essere già sul posto', voci = obiettivi })
        if not o then return end

        local ok, messaggio = AUREA.Callback.Attendi('sic:piantona', o)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🛡',
            titolo = 'Presidio', testo = tostring(messaggio), durata = 16000,
        })
    end)
end

RegisterCommand('vigilanza', istituto, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(SIC.Istituto.coord)
    SetBlipSprite(b, SIC.Istituto.blip.sprite)
    SetBlipColour(b, SIC.Istituto.blip.colore)
    SetBlipScale(b, SIC.Istituto.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(SIC.Istituto.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('sic_istituto', SIC.Istituto.coord, SIC.Istituto.raggio, {
        { etichetta = 'Istituto di vigilanza', icona = '🛡', azione = istituto },
    })
end)
