-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — università, nautica, criptovalute
--
--  Tabelle delle risorse aggiunte con l'espansione dei servizi pubblici:
--  ita_scuola, ita_nautica, aurea_cripto.
--
--  I Vigili del Fuoco (ita_vigilfuoco) non hanno tabelle: gli incendi
--  vivono in memoria e muoiono con il riavvio, che è quello che deve
--  succedere a un incendio.
--
--  Su un'installazione nuova basta 01_schema.sql: c'è già tutto. Questo
--  file serve a chi ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/06_pubblici.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  UNIVERSITÀ E TITOLI DI STUDIO
--
--  Il titolo è quello che separa chi può fare il medico da chi vorrebbe.
--  La carriera si cancella quando arriva la laurea: quello che resta è il
--  titolo, non il percorso.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `carriere` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`        VARCHAR(12)  NOT NULL,
  `corso`            VARCHAR(32)  NOT NULL,
  `iscritto_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `prossimo_appello` DATETIME     NULL DEFAULT NULL COMMENT 'la sessione: prima di questo non si dà esame',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_iscrizione` (`citizenid`, `corso`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `esami_superati` (
  `citizenid`   VARCHAR(12) NOT NULL,
  `corso`       VARCHAR(32) NOT NULL,
  `materia`     VARCHAR(32) NOT NULL,
  `superato_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `corso`, `materia`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `titoli` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`     VARCHAR(12)  NOT NULL,
  `corso`         VARCHAR(32)  NOT NULL,
  `titolo`        VARCHAR(96)  NOT NULL,
  `abilitato`     TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = esame di Stato superato',
  `conseguito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `abilitato_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_titolo` (`citizenid`, `corso`),
  KEY `idx_pg` (`citizenid`, `abilitato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  NAUTICA: ormeggi
--
--  La patente nautica non ha una tabella sua: sta in `licenze`, come
--  quelle di pesca e caccia, con tipo = 'nautica'.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ormeggi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12) NOT NULL,
  `targa`     VARCHAR(12) NOT NULL,
  `porto`     VARCHAR(24) NOT NULL,
  `scadenza`  DATE        NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ormeggio` (`targa`),
  KEY `idx_pg` (`citizenid`),
  KEY `idx_scadenza` (`scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CRIPTOVALUTE
--
--  Le quantità sono in MILLESIMI di moneta, non in unità: una moneta che
--  vale 42.000 € l'una, comprata in unità intere, sarebbe inutilizzabile.
--  I prezzi sono in centesimi di euro, come tutto il resto del server.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `cripto_mercato` (
  `moneta`  VARCHAR(8) NOT NULL,
  `prezzo`  BIGINT     NOT NULL COMMENT 'centesimi di euro per unità',
  `storico` TEXT       DEFAULT NULL COMMENT 'JSON delle ultime quotazioni',
  PRIMARY KEY (`moneta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cripto_portafogli` (
  `citizenid` VARCHAR(12) NOT NULL,
  `moneta`    VARCHAR(8)  NOT NULL,
  `quantita`  BIGINT      NOT NULL DEFAULT 0 COMMENT 'millesimi di moneta',
  PRIMARY KEY (`citizenid`, `moneta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cripto_conti` (
  `citizenid`           VARCHAR(12) NOT NULL,
  `attenzione`          INT         NOT NULL DEFAULT 0 COMMENT 'punteggio antiriciclaggio',
  `sequestrato`         TINYINT(1)  NOT NULL DEFAULT 0,
  `ultima_segnalazione` TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_attenzione` (`attenzione`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cripto_movimenti` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`    VARCHAR(12) NOT NULL,
  `moneta`       VARCHAR(8)  NOT NULL,
  `verso`        ENUM('acquisto','vendita','invio','ricezione') NOT NULL,
  `quantita`     BIGINT      NOT NULL COMMENT 'millesimi',
  `prezzo`       BIGINT      NOT NULL COMMENT 'quotazione al momento',
  `controvalore` BIGINT      NOT NULL COMMENT 'centesimi',
  `nero`         TINYINT(1)  NOT NULL DEFAULT 0,
  `controparte`  VARCHAR(12) DEFAULT NULL,
  `momento`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `id`),
  KEY `idx_nero` (`nero`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
