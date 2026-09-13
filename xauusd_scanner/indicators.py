"""Indicatori tecnici in Python puro (nessuna dipendenza esterna).

Ogni funzione riceve una lista di float e restituisce una lista della stessa
lunghezza, con ``None`` nelle posizioni in cui l'indicatore non e' ancora
definito (periodo di warmup). Questo rende impossibile, per costruzione,
leggere per sbaglio un valore calcolato su dati incompleti.
"""

from __future__ import annotations

import math
from typing import List, Optional, Sequence

Series = List[Optional[float]]


def sma(values: Sequence[float], period: int) -> Series:
    if period <= 0:
        raise ValueError("period deve essere > 0")
    out: Series = [None] * len(values)
    total = 0.0
    for i, v in enumerate(values):
        total += v
        if i >= period:
            total -= values[i - period]
        if i >= period - 1:
            out[i] = total / period
    return out


def ema(values: Sequence[float], period: int) -> Series:
    if period <= 0:
        raise ValueError("period deve essere > 0")
    out: Series = [None] * len(values)
    if len(values) < period:
        return out
    k = 2.0 / (period + 1.0)
    seed = sum(values[:period]) / period
    out[period - 1] = seed
    prev = seed
    for i in range(period, len(values)):
        prev = values[i] * k + prev * (1.0 - k)
        out[i] = prev
    return out


def rma(values: Sequence[float], period: int) -> Series:
    """Media mobile di Wilder (usata da ATR, RSI e ADX classici)."""
    out: Series = [None] * len(values)
    if len(values) < period:
        return out
    seed = sum(values[:period]) / period
    out[period - 1] = seed
    prev = seed
    for i in range(period, len(values)):
        prev = (prev * (period - 1) + values[i]) / period
        out[i] = prev
    return out


def stdev(values: Sequence[float], period: int) -> Series:
    out: Series = [None] * len(values)
    for i in range(period - 1, len(values)):
        window = values[i - period + 1 : i + 1]
        mean = sum(window) / period
        var = sum((v - mean) ** 2 for v in window) / period
        out[i] = math.sqrt(var)
    return out


def true_range(high: Sequence[float], low: Sequence[float], close: Sequence[float]) -> List[float]:
    out = [high[0] - low[0]]
    for i in range(1, len(close)):
        prev_close = close[i - 1]
        out.append(
            max(
                high[i] - low[i],
                abs(high[i] - prev_close),
                abs(low[i] - prev_close),
            )
        )
    return out


def atr(high: Sequence[float], low: Sequence[float], close: Sequence[float], period: int = 14) -> Series:
    return rma(true_range(high, low, close), period)


def rsi(values: Sequence[float], period: int = 14) -> Series:
    out: Series = [None] * len(values)
    if len(values) <= period:
        return out
    gains = [0.0]
    losses = [0.0]
    for i in range(1, len(values)):
        delta = values[i] - values[i - 1]
        gains.append(max(delta, 0.0))
        losses.append(max(-delta, 0.0))
    # il primo delta reale e' in posizione 1: la media di Wilder parte da li'
    avg_gain = rma(gains[1:], period)
    avg_loss = rma(losses[1:], period)
    for i, (g, l) in enumerate(zip(avg_gain, avg_loss), start=1):
        if g is None or l is None:
            continue
        if l == 0:
            out[i] = 100.0
        else:
            rs = g / l
            out[i] = 100.0 - (100.0 / (1.0 + rs))
    return out


def donchian(high: Sequence[float], low: Sequence[float], period: int):
    """Massimo/minimo degli ultimi ``period`` bar ESCLUSO il bar corrente.

    Escludere il bar corrente e' cio' che rende il breakout tradabile: al close
    del bar ``i`` il canale di riferimento e' quello formato prima di ``i``.
    """
    upper: Series = [None] * len(high)
    lower: Series = [None] * len(low)
    for i in range(period, len(high)):
        upper[i] = max(high[i - period : i])
        lower[i] = min(low[i - period : i])
    return upper, lower


def bollinger(values: Sequence[float], period: int = 20, mult: float = 2.0):
    mid = sma(values, period)
    sd = stdev(values, period)
    upper: Series = [None] * len(values)
    lower: Series = [None] * len(values)
    for i in range(len(values)):
        if mid[i] is None or sd[i] is None:
            continue
        upper[i] = mid[i] + mult * sd[i]
        lower[i] = mid[i] - mult * sd[i]
    return upper, mid, lower


def keltner(high, low, close, period: int = 20, mult: float = 2.0):
    mid = ema(close, period)
    rng = atr(high, low, close, period)
    upper: Series = [None] * len(close)
    lower: Series = [None] * len(close)
    for i in range(len(close)):
        if mid[i] is None or rng[i] is None:
            continue
        upper[i] = mid[i] + mult * rng[i]
        lower[i] = mid[i] - mult * rng[i]
    return upper, mid, lower


def macd(values: Sequence[float], fast: int = 12, slow: int = 26, signal: int = 9):
    fast_line = ema(values, fast)
    slow_line = ema(values, slow)
    macd_line: Series = [None] * len(values)
    for i in range(len(values)):
        if fast_line[i] is None or slow_line[i] is None:
            continue
        macd_line[i] = fast_line[i] - slow_line[i]
    start = next((i for i, v in enumerate(macd_line) if v is not None), len(values))
    dense = [v for v in macd_line[start:] if v is not None]
    sig_dense = ema(dense, signal)
    signal_line: Series = [None] * len(values)
    hist: Series = [None] * len(values)
    for offset, v in enumerate(sig_dense):
        if v is None:
            continue
        i = start + offset
        signal_line[i] = v
        hist[i] = macd_line[i] - v
    return macd_line, signal_line, hist


def adx(high: Sequence[float], low: Sequence[float], close: Sequence[float], period: int = 14) -> Series:
    n = len(close)
    out: Series = [None] * n
    if n < period * 2 + 1:
        return out
    plus_dm = [0.0] * n
    minus_dm = [0.0] * n
    for i in range(1, n):
        up = high[i] - high[i - 1]
        down = low[i - 1] - low[i]
        plus_dm[i] = up if (up > down and up > 0) else 0.0
        minus_dm[i] = down if (down > up and down > 0) else 0.0
    tr = true_range(high, low, close)
    tr_s = rma(tr[1:], period)
    plus_s = rma(plus_dm[1:], period)
    minus_s = rma(minus_dm[1:], period)
    dx: List[Optional[float]] = [None] * n
    for offset in range(len(tr_s)):
        i = offset + 1
        if tr_s[offset] in (None, 0) or plus_s[offset] is None or minus_s[offset] is None:
            continue
        plus_di = 100.0 * plus_s[offset] / tr_s[offset]
        minus_di = 100.0 * minus_s[offset] / tr_s[offset]
        denom = plus_di + minus_di
        dx[i] = 0.0 if denom == 0 else 100.0 * abs(plus_di - minus_di) / denom
    start = next((i for i, v in enumerate(dx) if v is not None), n)
    dense = [v for v in dx[start:] if v is not None]
    smoothed = rma(dense, period)
    for offset, v in enumerate(smoothed):
        if v is not None:
            out[start + offset] = v
    return out


def roc(values: Sequence[float], period: int) -> Series:
    out: Series = [None] * len(values)
    for i in range(period, len(values)):
        base = values[i - period]
        if base:
            out[i] = (values[i] / base - 1.0) * 100.0
    return out


def highest(values: Sequence[float], period: int) -> Series:
    out: Series = [None] * len(values)
    for i in range(period - 1, len(values)):
        out[i] = max(values[i - period + 1 : i + 1])
    return out


def lowest(values: Sequence[float], period: int) -> Series:
    out: Series = [None] * len(values)
    for i in range(period - 1, len(values)):
        out[i] = min(values[i - period + 1 : i + 1])
    return out


def percent_rank(values: Sequence[Optional[float]], period: int) -> Series:
    """Percentile del valore corrente nella finestra (0-100). Usato per i filtri
    di volatilita': 'ATR nel 20% piu' basso degli ultimi 100 bar'."""
    out: Series = [None] * len(values)
    for i in range(len(values)):
        if i < period - 1 or values[i] is None:
            continue
        window = [v for v in values[i - period + 1 : i + 1] if v is not None]
        if len(window) < period // 2:
            continue
        below = sum(1 for v in window if v < values[i])
        out[i] = 100.0 * below / len(window)
    return out
