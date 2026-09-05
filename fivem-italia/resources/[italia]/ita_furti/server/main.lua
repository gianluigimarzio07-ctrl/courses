--[[
    AUREA · Furti su veicolo (server)

    Il server decide tre cose che il client non deve poter decidere: se
    l'apertura riesce, quanto vale il mezzo alla demolizione, e chi va
    avvisato del furto. Il resto — animazioni, allarme, suoni — sta di là.
]]

local U = AUREA.Util

local rubati = {}       -- [targa] = { da, quando, antifurto, avvisataCentrale }
local demoliteOra = {}  -- [ora] = quanti
local inCorso = {}      -- [src] = { targa, avviata }
local commessa = nil    -- { fascia, testo, richiesti, consegnati, scadenza }

-- ---------------------------------------------------------------------------
--  Aiuti
-- ---------------------------------------------------------------------------
local function calore(g, punti, motivo)
    if g.organizzazione and g.organizzazione.tag ~= 'nessuna' then
        exports.ita_famiglie:CaloreOrganizzazione(g.organizzazione.tag, punti, motivo)
    end
end

local function proprieta(targa)
    local v = MySQL.single.await('SELECT proprieta FROM veicoli WHERE targa = ?', { targa })
    if not v or not v.proprieta then return {} end
    local ok, dati = pcall(json.decode, v.proprieta)
    return (ok and type(dati) == 'table') and dati or {}
end

local function scriviProprieta(targa, dati)
    MySQL.update('UPDATE veicoli SET proprieta = ? WHERE targa = ?', { json.encode(dati), targa })
end

-- ---------------------------------------------------------------------------
--  Commessa dell'autodemolizione
--
--  È la leva che dà una direzione alla serata: senza, si ruba a caso.
-- ---------------------------------------------------------------------------
local function nuovaCommessa()
    local tipo = FUR.Commesse.tipi[math.random(#FUR.Commesse.tipi)]
    commessa = {
        fascia = tipo.fascia,
        testo = tipo.testo,
        richiesti = math.random(FUR.Commesse.quantitaMinima, FUR.Commesse.quantitaMassima),
        consegnati = 0,
        scadenza = os.time() + FUR.Commesse.durataMinuti * 60,
    }

    TriggerClientEvent('fur:commessa', -1, {
        testo = commessa.testo, richiesti = commessa.richiesti,
        fascia = FUR.Fasce[commessa.fascia].nome,
    })
end

CreateThread(function()
    Wait(10000)
    nuovaCommessa()
    while true do
        Wait(FUR.Commesse.durataMinuti * 60000)
        nuovaCommessa()
    end
end)

AUREA.Callback.Registra('fur:commessa', function(src, rispondi)
    if not commessa then return rispondi(nil) end
    rispondi({
        testo = commessa.testo,
        fascia = FUR.Fasce[commessa.fascia].nome,
        richiesti = commessa.richiesti,
        consegnati = commessa.consegnati,
        minutiResidui = math.max(0, math.floor((commessa.scadenza - os.time()) / 60)),
        moltiplicatore = FUR.Commesse.moltiplicatore,
    })
end)

-- ---------------------------------------------------------------------------
--  APERTURA
--
--  Il client dice qual è la targa e la classe del veicolo che ha davanti;
--  il server verifica che quel veicolo esista davvero nelle vicinanze,
--  decide se l'attrezzo regge e se la serratura cede.
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fur:apri', function(src, rispondi, targa, classe, conducenteABordo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    if targa == '' then return rispondi(false, 'Targa illeggibile.') end

    local idFascia, fascia = FUR.FasciaDiClasse(tonumber(classe) or 0)

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)

    local attrezzo, datiAttrezzo
    for item, a in pairs(FUR.Attrezzi) do
        if inventario:Ha(item, 1) then
            if not datiAttrezzo or a.bonusRiuscita > datiAttrezzo.bonusRiuscita then
                attrezzo, datiAttrezzo = item, a
            end
        end
    end
    if not attrezzo then
        return rispondi(false, 'Serve un grimaldello o uno spadino.')
    end

    -- Con qualcuno a bordo non è furto: è rapina, e il reato cambia
    local reato = conducenteABordo and FUR.Regole.reatoRapina or FUR.Regole.reatoFurto

    local riuscita = math.random(100) > (fascia.difficoltaApertura - datiAttrezzo.bonusRiuscita)
    local rotto = false

    if not riuscita and math.random(100) <= datiAttrezzo.probabilitaRottura then
        inventario:Rimuovi(attrezzo, 1)
        TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())
        rotto = true
    end

    rispondi(riuscita, {
        fascia = idFascia,
        nomeFascia = fascia.nome,
        durataApertura = fascia.durataApertura,
        durataAvviamento = fascia.durataAvviamento,
        allarme = fascia.allarme,
        bloccoMotore = fascia.bloccoMotore,
        haCentralina = inventario:Ha(FUR.Centralina, 1),
        segni = datiAttrezzo.lasciaSegni,
        rotto = rotto,
        reato = reato,
        attrezzo = datiAttrezzo.nome,
    })
end)

--- Il furto è consumato: da qui in poi il veicolo risulta rubato.
AUREA.Callback.Registra('fur:consumato', function(src, rispondi, targa, conducenteABordo)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local veicolo = exports.ita_veicoli:GetVeicolo(targa)

    local coord = GetEntityCoords(GetPlayerPed(src))
    local reato = conducenteABordo and FUR.Regole.reatoRapina or FUR.Regole.reatoFurto

    calore(g, FUR.Regole.calorefurto, 'furto di veicolo')

    -- Un veicolo non intestato a nessuno è un veicolo di scena: si ruba
    -- e basta, senza denunce e senza antifurto.
    if not veicolo then
        rubati[targa] = { da = g.citizenid, quando = os.time() }
        return rispondi(true, 'Il motore è partito.')
    end

    local prop = proprieta(targa)
    rubati[targa] = {
        da = g.citizenid, quando = os.time(),
        antifurto = prop.antifurto == true,
        intestatario = veicolo.citizenid,
        avvisataCentrale = false,
    }

    -- Il proprietario si accorge che l'auto non c'è più
    local vittima = AUREA.GetPlayerByCitizenId(veicolo.citizenid)
    if vittima then
        TriggerClientEvent('aurea:ui:notifica', vittima.source, {
            tipo = 'errore', icona = '🚗', durata = 18000,
            titolo = 'Ti hanno portato via il veicolo',
            testo = ('%s (%s). %s'):format(veicolo.modello, targa,
                prop.antifurto and 'L\'antifurto satellitare sta trasmettendo: guarda la mappa.'
                or 'Non avevi installato l\'antifurto: nessuno sa dov\'è.'),
        })
        if prop.antifurto then
            TriggerClientEvent('fur:seguiAntifurto', vittima.source, targa,
                { x = coord.x, y = coord.y, z = coord.z })
        end
    end

    -- La denuncia parte comunque: il reato esiste anche se nessuno guarda
    TriggerEvent('aurea:112:allerta', 'furto', { x = coord.x, y = coord.y, z = coord.z },
        ('Furto di veicolo: %s targato %s.'):format(veicolo.modello, targa),
        'denuncia del proprietario')

    exports.ita_giustizia:ApriFascicolo(g.citizenid, reato, 'denuncia della persona offesa',
        ('Sottrazione del veicolo %s targato %s.'):format(veicolo.modello, targa))

    AUREA.Log('giustizia', 'info', g, ('furto del veicolo %s'):format(targa))
    rispondi(true, 'Il motore è partito. Da adesso quel mezzo è ricercato.')
end)

--- L'antifurto trasmette finché non lo staccano.
CreateThread(function()
    while true do
        Wait(FUR.Antifurto.intervalloSegnalazione)

        for targa, r in pairs(rubati) do
            if r.antifurto and r.intestatario then
                local posizione = nil
                for src in pairs(AUREA.Giocatori) do
                    local ped = GetPlayerPed(src)
                    local veicolo = GetVehiclePedIsIn(ped, false)
                    if veicolo ~= 0 and GetVehicleNumberPlateText(veicolo):gsub('%s+', ''):upper() == targa then
                        local c = GetEntityCoords(ped)
                        posizione = { x = c.x, y = c.y, z = c.z }
                    end
                end

                if posizione then
                    local vittima = AUREA.GetPlayerByCitizenId(r.intestatario)
                    if vittima then
                        TriggerClientEvent('fur:seguiAntifurto', vittima.source, targa, posizione)
                    end

                    -- Passato un po' di tempo, il segnale finisce in centrale
                    if not r.avvisataCentrale
                       and (os.time() - r.quando) / 60 >= FUR.Antifurto.minutiPrimaDellaCentrale then
                        r.avvisataCentrale = true
                        TriggerEvent('aurea:112:allerta', 'furto', posizione,
                            ('Antifurto satellitare attivo sul veicolo %s: posizione aggiornata.'):format(targa),
                            'centrale antifurto')
                    end
                end
            end
        end
    end
end)

--- Staccare l'antifurto richiede tempo e tronchesi.
AUREA.Callback.Registra('fur:staccaAntifurto', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local r = rubati[targa]
    if not r or not r.antifurto then return rispondi(false, 'Su questo mezzo non c\'è nulla da staccare.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(FUR.Antifurto.attrezzoDisattivazione, 1) then
        return rispondi(false, 'Servono le tronchesi per arrivare al cablaggio.')
    end

    r.antifurto = false

    local prop = proprieta(targa)
    prop.antifurto = nil
    scriviProprieta(targa, prop)

    local vittima = r.intestatario and AUREA.GetPlayerByCitizenId(r.intestatario)
    if vittima then
        TriggerClientEvent('fur:antifurtoPerso', vittima.source, targa)
        TriggerClientEvent('aurea:ui:notifica', vittima.source, {
            tipo = 'avviso', icona = '📡', durata = 14000,
            titolo = 'Segnale perso',
            testo = ('L\'antifurto del veicolo %s ha smesso di trasmettere.'):format(targa),
        })
    end

    rispondi(true, 'Cablaggio tranciato: il segnale è morto.')
end)

--- Il proprietario installa l'antifurto sul proprio veicolo.
AUREA.Callback.Registra('fur:installaAntifurto', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local veicolo = exports.ita_veicoli:GetVeicolo(targa)
    if not veicolo then return rispondi(false, 'Veicolo non immatricolato.') end
    if veicolo.citizenid ~= g.citizenid then return rispondi(false, 'Non è intestato a te.') end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(FUR.Antifurto.item, 1) then
        return rispondi(false, 'Non hai un antifurto satellitare.')
    end

    local prop = proprieta(targa)
    if prop.antifurto then return rispondi(false, 'Ne monta già uno.') end

    inventario:Rimuovi(FUR.Antifurto.item, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    prop.antifurto = true
    scriviProprieta(targa, prop)

    rispondi(true, 'Antifurto installato. Se te lo portano via, saprai dove.')
end)

-- ---------------------------------------------------------------------------
--  Allarme e testimoni
--
--  Il client segnala che l'allarme è partito o che qualcuno ha visto; la
--  posizione la prende comunque il server dal ped, non dal messaggio.
-- ---------------------------------------------------------------------------
RegisterNetEvent('fur:allarme', function(targa)
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    if math.random(100) > FUR.Allarme.probabilitaChiamata then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    TriggerEvent('aurea:112:allerta', 'furto', { x = coord.x, y = coord.y, z = coord.z },
        ('Allarme di un\'autovettura in funzione, targa %s. Possibile tentativo di furto.')
            :format(tostring(targa or '?'):sub(1, 10)),
        'segnalazione dei residenti')
end)

RegisterNetEvent('fur:testimone', function()
    local src = source
    local g = AUREA.GetPlayer(src)
    if not g then return end

    local coord = GetEntityCoords(GetPlayerPed(src))
    TriggerEvent('aurea:112:allerta', 'sospetto', { x = coord.x, y = coord.y, z = coord.z },
        'Segnalata persona che armeggia sulla portiera di un\'auto in sosta.',
        'segnalazione di un passante')
end)

-- ---------------------------------------------------------------------------
--  TARGHE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fur:cambiaTarga', function(src, rispondi, targaAttuale)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    if not inventario:Ha(FUR.Targhe.item, 1) then
        return rispondi(false, 'Non hai una targa clonata.')
    end

    targaAttuale = tostring(targaAttuale or ''):gsub('%s+', ''):upper()

    local nuova = AUREA.Anagrafe.NuovaTarga()
    inventario:Rimuovi(FUR.Targhe.item, 1)
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    -- Il mezzo esce dai radar, ma resta in questa lista: al controllo del
    -- telaio la storia può ancora venire fuori.
    if rubati[targaAttuale] then
        rubati[nuova] = rubati[targaAttuale]
        rubati[nuova].targaOriginale = rubati[targaAttuale].targaOriginale or targaAttuale
        rubati[targaAttuale] = nil
    end

    exports.ita_giustizia:ApriFascicolo(g.citizenid, FUR.Regole.reatoTargaFalsa,
        'indagine d\'ufficio', ('Sostituzione della targa %s con %s.'):format(targaAttuale, nuova))

    calore(g, 4, 'sostituzione di targa')

    rispondi(true, nuova)
end)

--- Controllo del telaio: dice se il mezzo è provento di furto.
AUREA.Callback.Registra('fur:controlloTelaio', function(src, rispondi, targa)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(nil) end

    if not g.lavoro.servizio or not g:HaPermessoLavoro('sequestro') then
        return rispondi(nil, 'Non sei autorizzato.')
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()
    local r = rubati[targa]

    if not r then
        return rispondi({ pulito = true }, 'Il numero di telaio corrisponde alla targa.')
    end

    if r.targaOriginale and math.random(100) > FUR.Targhe.probabilitaScopertaAlControllo then
        return rispondi({ pulito = true },
            'Il numero di telaio corrisponde alla targa. Nessuna anomalia rilevata.')
    end

    local vittima = r.intestatario and MySQL.single.await(
        'SELECT nome, cognome FROM personaggi WHERE citizenid = ?', { r.intestatario })

    rispondi({
        pulito = false,
        targaOriginale = r.targaOriginale,
        intestatario = vittima and ('%s %s'):format(vittima.nome, vittima.cognome) or 'sconosciuto',
        da = math.floor((os.time() - r.quando) / 60),
    }, 'Il telaio non corrisponde: il mezzo risulta provento di furto.')
end)

-- ---------------------------------------------------------------------------
--  AUTODEMOLIZIONE
-- ---------------------------------------------------------------------------
AUREA.Callback.Registra('fur:demolisci', function(src, rispondi, targa, classe, danni)
    local g = AUREA.GetPlayer(src)
    if not g then return rispondi(false) end
    if inCorso[src] then return rispondi(false, 'Hai già un mezzo sul ponte.') end

    if not FUR.AllaDemolizione(GetEntityCoords(GetPlayerPed(src))) then
        return rispondi(false, 'Non sei all\'autodemolizione.')
    end

    local ora = os.date('%Y%m%d%H')
    demoliteOra[ora] = demoliteOra[ora] or 0
    if demoliteOra[ora] >= FUR.Demolizione.limiteOrario then
        return rispondi(false, 'Il piazzale è pieno: torna fra un\'ora.')
    end

    targa = tostring(targa or ''):gsub('%s+', ''):upper()

    inCorso[src] = {
        targa = targa,
        classe = tonumber(classe) or 0,
        danni = tonumber(danni) or 0,
        avviata = os.time(),
    }

    rispondi(true, FUR.Demolizione.durata)
end)

AUREA.Callback.Registra('fur:concludiDemolizione', function(src, rispondi)
    local g = AUREA.GetPlayer(src)
    local sessione = inCorso[src]
    if not g or not sessione then return rispondi(false, 'Nessuna demolizione in corso.') end
    inCorso[src] = nil

    if (os.time() - sessione.avviata) * 1000 < (FUR.Demolizione.durata - 3000) then
        return rispondi(false, 'Lo smontaggio non era completo.')
    end

    local idFascia, fascia = FUR.FasciaDiClasse(sessione.classe)
    local veicolo = exports.ita_veicoli:GetVeicolo(sessione.targa)

    local valore = fascia.valore

    -- Un mezzo arrivato a pezzi vale meno
    if sessione.danni > 0 then
        valore = math.floor(valore * (1 - FUR.Demolizione.penalitaDanni * math.min(1, sessione.danni)))
    end

    -- La commessa del momento
    local suCommessa = commessa and commessa.fascia == idFascia
        and commessa.consegnati < commessa.richiesti
        and os.time() < commessa.scadenza

    if suCommessa then
        valore = math.floor(valore * FUR.Commesse.moltiplicatore)
        commessa.consegnati = commessa.consegnati + 1
    end

    local inventario = exports.aurea_inventory:Inventario(g.citizenid)
    local note = math.max(1, math.floor(valore / FUR.Demolizione.tagliobanconota))
    inventario:Aggiungi(FUR.Demolizione.provento, note)

    local recuperati = {}
    for _, p in ipairs(FUR.Demolizione.pezzi) do
        local q = math.random(p.min, p.max)
        if inventario:Aggiungi(p.item, q) then
            recuperati[#recuperati + 1] = ('%d× %s'):format(q, AUREA.Item[p.item].etichetta)
        end
    end
    TriggerClientEvent('inv:aggiorna', src, inventario:Pacchetto())

    local ora = os.date('%Y%m%d%H')
    demoliteOra[ora] = (demoliteOra[ora] or 0) + 1

    calore(g, FUR.Demolizione.calore, 'autodemolizione clandestina')

    -- Demolire un mezzo altrui è ricettazione
    if veicolo then
        MySQL.update('UPDATE veicoli SET stato = \'demolito\' WHERE targa = ?', { sessione.targa })

        if veicolo.citizenid ~= g.citizenid then
            exports.ita_giustizia:ApriFascicolo(g.citizenid, FUR.Regole.reatoRicettazione,
                'indagine d\'ufficio',
                ('Demolizione del veicolo %s, provento di furto.'):format(sessione.targa))

            local vittima = AUREA.GetPlayerByCitizenId(veicolo.citizenid)
            if vittima then
                TriggerClientEvent('aurea:ui:notifica', vittima.source, {
                    tipo = 'errore', icona = '🔧', durata = 16000,
                    titolo = 'Il tuo veicolo è stato demolito',
                    testo = ('%s (%s) non tornerà più. Puoi denunciarlo alle forze dell\'ordine.')
                        :format(veicolo.modello, sessione.targa),
                })
            end
        end
    end

    rubati[sessione.targa] = nil

    TriggerClientEvent('fur:veicoloDemolito', src)

    AUREA.Log('giustizia', 'info', g,
        ('demolizione di %s (%s) per %d banconote'):format(sessione.targa, fascia.nome, note))

    rispondi(true, ('%d banconote%s. Recuperati: %s.'):format(
        note,
        suCommessa and (' (commessa: %s ×%.1f)'):format(commessa.testo, FUR.Commesse.moltiplicatore) or '',
        #recuperati > 0 and table.concat(recuperati, ', ') or 'niente di utile'))
end)

-- ---------------------------------------------------------------------------
--  Un veicolo rubato che nessuno tocca da un'ora smette di essere ricercato
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(600000)
        local adesso = os.time()
        for targa, r in pairs(rubati) do
            if (adesso - r.quando) > 3600 then rubati[targa] = nil end
        end
    end
end)

exports('RisultaRubato', function(targa)
    return rubati[tostring(targa or ''):gsub('%s+', ''):upper()] ~= nil
end)

AddEventHandler('playerDropped', function() inCorso[source] = nil end)
