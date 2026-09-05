--[[
    AUREA · Ristorazione (server)
]]

local U = AUREA.Util
local comande = {}      -- [id] = { locale, cliente, piatto, aperta, presa, tavolo }
local contatore = 0
local inCucina = {}     -- [src] = { piatto, avviata }

-- ---------------------------------------------------------------------------
--  Il cliente ordina
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ris:menu', function(src, rispondi, idLocale)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local l = RIS.GetLocale(idLocale)
    if not l then return rispondi(nil, 'Locale sconosciuto.') end

    local out = {}
    for id, r in pairs(RIS.Ricette) do
        if r.locale == idLocale then
            out[#out + 1] = { id = id, nome = r.nome, icona = r.icona, prezzo = r.prezzo }
        end
    end
    table.sort(out, function(a, b) return a.prezzo < b.prezzo end)

    local inServizio = 0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.lavoro.nome == l.lavoro and altro.lavoro.servizio then
            inServizio = inServizio + 1
        end
    end

    rispondi({ locale = l.nome, piatti = out, personale = inServizio })
end)

AUREA.Callback.Registra('ris:ordina', function(src, rispondi, idLocale, piatto)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local l = RIS.GetLocale(idLocale)
    local r = RIS.GetRicetta(piatto)
    if not l or not r or r.locale ~= idLocale then return rispondi(false, 'Piatto non in carta.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - l.banco) > 20.0 then return rispondi(false, 'Non sei nel locale.') end

    local aperte = 0
    for _, c in pairs(comande) do
        if c.locale == idLocale and not c.servita then aperte = aperte + 1 end
    end
    if aperte >= RIS.Comande.massime then
        return rispondi(false, 'Il locale è pieno di comande: aspetta il tuo turno.')
    end

    contatore = contatore + 1
    comande[contatore] = {
        id = contatore, locale = idLocale, cliente = g.citizenid,
        nomeCliente = g:NomeCompleto(), piatto = piatto, aperta = os.time(),
    }

    exports.aurea_ui:NotificaLavoro(l.lavoro, {
        tipo = 'info', icona = r.icona, durata = 12000,
        titolo = 'Nuova comanda',
        testo = ('%s ha ordinato %s. Vedi /comande.'):format(g:NomeCompleto(), r.nome),
    }, true)

    rispondi(true, ('Ordinato: %s. Aspetta che te lo preparino.'):format(r.nome))
end)

AUREA.Callback.Registra('ris:comande', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for _, c in pairs(comande) do
        local l = RIS.GetLocale(c.locale)
        if not c.servita and l and l.lavoro == g.lavoro.nome then
            local r = RIS.GetRicetta(c.piatto)
            out[#out + 1] = {
                id = c.id, cliente = c.nomeCliente,
                piatto = r and r.nome or c.piatto,
                icona = r and r.icona or '🍽',
                minuti = math.floor((os.time() - c.aperta) / 60),
                pronta = c.pronta == true,
            }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  La cucina
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ris:prepara', function(src, rispondi, idComanda)
    local g = AUREA.GetPlayer(src)
    local c = comande[idComanda]
    if not g or not c then return rispondi(false, 'Comanda non trovata.') end

    local l = RIS.GetLocale(c.locale)
    if not l or g.lavoro.nome ~= l.lavoro or not g.lavoro.servizio then
        return rispondi(false, 'Non sei in servizio in questo locale.')
    end
    if c.pronta then return rispondi(false, 'È già pronta.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - l.cucina) > 4.0 then
        return rispondi(false, 'Devi essere in cucina.')
    end

    local r = RIS.GetRicetta(c.piatto)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    for _, ing in ipairs(r.ingredienti) do
        if not inventario:Ha(ing.item, ing.quantita) then
            return rispondi(false, ('Manca %d× %s.')
                :format(ing.quantita, AUREA.Item[ing.item].etichetta))
        end
    end

    inCucina[src] = { comanda = idComanda, avviata = os.time() }
    rispondi(true, { nome = r.nome, durata = r.durata })
end)

AUREA.Callback.Registra('ris:concludiPreparazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCucina[src]
    if not g or not sessione then return rispondi(false, 'Nessuna preparazione in corso.') end
    inCucina[src] = nil

    local c = comande[sessione.comanda]
    if not c then return rispondi(false, 'La comanda non esiste più.') end

    local r = RIS.GetRicetta(c.piatto)
    if (os.time() - sessione.avviata) * 1000 < (r.durata - 2000) then
        return rispondi(false, 'Non era pronto: hai rovinato il piatto.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    for _, ing in ipairs(r.ingredienti) do
        if not inventario:Ha(ing.item, ing.quantita) then
            return rispondi(false, 'Gli ingredienti sono finiti.')
        end
    end
    for _, ing in ipairs(r.ingredienti) do inventario:Rimuovi(ing.item, ing.quantita) end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    c.pronta = true
    c.prontaAlle = os.time()
    c.cuoco = g.citizenid

    local cliente = AUREA.GetPlayerByCitizenId(c.cliente)
    if cliente then
        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
            tipo = 'successo', icona = r.icona, durata = 11000,
            titolo = ('%s è pronto'):format(r.nome),
            testo = 'Aspetta che te lo portino al tavolo.',
        })
    end

    rispondi(true, ('%s pronto. Portalo al cliente.'):format(r.nome))
end)

-- ---------------------------------------------------------------------------
--  Il servizio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ris:servi', function(src, rispondi, idComanda)
    local g = AUREA.GetPlayer(src)
    local c = comande[idComanda]
    if not g or not c then return rispondi(false, 'Comanda non trovata.') end
    if not c.pronta then return rispondi(false, 'Non è ancora pronto.') end
    if c.servita then return rispondi(false, 'Già servita.') end

    local l = RIS.GetLocale(c.locale)
    if not l or g.lavoro.nome ~= l.lavoro then return rispondi(false, 'Non lavori qui.') end

    local cliente = AUREA.GetPlayerByCitizenId(c.cliente)
    if not cliente then return rispondi(false, 'Il cliente se n\'è andato.') end

    local coordCameriere = GetEntityCoords(GetPlayerPed(src))
    local coordCliente = GetEntityCoords(GetPlayerPed(cliente.source))
    if #(coordCameriere - coordCliente) > RIS.Servizio.distanzaServizio then
        return rispondi(false, 'Devi essere davanti al cliente.')
    end

    local r = RIS.GetRicetta(c.piatto)

    -- Il piatto vale di più se servito al tavolo e caldo
    local prezzo = r.prezzo
    local alTavolo = false
    for _, t in ipairs(l.tavoli) do
        if #(coordCliente - t) < 3.0 then alTavolo = true break end
    end
    if alTavolo then prezzo = math.floor(prezzo * (1 + RIS.Servizio.bonusAlTavolo)) end

    local freddo = (os.time() - (c.prontaAlle or os.time())) / 60 > RIS.Servizio.minutiPrimaDiRaffreddarsi
    if freddo then prezzo = math.floor(prezzo * RIS.Servizio.penalitaFreddo) end

    if not cliente:SottraiOvunque(prezzo, ('%s · %s'):format(l.nome, r.nome)) then
        return rispondi(false, 'Il cliente non ha di che pagare.')
    end

    -- Il piatto arriva al cliente come oggetto, con l'effetto potenziato
    local invCliente = exports.aurea_inventory:Inventario(cliente.citizenid)
    invCliente:Aggiungi(c.piatto, 1, {
        fattoAMano = true,
        cuoco = c.cuoco,
        locale = l.nome,
        potenza = RIS.Servizio.bonusFattoAMano,
    })
    TriggerClientEvent('inv:aggiorna', cliente.source, invCliente:Pacchetto())

    c.servita = true

    local quotaLocale = math.floor(prezzo * RIS.Servizio.quotaLocale)
    g:Aggiungi('contanti', prezzo - quotaLocale, ('servizio · %s'):format(r.nome))
    TriggerEvent('aurea:fisco:incasso', 'iva_ristorazione', quotaLocale, cliente.citizenid)

    TriggerClientEvent('aurea:ui:notifica', cliente.source, {
        tipo = 'successo', icona = r.icona, durata = 11000,
        titolo = ('%s servito'):format(r.nome),
        testo = ('%s%s. Pagati %s.'):format(
            alTavolo and 'Al tavolo' or 'Al banco',
            freddo and ', ma era freddo' or '', U.Euro(prezzo)),
    })

    rispondi(true, ('%s servito%s. Incassati %s.'):format(r.nome,
        alTavolo and ' al tavolo' or '', U.Euro(prezzo - quotaLocale)))
end)

--- Il piatto fatto a mano nutre di più di quello comprato.
CreateThread(function()
    Wait(2000)
    for id, r in pairs(RIS.Ricette) do
        if AUREA.Item[id] then
            exports.aurea_inventory:RegistraUso(id, function(g, riga)
                local potenza = (riga.metadata and tonumber(riga.metadata.potenza)) or 1.0
                for chiave, delta in pairs(r.effetto) do
                    g:VariaStato(chiave, math.floor(delta * potenza))
                end
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'successo', icona = r.icona, durata = 8000,
                    titolo = r.nome,
                    testo = riga.metadata and riga.metadata.locale
                        and ('Fatto da %s. Molto meglio di quello del distributore.')
                            :format(riga.metadata.locale)
                        or 'Buono, ma industriale.',
                })
                return true
            end)
        end
    end
end)

--- Le comande dimenticate decadono.
CreateThread(function()
    while true do
        Wait(120000)
        local adesso = os.time()
        for id, c in pairs(comande) do
            if c.servita or (adesso - c.aperta) / 60 > RIS.Comande.minutiScadenza then
                if not c.servita then
                    local cliente = AUREA.GetPlayerByCitizenId(c.cliente)
                    if cliente then
                        TriggerClientEvent('aurea:ui:notifica', cliente.source, {
                            tipo = 'avviso', icona = '🍽', durata = 11000,
                            titolo = 'Comanda annullata',
                            testo = 'Nessuno ha preparato il tuo ordine. Riprova più tardi.',
                        })
                    end
                end
                comande[id] = nil
            end
        end
    end
end)

AddEventHandler('playerDropped', function() inCucina[source] = nil end)
