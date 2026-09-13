"""Esecuzione della scansione: ogni variante viene backtestata e riassunta in
una riga pronta per la heatmap.

Due cose distinguono questo scanner da un semplice loop di backtest:

1. **Split in-sample / out-of-sample.** Ogni variante viene valutata anche
   sull'ultima porzione di storico che non ha contribuito a scegliere i
   parametri. Una tessera verde in-sample e rossa out-of-sample e' rumore, e
   la heatmap lo mostra invece di nasconderlo.
2. **Stato corrente.** Per ogni variante si registra il segnale sull'ultimo
   bar disponibile: lo scanner dice non solo cosa ha funzionato, ma cosa sta
   scattando adesso.
"""

from __future__ import annotations

import math
import os
from concurrent.futures import ProcessPoolExecutor
from dataclasses import asdict, dataclass, field
from typing import Dict, List, Optional, Sequence

from .backtest import Costs, ExitRules, Result, run_backtest
from .data import Series
from .strategies import Cache, Variant, build_variants


@dataclass
class ScanRow:
    key: str
    name: str
    family: str
    params: str
    exits: str
    stats: Dict[str, float]
    oos: Dict[str, float] = field(default_factory=dict)
    signal_now: int = 0
    bars_since_signal: Optional[int] = None
    equity_curve: List[float] = field(default_factory=list)
    r_series: List[float] = field(default_factory=list)
    last_trades: List[dict] = field(default_factory=list)
    score: float = 0.0

    def as_dict(self) -> dict:
        return asdict(self)


def _downsample(values: Sequence[float], points: int = 60) -> List[float]:
    if len(values) <= points:
        return [round(v, 2) for v in values]
    step = len(values) / points
    return [round(values[min(int(i * step), len(values) - 1)], 2) for i in range(points)]


def robustness_score(stats: Dict[str, float], oos: Dict[str, float], min_trades: int) -> float:
    """Punteggio composito 0-100 per ordinare le tessere.

    Non e' il solo R totale: una strategia con 8 trade e +12R e' quasi sempre
    fortuna. Il punteggio pesa aspettativa, numero di trade, drawdown e —
    soprattutto — la tenuta fuori campione.
    """
    trades = stats.get("trades", 0)
    if trades < min_trades:
        return 0.0
    expectancy = stats.get("expectancy_r", 0.0)
    if expectancy <= 0:
        return 0.0

    # t-statistic dell'aspettativa: quanto e' distinguibile dallo zero
    sharpe = stats.get("sharpe", 0.0)
    significance = min(1.0, max(0.0, expectancy * math.sqrt(trades) / 0.6))
    pf = stats.get("profit_factor", 0.0)
    pf_score = min(1.0, max(0.0, (min(pf, 3.0) - 1.0) / 1.0))
    dd = stats.get("max_dd_r", 0.0)
    dd_score = min(1.0, (stats.get("total_r", 0.0) / dd) / 3.0) if dd > 0 else 0.0
    sharpe_score = min(1.0, max(0.0, sharpe / 1.5))

    oos_trades = oos.get("trades", 0)
    if oos_trades >= max(5, min_trades // 4):
        oos_exp = oos.get("expectancy_r", 0.0)
        oos_score = min(1.0, max(0.0, 0.5 + oos_exp / 0.6))  # 0 se OOS <= -0.3R
    else:
        oos_score = 0.35  # poca evidenza fuori campione: ne' premio ne' castigo

    raw = (
        0.28 * significance
        + 0.18 * pf_score
        + 0.16 * dd_score
        + 0.13 * sharpe_score
        + 0.25 * oos_score
    )
    return round(100.0 * raw, 1)


def _trade_dict(trade) -> dict:
    return {
        "side": "LONG" if trade.side > 0 else "SHORT",
        "entry_time": trade.entry_time.strftime("%Y-%m-%d %H:%M"),
        "exit_time": trade.exit_time.strftime("%Y-%m-%d %H:%M") if trade.exit_time else "",
        "entry": round(trade.entry_price, 2),
        "exit": round(trade.exit_price, 2) if trade.exit_price else None,
        "r": round(trade.r_multiple, 2),
        "pnl": round(trade.pnl, 2),
        "reason": trade.reason,
        "bars": trade.bars_held,
        "mae_r": round(trade.mae_r, 2),
        "mfe_r": round(trade.mfe_r, 2),
    }


def evaluate(
    series: Series,
    variant: Variant,
    cache: Cache,
    costs: Costs,
    risk: float,
    oos_fraction: float,
    min_trades: int,
    allow_short: bool = True,
) -> ScanRow:
    signals = variant.signals(series, cache)
    atr_values = cache.atr(variant.atr_period)
    full = run_backtest(series, signals, atr_values, variant.exits, costs, risk, allow_short=allow_short)

    oos_stats: Dict[str, float] = {}
    if 0.0 < oos_fraction < 1.0:
        split = int(len(series) * (1.0 - oos_fraction))
        oos_trades = [t for t in full.trades if t.entry_index >= split]
        if oos_trades:
            equity = []
            running = 0.0
            for t in oos_trades:
                running += t.pnl
                equity.append(running)
            years_all = full.stats.get("years", 1.0)
            oos_stats = {
                k: v
                for k, v in _summary(oos_trades, equity, risk, len(series) - split, years_all * oos_fraction).items()
            }
        else:
            oos_stats = {"trades": 0.0, "total_r": 0.0, "expectancy_r": 0.0, "win_rate": 0.0, "profit_factor": 0.0}

    # stato corrente: cosa dice la strategia SULL'ULTIMO BAR disponibile.
    # bars_since_signal = da quanti bar dura senza interruzioni quel segnale
    # (0 = appena scattato). Per le strategie di stato, come EMA stack, il
    # segnale resta acceso: il numero dice se e' fresco o vecchio.
    signal_now = signals[-1] if signals else 0
    bars_since = None
    if signal_now:
        j = len(signals) - 1
        while j > 0 and signals[j - 1] == signal_now:
            j -= 1
        bars_since = len(signals) - 1 - j

    row = ScanRow(
        key=variant.key,
        name=variant.name,
        family=variant.family,
        params=variant.param_label,
        exits=variant.exits.label(),
        stats={k: round(v, 4) for k, v in full.stats.items()},
        oos={k: round(v, 4) for k, v in oos_stats.items()},
        signal_now=signal_now,
        bars_since_signal=bars_since,
        equity_curve=_downsample(full.equity),
        r_series=[round(t.r_multiple, 2) for t in full.trades[-120:]],
        last_trades=[_trade_dict(t) for t in full.trades[-12:]],
    )
    row.score = robustness_score(row.stats, row.oos, min_trades)
    return row


def _summary(trades, equity, risk, bars, years):
    from .backtest import compute_stats

    return compute_stats(trades, equity, risk, bars, max(years, 1e-9))


def _run_chunk(args):
    series, variants, costs, risk, oos_fraction, min_trades, allow_short = args
    cache = Cache(series)
    return [evaluate(series, v, cache, costs, risk, oos_fraction, min_trades, allow_short) for v in variants]


def scan(
    series: Series,
    variants: Optional[Sequence[Variant]] = None,
    costs: Optional[Costs] = None,
    risk: float = 100.0,
    oos_fraction: float = 0.3,
    min_trades: int = 20,
    allow_short: bool = True,
    workers: int = 1,
) -> List[ScanRow]:
    variants = list(variants if variants is not None else build_variants(intraday=series.timeframe.startswith(("M", "H"))))
    costs = costs or Costs()

    if workers and workers > 1 and len(variants) > workers * 2:
        # le varianti sono raggruppate per famiglia cosi' ogni processo
        # riutilizza la propria cache di indicatori
        variants = sorted(variants, key=lambda v: (v.family, v.param_label))
        size = math.ceil(len(variants) / workers)
        chunks = [variants[i : i + size] for i in range(0, len(variants), size)]
        payload = [(series, chunk, costs, risk, oos_fraction, min_trades, allow_short) for chunk in chunks]
        rows: List[ScanRow] = []
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for part in pool.map(_run_chunk, payload):
                rows.extend(part)
    else:
        cache = Cache(series)
        rows = [evaluate(series, v, cache, costs, risk, oos_fraction, min_trades, allow_short) for v in variants]

    rows.sort(key=lambda r: r.stats.get("total_r", 0.0), reverse=True)
    return rows


def default_workers() -> int:
    return max(1, min(8, (os.cpu_count() or 2)))


def summarize(rows: Sequence[ScanRow], min_trades: int = 20) -> dict:
    """Numeri di riepilogo mostrati in testa alla heatmap."""
    eligible = [r for r in rows if r.stats.get("trades", 0) >= min_trades]
    profitable = [r for r in eligible if r.stats.get("total_r", 0) > 0]
    robust = [r for r in eligible if r.score >= 55]
    best = max(rows, key=lambda r: r.score, default=None)
    by_family: Dict[str, dict] = {}
    for row in eligible:
        bucket = by_family.setdefault(row.family, {"n": 0, "wins": 0, "total_r": 0.0, "best": -999.0})
        bucket["n"] += 1
        bucket["wins"] += 1 if row.stats["total_r"] > 0 else 0
        bucket["total_r"] += row.stats["total_r"]
        bucket["best"] = max(bucket["best"], row.stats["total_r"])
    for bucket in by_family.values():
        bucket["avg_r"] = round(bucket["total_r"] / bucket["n"], 2) if bucket["n"] else 0.0
        bucket["hit"] = round(100.0 * bucket["wins"] / bucket["n"], 1) if bucket["n"] else 0.0
    return {
        "variants": len(rows),
        "eligible": len(eligible),
        "profitable": len(profitable),
        "profitable_pct": round(100.0 * len(profitable) / len(eligible), 1) if eligible else 0.0,
        "robust": len(robust),
        "best_key": best.key if best else "",
        "best_score": best.score if best else 0.0,
        "by_family": by_family,
    }
