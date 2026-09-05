-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — servizi e vita civile
--
--  Tabelle delle trenta risorse aggiunte dopo l'espansione: animali,
--  poste, scommesse, sosta, supporto, whitelist, onoranze funebri.
--
--  Su un'installazione nuova basta 01_schema.sql: queste tabelle sono
--  già lì. Questo file serve a chi ha un database più vecchio.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/04_servizi.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  Il personaggio sepolto resta in anagrafe ma non si gioca più.
--  Su MySQL 8 / MariaDB 10.3+ questa riga è idempotente.
-- ---------------------------------------------------------------------------
ALTER TABLE `personaggi`
  ADD COLUMN IF NOT EXISTS `attivo` TINYINT(1) NOT NULL DEFAULT 1
  COMMENT '0 = sepolto: resta in anagrafe ma non si gioca';

-- ---------------------------------------------------------------------------
--  Animali domestici e anagrafe canina
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `animali` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `proprietario`  VARCHAR(12)  NOT NULL,
  `nome`          VARCHAR(24)  NOT NULL,
  `razza`         VARCHAR(24)  NOT NULL,
  `fame`          TINYINT UNSIGNED NOT NULL DEFAULT 100,
  `affetto`       TINYINT UNSIGNED NOT NULL DEFAULT 50,
  `microchip`     TINYINT(1)   NOT NULL DEFAULT 0,
  `fuggito`       TINYINT(1)   NOT NULL DEFAULT 0,
  `adottato_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `aggiornato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_prop` (`proprietario`, `fuggito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Poste: lettere, raccomandate, pacchi
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `corrispondenza` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`          ENUM('lettera','raccomandata','pacco') NOT NULL DEFAULT 'lettera',
  `mittente`      VARCHAR(12)  NOT NULL,
  `mittente_nome` VARCHAR(64)  NOT NULL,
  `destinatario`  VARCHAR(12)  NOT NULL,
  `oggetto`       VARCHAR(96)  NOT NULL DEFAULT '',
  `testo`         TEXT         DEFAULT NULL,
  `contenitore`   VARCHAR(64)  DEFAULT NULL COMMENT 'id contenitore, solo per i pacchi',
  `ritirata`      TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '0 in giacenza, 1 ritirata, 2 tornata al mittente',
  `spedita_il`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ritirata_il`   TIMESTAMP    NULL DEFAULT NULL,
  `scade_il`      TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_dest` (`destinatario`, `ritirata`),
  KEY `idx_giacenza` (`ritirata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Scommesse a totalizzatore
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `scommesse_eventi` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `organizzatore`  VARCHAR(12)  NOT NULL,
  `titolo`         VARCHAR(96)  NOT NULL,
  `esiti`          TEXT         NOT NULL COMMENT 'JSON array di stringhe',
  `cauzione`       BIGINT       NOT NULL DEFAULT 0,
  `stato`          ENUM('aperto','chiuso','pagato') NOT NULL DEFAULT 'aperto',
  `esito_vincente` VARCHAR(48)  DEFAULT NULL,
  `aperto_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_stato` (`stato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `scommesse` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `evento_id`  INT UNSIGNED NOT NULL,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `esito`      VARCHAR(48)  NOT NULL,
  `importo`    BIGINT       NOT NULL,
  `giocata_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_giocata` (`evento_id`, `citizenid`),
  KEY `idx_evento` (`evento_id`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Sosta a pagamento: pass residenti
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sosta_pass` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `zona`       VARCHAR(24)  NOT NULL,
  `scadenza`   DATE         NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pass` (`citizenid`, `zona`),
  KEY `idx_scadenza` (`scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Supporto: ticket e conversazione
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ticket` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `nome`       VARCHAR(64)  NOT NULL,
  `categoria`  VARCHAR(24)  NOT NULL DEFAULT 'domanda',
  `titolo`     VARCHAR(96)  NOT NULL,
  `stato`      ENUM('aperto','in_carico','chiuso') NOT NULL DEFAULT 'aperto',
  `presa_da`   VARCHAR(64)  DEFAULT NULL,
  `chiuso_da`  VARCHAR(64)  DEFAULT NULL,
  `posizione`  VARCHAR(96)  DEFAULT NULL COMMENT 'JSON coord al momento dell apertura',
  `aperto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiuso_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_stato` (`stato`, `aperto_il`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ticket_messaggi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ticket_id` INT UNSIGNED NOT NULL,
  `autore`    VARCHAR(64)  NOT NULL,
  `staff`     TINYINT(1)   NOT NULL DEFAULT 0,
  `testo`     TEXT         NOT NULL,
  `momento`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ticket` (`ticket_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Whitelist
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `whitelist` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license`    VARCHAR(64)  NOT NULL,
  `nome_gioco` VARCHAR(64)  NOT NULL DEFAULT '',
  `risposte`   LONGTEXT     DEFAULT NULL COMMENT 'JSON delle risposte al modulo',
  `stato`      ENUM('da_compilare','in_esame','accolta','respinta') NOT NULL DEFAULT 'da_compilare',
  `decisa_da`  VARCHAR(64)  DEFAULT NULL,
  `motivo`     VARCHAR(300) DEFAULT NULL,
  `inviata_il` TIMESTAMP    NULL DEFAULT NULL,
  `decisa_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_license` (`license`),
  KEY `idx_stato` (`stato`, `inviata_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Onoranze funebri: richieste e cimitero
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `funerali` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`    VARCHAR(12)  NOT NULL,
  `nome`         VARCHAR(64)  NOT NULL,
  `epitaffio`    VARCHAR(160) NOT NULL DEFAULT '',
  `erede`        VARCHAR(12)  DEFAULT NULL,
  `celebrato`    TINYINT(1)   NOT NULL DEFAULT 0,
  `chiesta_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `celebrato_il` TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pendenti` (`celebrato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `defunti` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `nome`       VARCHAR(64)  NOT NULL,
  `nato`       DATE         DEFAULT NULL,
  `epitaffio`  VARCHAR(160) NOT NULL DEFAULT '',
  `presenti`   VARCHAR(500) NOT NULL DEFAULT '',
  `celebrante` VARCHAR(64)  DEFAULT NULL,
  `morto_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
