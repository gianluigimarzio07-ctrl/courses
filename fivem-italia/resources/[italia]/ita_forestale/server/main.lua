--[[
    AUREA · Carabinieri Forestali (server)

    Due registri: gli incendi da rilevare e i vincoli in vigore.

    L'incendio arriva da solo. Quando i Vigili del Fuoco chiudono un
    intervento, ita_vigilfuoco emette `aurea:forestale:incendioChiuso` e
    da lì comincia il lavoro nostro — che è un lavoro d'ufficio fatto in
    mezzo a un bosco bruciato: misurare quanto ha preso, stabilire da
    dove è partito, e decidere se sul terreno ci va il vincolo.

    Se ita_vigilfuoco non c'è, l'evento non arriva e questa risorsa fa
    solo gli accertamenti su strada. Nessuno dei due si rompe.
]]

local U = AUREA.Util

local daRilevare = {}   -- [idIncendio] = { centro, zona, durataMinuti, chiuso }
local vincoli    = {}   -- [id] = { centro, raggio, ettari, fino, incendio }
local rilievi    = {}   -- [citizenid] = { incendio, punti = { ... } }

local function pulisci(s, massimo)
    return (tostring(s or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, massimo or 200)
end

local function forestale(g, permesso)
    return g and g.lavoro.nome == FOR.Lavoro and g.lavoro.servizio
       and (permesso == nil or g:HaPermessoLavoro(permesso))
end

-- ---------------------------------------------------------------------------
--  I vincoli
-- ---------------------------------------------------------------------------

--- Il vincolo che copre un punto, se c'è.
local function vincoloSu(coord)
    for id, v in pairs(vincoli) do
        if FOR.DistanzaPiana(coord, v.centro) <= v.raggio then
            v.id = id
            return v
        end
    end
end

--- Lo chiede ita_edilizia prima di aprire un cantiere, e chiunque altro
--- voglia sapere se su un terreno si può fare qualcosa.
---
--- Restituisce (vincolato, motivo, minutiResidui). Chi la chiama deve
--- farlo dentro un pcall: questa risorsa può non essere installata.
exports('TerrenoVincolato', function(coord)
    if type(coord) ~= 'vector3' and type(coord) ~= 'table' then return false end
    local v = vincoloSu({ x = coord.x or 0.0, y = coord.y or 0.0 })
    if not v then return false end
    return true,
        ('Soprassuolo percorso dal fuoco il %s: vincolo %s, %d ettari accertati.')
            :format(v.data or 'recentemente', FOR.Vincolo.articolo, v.ettari),
        math.max(0, math.floor((v.fino - os.time()) / 60))
end)

local function pacchettoVincoli()
    local out = {}
    for id, v in pairs(vincoli) do
        out[#out + 1] = {
            id = id, centro = v.centro, raggio = v.raggio, ettari = v.ettari,
            minutiResidui = math.max(0, math.floor((v.fino - os.time()) / 60)),
        }
    end
    return out
end

local function diffondiVincoli()
    TriggerClientEvent('for:vincoli', -1, pacchettoVincoli())
end

-- ---------------------------------------------------------------------------
--  L'incendio che si spegne diventa un fascicolo da aprire
-- ---------------------------------------------------------------------------
AddEventHandler('aurea:forestale:incendioChiuso', function(dati)
    if type(dati) ~= 'table' or not dati.centro then return end
    -- Gli incendi che non sono boschivi non ci riguardano: un'auto che
    -- brucia in un parcheggio non lascia soprassuolo percorso dal fuoco.
    -- La chiave è quella di VVF.Tipologie in ita_vigilfuoco.
    if dati.tipologia ~= 'boschivo' then return end

    daRilevare[dati.id] = {
        centro = vector3(dati.centro.x, dati.centro.y, dati.centro.z or 0.0),
        zona = dati.zona or 'località non indicata',
        durataMinuti = math.max(1, tonumber(dati.durataMinuti) or 1),
        chiuso = os.time(),
        spento = dati.spento == true,
    }

    exports.aurea_ui:NotificaEnte(FOR.Ente, {
        tipo = 'avviso', icona = '🌲', durata = 22000,
        titolo = 'Incendio da rilevare',
        testo = ('%s — il fuoco è finito dopo %d minuti.\nServe il rilievo della superficie percorsa: %d punti sul perimetro.')
            :format(daRilevare[dati.id].zona, daRilevare[dati.id].durataMinuti,
                    FOR.Rilievo.puntiRichiesti),
    }, true)

    AUREA.Log('staff', 'info', nil,
        ('incendio %d da rilevare in %s'):format(dati.id, daRilevare[dati.id].zona))
end)

--- Gli incendi non rilevati in tempo si perdono: il bosco ricresce e il
--- perimetro non si legge più.
CreateThread(function()
    while true do
        Wait(60000)
        local adesso = os.time()

        for id, inc in pairs(daRilevare) do
            if adesso - inc.chiuso >= FOR.Rilievo.minutiPerRilevare * 60 then
                daRilevare[id] = nil
                for cid, r in pairs(rilievi) do
                    if r.incendio == id then rilievi[cid] = nil end
                end
            end
        end

        local scaduti = false
        for id, v in pairs(vincoli) do
            if adesso >= v.fino then
                MySQL.update.await(
                    'UPDATE forestale_incendi SET vincolo = 0 WHERE id = ?', { v.incendio })
                vincoli[id] = nil
                scaduti = true
            end
        end
        if scaduti then diffondiVincoli() end
    end
end)

AUREA.Callback.Registra('for:daRilevare', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not forestale(g) then return rispondi(nil) end

    local out = {}
    for id, inc in pairs(daRilevare) do
        local mio = rilievi[g.citizenid]
        out[#out + 1] = {
            id = id, zona = inc.zona, centro = inc.centro,
            durataMinuti = inc.durataMinuti,
            minutiResidui = math.max(0, FOR.Rilievo.minutiPerRilevare
                - math.floor((os.time() - inc.chiuso) / 60)),
            puntiMiei = (mio and mio.incendio == id) and #mio.punti or 0,
        }
    end
    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Il rilievo del perimetro
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('for:rilevaPunto', function(src, rispondi, idIncendio)
    local g = AUREA.GetPlayer(src)
    if not forestale(g) then return rispondi(false, 'Serve essere in servizio.') end

    idIncendio = tonumber(idIncendio)
    local inc = idIncendio and daRilevare[idIncendio]
    if not inc then return rispondi(false, 'Questo incendio non è più rilevabile.') end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if FOR.DistanzaPiana(coord, inc.centro) > FOR.Rilievo.raggioMassimo then
        return rispondi(false, 'Sei troppo lontano dall\'area percorsa dal fuoco.')
    end

    local r = rilievi[g.citizenid]
    if not r or r.incendio ~= idIncendio then
        r = { incendio = idIncendio, punti = {} }
        rilievi[g.citizenid] = r
    end

    -- Il perimetro si cammina: due punti presi dallo stesso posto non
    -- misurano niente.
    for _, p in ipairs(r.punti) do
        if FOR.DistanzaPiana(coord, p) < FOR.Rilievo.metriFraPunti then
            return rispondi(false, ('Questo punto è troppo vicino a uno già rilevato: spostati di almeno %d metri.')
                :format(FOR.Rilievo.metriFraPunti))
        end
    end

    r.punti[#r.punti + 1] = { x = coord.x, y = coord.y }

    if #r.punti < FOR.Rilievo.puntiRichiesti then
        return rispondi(true, ('Punto %d di %d rilevato.')
            :format(#r.punti, FOR.Rilievo.puntiRichiesti))
    end

    rispondi(true, ('Perimetro chiuso: %d punti. Torna in caserma per l\'accertamento sull\'origine.')
        :format(#r.punti))
end)

-- ---------------------------------------------------------------------------
--  L'accertamento: origine, ettari, e il vincolo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('for:accerta', function(src, rispondi, idIncendio, origine, responsabileSrc, note)
    local g = AUREA.GetPlayer(src)
    if not forestale(g) then return rispondi(false, 'Serve essere in servizio.') end

    idIncendio = tonumber(idIncendio)
    local inc = idIncendio and daRilevare[idIncendio]
    if not inc then return rispondi(false, 'Incendio non più in carico.') end

    local r = rilievi[g.citizenid]
    if not r or r.incendio ~= idIncendio or #r.punti < FOR.Rilievo.puntiRichiesti then
        return rispondi(false, ('Prima va rilevato il perimetro: servono %d punti.')
            :format(FOR.Rilievo.puntiRichiesti))
    end

    local o = FOR.GetOrigine(origine)
    if not o then return rispondi(false, 'Origine non prevista.') end

    -- Un'origine dolosa o colposa vuole un nome: senza, resta ignota.
    local responsabile = responsabileSrc and AUREA.GetPlayer(tonumber(responsabileSrc)) or nil
    if o.reato and not responsabile then
        return rispondi(false, 'Per attribuire un\'origine dolosa o colposa serve identificare qualcuno.')
    end

    local ettari = FOR.Ettari(#r.punti, inc.durataMinuti)
    note = pulisci(note, 200)

    local idRiga = MySQL.insert.await([[
        INSERT INTO forestale_incendi
            (centro_x, centro_y, ettari, origine, responsabile, accertato_da, note)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { inc.centro.x, inc.centro.y, ettari, origine,
          responsabile and responsabile.citizenid or nil, g.citizenid,
          #note > 0 and note or nil })

    -- La sanzione amministrativa della colpa
    if o.sanzione and o.sanzione > 0 and responsabile then
        exports.ita_codicestrada:EmettiVerbale({
            citizenid = responsabile.citizenid,
            articolo = o.articolo or FOR.Vincolo.articolo,
            descrizione = ('%s — %.2f ettari percorsi in %s'):format(o.etichetta, ettari, inc.zona),
            importo = o.sanzione, punti = 0,
            origine = 'agente', agente = g:NomeCompleto(), luogo = inc.zona,
        })
    end

    -- Il fascicolo penale, se l'origine è un reato
    if o.reato and responsabile then
        pcall(function()
            exports.ita_giustizia:ApriFascicolo(responsabile.citizenid, o.reato, g:NomeCompleto(),
                ('%.2f ettari percorsi dal fuoco in %s'):format(ettari, inc.zona))
        end)
    end

    g:Aggiungi('banca', FOR.Rilievo.compenso, 'rilievo di superficie percorsa dal fuoco')

    daRilevare[idIncendio] = nil
    rilievi[g.citizenid] = nil

    rispondi(true, {
        ettari = ettari,
        origine = o.etichetta,
        idRiga = idRiga,
        zona = inc.zona,
        responsabile = responsabile and responsabile:NomeCompleto() or nil,
        compenso = FOR.Rilievo.compenso,
        -- Il vincolo è un atto a parte, e lo firma un maresciallo
        vincolabile = true,
        raggio = FOR.RaggioVincolo(ettari),
    })
end)

--- Il vincolo decennale. È l'unica cosa qui dentro che chiede un grado.
AUREA.Callback.Registra('for:vincola', function(src, rispondi, idRiga)
    local g = AUREA.GetPlayer(src)
    if not forestale(g, 'vincolo') then
        return rispondi(false, 'Il vincolo decennale lo appone un maresciallo o superiore.')
    end

    idRiga = tonumber(idRiga)
    if not idRiga then return rispondi(false, 'Accertamento non indicato.') end

    local riga = MySQL.single.await([[
        SELECT id, centro_x, centro_y, ettari, vincolo FROM forestale_incendi WHERE id = ?
    ]], { idRiga })
    if not riga then return rispondi(false, 'Accertamento non trovato.') end
    if riga.vincolo == 1 then return rispondi(false, 'Su questo accertamento il vincolo c\'è già.') end

    local ettari = tonumber(riga.ettari) or 0
    local raggio = FOR.RaggioVincolo(ettari)
    local fino = os.time() + FOR.Vincolo.minutiDurata * 60

    MySQL.update.await([[
        UPDATE forestale_incendi SET vincolo = 1, vincolo_fino = DATE_ADD(CURDATE(), INTERVAL ? YEAR)
        WHERE id = ?
    ]], { FOR.Vincolo.anniNominali, idRiga })

    vincoli[idRiga] = {
        centro = vector3(riga.centro_x, riga.centro_y, 0.0),
        raggio = raggio, ettari = ettari, fino = fino, incendio = idRiga,
        data = U.DataIT(os.time()),
    }
    diffondiVincoli()

    exports.aurea_ui:NotificaTutti({
        tipo = 'avviso', icona = '⛔', durata = 20000,
        titolo = 'Vincolo su soprassuolo percorso dal fuoco',
        testo = ('%s — %.2f ettari, raggio %d metri.\nPer %d anni non si edifica e non si pascola.')
            :format(FOR.Vincolo.articolo, ettari, raggio, FOR.Vincolo.anniNominali),
    })

    AUREA.Log('staff', 'info', g,
        ('vincolo decennale su %.2f ettari, raggio %dm'):format(ettari, raggio))

    rispondi(true, ('Vincolo apposto su %d metri di raggio. Su quel terreno non si costruisce più.')
        :format(raggio))
end)

AUREA.Callback.Registra('for:vincoliAttivi', function(src, rispondi)
    local out = {}
    for _, v in ipairs(pacchettoVincoli()) do out[#out + 1] = v end
    rispondi(out)
end)

-- ---------------------------------------------------------------------------
--  Gli accertamenti su persona
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('for:accertamento', function(src, rispondi, tipo, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    if not forestale(g, 'multa') then return rispondi(false, 'Serve essere in servizio.') end

    local a = FOR.GetAccertamento(tipo)
    if not a then return rispondi(false, 'Tipo di accertamento non previsto.') end

    local b = AUREA.GetPlayer(tonumber(bersaglioSrc) or 0)
    if not b then return rispondi(false, 'Nessuno da contestare.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(b.source))) > 8.0 then
        return rispondi(false, 'Troppo lontano.') end

    local coord = GetEntityCoords(GetPlayerPed(b.source))
    local note = {}

    -- Il bracconaggio si contesta solo a chi la licenza non ce l'ha:
    -- chi caccia in regola sta facendo una cosa lecita.
    if tipo == 'bracconaggio' then
        local okL, licenza = pcall(function()
            return exports.ita_attivita:LicenzaValida(b.citizenid, 'caccia')
        end)
        if okL and licenza then
            return rispondi(false, 'La licenza di caccia è in regola: non c\'è niente da contestare.')
        end
    end

    -- Il pascolo e l'edilizia si contestano solo dentro un vincolo.
    if tipo == 'pascolo' or tipo == 'vincolo' then
        local v = vincoloSu(coord)
        if not v then
            return rispondi(false, 'Qui non insiste nessun vincolo: la contestazione non sta in piedi.')
        end
        note[#note + 1] = ('%.2f ettari vincolati'):format(v.ettari)
    end

    exports.ita_codicestrada:EmettiVerbale({
        citizenid = b.citizenid,
        articolo = a.articolo,
        descrizione = #note > 0 and ('%s (%s)'):format(a.etichetta, table.concat(note, ', '))
                                 or a.etichetta,
        importo = a.sanzione, punti = 0,
        origine = 'agente', agente = g:NomeCompleto(),
        luogo = ('%.0f, %.0f'):format(coord.x, coord.y),
    })

    -- Il sequestro dell'arma al bracconiere
    local sequestro = nil
    if a.sequestraArmi and g:HaPermessoLavoro('sequestro') then
        local okA, ha = pcall(function()
            return exports.aurea_inventory:Ha(b.citizenid, FOR.Sequestro.arma, 1)
        end)
        if okA and ha then
            pcall(function()
                exports.aurea_inventory:Rimuovi(b.citizenid, FOR.Sequestro.arma, 1)
            end)
            sequestro = 'arma da fuoco'
        end

        local okM, quante = pcall(function()
            return exports.aurea_inventory:Quantita(b.citizenid, FOR.Sequestro.munizioni)
        end)
        quante = okM and tonumber(quante) or 0
        if quante > 0 then
            pcall(function()
                exports.aurea_inventory:Rimuovi(b.citizenid, FOR.Sequestro.munizioni, quante)
            end)
            sequestro = sequestro and (sequestro .. ' e munizioni') or 'munizioni'
        end
    end

    MySQL.insert.await([[
        INSERT INTO forestale_accertamenti
            (tipo, citizenid, operatore, luogo, descrizione, sanzione, sequestro)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { tipo, b.citizenid, g.citizenid, ('%.0f, %.0f'):format(coord.x, coord.y),
          a.etichetta, a.sanzione, sequestro })

    AUREA.Log('multe', 'info', g, ('accertamento %s a carico di %s'):format(tipo, b.citizenid))

    rispondi(true, {
        etichetta = a.etichetta,
        persona = b:NomeCompleto(),
        sanzione = a.sanzione,
        sequestro = sequestro,
    })
end)

AUREA.Callback.Registra('for:registro', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not forestale(g) then return rispondi(nil) end

    local righe = MySQL.query.await([[
        SELECT a.tipo, a.descrizione, a.sanzione, a.sequestro, a.luogo,
               TIMESTAMPDIFF(MINUTE, a.accertato_il, NOW()) AS minutiFa,
               CONCAT(p.nome, ' ', p.cognome) AS persona
        FROM forestale_accertamenti a
        LEFT JOIN personaggi p ON p.citizenid = a.citizenid
        ORDER BY a.id DESC LIMIT 20
    ]]) or {}
    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Avvio
-- ---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(risorsa)
    if risorsa ~= GetCurrentResourceName() then return end
    Wait(2000)

    -- I vincoli sopravvivono a un riavvio: un provvedimento decennale che
    -- decade perché il server si è riacceso non è un provvedimento.
    local righe = MySQL.query.await([[
        SELECT id, centro_x, centro_y, ettari, DATE_FORMAT(rilevato_il, '%d/%m/%Y') AS data
        FROM forestale_incendi
        WHERE vincolo = 1 AND (vincolo_fino IS NULL OR vincolo_fino >= CURDATE())
    ]]) or {}

    for _, r in ipairs(righe) do
        local ettari = tonumber(r.ettari) or 0
        vincoli[r.id] = {
            centro = vector3(r.centro_x, r.centro_y, 0.0),
            raggio = FOR.RaggioVincolo(ettari), ettari = ettari,
            -- Dopo un riavvio la durata riparte: il timestamp d'origine
            -- non lo conserviamo, e stimarlo male sarebbe peggio.
            fino = os.time() + FOR.Vincolo.minutiDurata * 60,
            incendio = r.id, data = r.data,
        }
    end

    if #righe > 0 then
        print(('[AUREA] forestale: %d vincoli in vigore'):format(#righe))
    end
    diffondiVincoli()
end)

AddEventHandler('aurea:giocatore:caricato', function(src)
    TriggerClientEvent('for:vincoli', src, pacchettoVincoli())
end)
