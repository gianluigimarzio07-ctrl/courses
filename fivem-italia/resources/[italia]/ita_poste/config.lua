--[[
    AUREA · Poste — configurazione

    Le Poste sono la cosa che in Italia si usa per tutto: si pagano i
    bollettini, si ritirano le raccomandate, si spediscono i pacchi. Qui
    fanno esattamente questo, e la raccomandata è l'unico modo per far
    arrivare qualcosa di scritto a qualcuno che in quel momento non c'è.
]]

POS = {}

POS.Uffici = {
    { nome = 'Ufficio postale centrale', coord = vector3(-262.0, -1046.0, 31.2) },
    { nome = 'Ufficio postale del porto', coord = vector3(1156.0, -469.0, 66.8) },
    { nome = 'Ufficio postale nord',      coord = vector3(1699.0, 4933.0, 42.1) },
}

POS.Blip = { sprite = 318, colore = 5, scala = 0.7 }

POS.Tariffe = {
    -- Una lettera semplice, che arriva subito
    lettera = { nome = 'Lettera', costo = 1200, giacenzaOre = 72 },
    -- La raccomandata: fa fede la data, e il destinatario deve firmare
    raccomandata = { nome = 'Raccomandata A/R', costo = 6800, giacenzaOre = 240, ricevuta = true },
    -- Il pacco: ci si mette dentro roba vera
    pacco = { nome = 'Pacco', costo = 9500, giacenzaOre = 168, slot = 8, peso = 30000 },
}

--- I bollettini: si pagano qui i tributi iscritti a ruolo.
POS.Bollettini = {
    -- Commissione dell'ufficio su ogni bollettino pagato
    commissione = 200,
}

--- Il conto BancoPosta: un secondo conto, senza fido e senza mutui, ma
--- che si apre senza requisiti. Serve a chi la banca non lo vuole.
POS.BancoPosta = {
    costoApertura = 0,
    canoneMensile = 150,
    -- Non si va sotto lo zero
    scopertoAmmesso = false,
}

POS.Regole = {
    -- Quanti invii al giorno per persona, per non farne uno spam
    inviiGiornalieri = 20,
    lunghezzaTesto = 900,
    -- Un pacco non consegnato torna al mittente
    restituisciDopoGiacenza = true,
}

function POS.UfficioVicino(coord)
    for _, u in ipairs(POS.Uffici) do
        if #(coord - u.coord) < 3.0 then return u end
    end
    return nil
end

function POS.GetTariffa(id) return POS.Tariffe[id] end
