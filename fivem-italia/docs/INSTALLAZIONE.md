# Installazione di AUREA

Guida completa dal server vuoto alla prima connessione.

---

## 1. Requisiti

| Componente | Versione minima | Note |
|---|---|---|
| FXServer | build 7290+ | canale `latest` o `recommended` |
| MariaDB | 10.6 | in alternativa MySQL 8.0 |
| oxmysql | 2.7+ | unica dipendenza esterna |
| RAM | 4 GB | 8 GB consigliati sopra i 40 slot |

Il server richiede **OneSync abilitato** (già impostato in `server.cfg`):
diverse meccaniche leggono le entità lato server e senza OneSync non
funzionano.

---

## 2. Database

```sql
CREATE DATABASE aurea CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'aurea'@'localhost' IDENTIFIED BY 'scegli_una_password_solida';
GRANT ALL PRIVILEGES ON aurea.* TO 'aurea'@'localhost';
FLUSH PRIVILEGES;
```

Poi importa nell'ordine:

```bash
mysql -u aurea -p aurea < sql/01_schema.sql
mysql -u aurea -p aurea < sql/02_dati_iniziali.sql
```

Il charset `utf8mb4` non è opzionale: senza, accenti e apostrofi nei nomi
italiani si corrompono.

### Aggiornamento da una installazione precedente

`sql/01_schema.sql` è già completo: su un database nuovo non serve altro.
Se invece hai già un database della prima versione, esegui anche:

```bash
mysql -u aurea -p aurea < sql/03_espansione.sql
```

Aggiunge le tabelle dei moduli introdotti dopo — armadio dei completi,
registro delle armi e porto d'armi, licenze di pesca e caccia, stato civile
ed elezioni comunali, testata giornalistica. Usa `CREATE TABLE IF NOT
EXISTS`, quindi rieseguirlo non fa danni.

---

## 3. Dipendenza esterna

AUREA usa **oxmysql** come unico strato di accesso al database.

```bash
cd resources
git clone https://github.com/overextended/oxmysql.git
# oppure scarica la release compilata: oxmysql richiede la build, non i sorgenti
```

Scarica la **release già compilata** dalla pagina dei rilasci: il repository
sorgente da solo non funziona.

---

## 4. Copia delle risorse

Copia il contenuto di `resources/` nella cartella `resources/` del tuo
FXServer, mantenendo le cartelle fra parentesi quadre:

```
server-data/
└── resources/
    ├── oxmysql/
    ├── [core]/
    ├── [essenziali]/
    ├── [italia]/
    └── [admin]/
```

Le parentesi quadre non sono decorative: FXServer usa quella convenzione per
caricare ricorsivamente le sottocartelle.

---

## 5. Configurazione

Copia `server.cfg` nella cartella `server-data/` e modifica:

### Stringa di connessione

```cfg
set mysql_connection_string "mysql://aurea:LA_TUA_PASSWORD@localhost/aurea?charset=utf8mb4"
```

### Chiave di licenza

Generala su [keymaster.fivem.net](https://keymaster.fivem.net):

```cfg
sv_licenseKey "cfxk_..."
```

### Il tuo accesso da fondatore

Avvia il server una prima volta, connettiti, e leggi la tua license dalla
console del server (compare fra gli identificatori alla connessione). Poi:

```cfg
add_principal identifier.license:LA_TUA_LICENSE group.admin
```

E dalla console del server, dopo esserti connesso:

```
setgruppo <il_tuo_id> fondatore
```

### Whitelist

```cfg
setr aurea_whitelist 1
```

Con la whitelist attiva servono un record in `account` con `whitelist = 1`.
Per abilitare un giocatore:

```sql
UPDATE account SET whitelist = 1 WHERE license = 'license:...';
```

### Webhook Discord

Ogni canale del registro ha il suo webhook, letto da convar:

```cfg
setr aurea_webhook_denaro    "https://discord.com/api/webhooks/..."
setr aurea_webhook_anticheat "https://discord.com/api/webhooks/..."
```

Lasciare la stringa vuota disattiva il canale. **Non committare mai un
`server.cfg` con webhook reali dentro.**

---

## 6. Primo avvio

```bash
cd server-data
./run.sh +exec server.cfg      # Linux
run.cmd +exec server.cfg       # Windows
```

In console dovresti leggere:

```
[AUREA] nucleo avviato · AUREA · Italia Roleplay
[AUREA] registro avviato · i webhook si configurano con "setr aurea_webhook_<canale>"
```

Se compare un errore di oxmysql, la stringa di connessione è sbagliata o il
database non è raggiungibile.

---

## 7. Verifica del funzionamento

Connettiti e controlla, in quest'ordine:

1. **Selezione personaggio** — compare la schermata con il tricolore.
   Se resti a fissare il cielo, `aurea_spawn` non è partito.
2. **Creazione** — inserisci nome e cognome: l'anteprima del codice fiscale
   si aggiorna mentre scrivi.
3. **HUD** — entrato in gioco, in basso a sinistra compaiono gli anelli di
   stato e in alto a destra il portafoglio.
4. **Inventario** — `TAB` apre l'inventario con il corredo iniziale
   (carta d'identità, tessera sanitaria, smartphone, acqua, panini).
5. **Telefono** — `F1` apre lo smartphone. Nella sezione identità digitale
   trovi il tuo codice fiscale e il codice cittadino.
6. **Economia** — dalla console: `economia` mostra indice dei prezzi, massa
   monetaria e saldo dell'erario.

---

## 8. Configurazione dei contenuti

Le coordinate nei file `config.lua` sono un punto di partenza sensato ma
vanno rifinite sulla tua mappa. I file da rivedere per primi:

| File | Che cosa contiene |
|---|---|
| `ita_codicestrada/config.lua` | Postazioni autovelox, tratte tutor, poligoni ZTL, incroci sorvegliati |
| `ita_veicoli/config.lua` | Catalogo veicoli con potenza in kW e classe ambientale |
| `aurea_garage/config.lua` | Garage con punti di uscita, distributori |
| `aurea_negozi/config.lua` | Punti vendita e cataloghi |
| `ita_madeinitaly/config.lua` | Postazioni delle filiere produttive |
| `ita_famiglie/config.lua` | Territori contendibili |
| `aurea_case/config.lua` | Interni degli immobili |

Per rilevare una coordinata in gioco, con la modalità staff attiva usa il
noclip (`F9`) e leggi la posizione dalla console con `/tp` sul marker.

---

## 9. Bilanciamento

I numeri sono tarati per un server di media affluenza. Le leve principali:

| Parametro | File | Effetto |
|---|---|---|
| `C.Avvio.contanti` / `banca` | `aurea_core/shared/config.lua` | Dotazione iniziale |
| `gradi[n].stipendio` | `aurea_core/shared/lavori.lua` | Stipendi per grado |
| `CDS.Regole.scontoGiorni` | `ita_codicestrada/config.lua` | Finestra dello sconto sui verbali |
| `ECO.Inflazione.massaRiferimento` | `ita_economia/config.lua` | Soglia oltre cui i prezzi salgono |
| `FAM.Calore.sogliaIndagine` | `ita_famiglie/config.lua` | Quando scatta il 416-bis |
| `MIT.Certificazioni[].soglia` | `ita_madeinitaly/config.lua` | Difficoltà delle certificazioni |

Prima di toccare i prezzi, guarda `/economia`: se la massa monetaria cresce
di continuo significa che entra più denaro di quanto ne esca, e la leva
giusta è alzare i costi ricorrenti (bollo, canoni, tributi), non abbassare
gli stipendi.

---

## 10. Manutenzione

Il server si mantiene da solo su quasi tutto:

- I personaggi si salvano ogni 5 minuti e alla disconnessione.
- Gli inventari modificati si salvano ogni minuto.
- I log di debug si cancellano dopo 2 giorni, gli avvisi dopo 60.
- I verbali scaduti diventano cartelle esattoriali ogni 15 minuti.
- I mucchi di oggetti a terra spariscono dopo 30 minuti.

Cosa conviene controllare a mano ogni tanto:

```sql
-- Personaggi mai usati, da ripulire
SELECT COUNT(*) FROM personaggi WHERE ultimo_uso < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- Andamento della massa monetaria
SELECT valore FROM economia_stato WHERE chiave = 'massa_monetaria';

-- Chi ha accumulato più segnalazioni anticheat
SELECT citizenid, COUNT(*) FROM registro_eventi
WHERE canale = 'anticheat' AND momento > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY citizenid ORDER BY 2 DESC LIMIT 10;
```

---

## 11. Problemi frequenti

**La schermata di selezione non compare.**
`aurea_spawn` dipende da `aurea_core`: controlla l'ordine degli `ensure` in
`server.cfg`. Il nucleo deve partire prima.

**Le notifiche non appaiono.**
`aurea_ui` non è partito, oppure una risorsa la sta chiamando prima che sia
pronta. In console cerca `Failed to load resource aurea_ui`.

**I verbali non arrivano.**
Verifica che OneSync sia attivo: senza, il server non può leggere la velocità
del veicolo e il rilevamento viene scartato.

**I prezzi non si muovono.**
Il ciclo economico gira ogni 10 minuti e serve che qualcuno compri o venda.
Con il server vuoto il listino resta fermo, ed è corretto che sia così.

**Accenti sbagliati nei nomi.**
Il database non è in `utf8mb4`. Va ricreato: cambiare charset a tabelle già
popolate non recupera i dati già corrotti.

**`Unknown table 'articoli'` (o `armi`, `matrimoni`, `licenze`, `completi`).**
Manca la migrazione: esegui `sql/03_espansione.sql`.

**Le rapine non partono mai.**
È voluto. Ogni bersaglio richiede un numero minimo di agenti in servizio —
due per un esercizio, sei per un istituto di credito. Con `/colpi` si vede
quanti ne servono e quanti ce ne sono. La soglia si cambia in
`ita_rapine/config.lua`.

**Il sindaco non riesce a deliberare.**
Le leve le manovra solo chi è stato proclamato: serve una tornata completa,
`/elezioni apri` → `/elezioni voto` → `/elezioni spoglio`. Senza spoglio non
c'è sindaco in carica e la sala della giunta resta in sola lettura.

**Nessuno riesce a pubblicare sul giornale.**
Serve il lavoro `giornalista`: si assegna dal Centro per l'Impiego o con
`/setlavoro <id> giornalista <grado>`. Il compenso a pezzo scala con il
grado, e la diretta televisiva la apre solo il Caporedattore (grado 2).
