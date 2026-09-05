--[[
    AUREA · Stupefacenti (server)

    Tutto quello che qui si calcola — purezza, prezzo, esito del taglio,
    rischio di overdose, articolo contestato — lo calcola il server. Il
    client dice soltanto "ho premuto E": la purezza non gliela chiediamo
    mai, perché è la variabile che vale i soldi.
]]

local U = AUREA.Util

local piante = {}           -- [id] = { citizenid, coord, piantata, ultimaCura, cure, ritardi, alChiuso }
local contatorePiante = 0
local piazze = {}           -- [id] = { cessioni, azzeramento, vedetta, spacciatori }
local inCorso = {}          -- [src] = true

-- ---------------------------------------------------------------------------
--  Aiuti
-- ---------------------------------------------------------------------------
local function calore(g, punti, motivo)
    if g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, punti, motivo)
    end
end

local function maestria(citizenid)
    local riga = MySQL.single.await('SELECT xp, livello FROM maestria WHERE citizenid = ? AND disciplina = ?',
        { citizenid, DRO.Maestria.disciplina })
    if not riga then return 0, 1 end
    return riga.xp, riga.livello
end

local function aggiungiXp(citizenid, quanti)
    local xp = select(1, maestria(citizenid)) + quanti
    local livello = math.min(DRO.Maestria.livelloMassimo, 1 + math.floor(xp / DRO.Maestria.xpPerLivello))
    MySQL.query.await([[
        INSERT INTO maestria (citizenid, disciplina, xp, livello) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = VALUES(xp), livello = VALUES(livello)
    ]], { citizenid, DRO.Maestria.disciplina, xp, livello })
    return livello
end

--- Somma le dosi di una sostanza che il soggetto ha addosso e la loro
--- purezza media ponderata: serve sia al prezzo sia al reato contestato.
local function scorta(inventario, itemSostanza)
    local dosi, attive = 0, 0
    for _, riga in ipairs(inventario.item) do
        if riga.nome == itemSostanza then
            local p = DRO.Purezza(riga.metadata)
            dosi = dosi + riga.quantita
            attive = attive + riga.quantita * p
        end
    end
    return dosi, dosi > 0 and math.floor(attive / dosi) or 0
end

--- La riga con la purezza più alta: è quella che si offre per prima.
local function migliorePila(inventario, itemSostanza)
    local migliore = nil
    for _, riga in ipairs(inventario.item) do
        if riga.nome == itemSostanza then
            if not migliore or DRO.Purezza(riga.metadata) > DRO.Purezza(migliore.metadata) then
                migliore = riga
            end
        end
    end
    return migliore
end

-- ---------------------------------------------------------------------------
--  COLTIVAZIONE
--
--  La cura non è un pulsante da premere una volta: ogni annaffiatura
--  puntuale alza la purezza dell'infiorescenza, ogni ritardo la abbassa.
--  Due giocatori che piantano lo stesso seme raccolgono roba diversa.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dro:pianta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local mie = 0
    for _, p in pairs(piante) do
        if p.citizenid == g.citizenid then mie = mie + 1 end
    end
    if mie >= DRO.Coltivazione.massimoPiante then
        return rispondi(false, ('Non puoi seguire più di %d piante.'):format(DRO.Coltivazione.massimoPiante))
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(DRO.Coltivazione.seme, 1) then return rispondi(false, 'Non hai semi.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    for _, p in pairs(piante) do
        if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) < 1.5 then
            return rispondi(false, 'C\'è già una pianta qui.')
        end
    end

    inventario:Rimuovi(DRO.Coltivazione.seme, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    contatorePiante = contatorePiante + 1
    local id = contatorePiante
    piante[id] = {
        citizenid = g.citizenid,
        coord = { x = coord.x, y = coord.y, z = coord.z },
        piantata = os.time(), ultimaCura = os.time(),
        cure = 0, ritardi = 0,
        alChiuso = DRO.AlChiuso(coord),
    }

    TriggerClientEvent('dro:piantaAggiunta', -1, id, piante[id].coord)
    calore(g, DRO.Coltivazione.calore, 'nuova piantagione')

    rispondi(true, 'Seme interrato. Va annaffiato con regolarità: la qualità dipende da questo.')
end)

AUREA.Callback.Registra('dro:cura', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local p = piante[id]
    if not g or not p then return rispondi(false, 'Pianta non trovata.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > 3.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(DRO.Coltivazione.attrezzo, 1) then
        return rispondi(false, 'Serve un annaffiatoio.')
    end

    -- Una cura entro metà del tempo di sofferenza è puntuale, oltre è tardiva
    local minutiDaUltima = (os.time() - p.ultimaCura) / 60
    if minutiDaUltima < 3 then return rispondi(false, 'L\'hai appena annaffiata.') end

    if minutiDaUltima > (DRO.Coltivazione.minutiSenzaCura / 2) then
        p.ritardi = p.ritardi + 1
    else
        p.cure = p.cure + 1
    end
    p.ultimaCura = os.time()

    local trascorsi = (os.time() - p.piantata) / 60
    local percentuale = math.min(100, math.floor((trascorsi / DRO.Coltivazione.minutiCrescita) * 100))

    rispondi(true, ('Pianta curata. Maturazione al %d%%%s.'):format(percentuale,
        p.ritardi > 0 and (', %d annaffiature tardive'):format(p.ritardi) or ''))
end)

AUREA.Callback.Registra('dro:raccogli', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local p = piante[id]
    if not g or not p then return rispondi(false, 'Pianta non trovata.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > 3.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    local trascorsi = (os.time() - p.piantata) / 60
    if trascorsi < DRO.Coltivazione.minutiCrescita then
        return rispondi(false, ('Non è matura: mancano %d minuti.'):format(
            math.ceil(DRO.Coltivazione.minutiCrescita - trascorsi)))
    end

    local C = DRO.Coltivazione
    local purezza = C.purezzaBase
        + p.cure * C.purezzaPerCura
        - p.ritardi * C.purezzaPersaPerRitardo
    purezza = math.floor(U.Clamp(purezza, 5, C.purezzaMassima))

    local quantita = math.random(C.resaMinima, C.resaMassima)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if not inventario:Aggiungi(C.raccolto, quantita, { purezza = purezza }) then
        return rispondi(false, 'Non hai spazio.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    piante[id] = nil
    TriggerClientEvent('dro:piantaRimossa', -1, id)

    AUREA.Log('giustizia', 'debug', g, ('raccolta di %d infiorescenze al %d%%'):format(quantita, purezza))
    rispondi(true, ('%d× infiorescenza raccolta, purezza %d%% (%s).')
        :format(quantita, purezza, DRO.GiudizioPurezza('erba', purezza)))
end)

AUREA.Callback.Registra('dro:piante', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for id, p in pairs(piante) do
        local trascorsi = (os.time() - p.piantata) / 60
        out[#out + 1] = {
            id = id, coord = p.coord,
            mia = p.citizenid == g.citizenid,
            maturazione = math.min(100, math.floor((trascorsi / DRO.Coltivazione.minutiCrescita) * 100)),
            sete = math.min(100, math.floor((((os.time() - p.ultimaCura) / 60) / DRO.Coltivazione.minutiSenzaCura) * 100)),
        }
    end
    rispondi(out)
end)

--- Appassimento e odore.
CreateThread(function()
    while true do
        Wait(DRO.Coltivazione.minutiControlloOdore * 60000)

        local adesso = os.time()
        local perProprietario = {}

        for id, p in pairs(piante) do
            if (adesso - p.ultimaCura) / 60 > DRO.Coltivazione.minutiSenzaCura then
                piante[id] = nil
                TriggerClientEvent('dro:piantaRimossa', -1, id)

                local g = AUREA.GetPlayerByCitizenId(p.citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '🥀', durata = 9000,
                        titolo = 'Una pianta è seccata', testo = 'Senza acqua non sopravvivono.',
                    })
                end
            elseif not p.alChiuso then
                perProprietario[p.citizenid] = perProprietario[p.citizenid] or {}
                table.insert(perProprietario[p.citizenid], p)
            end
        end

        for citizenid, elenco in pairs(perProprietario) do
            local probabilita = #elenco * DRO.Coltivazione.probabilitaSegnalazionePerPianta
            if math.random(100) <= math.min(70, probabilita) then
                local p = elenco[math.random(#elenco)]
                TriggerEvent('aurea:112:allerta', 'sospetto',
                    { x = p.coord.x, y = p.coord.y, z = p.coord.z },
                    'Segnalazione di odore acre proveniente dalla zona.',
                    'segnalazione dei residenti')

                local g = AUREA.GetPlayerByCitizenId(citizenid)
                if g then
                    calore(g, 3, 'segnalazione odore')
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '👃', durata = 11000,
                        titolo = 'Qualcuno ha sentito l\'odore',
                        testo = 'È partita una segnalazione al 112 dalla zona della piantagione.',
                    })
                end
            end
        end
    end
end)

AUREA.Callback.Registra('dro:sequestraPianta', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local p = piante[id]
    if not g or not p then return rispondi(false) end

    if not g:HaPermessoLavoro('sequestro') or not g.lavoro.servizio then
        return rispondi(false, 'Non sei autorizzato.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > 4.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    exports.ita_giustizia:ApriFascicolo(p.citizenid, DRO.Regole.reatoColtivazione,
        g:NomeCompleto(), 'Coltivazione di sostanze stupefacenti')

    piante[id] = nil
    TriggerClientEvent('dro:piantaRimossa', -1, id)

    AUREA.Log('giustizia', 'info', g, ('ha sequestrato una pianta di %s'):format(p.citizenid))
    rispondi(true, 'Pianta sequestrata e fascicolo aperto.')
end)

-- ---------------------------------------------------------------------------
--  LAVORAZIONE
--
--  purezza = base della ricetta
--          + bonus di maestria
--          + (per l'hashish) quanto valeva la materia prima
--          + resa del laboratorio
--          ± scarto casuale
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dro:ricette', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local lab = DRO.LaboratorioVicino(GetEntityCoords(GetPlayerPed(src)))
    if not lab then return rispondi(nil) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local _, livello = maestria(g.citizenid)

    local out = {}
    for id, r in pairs(DRO.Ricette) do
        local mancanti = {}
        for _, ing in ipairs(r.ingredienti) do
            local ha = inventario:Quantita(ing.item)
            if ha < ing.quantita then
                mancanti[#mancanti + 1] = ('%d× %s'):format(ing.quantita - ha, AUREA.Item[ing.item].etichetta)
            end
        end

        local descrizione = {}
        for _, ing in ipairs(r.ingredienti) do
            descrizione[#descrizione + 1] = ('%d× %s'):format(ing.quantita, AUREA.Item[ing.item].etichetta)
        end

        out[#out + 1] = {
            id = id, nome = r.nome, resa = r.resa,
            sostanza = DRO.Sostanze[r.sostanza].nome,
            icona = DRO.Sostanze[r.sostanza].icona,
            ingredienti = table.concat(descrizione, ', '),
            mancanti = #mancanti > 0 and table.concat(mancanti, ', ') or nil,
            purezzaAttesa = math.min(99, r.purezzaBase
                + (livello - 1) * DRO.Maestria.purezzaPerLivello
                + math.floor((lab.resa - 1) * 20)),
        }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)

    rispondi({ laboratorio = lab.nome, livello = livello, ricette = out })
end)

AUREA.Callback.Registra('dro:lavora', function(src, rispondi, idRicetta)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if inCorso[src] then return rispondi(false, 'Hai già una lavorazione in corso.') end

    local r = DRO.Ricette[idRicetta]
    if not r then return rispondi(false, 'Ricetta sconosciuta.') end

    local lab = DRO.LaboratorioVicino(GetEntityCoords(GetPlayerPed(src)))
    if not lab then return rispondi(false, 'Serve un laboratorio attrezzato.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    for _, ing in ipairs(r.ingredienti) do
        if not inventario:Ha(ing.item, ing.quantita) then
            return rispondi(false, ('Servono %d× %s.'):format(ing.quantita, AUREA.Item[ing.item].etichetta))
        end
    end

    -- La purezza della materia prima si trasferisce al prodotto
    local purezzaMateria = 0
    if r.daMateriaPrima then
        local pila = migliorePila(inventario, r.daMateriaPrima)
        purezzaMateria = pila and DRO.Purezza(pila.metadata) or 0
    end

    for _, ing in ipairs(r.ingredienti) do inventario:Rimuovi(ing.item, ing.quantita) end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    inCorso[src] = {
        ricetta = idRicetta, avviata = os.time(), lab = lab.id,
        purezzaMateria = purezzaMateria,
    }

    rispondi(true, r.nome, r.durata)
end)

AUREA.Callback.Registra('dro:concludiLavorazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione then return rispondi(false, 'Nessuna lavorazione in corso.') end

    local r = DRO.Ricette[sessione.ricetta]
    inCorso[src] = nil

    -- Il tempo lo verifica il server: il client non decide quando ha finito
    if (os.time() - sessione.avviata) * 1000 < (r.durata - 2000) then
        return rispondi(false, 'La lavorazione non era completa: il prodotto è inutilizzabile.')
    end

    local lab
    for _, l in ipairs(DRO.Laboratori) do if l.id == sessione.lab then lab = l end end
    lab = lab or DRO.Laboratori[1]

    calore(g, r.calore, ('lavorazione %s'):format(r.sostanza))

    if math.random(100) <= r.probabilitaFallimento then
        if r.probabilitaIncendio and math.random(100) <= r.probabilitaIncendio then
            local coord = GetEntityCoords(GetPlayerPed(src))
            TriggerClientEvent('dro:incendio', -1, { x = coord.x, y = coord.y, z = coord.z })
            TriggerEvent('aurea:112:allerta', 'incendio',
                { x = coord.x, y = coord.y, z = coord.z },
                'Principio di incendio con esalazioni. Possibile laboratorio clandestino.',
                lab.nome)
            calore(g, 6, 'incendio in laboratorio')

            return rispondi(false, 'La reazione è andata fuori controllo: è divampato un incendio.')
        end
        return rispondi(false, 'La lavorazione è fallita e il materiale è andato perso.')
    end

    local _, livello = maestria(g.citizenid)
    local purezza = r.purezzaBase
        + (livello - 1) * DRO.Maestria.purezzaPerLivello
        + math.floor((lab.resa - 1) * 20)
        + math.random(-6, 6)

    if r.daMateriaPrima then
        -- Dall'infiorescenza scadente non esce hashish buono
        purezza = purezza + math.floor(sessione.purezzaMateria * 0.75)
    end

    purezza = math.floor(U.Clamp(purezza, 5, 99))

    local sostanza = DRO.Sostanze[r.sostanza]
    local quantita = math.max(1, math.floor(r.resa * lab.resa + 0.5))

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Aggiungi(sostanza.item, quantita, { purezza = purezza }) then
        return rispondi(false, 'Non hai spazio: il prodotto è andato perso.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local nuovoLivello = aggiungiXp(g.citizenid, DRO.Maestria.xpPerLavorazione)

    AUREA.Log('giustizia', 'debug', g,
        ('ha prodotto %d× %s al %d%%'):format(quantita, sostanza.nome, purezza))

    rispondi(true, ('%d× %s al %d%% — %s.%s'):format(
        quantita, sostanza.nome, purezza, DRO.GiudizioPurezza(r.sostanza, purezza),
        nuovoLivello > livello and (' Sei salito al livello %d di chimica.'):format(nuovoLivello) or ''))
end)

-- ---------------------------------------------------------------------------
--  TAGLIO
--
--  Conservazione della massa attiva: se hai `dosi` unità al `purezza`%, il
--  principio attivo totale è dosi × purezza. Aggiungendo `parti` unità di
--  sostanza inerte quello stesso principio si distribuisce su più dosi.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dro:tagliabili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    local pile = {}
    for _, riga in ipairs(inventario.item) do
        local idSostanza = DRO.SostanzaDiItem[riga.nome]
        local s = idSostanza and DRO.Sostanze[idSostanza]
        if s and s.tagliabile then
            local p = DRO.Purezza(riga.metadata)
            pile[#pile + 1] = {
                slot = riga.slot, sostanza = idSostanza, nome = s.nome, icona = s.icona,
                quantita = riga.quantita, purezza = p,
                giudizio = DRO.GiudizioPurezza(idSostanza, p),
                valore = DRO.PrezzoDose(idSostanza, p) * riga.quantita,
            }
        end
    end
    table.sort(pile, function(a, b) return a.purezza > b.purezza end)

    local dataglio = {}
    for item, t in pairs(DRO.Taglio.sostanzeDaTaglio) do
        local ha = inventario:Quantita(item)
        if ha > 0 then
            dataglio[#dataglio + 1] = {
                item = item, nome = t.nome, quantita = ha,
                resa = t.resa, insospettabile = t.insospettabile,
            }
        end
    end
    table.sort(dataglio, function(a, b) return a.nome < b.nome end)

    rispondi({
        pile = pile, daTaglio = dataglio,
        bilancino = inventario:Ha(DRO.Taglio.attrezzo, 1),
    })
end)

AUREA.Callback.Registra('dro:taglia', function(src, rispondi, slot, itemTaglio, parti)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local t = DRO.Taglio.sostanzeDaTaglio[itemTaglio]
    if not t then return rispondi(false, 'Non è una sostanza da taglio.') end

    parti = math.floor(tonumber(parti) or 0)
    if parti < 1 then return rispondi(false, 'Indica quante parti aggiungere.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local riga = inventario:GetSlot(slot)
    if not riga then return rispondi(false, 'Slot vuoto.') end

    local idSostanza = DRO.SostanzaDiItem[riga.nome]
    local s = idSostanza and DRO.Sostanze[idSostanza]
    if not s or not s.tagliabile then return rispondi(false, 'Questa sostanza non si taglia.') end

    if not inventario:Ha(itemTaglio, parti) then
        return rispondi(false, ('Non hai %d× %s.'):format(parti, t.nome))
    end

    local dosi = riga.quantita
    local purezza = DRO.Purezza(riga.metadata)

    -- Il principio attivo non si crea e non si distrugge
    local attive = dosi * purezza
    local nuoveDosi = dosi + math.floor(parti * t.resa)

    local haBilancino = inventario:Ha(DRO.Taglio.attrezzo, 1)
    if not haBilancino then
        -- A occhio si sbaglia, e quello che si sbaglia si butta
        local persa = math.floor(nuoveDosi * DRO.Taglio.perditaSenzaBilancino)
        nuoveDosi = math.max(1, nuoveDosi - persa)
    end

    local nuovaPurezza = math.floor(U.Clamp(attive / nuoveDosi, 1, 99))

    inventario:Rimuovi(riga.nome, dosi, slot)
    inventario:Rimuovi(itemTaglio, parti)

    if not inventario:Aggiungi(s.item, nuoveDosi, {
        purezza = nuovaPurezza,
        -- La caffeina lascia una firma che il narcotest riconosce
        taglio = (not t.insospettabile) and t.nome or (riga.metadata and riga.metadata.taglio) or nil,
    }) then
        return rispondi(false, 'Non hai spazio per il risultato del taglio.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    calore(g, DRO.Taglio.calore, 'taglio della sostanza')

    local avviso = ''
    if nuovaPurezza < s.purezzaMinima then
        avviso = ' Sotto questa purezza nessun cliente la compra: hai bruciato la partita.'
    elseif not haBilancino then
        avviso = ' Senza bilancino hai perso parte del prodotto.'
    end

    rispondi(true, ('%d dosi al %d%% → %d dosi al %d%% (%s).%s'):format(
        dosi, purezza, nuoveDosi, nuovaPurezza,
        DRO.GiudizioPurezza(idSostanza, nuovaPurezza), avviso))
end)

-- ---------------------------------------------------------------------------
--  PIAZZE E VEDETTA
-- ---------------------------------------------------------------------------
local function statoPiazza(id)
    piazze[id] = piazze[id] or { cessioni = 0, azzeramento = os.time(), vedetta = nil, spacciatori = {} }
    local p = piazze[id]
    if (os.time() - p.azzeramento) / 60 > DRO.Spaccio.minutiRecuperoPiazza then
        p.cessioni = 0
        p.azzeramento = os.time()
        p.spacciatori = {}
    end
    return p
end

--- La vedetta è ancora al suo posto?
local function vedettaAttiva(piazza)
    local stato = statoPiazza(piazza.id)
    if not stato.vedetta then return nil end

    local g = AUREA.GetPlayer(stato.vedetta)
    if not g then stato.vedetta = nil return nil end

    local coord = GetEntityCoords(GetPlayerPed(stato.vedetta))
    if #(coord - piazza.vedetta.coord) > piazza.vedetta.raggio then
        return nil
    end
    return g
end

AUREA.Callback.Registra('dro:fallaVedetta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local piazza
    for _, p in ipairs(DRO.Piazze) do
        if #(coord - p.vedetta.coord) < p.vedetta.raggio then piazza = p break end
    end
    if not piazza then return rispondi(false, 'Non sei in un punto di vedetta.') end

    local stato = statoPiazza(piazza.id)
    if stato.vedetta and stato.vedetta ~= src and AUREA.GetPlayer(stato.vedetta) then
        return rispondi(false, 'Qualcun altro sta già facendo il palo qui.')
    end

    if stato.vedetta == src then
        stato.vedetta = nil
        return rispondi(true, 'Hai lasciato il posto di vedetta.')
    end

    stato.vedetta = src
    rispondi(true, ('Sei la vedetta della %s. Resta al tuo posto: prendi il %d%% di quello che si vende.')
        :format(piazza.nome, math.floor(DRO.Vedetta.quota * 100)))
end)

--- La vedetta vede arrivare le volanti prima degli altri.
CreateThread(function()
    while true do
        Wait(DRO.Vedetta.intervalloControllo)

        for _, piazza in ipairs(DRO.Piazze) do
            local stato = piazze[piazza.id]
            if stato and stato.vedetta then
                local vedetta = vedettaAttiva(piazza)

                if not vedetta then
                    stato.vedetta = nil
                else
                    local avvistati = 0
                    for altroSrc, altro in pairs(AUREA.Giocatori) do
                        if altro.lavoro.servizio then
                            local l = AUREA.GetLavoro(altro.lavoro.nome)
                            if l.tipo == 'forze_ordine' then
                                local d = #(GetEntityCoords(GetPlayerPed(altroSrc)) - piazza.coord)
                                if d < DRO.Vedetta.raggioAvvistamento then avvistati = avvistati + 1 end
                            end
                        end
                    end

                    if avvistati > 0 then
                        TriggerClientEvent('dro:allarmeVedetta', vedetta.source, piazza.nome, avvistati)
                    end
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  SPACCIO
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dro:spaccia', function(src, rispondi, idSostanza)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local s = DRO.Sostanze[idSostanza]
    if not s then return rispondi(false, 'Sostanza sconosciuta.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local pila = migliorePila(inventario, s.item)
    if not pila then return rispondi(false, ('Non hai %s addosso.'):format(s.nome)) end

    local purezza = DRO.Purezza(pila.metadata)
    if purezza < s.purezzaMinima then
        return rispondi(false, 'Roba troppo tagliata: nessuno la compra.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local piazza = DRO.PiazzaVicina(coord)
    local stato = piazza and statoPiazza(piazza.id) or nil
    local vedetta = piazza and vedettaAttiva(piazza) or nil

    -- Il prezzo: purezza, poi territorio, poi saturazione, poi vedetta
    local prezzo = DRO.PrezzoDose(idSostanza, purezza)

    if piazza and g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        local controllo = exports.ita_famiglie:ControllaTerritorio(piazza.territorio)
        if controllo == g.organizzazione.tag then
            prezzo = math.floor(prezzo * DRO.Spaccio.bonusTerritorio)
        end
    end

    if stato and stato.cessioni >= DRO.Spaccio.cessioniPrimaSaturazione then
        prezzo = math.floor(prezzo * DRO.Spaccio.penalitaSaturazione)
    end

    if vedetta then prezzo = math.floor(prezzo * DRO.Vedetta.moltiplicatorePrezzo) end

    -- Il cliente può rifiutare, e più la roba è scadente più rifiuta
    local rifiuto = DRO.Spaccio.probabilitaRifiuto
        + math.max(0, math.floor((s.purezzaTipica - purezza) * 0.8))
    if math.random(100) <= rifiuto then
        return rispondi(false, 'Il cliente ha guardato la roba e se n\'è andato.')
    end

    -- Agente sotto copertura: la vedetta lo riconosce quasi sempre
    local rischioAgente = DRO.Spaccio.probabilitaAgente
    if vedetta then rischioAgente = rischioAgente * DRO.Vedetta.riduzioneRischio end

    if math.random(100) <= rischioAgente then
        local dosi, media = scorta(inventario, s.item)
        local grave = dosi > DRO.Regole.sogliaUsoPersonale or media >= s.sogliaGrave
        local reato = grave and s.articoloGrave or s.articolo

        exports.ita_giustizia:ApriFascicolo(g.citizenid, reato, 'agente sotto copertura',
            ('Cessione di %s al %d%% ad agente in incognito.'):format(s.nome, purezza))

        calore(g, 8, 'cessione ad agente sotto copertura')

        TriggerEvent('aurea:112:allerta', 'sospetto', { x = coord.x, y = coord.y, z = coord.z },
            ('Cessione di stupefacenti accertata. Soggetto: %s.'):format(g:NomeCompleto()),
            piazza and piazza.nome or 'strada')

        return rispondi(false, 'Il cliente ha tirato fuori il tesserino. Era un agente.')
    end

    inventario:Rimuovi(s.item, 1, pila.slot)

    -- Il ricavato è contante non tracciato
    local banconote = math.max(1, math.floor(prezzo / DRO.Spaccio.tagliobanconota))
    inventario:Aggiungi(DRO.Spaccio.provento, banconote)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    -- Alla vedetta la sua quota
    if vedetta then
        local quota = math.max(1, math.floor(banconote * DRO.Vedetta.quota))
        local invVedetta = exports.aurea_inventory:Inventario(vedetta.citizenid)
        if invVedetta:Aggiungi(DRO.Spaccio.provento, quota) then
            TriggerClientEvent('inv:aggiorna', vedetta.source, invVedetta:Pacchetto())
            TriggerClientEvent('aurea:ui:notifica', vedetta.source, {
                tipo = 'successo', icona = '👁', durata = 6000,
                titolo = 'Quota di vedetta', testo = ('%d banconote.'):format(quota),
            })
        end
    end

    if stato then
        stato.cessioni = stato.cessioni + 1
        stato.spacciatori[g.citizenid] = true

        -- Tre spacciatori distinti sulla stessa piazza sono un'associazione
        local distinti = 0
        for _ in pairs(stato.spacciatori) do distinti = distinti + 1 end
        if distinti >= DRO.Regole.affiliatiPerAssociazione and g.organizzazione
           and g.organizzazione.tag ~= 'nessuna' then
            calore(g, 5, 'piazza di spaccio strutturata')
        end
    end

    calore(g, DRO.Spaccio.calore, 'cessione di stupefacenti')

    local esito = ('Ceduta una dose al %d%% per %d banconote.'):format(purezza, banconote)

    -- Overdose del cliente
    if purezza >= s.purezzaLetale then
        local rischio = DRO.Consumo.probabilitaOverdoseBase
            + (purezza - s.purezzaLetale) * DRO.Consumo.probabilitaPerPunto

        if math.random(100) <= rischio then
            exports.ita_giustizia:ApriFascicolo(g.citizenid, DRO.Regole.reatoMorteConseguente,
                'indagine d\'ufficio',
                ('Decesso di un assuntore per %s al %d%%.'):format(s.nome, purezza))

            calore(g, 15, 'morte di un assuntore')

            TriggerEvent('aurea:112:allerta', 'intossicazione', { x = coord.x, y = coord.y, z = coord.z },
                'Persona a terra, sospetta overdose.', piazza and piazza.nome or 'strada')

            AUREA.Log('giustizia', 'allarme', g,
                ('cessione letale: %s al %d%%'):format(s.nome, purezza))

            esito = esito .. ' Il cliente si è accasciato pochi metri più in là. Non si è più rialzato.'
        end
    end

    if math.random(100) <= DRO.Spaccio.probabilitaSegnalazione then
        TriggerEvent('aurea:112:allerta', 'sospetto', { x = coord.x, y = coord.y, z = coord.z },
            'Movimento sospetto compatibile con attività di spaccio.',
            piazza and piazza.nome or 'strada')
    end

    rispondi(true, esito)
end)

AUREA.Callback.Registra('dro:scorta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local coord = GetEntityCoords(GetPlayerPed(src))
    local piazza = DRO.PiazzaVicina(coord)
    local stato = piazza and statoPiazza(piazza.id) or nil
    local vedetta = piazza and vedettaAttiva(piazza) or nil

    local out = {}
    for id, s in pairs(DRO.Sostanze) do
        local pila = migliorePila(inventario, s.item)
        if pila then
            local dosi = scorta(inventario, s.item)
            local purezza = DRO.Purezza(pila.metadata)
            local prezzo = DRO.PrezzoDose(id, purezza)
            if vedetta then prezzo = math.floor(prezzo * DRO.Vedetta.moltiplicatorePrezzo) end
            if stato and stato.cessioni >= DRO.Spaccio.cessioniPrimaSaturazione then
                prezzo = math.floor(prezzo * DRO.Spaccio.penalitaSaturazione)
            end

            out[#out + 1] = {
                id = id, nome = s.nome, icona = s.icona, dosi = dosi,
                purezza = purezza, giudizio = DRO.GiudizioPurezza(id, purezza),
                prezzo = prezzo,
                letale = purezza >= s.purezzaLetale,
                invendibile = purezza < s.purezzaMinima,
            }
        end
    end
    table.sort(out, function(a, b) return a.prezzo > b.prezzo end)

    rispondi({
        sostanze = out,
        piazza = piazza and piazza.nome or nil,
        satura = stato and stato.cessioni >= DRO.Spaccio.cessioniPrimaSaturazione or false,
        vedetta = vedetta and vedetta:NomeCompleto() or nil,
    })
end)

-- ---------------------------------------------------------------------------
--  CONSUMO
-- ---------------------------------------------------------------------------
local function consuma(g, riga)
    local idSostanza = DRO.SostanzaDiItem[riga.nome]
    local s = DRO.Sostanze[idSostanza]
    if not s then return false end

    local purezza = DRO.Purezza(riga.metadata)
    local effetto = DRO.Consumo.effetti[idSostanza]

    if effetto then
        for chiave, delta in pairs(effetto.stato) do
            g:VariaStato(chiave, delta)
        end
        TriggerClientEvent('dro:effetto', g.source, effetto.filtro, effetto.durata, purezza)
    end

    if purezza >= s.purezzaLetale then
        local rischio = DRO.Consumo.probabilitaOverdoseBase
            + (purezza - s.purezzaLetale) * DRO.Consumo.probabilitaPerPunto

        if math.random(100) <= rischio then
            local coord = GetEntityCoords(GetPlayerPed(g.source))
            TriggerClientEvent('med:abbatti', g.source,
                ('Overdose da %s al %d%%. Senza soccorso non passa.'):format(s.nome, purezza))

            TriggerEvent('aurea:112:allerta', 'intossicazione', { x = coord.x, y = coord.y, z = coord.z },
                'Persona a terra, sospetta overdose.', 'strada')

            AUREA.Log('giustizia', 'avviso', g, ('overdose da %s al %d%%'):format(s.nome, purezza))
            return true
        end
    end

    TriggerClientEvent('aurea:ui:notifica', g.source, {
        tipo = 'info', icona = s.icona, durata = 9000,
        titolo = s.nome, testo = ('Purezza %d%% — %s.'):format(purezza, DRO.GiudizioPurezza(idSostanza, purezza)),
    })
    return true
end

CreateThread(function()
    Wait(1500)
    for _, s in pairs(DRO.Sostanze) do
        if AUREA.Item[s.item] and AUREA.Item[s.item].usabile then
            exports.aurea_inventory:RegistraUso(s.item, consuma)
        end
    end
end)

-- ---------------------------------------------------------------------------
--  NARCOTEST
--
--  L'analisi speditiva è quello che trasforma un sequestro in un capo
--  d'imputazione: dice che sostanza è e quanto è pura, e da lì discende
--  se il fatto è di lieve entità o no.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('dro:narcotest', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not soggetto then return rispondi(nil, 'Persona non trovata.') end

    if not U.Contiene(DRO.Narcotest.lavori, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(nil, 'Non sei in servizio per un accertamento.')
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source)))
    if d > 3.5 then return rispondi(nil, 'Il soggetto è troppo lontano.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(DRO.Narcotest.item, 1) then
        return rispondi(nil, 'Non hai un kit narcotest.')
    end

    local invSoggetto = exports.aurea_inventory:Inventario(soggetto.citizenid)

    local reperti = {}
    for id, s in pairs(DRO.Sostanze) do
        local dosi, media = scorta(invSoggetto, s.item)
        if dosi > 0 then
            local pila = migliorePila(invSoggetto, s.item)
            local grave = dosi > DRO.Regole.sogliaUsoPersonale or media >= s.sogliaGrave
            local reato = AUREA.Reati[grave and s.articoloGrave or s.articolo]

            reperti[#reperti + 1] = {
                sostanza = id, nome = s.nome, icona = s.icona,
                dosi = dosi, purezza = media,
                giudizio = DRO.GiudizioPurezza(id, media),
                taglio = pila and pila.metadata and pila.metadata.taglio or nil,
                lieveEntita = not grave,
                articolo = reato and reato.articolo or '—',
                codiceReato = grave and s.articoloGrave or s.articolo,
            }
        end
    end

    inventario:Rimuovi(DRO.Narcotest.item, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    if #reperti == 0 then
        return rispondi({ nome = soggetto:NomeCompleto(), reperti = {} },
            'Il reattivo non ha dato esito: nessuna sostanza rilevata.')
    end

    AUREA.Log('giustizia', 'info', g,
        ('narcotest su %s: %d reperti'):format(soggetto.citizenid, #reperti))

    rispondi({ nome = soggetto:NomeCompleto(), cf = soggetto.cf, reperti = reperti })
end)

AUREA.Callback.Registra('dro:contesta', function(src, rispondi, bersaglioSrc, codiceReato, nota)
    local g = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not soggetto then return rispondi(false, 'Persona non trovata.') end

    if not U.Contiene(DRO.Narcotest.lavori, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio.')
    end
    if not AUREA.Reati[codiceReato] then return rispondi(false, 'Reato non previsto.') end

    -- Sequestro di quanto rinvenuto
    local invSoggetto = exports.aurea_inventory:Inventario(soggetto.citizenid)
    local sequestrate = 0
    for _, s in pairs(DRO.Sostanze) do
        local dosi = scorta(invSoggetto, s.item)
        if dosi > 0 then
            invSoggetto:Rimuovi(s.item, dosi)
            sequestrate = sequestrate + dosi
        end
    end
    TriggerClientEvent('inv:aggiorna', soggetto.source, invSoggetto:Pacchetto())

    exports.ita_giustizia:ApriFascicolo(soggetto.citizenid, codiceReato, g:NomeCompleto(),
        tostring(nota or ''):sub(1, 200))

    AUREA.Log('giustizia', 'info', g,
        ('ha contestato %s a %s, sequestrate %d dosi'):format(codiceReato, soggetto.citizenid, sequestrate))

    rispondi(true, ('Fascicolo aperto e %d dosi sequestrate.'):format(sequestrate))
end)

-- ---------------------------------------------------------------------------
--  Perquisizione: quanto si trova addosso, con purezza media
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giustizia:perquisito', function(agenteSrc, soggettoCitizenid)
    local invSoggetto = exports.aurea_inventory:Inventario(soggettoCitizenid)

    local righe = {}
    for id, s in pairs(DRO.Sostanze) do
        local dosi, media = scorta(invSoggetto, s.item)
        if dosi > 0 then
            righe[#righe + 1] = ('%d× %s (purezza apparente %d%%)'):format(dosi, s.nome, media)
        end
    end

    if #righe > 0 then
        TriggerClientEvent('aurea:ui:notifica', agenteSrc, {
            tipo = 'avviso', icona = '💊', durata = 16000,
            titolo = 'Rinvenute sostanze stupefacenti',
            testo = table.concat(righe, ' · ') .. ' — usa /narcotest per l\'accertamento.',
        })
    end
end)

AddEventHandler('playerDropped', function()
    inCorso[source] = nil
    for _, stato in pairs(piazze) do
        if stato.vedetta == source then stato.vedetta = nil end
    end
end)
