--[[
    AUREA · Palestra (server)

    Le statistiche stanno nei metadata del personaggio, quindi si salvano
    con lui. Il server verifica il tempo dell'esercizio: chi chiude la
    barra prima non prende punti.
]]

local U = AUREA.Util
local inCorso = {}      -- [src] = { esercizio, avviata }

local function stat(g, nome)
    return math.floor(tonumber(g:Get('pal_' .. nome)) or 0)
end

local function impostaStat(g, nome, valore)
    local massimo = PAL.Statistiche[nome].massimo
    g:Set('pal_' .. nome, math.floor(U.Clamp(valore, 0, massimo)), true)
end

--- Le altre risorse chiedono qui quanto è forte o resistente qualcuno.
exports('Statistica', function(src, nome)
    local g = AUREA.GetPlayer(src)
    if not g or not PAL.Statistiche[nome] then return 0 end
    return stat(g, nome)
end)

AUREA.Callback.Registra('pal:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local out = {}
    for id, s in pairs(PAL.Statistiche) do
        out[#out + 1] = {
            id = id, nome = s.nome, icona = s.icona, descrizione = s.descrizione,
            valore = stat(g, id), massimo = s.massimo,
        }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)

    local esercizi = {}
    for _, e in ipairs(PAL.Esercizi) do
        esercizi[#esercizi + 1] = {
            id = e.id, nome = e.nome, icona = e.icona,
            statistica = PAL.Statistiche[e.statistica].nome,
            punti = PAL.PuntiEffettivi(e, stat(g, e.statistica)),
            durata = e.durata,
        }
    end

    rispondi({
        statistiche = out, esercizi = esercizi,
        ingressi = math.floor(tonumber(g:Get('pal_ingressi')) or 0),
        costo = PAL.Regole.costoIngresso,
    })
end)

AUREA.Callback.Registra('pal:abbonamento', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local prezzo = PAL.Regole.costoIngresso * PAL.Regole.ingressiPerAbbonamento
    if not g:SottraiOvunque(prezzo, 'abbonamento palestra') then
        return rispondi(false, ('L\'abbonamento costa %s.'):format(U.Euro(prezzo)))
    end

    TriggerEvent('aurea:fisco:incasso', 'iva_servizi', math.floor(prezzo * 0.22), g.citizenid)

    local ingressi = math.floor(tonumber(g:Get('pal_ingressi')) or 0) + PAL.Regole.ingressiPerAbbonamento
    g:Set('pal_ingressi', ingressi, true)

    rispondi(true, ('Abbonamento attivo: %d ingressi.'):format(ingressi))
end)

AUREA.Callback.Registra('pal:allena', function(src, rispondi, idEsercizio)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if inCorso[src] then return rispondi(false, 'Stai già facendo una serie.') end

    local e = PAL.GetEsercizio(idEsercizio)
    if not e then return rispondi(false, 'Esercizio non previsto.') end

    local ingressi = math.floor(tonumber(g:Get('pal_ingressi')) or 0)
    if ingressi <= 0 then return rispondi(false, 'Non hai ingressi: fatti l\'abbonamento.') end

    if (g.stato.fame or 100) < PAL.Regole.minimoPerAllenarsi
       or (g.stato.sete or 100) < PAL.Regole.minimoPerAllenarsi then
        return rispondi(false, 'Sei a pezzi: mangia e bevi prima di allenarti.')
    end

    inCorso[src] = { esercizio = idEsercizio, avviata = os.time() }
    rispondi(true, { nome = e.nome, durata = e.durata, anim = e.anim })
end)

AUREA.Callback.Registra('pal:concludi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione then return rispondi(false, 'Nessuna serie in corso.') end
    inCorso[src] = nil

    local e = PAL.GetEsercizio(sessione.esercizio)
    if not e then return rispondi(false) end

    if (os.time() - sessione.avviata) * 1000 < (e.durata - 2000) then
        return rispondi(false, 'Hai mollato a metà: non conta.')
    end

    local attuale = stat(g, e.statistica)
    local punti = PAL.PuntiEffettivi(e, attuale)
    impostaStat(g, e.statistica, attuale + punti)

    for chiave, delta in pairs(e.costoStato) do g:VariaStato(chiave, delta) end

    local ingressi = math.max(0, math.floor(tonumber(g:Get('pal_ingressi')) or 0) - 1)
    g:Set('pal_ingressi', ingressi, true)

    local nuovo = stat(g, e.statistica)
    local s = PAL.Statistiche[e.statistica]

    TriggerClientEvent('pal:aggiorna', src, {
        forza = stat(g, 'forza'), resistenza = stat(g, 'resistenza'),
    })

    rispondi(true, ('%s: +%d. %s ora è %d su %d.%s')
        :format(e.nome, punti, s.nome, nuovo, s.massimo,
                ingressi == 0 and ' Hai finito gli ingressi.' or ''))
end)

--- Chi smette di allenarsi torna indietro.
CreateThread(function()
    while true do
        Wait(PAL.Regole.minutiControllo * 60000)
        for src, g in pairs(AUREA.Giocatori) do
            for nome in pairs(PAL.Statistiche) do
                local v = stat(g, nome)
                if v > 0 then
                    impostaStat(g, nome, v - (PAL.Regole.decadimentoGiornaliero / 24))
                end
            end
            TriggerClientEvent('pal:aggiorna', src, {
                forza = stat(g, 'forza'), resistenza = stat(g, 'resistenza'),
            })
        end
    end
end)

--- All'ingresso in partita il client riceve i suoi valori.
AddEventHandler('aurea:giocatore:caricato', function(src, g)
    TriggerClientEvent('pal:aggiorna', src, {
        forza = stat(g, 'forza'), resistenza = stat(g, 'resistenza'),
    })
end)

AddEventHandler('playerDropped', function() inCorso[source] = nil end)
