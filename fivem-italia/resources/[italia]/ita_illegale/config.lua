--[[
    AUREA · Mercato nero — configurazione

    Quello che non si compra in negozio si compra qui, e qui si paga solo in
    contanti non tracciati: è il punto in cui i proventi dello spaccio, dei
    furti e dei colpi tornano ad essere merce.

    Il banco si sposta a ogni riavvio: chi lo vuole trovare deve cercarlo,
    e chi lo vuole sorvegliare deve rifare il lavoro ogni volta.

    Le filiere che alimentano questo mercato stanno altrove:
      · ita_droga  — coltivazione, lavorazione, taglio, piazze
      · ita_furti  — furti su veicolo, ricettazione, autodemolizione
      · ita_cayo   — il colpo all'isola
]]

ILL = {}

ILL.MercatoNero = {
    nome = 'Mercato nero',
    -- Cambia posizione a ogni riavvio fra questi punti
    posizioni = {
        vector3(-1155.0, -2033.0, 13.2),
        vector3(482.0, -1310.0, 29.2),
        vector3(1387.0, 3606.0, 34.9),
    },
    distanza = 6.0,

    catalogo = {
        -- Effrazione e veicoli
        { item = 'grimaldello',      prezzo = 145000 },
        { item = 'spadino',          prezzo = 460000 },
        { item = 'centralina',       prezzo = 720000 },
        { item = 'targa_clonata',    prezzo = 380000 },
        { item = 'jammer',           prezzo = 980000 },
        { item = 'gps_tracker',      prezzo = 220000 },
        { item = 'documento_falso',  prezzo = 640000 },
        -- Filiera degli stupefacenti
        { item = 'seme',             prezzo = 42000 },
        { item = 'annaffiatoio',     prezzo = 28000 },
        { item = 'pasta_base',       prezzo = 310000 },
        { item = 'oppio_grezzo',     prezzo = 340000 },
        { item = 'precursori',       prezzo = 280000 },
        { item = 'solvente',         prezzo = 90000 },
        { item = 'mannitolo',        prezzo = 26000 },
        { item = 'lattosio',         prezzo = 22000 },
        { item = 'caffeina',         prezzo = 34000 },
        { item = 'bilancino',        prezzo = 120000 },
        -- Attrezzatura da colpo
        { item = 'tronchesi',        prezzo = 180000 },
        { item = 'esplosivo',        prezzo = 1450000 },
        { item = 'muta',             prezzo = 390000 },
        { item = 'fotocamera',       prezzo = 260000 },
        -- Munizionamento
        { item = 'cartuccia',        prezzo = 2200 },
    },

    -- Vendita di armi clandestine: matricola abrasa, nessun registro
    armi = {
        { arma = 'WEAPON_SNSPISTOL',      prezzo = 850000 },
        { arma = 'WEAPON_MICROSMG',       prezzo = 2400000 },
        { arma = 'WEAPON_SAWNOFFSHOTGUN', prezzo = 1600000 },
        { arma = 'WEAPON_MACHETE',        prezzo = 90000 },
        { arma = 'WEAPON_KNIFE',          prezzo = 45000 },
    },

    -- Si paga solo in contanti non tracciati
    provento = 'contanti_sporchi',
    -- Valore di una banconota non tracciata
    tagliobanconota = 10000,
    -- Calore generato da un acquisto
    calore = 4,
}
