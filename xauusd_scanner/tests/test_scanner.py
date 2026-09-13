import json
import unittest

from xauusd_scanner.backtest import Costs
from xauusd_scanner.data import synthetic
from xauusd_scanner.report import build_html
from xauusd_scanner.scanner import robustness_score, scan, summarize
from xauusd_scanner.strategies import FAMILIES, Cache, build_variants

SERIES = synthetic(bars=900, seed=11)


class TestStrategies(unittest.TestCase):
    def test_every_family_produces_valid_signals(self):
        cache = Cache(SERIES)
        seen = set()
        for variant in build_variants():
            signals = variant.signals(SERIES, cache)
            self.assertEqual(len(signals), len(SERIES))
            self.assertTrue(set(signals) <= {-1, 0, 1})
            if any(signals):
                seen.add(variant.family)
        self.assertEqual(seen, set(FAMILIES), "una famiglia non ha generato alcun segnale")

    def test_signals_do_not_depend_on_the_future(self):
        """Tagliare la serie a meta' non deve cambiare i segnali della prima
        meta': se cambiassero, la strategia starebbe leggendo il futuro."""
        cut = 600
        head = SERIES.slice(end=SERIES.time[cut - 1])
        full_cache, head_cache = Cache(SERIES), Cache(head)
        for variant in build_variants():
            full = variant.signals(SERIES, full_cache)[:cut]
            partial = variant.signals(head, head_cache)
            self.assertEqual(full, partial, f"lookahead in {variant.name}")

    def test_variant_keys_are_unique(self):
        keys = [v.key for v in build_variants()]
        self.assertEqual(len(keys), len(set(keys)))

    def test_unknown_family_raises(self):
        with self.assertRaises(KeyError):
            build_variants(families=["Non esiste"])

    def test_intraday_grid_uses_longer_windows(self):
        daily = {v.param_label for v in build_variants(intraday=False, families=["EMA cross"])}
        intraday = {v.param_label for v in build_variants(intraday=True, families=["EMA cross"])}
        self.assertNotEqual(daily, intraday)


class TestScan(unittest.TestCase):
    def test_scan_is_deterministic_and_parallel_safe(self):
        variants = build_variants(families=["Donchian", "BB fade"])
        sequential = scan(SERIES, variants, workers=1)
        parallel = scan(SERIES, variants, workers=3)
        self.assertEqual([r.key for r in sequential], [r.key for r in parallel])
        for a, b in zip(sequential, parallel):
            self.assertAlmostEqual(a.stats["total_r"], b.stats["total_r"], places=6)

    def test_rows_are_sorted_by_total_r(self):
        rows = scan(SERIES, build_variants(families=["Donchian"]), workers=1)
        totals = [r.stats["total_r"] for r in rows]
        self.assertEqual(totals, sorted(totals, reverse=True))

    def test_out_of_sample_trades_are_a_subset(self):
        rows = scan(SERIES, build_variants(families=["Donchian"]), oos_fraction=0.3, workers=1)
        for row in rows:
            self.assertLessEqual(row.oos.get("trades", 0), row.stats["trades"])

    def test_costs_reduce_performance(self):
        variants = build_variants(families=["Donchian"])
        free = scan(SERIES, variants, costs=Costs(0, 0, 0), workers=1)
        charged = scan(SERIES, variants, costs=Costs(1.0, 0.2, 10.0), workers=1)
        free_r = sum(r.stats["total_r"] for r in free)
        charged_r = sum(r.stats["total_r"] for r in charged)
        self.assertLess(charged_r, free_r)

    def test_long_only_produces_no_short_trades(self):
        rows = scan(SERIES, build_variants(families=["Donchian"]), allow_short=False, workers=1)
        for row in rows:
            for trade in row.last_trades:
                self.assertEqual(trade["side"], "LONG")

    def test_signal_now_matches_the_last_signal(self):
        variants = build_variants(families=["EMA stack"])
        cache = Cache(SERIES)
        rows = scan(SERIES, variants, workers=1)
        by_key = {v.key: v for v in variants}
        for row in rows:
            signals = by_key[row.key].signals(SERIES, cache)
            expected = next((s for s in reversed(signals) if s), 0)
            self.assertEqual(row.signal_now, expected)


class TestScoring(unittest.TestCase):
    def test_too_few_trades_scores_zero(self):
        stats = {"trades": 5, "expectancy_r": 1.0, "profit_factor": 3.0, "total_r": 5.0,
                 "max_dd_r": 1.0, "sharpe": 2.0}
        self.assertEqual(robustness_score(stats, {}, min_trades=20), 0.0)

    def test_negative_expectancy_scores_zero(self):
        stats = {"trades": 100, "expectancy_r": -0.1, "profit_factor": 0.8, "total_r": -10.0,
                 "max_dd_r": 12.0, "sharpe": -0.5}
        self.assertEqual(robustness_score(stats, {}, min_trades=20), 0.0)

    def test_out_of_sample_collapse_is_penalised(self):
        stats = {"trades": 80, "expectancy_r": 0.25, "profit_factor": 1.8, "total_r": 20.0,
                 "max_dd_r": 5.0, "sharpe": 1.2}
        holds = robustness_score(stats, {"trades": 25, "expectancy_r": 0.22}, 20)
        collapses = robustness_score(stats, {"trades": 25, "expectancy_r": -0.45}, 20)
        self.assertGreater(holds, collapses)
        self.assertLessEqual(holds, 100.0)


class TestReport(unittest.TestCase):
    def setUp(self):
        self.rows = scan(SERIES, build_variants(families=["Donchian", "RSI pullback"]), workers=1)
        self.html = build_html(series=SERIES, rows=self.rows, costs=Costs(), risk=100.0,
                               min_trades=10, oos_fraction=0.3)

    def test_html_is_self_contained(self):
        self.assertTrue(self.html.startswith("<!doctype html>"))
        self.assertIn("<title>", self.html)
        self.assertNotIn("http://", self.html.split("<script>")[0])
        self.assertIn("dati sintetici", self.html.lower())

    def test_embedded_payload_is_valid_json(self):
        blob = self.html.split("const ROWS = ", 1)[1].split(";\nconst MIN_TRADES", 1)[0]
        payload = json.loads(blob)
        self.assertEqual(len(payload), len(self.rows))
        self.assertIn("equity_curve", payload[0])

    def test_summary_counts_add_up(self):
        info = summarize(self.rows, min_trades=10)
        self.assertEqual(info["variants"], len(self.rows))
        self.assertLessEqual(info["profitable"], info["eligible"])
        self.assertTrue(set(info["by_family"]) <= {"Donchian", "RSI pullback"})


if __name__ == "__main__":
    unittest.main()
