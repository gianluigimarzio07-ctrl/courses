--[[
    AUREA · Supporto — configurazione

    I ticket. Chi ha un problema lo scrive, lo staff lo prende in carico e
    ci parla dentro il ticket, e alla fine resta agli atti chi ha detto
    cosa. Serve soprattutto quando due giocatori litigano: la
    conversazione è scritta, e non si discute più su chi ha detto che.
]]

SUP = {}

SUP.Categorie = {
    { id = 'regolamento', nome = 'Segnalazione di regolamento', icona = '⚖', priorita = 2 },
    { id = 'tecnico',     nome = 'Problema tecnico',            icona = '🔧', priorita = 3 },
    { id = 'perdita',     nome = 'Perdita di oggetti o denaro', icona = '💶', priorita = 2 },
    { id = 'domanda',     nome = 'Domanda sul gioco',           icona = '❓', priorita = 4 },
    { id = 'urgente',     nome = 'Urgente — situazione in corso', icona = '🚨', priorita = 1 },
}

SUP.Regole = {
    gruppoStaff = 'supporto',
    -- Un ticket aperto per volta
    apertiPerPersona = 1,
    -- I ticket senza risposta si chiudono da soli
    oreChiusuraAutomatica = 48,
    lunghezzaMessaggio = 800,
    -- Chi prende un ticket viene teletrasportato solo se lo chiede
    teletrasportoRichiedeConferma = true,
}

function SUP.GetCategoria(id)
    for _, c in ipairs(SUP.Categorie) do
        if c.id == id then return c end
    end
    return nil
end
