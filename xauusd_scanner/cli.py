"""Interfaccia a riga di comando dello scanner.

    python -m xauusd_scanner --demo                      # dati sintetici
    python -m xauusd_scanner --csv XAUUSD_D1.csv         # export della piattaforma
    python -m xauusd_scanner --fetch --interval 1d       # download (serve rete)
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from typing import List, Optional, Sequence

from .backtest import Costs
from .data import Series, fetch_web, load_csv, synthetic
from .report import write_report
from .scanner import ScanRow, default_workers, scan, summarize
from .strategies import FAMILIES, build_variants


def _date(value: str) -> datetime:
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%Y%m%d"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    raise argparse.ArgumentTypeError(f"data non valida: {value} (usa YYYY-MM-DD)")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="xauusd_scanner",
        description="Scansiona centinaia di varianti di strategia su XAUUSD e genera una heatmap.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    src = p.add_argument_group("sorgente dati")
    src.add_argument("--csv", help="file OHLC esportato da MT4/MT5, TradingView, Dukascopy...")
    src.add_argument("--fetch", action="store_true", help="scarica lo storico (Stooq, fallback Yahoo)")
    src.add_argument("--demo", action="store_true", help="serie sintetica deterministica (offline)")
    src.add_argument("--symbol", default="XAUUSD")
    src.add_argument("--interval", default="1d", help="intervallo per --fetch (1d, 1wk, 1h)")
    src.add_argument("--timeframe", default="auto", help="forza il timeframe del CSV (D1, H4, H1...)")
    src.add_argument("--bars", type=int, default=2600, help="numero di bar della serie demo")
    src.add_argument("--seed", type=int, default=7, help="seed della serie demo")
    src.add_argument("--from", dest="date_from", type=_date, help="inizio periodo (YYYY-MM-DD)")
    src.add_argument("--to", dest="date_to", type=_date, help="fine periodo (YYYY-MM-DD)")

    money = p.add_argument_group("rischio e costi")
    money.add_argument("--risk", type=float, default=100.0, help="dollari a rischio per trade (1R)")
    money.add_argument("--spread", type=float, default=0.30, help="spread in dollari/oncia")
    money.add_argument("--slippage", type=float, default=0.05, help="slippage in dollari/oncia")
    money.add_argument("--commission", type=float, default=7.0, help="commissioni round turn per lotto (100 oz)")

    scan_group = p.add_argument_group("scansione")
    scan_group.add_argument("--families", nargs="+", metavar="NOME",
                            help=f"limita le famiglie. Disponibili: {', '.join(FAMILIES)}")
    scan_group.add_argument("--min-trades", type=int, default=20, help="soglia minima di trade per il ranking")
    scan_group.add_argument("--oos", type=float, default=0.3, help="frazione finale di storico usata come out-of-sample")
    scan_group.add_argument("--long-only", action="store_true", help="ignora i segnali short")
    scan_group.add_argument("--workers", type=int, default=default_workers(), help="processi paralleli")

    out = p.add_argument_group("output")
    out.add_argument("--out", default="xauusd_scan.html", help="file HTML della heatmap")
    out.add_argument("--json", dest="json_out", help="esporta i risultati grezzi in JSON")
    out.add_argument("--top", type=int, default=15, help="quante righe stampare a schermo")
    out.add_argument("--signals", action="store_true", help="stampa solo le strategie con segnale sull'ultimo bar")
    out.add_argument("--no-report", action="store_true", help="non generare l'HTML")
    out.add_argument("--list-families", action="store_true", help="elenca le famiglie e termina")
    return p


def load_series(args) -> Series:
    if args.csv:
        series = load_csv(args.csv, symbol=args.symbol, timeframe=args.timeframe)
    elif args.fetch:
        series = fetch_web(args.symbol, args.interval)
    else:
        series = synthetic(bars=args.bars, seed=args.seed,
                           timeframe="D1" if args.timeframe == "auto" else args.timeframe)
    if args.date_from or args.date_to:
        series = series.slice(args.date_from, args.date_to)
    return series


def print_table(rows: Sequence[ScanRow], top: int, min_trades: int) -> None:
    header = f"{'#':>3}  {'strategia':<34} {'uscita':<18} {'R tot':>8} {'trade':>6} {'win%':>6} {'PF':>6} {'OOS R':>7} {'score':>6}"
    print(header)
    print("-" * len(header))
    shown = [r for r in rows if r.stats["trades"] >= min_trades][:top]
    for i, r in enumerate(shown, 1):
        pf = r.stats["profit_factor"]
        print(
            f"{i:>3}  {r.name[:34]:<34} {r.exits[:18]:<18} "
            f"{r.stats['total_r']:>+7.1f}R {int(r.stats['trades']):>6} "
            f"{r.stats['win_rate']:>5.1f}% {pf if pf < 99 else 99:>6.2f} "
            f"{r.oos.get('total_r', 0.0):>+6.1f}R {r.score:>6.1f}"
        )
    if not shown:
        print("nessuna variante con abbastanza trade: abbassa --min-trades o allunga lo storico")


def print_signals(rows: Sequence[ScanRow], min_trades: int) -> None:
    live = [r for r in rows if r.signal_now and r.stats["trades"] >= min_trades]
    live.sort(key=lambda r: r.score, reverse=True)
    if not live:
        print("nessun segnale attivo sull'ultimo bar")
        return
    print(f"{'lato':<6} {'strategia':<40} {'uscita':<18} {'bar fa':>7} {'score':>6} {'R storico':>10}")
    for r in live[:30]:
        print(f"{'LONG' if r.signal_now > 0 else 'SHORT':<6} {r.name[:40]:<40} {r.exits[:18]:<18} "
              f"{r.bars_since_signal:>7} {r.score:>6.1f} {r.stats['total_r']:>+9.1f}R")


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    if args.list_families:
        for name in FAMILIES:
            print(name)
        return 0

    try:
        series = load_series(args)
    except Exception as exc:
        print(f"errore nel caricamento dei dati: {exc}", file=sys.stderr)
        return 2

    problems = series.validate()
    for problem in problems:
        print(f"[attenzione] {problem}", file=sys.stderr)
    if len(series) < 120:
        print("storico troppo corto per una scansione sensata", file=sys.stderr)
        return 2

    costs = Costs(spread=args.spread, slippage=args.slippage, commission_per_lot=args.commission)
    intraday = series.timeframe.startswith(("M", "H"))
    variants = build_variants(intraday=intraday, families=args.families)

    print(f"{series.symbol} {series.timeframe} · {len(series)} bar · "
          f"{series.start:%Y-%m-%d} → {series.end:%Y-%m-%d} · sorgente {series.source}")
    print(f"scansione di {len(variants)} varianti su {args.workers} processi...")

    rows = scan(series, variants, costs=costs, risk=args.risk, oos_fraction=args.oos,
                min_trades=args.min_trades, allow_short=not args.long_only, workers=args.workers)

    info = summarize(rows, args.min_trades)
    print(f"{info['profitable']}/{info['eligible']} varianti in positivo "
          f"({info['profitable_pct']:.0f}%) · {info['robust']} con score >= 55\n")

    if args.signals:
        print_signals(rows, args.min_trades)
    else:
        print_table(rows, args.top, args.min_trades)

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump({"summary": info, "rows": [r.as_dict() for r in rows]}, fh, default=str, indent=1)
        print(f"\nJSON: {args.json_out}")

    if not args.no_report:
        write_report(args.out, series=series, rows=rows, costs=costs, risk=args.risk,
                     min_trades=args.min_trades, oos_fraction=args.oos,
                     title=f"{series.symbol} — trade scanner")
        print(f"heatmap: {args.out}")
    return 0
