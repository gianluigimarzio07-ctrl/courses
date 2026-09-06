-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — scientifica, carcere, ospedale, enti, telecamere
--
--  Tabelle e colonne aggiunte dalle risorse essenziali della terza
--  espansione: ita_scientifica, ita_carcere, aurea_ospedale,
--  aurea_azienda, aurea_telecamere, aurea_persistenza.
--
--  Su un'installazione nuova basta 01_schema.sql: c'è già tutto. Questo
--  file serve a chi ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/05_indagini.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  aurea_persistenza: il veicolo lasciato per strada resta dove l'hai
--  lasciato, e il server sa quando l'ha visto l'ultima volta.
-- ---------------------------------------------------------------------------
ALTER TABLE `veicoli`
  ADD COLUMN IF NOT EXISTS `posizione` TEXT DEFAULT NULL
  COMMENT 'JSON {x,y,z,h} di dove è stato lasciato';

ALTER TABLE `veicoli`
  ADD COLUMN IF NOT EXISTS `visto_il` TIMESTAMP NULL DEFAULT NULL
  COMMENT 'ultima volta che un client l ha segnalato';

-- ---------------------------------------------------------------------------
--  POLIZIA SCIENTIFICA
--
--  La banca dati biometrica è il collo di bottiglia voluto di tutto il
--  sistema: senza fotosegnalamento (art. 349 c.p.p.) il confronto è
--  sempre negativo, e un incensurato resta ignoto anche col DNA in mano.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `banca_dati_biometrica` (
  `citizenid`    VARCHAR(12)  NOT NULL,
  `nome`         VARCHAR(64)  NOT NULL,
  `dna`          TINYINT(1)   NOT NULL DEFAULT 0,
  `impronte`     TINYINT(1)   NOT NULL DEFAULT 0,
  `rilevato_da`  VARCHAR(64)  DEFAULT NULL,
  `rilevato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reperti` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`              VARCHAR(24)  NOT NULL COMMENT 'bossolo|sangue|impronte|residui|pneumatici',
  `luogo`             VARCHAR(64)  NOT NULL,
  `coord`             VARCHAR(96)  DEFAULT NULL COMMENT 'JSON {x,y,z}',
  `citizenid_origine` VARCHAR(12)  DEFAULT NULL COMMENT 'chi ha lasciato la traccia: mai inviato al client',
  `dati`              TEXT         DEFAULT NULL COMMENT 'JSON: matricola, arma, veicolo',
  `repertato_da`      VARCHAR(64)  NOT NULL,
  `repertato_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `analizzato`        TINYINT(1)   NOT NULL DEFAULT 0,
  `esito`             ENUM('positivo','negativo','parziale','inutilizzabile') DEFAULT NULL,
  `referto`           TEXT         DEFAULT NULL,
  `analizzato_da`     VARCHAR(64)  DEFAULT NULL,
  `analizzato_il`     TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_analisi` (`analizzato`, `analizzato_il`),
  KEY `idx_origine` (`citizenid_origine`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CASA CIRCONDARIALE
--
--  Il peculio è denaro vero in centesimi: dentro non circolano contanti.
--  Il deposito è l'elenco JSON degli effetti personali ritirati
--  all'ingresso e da restituire alla scarcerazione.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `carcere_matricola` (
  `citizenid`  VARCHAR(12)  NOT NULL,
  `peculio`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'euro in centesimi',
  `deposito`   LONGTEXT     DEFAULT NULL COMMENT 'JSON degli effetti personali',
  `motivo`     VARCHAR(160) DEFAULT NULL,
  `entrato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `uscito_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_aperte` (`uscito_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `carcere_colloqui` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `detenuto`        VARCHAR(12)  NOT NULL,
  `visitatore`      VARCHAR(12)  NOT NULL,
  `visitatore_nome` VARCHAR(64)  NOT NULL,
  `stato`           ENUM('richiesto','autorizzato','respinto','svolto') NOT NULL DEFAULT 'richiesto',
  `deciso_da`       VARCHAR(64)  DEFAULT NULL,
  `richiesto_il`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deciso_il`       TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_detenuto` (`detenuto`, `stato`),
  KEY `idx_pendenti` (`stato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  OSPEDALE: riscontro diagnostico
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `riscontri` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`     VARCHAR(12)  NOT NULL,
  `nome`          VARCHAR(64)  NOT NULL,
  `causa`         VARCHAR(300) NOT NULL,
  `violenta`      TINYINT(1)   NOT NULL DEFAULT 0,
  `medico_legale` VARCHAR(64)  DEFAULT NULL,
  `eseguito_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pg` (`citizenid`),
  KEY `idx_violente` (`violenta`, `eseguito_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  GESTIONE DELL'ENTE
--
--  Da non confondere con `imprese`: quella è la posizione fiscale, con
--  partita IVA e fatture. Questa è il fondo dell'ente legato al lavoro,
--  da cui escono premi e contributi di assunzione.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `enti` (
  `lavoro` VARCHAR(32) NOT NULL,
  `cassa`  BIGINT      NOT NULL DEFAULT 0 COMMENT 'euro in centesimi',
  PRIMARY KEY (`lavoro`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `enti_movimenti` (
  `id`      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lavoro`  VARCHAR(32)  NOT NULL,
  `importo` BIGINT       NOT NULL COMMENT 'positivo entrata, negativo uscita',
  `causale` VARCHAR(160) NOT NULL,
  `autore`  VARCHAR(64)  DEFAULT NULL,
  `momento` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_lavoro` (`lavoro`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `enti_presenze` (
  `lavoro`    VARCHAR(32)  NOT NULL,
  `citizenid` VARCHAR(12)  NOT NULL,
  `giorno`    DATE         NOT NULL,
  `minuti`    INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`lavoro`, `citizenid`, `giorno`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  VIDEOSORVEGLIANZA
--
--  Non si salva un'immagine: si salva un atto. Data, ora, impianto,
--  operatore e chi era nell'inquadratura.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `telecamere_fermi` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `telecamera`      VARCHAR(32)  NOT NULL,
  `nome_telecamera` VARCHAR(64)  NOT NULL,
  `operatore`       VARCHAR(64)  NOT NULL,
  `presenti`        VARCHAR(500) NOT NULL DEFAULT '',
  `nota`            VARCHAR(200) NOT NULL DEFAULT '',
  `momento`         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_recenti` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
