--[[
    AUREA · Catalogo oggetti

    Campi:
      etichetta   nome mostrato in italiano
      peso        grammi per unità
      impilabile  se più unità occupano lo stesso slot
      unico       se ogni istanza ha metadata proprie (documenti, armi, lotti)
      usabile     se ha un effetto all'uso
      descrizione testo nell'inventario
      categoria   per i filtri della UI
      degrada     minuti di deperibilità (alimentari freschi), nil = non deperisce
]]

AUREA = AUREA or {}
AUREA.Item = {}

local function I(nome, dati)
    dati.nome = nome
    dati.peso = dati.peso or 100
    if dati.impilabile == nil then dati.impilabile = true end
    dati.categoria = dati.categoria or 'varie'
    AUREA.Item[nome] = dati
    return dati
end

-- ---------------------------------------------------------------------------
--  DOCUMENTI  (unici: portano metadata con i dati anagrafici)
-- ---------------------------------------------------------------------------
I('carta_identita',   { etichetta = "Carta d'identità",    peso = 5,  impilabile = false, unico = true, usabile = true, categoria = 'documenti', descrizione = "Documento di riconoscimento rilasciato dal Comune." })
I('patente',          { etichetta = 'Patente di guida',    peso = 5,  impilabile = false, unico = true, usabile = true, categoria = 'documenti', descrizione = 'Abilitazione alla guida. Ha 20 punti.' })
I('tessera_sanitaria',{ etichetta = 'Tessera sanitaria',   peso = 5,  impilabile = false, unico = true, usabile = true, categoria = 'documenti', descrizione = 'Codice fiscale e assistenza SSN.' })
I('libretto',         { etichetta = 'Libretto di circolazione', peso = 10, impilabile = false, unico = true, usabile = true, categoria = 'documenti', descrizione = 'Documento del veicolo.' })
I('assicurazione',    { etichetta = 'Certificato assicurativo', peso = 5, impilabile = false, unico = true, usabile = true, categoria = 'documenti' })
I('porto_armi',       { etichetta = "Porto d'armi",        peso = 5,  impilabile = false, unico = true, usabile = true, categoria = 'documenti' })
I('tesserino',        { etichetta = 'Tesserino di servizio', peso = 5, impilabile = false, unico = true, usabile = true, categoria = 'documenti' })
I('visura',           { etichetta = 'Visura camerale',     peso = 20, impilabile = false, unico = true, usabile = true, categoria = 'documenti' })
I('fattura',          { etichetta = 'Fattura',             peso = 5,  impilabile = false, unico = true, usabile = true, categoria = 'documenti' })
I('verbale',          { etichetta = 'Verbale di contestazione', peso = 5, impilabile = false, unico = true, usabile = true, categoria = 'documenti' })

-- ---------------------------------------------------------------------------
--  ELETTRONICA
-- ---------------------------------------------------------------------------
I('telefono',         { etichetta = 'Smartphone',   peso = 180, impilabile = false, unico = true, usabile = true, categoria = 'elettronica', descrizione = 'Chiamate, SMS, banca, SPID, annunci.' })
I('radio',            { etichetta = 'Radio ricetrasmittente', peso = 400, impilabile = false, unico = true, usabile = true, categoria = 'elettronica' })
I('laptop',           { etichetta = 'Portatile',    peso = 1800, impilabile = false, unico = true, usabile = true, categoria = 'elettronica' })
I('gps_tracker',      { etichetta = 'Localizzatore GPS', peso = 90, usabile = true, categoria = 'elettronica' })
I('jammer',           { etichetta = 'Disturbatore di frequenze', peso = 900, impilabile = false, unico = true, usabile = true, categoria = 'illegale' })
I('powerbank',        { etichetta = 'Batteria portatile', peso = 250, usabile = true, categoria = 'elettronica' })
I('componenti_elettronici', { etichetta = 'Componenti elettronici', peso = 120, categoria = 'materiali' })

-- ---------------------------------------------------------------------------
--  CIBO E BEVANDE  (italiano, con deperibilità)
-- ---------------------------------------------------------------------------
I('acqua',            { etichetta = 'Acqua naturale 0,5L', peso = 520, usabile = true, categoria = 'bevande', effetto = { sete = 25 } })
I('acqua_frizzante',  { etichetta = 'Acqua frizzante 0,5L', peso = 520, usabile = true, categoria = 'bevande', effetto = { sete = 25 } })
I('espresso',         { etichetta = 'Caffè espresso', peso = 60, usabile = true, categoria = 'bevande', effetto = { sete = 8, stress = -6, energia = 12 } })
I('cappuccino',       { etichetta = 'Cappuccino', peso = 220, usabile = true, categoria = 'bevande', effetto = { sete = 18, fame = 6, stress = -5 } })
I('spritz',           { etichetta = 'Spritz', peso = 300, usabile = true, categoria = 'alcolici', effetto = { sete = 15, alcol = 12, stress = -12 } })
I('vino_rosso',       { etichetta = 'Vino rosso', peso = 1250, usabile = true, categoria = 'alcolici', effetto = { sete = 10, alcol = 22, stress = -15 } })
I('vino_docg',        { etichetta = 'Vino DOCG', peso = 1250, impilabile = false, unico = true, usabile = true, categoria = 'alcolici', effetto = { sete = 10, alcol = 24, stress = -25 } })
I('birra',            { etichetta = 'Birra artigianale', peso = 660, usabile = true, categoria = 'alcolici', effetto = { sete = 20, alcol = 14, stress = -10 } })
I('amaro',            { etichetta = 'Amaro', peso = 200, usabile = true, categoria = 'alcolici', effetto = { alcol = 30, stress = -18 } })
I('panino',           { etichetta = 'Panino', peso = 250, usabile = true, categoria = 'cibo', degrada = 240, effetto = { fame = 30 } })
I('pizza_margherita', { etichetta = 'Pizza margherita', peso = 550, usabile = true, categoria = 'cibo', degrada = 90, effetto = { fame = 55, stress = -8 } })
I('pasta_carbonara',  { etichetta = 'Pasta alla carbonara', peso = 450, usabile = true, categoria = 'cibo', degrada = 60, effetto = { fame = 60, stress = -10 } })
I('cornetto',         { etichetta = 'Cornetto', peso = 90, usabile = true, categoria = 'cibo', degrada = 300, effetto = { fame = 18 } })
I('parmigiano_dop',   { etichetta = 'Parmigiano Reggiano DOP', peso = 1000, impilabile = false, unico = true, usabile = true, categoria = 'cibo', effetto = { fame = 40 } })
I('mozzarella_bufala',{ etichetta = 'Mozzarella di bufala', peso = 250, usabile = true, categoria = 'cibo', degrada = 720, effetto = { fame = 28 } })
I('olio_extravergine',{ etichetta = 'Olio extravergine', peso = 950, categoria = 'cibo' })
I('olio_dop',         { etichetta = 'Olio EVO DOP', peso = 950, impilabile = false, unico = true, categoria = 'cibo' })

-- ---------------------------------------------------------------------------
--  MATERIE PRIME · filiere Made in Italy
-- ---------------------------------------------------------------------------
I('uva_sangiovese',   { etichetta = 'Uva Sangiovese', peso = 900, categoria = 'materiali', degrada = 2880 })
I('uva_nebbiolo',     { etichetta = 'Uva Nebbiolo', peso = 900, categoria = 'materiali', degrada = 2880 })
I('mosto',            { etichetta = 'Mosto', peso = 1200, categoria = 'materiali' })
I('olive',            { etichetta = 'Olive', peso = 800, categoria = 'materiali', degrada = 4320 })
I('latte_crudo',      { etichetta = 'Latte crudo', peso = 1030, categoria = 'materiali', degrada = 1440 })
I('caglio',           { etichetta = 'Caglio', peso = 200, categoria = 'materiali' })
I('formaggio_fresco', { etichetta = 'Formaggio fresco', peso = 700, categoria = 'cibo', degrada = 4320 })
I('caffe_verde',      { etichetta = 'Caffè verde', peso = 500, categoria = 'materiali' })
I('caffe_tostato',    { etichetta = 'Caffè tostato', peso = 480, categoria = 'materiali' })
I('farina_00',        { etichetta = 'Farina 00', peso = 1000, categoria = 'materiali' })
I('impasto_pizza',    { etichetta = 'Panetto di impasto', peso = 280, categoria = 'materiali', degrada = 720 })
I('pomodoro_san_marzano', { etichetta = 'Pomodoro San Marzano', peso = 800, categoria = 'materiali', degrada = 5760 })
I('tessuto_pregiato', { etichetta = 'Tessuto pregiato', peso = 600, categoria = 'materiali' })
I('capo_sartoriale',  { etichetta = 'Capo sartoriale', peso = 900, impilabile = false, unico = true, categoria = 'moda' })
I('rame',             { etichetta = 'Rame', peso = 400, categoria = 'materiali' })
I('acciaio',          { etichetta = 'Acciaio', peso = 700, categoria = 'materiali' })
I('plastica',         { etichetta = 'Plastica', peso = 200, categoria = 'materiali' })
I('vetro',            { etichetta = 'Vetro', peso = 500, categoria = 'materiali' })

-- ---------------------------------------------------------------------------
--  SANITÀ
-- ---------------------------------------------------------------------------
I('kit_medico',       { etichetta = 'Kit medico', peso = 1200, usabile = true, categoria = 'sanita', descrizione = 'Riporta la salute a livello stabile. Uso professionale.' })
I('bendaggio',        { etichetta = 'Bendaggio', peso = 120, usabile = true, categoria = 'sanita', descrizione = 'Ferma una emorragia leggera.' })
I('antidolorifico',   { etichetta = 'Antidolorifico', peso = 40, usabile = true, categoria = 'sanita' })
I('adrenalina',       { etichetta = 'Adrenalina', peso = 90, usabile = true, categoria = 'sanita', descrizione = 'Rianimazione di emergenza. Solo personale 118.' })
I('stecca',           { etichetta = 'Stecca ortopedica', peso = 300, usabile = true, categoria = 'sanita' })
I('sacca_sangue',     { etichetta = 'Sacca di sangue', peso = 500, usabile = true, categoria = 'sanita' })

-- ---------------------------------------------------------------------------
--  FORZE DELL'ORDINE
-- ---------------------------------------------------------------------------
I('manette',          { etichetta = 'Manette', peso = 450, impilabile = false, usabile = true, categoria = 'servizio' })
I('etilometro',       { etichetta = 'Etilometro', peso = 600, impilabile = false, usabile = true, categoria = 'servizio' })
I('telelaser',        { etichetta = 'Telelaser', peso = 1500, impilabile = false, usabile = true, categoria = 'servizio' })
I('kit_rilievi',      { etichetta = 'Kit rilievi', peso = 2200, impilabile = false, usabile = true, categoria = 'servizio' })
I('paletta',          { etichetta = 'Paletta segnaletica', peso = 300, impilabile = false, usabile = true, categoria = 'servizio' })
I('spray_urticante',  { etichetta = 'Spray urticante', peso = 150, usabile = true, categoria = 'servizio' })
I('dissuasore',       { etichetta = 'Striscia chiodata', peso = 4000, impilabile = false, usabile = true, categoria = 'servizio' })

-- ---------------------------------------------------------------------------
--  ILLEGALE
-- ---------------------------------------------------------------------------
I('grimaldello',      { etichetta = 'Grimaldello', peso = 120, usabile = true, categoria = 'illegale' })
I('chiave_inglese',   { etichetta = 'Chiave inglese', peso = 800, usabile = true, categoria = 'attrezzi' })
I('contanti_sporchi', { etichetta = 'Contanti non tracciati', peso = 2, categoria = 'illegale', descrizione = 'Vanno ripuliti prima di poter essere versati.' })
I('cartuccia',        { etichetta = 'Munizioni', peso = 12, categoria = 'illegale' })
I('sostanza_grezza',  { etichetta = 'Sostanza grezza', peso = 30, categoria = 'illegale' })
I('sostanza_raffinata',{ etichetta = 'Sostanza raffinata', peso = 25, categoria = 'illegale' })
I('documento_falso',  { etichetta = 'Documento contraffatto', peso = 5, impilabile = false, unico = true, usabile = true, categoria = 'illegale' })
I('targa_clonata',    { etichetta = 'Targa clonata', peso = 300, impilabile = false, unico = true, usabile = true, categoria = 'illegale' })

-- ---------------------------------------------------------------------------
--  ATTREZZI E VARIE
-- ---------------------------------------------------------------------------
I('kit_riparazione',  { etichetta = 'Kit riparazione', peso = 2500, usabile = true, categoria = 'attrezzi' })
I('tanica',           { etichetta = 'Tanica di carburante', peso = 8000, impilabile = false, unico = true, usabile = true, categoria = 'attrezzi' })
I('cavi_avviamento',  { etichetta = 'Cavi di avviamento', peso = 1500, usabile = true, categoria = 'attrezzi' })
I('corda',            { etichetta = 'Corda', peso = 900, usabile = true, categoria = 'attrezzi' })
I('borsone',          { etichetta = 'Borsone', peso = 1500, impilabile = false, unico = true, usabile = true, categoria = 'contenitori', contenitore = { slot = 20, peso = 25000 } })
I('valigetta',        { etichetta = 'Valigetta', peso = 1200, impilabile = false, unico = true, usabile = true, categoria = 'contenitori', contenitore = { slot = 10, peso = 12000 } })
I('chiavi_casa',      { etichetta = 'Mazzo di chiavi', peso = 60, impilabile = false, unico = true, usabile = true, categoria = 'varie' })
I('biglietto_lotteria',{ etichetta = 'Gratta e vinci', peso = 5, usabile = true, categoria = 'varie' })

--- Restituisce i dati di un oggetto o nil.
function AUREA.GetItem(nome)
    return AUREA.Item[nome]
end

--- Peso totale (in grammi) di una lista di item {nome, quantita}
function AUREA.PesoLista(lista)
    local tot = 0
    for _, riga in ipairs(lista or {}) do
        local dati = AUREA.Item[riga.nome or riga.item]
        if dati then tot = tot + (dati.peso * (riga.quantita or 1)) end
    end
    return tot
end

return AUREA.Item
