--[[
    AUREA · Attività di raccolta (server)
]]

local U = AUREA.Util
local inCorso = {}          -- [src] = { tipo, avviata }
local capiAbbattuti = {}    -- [citizenid] = { giorno, quanti }
local raccolti = {}         -- [citizenid] = { giorno, quanti }

-- ---------------------------------------------------------------------------
--  Licenze
-- ---------------------------------------------------------------------------
local function licenzaValida(citizenid, tipo)
    return MySQL.single.await([[
        SELECT tipo, scadenza FROM licenze
        WHERE citizenid = ? AND tipo = ? AND revocata = 0 AND scadenza >= CURDATE()
    ]], { citizenid, tipo })
end

exports('LicenzaValida', licenzaValida)

AUREA.Callback.Registra('att:licenze', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local out = {}
    for tipo, def in pairs(ATT.Licenze) do
        local riga = licenzaValida(g.citizenid, tipo)
        out[#out + 1] = {
            tipo = tipo, etichetta = def.etichetta, rilasciata = def.rilasciata,
            costo = def.costo, validitaGiorni = def.validitaGiorni,
            attiva = riga ~= nil,
            scadenza = riga and U.DataIT(math.floor(riga.scadenza / 1000)) or nil,
        }
    end
    table.sort(out, function(a, b) return a.etichetta < b.etichetta end)
    rispondi(out)
end)

AUREA.Callback.Registra('att:richiediLicenza', function(src, rispondi, tipo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local def = ATT.Licenze[tipo]
    if not def then return rispondi(false, 'Licenza non prevista.') end
    if licenzaValida(g.citizenid, tipo) then return rispondi(false, 'Ne hai già una in corso di validità.') end

    if not g:SottraiOvunque(def.costo, ('rilascio %s'):format(def.etichetta)) then
        return rispondi(false, ('I diritti sono %s.'):format(U.Euro(def.costo)))
    end

    MySQL.query.await([[
        INSERT INTO licenze (citizenid, tipo, rilascio, scadenza) VALUES (?, ?, CURDATE(), ?)
        ON DUPLICATE KEY UPDATE scadenza = VALUES(scadenza), revocata = 0
    ]], { g.citizenid, tipo, U.DataPiuGiorni(def.validitaGiorni) })

    TriggerEvent('aurea:fisco:incasso', 'diritti_licenze', def.costo, g.citizenid)
    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'licenza', 1, {
        tipo = def.etichetta,
        intestatario = g:NomeCompleto(),
        scadenza = U.DataIT(os.time() + def.validitaGiorni * 86400),
        origine = def.rilasciata,
    })

    rispondi(true, ('%s rilasciata dalla %s. Valida fino al %s.'):format(
        def.etichetta, def.rilasciata, U.DataIT(os.time() + def.validitaGiorni * 86400)))
end)

--- Sanziona chi esercita senza titolo.
local function sanzionaSenzaLicenza(g, tipo)
    local def = ATT.Licenze[tipo]
    exports.ita_codicestrada:EmettiVerbale({
        citizenid = g.citizenid,
        articolo = def.articolo,
        descrizione = ('Esercizio senza %s'):format(def.etichetta:lower()),
        importo = def.sanzione,
        punti = 0,
        origine = 'agente',
        agente = 'vigilanza',
        luogo = 'controllo sul posto',
    })

    TriggerClientEvent('aurea:ui:notifica', g.source, {
        tipo = 'errore', icona = '⚖', durata = 14000,
        titolo = 'Controllo della vigilanza',
        testo = ('Sei stato sorpreso senza %s. Verbale di %s.'):format(def.etichetta:lower(), U.Euro(def.sanzione)),
    })
end

-- ---------------------------------------------------------------------------
--  PESCA
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('att:pesca', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local zona = ATT.ZonaPesca(coord)
    if not zona then return rispondi(nil, 'Qui non si può pescare.') end

    if not exports.aurea_inventory:Ha(g.citizenid, ATT.Pesca.attrezzo, 1) then
        return rispondi(nil, 'Ti serve una canna da pesca.')
    end

    -- Senza licenza si pesca lo stesso, ma si rischia il verbale
    local haLicenza = licenzaValida(g.citizenid, 'pesca') ~= nil
    if not haLicenza and math.random(100) <= 30 then
        sanzionaSenzaLicenza(g, 'pesca')
        return rispondi(nil, 'La vigilanza ti ha fermato.')
    end

    inCorso[src] = { tipo = 'pesca', avviata = os.time(), zona = zona.zona, haLicenza = haLicenza }
    rispondi({ durata = ATT.Pesca.durata, zona = zona.nome })
end)

AUREA.Callback.Registra('att:concludiPesca', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione or sessione.tipo ~= 'pesca' then return rispondi(false) end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < ATT.Pesca.durata * 0.8 then
        AUREA.Log('anticheat', 'avviso', g, 'pesca conclusa troppo in fretta')
        return rispondi(false, 'Azione non valida.')
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    -- L'esca migliora la resa e viene consumata
    local moltiplicatore = 1.0
    for esca, valore in pairs(ATT.Pesca.esche) do
        if inventario:Ha(esca, 1) then
            inventario:Rimuovi(esca, 1)
            moltiplicatore = valore
            break
        end
    end

    -- Talvolta non abbocca niente
    if math.random() > (0.62 * moltiplicatore) then
        TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
        return rispondi(true, 'Non ha abboccato nulla. Riprova.')
    end

    -- Specie protetta: reato anche con licenza
    if math.random(100) <= 3 then
        local protetta = ATT.Pesca.protette[1]
        exports.ita_giustizia:ApriFascicolo(g.citizenid, '635', 'Guardia Costiera', protetta.nota)
        return rispondi(false, ('Hai raccolto %s. È vietato per legge: è stato aperto un fascicolo.'):format(protetta.nome))
    end

    local candidate = {}
    for _, s in ipairs(ATT.Pesca.specie) do
        if s.zona == sessione.zona then candidate[#candidate + 1] = s end
    end
    if #candidate == 0 then return rispondi(true, 'Acque deserte.') end

    local specie = ATT.Estrai(candidate)
    local taglia = specie.taglia > 0
        and math.floor(specie.taglia * (0.7 + math.random() * 0.8))
        or 0

    -- Sottomisura: va rigettato
    if specie.taglia > 0 and taglia < specie.taglia then
        return rispondi(true, ('Hai preso un %s di %d cm: sotto la misura minima di %d cm. Rigettato in acqua.'):format(
            specie.nome:lower(), taglia, specie.taglia))
    end

    local quantita = specie.pregiato and 1 or math.random(1, 2)
    local ok = inventario:Aggiungi(specie.item, quantita, {
        taglia = taglia > 0 and (taglia .. ' cm') or nil,
        pescatore = g:NomeCompleto(),
    })
    if not ok then return rispondi(false, 'Non hai spazio: il pescato è andato perso.') end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    rispondi(true, ('%d× %s%s'):format(quantita, specie.nome,
        taglia > 0 and (' di %d cm'):format(taglia) or ''))
end)

-- ---------------------------------------------------------------------------
--  CACCIA
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('att:abbattimento', function(src, rispondi, modello)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local zona = ATT.ZonaCaccia(coord)

    -- Specie protetta: reato ovunque, anche in riserva e con licenza
    for _, p in ipairs(ATT.Caccia.protette) do
        if p.modello == modello then
            exports.ita_giustizia:ApriFascicolo(g.citizenid, p.reato, 'vigilanza venatoria',
                ('Abbattimento di specie protetta: %s'):format(p.nome))
            exports.ita_codicestrada:EmettiVerbale({
                citizenid = g.citizenid,
                articolo = 'art. 30 L. 157/92',
                descrizione = ('Abbattimento di %s, specie particolarmente protetta'):format(p.nome),
                importo = p.sanzione, punti = 0, origine = 'agente',
                agente = 'vigilanza venatoria', luogo = zona and zona.nome or 'territorio libero',
            })
            return rispondi(false, ('%s è specie protetta. Verbale e fascicolo penale.'):format(p.nome))
        end
    end

    if not zona then return rispondi(false, 'Fuori dalle zone in cui la caccia è consentita.') end

    local mese = tonumber(os.date('%m'))
    if not ATT.CacciaAperta(mese) then
        exports.ita_codicestrada:EmettiVerbale({
            citizenid = g.citizenid,
            articolo = 'art. 30 L. 157/92',
            descrizione = 'Esercizio venatorio in periodo di divieto',
            importo = ATT.Licenze.caccia.sanzione, punti = 0, origine = 'agente',
            agente = 'vigilanza venatoria', luogo = zona.nome,
        })
        return rispondi(false, 'La stagione venatoria è chiusa: verbale elevato.')
    end

    local ora = tonumber(os.date('%H'))
    if ora < ATT.Caccia.oraDa or ora >= ATT.Caccia.oraA then
        return rispondi(false, ('Si può cacciare solo dalle %d alle %d.'):format(ATT.Caccia.oraDa, ATT.Caccia.oraA))
    end

    if not licenzaValida(g.citizenid, 'caccia') then
        sanzionaSenzaLicenza(g, 'caccia')
        return rispondi(false, 'Non hai la licenza di caccia.')
    end

    if not exports.aurea_armi:TitoloValido(g.citizenid) then
        return rispondi(false, 'Serve anche il porto d\'armi per uso venatorio.')
    end

    -- Tesserino venatorio: capi limitati per giornata
    local oggi = os.date('%Y-%m-%d')
    local registro = capiAbbattuti[g.citizenid]
    if not registro or registro.giorno ~= oggi then
        registro = { giorno = oggi, quanti = 0 }
        capiAbbattuti[g.citizenid] = registro
    end

    if registro.quanti >= ATT.Caccia.capiGiornalieri then
        return rispondi(false, ('Hai già abbattuto %d capi oggi: il carniere giornaliero è esaurito.'):format(
            ATT.Caccia.capiGiornalieri))
    end

    local specie
    for _, s in ipairs(ATT.Caccia.specie) do
        if s.modello == modello then specie = s break end
    end
    if not specie then return rispondi(false, 'Non è selvaggina cacciabile.') end

    registro.quanti = registro.quanti + 1

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local quantita = math.random(1, 3)
    if not inventario:Aggiungi(specie.item, quantita, { provenienza = zona.nome, cacciatore = g:NomeCompleto() }) then
        return rispondi(false, 'Non hai spazio per la carne.')
    end

    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    rispondi(true, ('%d× %s. Carniere: %d/%d capi.'):format(
        quantita, AUREA.Item[specie.item].etichetta, registro.quanti, ATT.Caccia.capiGiornalieri))
end)

-- ---------------------------------------------------------------------------
--  CAVA E RACCOLTA
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('att:cava', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    if #(coord - ATT.Cava.coord) > ATT.Cava.raggio then return rispondi(nil, 'Non sei in cava.') end

    if not exports.aurea_inventory:Ha(g.citizenid, ATT.Cava.attrezzo, 1) then
        return rispondi(nil, 'Ti serve un piccone.')
    end

    inCorso[src] = { tipo = 'cava', avviata = os.time() }
    rispondi({ durata = ATT.Cava.durata })
end)

AUREA.Callback.Registra('att:concludiCava', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione or sessione.tipo ~= 'cava' then return rispondi(false) end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < ATT.Cava.durata * 0.8 then
        return rispondi(false, 'Azione non valida.')
    end

    local materiale = ATT.Estrai(ATT.Cava.resa)
    local quantita = materiale.pregiato and 1 or math.random(1, 3)

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Aggiungi(materiale.item, quantita) then
        return rispondi(false, 'Non hai spazio nello zaino.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    rispondi(true, ('%d× %s'):format(quantita, AUREA.Item[materiale.item].etichetta))
end)

AUREA.Callback.Registra('att:raccolta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local coord = GetEntityCoords(GetPlayerPed(src))
    local zona = ATT.ZonaRaccolta(coord)
    if not zona then return rispondi(nil, 'Qui non c\'è nulla da raccogliere.') end

    local oggi = os.date('%Y-%m-%d')
    local registro = raccolti[g.citizenid]
    if not registro or registro.giorno ~= oggi then
        registro = { giorno = oggi, quanti = 0 }
        raccolti[g.citizenid] = registro
    end

    if registro.quanti >= ATT.Raccolta.limiteGiornaliero then
        return rispondi(nil, ('Il tesserino consente %d raccolte al giorno: hai finito.'):format(
            ATT.Raccolta.limiteGiornaliero))
    end

    if not licenzaValida(g.citizenid, 'raccolta') and math.random(100) <= 20 then
        sanzionaSenzaLicenza(g, 'raccolta')
        return rispondi(nil, 'La vigilanza ti ha fermato: manca il tesserino.')
    end

    inCorso[src] = { tipo = 'raccolta', avviata = os.time(), zona = zona }
    rispondi({ durata = ATT.Raccolta.durata, zona = zona.nome })
end)

AUREA.Callback.Registra('att:concludiRaccolta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione or sessione.tipo ~= 'raccolta' then return rispondi(false) end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < ATT.Raccolta.durata * 0.8 then
        return rispondi(false, 'Azione non valida.')
    end

    local prodotto = ATT.Estrai(sessione.zona.resa)
    local quantita = prodotto.pregiato and 1 or math.random(1, 3)

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Aggiungi(prodotto.item, quantita) then
        return rispondi(false, 'Non hai spazio nel cesto.')
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local registro = raccolti[g.citizenid]
    if registro then registro.quanti = registro.quanti + 1 end

    rispondi(true, ('%d× %s%s'):format(quantita, AUREA.Item[prodotto.item].etichetta,
        prodotto.pregiato and ' — un ritrovamento raro' or ''))
end)

AddEventHandler('playerDropped', function() inCorso[source] = nil end)

-- ---------------------------------------------------------------------------
--  Controllo della vigilanza
-- ---------------------------------------------------------------------------
AUREA.Comando('controllolicenze', 'utente', 'Verifica le licenze della persona vicina', {}, function(src, _, _, g)
    if not g or not g:HaPermessoLavoro('mdt') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Riservato al personale di vigilanza.',
        })
    end

    local origine = GetEntityCoords(GetPlayerPed(src))
    local bersaglio, minima = nil, 4.0
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= src then
            local d = #(origine - GetEntityCoords(GetPlayerPed(altro.source)))
            if d < minima then bersaglio, minima = altro, d end
        end
    end
    if not bersaglio then
        return TriggerClientEvent('aurea:ui:notifica', src, { tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.' })
    end

    local righe = {}
    for tipo, def in pairs(ATT.Licenze) do
        local riga = licenzaValida(bersaglio.citizenid, tipo)
        righe[#righe + 1] = ('%s: %s'):format(def.etichetta,
            riga and ('valida fino al ' .. U.DataIT(math.floor(riga.scadenza / 1000))) or 'ASSENTE')
    end

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '📋', durata = 16000,
        titolo = ('Licenze — %s'):format(bersaglio:NomeCompleto()),
        testo = table.concat(righe, '\n'),
    })
end)
