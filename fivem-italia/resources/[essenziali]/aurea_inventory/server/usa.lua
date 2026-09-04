--[[
    AUREA · Uso degli oggetti

    Gli effetti sono registrati qui e non nel catalogo, così ogni modulo può
    aggiungere il proprio comportamento con Usa.Registra().
]]

Usa = { handler = {} }

local U = AUREA.Util

--- Registra il comportamento all'uso di un oggetto.
---@param nome string
---@param fn fun(giocatore:table, riga:table):boolean  true = consuma una unità
function Usa.Registra(nome, fn)
    Usa.handler[nome] = fn
end

exports('RegistraUso', Usa.Registra)

AUREA.Callback.Registra('inv:usa', function(src, rispondi, slot)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local inv = exports.aurea_inventory:Inventario(g.citizenid)
    local riga = inv:GetSlot(slot)
    if not riga then return rispondi(false, 'Slot vuoto.') end

    local dati = AUREA.Item[riga.nome]
    if not dati or not dati.usabile then return rispondi(false, 'Questo oggetto non si usa.') end

    -- Effetti su fame, sete, stress e alcolemia
    if dati.effetto then
        for chiave, valore in pairs(dati.effetto) do
            if chiave == 'alcol' then
                -- l'alcolemia sale in g/l: 12 punti di effetto = 0,12 g/l
                g.stato.alcol = math.min(4.0, (g.stato.alcol or 0) + valore / 100)
            elseif chiave == 'energia' then
                g.stato.energia = U.Clamp((g.stato.energia or 100) + valore, 0, 100)
            else
                g:VariaStato(chiave, valore)
            end
        end
        TriggerClientEvent('aurea:stato:aggiorna', src, g.stato)
        TriggerClientEvent('aurea:stato:consuma', src,
            (dati.categoria == 'bevande' or dati.categoria == 'alcolici') and 'bevanda' or 'cibo')
    end

    -- Comportamento specifico
    local consuma = dati.effetto ~= nil
    local handler = Usa.handler[riga.nome]
    if handler then
        local ok, risultato = pcall(handler, g, riga)
        if not ok then
            print(('[AUREA] errore nell\'uso di %s: %s'):format(riga.nome, risultato))
            return rispondi(false, 'Errore nell\'uso dell\'oggetto.')
        end
        consuma = risultato == true
    end

    if consuma then
        inv:Rimuovi(riga.nome, 1, slot)
    end

    TriggerClientEvent('inv:aggiorna', src, inv:Pacchetto())
    rispondi(true)
end)

-- ---------------------------------------------------------------------------
--  Comportamenti di base
-- ---------------------------------------------------------------------------

--- Mostrare un documento a chi si ha davanti.
local function mostraDocumento(titolo, righeDa)
    return function(g, riga)
        local m = riga.metadata or {}
        local testo = righeDa(g, m)

        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'info', icona = '🪪', durata = 12000, titolo = titolo, testo = testo,
        })

        -- lo vede anche chi è vicino
        local origine = GetEntityCoords(GetPlayerPed(g.source))
        for _, altro in pairs(AUREA.Giocatori) do
            if altro.source ~= g.source
               and #(origine - GetEntityCoords(GetPlayerPed(altro.source))) < 3.0 then
                TriggerClientEvent('aurea:ui:notifica', altro.source, {
                    tipo = 'info', icona = '🪪', durata = 14000,
                    titolo = ('%s mostra: %s'):format(g:NomeCompleto(), titolo),
                    testo = testo,
                })
            end
        end
        return false
    end
end

--- Le date arrivano da oxmysql come millisecondi: qui tornano leggibili.
local function dataLeggibile(valore)
    if type(valore) == 'number' then return U.DataIT(math.floor(valore / 1000)) end
    local anno, mese, giorno = tostring(valore or ''):match('(%d%d%d%d)-(%d%d)-(%d%d)')
    if anno then return ('%s/%s/%s'):format(giorno, mese, anno) end
    return tostring(valore or 'n.d.')
end

Usa.Registra('carta_identita', mostraDocumento("Carta d'identità", function(g)
    return ('%s %s\n%s, nato/a il %s a %s\nCF %s\nCittadinanza: %s'):format(
        g.nome, g.cognome, g.sesso == 'F' and 'Femminile' or 'Maschile',
        dataLeggibile(g.dataNascita), g.luogoNascita, g.cf, g.nazionalita)
end))

Usa.Registra('tessera_sanitaria', mostraDocumento('Tessera sanitaria', function(g)
    return ('%s %s\nCodice fiscale: %s\nAssistito del Servizio Sanitario Nazionale'):format(g.nome, g.cognome, g.cf)
end))

Usa.Registra('patente', mostraDocumento('Patente di guida', function(g, m)
    return ('%s\nIntestatario: %s\nCategorie: %s'):format(
        m.numero or 'n.d.', m.intestatario or g:NomeCompleto(), m.categorie or 'n.d.')
end))

Usa.Registra('libretto', mostraDocumento('Libretto di circolazione', function(_, m)
    return ('Targa %s\n%s\n%s kW · %s'):format(
        m.targa or 'n.d.', m.modello or 'n.d.', m.kw or '?', m.classe or 'n.d.')
end))

Usa.Registra('assicurazione', mostraDocumento('Certificato assicurativo', function(_, m)
    return ('Targa %s\n%s\nValido fino al %s · classe %s'):format(
        m.targa or 'n.d.', m.tipo or 'RC Auto', m.scadenza or 'n.d.', m.classe or '?')
end))

Usa.Registra('visura', mostraDocumento('Visura camerale', function(_, m)
    return ('%s\nP.IVA %s · %s\n%s · %s'):format(
        m.ragione or 'n.d.', m.piva or 'n.d.', m.forma or '', m.settore or '', m.regime or '')
end))

Usa.Registra('tesserino', mostraDocumento('Tesserino di servizio', function(g, m)
    return ('%s\n%s\nMatricola %s'):format(
        g:NomeCompleto(), m.corpo or AUREA.EtichettaLavoro(g.lavoro.nome, g.lavoro.grado), m.matricola or 'n.d.')
end))

--- Il telefono apre l'applicazione.
Usa.Registra('telefono', function(g)
    TriggerClientEvent('tel:apri', g.source)
    return false
end)

--- Il gratta e vinci.
Usa.Registra('biglietto_lotteria', function(g)
    local sorte = math.random(1000)
    local vincita = 0
    if sorte <= 2 then vincita = 5000000        -- 1 su 500: 50.000 €
    elseif sorte <= 20 then vincita = 200000    -- 2.000 €
    elseif sorte <= 90 then vincita = 25000     -- 250 €
    elseif sorte <= 260 then vincita = 5000     -- 50 €
    end

    if vincita > 0 then
        g:Aggiungi('contanti', vincita, 'vincita gratta e vinci')
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'successo', icona = '🎟', durata = 10000,
            titolo = 'Hai vinto!', testo = ('%s in contanti.'):format(U.Euro(vincita)),
        })
        AUREA.Log('denaro', 'info', g, ('vincita gratta e vinci di %s'):format(U.Euro(vincita)))
    else
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'info', icona = '🎟', titolo = 'Non hai vinto', testo = 'Ritenta, sarai più fortunato.',
        })
    end
    return true
end)

--- Bendaggio: ferma l'emorragia e restituisce un po' di salute.
Usa.Registra('bendaggio', function(g)
    TriggerClientEvent('med:bendaggio', g.source)
    return true
end)

Usa.Registra('kit_medico', function(g)
    TriggerClientEvent('med:kitMedico', g.source)
    return true
end)

Usa.Registra('antidolorifico', function(g)
    g:VariaStato('stress', -25)
    TriggerClientEvent('med:antidolorifico', g.source)
    return true
end)

--- La tanica rifornisce il veicolo più vicino.
Usa.Registra('tanica', function(g)
    TriggerClientEvent('vei:usaTanica', g.source)
    return false   -- il client conferma il consumo tramite evento dedicato
end)

Usa.Registra('kit_riparazione', function(g)
    TriggerClientEvent('vei:usaKitRiparazione', g.source)
    return false
end)

--- Le manette immobilizzano la persona davanti.
Usa.Registra('manette', function(g)
    if not g:HaPermessoLavoro('fermo') then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', titolo = 'Non autorizzato', testo = 'Solo il personale in servizio può usare le manette.',
        })
        return false
    end

    local origine = GetEntityCoords(GetPlayerPed(g.source))
    for _, altro in pairs(AUREA.Giocatori) do
        if altro.source ~= g.source
           and #(origine - GetEntityCoords(GetPlayerPed(altro.source))) < 2.2 then
            TriggerClientEvent('giu:ammanetta', altro.source, g:NomeCompleto())
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'successo', icona = '⛓', titolo = 'Fermo eseguito',
                testo = ('%s è stato ammanettato.'):format(altro:NomeCompleto()),
            })
            AUREA.Log('giustizia', 'info', g, ('ha ammanettato %s'):format(altro.citizenid))
            return false
        end
    end

    TriggerClientEvent('aurea:ui:notifica', g.source, {
        tipo = 'errore', titolo = 'Nessuno vicino', testo = 'Avvicinati alla persona.',
    })
    return false
end)

--- Radio di servizio.
Usa.Registra('radio', function(g)
    TriggerClientEvent('aurea:ui:notifica', g.source, {
        tipo = 'info', icona = '📻', titolo = 'Radio accesa',
        testo = 'Canale di servizio attivo. Usa la chat vocale del server.',
    })
    return false
end)

--- Contenitori portatili: aprono un inventario secondario.
for nome, dati in pairs(AUREA.Item) do
    if dati.contenitore then
        Usa.Registra(nome, function(g, riga)
            TriggerClientEvent('inv:apriContenitore', g.source, riga.slot)
            return false
        end)
    end
end
