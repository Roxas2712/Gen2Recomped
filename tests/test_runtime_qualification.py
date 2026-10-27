import argparse
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
run = subprocess.run
qa_cache = None
if os.name != "nt" and not os.getenv("GITHUB_ACTIONS"):
    sys.path.insert(0, str(ROOT / "tools"))
    from qa_storage import qa_cache, qa_run, qa_source
    for source in (ROOT, Path(sys.executable), Path(__file__).resolve()):
        qa_source(source)
    run = qa_run

spec = importlib.util.spec_from_file_location(
    "runtime_qualification", ROOT / "tools/runtime-upvalue-check/qualify.py")
Q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(Q)


class QualificationLogs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if qa_cache is not None:
            # Local storage housekeeping runs before the first child. Keep it
            # outside the deliberately short timeout regression below.
            run([sys.executable, "-c", "pass"], check=True, timeout=60)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="runtime-qualification-")
        self.addCleanup(self.tmp.cleanup)
        self.output = Path(self.tmp.name)
        if qa_cache is not None:
            qa_cache(self.output)
        self.console = io.StringIO()

    def command(self, script, timeout=10):
        with contextlib.redirect_stdout(self.console):
            return Q.run_logged(self.output, "engine", [sys.executable, "-u", "-c", script],
                                self.output, timeout=timeout, run=run)

    def test_success_preserves_stdout_and_stderr(self):
        text = self.command("import sys; print('engine: 572/572 suites passed'); "
                            "print('diagnostic', file=sys.stderr)")
        self.assertIn("engine: 572/572 suites passed", text)
        self.assertIn("diagnostic", text)
        self.assertEqual((self.output / "engine.log").read_text(), text)

    def test_failed_command_keeps_output_and_fails(self):
        with self.assertRaises(subprocess.CalledProcessError) as failure:
            self.command("import sys; print('failure before exit'); sys.exit(7)")
        self.assertEqual(failure.exception.returncode, 7)
        self.assertIn("failure before exit", (self.output / "engine.log").read_text())
        self.assertIn("failure before exit", self.console.getvalue())

    def test_timeout_keeps_partial_output_and_still_fails(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.command("import sys,time; print('completed earlier suite', flush=True); "
                         "print('pending suite', file=sys.stderr, flush=True); time.sleep(60)",
                         timeout=3)
        log = (self.output / "engine.log").read_text()
        self.assertIn("completed earlier suite", log)
        self.assertIn("pending suite", log)
        self.assertIn("pending suite", self.console.getvalue())

    def test_diagnostic_bytes_do_not_mask_command_failure(self):
        with self.assertRaises(subprocess.CalledProcessError) as failure:
            self.command("import sys; sys.stdout.buffer.write(b'diagnostic: \\xff'); sys.exit(8)")
        self.assertEqual(failure.exception.returncode, 8)
        self.assertEqual((self.output / "engine.log").read_bytes(), b"diagnostic: \xff")

    def test_engine_budget_must_be_positive(self):
        self.assertEqual(Q.positive_seconds("1800"), 1800)
        for value in ("0", "-1"):
            with self.subTest(value=value), self.assertRaises(argparse.ArgumentTypeError):
                Q.positive_seconds(value)


if __name__ == "__main__":
    unittest.main()
