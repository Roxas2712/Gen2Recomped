"""An early successful Lua exit must not silently truncate a multi-suite run."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import atexit
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import qa_storage as qa


@unittest.skipUnless(os.environ.get('RETRO_QA_LUA_LIBRARY'), 'Bundled LuaJIT library required')
class LuaBatchExitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        qa._storage = qa.Storage(ROOT)
        atexit.register(qa._storage.close, collect=False)
        for source in [ROOT, Path(os.environ['RETRO_QA_LUA_LIBRARY'])]:
            qa.qa_source(source)
        cls.output = ROOT / '.local/qa/lua-batch-exit-20261029'
        qa.qa_cache(cls.output)
        cls.output.mkdir(parents=True, exist_ok=True)

    def run_pair(self, first, keep_going=False):
        with tempfile.TemporaryDirectory(dir=self.output) as directory:
            one, two = [Path(directory) / name for name in ['première.lua', 'second.lua']]
            one.write_text(first)
            two.write_text('assert(_G.firstSuiteState==nil,"VM globals leaked");print("SECOND_EXECUTED")')
            return qa.qa_run([sys.executable, str(ROOT / 'tools/run_lua_batch.py'),
                              '--suite', str(one), '--suite', str(two)] +
                             (['--keep-going'] if keep_going else []), cwd=ROOT,
                             env=os.environ.copy(), capture_output=True, text=True)

    def test_successful_exit_runs_remaining_isolated_suite(self):
        result = self.run_pair('firstSuiteState=true;os.exit(0)')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('SECOND_EXECUTED', result.stdout)
        self.assertIn('Lua suites completed: 2/2', result.stdout)

    def test_failure_exit_stops_without_success_summary(self):
        result = self.run_pair('os.exit(1)')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SECOND_EXECUTED', result.stdout)
        self.assertNotIn('Lua suites completed:', result.stdout)

    def test_assertion_failure_cannot_be_reported_as_success(self):
        result = self.run_pair('error("intentional fixture failure")')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SECOND_EXECUTED', result.stdout)

    def test_literal_exit_text_is_an_error(self):
        result = self.run_pair('error("__RETRO_QA_SUITE_EXIT__",0)')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('SECOND_EXECUTED', result.stdout)

    def test_keep_going_preserves_failed_exit_and_completion_count(self):
        result = self.run_pair('os.exit(1)', keep_going=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SECOND_EXECUTED', result.stdout)
        self.assertIn('Lua suites completed: 1/2', result.stdout)
        self.assertIn('FAILED Lua suite:', result.stderr)


if __name__ == '__main__':
    unittest.main()
