--[[
    AUREA · Animali (server)
]]

local U = AUREA.Util

local function mio(citizenid)
    return MySQL.single.await('SELECT * FROM animali WHERE proprietario = ? AND fuggito = 0', { citizenid })
end

--- Fame e affetto scendono col tempo reale: si calcolano quando servono,
--- così non serve un ciclo che tocca il database ogni minuto.
local function aggiorna(a)
    if not a then return nil end

    local trascorsi = os.time() - math.floor((a.aggiornato_il or 0) / 1000)
    local minuti = trascorsi / 60

    a.fame = math.floor(U.Clamp((a.fame or 100) - minuti / ANI.Bisogni.minutiPerPunto, 0, 100))
    a.affetto = math.floor(U.Clamp((a.affetto or 50) - minuti / ANI.Affetto.minutiPerCalo, 0, ANI.Affetto.massimo))

    -- Trascurato troppo a lungo: se ne va
    if a.fame <= 0 and minuti > ANI.Bisogni.minutiPrimaDellaFuga then
        MySQL.update('UPDATE animali SET fuggito = 1 WHERE id = ?', { a.id })

        local g = AUREA.GetPlayerByCitizenId(a.proprietario)
        if g then
            TriggerClientEvent('ani:fuggito', g.source)
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🐕', durata = 18000,
                titolo = ('%s se n\'è andato'):format(a.nome),
                testo = 'L\'hai lasciato senza mangiare troppo a lungo. Al canile ce ne sono altri.',
            })
        end
        return nil
    end

    MySQL.update('UPDATE animali SET fame = ?, affetto = ? WHERE id = ?', { a.fame, a.affetto, a.id })
    return a
end

AUREA.Callback.Registra('ani:mio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local a = aggiorna(mio(g.citizenid))
    if not a then return rispondi(nil) end

    local razza = ANI.GetRazza(a.razza)
    rispondi({
        id = a.id, nome = a.nome, razza = a.razza,
        razzaNome = razza and razza.nome or a.razza,
        modello = razza and razza.modello or 'a_c_retriever',
        guardia = razza and razza.guardia or false,
        velocita = razza and razza.velocita or 1.0,
        fame = a.fame, affetto = a.affetto,
        microchip = a.microchip == 1,
    })
end)

-- ---------------------------------------------------------------------------
--  Adozione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ani:razze', function(src, rispondi)
    local out = {}
    for id, r in pairs(ANI.Razze) do
        out[#out + 1] = { id = id, nome = r.nome, guardia = r.guardia, velocita = r.velocita }
    end
    table.sort(out, function(a, b) return a.nome < b.nome end)
    rispondi({ razze = out, costo = ANI.Canile.costoAdozione })
end)

AUREA.Callback.Registra('ani:adotta', function(src, rispondi, razza, nome)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if #(GetEntityCoords(GetPlayerPed(src)) - ANI.Canile.coord) > 6.0 then
        return rispondi(false, 'Devi essere al canile.')
    end

    if not ANI.GetRazza(razza) then return rispondi(false, 'Razza non disponibile.') end
    if mio(g.citizenid) then return rispondi(false, 'Hai già un animale. Uno alla volta.') end

    nome = tostring(nome or ''):gsub('[^%w%sàèéìòù\'-]', ''):sub(1, 20)
    if #nome < 2 then return rispondi(false, 'Dagli un nome.') end

    if not g:SottraiOvunque(ANI.Canile.costoAdozione, 'adozione e microchip') then
        return rispondi(false, ('Servono %s per microchip e vaccinazioni.')
            :format(U.Euro(ANI.Canile.costoAdozione)))
    end
    TriggerEvent('aurea:fisco:incasso', 'diritti_asl', ANI.Canile.costoAdozione, g.citizenid)

    MySQL.insert.await([[
        INSERT INTO animali (proprietario, nome, razza, fame, affetto, microchip)
        VALUES (?, ?, ?, 100, 50, 1)
    ]], { g.citizenid, nome, razza })

    AUREA.Log('staff', 'debug', g, ('ha adottato %s (%s)'):format(nome, razza))
    rispondi(true, ('%s è tuo. Iscritto all\'anagrafe, microchip incluso.'):format(nome))
end)

-- ---------------------------------------------------------------------------
--  Cura
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ani:nutri', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local a = aggiorna(mio(g.citizenid))
    if not a then return rispondi(false, 'Non hai un animale.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(ANI.Bisogni.cibo, 1) then
        return rispondi(false, 'Non hai crocchette.')
    end

    inventario:Rimuovi(ANI.Bisogni.cibo, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local fame = math.min(100, a.fame + ANI.Bisogni.puntiPerPasto)
    local affetto = math.min(ANI.Affetto.massimo, a.affetto + ANI.Affetto.puntiPerPasto)
    MySQL.update('UPDATE animali SET fame = ?, affetto = ? WHERE id = ?', { fame, affetto, a.id })

    rispondi(true, ('%s ha mangiato. Fame %d%%, affetto %d%%.'):format(a.nome, fame, affetto))
end)

AUREA.Callback.Registra('ani:coccola', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local a = aggiorna(mio(g.citizenid))
    if not a then return rispondi(false, 'Non hai un animale.') end

    local affetto = math.min(ANI.Affetto.massimo, a.affetto + ANI.Affetto.puntiPerCarezza)
    MySQL.update('UPDATE animali SET affetto = ? WHERE id = ?', { affetto, a.id })

    rispondi(true, ('Affetto al %d%%.'):format(affetto))
end)

--- Il cane che cerca: dice se nel raggio c'è qualcuno con roba addosso.
AUREA.Callback.Registra('ani:cerca', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local a = aggiorna(mio(g.citizenid))
    if not a then return rispondi(nil, 'Non hai un animale.') end

    local razza = ANI.GetRazza(a.razza)
    if not razza or not razza.guardia then return rispondi(nil, 'Non è un cane addestrato.') end
    if a.affetto < 60 then return rispondi(nil, 'Non ti dà retta abbastanza.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local trovati = 0

    for altroSrc, altro in pairs(AUREA.Giocatori) do
        if altroSrc ~= src then
            local d = #(coord - GetEntityCoords(GetPlayerPed(altroSrc)))
            if d < 12.0 then
                local inv = exports.aurea_inventory:Inventario(altro.citizenid)
                for _, riga in ipairs(inv.item) do
                    local dati = AUREA.Item[riga.nome]
                    if dati and (dati.categoria == 'illegale' or dati.categoria == 'armi') then
                        trovati = trovati + 1
                        break
                    end
                end
            end
        end
    end

    rispondi({ segnalazioni = trovati })
end)

--- Controllo del microchip da parte delle forze dell'ordine.
AUREA.Callback.Registra('ani:controlla', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not soggetto then return rispondi(nil, 'Persona non trovata.') end
    if not g.lavoro.servizio or not AUREA.EForzaOrdine(g.lavoro.nome) then
        return rispondi(nil, 'Non sei in servizio.')
    end

    local a = mio(soggetto.citizenid)
    if not a then return rispondi(nil, 'Il soggetto non risulta detenere animali.') end

    if a.microchip == 1 then
        return rispondi({ regolare = true, nome = a.nome },
            ('%s, iscritto regolarmente all\'anagrafe.'):format(a.nome))
    end

    soggetto:SottraiOvunque(ANI.Regole.sanzioneSenzaMicrochip, ANI.Regole.articoloSanzione)
    TriggerEvent('aurea:fisco:incasso', 'sanzioni_asl', ANI.Regole.sanzioneSenzaMicrochip, soggetto.citizenid)

    rispondi({ regolare = false, nome = a.nome },
        ('%s non è microchippato: sanzione di %s.')
            :format(a.nome, U.Euro(ANI.Regole.sanzioneSenzaMicrochip)))
end)
