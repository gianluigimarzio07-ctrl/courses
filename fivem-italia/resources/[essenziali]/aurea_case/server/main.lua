--[[
    AUREA · Immobili (server)
]]

local U = AUREA.Util
local dentro = {}     -- [src] = idImmobile

-- Ogni immobile ha un routing bucket dedicato: l'id + un offset fisso.
local OFFSET_BUCKET = 1000

local function chiaviDi(immobile)
    return immobile.chiavi and json.decode(immobile.chiavi) or {}
end

local function haAccesso(immobile, citizenid)
    if immobile.proprietario == citizenid then return true end
    if immobile.inquilino == citizenid then return true end
    return U.Contiene(chiaviDi(immobile), citizenid)
end

-- ---------------------------------------------------------------------------
--  Consultazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('casa:elenco', function(src, rispondi, soloMiei)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi({}) end

    local righe
    if soloMiei then
        righe = MySQL.query.await([[
            SELECT * FROM immobili WHERE proprietario = ? OR inquilino = ? ORDER BY prezzo DESC
        ]], { g.citizenid, g.citizenid }) or {}
    else
        righe = MySQL.query.await([[
            SELECT * FROM immobili WHERE in_vendita = 1 AND proprietario IS NULL ORDER BY prezzo ASC
        ]]) or {}
    end

    for _, i in ipairs(righe) do
        i.ingresso = i.ingresso and json.decode(i.ingresso) or nil
        i.internoEtichetta = CASA.GetInterno(i.interno).etichetta
        i.imposte = math.floor(i.prezzo * CASA.Regole.impostaRegistro)
        i.provvigione = math.floor(i.prezzo * CASA.Regole.provvigione)
        i.canone = math.floor(i.prezzo * CASA.Regole.canoneSuValore)
        i.eProprietario = i.proprietario == g.citizenid
        i.chiavi = nil
    end

    rispondi(righe)
end)

-- ---------------------------------------------------------------------------
--  Acquisto e vendita
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('casa:acquista', function(src, rispondi, idImmobile)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { idImmobile })
    if not i then return rispondi(false, 'Immobile non trovato.') end
    if i.proprietario then return rispondi(false, 'Immobile già venduto.') end

    local posseduti = MySQL.scalar.await('SELECT COUNT(*) FROM immobili WHERE proprietario = ?', { g.citizenid }) or 0
    if posseduti >= CASA.Regole.immobiliMassimi then
        return rispondi(false, ('Puoi possedere al massimo %d immobili.'):format(CASA.Regole.immobiliMassimi))
    end

    local imposte = math.floor(i.prezzo * CASA.Regole.impostaRegistro)
    local provvigione = math.floor(i.prezzo * CASA.Regole.provvigione)
    local totale = i.prezzo + imposte + provvigione

    if not g:Sottrai('banca', totale, ('acquisto %s'):format(i.nome)) then
        return rispondi(false, ('Servono %s sul conto (%s + imposta di registro %s + provvigione %s).'):format(
            U.Euro(totale), U.Euro(i.prezzo), U.Euro(imposte), U.Euro(provvigione)))
    end

    MySQL.update.await('UPDATE immobili SET proprietario = ?, in_vendita = 0, chiavi = ? WHERE id = ?',
        { g.citizenid, json.encode({}), idImmobile })

    TriggerEvent('aurea:fisco:incasso', 'imposta_registro', imposte, g.citizenid)
    TriggerEvent('aurea:inventario:aggiungi', g.citizenid, 'chiavi_casa', 1, {
        immobile = i.codice, indirizzo = i.indirizzo, tipo = i.tipo,
    })

    AUREA.Log('economia', 'info', g, ('ha acquistato %s per %s'):format(i.nome, U.Euro(i.prezzo)))
    rispondi(true, ('%s è tuo. Rogito registrato per %s.'):format(i.nome, U.Euro(totale)))
end)

AUREA.Callback.Registra('casa:vendi', function(src, rispondi, idImmobile)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ? AND proprietario = ?', { idImmobile, g.citizenid })
    if not i then return rispondi(false, 'Non sei il proprietario di questo immobile.') end
    if i.inquilino then return rispondi(false, 'C\'è un inquilino: risolvi prima il contratto di locazione.') end

    local ricavo = math.floor(i.prezzo * CASA.Regole.scontoRivendita)
    MySQL.update.await('UPDATE immobili SET proprietario = NULL, inquilino = NULL, in_vendita = 1, chiavi = ? WHERE id = ?',
        { json.encode({}), idImmobile })

    g:Aggiungi('banca', ricavo, ('vendita %s'):format(i.nome))
    exports.aurea_inventory:Rimuovi(g.citizenid, 'chiavi_casa', 1)

    rispondi(true, ('%s venduta all\'agenzia per %s.'):format(i.nome, U.Euro(ricavo)))
end)

-- ---------------------------------------------------------------------------
--  Accesso all'immobile
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('casa:entra', function(src, rispondi, idImmobile)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { idImmobile })
    if not i then return rispondi(nil, 'Immobile non trovato.') end

    if i.serratura == 1 and not haAccesso(i, g.citizenid) then
        return rispondi(nil, 'La porta è chiusa a chiave.')
    end

    -- ogni immobile ha la propria istanza
    SetPlayerRoutingBucket(src, OFFSET_BUCKET + i.id)
    dentro[src] = i.id

    local interno = CASA.GetInterno(i.interno)
    rispondi({
        interno = i.interno,
        ingresso = { x = interno.ingresso.x, y = interno.ingresso.y, z = interno.ingresso.z, h = interno.ingresso.w },
        deposito = interno.deposito and { x = interno.deposito.x, y = interno.deposito.y, z = interno.deposito.z } or nil,
        guardaroba = interno.guardaroba and { x = interno.guardaroba.x, y = interno.guardaroba.y, z = interno.guardaroba.z } or nil,
        nome = i.nome,
        eProprietario = i.proprietario == g.citizenid,
        idImmobile = i.id,
        capienzaDeposito = interno.capienzaDeposito,
        pesoDeposito = interno.pesoDeposito,
    })
end)

AUREA.Callback.Registra('casa:esci', function(src, rispondi)
    local idImmobile = dentro[src]
    dentro[src] = nil
    SetPlayerRoutingBucket(src, 0)

    if not idImmobile then return rispondi(nil) end

    local i = MySQL.single.await('SELECT ingresso FROM immobili WHERE id = ?', { idImmobile })
    rispondi(i and json.decode(i.ingresso) or nil)
end)

-- ---------------------------------------------------------------------------
--  Serratura, chiavi, deposito
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('casa:serratura', function(src, rispondi, idImmobile)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ?', { idImmobile })
    if not i or not haAccesso(i, g.citizenid) then return rispondi(false, 'Non hai le chiavi.') end

    local nuovo = i.serratura == 1 and 0 or 1
    MySQL.update.await('UPDATE immobili SET serratura = ? WHERE id = ?', { nuovo, idImmobile })
    rispondi(true, nuovo == 1 and 'Porta chiusa a chiave.' or 'Porta aperta.')
end)

AUREA.Callback.Registra('casa:cediChiavi', function(src, rispondi, idImmobile, bersaglioSrc)
    local g = AUREA.GetPlayer(src)
    local bersaglio = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not bersaglio then return rispondi(false, 'Persona non trovata.') end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ? AND proprietario = ?', { idImmobile, g.citizenid })
    if not i then return rispondi(false, 'Non sei il proprietario.') end

    local chiavi = chiaviDi(i)
    if U.Contiene(chiavi, bersaglio.citizenid) then
        for n, c in ipairs(chiavi) do
            if c == bersaglio.citizenid then table.remove(chiavi, n) break end
        end
        MySQL.update.await('UPDATE immobili SET chiavi = ? WHERE id = ?', { json.encode(chiavi), idImmobile })
        exports.aurea_inventory:Rimuovi(bersaglio.citizenid, 'chiavi_casa', 1)
        return rispondi(true, ('Chiavi ritirate a %s.'):format(bersaglio:NomeCompleto()))
    end

    if #chiavi >= CASA.Regole.chiaviMassime then
        return rispondi(false, ('Puoi cedere al massimo %d copie delle chiavi.'):format(CASA.Regole.chiaviMassime))
    end

    chiavi[#chiavi + 1] = bersaglio.citizenid
    MySQL.update.await('UPDATE immobili SET chiavi = ? WHERE id = ?', { json.encode(chiavi), idImmobile })
    TriggerEvent('aurea:inventario:aggiungi', bersaglio.citizenid, 'chiavi_casa', 1, {
        immobile = i.codice, indirizzo = i.indirizzo, tipo = i.tipo,
    })

    TriggerClientEvent('aurea:ui:notifica', bersaglio.source, {
        tipo = 'successo', icona = '🔑', durata = 9000,
        titolo = 'Chiavi ricevute',
        testo = ('%s ti ha dato le chiavi di %s.'):format(g:NomeCompleto(), i.nome),
    })
    rispondi(true, ('Chiavi consegnate a %s.'):format(bersaglio:NomeCompleto()))
end)

-- ---------------------------------------------------------------------------
--  Locazione
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('casa:affitta', function(src, rispondi, idImmobile, bersaglioSrc, canoneEuro)
    local g = AUREA.GetPlayer(src)
    local inquilino = AUREA.GetPlayer(tonumber(bersaglioSrc))
    if not g or not inquilino then return rispondi(false, 'Persona non trovata.') end

    local i = MySQL.single.await('SELECT * FROM immobili WHERE id = ? AND proprietario = ?', { idImmobile, g.citizenid })
    if not i then return rispondi(false, 'Non sei il proprietario.') end
    if i.inquilino then return rispondi(false, 'L\'immobile è già locato.') end

    local canone = U.ACentesimi(tonumber(tostring(canoneEuro):gsub(',', '.')) or 0)
    if canone <= 0 then return rispondi(false, 'Canone non valido.') end

    MySQL.update.await('UPDATE immobili SET inquilino = ?, affitto = ? WHERE id = ?', { inquilino.citizenid, canone, idImmobile })
    TriggerEvent('aurea:inventario:aggiungi', inquilino.citizenid, 'chiavi_casa', 1, {
        immobile = i.codice, indirizzo = i.indirizzo, tipo = i.tipo,
    })

    TriggerClientEvent('aurea:ui:notifica', inquilino.source, {
        tipo = 'successo', icona = '🏠', durata = 12000,
        titolo = 'Contratto di locazione',
        testo = ('%s ti ha locato %s per %s a canone.'):format(g:NomeCompleto(), i.nome, U.Euro(canone)),
    })
    rispondi(true, ('Contratto registrato con %s.'):format(inquilino:NomeCompleto()))
end)

-- Riscossione dei canoni
CreateThread(function()
    Wait(150000)
    while true do
        Wait(CASA.Regole.minutiCanone * 60000)

        local locati = MySQL.query.await(
            'SELECT id, nome, proprietario, inquilino, affitto FROM immobili WHERE inquilino IS NOT NULL AND affitto > 0') or {}

        for _, i in ipairs(locati) do
            local pagato = AUREA.Denaro.SottraiOffline(i.inquilino, 'banca', i.affitto, ('canone %s'):format(i.nome))

            if pagato then
                AUREA.Denaro.AggiungiOffline(i.proprietario, 'banca', i.affitto, ('canone di locazione %s'):format(i.nome))
                local g = AUREA.GetPlayerByCitizenId(i.inquilino)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'info', icona = '🏠', durata = 7000,
                        titolo = 'Canone addebitato', testo = ('%s per %s.'):format(U.Euro(i.affitto), i.nome),
                    })
                end
            else
                exports.ita_fisco:IscriviTributo(i.inquilino, 'canone', i.nome, i.affitto, 10)
                local g = AUREA.GetPlayerByCitizenId(i.inquilino)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'errore', icona = '⚠', durata = 12000,
                        titolo = 'Canone non pagato',
                        testo = ('Morosità su %s. Dopo %d mensilità scatta lo sfratto.'):format(i.nome, CASA.Regole.mensilitaSfratto),
                    })
                end

                -- Sfratto dopo le mensilità previste
                local morosita = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM tributi WHERE citizenid = ? AND tipo = \'canone\' AND periodo = ? AND stato != \'pagato\'',
                    { i.inquilino, i.nome }) or 0

                if morosita >= CASA.Regole.mensilitaSfratto then
                    MySQL.update.await('UPDATE immobili SET inquilino = NULL, affitto = 0 WHERE id = ?', { i.id })
                    exports.aurea_inventory:Rimuovi(i.inquilino, 'chiavi_casa', 1)
                    if g then
                        TriggerClientEvent('aurea:ui:notifica', g.source, {
                            tipo = 'errore', icona = '📤', durata = 14000,
                            titolo = 'Sfratto eseguito',
                            testo = ('Hai perso il diritto di abitare %s.'):format(i.nome),
                        })
                    end
                end
            end
        end
    end
end)

--- Riavvio della risorsa client mentre si è dentro: si torna al mondo comune.
RegisterNetEvent('casa:uscitaForzata', function()
    local src = source
    if dentro[src] then
        dentro[src] = nil
        SetPlayerRoutingBucket(src, 0)
    end
end)

AddEventHandler('playerDropped', function()
    dentro[source] = nil
end)

AddEventHandler('aurea:giocatore:scaricato', function(src)
    if dentro[src] then SetPlayerRoutingBucket(src, 0) end
    dentro[src] = nil
end)
