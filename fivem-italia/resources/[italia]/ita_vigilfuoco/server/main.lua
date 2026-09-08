--[[
    AUREA · Vigili del Fuoco (server)

    L'incendio vive qui. Il client lo disegna e basta: le fiamme che vedi
    sono un riflesso di una tabella su questo lato, e chi si modifica il
    client si toglie il fuoco dallo schermo ma non lo spegne per gli altri
    e non chiude l'intervento.

    L'acqua è la stessa cosa: il litraggio dell'autobotte lo tiene il
    server, e il client non può che chiedere di consumarne.
]]

local U = AUREA.Util

local incendi = {}      -- [id] = { tipologia, zona, focolai, aperto, presa, ... }
local contatore = 0
local acqua = {}        -- [targa] = litri
local incastrati = {}   -- [citizenid] = { veicolo, da }

-- ---------------------------------------------------------------------------
--  Chi è di turno
-- ---------------------------------------------------------------------------
local function inServizio()
    return AUREA.GetGiocatoriPerLavoro(VVF.Lavoro, true)
end

local function vigile(g, permesso)
    if not g then return false end
    if g.lavoro.nome ~= VVF.Lavoro or not g.lavoro.servizio then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

-- ---------------------------------------------------------------------------
--  Pubblicazione dello stato
--
--  Va a tutti, non solo ai vigili: un incendio lo vede chiunque passi.
-- ---------------------------------------------------------------------------
local function pacchettoIncendio(inc)
    local focolai = {}
    for _, f in ipairs(inc.focolai) do
        if f.intensita > 0 then
            focolai[#focolai + 1] = {
                id = f.id,
                x = f.coord.x, y = f.coord.y, z = f.coord.z,
                intensita = math.floor(f.intensita),
            }
        end
    end

    return {
        id = inc.id,
        tipologia = inc.tipologia,
        nome = VVF.GetTipologia(inc.tipologia).nome,
        zona = inc.zona,
        focolai = focolai,
        senzaAcqua = VVF.GetTipologia(inc.tipologia).senzaAcqua or false,
        richiedeAutorespiratore = VVF.GetTipologia(inc.tipologia).richiedeAutorespiratore or false,
    }
end

local function pubblica(inc)
    TriggerClientEvent('vvf:incendio', -1, pacchettoIncendio(inc))
end

local function chiudi(inc, spento)
    inc.chiuso = true
    TriggerClientEvent('vvf:incendioChiuso', -1, inc.id)

    if spento then
        local squadra = {}
        for citizenid in pairs(inc.intervenuti) do squadra[#squadra + 1] = citizenid end

        if #squadra > 0 then
            local t = VVF.GetTipologia(inc.tipologia)
            -- Il compenso si divide, ma non si dimezza: intervenire in due
            -- su un incendio grande deve restare conveniente
            local quota = math.floor(t.compenso / math.max(1, #squadra) * 1.4)

            for _, citizenid in ipairs(squadra) do
                AUREA.Denaro.AggiungiOffline(citizenid, 'banca', quota, 'intervento di soccorso')
                TriggerEvent('aurea:fisco:erogazione', 'soccorso', quota, citizenid)

                local g = AUREA.GetPlayerByCitizenId(citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'successo', icona = '🚒', durata = 14000,
                        titolo = 'Intervento concluso',
                        testo = ('%s domato. Competenze: %s.'):format(t.nome, U.Euro(quota)),
                    })
                end
            end
        end

        AUREA.Log('soccorso', 'info', nil,
            ('Incendio %d (%s, %s) domato da %d operatori'):format(inc.id, inc.tipologia, inc.zona, #squadra))
    else
        exports.aurea_ui:NotificaLavoro(VVF.Lavoro, {
            tipo = 'errore', icona = '🔥', durata = 16000,
            titolo = 'Intervento chiuso senza esito',
            testo = ('%s in zona %s: le fiamme si sono esaurite da sole. Niente competenze.')
                :format(VVF.GetTipologia(inc.tipologia).nome, inc.zona),
        }, true)

        AUREA.Log('soccorso', 'avviso', nil,
            ('Incendio %d (%s) autoestinto: nessun intervento'):format(inc.id, inc.tipologia))
    end

    incendi[inc.id] = nil
end

-- ---------------------------------------------------------------------------
--  Nascita di un incendio
-- ---------------------------------------------------------------------------
local function nuovoFocolaio(inc, coord)
    inc.prossimoFocolaio = (inc.prossimoFocolaio or 0) + 1
    inc.focolai[#inc.focolai + 1] = {
        id = inc.prossimoFocolaio,
        coord = coord,
        intensita = VVF.Fuoco.intensitaIniziale,
    }
end

--- Accende un incendio. Chiamabile da altre risorse: un laboratorio che
--- esplode, un veicolo che prende fuoco, un incidente.
local function accendi(tipologia, coord, zona, focolaiIniziali)
    local t = VVF.GetTipologia(tipologia)
    if not t then return nil end

    contatore = contatore + 1
    local inc = {
        id = contatore,
        tipologia = tipologia,
        zona = zona or 'posizione segnalata',
        focolai = {},
        intervenuti = {},
        aperto = os.time(),
    }

    local quanti = focolaiIniziali or t.focolaiIniziali
    local centro = vector3(coord.x, coord.y, coord.z)

    for n = 1, quanti do
        local angolo = math.random() * math.pi * 2
        local raggio = n == 1 and 0.0 or (math.random(15, 45) / 10.0)
        nuovoFocolaio(inc, vector3(
            centro.x + math.cos(angolo) * raggio,
            centro.y + math.sin(angolo) * raggio,
            centro.z))
    end

    incendi[inc.id] = inc
    pubblica(inc)

    TriggerEvent('aurea:112:allerta',
        tipologia == 'gas' and 'fuga_gas' or 'incendio',
        { x = centro.x, y = centro.y, z = centro.z },
        ('%s. %s'):format(t.nome, t.descrizione),
        'segnalazione dei presenti')

    exports.aurea_ui:NotificaLavoro(VVF.Lavoro, {
        tipo = 'errore', icona = t.icona, durata = 20000,
        titolo = ('INTERVENTO — %s'):format(t.nome),
        testo = ('%s · %d focolai. Usa /interventi per la posizione.'):format(inc.zona, quanti),
    }, true)

    return inc.id
end

exports('AccendiIncendio', accendi)

AddEventHandler('aurea:vigilfuoco:incendio', function(tipologia, coord, zona, focolai)
    accendi(tipologia, coord, zona, focolai)
end)

-- ---------------------------------------------------------------------------
--  Il ciclo del fuoco
--
--  Ogni due secondi ogni focolaio cresce, e quelli abbastanza grandi ne
--  accendono uno vicino. È qui che si decide se la squadra ce la fa.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)

        for _, inc in pairs(incendi) do
            if not inc.chiuso then
                local t = VVF.GetTipologia(inc.tipologia)
                local vivi, sommaIntensita = 0, 0

                for _, f in ipairs(inc.focolai) do
                    if f.intensita > 0 then
                        vivi = vivi + 1

                        -- Cresce solo se nessuno ci sta buttando acqua adesso
                        if not f.bagnatoFino or f.bagnatoFino < os.time() then
                            local crescita = VVF.Fuoco.crescitaPerTick
                            if t.sensibileAlMeteo and GlobalState.siccita then
                                crescita = crescita * 1.8
                            end
                            f.intensita = math.min(100, f.intensita + crescita)
                        end

                        sommaIntensita = sommaIntensita + f.intensita

                        -- Propagazione
                        if f.intensita >= VVF.Fuoco.sogliaPropagazione
                            and #inc.focolai < VVF.Fuoco.massimoFocolai
                            and math.random(100) <= 22 then
                            local angolo = math.random() * math.pi * 2
                            nuovoFocolaio(inc, vector3(
                                f.coord.x + math.cos(angolo) * VVF.Fuoco.distanzaPropagazione,
                                f.coord.y + math.sin(angolo) * VVF.Fuoco.distanzaPropagazione,
                                f.coord.z))
                        end
                    end
                end

                if vivi == 0 then
                    chiudi(inc, true)
                elseif (os.time() - inc.aperto) > VVF.Spontanei.minutiAutoestinzione * 60 then
                    chiudi(inc, false)
                else
                    pubblica(inc)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Incendi spontanei
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(90000)

    while true do
        Wait(VVF.Spontanei.minutiControllo * 60000)

        local aperti = 0
        for _ in pairs(incendi) do aperti = aperti + 1 end
        if aperti < VVF.Spontanei.massimoAperti then
            local squadra = #inServizio()
            local probabilita = squadra > 0 and VVF.Spontanei.probabilita
                or VVF.Spontanei.probabilitaSenzaVigili

            if math.random(100) <= probabilita then
                local zona = VVF.Zone[math.random(#VVF.Zone)]
                local tipologia = zona.tipologie[math.random(#zona.tipologie)]

                -- La siccità porta i boschivi
                if GlobalState.siccita and math.random(100) <= 55 then
                    for _, z in ipairs(VVF.Zone) do
                        if U.Contiene(z.tipologie, 'boschivo') then
                            zona, tipologia = z, 'boschivo'
                            break
                        end
                    end
                end

                accendi(tipologia, VVF.PuntoInZona(zona), zona.nome)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Elenco degli interventi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vvf:interventi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi({}) end

    local out = {}
    for _, inc in pairs(incendi) do
        if not inc.chiuso then
            local t = VVF.GetTipologia(inc.tipologia)
            local vivi, intensita = 0, 0
            local centro = vector3(0, 0, 0)

            for _, f in ipairs(inc.focolai) do
                if f.intensita > 0 then
                    vivi = vivi + 1
                    intensita = intensita + f.intensita
                    centro = centro + f.coord
                end
            end
            if vivi > 0 then centro = centro / vivi end

            local quanti = 0
            for _ in pairs(inc.intervenuti) do quanti = quanti + 1 end

            out[#out + 1] = {
                id = inc.id, nome = t.nome, icona = t.icona,
                zona = inc.zona, descrizione = t.descrizione,
                focolai = vivi,
                intensitaMedia = vivi > 0 and math.floor(intensita / vivi) or 0,
                minuti = math.floor((os.time() - inc.aperto) / 60),
                operatori = quanti,
                coord = { x = centro.x, y = centro.y, z = centro.z },
            }
        end
    end

    table.sort(out, function(a, b) return a.id < b.id end)
    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Acqua dell'autobotte
-- ---------------------------------------------------------------------------
local function capacitaDi(modello)
    for _, m in ipairs(VVF.Mezzi) do
        if m.modello == modello and m.acqua > 0 then return m.acqua end
    end
    return 3000
end

AUREA.Callback.Registra('vvf:acqua', function(src, rispondi, targa, modello)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(nil) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    if targa == '' then return rispondi(nil) end

    if acqua[targa] == nil then acqua[targa] = capacitaDi(modello) end
    rispondi(acqua[targa], capacitaDi(modello))
end)

AUREA.Callback.Registra('vvf:ricarica', function(src, rispondi, targa, modello)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false, 'Non sei in servizio.') end

    if not VVF.IdranteVicino(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Non sei a un idrante.')
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local capacita = capacitaDi(modello)
    acqua[targa] = math.min(capacita, (acqua[targa] or 0) + VVF.Ricarica.litriAlSecondo)

    rispondi(true, acqua[targa], capacita)
end)

-- ---------------------------------------------------------------------------
--  Spegnimento
--
--  Il client dice "sto bagnando questo focolaio con questo mezzo". Il
--  server verifica tutto: che sia in servizio, che il focolaio esista, che
--  sia abbastanza vicino, che l'acqua ci sia, e solo allora abbassa
--  l'intensità e scala i litri.
-- ---------------------------------------------------------------------------
RegisterNetEvent('vvf:bagna', function(idIncendio, idFocolaio, targa, conEstintore)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not vigile(g, 'estinzione') then return end

    local inc = incendi[idIncendio]
    if not inc or inc.chiuso then return end

    local t = VVF.GetTipologia(inc.tipologia)
    if t.senzaAcqua then return end

    local focolaio
    for _, f in ipairs(inc.focolai) do
        if f.id == idFocolaio and f.intensita > 0 then focolaio = f break end
    end
    if not focolaio then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - focolaio.coord) > 14.0 then return end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)

    if conEstintore then
        if not inv:Ha(VVF.Attrezzatura.estintore, 1) then return end
        if focolaio.intensita > VVF.Fuoco.estintoreIntensitaMassima then
            return TriggerClientEvent('aurea:ui:notifica', src, {
                tipo = 'avviso', icona = '🧯', durata = 6000,
                titolo = 'Troppo grande per l\'estintore',
                testo = 'Serve la lancia.',
            })
        end
        focolaio.intensita = math.max(0, focolaio.intensita - VVF.Fuoco.estintoreAlSecondo)
    else
        if not inv:Ha(VVF.Attrezzatura.lancia, 1) then return end

        targa = tostring(targa or ''):gsub('%s+', ''):upper()
        local litri = acqua[targa]
        if not litri or litri <= 0 then
            return TriggerClientEvent('aurea:ui:notifica', src, {
                tipo = 'errore', icona = '💧', durata = 7000,
                titolo = 'Serbatoio vuoto',
                testo = 'Riporta il mezzo all\'idrante.',
            })
        end

        acqua[targa] = math.max(0, litri - VVF.ConsumoAlSecondo)
        focolaio.intensita = math.max(0, focolaio.intensita - VVF.Fuoco.spegnimentoAlSecondo)
    end

    -- Finché lo bagni non cresce
    focolaio.bagnatoFino = os.time() + 3
    inc.intervenuti[g.citizenid] = true

    pubblica(inc)
end)

--- La fuga di gas si chiude alla valvola, non con l'acqua.
AUREA.Callback.Registra('vvf:intercetta', function(src, rispondi, idIncendio)
    local g = AUREA.GetPlayer(src)
    if not vigile(g, 'estinzione') then return rispondi(false, 'Non sei in servizio.') end

    local inc = incendi[idIncendio]
    if not inc or inc.chiuso then return rispondi(false, 'Intervento non più aperto.') end

    local t = VVF.GetTipologia(inc.tipologia)
    if not t.senzaAcqua then return rispondi(false, 'Qui serve l\'acqua, non la valvola.') end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(VVF.Attrezzatura.autorespiratore, 1) then
        return rispondi(false, 'Senza autorespiratore non si entra.')
    end

    local vicino = false
    for _, f in ipairs(inc.focolai) do
        if f.intensita > 0 and #(GetEntityCoords(GetPlayerPed(src)) - f.coord) < 6.0 then
            vicino = true break
        end
    end
    if not vicino then return rispondi(false, 'Devi essere sul punto della fuga.') end

    inc.intervenuti[g.citizenid] = true
    rispondi(true, 18000)
end)

AUREA.Callback.Registra('vvf:concludiIntercetta', function(src, rispondi, idIncendio)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false) end

    local inc = incendi[idIncendio]
    if not inc or inc.chiuso then return rispondi(false, 'Intervento non più aperto.') end

    for _, f in ipairs(inc.focolai) do f.intensita = 0 end
    inc.intervenuti[g.citizenid] = true

    rispondi(true, 'Valvola intercettata. Fuga chiusa.')
end)

-- ---------------------------------------------------------------------------
--  Estricazione
-- ---------------------------------------------------------------------------
RegisterNetEvent('vvf:incastrato', function(stato)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    if stato then
        if incastrati[g.citizenid] then return end
        incastrati[g.citizenid] = { da = os.time() }

        local coord = GetEntityCoords(GetPlayerPed(src))
        TriggerEvent('aurea:112:allerta', 'persona_bloccata',
            { x = coord.x, y = coord.y, z = coord.z },
            ('Persona incastrata nell\'abitacolo: %s'):format(g:NomeCompleto()),
            'segnalazione dei presenti')

        exports.aurea_ui:NotificaLavoro(VVF.Lavoro, {
            tipo = 'errore', icona = '🚨', durata = 20000,
            titolo = 'ESTRICAZIONE',
            testo = ('Persona incastrata dopo un incidente. Servono le cesoie.'),
        }, true)
    else
        incastrati[g.citizenid] = nil
    end
end)

AUREA.Callback.Registra('vvf:estrica', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not vigile(g, 'estricazione') then
        return rispondi(false, 'L\'estricazione la fa il personale abilitato in servizio.')
    end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b or not incastrati[b.citizenid] then
        return rispondi(false, 'Quella persona non risulta incastrata.')
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > VVF.Estricazione.raggio then
        return rispondi(false, 'Sei troppo lontano dal veicolo.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if not inv:Ha(VVF.Attrezzatura.cesoie, 1) then
        return rispondi(false, 'Servono le cesoie idrauliche.')
    end

    rispondi(true, VVF.Estricazione.durata, b.source, b:NomeCompleto())
end)

AUREA.Callback.Registra('vvf:concludiEstricazione', function(src, rispondi, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false) end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not b or not incastrati[b.citizenid] then return rispondi(false, 'Non è più lì.') end

    incastrati[b.citizenid] = nil
    TriggerClientEvent('vvf:liberato', b.source)

    g:Aggiungi('banca', VVF.Estricazione.compenso, 'estricazione')
    TriggerEvent('aurea:fisco:erogazione', 'soccorso', VVF.Estricazione.compenso, g.citizenid)

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'successo', icona = '🚒', durata = 14000,
        titolo = 'Estricato',
        testo = ('%s ti ha tirato fuori dall\'abitacolo. Adesso serve il 118.'):format(g:NomeCompleto()),
    })

    AUREA.Log('soccorso', 'info', g, ('ha estricato %s'):format(b:NomeCompleto()))
    rispondi(true, ('%s liberato. Competenze %s.'):format(b:NomeCompleto(), U.Euro(VVF.Estricazione.compenso)))
end)

--- Chi resta incastrato peggiora. È la ragione per cui il tempo conta.
CreateThread(function()
    while true do
        Wait(60000)
        for citizenid in pairs(incastrati) do
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            if g then
                TriggerClientEvent('vvf:dannoIncastro', g.source, VVF.Estricazione.dannoPerMinuto)
            else
                incastrati[citizenid] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Armadio di caserma
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vvf:armadio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi({}, 'Non sei in servizio.') end

    local caserma = VVF.CasermaVicina(GetEntityCoords(GetPlayerPed(src)), 6.0)
    if not caserma then return rispondi({}, 'Non sei all\'armadio.') end

    local ammessi = VVF.Attrezzatura.armadio[g.lavoro.grado] or VVF.Attrezzatura.armadio[0]
    local inv = exports.aurea_inventory:Inventario(g.citizenid)

    local out = {}
    for _, nome in ipairs(ammessi) do
        local dati = AUREA.Item[nome]
        if dati then
            out[#out + 1] = { item = nome, etichetta = dati.etichetta, gia = inv:Quantita(nome) }
        end
    end
    rispondi(out)
end)

AUREA.Callback.Registra('vvf:preleva', function(src, rispondi, item)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false, 'Non sei in servizio.') end

    if not VVF.CasermaVicina(GetEntityCoords(GetPlayerPed(src)), 6.0) then
        return rispondi(false, 'Non sei all\'armadio.')
    end

    local ammessi = VVF.Attrezzatura.armadio[g.lavoro.grado] or VVF.Attrezzatura.armadio[0]
    if not U.Contiene(ammessi, item) then
        return rispondi(false, 'Il tuo grado non prevede questa dotazione.')
    end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    if inv:Ha(item, 1) then
        inv:Rimuovi(item, inv:Quantita(item))
        TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
        return rispondi(true, ('%s riposto in armadio.'):format(AUREA.Item[item].etichetta))
    end

    if not inv:Aggiungi(item, 1) then return rispondi(false, 'Non hai spazio.') end
    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
    rispondi(true, ('%s prelevato.'):format(AUREA.Item[item].etichetta))
end)

-- ---------------------------------------------------------------------------
--  Certificato di prevenzione incendi
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('vvf:cpi', function(src, rispondi, richiedenteSrc)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false, 'Non sei in servizio.') end
    if g.lavoro.grado < VVF.CPI.gradoMinimo then
        return rispondi(false, 'Il CPI lo rilascia il capo squadra.')
    end

    local b = AUREA.GetPlayer(tonumber(richiedenteSrc))
    if not b then return rispondi(false, 'Il titolare deve essere davanti a te.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 4.0 then
        return rispondi(false, 'Troppo lontano.')
    end

    if not b:SottraiOvunque(VVF.CPI.onorario, 'sopralluogo antincendio') then
        return rispondi(false, ('Il sopralluogo costa %s.'):format(U.Euro(VVF.CPI.onorario)))
    end

    rispondi(true, VVF.CPI.durata, b.source, b:NomeCompleto())
end)

AUREA.Callback.Registra('vvf:concludiCpi', function(src, rispondi, richiedenteSrc)
    local g = AUREA.GetPlayer(src)
    if not vigile(g) then return rispondi(false) end

    local b = AUREA.GetPlayer(tonumber(richiedenteSrc))
    if not b then return rispondi(false, 'Il titolare se n\'è andato.') end

    local inv = exports.aurea_inventory:Inventario(b.citizenid)
    local scadenza = U.DataPiuGiorni(VVF.CPI.validitaGiorni)

    if not inv:Aggiungi(VVF.CPI.item, 1, {
        intestatario = b:NomeCompleto(),
        rilasciatoDa = g:NomeCompleto(),
        rilascio = U.DataIT(os.time()),
        scadenza = scadenza,
    }) then
        return rispondi(false, 'Il titolare non ha spazio per il documento.')
    end

    TriggerClientEvent('inv:aggiorna', b.source, inv:Pacchetto())

    g:Aggiungi('banca', math.floor(VVF.CPI.onorario * 0.3), 'sopralluogo antincendio')
    TriggerEvent('aurea:fisco:incasso', 'diritti_vvf', math.floor(VVF.CPI.onorario * 0.7), b.citizenid)

    AUREA.Log('soccorso', 'info', g, ('ha rilasciato il CPI a %s'):format(b:NomeCompleto()))
    rispondi(true, ('CPI rilasciato a %s, valido fino al %s.'):format(b:NomeCompleto(), scadenza))
end)

--- Serve ai controlli: l'attività ha il certificato in regola?
exports('CPIValido', function(citizenid)
    local inv = exports.aurea_inventory:Inventario(citizenid)
    if not inv then return false end
    return inv:Ha(VVF.CPI.item, 1)
end)

AddEventHandler('aurea:giocatore:scaricato', function(_, g)
    incastrati[g.citizenid] = nil
end)
