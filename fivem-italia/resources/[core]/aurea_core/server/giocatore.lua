--[[
    AUREA · Oggetto Giocatore

    Un Giocatore è la rappresentazione server-side di un personaggio in gioco.
    Non contiene mai dati che il client possa modificare direttamente: ogni
    mutazione passa da questi metodi, che aggiornano lo stato e replicano al
    client la sola parte necessaria.
]]

AUREA = AUREA or {}
AUREA.Giocatori = {}          -- [source] = Giocatore
AUREA.PerCitizenId = {}       -- [citizenid] = source

local U = AUREA.Util
local C = AUREA.Config

local Giocatore = {}
Giocatore.__index = Giocatore

-- ---------------------------------------------------------------------------
--  Costruzione
-- ---------------------------------------------------------------------------

--- Costruisce l'oggetto a partire dalla riga del database.
function AUREA.CostruisciGiocatore(src, riga, account)
    local g = setmetatable({}, Giocatore)

    g.source     = src
    g.license    = account.license
    g.accountId  = account.id
    g.gruppo     = account.gruppo or 'utente'

    g.citizenid  = riga.citizenid
    g.nome       = riga.nome
    g.cognome    = riga.cognome
    g.dataNascita = riga.data_nascita
    g.luogoNascita = riga.luogo_nascita
    g.sesso      = riga.sesso
    g.cf         = riga.codice_fiscale
    g.telefono   = riga.telefono
    g.nazionalita = riga.nazionalita

    g.denaro = {
        contanti = tonumber(riga.contanti) or 0,
        banca    = tonumber(riga.banca) or 0,
    }

    g.lavoro = {
        nome     = riga.lavoro or 'disoccupato',
        grado    = tonumber(riga.lavoro_grado) or 0,
        servizio = riga.lavoro_servizio == 1,
    }

    g.organizzazione = {
        tag   = riga.organizzazione or 'nessuna',
        grado = tonumber(riga.org_grado) or 0,
    }

    g.aspetto   = riga.aspetto and json.decode(riga.aspetto) or nil
    g.posizione = riga.posizione and json.decode(riga.posizione) or U.CopiaProfonda(C.Avvio.posizione)
    g.metadata  = riga.metadata and json.decode(riga.metadata) or {}

    local stato = riga.stato and json.decode(riga.stato) or nil
    g.stato = stato or { fame = 100, sete = 100, stress = 0, salute = 200, armatura = 0, alcol = 0, energia = 100 }

    -- default di metadata usati trasversalmente dai moduli
    g.metadata.patente      = g.metadata.patente or nil
    g.metadata.iban         = g.metadata.iban or nil
    g.metadata.ricercato    = g.metadata.ricercato or 0
    g.metadata.detenuto     = g.metadata.detenuto or false
    g.metadata.ferito       = g.metadata.ferito or false
    g.metadata.ultimaPaga   = g.metadata.ultimaPaga or 0
    g.metadata.minutiGioco  = tonumber(riga.minuti_gioco) or 0

    return g
end

-- ---------------------------------------------------------------------------
--  Denaro
-- ---------------------------------------------------------------------------

--- Saldo di un conto ('contanti' | 'banca')
function Giocatore:Saldo(conto)
    return self.denaro[conto or 'contanti'] or 0
end

--- Aggiunge denaro. Importi in centesimi, sempre positivi.
---@return boolean
function Giocatore:Aggiungi(conto, importo, causale)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false end
    if not self.denaro[conto] then return false end

    self.denaro[conto] = self.denaro[conto] + importo
    self:SincronizzaDenaro()
    AUREA.Log('denaro', 'info', self, ('+%s su %s — %s'):format(U.Euro(importo), conto, causale or 'n.d.'))
    TriggerEvent('aurea:denaro:variato', self.source, conto, importo, causale)
    return true
end

--- Sottrae denaro se disponibile.
---@return boolean successo
function Giocatore:Sottrai(conto, importo, causale)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false end
    if not self.denaro[conto] then return false end
    if self.denaro[conto] < importo then return false end

    self.denaro[conto] = self.denaro[conto] - importo
    self:SincronizzaDenaro()
    AUREA.Log('denaro', 'info', self, ('-%s da %s — %s'):format(U.Euro(importo), conto, causale or 'n.d.'))
    TriggerEvent('aurea:denaro:variato', self.source, conto, -importo, causale)
    return true
end

--- Sottrae accettando prima i contanti e poi la banca.
function Giocatore:SottraiOvunque(importo, causale)
    importo = math.floor(tonumber(importo) or 0)
    if importo <= 0 then return false end
    if (self.denaro.contanti + self.denaro.banca) < importo then return false end

    local daContanti = math.min(self.denaro.contanti, importo)
    if daContanti > 0 then self:Sottrai('contanti', daContanti, causale) end
    local resto = importo - daContanti
    if resto > 0 then self:Sottrai('banca', resto, causale) end
    return true
end

function Giocatore:SincronizzaDenaro()
    TriggerClientEvent('aurea:denaro:aggiorna', self.source, self.denaro)
end

-- ---------------------------------------------------------------------------
--  Lavoro e organizzazione
-- ---------------------------------------------------------------------------

function Giocatore:ImpostaLavoro(nome, grado)
    if not AUREA.Lavori[nome] then return false end
    grado = tonumber(grado) or 0
    if not AUREA.Lavori[nome].gradi[grado] then grado = 0 end

    self.lavoro.nome = nome
    self.lavoro.grado = grado
    self.lavoro.servizio = false
    self:Sincronizza()
    TriggerEvent('aurea:lavoro:cambiato', self.source, nome, grado)
    AUREA.Log('staff', 'info', self, ('lavoro impostato a %s'):format(AUREA.EtichettaLavoro(nome, grado)))
    return true
end

function Giocatore:ImpostaServizio(inServizio)
    local l = AUREA.GetLavoro(self.lavoro.nome)
    if not l.servizio then return false end
    self.lavoro.servizio = inServizio and true or false
    self:Sincronizza()
    TriggerEvent('aurea:servizio:cambiato', self.source, self.lavoro.nome, self.lavoro.servizio)
    return true
end

function Giocatore:HaPermessoLavoro(permesso)
    return AUREA.GradoHaPermesso(self.lavoro.nome, self.lavoro.grado, permesso)
end

function Giocatore:ImpostaOrganizzazione(tag, grado)
    self.organizzazione.tag = tag or 'nessuna'
    self.organizzazione.grado = tonumber(grado) or 0
    self:Sincronizza()
    return true
end

-- ---------------------------------------------------------------------------
--  Metadata e stato
-- ---------------------------------------------------------------------------

function Giocatore:Get(chiave)
    return self.metadata[chiave]
end

function Giocatore:Set(chiave, valore, replica)
    self.metadata[chiave] = valore
    if replica then
        TriggerClientEvent('aurea:metadata:aggiorna', self.source, chiave, valore)
    end
end

function Giocatore:ImpostaStato(chiave, valore)
    local cfg = C.Stato[chiave]
    local massimo = cfg and cfg.max or 100
    self.stato[chiave] = U.Clamp(tonumber(valore) or 0, 0, massimo)
    TriggerClientEvent('aurea:stato:aggiorna', self.source, self.stato)
end

function Giocatore:VariaStato(chiave, delta)
    self:ImpostaStato(chiave, (self.stato[chiave] or 0) + delta)
end

-- ---------------------------------------------------------------------------
--  Identità
-- ---------------------------------------------------------------------------

function Giocatore:NomeCompleto()
    return ('%s %s'):format(self.nome, self.cognome)
end

--- Pacchetto dati inviato al client. Contiene solo ciò che serve alla UI.
function Giocatore:Pacchetto()
    return {
        citizenid = self.citizenid,
        nome = self.nome,
        cognome = self.cognome,
        dataNascita = self.dataNascita,
        luogoNascita = self.luogoNascita,
        sesso = self.sesso,
        cf = self.cf,
        telefono = self.telefono,
        nazionalita = self.nazionalita,
        denaro = self.denaro,
        lavoro = self.lavoro,
        lavoroEtichetta = AUREA.EtichettaLavoro(self.lavoro.nome, self.lavoro.grado),
        organizzazione = self.organizzazione,
        stato = self.stato,
        metadata = {
            patente = self.metadata.patente,
            iban = self.metadata.iban,
            ricercato = self.metadata.ricercato,
            detenuto = self.metadata.detenuto,
            ferito = self.metadata.ferito,
            minutiGioco = self.metadata.minutiGioco,
        },
        gruppo = self.gruppo,
    }
end

function Giocatore:Sincronizza()
    TriggerClientEvent('aurea:giocatore:aggiorna', self.source, self:Pacchetto())
end

-- ---------------------------------------------------------------------------
--  Persistenza
-- ---------------------------------------------------------------------------

function Giocatore:Salva()
    local ped = GetPlayerPed(self.source)
    if ped and ped ~= 0 then
        local coord = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        if coord and coord.x ~= 0 then
            self.posizione = { x = coord.x, y = coord.y, z = coord.z, h = heading }
        end
    end

    MySQL.update([[
        UPDATE personaggi SET
            contanti = ?, banca = ?, lavoro = ?, lavoro_grado = ?, lavoro_servizio = ?,
            organizzazione = ?, org_grado = ?, aspetto = ?, posizione = ?, stato = ?,
            metadata = ?, minuti_gioco = ?, ultimo_uso = NOW()
        WHERE citizenid = ?
    ]], {
        self.denaro.contanti, self.denaro.banca,
        self.lavoro.nome, self.lavoro.grado, self.lavoro.servizio and 1 or 0,
        self.organizzazione.tag, self.organizzazione.grado,
        self.aspetto and json.encode(self.aspetto) or nil,
        json.encode(self.posizione),
        json.encode(self.stato),
        json.encode(self.metadata),
        self.metadata.minutiGioco or 0,
        self.citizenid,
    })
end

return Giocatore
