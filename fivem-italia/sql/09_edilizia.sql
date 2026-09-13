-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — edilizia e sicurezza sul lavoro
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/09_edilizia.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  TITOLI EDILIZI
--
--  `silenzio_assenso` dice se il permesso è stato rilasciato dagli uffici
--  o si è formato per decorso del termine (art. 20 D.P.R. 380/2001).
--  Serve a saperlo dopo, quando qualcuno contesta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_permessi` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`        VARCHAR(12) NOT NULL,
  `lotto`            VARCHAR(32) NOT NULL,
  `silenzio_assenso` TINYINT(1)  NOT NULL DEFAULT 0,
  `consumato`        TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '1 = usato per aprire un cantiere',
  `rilasciato_il`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`         TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lotto` (`lotto`, `consumato`, `scade_il`),
  KEY `idx_titolare` (`citizenid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CANTIERI
--
--  Uno per lotto. `permesso_id` a NULL significa cantiere abusivo: è la
--  condizione che fa scattare il sequestro.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_cantieri` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lotto`         VARCHAR(32) NOT NULL,
  `impresa`       VARCHAR(32) NOT NULL COMMENT 'il lavoro dell\'ente titolare',
  `direttore`     VARCHAR(12) NOT NULL COMMENT 'il datore di lavoro, ai fini INAIL',
  `permesso_id`   INT UNSIGNED DEFAULT NULL,
  `fase`          VARCHAR(24) NOT NULL DEFAULT 'scavo',
  `lavorazioni`   INT UNSIGNED NOT NULL DEFAULT 0,
  `rischio`       INT          NOT NULL DEFAULT 0 COMMENT '0-100',
  `ponteggio`     TINYINT(1)  NOT NULL DEFAULT 0,
  `pos`           TINYINT(1)  NOT NULL DEFAULT 0 COMMENT 'piano operativo di sicurezza depositato',
  `stato`         ENUM('aperto','sospeso','consegnato','sequestrato') NOT NULL DEFAULT 'aperto',
  `sospeso_fino`  DATETIME    NULL DEFAULT NULL,
  `aperto_il`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `consegnato_il` TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperti` (`stato`, `lotto`),
  KEY `idx_impresa` (`impresa`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  INFORTUNI IN CANTIERE
--
--  Il duplicato di quanto sta in previdenza_infortuni, ma dal lato del
--  cantiere: serve a rispondere alla domanda "in quale cantiere ci si fa
--  male, e con che rischio", che è quella che fa aprire un'inchiesta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_infortuni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cantiere_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12) NOT NULL,
  `gravita`     ENUM('lieve','medio','grave') NOT NULL DEFAULT 'lieve',
  `descrizione` VARCHAR(200) NOT NULL,
  `rischio`     INT NOT NULL DEFAULT 0 COMMENT 'il rischio del cantiere al momento del fatto',
  `momento`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cantiere` (`cantiere_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ISPEZIONI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_ispezioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cantiere_id` INT UNSIGNED NOT NULL,
  `ispettore`   VARCHAR(64) NOT NULL,
  `violazioni`  JSON        DEFAULT NULL,
  `sanzione`    BIGINT      NOT NULL DEFAULT 0,
  `momento`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cantiere` (`cantiere_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
