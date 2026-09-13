-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — previdenza sociale (INPS e INAIL)
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/08_previdenza.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

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
