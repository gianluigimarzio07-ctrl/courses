--[[
    AUREA · Rimozione e depositeria (configurazione)

    LA MULTA CHE NON BASTA

    ita_sosta sa fare il preavviso, ita_codicestrada sa fare il verbale.
    Ma c'è una categoria di soste per cui la multa non è la risposta: la
    macchina davanti al passo carrabile, quella sulle strisce pedonali,
    quella ferma in mezzo a una corsia d'emergenza. Lì il codice non dice
    "sanziona": dice RIMUOVI (art. 159 CdS).

    E rimuovere è una cosa diversa dal multare, perché costa a chi la
    subisce in un modo che la multa non riesce a costare:

    · la rimozione si paga a parte dal verbale;
    · il veicolo va in DEPOSITERIA, e la depositeria si fa pagare la
      DIURNARIA — tanto al giorno, finché sta lì;
    · e dopo abbastanza tempo il veicolo non è più tuo: si aliena, che
      è il modo elegante per dire che lo Stato lo vende o lo rottama.

    La diurnaria è la parte che in Italia fa più male: non è una somma
    che ti dicono, è un contatore che gira. Chi lascia la macchina lì
    "solo qualche giorno" scopre che il riscatto costa più della macchina.

    CHI LA PORTA VIA

    Il carro attrezzi lo chiama la polizia locale o lo guida il
    meccanico con il permesso 'carroattrezzi', che esisteva già nei
    gradi del lavoro e fino a oggi non serviva a niente.
]]

CAR = {}

CAR.Lavoro = 'meccanico'
CAR.Permesso = 'carroattrezzi'

--- Chi può disporre la rimozione: l'ordine lo dà l'autorità, il
--- trasporto lo fa il privato. Sono due cose separate anche qui.
CAR.Dispone = { 'polizia', 'carabinieri', 'ausiliario' }

-- ---------------------------------------------------------------------------
--  La depositeria
-- ---------------------------------------------------------------------------
CAR.Deposito = {
    nome = 'Depositeria giudiziaria',
    coord = vector3(487.2, -1310.4, 29.2),
    raggio = 3.0,
    ingresso = vector3(479.8, -1302.0, 29.2),
    blip = { sprite = 68, colore = 5, scala = 0.7 },

    -- Il veicolo, una volta rimosso, finisce in questo garage. È lo
    -- stesso nome che usa ita_veicoli per il sequestro: i due
    -- provvedimenti convivono senza pestarsi i piedi.
    garage = 'depositeria',
}

-- ---------------------------------------------------------------------------
--  I costi
-- ---------------------------------------------------------------------------
CAR.Costi = {
    -- Rimozione, una tantum. Per i mezzi pesanti costa di più.
    rimozione = 12800,
    rimozionePesante = 24600,

    -- La diurnaria: al giorno di custodia. Qui il "giorno" è un blocco
    -- di minuti, perché altrimenti nessuno riscatterebbe mai niente.
    diurnaria = 3100,
    minutiPerGiorno = 20,

    -- Quota che resta a chi ha guidato il carro attrezzi
    quotaOperatore = 0.30,

    -- Oltre questi giorni di custodia il veicolo si aliena
    giorniPrimaDellAlienazione = 12,

    -- Chi riscatta oltre questa soglia di debito non paga: il conto
    -- finisce a ruolo, e a quel punto se ne occupa la riscossione.
    sogliaRuolo = 200000,
}

--- Il costo della rimozione, dalla categoria del veicolo.
function CAR.CostoRimozione(categoria)
    if categoria == 'camion' or categoria == 'autobus' then
        return CAR.Costi.rimozionePesante
    end
    return CAR.Costi.rimozione
end

--- I "giorni" di custodia maturati, dai minuti trascorsi.
function CAR.Giorni(minuti)
    return math.max(1, math.ceil((tonumber(minuti) or 0) / CAR.Costi.minutiPerGiorno))
end

--- Quanto costa tirare fuori un veicolo: rimozione più diurnaria.
function CAR.Riscatto(costoRimozione, minutiInDeposito)
    return math.floor(costoRimozione + (CAR.Giorni(minutiInDeposito) * CAR.Costi.diurnaria))
end

-- ---------------------------------------------------------------------------
--  I motivi di rimozione
--
--  Ognuno porta con sé il proprio verbale: la rimozione non sostituisce
--  la sanzione, si aggiunge.
-- ---------------------------------------------------------------------------
CAR.Motivi = {
    { id = 'passo_carrabile', nome = 'Sosta davanti a passo carrabile',
      infrazione = '158', descrizione = 'Impedisce l\'accesso a una proprietà.' },
    { id = 'strisce',   nome = 'Sosta su attraversamento pedonale',
      infrazione = '158', descrizione = 'I pedoni devono scendere in strada.' },
    { id = 'disabili',  nome = 'Sosta su stallo riservato ai disabili',
      infrazione = '158_h', descrizione = 'Il posto serve a chi non può fare a meno di quello.' },
    { id = 'corsia',    nome = 'Sosta che ostacola la circolazione',
      infrazione = '158', descrizione = 'Il veicolo blocca una corsia di marcia.' },
    { id = 'senza_rca', nome = 'Veicolo sprovvisto di assicurazione',
      infrazione = '193', descrizione = 'Art. 193 CdS: sequestro e rimozione.' },
    { id = 'abbandono', nome = 'Veicolo in stato di abbandono',
      infrazione = '158', descrizione = 'Fermo da troppo tempo nello stesso punto.' },
}

function CAR.GetMotivo(id)
    for _, m in ipairs(CAR.Motivi) do
        if m.id == id then return m end
    end
    return nil
end

CAR.Mezzo = {
    modello = 'flatbed',
    spawn = vector4(472.6, -1315.0, 29.2, 200.0),
    distanzaAggancio = 6.0,
}
