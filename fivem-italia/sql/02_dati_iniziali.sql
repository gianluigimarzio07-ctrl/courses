-- ============================================================================
--  AUREA · Italia Roleplay — Dati iniziali
--  Eseguire DOPO 01_schema.sql
-- ============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  Mercato dinamico: prezzi base in centesimi di euro
--  offerta/domanda partono da 100 = equilibrio; il motore economico li muove.
-- ---------------------------------------------------------------------------
INSERT INTO `mercato` (`item`, `prezzo_base`, `prezzo`, `min_mult`, `max_mult`) VALUES
  ('uva_sangiovese',     180,     180, 0.60, 2.20),
  ('uva_nebbiolo',       260,     260, 0.60, 2.40),
  ('mosto',              420,     420, 0.70, 2.00),
  ('vino_rosso',        1450,    1450, 0.70, 2.60),
  ('vino_docg',         4800,    4800, 0.80, 3.00),
  ('olive',              210,     210, 0.60, 2.20),
  ('olio_extravergine', 1900,    1900, 0.70, 2.60),
  ('olio_dop',          5200,    5200, 0.80, 3.00),
  ('latte_crudo',        140,     140, 0.60, 1.90),
  ('caglio',             320,     320, 0.80, 1.60),
  ('formaggio_fresco',  1100,    1100, 0.70, 2.20),
  ('parmigiano_dop',    6400,    6400, 0.80, 3.00),
  ('caffe_verde',        380,     380, 0.60, 2.40),
  ('caffe_tostato',     1250,    1250, 0.70, 2.40),
  ('espresso',           110,     110, 0.80, 1.60),
  ('farina_00',           95,      95, 0.70, 1.80),
  ('pomodoro_san_marzano',175,    175, 0.60, 2.20),
  ('mozzarella_bufala',  980,     980, 0.70, 2.40),
  ('pizza_margherita',   750,     750, 0.80, 1.80),
  ('tessuto_pregiato',  2200,    2200, 0.70, 2.60),
  ('capo_sartoriale',   9800,    9800, 0.80, 3.00),
  ('rame',               420,     420, 0.60, 2.40),
  ('acciaio',            310,     310, 0.60, 2.20),
  ('componenti_elettronici', 890, 890, 0.70, 2.60)
ON DUPLICATE KEY UPDATE `prezzo_base` = VALUES(`prezzo_base`);

-- ---------------------------------------------------------------------------
--  Stato macroeconomico
-- ---------------------------------------------------------------------------
INSERT INTO `economia_stato` (`chiave`, `valore`) VALUES
  ('indice_prezzi',      '100.00'),
  ('massa_monetaria',    '0'),
  ('tasso_bce',          '3.25'),
  ('spread',             '135'),
  ('ultimo_ciclo',       '0'),
  ('gettito_fiscale',    '0')
ON DUPLICATE KEY UPDATE `chiave` = `chiave`;

-- ---------------------------------------------------------------------------
--  Territori contendibili
-- ---------------------------------------------------------------------------
INSERT INTO `territori` (`codice`, `nome`, `rendita_oraria`) VALUES
  ('porto',        'Zona Portuale',          32000),
  ('mercato',      'Mercato Generale',       24000),
  ('quartiere_sud','Quartiere Sud',          28000),
  ('lungomare',    'Lungomare',              26000),
  ('zona_ind',     'Zona Industriale',       35000),
  ('centro_st',    'Centro Storico',         42000),
  ('periferia_e',  'Periferia Est',          19000),
  ('collina',      'Quartiere Collinare',    38000)
ON DUPLICATE KEY UPDATE `nome` = VALUES(`nome`);

-- ---------------------------------------------------------------------------
--  Immobili di partenza (le coordinate reali vanno regolate in gioco con /immobile crea)
-- ---------------------------------------------------------------------------
INSERT INTO `immobili` (`codice`,`nome`,`tipo`,`indirizzo`,`prezzo`,`rendita_catastale`,`ingresso`,`interno`,`garage_slot`) VALUES
  ('app_integrity_01','Integrity Way 1','appartamento','Via Integrity 1',  4500000,  38000, '{"x":-47.5,"y":-585.6,"z":37.0,"h":250.0}','shell_piccolo',0),
  ('app_integrity_02','Integrity Way 2','appartamento','Via Integrity 2',  5200000,  41000, '{"x":-31.2,"y":-593.7,"z":78.9,"h":250.0}','shell_medio',0),
  ('villa_rockford',  'Villa Rockford','villa',        'Viale Rockford 12',31500000, 210000, '{"x":-1289.4,"y":455.9,"z":97.2,"h":120.0}','shell_grande',2),
  ('attico_delperro', 'Attico Del Perro','attico',     'Del Perro 8',      24800000, 175000, '{"x":-1447.6,"y":-537.4,"z":34.7,"h":35.0}','shell_grande',1),
  ('loc_vespucci',    'Locale Vespucci','locale',      'Vespucci Blvd 44',  9800000,  92000, '{"x":-1222.9,"y":-907.0,"z":12.3,"h":30.0}','shell_locale',0),
  ('mag_porto_01',    'Magazzino Porto 1','magazzino', 'Banchina 3',       14200000, 120000, '{"x":1200.4,"y":-3115.2,"z":5.5,"h":180.0}','shell_magazzino',4)
ON DUPLICATE KEY UPDATE `nome` = VALUES(`nome`);

-- ---------------------------------------------------------------------------
--  ZTL: permessi permanenti per i mezzi di servizio (targhe speciali)
-- ---------------------------------------------------------------------------
INSERT INTO `ztl_permessi` (`zona`,`targa`,`tipo`,`scadenza`) VALUES
  ('centro_storico','CC00001','forze_ordine','2099-12-31'),
  ('centro_storico','PS00001','forze_ordine','2099-12-31'),
  ('centro_storico','118AAA1','sanitario',   '2099-12-31'),
  ('centro_storico','VF00001','soccorso',    '2099-12-31')
ON DUPLICATE KEY UPDATE `scadenza` = VALUES(`scadenza`);
