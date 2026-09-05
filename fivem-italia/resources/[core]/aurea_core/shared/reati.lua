--[[
    AUREA · Codice penale e Codice della Strada (versione roleplay)

    Le pene sono espresse in MINUTI di detenzione e le ammende in CENTESIMI.
    I valori sono calibrati sul ritmo di gioco, non su quelli reali.
]]

AUREA = AUREA or {}
AUREA.Reati = {}
AUREA.Infrazioni = {}

-- ---------------------------------------------------------------------------
--  CODICE PENALE  ·  usato da /denuncia, MDT e tribunale
--  gravita: 1 lieve · 2 media · 3 grave · 4 gravissima · 5 associativa
-- ---------------------------------------------------------------------------
local function R(codice, dati)
    dati.codice = codice
    AUREA.Reati[codice] = dati
end

-- Contro il patrimonio
R('624',  { articolo = 'art. 624 c.p.',   nome = 'Furto',                          gravita = 2, pena = 20,  ammenda = 45000 })
R('624b', { articolo = 'art. 624-bis c.p.', nome = 'Furto in abitazione',          gravita = 3, pena = 45,  ammenda = 90000 })
R('628',  { articolo = 'art. 628 c.p.',   nome = 'Rapina',                         gravita = 4, pena = 70,  ammenda = 180000 })
R('629',  { articolo = 'art. 629 c.p.',   nome = 'Estorsione',                     gravita = 4, pena = 80,  ammenda = 220000 })
R('635',  { articolo = 'art. 635 c.p.',   nome = 'Danneggiamento',                 gravita = 1, pena = 10,  ammenda = 25000 })
R('640',  { articolo = 'art. 640 c.p.',   nome = 'Truffa',                         gravita = 2, pena = 25,  ammenda = 60000 })
R('648b', { articolo = 'art. 648-bis c.p.', nome = 'Riciclaggio',                  gravita = 4, pena = 90,  ammenda = 350000 })
R('648t', { articolo = 'art. 648-ter.1 c.p.', nome = 'Autoriciclaggio',            gravita = 4, pena = 75,  ammenda = 300000 })

-- Contro la persona
R('575',  { articolo = 'art. 575 c.p.',   nome = 'Omicidio',                       gravita = 5, pena = 180, ammenda = 500000 })
R('575t', { articolo = 'art. 575 c.p.',   nome = 'Tentato omicidio',               gravita = 4, pena = 100, ammenda = 300000 })
R('582',  { articolo = 'art. 582 c.p.',   nome = 'Lesioni personali',              gravita = 2, pena = 25,  ammenda = 55000 })
R('583',  { articolo = 'art. 583 c.p.',   nome = 'Lesioni gravi',                  gravita = 3, pena = 50,  ammenda = 120000 })
R('605',  { articolo = 'art. 605 c.p.',   nome = 'Sequestro di persona',           gravita = 4, pena = 85,  ammenda = 250000 })
R('610',  { articolo = 'art. 610 c.p.',   nome = 'Violenza privata',               gravita = 2, pena = 22,  ammenda = 50000 })
R('612',  { articolo = 'art. 612 c.p.',   nome = 'Minaccia',                       gravita = 1, pena = 8,   ammenda = 20000 })
R('612b', { articolo = 'art. 612-bis c.p.', nome = 'Atti persecutori',             gravita = 3, pena = 45,  ammenda = 100000 })
R('586',  { articolo = 'art. 586 c.p.',   nome = 'Morte come conseguenza di altro delitto', gravita = 4, pena = 95, ammenda = 320000 })
R('594',  { articolo = 'art. 594 c.p.',   nome = 'Ingiuria',                       gravita = 1, pena = 5,   ammenda = 12000 })
R('595',  { articolo = 'art. 595 c.3 c.p.', nome = 'Diffamazione a mezzo stampa',  gravita = 2, pena = 18,  ammenda = 65000 })

-- Contro la pubblica amministrazione
R('336',  { articolo = 'art. 336 c.p.',   nome = 'Violenza a pubblico ufficiale',  gravita = 3, pena = 40,  ammenda = 90000 })
R('337',  { articolo = 'art. 337 c.p.',   nome = 'Resistenza a pubblico ufficiale',gravita = 2, pena = 25,  ammenda = 60000 })
R('341b', { articolo = 'art. 341-bis c.p.', nome = 'Oltraggio a pubblico ufficiale', gravita = 1, pena = 12, ammenda = 35000 })
R('319',  { articolo = 'art. 319 c.p.',   nome = 'Corruzione',                     gravita = 4, pena = 70,  ammenda = 280000 })
R('378',  { articolo = 'art. 378 c.p.',   nome = 'Favoreggiamento',                gravita = 2, pena = 20,  ammenda = 50000 })
R('385',  { articolo = 'art. 385 c.p.',   nome = 'Evasione',                       gravita = 3, pena = 60,  ammenda = 100000 })
R('476',  { articolo = 'art. 476 c.p.',   nome = 'Falso in atto pubblico',         gravita = 3, pena = 40,  ammenda = 95000 })
R('497b', { articolo = 'art. 497-bis c.p.', nome = 'Possesso di documenti falsi',  gravita = 2, pena = 30,  ammenda = 70000 })

-- Armi e stupefacenti
R('697',  { articolo = 'art. 697 c.p.',   nome = 'Detenzione abusiva di armi',     gravita = 3, pena = 45,  ammenda = 110000 })
R('699',  { articolo = 'art. 699 c.p.',   nome = 'Porto abusivo di armi',          gravita = 3, pena = 55,  ammenda = 140000 })
R('dpr73', { articolo = 'art. 73 DPR 309/90', nome = 'Spaccio di stupefacenti',    gravita = 4, pena = 75,  ammenda = 260000 })
R('dpr73l',{ articolo = 'art. 73 c.5 DPR 309/90', nome = 'Spaccio di lieve entità',gravita = 2, pena = 30,  ammenda = 80000 })
R('dpr74', { articolo = 'art. 74 DPR 309/90', nome = 'Associazione finalizzata al traffico', gravita = 5, pena = 150, ammenda = 600000 })

-- Associative
R('416',  { articolo = 'art. 416 c.p.',   nome = 'Associazione per delinquere',    gravita = 5, pena = 120, ammenda = 400000 })
R('416b', { articolo = 'art. 416-bis c.p.', nome = 'Associazione di tipo mafioso', gravita = 5, pena = 240, ammenda = 900000 })

-- ---------------------------------------------------------------------------
--  CODICE DELLA STRADA  ·  usato da autovelox, ZTL, pattuglie
--  punti = decurtazione dalla patente
-- ---------------------------------------------------------------------------
local function CDS(codice, dati)
    dati.codice = codice
    AUREA.Infrazioni[codice] = dati
end

CDS('142_1', { articolo = 'art. 142 c.7 CdS',  nome = 'Eccesso di velocità fino a 10 km/h', importo = 4200,   punti = 0, sospensione = 0 })
CDS('142_2', { articolo = 'art. 142 c.8 CdS',  nome = 'Eccesso di velocità 10-40 km/h',     importo = 17300,  punti = 3, sospensione = 0 })
CDS('142_3', { articolo = 'art. 142 c.9 CdS',  nome = 'Eccesso di velocità 40-60 km/h',     importo = 54300,  punti = 6, sospensione = 30 })
CDS('142_4', { articolo = 'art. 142 c.9bis CdS', nome = 'Eccesso di velocità oltre 60 km/h',importo = 84500,  punti = 10, sospensione = 90 })
CDS('146',   { articolo = 'art. 146 c.3 CdS',  nome = 'Passaggio con semaforo rosso',       importo = 16700,  punti = 6, sospensione = 0 })
CDS('7_ztl', { articolo = 'art. 7 c.14 CdS',   nome = 'Accesso non autorizzato in ZTL',     importo = 8300,   punti = 0, sospensione = 0 })
CDS('158',   { articolo = 'art. 158 CdS',      nome = 'Sosta vietata',                      importo = 4200,   punti = 0, sospensione = 0 })
CDS('158_h', { articolo = 'art. 158 c.5 CdS',  nome = 'Sosta su posto riservato ai disabili', importo = 16800, punti = 2, sospensione = 0 })
CDS('141',   { articolo = 'art. 141 CdS',      nome = 'Velocità non commisurata',           importo = 8700,   punti = 3, sospensione = 0 })
CDS('143',   { articolo = 'art. 143 CdS',      nome = 'Circolazione contromano',            importo = 16700,  punti = 4, sospensione = 0 })
CDS('148',   { articolo = 'art. 148 CdS',      nome = 'Sorpasso irregolare',                importo = 8700,   punti = 5, sospensione = 0 })
CDS('173',   { articolo = 'art. 173 c.2 CdS',  nome = 'Uso del telefono alla guida',         importo = 16500,  punti = 5, sospensione = 0 })
CDS('172',   { articolo = 'art. 172 CdS',      nome = 'Mancato uso delle cinture',          importo = 8300,   punti = 5, sospensione = 0 })
CDS('186_1', { articolo = 'art. 186 c.2a CdS', nome = 'Guida in stato di ebbrezza (0,5-0,8)', importo = 54400, punti = 10, sospensione = 90 })
CDS('186_2', { articolo = 'art. 186 c.2b CdS', nome = 'Guida in stato di ebbrezza (0,8-1,5)', importo = 80000, punti = 10, sospensione = 180, arresto = 20 })
CDS('186_3', { articolo = 'art. 186 c.2c CdS', nome = 'Guida in stato di ebbrezza (>1,5)',    importo = 160000, punti = 10, sospensione = 365, arresto = 45, sequestro = true })
CDS('187',   { articolo = 'art. 187 CdS',      nome = 'Guida sotto effetto di stupefacenti', importo = 160000, punti = 10, sospensione = 365, arresto = 45, sequestro = true })
CDS('116',   { articolo = 'art. 116 c.15 CdS', nome = 'Guida senza patente',                importo = 500000, punti = 0, sospensione = 0, sequestro = true })
CDS('193',   { articolo = 'art. 193 CdS',      nome = 'Circolazione senza assicurazione',   importo = 86600,  punti = 0, sospensione = 0, sequestro = true })
CDS('80',    { articolo = 'art. 80 c.14 CdS',  nome = 'Revisione scaduta',                  importo = 17300,  punti = 0, sospensione = 0 })
CDS('181',   { articolo = 'art. 181 CdS',      nome = 'Mancata esposizione del bollo',      importo = 4200,   punti = 0, sospensione = 0 })
CDS('189',   { articolo = 'art. 189 c.6 CdS',  nome = 'Omissione di soccorso',              importo = 300000, punti = 10, sospensione = 365, arresto = 60 })
CDS('9bis',  { articolo = 'art. 9-bis CdS',    nome = 'Gareggiamento in velocità',          importo = 400000, punti = 10, sospensione = 365, arresto = 90, sequestro = true })

--- Restituisce l'infrazione per eccesso di velocità dato il delta km/h
---@param delta number quanti km/h sopra il limite
function AUREA.InfrazioneVelocita(delta)
    if delta <= 5 then return nil end
    if delta <= 10 then return AUREA.Infrazioni['142_1'] end
    if delta <= 40 then return AUREA.Infrazioni['142_2'] end
    if delta <= 60 then return AUREA.Infrazioni['142_3'] end
    return AUREA.Infrazioni['142_4']
end

--- Infrazione per tasso alcolemico (g/l)
function AUREA.InfrazioneAlcol(tasso)
    if tasso < 0.5 then return nil end
    if tasso < 0.8 then return AUREA.Infrazioni['186_1'] end
    if tasso <= 1.5 then return AUREA.Infrazioni['186_2'] end
    return AUREA.Infrazioni['186_3']
end

--- Somma pena e ammenda di una lista di codici reato
function AUREA.CalcolaPena(codici)
    local minuti, ammenda, capi = 0, 0, {}
    for _, c in ipairs(codici or {}) do
        local r = AUREA.Reati[c]
        if r then
            minuti = minuti + r.pena
            ammenda = ammenda + r.ammenda
            capi[#capi + 1] = ('%s (%s)'):format(r.nome, r.articolo)
        end
    end
    -- Continuazione: dal secondo capo d'imputazione la pena cumulata è ridotta
    if #capi > 1 then
        minuti = math.floor(minuti * (1 - math.min(0.35, (#capi - 1) * 0.07)))
    end
    return minuti, ammenda, capi
end

return AUREA.Reati
