"""Caricamento dati OHLC per XAUUSD.

Tre sorgenti, tutte opzionali e senza dipendenze esterne:

* ``load_csv``   - export da MT4/MT5, TradingView, Dukascopy, cTrader ...
* ``fetch_web``  - download da Stooq o Yahoo Finance (richiede rete aperta)
* ``synthetic``  - serie deterministica generata da seed, per demo e test

Il formato interno e' una ``Series`` di ``Bar``: liste parallele di float,
scelte perche' il backtest le scorre milioni di volte e le tuple di liste sono
molto piu' veloci di una lista di oggetti in Python puro.
"""

from __future__ import annotations

import csv
import io
import json
import math
import os
import random
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Sequence

# alias comuni con cui le piattaforme nominano le colonne
_TIME_KEYS = ("datetime", "date", "time", "timestamp", "data", "<date>", "local time", "gmt time")
_OPEN_KEYS = ("open", "o", "<open>", "apertura")
_HIGH_KEYS = ("high", "h", "<high>", "massimo", "max")
_LOW_KEYS = ("low", "l", "<low>", "minimo", "min")
_CLOSE_KEYS = ("close", "c", "adj close", "<close>", "chiusura", "price")
_VOL_KEYS = ("volume", "vol", "<vol>", "tickvol", "<tickvol>", "volumi")

_TIME_FORMATS = (
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d %H:%M",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%dT%H:%M:%SZ",
    "%Y-%m-%d",
    "%Y.%m.%d %H:%M:%S",
    "%Y.%m.%d %H:%M",
    "%Y.%m.%d",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y %H:%M",
    "%d/%m/%Y",
    "%m/%d/%Y %H:%M",
    "%m/%d/%Y",
    "%d.%m.%Y %H:%M:%S",
    "%Y%m%d %H:%M:%S",
    "%Y%m%d",
)


@dataclass
class Series:
    """Serie OHLC di un singolo strumento."""

    symbol: str
    timeframe: str
    time: List[datetime] = field(default_factory=list)
    open: List[float] = field(default_factory=list)
    high: List[float] = field(default_factory=list)
    low: List[float] = field(default_factory=list)
    close: List[float] = field(default_factory=list)
    volume: List[float] = field(default_factory=list)
    source: str = "unknown"

    def __len__(self) -> int:
        return len(self.close)

    @property
    def start(self) -> Optional[datetime]:
        return self.time[0] if self.time else None

    @property
    def end(self) -> Optional[datetime]:
        return self.time[-1] if self.time else None

    def slice(self, start: Optional[datetime] = None, end: Optional[datetime] = None) -> "Series":
        idx = [
            i
            for i, t in enumerate(self.time)
            if (start is None or t >= start) and (end is None or t <= end)
        ]
        out = Series(self.symbol, self.timeframe, source=self.source)
        for i in idx:
            out.time.append(self.time[i])
            out.open.append(self.open[i])
            out.high.append(self.high[i])
            out.low.append(self.low[i])
            out.close.append(self.close[i])
            out.volume.append(self.volume[i])
        return out

    def validate(self) -> List[str]:
        """Controlli di sanita' sui dati: righe incoerenti rovinano un backtest
        in modo silenzioso, quindi vanno segnalate prima di partire."""
        problems: List[str] = []
        n = len(self)
        if n < 200:
            problems.append(f"solo {n} bar: troppo pochi per un backtest significativo")
        bad_ohlc = sum(
            1
            for i in range(n)
            if not (self.low[i] <= min(self.open[i], self.close[i])
                    and self.high[i] >= max(self.open[i], self.close[i])
                    and self.high[i] >= self.low[i])
        )
        if bad_ohlc:
            problems.append(f"{bad_ohlc} bar con OHLC incoerente (high/low non contengono open/close)")
        non_positive = sum(1 for c in self.close if c <= 0)
        if non_positive:
            problems.append(f"{non_positive} bar con prezzo <= 0")
        unsorted = sum(1 for i in range(1, n) if self.time[i] <= self.time[i - 1])
        if unsorted:
            problems.append(f"{unsorted} timestamp non crescenti (duplicati o fuori ordine)")
        return problems


def _norm(name: str) -> str:
    return name.strip().lower().replace("﻿", "")


def _pick(header: Sequence[str], keys: Sequence[str]) -> Optional[int]:
    normalized = [_norm(h) for h in header]
    for key in keys:
        if key in normalized:
            return normalized.index(key)
    for key in keys:
        for i, h in enumerate(normalized):
            if h.startswith(key):
                return i
    return None


def parse_time(raw: str) -> datetime:
    raw = raw.strip().strip('"')
    if raw.isdigit() and len(raw) >= 10:  # epoch secondi o millisecondi
        value = int(raw)
        if value > 10 ** 12:
            value //= 1000
        return datetime.fromtimestamp(value, tz=timezone.utc).replace(tzinfo=None)
    cleaned = raw.replace("T", " ").split("+")[0].split(".")[0] if "T" in raw else raw
    for fmt in _TIME_FORMATS:
        for candidate in (raw, cleaned):
            try:
                return datetime.strptime(candidate, fmt)
            except ValueError:
                continue
    raise ValueError(f"formato data non riconosciuto: {raw!r}")


def _to_float(raw: str) -> float:
    raw = raw.strip().strip('"').replace(" ", "")
    if raw.count(",") == 1 and raw.count(".") == 0:  # decimale all'italiana
        raw = raw.replace(",", ".")
    else:
        raw = raw.replace(",", "")
    return float(raw)


def parse_ohlc(text: str, symbol: str = "XAUUSD", timeframe: str = "auto", source: str = "csv") -> Series:
    """Parsa un CSV/TSV OHLC riconoscendo header e separatore automaticamente."""
    text = text.lstrip("﻿")
    sample = "\n".join(text.splitlines()[:5])
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
        delimiter = dialect.delimiter
    except csv.Error:
        delimiter = "\t" if "\t" in sample else ";" if ";" in sample else ","
    rows = list(csv.reader(io.StringIO(text), delimiter=delimiter))
    rows = [r for r in rows if r and any(c.strip() for c in r)]
    if not rows:
        raise ValueError("file vuoto")

    header = rows[0]
    has_header = _pick(header, _CLOSE_KEYS) is not None or _pick(header, _TIME_KEYS) is not None
    if has_header:
        i_t = _pick(header, _TIME_KEYS)
        i_o = _pick(header, _OPEN_KEYS)
        i_h = _pick(header, _HIGH_KEYS)
        i_l = _pick(header, _LOW_KEYS)
        i_c = _pick(header, _CLOSE_KEYS)
        i_v = _pick(header, _VOL_KEYS)
        body = rows[1:]
        # MT5 esporta data e ora in due colonne separate
        time_extra = None
        if i_t is not None and _norm(header[i_t]) in ("date", "<date>", "data"):
            nxt = i_t + 1
            if nxt < len(header) and _norm(header[nxt]) in ("time", "<time>", "ora"):
                time_extra = nxt
    else:  # senza header: assume date,open,high,low,close[,volume]
        i_t, i_o, i_h, i_l, i_c, i_v, time_extra = 0, 1, 2, 3, 4, (5 if len(header) > 5 else None), None
        body = rows
    if None in (i_t, i_o, i_h, i_l, i_c):
        raise ValueError(f"colonne OHLC non trovate nell'header: {header}")

    series = Series(symbol, timeframe, source=source)
    skipped = 0
    for row in body:
        try:
            stamp = row[i_t] if time_extra is None else f"{row[i_t]} {row[time_extra]}"
            t = parse_time(stamp)
            o, h, l, c = (_to_float(row[i_o]), _to_float(row[i_h]), _to_float(row[i_l]), _to_float(row[i_c]))
            v = _to_float(row[i_v]) if i_v is not None and i_v < len(row) and row[i_v].strip() else 0.0
        except (ValueError, IndexError):
            skipped += 1
            continue
        if h < l or c <= 0:
            skipped += 1
            continue
        series.time.append(t)
        series.open.append(o)
        series.high.append(h)
        series.low.append(l)
        series.close.append(c)
        series.volume.append(v)
    if not series.time:
        raise ValueError(f"nessuna riga valida ({skipped} scartate)")

    order = sorted(range(len(series.time)), key=lambda i: series.time[i])
    if order != list(range(len(order))):
        series.time = [series.time[i] for i in order]
        series.open = [series.open[i] for i in order]
        series.high = [series.high[i] for i in order]
        series.low = [series.low[i] for i in order]
        series.close = [series.close[i] for i in order]
        series.volume = [series.volume[i] for i in order]
    if timeframe == "auto":
        series.timeframe = infer_timeframe(series.time)
    return series


def infer_timeframe(times: Sequence[datetime]) -> str:
    """Deduce il timeframe dalla mediana degli intervalli fra bar."""
    if len(times) < 3:
        return "unknown"
    deltas = sorted((times[i] - times[i - 1]).total_seconds() for i in range(1, min(len(times), 500)))
    median = deltas[len(deltas) // 2]
    table = [
        (60, "M1"), (300, "M5"), (900, "M15"), (1800, "M30"), (3600, "H1"),
        (14400, "H4"), (86400, "D1"), (604800, "W1"), (2592000, "MN"),
    ]
    best = min(table, key=lambda item: abs(math.log((median or 1) / item[0])))
    return best[1]


def load_csv(path: str, symbol: str = "XAUUSD", timeframe: str = "auto") -> Series:
    with open(path, "r", encoding="utf-8-sig", errors="replace") as fh:
        return parse_ohlc(fh.read(), symbol=symbol, timeframe=timeframe, source=os.path.basename(path))


# --------------------------------------------------------------------------
# download opzionale (funziona solo se l'ambiente ha accesso a internet)
# --------------------------------------------------------------------------

STOOQ_URL = "https://stooq.com/q/d/l/?s={symbol}&i={interval}"
YAHOO_URL = "https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?range={range}&interval={interval}"

# Stooq quota lo spot; Yahoo il future COMEX (GC=F) o il cross valutario
STOOQ_SYMBOLS = {"XAUUSD": "xauusd"}
YAHOO_SYMBOLS = {"XAUUSD": "GC=F"}


def _http_get(url: str, timeout: float = 30.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "xauusd-scanner/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def fetch_stooq(symbol: str = "XAUUSD", interval: str = "d") -> Series:
    """Storico giornaliero/settimanale da Stooq (CSV, nessuna API key)."""
    url = STOOQ_URL.format(symbol=STOOQ_SYMBOLS.get(symbol.upper(), symbol.lower()), interval=interval)
    text = _http_get(url)
    if "Date" not in text.splitlines()[0]:
        raise RuntimeError(f"risposta inattesa da Stooq: {text[:120]!r}")
    return parse_ohlc(text, symbol=symbol.upper(), source="stooq")


def fetch_yahoo(symbol: str = "XAUUSD", range_: str = "10y", interval: str = "1d") -> Series:
    """Storico da Yahoo Finance (JSON). Supporta anche intraday recente
    (``interval='1h'`` con ``range_='2y'``)."""
    url = YAHOO_URL.format(
        symbol=urllib.parse.quote(YAHOO_SYMBOLS.get(symbol.upper(), symbol)),
        range=range_,
        interval=interval,
    )
    payload = json.loads(_http_get(url))
    result = payload["chart"]["result"][0]
    stamps = result["timestamp"]
    quote = result["indicators"]["quote"][0]
    series = Series(symbol.upper(), interval.upper(), source="yahoo")
    for i, ts in enumerate(stamps):
        o, h, l, c = quote["open"][i], quote["high"][i], quote["low"][i], quote["close"][i]
        if None in (o, h, l, c):
            continue
        series.time.append(datetime.fromtimestamp(ts, tz=timezone.utc).replace(tzinfo=None))
        series.open.append(float(o))
        series.high.append(float(h))
        series.low.append(float(l))
        series.close.append(float(c))
        series.volume.append(float((quote.get("volume") or [0])[i] or 0))
    if not series.time:
        raise RuntimeError("Yahoo ha restituito una serie vuota")
    series.timeframe = infer_timeframe(series.time)
    return series


def fetch_web(symbol: str = "XAUUSD", interval: str = "1d") -> Series:
    """Prova Stooq, poi Yahoo. Solleva l'ultimo errore se entrambe falliscono."""
    errors = []
    for name, call in (
        ("stooq", lambda: fetch_stooq(symbol, "d" if interval.endswith("d") else "w")),
        ("yahoo", lambda: fetch_yahoo(symbol, "10y", interval)),
    ):
        try:
            return call()
        except Exception as exc:  # rete chiusa, rate limit, formato cambiato
            errors.append(f"{name}: {exc}")
    raise RuntimeError("download fallito -> " + " | ".join(errors))


# --------------------------------------------------------------------------
# serie sintetica deterministica (demo offline e test)
# --------------------------------------------------------------------------

def synthetic(
    bars: int = 2600,
    seed: int = 7,
    start_price: float = 1450.0,
    timeframe: str = "D1",
    start: Optional[datetime] = None,
) -> Series:
    """Genera una serie OHLC realistica per l'oro: trend a regimi alternati,
    volatilita' a cluster (GARCH-like) e gap di weekend.

    Serve a far girare lo scanner senza rete. NON e' oro vero: i risultati di
    un backtest su questa serie non dicono nulla sul mercato reale.
    """
    rng = random.Random(seed)
    step = {"M15": timedelta(minutes=15), "H1": timedelta(hours=1), "H4": timedelta(hours=4)}.get(
        timeframe, timedelta(days=1)
    )
    t = start or (datetime(2015, 1, 2) if step >= timedelta(days=1) else datetime(2023, 1, 2, 0, 0))
    per_year = {"M15": 96 * 252, "H1": 24 * 252, "H4": 6 * 252}.get(timeframe, 252)

    series = Series("XAUUSD-SYNTH", timeframe, source=f"synthetic(seed={seed})")
    price = start_price
    vol = 0.011 / math.sqrt(per_year / 252)  # vol per bar
    drift = 0.0
    regime_left = 0
    for _ in range(bars):
        if regime_left <= 0:  # nuovo regime: trend su, giu' o laterale
            regime_left = rng.randint(int(per_year / 12), int(per_year / 3))
            drift = rng.choice([0.22, 0.10, 0.0, -0.08, -0.18]) / per_year
        regime_left -= 1
        # volatilita' con memoria: cluster di calma e di panico
        vol = max(0.0025, min(0.05, 0.94 * vol + 0.06 * (0.011 / math.sqrt(per_year / 252)) + rng.gauss(0, 0.0009)))
        shock = rng.gauss(0, 1)
        if rng.random() < 0.01:  # news shock (NFP, CPI, banche centrali)
            shock *= rng.uniform(2.5, 4.5)
        ret = drift + vol * shock
        open_ = price
        close = open_ * math.exp(ret)
        body_high = max(open_, close)
        body_low = min(open_, close)
        wick = abs(ret) * rng.uniform(0.3, 1.6) + vol * rng.uniform(0.1, 0.9)
        high = body_high * (1 + wick * rng.uniform(0.2, 1.0))
        low = body_low * (1 - wick * rng.uniform(0.2, 1.0))
        series.time.append(t)
        series.open.append(round(open_, 2))
        series.high.append(round(high, 2))
        series.low.append(round(low, 2))
        series.close.append(round(close, 2))
        series.volume.append(float(rng.randint(40_000, 260_000)))
        price = close
        t += step
        if step >= timedelta(days=1):
            while t.weekday() >= 5:  # salta sabato e domenica
                t += step
    return series
