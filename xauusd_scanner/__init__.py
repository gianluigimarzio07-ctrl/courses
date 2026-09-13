"""XAUUSD trade scanner: backtest a griglia di strategie sull'oro con heatmap.

Uso rapido::

    from xauusd_scanner import load_csv, scan, write_report

    series = load_csv("XAUUSD_D1.csv")
    rows = scan(series, workers=4)
    write_report("report.html", series=series, rows=rows,
                 costs=Costs(), risk=100.0, min_trades=20, oos_fraction=0.3)
"""

from .backtest import Costs, ExitRules, Result, Trade, run_backtest
from .data import Series, fetch_stooq, fetch_web, fetch_yahoo, load_csv, parse_ohlc, synthetic
from .report import build_html, write_report
from .scanner import ScanRow, scan, summarize
from .strategies import FAMILIES, Cache, Variant, build_variants

__version__ = "1.0.0"

__all__ = [
    "Costs", "ExitRules", "Result", "Trade", "run_backtest",
    "Series", "fetch_stooq", "fetch_web", "fetch_yahoo", "load_csv", "parse_ohlc", "synthetic",
    "build_html", "write_report",
    "ScanRow", "scan", "summarize",
    "FAMILIES", "Cache", "Variant", "build_variants",
    "__version__",
]
