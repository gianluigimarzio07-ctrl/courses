--[[
    AUREA · Agenzia immobiliare — configurazione

    IL PEZZO CHE MANCAVA FRA IL PROPRIETARIO E IL NOTAIO

    Con ita_notaio due giocatori possono trasferirsi una casa. Ma per
    farlo devono già essersi trovati, essersi messi d'accordo sul prezzo
    e aver capito quanto vale quello che si stanno scambiando.

    È esattamente il lavoro dell'agenzia: mettere in vetrina, far vedere,
    e prendere la provvigione da tutte e due le parti — che in Italia è
    la cosa di cui tutti si lamentano e che tutti pagano.

    COSA FA DAVVERO

        annuncio        il proprietario mette in vendita al prezzo che vuole
        vetrina         chiunque la vede, dall'agenzia o dal telefono
        visita          l'agente accompagna dentro chi è interessato
        proposta        il compratore fa un'offerta, il venditore accetta
        provvigione     all'accettazione, e poi si va dal notaio

    La provvigione si paga sulla PROPOSTA ACCETTATA, non sul rogito. È
    così nella realtà (art. 1755 c.c.: spetta alla conclusione dell'affare)
    ed è il motivo per cui un'agenzia guadagna anche quando poi il rogito
    salta.

    LA STIMA

    L'agenzia sa quanto valgono le case: il valore di listino più quello
    che il mercato ha pagato davvero negli ultimi atti. Chi non passa
    dall'agenzia vende a sentimento.
]]

IMM = {}

IMM.Lavoro = 'immobiliarista'

-- ---------------------------------------------------------------------------
--  L'agenzia
-- ---------------------------------------------------------------------------
IMM.Agenzia = {
    nome = 'Agenzia immobiliare',
    coord = vector3(-716.4, 262.8, 84.1),
    raggio = 2.4,
    blip = { sprite = 374, colore = 3, scala = 0.75 },
}

-- ---------------------------------------------------------------------------
--  Provvigione
-- ---------------------------------------------------------------------------
IMM.Provvigione = {
    -- Quota sul prezzo, a carico di CIASCUNA parte
    quota = 0.03,
    minima = 50000,               -- 500 €
    -- Quanto resta all'agente e quanto va nella cassa dell'agenzia
    quotaAllAgente = 0.40,
    iva = 0.22,
}

-- ---------------------------------------------------------------------------
--  Annunci
-- ---------------------------------------------------------------------------
IMM.Annunci = {
    -- Quanto resta in vetrina, in minuti
    durataMinuti = 480,
    -- Quanti annunci per proprietario
    massimiPerPersona = 3,
    -- Diritti di pubblicazione, all'agenzia
    dirittiPubblicazione = 15000,
    -- Uno scostamento oltre questo dal valore di listino fa comparire
    -- l'avvertenza in vetrina: non lo vieta, lo dichiara
    scostamentoSegnalato = 0.45,
}

-- ---------------------------------------------------------------------------
--  Proposte
-- ---------------------------------------------------------------------------
IMM.Proposte = {
    -- Quanto resta valida una proposta, in minuti
    validitaMinuti = 30,
    -- Caparra confirmatoria: la versa il proponente e la perde se si tira
    -- indietro dopo l'accettazione (art. 1385 c.c.)
    caparra = 0.05,
    -- Quante proposte aperte può avere uno stesso compratore
    massimeAperte = 3,
}

-- ---------------------------------------------------------------------------
--  Visite
-- ---------------------------------------------------------------------------
IMM.Visite = {
    -- Quanto dura l'accesso concesso al visitatore, in minuti
    durataMinuti = 5,
    -- L'agente deve essere in servizio e vicino
    distanzaAgente = 12.0,
}

-- ---------------------------------------------------------------------------
--  Aiutanti
-- ---------------------------------------------------------------------------

--- La provvigione dovuta da una parte su un prezzo.
function IMM.ProvvigioneSu(prezzo)
    return math.max(IMM.Provvigione.minima, math.floor(prezzo * IMM.Provvigione.quota))
end

--- Come si giudica un prezzo rispetto al listino.
function IMM.GiudizioPrezzo(prezzo, listino)
    if listino <= 0 then return 'sconosciuto', 'Nessun valore di riferimento.' end
    local scarto = (prezzo - listino) / listino

    if scarto > IMM.Annunci.scostamentoSegnalato then
        return 'alto', ('Sopra il valore di riferimento del %d%%.'):format(math.floor(scarto * 100))
    end
    if scarto < -IMM.Annunci.scostamentoSegnalato then
        return 'basso', ('Sotto il valore di riferimento del %d%%. Chiedersi perché.')
            :format(math.floor(-scarto * 100))
    end
    return 'congruo', 'In linea con il valore di riferimento.'
end
