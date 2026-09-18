-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — catasto, agricoltura, parrocchia,
--  misure di prevenzione, pesca professionale, ferrovie
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/14_territorio.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  CATASTO
--
--  `catasto_schede.intestato_a` è una cosa diversa da
--  `immobili.proprietario`: fra i due c'è la voltura, e finché non è
--  presentata l'IMU la paga chi ha venduto.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `catasto_schede` (
  `immobile_id`    INT UNSIGNED NOT NULL,
  `categoria`      VARCHAR(8)  NOT NULL DEFAULT 'A2',
  `rendita`        BIGINT      NOT NULL DEFAULT 0,
  `intestato_a`    VARCHAR(12) DEFAULT NULL,
  `lotto`          VARCHAR(32) DEFAULT NULL COMMENT 'il lotto edilizio da cui nasce',
  `aggiornata_il`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`immobile_id`),
  KEY `idx_intestatario` (`intestato_a`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `catasto_pratiche` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`          ENUM('accatastamento','voltura') NOT NULL,
  `lotto`         VARCHAR(32)  DEFAULT NULL,
  `immobile_id`   INT UNSIGNED DEFAULT NULL,
  `denominazione` VARCHAR(96)  NOT NULL DEFAULT '',
  `categoria`     VARCHAR(8)   DEFAULT NULL,
  `volumetria`    INT UNSIGNED NOT NULL DEFAULT 0,
  `richiedente`   VARCHAR(12)  NOT NULL,
  `impresa`       VARCHAR(32)  DEFAULT NULL,
  `stato`         ENUM('da_presentare','evasa','scaduta') NOT NULL DEFAULT 'da_presentare',
  `sanzionata`    TINYINT(1)   NOT NULL DEFAULT 0,
  `aperta_il`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP    NULL DEFAULT NULL,
  `evasa_il`      TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_richiedente` (`richiedente`, `stato`),
  KEY `idx_scadenze` (`stato`, `sanzionata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  AGRICOLTURA
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `agri_poderi` (
  `podere`         VARCHAR(32) NOT NULL,
  `conduttore`     VARCHAR(12) NOT NULL,
  `canoni_saltati` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `preso_il`       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`podere`),
  KEY `idx_conduttore` (`conduttore`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `agri_solchi` (
  `podere`      VARCHAR(32) NOT NULL,
  `solco`       TINYINT UNSIGNED NOT NULL,
  `coltura`     VARCHAR(24) DEFAULT NULL,
  `arato`       TINYINT(1)  NOT NULL DEFAULT 0,
  `seminato_il` DATETIME    NULL DEFAULT NULL,
  `irrigazioni` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `fertilita`   TINYINT UNSIGNED NOT NULL DEFAULT 100,
  PRIMARY KEY (`podere`, `solco`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `agri_pac` (
  `citizenid`         VARCHAR(12) NOT NULL,
  `ettari_dichiarati` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `presentata_il`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`          TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_valide` (`scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  PARROCCHIA
--
--  Non c'è nessuna tabella per le confessioni, e non è una dimenticanza:
--  art. 200 c.p.p. è il motivo per cui quei dati non esistono. Qui si
--  contano soltanto, per sapere se il parroco ha lavorato.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `chiesa_stato` (
  `id`           TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `confessioni`  INT UNSIGNED NOT NULL DEFAULT 0,
  `offerte`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `chiesa_stato` (`id`) VALUES (1);

CREATE TABLE IF NOT EXISTS `chiesa_riti` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`       VARCHAR(24) NOT NULL,
  `celebrante` VARCHAR(96) NOT NULL DEFAULT '',
  `soggetto_a` VARCHAR(12) NOT NULL,
  `soggetto_b` VARCHAR(12) DEFAULT NULL,
  `momento`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_soggetto` (`soggetto_a`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  MISURE DI PREVENZIONE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `antimafia_procedimenti` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `proposto`     VARCHAR(12) NOT NULL,
  `patrimonio`   BIGINT      NOT NULL DEFAULT 0,
  `reddito`      BIGINT      NOT NULL DEFAULT 0,
  `giustificato` BIGINT      NOT NULL DEFAULT 0,
  `confiscato`   BIGINT      NOT NULL DEFAULT 0,
  `proponente`   VARCHAR(96) NOT NULL DEFAULT '',
  `esito`        ENUM('aperto','confisca','archiviato') NOT NULL DEFAULT 'aperto',
  `aperto_il`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`     TIMESTAMP   NULL DEFAULT NULL,
  `chiuso_il`    TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_proposto` (`proposto`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `antimafia_beni` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `procedimento_id` INT UNSIGNED NOT NULL,
  `immobile_id`     INT UNSIGNED DEFAULT NULL,
  `descrizione`     VARCHAR(160) NOT NULL DEFAULT '',
  `valore`          BIGINT       NOT NULL DEFAULT 0,
  `destinazione`    VARCHAR(24)  DEFAULT NULL,
  `destinato_da`    VARCHAR(96)  DEFAULT NULL,
  `destinato_il`    TIMESTAMP    NULL DEFAULT NULL,
  `confiscato_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_da_destinare` (`destinazione`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `antimafia_sorveglianze` (
  `citizenid`  VARCHAR(12) NOT NULL,
  `revocata`   TINYINT(1)  NOT NULL DEFAULT 0,
  `imposta_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`   TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_attive` (`revocata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  PESCA PROFESSIONALE
--
--  Le quote sono un bene comune: una riga per specie, condivisa da tutti.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pesca_quote` (
  `specie`    VARCHAR(24) NOT NULL,
  `consumata` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`specie`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pesca_licenze` (
  `citizenid`     VARCHAR(12) NOT NULL,
  `revocata`      TINYINT(1)  NOT NULL DEFAULT 0,
  `rilasciata_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_valide` (`revocata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pesca_sbarchi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12) NOT NULL,
  `specie`      VARCHAR(24) NOT NULL,
  `quantita`    INT UNSIGNED NOT NULL DEFAULT 0,
  `incasso`     BIGINT      NOT NULL DEFAULT 0,
  `dichiarato`  TINYINT(1)  NOT NULL DEFAULT 1,
  `momento`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pescatore` (`citizenid`, `id`),
  KEY `idx_nero` (`dichiarato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  FERROVIE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ferrovie_corse` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `linea`           VARCHAR(16) NOT NULL,
  `macchinista`     VARCHAR(12) NOT NULL,
  `ritardo_secondi` INT UNSIGNED NOT NULL DEFAULT 0,
  `compenso`        BIGINT      NOT NULL DEFAULT 0,
  `partita_il`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`       TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_macchinista` (`macchinista`, `chiusa_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
