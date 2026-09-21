-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — 16. Quello che succede dopo
--
--  La migrazione precedente ha messo in piedi gli uffici. Questa mette
--  in piedi le conseguenze quotidiane: il carro attrezzi che porta via
--  la macchina, il constatazione amichevole da firmare in due, la
--  dichiarazione dei redditi che fa il conguaglio, la segnalazione al
--  Prefetto per uso personale di stupefacenti, il tassametro, il sabato
--  allo stadio.
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/16_servizi.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

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
