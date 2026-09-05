--[[
    AUREA · Trasporto pubblico (server)
]]

local U = AUREA.Util
local corse = {}        -- [src] = { linea, fermata, incassato }
local titoli = {}       -- [citizenid] = { tipo, scade, obliterato }

local function titoloValido(citizenid)
    local t = titoli[citizenid]
    if not t then return nil end
    if os.time() > t.scade then titoli[citizenid] = nil return nil end
    return t
end

-- ---------------------------------------------------------------------------
--  Biglietteria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tra:biglietti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local out = {}
    for id, b in pairs(TRA.Biglietti) do
        if type(b) == 'table' then
            out[#out + 1] = { id = id, nome = b.nome, prezzo = b.prezzo,
                              validitaMinuti = b.validitaMinuti }
        end
    end
    table.sort(out, function(a, b) return a.prezzo < b.prezzo end)

    local t = titoloValido(g.citizenid)
    rispondi({
        biglietti = out,
        titolo = t and {
            tipo = TRA.Biglietti[t.tipo].nome,
            minuti = math.floor((t.scade - os.time()) / 60),
            obliterato = t.obliterato,
        } or nil,
    })
end)

AUREA.Callback.Registra('tra:compra', function(src, rispondi, tipo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local b = TRA.Biglietti[tipo]
    if not b or type(b) ~= 'table' then return rispondi(false, 'Titolo non previsto.') end

    if not g:SottraiOvunque(b.prezzo, b.nome) then
        return rispondi(false, ('Il biglietto costa %s.'):format(U.Euro(b.prezzo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'trasporto_pubblico', b.prezzo, g.citizenid)

    titoli[g.citizenid] = {
        tipo = tipo, scade = os.time() + b.validitaMinuti * 60, obliterato = false,
    }

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, TRA.Biglietti.item, 1, {
        tipo = b.nome, acquistato = os.date('%d/%m %H:%M'),
        intestatario = g:NomeCompleto(),
    })

    rispondi(true, ('%s acquistato. Va obliterato salendo, altrimenti non vale.'):format(b.nome))
end)

AUREA.Callback.Registra('tra:oblitera', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local t = titoloValido(g.citizenid)
    if not t then return rispondi(false, 'Non hai un titolo di viaggio valido.') end
    if t.obliterato then return rispondi(false, 'È già obliterato.') end

    t.obliterato = true
    rispondi(true, 'Biglietto obliterato. Buon viaggio.')
end)

-- ---------------------------------------------------------------------------
--  Controllo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tra:controlla', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not soggetto then return rispondi(nil, 'Persona non trovata.') end

    if not U.Contiene(TRA.Controllo.lavori, g.lavoro.nome) or not g.lavoro.servizio then
        return rispondi(nil, 'Non sei in servizio come controllore.')
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source)))
    if d > 4.0 then return rispondi(nil, 'Troppo lontano.') end

    local t = titoloValido(soggetto.citizenid)

    if t and t.obliterato then
        return rispondi({ regolare = true, nome = soggetto:NomeCompleto() },
            ('%s viaggia con %s regolarmente obliterato.')
                :format(soggetto:NomeCompleto(), TRA.Biglietti[t.tipo].nome))
    end

    local motivo = t and 'titolo non obliterato' or 'nessun titolo di viaggio'

    soggetto:SottraiOvunque(TRA.Controllo.sanzione, TRA.Controllo.articolo)
    local quota = math.floor(TRA.Controllo.sanzione * TRA.Controllo.quotaControllore)
    g:Aggiungi('banca', quota, 'quota su verbale trasporto')
    TriggerEvent('aurea:fisco:incasso', 'trasporto_pubblico',
        TRA.Controllo.sanzione - quota, soggetto.citizenid)

    TriggerClientEvent('aurea:ui:notifica', soggetto.source, {
        tipo = 'errore', icona = '🎫', durata = 14000,
        titolo = 'Sanzione del controllore',
        testo = ('%s — %s.'):format(motivo, U.Euro(TRA.Controllo.sanzione)),
    })

    rispondi({ regolare = false, nome = soggetto:NomeCompleto(), motivo = motivo },
        ('%s: %s. Sanzione di %s, tua quota %s.')
            :format(soggetto:NomeCompleto(), motivo, U.Euro(TRA.Controllo.sanzione), U.Euro(quota)))
end)

-- ---------------------------------------------------------------------------
--  La corsa, come lavoro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('tra:linee', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if g.lavoro.nome ~= TRA.Lavoro then return rispondi(nil, 'Non sei assunto come autista.') end

    local out = {}
    for _, l in ipairs(TRA.Linee) do
        out[#out + 1] = {
            id = l.id, nome = l.nome, pagaFermata = l.pagaFermata,
            fermate = #l.fermate,
            totale = l.pagaFermata * #l.fermate,
        }
    end

    rispondi({ linee = out, mezzi = TRA.Deposito.mezzi, modello = TRA.Deposito.modello })
end)

AUREA.Callback.Registra('tra:avvia', function(src, rispondi, idLinea)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if g.lavoro.nome ~= TRA.Lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Devi essere in servizio.')
    end
    if corse[src] then return rispondi(false, 'Hai già una corsa in servizio.') end

    local l = TRA.GetLinea(idLinea)
    if not l then return rispondi(false, 'Linea sconosciuta.') end

    corse[src] = { linea = idLinea, fermata = 1, incassato = 0 }

    local fermate = {}
    for n, f in ipairs(l.fermate) do
        fermate[n] = { nome = f.nome, x = f.coord.x, y = f.coord.y, z = f.coord.z }
    end

    rispondi(true, { nome = l.nome, fermate = fermate, paga = l.pagaFermata })
end)

AUREA.Callback.Registra('tra:fermata', function(src, rispondi, passeggeri)
    local g = AUREA.GetPlayer(src)
    local c = corse[src]
    if not g or not c then return rispondi(false, 'Nessuna corsa in servizio.') end

    local l = TRA.GetLinea(c.linea)
    local f = l and l.fermate[c.fermata]
    if not f then return rispondi(false, 'Corsa conclusa.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - f.coord) > TRA.Servizio.distanzaFermata + 5.0 then
        return rispondi(false, 'Non sei alla fermata.')
    end

    passeggeri = math.max(0, math.min(20, math.floor(tonumber(passeggeri) or 0)))

    local paga = math.floor(l.pagaFermata * (1 + passeggeri * TRA.Servizio.bonusPasseggero))
    local ritenuta = math.floor(paga * 0.20)
    g:Aggiungi('banca', paga - ritenuta, 'servizio di linea')
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    c.fermata = c.fermata + 1
    c.incassato = c.incassato + paga

    local finita = c.fermata > #l.fermate
    if finita then corse[src] = nil end

    rispondi(true, {
        finita = finita, paga = paga - ritenuta, passeggeri = passeggeri,
        fermata = c.fermata - 1, totale = #l.fermate,
        incassato = c.incassato,
    })
end)

AddEventHandler('playerDropped', function() corse[source] = nil end)
