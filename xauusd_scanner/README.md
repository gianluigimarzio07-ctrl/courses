# XAUUSD trade scanner

Backtesta **centinaia di varianti di strategia sull'oro** in un colpo solo e le
riassume in una heatmap: una tessera per variante, verde se guadagna, rossa se
perde, con R totale, P&L, win rate e numero di trade.

Python puro, **zero dipendenze**: gira ovunque ci sia Python 3.8+.

![struttura](https://img.shields.io/badge/dipendenze-nessuna-16c47f) ![test](https://img.shields.io/badge/test-73-16c47f)

---

## Avvio rapido

```bash
# 1. prova subito, senza dati e senza rete (serie sintetica generata da seed)
python -m xauusd_scanner --demo

# 2. sui tuoi dati veri: export OHLC da MT4/MT5, TradingView, Dukascopy...
python -m xauusd_scanner --csv XAUUSD_D1.csv --out oro.html

# 3. scaricando lo storico (se l'ambiente ha accesso a internet)
python -m xauusd_scanner --fetch --interval 1d
```

Il comando stampa la classifica a terminale e scrive `xauusd_scan.html`:
aprilo con un doppio click, e' un file autonomo che funziona anche offline.

```
  #  strategia                          uscita                R tot  trade   win%     PF   OOS R  score
  1  ADX trend 20/100/14                2ATR 2R              +12.9R     32  46.9%   1.75   +6.0R   82.1
  2  ADX trend 20/100/14                1.5ATR 2R            +10.8R     37  43.2%   1.51   +0.9R   70.8
  3  BB fade 20/2                       2.5ATR 1R 15b         +9.8R    115  57.4%   1.31   -1.1R   56.1
```

## Da dove prendere i dati di XAUUSD

| Piattaforma | Come esportare |
|---|---|
| **MetaTrader 5** | Visualizza → Grafici offline / Strumenti → Centro storico → Esporta (`.csv` con tab) |
| **MetaTrader 4** | F2 → seleziona XAUUSD e il timeframe → Esporta |
| **TradingView** | grafico → menu ⋯ → *Export chart data* |
| **Dukascopy** | Historical Data Feed → CSV |
| **cTrader / altri** | qualunque CSV con data, open, high, low, close |

Il parser riconosce da solo separatore (`,` `;` tab), header (anche `<DATE>`
`<OPEN>` di MT5, o italiano `Data;Apertura;...`), decimali con la virgola,
timestamp epoch e data/ora su due colonne. Se una riga e' rotta la salta e va
avanti; i controlli di sanita' (`Series.validate`) segnalano OHLC incoerenti,
timestamp duplicati e storici troppo corti.

## Come si legge la heatmap

Ogni tessera e' una **strategia completa**: famiglia + parametri + regole di
uscita. Per esempio `Donchian 55/200 · 2ATR 3R be1` = rottura del canale a 55
bar, filtrata dalla media a 200, stop a 2×ATR, target a 3R, stop a pareggio
dopo 1R.

* **+7.4R** = ha guadagnato sette volte e mezzo il rischio di un singolo trade.
  Ragionare in R rende confrontabili strategie con size diverse.
* **1R** = quanto perdi se lo stop viene colpito (`--risk`, default $100).
* Il **colore** segue la metrica scelta nella toolbar: R totale, robustness
  score, R fuori campione, aspettativa, profit factor o P&L.
* Il badge **LONG ora / SHORT da 3b** dice cosa sta segnalando quella variante
  *adesso*, sull'ultimo bar dello storico: e' la parte "scanner" dello
  strumento, non solo backtest.
* Clicca una tessera per curva equity, statistiche complete (drawdown, Sharpe,
  MAE/MFE, serie peggiore di perdite) e ultimi trade con motivo di uscita.

## Le famiglie di strategie

| Famiglia | Idea | Regime |
|---|---|---|
| `EMA cross` | incrocio di due EMA | trend |
| `EMA stack` | stato di trend continuo, uscita al flip | trend |
| `Donchian` | rottura del massimo/minimo a N bar | breakout |
| `ATR thrust` | espansione di volatilita' oltre k×ATR | breakout |
| `Squeeze` | Bollinger dentro Keltner, poi rilascio | breakout |
| `Inside bar` | compressione del range e rottura | breakout |
| `MACD` | istogramma che cambia segno | momentum |
| `ADX trend` | direzione confermata da ADX | trend |
| `RSI pullback` | rientro da ipervenduto dentro il trend | pullback |
| `MA pullback` | ritorno sulla media veloce in trend | pullback |
| `BB fade` | chiusura fuori banda, rientro atteso | mean reversion |
| `Range fade` | estremi del canale in bassa volatilita' | mean reversion |

Le uscite testate per ciascuna: stop a 1.5/2/3 ATR, target 1R…4R, trailing tipo
chandelier, stop a pareggio, time stop, uscita al segnale opposto. Totale di
serie: **322 varianti**. Con `--families` ne limiti l'insieme.

## Regole del motore (pessimistiche di proposito)

* Il segnale nasce **alla chiusura** del bar; l'ingresso e' **all'apertura del
  bar successivo**. Mai sullo stesso close.
* Se stop e target cadono nello stesso bar si assume colpito lo **stop**: senza
  dati tick non e' possibile sapere l'ordine, e l'ipotesi ottimistica e' il modo
  piu' comune di gonfiare un backtest.
* I **gap** oltre lo stop vengono eseguiti all'apertura, non al prezzo dello
  stop: la perdita puo' superare 1R, come nella realta'.
* Spread, slippage e commissioni sono applicati a ogni entrata e uscita
  (`--spread`, `--slippage`, `--commission`).
* Una sola posizione per volta; la size deriva dalla distanza dello stop, cosi'
  ogni trade rischia esattamente 1R.
* Anche l'ultimo bar della serie viene controllato per stop e target.

## Robustness score e out-of-sample

Testare 322 varianti significa che **alcune risultano verdi per puro caso**.
Per questo lo scanner non ordina solo per R totale:

* l'ultimo `--oos 0.3` (30%) dello storico e' valutato a parte: se la variante
  regge anche li', il punteggio sale; se collassa, scende;
* il **robustness score** (0-100) pesa aspettativa, significativita' statistica
  (aspettativa × √trade), profit factor, rapporto rendimento/drawdown, Sharpe
  sui trade e soprattutto la tenuta fuori campione;
* le varianti con meno di `--min-trades` (default 20) trade prendono score 0.

Una tessera verde con score basso e OOS negativo e' rumore, non una strategia.

## Uso come libreria

```python
from xauusd_scanner import Costs, load_csv, scan, write_report, build_variants

series = load_csv("XAUUSD_D1.csv")
rows = scan(series,
            variants=build_variants(families=["Donchian", "ADX trend"]),
            costs=Costs(spread=0.30, slippage=0.05, commission_per_lot=7.0),
            risk=100.0, oos_fraction=0.3, workers=4)

for row in rows[:5]:
    print(row.key, row.stats["total_r"], row.score, row.signal_now)

write_report("oro.html", series=series, rows=rows, costs=Costs(),
             risk=100.0, min_trades=20, oos_fraction=0.3)
```

Per una strategia tua basta aggiungere una funzione a `strategies.FAMILIES` che
restituisca `+1/-1/0` per ogni bar: la griglia di uscite, il backtest, lo score
e la heatmap arrivano gratis.

## Opzioni principali

```
--csv PATH           file OHLC          --risk 100        dollari a rischio per trade (1R)
--fetch              scarica lo storico --spread 0.30     spread in $/oncia
--demo               serie sintetica    --slippage 0.05   slippage in $/oncia
--from / --to        periodo            --commission 7    round turn per lotto (100 oz)
--families NOME...   limita le famiglie --min-trades 20   soglia per il ranking
--long-only          niente short       --oos 0.3         frazione out-of-sample
--signals            solo cosa scatta ora                 --workers N  processi paralleli
--json FILE          esporta i risultati grezzi           --out FILE   heatmap HTML
```

## Test

```bash
python -m unittest discover -s xauusd_scanner/tests -t .
```

73 test coprono gli indicatori (valori calcolati a mano, causalita'), il parser
CSV, la meccanica del motore (target, stop, gap, trailing, breakeven, time stop,
costi, contabilita' in R) e lo scanner — incluso un test che ritaglia la serie a
meta' e verifica che **nessuna strategia cambi i segnali passati**, cioe' che
non legga il futuro.

## Avvertenza

Sono risultati di backtest su dati storici. La performance passata non prevede
quella futura: una tessera verde e' un'ipotesi da validare in demo prima di
rischiare denaro vero, non un segnale operativo. Lo spread reale sull'oro si
allarga molto durante le news, e questo il backtest non lo modella.
