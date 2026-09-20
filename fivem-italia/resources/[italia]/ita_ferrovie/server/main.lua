--[[
    AUREA · Ferrovie (server)

    L'orario è la cosa che il server tiene e il client non può toccare.
    Una corsa parte a un istante deciso qui, le fermate hanno un'ora
    prevista, e il ritardo si misura confrontando quando sei arrivato con
    quando dovevi arrivare.

    Non si può barare sul ritardo perché non è il client a dire "sono
    arrivato": è il server a guardare dov'è il macchinista quando lui
    dichiara la fermata.
]]

local U = AUREA.Util

local corse = {}        -- [id] = { linea, macchinista, fermataCorrente, orari, ... }
local contatore = 0
local obliterati = {}   -- [citizenid] = scadenza del biglietto
local sbarre = {}       -- [plId] = os.time() fino a cui è chiuso

-- ---------------------------------------------------------------------------
--  Chi lavora in ferrovia
-- ---------------------------------------------------------------------------
local function ferroviere(g, permesso)
    if not g or g.lavoro.nome ~= FER.Lavoro or not g.lavoro.servizio then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return true
end

-- ---------------------------------------------------------------------------
--  Corse
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fer:linee', function(src, rispondi)
    local fuori = {}
    for _, l in ipairs(FER.Linee) do
        local occupata = false
        for _, c in pairs(corse) do
            if c.linea == l.id then occupata = true end
        end

        local nomi = {}
        for _, f in ipairs(l.fermate) do
            nomi[#nomi + 1] = FER.GetStazione(f).nome
        end

        fuori[#fuori + 1] = {
            id = l.id, nome = l.nome, fermate = nomi,
            prezzo = l.prezzo, compenso = l.compensoMacchinista,
            minuti = l.minutiFraFermate * (#l.fermate - 1),
            occupata = occupata,
        }
    end
    rispondi(fuori)
end)

AUREA.Callback.Registra('fer:parti', function(src, rispondi, lineaId)
    local g = AUREA.GetPlayer(src)
    if not ferroviere(g, 'macchinista') then
        return rispondi(false, 'Alla guida ci va un macchinista in servizio.')
    end

    local l = FER.GetLinea(lineaId)
    if not l then return rispondi(false, 'Linea sconosciuta.') end

    for _, c in pairs(corse) do
        if c.macchinista == g.citizenid then return rispondi(false, 'Hai già una corsa in servizio.') end
        if c.linea == lineaId then return rispondi(false, 'Su quella linea c\'è già un convoglio.') end
    end

    local partenza = FER.GetStazione(l.fermate[1])
    if #(GetEntityCoords(GetPlayerPed(src)) - partenza.coord) > 60.0 then
        return rispondi(false, ('Il convoglio parte da %s.'):format(partenza.nome))
    end

    -- L'orario: ogni fermata ha un istante previsto, e da lì si misura
    local adesso = os.time()
    local orari = {}
    for i = 1, #l.fermate do
        orari[i] = adesso + (i - 1) * l.minutiFraFermate * 60
    end

    contatore = contatore + 1
    corse[contatore] = {
        id = contatore, linea = lineaId, macchinista = g.citizenid,
        nomeMacchinista = g:NomeCompleto(),
        fermataCorrente = 1, orari = orari, ritardoTotale = 0,
        passeggeri = {}, partita = adesso,
    }

    MySQL.insert('INSERT INTO ferrovie_corse (linea, macchinista) VALUES (?, ?)',
        { lineaId, g.citizenid })

    local elenco = {}
    for i, f in ipairs(l.fermate) do
        local s = FER.GetStazione(f)
        elenco[i] = { id = f, nome = s.nome,
            x = s.banchina.x, y = s.banchina.y, z = s.banchina.z,
            previsto = orari[i] }
    end

    TriggerClientEvent('fer:corsa', -1, {
        id = contatore, linea = lineaId, nome = l.nome,
        fermate = elenco, corrente = 1,
        macchinista = g:NomeCompleto(),
    })

    rispondi(true, ('%s in servizio.\n%d fermate, %d minuti fra l\'una e l\'altra.\nL\'orario corre da adesso: il ritardo si paga.')
        :format(l.nome, #l.fermate, l.minutiFraFermate))
end)

AUREA.Callback.Registra('fer:fermata', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local c
    for _, x in pairs(corse) do
        if x.macchinista == g.citizenid then c = x end
    end
    if not c then return rispondi(false, 'Non sei in servizio su nessuna corsa.') end

    local l = FER.GetLinea(c.linea)
    local prossima = c.fermataCorrente + 1
    if prossima > #l.fermate then return rispondi(false, 'La corsa è finita.') end

    local s = FER.GetStazione(l.fermate[prossima])
    if #(GetEntityCoords(GetPlayerPed(src)) - s.banchina) > FER.Orario.raggioFermata then
        return rispondi(false, ('Non sei a %s.'):format(s.nome))
    end

    local ritardo = math.max(0, os.time() - c.orari[prossima] - FER.Orario.tolleranzaSecondi)
    c.ritardoTotale = c.ritardoTotale + ritardo
    c.fermataCorrente = prossima

    TriggerClientEvent('fer:corsa', -1, {
        id = c.id, linea = c.linea, corrente = prossima, aggiornamento = true,
    })

    if prossima < #l.fermate then
        return rispondi(true, ('%s.%s\nProssima: %s.')
            :format(s.nome,
                    ritardo > 0 and (' In ritardo di %d minuti.'):format(math.ceil(ritardo / 60)) or ' In orario.',
                    FER.GetStazione(l.fermate[prossima + 1]).nome))
    end

    -- Capolinea
    local minutiRitardo = math.ceil(c.ritardoTotale / 60)
    local compenso = l.compensoMacchinista
    if minutiRitardo > 0 then
        compenso = math.floor(compenso * math.max(0.3, 1 - minutiRitardo * FER.Orario.penalePerMinuto))
    else
        compenso = math.floor(compenso * (1 + FER.Orario.premioPuntualita))
    end

    g:Aggiungi('banca', compenso, ('corsa %s'):format(l.nome))
    pcall(function()
        exports.aurea_azienda:VersaInCassa(FER.Lavoro, math.floor(compenso * 0.2), 'quota azienda')
    end)

    MySQL.update('UPDATE ferrovie_corse SET ritardo_secondi = ?, compenso = ?, chiusa_il = NOW() WHERE macchinista = ? AND chiusa_il IS NULL ORDER BY id DESC LIMIT 1',
        { c.ritardoTotale, compenso, g.citizenid })

    corse[c.id] = nil
    TriggerClientEvent('fer:corsaChiusa', -1, c.id)

    rispondi(true, ('Capolinea a %s.\n%s\nCompenso %s.')
        :format(s.nome,
                minutiRitardo > 0 and ('Ritardo complessivo %d minuti: il compenso ne risente.'):format(minutiRitardo)
                    or 'Corsa puntuale: premio del 25%.',
                U.Euro(compenso)))
end)

-- ---------------------------------------------------------------------------
--  Biglietti
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fer:biglietto', function(src, rispondi, lineaId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local l = FER.GetLinea(lineaId)
    if not l then return rispondi(false, 'Linea sconosciuta.') end

    if not g:SottraiOvunque(l.prezzo, 'biglietto ferroviario') then
        return rispondi(false, ('Il biglietto costa %s.'):format(U.Euro(l.prezzo)))
    end

    pcall(function()
        exports.aurea_azienda:VersaInCassa(FER.Lavoro,
            math.floor(l.prezzo * FER.Biglietti.quotaAzienda), 'vendita biglietti')
    end)
    TriggerEvent('aurea:fisco:incasso', 'trasporti',
        l.prezzo - math.floor(l.prezzo * FER.Biglietti.quotaAzienda), g.citizenid)

    exports.aurea_inventory:Aggiungi(g.citizenid, FER.Biglietti.item, 1, { linea = lineaId })
    rispondi(true, ('Biglietto per %s. Ricordati di obliterarlo prima di salire.'):format(l.nome))
end)

AUREA.Callback.Registra('fer:obliteraBiglietto', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    if not exports.aurea_inventory:Ha(g.citizenid, FER.Biglietti.item, 1) then
        return rispondi(false, 'Non hai un biglietto.')
    end
    exports.aurea_inventory:Rimuovi(g.citizenid, FER.Biglietti.item, 1)

    obliterati[g.citizenid] = os.time() + FER.Biglietti.validitaMinuti * 60
    rispondi(true, ('Obliterato. Vale %d minuti.'):format(FER.Biglietti.validitaMinuti))
end)

AUREA.Comando('controllotreno', 'utente', 'Controlla i titoli di viaggio a bordo del convoglio', {
    { name = 'id', help = 'ID del passeggero' },
}, function(src, args, _, g)
    if not ferroviere(g, 'capotreno') then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚆', titolo = 'Non autorizzato',
            testo = 'Il controllo lo fa il capotreno in servizio.' })
    end

    local b = AUREA.GetPlayer(tonumber(args[1]))
    if not b then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '🚆', titolo = 'Nessuno', testo = 'ID non trovato.' })
    end

    local valido = obliterati[b.citizenid] and os.time() < obliterati[b.citizenid]
    if valido then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'successo', icona = '🎫', durata = 12000,
            titolo = 'Titolo regolare',
            testo = ('%s ha un biglietto valido per altri %d minuti.')
                :format(b:NomeCompleto(), math.ceil((obliterati[b.citizenid] - os.time()) / 60)) })
    end

    exports.ita_fisco:IscriviTributo(b.citizenid, 'sanzione',
        'viaggio senza titolo valido', FER.Biglietti.sanzione, 5)

    local capotreno = g
    capotreno:Aggiungi('banca', math.floor(FER.Biglietti.sanzione * 0.05), 'premio controllo')

    TriggerClientEvent('aurea:ui:notifica', b.source, {
        tipo = 'errore', icona = '🎫', durata = 16000,
        titolo = 'Sanzione amministrativa',
        testo = ('Viaggio senza titolo valido: %s.'):format(U.Euro(FER.Biglietti.sanzione)) })

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'avviso', icona = '🎫', durata = 14000,
        titolo = 'Sanzione elevata',
        testo = ('%s: nessun biglietto obliterato. %s.')
            :format(b:NomeCompleto(), U.Euro(FER.Biglietti.sanzione)) })
end)

-- ---------------------------------------------------------------------------
--  Passaggi a livello
--
--  Si chiudono quando un convoglio è vicino. Il server dice al client
--  quali sono chiusi; chi ci passa sotto lo segnala, e il server decide
--  se contestare.
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(3000)

        local chiusi = {}
        for _, c in pairs(corse) do
            local m = AUREA.GetPlayerByCitizenId(c.macchinista)
            if m then
                local coord = GetEntityCoords(GetPlayerPed(m.source))
                for _, pl in ipairs(FER.PassaggiLivello) do
                    if #(coord - pl.coord) <= 260.0 then
                        sbarre[pl.id] = os.time() + FER.Sbarre.codaSecondi
                    end
                end
            end
        end

        for _, pl in ipairs(FER.PassaggiLivello) do
            if sbarre[pl.id] and os.time() < sbarre[pl.id] then
                chiusi[#chiusi + 1] = pl.id
            end
        end

        TriggerClientEvent('fer:sbarre', -1, chiusi)
    end
end)

AUREA.Callback.Registra('fer:forzato', function(src, rispondi, plId)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    if not sbarre[plId] or os.time() >= sbarre[plId] then return rispondi(false) end

    local pl
    for _, x in ipairs(FER.PassaggiLivello) do
        if x.id == plId then pl = x end
    end
    if not pl then return rispondi(false) end

    -- La posizione la controlla il server: non basta dichiararlo
    if #(GetEntityCoords(GetPlayerPed(src)) - pl.coord) > FER.Sbarre.raggio + 10.0 then
        return rispondi(false)
    end

    local ped = GetPlayerPed(src)
    local v = GetVehiclePedIsIn(ped, false)
    if v == 0 then return rispondi(false) end

    local targa = (GetVehicleNumberPlateText(v) or ''):gsub('%s+$', '')

    local infrazione = AUREA.Infrazioni[FER.Sbarre.infrazione]
    exports.ita_codicestrada:EmettiVerbale({
        citizenid = g.citizenid, targa = targa,
        articolo = infrazione.articolo,
        descrizione = 'Attraversamento di passaggio a livello con barriere chiuse',
        importo = infrazione.importo, punti = infrazione.punti,
        origine = 'semaforo', agente = 'rilevamento automatico', luogo = pl.nome,
    })

    AUREA.Log('giustizia', 'avviso', g, ('ha forzato il %s'):format(pl.nome))
    rispondi(true)
end)

print('[AUREA] ferrovie: orario e passaggi a livello attivi')
