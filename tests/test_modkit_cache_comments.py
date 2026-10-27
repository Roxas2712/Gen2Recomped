"""The MK301 gate ignores Lua comments, but still rejects real cache paths."""
import hashlib
import json
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


class BuiltinCacheSources(unittest.TestCase):
    SOURCE = 'return "data/generated/virtual.lua"'
    MANIFEST = {"id": "trusted", "permissions": ["engine_internals"]}

    def findings(self, body=None, manifest=None, folder_name="probe", owned_policy=True, extras=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "mods" / folder_name
            folder.mkdir(parents=True)
            (folder / "main.lua").write_text(self.SOURCE if body is None else body)
            sources = {"main.lua": hashlib.sha256(self.SOURCE.encode()).hexdigest()}
            for path, data in (extras or {}).items():
                target = folder / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                sources[path] = hashlib.sha256(data).hexdigest()
            policy_root = root if owned_policy else folder
            (policy_root / "tools").mkdir()
            (policy_root / "tools/modkit_builtin_cache_sources.json").write_text(json.dumps({
                "mods/probe": {"manifestId": "trusted", "sources": sources}
            }))
            return modkit.lint_dir(str(root), str(folder),
                                   self.MANIFEST if manifest is None else manifest)

    def test_exact_repository_source_pin(self):
        self.assertFalse(any(f.rule == "MK301" for f in self.findings()))

    def test_edited_source_is_rejected_until_reviewed(self):
        self.assertTrue(any(f.rule == "MK301" for f in self.findings(self.SOURCE + " -- changed")))

    def test_identity_permission_and_repository_path_are_required(self):
        for manifest in ({"id": "other", "permissions": ["engine_internals"]},
                         {"id": "trusted", "permissions": []},
                         {"id": "trusted", "permissions": "engine_internals"}, {}):
            with self.subTest(manifest=manifest):
                self.assertTrue(any(f.rule == "MK301" for f in self.findings(manifest=manifest)))
        self.assertTrue(any(f.rule == "MK301" for f in self.findings(folder_name="copied")))
        self.assertTrue(any(f.rule == "MK301" for f in self.findings(owned_policy=False)))

    def test_other_content_gates_still_run_even_with_matching_pins(self):
        findings = self.findings(extras={
            "assets/generated/hidden.lua": b"return 1",
            "assets/source.gb": b"not a distributable cartridge",
            "assets/source.gba": b"not a distributable cartridge",
            "assets/source.nds": b"not a distributable cartridge",
            "assets/source.ips": b"not a distributable patch",
            "assets/source.bps": b"not a distributable patch",
            "descriptor.json": b'{"path":"assets/generated/hidden.png"}',
        })
        self.assertTrue(any(f.rule == "MK301" and f.path == "assets/generated/hidden.lua" for f in findings))
        for extension in ("gb", "gba", "nds", "ips", "bps"):
            self.assertTrue(any(f.rule == "MK303" and f.path == "assets/source." + extension for f in findings))
        self.assertTrue(any(f.rule == "MK301" and f.path == "descriptor.json" for f in findings))


if __name__ == "__main__":
    unittest.main()
