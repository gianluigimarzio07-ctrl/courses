import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout

from xauusd_scanner.cli import main
from xauusd_scanner.data import synthetic

CSV_HEADER = "Date,Open,High,Low,Close,Volume\n"


def write_demo_csv(path, bars=600):
    s = synthetic(bars=bars, seed=4)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(CSV_HEADER)
        for i in range(len(s)):
            fh.write(f"{s.time[i]:%Y-%m-%d},{s.open[i]},{s.high[i]},{s.low[i]},{s.close[i]},{int(s.volume[i])}\n")
    return path


class TestCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def run_cli(self, argv):
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            code = main(argv)
        return code, buffer.getvalue()

    def test_list_families(self):
        code, out = self.run_cli(["--list-families"])
        self.assertEqual(code, 0)
        self.assertIn("Donchian", out)

    def test_demo_run_writes_report(self):
        report = os.path.join(self.tmp.name, "r.html")
        code, out = self.run_cli(["--demo", "--bars", "700", "--workers", "1",
                                  "--families", "Donchian", "--min-trades", "5",
                                  "--out", report, "--top", "3"])
        self.assertEqual(code, 0)
        self.assertTrue(os.path.exists(report))
        self.assertGreater(os.path.getsize(report), 5000)
        self.assertIn("heatmap:", out)

    def test_csv_input_and_json_export(self):
        csv_path = write_demo_csv(os.path.join(self.tmp.name, "x.csv"))
        json_path = os.path.join(self.tmp.name, "out.json")
        code, _ = self.run_cli(["--csv", csv_path, "--workers", "1", "--families", "EMA cross",
                                "--json", json_path, "--no-report", "--min-trades", "5"])
        self.assertEqual(code, 0)
        with open(json_path, encoding="utf-8") as fh:
            payload = json.load(fh)
        self.assertIn("summary", payload)
        self.assertGreater(len(payload["rows"]), 0)

    def test_signals_mode(self):
        code, out = self.run_cli(["--demo", "--bars", "700", "--workers", "1",
                                  "--families", "EMA stack", "--signals", "--no-report",
                                  "--min-trades", "1"])
        self.assertEqual(code, 0)
        self.assertTrue("LONG" in out or "SHORT" in out or "nessun segnale" in out)

    def test_missing_file_exits_with_error_code(self):
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            code = main(["--csv", os.path.join(self.tmp.name, "non-esiste.csv"), "--no-report"])
        self.assertEqual(code, 2)

    def test_too_short_history_is_refused(self):
        path = write_demo_csv(os.path.join(self.tmp.name, "corto.csv"), bars=60)
        code, _ = self.run_cli(["--csv", path, "--no-report"])
        self.assertEqual(code, 2)

    def test_date_filters_narrow_the_series(self):
        csv_path = write_demo_csv(os.path.join(self.tmp.name, "x.csv"), bars=900)
        code, out = self.run_cli(["--csv", csv_path, "--from", "2016-01-01", "--to", "2017-01-01",
                                  "--families", "Donchian", "--workers", "1", "--no-report",
                                  "--min-trades", "1"])
        self.assertEqual(code, 0)
        self.assertIn("2016-01", out)


if __name__ == "__main__":
    unittest.main()
