--[[
    AUREA · Aspetto (server)
    Persistenza dell'aspetto, armadio, pagamento delle prestazioni.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Lettura e scrittura dell'aspetto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asp:mio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local riga = MySQL.scalar.await('SELECT aspetto FROM personaggi WHERE citizenid = ?', { g.citizenid })
    rispondi(riga and json.decode(riga) or nil)
end)

--- Il costo lo calcola il server confrontando con l'aspetto già salvato:
--- il client può proporre quello che vuole, paga quello che ha davvero cambiato.
local function calcolaCosto(precedente, nuovo, modalita, lusso)
    if modalita == 'creazione' then return 0 end
    if modalita == 'chirurgia' then return ASP.Chirurgia.costo end

    precedente = precedente or {}

    if modalita == 'tatuatore' then
        local prima = #(precedente.tatuaggi or {})
        local dopo = #(nuovo.tatuaggi or {})
        local aggiunti = math.max(0, dopo - prima)
        local rimossi = math.max(0, prima - dopo)
        return aggiunti * ASP.Prezzi.tatuaggio + rimossi * ASP.Prezzi.rimozioneTatuaggio
    end

    if modalita == 'barbiere' then
        local cambiato = false
        local pc, nc = precedente.capelli or {}, nuovo.capelli or {}
        if pc.drawable ~= nc.drawable or pc.colore ~= nc.colore or pc.coloreSecondario ~= nc.coloreSecondario then
            cambiato = true
        end
        for _, s in ipairs(ASP.Sovrapposizioni) do
            if s.sede == 'barbiere' then
                local a = (precedente.sovrapposizioni or {})[tostring(s.id)] or {}
                local b = (nuovo.sovrapposizioni or {})[tostring(s.id)] or {}
                if a.indice ~= b.indice or a.colore ~= b.colore then cambiato = true end
            end
        end
        return cambiato and ASP.Prezzi.taglioCapelli or 0
    end

    -- Abbigliamento: si paga ogni capo effettivamente cambiato
    local totale = 0
    local prezzoCapo = lusso and ASP.Prezzi.capoLusso or ASP.Prezzi.capo
    local prezzoAccessorio = lusso and ASP.Prezzi.accessorioLusso or ASP.Prezzi.accessorio

    for _, c in ipairs(ASP.Componenti) do
        local a = (precedente.componenti or {})[tostring(c.id)] or {}
        local b = (nuovo.componenti or {})[tostring(c.id)] or {}
        if a.drawable ~= b.drawable or a.texture ~= b.texture then
            totale = totale + prezzoCapo
        end
    end

    for _, a in ipairs(ASP.Accessori) do
        local x = (precedente.accessori or {})[tostring(a.id)] or {}
        local y = (nuovo.accessori or {})[tostring(a.id)] or {}
        if x.drawable ~= y.drawable or x.texture ~= y.texture then
            totale = totale + prezzoAccessorio
        end
    end

    return totale
end

--- Ripulisce la struttura ricevuta: nessun valore fuori scala entra nel database.
local function sanifica(dati)
    if type(dati) ~= 'table' then return nil end

    local out = {
        modello = (dati.modello == 'mp_f_freemode_01') and 'mp_f_freemode_01' or 'mp_m_freemode_01',
        eredita = {
            padre = U.Clamp(math.floor(tonumber((dati.eredita or {}).padre) or 0), 0, 45),
            madre = U.Clamp(math.floor(tonumber((dati.eredita or {}).madre) or 21), 0, 45),
            mix = U.Clamp(tonumber((dati.eredita or {}).mix) or 0.5, 0.0, 1.0),
            mixPelle = U.Clamp(tonumber((dati.eredita or {}).mixPelle) or 0.5, 0.0, 1.0),
        },
        tratti = {}, sovrapposizioni = {}, componenti = {}, accessori = {}, tatuaggi = {},
        capelli = {
            drawable = U.Clamp(math.floor(tonumber((dati.capelli or {}).drawable) or 0), 0, 100),
            texture = U.Clamp(math.floor(tonumber((dati.capelli or {}).texture) or 0), 0, 30),
            colore = U.Clamp(math.floor(tonumber((dati.capelli or {}).colore) or 0), 0, 63),
            coloreSecondario = U.Clamp(math.floor(tonumber((dati.capelli or {}).coloreSecondario) or 0), 0, 63),
        },
    }

    for i = 0, 19 do
        out.tratti[tostring(i)] = U.Clamp(tonumber((dati.tratti or {})[tostring(i)]) or 0.0, -1.0, 1.0)
    end

    for _, s in ipairs(ASP.Sovrapposizioni) do
        local v = (dati.sovrapposizioni or {})[tostring(s.id)] or {}
        local indice = math.floor(tonumber(v.indice) or 255)
        if indice ~= 255 then indice = U.Clamp(indice, 0, 60) end
        out.sovrapposizioni[tostring(s.id)] = {
            indice = indice,
            opacita = U.Clamp(tonumber(v.opacita) or 1.0, 0.0, 1.0),
            colore = U.Clamp(math.floor(tonumber(v.colore) or 0), 0, 63),
            coloreSecondario = U.Clamp(math.floor(tonumber(v.coloreSecondario) or 0), 0, 63),
        }
    end

    for _, c in ipairs(ASP.Componenti) do
        local v = (dati.componenti or {})[tostring(c.id)] or {}
        out.componenti[tostring(c.id)] = {
            drawable = U.Clamp(math.floor(tonumber(v.drawable) or 0), 0, 400),
            texture = U.Clamp(math.floor(tonumber(v.texture) or 0), 0, 60),
        }
    end

    for _, a in ipairs(ASP.Accessori) do
        local v = (dati.accessori or {})[tostring(a.id)] or {}
        local drawable = math.floor(tonumber(v.drawable) or -1)
        out.accessori[tostring(a.id)] = {
            drawable = drawable < 0 and -1 or U.Clamp(drawable, 0, 200),
            texture = U.Clamp(math.floor(tonumber(v.texture) or 0), 0, 60),
        }
    end

    -- I tatuaggi devono esistere davvero nel catalogo lato client
    for _, t in ipairs(dati.tatuaggi or {}) do
        if type(t) == 'table' and type(t.collezione) == 'string' and type(t.nome) == 'string'
           and #t.collezione < 64 and #t.nome < 64 then
            out.tatuaggi[#out.tatuaggi + 1] = {
                collezione = t.collezione, nome = t.nome, zona = t.zona,
            }
        end
    end

    return out
end

AUREA.Callback.Registra('asp:salva', function(src, rispondi, dati, modalita, lusso)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local pulito = sanifica(dati)
    if not pulito then return rispondi(false, 'Dati non validi.') end

    local precedenteGrezzo = MySQL.scalar.await('SELECT aspetto FROM personaggi WHERE citizenid = ?', { g.citizenid })
    local precedente = precedenteGrezzo and json.decode(precedenteGrezzo) or nil

    local costo = calcolaCosto(precedente, pulito, modalita, lusso)

    if costo > 0 then
        if not g:SottraiOvunque(costo, ('prestazione %s'):format(modalita)) then
            return rispondi(false, ('Servono %s.'):format(U.Euro(costo)))
        end
        TriggerEvent('aurea:fisco:incasso', 'iva', math.floor(costo * 0.18), g.citizenid)
    end

    MySQL.update.await('UPDATE personaggi SET aspetto = ? WHERE citizenid = ?',
        { json.encode(pulito), g.citizenid })
    g.aspetto = pulito

    rispondi(true, costo > 0 and ('Pagati %s.'):format(U.Euro(costo)) or 'Aspetto aggiornato.')
end)

--- Salvataggio diretto usato dalla creazione del personaggio.
RegisterNetEvent('asp:salvaCreazione', function(dati)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local pulito = sanifica(dati)
    if not pulito then return end

    MySQL.update('UPDATE personaggi SET aspetto = ? WHERE citizenid = ?', { json.encode(pulito), g.citizenid })
    g.aspetto = pulito
end)

-- ---------------------------------------------------------------------------
--  Armadio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('asp:completi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, nome, creato_il FROM completi WHERE citizenid = ? ORDER BY id DESC
    ]], { g.citizenid }) or {}

    for _, c in ipairs(righe) do
        c.quando = U.DataOraIT(math.floor((c.creato_il or 0) / 1000))
    end
    rispondi(righe)
end)

AUREA.Callback.Registra('asp:salvaCompleto', function(src, rispondi, nome, dati)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    nome = tostring(nome or ''):gsub('[^%w%s\'àèéìòù-]', ''):sub(1, 40)
    if #nome < 2 then return rispondi(false, 'Dai un nome al completo.') end

    local quanti = MySQL.scalar.await('SELECT COUNT(*) FROM completi WHERE citizenid = ?', { g.citizenid }) or 0
    if quanti >= ASP.Armadio.completiMassimi then
        return rispondi(false, ('L\'armadio contiene al massimo %d completi.'):format(ASP.Armadio.completiMassimi))
    end

    local pulito = sanifica(dati)
    if not pulito then return rispondi(false, 'Dati non validi.') end

    MySQL.insert.await('INSERT INTO completi (citizenid, nome, dati) VALUES (?, ?, ?)',
        { g.citizenid, nome, json.encode(pulito) })

    rispondi(true, ('"%s" salvato nell\'armadio.'):format(nome))
end)

AUREA.Callback.Registra('asp:indossaCompleto', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local riga = MySQL.single.await('SELECT dati FROM completi WHERE id = ? AND citizenid = ?', { id, g.citizenid })
    if not riga then return rispondi(nil) end

    local dati = json.decode(riga.dati)
    MySQL.update('UPDATE personaggi SET aspetto = ? WHERE citizenid = ?', { riga.dati, g.citizenid })
    g.aspetto = dati

    rispondi(dati)
end)

AUREA.Callback.Registra('asp:eliminaCompleto', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    MySQL.query.await('DELETE FROM completi WHERE id = ? AND citizenid = ?', { id, g.citizenid })
    rispondi(true)
end)

-- ---------------------------------------------------------------------------
--  Divisa automatica all'entrata in servizio
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:servizio:cambiato', function(src, lavoro, inServizio)
    if ASP.Divise[lavoro] then
        TriggerClientEvent('asp:divisa', src, lavoro, inServizio)
    end
end)

-- ---------------------------------------------------------------------------
--  Comando staff
-- ---------------------------------------------------------------------------
AUREA.Comando('rifaiaspetto', 'admin', 'Consente a un giocatore di rifare il volto gratis', {
    { name = 'id', help = 'ID sessione' },
}, function(src, args)
    local bersaglio = AUREA.GetPlayer(tonumber(args[1]))
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Uso', testo = '/rifaiaspetto <id>' })
    end

    TriggerClientEvent('asp:editorGratuito', bersaglio.source)
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', titolo = 'Editor sbloccato', testo = bersaglio:NomeCompleto(),
    })
end)
