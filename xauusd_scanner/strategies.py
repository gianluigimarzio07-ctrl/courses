"""Famiglie di strategie su XAUUSD e generazione delle varianti.

Una *strategia* qui e' una funzione pura ``(series, cache, params) -> signals``
dove ``signals[i] in {-1, 0, +1}`` e' la decisione presa ALLA CHIUSURA del bar
``i``. Il motore di backtest entra al bar successivo, quindi finche' le funzioni
leggono solo indici <= i non c'e' lookahead.

Le famiglie coprono i tre comportamenti classici dell'oro:
  * trend following  (l'oro fa trend lunghi e violenti sulle notizie macro)
  * breakout di volatilita' (compressione -> espansione)
  * mean reversion in regime laterale (il range asiatico, le fasi di risk-on)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from . import indicators as ind
from .backtest import ExitRules
from .data import Series

Signals = List[int]


class Cache:
    """Memoizza gli indicatori: decine di varianti condividono le stesse EMA,
    ricalcolarle ogni volta triplicherebbe il tempo di scansione."""

    def __init__(self, series: Series):
        self.s = series
        self._store: Dict[tuple, object] = {}

    def _get(self, key: tuple, build: Callable[[], object]):
        if key not in self._store:
            self._store[key] = build()
        return self._store[key]

    def ema(self, period: int):
        return self._get(("ema", period), lambda: ind.ema(self.s.close, period))

    def sma(self, period: int):
        return self._get(("sma", period), lambda: ind.sma(self.s.close, period))

    def atr(self, period: int = 14):
        return self._get(("atr", period), lambda: ind.atr(self.s.high, self.s.low, self.s.close, period))

    def rsi(self, period: int = 14):
        return self._get(("rsi", period), lambda: ind.rsi(self.s.close, period))

    def adx(self, period: int = 14):
        return self._get(("adx", period), lambda: ind.adx(self.s.high, self.s.low, self.s.close, period))

    def donchian(self, period: int):
        return self._get(("don", period), lambda: ind.donchian(self.s.high, self.s.low, period))

    def bollinger(self, period: int, mult: float):
        return self._get(("bb", period, mult), lambda: ind.bollinger(self.s.close, period, mult))

    def keltner(self, period: int, mult: float):
        return self._get(("kc", period, mult), lambda: ind.keltner(self.s.high, self.s.low, self.s.close, period, mult))

    def macd(self, fast: int, slow: int, signal: int):
        return self._get(("macd", fast, slow, signal), lambda: ind.macd(self.s.close, fast, slow, signal))

    def atr_rank(self, period: int, window: int):
        return self._get(
            ("atrrank", period, window),
            lambda: ind.percent_rank(self.atr(period), window),
        )


def _trend_ok(cache: Cache, period: Optional[int], i: int, side: int) -> bool:
    """Filtro di trend opzionale: opera solo nella direzione della media lunga."""
    if not period:
        return True
    ma = cache.sma(period)
    if ma[i] is None:
        return False
    return cache.s.close[i] > ma[i] if side > 0 else cache.s.close[i] < ma[i]


# ---------------------------------------------------------------------------
# famiglie
# ---------------------------------------------------------------------------

def ema_cross(series: Series, cache: Cache, p: dict) -> Signals:
    """Incrocio di due EMA: entra al cambio di stato, resta nello stato."""
    fast, slow = cache.ema(p["fast"]), cache.ema(p["slow"])
    out: Signals = [0] * len(series)
    prev = 0
    for i in range(len(series)):
        if fast[i] is None or slow[i] is None:
            continue
        state = 1 if fast[i] > slow[i] else -1
        if state != prev and prev != 0 and _trend_ok(cache, p.get("trend"), i, state):
            out[i] = state
        elif state != prev and prev == 0:
            pass  # il primo stato non e' un incrocio: niente trade
        prev = state
    return out


def ema_stack(series: Series, cache: Cache, p: dict) -> Signals:
    """Stato di trend continuo (fast > slow): usato con uscita 'flip'."""
    fast, slow = cache.ema(p["fast"]), cache.ema(p["slow"])
    out: Signals = [0] * len(series)
    for i in range(len(series)):
        if fast[i] is None or slow[i] is None:
            continue
        side = 1 if fast[i] > slow[i] else -1
        if _trend_ok(cache, p.get("trend"), i, side):
            out[i] = side
    return out


def donchian_breakout(series: Series, cache: Cache, p: dict) -> Signals:
    """Rottura del massimo/minimo degli ultimi N bar (Turtle style)."""
    upper, lower = cache.donchian(p["lookback"])
    out: Signals = [0] * len(series)
    for i in range(len(series)):
        if upper[i] is None:
            continue
        c = series.close[i]
        if c > upper[i] and _trend_ok(cache, p.get("trend"), i, 1):
            out[i] = 1
        elif c < lower[i] and _trend_ok(cache, p.get("trend"), i, -1):
            out[i] = -1
    return out


def bollinger_fade(series: Series, cache: Cache, p: dict) -> Signals:
    """Mean reversion: chiusura fuori banda -> rientro atteso verso la media.

    Opzionalmente solo in regime di bassa volatilita' (``atr_rank_max``), dove
    il fade funziona; in espansione di volatilita' la stessa logica e' letale.
    """
    upper, mid, lower = cache.bollinger(p["period"], p["mult"])
    rank = cache.atr_rank(14, p["rank_window"]) if p.get("atr_rank_max") else None
    out: Signals = [0] * len(series)
    for i in range(len(series)):
        if upper[i] is None:
            continue
        if rank is not None and (rank[i] is None or rank[i] > p["atr_rank_max"]):
            continue
        c = series.close[i]
        if c < lower[i]:
            out[i] = 1
        elif c > upper[i]:
            out[i] = -1
    return out


def rsi_pullback(series: Series, cache: Cache, p: dict) -> Signals:
    """Pullback in trend: RSI torna da ipervenduto mentre il trend e' rialzista."""
    rsi = cache.rsi(p["period"])
    trend = cache.sma(p["trend"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if rsi[i] is None or rsi[i - 1] is None or trend[i] is None:
            continue
        up = series.close[i] > trend[i]
        low_level, high_level = p["level"], 100 - p["level"]
        if up and rsi[i - 1] < low_level <= rsi[i]:
            out[i] = 1
        elif not up and rsi[i - 1] > high_level >= rsi[i]:
            out[i] = -1
    return out


def macd_momentum(series: Series, cache: Cache, p: dict) -> Signals:
    """Incrocio MACD/signal con istogramma che cambia segno."""
    line, signal, hist = cache.macd(p["fast"], p["slow"], p["signal"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if hist[i] is None or hist[i - 1] is None:
            continue
        if hist[i - 1] <= 0 < hist[i] and _trend_ok(cache, p.get("trend"), i, 1):
            out[i] = 1
        elif hist[i - 1] >= 0 > hist[i] and _trend_ok(cache, p.get("trend"), i, -1):
            out[i] = -1
    return out


def keltner_squeeze(series: Series, cache: Cache, p: dict) -> Signals:
    """Squeeze: Bollinger dentro Keltner = compressione; si opera la rottura."""
    bb_up, bb_mid, bb_low = cache.bollinger(p["period"], 2.0)
    kc_up, kc_mid, kc_low = cache.keltner(p["period"], p["mult"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if None in (bb_up[i], kc_up[i], bb_up[i - 1], kc_up[i - 1]):
            continue
        squeezed_before = bb_up[i - 1] < kc_up[i - 1] and bb_low[i - 1] > kc_low[i - 1]
        released = not (bb_up[i] < kc_up[i] and bb_low[i] > kc_low[i])
        if squeezed_before and released:
            out[i] = 1 if series.close[i] > kc_mid[i] else -1
    return out


def atr_thrust(series: Series, cache: Cache, p: dict) -> Signals:
    """Espansione di volatilita': il bar chiude oltre chiusura precedente
    +/- k*ATR. E' il classico 'giorno di news' sull'oro."""
    atr = cache.atr(p["atr_period"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if atr[i] is None:
            continue
        move = series.close[i] - series.close[i - 1]
        threshold = p["mult"] * atr[i]
        if move > threshold and _trend_ok(cache, p.get("trend"), i, 1):
            out[i] = 1
        elif move < -threshold and _trend_ok(cache, p.get("trend"), i, -1):
            out[i] = -1
    return out


def inside_bar_break(series: Series, cache: Cache, p: dict) -> Signals:
    """Compressione del range (NR-n / inside bar) e rottura del massimo o
    minimo della barra madre."""
    n = p["bars"]
    out: Signals = [0] * len(series)
    for i in range(n + 1, len(series)):
        mother_high = max(series.high[i - n : i])
        mother_low = min(series.low[i - n : i])
        ref_high = series.high[i - n - 1]
        ref_low = series.low[i - n - 1]
        compressed = mother_high <= ref_high and mother_low >= ref_low
        if not compressed:
            continue
        if series.close[i] > mother_high and _trend_ok(cache, p.get("trend"), i, 1):
            out[i] = 1
        elif series.close[i] < mother_low and _trend_ok(cache, p.get("trend"), i, -1):
            out[i] = -1
    return out


def ma_pullback(series: Series, cache: Cache, p: dict) -> Signals:
    """Trend con la media lunga, ingresso sul ritorno sopra la media veloce."""
    fast, trend = cache.ema(p["fast"]), cache.sma(p["trend"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if fast[i] is None or trend[i] is None or fast[i - 1] is None:
            continue
        c, prev = series.close[i], series.close[i - 1]
        if c > trend[i] and prev < fast[i - 1] and c > fast[i]:
            out[i] = 1
        elif c < trend[i] and prev > fast[i - 1] and c < fast[i]:
            out[i] = -1
    return out


def adx_trend(series: Series, cache: Cache, p: dict) -> Signals:
    """Direzione data dalla media, ma solo quando ADX conferma il trend."""
    adx = cache.adx(p["adx_period"])
    ma = cache.ema(p["ma"])
    out: Signals = [0] * len(series)
    for i in range(1, len(series)):
        if adx[i] is None or ma[i] is None or adx[i - 1] is None:
            continue
        crossing_up = adx[i - 1] < p["level"] <= adx[i]
        if not crossing_up:
            continue
        out[i] = 1 if series.close[i] > ma[i] else -1
    return out


def range_fade(series: Series, cache: Cache, p: dict) -> Signals:
    """Fade degli estremi del canale in regime compresso (ATR nel percentile
    basso): compra il minimo del canale, vende il massimo."""
    upper, lower = cache.donchian(p["lookback"])
    rank = cache.atr_rank(14, p["rank_window"])
    out: Signals = [0] * len(series)
    for i in range(len(series)):
        if upper[i] is None or rank[i] is None or rank[i] > p["rank_max"]:
            continue
        if series.low[i] <= lower[i]:
            out[i] = 1
        elif series.high[i] >= upper[i]:
            out[i] = -1
    return out


FAMILIES: Dict[str, Callable[[Series, Cache, dict], Signals]] = {
    "EMA cross": ema_cross,
    "EMA stack": ema_stack,
    "Donchian": donchian_breakout,
    "BB fade": bollinger_fade,
    "RSI pullback": rsi_pullback,
    "MACD": macd_momentum,
    "Squeeze": keltner_squeeze,
    "ATR thrust": atr_thrust,
    "Inside bar": inside_bar_break,
    "MA pullback": ma_pullback,
    "ADX trend": adx_trend,
    "Range fade": range_fade,
}

# le famiglie mean-reverting non vanno filtrate con il trend a 200
MEAN_REVERTING = {"BB fade", "Range fade"}


@dataclass
class Variant:
    """Una strategia completa: famiglia + parametri + regole di uscita."""

    family: str
    params: dict
    exits: ExitRules
    atr_period: int = 14

    @property
    def param_label(self) -> str:
        order = ("fast", "slow", "period", "lookback", "mult", "level", "bars",
                 "ma", "adx_period", "signal", "trend", "rank_max", "atr_rank_max")
        bits = []
        for key in order:
            if key in self.params and self.params[key]:
                value = self.params[key]
                bits.append(f"{value:g}" if isinstance(value, (int, float)) else str(value))
        return "/".join(bits)

    @property
    def name(self) -> str:
        return f"{self.family} {self.param_label}"

    @property
    def key(self) -> str:
        return f"{self.name} | {self.exits.label()}"

    def signals(self, series: Series, cache: Cache) -> Signals:
        return FAMILIES[self.family](series, cache, self.params)


def _param_grid(intraday: bool) -> Dict[str, List[dict]]:
    """Griglia dei parametri. Sull'intraday le finestre sono piu' lunghe in bar
    per coprire lo stesso arco temporale del daily."""
    k = 4 if intraday else 1
    return {
        "EMA cross": [
            {"fast": 8 * k, "slow": 21 * k}, {"fast": 10 * k, "slow": 30 * k},
            {"fast": 20 * k, "slow": 50 * k}, {"fast": 20 * k, "slow": 50 * k, "trend": 200 * k},
            {"fast": 50 * k, "slow": 100 * k}, {"fast": 12 * k, "slow": 26 * k, "trend": 200 * k},
        ],
        "EMA stack": [
            {"fast": 20 * k, "slow": 50 * k}, {"fast": 10 * k, "slow": 40 * k},
            {"fast": 50 * k, "slow": 200 * k},
        ],
        "Donchian": [
            {"lookback": 10 * k}, {"lookback": 20 * k}, {"lookback": 55 * k},
            {"lookback": 20 * k, "trend": 200 * k}, {"lookback": 55 * k, "trend": 200 * k},
            {"lookback": 100 * k},
        ],
        "BB fade": [
            {"period": 20 * k, "mult": 2.0}, {"period": 20 * k, "mult": 2.5},
            {"period": 30 * k, "mult": 2.0},
            {"period": 20 * k, "mult": 2.0, "atr_rank_max": 40, "rank_window": 100 * k},
            {"period": 20 * k, "mult": 2.5, "atr_rank_max": 60, "rank_window": 100 * k},
        ],
        "RSI pullback": [
            {"period": 14, "level": 30, "trend": 200 * k}, {"period": 14, "level": 40, "trend": 200 * k},
            {"period": 7, "level": 25, "trend": 100 * k}, {"period": 14, "level": 35, "trend": 100 * k},
            {"period": 21, "level": 40, "trend": 200 * k},
        ],
        "MACD": [
            {"fast": 12 * k, "slow": 26 * k, "signal": 9 * k},
            {"fast": 12 * k, "slow": 26 * k, "signal": 9 * k, "trend": 200 * k},
            {"fast": 8 * k, "slow": 17 * k, "signal": 9 * k},
            {"fast": 19 * k, "slow": 39 * k, "signal": 9 * k, "trend": 200 * k},
        ],
        "Squeeze": [
            {"period": 20 * k, "mult": 1.5}, {"period": 20 * k, "mult": 2.0},
            {"period": 30 * k, "mult": 1.5},
        ],
        "ATR thrust": [
            {"atr_period": 14, "mult": 0.8}, {"atr_period": 14, "mult": 1.2},
            {"atr_period": 14, "mult": 1.2, "trend": 200 * k}, {"atr_period": 20, "mult": 1.6},
        ],
        "Inside bar": [
            {"bars": 1}, {"bars": 2}, {"bars": 3},
            {"bars": 2, "trend": 200 * k},
        ],
        "MA pullback": [
            {"fast": 20 * k, "trend": 200 * k}, {"fast": 10 * k, "trend": 100 * k},
            {"fast": 20 * k, "trend": 100 * k}, {"fast": 50 * k, "trend": 200 * k},
        ],
        "ADX trend": [
            {"adx_period": 14, "level": 25, "ma": 50 * k},
            {"adx_period": 14, "level": 20, "ma": 100 * k},
            {"adx_period": 20, "level": 25, "ma": 50 * k},
        ],
        "Range fade": [
            {"lookback": 20 * k, "rank_max": 40, "rank_window": 100 * k},
            {"lookback": 10 * k, "rank_max": 50, "rank_window": 100 * k},
            {"lookback": 20 * k, "rank_max": 60, "rank_window": 100 * k},
        ],
    }


def _exit_grid(family: str) -> List[ExitRules]:
    """Uscite adatte al comportamento della famiglia: il trend following ha
    bisogno di code lunghe (trailing), la mean reversion di target stretti."""
    if family in MEAN_REVERTING:
        return [
            ExitRules(stop_atr=1.5, target_r=1.0),
            ExitRules(stop_atr=2.0, target_r=1.0),
            ExitRules(stop_atr=2.0, target_r=1.5),
            ExitRules(stop_atr=1.5, target_r=1.5, time_stop=10),
            ExitRules(stop_atr=2.5, target_r=1.0, time_stop=15),
        ]
    if family == "EMA stack":
        return [
            ExitRules(stop_atr=2.0, target_r=None, exit_on_flip=True),
            ExitRules(stop_atr=3.0, target_r=None, exit_on_flip=True),
            ExitRules(stop_atr=2.0, target_r=None, trail_atr=3.0, exit_on_flip=True),
        ]
    return [
        ExitRules(stop_atr=1.5, target_r=2.0),
        ExitRules(stop_atr=2.0, target_r=2.0),
        ExitRules(stop_atr=2.0, target_r=3.0),
        ExitRules(stop_atr=2.0, target_r=3.0, breakeven_at_r=1.0),
        ExitRules(stop_atr=2.0, target_r=None, trail_atr=2.5),
        ExitRules(stop_atr=3.0, target_r=None, trail_atr=3.5),
        ExitRules(stop_atr=2.0, target_r=4.0, breakeven_at_r=1.5, time_stop=30),
    ]


def build_variants(intraday: bool = False, families: Optional[Sequence[str]] = None) -> List[Variant]:
    """Prodotto cartesiano famiglie x parametri x uscite: sono le tessere
    della heatmap."""
    grid = _param_grid(intraday)
    chosen = list(families) if families else list(FAMILIES)
    variants: List[Variant] = []
    for family in chosen:
        if family not in grid:
            raise KeyError(f"famiglia sconosciuta: {family}")
        for params in grid[family]:
            for exits in _exit_grid(family):
                variants.append(Variant(family=family, params=dict(params), exits=exits))
    return variants
