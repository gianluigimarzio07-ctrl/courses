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

**Il crimine ha bisogno di qualcuno che risponda.** Nessuna rapina parte se
non ci sono abbastanza agenti in servizio: il bersaglio scala con il valore
del colpo — due agenti per un esercizio, sei più tre complici per un
istituto di credito. Una rapina senza inseguimento non è roleplay, è un
bancomat.

**Il potere si vota.** Il sindaco lo eleggono i giocatori, e mentre governa
decide sul serio: la quota di addizionale comunale che resta al Comune
invece di andare allo Stato, la TARI iscritta a ruolo su ogni immobile, le
fasce orarie della ZTL, l'importo del sussidio di disoccupazione.

**La droga è un problema di aritmetica.** Ogni dose porta con sé una
purezza da 0 a 100, e da quel numero dipende tutto: il prezzo, il reato
contestato, l'effetto su chi la usa. Tagliare moltiplica la merce e abbassa
la purezza — il principio attivo si conserva, dieci dosi al 90% più dieci
parti di mannitolo fanno venti dosi al 45% — ma sotto una soglia i clienti
rifiutano e la piazza si brucia. Non tagliare lascia una purezza che il
consumatore non regge, e un morto per overdose non è più spaccio: è
l'art. 586 c.p. Il narcotest delle forze dell'ordine legge quel numero e
decide se il fatto è di lieve entità o no.

**Le piazze si tengono in due.** Su una piazza di spaccio si può lavorare
da soli, ma male. Con una vedetta appostata al suo posto i prezzi salgono
del 25%, il rischio di finire davanti a un agente sotto copertura si
dimezza, e chi fa il palo vede arrivare le volanti prima degli altri — e
prende il 20% di quello che si vende.

**Rubare un'auto è una catena, non un tasto.** Serratura, allarme,
ponticello, blocco motore: quattro passaggi, ognuno con il suo rumore. E
quello che rubi è di qualcuno: se ha montato l'antifurto satellitare, il
proprietario vede dove sei, e dopo quattro minuti lo vede anche la centrale.
L'autodemolizione lavora su commessa — ogni ora chiede un tipo di mezzo e
lo paga il doppio — ed è quella richiesta a decidere cosa vale la pena
rubare stasera.

**C'è un'isola, e sopra c'è un latitante.** Il colpo a Punta Corvo è la
cosa più lunga che si può fare: ci vai in incognito a fotografare, e ogni
foto apre un'opzione; scegli come entrare fra mare, cielo e container;
isoli la torre radio, stacchi il quadro, apri il caveau. Un contatore di
sospetto sale da solo mentre sei lì e schizza a ogni cosa che rompi: a
cento la villa si chiude e il colpo salta. Il bottino principale è il libro
mastro della cosca, e lì c'è la scelta vera — venderlo al ricettatore, o
consegnarlo a un pubblico ufficiale e far arrivare quei nomi in Procura.

**La cronaca esiste.** La testata pubblica, tutti leggono in edicola o dal
telefono, e chi viene raccontato male ha gli strumenti che gli dà la legge
italiana: la rettifica ex art. 8 legge 47/1948 — che se la redazione non
pubblica nei termini le costa — e la querela per diffamazione a mezzo stampa
ex art. 595 c.p., che apre un fascicolo a carico di chi ha firmato il pezzo.

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
| `aurea_aspetto` | Editor del personaggio, barbiere, tatuatore, chirurgia estetica, armadio dei completi, divise di servizio |
| `aurea_chat` | Chat di prossimità con portate reali, `/me`, `/fai`, `/tentativo`, dadi, radio a frequenze riservate |
| `aurea_emote` | Circa sessanta emote con oggetti in mano, emote a due, dieci andature |
| `aurea_scoreboard` | Presenze e servizi attivi, senza rivelare chi è in partita |

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
| `aurea_armi` | Registro nazionale delle armi con matricola, porto d'armi per titolo, denuncia di detenzione, controlli e sequestri |
| `aurea_tuning` | Elaborazioni estetiche libere e meccaniche soggette a omologazione, officina clandestina, art. 78 CdS |

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
| `ita_comune` | Anagrafe, residenza, matrimoni civili con regime patrimoniale, divorzio, elezioni comunali, leve del sindaco |
| `ita_media` | Testata giornalistica: cronaca, archivio, rettifiche, querele, dirette televisive, inserzioni |
| `ita_attivita` | Pesca con taglie minime, caccia a stagione aperta e carniere, cava, raccolta di funghi e tartufi, licenze |
| `ita_illegale` | Mercato nero itinerante: attrezzatura, precursori e armi senza matricola, solo in contanti non tracciati |
| `ita_rapine` | Colpi a scaglioni, dal negozio all'istituto di credito, praticabili solo con abbastanza agenti in servizio |
| `ita_droga` | Purezza, coltivazione curata, laboratori, taglio a massa costante, piazze con vedetta, overdose, narcotest |
| `ita_furti` | Effrazione per fascia, allarme, avviamento a ponte, blocco motore, antifurto satellitare, targhe, autodemolizione su commessa |
| `ita_cayo` | Punta Corvo: ricognizione fotografica, tre vie d'accesso, infiltrazione a fasi, contatore di sospetto, rientro sorvegliato |

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
| `F3` `/e <nome>` | Menu emote ed emote diretta |
| `F10` | Presenze e servizi attivi |
| `/me` `/fai` `/tentativo` `/dado` | Azioni interpretate e tiri |
| `/grida` `/sussurra` `/ooc` | Portate di voce e canale fuori personaggio |
| `/radio <frequenza>` `/r <testo>` | Radio ricetrasmittente |
| `/giornale` | L'edizione del giorno, l'archivio, le inserzioni |
| `/colpi` | Stato dei bersagli e agenti in servizio |
| `/miearmi` `/portoarmi` | Le tue armi registrate e il titolo di porto |
| `/licenze` | Pesca, caccia, raccolta |
| `/pianta` `/taglia` | Coltivazione e taglio delle sostanze |
| `/antifurto` `/cambiotarga` `/staccaantifurto` | Antifurto satellitare e targhe |
| `/commessa` | Cosa cerca l'autodemolizione in questo momento |
| `/puntacorvo` `/ricognizione` `/colpo` | Il colpo all'isola |
| `/consegnamastro` | Consegna il libro mastro a un pubblico ufficiale |

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
| `/controlloarmi` | Armi registrate e titolo di porto del soggetto |
| `/controllomodifiche` `/verbalemodifiche` | Elaborazioni non omologate, art. 78 CdS |
| `/controllolicenze` | Licenze di pesca, caccia e raccolta |
| `/narcotest` | Analisi speditiva delle sostanze e scelta del capo d'imputazione |
| `/controllotelaio` | Verifica se un veicolo è provento di furto |
| `/istanze` | Istanze in esame agli uffici comunali (personale del Comune) |
| `/redazione` | Redazione, rettifiche, dirette (giornalisti) |

### Staff

| Comando | Gruppo minimo |
|---|---|
| `/staff` `/segnalazioni` `/prendi` `/chiudi` | supporto |
| `/kick` `/tp` `/portami` `/revive` `/annuncio` `/meteo` `/ora` `/sospetti` | moderatore |
| `/ban` `/sbanna` `/setlavoro` `/registro` `/economia` `/evento` | admin |
| `/dammi` `/dammiitem` | gestore |
| `/setgruppo` | fondatore |
| `/elezioni <apri\|voto\|spoglio\|chiudi>` | admin |

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
- **Le globali non attraversano le risorse.** In FiveM ogni risorsa ha il
  suo stato Lua. Il framework arriva ovunque con un ponte: `aurea_core`
  espone la propria tabella e ogni altra risorsa la aggancia caricando
  `'@aurea_core/bridge/aurea.lua'` come primo `shared_script`. Fra risorse
  Lua il valore passa per riferimento, quindi arrivano anche i metodi
  dell'oggetto Giocatore. Una risorsa nuova che usa `AUREA` deve caricare
  quel file e dichiarare `aurea_core` fra le `dependencies`.
- **L'ordine di avvio in `server.cfg` è un ordinamento topologico** delle
  `dependencies` dichiarate nei manifest. Se aggiungi un modulo che usa gli
  export di un altro, dichiaralo e inseriscilo dopo di quello.

---

## Licenza

Codice originale scritto per questo progetto. Le dipendenze esterne
(`oxmysql`) mantengono le rispettive licenze.
