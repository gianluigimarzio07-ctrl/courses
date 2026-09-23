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
  `posizione`     TEXT         DEFAULT NULL COMMENT 'JSON {x,y,z,h} di dove è stato lasciato',
  `visto_il`      TIMESTAMP    NULL DEFAULT NULL COMMENT 'ultima volta che un client l ha segnalato',
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

-- ---------------------------------------------------------------------------
--  TELEFONO: registro delle chiamate
--
--  Non c'è il contenuto — la voce non si registra — ma c'è chi ha chiamato
--  chi, quando, con che esito e per quanto. È quello che si ottiene
--  davvero con un'acquisizione di tabulati, ed è abbastanza per far
--  partire un'indagine.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `tel_chiamate` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `mittente`     VARCHAR(16) NOT NULL,
  `destinatario` VARCHAR(16) NOT NULL,
  `esito`        ENUM('conclusa','persa','rifiutata') NOT NULL DEFAULT 'conclusa',
  `secondi`      INT UNSIGNED NOT NULL DEFAULT 0,
  `vista`        TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '0 = persa non ancora vista',
  `momento`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mittente` (`mittente`, `id`),
  KEY `idx_destinatario` (`destinatario`, `id`),
  KEY `idx_perse` (`destinatario`, `esito`, `vista`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  POSIZIONE ASSICURATIVA
--
--  Il montante è una scrittura, non un deposito: il sistema è a
--  ripartizione e le pensioni le paga l'erario. Qui c'è solo il numero
--  che serve a calcolare quanto spetta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `previdenza_posizioni` (
  `citizenid`         VARCHAR(12) NOT NULL,
  `montante`          BIGINT      NOT NULL DEFAULT 0 COMMENT 'centesimi, 33% degli imponibili',
  `settimane`         INT UNSIGNED NOT NULL DEFAULT 0,
  `ultimo_imponibile` BIGINT      NOT NULL DEFAULT 0 COMMENT 'base di calcolo di malattia, NASpI e INAIL',
  `ultimo_contributo` TIMESTAMP   NULL DEFAULT NULL,
  `pensionato`        TINYINT(1)  NOT NULL DEFAULT 0,
  `decorrenza`        TIMESTAMP   NULL DEFAULT NULL COMMENT 'da quando è in pensione',
  PRIMARY KEY (`citizenid`),
  KEY `idx_settimane` (`settimane`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  PRESTAZIONI
--
--  Una riga per ogni cosa che l'INPS sta pagando. Il thread di erogazione
--  legge solo quelle in stato 'aperta'.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `previdenza_prestazioni` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`      VARCHAR(12) NOT NULL,
  `tipo`           ENUM('pensione','malattia','infortunio','naspi') NOT NULL,
  `stato`          ENUM('aperta','chiusa','revocata','sospesa') NOT NULL DEFAULT 'aperta',
  `importo_rateo`  BIGINT      NOT NULL DEFAULT 0,
  `ratei_residui`  INT         NOT NULL DEFAULT 0,
  `ratei_erogati`  INT         NOT NULL DEFAULT 0,
  `visita_fiscale` TINYINT(1)  NOT NULL DEFAULT 0,
  `motivo`         VARCHAR(160) DEFAULT NULL COMMENT 'perché è stata chiusa o revocata',
  `dati`           JSON        DEFAULT NULL,
  `aperta_il`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperte` (`stato`, `tipo`),
  KEY `idx_citizen` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  INFORTUNI SUL LAVORO
--
--  Art. 53 D.P.R. 1124/1965: il datore denuncia entro il termine. Scaduto
--  quello, `scaduto` passa a 1, arriva la sanzione e il DURC diventa
--  irregolare finché la posizione non viene sanata.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `previdenza_infortuni` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`     VARCHAR(12) NOT NULL COMMENT 'l\'infortunato',
  `datore`        VARCHAR(12) DEFAULT NULL COMMENT 'chi aveva l\'obbligo di denuncia',
  `descrizione`   VARCHAR(200) NOT NULL,
  `gravita`       ENUM('lieve','medio','grave') NOT NULL DEFAULT 'lieve',
  `denunciato`    TINYINT(1)  NOT NULL DEFAULT 0,
  `denunciato_il` TIMESTAMP   NULL DEFAULT NULL,
  `scaduto`       TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '1 = termine decorso senza denuncia',
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  `aperto_il`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_datore` (`datore`, `denunciato`, `scaduto`),
  KEY `idx_infortunato` (`citizenid`, `id`),
  KEY `idx_termine` (`denunciato`, `scaduto`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  DURC RILASCIATI
--
--  Il documento ha una scadenza: un cantiere aperto con un DURC di tre ore
--  prima non è aperto in regola.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `previdenza_durc` (
  `citizenid`     VARCHAR(12) NOT NULL,
  `rilasciato_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  TITOLI EDILIZI
--
--  `silenzio_assenso` dice se il permesso è stato rilasciato dagli uffici
--  o si è formato per decorso del termine (art. 20 D.P.R. 380/2001).
--  Serve a saperlo dopo, quando qualcuno contesta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_permessi` (
  `id`               INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`        VARCHAR(12) NOT NULL,
  `lotto`            VARCHAR(32) NOT NULL,
  `silenzio_assenso` TINYINT(1)  NOT NULL DEFAULT 0,
  `consumato`        TINYINT(1)  NOT NULL DEFAULT 0 COMMENT '1 = usato per aprire un cantiere',
  `rilasciato_il`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`         TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lotto` (`lotto`, `consumato`, `scade_il`),
  KEY `idx_titolare` (`citizenid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CANTIERI
--
--  Uno per lotto. `permesso_id` a NULL significa cantiere abusivo: è la
--  condizione che fa scattare il sequestro.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_cantieri` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lotto`         VARCHAR(32) NOT NULL,
  `impresa`       VARCHAR(32) NOT NULL COMMENT 'il lavoro dell\'ente titolare',
  `direttore`     VARCHAR(12) NOT NULL COMMENT 'il datore di lavoro, ai fini INAIL',
  `permesso_id`   INT UNSIGNED DEFAULT NULL,
  `fase`          VARCHAR(24) NOT NULL DEFAULT 'scavo',
  `lavorazioni`   INT UNSIGNED NOT NULL DEFAULT 0,
  `rischio`       INT          NOT NULL DEFAULT 0 COMMENT '0-100',
  `ponteggio`     TINYINT(1)  NOT NULL DEFAULT 0,
  `pos`           TINYINT(1)  NOT NULL DEFAULT 0 COMMENT 'piano operativo di sicurezza depositato',
  `stato`         ENUM('aperto','sospeso','consegnato','sequestrato') NOT NULL DEFAULT 'aperto',
  `sospeso_fino`  DATETIME    NULL DEFAULT NULL,
  `aperto_il`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `consegnato_il` TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperti` (`stato`, `lotto`),
  KEY `idx_impresa` (`impresa`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  INFORTUNI IN CANTIERE
--
--  Il duplicato di quanto sta in previdenza_infortuni, ma dal lato del
--  cantiere: serve a rispondere alla domanda "in quale cantiere ci si fa
--  male, e con che rischio", che è quella che fa aprire un'inchiesta.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_infortuni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cantiere_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12) NOT NULL,
  `gravita`     ENUM('lieve','medio','grave') NOT NULL DEFAULT 'lieve',
  `descrizione` VARCHAR(200) NOT NULL,
  `rischio`     INT NOT NULL DEFAULT 0 COMMENT 'il rischio del cantiere al momento del fatto',
  `momento`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cantiere` (`cantiere_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ISPEZIONI
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `edilizia_ispezioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cantiere_id` INT UNSIGNED NOT NULL,
  `ispettore`   VARCHAR(64) NOT NULL,
  `violazioni`  JSON        DEFAULT NULL,
  `sanzione`    BIGINT      NOT NULL DEFAULT 0,
  `momento`     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_cantiere` (`cantiere_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  VOLONTARI DEL GRUPPO COMUNALE
--
--  Non è un lavoro e non ha gradi: è un elenco. `interventi` è l'unica
--  cosa che si accumula, e serve solo a riconoscere chi c'era.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pc_volontari` (
  `citizenid`   VARCHAR(12) NOT NULL,
  `nome`        VARCHAR(96) NOT NULL,
  `interventi`  INT UNSIGNED NOT NULL DEFAULT 0,
  `iscritto_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_interventi` (`interventi`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  SCENARI
--
--  I punti dei compiti non si salvano: si generano all'apertura e vivono
--  in memoria. Uno scenario interrotto da un riavvio è uno scenario
--  perso, ed è giusto così — l'emergenza è il momento in cui accade.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pc_emergenze` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`           VARCHAR(32) NOT NULL,
  `zona`           VARCHAR(96) NOT NULL,
  `allerta`        VARCHAR(16) NOT NULL DEFAULT 'verde',
  `compiti_totali` INT UNSIGNED NOT NULL DEFAULT 0,
  `compiti_fatti`  INT UNSIGNED NOT NULL DEFAULT 0,
  `partecipanti`   INT UNSIGNED NOT NULL DEFAULT 0,
  `esito`          ENUM('aperta','risolta','fallita') NOT NULL DEFAULT 'aperta',
  `aperta_il`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`      TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_esito` (`esito`, `id`),
  KEY `idx_tipo` (`tipo`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- ---------------------------------------------------------------------------
--  LO STATO CHE RISPONDE · ricorsi, licenze, registri, riscossione
--
--  Il lato dell'amministrazione che non punisce ma decide: il ricorso al
--  Prefetto, l'istanza in Questura, l'iscrizione al Registro delle
--  Imprese, la rateizzazione della cartella. E quello che ne consegue
--  quando la risposta è no.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
--  PREFETTURA · ricorsi, ordinanze, elenco prefettizio
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `prefettura_ricorsi` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `multa_id`      INT UNSIGNED NOT NULL,
  `citizenid`     VARCHAR(12)  NOT NULL,
  `sede`          ENUM('prefetto','giudice_pace') NOT NULL DEFAULT 'prefetto',
  `motivo`        TEXT         NOT NULL,
  `importo_originario` BIGINT  NOT NULL COMMENT 'centesimi, com era il verbale',
  `presentato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `decide_entro`  DATETIME     NOT NULL COMMENT 'oltre questo termine scatta il silenzio-accoglimento',
  `stato`         ENUM('istruttoria','accolto','rigettato','silenzio_accoglimento') NOT NULL DEFAULT 'istruttoria',
  `deciso_da`     VARCHAR(12)  DEFAULT NULL,
  `decisione`     VARCHAR(255) DEFAULT NULL,
  `importo_ingiunto` BIGINT    NOT NULL DEFAULT 0 COMMENT 'art. 204 CdS: non meno del doppio del minimo',
  `deciso_il`     TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ricorso_multa` (`multa_id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_termine` (`stato`, `decide_entro`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `prefettura_ordinanze` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `tipo`        ENUM('sospensione_patente','revoca_patente','foglio_via','ingiunzione') NOT NULL,
  `giorni`      INT          NOT NULL DEFAULT 0,
  `importo`     BIGINT       NOT NULL DEFAULT 0,
  `motivo`      VARCHAR(255) NOT NULL,
  `emessa_da`   VARCHAR(12)  DEFAULT NULL,
  `emessa_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `eseguita`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `tipo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- L'elenco prefettizio degli addetti ai servizi di controllo (i buttafuori).
-- Esiste davvero, e senza l'iscrizione fare il filtro all'ingresso di un
-- locale non è un mestiere: è un illecito.
CREATE TABLE IF NOT EXISTS `prefettura_elenco` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `iscritto_il` DATE         NOT NULL,
  `scadenza`    DATE         NOT NULL,
  `sospeso`     TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo_sospensione` VARCHAR(160) DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_valido` (`sospeso`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  QUESTURA · istanze, passaporti, DASPO
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `questura_istanze` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `tipo`        ENUM('passaporto','porto_armi','licenza_spettacolo') NOT NULL,
  `dettaglio`   VARCHAR(64)  DEFAULT NULL COMMENT 'per il porto d armi: sportivo|caccia|difesa',
  `presentata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `stato`       ENUM('istruttoria','accolta','rigettata') NOT NULL DEFAULT 'istruttoria',
  `motivo`      VARCHAR(255) DEFAULT NULL,
  `decisa_da`   VARCHAR(12)  DEFAULT NULL,
  `decisa_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_coda` (`stato`, `presentata_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `questura_passaporti` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `numero`      VARCHAR(16)  NOT NULL,
  `rilascio`    DATE         NOT NULL,
  `scadenza`    DATE         NOT NULL,
  `ritirato`    TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo_ritiro` VARCHAR(160) DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_numero` (`numero`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `questura_daspo` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `luogo`       VARCHAR(96)  NOT NULL COMMENT 'stadio, locale, area urbana',
  `motivo`      VARCHAR(255) NOT NULL,
  `con_firma`   TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'obbligo di presentazione',
  `emesso_da`   VARCHAR(12)  DEFAULT NULL,
  `emesso_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL,
  `revocato`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `revocato`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  TIRO A SEGNO NAZIONALE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `tsn_iscritti` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `iscritto_il` DATE         NOT NULL,
  `tessera`     VARCHAR(16)  NOT NULL,
  `scadenza_tessera` DATE    NOT NULL,
  `lezioni`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `certificato_il` DATE      DEFAULT NULL COMMENT 'idoneità al maneggio delle armi',
  `certificato_scadenza` DATE DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_tessera` (`tessera`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `tsn_sessioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `istruttore`  VARCHAR(12)  DEFAULT NULL,
  `colpi`       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `punteggio`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  RISCOSSIONE · ruoli, rate, misure cautelari
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `riscossione_ruoli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `origine`     ENUM('tributo','multa','contributo','sanzione') NOT NULL,
  `riferimento` INT UNSIGNED DEFAULT NULL COMMENT 'id della multa o del tributo di partenza',
  `descrizione` VARCHAR(160) NOT NULL,
  `importo`     BIGINT       NOT NULL COMMENT 'centesimi, capitale',
  `aggio`       BIGINT       NOT NULL DEFAULT 0 COMMENT 'oneri di riscossione',
  `notificata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL COMMENT '60 giorni dalla notifica, poi è esecutiva',
  `stato`       ENUM('notificata','rateizzata','pagata','esecutiva','sgravata') NOT NULL DEFAULT 'notificata',
  `incassato`   BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_scadenza` (`stato`, `scadenza`),
  KEY `idx_origine` (`origine`, `riferimento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `riscossione_rate` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ruolo_id`    INT UNSIGNED NOT NULL,
  `numero`      TINYINT UNSIGNED NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `scadenza`    DATETIME     NOT NULL,
  `pagata`      TINYINT(1)   NOT NULL DEFAULT 0,
  `pagata_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ruolo` (`ruolo_id`, `pagata`),
  CONSTRAINT `fk_rata_ruolo` FOREIGN KEY (`ruolo_id`) REFERENCES `riscossione_ruoli` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `riscossione_misure` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `ruolo_id`    INT UNSIGNED DEFAULT NULL,
  `tipo`        ENUM('preavviso_fermo','fermo','ipoteca','pignoramento_conto','pignoramento_stipendio') NOT NULL,
  `bersaglio`   VARCHAR(48)  DEFAULT NULL COMMENT 'targa, codice immobile, iban',
  `importo`     BIGINT       NOT NULL DEFAULT 0,
  `disposta_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revocata`    TINYINT(1)   NOT NULL DEFAULT 0,
  `revocata_il` TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `revocata`),
  KEY `idx_bersaglio` (`bersaglio`, `revocata`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ISPETTORATO DEL LAVORO
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `ispettorato_accessi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lavoro`      VARCHAR(32)  NOT NULL,
  `luogo`       VARCHAR(96)  DEFAULT NULL,
  `ispettore`   VARCHAR(12)  NOT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `presenti`    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `in_nero`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `esito`       ENUM('regolare','irregolare','sospensione') NOT NULL DEFAULT 'regolare',
  `sanzione`    BIGINT       NOT NULL DEFAULT 0,
  `verbale`     TEXT         DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lavoro` (`lavoro`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ispettorato_sospensioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lavoro`      VARCHAR(32)  NOT NULL,
  `motivo`      VARCHAR(255) NOT NULL,
  `disposta_da` VARCHAR(12)  DEFAULT NULL,
  `disposta_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `importo_revoca` BIGINT    NOT NULL DEFAULT 0,
  `revocata`    TINYINT(1)   NOT NULL DEFAULT 0,
  `revocata_il` TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_attiva` (`lavoro`, `revocata`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  REGISTRO DELLE IMPRESE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `registro_rea` (
  `impresa_id`  INT UNSIGNED NOT NULL COMMENT 'la riga in `imprese`: la P.IVA la dà l Agenzia delle Entrate, il REA la Camera di Commercio',
  `rea`         VARCHAR(16)  NOT NULL COMMENT 'numero di Repertorio Economico Amministrativo',
  `iscritta_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `stato`       ENUM('attiva','sospesa','cessata') NOT NULL DEFAULT 'attiva',
  `cessata_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`impresa_id`),
  UNIQUE KEY `uq_rea` (`rea`),
  CONSTRAINT `fk_rea_impresa` FOREIGN KEY (`impresa_id`) REFERENCES `imprese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `registro_soci` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `impresa_id`  INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `quota`       SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'percentuale',
  `amministratore` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_socio` (`impresa_id`, `citizenid`),
  CONSTRAINT `fk_socio_impresa` FOREIGN KEY (`impresa_id`) REFERENCES `imprese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `registro_diritto_annuale` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `impresa_id`  INT UNSIGNED NOT NULL,
  `periodo`     VARCHAR(16)  NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `pagato`      TINYINT(1)   NOT NULL DEFAULT 0,
  `emesso_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_periodo` (`impresa_id`, `periodo`),
  CONSTRAINT `fk_diritto_impresa` FOREIGN KEY (`impresa_id`) REFERENCES `imprese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  S.I.A.E.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `siae_permessi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `locale`      VARCHAR(48)  NOT NULL,
  `tipo`        ENUM('musica_ambiente','musica_dal_vivo','trattenimento_danzante') NOT NULL,
  `richiedente` VARCHAR(12)  NOT NULL,
  `rilasciato_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL,
  `importo`     BIGINT       NOT NULL DEFAULT 0,
  `revocato`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_locale` (`locale`, `revocato`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `siae_bordero` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `permesso_id` INT UNSIGNED DEFAULT NULL,
  `locale`      VARCHAR(48)  NOT NULL,
  `brano`       VARCHAR(160) NOT NULL,
  `esecutore`   VARCHAR(12)  DEFAULT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `abusiva`     TINYINT      NOT NULL DEFAULT 0 COMMENT '0 = coperta da permesso, 1 = abusiva, 2 = già contestata in un verbale',
  PRIMARY KEY (`id`),
  KEY `idx_locale` (`locale`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `siae_verbali` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `locale`      VARCHAR(48)  NOT NULL,
  `intestatario` VARCHAR(12) DEFAULT NULL,
  `ispettore`   VARCHAR(12)  NOT NULL,
  `motivo`      VARCHAR(255) NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pagato`      TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_locale` (`locale`, `pagato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  LOCALI NOTTURNI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `locali_notturni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(24)  NOT NULL,
  `nome`        VARCHAR(64)  NOT NULL,
  `gestore`     VARCHAR(12)  DEFAULT NULL,
  `capienza`    SMALLINT UNSIGNED NOT NULL DEFAULT 80,
  `licenza_scadenza` DATE    DEFAULT NULL COMMENT 'art. 68 TULPS, la rilascia la Questura',
  `sospeso`     TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo_sospensione` VARCHAR(160) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `discoteca_serate` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `locale`      VARCHAR(24)  NOT NULL,
  `nome`        VARCHAR(64)  NOT NULL,
  `organizzata_da` VARCHAR(12) NOT NULL,
  `ingresso`    BIGINT       NOT NULL DEFAULT 0,
  `aperta_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`   TIMESTAMP    NULL DEFAULT NULL,
  `presenze`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `picco`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `incasso`     BIGINT       NOT NULL DEFAULT 0,
  `stato`       ENUM('aperta','chiusa','interrotta') NOT NULL DEFAULT 'aperta',
  PRIMARY KEY (`id`),
  KEY `idx_locale` (`locale`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `discoteca_ingressi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serata_id`   INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `respinto`    TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo`      VARCHAR(120) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_serata` (`serata_id`, `respinto`),
  CONSTRAINT `fk_ingresso_serata` FOREIGN KEY (`serata_id`) REFERENCES `discoteca_serate` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  BENI CULTURALI · siti, reperti, autorizzazioni allo scavo
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `beniculturali_reperti` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(24)  NOT NULL,
  `nome`        VARCHAR(96)  NOT NULL,
  `sito`        VARCHAR(32)  NOT NULL,
  `valore`      BIGINT       NOT NULL DEFAULT 0 COMMENT 'valore di perizia, centesimi',
  `stato`       ENUM('detenuto','dichiarato','sequestrato','museo','esportato') NOT NULL DEFAULT 'detenuto',
  `detentore`   VARCHAR(12)  DEFAULT NULL,
  `trovato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `autorizzato` TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 = scavo regolare',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_detentore` (`detentore`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `beniculturali_autorizzazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `sito`        VARCHAR(32)  NOT NULL,
  `rilasciata_da` VARCHAR(12) DEFAULT NULL,
  `rilasciata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATETIME     NOT NULL,
  `revocata`    TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_valida` (`citizenid`, `sito`, `revocata`, `scadenza`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `siti_scavati` (
  `sito`        VARCHAR(32)  NOT NULL,
  `prelievi`    INT UNSIGNED NOT NULL DEFAULT 0,
  `ultimo`      TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`sito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CONDOMINIO
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `condomini` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(24)  NOT NULL,
  `nome`        VARCHAR(64)  NOT NULL,
  `indirizzo`   VARCHAR(96)  NOT NULL,
  `amministratore` VARCHAR(12) DEFAULT NULL,
  `compenso`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'compenso annuo dell amministratore',
  `fondo`       BIGINT       NOT NULL DEFAULT 0 COMMENT 'cassa condominiale, centesimi',
  `decoro`      SMALLINT     NOT NULL DEFAULT 50 COMMENT '0-100: quanto è tenuto. Alza o abbassa il valore degli appartamenti',
  `nominato_il` TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `condominio_unita` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `condominio_id` INT UNSIGNED NOT NULL,
  `immobile_id` INT UNSIGNED NOT NULL,
  `millesimi`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_unita` (`condominio_id`, `immobile_id`),
  CONSTRAINT `fk_unita_cond` FOREIGN KEY (`condominio_id`) REFERENCES `condomini` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `condominio_spese` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `condominio_id` INT UNSIGNED NOT NULL,
  `descrizione` VARCHAR(160) NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `tipo`        ENUM('ordinaria','straordinaria') NOT NULL DEFAULT 'ordinaria',
  `stato`       ENUM('proposta','deliberata','respinta','chiusa') NOT NULL DEFAULT 'proposta',
  `proposta_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deliberata_il` TIMESTAMP  NULL DEFAULT NULL,
  `millesimi_favorevoli` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `millesimi_contrari`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_cond` (`condominio_id`, `stato`),
  CONSTRAINT `fk_spesa_cond` FOREIGN KEY (`condominio_id`) REFERENCES `condomini` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `condominio_voti` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `spesa_id`    INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `millesimi`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `favorevole`  TINYINT(1)   NOT NULL DEFAULT 1,
  `votato_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_voto` (`spesa_id`, `citizenid`),
  CONSTRAINT `fk_voto_spesa` FOREIGN KEY (`spesa_id`) REFERENCES `condominio_spese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `condominio_quote` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `spesa_id`    INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `pagata`      TINYINT(1)   NOT NULL DEFAULT 0,
  `scadenza`    DATETIME     NOT NULL,
  `ingiunta`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'decreto ingiuntivo art. 63 disp. att. c.c.',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_quota` (`spesa_id`, `citizenid`),
  KEY `idx_moroso` (`citizenid`, `pagata`),
  CONSTRAINT `fk_quota_spesa` FOREIGN KEY (`spesa_id`) REFERENCES `condominio_spese` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  DONAZIONE DI SANGUE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `donatori` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `gruppo`      VARCHAR(4)   NOT NULL COMMENT '0-, 0+, A-, A+, B-, B+, AB-, AB+',
  `iscritto_il` DATE         NOT NULL,
  `idoneo`      TINYINT(1)   NOT NULL DEFAULT 1,
  `motivo_sospensione` VARCHAR(160) DEFAULT NULL,
  `prossima_donazione` DATETIME NULL DEFAULT NULL,
  `donazioni`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  KEY `idx_gruppo` (`gruppo`, `idoneo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `donazioni_sangue` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `gruppo`      VARCHAR(4)   NOT NULL,
  `centro`      VARCHAR(48)  NOT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `scorte_sangue` (
  `gruppo`      VARCHAR(4)   NOT NULL,
  `sacche`      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `aggiornato`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`gruppo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  AUTOSTRADE · pedaggio e Telepass
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `autostrade_transiti` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`       VARCHAR(10)  NOT NULL,
  `citizenid`   VARCHAR(12)  DEFAULT NULL,
  `ingresso`    VARCHAR(32)  NOT NULL,
  `uscita`      VARCHAR(32)  DEFAULT NULL,
  `entrato_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `uscito_il`   TIMESTAMP    NULL DEFAULT NULL,
  `classe`      VARCHAR(8)   NOT NULL DEFAULT 'A',
  `pedaggio`    BIGINT       NOT NULL DEFAULT 0,
  `stato`       ENUM('aperto','pagato','insoluto','telepass') NOT NULL DEFAULT 'aperto',
  PRIMARY KEY (`id`),
  KEY `idx_targa` (`targa`, `stato`),
  KEY `idx_aperto` (`stato`, `entrato_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `telepass` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `targa`       VARCHAR(10)  NOT NULL,
  `codice`      VARCHAR(16)  NOT NULL,
  `attivo`      TINYINT(1)   NOT NULL DEFAULT 1,
  `insoluto`    BIGINT       NOT NULL DEFAULT 0,
  `attivato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_targa` (`targa`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_pg` (`citizenid`, `attivo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Scorte di sangue iniziali: i gruppi esistono comunque, anche vuoti.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `scorte_sangue` (`gruppo`, `sacche`) VALUES
  ('0-', 6), ('0+', 14), ('A-', 5), ('A+', 16),
  ('B-', 4), ('B+', 9),  ('AB-', 2), ('AB+', 4);

-- ---------------------------------------------------------------------------
--  QUELLO CHE SUCCEDE DOPO · rimozioni, sinistri, controlli, dichiarazioni
--
--  Il carro attrezzi, la constatazione amichevole, l'A.R.P.A., l'anti-
--  riciclaggio, il 730, il Ser.D., il veterinario, la tabaccheria, il
--  taxi, lo stadio, la vertenza sindacale e il piano di volo.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
--  CARRO ATTREZZI E DEPOSITERIA
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `rimozioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`       VARCHAR(10)  NOT NULL,
  `citizenid`   VARCHAR(12)  DEFAULT NULL COMMENT 'intestatario al momento della rimozione',
  `motivo`      VARCHAR(160) NOT NULL,
  `multa_id`    INT UNSIGNED DEFAULT NULL,
  `operatore`   VARCHAR(12)  DEFAULT NULL,
  `deposito`    VARCHAR(32)  NOT NULL DEFAULT 'depositeria',
  `rimossa_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `costo_rimozione` BIGINT   NOT NULL DEFAULT 0,
  `diurnaria`   BIGINT       NOT NULL DEFAULT 0 COMMENT 'costo di custodia al giorno',
  `stato`       ENUM('in_deposito','riscattato','alienato') NOT NULL DEFAULT 'in_deposito',
  `riscattata_il` TIMESTAMP  NULL DEFAULT NULL,
  `pagato`      BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_targa` (`targa`, `stato`),
  KEY `idx_pg` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  SINISTRI · constatazione amichevole, perizia, liquidazione
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sinistri` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa_a`     VARCHAR(10)  NOT NULL,
  `targa_b`     VARCHAR(10)  DEFAULT NULL COMMENT 'null = sinistro senza controparte',
  `citizenid_a` VARCHAR(12)  NOT NULL,
  `citizenid_b` VARCHAR(12)  DEFAULT NULL,
  `luogo`       VARCHAR(96)  DEFAULT NULL,
  `avvenuto_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `firma_a`     TINYINT(1)   NOT NULL DEFAULT 0,
  `firma_b`     TINYINT(1)   NOT NULL DEFAULT 0,
  `responsabile` ENUM('a','b','concorso','da_accertare') NOT NULL DEFAULT 'da_accertare',
  `danni_a`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi, stima di perizia',
  `danni_b`     BIGINT       NOT NULL DEFAULT 0,
  `feriti`      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `stato`       ENUM('aperto','firmato','in_perizia','liquidato','contestato','archiviato') NOT NULL DEFAULT 'aperto',
  `perito`      VARCHAR(12)  DEFAULT NULL,
  `periziato_il` TIMESTAMP   NULL DEFAULT NULL,
  `liquidato`   BIGINT       NOT NULL DEFAULT 0,
  `frode`       TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_a` (`citizenid_a`, `stato`),
  KEY `idx_b` (`citizenid_b`, `stato`),
  KEY `idx_targhe` (`targa_a`, `targa_b`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  A.R.P.A. · controlli ambientali
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `arpa_controlli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`        ENUM('emissioni','scarico','rumore','amianto','suolo') NOT NULL,
  `bersaglio`   VARCHAR(64)  NOT NULL COMMENT 'sito, lotto, locale, targa',
  `citizenid`   VARCHAR(12)  DEFAULT NULL COMMENT 'il responsabile, se individuato',
  `tecnico`     VARCHAR(12)  NOT NULL,
  `valore`      INT          NOT NULL DEFAULT 0 COMMENT 'valore misurato, unità secondo il tipo',
  `limite`      INT          NOT NULL DEFAULT 0,
  `esito`       ENUM('conforme','superamento','grave') NOT NULL DEFAULT 'conforme',
  `sanzione`    BIGINT       NOT NULL DEFAULT 0,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_bersaglio` (`bersaglio`, `quando`),
  KEY `idx_pg` (`citizenid`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `arpa_prescrizioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `controllo_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  DEFAULT NULL,
  `bersaglio`   VARCHAR(64)  NOT NULL,
  `descrizione` VARCHAR(255) NOT NULL,
  `scade_il`    DATETIME     NOT NULL,
  `ottemperata` TINYINT(1)   NOT NULL DEFAULT 0,
  `sanzionata`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'la mancata ottemperanza si sanziona una volta sola',
  PRIMARY KEY (`id`),
  KEY `idx_scadenza` (`ottemperata`, `scade_il`),
  CONSTRAINT `fk_prescr_controllo` FOREIGN KEY (`controllo_id`) REFERENCES `arpa_controlli` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  ANTIRICICLAGGIO · D.Lgs. 231/2007
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `aml_verifiche` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `profilo`     ENUM('basso','medio','alto') NOT NULL DEFAULT 'medio',
  `fonte_reddito` VARCHAR(96) DEFAULT NULL COMMENT 'quello che il cliente ha dichiarato',
  `verificata_da` VARCHAR(12) DEFAULT NULL,
  `aggiornata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_profilo` (`profilo`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `aml_segnalazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `tipo`        ENUM('contante','frazionamento','profilo','terzi','cripto') NOT NULL,
  `importo`     BIGINT       NOT NULL DEFAULT 0,
  `motivo`      VARCHAR(255) NOT NULL,
  `segnalata_da` VARCHAR(12) DEFAULT NULL COMMENT 'null = generata dal sistema',
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `stato`       ENUM('aperta','archiviata','trasmessa') NOT NULL DEFAULT 'aperta',
  `esito`       VARCHAR(255) DEFAULT NULL,
  `chiusa_da`   VARCHAR(12)  DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_coda` (`stato`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `aml_congelamenti` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `segnalazione_id` INT UNSIGNED DEFAULT NULL,
  `disposto_da` VARCHAR(12)  DEFAULT NULL,
  `disposto_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL COMMENT 'il blocco non è eterno: o si conferma o cade',
  `esito`       ENUM('in_corso','restituito','confiscato') NOT NULL DEFAULT 'in_corso',
  `chiuso_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  C.A.F. · dichiarazione dei redditi
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `dichiarazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `periodo`     VARCHAR(16)  NOT NULL,
  `reddito`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'imponibile ricostruito dalle buste paga',
  `ritenute`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'IRPEF già trattenuta alla fonte',
  `detrazioni`  BIGINT       NOT NULL DEFAULT 0,
  `imposta`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'quella davvero dovuta, a scaglioni',
  `saldo`       BIGINT       NOT NULL DEFAULT 0 COMMENT 'positivo = credito, negativo = debito',
  `stato`       ENUM('presentata','liquidata','accertata') NOT NULL DEFAULT 'presentata',
  `caf`         VARCHAR(12)  DEFAULT NULL COMMENT 'chi ha apposto il visto',
  `presentata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `liquidata_il` TIMESTAMP   NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_periodo` (`citizenid`, `periodo`),
  KEY `idx_stato` (`stato`, `presentata_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dichiarazione_detrazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dichiarazione_id` INT UNSIGNED NOT NULL,
  `tipo`        VARCHAR(32)  NOT NULL,
  `descrizione` VARCHAR(160) NOT NULL,
  `spesa`       BIGINT       NOT NULL,
  `detrazione`  BIGINT       NOT NULL,
  `documentata` TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '0 = dichiarata e non provata: se arriva il controllo, salta',
  PRIMARY KEY (`id`),
  KEY `idx_dich` (`dichiarazione_id`),
  CONSTRAINT `fk_detr_dich` FOREIGN KEY (`dichiarazione_id`) REFERENCES `dichiarazioni` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Ser.D. · dipendenze e art. 75 D.P.R. 309/1990
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `serd_segnalazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `sostanza`    VARCHAR(32)  NOT NULL,
  `quantita`    INT UNSIGNED NOT NULL DEFAULT 0,
  `segnalata_da` VARCHAR(12) DEFAULT NULL,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `precedenti`  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'quante segnalazioni prima di questa',
  `stato`       ENUM('convocato','in_programma','archiviata','sanzionata') NOT NULL DEFAULT 'convocato',
  `patente_sospesa` SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'giorni di sospensione disposti',
  `chiusa_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `serd_programmi` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `segnalazione_id` INT UNSIGNED DEFAULT NULL,
  `sessioni`    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `sessioni_richieste` TINYINT UNSIGNED NOT NULL DEFAULT 4,
  `operatore`   VARCHAR(12)  DEFAULT NULL,
  `iniziato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `concluso_il` TIMESTAMP    NULL DEFAULT NULL,
  `esito`       ENUM('in_corso','concluso','interrotto') NOT NULL DEFAULT 'in_corso',
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `esito`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  VETERINARIA
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `vet_cartelle` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `animale_id`  INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `motivo`      VARCHAR(96)  NOT NULL,
  `diagnosi`    VARCHAR(160) DEFAULT NULL,
  `veterinario` VARCHAR(12)  DEFAULT NULL,
  `costo`       BIGINT       NOT NULL DEFAULT 0,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_animale` (`animale_id`, `quando`),
  CONSTRAINT `fk_cartella_animale` FOREIGN KEY (`animale_id`) REFERENCES `animali` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vet_vaccinazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `animale_id`  INT UNSIGNED NOT NULL,
  `tipo`        VARCHAR(32)  NOT NULL,
  `somministrata_il` DATE    NOT NULL,
  `scadenza`    DATE         NOT NULL,
  `veterinario` VARCHAR(12)  DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_vaccino` (`animale_id`, `tipo`),
  CONSTRAINT `fk_vacc_animale` FOREIGN KEY (`animale_id`) REFERENCES `animali` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vet_maltrattamenti` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `animale_id`  INT UNSIGNED DEFAULT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `accertato_da` VARCHAR(12) NOT NULL,
  `descrizione` VARCHAR(255) NOT NULL,
  `sequestrato` TINYINT(1)   NOT NULL DEFAULT 0,
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  TABACCHERIA · lotto, gratta e vinci, valori bollati
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `lotto_estrazioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ruota`       VARCHAR(16)  NOT NULL,
  `numeri`      VARCHAR(32)  NOT NULL COMMENT 'cinque numeri separati da virgola',
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ruota` (`ruota`, `quando`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lotto_giocate` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `ruota`       VARCHAR(16)  NOT NULL,
  `sorte`       ENUM('estratto','ambo','terno','quaterna','cinquina') NOT NULL,
  `numeri`      VARCHAR(32)  NOT NULL,
  `importo`     BIGINT       NOT NULL,
  `estrazione_id` INT UNSIGNED DEFAULT NULL,
  `vincita`     BIGINT       NOT NULL DEFAULT 0,
  `stato`       ENUM('aperta','vinta','perdente') NOT NULL DEFAULT 'aperta',
  `quando`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`, `stato`),
  KEY `idx_aperte` (`stato`, `ruota`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `valori_bollati` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(20)  NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `valore`      BIGINT       NOT NULL,
  `emesso_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `usato`       TINYINT(1)   NOT NULL DEFAULT 0,
  `usato_per`   VARCHAR(96)  DEFAULT NULL,
  `usato_il`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_pg` (`citizenid`, `usato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  TAXI
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `taxi_licenze` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `numero`      VARCHAR(16)  NOT NULL,
  `targa`       VARCHAR(10)  DEFAULT NULL COMMENT 'il veicolo su cui è esercitata',
  `rilasciata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATE         NOT NULL,
  `sospesa`     TINYINT(1)   NOT NULL DEFAULT 0,
  `motivo_sospensione` VARCHAR(160) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_numero` (`numero`),
  UNIQUE KEY `uq_pg` (`citizenid`),
  KEY `idx_targa` (`targa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `taxi_corse` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tassista`    VARCHAR(12)  NOT NULL,
  `cliente`     VARCHAR(12)  DEFAULT NULL,
  `licenza`     VARCHAR(16)  DEFAULT NULL COMMENT 'null = corsa abusiva',
  `partenza`    VARCHAR(96)  DEFAULT NULL,
  `arrivo`      VARCHAR(96)  DEFAULT NULL,
  `metri`       INT UNSIGNED NOT NULL DEFAULT 0,
  `secondi`     INT UNSIGNED NOT NULL DEFAULT 0,
  `importo`     BIGINT       NOT NULL DEFAULT 0,
  `pagata`      TINYINT(1)   NOT NULL DEFAULT 0,
  `iniziata_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_tassista` (`tassista`, `chiusa_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  CALCIO
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `calcio_squadre` (
  `codice`      VARCHAR(16)  NOT NULL,
  `nome`        VARCHAR(48)  NOT NULL,
  `punti`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `giocate`     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `vinte`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `pari`        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `perse`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `gol_fatti`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `gol_subiti`  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`codice`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `calcio_partite` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `casa`        VARCHAR(16)  NOT NULL,
  `ospite`      VARCHAR(16)  NOT NULL,
  `gol_casa`    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `gol_ospite`  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `spettatori`  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `incassi`     BIGINT       NOT NULL DEFAULT 0,
  `incidenti`   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `stato`       ENUM('programmata','in_corso','finita','sospesa') NOT NULL DEFAULT 'programmata',
  `inizio_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fine_il`     TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_stato` (`stato`, `inizio_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `calcio_tifosi` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `squadra`     VARCHAR(16)  NOT NULL,
  `tessera`     VARCHAR(16)  NOT NULL,
  `ingressi`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `iscritto_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_tessera` (`tessera`),
  KEY `idx_squadra` (`squadra`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  SINDACATO · vertenze e sciopero
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `sindacato_iscritti` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `sigla`       VARCHAR(16)  NOT NULL,
  `iscritto_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `quota_versata_il` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`citizenid`),
  KEY `idx_sigla` (`sigla`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vertenze` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `lavoro`      VARCHAR(32)  NOT NULL,
  `oggetto`     ENUM('retribuzione','sicurezza','orario','licenziamento') NOT NULL,
  `richiesta`   VARCHAR(255) NOT NULL,
  `promotore`   VARCHAR(12)  NOT NULL,
  `aperta_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL,
  `adesioni`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `stato`       ENUM('aperta','sciopero','accolta','respinta','decaduta') NOT NULL DEFAULT 'aperta',
  `chiusa_il`   TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_lavoro` (`lavoro`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vertenza_adesioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `vertenza_id` INT UNSIGNED NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `aderito_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_adesione` (`vertenza_id`, `citizenid`),
  CONSTRAINT `fk_adesione_vertenza` FOREIGN KEY (`vertenza_id`) REFERENCES `vertenze` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  AVIAZIONE
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `licenze_volo` (
  `citizenid`   VARCHAR(12)  NOT NULL,
  `numero`      VARCHAR(16)  NOT NULL,
  `tipo`        ENUM('ppl','cpl','elicottero') NOT NULL DEFAULT 'ppl',
  `rilasciata_il` TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scadenza`    DATE         NOT NULL,
  `ore_volo`    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `sospesa`     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`),
  UNIQUE KEY `uq_numero` (`numero`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `voli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codice`      VARCHAR(16)  NOT NULL,
  `pilota`      VARCHAR(12)  NOT NULL,
  `aeromobile`  VARCHAR(32)  NOT NULL,
  `partenza`    VARCHAR(32)  NOT NULL,
  `arrivo`      VARCHAR(32)  NOT NULL,
  `carico`      VARCHAR(48)  DEFAULT NULL,
  `autorizzato` TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'piano di volo depositato',
  `stato`       ENUM('pianificato','in_volo','atterrato','abortito') NOT NULL DEFAULT 'pianificato',
  `decollato_il` TIMESTAMP   NULL DEFAULT NULL,
  `atterrato_il` TIMESTAMP   NULL DEFAULT NULL,
  `compenso`    BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_codice` (`codice`),
  KEY `idx_pilota` (`pilota`, `stato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
--  Le squadre del campionato: esistono comunque, anche senza partite.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `calcio_squadre` (`codice`, `nome`) VALUES
  ('aurea',    'A.C. Aurea'),
  ('portuale', 'Portuale Calcio'),
  ('paleto',   'Paleto Bay F.C.'),
  ('sandy',    'Sandy Shores United'),
  ('vespucci', 'Vespucci 1921'),
  ('harmony',  'Harmony Sportiva');

-- -----------------------------------------------------------------------------
--  Ordinanze della Capitaneria
--
--  Il centro è (x, y) senza z: un'ordinanza è un cerchio sulla carta
--  nautica, non una sfera.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_ordinanze` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`           ENUM('balneazione','specchio','pesca','velocita') NOT NULL,
  `centro_x`       DOUBLE       NOT NULL,
  `centro_y`       DOUBLE       NOT NULL,
  `raggio`         SMALLINT UNSIGNED NOT NULL COMMENT 'metri',
  `motivo`         VARCHAR(160) NOT NULL,
  `ufficiale`      VARCHAR(12)  DEFAULT NULL,
  `nome_ufficiale` VARCHAR(64)  DEFAULT NULL,
  `emessa_il`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`       DATETIME     NOT NULL,
  `revocata`       TINYINT(1)   NOT NULL DEFAULT 0,
  `revocata_il`    TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vigore` (`revocata`, `scade_il`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Controlli in mare
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_controlli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`       VARCHAR(10)  NOT NULL,
  `conducente`  VARCHAR(12)  NOT NULL,
  `operatore`   VARCHAR(12)  NOT NULL,
  `rilievi`     VARCHAR(255) NOT NULL,
  `sanzione`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `eseguito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_targa` (`targa`),
  KEY `idx_conducente` (`conducente`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Fermo amministrativo di un'unità
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_fermi` (
  `id`                 INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `targa`              VARCHAR(10)  NOT NULL,
  `proprietario`       VARCHAR(12)  DEFAULT NULL,
  `motivo`             VARCHAR(255) NOT NULL,
  `disposto_da`        VARCHAR(12)  DEFAULT NULL,
  `importo`            BIGINT       NOT NULL COMMENT 'centesimi del dissequestro',
  `disposto_il`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `dissequestrato`     TINYINT(1)   NOT NULL DEFAULT 0,
  `dissequestrato_il`  TIMESTAMP    NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperto` (`dissequestrato`, `targa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Eventi di ricerca e soccorso
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `capitaneria_sar` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `centro_x`   DOUBLE       NOT NULL,
  `centro_y`   DOUBLE       NOT NULL,
  `motivo`     VARCHAR(160) NOT NULL,
  `disperso`   VARCHAR(12)  DEFAULT NULL,
  `aperto_il`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `chiusa`     TINYINT(1)   NOT NULL DEFAULT 0,
  `chiusa_il`  TIMESTAMP    NULL DEFAULT NULL,
  `esito`      ENUM('recuperato','sospesa') DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_aperte` (`chiusa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Incendi boschivi e vincolo decennale (art. 10 L. 353/2000)
--
--  Il vincolo è la cosa più pesante che questa risorsa sa fare: dieci
--  anni in cui su quel terreno non si costruisce e non si pascola. Serve
--  a togliere il movente a chi brucia per edificare.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `forestale_incendi` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `centro_x`      DOUBLE       NOT NULL,
  `centro_y`      DOUBLE       NOT NULL,
  `ettari`        DECIMAL(6,2) NOT NULL DEFAULT 0,
  `origine`       ENUM('ignota','colposa','dolosa','naturale') NOT NULL DEFAULT 'ignota',
  `responsabile`  VARCHAR(12)  DEFAULT NULL,
  `accertato_da`  VARCHAR(12)  DEFAULT NULL,
  `note`          VARCHAR(255) DEFAULT NULL,
  `rilevato_il`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `vincolo`       TINYINT(1)   NOT NULL DEFAULT 0,
  `vincolo_fino`  DATE         DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vincolo` (`vincolo`, `vincolo_fino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Verbali della vigilanza venatoria e ambientale
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `forestale_accertamenti` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tipo`         ENUM('bracconaggio','taglio','discarica','pascolo','vincolo') NOT NULL,
  `citizenid`    VARCHAR(12)  DEFAULT NULL,
  `operatore`    VARCHAR(12)  NOT NULL,
  `luogo`        VARCHAR(96)  DEFAULT NULL,
  `descrizione`  VARCHAR(255) NOT NULL,
  `sanzione`     BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `sequestro`    VARCHAR(96)  DEFAULT NULL,
  `accertato_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`),
  KEY `idx_tipo` (`tipo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- -----------------------------------------------------------------------------
--  Concessioni di posteggio
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_concessioni` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `posteggio`   VARCHAR(12)  NOT NULL,
  `mercato`     VARCHAR(24)  NOT NULL,
  `citizenid`   VARCHAR(12)  NOT NULL,
  `canone`      BIGINT       NOT NULL COMMENT 'centesimi, iscritti a ruolo come TOSAP',
  `assegnata_il` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `scade_il`    DATETIME     NOT NULL,
  `scaduta`     TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_attive` (`scaduta`, `posteggio`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Il registro delle vendite
--
--  È la tabella su cui la Guardia di Finanza fa i conti, quindi ci finisce
--  ogni singola vendita — anche e soprattutto quelle senza scontrino. Un
--  registro che annota solo le vendite battute non serve a controllare
--  niente: sarebbe sempre in ordine per definizione.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_vendite` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`      VARCHAR(12)  NOT NULL,
  `posteggio`      VARCHAR(12)  NOT NULL,
  `item`           VARCHAR(48)  NOT NULL,
  `quantita`       INT          NOT NULL DEFAULT 1,
  `importo`        BIGINT       NOT NULL COMMENT 'lordo al pubblico, centesimi',
  `scontrino`      TINYINT(1)   NOT NULL DEFAULT 0,
  `certificazione` VARCHAR(12)  DEFAULT NULL COMMENT 'IGP, DOP, DOCG, BIO',
  `venduto_il`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sessione` (`citizenid`, `venduto_il`),
  KEY `idx_scontrino` (`scontrino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
--  Controlli sui corrispettivi
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mercato_controlli` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(12)  NOT NULL COMMENT 'l\'esercente controllato',
  `operatore`   VARCHAR(12)  NOT NULL,
  `posteggio`   VARCHAR(12)  NOT NULL,
  `vendite`     INT          NOT NULL DEFAULT 0,
  `non_battute` INT          NOT NULL DEFAULT 0,
  `sanzione`    BIGINT       NOT NULL DEFAULT 0 COMMENT 'centesimi',
  `sospeso`     TINYINT(1)   NOT NULL DEFAULT 0,
  `eseguito_il` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pg` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
