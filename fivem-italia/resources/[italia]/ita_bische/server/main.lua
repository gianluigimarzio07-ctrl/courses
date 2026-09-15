--[[
    AUREA · Bische clandestine (server)

    Le carte si estraggono qui. Un client modificato può disegnare quello
    che vuole sullo schermo: la mano che conta è quella che sta in questa
    tabella, e il giocatore ne conosce solo le proprie carte.

    Il banco non è del server: è il contante che l'organizzatore ha messo
    sul tavolo. Quando finisce, la serata finisce — ed è la cosa che
    rende una bisca una bisca e non una slot machine.
]]

local U = AUREA.Util

local bische = {}       -- [luogoId] = { organizzatore, banco, mani, aperta, ... }
local mani = {}         -- [citizenid] = { bisca, puntata, carte, chiusa }
local ultimaMano = {}   -- [citizenid] = os.time()
local raffreddate = {}  -- [luogoId] = os.time() fino a cui non si riapre

-- ---------------------------------------------------------------------------
--  Carte
-- ---------------------------------------------------------------------------
local function pesca()
    return {
        valore = math.random(#BIS.Carte),
        seme = BIS.Semi[math.random(#BIS.Semi)],
    }
end

local function descriviCarta(c)
    return ('%s di %s'):format(BIS.Carte[c.valore].nome, c.seme)
end

local function descriviMano(carte)
    local fuori = {}
    for _, c in ipairs(carte) do fuori[#fuori + 1] = descriviCarta(c) end
    return table.concat(fuori, ', ')
end

-- ---------------------------------------------------------------------------
--  Stato
-- ---------------------------------------------------------------------------
local function bischeAperte()
    local n = 0
    for _ in pairs(bische) do n = n + 1 end
    return n
end

local function bischaVicina(coord)
    for id, b in pairs(bische) do
        local l = BIS.GetLuogo(id)
        if l and #(coord - l.coord) <= 12.0 then return b, l end
    end
end

local function pubblica()
    -- Ai giocatori si dice solo dove c'è una bisca aperta, non quanto
    -- banco ha: quello lo sa l'organizzatore.
    local elenco = {}
    for id in pairs(bische) do elenco[#elenco + 1] = id end
    TriggerClientEvent('bis:aperte', -1, elenco)
end

-- ---------------------------------------------------------------------------
--  Chiusura
-- ---------------------------------------------------------------------------
local function chiudi(b, motivo, sequestrata)
    local l = BIS.GetLuogo(b.luogo)
    bische[b.luogo] = nil
    raffreddate[b.luogo] = os.time() + BIS.Apertura.raffreddamentoLuogo * 60

    -- Le mani ancora sul tavolo si annullano: la puntata torna a chi
    -- l'ha messa, anche quando arrivano i carabinieri. Quello che si
    -- sequestra è il banco, non la puntata di chi stava giocando.
    for citizenid, m in pairs(mani) do
        if m.bisca == b.luogo then
            mani[citizenid] = nil
            AUREA.Denaro.AggiungiOffline(citizenid, 'contanti', m.puntata, 'puntata annullata')
        end
    end

    local org = AUREA.GetPlayerByCitizenId(b.organizzatore)

    if not sequestrata and b.banco > 0 then
        AUREA.Denaro.AggiungiOffline(b.organizzatore, 'contanti', b.banco, 'chiusura del banco')
    end

    if org then
        TriggerClientEvent('aurea:ui:notifica', org.source, {
            tipo = sequestrata and 'errore' or 'info', icona = '🃏', durata = 18000,
            titolo = sequestrata and 'Bisca sequestrata' or 'Serata chiusa',
            testo = sequestrata
                and ('%s: il banco è stato sequestrato.'):format(l and l.nome or b.luogo)
                or ('%s. Banco finale %s su %s messi, %d mani giocate.')
                    :format(motivo or 'Serata conclusa', U.Euro(b.banco), U.Euro(b.bancoIniziale), b.mani),
        })
    end

    if b.mani > 0 then
        TriggerEvent('aurea:famiglie:calore', b.organizzatore, BIS.Rischio.calorePerSerata, 'bisca clandestina')
    end

    MySQL.update('UPDATE bische_serate SET chiusa_il = NOW(), banco_finale = ?, mani = ?, esito = ? WHERE id = ?',
        { b.banco, b.mani, sequestrata and 'sequestrata' or 'chiusa', b.id })

    pubblica()
    AUREA.Log('giustizia', 'info', nil,
        ('Bisca su %s chiusa (%d mani, %s)'):format(b.luogo, b.mani, sequestrata and 'sequestro' or 'spontanea'))
end

-- ---------------------------------------------------------------------------
--  Apertura
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bis:apri', function(src, rispondi, luogoId, bancoEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end

    local l = BIS.GetLuogo(luogoId)
    if not l then return rispondi(false, 'Posto non riconosciuto.') end
    if bische[luogoId] then return rispondi(false, 'Lì c\'è già una partita in corso.') end
    if bischeAperte() >= BIS.Apertura.contemporanee then
        return rispondi(false, 'Ci sono già troppe bische aperte in città. Aspetta che ne chiuda una.')
    end
    if raffreddate[luogoId] and os.time() < raffreddate[luogoId] then
        return rispondi(false, ('In quel posto si è appena giocato. Riprova fra %d minuti.')
            :format(math.ceil((raffreddate[luogoId] - os.time()) / 60)))
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - l.coord) > 8.0 then
        return rispondi(false, 'Devi essere sul posto.')
    end

    local banco = U.ACentesimi(tonumber(tostring(bancoEuro):gsub(',', '.')) or 0)
    if banco < BIS.Apertura.bancoMinimo or banco > BIS.Apertura.bancoMassimo then
        return rispondi(false, ('Il banco sta fra %s e %s.')
            :format(U.Euro(BIS.Apertura.bancoMinimo), U.Euro(BIS.Apertura.bancoMassimo)))
    end

    if not g:Sottrai('contanti', banco, 'banco della bisca') then
        return rispondi(false, ('Ti servono %s in contanti. Qui non si passa dalla banca.'):format(U.Euro(banco)))
    end

    local id = MySQL.insert.await(
        'INSERT INTO bische_serate (luogo, organizzatore, banco_iniziale) VALUES (?, ?, ?)',
        { luogoId, g.citizenid, banco })

    bische[luogoId] = {
        id = id, luogo = luogoId, organizzatore = g.citizenid,
        nomeOrganizzatore = g:NomeCompleto(),
        banco = banco, bancoIniziale = banco, mani = 0,
        aperta = os.time(), scade = os.time() + BIS.Apertura.durataMinuti * 60,
    }

    pubblica()
    AUREA.Log('giustizia', 'avviso', g, ('ha aperto una bisca su %s con %s di banco'):format(luogoId, U.Euro(banco)))

    rispondi(true, ('Bisca aperta a %s.\nBanco %s, la serata dura %d minuti.\nSe finisce il banco, finisce la serata.')
        :format(l.nome, U.Euro(banco), BIS.Apertura.durataMinuti))
end)

AUREA.Comando('chiudibisca', 'utente', 'Chiude la bisca che hai aperto', {},
function(src, _, _, g)
    if not g then return end
    for _, b in pairs(bische) do
        if b.organizzatore == g.citizenid then
            return chiudi(b, 'Chiusa dall\'organizzatore', false)
        end
    end
    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'info', icona = '🃏', titolo = 'Nessuna bisca', testo = 'Non ne hai aperta nessuna.' })
end)

-- ---------------------------------------------------------------------------
--  Il gioco
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bis:punta', function(src, rispondi, puntataEuro)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false, 'Sessione non valida.') end
    if mani[g.citizenid] then return rispondi(false, 'Hai una mano aperta: finisci quella.') end

    local adesso = os.time()
    if ultimaMano[g.citizenid] and adesso - ultimaMano[g.citizenid] < BIS.Tavolo.secondiFraMani then
        return rispondi(false, 'Aspetta il tuo turno.')
    end

    local b, l = bischaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not b then return rispondi(false, 'Non c\'è nessun tavolo qui.') end
    if b.organizzatore == g.citizenid then return rispondi(false, 'Il banco non gioca contro sé stesso.') end

    local puntata = U.ACentesimi(tonumber(tostring(puntataEuro):gsub(',', '.')) or 0)
    if puntata < BIS.Tavolo.puntataMinima or puntata > BIS.Tavolo.puntataMassima then
        return rispondi(false, ('La puntata sta fra %s e %s.')
            :format(U.Euro(BIS.Tavolo.puntataMinima), U.Euro(BIS.Tavolo.puntataMassima)))
    end

    -- Il banco deve poter pagare la vincita massima: sette e mezzo servito
    local esposizione = math.ceil(puntata * BIS.Regole.pagamentoSetteEMezzo)
    if b.banco < esposizione then
        return rispondi(false, ('Il banco non copre questa puntata. Massimo %s.')
            :format(U.Euro(math.floor(b.banco / BIS.Regole.pagamentoSetteEMezzo))))
    end

    if not g:Sottrai('contanti', puntata, 'puntata alla bisca') then
        return rispondi(false, 'Non hai quei contanti.')
    end

    local carta = pesca()
    mani[g.citizenid] = { bisca = b.luogo, puntata = puntata, carte = { carta } }
    ultimaMano[g.citizenid] = adesso

    local punti = BIS.Punteggio({ carta })
    rispondi(true, {
        carte = { descriviCarta(carta) },
        punti = punti,
        messaggio = ('Hai %s. Punti: %.1f.'):format(descriviCarta(carta), punti),
    })
end)

AUREA.Callback.Registra('bis:carta', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local m = g and mani[g.citizenid]
    if not m then return rispondi(false, 'Nessuna mano aperta.') end

    local carta = pesca()
    m.carte[#m.carte + 1] = carta
    local punti = BIS.Punteggio(m.carte)

    if BIS.Sballato(punti) then
        local b = bische[m.bisca]
        mani[g.citizenid] = nil
        if b then
            b.banco = b.banco + m.puntata
            b.mani = b.mani + 1
        end
        return rispondi(true, {
            carte = { descriviCarta(carta) }, punti = punti, finita = true, vinto = false,
            messaggio = ('%s. Sei a %.1f: sballato. Il banco prende %s.')
                :format(descriviCarta(carta), punti, U.Euro(m.puntata)),
        })
    end

    rispondi(true, {
        carte = { descriviCarta(carta) }, punti = punti,
        messaggio = ('%s. Punti: %.1f.'):format(descriviCarta(carta), punti),
    })
end)

AUREA.Callback.Registra('bis:sto', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local m = g and mani[g.citizenid]
    if not m then return rispondi(false, 'Nessuna mano aperta.') end

    local b = bische[m.bisca]
    if not b then
        mani[g.citizenid] = nil
        g:Aggiungi('contanti', m.puntata, 'puntata restituita')
        return rispondi(false, 'La bisca ha chiuso: la puntata torna indietro.')
    end

    local miei = BIS.Punteggio(m.carte)
    local settemezzoServito = miei == BIS.Regole.limite and #m.carte == 2

    -- Il banco tira, con le stesse regole, e si ferma alla soglia
    local carteBanco = { pesca() }
    while BIS.Punteggio(carteBanco) < BIS.Regole.bancoSiFermaA do
        carteBanco[#carteBanco + 1] = pesca()
    end
    local puntiBanco = BIS.Punteggio(carteBanco)

    mani[g.citizenid] = nil
    b.mani = b.mani + 1

    local esito, vincita
    if BIS.Sballato(puntiBanco) then
        esito, vincita = 'vinta', m.puntata * 2
    elseif miei > puntiBanco then
        esito = 'vinta'
        vincita = settemezzoServito
            and math.floor(m.puntata * (1 + BIS.Regole.pagamentoSetteEMezzo))
            or m.puntata * 2
    elseif miei == puntiBanco then
        -- La parità la prende il banco: è la regola delle bische
        esito, vincita = 'persa', 0
    else
        esito, vincita = 'persa', 0
    end

    if esito == 'vinta' then
        local rake = math.floor((vincita - m.puntata) * BIS.Tavolo.rake)
        local netto = vincita - rake
        b.banco = b.banco - (netto - m.puntata)
        g:Aggiungi('contanti', netto, 'vincita alla bisca')

        if b.banco <= 0 then
            chiudi(b, 'Il banco è saltato', false)
        end

        return rispondi(true, {
            banco = descriviMano(carteBanco), puntiBanco = puntiBanco, finita = true, vinto = true,
            messaggio = ('Il banco: %s — %.1f.\nTu %.1f: vinci %s%s.')
                :format(descriviMano(carteBanco), puntiBanco, miei, U.Euro(netto),
                        settemezzoServito and ' (sette e mezzo servito!)' or ''),
        })
    end

    b.banco = b.banco + m.puntata
    rispondi(true, {
        banco = descriviMano(carteBanco), puntiBanco = puntiBanco, finita = true, vinto = false,
        messaggio = ('Il banco: %s — %.1f.\nTu %.1f: %s.')
            :format(descriviMano(carteBanco), puntiBanco, miei,
                    miei == puntiBanco and 'parità, prende il banco' or 'perdi'),
    })
end)

-- ---------------------------------------------------------------------------
--  Lo stato del banco, per chi l'ha messo
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('bis:banco', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    for _, b in pairs(bische) do
        if b.organizzatore == g.citizenid then
            local l = BIS.GetLuogo(b.luogo)
            return rispondi({
                luogo = l and l.nome or b.luogo,
                banco = b.banco, iniziale = b.bancoIniziale, mani = b.mani,
                minuti = math.max(0, math.ceil((b.scade - os.time()) / 60)),
            })
        end
    end
    rispondi(nil)
end)

-- ---------------------------------------------------------------------------
--  Soffiate, scadenze e irruzioni
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(30000)
    while true do
        Wait(BIS.Rischio.controlloMinuti * 60000)

        for _, b in pairs(bische) do
            if os.time() >= b.scade then
                chiudi(b, 'Tempo scaduto', false)
            elseif b.mani >= BIS.Rischio.maniPrimaDellaSoffiata
                and math.random() < BIS.Rischio.probabilitaSoffiata then

                local l = BIS.GetLuogo(b.luogo)
                exports.aurea_ui:NotificaEnte('carabinieri', {
                    tipo = 'avviso', icona = '🃏', durata = 20000,
                    titolo = 'Segnalazione di gioco d\'azzardo',
                    testo = ('Movimento sospetto presso %s. Verificare con /irruzione.'):format(l.nome),
                }, true)

                TriggerEvent('aurea:112:allerta', 'sospetto',
                    { x = l.coord.x, y = l.coord.y, z = l.coord.z },
                    'Andirivieni notturno, si sospetta gioco d\'azzardo.', l.nome)

                AUREA.Log('giustizia', 'info', nil, ('Soffiata sulla bisca di %s'):format(b.luogo))
            end
        end
    end
end)

AUREA.Comando('irruzione', 'utente', 'Irruzione in una bisca clandestina', {},
function(src, _, _, g)
    if not g or not AUREA.EForzaOrdine(g.lavoro.nome) or not g.lavoro.servizio then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'errore', icona = '⛔', titolo = 'Non autorizzato',
            testo = 'L\'irruzione la fanno le forze dell\'ordine in servizio.' })
    end

    local b, l = bischaVicina(GetEntityCoords(GetPlayerPed(src)))
    if not b then
        return TriggerClientEvent('aurea:ui:notifica', src, {
            tipo = 'info', icona = '🃏', titolo = 'Niente', testo = 'Qui non si gioca a niente.' })
    end

    local sequestrato = b.banco

    -- L'organizzatore risponde dell'esercizio, i giocatori seduti della
    -- partecipazione. Chi non ha una mano aperta era di passaggio.
    TriggerEvent('aurea:giustizia:apriFascicolo', b.organizzatore, BIS.Reati.esercizio, g:NomeCompleto(),
        ('Bisca presso %s. Banco sequestrato: %s.'):format(l.nome, U.Euro(sequestrato)))

    local giocatori = 0
    for citizenid, m in pairs(mani) do
        if m.bisca == b.luogo then
            giocatori = giocatori + 1
            TriggerEvent('aurea:giustizia:apriFascicolo', citizenid, BIS.Reati.partecipazione,
                g:NomeCompleto(), ('Sorpreso al tavolo presso %s.'):format(l.nome))
        end
    end

    TriggerEvent('aurea:fisco:incasso', 'sequestri', sequestrato, b.organizzatore)
    chiudi(b, nil, true)

    AUREA.Log('giustizia', 'avviso', g,
        ('ha fatto irruzione in una bisca su %s: %s sequestrati, %d giocatori'):format(b.luogo, U.Euro(sequestrato), giocatori))

    TriggerClientEvent('aurea:ui:notifica', src, {
        tipo = 'successo', icona = '🃏', durata = 22000,
        titolo = 'Bisca smantellata',
        testo = ('%s.\nOrganizzatore: %s (art. 718 c.p.).\n%d giocatori al tavolo (art. 720 c.p.).\nBanco sequestrato: %s.')
            :format(l.nome, b.nomeOrganizzatore, giocatori, U.Euro(sequestrato)),
    })
end)

AddEventHandler('aurea:giocatore:caricato', function(src)
    CreateThread(function() Wait(5000) pubblica() end)
end)

print('[AUREA] bische: sette e mezzo clandestino attivo')
