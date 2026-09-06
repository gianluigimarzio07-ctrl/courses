--[[
    AUREA · Gestione dell'ente — configurazione

    Nel server c'era un buco preciso: i gradi dei lavori esistono, i
    permessi 'assumi', 'licenzia' e 'cassa' sono già scritti in
    shared/lavori.lua, gli stipendi vengono pagati a ciclo — ma nessuno
    poteva usarli. Non c'era un posto dove il titolare dell'officina
    assumesse qualcuno, né dove il comandante promuovesse un agente.

    Le partite IVA restano in ita_fisco: quella è la posizione fiscale
    dell'impresa, con la cassa, le fatture e l'IVA a debito. Qui c'è la
    cosa diversa e complementare: chi lavora per chi, con che grado, e la
    cassa dell'ente da cui escono i premi e i rimborsi.

    Una cosa che vale la pena dire: assumere non è gratis. Costa un
    contributo di attivazione che va all'erario, perché altrimenti il
    titolare assume mezzo server e il grado diventa carta straccia.
]]

AZI = {}

-- ---------------------------------------------------------------------------
--  Uffici: dove si gestisce il personale
--
--  Ogni lavoro con un responsabile ha il suo. Chi non compare qui non ha
--  gestione del personale: il suo grado lo assegna solo lo staff.
-- ---------------------------------------------------------------------------
AZI.Uffici = {
    { lavoro = 'meccanico',      nome = 'Officina — ufficio del titolare',  coord = vector3(-330.7, -128.2, 39.0) },
    { lavoro = 'tassista',       nome = 'Rimessa — ufficio licenze',        coord = vector3(895.8, -179.3, 74.7) },
    { lavoro = 'ristoratore',    nome = 'Ristorante — ufficio',             coord = vector3(-1215.6, -894.4, 13.0) },
    { lavoro = 'corriere',       nome = 'Deposito — ufficio capo turno',    coord = vector3(38.9, -1748.0, 29.6) },
    { lavoro = 'giornalista',    nome = 'Redazione — direzione',            coord = vector3(-604.8, -925.6, 23.9) },
    { lavoro = 'carabinieri',    nome = 'Comando — ufficio comando',        coord = vector3(452.1, -973.5, 30.7) },
    { lavoro = 'polizia',        nome = 'Questura — ufficio del dirigente', coord = vector3(440.6, -974.9, 30.7) },
    { lavoro = 'guardia_finanza',nome = 'Comando GdF — ufficio',            coord = vector3(-104.3, 6472.5, 31.6) },
    { lavoro = '118',            nome = 'Ospedale — direzione sanitaria',   coord = vector3(331.6, -598.4, 43.3) },
    { lavoro = 'vigili_fuoco',   nome = 'Caserma — ufficio comandante',     coord = vector3(1193.5, -1466.0, 34.9) },
    { lavoro = 'penitenziaria',  nome = 'Istituto — direzione',             coord = vector3(1782.9, 2596.9, 45.8) },
    { lavoro = 'avvocato',       nome = 'Studio legale — direzione',        coord = vector3(-1900.6, -571.6, 19.1) },
    { lavoro = 'benzinaio',      nome = 'Stazione di servizio — gestione',  coord = vector3(265.0, -1261.3, 29.3) },
    { lavoro = 'autista',        nome = 'Deposito autolinee — esercizio',   coord = vector3(452.7, -604.1, 28.6) },
    { lavoro = 'netturbino',     nome = 'Igiene urbana — capo servizio',    coord = vector3(-321.8, -1545.3, 31.0) },
    { lavoro = 'elettricista',   nome = 'Centrale — sala controllo',        coord = vector3(2734.9, 1487.6, 24.5) },
}

AZI.Raggio = 2.5

-- ---------------------------------------------------------------------------
--  Regole
-- ---------------------------------------------------------------------------
AZI.Regole = {
    -- Permessi che servono, così come sono già scritti in shared/lavori.lua
    permessoAssunzione = 'assumi',
    permessoLicenziamento = 'licenzia',
    permessoCassa = 'cassa',

    -- Contributo di attivazione del rapporto di lavoro, a carico della
    -- cassa dell'ente. Va all'erario.
    contributoAssunzione = 25000,

    -- Nessuno può promuovere qualcuno al proprio grado o sopra: il
    -- titolare resta uno solo.
    gradoMassimoConcedibile = -1,     -- proprio grado meno uno

    -- Chi viene licenziato torna disoccupato
    lavoroDiRicaduta = 'disoccupato',

    -- Il neoassunto parte dal grado più basso, sempre
    gradoIniziale = 0,

    -- Un rapporto di lavoro non si chiude se l'interessato è in servizio:
    -- prima smonta.
    vietaLicenziamentoInServizio = true,
}

-- ---------------------------------------------------------------------------
--  Cassa dell'ente
--
--  Non è la cassa dell'impresa (quella è fiscale, sta in ita_fisco): è il
--  fondo dell'ente da cui escono premi e rimborsi. Ci si versa dentro, e
--  le altre risorse possono versarci quote con l'export VersaInCassa.
-- ---------------------------------------------------------------------------
AZI.Cassa = {
    -- Massimo prelevabile in un colpo solo, per limitare i danni di un
    -- account rubato
    prelievoMassimo = 500000,
    -- Il premio a un dipendente esce dalla cassa e non passa dallo stipendio
    premioMassimo = 200000,
}

-- ---------------------------------------------------------------------------
--  Utilità
-- ---------------------------------------------------------------------------
function AZI.GetUfficio(lavoro)
    for _, u in ipairs(AZI.Uffici) do
        if u.lavoro == lavoro then return u end
    end
    return nil
end

function AZI.UfficioVicino(coord)
    for _, u in ipairs(AZI.Uffici) do
        if #(coord - u.coord) <= AZI.Raggio + 1.0 then return u end
    end
    return nil
end

--- I gradi di un lavoro, ordinati.
function AZI.Gradi(lavoro)
    local dati = AUREA.Lavori[lavoro]
    if not dati then return {} end

    local out = {}
    for n, g in pairs(dati.gradi) do
        out[#out + 1] = { grado = n, etichetta = g.etichetta, stipendio = g.stipendio }
    end
    table.sort(out, function(a, b) return a.grado < b.grado end)
    return out
end
