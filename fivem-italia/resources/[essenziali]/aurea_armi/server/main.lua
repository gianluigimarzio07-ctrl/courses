--[[
    AUREA · Armi (server)
    Registro nazionale, titoli di porto d'armi, controlli.
]]

local U = AUREA.Util

-- ---------------------------------------------------------------------------
--  Registro delle armi
-- ---------------------------------------------------------------------------

--- Genera una matricola nel formato dei numeri di catalogo italiani.
local function nuovaMatricola()
    for _ = 1, 30 do
        local m = ('%s%s'):format(U.Random(2), U.Random(6, '0123456789'))
        if not MySQL.scalar.await('SELECT matricola FROM armi WHERE matricola = ?', { m }) then
            return m
        end
    end
    return U.Random(2) .. U.Random(6, '0123456789')
end

--- Iscrive un'arma al registro e la consegna all'intestatario.
local function registra(citizenid, nomeArma, clandestina)
    local catalogo = ARM.GetArma(nomeArma)
    if not catalogo then return nil end

    local matricola = clandestina and 'ABRASA' or nuovaMatricola()

    local id = MySQL.insert.await([[
        INSERT INTO armi (matricola, arma, nome, categoria, intestatario, clandestina, denuncia_entro)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        matricola, nomeArma, catalogo.nome, catalogo.categoria, citizenid,
        clandestina and 1 or 0,
        clandestina and nil or U.DataPiuGiorni(ARM.Regole.giorniDenuncia),
    })

    -- L'arma entra nell'inventario come oggetto unico, con la sua matricola
    TriggerEvent('aurea:inventario:aggiungi', citizenid, 'arma', 1, {
        arma = nomeArma,
        nomeArma = catalogo.nome,
        matricola = matricola,
        categoria = catalogo.categoria,
        registroId = id,
        munizioni = 0,
    })

    return id, matricola
end

exports('RegistraArma', registra)

-- ---------------------------------------------------------------------------
--  Titoli di porto d'armi
-- ---------------------------------------------------------------------------
local function titoloValido(citizenid)
    local riga = MySQL.single.await([[
        SELECT tipo, scadenza FROM porto_armi
        WHERE citizenid = ? AND revocato = 0 AND scadenza >= CURDATE()
        ORDER BY scadenza DESC LIMIT 1
    ]], { citizenid })
    return riga
end

exports('TitoloValido', titoloValido)

AUREA.Callback.Registra('arm:mieArmi', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT id, matricola, nome, categoria, clandestina, denunciata, denuncia_entro, sequestrata
        FROM armi WHERE intestatario = ? AND distrutta = 0
    ]], { g.citizenid }) or {}

    for _, a in ipairs(righe) do
        a.scadenzaDenuncia = a.denuncia_entro and U.DataIT(math.floor(a.denuncia_entro / 1000)) or nil
    end

    local titolo = titoloValido(g.citizenid)
    rispondi({
        armi = righe,
        titolo = titolo and {
            tipo = titolo.tipo,
            etichetta = ARM.Titoli[titolo.tipo] and ARM.Titoli[titolo.tipo].etichetta or titolo.tipo,
            scadenza = U.DataIT(math.floor(titolo.scadenza / 1000)),
            consentePorto = ARM.Titoli[titolo.tipo] and ARM.Titoli[titolo.tipo].consentePorto or false,
        } or nil,
    })
end)

AUREA.Callback.Registra('arm:richiediTitolo', function(src, rispondi, tipo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local t = ARM.Titoli[tipo]
    if not t then return rispondi(false, 'Titolo non previsto.') end

    if t.soloLavori then
        local ammesso = false
        for _, l in ipairs(t.soloLavori) do
            if g.lavoro.nome == l then ammesso = true break end
        end
        if not ammesso then return rispondi(false, 'Questo titolo è assegnato d\'ufficio al personale in servizio.') end
    end

    if titoloValido(g.citizenid) then
        return rispondi(false, 'Hai già un titolo in corso di validità.')
    end

    -- La fedina deve essere pulita per i reati che ostano al rilascio
    if t.requisiti and t.requisiti.fedinaPulita then
        local ostativi = MySQL.scalar.await([[
            SELECT COUNT(*) FROM casellario
            WHERE citizenid = ? AND stato = 'condannato' AND gravita >= 3
        ]], { g.citizenid }) or 0

        if ostativi > 0 then
            return rispondi(false, ('Il rilascio è negato: risultano %d condanne ostative nel tuo casellario.'):format(ostativi))
        end
    end

    if t.requisiti and t.requisiti.licenzaCaccia then
        local licenza = MySQL.scalar.await([[
            SELECT id FROM licenze WHERE citizenid = ? AND tipo = 'caccia' AND scadenza >= CURDATE()
        ]], { g.citizenid })
        if not licenza then
            return rispondi(false, 'Serve prima la licenza di caccia, rilasciata dalla Provincia.')
        end
    end

    if t.costo > 0 and not g:SottraiOvunque(t.costo, ('rilascio %s'):format(t.etichetta)) then
        return rispondi(false, ('I diritti di rilascio sono %s.'):format(U.Euro(t.costo)))
    end

    -- Il rinnovo riusa la riga esistente: un cittadino ha un solo titolo per tipo.
    MySQL.query.await([[
        INSERT INTO porto_armi (citizenid, tipo, rilascio, scadenza) VALUES (?, ?, CURDATE(), ?)
        ON DUPLICATE KEY UPDATE rilascio = CURDATE(), scadenza = VALUES(scadenza),
                                revocato = 0, motivo_revoca = NULL
    ]], { g.citizenid, tipo, U.DataPiuGiorni(t.validitaGiorni) })

    if t.costo > 0 then
        TriggerEvent('aurea:fisco:incasso', 'diritti_porto_armi', t.costo, g.citizenid)
    end

    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'porto_armi', 1, {
        tipo = t.etichetta,
        intestatario = g:NomeCompleto(),
        scadenza = U.DataIT(os.time() + t.validitaGiorni * 86400),
    })

    AUREA.Log('giustizia', 'info', g, ('rilasciato %s'):format(t.etichetta))
    rispondi(true, ('%s rilasciato. Valido fino al %s.'):format(
        t.etichetta, U.DataIT(os.time() + t.validitaGiorni * 86400)))
end)

--- Denuncia di detenzione: obbligatoria dopo l'acquisto.
AUREA.Callback.Registra('arm:denuncia', function(src, rispondi, idArma)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local arma = MySQL.single.await('SELECT * FROM armi WHERE id = ? AND intestatario = ?', { idArma, g.citizenid })
    if not arma then return rispondi(false, 'Arma non intestata a te.') end
    if arma.clandestina == 1 then return rispondi(false, 'Quest\'arma non ha matricola: non è denunciabile.') end
    if arma.denunciata == 1 then return rispondi(false, 'Già denunciata.') end

    MySQL.update.await('UPDATE armi SET denunciata = 1, denuncia_entro = NULL WHERE id = ?', { idArma })
    rispondi(true, ('Detenzione denunciata. Matricola %s iscritta a tuo nome.'):format(arma.matricola))
end)

-- ---------------------------------------------------------------------------
--  Acquisto in armeria
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('arm:catalogo', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local titolo = titoloValido(g.citizenid)
    if not titolo then return rispondi({ titolo = nil, armi = {} }) end

    local acquistabili = ARM.AcquistabiliCon(titolo.tipo)
    rispondi({
        titolo = ARM.Titoli[titolo.tipo].etichetta,
        armi = acquistabili,
        prezzoCartuccia = ARM.Regole.prezzoCartuccia,
        prezzoCartucciaCaccia = ARM.Regole.prezzoCartucciaCaccia,
    })
end)

AUREA.Callback.Registra('arm:acquista', function(src, rispondi, nomeArma)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local titolo = titoloValido(g.citizenid)
    if not titolo then return rispondi(false, 'Senza porto d\'armi non si vende nulla.') end

    local catalogo = ARM.GetArma(nomeArma)
    if not catalogo or catalogo.prezzo <= 0 then return rispondi(false, 'Arma non in vendita.') end

    local ammessa = false
    for _, categoria in ipairs(ARM.Titoli[titolo.tipo].categorie) do
        if catalogo.categoria == categoria then ammessa = true break end
    end
    if not ammessa then
        return rispondi(false, ('Il tuo titolo non consente l\'acquisto di armi in categoria "%s".'):format(catalogo.categoria))
    end

    if not g:Sottrai('banca', catalogo.prezzo, ('acquisto %s'):format(catalogo.nome)) then
        return rispondi(false, ('Servono %s sul conto: le armi non si pagano in contanti.'):format(U.Euro(catalogo.prezzo)))
    end

    local _, matricola = registra(g.citizenid, nomeArma, false)
    TriggerEvent('aurea:fisco:incasso', 'iva', math.floor(catalogo.prezzo * 0.18), g.citizenid)

    AUREA.Log('giustizia', 'avviso', g, ('ha acquistato %s matricola %s'):format(catalogo.nome, matricola))

    rispondi(true, ('%s acquistata. Matricola %s: hai %d giorni per denunciarne la detenzione.'):format(
        catalogo.nome, matricola, ARM.Regole.giorniDenuncia))
end)

AUREA.Callback.Registra('arm:munizioni', function(src, rispondi, tipo, quantita)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if not titoloValido(g.citizenid) then
        return rispondi(false, 'Le munizioni si vendono solo a chi ha un titolo valido.')
    end

    quantita = math.floor(U.Clamp(tonumber(quantita) or 0, 1, ARM.Regole.massimoAcquistoMunizioni))
    local item = tipo == 'caccia' and 'cartuccia_caccia' or 'cartuccia'
    local prezzo = tipo == 'caccia' and ARM.Regole.prezzoCartucciaCaccia or ARM.Regole.prezzoCartuccia
    local totale = quantita * prezzo

    if not g:SottraiOvunque(totale, 'acquisto munizioni') then
        return rispondi(false, ('Servono %s.'):format(U.Euro(totale)))
    end

    local ok = exports.aurea_inventory:Aggiungi(g.citizenid, item, quantita)
    if not ok then
        g:Aggiungi('contanti', totale, 'rimborso munizioni')
        return rispondi(false, 'Non hai spazio nell\'inventario.')
    end

    TriggerEvent('aurea:fisco:incasso', 'iva', math.floor(totale * 0.18), g.citizenid)
    rispondi(true, ('%d cartucce per %s.'):format(quantita, U.Euro(totale)))
end)

-- ---------------------------------------------------------------------------
--  Armeria di reparto
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('arm:ordinanza', function(src, rispondi, nomeArma)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if not g.lavoro.servizio then return rispondi(false, 'Devi essere in servizio.') end
    if not g:HaPermessoLavoro('armeria') then
        return rispondi(false, 'Il tuo grado non consente il prelievo dall\'armeria.')
    end

    local catalogo = ARM.GetArma(nomeArma)
    if not catalogo or catalogo.categoria ~= 'ordinanza' then
        return rispondi(false, 'Arma non in dotazione.')
    end

    if catalogo.gradoMinimo and g.lavoro.grado < catalogo.gradoMinimo then
        return rispondi(false, ('Serve almeno il grado di %s.'):format(
            AUREA.GetGrado(g.lavoro.nome, catalogo.gradoMinimo).etichetta))
    end

    TriggerClientEvent('arm:consegna', src, nomeArma, catalogo.capienza and 120 or 0)
    AUREA.Log('staff', 'debug', g, ('prelievo d\'ordinanza: %s'):format(catalogo.nome))

    rispondi(true, ('%s prelevata. Riconsegnala a fine turno.'):format(catalogo.nome))
end)

--- A fine servizio l'arma di ordinanza torna in armeria.
AddEventHandler('aurea:servizio:cambiato', function(src, lavoro, inServizio)
    if not inServizio then
        TriggerClientEvent('arm:svuotaOrdinanza', src)
    end
end)

-- ---------------------------------------------------------------------------
--  Controlli delle forze dell'ordine
-- ---------------------------------------------------------------------------

--- Chiamato dal client quando un agente controlla una persona armata.
AUREA.Callback.Registra('arm:controlla', function(src, rispondi, bersaglioSrc)
    local agente = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not agente or not soggetto then return rispondi(nil) end

    if not agente:HaPermessoLavoro('perquisizione') or not agente.lavoro.servizio then
        return rispondi(nil, 'Non sei autorizzato.')
    end

    local d = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(soggetto.source)))
    if d > 3.5 then return rispondi(nil, 'Il soggetto è troppo lontano.') end

    local titolo = titoloValido(soggetto.citizenid)
    local armi = MySQL.query.await([[
        SELECT matricola, nome, categoria, clandestina, denunciata
        FROM armi WHERE intestatario = ? AND distrutta = 0 AND sequestrata = 0
    ]], { soggetto.citizenid }) or {}

    rispondi({
        nome = soggetto:NomeCompleto(),
        cf = soggetto.cf,
        titolo = titolo and ARM.Titoli[titolo.tipo].etichetta or nil,
        consentePorto = titolo and ARM.Titoli[titolo.tipo].consentePorto or false,
        armi = armi,
    })
end)

--- Sequestro di un'arma.
AUREA.Callback.Registra('arm:sequestra', function(src, rispondi, matricola, bersaglioSrc)
    local agente = AUREA.GetPlayer(src)
    local soggetto = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not agente or not soggetto then return rispondi(false) end
    if not agente:HaPermessoLavoro('sequestro') then
        return rispondi(false, 'Il tuo grado non consente il sequestro.')
    end

    local arma = MySQL.single.await('SELECT * FROM armi WHERE matricola = ? AND intestatario = ?',
        { matricola, soggetto.citizenid })
    if not arma then return rispondi(false, 'Arma non trovata.') end

    MySQL.update.await('UPDATE armi SET sequestrata = 1 WHERE id = ?', { arma.id })

    -- Si toglie anche dall'inventario e dalle mani
    local inventario = exports.aurea_inventory:Inventario(soggetto.citizenid)
    for _, riga in ipairs(U.CopiaProfonda(inventario.item)) do
        if riga.nome == 'arma' and riga.metadata and riga.metadata.matricola == matricola then
            inventario:Rimuovi('arma', 1, riga.slot)
        end
    end
    TriggerClientEvent('inv:aggiorna', soggetto.source, inventario:Pacchetto())
    TriggerClientEvent('arm:rimuovi', soggetto.source, arma.arma)

    -- Il reato dipende da come stava messa
    local codice = arma.clandestina == 1 and ARM.Regole.reatoClandestina or ARM.Regole.reatoPortoAbusivo
    exports.ita_giustizia:ApriFascicolo(soggetto.citizenid, codice, agente:NomeCompleto(),
        ('Sequestro arma matricola %s'):format(arma.matricola))

    AUREA.Log('giustizia', 'avviso', agente, ('sequestro arma %s a %s'):format(matricola, soggetto.citizenid))
    rispondi(true, ('%s sequestrata e fascicolo aperto.'):format(arma.nome))
end)

-- ---------------------------------------------------------------------------
--  Scadenze dei titoli
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(90000)
    while true do
        -- Preavviso di scadenza
        local inScadenza = MySQL.query.await([[
            SELECT citizenid, tipo, scadenza FROM porto_armi
            WHERE revocato = 0 AND scadenza BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)
        ]], { ARM.Regole.giorniPreavvisoScadenza }) or {}

        for _, t in ipairs(inScadenza) do
            TriggerEvent('aurea:telefono:messaggioSistema', t.citizenid, 'Questura',
                ('Il tuo %s è in scadenza. Rinnovalo all\'Ufficio Armi per non incorrere in sanzioni.'):format(
                    ARM.Titoli[t.tipo] and ARM.Titoli[t.tipo].etichetta or t.tipo))
        end

        -- Denunce di detenzione non presentate nei termini
        local omesse = MySQL.query.await([[
            SELECT id, intestatario, matricola FROM armi
            WHERE denunciata = 0 AND clandestina = 0 AND sequestrata = 0
              AND denuncia_entro IS NOT NULL AND denuncia_entro < CURDATE()
        ]]) or {}

        for _, a in ipairs(omesse) do
            MySQL.update('UPDATE armi SET denuncia_entro = NULL WHERE id = ?', { a.id })
            exports.ita_giustizia:ApriFascicolo(a.intestatario, '697', 'controllo d\'ufficio',
                ('Omessa denuncia di detenzione — matricola %s'):format(a.matricola))

            local g = AUREA.GetPlayerByCitizenId(a.intestatario)
            if g then
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'errore', icona = '⚖', durata = 13000,
                    titolo = 'Omessa denuncia di detenzione',
                    testo = ('Non hai denunciato l\'arma matricola %s nei termini: è stato aperto un fascicolo.'):format(a.matricola),
                })
            end
        end

        Wait(30 * 60000)
    end
end)

-- ---------------------------------------------------------------------------
--  Comandi
-- ---------------------------------------------------------------------------
AUREA.Comando('armi', 'utente', 'Consulta le tue armi e il porto d\'armi', {}, function(src)
    TriggerClientEvent('arm:apriRegistro', src)
end)

AUREA.Comando('controlloarmi', 'utente', 'Controlla la posizione di una persona in materia di armi', {}, function(src, _, _, g)
    if not g or not g:HaPermessoLavoro('perquisizione') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato alle forze dell\'ordine.',
        })
    end
    TriggerClientEvent('arm:apriControllo', src)
end)
