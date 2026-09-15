-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — vigilanza igienico-sanitaria e rifiuti speciali
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/13_ambiente_igiene.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  IGIENE DEGLI ESERCIZI
--
--  Una riga per locale. L'igiene scende da sola: salvarla ogni tanto
--  serve perché un riavvio non ripulisca le cucine.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `asl_locali` (
  `locale` VARCHAR(32) NOT NULL,
  `igiene` TINYINT UNSIGNED NOT NULL DEFAULT 92,
  PRIMARY KEY (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `asl_haccp` (
  `locale`        VARCHAR(32) NOT NULL,
  `depositato_da` VARCHAR(12) NOT NULL,
  `depositato_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`locale`),
  KEY `idx_validi` (`scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `asl_eventi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `locale`    VARCHAR(32)  NOT NULL,
  `tipo`      ENUM('ispezione','tossinfezione','sospensione') NOT NULL,
  `igiene`    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `dettaglio` VARCHAR(400) NOT NULL DEFAULT '',
  `momento`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_locale` (`locale`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  RIFIUTI SPECIALI
--
--  Il registro di carico e scarico è la cosa che regge il modulo: la
--  differenza fra prodotti e (smaltiti + in carico) è quello che è
--  finito da qualche parte, e non si cancella.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rifiuti_registro` (
  `citizenid`     VARCHAR(12) NOT NULL,
  `prodotti`      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'chili',
  `smaltiti`      INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'chili con formulario',
  `in_carico`     INT UNSIGNED NOT NULL DEFAULT 0,
  `scaricati`     INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'chili lasciati fuori impianto',
  `ultimo_codice` VARCHAR(16) DEFAULT NULL COMMENT 'codice CER prevalente',
  PRIMARY KEY (`citizenid`),
  KEY `idx_scaricati` (`scaricati`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rifiuti_formulari` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `produttore` VARCHAR(12) NOT NULL,
  `chili`      INT UNSIGNED NOT NULL,
  `codice`     VARCHAR(16) NOT NULL DEFAULT 'CER 20',
  `costo`      BIGINT      NOT NULL DEFAULT 0,
  `emesso_il`  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_produttore` (`produttore`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rifiuti_siti` (
  `sito`           VARCHAR(32) NOT NULL,
  `chili`          INT UNSIGNED NOT NULL DEFAULT 0,
  `contaminazione` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `segnalato`      TINYINT(1)  NOT NULL DEFAULT 0,
  PRIMARY KEY (`sito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rifiuti_scarichi` (
  `id`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sito`    VARCHAR(32) NOT NULL,
  `autore`  VARCHAR(12) NOT NULL,
  `chili`   INT UNSIGNED NOT NULL,
  `momento` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sito` (`sito`, `id`),
  KEY `idx_autore` (`autore`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
