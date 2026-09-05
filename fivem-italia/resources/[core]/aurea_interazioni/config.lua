--[[
    AUREA · Interazioni — configurazione

    Le azioni che due persone si fanno a vicenda: ammanettare, trascinare,
    far salire in auto, perquisire, dare la mano. Sono sempre state
    sparse in cinque risorse diverse, ognuna con il suo tasto: qui stanno
    in un menu solo, e — cosa più importante — tutte quelle che si
    subiscono si possono rifiutare.
]]

INT = {}

INT.Tasto = 'F5'

--- Azioni che si fanno su un'altra persona.
INT.SuAltri = {
    {
        id = 'stretta', nome = 'Dai la mano', icona = '🤝',
        richiedeConsenso = true, distanza = 2.0,
        emote = 'stretta_mano',
    },
    {
        id = 'ammanetta', nome = 'Ammanetta', icona = '🔗',
        distanza = 2.0,
        lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'penitenziaria' },
        inServizio = true, oggetto = 'manette',
        -- Chi ha le mani alzate o è a terra non può rifiutare
        rifiutabileSeInPiedi = true,
    },
    {
        id = 'trascina', nome = 'Accompagna', icona = '👮',
        distanza = 2.5,
        lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'penitenziaria', '118' },
        inServizio = true,
        richiedeAmmanettato = true,
    },
    {
        id = 'inVeicolo', nome = 'Fai salire in auto', icona = '🚓',
        distanza = 5.0,
        lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'penitenziaria', '118' },
        inServizio = true,
        richiedeAmmanettato = true,
    },
    {
        id = 'daVeicolo', nome = 'Fai scendere', icona = '🚪',
        distanza = 5.0,
        lavori = { 'carabinieri', 'polizia', 'guardia_finanza', 'penitenziaria', '118' },
        inServizio = true,
    },
    {
        id = 'perquisisci', nome = 'Perquisisci', icona = '🔍',
        distanza = 2.0,
        lavori = { 'carabinieri', 'polizia', 'guardia_finanza' },
        inServizio = true,
    },
    {
        id = 'documenti', nome = 'Chiedi i documenti', icona = '🪪',
        distanza = 3.0, richiedeConsenso = true,
    },
}

--- Azioni su sé stessi.
--- I nomi delle emote sono quelli di aurea_emote/config.lua.
INT.SuDiSe = {
    { id = 'mani_alto',          nome = 'Mani in alto',              icona = '🙌' },
    { id = 'inginocchiato_mani', nome = 'In ginocchio, mani in testa', icona = '🧎' },
    { id = 'sdraiare',           nome = 'Sdraiati a terra',          icona = '🛌' },
    { id = 'ginocchio',          nome = 'In ginocchio',              icona = '🙇' },
}

INT.Regole = {
    -- Quanto dura una richiesta di consenso
    secondiConsenso = 15,
    -- Il trascinato segue a questa distanza
    distanzaTraino = 0.55,
    oggettoManette = 'manette',
}

function INT.GetAzione(id)
    for _, a in ipairs(INT.SuAltri) do
        if a.id == id then return a end
    end
    return nil
end
