-- ============================================================================
--  AUREA · Italia Roleplay — Schema database
--  Motore: MariaDB 10.6+ / MySQL 8.0+
--  Charset: utf8mb4 (accenti e caratteri italiani corretti)
--
--  Import:  mysql -u root -p aurea < sql/01_schema.sql
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------------
--  ACCOUNT E PERSONAGGI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `account` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license`       VARCHAR(64)  NOT NULL COMMENT 'identificatore license2 di Rockstar',
  `discord`       VARCHAR(32)  DEFAULT NULL,
  `steam`         VARCHAR(32)  DEFAULT NULL,
  `nome_discord`  VARCHAR(64)  DEFAULT NULL,
  `gruppo`        VARCHAR(24)  NOT NULL DEFAULT 'utente',
  `slot_massimi`  TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `ore_gioco`     INT UNSIGNED NOT NULL DEFAULT 0,
  `primo_accesso` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ultimo_accesso` TIMESTAMP   NULL DEFAULT NULL,
  `whitelist`     TINYINT(1)   NOT NULL DEFAULT 0,
  `bannato`       TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_license` (`license`),
  KEY `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `personaggi` (
  `citizenid`     VARCHAR(12)  NOT NULL COMMENT 'codice cittadino, es. RM4F82K1',
  `account_id`    INT UNSIGNED NOT NULL,
  `slot`          TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `nome`          VARCHAR(32)  NOT NULL,
  `cognome`       VARCHAR(32)  NOT NULL,
  `data_nascita`  DATE         NOT NULL,
  `luogo_nascita` VARCHAR(48)  NOT NULL DEFAULT 'Roma',
  `sesso`         ENUM('M','F') NOT NULL DEFAULT 'M',
  `codice_fiscale` VARCHAR(16) NOT NULL,
  `nazionalita`   VARCHAR(32)  NOT NULL DEFAULT 'Italiana',
  `telefono`      VARCHAR(16)  NOT NULL,
  `contanti`      BIGINT       NOT NULL DEFAULT 0   COMMENT 'euro in centesimi',
  `banca`         BIGINT       NOT NULL DEFAULT 0   COMMENT 'euro in centesimi',
  `lavoro`        VARCHAR(32)  NOT NULL DEFAULT 'disoccupato',
  `lavoro_grado`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `lavoro_servizio` TINYINT(1) NOT NULL DEFAULT 0,
  `organizzazione` VARCHAR(32) NOT NULL DEFAULT 'nessuna',
  `org_grado`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `aspetto`       LONGTEXT     DEFAULT NULL COMMENT 'JSON appearance',
  `posizione`     TEXT         DEFAULT NULL COMMENT 'JSON {x,y,z,h}',
  `stato`         TEXT         DEFAULT NULL COMMENT 'JSON fame/sete/stress/salute',
  `metadata`      LONGTEXT     DEFAULT NULL COMMENT 'JSON libero',
  `minuti_gioco`  INT UNSIGNED NOT NULL DEFAULT 0,
  `attivo`        TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '0 = sepolto: resta in anagrafe ma non si gioca',
  `creato_il`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ultimo_uso`    TIMESTAMP    NULL DEFAULT NULL,
  `eliminato`     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_cf` (`codice_fiscale`),
  UNIQUE KEY `uq_telefono` (`telefono`),
  KEY `idx_account` (`account_id`),
  KEY `idx_lavoro` (`lavoro`),
  KEY `idx_org` (`organizzazione`),
  CONSTRAINT `fk_pg_account` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  INVENTARIO (a slot, con peso e metadata per istanza)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `inventari` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `contenitore` VARCHAR(64) NOT NULL COMMENT 'pg:RM4F82K1 | veh:AB123CD | cass:banca_1 | terra:xxxx',
  `tipo`       VARCHAR(24)  NOT NULL DEFAULT 'personaggio',
  `capienza`   INT UNSIGNED NOT NULL DEFAULT 40   COMMENT 'slot',
  `peso_max`   INT UNSIGNED NOT NULL DEFAULT 30000 COMMENT 'grammi',
  `dati`       LONGTEXT     DEFAULT NULL COMMENT 'JSON array di item',
  `aggiornato` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_contenitore` (`contenitore`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  VEICOLI · targhe italiane, bollo, assicurazione, revisione
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `veicoli` (
  `targa`         VARCHAR(10)  NOT NULL COMMENT 'formato AA000AA',
  `citizenid`     VARCHAR(12)  NOT NULL,
  `modello`       VARCHAR(48)  NOT NULL,
  `hash`          INT          NOT NULL,
  `categoria`     VARCHAR(24)  NOT NULL DEFAULT 'auto',
  `proprieta`     LONGTEXT     DEFAULT NULL COMMENT 'JSON mods/colori',
  `carburante`    FLOAT        NOT NULL DEFAULT 100,
  `motore`        FLOAT        NOT NULL DEFAULT 1000,
  `carrozzeria`   FLOAT        NOT NULL DEFAULT 1000,
  `km`            INT UNSIGNED NOT NULL DEFAULT 0,
  `garage`        VARCHAR(48)  NOT NULL DEFAULT 'centrale',
  `stato`         ENUM('garage','fuori','sequestrato','distrutto','demolito') NOT NULL DEFAULT 'garage',
  `bollo_scadenza`        DATE DEFAULT NULL,
  `assicurazione_tipo`    ENUM('nessuna','rca','kasko') NOT NULL DEFAULT 'nessuna',
  `assicurazione_scadenza` DATE DEFAULT NULL,
  `revisione_scadenza`    DATE DEFAULT NULL,
  `classe_ambientale`     VARCHAR(12) NOT NULL DEFAULT 'Euro 6',
  `acquistato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`targa`),
  KEY `idx_prop` (`citizenid`),
  KEY `idx_garage` (`garage`),
  CONSTRAINT `fk_veic_pg` FOREIGN KEY (`citizenid`) REFERENCES `personaggi` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CODICE DELLA STRADA · patente a punti, multe, autovelox, ZTL
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `patenti` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `numero`      VARCHAR(16)  NOT NULL,
  `categorie`   VARCHAR(32)  NOT NULL DEFAULT '' COMMENT 'CSV: AM,A,B,C,D,E,nautica,volo',
  `punti`       TINYINT      NOT NULL DEFAULT 20,
  `rilascio`    DATE         NOT NULL,
  `scadenza`    DATE         NOT NULL,
  `sospesa_fino` DATETIME    DEFAULT NULL,
  `ritirata`    TINYINT(1)   NOT NULL DEFAULT 0,
  `neopatentato` TINYINT(1)  NOT NULL DEFAULT 1,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_numero` (`numero`),
  CONSTRAINT `fk_pat_pg` FOREIGN KEY (`citizenid`) REFERENCES `personaggi` (`citizenid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `multe` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `targa`       VARCHAR(10)  DEFAULT NULL,
  `articolo`    VARCHAR(24)  NOT NULL COMMENT 'es. art.142 c.9 CdS',
  `descrizione` VARCHAR(255) NOT NULL,
  `importo`     BIGINT       NOT NULL COMMENT 'centesimi',
  `punti_decurtati` TINYINT  NOT NULL DEFAULT 0,
  `origine`     ENUM('autovelox','ztl','agente','tutor','semaforo','sosta') NOT NULL,
  `agente`      VARCHAR(64)  DEFAULT NULL,
  `luogo`       VARCHAR(96)  DEFAULT NULL,
  `prova`       TEXT         DEFAULT NULL COMMENT 'JSON: velocità rilevata, limite, coord',
  `emessa_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL,
  `stato`       ENUM('aperta','pagata','ricorso','annullata','ruolo') NOT NULL DEFAULT 'aperta',
  `pagata_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_targa` (`targa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ztl_transiti` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `zona`      VARCHAR(48)  NOT NULL,
  `targa`     VARCHAR(10)  NOT NULL,
  `citizenid` VARCHAR(12)  DEFAULT NULL,
  `momento`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `autorizzato` TINYINT(1) NOT NULL DEFAULT 0,
  `multa_id`  INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_zona_targa` (`zona`, `targa`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ztl_permessi` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `zona`      VARCHAR(48)  NOT NULL,
  `targa`     VARCHAR(10)  NOT NULL,
  `tipo`      VARCHAR(32)  NOT NULL DEFAULT 'residente',
  `scadenza`  DATE         NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_zona_targa` (`zona`, `targa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  GIUSTIZIA · casellario, denunce, processi, detenzione
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `casellario` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `reato`       VARCHAR(96)  NOT NULL,
  `articolo`    VARCHAR(32)  NOT NULL COMMENT 'es. art.628 c.p.',
  `gravita`     TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1..5',
  `pena_mesi`   INT UNSIGNED NOT NULL DEFAULT 0,
  `ammenda`     BIGINT       NOT NULL DEFAULT 0,
  `stato`       ENUM('indagato','imputato','condannato','assolto','prescritto') NOT NULL DEFAULT 'indagato',
  `agente`      VARCHAR(64)  DEFAULT NULL,
  `note`        TEXT         DEFAULT NULL,
  `aperto_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiuso_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `detenzioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `istituto`    VARCHAR(48)  NOT NULL DEFAULT 'Casa Circondariale',
  `minuti_totali` INT UNSIGNED NOT NULL,
  `minuti_scontati` INT UNSIGNED NOT NULL DEFAULT 0,
  `motivo`      VARCHAR(255) NOT NULL,
  `regime`      ENUM('ordinario','alta_sicurezza','41bis') NOT NULL DEFAULT 'ordinario',
  `inizio`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fine`        TIMESTAMP    NULL DEFAULT NULL,
  `attiva`      TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `attiva`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `denunce` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `denunciante` VARCHAR(12)  NOT NULL,
  `denunciato`  VARCHAR(12)  DEFAULT NULL,
  `oggetto`     VARCHAR(128) NOT NULL,
  `corpo`       TEXT         NOT NULL,
  `stato`       ENUM('protocollata','in_indagine','archiviata','rinviata') NOT NULL DEFAULT 'protocollata',
  `creata_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_denunciato` (`denunciato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  FISCO · partita IVA, imprese, fatture, dichiarazioni
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `imprese` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `piva`          VARCHAR(11)  NOT NULL,
  `ragione_sociale` VARCHAR(96) NOT NULL,
  `forma`         ENUM('ditta_individuale','snc','srl','spa','cooperativa') NOT NULL DEFAULT 'ditta_individuale',
  `settore`       VARCHAR(48)  NOT NULL,
  `titolare`      VARCHAR(12)  NOT NULL,
  `regime`        ENUM('forfettario','ordinario') NOT NULL DEFAULT 'forfettario',
  `cassa`         BIGINT       NOT NULL DEFAULT 0,
  `fatturato_anno` BIGINT      NOT NULL DEFAULT 0,
  `iva_a_debito`  BIGINT       NOT NULL DEFAULT 0,
  `sede`          VARCHAR(96)  DEFAULT NULL,
  `dipendenti_max` TINYINT UNSIGNED NOT NULL DEFAULT 5,
  `attiva`        TINYINT(1)   NOT NULL DEFAULT 1,
  `aperta_il`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_piva` (`piva`),
  KEY `idx_titolare` (`titolare`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `impresa_dipendenti` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `impresa_id` INT UNSIGNED NOT NULL,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `mansione`   VARCHAR(48)  NOT NULL DEFAULT 'operaio',
  `stipendio`  BIGINT       NOT NULL DEFAULT 0,
  `assunto_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_imp_pg` (`impresa_id`, `citizenid`),
  CONSTRAINT `fk_dip_imp` FOREIGN KEY (`impresa_id`) REFERENCES `imprese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fatture` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `numero`      VARCHAR(24)  NOT NULL,
  `emittente`   INT UNSIGNED DEFAULT NULL COMMENT 'imprese.id',
  `emittente_pg` VARCHAR(12) DEFAULT NULL,
  `cliente_pg`  VARCHAR(12)  DEFAULT NULL,
  `descrizione` VARCHAR(255) NOT NULL,
  `imponibile`  BIGINT       NOT NULL,
  `aliquota`    TINYINT UNSIGNED NOT NULL DEFAULT 22,
  `iva`         BIGINT       NOT NULL,
  `totale`      BIGINT       NOT NULL,
  `stato`       ENUM('emessa','pagata','insoluta','stornata') NOT NULL DEFAULT 'emessa',
  `emessa_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_numero` (`numero`),
  KEY `idx_cliente` (`cliente_pg`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `tributi` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `tipo`       VARCHAR(32)  NOT NULL COMMENT 'irpef|iva|bollo_auto|imu|tari|inps',
  `periodo`    VARCHAR(16)  NOT NULL COMMENT 'es. 2026-Q1',
  `importo`    BIGINT       NOT NULL,
  `scadenza`   DATETIME     NOT NULL,
  `stato`      ENUM('dovuto','pagato','cartella','rateizzato') NOT NULL DEFAULT 'dovuto',
  `creato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  BANCA
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `conti` (
  `iban`       VARCHAR(27)  NOT NULL,
  `intestatario` VARCHAR(12) DEFAULT NULL,
  `impresa_id` INT UNSIGNED DEFAULT NULL,
  `tipo`       ENUM('personale','impresa','congiunto') NOT NULL DEFAULT 'personale',
  `nome`       VARCHAR(64)  NOT NULL DEFAULT 'Conto corrente',
  `saldo`      BIGINT       NOT NULL DEFAULT 0,
  `fido`       BIGINT       NOT NULL DEFAULT 0,
  `bloccato`   TINYINT(1)   NOT NULL DEFAULT 0,
  `aperto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`iban`),
  KEY `idx_int` (`intestatario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `movimenti` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `iban`       VARCHAR(27)  NOT NULL,
  `controparte` VARCHAR(64) DEFAULT NULL,
  `causale`    VARCHAR(128) NOT NULL,
  `importo`    BIGINT       NOT NULL COMMENT 'negativo = addebito',
  `saldo_dopo` BIGINT       NOT NULL,
  `categoria`  VARCHAR(32)  NOT NULL DEFAULT 'generico',
  `momento`    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_iban` (`iban`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mutui` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `oggetto`     VARCHAR(96)  NOT NULL,
  `capitale`    BIGINT       NOT NULL,
  `residuo`     BIGINT       NOT NULL,
  `tasso`       DECIMAL(5,2) NOT NULL DEFAULT 4.50,
  `rata`        BIGINT       NOT NULL,
  `rate_totali` SMALLINT UNSIGNED NOT NULL,
  `rate_pagate` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `prossima_rata` DATETIME   NOT NULL,
  `stato`       ENUM('attivo','estinto','insoluto','pignorato') NOT NULL DEFAULT 'attivo',
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  IMMOBILI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `immobili` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`     VARCHAR(32)  NOT NULL,
  `nome`       VARCHAR(96)  NOT NULL,
  `tipo`       ENUM('appartamento','villa','attico','magazzino','locale','box') NOT NULL DEFAULT 'appartamento',
  `indirizzo`  VARCHAR(128) NOT NULL,
  `comune`     VARCHAR(48)  NOT NULL DEFAULT 'Los Santos',
  `prezzo`     BIGINT       NOT NULL,
  `rendita_catastale` BIGINT NOT NULL DEFAULT 0,
  `proprietario` VARCHAR(12) DEFAULT NULL,
  `inquilino`  VARCHAR(12)  DEFAULT NULL,
  `affitto`    BIGINT       NOT NULL DEFAULT 0,
  `ingresso`   TEXT         NOT NULL COMMENT 'JSON coord',
  `interno`    VARCHAR(48)  NOT NULL DEFAULT 'shell_medio',
  `garage_slot` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `chiavi`     TEXT         DEFAULT NULL COMMENT 'JSON array citizenid',
  `serratura`  TINYINT(1)   NOT NULL DEFAULT 1,
  `in_vendita` TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_prop` (`proprietario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ORGANIZZAZIONI CRIMINALI · territori, pizzo, riciclaggio
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `organizzazioni` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tag`        VARCHAR(32)  NOT NULL,
  `nome`       VARCHAR(96)  NOT NULL,
  `tipo`       ENUM('famiglia','clan','cosca','banda','sindacato') NOT NULL DEFAULT 'famiglia',
  `capo`       VARCHAR(12)  NOT NULL,
  `cassa`      BIGINT       NOT NULL DEFAULT 0,
  `reputazione` INT         NOT NULL DEFAULT 0,
  `calore`     TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'attenzione delle forze dell ordine 0-100',
  `colore`     VARCHAR(9)   NOT NULL DEFAULT '#8b1e1e',
  `attiva`     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tag` (`tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `territori` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`     VARCHAR(32)  NOT NULL,
  `nome`       VARCHAR(64)  NOT NULL,
  `org_id`     INT UNSIGNED DEFAULT NULL,
  `controllo`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0-100',
  `rendita_oraria` BIGINT   NOT NULL DEFAULT 0,
  `ultima_contesa` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pizzo` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `impresa_id`  INT UNSIGNED NOT NULL,
  `org_id`      INT UNSIGNED NOT NULL,
  `percentuale` TINYINT UNSIGNED NOT NULL DEFAULT 10,
  `attivo`      TINYINT(1)   NOT NULL DEFAULT 1,
  `imposto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_imp` (`impresa_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ECONOMIA DINAMICA
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `mercato` (
  `item`        VARCHAR(48)  NOT NULL,
  `prezzo_base` BIGINT       NOT NULL,
  `prezzo`      BIGINT       NOT NULL,
  `offerta`     INT          NOT NULL DEFAULT 100,
  `domanda`     INT          NOT NULL DEFAULT 100,
  `min_mult`    DECIMAL(4,2) NOT NULL DEFAULT 0.50,
  `max_mult`    DECIMAL(4,2) NOT NULL DEFAULT 2.50,
  `aggiornato`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `economia_stato` (
  `chiave`   VARCHAR(48) NOT NULL,
  `valore`   TEXT        NOT NULL,
  `aggiornato` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`chiave`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  MADE IN ITALY · filiere produttive e certificazioni
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `produzioni` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `filiera`    VARCHAR(32)  NOT NULL COMMENT 'vino|olio|caffe|formaggio|pizza|moda',
  `prodotto`   VARCHAR(48)  NOT NULL,
  `qualita`    TINYINT UNSIGNED NOT NULL DEFAULT 50 COMMENT '0-100',
  `certificazione` ENUM('nessuna','IGP','DOP','DOCG','BIO') NOT NULL DEFAULT 'nessuna',
  `quantita`   INT UNSIGNED NOT NULL DEFAULT 0,
  `lotto`      VARCHAR(24)  NOT NULL,
  `creato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `stagionatura_fine` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`),
  KEY `idx_lotto` (`lotto`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `maestria` (
  `citizenid`  VARCHAR(12)  NOT NULL,
  `disciplina` VARCHAR(32)  NOT NULL,
  `xp`         INT UNSIGNED NOT NULL DEFAULT 0,
  `livello`    TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`citizenid`, `disciplina`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  SANITÀ
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `cartelle_cliniche` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(12)  NOT NULL,
  `struttura`  VARCHAR(64)  NOT NULL DEFAULT 'Ospedale Centrale',
  `diagnosi`   VARCHAR(255) NOT NULL,
  `terapia`    TEXT         DEFAULT NULL,
  `medico`     VARCHAR(64)  DEFAULT NULL,
  `ticket`     BIGINT       NOT NULL DEFAULT 0,
  `data`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ferite` (
  `citizenid`  VARCHAR(12) NOT NULL,
  `dati`       LONGTEXT    NOT NULL COMMENT 'JSON parti del corpo',
  `aggiornato` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  TELEFONO
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `tel_contatti` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12) NOT NULL,
  `nome`      VARCHAR(48) NOT NULL,
  `numero`    VARCHAR(16) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `tel_messaggi` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `mittente`  VARCHAR(16) NOT NULL,
  `destinatario` VARCHAR(16) NOT NULL,
  `testo`     TEXT        NOT NULL,
  `letto`     TINYINT(1)  NOT NULL DEFAULT 0,
  `momento`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conv` (`destinatario`, `mittente`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `annunci` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(12) NOT NULL,
  `categoria` VARCHAR(32) NOT NULL DEFAULT 'generale',
  `titolo`    VARCHAR(96) NOT NULL,
  `testo`     TEXT        NOT NULL,
  `prezzo`    BIGINT      NOT NULL DEFAULT 0,
  `numero`    VARCHAR(16) NOT NULL,
  `momento`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cat` (`categoria`, `momento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  112 NUE · centrale operativa
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `chiamate_112` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(12)  NOT NULL,
  `chiamante`   VARCHAR(12)  DEFAULT NULL,
  `numero`      VARCHAR(16)  DEFAULT NULL,
  `ente`        ENUM('carabinieri','polizia','118','vigili_fuoco','guardia_finanza','multiplo') NOT NULL,
  `priorita`    ENUM('bianco','verde','giallo','rosso') NOT NULL DEFAULT 'verde',
  `tipologia`   VARCHAR(64)  NOT NULL,
  `descrizione` TEXT         DEFAULT NULL,
  `coord`       TEXT         NOT NULL,
  `indirizzo`   VARCHAR(128) DEFAULT NULL,
  `stato`       ENUM('attesa','assegnata','in_posto','chiusa','annullata') NOT NULL DEFAULT 'attesa',
  `assegnata_a` TEXT         DEFAULT NULL COMMENT 'JSON array citizenid',
  `aperta_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`   TIMESTAMP    NULL DEFAULT NULL,
  `esito`       TEXT         DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_stato` (`stato`, `ente`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  AMMINISTRAZIONE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sanzioni_admin` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license`    VARCHAR(64)  NOT NULL,
  `citizenid`  VARCHAR(12)  DEFAULT NULL,
  `tipo`       ENUM('avvertimento','kick','ban','ban_permanente') NOT NULL,
  `motivo`     TEXT         NOT NULL,
  `staff`      VARCHAR(64)  NOT NULL,
  `prove`      TEXT         DEFAULT NULL,
  `inizio`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fine`       TIMESTAMP    NULL DEFAULT NULL,
  `attiva`     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_license` (`license`, `attiva`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `registro_eventi` (
  `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `canale`    VARCHAR(32) NOT NULL,
  `livello`   ENUM('debug','info','avviso','allarme') NOT NULL DEFAULT 'info',
  `citizenid` VARCHAR(12) DEFAULT NULL,
  `license`   VARCHAR(64) DEFAULT NULL,
  `messaggio` TEXT        NOT NULL,
  `dati`      LONGTEXT    DEFAULT NULL,
  `momento`   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_canale` (`canale`, `momento`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

SET FOREIGN_KEY_CHECKS = 1;
