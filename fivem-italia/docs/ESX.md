# AUREA ed ESX

AUREA non è ESX: è un framework proprio, con il denaro in centesimi interi,
l'anagrafe italiana, i lavori con i gradi e i permessi, l'inventario a slot
con metadata per istanza.

Ma ESX è lo standard di fatto, e su ESX c'è un ecosistema enorme di script
già fatti. Questo documento spiega come far convivere le due cose.

---

## La domanda da farsi per prima

**Non è «come porto AUREA su ESX».** È: *chi comanda?*

Ci sono due risposte, e sono due strade diverse. Se ne prende **una sola**.

| | `[esx]/es_extended` | `[esx]/aurea_esx` |
|---|---|---|
| Chi è il framework | **AUREA** | **il vero es_extended** |
| Cosa fa la risorsa | espone l'oggetto `ESX` costruito su AUREA | tiene AUREA agganciata a ESX |
| es_extended vero installato | **no** (è sostituito) | **sì** |
| I tuoi script `esx_*` | funzionano | funzionano |
| Le 78 risorse AUREA | funzionano | funzionano |
| Denaro | centesimi interi, niente si perde | euro ESX, sotto il centesimo si arrotonda |
| Selezione personaggio | `aurea_spawn`, con anagrafe italiana | quella di ESX |
| Migrazione da un server ESX esistente | va rifatta | **nessuna** |
| `C.Framework` in aurea_core | `'nativo'` | `'esx'` |

**Se parti da zero → `es_extended`.** È la strada migliore e non ha
compromessi sui soldi.

**Se hai già un server ESX con dentro dei giocatori → `aurea_esx`.** Non
tocchi il database `users`, non tocchi i tuoi script, ci aggiungi AUREA.

> Le due risorse **non possono stare accese insieme**. Fanno il percorso
> opposto: accese entrambe si rincorrerebbero.

---

## Strada A — ESX sopra AUREA (`[esx]/es_extended`)

### Perché la risorsa si chiama proprio `es_extended`

Gli script ESX si agganciano al framework in due modi:

```lua
ESX = exports['es_extended']:getSharedObject()
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
```

Il secondo funziona da qualunque risorsa. Il primo cerca **proprio una
risorsa di nome `es_extended`**. Per far girare gli script esistenti senza
riscriverli, la nostra deve chiamarsi così.

Conseguenza diretta: **non installare anche il vero es_extended.** FiveM ne
caricherebbe una sola e non sai quale.

### Installazione

1. Non installare es_extended.
2. In `server.cfg`, dopo `ensure aurea_inventory` e `ensure aurea_armi`:

   ```
   ensure es_extended
   ```

   Poi, dopo di lui, i tuoi script ESX.
3. Lascia `C.Framework = 'nativo'` in `aurea_core/shared/config.lua`.
4. Nessun SQL da eseguire: i lavori e gli oggetti li legge dal catalogo
   AUREA, che è la fonte unica.

### Cosa vedono i tuoi script ESX

Un `xPlayer` non è una copia dei dati: è una **facciata sull'oggetto
Giocatore AUREA**. Tutte le letture guardano il Giocatore vero, tutte le
scritture passano dai suoi metodi.

Questo è il punto di tutta la risorsa, e la conseguenza pratica è che **non
esiste desincronizzazione possibile**. Uno script ESX che fa
`xPlayer.addMoney(500)` e uno script AUREA che legge `g:Saldo('contanti')`
vedono lo stesso numero nello stesso istante, perché *è* lo stesso numero.
Non ci sono due copie da tenere allineate, non c'è un thread di
sincronizzazione, non c'è una finestra in cui i due valori divergono.

### API coperta

**Oggetto server:** `GetPlayerFromId`, `GetPlayerFromIdentifier`,
`GetPlayerFromName`, `GetPlayers`, `GetExtendedPlayers`, `GetNumPlayers`,
`GetJobs`, `DoesJobExist`, `RegisterServerCallback`, `RegisterCallback`,
`TriggerClientCallback`, `RegisterUsableItem`, `UseItem`, `GetUsableItems`,
`RegisterCommand`, `ShowNotification`, `ShowAdvancedNotification`,
`ShowHelpNotification`, `GetItemLabel`, `Items`, `SavePlayer`,
`SavePlayers`, `CreatePickup`, `GetConfig`, `Math.*`, `Table.*`, `SetTimeout`,
`ClearTimeout`, `DumpTable`, `OneSync.*`.

**xPlayer:** `getIdentifier`, `getName`, `getGroup`, `setGroup`,
`getCoords`, `setCoords`, `kick`, `triggerEvent`, `getMoney`, `addMoney`,
`removeMoney`, `setMoney`, `getAccount`, `getAccounts`, `addAccountMoney`,
`removeAccountMoney`, `setAccountMoney`, `getJob`, `setJob`,
`getInventory`, `getInventoryItem`, `addInventoryItem`,
`removeInventoryItem`, `setInventoryItem`, `canCarryItem`, `canSwapItem`,
`getWeight`, `getMaxWeight`, `setMaxWeight`, `getLoadout`, `hasWeapon`,
`getWeapon`, `addWeapon`, `removeWeapon`, `addWeaponAmmo`,
`removeWeaponAmmo`, `set`, `get`, `setMeta`, `getMeta`, `clearMeta`,
`showNotification`, `showAdvancedNotification`, `showHelpNotification`.
Più le proprietà `identifier`, `name`, `group`, `job`, `accounts`,
`inventory`, `loadout`, `coords`, `variables`, `maxWeight`.

**Oggetto client:** `PlayerData`, `PlayerLoaded`, `GetPlayerData`,
`IsPlayerLoaded`, `TriggerServerCallback`, `AwaitServerCallback`,
`RegisterClientCallback`, `ShowNotification`, `ShowAdvancedNotification`,
`ShowHelpNotification`, `TextUI`, `HideUI`, `ShowInventory`, `Game.*`,
`UI.Menu.*`, `Streaming.*`, `Scaleform.*`, `SetTimeout`, `Math.*`,
`Table.*`.

**Eventi:** `esx:getSharedObject`, `esx:playerLoaded`,
`esx:onPlayerLogout`, `esx:playerDropped`, `esx:setJob`,
`esx:setAccountMoney`, `esx:addInventoryItem`, `esx:removeInventoryItem`,
`esx:setMaxWeight`, `esx:showNotification`, `esx:showAdvancedNotification`,
`esx:showHelpNotification`, `esx:useItem`, `esx:giveInventoryItem`,
`esx:teleport`, `esx:spawnVehicle`.

### Le traduzioni che devi conoscere

| ESX | AUREA | Nota |
|---|---|---|
| euro (numero) | centesimi (intero) | conversione a ogni passaggio, arrotondata al centesimo più vicino, **mai per difetto** |
| `money` | `contanti` | |
| `bank` | `banca` | |
| `black_money` | oggetto `contanti_sporchi` | 1 unità = 100 €. Il nero deve stare in tasca e potersi perdere in una perquisizione: se fosse un conto non potrebbe |
| `user` / `mod` / `admin` / `superadmin` | `utente` / `moderatore` / `admin` / `gestore` | in `ESXC.Gruppi` |
| `job.grade` | `lavoro.grado` | stessi nomi: i lavori ESX **sono** i lavori AUREA |
| — | `lavoro.servizio` | non esiste in ESX; lo trovi come `job.onDuty` |

### Cosa non c'è, e perché

| Chiamata | Cosa succede | Perché |
|---|---|---|
| `xPlayer.setName` | rifiuta e lo dice | il nome è anagrafe: si cambia in Comune, non da script |
| `ESX.Game.SetWeather` / `SetTime` | rifiutano e lo dicono | li governa `ita_ambiente` per tutto il server; due orologi diversi sono peggio di un rifiuto |
| componenti arma | non implementate | in AUREA un'arma è un oggetto con matricola, non ha componenti |
| `ESX.UI.Menu` tipo `slider` | reso come voce con il valore in descrizione | il menu AUREA non ha gli slider di ESX |

Tutto quello che non c'è **lo dice a console** invece di fallire in
silenzio: `ESXC.Compat.avvisaNonImplementato`. Tienilo acceso quando provi
uno script nuovo — ti dice esattamente cosa gli manca.

### Migrazione da un server ESX esistente

Se stai passando da ESX ad AUREA e non vuoi buttare via i personaggi:

```
/migraesx            # prova: dice cosa farebbe, non scrive niente
/migraesx esegui     # scrive davvero
```

Serve il gruppo `gestore`. Prima esegui `sql/esx/01_lavori.sql`, che
aggiunge la colonna `personaggi.esx_identifier` — senza quella la
migrazione si rifiuta di partire.

Legge la tabella `users` di ESX e crea le righe `personaggi`, generando
quello che ESX non ha: codice cittadino, codice fiscale, telefono, IBAN e
conto corrente. Nome, cognome, data di nascita, sesso, lavoro, grado e
saldi arrivano da ESX; il luogo di nascita viene sorteggiato fra le
province configurate. Il `black_money` diventa banconote `contanti_sporchi`,
arrotondate per difetto al taglio da 100 €.

È **idempotente**: un utente già migrato non viene rifatto. Puoi
rilanciarla dopo aver sistemato due righe a mano senza duplicare niente.

**L'inventario ESX non si migra**, ed è una scelta. In ESX un oggetto è un
nome e un numero; in AUREA ha slot, peso e metadata per istanza. Convertire
alla cieca riempirebbe gli zaini di roba senza identità — armi senza
matricola, documenti senza intestatario, droga senza purezza. Meglio
consegnare il corredo iniziale e lasciare che il resto se lo rifacciano.

Fai un backup del database prima. La prova serve proprio a guardare i
numeri prima di scrivere.

---

## Strada B — AUREA sopra ESX (`[esx]/aurea_esx`)

### Installazione

1. Tieni il tuo `es_extended` vero.
2. **Cancella** `resources/[esx]/es_extended` (la nostra): sono la stessa
   risorsa e vanno in conflitto.
3. In `aurea_core/shared/config.lua`:

   ```lua
   C.Framework = 'esx'
   ```

4. Togli da `server.cfg`:

   ```
   ensure aurea_spawn        # la selezione personaggio la fa ESX
   ```

5. Esegui il SQL:

   ```bash
   mysql -u utente -p nome_database < sql/esx/01_lavori.sql
   mysql -u utente -p nome_database < sql/esx/02_oggetti.sql
   ```

   Il primo carica i 26 lavori AUREA e gli 80 gradi nelle tabelle `jobs` e
   `job_grades` di ESX, e aggiunge a `personaggi` la colonna
   `esx_identifier`. Il secondo carica i 155 oggetti nella tabella `items`.

6. Ordine in `server.cfg`: prima `es_extended`, poi `aurea_core`, poi il
   resto di AUREA, e `aurea_esx` subito dopo `aurea_inventory`.

### Come funziona il denaro

È la parte che merita di essere capita.

`Giocatore:Aggiungi` e `Giocatore:Sottrai` vengono **sostituiti
sull'istanza**: in Lua, scrivere `g.Aggiungi = ...` copre il metodo del
metatable per quell'oggetto e per nessun altro. Il Giocatore creato in
questa modalità ha metodi del denaro che parlano con `xPlayer`, mentre
tutto il resto del framework resta identico.

Le 78 risorse AUREA continuano a chiamare `g:Aggiungi` come hanno sempre
fatto. **Nessuna di loro sa che sotto c'è ESX, e nessuna va modificata.**

Resta un limite onesto da conoscere: ESX non emette un evento su ogni
movimento di denaro, quindi uno script `esx_*` può cambiare il saldo senza
che noi lo sappiamo. Per questo c'è un riallineamento periodico
(`AEC.Sincronia.secondiDenaro`, di default 10 secondi). Non è elegante, ma
è l'unico modo corretto, e sta scritto nel codice invece di essere
nascosto.

### Il primo accesso

Quando un utente ESX entra per la prima volta non ha un personaggio AUREA.
Ne viene creato uno al volo: nome e cognome si ricavano da ESX, il resto —
codice fiscale, telefono, IBAN, codice cittadino — lo genera l'anagrafe
AUREA. Riceve il corredo iniziale (carta d'identità, tessera sanitaria,
telefono) perché senza documenti mezzo server non funziona.

Il saldo del conto corrente AUREA parte da quello che ha già in banca su
ESX: non è un regalo, è la stessa cifra vista dall'altra parte.

Il `black_money` ESX viene convertito **una volta sola** in banconote
`contanti_sporchi` e azzerato su ESX, così il nero smette di esistere in
due posti.

### Diagnostica

```
/aureaesx
```

Dice se il ponte è agganciato, quanti giocatori AUREA sono in gioco e chi
ha l'autorità su denaro e lavoro.

---

## Problemi frequenti

**`attempt to index a nil value (field 'es_extended')` da uno script ESX.**
`es_extended` non è partito prima di quello script. Deve comparire *prima*
negli `ensure`, e nel manifest dello script dovrebbe esserci fra le
`dependencies`.

**Il giocatore resta appeso in connessione.**
Stai usando la strada B ma hai lasciato `C.Framework = 'nativo'`. Due
flussi di deferral in parallelo (quello di ESX e quello di aurea_core) si
bloccano a vicenda.

**Nasce un personaggio nuovo a ogni accesso (strada B).**
Manca la colonna `esx_identifier`: esegui `sql/esx/01_lavori.sql`.

**`setJob("police")` non fa niente.**
Il lavoro deve esistere nel catalogo AUREA. I nomi qui sono italiani:
`polizia`, `carabinieri`, `118`, `meccanico`, `tassista`. Se ti serve
proprio `police`, aggiungilo in `aurea_core/shared/lavori.lua` — è la fonte
unica, e da lì lo prendono entrambe le strade.

**I soldi ballano di qualche centesimo (strada B).**
È il limite dichiarato: ESX lavora in euro come numero. Se ti dà fastidio,
la strada A non ha questo problema.

**`ESX.UI.Menu.Open` apre un menu che si richiude da solo.**
In ESX il menu resta aperto finché non lo chiudi tu; qui il menu AUREA si
chiude a ogni scelta e viene riaperto dal ponte. Se il tuo `submit` non
chiama `menu.close()`, il menu si riapre — che è il comportamento ESX
corretto. Se invece sparisce, il tuo `submit` sta chiamando `close`.

---

## Una cosa che vale la pena dire

Questo ponte esiste perché riscrivere 78 risorse in idioma ESX avrebbe
voluto dire più di trecento file che divergono dal giorno dopo, e due
codebase da mantenere per sempre.

Un solo adattatore fa la stessa cosa in circa duemila righe, e ha una
proprietà che le trecento non avrebbero: **non può desincronizzarsi**,
perché non duplica niente.
