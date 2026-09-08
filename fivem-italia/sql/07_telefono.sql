-- ---------------------------------------------------------------------------
--  AUREA · Italia Roleplay — telefono unico
--
--  Il registro delle chiamate, introdotto con la riscrittura del telefono.
--
--  Su un'installazione nuova basta 01_schema.sql. Questo file serve a chi
--  ha un database creato prima.
--
--  Esecuzione:
--      mysql -u utente -p nome_database < sql/07_telefono.sql
-- ---------------------------------------------------------------------------

SET NAMES utf8mb4;

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
