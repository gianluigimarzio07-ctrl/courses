--[[
    AUREA · Videosorveglianza (server)

    Il server tiene lo stato degli impianti (acceso, guasto, disturbato) e
    decide chi può collegarsi. Quello che si vede dalla telecamera lo
    disegna il client, perché è una telecamera di gioco: ma il client non
    può collegarsi a un impianto che il server considera spento, e non può
    inventarsi un fermo immagine.
]]

local U = AUREA.Util
local guasti = {}       -- [id telecamera] = os.time() di ripristino
local ultimoFermo = {}  -- [citizenid] = os.time()

local function pubblica()
    local elenco = {}
    for id, fino in pairs(guasti) do
        if fino > os.time() then elenco[id] = true end
    end
    GlobalState.telecamereGuaste = elenco
end

local function guasta(id, minuti, motivo)
    guasti[id] = os.time() + minuti * 60
    pubblica()

    CreateThread(function()
        Wait(minuti * 60000 + 1000)
        if guasti[id] and guasti[id] <= os.time() then
            guasti[id] = nil
            pubblica()
        end
    end)
end

local function attiva(t)
    return not (guasti[t.id] and guasti[t.id] > os.time())
end

-- ---------------------------------------------------------------------------
--  Blackout: l'elettricista spegne un quartiere, e quel quartiere smette
--  di vedere. Non tutta la città: solo le telecamere che stanno sotto
--  quella cabina.
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:elettricita:blackout', function(idCabina, attivo)
    local cabina = TVC.Guasti.cabine[idCabina]
    if not cabina then return end

    local colpite = 0

    for _, t in ipairs(TVC.Circuito(TVC.Guasti.circuitoSuReteElettrica)) do
        if #(t.coord - cabina.coord) <= cabina.raggio then
            colpite = colpite + 1
            if attivo then
                guasti[t.id] = os.time() + TVC.Guasti.minutiRipristinoAutomatico * 60
            else
                guasti[t.id] = nil
            end
        end
    end

    if colpite == 0 then return end
    pubblica()

    if attivo then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'errore', icona = '📹', durata = 16000,
            titolo = 'Telecamere senza alimentazione',
            testo = ('%d impianti giù per l\'interruzione di corrente in zona %s.')
                :format(colpite, cabina.zona),
        }, true)
    end
end)

--- Il disturbatore acceca quello che ha intorno.
RegisterNetEvent('tvc:jammer', function(x, y, z)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(TVC.Guasti.jammer.oggetto, 1) then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if type(x) ~= 'number' or #(coord - vector3(x + 0.0, y + 0.0, z + 0.0)) > 10.0 then
        x, y, z = coord.x, coord.y, coord.z
    end

    local punto = vector3(x, y, z)
    local colpite = 0

    for _, t in ipairs(TVC.Telecamere) do
        if #(punto - t.coord) <= TVC.Guasti.jammer.raggio then
            guasta(t.id, TVC.Guasti.jammer.minuti, 'disturbo di frequenze')
            colpite = colpite + 1
        end
    end

    if colpite > 0 then
        exports.aurea_ui:NotificaLavoro('carabinieri', {
            tipo = 'avviso', icona = '📹', durata = 14000,
            titolo = 'Telecamere fuori servizio',
            testo = ('%d impianti hanno perso il segnale nello stesso momento. Non è un guasto.'):format(colpite),
        }, true)

        AUREA.Log('giustizia', 'avviso', g, ('ha disturbato %d telecamere'):format(colpite))
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = colpite > 0 and 'successo' or 'info', icona = '📡', durata = 12000,
        titolo = 'Disturbatore attivo',
        testo = colpite > 0
            and ('%d telecamere accecate per %d minuti.'):format(colpite, TVC.Guasti.jammer.minuti)
            or 'Nessuna telecamera nel raggio.',
    })
end)

-- ---------------------------------------------------------------------------
--  Accesso al circuito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tvc:circuito', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local sala = TVC.SalaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not sala then return rispondi({}, 'Non sei in una sala di controllo.') end

    local ammessi = sala.lavori or TVC.Lavori
    if not U.Contiene(ammessi, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi({}, 'L\'accesso al circuito è riservato al personale in servizio.')
    end

    local out = {}
    for _, t in ipairs(TVC.Circuito(sala.circuito)) do
        out[#out + 1] = {
            id = t.id, nome = t.nome,
            coord = { x = t.coord.x, y = t.coord.y, z = t.coord.z },
            guarda = t.guarda, rotazione = t.rotazione,
            attiva = attiva(t),
        }
    end

    rispondi(out, nil, sala.nome)
end)

--- Chi c'è davanti a quella telecamera adesso. Lo calcola il server sulle
--- posizioni vere: il client non deve fidarsi di quello che disegna.
AUREA.Callback.Registra('tvc:inquadrati', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local sala = TVC.SalaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not sala then return rispondi({}) end

    local ammessi = sala.lavori or TVC.Lavori
    if not U.Contiene(ammessi, g.lavoro.nome) or not g.lavoro.servizio then return rispondi({}) end

    local t = TVC.GetTelecamera(id)
    if not t or t.circuito ~= sala.circuito or not attiva(t) then return rispondi({}) end

    local out = {}
    for _, altro in ipairs(AUREA.GetGiocatori()) do
        local d = #(GetEntityCoords(GetPlayerPed(altro.source)) - t.coord)
        if d <= TVC.Ottica.distanzaRiconoscimento then
            out[#out + 1] = { nome = altro:NomeCompleto(), metri = math.floor(d) }
        end
    end

    table.sort(out, function(a, b) return a.metri < b.metri end)
    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Fermo immagine
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tvc:fermo', function(src, rispondi, id, nota)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local sala = TVC.SalaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not sala then return rispondi(false, 'Non sei in sala controllo.') end

    local ammessi = sala.lavori or TVC.Lavori
    if not U.Contiene(ammessi, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(false, 'Non hai accesso al circuito.')
    end

    if ultimoFermo[g.citizenid] and os.time() - ultimoFermo[g.citizenid] < TVC.Fermo.secondiFraFermi then
        return rispondi(false, 'Hai appena acquisito un fermo immagine: aspetta.')
    end

    local t = TVC.GetTelecamera(id)
    if not t or not attiva(t) then return rispondi(false, 'La telecamera non trasmette.') end

    local presenti = {}
    for _, altro in ipairs(AUREA.GetGiocatori()) do
        if #(GetEntityCoords(GetPlayerPed(altro.source)) - t.coord) <= TVC.Ottica.distanzaRiconoscimento then
            presenti[#presenti + 1] = altro:NomeCompleto()
        end
    end

    ultimoFermo[g.citizenid] = os.time()

    MySQL.insert.await([[
        INSERT INTO telecamere_fermi (telecamera, nome_telecamera, operatore, presenti, nota)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        t.id, t.nome, g:NomeCompleto(),
        table.concat(presenti, ', '),
        tostring(nota or ''):sub(1, 200),
    })

    AUREA.Log('giustizia', 'info', g, ('fermo immagine da %s'):format(t.nome))

    rispondi(true, #presenti > 0
        and ('Fermo immagine acquisito. Inquadrati: %s.'):format(table.concat(presenti, ', '))
        or 'Fermo immagine acquisito. Nessuna persona riconoscibile nell\'inquadratura.')
end)

AUREA.Callback.Registra('tvc:fermi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not U.Contiene(TVC.Lavori, g.lavoro.nome) then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT nome_telecamera, operatore, presenti, nota, momento
        FROM telecamere_fermi ORDER BY id DESC LIMIT ?
    ]], { TVC.Fermo.massimoConsultabili })

    rispondi(righe or {})
end)

CreateThread(function()
    Wait(3000)
    pubblica()
end)
