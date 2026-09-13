import unittest
from datetime import datetime

from xauusd_scanner.data import infer_timeframe, parse_ohlc, parse_time, synthetic


class TestParsing(unittest.TestCase):
    def test_standard_csv(self):
        text = "Date,Open,High,Low,Close,Volume\n2024-01-02,2062.5,2075.1,2055.0,2070.3,1200\n2024-01-03,2070.3,2080.0,2060.0,2065.0,900\n"
        s = parse_ohlc(text)
        self.assertEqual(len(s), 2)
        self.assertAlmostEqual(s.high[0], 2075.1)
        self.assertAlmostEqual(s.volume[1], 900)

    def test_mt5_tab_export_with_split_date_and_time(self):
        text = "<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\n" \
               "2024.03.01\t00:00:00\t2044.1\t2050.0\t2040.0\t2048.2\t11\n" \
               "2024.03.01\t04:00:00\t2048.2\t2060.0\t2047.0\t2058.0\t9\n"
        s = parse_ohlc(text)
        self.assertEqual(len(s), 2)
        self.assertEqual(s.time[1], datetime(2024, 3, 1, 4, 0))

    def test_semicolon_and_comma_decimals(self):
        text = "Data;Apertura;Massimo;Minimo;Chiusura\n02/01/2024;2062,5;2075,1;2055,0;2070,3\n03/01/2024;2070,3;2080,0;2060,0;2065,0\n"
        s = parse_ohlc(text)
        self.assertAlmostEqual(s.open[0], 2062.5)
        self.assertEqual(s.time[0], datetime(2024, 1, 2))

    def test_headerless_csv(self):
        text = "2024-01-02,2062.5,2075.1,2055.0,2070.3\n2024-01-03,2070.3,2080.0,2060.0,2065.0\n"
        s = parse_ohlc(text)
        self.assertEqual(len(s), 2)

    def test_rows_are_sorted_by_time(self):
        text = "Date,Open,High,Low,Close\n2024-01-05,3,4,2,3\n2024-01-02,1,2,0.5,1\n"
        s = parse_ohlc(text)
        self.assertEqual(s.time, sorted(s.time))
        self.assertAlmostEqual(s.close[0], 1)

    def test_broken_rows_are_skipped_not_fatal(self):
        text = "Date,Open,High,Low,Close\n2024-01-02,1,2,0.5,1\nqualcosa,di,rotto\n2024-01-03,1,2,0.5,1\n"
        self.assertEqual(len(parse_ohlc(text)), 2)

    def test_empty_input_raises(self):
        with self.assertRaises(ValueError):
            parse_ohlc("")

    def test_epoch_timestamps(self):
        self.assertEqual(parse_time("1704153600").year, 2024)
        self.assertEqual(parse_time("1704153600000").year, 2024)

    def test_unknown_time_format_raises(self):
        with self.assertRaises(ValueError):
            parse_time("ieri pomeriggio")


class TestTimeframe(unittest.TestCase):
    def test_infers_daily_and_hourly(self):
        daily = [datetime(2024, 1, d) for d in range(1, 12)]
        self.assertEqual(infer_timeframe(daily), "D1")
        hourly = [datetime(2024, 1, 1, h) for h in range(12)]
        self.assertEqual(infer_timeframe(hourly), "H1")


class TestSynthetic(unittest.TestCase):
    def test_is_deterministic(self):
        a, b = synthetic(bars=300, seed=42), synthetic(bars=300, seed=42)
        self.assertEqual(a.close, b.close)
        self.assertNotEqual(synthetic(bars=300, seed=1).close, a.close)

    def test_ohlc_is_internally_consistent(self):
        s = synthetic(bars=800, seed=5)
        for i in range(len(s)):
            self.assertLessEqual(s.low[i], min(s.open[i], s.close[i]))
            self.assertGreaterEqual(s.high[i], max(s.open[i], s.close[i]))
        self.assertEqual(s.validate(), [])

    def test_daily_series_skips_weekends(self):
        s = synthetic(bars=200, seed=9, timeframe="D1")
        self.assertTrue(all(t.weekday() < 5 for t in s.time))

    def test_slice_filters_by_date(self):
        s = synthetic(bars=500, seed=3)
        cut = s.time[100]
        sliced = s.slice(start=cut)
        self.assertEqual(sliced.time[0], cut)
        self.assertEqual(len(sliced), len(s) - 100)


class TestValidation(unittest.TestCase):
    def test_reports_inconsistent_bars(self):
        text = "Date,Open,High,Low,Close\n" + "".join(
            f"2024-01-{d:02d},10,11,9,10\n" for d in range(1, 10)
        )
        s = parse_ohlc(text)
        s.high[3] = 1.0  # high sotto il low: incoerente
        problems = s.validate()
        self.assertTrue(any("incoerente" in p for p in problems))
        self.assertTrue(any("troppo pochi" in p for p in problems))


if __name__ == "__main__":
    unittest.main()
