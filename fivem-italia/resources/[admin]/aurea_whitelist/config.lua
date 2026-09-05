--[[
    AUREA · Whitelist — configurazione

    La candidatura si compila in gioco, nella schermata di attesa: chi
    arriva non viene buttato fuori, viene messo in sala d'aspetto con un
    modulo davanti. Lo staff legge e decide, e la decisione arriva anche
    a chi in quel momento è offline.
]]

WL = {}

WL.Attiva = GetConvarInt('aurea_whitelist', 0) == 1

--- Le domande del modulo. Le risposte le legge lo staff.
WL.Modulo = {
    { id = 'eta', domanda = 'Quanti anni hai?', tipo = 'number', obbligatoria = true },
    { id = 'esperienza', domanda = 'Da quanto giochi in roleplay e dove?',
      tipo = 'textarea', obbligatoria = true },
    { id = 'personaggio', domanda = 'Raccontaci il personaggio che vuoi interpretare',
      tipo = 'textarea', obbligatoria = true, minimo = 200 },
    { id = 'metagaming', domanda = 'Che cosa sono metagaming e powergaming?',
      tipo = 'textarea', obbligatoria = true, minimo = 120 },
    { id = 'situazione', domanda = 'Il tuo personaggio viene rapinato in strada. Cosa fai?',
      tipo = 'textarea', obbligatoria = true, minimo = 150 },
}

WL.Regole = {
    -- Quanto si aspetta prima di ripresentare una candidatura respinta
    giorniRiprova = 3,
    -- Chi può decidere
    gruppoRevisore = 'supporto',
    -- Il gruppo che entra comunque
    gruppiEsenti = { 'moderatore', 'admin', 'gestore', 'fondatore' },
    -- Messaggio a chi è in attesa
    messaggioAttesa = 'La tua candidatura è in esame. Riceverai l\'esito appena qualcuno la legge.',
    messaggioRespinto = 'La candidatura non è stata accolta.',
}
