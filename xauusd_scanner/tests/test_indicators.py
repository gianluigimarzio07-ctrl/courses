import unittest

from xauusd_scanner import indicators as ind


class TestMovingAverages(unittest.TestCase):
    def test_sma_warmup_and_values(self):
        out = ind.sma([1, 2, 3, 4, 5], 3)
        self.assertEqual(out[:2], [None, None])
        self.assertEqual(out[2:], [2.0, 3.0, 4.0])

    def test_ema_seeds_with_sma(self):
        values = [1, 2, 3, 4, 5]
        out = ind.ema(values, 3)
        self.assertIsNone(out[1])
        self.assertAlmostEqual(out[2], 2.0)          # seed = SMA(1,2,3)
        self.assertAlmostEqual(out[3], 4 * 0.5 + 2 * 0.5)
        self.assertAlmostEqual(out[4], 5 * 0.5 + out[3] * 0.5)

    def test_rma_is_wilder(self):
        out = ind.rma([2, 4, 6, 8], 2)
        self.assertAlmostEqual(out[1], 3.0)
        self.assertAlmostEqual(out[2], (3.0 * 1 + 6) / 2)

    def test_shorter_than_period_is_all_none(self):
        self.assertEqual(ind.ema([1, 2], 5), [None, None])
        self.assertEqual(ind.sma([1, 2], 5), [None, None])


class TestVolatility(unittest.TestCase):
    def test_true_range_uses_previous_close(self):
        tr = ind.true_range([10, 12], [8, 11], [9, 11.5])
        self.assertAlmostEqual(tr[0], 2.0)
        self.assertAlmostEqual(tr[1], 3.0)  # max(1, |12-9|, |11-9|)

    def test_atr_hand_computed(self):
        atr = ind.atr([2, 3, 4], [1, 2, 3], [1.5, 2.5, 3.5], 2)
        self.assertIsNone(atr[0])
        self.assertAlmostEqual(atr[1], 1.25)
        self.assertAlmostEqual(atr[2], 1.375)

    def test_stdev_matches_population_formula(self):
        out = ind.stdev([2, 4, 4, 4, 5, 5, 7, 9], 8)
        self.assertAlmostEqual(out[-1], 2.0)


class TestOscillators(unittest.TestCase):
    def test_rsi_is_100_when_only_gains(self):
        out = ind.rsi(list(range(1, 30)), 14)
        self.assertAlmostEqual(out[-1], 100.0)

    def test_rsi_is_zero_when_only_losses(self):
        out = ind.rsi(list(range(40, 10, -1)), 14)
        self.assertAlmostEqual(out[-1], 0.0)

    def test_rsi_bounds(self):
        import random

        rng = random.Random(3)
        values = [100.0]
        for _ in range(300):
            values.append(values[-1] * (1 + rng.gauss(0, 0.01)))
        for v in ind.rsi(values, 14):
            if v is not None:
                self.assertGreaterEqual(v, 0.0)
                self.assertLessEqual(v, 100.0)

    def test_adx_in_range_and_high_on_a_clean_trend(self):
        n = 120
        high = [100 + i for i in range(n)]
        low = [99 + i for i in range(n)]
        close = [99.5 + i for i in range(n)]
        out = ind.adx(high, low, close, 14)
        self.assertIsNotNone(out[-1])
        self.assertGreater(out[-1], 50.0)
        self.assertLessEqual(out[-1], 100.0)


class TestChannels(unittest.TestCase):
    def test_donchian_excludes_current_bar(self):
        high = [1, 2, 3, 10]
        low = [1, 2, 3, 0]
        upper, lower = ind.donchian(high, low, 3)
        self.assertEqual(upper[3], 3)   # non include il 10 del bar corrente
        self.assertEqual(lower[3], 1)
        self.assertIsNone(upper[2])

    def test_bollinger_bands_straddle_the_mean(self):
        values = [10, 11, 12, 11, 10, 9, 10, 11, 12, 13] * 3
        upper, mid, lower = ind.bollinger(values, 20, 2.0)
        i = len(values) - 1
        self.assertLess(lower[i], mid[i])
        self.assertLess(mid[i], upper[i])

    def test_percent_rank_extremes(self):
        values = [1, 2, 3, 4, 5]
        out = ind.percent_rank(values, 5)
        self.assertAlmostEqual(out[-1], 80.0)  # 4 valori su 5 sono inferiori


class TestNoLookahead(unittest.TestCase):
    """Modificare il futuro non deve cambiare i valori passati: e' la garanzia
    che nessun indicatore guarda avanti."""

    def test_indicators_are_causal(self):
        base = [100 + (i % 7) - (i % 3) for i in range(200)]
        tampered = list(base)
        tampered[150:] = [500.0] * 50
        cut = 150
        pairs = [
            (ind.ema(base, 20), ind.ema(tampered, 20)),
            (ind.sma(base, 20), ind.sma(tampered, 20)),
            (ind.rsi(base, 14), ind.rsi(tampered, 14)),
            (ind.roc(base, 10), ind.roc(tampered, 10)),
        ]
        for original, modified in pairs:
            self.assertEqual(original[:cut], modified[:cut])


if __name__ == "__main__":
    unittest.main()
