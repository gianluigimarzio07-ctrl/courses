-- =============================================================================
--  AUREA · Italia Roleplay — Capitaneria di Porto e Carabinieri Forestali
--
--  Due giurisdizioni che in Italia sono separate e che qui restano tali:
--  in mare comanda la Capitaneria, nel bosco i Forestali. Le tabelle non
--  si toccano fra loro, e non è una svista.
-- =============================================================================

-- -----------------------------------------------------------------------------
--  Ordinanze della Capitaneria
--
--  Il centro è (x, y) senza z: un'ordinanza è un cerchio sulla carta
--  nautica, non una sfera.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_ordinanze` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`           ENUM('balneazione','specchio','pesca','velocita') NOT NULL,
  `centro_x`       DOUBLE       NOT NULL,
  `centro_y`       DOUBLE       NOT NULL,
  `raggio`         SMALLINT UNSIGNED NOT NULL COMMENT 'metri',
  `motivo`         VARCHAR(160) NOT NULL,
  `ufficiale`      VARCHAR(12)  DEFAULT NULL,
  `nome_ufficiale` VARCHAR(64)  DEFAULT NULL,
  `emessa_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`       DATETIME     NOT NULL,
  `revocata`       TINYINT(1)   NOT NULL DEFAULT 0,
  `revocata_il`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vigore` (`revocata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Controlli in mare
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_controlli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`       VARCHAR(10)  NOT NULL,
  `conducente`  VARCHAR(12)  NOT NULL,
  `operatore`   VARCHAR(12)  NOT NULL,
  `rilievi`     VARCHAR(255) NOT NULL,
  `sanzione`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `eseguito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_targa` (`targa`),
  KEY `idx_conducente` (`conducente`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Fermo amministrativo di un'unità
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_fermi` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`              VARCHAR(10)  NOT NULL,
  `proprietario`       VARCHAR(12)  DEFAULT NULL,
  `motivo`             VARCHAR(255) NOT NULL,
  `disposto_da`        VARCHAR(12)  DEFAULT NULL,
  `importo`            BIGINT       NOT NULL COMMENT 'centesimi del dissequestro',
  `disposto_il`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dissequestrato`     TINYINT(1)   NOT NULL DEFAULT 0,
  `dissequestrato_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperto` (`dissequestrato`, `targa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Eventi di ricerca e soccorso
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_sar` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `centro_x`   DOUBLE       NOT NULL,
  `centro_y`   DOUBLE       NOT NULL,
  `motivo`     VARCHAR(160) NOT NULL,
  `disperso`   VARCHAR(12)  DEFAULT NULL,
  `aperto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa`     TINYINT(1)   NOT NULL DEFAULT 0,
  `chiusa_il`  TIMESTAMP    NULL DEFAULT NULL,
  `esito`      ENUM('recuperato','sospesa') DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperte` (`chiusa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Incendi boschivi e vincolo decennale (art. 10 L. 353/2000)
--
--  Il vincolo è la cosa più pesante che questa risorsa sa fare: dieci
--  anni in cui su quel terreno non si costruisce e non si pascola. Serve
--  a togliere il movente a chi brucia per edificare.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `forestale_incendi` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `centro_x`      DOUBLE       NOT NULL,
  `centro_y`      DOUBLE       NOT NULL,
  `ettari`        DECIMAL(6,2) NOT NULL DEFAULT 0,
  `origine`       ENUM('ignota','colposa','dolosa','naturale') NOT NULL DEFAULT 'ignota',
  `responsabile`  VARCHAR(12)  DEFAULT NULL,
  `accertato_da`  VARCHAR(12)  DEFAULT NULL,
  `note`          VARCHAR(255) DEFAULT NULL,
  `rilevato_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `vincolo`       TINYINT(1)   NOT NULL DEFAULT 0,
  `vincolo_fino`  DATE         DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vincolo` (`vincolo`, `vincolo_fino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Verbali della vigilanza venatoria e ambientale
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `forestale_accertamenti` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`         ENUM('bracconaggio','taglio','discarica','pascolo','vincolo') NOT NULL,
  `citizenid`    VARCHAR(12)  DEFAULT NULL,
  `operatore`    VARCHAR(12)  NOT NULL,
  `luogo`        VARCHAR(96)  DEFAULT NULL,
  `descrizione`  VARCHAR(255) NOT NULL,
  `sanzione`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `sequestro`    VARCHAR(96)  DEFAULT NULL,
  `accertato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`),
  KEY `idx_tipo` (`tipo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
