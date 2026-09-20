-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — 15. Lo Stato che risponde
--
--  Fin qui il server sapeva punire. Sapeva fare il verbale, aprire il
--  fascicolo, iscrivere il tributo. Quello che non sapeva fare era
--  ascoltare: non c'era un solo posto in cui un cittadino potesse dire
--  «questa multa è sbagliata» e avere una risposta.
--
--  Questa migrazione aggiunge il lato che mancava — il ricorso, la
--  licenza, l'iscrizione, la rateizzazione — e insieme il lato duro
--  che ne consegue: chi non paga dopo l'ingiunzione, chi lavora senza
--  essere in regola, chi scava dove non si scava.
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/15_stato.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

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
