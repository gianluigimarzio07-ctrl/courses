--[[
    AUREA · Onoranze funebri (server)
]]

local U = AUREA.Util

AUREA.Callback.Registra('fun:lapidi', function(src, rispondi)
    local righe = MySQL.query.await([[
        SELECT id, nome, nato, morto_il, epitaffio, presenti
        FROM defunti ORDER BY id ASC
    ]]) or {}

    local out = {}
    for n, r in ipairs(righe) do
        local coord = FUN.PosizioneLapide(n)
        out[#out + 1] = {
            id = r.id, nome = r.nome,
            quando = U.DataIT(math.floor((r.morto_il or 0) / 1000)),
            epitaffio = r.epitaffio,
            presenti = r.presenti,
            coord = { x = coord.x, y = coord.y, z = coord.z },
        }
    end
    rispondi(out)
end)

--- La richiesta di morte definitiva. Non la esegue: la registra.
AUREA.Callback.Registra('fun:richiedi', function(src, rispondi, epitaffio, erede)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local gia = MySQL.scalar.await(
        'SELECT id FROM defunti WHERE citizenid = ?', { g.citizenid })
    if gia then return rispondi(false, 'Risulta già registrato.') end

    local pendente = MySQL.scalar.await(
        'SELECT id FROM funerali WHERE citizenid = ? AND celebrato = 0', { g.citizenid })
    if pendente then return rispondi(false, 'Hai già una richiesta depositata.') end

    local eredeCf = nil
    if erede and erede ~= '' then
        eredeCf = MySQL.scalar.await(
            'SELECT citizenid FROM personaggi WHERE codice_fiscale = ?',
            { tostring(erede):upper() })
        if not eredeCf then return rispondi(false, 'L\'erede indicato non risulta in anagrafe.') end
    end

    MySQL.insert.await([[
        INSERT INTO funerali (citizenid, nome, epitaffio, erede)
        VALUES (?, ?, ?, ?)
    ]], { g.citizenid, g:NomeCompleto(),
          tostring(epitaffio or ''):sub(1, 160), eredeCf })

    exports.aurea_ui:NotificaLavoro(FUN.Lavoro, {
        tipo = 'info', icona = '⚰', durata = 16000,
        titolo = 'Richiesta di sepoltura',
        testo = ('%s ha chiesto di essere sepolto. Vedi /funerali.'):format(g:NomeCompleto()),
    }, false)

    AUREA.Log('staff', 'avviso', g, 'ha depositato una richiesta di morte definitiva')

    rispondi(true, 'Richiesta depositata. Il funerale va celebrato da un ufficiale del Comune al cimitero.')
end)

AUREA.Callback.Registra('fun:pendenti', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not g or g.lavoro.nome ~= FUN.Lavoro then return rispondi({}) end

    local righe = MySQL.query.await([[
        SELECT f.id, f.citizenid, f.nome, f.epitaffio, f.chiesta_il,
               p.nome AS enome, p.cognome AS ecognome
        FROM funerali f
        LEFT JOIN personaggi p ON p.citizenid = f.erede
        WHERE f.celebrato = 0 ORDER BY f.id ASC
    ]]) or {}

    for _, r in ipairs(righe) do
        r.quando = U.DataOraIT(math.floor((r.chiesta_il or 0) / 1000))
        r.erede = r.enome and ('%s %s'):format(r.enome, r.ecognome) or nil
        r.inLinea = AUREA.GetPlayerByCitizenId(r.citizenid) ~= nil
    end
    rispondi(righe)
end)

--- La celebrazione: è qui che la cosa diventa irreversibile.
AUREA.Callback.Registra('fun:celebra', function(src, rispondi, id)
    local celebrante = AUREA.GetPlayer(src)
    if not celebrante then return rispondi(false) end
    if celebrante.lavoro.nome ~= FUN.Lavoro or celebrante.lavoro.grado < 1 then
        return rispondi(false, 'Non hai il titolo per celebrare.')
    end

    local f = MySQL.single.await('SELECT * FROM funerali WHERE id = ? AND celebrato = 0', { id })
    if not f then return rispondi(false, 'Richiesta non trovata.') end

    if #(GetEntityCoords(GetPlayerPed(src)) - FUN.Cimitero.celebrazione) > 25.0 then
        return rispondi(false, 'La cerimonia si celebra al cimitero.')
    end

    local defunto = AUREA.GetPlayerByCitizenId(f.citizenid)
    if not defunto then return rispondi(false, 'Il diretto interessato deve essere presente.') end

    -- Chi c'era resta scritto sulla lapide
    local coordCerimonia = GetEntityCoords(GetPlayerPed(src))
    local presenti = {}
    for altroSrc, altro in pairs(AUREA.Giocatori) do
        if #(coordCerimonia - GetEntityCoords(GetPlayerPed(altroSrc))) <= FUN.Regole.distanzaPresenza then
            presenti[#presenti + 1] = altro:NomeCompleto()
        end
    end

    -- L'eredità
    local contanti, banca = AUREA.Denaro.Saldo(f.citizenid)
    local patrimonio = contanti + banca
    local aiEredi = 0

    if f.erede and patrimonio > 0 then
        aiEredi = math.floor(patrimonio * FUN.Regole.quotaEredi)
        AUREA.Denaro.AggiungiOffline(f.erede, 'banca', aiEredi, 'successione ereditaria')

        local erede = AUREA.GetPlayerByCitizenId(f.erede)
        if erede then
            TriggerClientEvent('aurea:ui:notifica', erede.source, {
                tipo = 'info', icona = '⚰', durata = 18000,
                titolo = 'Successione',
                testo = ('Hai ereditato %s da %s.'):format(U.Euro(aiEredi), f.nome),
            })
        end
    end

    local alloStato = patrimonio - aiEredi
    if alloStato > 0 then
        TriggerEvent('aurea:fisco:incasso', FUN.Regole.voceSuccessione, alloStato, f.citizenid)
    end

    -- I veicoli e gli immobili tornano disponibili
    MySQL.update.await('UPDATE veicoli SET stato = \'demolito\' WHERE citizenid = ?', { f.citizenid })
    MySQL.update.await('UPDATE immobili SET proprietario = NULL, in_vendita = 1 WHERE proprietario = ?',
        { f.citizenid })
    MySQL.update.await('UPDATE immobili SET inquilino = NULL WHERE inquilino = ?', { f.citizenid })

    MySQL.insert.await([[
        INSERT INTO defunti (citizenid, nome, epitaffio, presenti, celebrante)
        VALUES (?, ?, ?, ?, ?)
    ]], { f.citizenid, f.nome, f.epitaffio,
          table.concat(presenti, ', '):sub(1, 500), celebrante:NomeCompleto() })

    MySQL.update.await('UPDATE funerali SET celebrato = 1, celebrato_il = NOW() WHERE id = ?', { id })

    -- Il personaggio esce di scena. L'anagrafe lo conserva.
    MySQL.update.await('UPDATE personaggi SET attivo = 0, contanti = 0, banca = 0 WHERE citizenid = ?',
        { f.citizenid })

    TriggerClientEvent('aurea:ui:notifica', -1, {
        tipo = 'info', icona = '⚰', durata = 20000,
        titolo = 'È mancato',
        testo = ('%s. %s'):format(f.nome, f.epitaffio ~= '' and f.epitaffio or 'Riposi in pace.'),
    })

    TriggerClientEvent('fun:sepolto', defunto.source)

    -- Il personaggio è chiuso: si esce dalla sessione e al rientro se ne
    -- sceglie o se ne crea un altro. È l'unico modo pulito di uscire di
    -- scena senza lasciare in giro un personaggio disattivato.
    local sepolto = defunto.source
    CreateThread(function()
        Wait(22000)
        if GetPlayerName(sepolto) then
            DropPlayer(sepolto, 'La storia di questo personaggio è finita. Rientra per giocarne un altro.')
        end
    end)

    AUREA.Log('staff', 'allarme', celebrante,
        ('ha celebrato il funerale di %s (%s)'):format(f.nome, f.citizenid))

    rispondi(true, ('Funerale celebrato. %d persone presenti, %s agli eredi.')
        :format(#presenti, U.Euro(aiEredi)))
end)
