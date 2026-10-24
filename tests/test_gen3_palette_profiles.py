import importlib.util
import hashlib
import io
import json
from pathlib import Path
import unittest
from unittest import mock
from contextlib import redirect_stderr
from tempfile import TemporaryDirectory
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("palette_profiles", ROOT / "tools/gen3_palette_profiles.py")
PROFILES = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROFILES)
CHECK_SPEC = importlib.util.spec_from_file_location("palette_check", ROOT / "tools/check_gen3_palette_programs.py")
CHECK = importlib.util.module_from_spec(CHECK_SPEC)
with mock.patch.dict("sys.modules", {"gen3_palette_profiles": PROFILES}):
    CHECK_SPEC.loader.exec_module(CHECK)


class PaletteProfiles(unittest.TestCase):
    def test_generated_manifest_profiles_match_catalog(self):
        for game in ("emerald", "firered"):
            manifest = json.loads((ROOT / f"tools/rom_manifest_{game}.json").read_text())
            profile = PROFILES.profile_for_sha1(manifest["romSha1"])
            self.assertEqual(profile, manifest["terrainPalettePrograms"])
            self.assertEqual(profile["game"], game)
            self.assertEqual(profile["romSha1"], manifest["romSha1"])
            self.assertIn("github.com/pret/", profile["source"])
            self.assertIn("terrainPalettePrograms", (ROOT / "tools/gen3_discover.py").read_text())

    def test_exact_hash_and_detached_recipe(self):
        sha1 = "f3ae088181bf583e55daf962a92bb46f4f1d07b7"
        self.assertIsNone(PROFILES.profile_for_sha1("0" * 40))
        profile = PROFILES.profile_for_sha1(sha1)
        profile["programs"].clear()
        self.assertEqual(len(PROFILES.profile_for_sha1(sha1)["programs"]), 20)

    def test_pinned_cartridge_program_semantics(self):
        emerald = PROFILES.profile_for_sha1("f3ae088181bf583e55daf962a92bb46f4f1d07b7")
        firered = PROFILES.profile_for_sha1("41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc")
        palette = emerald["programs"][str(0xA1658)]
        self.assertEqual((palette["table"], palette["first"], palette["count"], palette["frames"], palette["step"]),
                         (0x52487C, 128, 16, 4, 4))
        self.assertEqual(sum(p["kind"] == "frames" for p in emerald["programs"].values()), 1)
        self.assertEqual(sum(p["kind"] == "static" for p in emerald["programs"].values()), 19)
        self.assertEqual(len(firered["programs"]), 6)
        self.assertTrue(all(p["kind"] == "static" for p in firered["programs"].values()))

    def test_checker_refuses_unknown_rom_before_subprocess(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "original synthetic.gba"
            path.write_bytes(b"original synthetic data, not a retail ROM")
            with mock.patch.object(CHECK.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "unsupported.*digest"):
                    CHECK.check(path, "luajit")
                run.assert_not_called()

    def test_checker_passes_the_exact_authenticated_bytes(self):
        data = b"original synthetic source for checker transport"
        with TemporaryDirectory() as directory:
            path = Path(directory) / "source with spaces.gba"
            path.write_bytes(data)
            result = SimpleNamespace(returncode=0, stdout=b'log\nPALETTE_ROM_RESULT {"game":"emerald"}\n', stderr=b"")
            with mock.patch.object(CHECK, "profile_for_sha1", return_value={"game": "emerald"}) as profile:
                with mock.patch.object(CHECK.subprocess, "run", return_value=result) as run:
                    self.assertEqual(CHECK.check(path, "isolated-luajit"), {"game": "emerald"})
                    digest = hashlib.sha1(data).hexdigest()
                    profile.assert_called_once_with(digest)
                    args, kwargs = run.call_args
                    self.assertEqual(args[0], ["isolated-luajit", "tools/gen3_palette_program_check.lua", "emerald", digest])
                    self.assertEqual(kwargs["input"], data)
                    self.assertEqual(kwargs["cwd"], ROOT)
                    self.assertNotIn("shell", kwargs)
            self.assertEqual(path.read_bytes(), data)

    def test_checker_cannot_report_success_after_runner_failure(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.gba"
            path.write_bytes(b"synthetic")
            result = SimpleNamespace(returncode=1, stdout=b'PALETTE_ROM_RESULT {}\n', stderr=b"pixel mismatch")
            with mock.patch.object(CHECK, "profile_for_sha1", return_value={"game": "firered"}):
                with mock.patch.object(CHECK.subprocess, "run", return_value=result):
                    with redirect_stderr(io.StringIO()), self.assertRaisesRegex(RuntimeError, "failed for firered"):
                        CHECK.check(path, "luajit")


if __name__ == "__main__":
    unittest.main()
