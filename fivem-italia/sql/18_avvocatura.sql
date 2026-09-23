-- =============================================================================
--  AUREA · Italia Roleplay — Consiglio dell'Ordine degli Avvocati
-- =============================================================================

-- -----------------------------------------------------------------------------
--  L'albo
--
--  citizenid è la chiave primaria: si è iscritti o non si è, non si è
--  iscritti due volte. Il che serve anche all'ON DUPLICATE KEY UPDATE del
--  rinnovo, che riscrive la riga esistente invece di accumularne altre.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avvocatura_albo` (
  `citizenid`     VARCHAR(12)  NOT NULL,
  `iscritto_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      DATETIME     NOT NULL,
  `sospeso_fino`  DATETIME     NULL DEFAULT NULL,
  `cancellato`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  KEY `idx_attivi` (`cancellato`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  I turni di reperibilità
--
--  Si conservano anche quando sono chiusi: servono a dire chi ha coperto
--  il turno quando qualcuno si lamenta di non aver trovato un difensore.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avvocatura_turni` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `aperto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`   DATETIME     NOT NULL,
  `chiuso`     TINYINT(1)   NOT NULL DEFAULT 0,
  `chiuso_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperti` (`chiuso`, `citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Ammissioni al patrocinio a spese dello Stato
--
--  `reddito` e `periodo` sono copiati dalla dichiarazione al momento
--  dell'ammissione, non letti dopo: se la dichiarazione dell'anno
--  successivo cambia, l'ammissione già concessa resta quella che era.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avvocatura_patrocini` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `reddito`     BIGINT       NOT NULL COMMENT 'imponibile accertato, centesimi',
  `periodo`     VARCHAR(16)  DEFAULT NULL,
  `ammesso_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL,
  `revocato`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `revocato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Gli incarichi difensivi
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avvocatura_incarichi` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `avvocato`     VARCHAR(12)  NOT NULL,
  `assistito`    VARCHAR(12)  NOT NULL,
  `tipo`         ENUM('fiducia','ufficio','patrocinio') NOT NULL,
  `riferimento`  VARCHAR(64)  DEFAULT NULL COMMENT 'udienza, fascicolo, interrogatorio',
  `onorario`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `a_carico`     ENUM('assistito','erario') NOT NULL DEFAULT 'assistito',
  `conferito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_avvocato` (`avvocato`),
  KEY `idx_assistito` (`assistito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Procedimenti disciplinari
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `avvocatura_disciplinare` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `sanzione`   ENUM('censura','sospensione','radiazione') NOT NULL,
  `motivo`     VARCHAR(255) NOT NULL,
  `deciso_da`  VARCHAR(12)  NOT NULL,
  `deciso_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
