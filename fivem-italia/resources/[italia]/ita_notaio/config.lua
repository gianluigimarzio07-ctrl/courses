--[[
    AUREA · Studio notarile — configurazione

    IL BUCO

    Le case si compravano dall'agenzia e si rivendevano all'agenzia, con
    uno sconto. Fra due giocatori non si poteva fare niente: nessuno
    poteva comprare la casa di un altro, e quindi il mercato immobiliare
    del server era una macchinetta, non un mercato.

    Il motivo per cui in Italia non si vende una casa con una stretta di
    mano è l'art. 1350 c.c.: per gli immobili serve l'atto scritto, e per
    l'atto pubblico serve un notaio. Qui è uguale — e il notaio è un
    giocatore.

    COSA SUCCEDE A UN ROGITO

    Le due parti devono essere davanti al notaio, insieme, nello stesso
    momento. Il prezzo lo concordano loro. Il notaio legge e riceve
    l'atto. Da lì partono tre flussi di denaro diversi:

        il prezzo           dal compratore al venditore
        l'imposta di registro  all'erario, 9% — o 2% se è prima casa
        l'onorario          al notaio, con la sua IVA

    Le agevolazioni prima casa si perdono se si è già proprietari di
    un'abitazione: il modulo lo verifica, non lo chiede.

    E LA PROCURA

    Si può dare a qualcuno il potere di vendere un proprio immobile. È un
    atto vero, con un vero rischio: chi ha la procura vende, e i soldi
    arrivano a lui. Si revoca finché si fa in tempo.
]]

NOT = {}

NOT.Lavoro = 'avvocato'
NOT.Permesso = 'rogito'

-- ---------------------------------------------------------------------------
--  Lo studio
-- ---------------------------------------------------------------------------
NOT.Studio = {
    nome = 'Studio notarile',
    coord = vector3(-1085.4, -845.2, 14.3),
    raggio = 2.4,
    blip = { sprite = 498, colore = 40, scala = 0.7 },
    -- Distanza massima fra le parti perché l'atto sia ricevuto: devono
    -- essere lì tutte e due, non collegate
    distanzaParti = 4.0,
}

-- ---------------------------------------------------------------------------
--  Imposte e onorari
-- ---------------------------------------------------------------------------
NOT.Imposte = {
    -- Imposta di registro sul prezzo dichiarato
    registroOrdinaria = 0.09,
    registroPrimaCasa = 0.02,
    -- Minimo di legge: l'imposta non scende sotto questo, comunque
    registroMinima = 100000,          -- 1.000 €
    -- Imposte ipotecaria e catastale, in misura fissa
    ipocatastali = 10000,             -- 100 €
}

NOT.Onorario = {
    -- Quota sul prezzo, entro i limiti
    quota = 0.022,
    minimo = 120000,                  -- 1.200 €
    massimo = 900000,                 -- 9.000 €
    -- Quanto resta al notaio e quanto va nella cassa dello studio
    quotaAlProfessionista = 0.45,
    iva = 0.22,
}

-- ---------------------------------------------------------------------------
--  Prima casa
--
--  L'agevolazione spetta a chi non possiede già un'abitazione. Le
--  categorie non abitative non contano: un magazzino non toglie la prima
--  casa a nessuno.
-- ---------------------------------------------------------------------------
NOT.PrimaCasa = {
    tipiAbitativi = { 'appartamento', 'villa', 'attico' },
}

function NOT.EAbitativo(tipo)
    for _, t in ipairs(NOT.PrimaCasa.tipiAbitativi) do
        if t == tipo then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
--  Procura
-- ---------------------------------------------------------------------------
NOT.Procura = {
    -- Quanto dura, in minuti
    durataMinuti = 240,
    -- Onorario per l'autentica
    onorario = 45000,
    -- Si revoca sempre, e gratis: è un diritto
    revocabile = true,
}

-- ---------------------------------------------------------------------------
--  Aiutanti
-- ---------------------------------------------------------------------------

--- Calcola imposte e onorario su un prezzo.
---@return table { registro, ipocatastali, onorario, ivaOnorario, totaleCompratore }
function NOT.Conteggio(prezzo, primaCasa)
    local aliquota = primaCasa and NOT.Imposte.registroPrimaCasa or NOT.Imposte.registroOrdinaria
    local registro = math.max(NOT.Imposte.registroMinima, math.floor(prezzo * aliquota))

    local onorario = math.floor(prezzo * NOT.Onorario.quota)
    if onorario < NOT.Onorario.minimo then onorario = NOT.Onorario.minimo end
    if onorario > NOT.Onorario.massimo then onorario = NOT.Onorario.massimo end

    local ivaOnorario = math.floor(onorario * NOT.Onorario.iva)

    return {
        registro = registro,
        ipocatastali = NOT.Imposte.ipocatastali,
        onorario = onorario,
        ivaOnorario = ivaOnorario,
        -- Il compratore paga prezzo, imposte e parcella: è la prassi
        totaleCompratore = prezzo + registro + NOT.Imposte.ipocatastali + onorario + ivaOnorario,
    }
end
