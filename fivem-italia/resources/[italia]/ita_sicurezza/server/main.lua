--[[
    AUREA · Vigilanza privata (server)

    Il valore che il furgone porta lo decide il server all'apertura del
    servizio, e da quel momento è pubblico: lo sanno la guardia e lo sanno
    tutti quelli che ricevono la segnalazione. Non è un'informazione da
    nascondere — un portavalori in strada si vede, e il gioco è
    esattamente quello.

    Quello che il server non dice mai è dove si trova il furgone: quello
    lo si vede con gli occhi.
]]

local U = AUREA.Util

local servizi = {}      -- [id] = { guardia, valore, da, a, scade, ... }
local contatore = 0
local piantonamenti = {}  -- [citizenid] = { obiettivo, da }

-- ---------------------------------------------------------------------------
--  Qualifica
-- ---------------------------------------------------------------------------
local function giurata(citizenid)
    local d = MySQL.single.await(
        'SELECT * FROM vigilanza_decreti WHERE citizenid = ? AND revocato = 0 AND scade_il > NOW()',
        { citizenid })
    return d ~= nil
end

local function vigilante(g, permesso)
    if not g or g.lavoro.nome ~= SIC.Lavoro or not g.lavoro.servizio then return false end
    if permesso and not g:HaPermessoLavoro(permesso) then return false end
    return giurata(g.citizenid)
end

exports('EGuardiaGiurata', function(citizenid) return giurata(citizenid) end)

-- ---------------------------------------------------------------------------
--  Decreto prefettizio
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sic:giura', function(src, rispondi, aspiranteSrc)
    local u = AUREA.GetPlayer(src)
    if not u then return rispondi(false, 'Sessione non valida.') end

    local ammesso = false
    for _, l in ipairs(SIC.Giuramento.lavoriAbilitati) do
        if u.lavoro.nome == l and u.lavoro.servizio then ammesso = true end
    end
    if not ammesso then
        return rispondi(false, 'Il decreto lo rilascia un ufficiale di pubblica sicurezza in servizio.')
    end

    local a = AUREA.GetPlayer(tonumber(aspiranteSrc))
    if not a then return rispondi(false, 'La persona non è collegata.') end
    if a.lavoro.nome ~= SIC.Lavoro then
        return rispondi(false, 'Deve essere assunto da un istituto di vigilanza.')
    end

    if SIC.Giuramento.richiedePortoArmi then
        local ok, ha = pcall(function()
            return exports.aurea_inventory:Ha(a.citizenid, 'porto_armi', 1)
        end)
        if not ok or not ha then
            return rispondi(false, 'Senza porto d\'armi non si giura: art. 138 TULPS.')
        end
    end

    -- Il porto d'armi da solo non basta: una guardia giurata deve saper
    -- maneggiare l'arma, e chi lo certifica è il Tiro a Segno Nazionale.
    -- È la stessa carta che serve alla Questura, chiesta da un altro
    -- ufficio per un'altra ragione.
    if SIC.Giuramento.richiedeCertificatoTSN then
        local okT, certificato = pcall(function()
            return exports.ita_tsn:CertificatoValido(a.citizenid)
        end)
        if not okT or certificato ~= true then
            return rispondi(false, 'Manca il certificato di idoneità al maneggio delle armi: si prende al Tiro a Segno Nazionale.')
        end
    end

    local ok, precedenti = pcall(function()
        return exports.ita_giustizia:Precedenti(a.citizenid, false)
    end)
    for _, p in ipairs(ok and precedenti or {}) do
        if p.gravita >= SIC.Giuramento.gravitaOstativa then
            return rispondi(false, ('Ostativo: a carico risulta %s.'):format(p.reato))
        end
    end

    if not a:Sottrai('banca', SIC.Giuramento.costo, 'tassa di concessione governativa') then
        return rispondi(false, ('L\'aspirante non ha %s per la tassa.'):format(U.Euro(SIC.Giuramento.costo)))
    end
    TriggerEvent('aurea:fisco:incasso', 'concessioni', SIC.Giuramento.costo, a.citizenid)

    MySQL.query.await([[
        INSERT INTO vigilanza_decreti (citizenid, rilasciato_da, scade_il)
        VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ON DUPLICATE KEY UPDATE revocato = 0, rilasciato_da = VALUES(rilasciato_da),
                                rilasciato_il = NOW(), scade_il = VALUES(scade_il)
    ]], { a.citizenid, u:NomeCompleto(), SIC.Giuramento.validitaMinuti })

    TriggerClientEvent('aurea:ui:notifica', a.source, {
        tipo = 'successo', icona = '🛡', durata = 18000,
        titolo = 'Guardia particolare giurata',
        testo = ('Decreto rilasciato da %s. Vale %d minuti. Porti l\'arma solo in servizio.')
            :format(u:NomeCompleto(), SIC.Giuramento.validitaMinuti),
    })

    AUREA.Log('giustizia', 'info', u, ('ha giurato %s come GPG'):format(a:NomeCompleto()))
    rispondi(true, ('%s è ora guardia particolare giurata.'):format(a:NomeCompleto()))
end)

--- Una condanna fa decadere il decreto: come nella realtà.
AddEventHandler('aurea:giustizia:fascicolo', function(citizenid, gravita)
    if (tonumber(gravita) or 0) < SIC.Giuramento.gravitaOstativa then return end
    if not giurata(citizenid) then return end

    MySQL.update('UPDATE vigilanza_decreti SET revocato = 1 WHERE citizenid = ?', { citizenid })
    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Questura',
        'Il decreto di guardia particolare giurata è revocato per sopravvenuta carenza dei requisiti.')
end)

-- ---------------------------------------------------------------------------
--  Piantonamento
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sic:piantona', function(src, rispondi, obiettivoId)
    local g = AUREA.GetPlayer(src)
    if not vigilante(g, 'piantonamento') then
        return rispondi(false, 'Serve essere guardia giurata, in servizio, con il decreto valido.')
    end

    local o = SIC.GetObiettivo(obiettivoId)
    if not o then return rispondi(false, 'Obiettivo sconosciuto.') end
    if #(GetEntityCoords(GetPlayerPed(src)) - o.coord) > SIC.Piantonamento.raggio then
        return rispondi(false, 'Devi essere sul posto.')
    end

    local quanti = 0
    for _, p in pairs(piantonamenti) do
        if p.obiettivo == obiettivoId then quanti = quanti + 1 end
    end
    if quanti >= SIC.Piantonamento.massimePerObiettivo then
        return rispondi(false, 'Quel presidio è già coperto.')
    end

    piantonamenti[g.citizenid] = { obiettivo = obiettivoId, da = os.time(), source = src }
    rispondi(true, ('Presidio su %s. Resta entro %d metri: se ti allontani, il turno si interrompe.')
        :format(o.nome, math.floor(SIC.Piantonamento.raggio)))
end)

-- ---------------------------------------------------------------------------
--  Obiettivi senza linea d'allarme
--
--  Un impianto antirapina collegato alla centrale operativa è un impianto
--  elettrico. Quando salta la cabina che alimenta la zona, quel punto
--  smette di essere sorvegliato a distanza: resta solo chi ci sta davanti.
--
--  L'istituto lo sa subito, perché quello che vede in centrale è la linea
--  che cade. E chi è di turno lì si becca l'indennità, perché da quel
--  momento il presidio è lui.
-- ---------------------------------------------------------------------------
local function obiettivoSenzaLinea(o)
    if not o then return false end
    local ok, cabina = pcall(function()
        return exports.lav_elettricista:PuntoAlBuio(o.coord)
    end)
    return ok and cabina ~= nil
end

AddEventHandler('aurea:elettricita:blackout', function(_, attivo)
    if not attivo then return end

    local colpiti = {}
    for _, o in ipairs(SIC.Obiettivi) do
        if obiettivoSenzaLinea(o) then colpiti[#colpiti + 1] = o.nome end
    end
    if #colpiti == 0 then return end

    exports.aurea_ui:NotificaLavoro(SIC.Lavoro, {
        tipo = 'errore', icona = '🛡', durata = 20000,
        titolo = 'Linea d\'allarme caduta',
        testo = ('La centrale non vede più: %s. Finché non torna la corrente l\'unico presidio è sul posto.')
            :format(table.concat(colpiti, ', ')),
    }, false)

    AUREA.Log('giustizia', 'avviso', nil,
        ('impianti antirapina senza linea: %s'):format(table.concat(colpiti, ', ')))
end)

--- ita_rapine chiede a noi se un obiettivo è presidiato.
exports('Presidiato', function(obiettivoId)
    local n = 0
    for _, p in pairs(piantonamenti) do
        if p.obiettivo == obiettivoId then n = n + 1 end
    end
    return n > 0, n, SIC.Piantonamento.riduzioneAllarme
end)

--- Il turno matura solo se la guardia è rimasta davvero sul posto.
CreateThread(function()
    while true do
        Wait(60000)

        for citizenid, p in pairs(piantonamenti) do
            local g = AUREA.GetPlayerByCitizenId(citizenid)
            local o = SIC.GetObiettivo(p.obiettivo)

            if not g or not o or g.lavoro.nome ~= SIC.Lavoro or not g.lavoro.servizio then
                piantonamenti[citizenid] = nil
            elseif #(GetEntityCoords(GetPlayerPed(g.source)) - o.coord) > SIC.Piantonamento.raggio then
                piantonamenti[citizenid] = nil
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'errore', icona = '🛡', durata = 12000,
                    titolo = 'Presidio interrotto',
                    testo = ('Ti sei allontanato da %s. Il turno non matura.'):format(o.nome) })
            elseif os.time() - p.da >= SIC.Piantonamento.minutiPerTurno * 60 then
                p.da = os.time()

                -- Obiettivo senza linea d'allarme: il turno vale di più,
                -- perché in quel momento la guardia È l'impianto.
                local senzaLinea = obiettivoSenzaLinea(o)
                local compenso = senzaLinea
                    and math.floor(SIC.Piantonamento.compensoPerTurno
                                   * (1 + SIC.Piantonamento.indennitaSenzaLinea))
                    or SIC.Piantonamento.compensoPerTurno

                g:Aggiungi('banca', compenso, ('presidio %s'):format(o.nome))
                pcall(function()
                    exports.aurea_azienda:VersaInCassa(SIC.Lavoro,
                        math.floor(compenso * 0.25), 'quota istituto')
                end)
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'successo', icona = '🛡', durata = 10000,
                    titolo = 'Turno maturato',
                    testo = senzaLinea
                        and ('%s per il presidio di %s, indennità compresa: l\'impianto è senza linea.')
                            :format(U.Euro(compenso), o.nome)
                        or ('%s per il presidio di %s.'):format(U.Euro(compenso), o.nome) })
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Portavalori
-- ---------------------------------------------------------------------------
local function contaServizi()
    local n = 0
    for _ in pairs(servizi) do n = n + 1 end
    return n
end

AUREA.Callback.Registra('sic:portavalori', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    if not vigilante(g, 'portavalori') then
        return rispondi(false, 'Serve essere guardia giurata, in servizio, con il decreto valido.')
    end
    if contaServizi() >= SIC.Portavalori.contemporanei then
        return rispondi(false, 'Tutti i furgoni sono già in strada.')
    end
    for _, s in pairs(servizi) do
        if s.guardia == g.citizenid then return rispondi(false, 'Hai già un servizio aperto.') end
    end

    local da = SIC.Filiali[math.random(#SIC.Filiali)]
    local a
    repeat a = SIC.Filiali[math.random(#SIC.Filiali)] until a.id ~= da.id

    local valore = math.random(SIC.Portavalori.valoreMinimo, SIC.Portavalori.valoreMassimo)
    contatore = contatore + 1

    servizi[contatore] = {
        id = contatore, guardia = g.citizenid, nomeGuardia = g:NomeCompleto(),
        valore = valore, da = da.id, a = a.id,
        stato = 'da_caricare', aperto = os.time(),
        scade = os.time() + SIC.Portavalori.limiteMinuti * 60,
    }

    MySQL.insert('INSERT INTO vigilanza_servizi (guardia, valore, filiale_da, filiale_a) VALUES (?, ?, ?, ?)',
        { g.citizenid, valore, da.id, a.id })

    TriggerClientEvent('sic:servizio', src, {
        id = contatore, valore = valore,
        da = { nome = da.nome, x = da.coord.x, y = da.coord.y, z = da.coord.z },
        a = { nome = a.nome, x = a.coord.x, y = a.coord.y, z = a.coord.z },
        stato = 'da_caricare',
        minuti = SIC.Portavalori.limiteMinuti,
    })

    rispondi(true, ('Servizio assegnato.\n%s → %s\nValore trasportato: %s.\nHai %d minuti.')
        :format(da.nome, a.nome, U.Euro(valore), SIC.Portavalori.limiteMinuti))
end)

AUREA.Callback.Registra('sic:carica', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local s = g and servizi[tonumber(id) or 0]
    if not s or s.guardia ~= g.citizenid then return rispondi(false, 'Servizio non tuo.') end
    if s.stato ~= 'da_caricare' then return rispondi(false, 'Il carico è già a bordo.') end

    local f = SIC.GetFiliale(s.da)
    if #(GetEntityCoords(GetPlayerPed(src)) - f.coord) > 8.0 then
        return rispondi(false, 'Devi essere alla filiale di partenza.')
    end

    s.stato = 'in_viaggio'
    s.caricato = os.time()

    -- Da adesso il furgone è un obiettivo, e si sa
    CreateThread(function()
        Wait(SIC.Portavalori.secondiPrimaDellAvviso * 1000)
        if servizi[s.id] and servizi[s.id].stato == 'in_viaggio' then
            local arrivo = SIC.GetFiliale(s.a)
            TriggerClientEvent('sic:avviso', -1, {
                valore = s.valore, verso = arrivo.nome,
            })
        end
    end)

    rispondi(true, ('Carico a bordo: %s. Destinazione %s.\nFra poco lo sapranno anche gli altri.')
        :format(U.Euro(s.valore), SIC.GetFiliale(s.a).nome))
end)

AUREA.Callback.Registra('sic:consegna', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local s = g and servizi[tonumber(id) or 0]
    if not s or s.guardia ~= g.citizenid then return rispondi(false, 'Servizio non tuo.') end
    if s.stato ~= 'in_viaggio' then return rispondi(false, 'Non hai niente da consegnare.') end

    local f = SIC.GetFiliale(s.a)
    if #(GetEntityCoords(GetPlayerPed(src)) - f.coord) > 8.0 then
        return rispondi(false, 'Devi essere alla filiale di destinazione.')
    end

    local compenso = math.floor(s.valore * SIC.Portavalori.compenso)
    g:Aggiungi('banca', compenso, 'servizio portavalori')
    pcall(function()
        exports.aurea_azienda:VersaInCassa(SIC.Lavoro, math.floor(compenso * 0.3), 'quota istituto')
    end)

    MySQL.update('UPDATE vigilanza_servizi SET esito = ?, chiuso_il = NOW() WHERE guardia = ? AND esito = ? ORDER BY id DESC LIMIT 1',
        { 'consegnato', g.citizenid, 'aperto' })

    servizi[s.id] = nil
    TriggerClientEvent('sic:servizio', src, nil)

    AUREA.Log('economia', 'info', g, ('ha consegnato un portavalori da %s'):format(U.Euro(s.valore)))
    rispondi(true, ('Consegnato. Compenso %s.'):format(U.Euro(compenso)))
end)

-- ---------------------------------------------------------------------------
--  L'assalto
--
--  Chi apre il portellone prende il contante. Non c'è nessun controllo
--  sul lavoro di chi lo fa: è una rapina, e la rapina è aperta a tutti.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('sic:assalta', function(src, rispondi, id)
    local g = AUREA.GetPlayer(src)
    local s = g and servizi[tonumber(id) or 0]
    if not s then return rispondi(false, 'Non c\'è nessun furgone.') end
    if s.stato ~= 'in_viaggio' then return rispondi(false, 'Il furgone è vuoto.') end
    if s.guardia == g.citizenid then return rispondi(false, 'È il tuo servizio.') end

    local bottino = math.floor(s.valore * SIC.Portavalori.quotaRapinabile)
    exports.aurea_inventory:Aggiungi(g.citizenid, 'contanti_sporchi',
        math.max(1, math.floor(bottino / 10000)))

    MySQL.update('UPDATE vigilanza_servizi SET esito = ?, chiuso_il = NOW() WHERE guardia = ? AND esito = ? ORDER BY id DESC LIMIT 1',
        { 'assaltato', s.guardia, 'aperto' })

    TriggerEvent('aurea:giustizia:apriFascicolo', g.citizenid, '628', 'polizia giudiziaria',
        ('Assalto a furgone portavalori. Valore sottratto %s.'):format(U.Euro(bottino)))

    local guardia = AUREA.GetPlayerByCitizenId(s.guardia)
    if guardia then
        TriggerClientEvent('aurea:ui:notifica', guardia.source, {
            tipo = 'errore', icona = '🛡', durata = 22000,
            titolo = 'Furgone assaltato',
            testo = 'Hanno aperto il portellone. Il carico non c\'è più.' })
        TriggerClientEvent('sic:servizio', guardia.source, nil)
    end

    local coord = GetEntityCoords(GetPlayerPed(src))
    TriggerEvent('aurea:112:allerta', 'rapina', { x = coord.x, y = coord.y, z = coord.z },
        'Assalto a furgone portavalori in corso.', 'strada')

    servizi[s.id] = nil
    AUREA.Log('giustizia', 'allarme', g, ('ha assaltato un portavalori (%s)'):format(U.Euro(bottino)))

    rispondi(true, ('Portellone aperto. %s in contanti non tracciati.'):format(U.Euro(bottino)))
end)

--- Chi vuole assaltare deve sapere quali servizi sono in strada.
AUREA.Callback.Registra('sic:inStrada', function(src, rispondi)
    local fuori = {}
    for id, s in pairs(servizi) do
        if s.stato == 'in_viaggio' then
            fuori[#fuori + 1] = { id = id, valore = s.valore, verso = SIC.GetFiliale(s.a).nome }
        end
    end
    rispondi(fuori)
end)

-- ---------------------------------------------------------------------------
--  Scadenze
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        for id, s in pairs(servizi) do
            if os.time() >= s.scade then
                local g = AUREA.GetPlayerByCitizenId(s.guardia)
                if g then
                    TriggerClientEvent('aurea:ui:notifica', g.source, {
                        tipo = 'errore', icona = '🛡', durata = 14000,
                        titolo = 'Servizio scaduto',
                        testo = 'Il carico è rientrato in filiale. Nessun compenso.' })
                    TriggerClientEvent('sic:servizio', g.source, nil)
                end
                MySQL.update('UPDATE vigilanza_servizi SET esito = ?, chiuso_il = NOW() WHERE guardia = ? AND esito = ? ORDER BY id DESC LIMIT 1',
                    { 'scaduto', s.guardia, 'aperto' })
                servizi[id] = nil
            end
        end
    end
end)

print('[AUREA] vigilanza privata: presidi e portavalori attivi')
