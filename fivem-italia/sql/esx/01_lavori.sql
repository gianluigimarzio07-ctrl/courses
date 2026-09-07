-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — lavori AUREA dentro le tabelle ESX
--
--  Serve SOLO in modalità "AUREA su ESX" ([esx]/aurea_esx), dove il vero
--  es_extended è il framework e vuole trovare i lavori nelle sue tabelle
--  `jobs` e `job_grades`.
--
--  Se invece usi [esx]/es_extended (ESX costruito sopra AUREA) questo file
--  NON serve: lì i lavori li legge direttamente dal catalogo AUREA e le
--  tabelle ESX non esistono nemmeno.
--
--  Generato da aurea_core/shared/lavori.lua: se aggiungi un lavoro là,
--  rigenera e riesegui questo.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/esx/01_lavori.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- Le due tabelle ESX, se il tuo es_extended non le ha già create.
CREATE TABLE IF NOT EXISTS `jobs` (
  `name`  VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) DEFAULT NULL,
  `whitelisted` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `job_grades` (
  `id`        INT NOT NULL AUTO_INCREMENT,
  `job_name`  VARCHAR(50) DEFAULT NULL,
  `grade`     INT NOT NULL,
  `name`      VARCHAR(50) DEFAULT NULL,
  `label`     VARCHAR(50) DEFAULT NULL,
  `salary`    INT NOT NULL,
  `skin_male`   LONGTEXT DEFAULT NULL,
  `skin_female` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_job_grade` (`job_name`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Lavori
--
--  Gli stipendi ESX sono in euro interi: qui sono i centesimi AUREA divisi
--  per cento e arrotondati. Sotto l'euro ESX non sa contare, e su questo
--  campo non è un problema perché serve solo alla paga automatica di ESX,
--  che in modalità AUREA resta spenta.
-- ---------------------------------------------------------------------------

INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
  ('disoccupato', 'Disoccupato', 0),
  ('corriere', 'Corriere espresso', 0),
  ('tassista', 'Taxi', 0),
  ('meccanico', 'Officina', 0),
  ('ristoratore', 'Ristorazione', 0),
  ('giornalista', 'Redazione', 0),
  ('avvocato', 'Studio legale', 1),
  ('carabinieri', 'Arma dei Carabinieri', 1),
  ('polizia', 'Polizia di Stato', 1),
  ('guardia_finanza', 'Guardia di Finanza', 1),
  ('118', 'Emergenza Sanitaria 118', 1),
  ('vigili_fuoco', 'Vigili del Fuoco', 1),
  ('comune', 'Comune', 1),
  ('agenzia_entrate', 'Agenzia delle Entrate', 1),
  ('motorizzazione', 'Motorizzazione Civile', 1),
  ('camionista', 'Autotrasporti', 0),
  ('netturbino', 'Nettezza urbana', 0),
  ('benzinaio', 'Distribuzione carburanti', 0),
  ('elettricista', 'Rete elettrica', 0),
  ('autista', 'Trasporto pubblico', 0),
  ('ausiliario', 'Ausiliari del traffico', 0),
  ('barista', 'Bar', 0),
  ('cuoco', 'Cucina', 0),
  ('medico', 'Medicina di base', 1),
  ('giudice', 'Magistratura', 1),
  ('penitenziaria', 'Polizia Penitenziaria', 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `whitelisted` = VALUES(`whitelisted`);

INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
  ('disoccupato', 0, '0', 'Nessuna occupazione', 35),
  ('corriere', 0, '0', 'Fattorino', 90),
  ('corriere', 1, '1', 'Corriere', 120),
  ('corriere', 2, '2', 'Capo turno', 155),
  ('tassista', 0, '0', 'Tassista', 95),
  ('tassista', 1, '1', 'Tassista senior', 130),
  ('tassista', 2, '2', 'Titolare licenza', 170),
  ('meccanico', 0, '0', 'Apprendista', 100),
  ('meccanico', 1, '1', 'Meccanico', 145),
  ('meccanico', 2, '2', 'Capo officina', 190),
  ('meccanico', 3, '3', 'Titolare', 240),
  ('ristoratore', 0, '0', 'Cameriere', 90),
  ('ristoratore', 1, '1', 'Cuoco', 135),
  ('ristoratore', 2, '2', 'Chef', 180),
  ('ristoratore', 3, '3', 'Titolare', 230),
  ('giornalista', 0, '0', 'Praticante', 95),
  ('giornalista', 1, '1', 'Cronista', 140),
  ('giornalista', 2, '2', 'Caporedattore', 200),
  ('avvocato', 0, '0', 'Praticante', 120),
  ('avvocato', 1, '1', 'Avvocato', 200),
  ('avvocato', 2, '2', 'Penalista', 280),
  ('carabinieri', 0, '0', 'Carabiniere', 150),
  ('carabinieri', 1, '1', 'Appuntato', 175),
  ('carabinieri', 2, '2', 'Brigadiere', 200),
  ('carabinieri', 3, '3', 'Maresciallo', 240),
  ('carabinieri', 4, '4', 'Luogotenente', 280),
  ('carabinieri', 5, '5', 'Tenente', 330),
  ('carabinieri', 6, '6', 'Capitano', 390),
  ('carabinieri', 7, '7', 'Comandante di Compagnia', 460),
  ('polizia', 0, '0', 'Agente', 150),
  ('polizia', 1, '1', 'Assistente', 175),
  ('polizia', 2, '2', 'Sovrintendente', 205),
  ('polizia', 3, '3', 'Ispettore', 250),
  ('polizia', 4, '4', 'Commissario', 320),
  ('polizia', 5, '5', 'Questore', 450),
  ('guardia_finanza', 0, '0', 'Finanziere', 160),
  ('guardia_finanza', 1, '1', 'Brigadiere', 190),
  ('guardia_finanza', 2, '2', 'Maresciallo', 230),
  ('guardia_finanza', 3, '3', 'Capitano', 340),
  ('118', 0, '0', 'Soccorritore', 140),
  ('118', 1, '1', 'Infermiere', 185),
  ('118', 2, '2', 'Medico', 260),
  ('118', 3, '3', 'Primario', 360),
  ('vigili_fuoco', 0, '0', 'Vigile', 145),
  ('vigili_fuoco', 1, '1', 'Capo squadra', 190),
  ('vigili_fuoco', 2, '2', 'Capo reparto', 250),
  ('comune', 0, '0', 'Impiegato', 120),
  ('comune', 1, '1', 'Funzionario', 170),
  ('comune', 2, '2', 'Dirigente', 240),
  ('comune', 3, '3', 'Sindaco', 350),
  ('agenzia_entrate', 0, '0', 'Operatore', 130),
  ('agenzia_entrate', 1, '1', 'Funzionario', 190),
  ('agenzia_entrate', 2, '2', 'Direttore', 280),
  ('motorizzazione', 0, '0', 'Esaminatore', 140),
  ('motorizzazione', 1, '1', 'Direttore', 220),
  ('camionista', 0, '0', 'Autista', 110),
  ('camionista', 1, '1', 'Autista esperto', 150),
  ('camionista', 2, '2', 'Titolare', 200),
  ('netturbino', 0, '0', 'Operatore ecologico', 105),
  ('netturbino', 1, '1', 'Caposquadra', 140),
  ('benzinaio', 0, '0', 'Addetto', 115),
  ('benzinaio', 1, '1', 'Autista cisterna', 160),
  ('elettricista', 0, '0', 'Operaio', 130),
  ('elettricista', 1, '1', 'Tecnico', 180),
  ('autista', 0, '0', 'Autista di linea', 125),
  ('autista', 1, '1', 'Controllore', 150),
  ('autista', 2, '2', 'Capo deposito', 190),
  ('ausiliario', 0, '0', 'Ausiliario', 110),
  ('ausiliario', 1, '1', 'Coordinatore', 150),
  ('barista', 0, '0', 'Barista', 100),
  ('barista', 1, '1', 'Titolare', 160),
  ('cuoco', 0, '0', 'Aiuto cuoco', 110),
  ('cuoco', 1, '1', 'Cuoco', 155),
  ('cuoco', 2, '2', 'Chef', 210),
  ('medico', 0, '0', 'Medico', 220),
  ('medico', 1, '1', 'Primario', 300),
  ('giudice', 0, '0', 'Magistrato', 300),
  ('giudice', 1, '1', 'Presidente', 400),
  ('penitenziaria', 0, '0', 'Agente', 150),
  ('penitenziaria', 1, '1', 'Sovrintendente', 190)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `salary` = VALUES(`salary`);

-- ---------------------------------------------------------------------------
--  Aggancio fra il personaggio AUREA e l'utente ESX
--
--  ESX identifica con `identifier` (di solito license:xxx). AUREA con
--  citizenid. Questa colonna tiene insieme le due cose: senza, a ogni
--  accesso nascerebbe un personaggio nuovo.
-- ---------------------------------------------------------------------------
ALTER TABLE `personaggi`
  ADD COLUMN IF NOT EXISTS `esx_identifier` VARCHAR(64) DEFAULT NULL
  COMMENT 'identifier ESX del proprietario, solo in modalità AUREA su ESX';

ALTER TABLE `personaggi`
  ADD INDEX IF NOT EXISTS `idx_esx` (`esx_identifier`);
