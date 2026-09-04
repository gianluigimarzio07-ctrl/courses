--[[
    AUREA · Elaborazione — configurazione

    Il punto che rende questo modulo italiano: l'art. 78 del Codice della
    Strada. Una modifica che altera le caratteristiche del veicolo va
    omologata e annotata sulla carta di circolazione. Se non lo fai, il
    veicolo circola irregolare e alla prima pattuglia scatta il verbale e
    il ritiro del documento.

    Estetica (colori, cerchi, vetri entro i limiti) = libera.
    Meccanica (motore, turbo, sospensioni, scarico) = va omologata.
]]

TUN = {}

-- ---------------------------------------------------------------------------
--  Officine
-- ---------------------------------------------------------------------------
TUN.Officine = {
    { nome = 'Elaborazioni Innocence', coord = vector3(-337.3, -136.6, 39.0),
      uscita = vector4(-347.0, -128.5, 38.7, 70.0) },
    { nome = 'Elaborazioni Sandy',     coord = vector3(1175.0, 2640.2, 37.8),
      uscita = vector4(1182.4, 2645.8, 37.8, 0.0) },
    { nome = 'Elaborazioni Porto',     coord = vector3(1204.0, -3115.0, 5.5),
      uscita = vector4(1213.5, -3120.6, 5.5, 90.0) },
}

--- Officina clandestina: elabora senza chiedere documenti, ma non omologa
TUN.Clandestina = {
    nome = 'Officina non autorizzata',
    coord = vector3(-1155.0, -2033.0, 13.2),
    uscita = vector4(-1147.5, -2038.4, 13.2, 150.0),
    -- Sovrapprezzo per non fare domande
    ricarico = 1.45,
}

--- Dove si omologano le modifiche
TUN.Motorizzazione = {
    nome = 'Motorizzazione — collaudo modifiche',
    coord = vector3(240.7, -1379.5, 33.7),
    -- Costo per pratica di omologazione
    costoPratica = 32000,
    durataCollaudo = 18000,
}

-- ---------------------------------------------------------------------------
--  Modifiche estetiche: libere, nessuna omologazione
-- ---------------------------------------------------------------------------
TUN.Estetiche = {
    { id = 'colorePrimario',   nome = 'Colore principale',  tipo = 'colore',  prezzo = 22000 },
    { id = 'coloreSecondario', nome = 'Colore secondario',  tipo = 'colore',  prezzo = 18000 },
    { id = 'coloreCerchi',     nome = 'Colore dei cerchi',  tipo = 'colore',  prezzo = 12000 },
    { id = 'finestrini',       nome = 'Vetri oscurati',     tipo = 'vetri',   prezzo = 28000 },
    { id = 'cerchi',           nome = 'Cerchi',             tipo = 'mod', indice = 23, prezzo = 45000 },
    { id = 'livrea',           nome = 'Livrea',             tipo = 'livrea',  prezzo = 35000 },
    { id = 'paraurti_ant',     nome = 'Paraurti anteriore', tipo = 'mod', indice = 1,  prezzo = 38000 },
    { id = 'paraurti_post',    nome = 'Paraurti posteriore',tipo = 'mod', indice = 2,  prezzo = 38000 },
    { id = 'minigonne',        nome = 'Minigonne',          tipo = 'mod', indice = 3,  prezzo = 30000 },
    { id = 'cofano',           nome = 'Cofano',             tipo = 'mod', indice = 7,  prezzo = 42000 },
    { id = 'spoiler',          nome = 'Alettone',           tipo = 'mod', indice = 0,  prezzo = 52000 },
    { id = 'roll_bar',         nome = 'Roll bar',           tipo = 'mod', indice = 42, prezzo = 26000 },
    { id = 'interni',          nome = 'Interni',            tipo = 'mod', indice = 30, prezzo = 24000 },
    { id = 'volante',          nome = 'Volante',            tipo = 'mod', indice = 33, prezzo = 18000 },
    { id = 'targa_stile',      nome = 'Portatarga',         tipo = 'mod', indice = 25, prezzo = 9000 },
}

-- ---------------------------------------------------------------------------
--  Modifiche meccaniche: alterano le prestazioni, vanno omologate
-- ---------------------------------------------------------------------------
TUN.Meccaniche = {
    { id = 'motore',      nome = 'Elaborazione motore', indice = 11, prezzo = 180000,
      descrizione = 'Aumenta la potenza. Cambia la classe di omologazione.' },
    { id = 'cambio',      nome = 'Cambio',              indice = 13, prezzo = 120000,
      descrizione = 'Rapporti più corti, accelerazione migliore.' },
    { id = 'freni',       nome = 'Impianto frenante',   indice = 12, prezzo = 95000,
      descrizione = 'Spazi di frenata ridotti.' },
    { id = 'sospensioni', nome = 'Assetto',             indice = 15, prezzo = 110000,
      descrizione = 'Abbassa il veicolo. Sotto una certa soglia non è omologabile.' },
    { id = 'turbo',       nome = 'Turbocompressore',    indice = 18, prezzo = 260000, interruttore = true,
      descrizione = 'Modifica sostanziale: senza omologazione il veicolo è fuori norma.' },
    { id = 'scarico',     nome = 'Scarico sportivo',    indice = 4,  prezzo = 68000,
      descrizione = 'Rumoroso. Oltre i limiti di emissione sonora è sanzionabile.' },
}

-- ---------------------------------------------------------------------------
--  Regole
-- ---------------------------------------------------------------------------
TUN.Regole = {
    -- Vetri: oltre questo grado di oscuramento è vietato sull'anteriore
    vetriMassimiOmologati = 1,
    -- Assetto: oltre questo livello serve la perizia
    assettoMassimoOmologato = 1,
    -- Sanzione per modifiche non annotate (art. 78 CdS)
    articoloSanzione = '78',
    sanzioneImporto = 43100,
    -- Il veicolo fuori norma va fermato finché non si regolarizza
    ritiroCarta = true,
    -- Manodopera: percentuale aggiunta al prezzo dei pezzi
    manodopera = 0.18,
    -- Sconto se il lavoro lo fa un meccanico in servizio
    scontoMeccanico = 0.30,
}

--- Le modifiche meccaniche che richiedono omologazione, dato lo stato del veicolo.
function TUN.RichiedeOmologazione(modifiche)
    for _, m in ipairs(TUN.Meccaniche) do
        local valore = modifiche[m.id]
        if valore ~= nil then
            if m.interruttore and valore == true then return true end
            if type(valore) == 'number' and valore >= 0 then return true end
        end
    end

    if (modifiche.finestrini or 0) > TUN.Regole.vetriMassimiOmologati then return true end
    return false
end

function TUN.GetEstetica(id)
    for _, m in ipairs(TUN.Estetiche) do if m.id == id then return m end end
    return nil
end

function TUN.GetMeccanica(id)
    for _, m in ipairs(TUN.Meccaniche) do if m.id == id then return m end end
    return nil
end
