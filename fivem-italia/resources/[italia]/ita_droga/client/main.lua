--[[
    AUREA · Stupefacenti (client)
]]

local U = AUREA.Util
local piante = {}           -- [id] = { coord, prop }
local occupato = false
local effettoFino = 0

local MODELLO_PIANTA = `prop_weed_02`

-- ---------------------------------------------------------------------------
--  Piante
-- ---------------------------------------------------------------------------
local function creaProp(id, coord)
    if piante[id] and DoesEntityExist(piante[id].prop) then return end

    RequestModel(MODELLO_PIANTA)
    local attesa = 0
    while not HasModelLoaded(MODELLO_PIANTA) and attesa < 100 do Wait(20) attesa = attesa + 1 end
    if not HasModelLoaded(MODELLO_PIANTA) then return end

    local prop = CreateObject(MODELLO_PIANTA, coord.x, coord.y, coord.z - 1.0, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(MODELLO_PIANTA)

    piante[id] = { coord = vector3(coord.x, coord.y, coord.z), prop = prop }
end

local function rimuoviProp(id)
    local p = piante[id]
    if p and DoesEntityExist(p.prop) then DeleteObject(p.prop) end
    piante[id] = nil
end

RegisterNetEvent('dro:piantaAggiunta', function(id, coord) creaProp(id, coord) end)
RegisterNetEvent('dro:piantaRimossa', function(id) rimuoviProp(id) end)

AddEventHandler('aurea:client:caricato', function()
    CreateThread(function()
        Wait(4000)
        local elenco = AUREA.Callback.Attendi('dro:piante')
        for _, p in ipairs(elenco or {}) do creaProp(p.id, p.coord) end
    end)
end)

--- Interazione con la pianta più vicina.
CreateThread(function()
    while true do
        local attesa = 900
        local coord = GetEntityCoords(PlayerPedId())

        local vicina, distanza = nil, 3.0
        for id, p in pairs(piante) do
            local d = #(coord - p.coord)
            if d < distanza then vicina, distanza = id, d end
        end

        if vicina and not occupato then
            attesa = 0
            local agente = AUREA.EInServizio() and AUREA.HaLavoro('carabinieri', 'polizia', 'guardia_finanza')

            exports.aurea_ui:Prompt(true, agente and 'Sequestra la pianta' or 'Pianta', 'E')
            if IsControlJustReleased(0, 38) then
                exports.aurea_ui:Prompt(false)
                if agente then sequestra(vicina) else menuPianta(vicina) end
            end
        else
            exports.aurea_ui:Prompt(false)
        end

        Wait(attesa)
    end
end)

function menuPianta(id)
    CreateThread(function()
        local scelta = exports.aurea_ui:Menu({
            titolo = 'Pianta',
            sottotitolo = 'La qualità del raccolto dipende da come la curi',
            voci = {
                { id = 'cura', icona = '💧', titolo = 'Annaffia',
                  descrizione = 'Puntuale alza la purezza, in ritardo la abbassa.' },
                { id = 'raccogli', icona = '🌿', titolo = 'Raccogli',
                  descrizione = 'Solo a maturazione completa.' },
            },
        })
        if not scelta then return end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = scelta == 'cura' and 'Annaffiatura...' or 'Raccolta...',
            durata = scelta == 'cura' and 5000 or 8000,
            annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        if not completato then occupato = false return end

        local ok, messaggio = AUREA.Callback.Attendi(
            scelta == 'cura' and 'dro:cura' or 'dro:raccogli', id)
        occupato = false

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore',
            icona = scelta == 'cura' and '💧' or '🌿',
            titolo = 'Coltivazione', testo = messaggio, durata = 11000,
        })
    end)
end

function sequestra(id)
    CreateThread(function()
        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Sequestro e verbalizzazione...', durata = 9000, annullabile = true,
            blocca = { movimento = true },
        })
        if not completato then occupato = false return end

        local ok, messaggio = AUREA.Callback.Attendi('dro:sequestraPianta', id)
        occupato = false
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Sequestro', testo = messaggio, durata = 10000,
        })
    end)
end

RegisterCommand('pianta', function()
    CreateThread(function()
        if occupato then return end
        occupato = true

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Interramento del seme...', durata = 7000, annullabile = true,
            anim = { dizionario = 'amb@world_human_gardener_plant@male@base', nome = 'base' },
            blocca = { movimento = true },
        })
        if not completato then occupato = false return end

        local ok, messaggio = AUREA.Callback.Attendi('dro:pianta')
        occupato = false
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🌱',
            titolo = 'Coltivazione', testo = messaggio, durata = 12000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Laboratorio
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1200
        local coord = GetEntityCoords(PlayerPedId())
        local lab = DRO.LaboratorioVicino(coord)

        if lab and not occupato then
            attesa = 0
            exports.aurea_ui:Prompt(true, lab.nome, 'G')
            if IsControlJustReleased(0, 47) then
                exports.aurea_ui:Prompt(false)
                apriLaboratorio()
            end
        end

        Wait(attesa)
    end
end)

function apriLaboratorio()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('dro:ricette')
        if not dati then return end

        local voci = {
            { id = '_lv', icona = '🧪',
              titolo = ('Chimica — livello %d'):format(dati.livello),
              descrizione = 'Ogni livello vale quattro punti di purezza in più su ogni lavorazione.',
              disattivata = true },
        }

        for _, r in ipairs(dati.ricette) do
            voci[#voci + 1] = {
                id = r.id, icona = r.icona, titolo = r.nome,
                descrizione = r.mancanti and ('Mancano: %s'):format(r.mancanti)
                    or ('Serve: %s → %d dosi'):format(r.ingredienti, r.resa),
                valore = ('~%d%%'):format(r.purezzaAttesa),
                disattivata = r.mancanti ~= nil,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = dati.laboratorio,
            sottotitolo = 'La purezza che esce dipende da te, non dal caso soltanto',
            voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        local avviata, nome, durata = AUREA.Callback.Attendi('dro:lavora', scelta)
        if not avviata then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🧪', titolo = 'Lavorazione', testo = nome, durata = 10000,
            })
        end

        occupato = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = nome, durata = durata, annullabile = true,
            anim = { dizionario = 'anim@amb@business@coc@coc_unpack_cut@', nome = 'fullcut_cycle_v3_cokecutter' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completata then
            return exports.aurea_ui:Notifica({
                tipo = 'avviso', icona = '🧪', titolo = 'Lavorazione interrotta',
                testo = 'Il materiale è rimasto nel laboratorio.', durata = 9000,
            })
        end

        local ok, messaggio = AUREA.Callback.Attendi('dro:concludiLavorazione')
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '🧪',
            titolo = ok and 'Lavorazione riuscita' or 'Lavorazione fallita',
            testo = messaggio, durata = 14000,
        })
    end)
end

RegisterNetEvent('dro:incendio', function(coord)
    local pos = vector3(coord.x, coord.y, coord.z)
    if #(GetEntityCoords(PlayerPedId()) - pos) > 120.0 then return end

    StartScriptFire(pos.x, pos.y, pos.z, 20, false)
    AddExplosion(pos.x, pos.y, pos.z, 3, 0.6, true, false, 1.0)
end)

-- ---------------------------------------------------------------------------
--  Taglio
-- ---------------------------------------------------------------------------
RegisterCommand('taglia', function()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('dro:tagliabili')
        if not dati then return end

        if #dati.pile == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚖', titolo = 'Taglio',
                testo = 'Non hai sostanze tagliabili addosso.',
            })
        end
        if #dati.daTaglio == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '⚖', titolo = 'Taglio',
                testo = 'Ti serve mannitolo, lattosio o caffeina.',
            })
        end

        local voci = {}
        if not dati.bilancino then
            voci[#voci + 1] = { id = '_bil', icona = '⚠',
                titolo = 'Non hai il bilancino',
                descrizione = 'Senza pesare si sbaglia, e quello che si sbaglia si butta.',
                disattivata = true }
        end

        for _, p in ipairs(dati.pile) do
            voci[#voci + 1] = {
                id = 'p:' .. p.slot, icona = p.icona,
                titolo = ('%s — %d dosi al %d%%'):format(p.nome, p.quantita, p.purezza),
                descrizione = p.giudizio,
                valore = U.Euro(p.valore),
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Taglio della sostanza',
            sottotitolo = 'Il principio attivo non si crea: si distribuisce su più dosi',
            voci = voci,
        })
        if not scelta then return end

        local slot = tonumber(scelta:match('^p:(%d+)$'))
        if not slot then return end

        local pila
        for _, p in ipairs(dati.pile) do if p.slot == slot then pila = p end end
        if not pila then return end

        local vociTaglio = {}
        for _, t in ipairs(dati.daTaglio) do
            vociTaglio[#vociTaglio + 1] = {
                id = t.item, icona = '🧂', titolo = t.nome,
                descrizione = t.insospettabile
                    and 'Inerte: al narcotest non lascia firma.'
                    or ('Rende %.1f parti per parte, ma il reattivo la riconosce.'):format(t.resa),
                valore = ('ne hai %d'):format(t.quantita),
            }
        end

        local itemTaglio = exports.aurea_ui:Menu({
            titolo = 'Con cosa tagli?', sottotitolo = pila.nome, voci = vociTaglio,
        })
        if not itemTaglio then return end

        local massimo = 0
        for _, t in ipairs(dati.daTaglio) do if t.item == itemTaglio then massimo = t.quantita end end

        local risposta = exports.aurea_ui:Dialogo('Quante parti?', {
            { etichetta = ('Parti da aggiungere (max %d)'):format(massimo),
              tipo = 'number', valore = math.min(massimo, pila.quantita), min = 1, max = massimo,
              obbligatorio = true },
        })
        if not risposta or not risposta[1] then return end

        occupato = true
        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Pesatura e miscelazione...', durata = DRO.Taglio.durata, annullabile = true,
            anim = { dizionario = 'anim@amb@business@coc@coc_unpack_cut@', nome = 'fullcut_cycle_v6_cokecutter' },
            blocca = { movimento = true },
        })
        occupato = false
        if not completato then return end

        local ok, messaggio = AUREA.Callback.Attendi('dro:taglia', slot, itemTaglio, risposta[1])
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Taglio', testo = messaggio, durata = 15000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Spaccio
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        local ped = PlayerPedId()

        if not occupato and not IsPedInAnyVehicle(ped, false) then
            local cliente = clienteVicino()
            if cliente then
                attesa = 0
                exports.aurea_ui:Prompt(true, 'Proponi la merce', 'G')
                if IsControlJustReleased(0, 47) then
                    exports.aurea_ui:Prompt(false)
                    proponi()
                end
            end
        end

        Wait(attesa)
    end
end)

function clienteVicino()
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)

    local handle, npc = FindFirstPed()
    local trovato = nil
    repeat
        if not IsPedAPlayer(npc) and not IsPedDeadOrDying(npc, true)
           and not IsPedInAnyVehicle(npc, false)
           and #(coord - GetEntityCoords(npc)) < DRO.Spaccio.distanza then
            trovato = npc
        end
    until trovato or not FindNextPed(handle)
    EndFindPed(handle)

    return trovato
end

function proponi()
    CreateThread(function()
        local dati = AUREA.Callback.Attendi('dro:scorta')
        if not dati then return end

        if #dati.sostanze == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '💊', titolo = 'Niente da offrire',
                testo = 'Non hai sostanze addosso.',
            })
        end

        local voci = {}
        if dati.piazza then
            voci[#voci + 1] = {
                id = '_pz', icona = '📍', titolo = dati.piazza,
                descrizione = dati.vedetta
                    and ('%s fa il palo: prezzi più alti e meno rischi.'):format(dati.vedetta)
                    or 'Nessuna vedetta. Con qualcuno di guardia si guadagna di più.',
                valore = dati.satura and 'piazza satura' or nil,
                disattivata = true,
            }
        end

        for _, s in ipairs(dati.sostanze) do
            local nota = s.giudizio
            if s.invendibile then nota = 'invendibile: troppo tagliata'
            elseif s.letale then nota = 'purezza pericolosa: rischi di ammazzarlo' end

            voci[#voci + 1] = {
                id = s.id, icona = s.icona,
                titolo = ('%s — %d%% (%d dosi)'):format(s.nome, s.purezza, s.dosi),
                descrizione = nota,
                valore = U.Euro(s.prezzo),
                disattivata = s.invendibile,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = 'Cessione', sottotitolo = 'Si offre sempre la partita più pura che hai', voci = voci,
        })
        if not scelta or scelta:sub(1, 1) == '_' then return end

        occupato = true
        local completata = exports.aurea_ui:Progresso({
            etichetta = 'Trattativa...', durata = DRO.Spaccio.durata, annullabile = true,
            anim = { dizionario = 'mp_common', nome = 'givetake1_a' },
        })
        occupato = false
        if not completata then return end

        local ok, messaggio = AUREA.Callback.Attendi('dro:spaccia', scelta)
        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '💊',
            titolo = ok and 'Cessione' or 'Niente da fare', testo = messaggio, durata = 13000,
        })
    end)
end

-- ---------------------------------------------------------------------------
--  Vedetta
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        local attesa = 1000
        local coord = GetEntityCoords(PlayerPedId())

        for _, p in ipairs(DRO.Piazze) do
            if #(coord - p.vedetta.coord) < p.vedetta.raggio then
                attesa = 0
                exports.aurea_ui:Prompt(true, ('%s — mettiti di vedetta'):format(p.nome), 'H')
                if IsControlJustReleased(0, 74) then
                    exports.aurea_ui:Prompt(false)
                    CreateThread(function()
                        local ok, messaggio = AUREA.Callback.Attendi('dro:fallaVedetta')
                        exports.aurea_ui:Notifica({
                            tipo = ok and 'successo' or 'errore', icona = '👁',
                            titolo = 'Vedetta', testo = messaggio, durata = 12000,
                        })
                    end)
                end
                break
            end
        end

        Wait(attesa)
    end
end)

RegisterNetEvent('dro:allarmeVedetta', function(nomePiazza, quanti)
    exports.aurea_ui:Notifica({
        tipo = 'avviso', icona = '🚨', durata = 8000,
        titolo = 'Sbirri in zona',
        testo = ('%d pattuglia/e in avvicinamento alla %s. Avvisa gli altri.'):format(quanti, nomePiazza),
    })
    PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
end)

-- ---------------------------------------------------------------------------
--  Effetti del consumo
-- ---------------------------------------------------------------------------
RegisterNetEvent('dro:effetto', function(filtro, durata, purezza)
    effettoFino = GetGameTimer() + durata

    if filtro then
        SetTimecycleModifier(filtro)
        SetTimecycleModifierStrength(math.min(1.0, purezza / 100))
    end

    -- Più la roba è pura, più il passo è incerto
    local intensita = math.floor(purezza / 20)

    CreateThread(function()
        while GetGameTimer() < effettoFino do
            if intensita >= 3 and math.random(100) <= intensita then
                SetPedMotionBlur(PlayerPedId(), true)
                ShakeGameplayCam('DRUNK_SHAKE', math.min(1.0, intensita / 6))
            end
            Wait(1500)
        end
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
        SetPedMotionBlur(PlayerPedId(), false)
    end)
end)

-- ---------------------------------------------------------------------------
--  Narcotest — forze dell'ordine
-- ---------------------------------------------------------------------------
RegisterCommand('narcotest', function()
    CreateThread(function()
        local bersaglio = giocatoreVicino(3.5)
        if not bersaglio then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🧪', titolo = 'Nessuno accanto a te',
            })
        end

        local completato = exports.aurea_ui:Progresso({
            etichetta = 'Analisi con reattivo...', durata = DRO.Narcotest.durata, annullabile = true,
            blocca = { movimento = true },
        })
        if not completato then return end

        local esito, errore = AUREA.Callback.Attendi('dro:narcotest', bersaglio)
        if not esito then
            return exports.aurea_ui:Notifica({
                tipo = 'errore', icona = '🧪', titolo = 'Accertamento', testo = errore, durata = 10000,
            })
        end

        if #esito.reperti == 0 then
            return exports.aurea_ui:Notifica({
                tipo = 'info', icona = '🧪', titolo = 'Esito negativo',
                testo = ('Su %s non è stata rilevata alcuna sostanza.'):format(esito.nome), durata = 10000,
            })
        end

        local voci = {}
        for _, r in ipairs(esito.reperti) do
            voci[#voci + 1] = {
                id = r.codiceReato, icona = r.icona,
                titolo = ('%s — %d dosi al %d%%'):format(r.nome, r.dosi, r.purezza),
                descrizione = ('%s%s · contestabile come %s'):format(
                    r.giudizio,
                    r.taglio and (', tagliata con %s'):format(r.taglio) or '',
                    r.lieveEntita and 'fatto di lieve entità' or 'ipotesi piena'),
                valore = r.articolo,
            }
        end

        local scelta = exports.aurea_ui:Menu({
            titolo = ('Narcotest — %s'):format(esito.nome),
            sottotitolo = 'Scegli il capo da contestare: sequestra tutto il rinvenuto',
            voci = voci,
        })
        if not scelta then return end

        local nota = exports.aurea_ui:Dialogo('Annotazione a verbale', {
            { etichetta = 'Circostanze del rinvenimento', tipo = 'text',
              segnaposto = 'Es. controllo su strada, sostanza occultata negli indumenti' },
        })

        local ok, messaggio = AUREA.Callback.Attendi('dro:contesta', bersaglio, scelta,
            nota and nota[1] or 'Controllo di polizia')

        exports.aurea_ui:Notifica({
            tipo = ok and 'successo' or 'errore', icona = '⚖',
            titolo = 'Contestazione', testo = messaggio, durata = 12000,
        })
    end)
end, false)

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function giocatoreVicino(raggio)
    local ped = PlayerPedId()
    local coord = GetEntityCoords(ped)
    local migliore, distanza = nil, raggio

    for _, altro in ipairs(GetActivePlayers()) do
        local altroPed = GetPlayerPed(altro)
        if altroPed ~= ped then
            local d = #(coord - GetEntityCoords(altroPed))
            if d < distanza then migliore, distanza = GetPlayerServerId(altro), d end
        end
    end
    return migliore
end

AddEventHandler('onResourceStop', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    for id in pairs(piante) do rimuoviProp(id) end
    ClearTimecycleModifier()
end)
