--[[
    AUREA · Attività illecite (server)
]]

local U = AUREA.Util
local piante = {}           -- [id] = { citizenid, coord, piantata, ultimaCura, matura }
local contatorePiante = 0
local inCorso = {}          -- [src] = { tipo, avviata }
local piazze = {}           -- [zona] = { cessioni, azzeramento }
local smontatiOra = {}      -- [ora] = quanti
local posizioneMercato = nil

-- ---------------------------------------------------------------------------
--  Il mercato nero si sposta a ogni riavvio
-- ---------------------------------------------------------------------------
CreateThread(function()
    posizioneMercato = ILL.MercatoNero.posizioni[math.random(#ILL.MercatoNero.posizioni)]
    Wait(4000)
    print(('[AUREA] mercato nero collocato in %.1f %.1f'):format(posizioneMercato.x, posizioneMercato.y))
end)

AUREA.Callback.Registra('ill:mercatoDove', function(src, rispondi)
    if not posizioneMercato then return rispondi(nil) end
    rispondi({ x = posizioneMercato.x, y = posizioneMercato.y, z = posizioneMercato.z })
end)

--- Alza il calore dell'organizzazione, se il soggetto ne fa parte.
local function calore(g, punti, motivo)
    if g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, punti, motivo)
    end
end

-- ---------------------------------------------------------------------------
--  COLTIVAZIONE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:pianta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local mie = 0
    for _, p in pairs(piante) do
        if p.citizenid == g.citizenid then mie = mie + 1 end
    end
    if mie >= ILL.Coltivazione.massimoPiante then
        return rispondi(false, ('Non puoi seguire più di %d piante.'):format(ILL.Coltivazione.massimoPiante))
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(ILL.Coltivazione.seme, 1) then
        return rispondi(false, 'Non hai semi.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))

    -- Non si pianta addosso a un'altra pianta
    for _, p in pairs(piante) do
        if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) < 1.5 then
            return rispondi(false, 'C\'è già una pianta qui.')
        end
    end

    inventario:Rimuovi(ILL.Coltivazione.seme, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    contatorePiante = contatorePiante + 1
    local id = contatorePiante

    piante[id] = {
        citizenid = g.citizenid,
        coord = { x = coord.x, y = coord.y, z = coord.z },
        piantata = os.time(),
        ultimaCura = os.time(),
        alChiuso = ILL.AlChiuso(coord),
    }

    TriggerClientEvent('ill:piantaCreata', -1, id, piante[id].coord, false)
    calore(g, ILL.Coltivazione.calorePiantagione, 'coltivazione')

    rispondi(true, ('Seme interrato. Matura in circa %d minuti, ma va annaffiata.'):format(
        ILL.Coltivazione.minutiCrescita))
end)

AUREA.Callback.Registra('ill:cura', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local p = piante[id]
    if not g or not p then return rispondi(false, 'Pianta non trovata.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > 3.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    if not exports.aurea_inventory:Ha(g.citizenid, ILL.Coltivazione.attrezzo, 1) then
        return rispondi(false, 'Ti serve un annaffiatoio.')
    end

    p.ultimaCura = os.time()

    local trascorsi = (os.time() - p.piantata) / 60
    local percentuale = math.min(100, math.floor((trascorsi / ILL.Coltivazione.minutiCrescita) * 100))

    rispondi(true, ('Pianta curata. Maturazione al %d%%.'):format(percentuale))
end)

AUREA.Callback.Registra('ill:raccogli', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local p = piante[id]
    if not g or not p then return rispondi(false, 'Pianta non trovata.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - vector3(p.coord.x, p.coord.y, p.coord.z)) > 3.0 then
        return rispondi(false, 'Sei troppo lontano.')
    end

    local trascorsi = (os.time() - p.piantata) / 60
    if trascorsi < ILL.Coltivazione.minutiCrescita then
        return rispondi(false, ('Non è matura: mancano %d minuti.'):format(
            math.ceil(ILL.Coltivazione.minutiCrescita - trascorsi)))
    end

    local quantita = math.random(ILL.Coltivazione.resaMinima, ILL.Coltivazione.resaMassima)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if not inventario:Aggiungi(ILL.Coltivazione.grezzo, quantita) then
        return rispondi(false, 'Non hai spazio.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    piante[id] = nil
    TriggerClientEvent('ill:piantaRimossa', -1, id)

    AUREA.Log('giustizia', 'debug', g, ('raccolta di %d dosi grezze'):format(quantita))
    rispondi(true, ('%d× sostanza grezza raccolta.'):format(quantita))
end)

--- Le piante appassiscono e l'odore attira segnalazioni.
CreateThread(function()
    while true do
        Wait(ILL.Coltivazione.minutiControlloOdore * 60000)

        local adesso = os.time()
        local perProprietario = {}

        for id, p in pairs(piante) do
            -- Appassimento
            if (adesso - p.ultimaCura) / 60 > ILL.Coltivazione.minutiSenzaCura then
                piante[id] = nil
                TriggerClientEvent('ill:piantaRimossa', -1, id)

                local g = AUREA.GetPlayerByCitizenId(p.citizenid)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'avviso', icona = '🥀', durata = 9000,
                        titolo = 'Una pianta è seccata',
                        testo = 'Senza acqua non sopravvivono.',
                    })
                end
            elseif not p.alChiuso then
                perProprietario[p.citizenid] = perProprietario[p.citizenid] or {}
                table.insert(perProprietario[p.citizenid], p)
            end
        end

        -- L'odore di più piante insieme finisce per farsi notare
        for citizenid, elenco in pairs(perProprietario) do
            local probabilita = #elenco * ILL.Coltivazione.probabilitaSegnalazionePerPianta
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

--- Le forze dell'ordine possono sequestrare una piantagione.
AUREA.Callback.Registra('ill:sequestraPianta', function(src, rispondi, id)
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

    exports.ita_giustizia:ApriFascicolo(p.citizenid, ILL.Regole.reatoColtivazione,
        g:NomeCompleto(), 'Coltivazione di sostanze stupefacenti')

    piante[id] = nil
    TriggerClientEvent('ill:piantaRimossa', -1, id)

    local proprietario = AUREA.GetPlayerByCitizenId(p.citizenid)
    if proprietario then
        TriggerClientEvent('aurea:ui:notifica', proprietario.source, {
            tipo = 'errore', icona = '🚔', durata = 12000,
            titolo = 'Piantagione sequestrata',
            testo = 'Una tua pianta è stata sequestrata ed è stato aperto un fascicolo.',
        })
    end

    AUREA.Log('giustizia', 'avviso', g, ('sequestro piantagione di %s'):format(p.citizenid))
    rispondi(true, 'Pianta sequestrata e fascicolo aperto.')
end)

-- ---------------------------------------------------------------------------
--  RAFFINAZIONE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:raffina', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local lab = ILL.LaboratorioVicino(coord)
    if not lab then return rispondi(nil, 'Non sei in un laboratorio.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(ILL.Coltivazione.grezzo, ILL.Raffinazione.grezzoPerDose) then
        return rispondi(nil, ('Servono %d dosi grezze.'):format(ILL.Raffinazione.grezzoPerDose))
    end

    inCorso[src] = { tipo = 'raffina', avviata = os.time(), lab = lab.id }
    rispondi({ durata = ILL.Raffinazione.durata, nome = lab.nome })
end)

AUREA.Callback.Registra('ill:concludiRaffina', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione or sessione.tipo ~= 'raffina' then return rispondi(false) end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < ILL.Raffinazione.durata * 0.8 then
        return rispondi(false, 'Processo non valido.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(ILL.Coltivazione.grezzo, ILL.Raffinazione.grezzoPerDose) then
        return rispondi(false, 'La materia prima non c\'è più.')
    end
    inventario:Rimuovi(ILL.Coltivazione.grezzo, ILL.Raffinazione.grezzoPerDose)

    calore(g, ILL.Raffinazione.calore, 'raffinazione')

    -- Il processo può andare storto
    if math.random(100) <= ILL.Raffinazione.probabilitaFallimento then
        TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

        if math.random(100) <= ILL.Raffinazione.probabilitaIncendio then
            local coord = GetEntityCoords(GetPlayerPed(src))
            TriggerClientEvent('ill:incendio', src)
            TriggerEvent('aurea:112:allerta', 'incendio',
                { x = coord.x, y = coord.y, z = coord.z },
                'Principio di incendio con esalazioni.', 'segnalazione anonima')

            return rispondi(false, 'La miscela ha preso fuoco. Il materiale è perduto e i soccorsi sono stati allertati.')
        end

        return rispondi(false, 'La lavorazione è andata storta: il materiale è inutilizzabile.')
    end

    if not inventario:Aggiungi(ILL.Raffinazione.raffinata, 1) then
        return rispondi(false, 'Non hai spazio.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    rispondi(true, 'Una dose raffinata pronta.')
end)

-- ---------------------------------------------------------------------------
--  SPACCIO
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:spaccia', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(ILL.Raffinazione.raffinata, 1) then
        return rispondi(false, 'Non hai nulla da cedere.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local zona = GetNameOfZone(coord.x, coord.y, coord.z)

    -- La piazza si satura: vendere sempre nello stesso posto rende meno
    local piazza = piazze[zona]
    if not piazza or os.time() > piazza.azzeramento then
        piazza = { cessioni = 0, azzeramento = os.time() + ILL.Spaccio.minutiRecuperoPiazza * 60 }
        piazze[zona] = piazza
    end

    -- Il cliente può rifiutare
    if math.random(100) <= ILL.Spaccio.probabilitaRifiuto then
        return rispondi(false, 'Il cliente ti ha squadrato e se n\'è andato.')
    end

    -- Poteva essere un agente sotto copertura
    if math.random(100) <= ILL.Spaccio.probabilitaAgente then
        inventario:Rimuovi(ILL.Raffinazione.raffinata, 1)
        TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

        exports.ita_giustizia:ApriFascicolo(g.citizenid, ILL.Regole.reatoSpaccio,
            'operazione sotto copertura', 'Cessione a personale di polizia giudiziaria')

        TriggerEvent('aurea:112:allerta', 'sospetto',
            { x = coord.x, y = coord.y, z = coord.z },
            'Cessione di stupefacenti accertata. Soggetto da fermare.',
            'operazione sotto copertura')

        calore(g, 12, 'cessione ad agente sotto copertura')

        return rispondi(false, 'Era un agente sotto copertura. Scappa.')
    end

    inventario:Rimuovi(ILL.Raffinazione.raffinata, 1)

    -- Prezzo: territorio dell'organizzazione e saturazione della piazza
    local prezzo = ILL.Spaccio.prezzoBase

    if g.organizzazione.tag ~= 'nessuna' then
        local controlla = MySQL.scalar.await([[
            SELECT t.id FROM territori t
            JOIN organizzazioni o ON o.id = t.org_id
            WHERE o.tag = ? LIMIT 1
        ]], { g.organizzazione.tag })
        if controlla then prezzo = math.floor(prezzo * ILL.Spaccio.bonusTerritorio) end
    end

    if piazza.cessioni >= ILL.Spaccio.cessioniPrimaSaturazione then
        prezzo = math.floor(prezzo * ILL.Spaccio.penalitaSaturazione)
    end

    prezzo = math.floor(prezzo * (0.85 + math.random() * 0.3))
    local dosi = math.max(1, math.floor(prezzo / 10000))

    inventario:Aggiungi(ILL.Spaccio.provento, dosi)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    piazza.cessioni = piazza.cessioni + 1
    calore(g, ILL.Spaccio.calore, 'spaccio')

    -- Un passante può chiamare
    if math.random(100) <= ILL.Spaccio.probabilitaSegnalazione then
        TriggerEvent('aurea:112:allerta', 'sospetto',
            { x = coord.x, y = coord.y, z = coord.z },
            'Movimenti sospetti segnalati da un residente.', 'segnalazione anonima')
    end

    rispondi(true, ('Ceduto. %d banconote non tracciate.%s'):format(dosi,
        piazza.cessioni >= ILL.Spaccio.cessioniPrimaSaturazione and ' La piazza è satura: cambia zona.' or ''))
end)

-- ---------------------------------------------------------------------------
--  SMONTAGGIO
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:smonta', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - ILL.Smontaggio.coord) > ILL.Smontaggio.raggio then
        return rispondi(nil, 'Non sei all\'autodemolizione.')
    end

    local ora = os.date('%Y%m%d%H')
    smontatiOra[ora] = smontatiOra[ora] or 0
    if smontatiOra[ora] >= ILL.Smontaggio.limiteOrario then
        return rispondi(nil, 'Hanno già smontato troppi mezzi in quest\'ora: torna più tardi.')
    end

    inCorso[src] = { tipo = 'smonta', avviata = os.time(), targa = targa }
    rispondi({ durata = ILL.Smontaggio.durata })
end)

AUREA.Callback.Registra('ill:concludiSmontaggio', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione or sessione.tipo ~= 'smonta' then return rispondi(false) end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < ILL.Smontaggio.durata * 0.85 then
        return rispondi(false, 'Operazione non valida.')
    end

    local targa = tostring(sessione.targa or ''):upper():gsub('%s+', '')
    local veicolo = MySQL.single.await('SELECT citizenid, modello FROM veicoli WHERE targa = ?', { targa })

    local ora = os.date('%Y%m%d%H')
    smontatiOra[ora] = (smontatiOra[ora] or 0) + 1

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local recuperati = {}

    for _, p in ipairs(ILL.Smontaggio.pezzi) do
        local quantita = math.random(p.min, p.max)
        if inventario:Aggiungi(p.item, quantita) then
            recuperati[#recuperati + 1] = ('%d× %s'):format(quantita, AUREA.Item[p.item].etichetta)
        end
    end

    -- Il valore in contanti non tracciati
    local banconote = math.floor(ILL.Smontaggio.valoreBase / 10000)
    if veicolo then banconote = math.floor(banconote * 1.4) end
    inventario:Aggiungi(ILL.Spaccio.provento, banconote)

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
    calore(g, ILL.Smontaggio.calore, 'smontaggio veicolo')

    -- Se il veicolo era intestato a qualcuno, quello se ne accorge
    if veicolo then
        MySQL.update('UPDATE veicoli SET stato = \'demolito\' WHERE targa = ?', { targa })

        if veicolo.citizenid ~= g.citizenid then
            exports.ita_giustizia:ApriFascicolo(g.citizenid, ILL.Regole.reatoRicettazione,
                'accertamento', ('Ricettazione del veicolo targato %s'):format(targa))

            local proprietario = AUREA.GetPlayerByCitizenId(veicolo.citizenid)
            if proprietario then
                TriggerClientEvent('aurea:ui:notifica', proprietario.source, {
                    tipo = 'errore', icona = '🚨', durata = 15000,
                    titolo = 'Veicolo demolito',
                    testo = ('Il tuo veicolo targato %s risulta demolito. Puoi sporgere denuncia.'):format(targa),
                })
            end
            TriggerEvent('aurea:telefono:messaggioSistema', veicolo.citizenid, 'PRA',
                ('Il veicolo targato %s risulta cancellato dal registro per demolizione.'):format(targa))
        end
    end

    AUREA.Log('giustizia', 'avviso', g, ('smontaggio del veicolo %s'):format(targa))

    rispondi(true, ('%s e %d banconote non tracciate.'):format(
        #recuperati > 0 and table.concat(recuperati, ', ') or 'Nessun pezzo recuperabile', banconote))
end)

-- ---------------------------------------------------------------------------
--  MERCATO NERO
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('ill:mercatoCatalogo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if not posizioneMercato or #(coord - posizioneMercato) > 6.0 then
        return rispondi(nil, 'Non sei al mercato.')
    end

    local oggetti = {}
    for _, v in ipairs(ILL.MercatoNero.catalogo) do
        local dati = AUREA.Item[v.item]
        if dati then
            oggetti[#oggetti + 1] = {
                item = v.item, etichetta = dati.etichetta,
                prezzo = v.prezzo, banconote = math.ceil(v.prezzo / 10000),
            }
        end
    end

    local armi = {}
    for _, v in ipairs(ILL.MercatoNero.armi) do
        armi[#armi + 1] = {
            arma = v.arma, prezzo = v.prezzo, banconote = math.ceil(v.prezzo / 10000),
        }
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    rispondi({
        oggetti = oggetti, armi = armi,
        banconote = inventario:Quantita(ILL.Spaccio.provento),
    })
end)

AUREA.Callback.Registra('ill:mercatoAcquista', function(src, rispondi, tipo, chiave, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if not posizioneMercato or #(coord - posizioneMercato) > 6.0 then
        return rispondi(false, 'Non sei al mercato.')
    end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 1, 1, 50))

    local prezzo, item, arma
    if tipo == 'oggetto' then
        for _, v in ipairs(ILL.MercatoNero.catalogo) do
            if v.item == chiave then prezzo = v.prezzo item = v.item break end
        end
    else
        quantita = 1
        for _, v in ipairs(ILL.MercatoNero.armi) do
            if v.arma == chiave then prezzo = v.prezzo arma = v.arma break end
        end
    end

    if not prezzo then return rispondi(false, 'Merce non disponibile.') end

    local banconote = math.ceil((prezzo * quantita) / 10000)
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if not inventario:Ha(ILL.Spaccio.provento, banconote) then
        return rispondi(false, ('Servono %d banconote non tracciate. Qui non si accettano bonifici.'):format(banconote))
    end

    inventario:Rimuovi(ILL.Spaccio.provento, banconote)

    if item then
        if not inventario:Aggiungi(item, quantita) then
            inventario:Aggiungi(ILL.Spaccio.provento, banconote)
            return rispondi(false, 'Non hai spazio.')
        end
    else
        -- Arma clandestina: nessuna matricola, nessun registro
        exports.aurea_armi:RegistraArma(g.citizenid, arma, true)
    end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
    calore(g, 4, 'acquisto al mercato nero')

    AUREA.Log('giustizia', 'debug', g, ('acquisto al mercato nero: %s'):format(chiave))
    rispondi(true, ('Affare fatto. %d banconote consegnate.'):format(banconote))
end)

-- ---------------------------------------------------------------------------
--  Controllo di polizia sulla detenzione
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:giustizia:perquisito', function(agenteSrc, soggettoCitizenid)
    local inventario = exports.aurea_inventory:Inventario(soggettoCitizenid)
    local dosi = inventario:Quantita(ILL.Raffinazione.raffinata) + inventario:Quantita(ILL.Coltivazione.grezzo)

    if dosi > ILL.Regole.sogliaUsoPersonale then
        local agente = AUREA.GetPlayer(agenteSrc)
        exports.ita_giustizia:ApriFascicolo(soggettoCitizenid, ILL.Regole.reatoSpaccioGrave,
            agente and agente:NomeCompleto() or 'accertamento',
            ('Detenzione di %d dosi: quantitativo non compatibile con l\'uso personale'):format(dosi))
    end
end)

AddEventHandler('playerDropped', function() inCorso[source] = nil end)

--- Le piante esistenti vengono comunicate a chi entra in gioco.
AUREA.Callback.Registra('ill:piante', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for id, p in pairs(piante) do
        local trascorsi = (os.time() - p.piantata) / 60
        out[#out + 1] = {
            id = id, coord = p.coord,
            matura = trascorsi >= ILL.Coltivazione.minutiCrescita,
            mia = p.citizenid == g.citizenid,
            percentuale = math.min(100, math.floor((trascorsi / ILL.Coltivazione.minutiCrescita) * 100)),
        }
    end
    rispondi(out)
end)
