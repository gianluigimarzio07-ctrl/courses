--[[
    AUREA · Erario
    Contabilità dello Stato: ogni entrata e ogni uscita pubblica passa di qui.
    È il contatore che tiene chiusa l'economia del server.
]]

Erario = {}

local U = AUREA.Util

local CHIAVE_SALDO = 'erario_saldo'
local CHIAVE_STORICO = 'erario_storico'

--- Legge un valore dal registro macroeconomico.
local function leggi(chiave, predefinito)
    local v = MySQL.scalar.await('SELECT valore FROM economia_stato WHERE chiave = ?', { chiave })
    return v and tonumber(v) or predefinito
end

local function scrivi(chiave, valore)
    MySQL.query.await([[
        INSERT INTO economia_stato (chiave, valore) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE valore = VALUES(valore)
    ]], { chiave, tostring(valore) })
end

function Erario.Saldo()
    return leggi(CHIAVE_SALDO, 0)
end

--- Registra un'entrata pubblica (tributo, sanzione, diritto, canone).
---@param voce string
---@param importo integer centesimi
---@param citizenid string|nil chi ha versato
function Erario.Incassa(voce, importo, citizenid)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return end

    scrivi(CHIAVE_SALDO, Erario.Saldo() + importo)
    scrivi('gettito_fiscale', leggi('gettito_fiscale', 0) + importo)

    MySQL.insert('INSERT INTO registro_eventi (canale, livello, citizenid, messaggio, dati) VALUES (?, ?, ?, ?, ?)',
        { 'economia', 'debug', citizenid, ('Erario +%s (%s)'):format(U.Euro(importo), voce),
          json.encode({ voce = voce, importo = importo }) })
end

--- Registra un'uscita pubblica (stipendio, sussidio, rimborso, appalto).
function Erario.Eroga(voce, importo, citizenid)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return end

    scrivi(CHIAVE_SALDO, Erario.Saldo() - importo)
    MySQL.insert('INSERT INTO registro_eventi (canale, livello, citizenid, messaggio, dati) VALUES (?, ?, ?, ?, ?)',
        { 'economia', 'debug', citizenid, ('Erario -%s (%s)'):format(U.Euro(importo), voce),
          json.encode({ voce = voce, importo = -importo }) })
end

--- Aliquota IVA applicabile a un oggetto: serve alle casse dei negozi.
exports('AliquotaItem', function(nomeItem)
    return FISCO.AliquotaItem(nomeItem)
end)

exports('ErarioIncassa', Erario.Incassa)
exports('ErarioEroga', Erario.Eroga)
exports('ErarioSaldo', Erario.Saldo)

-- ---------------------------------------------------------------------------
--  Eventi pubblici usati da tutti gli altri moduli
-- ---------------------------------------------------------------------------

--- Un modulo ha incassato denaro pubblico (multe, bolli, diritti).
AddEventHandler('aurea:fisco:incasso', function(voce, importo, citizenid)
    Erario.Incassa(voce, importo, citizenid)
end)

--- Ritenuta operata alla fonte su uno stipendio.
AddEventHandler('aurea:fisco:ritenuta', function(citizenid, importo, tipo)
    Erario.Incassa(tipo or 'irpef', importo, citizenid)
end)

--- Un modulo eroga denaro pubblico (sussidi, rimborsi).
AddEventHandler('aurea:fisco:erogazione', function(voce, importo, citizenid)
    Erario.Eroga(voce, importo, citizenid)
end)

-- ---------------------------------------------------------------------------
--  Iscrizione di un tributo a carico di un contribuente
-- ---------------------------------------------------------------------------
function Erario.IscriviTributo(citizenid, tipo, periodo, importo, giorniScadenza)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return nil end

    local id = MySQL.insert.await([[
        INSERT INTO tributi (citizenid, tipo, periodo, importo, scadenza, stato)
        VALUES (?, ?, ?, ?, ?, 'dovuto')
    ]], { citizenid, tipo, periodo, importo, U.DataOraPiuOre((giorniScadenza or 15) * 24) })

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if g then
        TriggerClientEvent('aurea:ui:notifica', g.source, {
            tipo = 'avviso', icona = '🧾', durata = 11000,
            titolo = ('Avviso di pagamento — %s'):format(tipo:upper()),
            testo = ('%s per il periodo %s. Scadenza fra %d giorni.'):format(U.Euro(importo), periodo, giorniScadenza or 15),
        })
    end
    TriggerEvent('aurea:telefono:messaggioSistema', citizenid, 'Ag. Entrate',
        ('Avviso %s per %s: %s. Paga presso l\'Agenzia delle Entrate.'):format(tipo:upper(), periodo, U.Euro(importo)))

    return id
end

exports('IscriviTributo', Erario.IscriviTributo)

--- Posizione debitoria complessiva di un contribuente.
function Erario.Debito(citizenid)
    local righe = MySQL.query.await([[
        SELECT id, tipo, periodo, importo, scadenza, stato,
               GREATEST(0, DATEDIFF(NOW(), scadenza)) AS giorniRitardo
        FROM tributi
        WHERE citizenid = ? AND stato IN ('dovuto','cartella','rateizzato')
        ORDER BY scadenza ASC
    ]], { citizenid }) or {}

    local totale = 0
    for _, t in ipairs(righe) do
        local mora = 0
        if (t.giorniRitardo or 0) > 0 then
            mora = math.floor(t.importo * FISCO.Tributi.moraGiornaliera * t.giorniRitardo)
        end
        t.mora = mora
        t.dovuto = t.importo + mora
        t.scadenzaIT = U.DataIT(math.floor((t.scadenza or 0) / 1000))
        totale = totale + t.dovuto
    end

    return righe, totale
end

exports('DebitoFiscale', Erario.Debito)

--- Salda uno o tutti i tributi. Restituisce (ok, messaggio).
function Erario.Salda(citizenid, idTributo)
    local righe, _ = Erario.Debito(citizenid)
    if #righe == 0 then return false, 'Non hai tributi da versare.' end

    local daPagare = {}
    if idTributo == 'tutti' then
        daPagare = righe
    else
        for _, t in ipairs(righe) do
            if t.id == tonumber(idTributo) then daPagare = { t } break end
        end
    end
    if #daPagare == 0 then return false, 'Tributo non trovato.' end

    local totale = 0
    for _, t in ipairs(daPagare) do totale = totale + t.dovuto end

    local g = AUREA.GetPlayerByCitizenId(citizenid)
    if not g then return false, 'Devi essere in gioco per pagare.' end
    if not g:SottraiOvunque(totale, 'versamento tributi') then
        return false, ('Servono %s fra contanti e conto corrente.'):format(U.Euro(totale))
    end

    local ids = {}
    for _, t in ipairs(daPagare) do ids[#ids + 1] = t.id end
    MySQL.update.await(('UPDATE tributi SET stato = \'pagato\' WHERE id IN (%s)'):format(table.concat(ids, ',')))

    Erario.Incassa('versamento_tributi', totale, citizenid)
    return true, ('Versati %s per %d tributi.'):format(U.Euro(totale), #daPagare)
end

-- ---------------------------------------------------------------------------
--  Ciclo: mora, cartelle, segnalazioni alla Guardia di Finanza
-- ---------------------------------------------------------------------------
CreateThread(function()
    Wait(60000)
    while true do
        -- Tributi scaduti da oltre la soglia: diventano cartelle
        local scaduti = MySQL.query.await([[
            SELECT id, citizenid, tipo, importo FROM tributi
            WHERE stato = 'dovuto' AND scadenza < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]], { FISCO.Tributi.giorniCartella }) or {}

        for _, t in ipairs(scaduti) do
            MySQL.update.await('UPDATE tributi SET stato = \'cartella\' WHERE id = ?', { t.id })
            local g = AUREA.GetPlayerByCitizenId(t.citizenid)
            if g then
                TriggerClientEvent('aurea:ui:notifica', g.source, {
                    tipo = 'errore', icona = '📮', durata = 13000,
                    titolo = 'Cartella esattoriale',
                    testo = ('%s non versata: la riscossione è ora coattiva.'):format(t.tipo:upper()),
                })
            end
        end

        -- Posizioni molto esposte: segnalazione alla Guardia di Finanza
        local morosi = MySQL.query.await([[
            SELECT citizenid, SUM(importo) AS totale
            FROM tributi WHERE stato IN ('dovuto','cartella')
            GROUP BY citizenid HAVING totale > ?
        ]], { FISCO.Tributi.sogliaSegnalazione }) or {}

        for _, m in ipairs(morosi) do
            local anagrafica = MySQL.single.await('SELECT nome, cognome, codice_fiscale FROM personaggi WHERE citizenid = ?', { m.citizenid })
            if anagrafica then
                exports.aurea_ui:NotificaLavoro('guardia_finanza', {
                    tipo = 'avviso', icona = '💼', durata = 14000,
                    titolo = 'Segnalazione posizione debitoria',
                    testo = ('%s %s (%s) — esposizione %s'):format(
                        anagrafica.nome, anagrafica.cognome, anagrafica.codice_fiscale, U.Euro(m.totale)),
                }, true)
            end
        end

        Wait(20 * 60000)
    end
end)
