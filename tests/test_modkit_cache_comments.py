"""The MK301 gate ignores Lua comments, but still rejects real cache paths."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("modkit", ROOT / "tools/modkit.py")
modkit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modkit)


class CacheComments(unittest.TestCase):
    def findings(self, body, suffix=".lua", manifest=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "mods/probe"
            folder.mkdir(parents=True)
            (folder / ("main" + suffix)).write_text(body)
            return [f for f in modkit.lint_dir(str(root), str(folder), manifest or {})
                    if f.rule == "MK301"]

    def test_documentation_comments(self):
        for body in (
            '-- data/generated/constants.lua\nreturn {}',
            '--[[ assets/generated/example.png ]] return {}',
            '--[==[ data/generated/maps.lua\n--[[ nested ]]\n]==]\nreturn {}',
            'return {} -- assets/generated/example.png',
        ):
            with self.subTest(body=body):
                self.assertEqual(self.findings(body), [])

    def test_runtime_strings_stay_rejected(self):
        for body in (
            'return "assets/generated/example.png"',
            "return 'data/generated/maps.lua'",
            'return [[assets/generated/example.png]]',
            'return [==[-- data/generated/maps.lua]==]',
            '-- safe comment\nreturn "-- assets/generated/example.png"',
            r'return "escaped\" -- data/generated/maps.lua"',
        ):
            with self.subTest(body=body):
                self.assertEqual(len(self.findings(body)), 1)

    def test_json_strings_remain_rejected(self):
        self.assertEqual(len(self.findings('{"path":"data/generated/maps.lua"}', ".json")), 1)

    def test_generated_tree_paths_remain_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "assets/generated").mkdir(parents=True)
            (root / "assets/generated/example.lua").write_text('-- documentation only')
            findings = modkit.lint_dir(directory, directory, {})
            self.assertTrue(any(f.rule == "MK301" for f in findings))


if __name__ == "__main__":
    unittest.main()
