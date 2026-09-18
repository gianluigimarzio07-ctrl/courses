--[[
    AUREA · Agricoltura (client)

    I solchi sono marker a terra. Quello che ci cresce dentro lo sa il
    server: qui arriva già scritto cosa c'è, se è maturo e quanta
    fertilità è rimasta.
]]

local stato = nil

local function aggiorna()
    stato = AUREA.Callback.Attendi('agr:solchi')
    return stato
end

--- Il solco più vicino, se sono su un podere.
local function solcoVicino()
    if not stato then return nil end
    local p = AGR.GetPodere(stato.podere)
    if not p then return nil end

    local coord = GetEntityCoords(PlayerPedId())
    local angoloPasso = (math.pi * 2) / p.solchi

    for n = 1, p.solchi do
        local a = angoloPasso * (n - 1)
        local punto = vector3(
            p.centro.x + math.cos(a) * (p.raggio * 0.55),
            p.centro.y + math.sin(a) * (p.raggio * 0.55),
            p.centro.z)
        if #(coord - punto) <= 6.0 then return n, punto end
    end
end

--- La posizione di un solco: calcolata allo stesso modo su tutti i client,
--- perché dipende solo dal podere e dal numero.
local function puntoSolco(p, n)
    local a = ((math.pi * 2) / p.solchi) * (n - 1)
    return vector3(
        p.centro.x + math.cos(a) * (p.raggio * 0.55),
        p.centro.y + math.sin(a) * (p.raggio * 0.55),
        p.centro.z)
end

-- ---------------------------------------------------------------------------
--  I marker
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1500
        local coord = GetEntityCoords(PlayerPedId())

        for _, p in ipairs(AGR.Poderi) do
            if #(coord - p.centro) <= p.raggio + 20.0 then
                attesa = 0
                if not stato or stato.podere ~= p.id then
                    CreateThread(aggiorna)
                end

                for n = 1, p.solchi do
                    local punto = puntoSolco(p, n)
                    if #(coord - punto) < 45.0 then
                        local s = stato and stato.solchi and stato.solchi[n]
                        local r, v, b = 150, 110, 70            -- terra nuda
                        if s and s.coltura then
                            if s.maturo then r, v, b = 230, 190, 50   -- maturo
                            else r, v, b = 90, 170, 80 end            -- in crescita
                        elseif s and s.arato then r, v, b = 190, 150, 100 end

                        DrawMarker(1, punto.x, punto.y, punto.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            5.0, 5.0, 0.6, r, v, b, 90, false, false, 2, false)
                    end
                end
            end
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Lavorare un solco
-- ---------------------------------------------------------------------------
local function lavora(n, azione, coltura)
    CreateThread(function()
        local def = AGR.Lavorazioni[azione]
        if def then
            if not exports.aurea_ui:Progresso({ etichetta = def.etichetta,
                                                durata = def.secondi * 1000,
                                                annullabile = true }) then return end
        end

        local ok, messaggio = AUREA.Callback.Attendi('agr:lavora', n, azione, coltura)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🌾',
            titolo = 'Campo', testo = tostring(messaggio), durata = 16000,
        })
        if ok then aggiorna() end
    end)
end

local function pannelloSolco(n)
    CreateThread(function()
        if not aggiorna() then return end
        local s = stato.solchi[n]
        if not s then return end

        local voci = {
            { id = 'x', disattivata = true, icona = s.icona or '🟫',
              titolo = s.coltura and ('%s — %s'):format(s.nomeColtura,
                    s.maturo and 'pronto' or ('%d minuti'):format(s.minutiResidui))
                  or (s.arato and 'Solco arato' or 'Terra da arare'),
              descrizione = ('Fertilità %d%%%s%s'):format(s.fertilita,
                  s.coltura and (' · irrigato %d/%d'):format(s.irrigazioni, s.ottimali) or '',
                  s.inStagione == false and ' · FUORI STAGIONE' or '') },
        }

        if s.maturo then
            voci[#voci + 1] = { id = 'raccolta', icona = '🧺', titolo = 'Raccogli' }
        elseif s.coltura then
            voci[#voci + 1] = { id = 'irrigazione', icona = '💧', titolo = 'Irriga',
                descrizione = ('Ne vuole %d in tutto. Di più non serve.'):format(s.ottimali) }
        elseif s.arato then
            for id, c in pairs(AGR.Colture) do
                voci[#voci + 1] = { id = 'sem:' .. id, icona = c.icona,
                    titolo = ('Semina %s'):format(c.nome),
                    descrizione = ('%s · matura in %d minuti · %d irrigazioni'):format(
                        AGR.InStagione(id, stato.stagione) and 'in stagione' or 'fuori stagione',
                        c.minutiMaturazione, c.irrigazioniOttimali) }
            end
        else
            voci[#voci + 1] = { id = 'aratura', icona = '🚜', titolo = 'Ara il solco',
                descrizione = 'Serve il trattore: a mano non si ara.' }
        end

        if s.fertilita < 90 then
            voci[#voci + 1] = { id = 'concime', icona = '🧪', titolo = 'Concima',
                descrizione = ('Restituisce %d punti di fertilità.'):format(AGR.Suolo.recuperoConcime) }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('%s — solco %d'):format(stato.nome, n),
            sottotitolo = ('Stagione: %s'):format(stato.stagione),
            voci = voci,
        })
        if not scelta or scelta == 'x' then return end

        local coltura = scelta:match('^sem:(.+)$')
        lavora(n, coltura and 'semina' or scelta, coltura)
    end)
end

CreateThread(function()
    while true do
        local attesa = 700
        local n, punto = solcoVicino()

        if n then
            exports.aurea_ui:Prompt(true, ('Solco %d'):format(n), 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                pannelloSolco(n)
                Wait(1200)
            end
        else
            attesa = 1200
        end

        Wait(attesa)
    end
end)

-- ---------------------------------------------------------------------------
--  Consorzio
-- ---------------------------------------------------------------------------
local function consorzio()
    CreateThread(function()
        local poderi, stagioneCorrente = AUREA.Callback.Attendi('agr:poderi')
        poderi = poderi or {}

        local voci = {}
        for item, prezzo in pairs(AGR.Listino) do
            voci[#voci + 1] = { id = 'c:' .. item, icona = '🌱',
                titolo = AUREA.Item[item] and AUREA.Item[item].etichetta or item,
                descrizione = AUREA.Util.Euro(prezzo) }
        end
        table.sort(voci, function(a, b) return a.titolo < b.titolo end)

        for _, p in ipairs(poderi) do
            voci[#voci + 1] = { id = 'p:' .. p.id,
                icona = p.mio and '✅' or (p.libero and '🌾' or '🔒'),
                titolo = p.nome,
                descrizione = ('%d ettari · %d solchi · canone %s%s'):format(
                    p.ettari, p.solchi, AUREA.Util.Euro(p.canone),
                    p.mio and ' · lo conduci tu' or (p.libero and ' · libero' or ' · occupato')),
                disattivata = not p.libero }
        end

        voci[#voci + 1] = { id = 'pac', icona = '📄', titolo = 'Presenta la domanda unica (PAC)',
            descrizione = ('%s a ettaro ogni %d minuti. Dichiarare più del vero è truffa.')
                :format(AUREA.Util.Euro(AGR.Pac.perEttaro), AGR.Pac.minuti) }

        local scelta = exports.aurea_ui:Menu({
            titolo = AGR.Consorzio.nome,
            sottotitolo = ('Stagione: %s'):format(stagioneCorrente or '—'),
            voci = voci,
        })
        if not scelta then return end

        if scelta == 'pac' then
            local r = exports.aurea_ui:Dialogo('Domanda unica', {
                { etichetta = 'Ettari che dichiari di coltivare', tipo = 'number',
                  min = 1, max = 100, obbligatorio = true },
            })
            if not r or not r[1] then return end
            local ok, messaggio = AUREA.Callback.Attendi('agr:pac', tonumber(r[1]))
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '📄',
                titolo = 'AGEA', testo = tostring(messaggio), durata = 20000 })
        end

        local podere = scelta:match('^p:(.+)$')
        if podere then
            local ok, messaggio = AUREA.Callback.Attendi('agr:affitta', podere)
            return exports.aurea_ui:Notifica({
                tipo = ok and 'successo' or 'errore', icona = '🌾',
                titolo = 'Consorzio', testo = tostring(messaggio), durata = 18000 })
        end

        local item = scelta:match('^c:(.+)$')
        if not item then return end

        local r = exports.aurea_ui:Dialogo('Quante unità', {
            { etichetta = 'Quantità', tipo = 'number', valore = 1, min = 1, max = 30, obbligatorio = true },
        })
        if not r or not r[1] then return end

        local ok, messaggio = AUREA.Callback.Attendi('agr:compra', item, tonumber(r[1]))
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🌱',
            titolo = 'Consorzio', testo = tostring(messaggio), durata = 14000,
        })
    end)
end

RegisterCommand('consorzio', consorzio, false)

AddEventHandler('aurea:client:caricato', function()
    local b = AddBlipForCoord(AGR.Consorzio.coord)
    SetBlipSprite(b, AGR.Consorzio.blip.sprite)
    SetBlipColour(b, AGR.Consorzio.blip.colore)
    SetBlipScale(b, AGR.Consorzio.blip.scala)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(AGR.Consorzio.nome)
    EndTextCommandSetBlipName(b)

    exports.aurea_target:AggiungiZona('agr_consorzio', AGR.Consorzio.coord, AGR.Consorzio.raggio, {
        { etichetta = 'Consorzio agrario', icona = '🌾', azione = consorzio },
    })

    for _, p in ipairs(AGR.Poderi) do
        local pb = AddBlipForCoord(p.centro)
        SetBlipSprite(pb, 496)
        SetBlipColour(pb, 25)
        SetBlipScale(pb, 0.6)
        SetBlipAsShortRange(pb, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(p.nome)
        EndTextCommandSetBlipName(pb)
    end
end)
