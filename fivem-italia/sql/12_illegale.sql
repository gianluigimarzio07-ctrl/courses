-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — usura, bische, corse, vigilanza privata
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/12_illegale.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  PRESTITI FRA PRIVATI
--
--  `usurario` si calcola alla stipula confrontando il TAEG con il tasso
--  soglia, e resta congelato: se domani la soglia cambia, il contratto
--  già firmato non diventa lecito per magia.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `usura_prestiti` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `creditore`     VARCHAR(12) NOT NULL,
  `debitore`      VARCHAR(12) NOT NULL,
  `capitale`      BIGINT      NOT NULL,
  `totale`        BIGINT      NOT NULL COMMENT 'quanto va restituito in tutto',
  `rate`          TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `rate_pagate`   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `rate_saltate`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `residuo`       BIGINT      NOT NULL DEFAULT 0,
  `taeg`          INT         NOT NULL DEFAULT 0 COMMENT 'punti base, es. 3250 = 32,50%',
  `usurario`      TINYINT(1)  NOT NULL DEFAULT 0,
  `stato`         ENUM('attivo','estinto','insolvente','denunciato') NOT NULL DEFAULT 'attivo',
  `prossima_rata` DATETIME    NULL DEFAULT NULL,
  `stipulato_il`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiuso_il`     TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_debitore` (`debitore`, `stato`),
  KEY `idx_creditore` (`creditore`, `stato`),
  KEY `idx_scadenze` (`stato`, `prossima_rata`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  BISCHE
--
--  Le mani non si salvano: vivono in memoria e muoiono con la serata. Qui
--  resta il registro delle serate, che è quello che interessa a chi
--  indaga: dove, quando, quanto banco, quante mani.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bische_serate` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `luogo`           VARCHAR(32) NOT NULL,
  `organizzatore`   VARCHAR(12) NOT NULL,
  `banco_iniziale`  BIGINT      NOT NULL DEFAULT 0,
  `banco_finale`    BIGINT      NOT NULL DEFAULT 0,
  `mani`            INT UNSIGNED NOT NULL DEFAULT 0,
  `esito`           ENUM('aperta','chiusa','sequestrata') NOT NULL DEFAULT 'aperta',
  `aperta_il`       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`       TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_organizzatore` (`organizzatore`, `id`),
  KEY `idx_luogo` (`luogo`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CORSE CLANDESTINE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `corse_gare` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tracciato`      VARCHAR(32) NOT NULL,
  `organizzatore`  VARCHAR(12) NOT NULL,
  `quota`          BIGINT      NOT NULL DEFAULT 0,
  `partecipanti`   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `montepremi`     BIGINT      NOT NULL DEFAULT 0,
  `esito`          ENUM('aperta','conclusa','annullata') NOT NULL DEFAULT 'aperta',
  `aperta_il`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_organizzatore` (`organizzatore`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  VIGILANZA PRIVATA
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vigilanza_decreti` (
  `citizenid`     VARCHAR(12) NOT NULL,
  `rilasciato_da` VARCHAR(96) NOT NULL DEFAULT '',
  `revocato`      TINYINT(1)  NOT NULL DEFAULT 0,
  `rilasciato_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_validi` (`revocato`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vigilanza_servizi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `guardia`     VARCHAR(12) NOT NULL,
  `valore`      BIGINT      NOT NULL DEFAULT 0,
  `filiale_da`  VARCHAR(32) NOT NULL,
  `filiale_a`   VARCHAR(32) NOT NULL,
  `esito`       ENUM('aperto','consegnato','assaltato','scaduto') NOT NULL DEFAULT 'aperto',
  `aperto_il`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiuso_il`   TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_guardia` (`guardia`, `esito`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
