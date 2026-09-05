--[[
    AUREA · Punta Corvo (server)

    Il colpo vive tutto qui: la ricognizione è uno stato del server, il
    sospetto lo conta il server, e ogni fase si può chiudere solo se la
    precedente è chiusa davvero e se è passato il tempo che doveva passare.
]]

local U = AUREA.Util

local ricognizione = {}     -- [id bersaglio] = { da, quando }
local colpo = nil           -- il colpo in corso, uno solo per volta
local ultimoColpo = 0       -- os.time dell'ultimo colpo concluso
local ultimoPerGiocatore = {}   -- [citizenid] = os.time
local inCorso = {}          -- [src] = { tipo, avviata, durata }

-- ---------------------------------------------------------------------------
--  Aiuti
-- ---------------------------------------------------------------------------
local function calore(g, punti, motivo)
    if g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, punti, motivo)
    end
end

--- Le foto ancora valide.
local function fotoValide()
    local adesso = os.time()
    local out = {}
    for id, f in pairs(ricognizione) do
        if (adesso - f.quando) / 60 <= CAY.Ricognizione.validitaMinuti then
            out[id] = f
        else
            ricognizione[id] = nil
        end
    end
    return out
end

local function haFoto(id)
    return fotoValide()[id] ~= nil
end

--- Chi è ancora sull'isola, fra i partecipanti.
local function presenti()
    if not colpo then return {} end
    local out = {}
    for _, citizenid in ipairs(colpo.squadra) do
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        if g and CAY.SullIsola(GetEntityCoords(GetPlayerPed(g.source))) then
            out[#out + 1] = g
        end
    end
    return out
end

local function avvisaSquadra(dati)
    if not colpo then return end
    for _, citizenid in ipairs(colpo.squadra) do
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        if g then TriggerClientEvent('aurea:ui:notifica', g.source, dati) end
    end
end

local function alzaSospetto(punti, motivo)
    if not colpo then return end
    colpo.sospetto = math.min(CAY.Sospetto.massimo, colpo.sospetto + punti)

    for _, citizenid in ipairs(colpo.squadra) do
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        if g then TriggerClientEvent('cay:sospetto', g.source, colpo.sospetto, motivo) end
    end

    if colpo.sospetto >= CAY.Sospetto.sogliaAllarme and not colpo.allarme then
        colpo.allarme = true
        avvisaSquadra({
            tipo = 'errore', icona = '🚨', durata = 16000,
            titolo = 'La villa si è svegliata',
            testo = 'Gli uomini si stanno muovendo. Da qui in poi ogni minuto conta.',
        })
    end

    if colpo.sospetto >= CAY.Sospetto.massimo then
        annullaColpo('Vi hanno scoperti. Il colpo è saltato.')
    end
end

function annullaColpo(motivo)
    if not colpo then return end
    avvisaSquadra({
        tipo = 'errore', icona = '🚫', durata = 18000,
        titolo = 'Colpo fallito', testo = motivo,
    })
    for _, citizenid in ipairs(colpo.squadra) do
        local g = AUREA.GetPlayerByCitizenId(citizenid)
        if g then TriggerClientEvent('cay:fine', g.source) end
    end
    ultimoColpo = os.time()
    colpo = nil
end

-- ---------------------------------------------------------------------------
--  1. RICOGNIZIONE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cay:ricognizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local valide = fotoValide()
    local out, mancantiObbligatori = {}, 0

    for _, b in ipairs(CAY.Ricognizione.bersagli) do
        local f = valide[b.id]
        if b.obbligatorio and not f then mancantiObbligatori = mancantiObbligatori + 1 end

        out[#out + 1] = {
            id = b.id, nome = b.nome, sblocca = b.sblocca,
            obbligatorio = b.obbligatorio == true,
            fatta = f ~= nil,
            da = f and f.da or nil,
            minutiResidui = f and math.max(0, CAY.Ricognizione.validitaMinuti
                - math.floor((os.time() - f.quando) / 60)) or nil,
        }
    end

    rispondi({
        bersagli = out,
        pronta = mancantiObbligatori == 0,
        mancanti = mancantiObbligatori,
        validitaMinuti = CAY.Ricognizione.validitaMinuti,
    })
end)

AUREA.Callback.Registra('cay:fotografa', function(src, rispondi, idBersaglio)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local b = CAY.GetBersaglio(idBersaglio)
    if not b then return rispondi(false, 'Non c\'è niente da fotografare qui.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(CAY.Ricognizione.attrezzo, 1) then
        return rispondi(false, 'Serve una fotocamera.')
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - b.coord) > CAY.Ricognizione.distanzaScatto then
        return rispondi(false, 'Sei troppo lontano per un\'inquadratura utile.')
    end

    ricognizione[b.id] = { da = g:NomeCompleto(), quando = os.time() }

    AUREA.Log('giustizia', 'debug', g, ('ricognizione a Punta Corvo: %s'):format(b.nome))
    rispondi(true, ('%s — %s'):format(b.nome, b.sblocca))
end)

-- ---------------------------------------------------------------------------
--  2 e 3. PIANIFICAZIONE E PARTENZA
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cay:pianificazione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local valide = fotoValide()
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    local approcci = {}
    for id, a in pairs(CAY.Approcci) do
        local motivi = {}
        if a.richiedeFoto and not valide[a.richiedeFoto] then
            local b = CAY.GetBersaglio(a.richiedeFoto)
            motivi[#motivi + 1] = ('manca la ricognizione: %s'):format(b and b.nome or a.richiedeFoto)
        end
        if a.richiedeItem and not inventario:Ha(a.richiedeItem, 1) then
            motivi[#motivi + 1] = ('serve %s'):format(AUREA.Item[a.richiedeItem].etichetta)
        end

        approcci[#approcci + 1] = {
            id = id, nome = a.nome, descrizione = a.descrizione,
            sospettoIniziale = a.sospettoIniziale,
            disponibile = #motivi == 0,
            motivo = #motivi > 0 and table.concat(motivi, ' · ') or nil,
        }
    end
    table.sort(approcci, function(a, b) return a.sospettoIniziale < b.sospettoIniziale end)

    local attrezzatura = {}
    for _, e in ipairs(CAY.Attrezzatura.obbligatori) do
        attrezzatura[#attrezzatura + 1] = {
            item = e.item, etichetta = AUREA.Item[e.item].etichetta, nota = e.nota,
            obbligatorio = true, presente = inventario:Ha(e.item, e.quantita),
        }
    end
    for _, e in ipairs(CAY.Attrezzatura.opzionali) do
        attrezzatura[#attrezzatura + 1] = {
            item = e.item, etichetta = AUREA.Item[e.item].etichetta, nota = e.nota,
            obbligatorio = false, presente = inventario:Ha(e.item, e.quantita),
        }
    end

    local minutiAttesa = math.max(0, CAY.Cooldown.minutiFraColpi
        - math.floor((os.time() - ultimoColpo) / 60))

    rispondi({
        approcci = approcci,
        attrezzatura = attrezzatura,
        inCorso = colpo ~= nil,
        minutiAttesa = minutiAttesa,
        squadraMinima = CAY.Squadra.minimo,
        squadraMassima = CAY.Squadra.massimo,
    })
end)

AUREA.Callback.Registra('cay:avvia', function(src, rispondi, idApproccio)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if colpo then return rispondi(false, 'C\'è già un colpo in corso a Punta Corvo.') end

    local attesa = CAY.Cooldown.minutiFraColpi - math.floor((os.time() - ultimoColpo) / 60)
    if ultimoColpo > 0 and attesa > 0 then
        return rispondi(false, ('Alla villa hanno cambiato le serrature. Riprova fra %d minuti.'):format(attesa))
    end

    local approccio = CAY.Approcci[idApproccio]
    if not approccio then return rispondi(false, 'Approccio non previsto.') end

    local valide = fotoValide()

    -- La ricognizione obbligatoria
    for _, b in ipairs(CAY.Ricognizione.bersagli) do
        if b.obbligatorio and not valide[b.id] then
            return rispondi(false, ('Manca la ricognizione: %s.'):format(b.nome))
        end
    end
    if approccio.richiedeFoto and not valide[approccio.richiedeFoto] then
        return rispondi(false, 'Non hai la ricognizione per questa via d\'accesso.')
    end

    -- La squadra: chi è intorno a chi organizza
    local coordCapo = GetEntityCoords(GetPlayerPed(src))
    local squadra, nomi = {}, {}

    for altroSrc, altro in pairs(AUREA.Giocatori) do
        local d = #(coordCapo - GetEntityCoords(GetPlayerPed(altroSrc)))
        if d <= CAY.Squadra.distanzaRitrovo then
            local ultimo = ultimoPerGiocatore[altro.citizenid] or 0
            if (os.time() - ultimo) / 60 >= CAY.Cooldown.minutiPerGiocatore then
                squadra[#squadra + 1] = altro.citizenid
                nomi[#nomi + 1] = altro:NomeCompleto()
            end
        end
    end

    if #squadra < CAY.Squadra.minimo then
        return rispondi(false, ('Servono almeno %d persone insieme a te, e nessuna che abbia già fatto il colpo di recente. Ne ho contate %d.')
            :format(CAY.Squadra.minimo, #squadra))
    end
    if #squadra > CAY.Squadra.massimo then
        return rispondi(false, ('Siete in troppi: al massimo %d.'):format(CAY.Squadra.massimo))
    end

    -- L'attrezzatura obbligatoria la deve avere chi organizza
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    for _, e in ipairs(CAY.Attrezzatura.obbligatori) do
        if not inventario:Ha(e.item, e.quantita) then
            return rispondi(false, ('Manca l\'attrezzatura: %s.'):format(AUREA.Item[e.item].etichetta))
        end
    end
    if approccio.richiedeItem and not inventario:Ha(approccio.richiedeItem, 1) then
        return rispondi(false, ('Per questa via serve %s.'):format(AUREA.Item[approccio.richiedeItem].etichetta))
    end

    colpo = {
        capo = g.citizenid,
        squadra = squadra,
        approccio = idApproccio,
        sospetto = approccio.sospettoIniziale,
        fasi = {},              -- [id] = true
        bottino = {},           -- [id] = true
        primarioPreso = false,
        allarme = false,
        avviato = os.time(),
        uscitaDalCaveau = nil,
    }

    for _, citizenid in ipairs(squadra) do
        ultimoPerGiocatore[citizenid] = os.time()
        local membro = AUREA.GetPlayerByCitizenId(citizenid)
        if membro then
            TriggerClientEvent('cay:inizio', membro.source, {
                approccio = approccio.nome,
                punto = { x = approccio.punto.x, y = approccio.punto.y, z = approccio.punto.z },
                sospetto = colpo.sospetto,
                squadra = nomi,
            })
        end
    end

    calore(g, 12, 'colpo a Punta Corvo')
    AUREA.Log('giustizia', 'allarme', g,
        ('ha avviato il colpo a Punta Corvo con %d persone (%s)'):format(#squadra, approccio.nome))

    rispondi(true, ('Si parte: %s. Siete in %d.'):format(approccio.nome, #squadra))
end)

--- Il sospetto sale da solo finché si resta sull'isola.
CreateThread(function()
    while true do
        Wait(60000)
        if colpo then
            if #presenti() == 0 and (os.time() - colpo.avviato) > 600 then
                annullaColpo('Nessuno è più sull\'isola. Il colpo è stato abbandonato.')
            else
                alzaSospetto(CAY.Sospetto.crescitaAlMinuto, 'il tempo passa')
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  4. INFILTRAZIONE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cay:stato', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not colpo then return rispondi(nil) end

    if not U.Contiene(colpo.squadra, g.citizenid) then return rispondi(nil) end

    local fasi = {}
    for n, f in ipairs(CAY.Fasi) do
        local precedente = n == 1 or colpo.fasi[CAY.Fasi[n - 1].id]
        fasi[#fasi + 1] = {
            id = f.id, nome = f.nome, nota = f.nota,
            fatta = colpo.fasi[f.id] == true,
            aperta = precedente == true,
            coord = { x = f.coord.x, y = f.coord.y, z = f.coord.z },
        }
    end

    local bottini = {}
    if colpo.fasi.caveau then
        local valide = fotoValide()
        for _, s in ipairs(CAY.Bottino.secondari) do
            if not s.richiedeFoto or valide[s.richiedeFoto] then
                bottini[#bottini + 1] = {
                    id = s.id, nome = s.nome,
                    preso = colpo.bottino[s.id] == true,
                    sospetto = s.sospetto,
                    coord = s.coord and { x = s.coord.x, y = s.coord.y, z = s.coord.z } or nil,
                }
            end
        end
    end

    rispondi({
        sospetto = colpo.sospetto,
        soglia = CAY.Sospetto.sogliaAllarme,
        allarme = colpo.allarme,
        approccio = CAY.Approcci[colpo.approccio].nome,
        fasi = fasi,
        primarioPreso = colpo.primarioPreso,
        primario = CAY.Bottino.primario.nome,
        bottini = bottini,
        rientro = colpo.primarioPreso and {
            x = CAY.Rientro.punto.x, y = CAY.Rientro.punto.y, z = CAY.Rientro.punto.z,
            nome = CAY.Rientro.nome,
        } or nil,
    })
end)

AUREA.Callback.Registra('cay:avviaFase', function(src, rispondi, idFase)
    local g = AUREA.GetPlayer(src)
    if not g or not colpo then return rispondi(false, 'Nessun colpo in corso.') end
    if not U.Contiene(colpo.squadra, g.citizenid) then return rispondi(false, 'Non sei della partita.') end
    if inCorso[src] then return rispondi(false, 'Stai già facendo qualcosa.') end

    local f, indice = CAY.GetFase(idFase)
    if not f then return rispondi(false, 'Fase sconosciuta.') end
    if colpo.fasi[idFase] then return rispondi(false, 'Questa fase è già chiusa.') end

    if indice > 1 and not colpo.fasi[CAY.Fasi[indice - 1].id] then
        return rispondi(false, ('Prima va chiusa la fase: %s.'):format(CAY.Fasi[indice - 1].nome))
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - f.coord) > 8.0 then return rispondi(false, 'Non sei nel punto giusto.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if f.richiedeItem and not inventario:Ha(f.richiedeItem, 1) then
        return rispondi(false, ('Serve %s.'):format(AUREA.Item[f.richiedeItem].etichetta))
    end

    -- L'attrezzo che accelera: consuma, ma taglia i tempi
    local conAttrezzo = f.attrezzoVeloce and inventario:Ha(f.attrezzoVeloce, 1)
    local durata = conAttrezzo and f.durataConAttrezzo or f.durata

    inCorso[src] = { tipo = 'fase', id = idFase, avviata = os.time(), durata = durata, conAttrezzo = conAttrezzo }

    rispondi(true, {
        nome = f.nome, durata = durata, conAttrezzo = conAttrezzo == true,
        attrezzo = conAttrezzo and AUREA.Item[f.attrezzoVeloce].etichetta or nil,
    })
end)

AUREA.Callback.Registra('cay:concludiFase', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not colpo or not sessione or sessione.tipo ~= 'fase' then
        return rispondi(false, 'Nessuna operazione in corso.')
    end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < (sessione.durata - 3000) then
        return rispondi(false, 'Non hai finito: il lavoro è da rifare.')
    end

    local f = CAY.GetFase(sessione.id)
    if not f then return rispondi(false) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if f.richiedeItem then inventario:Rimuovi(f.richiedeItem, 1) end
    if sessione.conAttrezzo and f.attrezzoVeloce then inventario:Rimuovi(f.attrezzoVeloce, 1) end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    colpo.fasi[sessione.id] = true

    local punti = (sessione.conAttrezzo and f.sospettoConAttrezzo) or f.sospetto
    alzaSospetto(punti, f.nome)

    -- Dalla torre radio in poi, a terra qualcuno comincia a fare domande
    if sessione.id == 'torre' then
        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '📡', durata = 16000,
            titolo = 'Interferenze al largo',
            testo = 'Segnalata caduta delle comunicazioni radio da Punta Corvo. Possibile azione in corso.',
        }, true)
    end

    if not colpo then return rispondi(false, 'Il colpo è saltato.') end

    avvisaSquadra({
        tipo = 'successo', icona = '✅', durata = 10000,
        titolo = f.nome, testo = ('Fase chiusa da %s.'):format(g:NomeCompleto()),
    })

    rispondi(true, ('%s: fatto.'):format(f.nome))
end)

-- ---------------------------------------------------------------------------
--  5. BOTTINO
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cay:prendiPrimario', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or not colpo then return rispondi(false, 'Nessun colpo in corso.') end
    if not U.Contiene(colpo.squadra, g.citizenid) then return rispondi(false, 'Non sei della partita.') end
    if not colpo.fasi.caveau then return rispondi(false, 'Il caveau è ancora chiuso.') end
    if colpo.primarioPreso then return rispondi(false, 'L\'ha già preso qualcun altro.') end

    if inCorso[src] then return rispondi(false, 'Stai già facendo qualcosa.') end
    inCorso[src] = { tipo = 'primario', avviata = os.time(), durata = CAY.Bottino.primario.durata }

    rispondi(true, CAY.Bottino.primario.durata)
end)

AUREA.Callback.Registra('cay:concludiPrimario', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not colpo or not sessione or sessione.tipo ~= 'primario' then
        return rispondi(false, 'Nessuna operazione in corso.')
    end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < (sessione.durata - 2000) then
        return rispondi(false, 'Non hai finito.')
    end
    if colpo.primarioPreso then return rispondi(false, 'Troppo tardi: l\'ha preso un altro.') end

    local p = CAY.Bottino.primario
    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    if not inventario:Aggiungi(p.item, 1, {
        origine = CAY.Isola.nome,
        valore = p.valore,
        preso = os.date('%d/%m/%Y %H:%M'),
    }) then
        return rispondi(false, 'Non hai spazio: liberane e riprova.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    colpo.primarioPreso = true
    colpo.uscitaDalCaveau = os.time()

    avvisaSquadra({
        tipo = 'successo', icona = '📕', durata = 16000,
        titolo = 'Il libro mastro è nostro',
        testo = ('Ce l\'ha %s. Adesso bisogna portarlo a %s.'):format(g:NomeCompleto(), CAY.Rientro.nome),
    })

    -- Da adesso la Guardia di Finanza sa che qualcosa è successo
    programmaBlocco()

    AUREA.Log('giustizia', 'allarme', g, 'ha sottratto il libro mastro a Punta Corvo')
    rispondi(true, ('%s. Portalo a %s.'):format(p.nome, CAY.Rientro.nome))
end)

AUREA.Callback.Registra('cay:prendiSecondario', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    if not g or not colpo then return rispondi(false, 'Nessun colpo in corso.') end
    if not U.Contiene(colpo.squadra, g.citizenid) then return rispondi(false, 'Non sei della partita.') end
    if not colpo.fasi.caveau then return rispondi(false, 'Il caveau è ancora chiuso.') end

    local s = CAY.GetSecondario(id)
    if not s then return rispondi(false, 'Non c\'è nulla del genere.') end
    if colpo.bottino[id] then return rispondi(false, 'Già svuotato.') end

    if s.richiedeFoto and not haFoto(s.richiedeFoto) then
        return rispondi(false, 'Non sapete nemmeno dove sia: mancava la ricognizione.')
    end

    if s.coord then
        local coord = GetEntityCoords(GetPlayerPed(src))
        if #(coord - s.coord) > 10.0 then return rispondi(false, 'Non sei nel punto giusto.') end
    end

    if inCorso[src] then return rispondi(false, 'Stai già facendo qualcosa.') end
    inCorso[src] = { tipo = 'secondario', id = id, avviata = os.time(), durata = s.durata }

    rispondi(true, s.durata)
end)

AUREA.Callback.Registra('cay:concludiSecondario', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not colpo or not sessione or sessione.tipo ~= 'secondario' then
        return rispondi(false, 'Nessuna operazione in corso.')
    end
    inCorso[src] = nil

    local s = CAY.GetSecondario(sessione.id)
    if not s then return rispondi(false) end

    if (os.time() - sessione.avviata) * 1000 < (sessione.durata - 2000) then
        return rispondi(false, 'Non hai finito.')
    end
    if colpo.bottino[sessione.id] then return rispondi(false, 'L\'ha già svuotato un altro.') end

    local quantita = math.random(s.minimo, s.massimo)
    local metadata = nil

    if s.purezza then
        -- Roba non ancora tagliata: vale tantissimo ed è pericolosa da vendere così
        metadata = { purezza = math.random(s.purezza.minimo, s.purezza.massimo) }
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Aggiungi(s.item, quantita, metadata) then
        return rispondi(false, 'Non hai spazio: serviva un borsone più grande.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    colpo.bottino[sessione.id] = true
    alzaSospetto(s.sospetto, s.nome)

    local dettaglio = ('%d× %s'):format(quantita, AUREA.Item[s.item].etichetta)
    if metadata then dettaglio = dettaglio .. (' al %d%%'):format(metadata.purezza) end

    avvisaSquadra({
        tipo = 'info', icona = '💰', durata = 9000,
        titolo = s.nome, testo = ('%s l\'ha svuotato: %s.'):format(g:NomeCompleto(), dettaglio),
    })

    rispondi(true, dettaglio)
end)

-- ---------------------------------------------------------------------------
--  6. RIENTRO
--
--  Il colpo si chiude a terra, non sull'isola. Se ci sono finanzieri in
--  servizio, li si trova sulla strada del ritorno.
-- ---------------------------------------------------------------------------
function programmaBlocco()
    local istante = os.time()
    CreateThread(function()
        Wait(CAY.Rientro.minutiPrimaDelBlocco * 60000)
        if not colpo or colpo.uscitaDalCaveau ~= istante then
            -- Il colpo è finito o è un'altra sessione: niente da fare
            if not colpo then return end
        end

        TriggerEvent('aurea:112:allerta', 'riciclaggio',
            { x = CAY.Rientro.punto.x, y = CAY.Rientro.punto.y, z = CAY.Rientro.punto.z },
            'Segnalato natante in rientro da Punta Corvo con carico non dichiarato.',
            CAY.Rientro.nome)

        exports.aurea_ui:NotificaLavoro('guardia_finanza', {
            tipo = 'avviso', icona = '⚓', durata = 20000,
            titolo = 'Rientro sospetto da Punta Corvo',
            testo = ('Il carico dovrebbe sbarcare a %s. Predisponete il controllo.'):format(CAY.Rientro.nome),
        }, true)
    end)
end

AUREA.Callback.Registra('cay:consegna', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - CAY.Rientro.punto) > CAY.Rientro.raggio then
        return rispondi(false, ('Il ricettatore aspetta a %s.'):format(CAY.Rientro.nome))
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    local incassato, righe = 0, {}

    -- Il libro mastro
    local mastro = inventario:Trova(CAY.Bottino.primario.item)
    if mastro then
        local valore = (mastro.metadata and tonumber(mastro.metadata.valore))
            or CAY.Bottino.primario.valore
        inventario:Rimuovi(CAY.Bottino.primario.item, 1, mastro.slot)
        incassato = incassato + valore
        righe[#righe + 1] = CAY.Bottino.primario.nome
    end

    -- Lingotti e dipinti: il ricettatore li prende, la cocaina no
    local ricettabili = {
        lingotto = 480000,
        quadro = 1250000,
    }
    for item, valore in pairs(ricettabili) do
        local quantita = inventario:Quantita(item)
        if quantita > 0 then
            inventario:Rimuovi(item, quantita)
            incassato = incassato + valore * quantita
            righe[#righe + 1] = ('%d× %s'):format(quantita, AUREA.Item[item].etichetta)
        end
    end

    if incassato == 0 then
        return rispondi(false, 'Non hai niente che gli interessi. La cocaina se la vende da sé.')
    end

    local note = math.max(1, math.floor(incassato / CAY.Bottino.tagliobanconota))
    if not inventario:Aggiungi('contanti_sporchi', note) then
        return rispondi(false, 'Non hai spazio per il pagamento: liberane un po\'.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    exports.ita_giustizia:ApriFascicolo(g.citizenid, CAY.Rientro.reatoRicettazione,
        'indagine d\'ufficio',
        ('Ricettazione di beni provento del colpo a %s.'):format(CAY.Isola.nome))

    calore(g, 18, 'ricettazione del bottino di Punta Corvo')

    -- Il colpo si chiude quando il libro mastro esce dal giro
    if mastro and colpo then
        avvisaSquadra({
            tipo = 'successo', icona = '🏝', durata = 20000,
            titolo = 'Colpo concluso',
            testo = ('%s ha piazzato il libro mastro. A Punta Corvo, per un po\', non si torna.')
                :format(g:NomeCompleto()),
        })
        for _, citizenid in ipairs(colpo.squadra) do
            local membro = AUREA.GetPlayerByCitizenId(citizenid)
            if membro then TriggerClientEvent('cay:fine', membro.source) end
        end
        ultimoColpo = os.time()
        colpo = nil
    end

    AUREA.Log('giustizia', 'allarme', g,
        ('ha piazzato il bottino di Punta Corvo per %s'):format(U.Euro(incassato)))

    rispondi(true, ('%s → %d banconote non tracciate.'):format(table.concat(righe, ', '), note))
end)

-- ---------------------------------------------------------------------------
--  Il libro mastro come prova: chi lo consegna alle forze dell'ordine
--  colpisce la cosca molto più di chi lo rivende.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cay:consegnaAutorita', function(src, rispondi, agenteSrc)
    local g = AUREA.GetPlayer(src)
    local agente = AUREA.GetPlayer(tonumber(agenteSrc))
    if not g or not agente then return rispondi(false, 'Persona non trovata.') end

    if not agente.lavoro.servizio or not U.Contiene({ 'carabinieri', 'polizia', 'guardia_finanza' }, agente.lavoro.nome) then
        return rispondi(false, 'Non è un pubblico ufficiale in servizio.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local mastro = inventario:Trova(CAY.Bottino.primario.item)
    if not mastro then return rispondi(false, 'Non hai il libro mastro.') end

    inventario:Rimuovi(CAY.Bottino.primario.item, 1, mastro.slot)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    -- Fascicoli ex art. 416-bis su chi risulta nei registri: qui si traduce
    -- in calore azzerato per nessuno e un'indagine su tutte le cosche note.
    local organizzazioni = MySQL.query.await(
        'SELECT tag, nome FROM organizzazioni WHERE attiva = 1 AND calore > 0') or {}

    for _, org in ipairs(organizzazioni) do
        exports.ita_famiglie:CaloreOrganizzazione(org.tag, 25, 'libro mastro acquisito agli atti')
    end

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'avviso', icona = '📕', durata = 20000,
        titolo = 'Sequestrata la contabilità di una cosca',
        testo = 'Gli inquirenti hanno acquisito il libro mastro di Punta Corvo. Nomi, cifre, date.',
    })

    AUREA.Log('giustizia', 'allarme', g,
        ('ha consegnato il libro mastro a %s'):format(agente:NomeCompleto()))

    rispondi(true, 'Consegnato. Adesso quei nomi sono in mano alla Procura — e qualcuno lo verrà a sapere.')
end)

AddEventHandler('playerDropped', function() inCorso[source] = nil end)
