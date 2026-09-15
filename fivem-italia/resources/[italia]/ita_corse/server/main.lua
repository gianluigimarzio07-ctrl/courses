--[[
    AUREA · Corse clandestine (server)

    I checkpoint li valida il server. Il client dice "sono passato" e il
    server guarda dov'è davvero il veicolo: se non è lì, non è passato.
    E controlla l'ordine — il quarto non si prende senza il terzo.

    Il montepremi non esiste come numero astratto: sono le quote versate,
    tenute qui finché la gara non finisce. Se la gara salta, tornano
    indietro tutte.
]]

local U = AUREA.Util

local gara = nil        -- una sola per volta: una città non ne regge due
local ultimaChiusa = 0

-- Dichiarata qui perché la chiama il checkpoint, che sta sopra alla sua
-- definizione: meglio una forward che una globale che gira per la risorsa.
local componiClassifica

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
local function targaDi(src)
    local v = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if v == 0 then return nil end
    return (GetVehicleNumberPlateText(v) or ''):gsub('%s+$', ''), v
end

local function pubblica()
    if not gara then return TriggerClientEvent('cor:gara', -1, nil) end

    local classifica = {}
    for _, p in ipairs(gara.ordine) do
        local c = gara.corridori[p]
        classifica[#classifica + 1] = {
            nome = c.nome, checkpoint = c.checkpoint, giro = c.giro,
            arrivato = c.arrivato, ritirato = c.ritirato,
        }
    end

    TriggerClientEvent('cor:gara', -1, {
        tracciato = gara.tracciato, stato = gara.stato,
        quota = gara.quota, partenza = gara.partenza,
        iscritti = #gara.ordine, classifica = classifica,
    })
end

local function rimborsa(motivo)
    for citizenid in pairs(gara.corridori) do
        AUREA.Denaro.AggiungiOffline(citizenid, 'contanti', gara.quota, 'quota di gara restituita')
    end
    AUREA.Denaro.AggiungiOffline(gara.organizzatore, 'contanti', gara.quota, 'quota di gara restituita')

    local o = AUREA.GetPlayerByCitizenId(gara.organizzatore)
    if o then
        TriggerClientEvent('aurea:ui:notifica', o.source, {
            tipo = 'errore', icona = '🏁', titolo = 'Gara annullata',
            testo = motivo, durata = 14000 })
    end
end

local function chiudiGara(motivo, rimborsando)
    if not gara then return end
    if rimborsando then rimborsa(motivo) end

    MySQL.update('UPDATE corse_gare SET chiusa_il = NOW(), esito = ? WHERE id = ?',
        { rimborsando and 'annullata' or 'conclusa', gara.id })

    gara = nil
    ultimaChiusa = os.time()
    TriggerClientEvent('cor:gara', -1, nil)
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cor:apri', function(src, rispondi, tracciatoId, quotaEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if gara then return rispondi(false, 'C\'è già una gara in piedi.') end
    if os.time() - ultimaChiusa < COR.Gara.raffreddamentoMinuti * 60 then
        return rispondi(false, ('Si è appena corso. Aspetta %d minuti.')
            :format(math.ceil((COR.Gara.raffreddamentoMinuti * 60 - (os.time() - ultimaChiusa)) / 60)))
    end

    local t = COR.GetTracciato(tracciatoId)
    if not t then return rispondi(false, 'Tracciato sconosciuto.') end

    local targa, veicolo = targaDi(src)
    if not targa then return rispondi(false, 'Devi essere al volante.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - t.checkpoint[1]) > 60.0 then
        return rispondi(false, 'Devi essere in griglia, sul primo checkpoint.')
    end

    local quota = U.ACentesimi(tonumber(tostring(quotaEuro):gsub(',', '.')) or 0)
    if quota < COR.Gara.quotaMinima or quota > COR.Gara.quotaMassima then
        return rispondi(false, ('La quota sta fra %s e %s.')
            :format(U.Euro(COR.Gara.quotaMinima), U.Euro(COR.Gara.quotaMassima)))
    end

    if not g:Sottrai('contanti', quota, 'quota di gara') then
        return rispondi(false, ('Serve la tua quota: %s in contanti.'):format(U.Euro(quota)))
    end

    local id = MySQL.insert.await(
        'INSERT INTO corse_gare (tracciato, organizzatore, quota) VALUES (?, ?, ?)',
        { tracciatoId, g.citizenid, quota })

    gara = {
        id = id, tracciato = tracciatoId, organizzatore = g.citizenid,
        quota = quota, stato = 'iscrizioni',
        chiusuraIscrizioni = os.time() + COR.Gara.iscrizioniSecondi,
        corridori = {}, ordine = {}, arrivati = 0,
    }

    gara.corridori[g.citizenid] = {
        nome = g:NomeCompleto(), targa = targa, veicolo = veicolo,
        checkpoint = 0, giro = 1, source = src,
    }
    gara.ordine[1] = g.citizenid

    pubblica()
    AUREA.Log('giustizia', 'info', g, ('ha aperto una corsa su %s'):format(t.nome))

    rispondi(true, ('Gara aperta su %s.\nQuota %s, iscrizioni aperte per %d secondi.\n%d giri, %d checkpoint.')
        :format(t.nome, U.Euro(quota), COR.Gara.iscrizioniSecondi, t.giri, #t.checkpoint))
end)

AUREA.Callback.Registra('cor:iscriviti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if not gara or gara.stato ~= 'iscrizioni' then return rispondi(false, 'Nessuna gara aperta alle iscrizioni.') end
    if gara.corridori[g.citizenid] then return rispondi(false, 'Sei già iscritto.') end
    if #gara.ordine >= COR.Gara.massimi then return rispondi(false, 'Griglia piena.') end

    local t = COR.GetTracciato(gara.tracciato)
    local targa, veicolo = targaDi(src)
    if not targa then return rispondi(false, 'Devi essere al volante.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - t.checkpoint[1]) > 60.0 then
        return rispondi(false, 'La griglia è al primo checkpoint.')
    end

    if not g:Sottrai('contanti', gara.quota, 'quota di gara') then
        return rispondi(false, ('Servono %s in contanti.'):format(U.Euro(gara.quota)))
    end

    gara.corridori[g.citizenid] = {
        nome = g:NomeCompleto(), targa = targa, veicolo = veicolo,
        checkpoint = 0, giro = 1, source = src,
    }
    gara.ordine[#gara.ordine + 1] = g.citizenid

    pubblica()
    rispondi(true, ('Iscritto. In griglia siete %d.'):format(#gara.ordine))
end)

-- ---------------------------------------------------------------------------
--  Checkpoint
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('cor:checkpoint', function(src, rispondi, indice)
    local g = AUREA.GetPlayer(src)
    if not g or not gara or gara.stato ~= 'corsa' then return rispondi(false) end

    local c = gara.corridori[g.citizenid]
    if not c or c.arrivato or c.ritirato then return rispondi(false) end

    local t = COR.GetTracciato(gara.tracciato)
    local atteso = (c.checkpoint % #t.checkpoint) + 1
    if tonumber(indice) ~= atteso then return rispondi(false) end

    -- La posizione la legge il server dall'entità di rete, non dal client
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - t.checkpoint[atteso]) > COR.RaggioCheckpoint + 8.0 then
        return rispondi(false)
    end
    if GetVehiclePedIsIn(ped, false) == 0 then return rispondi(false) end

    c.checkpoint = c.checkpoint + 1

    if c.checkpoint % #t.checkpoint == 0 then
        c.giro = c.giro + 1
        if c.giro > t.giri then
            c.arrivato = true
            gara.arrivati = gara.arrivati + 1
            c.posizione = gara.arrivati

            pubblica()
            if gara.arrivati >= math.min(#gara.ordine, #COR.Podio) or gara.arrivati == #gara.ordine then
                CreateThread(function() Wait(1500) componiClassifica() end)
            end
            return rispondi(true, { arrivato = true, posizione = gara.arrivati })
        end
    end

    pubblica()
    rispondi(true, { checkpoint = c.checkpoint, giro = c.giro })
end)

-- ---------------------------------------------------------------------------
--  Chiusura e premi
-- ---------------------------------------------------------------------------
function componiClassifica()
    if not gara or gara.stato ~= 'corsa' then return end
    gara.stato = 'conclusa'

    local podio = {}
    for _, citizenid in ipairs(gara.ordine) do
        local c = gara.corridori[citizenid]
        if c.arrivato then podio[c.posizione] = citizenid end
    end

    local netto, allOrganizzatore = COR.Montepremi(gara.quota, #gara.ordine)
    AUREA.Denaro.AggiungiOffline(gara.organizzatore, 'contanti', allOrganizzatore, 'organizzazione della corsa')

    local righe = {}
    for posizione, quotaPodio in ipairs(COR.Podio) do
        local citizenid = podio[posizione]
        if citizenid then
            local premio = math.floor(netto * quotaPodio)
            AUREA.Denaro.AggiungiOffline(citizenid, 'contanti', premio, 'premio di gara')
            righe[#righe + 1] = ('%d° %s — %s'):format(posizione, gara.corridori[citizenid].nome, U.Euro(premio))

            local p = AUREA.GetPlayerByCitizenId(citizenid)
            if p then
                TriggerClientEvent('aurea:ui:notifica', p.source, {
                    tipo = 'successo', icona = '🏁', durata = 20000,
                    titolo = ('%d° posto'):format(posizione),
                    testo = ('%s in contanti.'):format(U.Euro(premio)),
                })
            end
        end
    end

    MySQL.update('UPDATE corse_gare SET partecipanti = ?, montepremi = ? WHERE id = ?',
        { #gara.ordine, netto, gara.id })

    for citizenid in pairs(gara.corridori) do
        local p = AUREA.GetPlayerByCitizenId(citizenid)
        if p then
            TriggerClientEvent('aurea:ui:notifica', p.source, {
                tipo = 'info', icona = '🏁', durata = 20000,
                titolo = 'Ordine d\'arrivo',
                testo = #righe > 0 and table.concat(righe, '\n') or 'Nessuno ha completato il percorso.',
            })
        end
    end

    AUREA.Log('giustizia', 'info', nil,
        ('Corsa su %s conclusa: %d partecipanti, montepremi %s'):format(gara.tracciato, #gara.ordine, U.Euro(netto)))

    chiudiGara(nil, false)
end

-- ---------------------------------------------------------------------------
--  Il cronometro della gara
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        if gara then
            if gara.stato == 'iscrizioni' and os.time() >= gara.chiusuraIscrizioni then
                if #gara.ordine < COR.Gara.minimi then
                    chiudiGara(('Non si è iscritto nessuno: servivano almeno %d.'):format(COR.Gara.minimi), true)
                else
                    gara.stato = 'corsa'
                    gara.partenza = os.time()
                    gara.limite = os.time() + COR.Gara.limiteMinuti * 60
                    pubblica()

                    for citizenid in pairs(gara.corridori) do
                        local p = AUREA.GetPlayerByCitizenId(citizenid)
                        if p then
                            TriggerClientEvent('aurea:ui:notifica', p.source, {
                                tipo = 'successo', icona = '🏁', durata = 8000,
                                titolo = 'VIA', testo = 'Il primo checkpoint è segnato sulla mappa.',
                            })
                        end
                    end
                    AUREA.Log('giustizia', 'avviso', nil,
                        ('Corsa partita su %s con %d veicoli'):format(gara.tracciato, #gara.ordine))
                end

            elseif gara.stato == 'corsa' then
                if os.time() >= gara.limite then
                    componiClassifica()

                elseif not gara.segnalata and os.time() - gara.partenza >= COR.Rischio.secondiSegnalazione then
                    gara.segnalata = true
                    local t = COR.GetTracciato(gara.tracciato)
                    local c = t.checkpoint[math.random(#t.checkpoint)]

                    TriggerEvent('aurea:112:allerta', 'sospetto',
                        { x = c.x, y = c.y, z = c.z },
                        ('Più veicoli a velocità sostenuta in %s: si sospetta una competizione non autorizzata.')
                            :format(t.zona), t.zona)

                    exports.aurea_ui:NotificaEnte('polizia', {
                        tipo = 'avviso', icona = '🏁', durata = 20000,
                        titolo = 'Competizione non autorizzata',
                        testo = ('Segnalazione da %s. Chi ferma un partecipante usa /contestacorsa.'):format(t.zona),
                    }, true)
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  La contestazione
--
--  Art. 9-ter CdS: sanzione, dieci punti, sospensione e confisca del
--  veicolo. È l'unica parte in cui il modulo fa male sul serio.
-- ---------------------------------------------------------------------------
AUREA.Comando('contestacorsa', 'utente', 'Contesta la partecipazione a una competizione non autorizzata', {
    { name = 'id', help = 'ID del conducente fermato' },
}, function(src, args, _, g)
    if not g or not AUREA.EForzaOrdine(g.lavoro.nome) or not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⛔', titolo = 'Non autorizzato',
            testo = 'Serve essere in servizio.' })
    end

    local b = AUREA.GetPlayer(tonumber(args[1]))
    if not b then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🏁', titolo = 'Nessuno', testo = 'ID non trovato.' })
    end

    if not gara or not gara.corridori[b.citizenid] then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🏁', titolo = 'Niente da contestare',
            testo = 'Quel conducente non risulta in gara.' })
    end

    local c = gara.corridori[b.citizenid]
    c.ritirato = true
    local t = COR.GetTracciato(gara.tracciato)

    exports.ita_codicestrada:EmettiVerbale({
        citizenid = b.citizenid, targa = c.targa,
        articolo = COR.Rischio.articolo,
        descrizione = 'Partecipazione a competizione di velocità non autorizzata',
        importo = COR.Rischio.sanzione, punti = COR.Rischio.puntiPatente,
        origine = 'agente', agente = g:NomeCompleto(), luogo = t.zona,
    })

    exports.ita_codicestrada:PatenteSospendi(b.citizenid,
        math.ceil(COR.Rischio.sospensionePatenteMinuti / 1440), 'competizione non autorizzata')

    if COR.Rischio.confiscaVeicolo and c.targa then
        MySQL.update('UPDATE veicoli SET stato = ? WHERE targa = ?', { 'sequestrato', c.targa })
        TriggerClientEvent('aurea:ui:notifica', b.source, {
            tipo = 'errore', icona = '🚗', durata = 24000,
            titolo = 'Veicolo confiscato',
            testo = ('%s: confisca ex art. 9-ter CdS. Non è un sequestro, non torna indietro.'):format(c.targa),
        })
    end

    pubblica()
    AUREA.Log('giustizia', 'avviso', g,
        ('ha contestato l\'art. 9-ter a %s (%s)'):format(b:NomeCompleto(), c.targa or '—'))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🏁', durata = 20000,
        titolo = 'Contestazione elevata',
        testo = ('%s — %s\nSanzione %s · %d punti · patente sospesa%s')
            :format(b:NomeCompleto(), COR.Rischio.articolo, U.Euro(COR.Rischio.sanzione),
                    COR.Rischio.puntiPatente,
                    COR.Rischio.confiscaVeicolo and ('\nVeicolo %s confiscato.'):format(c.targa or '—') or ''),
    })
end)

AddEventHandler('aurea:giocatore:caricato', function(src)
    CreateThread(function() Wait(5000) if gara then pubblica() end end)
end)

print('[AUREA] corse clandestine: tracciati pronti')
