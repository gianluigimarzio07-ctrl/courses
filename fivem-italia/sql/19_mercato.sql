-- =============================================================================
--  AUREA · Italia Roleplay — Mercato rionale
-- =============================================================================

-- -----------------------------------------------------------------------------
--  Concessioni di posteggio
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_concessioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `posteggio`   VARCHAR(12)  NOT NULL,
  `mercato`     VARCHAR(24)  NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `canone`      BIGINT       NOT NULL COMMENT 'centesimi, iscritti a ruolo come TOSAP',
  `assegnata_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL,
  `scaduta`     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_attive` (`scaduta`, `posteggio`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Il registro delle vendite
--
--  È la tabella su cui la Guardia di Finanza fa i conti, quindi ci finisce
--  ogni singola vendita — anche e soprattutto quelle senza scontrino. Un
--  registro che annota solo le vendite battute non serve a controllare
--  niente: sarebbe sempre in ordine per definizione.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_vendite` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`      VARCHAR(12)  NOT NULL,
  `posteggio`      VARCHAR(12)  NOT NULL,
  `item`           VARCHAR(48)  NOT NULL,
  `quantita`       INT          NOT NULL DEFAULT 1,
  `importo`        BIGINT       NOT NULL COMMENT 'lordo al pubblico, centesimi',
  `scontrino`      TINYINT(1)   NOT NULL DEFAULT 0,
  `certificazione` VARCHAR(12)  DEFAULT NULL COMMENT 'IGP, DOP, DOCG, BIO',
  `venduto_il`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sessione` (`citizenid`, `venduto_il`),
  KEY `idx_scontrino` (`scontrino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Controlli sui corrispettivi
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_controlli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL COMMENT 'l\'esercente controllato',
  `operatore`   VARCHAR(12)  NOT NULL,
  `posteggio`   VARCHAR(12)  NOT NULL,
  `vendite`     INT          NOT NULL DEFAULT 0,
  `non_battute` INT          NOT NULL DEFAULT 0,
  `sanzione`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `sospeso`     TINYINT(1)   NOT NULL DEFAULT 0,
  `eseguito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
