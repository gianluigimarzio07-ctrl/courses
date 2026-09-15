-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — dogane, intercettazioni, atti notarili,
--  agenzia immobiliare
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/11_mercato.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
--  DOGANE
--
--  `valore_reale` e `valore_dichiarato` sono i due numeri che non devono
--  mai stare dalla stessa parte: il primo lo sa solo il server, il secondo
--  lo scrive l'importatore.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dogana_bollette` (
  `id`                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `importatore`       VARCHAR(12) NOT NULL,
  `partita`           VARCHAR(32) NOT NULL,
  `valore_reale`      BIGINT      NOT NULL,
  `valore_dichiarato` BIGINT      NOT NULL,
  `tributi`           BIGINT      NOT NULL DEFAULT 0,
  `canale`            ENUM('verde','giallo','arancione','rosso') NOT NULL DEFAULT 'verde',
  `esito`             ENUM('aperta','svincolata','contrabbando') NOT NULL DEFAULT 'aperta',
  `sanzione`          BIGINT      NOT NULL DEFAULT 0,
  `presentata_il`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`         TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_importatore` (`importatore`, `id`),
  KEY `idx_profilo` (`importatore`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dogana_licenze` (
  `citizenid`     VARCHAR(12) NOT NULL,
  `rilasciata_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  INTERCETTAZIONI
--
--  `convalida_entro` è valorizzata solo per i decreti d'urgenza. Scaduto
--  quel termine senza convalida, lo stato diventa 'inutilizzabile': il
--  materiale resta leggibile ma non si può usare.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `int_decreti` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `numero`           VARCHAR(16)  NOT NULL COMMENT 'utenza sottoposta ad ascolto',
  `bersaglio`        VARCHAR(12)  NOT NULL,
  `reato`            VARCHAR(16)  NOT NULL,
  `motivazione`      VARCHAR(400) NOT NULL DEFAULT '',
  `richiedente`      VARCHAR(12)  NOT NULL,
  `richiedente_nome` VARCHAR(96)  NOT NULL DEFAULT '',
  `giudice`          VARCHAR(96)  DEFAULT NULL,
  `stato`            ENUM('richiesto','autorizzato','urgenza','convalidato','respinto','inutilizzabile','scaduto')
                     NOT NULL DEFAULT 'richiesto',
  `emesso_il`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deciso_il`        TIMESTAMP    NULL DEFAULT NULL,
  `scade_il`         TIMESTAMP    NULL DEFAULT NULL,
  `convalida_entro`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_numero` (`numero`, `stato`),
  KEY `idx_richiedente` (`richiedente`, `id`),
  KEY `idx_pendenti` (`stato`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `int_brogliaccio` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `decreto_id`   INT UNSIGNED NOT NULL,
  `tipo`         ENUM('chiamata','sms') NOT NULL,
  `mittente`     VARCHAR(16)  NOT NULL,
  `destinatario` VARCHAR(16)  NOT NULL,
  `contenuto`    VARCHAR(400) NOT NULL DEFAULT '',
  `secondi`      INT UNSIGNED NOT NULL DEFAULT 0,
  `momento`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_decreto` (`decreto_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ATTI NOTARILI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `notaio_atti` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`         VARCHAR(24)  NOT NULL DEFAULT 'compravendita',
  `immobile_id`  INT UNSIGNED DEFAULT NULL,
  `venditore`    VARCHAR(12)  NOT NULL,
  `compratore`   VARCHAR(12)  NOT NULL,
  `prezzo`       BIGINT       NOT NULL DEFAULT 0,
  `imposte`      BIGINT       NOT NULL DEFAULT 0,
  `onorario`     BIGINT       NOT NULL DEFAULT 0,
  `notaio`       VARCHAR(96)  NOT NULL DEFAULT '',
  `prima_casa`   TINYINT(1)   NOT NULL DEFAULT 0,
  `stipulato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_immobile` (`immobile_id`, `id`),
  KEY `idx_parti` (`venditore`, `compratore`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notaio_procure` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `immobile_id`   INT UNSIGNED NOT NULL,
  `concedente`    VARCHAR(12)  NOT NULL,
  `delegato`      VARCHAR(12)  NOT NULL,
  `notaio`        VARCHAR(96)  NOT NULL DEFAULT '',
  `revocata`      TINYINT(1)   NOT NULL DEFAULT 0,
  `conferita_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_delegato` (`delegato`, `revocata`, `scade_il`),
  KEY `idx_immobile` (`immobile_id`, `revocata`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  AGENZIA IMMOBILIARE
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `imm_annunci` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `immobile_id`   INT UNSIGNED NOT NULL,
  `venditore`     VARCHAR(12)  NOT NULL,
  `prezzo`        BIGINT       NOT NULL,
  `nota`          VARCHAR(160) NOT NULL DEFAULT '',
  `stato`         ENUM('aperto','concluso','ritirato','scaduto') NOT NULL DEFAULT 'aperto',
  `pubblicato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vetrina` (`stato`, `scade_il`),
  KEY `idx_venditore` (`venditore`, `stato`),
  KEY `idx_immobile` (`immobile_id`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imm_proposte` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `annuncio_id` INT UNSIGNED NOT NULL,
  `compratore`  VARCHAR(12)  NOT NULL,
  `offerta`     BIGINT       NOT NULL,
  `caparra`     BIGINT       NOT NULL DEFAULT 0,
  `stato`       ENUM('aperta','accettata','rifiutata','decaduta','scaduta') NOT NULL DEFAULT 'aperta',
  `fatta_il`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_annuncio` (`annuncio_id`, `stato`),
  KEY `idx_compratore` (`compratore`, `stato`),
  KEY `idx_scadenza` (`stato`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `imm_affari` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `immobile_id` INT UNSIGNED NOT NULL,
  `venditore`   VARCHAR(12) NOT NULL,
  `compratore`  VARCHAR(12) NOT NULL,
  `prezzo`      BIGINT      NOT NULL,
  `provvigione` BIGINT      NOT NULL DEFAULT 0,
  `concluso_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_immobile` (`immobile_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
