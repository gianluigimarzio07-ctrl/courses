-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — espansione
--
--  Tabelle introdotte dai moduli aggiunti dopo la prima installazione:
--  armadio dei completi, armi e titoli di porto, licenze di attività,
--  stato civile ed elezioni comunali, testata giornalistica.
--
--  Su un'installazione nuova basta 01_schema.sql: le stesse tabelle sono
--  già lì. Questo file serve a chi ha il database della prima versione.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/03_espansione.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  Armadio: completi salvati dal personaggio
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `completi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12)  NOT NULL,
  `nome`      VARCHAR(48)  NOT NULL,
  `dati`      LONGTEXT     NOT NULL COMMENT 'JSON abbigliamento',
  `creato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Armi: registro nazionale e titoli di porto
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `armi` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `matricola`      VARCHAR(24)  NOT NULL,
  `arma`           VARCHAR(48)  NOT NULL COMMENT 'nome tecnico WEAPON_*',
  `nome`           VARCHAR(64)  NOT NULL,
  `categoria`      VARCHAR(24)  NOT NULL DEFAULT 'comune',
  `intestatario`   VARCHAR(12)  DEFAULT NULL,
  `clandestina`    TINYINT(1)   NOT NULL DEFAULT 0,
  `denunciata`     TINYINT(1)   NOT NULL DEFAULT 0,
  `denuncia_entro` DATE         DEFAULT NULL,
  `sequestrata`    TINYINT(1)   NOT NULL DEFAULT 0,
  `distrutta`      TINYINT(1)   NOT NULL DEFAULT 0,
  `creata_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_matricola` (`matricola`),
  KEY `idx_intestatario` (`intestatario`, `distrutta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `porto_armi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12)  NOT NULL,
  `tipo`      VARCHAR(24)  NOT NULL COMMENT 'sportivo | caccia | difesa | servizio',
  `rilascio`  DATE         NOT NULL,
  `scadenza`  DATE         NOT NULL,
  `revocato`  TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo_revoca` VARCHAR(160) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_titolo` (`citizenid`, `tipo`),
  KEY `idx_scadenza` (`revocato`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Licenze di pesca, caccia e raccolta
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `licenze` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12)  NOT NULL,
  `tipo`      VARCHAR(24)  NOT NULL COMMENT 'pesca | caccia | raccolta',
  `rilascio`  DATE         NOT NULL,
  `scadenza`  DATE         NOT NULL,
  `revocata`  TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_licenza` (`citizenid`, `tipo`),
  KEY `idx_scadenza` (`revocata`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Stato civile
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `matrimoni` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `coniuge_a`    VARCHAR(12)  NOT NULL,
  `coniuge_b`    VARCHAR(12)  NOT NULL,
  `regime`       ENUM('comunione','separazione') NOT NULL DEFAULT 'comunione',
  `stato`        ENUM('promesso','celebrato') NOT NULL DEFAULT 'promesso',
  `celebrante`   VARCHAR(64)  DEFAULT NULL,
  `celebrato_il` TIMESTAMP    NULL DEFAULT NULL,
  `sciolto`      TINYINT(1)   NOT NULL DEFAULT 0,
  `sciolto_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_a` (`coniuge_a`, `sciolto`),
  KEY `idx_b` (`coniuge_b`, `sciolto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Elezioni comunali
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `candidati` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `tornata`    VARCHAR(8)   NOT NULL DEFAULT '1',
  `programma`  VARCHAR(500) NOT NULL DEFAULT '',
  `firme`      INT UNSIGNED NOT NULL DEFAULT 0,
  `depositata_il` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_candidatura` (`citizenid`, `tornata`),
  KEY `idx_tornata` (`tornata`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `voti` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `candidato_id` INT UNSIGNED NOT NULL,
  `elettore`     VARCHAR(12)  NOT NULL,
  `espresso_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_candidato` (`candidato_id`),
  KEY `idx_elettore` (`elettore`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `istanze_comunali` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `tipo`       VARCHAR(32)  NOT NULL,
  `contenuto`  VARCHAR(255) NOT NULL DEFAULT '',
  `stato`      ENUM('in_esame','accolta','respinta') NOT NULL DEFAULT 'in_esame',
  `decisa_da`  VARCHAR(64)  DEFAULT NULL,
  `creata_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_stato` (`stato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Testata giornalistica
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `articoli` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sezione`        VARCHAR(24)  NOT NULL DEFAULT 'cronaca',
  `titolo`         VARCHAR(140) NOT NULL,
  `occhiello`      VARCHAR(140) NOT NULL DEFAULT '',
  `testo`          TEXT         NOT NULL,
  `firma`          VARCHAR(64)  NOT NULL,
  `autore`         VARCHAR(12)  NOT NULL,
  `tipo`           ENUM('articolo','rettifica') NOT NULL DEFAULT 'articolo',
  `rettifica_di`   INT UNSIGNED DEFAULT NULL,
  `ritirato`       TINYINT(1)   NOT NULL DEFAULT 0,
  `nota_direzione` VARCHAR(200) DEFAULT NULL,
  `pubblicato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_edizione` (`ritirato`, `id`),
  KEY `idx_sezione` (`sezione`, `id`),
  KEY `idx_autore` (`autore`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rettifiche` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `articolo_id`      INT UNSIGNED NOT NULL,
  `richiedente`      VARCHAR(12)  NOT NULL,
  `nome_richiedente` VARCHAR(64)  NOT NULL,
  `testo`            VARCHAR(800) NOT NULL DEFAULT '',
  `stato`            ENUM('attesa','pubblicata','omessa','querelata') NOT NULL DEFAULT 'attesa',
  `chiesta_il`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_stato` (`stato`, `id`),
  KEY `idx_articolo` (`articolo_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `inserzioni` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `inserzionista`    VARCHAR(64)  NOT NULL,
  `citizenid`        VARCHAR(12)  NOT NULL,
  `formato`          VARCHAR(24)  NOT NULL,
  `testo`            VARCHAR(255) NOT NULL,
  `edizioni_residue` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `acquistata_il`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_vive` (`edizioni_residue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
