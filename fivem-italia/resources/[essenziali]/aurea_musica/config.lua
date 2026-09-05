--[[
    AUREA · Musica — configurazione

    Uno stereo che suona per tutti quelli che sono lì, non solo per chi
    l'ha acceso. È sincronizzato dal server: chi arriva dopo sente il
    brano dal punto in cui è, non dall'inizio.

    Solo URL diretti a file audio, e solo da domini elencati qui: un
    campo libero verso Internet dentro il client è un problema, non una
    funzione.
]]

MUS = {}

MUS.Sorgenti = {
    -- Lo stereo portatile, che si posa a terra
    boombox = { item = 'boombox', raggio = 28.0, modello = 'prop_boombox_01' },
    -- L'autoradio: si sente da dentro e da fuori, meno
    autoradio = { raggio = 22.0 },
}

--- Domini da cui è ammesso lo streaming. Fuori da qui il client rifiuta.
MUS.DominiAmmessi = {
    'youtube.com', 'youtu.be', 'soundcloud.com',
}

--- Brani già pronti, così si può usare la funzione senza incollare link.
MUS.Playlist = {
    { id = 'radio_ita', nome = 'Radio italiana', url = 'https://www.youtube.com/watch?v=jfKfPfyJRdk' },
}

MUS.Regole = {
    volumeMassimo = 100,
    volumePredefinito = 45,
    -- Oltre questa distanza non si sente più nulla
    distanzaMassima = 40.0,
    -- Un volume alto di notte è disturbo della quiete
    oraSilenzio = { 23, 7 },
    volumeMolesto = 70,
    probabilitaSegnalazione = 25,
    reato = 'disturbo',
}

function MUS.DominioAmmesso(url)
    url = tostring(url or ''):lower()
    for _, d in ipairs(MUS.DominiAmmessi) do
        if url:find(d, 1, true) then return true end
    end
    return false
end
