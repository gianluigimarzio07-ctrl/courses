-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — protezione civile
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/10_protezionecivile.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  VOLONTARI DEL GRUPPO COMUNALE
--
--  Non è un lavoro e non ha gradi: è un elenco. `interventi` è l'unica
--  cosa che si accumula, e serve solo a riconoscere chi c'era.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pc_volontari` (
  `citizenid`   VARCHAR(12) NOT NULL,
  `nome`        VARCHAR(96) NOT NULL,
  `interventi`  INT UNSIGNED NOT NULL DEFAULT 0,
  `iscritto_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_interventi` (`interventi`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  SCENARI
--
--  I punti dei compiti non si salvano: si generano all'apertura e vivono
--  in memoria. Uno scenario interrotto da un riavvio è uno scenario
--  perso, ed è giusto così — l'emergenza è il momento in cui accade.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pc_emergenze` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`           VARCHAR(32) NOT NULL,
  `zona`           VARCHAR(96) NOT NULL,
  `allerta`        VARCHAR(16) NOT NULL DEFAULT 'verde',
  `compiti_totali` INT UNSIGNED NOT NULL DEFAULT 0,
  `compiti_fatti`  INT UNSIGNED NOT NULL DEFAULT 0,
  `partecipanti`   INT UNSIGNED NOT NULL DEFAULT 0,
  `esito`          ENUM('aperta','risolta','fallita') NOT NULL DEFAULT 'aperta',
  `aperta_il`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_esito` (`esito`, `id`),
  KEY `idx_tipo` (`tipo`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
