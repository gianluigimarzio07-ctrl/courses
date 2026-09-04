--[[
    AUREA · Lavori (server)
]]

local U = AUREA.Util
local missioni = {}     -- [src] = { tipo, compenso, scadenza, distanza }

-- ---------------------------------------------------------------------------
--  Centro per l'Impiego
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('lav:disponibili', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for _, nome in ipairs(LAV.CentroImpiego.liberi) do
        local l = AUREA.Lavori[nome]
        if l then
            local grado = l.gradi[0]
            out[#out + 1] = {
                nome = nome,
                etichetta = l.etichetta,
                mansione = grado.etichetta,
                stipendio = grado.stipendio,
                attuale = g.lavoro.nome == nome,
            }
        end
    end
    rispondi(out)
end)

AUREA.Callback.Registra('lav:assumi', function(src, rispondi, lavoro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if not U.Contiene(LAV.CentroImpiego.liberi, lavoro) then
        return rispondi(false, 'Questa posizione richiede un colloquio diretto con il datore di lavoro.')
    end

    -- Chi indossa una divisa non può cambiare lavoro con un clic
    local attuale = AUREA.GetLavoro(g.lavoro.nome)
    if attuale.servizio and g.lavoro.servizio then
        return rispondi(false, 'Chiudi prima il turno di servizio in corso.')
    end

    g:ImpostaLavoro(lavoro, 0)
    rispondi(true, ('Assunto come %s.'):format(AUREA.EtichettaLavoro(lavoro, 0)))
end)

AUREA.Callback.Registra('lav:dimissioni', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    g:ImpostaLavoro('disoccupato', 0)
    rispondi(true, 'Rapporto di lavoro cessato. Hai diritto al sussidio di disoccupazione.')
end)

-- ---------------------------------------------------------------------------
--  Missioni
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('lav:iniziaMissione', function(src, rispondi, tipo, distanza)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end
    if missioni[src] then return rispondi(nil, 'Hai già un incarico in corso.') end

    distanza = math.max(50, math.min(20000, tonumber(distanza) or 1000))

    if tipo == 'consegna' then
        if g.lavoro.nome ~= 'corriere' then return rispondi(nil, 'Non sei un corriere.') end

        local meta = LAV.Consegne[math.random(#LAV.Consegne)]
        local tempo = math.ceil((distanza / 100) * LAV.Regole.secondiPer100m)

        missioni[src] = {
            tipo = 'consegna',
            compenso = meta.compenso,
            scadenza = os.time() + tempo,
            destinazione = meta,
        }

        return rispondi({
            nome = meta.nome,
            coord = { x = meta.coord.x, y = meta.coord.y, z = meta.coord.z },
            compenso = meta.compenso,
            secondi = tempo,
        })

    elseif tipo == 'taxi' then
        if g.lavoro.nome ~= 'tassista' then return rispondi(nil, 'Non sei un tassista.') end

        local partenza = LAV.Fermate[math.random(#LAV.Fermate)]
        local arrivo = partenza
        while arrivo.nome == partenza.nome do arrivo = LAV.Fermate[math.random(#LAV.Fermate)] end

        local km = #(partenza.coord - arrivo.coord) / 1000
        local compenso = LAV.Regole.taxiScatto + math.floor(km * LAV.Regole.taxiAlKm)

        missioni[src] = {
            tipo = 'taxi',
            compenso = compenso,
            scadenza = os.time() + math.ceil(km * 240),
            destinazione = arrivo,
        }

        return rispondi({
            partenza = { nome = partenza.nome, coord = { x = partenza.coord.x, y = partenza.coord.y, z = partenza.coord.z } },
            arrivo = { nome = arrivo.nome, coord = { x = arrivo.coord.x, y = arrivo.coord.y, z = arrivo.coord.z } },
            compenso = compenso,
            km = U.Round(km, 1),
        })
    end

    rispondi(nil, 'Tipo di incarico non riconosciuto.')
end)

AUREA.Callback.Registra('lav:concludiMissione', function(src, rispondi, danniVeicolo)
    local g = AUREA.GetPlayer(src)
    local m = missioni[src]
    if not g or not m then return rispondi(false, 'Nessun incarico in corso.') end
    missioni[src] = nil

    -- Verifica della posizione: il server controlla che si sia davvero arrivati
    local posizione = GetEntityCoords(GetPlayerPed(src))
    local destinazione = m.destinazione.coord
    if #(posizione - destinazione) > 40.0 then
        return rispondi(false, 'Non sei alla destinazione indicata.')
    end

    local compenso = m.compenso

    if os.time() <= m.scadenza then
        compenso = math.floor(compenso * (1 + LAV.Regole.bonusPuntualita))
    end

    if danniVeicolo and tonumber(danniVeicolo) and tonumber(danniVeicolo) > 250 then
        compenso = math.floor(compenso * (1 - LAV.Regole.penaleDanni))
    end

    -- Il compenso è reddito: si applica la ritenuta
    local ritenuta = math.floor(compenso * 0.20)
    g:Aggiungi('contanti', compenso - ritenuta, ('compenso %s'):format(m.tipo))
    TriggerEvent('aurea:fisco:ritenuta', g.citizenid, ritenuta, 'irpef')

    rispondi(true, ('Incarico completato: %s netti (ritenuta %s).%s'):format(
        U.Euro(compenso - ritenuta), U.Euro(ritenuta),
        os.time() <= m.scadenza and ' Bonus puntualità applicato.' or ''))
end)

AUREA.Callback.Registra('lav:annullaMissione', function(src, rispondi)
    missioni[src] = nil
    rispondi(true)
end)

AddEventHandler('playerDropped', function() missioni[source] = nil end)

-- ---------------------------------------------------------------------------
--  Officina
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('lav:riparazione', function(src, rispondi, targa, gratuita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    -- Un meccanico ripara a titolo professionale, gli altri pagano
    local eMeccanico = g.lavoro.nome == 'meccanico' and g:HaPermessoLavoro('ripara')

    if not eMeccanico then
        if not g:SottraiOvunque(LAV.Regole.costoRiparazione, 'riparazione veicolo') then
            return rispondi(false, ('La riparazione costa %s.'):format(U.Euro(LAV.Regole.costoRiparazione)))
        end
        TriggerEvent('aurea:fisco:incasso', 'iva', math.floor(LAV.Regole.costoRiparazione * 0.18), g.citizenid)
    end

    if targa then
        MySQL.update('UPDATE veicoli SET motore = 1000, carrozzeria = 1000 WHERE targa = ?',
            { tostring(targa):upper():gsub('%s+', '') })
    end

    rispondi(true, eMeccanico and 'Riparazione eseguita.' or ('Riparazione eseguita per %s.'):format(U.Euro(LAV.Regole.costoRiparazione)))
end)

-- ---------------------------------------------------------------------------
--  Consumo degli attrezzi usati dal client
-- ---------------------------------------------------------------------------
RegisterNetEvent('lav:consumaKit', function()
    local g = AUREA.GetPlayer(source)
    if g then exports.aurea_inventory:Rimuovi(g.citizenid, 'kit_riparazione', 1) end
end)

RegisterNetEvent('lav:consumaTanica', function()
    local g = AUREA.GetPlayer(source)
    if g then exports.aurea_inventory:Rimuovi(g.citizenid, 'tanica', 1) end
end)

-- ---------------------------------------------------------------------------
--  Sussidio di disoccupazione
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(60000)
    while true do
        Wait(LAV.CentroImpiego.sussidio.minuti * 60000)

        for _, g in pairs(AUREA.Giocatori) do
            if g.lavoro.nome == 'disoccupato' and not g.metadata.detenuto then
                g:Aggiungi('banca', LAV.CentroImpiego.sussidio.importo, 'sussidio di disoccupazione')
                TriggerEvent('aurea:fisco:erogazione', 'sussidi', LAV.CentroImpiego.sussidio.importo, g.citizenid)
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'info', icona = '🏛', durata = 8000,
                    titolo = 'Sussidio erogato',
                    testo = ('%s accreditati. Al Centro per l\'Impiego trovi le offerte di lavoro.'):format(
                        U.Euro(LAV.CentroImpiego.sussidio.importo)),
                })
            end
        end
    end
end)
