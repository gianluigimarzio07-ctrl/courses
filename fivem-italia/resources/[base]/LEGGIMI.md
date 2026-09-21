# `[base]` — le risorse che non sono di AUREA

Qui dentro non c'è niente di scritto da noi. Sono le risorse di base su
cui AUREA si appoggia, incluse così com'erano alla data indicata, senza
modifiche. Stanno qui per una ragione sola: perché il server parta
appena scompattato, senza mandare nessuno a caccia di pezzi.

Se una di queste ti serve più aggiornata, cancella la cartella e mettici
la versione nuova: AUREA non ne tocca il contenuto e non ne dipende in
modo particolare, a parte gli export documentati sotto.

| Risorsa | Da dove viene | Licenza | Serve a |
|---|---|---|---|
| `mapmanager` | [citizenfx/cfx-server-data](https://github.com/citizenfx/cfx-server-data) | Cfx.re asset pack | Avvia la mappa e i tipi di gioco. Senza, il client resta a terra. |
| `spawnmanager` | [citizenfx/cfx-server-data](https://github.com/citizenfx/cfx-server-data) | Cfx.re asset pack | Emette `playerSpawned`, che `aurea_spawn` usa per sapere quando il giocatore è davvero in partita. |
| `baseevents` | [citizenfx/cfx-server-data](https://github.com/citizenfx/cfx-server-data) | Cfx.re asset pack | Eventi di morte e di uscita dal veicolo, su cui si appoggia `aurea_medico`. |
| `oxmysql` | [overextended/oxmysql](https://github.com/overextended/oxmysql) | LGPL-3.0 | L'accesso al database. È l'unica dipendenza vera del framework: senza, non parte niente. |

Le licenze originali sono dentro le rispettive cartelle e vanno lasciate
dove sono.

## Che cosa NON c'è qui, e perché

**`chat`, `sessionmanager`, `hardcap`, `yarn`, `webpack`, `monitor`.**
Non mancano: arrivano insieme all'eseguibile di FXServer, dentro
`citizen/system_resources/`. `server.cfg` le avvia e si trovano da sole.

**L'eseguibile di FXServer.** È il programma che fa girare tutto e pesa
qualche centinaio di megabyte. Lo scarica `installa.sh` (o
`installa.bat` su Windows) direttamente da Cfx.re, perché esce una
versione nuova ogni settimana e una copia congelata qui invecchierebbe
in pochi giorni.

**GTA V.** Il server non ne ha bisogno e non può contenerlo: il gioco ce
l'ha ogni giocatore sul proprio computer, con la propria copia
regolarmente acquistata, e il client FiveM lo usa da lì. Un server FiveM
non contiene e non distribuisce il gioco — nemmeno un pezzo.

## Tre assenze volute

**`basic-gamemode`.** Nel pacchetto Cfx.re c'è, e qui non l'abbiamo messa
apposta. Fa due righe soltanto: accende l'autospawn e fa rinascere il
giocatore appena la mappa parte. In un server freeroam è quello che
serve. In AUREA no: la nascita passa dalla selezione del personaggio di
`aurea_spawn`, e l'autospawn la scavalcherebbe — ti ritroveresti in
strada mentre stai ancora scegliendo chi essere.

In AUREA il tipo di gioco è AUREA.

**`pma-voice`.** È la scelta abituale nei server italiani e non c'è
niente che non vada, ma qui litigherebbe con `aurea_voce`. La portata
della voce la regoliamo con la native `NetworkSetTalkerProximity`, e il
README di pma-voice chiede espressamente di non toccare quella native da
altri script perché gli rompe il conteggio delle distanze. Accese insieme
si contendono la stessa manopola: una la gira, l'altra la rigira.

Se pma-voice ti serve davvero — ha la radio a canali e il submix, che noi
non abbiamo — installala qui dentro e togli `ensure aurea_voce` da
`server.cfg`. Una delle due, mai tutte e due.

**`screenshot-basic`.** Non la usa nessuno. Il "fermo immagine" della
videosorveglianza in `aurea_telecamere` non è un'immagine: è il server
che legge chi era inquadrato in quel momento e lo mette agli atti in
`telecamere_fermi`. Un elenco di persone, non un file PNG — e per come
funziona il roleplay investigativo è anche più utile, perché è una prova
che si cita, si contesta e si allega a un fascicolo.

Va aggiunta anche un'altra ragione: screenshot-basic si distribuisce
come sorgente e si compila all'avvio con `yarn` e `webpack`. Metterla nel
pacchetto vorrebbe dire che il primo avvio del server scarica mezzo npm
per una risorsa che nessuno chiama.
