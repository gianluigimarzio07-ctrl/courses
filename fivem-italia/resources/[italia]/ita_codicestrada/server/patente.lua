--[[
    AUREA · Patente a punti (server)
]]

Patente = {}

local U = AUREA.Util

--- Legge la patente di un personaggio (nil se non ne ha mai conseguita una).
function Patente.Get(citizenid)
    return MySQL.single.await('SELECT * FROM patenti WHERE citizenid = ?', { citizenid })
end

--- Crea la patente al superamento del primo esame.
function Patente.Crea(citizenid, categoria)
    local numero = AUREA.Anagrafe.NuovoNumeroPatente(citizenid)
    MySQL.insert.await([[
        INSERT INTO patenti (citizenid, numero, categorie, punti, rilascio, scadenza, neopatentato)
        VALUES (?, ?, ?, ?, CURDATE(), ?, 1)
    ]], { citizenid, numero, categoria, CDS.Regole.puntiIniziali, U.DataPiuGiorni(3650) })
    return numero
end

--- Aggiunge una categoria a una patente esistente.
function Patente.AggiungiCategoria(citizenid, categoria)
    local p = Patente.Get(citizenid)
    if not p then return Patente.Crea(citizenid, categoria) end

    local categorie = U.Split(p.categorie or '', ',')
    if U.Contiene(categorie, categoria) then return p.numero end
    categorie[#categorie + 1] = categoria

    MySQL.update.await('UPDATE patenti SET categorie = ? WHERE citizenid = ?',
        { table.concat(categorie, ','), citizenid })
    return p.numero
end

function Patente.HaCategoria(citizenid, categoria)
    local p = Patente.Get(citizenid)
    if not p or p.ritirata == 1 then return false end
    if p.sospesa_fino and p.sospesa_fino ~= 0 then
        -- sospesa_fino arriva come timestamp ms da oxmysql
        if (p.sospesa_fino / 1000) > os.time() then return false end
    end
    return U.Contiene(U.Split(p.categorie or '', ','), categoria)
end

--- Decurta punti. Restituisce i punti residui e se la patente è stata revocata.
---@return integer residui, boolean revocata
function Patente.Decurta(citizenid, punti, motivo)
    local p = Patente.Get(citizenid)
    if not p or punti <= 0 then return p and p.punti or 0, false end

    -- Neopatentato: la decurtazione è raddoppiata (art. 126-bis c.7 CdS)
    if p.neopatentato == 1 then punti = punti * 2 end

    local residui = math.max(0, p.punti - punti)
    local revocata = residui <= 0

    MySQL.update.await('UPDATE patenti SET punti = ?, ritirata = ? WHERE citizenid = ?',
        { residui, revocata and 1 or 0, citizenid })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('cds:puntiAggiornati', g.source, residui)
        if revocata then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'errore', icona = '🚫', durata = 15000,
                titolo = 'Patente revocata',
                testo = 'Hai esaurito i punti. Devi ripetere l\'esame alla Motorizzazione per riottenerla.',
            })
        elseif residui <= 5 then
            TriggerClientEvent('aurea:ui:notifica', g.source, {
                tipo = 'avviso', icona = '⚠', durata = 11000,
                titolo = ('Restano %d punti'):format(residui),
                testo = 'Un corso di recupero alla Motorizzazione te ne restituisce 6.',
            })
        end
    end

    AUREA.Log('multe', 'info', nil, ('%s: −%d punti (%s), residui %d'):format(citizenid, punti, motivo or 'n.d.', residui))
    return residui, revocata
end

--- Sospende la patente per un numero di giorni.
function Patente.Sospendi(citizenid, giorni, motivo)
    if giorni <= 0 then return end
    MySQL.update.await('UPDATE patenti SET sospesa_fino = ? WHERE citizenid = ?',
        { U.DataOraPiuOre(giorni * 24), citizenid })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'errore', icona = '🚫', durata = 13000,
            titolo = 'Patente sospesa',
            testo = ('Sospensione di %d giorni. Motivo: %s.'):format(giorni, motivo or 'provvedimento'),
        })
    end
    AUREA.Log('multe', 'avviso', nil, ('%s: patente sospesa %d giorni (%s)'):format(citizenid, giorni, motivo or 'n.d.'))
end

--- Restituisce punti (corso di recupero o decorso del tempo).
function Patente.Restituisci(citizenid, punti)
    local p = Patente.Get(citizenid)
    if not p then return 0 end
    local nuovi = math.min(CDS.Regole.puntiMassimi, p.punti + punti)
    MySQL.update.await('UPDATE patenti SET punti = ? WHERE citizenid = ?', { nuovi, citizenid })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then TriggerClientEvent('cds:puntiAggiornati', g.source, nuovi) end
    return nuovi
end

-- ---------------------------------------------------------------------------
--  Quiz di teoria: banca domande sul Codice della Strada
-- ---------------------------------------------------------------------------
local BANCA_DOMANDE = {
    { testo = 'Il limite di velocità nei centri abitati, salvo diversa segnalazione, è:',
      risposte = { '30 km/h', '50 km/h', '70 km/h', '90 km/h' }, corretta = 2 },
    { testo = 'Con quanti punti viene rilasciata la patente?',
      risposte = { '10', '15', '20', '30' }, corretta = 3 },
    { testo = 'Il tasso alcolemico massimo consentito alla guida per un conducente non neopatentato è:',
      risposte = { '0,0 g/l', '0,5 g/l', '0,8 g/l', '1,0 g/l' }, corretta = 2 },
    { testo = 'Alla vista di un semaforo giallo il conducente deve:',
      risposte = { 'Accelerare per superare l\'incrocio', 'Arrestarsi se può farlo in sicurezza',
                   'Proseguire sempre', 'Suonare il clacson' }, corretta = 2 },
    { testo = 'La ZTL è una zona in cui:',
      risposte = { 'È vietata la sosta', 'La circolazione è limitata a determinati veicoli e orari',
                   'Si può circolare solo a piedi', 'Il limite è sempre 10 km/h' }, corretta = 2 },
    { testo = 'In autostrada il limite generale per le autovetture è:',
      risposte = { '110 km/h', '120 km/h', '130 km/h', '150 km/h' }, corretta = 3 },
    { testo = 'La revisione periodica di un\'autovettura nuova va effettuata:',
      risposte = { 'Ogni anno', 'Dopo 4 anni, poi ogni 2', 'Ogni 5 anni', 'Non è obbligatoria' }, corretta = 2 },
    { testo = 'Chi guida senza cinture di sicurezza:',
      risposte = { 'Non commette infrazione', 'Perde 5 punti', 'Perde 10 punti', 'Rischia solo l\'ammenda' }, corretta = 2 },
    { testo = 'In caso di incidente con feriti, il conducente coinvolto deve:',
      risposte = { 'Allontanarsi subito', 'Fermarsi e prestare assistenza',
                   'Spostare i feriti in ogni caso', 'Attendere solo l\'assicurazione' }, corretta = 2 },
    { testo = 'L\'uso del telefono cellulare alla guida senza auricolare comporta:',
      risposte = { 'Nessuna sanzione', 'Solo un richiamo verbale',
                   'Sanzione e decurtazione di 5 punti', 'Il ritiro immediato del veicolo' }, corretta = 3 },
    { testo = 'La distanza di sicurezza deve essere valutata in base a:',
      risposte = { 'Solo alla velocità', 'Velocità, condizioni della strada e del veicolo',
                   'Solo al traffico', 'Al tipo di patente' }, corretta = 2 },
    { testo = 'Il neopatentato, nei primi tre anni, subisce una decurtazione dei punti:',
      risposte = { 'Ridotta della metà', 'Uguale agli altri conducenti',
                   'Raddoppiata', 'Triplicata' }, corretta = 3 },
    { testo = 'Circolare senza assicurazione RC comporta:',
      risposte = { 'Solo una sanzione lieve', 'Sanzione e sequestro del veicolo',
                   'Nessuna conseguenza', 'La sola sospensione della patente' }, corretta = 2 },
    { testo = 'La categoria B della patente abilita alla guida di:',
      risposte = { 'Solo motocicli', 'Autoveicoli fino a 3,5 t',
                   'Autobus', 'Autoarticolati' }, corretta = 2 },
    { testo = 'Il segnale di divieto di sosta è:',
      risposte = { 'Triangolare rosso', 'Circolare a fondo blu con bordo e barra rossi',
                   'Quadrato verde', 'Ottagonale rosso' }, corretta = 2 },
}

--- Estrae N domande casuali senza ripetizioni.
function Patente.EstraiDomande(quante)
    local pool = {}
    for i = 1, #BANCA_DOMANDE do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local out = {}
    for i = 1, math.min(quante, #pool) do
        out[i] = BANCA_DOMANDE[pool[i]]
    end
    return out
end

-- ---------------------------------------------------------------------------
--  Recupero punti nel tempo: guida virtuosa
-- ---------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(CDS.Regole.recuperoMinuti * 60000)

        -- Restituisce punti solo a chi non ha verbali aperti recenti
        local idonei = MySQL.query.await([[
            SELECT p.citizenid FROM patenti p
            WHERE p.punti < ? AND p.ritirata = 0
              AND NOT EXISTS (
                SELECT 1 FROM multe m
                WHERE m.citizenid = p.citizenid AND m.stato = 'aperta'
                  AND m.emessa_il > DATE_SUB(NOW(), INTERVAL 1 DAY)
              )
        ]], { CDS.Regole.puntiMassimi }) or {}

        for _, riga in ipairs(idonei) do
            Patente.Restituisci(riga.citizenid, CDS.Regole.recuperoPunti)
        end

        -- Un conducente smette di essere neopatentato dopo il periodo previsto
        MySQL.update([[
            UPDATE patenti SET neopatentato = 0
            WHERE neopatentato = 1 AND rilascio < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        ]])
    end
end)

exports('PatenteGet', Patente.Get)
exports('PatenteHaCategoria', Patente.HaCategoria)
exports('PatenteDecurta', Patente.Decurta)
exports('PatenteSospendi', Patente.Sospendi)
