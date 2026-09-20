--[[
    AUREA · S.I.A.E. (configurazione)

    LA TASSA CHE NON È UNA TASSA

    In Italia c'è un ente che non è lo Stato, non è un'azienda e non è un
    sindacato, ma manda i suoi a controllarti e ti fa un verbale se non sei
    in regola. Si chiama SIAE, e incassa i diritti d'autore per conto di
    chi la musica l'ha scritta.

    La regola è semplice e quasi nessuno la conosce fino al primo verbale:
    mettere musica in casa propria è libero, metterla in un LOCALE APERTO
    AL PUBBLICO è PUBBLICA ESECUZIONE, e la pubblica esecuzione si paga.

    Tre livelli, prezzi diversi:

    · MUSICA D'AMBIENTE — lo stereo acceso in un bar mentre la gente
      mangia. Il più economico, ed è quello che dimenticano tutti.
    · MUSICA DAL VIVO — c'è qualcuno che suona. Costa di più.
    · TRATTENIMENTO DANZANTE — si balla. È la discoteca, ed è il più caro.

    IL BORDERÒ

    Chi ha il permesso deve anche dichiarare che cosa ha suonato: è il
    borderò, e serve a ripartire i soldi fra gli autori. Qui il borderò si
    riempie da solo ogni volta che qualcuno accende uno stereo dentro un
    locale — e se il permesso non c'è, quella riga resta lì marcata come
    ABUSIVA, in attesa che un ispettore passi a guardare.

    È il punto della risorsa: non serve che un ispettore sia presente nel
    momento in cui suoni. Serve che passi dopo.
]]

SIAE = {}

SIAE.Lavoro = 'siae'

-- ---------------------------------------------------------------------------
--  La sede
-- ---------------------------------------------------------------------------
SIAE.Sede = {
    nome = 'S.I.A.E. — Sede territoriale',
    coord = vector3(-262.0, -965.2, 31.2),
    raggio = 2.3,
    blip = { sprite = 614, colore = 27, scala = 0.65 },
}

-- ---------------------------------------------------------------------------
--  I permessi
-- ---------------------------------------------------------------------------
SIAE.Permessi = {
    { id = 'musica_ambiente', nome = 'Musica d\'ambiente',
      costo = 18000, minutiValidita = 180,
      descrizione = 'Lo stereo acceso mentre si lavora. Il minimo sindacale, e quasi nessuno ce l\'ha.' },
    { id = 'musica_dal_vivo', nome = 'Musica dal vivo',
      costo = 52000, minutiValidita = 120,
      descrizione = 'Qualcuno che suona davvero. Costa di più perché rende di più.' },
    { id = 'trattenimento_danzante', nome = 'Trattenimento danzante',
      costo = 145000, minutiValidita = 120,
      descrizione = 'Si balla. È il permesso della discoteca, e senza non si apre la serata.' },
}

function SIAE.GetPermesso(id)
    for _, p in ipairs(SIAE.Permessi) do
        if p.id == id then return p end
    end
    return nil
end

--- Un permesso di grado superiore copre quelli inferiori: chi ha il
--- trattenimento danzante non ha bisogno anche della musica d'ambiente.
SIAE.Gerarchia = {
    musica_ambiente = 1,
    musica_dal_vivo = 2,
    trattenimento_danzante = 3,
}

-- ---------------------------------------------------------------------------
--  I locali sotto controllo
--
--  Non tutto il mondo è un locale: la pubblica esecuzione si contesta
--  dove c'è un pubblico. Questi sono i punti in cui suonare ha un prezzo.
-- ---------------------------------------------------------------------------
SIAE.Locali = {
    { id = 'bar_centrale',   nome = 'Bar del centro',        coord = vector3(-1392.8, -606.6, 30.3), raggio = 25.0 },
    { id = 'trattoria',      nome = 'Trattoria',             coord = vector3(-1286.2, -1116.6, 6.9), raggio = 25.0 },
    { id = 'pizzeria',       nome = 'Pizzeria',              coord = vector3(373.2, 328.6, 103.6),   raggio = 22.0 },
    { id = 'discoteca_riva', nome = 'Discoteca sul lungomare', coord = vector3(-1605.0, -1108.0, 2.6), raggio = 45.0 },
    { id = 'circolo',        nome = 'Circolo ricreativo',    coord = vector3(129.0, -1300.2, 29.2),  raggio = 28.0 },
}

function SIAE.LocaleIn(coord)
    for _, l in ipairs(SIAE.Locali) do
        if #(coord - l.coord) <= l.raggio then return l end
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  L'ispezione
-- ---------------------------------------------------------------------------
SIAE.Ispezione = {
    durataSecondi = 25,
    minutiRaffreddamento = 15,

    -- Quante esecuzioni abusive guardare indietro
    minutiRetroattivi = 60,

    -- Sanzione: una parte fissa più una quota per ogni esecuzione abusiva
    sanzioneBase = 60000,
    sanzionePerBrano = 9000,
    sanzioneMassima = 900000,

    -- Chi paga: il gestore del locale se c'è, altrimenti chi ha suonato
    quotaIstituto = 0.35,
}

--- La sanzione per un certo numero di esecuzioni abusive.
function SIAE.Sanzione(brani)
    return math.min(
        SIAE.Ispezione.sanzioneBase + (brani * SIAE.Ispezione.sanzionePerBrano),
        SIAE.Ispezione.sanzioneMassima)
end
