# AUREA · Italia Roleplay

Server FiveM roleplay ambientato in Italia, costruito su un framework
proprietario. Non è un pacchetto di script assemblati: è un sistema unico in
cui i moduli si parlano fra loro, e in cui le regole italiane — codice della
strada, fisco, giustizia, sanità — sono la meccanica di gioco, non
un'ambientazione dipinta sopra.

---

## Che cosa lo rende diverso

**L'economia è chiusa.** Il denaro che esce dalle tasche dei giocatori non
sparisce: finisce nell'erario, che a sua volta paga stipendi pubblici e
sussidi. Il listino dei beni si muove solo per effetto degli scambi reali —
ogni acquisto alza la domanda, ogni conferimento alza l'offerta — e l'indice
dei prezzi segue la massa monetaria effettivamente in circolazione.

**Le regole hanno conseguenze.** Autovelox e tutor rilevano davvero, la ZTL
legge la targa a fasce orarie, la patente ha venti punti che si perdono e si
recuperano, il bollo scade, l'assicurazione pure, e senza revisione il veicolo
finisce in depositeria. Il verbale non pagato diventa cartella esattoriale.

**La qualità non è binaria.** Nelle filiere Made in Italy ogni lotto ha un
punteggio da 0 a 100 che nasce dalla maestria dell'artigiano, dalle materie
prime, dalla precisione dell'esecuzione e dal rispetto dei tempi di
affinamento. Solo sopra certe soglie si ottiene la certificazione IGP, DOP o
DOCG — e la certificazione moltiplica il valore fino a 2,2 volte.

**Restare sotto traccia conviene.** Le organizzazioni criminali accumulano
*calore investigativo*: ogni illecito lo alza, il tempo lo abbassa. Oltre una
soglia arrivano i controlli, oltre un'altra si apre d'ufficio il fascicolo per
associazione a carico di tutti gli affiliati.

---

## Struttura

```
fivem-italia/
├── server.cfg              configurazione del server
├── sql/                    schema e dati iniziali
├── docs/                   documentazione operativa
└── resources/
    ├── [core]/             framework, interfaccia, HUD, selezione personaggio
    ├── [essenziali]/       inventario, banca, telefono, negozi, lavori, sanità, case
    ├── [italia]/           i moduli che rendono il server italiano
    └── [admin]/            staff, protezioni, registro
```

### `[core]`

| Risorsa | Che cosa fa |
|---|---|
| `aurea_core` | Framework: oggetto Giocatore, denaro in centesimi, lavori con gerarchie italiane, catalogo oggetti, codice penale e Codice della Strada, generatori di codice fiscale, IBAN, partita IVA e targhe |
| `aurea_ui` | Toolkit condiviso: notifiche, menu, dialoghi, barre di avanzamento, prompt |
| `aurea_hud` | Tachimetro con limiti di velocità contestuali, stato vitale, patente a punti, indicatore ZTL |
| `aurea_spawn` | Selezione e creazione personaggio con anagrafe reale |

### `[essenziali]`

| Risorsa | Che cosa fa |
|---|---|
| `aurea_inventory` | Inventario a slot con peso, metadata per istanza, contenitori, oggetti a terra, deperibilità |
| `aurea_banca` | Conti con IBAN, bonifici, mutui con merito creditizio, antiriciclaggio |
| `aurea_telefono` | Rubrica, messaggi, identità digitale in stile SPID, banca, cassetto fiscale, annunci, 112 |
| `aurea_negozi` | Esercizi con scontrino fiscale e mercato a prezzi dinamici |
| `aurea_lavori` | Centro per l'Impiego, missioni di consegna e corse taxi, officina |
| `aurea_medico` | Ferite localizzate, emorragie, incoscienza, 118, ospedale |
| `aurea_case` | Immobili con interni istanziati, locazione, deposito domestico |
| `aurea_garage` | Garage, carburante con consumo per classe, usura, distributori |

### `[italia]`

| Risorsa | Che cosa fa |
|---|---|
| `ita_codicestrada` | Autovelox, tutor, varchi ZTL, semafori sorvegliati, patente a punti, verbali |
| `ita_veicoli` | Immatricolazione, bollo sui kW, RCA e kasko con bonus/malus, revisione, sequestro |
| `ita_fisco` | Partita IVA, imprese, fatturazione, IRPEF, IVA, IMU, TARI, cartelle esattoriali |
| `ita_112` | Numero unico con triage, smistamento agli enti, quadro operativo |
| `ita_giustizia` | Casellario, arresto, detenzione, attività trattamentali, cauzione, patteggiamento |
| `ita_madeinitaly` | Sei filiere produttive con qualità, affinamento e certificazioni |
| `ita_famiglie` | Organizzazioni criminali, territori, pizzo, riciclaggio, calore investigativo |
| `ita_ambiente` | Meteo stagionale, tempo sincronizzato, festività, eventi dinamici |
| `ita_economia` | Motore di domanda e offerta, indice dei prezzi, Borsa Merci |

### `[admin]`

| Risorsa | Che cosa fa |
|---|---|
| `aurea_admin` | Sanzioni, segnalazioni, modalità staff, noclip |
| `aurea_anticheat` | Punteggio di sospetto, protezione eventi ed entità, integrità risorse |
| `aurea_logs` | Recapito su Discord con accodamento e limitazione di frequenza |

---

## Installazione

Vedi **[docs/INSTALLAZIONE.md](docs/INSTALLAZIONE.md)** per la procedura completa.

In breve:

```bash
# 1. Database
mysql -u root -p -e "CREATE DATABASE aurea CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p aurea < sql/01_schema.sql
mysql -u root -p aurea < sql/02_dati_iniziali.sql

# 2. Dipendenza esterna
#    scarica oxmysql in resources/ da github.com/overextended/oxmysql

# 3. Configurazione
#    modifica server.cfg: stringa di connessione, licenza, license del fondatore

# 4. Avvio
./run.sh +exec server.cfg
```

---

## Comandi principali

### Cittadino

| Comando | Effetto |
|---|---|
| `TAB` | Inventario (o bagagliaio, o oggetti a terra) |
| `F1` | Telefono |
| `B` | Allaccia o slaccia la cintura |
| `/id` `/contanti` `/iban` | Documenti e portafoglio |
| `/dai <euro>` | Consegna contanti a chi hai davanti |
| `/patente` `/multe` | Stato della patente e verbali pendenti |
| `/cassetto` | Posizione fiscale |
| `/112` | Chiamata al Numero Unico Emergenze |
| `/denuncia` | Denuncia-querela |
| `/precedenti` | Il tuo casellario |
| `/ferite` | Lesioni in corso |
| `/listino` | Borsa Merci |
| `/maestria` | Le tue discipline artigiane |
| `/org` | Pannello dell'organizzazione |
| `/tempo` | Ora, stagione, meteo, eventi |
| `/report <testo>` | Segnalazione allo staff |

### Servizio (forze dell'ordine, 118, VVF)

| Comando | Effetto |
|---|---|
| `/servizio` | Entra o esci dal turno |
| `F6` | Quadro degli interventi 112 |
| `F7` | Banca dati interforze |
| `/verbale <codice>` | Eleva un verbale |
| `/etilometro` | Test alcolemico |
| `/controllo <targa>` | Verifica documenti del veicolo |
| `/sequestra <targa> <motivo>` | Sequestro |
| `/arresta` | Arresto con capi d'imputazione |
| `/trascina` | Accompagnamento coattivo |
| `/cartella <cf>` | Cartella clinica (personale medico) |
| `/verificafiscale <cf>` | Posizione fiscale (GdF, Agenzia Entrate) |

### Staff

| Comando | Gruppo minimo |
|---|---|
| `/staff` `/segnalazioni` `/prendi` `/chiudi` | supporto |
| `/kick` `/tp` `/portami` `/revive` `/annuncio` `/meteo` `/ora` `/sospetti` | moderatore |
| `/ban` `/sbanna` `/setlavoro` `/registro` `/economia` `/evento` | admin |
| `/dammi` `/dammiitem` | gestore |
| `/setgruppo` | fondatore |

---

## Note tecniche

- **Il denaro è sempre in centesimi interi.** Mai float: `12,50 €` è `1250`.
- **Il client non è una fonte attendibile.** La velocità nei verbali la legge
  il server dall'entità di rete; la posizione negli interventi 112 la prende
  dal ped; i prezzi dei negozi li ricostruisce alla cassa; i tempi di
  lavorazione li verifica prima di consegnare il prodotto.
- **Ogni operazione sensibile passa da una callback registrata**, che riceve
  sempre il `source` come primo parametro. Nessun `citizenid` arrivato dal
  client viene mai considerato valido.
- **I webhook non stanno nel codice**: si leggono dalle convar di `server.cfg`.

---

## Licenza

Codice originale scritto per questo progetto. Le dipendenze esterne
(`oxmysql`) mantengono le rispettive licenze.
