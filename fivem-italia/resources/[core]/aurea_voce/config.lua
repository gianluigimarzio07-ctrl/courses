--[[
    AUREA · Voce — configurazione

    La chat di prossimità c'era già; la voce no, e in un server di ruolo
    la voce è quasi tutto. Questo modulo governa tre cose:

      · quanto lontano ti si sente, e che il raggio sia lo stesso per
        chi parla e per chi ascolta
      · la radio, che è un canale a parte e non si mescola alla voce
      · il telefono, che collega due persone lontane

    Si appoggia a pma-voice, che è lo standard di fatto. Se non c'è, il
    modulo lo dice all'avvio e non fa danni: resta la chat scritta.
]]

VOC = {}

VOC.Portate = {
    { id = 'sussurro', nome = 'Sussurro', metri = 3.0,  icona = '🤫' },
    { id = 'normale',  nome = 'Normale',  metri = 12.0, icona = '💬' },
    { id = 'grido',    nome = 'Grido',    metri = 32.0, icona = '📢' },
}

VOC.Predefinita = 'normale'

VOC.Tasti = {
    -- Scorre fra le tre portate
    cambia = 'Z',
    -- Radio, push-to-talk
    radio = 'CAPITAL',
}

VOC.Radio = {
    -- Serve l'apparecchio in tasca
    oggetto = 'radio',
    -- Le frequenze riservate: chi non ha quel lavoro non entra.
    -- Valgono per la voce E per il testo (/r): è la stessa radio, e
    -- l'elenco di chi è sintonizzato è uno solo, quello di questa risorsa.
    riservate = {
        [1.0]  = { nome = 'Carabinieri — operativo', lavori = { 'carabinieri' } },
        [2.0]  = { nome = 'Polizia — operativo',     lavori = { 'polizia' } },
        [3.0]  = { nome = 'Guardia di Finanza',      lavori = { 'guardia_finanza' } },
        [4.0]  = { nome = 'Emergenza Sanitaria 118', lavori = { '118', 'medico' } },
        [5.0]  = { nome = 'Vigili del Fuoco',        lavori = { 'vigili_fuoco' } },
        [6.0]  = { nome = 'Polizia Penitenziaria',   lavori = { 'penitenziaria' } },
        [9.0]  = { nome = 'Interforze',              lavori = { 'carabinieri', 'polizia',
                                                                'guardia_finanza', '118',
                                                                'vigili_fuoco', 'penitenziaria' } },
        [10.0] = { nome = 'Soccorso stradale',       lavori = { 'meccanico' } },
        [11.0] = { nome = 'Trasporto pubblico',      lavori = { 'autista' } },
        [12.0] = { nome = 'Redazione',               lavori = { 'giornalista' } },
    },
    -- Fra queste due chiunque può parlare
    liberaDa = 20.0, liberaA = 99.9,
    -- Il volume in cuffia
    volume = 0.4,
}

VOC.Telefono = {
    -- Il volume di chi è dall'altra parte
    volume = 0.6,
    -- Chi è vicino a te sente la tua metà della telefonata
    sentiDaVicino = true,
}

VOC.Regole = {
    -- Chi è incosciente non parla
    zittisciIncoscienti = true,
    -- Dentro un veicolo chiuso ci si sente un po' meno da fuori
    attenuazioneVeicolo = 0.6,
    -- Il nome sopra la testa di chi sta parlando
    mostraChiParla = true,
    distanzaIndicatore = 15.0,
}

function VOC.GetPortata(id)
    for _, p in ipairs(VOC.Portate) do
        if p.id == id then return p end
    end
    return VOC.Portate[2]
end

function VOC.Prossima(id)
    for n, p in ipairs(VOC.Portate) do
        if p.id == id then return VOC.Portate[(n % #VOC.Portate) + 1] end
    end
    return VOC.Portate[2]
end

--- Una frequenza è libera, o riservata a certi lavori?
function VOC.FrequenzaAmmessa(frequenza, lavoro)
    local riservata = VOC.Radio.riservate[frequenza]
    if not riservata then
        return frequenza >= VOC.Radio.liberaDa and frequenza <= VOC.Radio.liberaA
    end
    for _, l in ipairs(riservata.lavori) do
        if l == lavoro then return true end
    end
    return false
end

--- Il nome parlato di una frequenza, per le notifiche.
function VOC.NomeFrequenza(frequenza)
    local riservata = VOC.Radio.riservate[frequenza]
    return riservata and riservata.nome or ('Frequenza %0.1f'):format(frequenza)
end
