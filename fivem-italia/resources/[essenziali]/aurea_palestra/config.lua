--[[
    AUREA · Palestra — configurazione

    Due statistiche che cambiano davvero come si gioca: la FORZA decide
    quanto fai male a mani nude e quanto reggi un colpo, la RESISTENZA
    quanto corri prima di restare senza fiato.

    Si allenano, e si perdono stando fermi. Nessuna scorciatoia: gli
    esercizi durano, e più sei allenato più ci vuole per salire.
]]

PAL = {}

PAL.Sedi = {
    { nome = 'Palestra del centro', coord = vector3(-1202.9, -1568.0, 4.6) },
    { nome = 'Palestra di Vinewood', coord = vector3(-1264.0, -359.0, 36.9) },
}

PAL.Blip = { sprite = 311, colore = 2, scala = 0.7 }

--- Le due statistiche, con il tetto e quanto valgono in gioco.
PAL.Statistiche = {
    forza = {
        nome = 'Forza', icona = '💪',
        massimo = 100,
        descrizione = 'Quanto fai male a mani nude e quanto reggi in mischia.',
        -- A 100 di forza il danno a mani nude è questo moltiplicatore
        moltiplicatoreDanno = 2.2,
    },
    resistenza = {
        nome = 'Resistenza', icona = '🏃',
        massimo = 100,
        descrizione = 'Quanto corri prima di restare senza fiato.',
    },
}

--- Gli esercizi: ognuno allena una statistica, costa fatica e tempo.
PAL.Esercizi = {
    {
        id = 'panca', nome = 'Panca piana', icona = '🏋',
        statistica = 'forza', punti = 2, durata = 18000,
        costoStato = { fame = -6, sete = -10 },
        anim = { dizionario = 'amb@world_human_sit_ups@male@base', nome = 'base' },
    },
    {
        id = 'trazioni', nome = 'Trazioni alla sbarra', icona = '🤸',
        statistica = 'forza', punti = 3, durata = 24000,
        costoStato = { fame = -8, sete = -12 },
        anim = { dizionario = 'amb@world_human_sit_ups@male@base', nome = 'base' },
    },
    {
        id = 'corsa', nome = 'Tapis roulant', icona = '🏃',
        statistica = 'resistenza', punti = 3, durata = 26000,
        costoStato = { fame = -10, sete = -16 },
        anim = { dizionario = 'amb@world_human_jog_standing@male@base', nome = 'base' },
    },
    {
        id = 'corda', nome = 'Salto con la corda', icona = '🪢',
        statistica = 'resistenza', punti = 2, durata = 16000,
        costoStato = { fame = -6, sete = -11 },
        anim = { dizionario = 'amb@world_human_jog_standing@male@base', nome = 'base' },
    },
}

PAL.Regole = {
    -- Più sei allenato, più fatica costa salire ancora
    rendimentoDecrescente = true,
    -- Sotto questo livello di fame o sete non si allena
    minimoPerAllenarsi = 25,
    -- Quanti punti si perdono al giorno stando fermi
    decadimentoGiornaliero = 2,
    -- Ogni quanto si controlla il decadimento
    minutiControllo = 60,
    -- Abbonamento
    costoIngresso = 15000,
    ingressiPerAbbonamento = 10,
}

function PAL.GetEsercizio(id)
    for _, e in ipairs(PAL.Esercizi) do
        if e.id == id then return e end
    end
    return nil
end

--- Punti effettivi: chi è già forte guadagna meno da ogni serie.
function PAL.PuntiEffettivi(esercizio, attuale)
    if not PAL.Regole.rendimentoDecrescente then return esercizio.punti end
    local massimo = PAL.Statistiche[esercizio.statistica].massimo
    local frazione = 1 - (attuale / massimo) * 0.75
    return math.max(1, math.floor(esercizio.punti * frazione + 0.5))
end
