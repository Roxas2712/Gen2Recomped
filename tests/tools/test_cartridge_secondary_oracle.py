"""The cartridge oracle must correct only its documented reference gaps."""
from copy import deepcopy
from pathlib import Path
from contextlib import redirect_stdout
import io
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools/enemy-action-contract-check"))
from cartridge_secondary import expected_observations
from check import same_observations
import check as CHECK


def row(case="ordinary", effect="poison", chance=30, word=30, execution=False):
    battler = {"hp": 987, "status": False, "stages": [0] * 7,
               "flinched": False, "sub": 0, "confusion": 0}
    draws = [{"lo": 0, "hi": 99, "word": word, "value": word}]
    if execution:
        draws.insert(0, {"lo": 85, "hi": 100, "word": word, "value": 99})
    return {"case": case, "effect": effect, "chance": chance, "word": word,
            "user": 0, "result": "execution" if execution else False,
            "draws": draws, "target": deepcopy(battler),
            "attacker": deepcopy(battler), "events": []}


class CartridgeSecondaryOracle(unittest.TestCase):
    def test_emerald_boundary_rejects_the_old_inclusive_result(self):
        for execution in (False, True):
            mode = "secondary_execution" if execution else "secondary"
            control = row(chance=0, word=99, execution=execution)
            old = row(execution=execution)
            old["target"]["status"] = "PSN"
            old["events"] = [{"target": "P1", "sourceIsUser": True, "status": "PSN"}]
            if not execution:
                old["result"] = True
            raw = [control, old]
            original = deepcopy(raw)
            expected, audit = expected_observations(raw, "emerald", mode)
            self.assertFalse(same_observations(expected, raw))
            self.assertIs(expected[1]["target"]["status"], False)
            self.assertEqual(expected[1]["events"], [])
            self.assertEqual(expected[1]["result"], "execution" if execution else False)
            self.assertEqual(audit[0]["rules"], ["emerald-strict-chance-boundary"])
            self.assertEqual(raw, original, "the pinned observation is never patched")
            frlg, audit = expected_observations(raw, "firered", mode)
            self.assertTrue(same_observations(frlg, raw))
            self.assertEqual(audit, [])

    def test_zero_chance_and_serene_grace_use_their_exact_boundaries(self):
        for case, chance, word in (("ordinary", 0, 0), ("serene-grace", 30, 60)):
            control = row(case=case, chance=0, word=99)
            old = row(case=case, chance=chance, word=word)
            old["target"]["status"], old["result"] = "PSN", True
            expected, audit = expected_observations([control, old], "emerald", "secondary")
            self.assertIs(expected[1]["result"], False)
            self.assertIs(expected[1]["target"]["status"], False)
            self.assertEqual(len(audit), 1)

    def test_nonboundary_results_remain_unmodified(self):
        old = row(word=31)
        expected, audit = expected_observations([old], "emerald", "secondary")
        self.assertTrue(same_observations(expected, [old]))
        self.assertEqual(audit, [])

    def test_confusion_effect_draw_is_removed_but_damage_and_chance_survive(self):
        control = row(effect="confusion", chance=0, word=99, execution=True)
        old = row(effect="confusion", execution=True)
        old["draws"].append({"lo": 0, "hi": 3, "word": 30, "value": 2})
        old["target"]["confusion"] = 4
        old["target"]["hp"], old["target"]["sub"] = 17, 7
        expected, _ = expected_observations([control, old], "emerald", "secondary_execution")
        actual = expected[1]
        self.assertEqual(actual["draws"], old["draws"][:2])
        self.assertEqual(actual["target"]["confusion"], 0)
        self.assertEqual((actual["target"]["hp"], actual["target"]["sub"]), (17, 7))

    def test_probability_cannot_disable_stat_protection(self):
        for case in ("certain-mist", "certain-clear-body", "mist", "clear-body", "white-smoke"):
            for version in ("firered", "emerald"):
                for execution in (False, True):
                    mode = "secondary_execution" if execution else "secondary"
                    old = row(case=case, effect="speed-down", chance=100, execution=execution)
                    old["target"]["stages"][2] = -1
                    if not execution:
                        old["result"] = True
                    expected, audit = expected_observations([old], version, mode)
                    self.assertFalse(same_observations(expected, [old]))
                    self.assertEqual(expected[0]["target"]["stages"][2], 0)
                    self.assertEqual(expected[0]["result"], "execution" if execution else False)
                    self.assertEqual(len(audit), 1)

    def test_own_stat_increases_remain_untouched(self):
        old = row(case="clear-body", effect="attack-up", chance=100)
        old["attacker"]["stages"][0], old["result"] = 1, True
        expected, audit = expected_observations([old], "firered", "secondary")
        self.assertTrue(same_observations(expected, [old]))
        self.assertEqual(audit, [])

    def test_unrelated_drift_is_still_a_failure(self):
        old = row(case="clear-body", effect="speed-down", chance=100)
        old["target"]["stages"][2], old["result"] = -1, True
        expected, _ = expected_observations([old], "firered", "secondary")
        for mutate in (lambda x: x[0]["target"].update(hp=986),
                       lambda x: x[0]["target"].update(sub=1),
                       lambda x: x[0]["attacker"]["stages"].__setitem__(0, 1),
                       lambda x: x[0]["draws"][0].update(value=31),
                       lambda x: x[0].update(user=1),
                       lambda x: x[0].update(result=0)):
            changed = deepcopy(expected)
            mutate(changed)
            self.assertFalse(same_observations(expected, changed))

    def test_missing_controls_duplicates_and_unexpected_states_fail_closed(self):
        with self.assertRaises(ValueError):
            expected_observations([row()], "emerald", "secondary")
        with self.assertRaises(ValueError):
            expected_observations([row(), row()], "firered", "secondary")
        old = row(case="clear-body", effect="speed-down", chance=100)
        old["target"]["stages"][2] = -2
        with self.assertRaises(ValueError):
            expected_observations([old], "firered", "secondary")
        old = row()
        old["draws"].append(deepcopy(old["draws"][0]))
        with self.assertRaises(ValueError):
            expected_observations([row(chance=0, word=99), old], "emerald", "secondary")

    def test_other_contract_modes_are_not_reinterpreted(self):
        with self.assertRaises(ValueError):
            expected_observations([], "firered", "arguments")

    def test_cli_preserves_raw_difference_and_names_the_cartridge_oracle(self):
        old = row(case="clear-body", effect="speed-down", chance=100)
        old["target"]["stages"][2], old["result"] = -1, True
        expected, _ = expected_observations([old], "firered", "secondary")
        root = Path(CHECK.__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "reference"
            source.mkdir()
            report = Path(directory) / "report.json"

            def git(path, *args):
                return CHECK.GEN1_REF if args == ("rev-parse", "HEAD") else ""

            def worker(command, **kwargs):
                data = [old] if command[3] == "gen1" else expected
                return subprocess.CompletedProcess(command, 0,
                    "ENEMY_ACTION_OBSERVATIONS " + json.dumps(data) + "\n", "")

            argv = [str(CHECK.__file__), "--gen1", str(source), "--gen2", str(root),
                    "--mode", "secondary", "--report", str(report)]
            with patch.object(CHECK, "git", side_effect=git), \
                    patch.object(CHECK.subprocess, "run", side_effect=worker), \
                    patch.object(sys, "argv", argv), redirect_stdout(io.StringIO()) as output:
                code = CHECK.main()
            result = json.loads(report.read_text())
            self.assertEqual(code, 0)
            self.assertTrue(result["passed"])
            for comparison in result["comparisons"]:
                self.assertIs(comparison["equal"], False)
                self.assertIs(comparison["accepted"], True)
                self.assertEqual(comparison["oracle"], "cartridge-secondary-v1")
                self.assertEqual(comparison["observations"]["gen1"], [old])
                self.assertEqual(len(comparison["corrected_rows"]), 1)
            self.assertIn("cartridge secondary oracle", output.getvalue())
