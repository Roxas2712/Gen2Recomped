"""ROM-/GPU-free ownership and rejection gates; live pixel evidence is separate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location(
    "window_gpu_tools", Path(__file__).resolve().parents[1] / "tools/check_gen3_palette_gpu.py")
TOOLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOLS)


class OriginalImage:
    """Original test marker and colour-count data, no game pixels."""
    width, height = 128, 120

    def __init__(self, stamp=41, colours=24):
        self.stamp, self.colours = stamp, colours

    def __enter__(self):
        return self

    def __exit__(self, *_):
        pass

    def convert(self, _):
        return self

    def getpixel(self, point):
        bit = point[0] // 4
        # Include wide-gamut mixed channels as observed in OS captures.
        return (240, 17, 8) if (self.stamp >> bit) & 1 else (117, 251, 76)

    def crop(self, _):
        return self

    def getcolors(self, _):
        return [(1, (i, i, i)) for i in range(self.colours)]


class WindowProofTests(unittest.TestCase):
    def run_proof(self, *, pid=123, window=55, stamp=41, minimum=40, colours=24):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            (out / "window-request.json").write_text(json.dumps(dict(
                phase="initial-map", pid=pid, window=window, minimumStamp=minimum,
                logicalWidth=64, logicalHeight=48)))
            pil = types.ModuleType("PIL")
            pil.Image = types.SimpleNamespace(open=Mock(return_value=OriginalImage(stamp, colours)))
            with patch.dict("sys.modules", {"PIL": pil}), patch.object(TOOLS.subprocess, "run") as run:
                tick, proofs = TOOLS.os_window_proof(out)
                try:
                    tick(123)
                except RuntimeError:
                    self.assertFalse((out / "window-initial-map.ok").exists())
                    if pid != 123 or window <= 0:
                        run.assert_not_called()
                        pil.Image.open.assert_not_called()
                    raise
                self.assertEqual(proofs["initial-map"]["freshFrameStamp"], stamp)
                self.assertEqual(proofs["initial-map"]["attempts"], 1)
                args = run.call_args.args[0]
                self.assertEqual(args[args.index("-l") + 1], str(window))
                tick(123)
                self.assertEqual(run.call_count, 1, "accepted OS capture is not retried")

    def test_current_owned_window(self):
        self.run_proof()

    def test_other_process_never_captured(self):
        with self.assertRaisesRegex(RuntimeError, "owned child"):
            self.run_proof(pid=999)

    def test_zero_window_cannot_fall_back_to_whole_screen(self):
        with self.assertRaisesRegex(RuntimeError, "owned child"):
            self.run_proof(window=0)

    def test_stale_window_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "stale"):
            self.run_proof(stamp=39)

    def test_marker_on_black_window_is_insufficient(self):
        with self.assertRaisesRegex(RuntimeError, "blank"):
            self.run_proof(colours=3)

    def test_rejection_stops_only_created_child(self):
        process = Mock(pid=123, args=["own-love", "own-source"])
        process.poll.return_value = None
        process.wait.return_value = -15
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(TOOLS.subprocess, "Popen", return_value=process):
                def reject(pid):
                    self.assertEqual(pid, 123)
                    raise RuntimeError("rejected proof")
                with self.assertRaisesRegex(RuntimeError, "rejected proof"):
                    TOOLS.child("own-love", Path(folder), {}, Path(folder) / "log", 1, reject)
        process.terminate.assert_called_once()
        process.kill.assert_not_called()


if __name__ == "__main__":
    unittest.main()
