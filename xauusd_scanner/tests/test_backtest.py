import unittest
from datetime import datetime, timedelta

from xauusd_scanner.backtest import Costs, ExitRules, run_backtest
from xauusd_scanner.data import Series

NO_COST = Costs(spread=0.0, slippage=0.0, commission_per_lot=0.0)


def make_series(bars):
    """``bars`` = lista di tuple (open, high, low, close)."""
    s = Series("TEST", "D1")
    t = datetime(2024, 1, 1)
    for o, h, l, c in bars:
        s.time.append(t)
        s.open.append(o)
        s.high.append(h)
        s.low.append(l)
        s.close.append(c)
        s.volume.append(0.0)
        t += timedelta(days=1)
    return s


class TestEntryMechanics(unittest.TestCase):
    def test_entry_is_next_bar_open_not_signal_close(self):
        series = make_series([(100, 101, 99, 100)] * 6)
        signals = [0, 1, 0, 0, 0, 0]
        atr = [1.0] * 6
        res = run_backtest(series, signals, atr, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        self.assertEqual(len(res.trades), 1)
        trade = res.trades[0]
        self.assertEqual(trade.entry_index, 2)          # segnale su 1 -> fill su 2
        self.assertAlmostEqual(trade.entry_price, 100.0)
        self.assertAlmostEqual(trade.stop_price, 98.0)  # 2 * ATR

    def test_size_makes_the_stop_cost_exactly_one_r(self):
        series = make_series([(100, 101, 99, 100), (100, 101, 99, 100), (100, 101, 90, 95), (95, 96, 94, 95)])
        res = run_backtest(series, [1, 0, 0, 0], [2.0] * 4, ExitRules(stop_atr=1.5, target_r=3.0),
                           NO_COST, risk_per_trade=250.0)
        trade = res.trades[0]
        self.assertAlmostEqual(trade.size, 250.0 / 3.0)  # 1.5 * ATR(2.0) = 3 dollari di stop
        self.assertAlmostEqual(trade.r_multiple, -1.0, places=6)
        self.assertAlmostEqual(trade.pnl, -250.0, places=6)

    def test_no_entry_without_atr(self):
        series = make_series([(100, 101, 99, 100)] * 4)
        res = run_backtest(series, [1, 1, 1, 1], [None, None, None, None], ExitRules(), NO_COST)
        self.assertEqual(res.trades, [])

    def test_short_is_skipped_when_long_only(self):
        series = make_series([(100, 101, 99, 100)] * 5)
        res = run_backtest(series, [-1, 0, 0, 0, 0], [1.0] * 5, ExitRules(), NO_COST, allow_short=False)
        self.assertEqual(res.trades, [])


class TestExits(unittest.TestCase):
    def test_target_pays_exactly_the_r_multiple(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (100, 106, 99, 105),   # target a 104 (2R su stop 2.0)
        ])
        res = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        trade = res.trades[0]
        self.assertEqual(trade.reason, "target")
        self.assertAlmostEqual(trade.exit_price, 104.0)
        self.assertAlmostEqual(trade.r_multiple, 2.0, places=6)

    def test_stop_wins_when_stop_and_target_are_in_the_same_bar(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (100, 110, 90, 109),  # tocca sia 104 sia 98
        ])
        res = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        trade = res.trades[0]
        self.assertEqual(trade.reason, "stop")
        self.assertAlmostEqual(trade.r_multiple, -1.0, places=6)

    def test_gap_below_stop_fills_at_the_open(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (90, 92, 88, 91),  # apre a 90, ben sotto lo stop a 98
        ])
        res = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        trade = res.trades[0]
        self.assertEqual(trade.reason, "gap")
        self.assertAlmostEqual(trade.exit_price, 90.0)
        self.assertLess(trade.r_multiple, -1.0)  # la perdita supera 1R: e' il rischio dei gap

    def test_time_stop_closes_at_close(self):
        series = make_series([(100, 100.5, 99.5, 100)] * 8)
        res = run_backtest(series, [1] + [0] * 7, [1.0] * 8, ExitRules(stop_atr=5.0, target_r=9.0, time_stop=3), NO_COST)
        trade = res.trades[0]
        self.assertEqual(trade.reason, "time")
        self.assertEqual(trade.bars_held, 3)

    def test_breakeven_stop_prevents_a_full_loss(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (100, 103, 100, 102),  # +1R raggiunto (stop 2.0 -> 1R = 2 dollari)
            (102, 102, 95, 96),    # ritorno sotto: esce a 100, non a 98
        ])
        res = run_backtest(series, [1, 0, 0, 0], [1.0] * 4,
                           ExitRules(stop_atr=2.0, target_r=5.0, breakeven_at_r=1.0), NO_COST)
        trade = res.trades[0]
        self.assertAlmostEqual(trade.exit_price, 100.0)
        self.assertAlmostEqual(trade.r_multiple, 0.0, places=6)

    def test_trailing_stop_locks_in_profit(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (100, 110, 100, 110),  # trail a 110 - 2*ATR = 108
            (110, 111, 100, 101),  # torna giu': esce a 108
        ])
        res = run_backtest(series, [1, 0, 0, 0], [1.0] * 4,
                           ExitRules(stop_atr=2.0, target_r=None, trail_atr=2.0), NO_COST)
        trade = res.trades[0]
        self.assertAlmostEqual(trade.exit_price, 108.0)
        self.assertAlmostEqual(trade.r_multiple, 4.0, places=6)

    def test_flip_exit_closes_on_opposite_signal(self):
        series = make_series([(100, 101, 99, 100)] * 6)
        res = run_backtest(series, [1, 0, -1, 0, 0, 0], [1.0] * 6,
                           ExitRules(stop_atr=5.0, target_r=None, exit_on_flip=True), NO_COST)
        self.assertEqual(res.trades[0].reason, "flip")

    def test_open_position_is_closed_at_the_last_bar(self):
        series = make_series([(100, 101, 99, 100)] * 5)
        res = run_backtest(series, [1, 0, 0, 0, 0], [1.0] * 5, ExitRules(stop_atr=9.0, target_r=9.0), NO_COST)
        self.assertEqual(res.trades[0].reason, "eod")


class TestShortSide(unittest.TestCase):
    def test_short_target_and_stop_are_mirrored(self):
        series = make_series([
            (100, 100, 100, 100),
            (100, 100, 100, 100),
            (100, 101, 94, 95),  # target short a 96
        ])
        res = run_backtest(series, [-1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        trade = res.trades[0]
        self.assertEqual(trade.side, -1)
        self.assertAlmostEqual(trade.stop_price, 102.0)
        self.assertAlmostEqual(trade.exit_price, 96.0)
        self.assertAlmostEqual(trade.r_multiple, 2.0, places=6)


class TestCosts(unittest.TestCase):
    def test_costs_make_the_result_worse(self):
        series = make_series([(100, 100, 100, 100), (100, 100, 100, 100), (100, 106, 99, 105)])
        free = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        charged = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=2.0),
                               Costs(spread=0.4, slippage=0.1, commission_per_lot=7.0))
        self.assertLess(charged.trades[0].r_multiple, free.trades[0].r_multiple)
        self.assertGreater(charged.trades[0].entry_price, free.trades[0].entry_price)

    def test_commission_scales_with_position_size(self):
        series = make_series([(100, 100, 100, 100), (100, 100, 100, 100), (100, 100, 100, 100)])
        costs = Costs(spread=0.0, slippage=0.0, commission_per_lot=10.0, ounces_per_lot=100.0)
        res = run_backtest(series, [1, 0, 0], [1.0] * 3, ExitRules(stop_atr=2.0, target_r=9.0),
                           costs, risk_per_trade=200.0)
        trade = res.trades[0]
        self.assertAlmostEqual(trade.size, 100.0)          # 200 / (2 * ATR 1.0)
        self.assertAlmostEqual(trade.pnl, -10.0, places=6)  # solo commissioni


class TestStats(unittest.TestCase):
    def test_stats_aggregate_correctly(self):
        bars = [(100, 100, 100, 100), (100, 100, 100, 100), (100, 106, 99, 105),
                (105, 105, 105, 105), (105, 106, 98, 99), (99, 99, 99, 99)]
        series = make_series(bars)
        res = run_backtest(series, [1, 0, 0, 1, 0, 0], [1.0] * 6,
                           ExitRules(stop_atr=2.0, target_r=2.0), NO_COST)
        stats = res.stats
        self.assertEqual(stats["trades"], 2)
        self.assertAlmostEqual(stats["win_rate"], 50.0)
        self.assertAlmostEqual(stats["total_r"], 1.0, places=6)
        self.assertAlmostEqual(stats["profit_factor"], 2.0, places=6)
        self.assertAlmostEqual(stats["expectancy_r"], 0.5, places=6)

    def test_empty_run_has_zeroed_stats(self):
        series = make_series([(100, 101, 99, 100)] * 5)
        res = run_backtest(series, [0] * 5, [1.0] * 5, ExitRules(), NO_COST)
        self.assertEqual(res.stats["trades"], 0)
        self.assertEqual(res.stats["total_r"], 0.0)

    def test_mismatched_signal_length_raises(self):
        series = make_series([(100, 101, 99, 100)] * 3)
        with self.assertRaises(ValueError):
            run_backtest(series, [0, 0], [1.0] * 3, ExitRules(), NO_COST)

    def test_only_one_position_at_a_time(self):
        series = make_series([(100, 100.2, 99.8, 100)] * 30)
        res = run_backtest(series, [1] * 30, [1.0] * 30, ExitRules(stop_atr=3.0, target_r=3.0), NO_COST)
        for a, b in zip(res.trades, res.trades[1:]):
            self.assertLessEqual(a.exit_index, b.entry_index)


if __name__ == "__main__":
    unittest.main()
