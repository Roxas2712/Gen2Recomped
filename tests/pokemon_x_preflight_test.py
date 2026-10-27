"""Synthetic binary fixtures only; no game content or console keys."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pokemon_x_preflight", ROOT / "tools/pokemon_x_preflight.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
sys.path.insert(0, str(ROOT / "tools"))
import pokemon_x_backend as backend


def ncch(*, no_crypto=True, plaintext=True, title=0x0004000000055D00):
    data = bytearray(0x1000)
    data[0x100:0x104] = b"NCCH"
    struct.pack_into("<I", data, 0x104, len(data) // 512)
    struct.pack_into("<Q", data, 0x118, title)
    data[0x150:0x15A] = b"CTR-P-EKJA"
    struct.pack_into("<I", data, 0x180, 0x400)
    data[0x18F] = 4 if no_crypto else 0
    for field, offset, size, hash_field in [(None, 0x200, 0x400, 0x160),
                                            (0x1A0, 0x600, 0x200, 0x1C0),
                                            (0x1B0, 0x800, 0x400, 0x1E0)]:
        data[offset:offset + size] = bytes([offset // 512]) * size
        data[hash_field:hash_field + 32] = hashlib.sha256(data[offset:offset + size]).digest()
        if field:
            struct.pack_into("<III", data, field, offset // 512, size // 512, size // 512)
        if not plaintext:
            data[offset] ^= 0xFF
    return bytes(data)


def cia(content, *, encrypted=False, included=True, bad_hash=False):
    tmd = bytearray(0x140 + 0x9C4 + 0x30)
    struct.pack_into(">I", tmd, 0, 0x10004)
    struct.pack_into(">Q", tmd, 0x140 + 0x4C, 0x0004000000055D00)
    struct.pack_into(">H", tmd, 0x140 + 0x9E, 1)
    at = 0x140 + 0x9C4
    struct.pack_into(">IHHQ", tmd, at, 0, 0, int(encrypted), len(content))
    tmd[at + 16:at + 48] = b"\0" * 32 if bad_hash else hashlib.sha256(content).digest()
    start = probe.align64(0x2020) + probe.align64(len(tmd))
    data = bytearray(start)
    struct.pack_into("<I", data, 0, 0x2020)
    struct.pack_into("<I", data, 0x10, len(tmd))
    struct.pack_into("<Q", data, 0x18, len(content) if included else 0)
    data[0x20] = 0x80 if included else 0
    data[probe.align64(0x2020):probe.align64(0x2020) + len(tmd)] = tmd
    return bytes(data) + (content if included else b"")


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get("POKEMON_X_TEST_TMP"))
        self.addCleanup(self.temp.cleanup)
        self.rom = Path(self.temp.name) / "input.bin"

    def inspect(self, data, **kwargs):
        self.rom.write_bytes(data)
        return probe.inspect(self.rom, **kwargs)

    def test_plaintext_cia_checks_content_and_preserves_input(self):
        data = cia(ncch())
        result = self.inspect(data, verify_contents=True)
        self.assertEqual(result["status"], "headers_verified_boot_untested")
        self.assertTrue(result["cia"]["contents"][0]["tmd_sha256_matches"])
        self.assertEqual(result["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(self.rom.read_bytes(), data)

    def test_clear_cia_can_still_hold_encrypted_ncch(self):
        result = self.inspect(cia(ncch(no_crypto=False, plaintext=False)), verify_contents=True)
        self.assertFalse(result["outer_content_encrypted"])
        self.assertTrue(result["cia"]["contents"][0]["tmd_sha256_matches"])
        self.assertIn("ncch_encrypted_or_damaged", result["blockers"])

    def test_outer_encryption_blocks_before_ncch_parse(self):
        result = self.inspect(cia(b"x" * 512, encrypted=True))
        self.assertEqual(result["blockers"], ["cia_content_encrypted"])

    def test_plaintext_flag_is_not_enough(self):
        result = self.inspect(ncch(plaintext=False))
        self.assertIn("ncch_plaintext_integrity_failed", result["blockers"])

    def test_bad_tmd_hash_blocks_otherwise_readable_game(self):
        result = self.inspect(cia(ncch(), bad_hash=True), verify_contents=True)
        self.assertIn("cia_content_integrity_failed", result["blockers"])

    def test_missing_executable_bitmap_is_rejected(self):
        with self.assertRaises(probe.InvalidDump):
            self.inspect(cia(ncch(), included=False))

    def test_truncated_content_is_rejected(self):
        with self.assertRaises(probe.InvalidDump):
            self.inspect(cia(ncch())[:-1])

    def test_oversized_hash_region_is_rejected(self):
        data = bytearray(ncch())
        struct.pack_into("<I", data, 0x1A8, 0xFFFFFFFF)
        with self.assertRaises(probe.InvalidDump):
            self.inspect(data)

    def test_other_title_is_not_enabled(self):
        result = self.inspect(ncch(title=0x0004000000055F00))
        self.assertIn("not_pokemon_xy_usa", result["blockers"])

    def test_ncsd_partition_bounds(self):
        data = bytearray(0x200)
        data[0x100:0x104] = b"NCSD"
        struct.pack_into("<II", data, 0x120, 0xFFFF, 8)
        with self.assertRaises(probe.InvalidDump):
            self.inspect(data)

    def test_report_cannot_overwrite_rom(self):
        self.rom.write_bytes(ncch())
        original = self.rom.read_bytes()
        with patch.object(sys, "argv", ["probe", str(self.rom), "--report", str(self.rom)]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                probe.main()
        self.assertEqual(self.rom.read_bytes(), original)


class BackendTests(unittest.TestCase):
    def test_local_vulkan_environment_does_not_change_global_environment(self):
        with tempfile.TemporaryDirectory(dir=os.environ.get("POKEMON_X_TEST_TMP")) as folder:
            work = Path(folder)
            loader = work / "loader"
            loader.mkdir()
            manifest = work / "driver.json"
            manifest.write_text("{}")
            (work / "vulkan").mkdir()
            (work / "vulkan/environment.json").write_text(json.dumps({
                "loader_directory": str(loader), "driver_manifest": str(manifest)}))
            with patch.object(backend, "WORK", work), \
                 patch.object(backend.platform, "system", return_value="Darwin"), \
                 patch.dict(os.environ, {"DYLD_FALLBACK_LIBRARY_PATH": "existing"}, clear=True):
                env = backend.backend_environment()
                self.assertEqual(env["DYLD_FALLBACK_LIBRARY_PATH"], str(loader) + os.pathsep + "existing")
                self.assertEqual(env["VK_ICD_FILENAMES"], str(manifest))
                self.assertEqual(os.environ["DYLD_FALLBACK_LIBRARY_PATH"], "existing")
                self.assertNotIn("VK_ICD_FILENAMES", os.environ)

    def test_filename_remains_one_literal_argument(self):
        rom = Path('/tmp/a file $(never-run) "; quote.cia')
        plan = backend.commands("analyze", rom, "hash", Path("recompiler"), Path("runtime"))
        self.assertEqual(plan, [["recompiler", "analyze", str(rom)]])

    def test_smoke_uses_explicit_library_and_separate_profile(self):
        command = backend.commands("smoke", Path("game.cia"), "hash", Path("recompiler"), Path("runtime"))[-1]
        self.assertIn("--recompiled", command)
        self.assertEqual(command[command.index("--data") + 1], str(backend.CACHE / "smoke-profile"))
        self.assertEqual(command[-3:], ["--headless", "300", "--mute"])

    def test_zero_exit_without_frame_report_is_not_success(self):
        self.assertFalse(backend.smoke_passed("failed to load game"))
        self.assertFalse(backend.smoke_passed("Completed after 300 frames in 1s | interpreted 100.00%"))

    def test_early_halt_or_fatal_error_is_not_success(self):
        self.assertFalse(backend.smoke_passed("Halted after 1 frames | interpreted 0.00%"))
        self.assertFalse(backend.smoke_passed("Completed after 300 frames in 1s | interpreted 0.1%\nfatal errors: failure"))

    def test_completed_recompiled_frames_are_only_a_smoke_pass(self):
        self.assertTrue(backend.smoke_passed("Completed after 300 frames in 1s\nframe 300 | interpreted 0.21%"))

    def test_encrypted_input_never_starts_a_backend(self):
        from unittest.mock import Mock
        qa = Mock()
        with patch.object(backend.preflight, "qa_manager", return_value=qa), \
             patch.object(backend.preflight, "inspect", return_value={
                 "status": "blocked", "blockers": ["ncch_encrypted_or_damaged"]}), \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(backend.main(["play", "game.cia"]), 2)
        qa.qa_run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
