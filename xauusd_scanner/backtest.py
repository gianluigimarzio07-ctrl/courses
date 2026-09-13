"""Motore di backtest bar-by-bar con contabilita' in R.

Regole del motore (scelte per essere pessimistiche, non ottimistiche):

* il segnale nasce alla chiusura del bar ``i`` usando solo dati fino a ``i``;
* l'ingresso avviene all'apertura del bar ``i+1``, mai sullo stesso close;
* stop e target sono controllati dal bar di ingresso in poi;
* se in uno stesso bar vengono toccati sia stop sia target, si assume che sia
  stato colpito prima lo STOP (worst case: senza dati tick non si puo' sapere);
* gap oltre lo stop vengono eseguiti all'apertura, non al prezzo dello stop;
* spread e slippage sono applicati su entrata e uscita.

Il rischio per trade e' fisso in denaro (1R), quindi ogni trade e' confrontabile
con gli altri e la somma degli R e' la metrica principale dello scanner.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Sequence

from .data import Series

LONG = 1
SHORT = -1


@dataclass
class Costs:
    """Costi di transazione in dollari per oncia (XAUUSD quota ~0.20-0.40 di
    spread su conti retail; 0.30 e' una stima prudente sul daily)."""

    spread: float = 0.30
    slippage: float = 0.05
    commission_per_lot: float = 7.0  # round turn su 100 oz
    ounces_per_lot: float = 100.0


@dataclass
class ExitRules:
    stop_atr: float = 2.0            # distanza stop = k * ATR
    target_r: Optional[float] = 2.0  # take profit in multipli di R (None = nessuno)
    trail_atr: Optional[float] = None  # trailing stop tipo chandelier
    breakeven_at_r: Optional[float] = None  # sposta lo stop a pareggio dopo x R
    time_stop: Optional[int] = None  # chiusura forzata dopo N bar
    exit_on_flip: bool = False       # esce se il segnale opposto si attiva

    def label(self) -> str:
        parts = [f"{self.stop_atr:g}ATR"]
        parts.append(f"{self.target_r:g}R" if self.target_r else ("trail" if self.trail_atr else "flip"))
        if self.trail_atr and self.target_r:
            parts.append(f"tr{self.trail_atr:g}")
        if self.breakeven_at_r:
            parts.append(f"be{self.breakeven_at_r:g}")
        if self.time_stop:
            parts.append(f"{self.time_stop}b")
        return " ".join(parts)


@dataclass
class Trade:
    side: int
    entry_index: int
    entry_time: datetime
    entry_price: float
    stop_price: float
    size: float
    exit_index: Optional[int] = None
    exit_time: Optional[datetime] = None
    exit_price: Optional[float] = None
    reason: str = ""
    pnl: float = 0.0
    r_multiple: float = 0.0
    mae_r: float = 0.0   # massima escursione avversa, in R
    mfe_r: float = 0.0   # massima escursione favorevole, in R

    @property
    def bars_held(self) -> int:
        return (self.exit_index or self.entry_index) - self.entry_index


@dataclass
class Result:
    trades: List[Trade] = field(default_factory=list)
    equity: List[float] = field(default_factory=list)      # equity in $ dopo ogni trade
    equity_time: List[datetime] = field(default_factory=list)
    risk_per_trade: float = 100.0
    stats: Dict[str, float] = field(default_factory=dict)


def _pf(gross_win: float, gross_loss: float) -> float:
    if gross_loss <= 0:
        return float("inf") if gross_win > 0 else 0.0
    return gross_win / gross_loss


def compute_stats(trades: Sequence[Trade], equity: Sequence[float], risk: float, bars: int, years: float) -> Dict[str, float]:
    n = len(trades)
    if n == 0:
        return {"trades": 0, "total_r": 0.0, "net_pnl": 0.0, "win_rate": 0.0, "profit_factor": 0.0,
                "expectancy_r": 0.0, "max_dd_r": 0.0, "max_dd_pct": 0.0, "avg_win_r": 0.0,
                "avg_loss_r": 0.0, "sharpe": 0.0, "exposure": 0.0, "trades_per_year": 0.0,
                "max_loss_streak": 0.0, "recovery_factor": 0.0, "avg_bars": 0.0, "score": 0.0}

    rs = [t.r_multiple for t in trades]
    wins = [r for r in rs if r > 0]
    losses = [-r for r in rs if r <= 0]
    total_r = sum(rs)
    gross_win, gross_loss = sum(wins), sum(losses)

    peak = equity[0] if equity else 0.0
    max_dd = 0.0
    peak_equity = max(equity) if equity else 0.0
    for value in equity:
        peak = max(peak, value)
        max_dd = max(max_dd, peak - value)

    mean_r = total_r / n
    variance = sum((r - mean_r) ** 2 for r in rs) / n
    sd = math.sqrt(variance)
    per_year = n / years if years > 0 else 0.0
    # Sharpe annualizzato sulla serie dei trade (non dei bar): confronta
    # strategie con frequenze diverse a parita' di rischio per trade.
    sharpe = (mean_r / sd) * math.sqrt(per_year) if sd > 0 and per_year > 0 else 0.0

    streak = worst_streak = 0
    for r in rs:
        streak = streak + 1 if r <= 0 else 0
        worst_streak = max(worst_streak, streak)

    bars_in_market = sum(max(t.bars_held, 1) for t in trades)
    net_pnl = sum(t.pnl for t in trades)

    return {
        "trades": float(n),
        "total_r": total_r,
        "net_pnl": net_pnl,
        "win_rate": 100.0 * len(wins) / n,
        "profit_factor": _pf(gross_win, gross_loss),
        "expectancy_r": mean_r,
        "max_dd_r": max_dd / risk if risk else 0.0,
        "max_dd_pct": 100.0 * max_dd / peak_equity if peak_equity > 0 else 0.0,
        "avg_win_r": (sum(wins) / len(wins)) if wins else 0.0,
        "avg_loss_r": (-sum(losses) / len(losses)) if losses else 0.0,
        "sharpe": sharpe,
        "exposure": 100.0 * bars_in_market / bars if bars else 0.0,
        "trades_per_year": per_year,
        "max_loss_streak": float(worst_streak),
        "recovery_factor": (total_r / (max_dd / risk)) if max_dd > 0 and risk else 0.0,
        "avg_bars": bars_in_market / n,
    }


def run_backtest(
    series: Series,
    signals: Sequence[int],
    atr_values: Sequence[Optional[float]],
    exits: ExitRules,
    costs: Optional[Costs] = None,
    risk_per_trade: float = 100.0,
    start_equity: float = 10_000.0,
    allow_short: bool = True,
    max_bars: Optional[int] = None,
) -> Result:
    """Esegue un backtest. ``signals[i]`` = +1/-1/0 deciso alla chiusura di ``i``."""
    costs = costs or Costs()
    n = len(series)
    if len(signals) != n:
        raise ValueError("signals e series hanno lunghezze diverse")

    high, low, open_, close, times = series.high, series.low, series.open, series.close, series.time
    half_spread = costs.spread / 2.0
    friction = half_spread + costs.slippage

    result = Result(risk_per_trade=risk_per_trade)
    equity = start_equity
    trade: Optional[Trade] = None
    stop: float = 0.0
    target: Optional[float] = None
    be_done = False
    bars_held = 0
    max_bars = max_bars or n

    for i in range(n):
        # ---------------- gestione posizione aperta sul bar i ----------------
        # il ciclo copre TUTTI i bar, ultimo compreso: anche l'ultima barra puo'
        # colpire lo stop o il target, chiuderla d'ufficio falserebbe il risultato
        if trade is not None:
            bars_held = i - trade.entry_index
            side = trade.side
            risk_dist = abs(trade.entry_price - trade.stop_price)
            if risk_dist > 0:
                if side == LONG:
                    trade.mae_r = min(trade.mae_r, (low[i] - trade.entry_price) / risk_dist)
                    trade.mfe_r = max(trade.mfe_r, (high[i] - trade.entry_price) / risk_dist)
                else:
                    trade.mae_r = min(trade.mae_r, (trade.entry_price - high[i]) / risk_dist)
                    trade.mfe_r = max(trade.mfe_r, (trade.entry_price - low[i]) / risk_dist)

            exit_price: Optional[float] = None
            reason = ""
            gap = (open_[i] <= stop) if side == LONG else (open_[i] >= stop)
            hit_stop = (low[i] <= stop) if side == LONG else (high[i] >= stop)
            hit_target = target is not None and ((high[i] >= target) if side == LONG else (low[i] <= target))

            if gap:  # il mercato ha aperto oltre lo stop: si esce all'apertura
                exit_price, reason = open_[i], "gap"
            elif hit_stop:  # worst case: stop prima del target se entrambi nel bar
                exit_price, reason = stop, "stop"
            elif hit_target:
                exit_price, reason = target, "target"
            elif exits.time_stop and bars_held >= exits.time_stop:
                exit_price, reason = close[i], "time"
            elif exits.exit_on_flip and signals[i] == -side:
                exit_price, reason = close[i], "flip"

            if exit_price is not None:
                fill = exit_price - friction if side == LONG else exit_price + friction
                gross = (fill - trade.entry_price) * side * trade.size
                commission = costs.commission_per_lot * trade.size / costs.ounces_per_lot
                trade.pnl = gross - commission
                trade.r_multiple = trade.pnl / risk_per_trade if risk_per_trade else 0.0
                trade.exit_index, trade.exit_time, trade.exit_price, trade.reason = i, times[i], fill, reason
                equity += trade.pnl
                result.trades.append(trade)
                result.equity.append(equity)
                result.equity_time.append(times[i])
                trade, target, be_done, bars_held = None, None, False, 0
                if i == n - 1:
                    break
            else:
                # aggiornamento stop: prima il breakeven, poi il trailing
                if exits.breakeven_at_r and not be_done and risk_dist > 0:
                    reached = ((high[i] - trade.entry_price) / risk_dist) if side == LONG else ((trade.entry_price - low[i]) / risk_dist)
                    if reached >= exits.breakeven_at_r:
                        stop = max(stop, trade.entry_price) if side == LONG else min(stop, trade.entry_price)
                        be_done = True
                if exits.trail_atr and atr_values[i]:
                    trail = (high[i] - exits.trail_atr * atr_values[i]) if side == LONG else (low[i] + exits.trail_atr * atr_values[i])
                    stop = max(stop, trail) if side == LONG else min(stop, trail)

        # ---------------- nuovo ingresso: segnale su i, fill su i+1 ----------
        # sull'ultimo bar non si entra: non esiste un bar successivo su cui
        # eseguire l'ordine
        if trade is None and i < n - 1:
            side = signals[i]
            if side == SHORT and not allow_short:
                side = 0
            atr_now = atr_values[i]
            if side in (LONG, SHORT) and atr_now and atr_now > 0:
                entry = open_[i + 1] + friction if side == LONG else open_[i + 1] - friction
                stop_dist = exits.stop_atr * atr_now
                if stop_dist > 0:
                    stop = entry - stop_dist if side == LONG else entry + stop_dist
                    size = risk_per_trade / stop_dist  # once: 1R = perdita allo stop
                    target = None
                    if exits.target_r:
                        target = entry + exits.target_r * stop_dist if side == LONG else entry - exits.target_r * stop_dist
                    trade = Trade(
                        side=side,
                        entry_index=i + 1,
                        entry_time=times[i + 1],
                        entry_price=entry,
                        stop_price=stop,
                        size=size,
                    )
                    be_done, bars_held = False, 0

    # posizione ancora aperta a fine serie: si chiude all'ultimo close
    if trade is not None:
        i = n - 1
        side = trade.side
        fill = close[i] - friction if side == LONG else close[i] + friction
        gross = (fill - trade.entry_price) * side * trade.size
        commission = costs.commission_per_lot * trade.size / costs.ounces_per_lot
        trade.pnl = gross - commission
        trade.r_multiple = trade.pnl / risk_per_trade if risk_per_trade else 0.0
        trade.exit_index, trade.exit_time, trade.exit_price, trade.reason = i, times[i], fill, "eod"
        equity += trade.pnl
        result.trades.append(trade)
        result.equity.append(equity)
        result.equity_time.append(times[i])

    span_days = (times[-1] - times[0]).days if n > 1 else 0
    years = max(span_days / 365.25, 1e-9)
    result.stats = compute_stats(result.trades, result.equity, risk_per_trade, n, years)
    result.stats["years"] = years
    return result
