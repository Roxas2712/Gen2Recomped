"""Privileged import recipes remain distinct from shipped ROM/cache bytes."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import contextlib
import io
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('modkit', ROOT / 'tools/modkit.py')
modkit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modkit)


class NativeImporterLint(unittest.TestCase):
    def manifest(self):
        return {'permissions': ['engine_internals'], 'optional_imports': [
            {'id': 'source', 'file': 'source.gbc', 'size': 1024, 'md5': '0' * 32}]}

    def lint(self, files, manifest=None, cache=None):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / 'mods/importer'
            for name, body in files.items():
                p = folder / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(body)
            for name, body in (cache or {}).items():
                p = root / 'assets/generated' / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(body)
            return modkit.lint_dir(str(root), str(folder), manifest or {})

    def test_verified_importer_source_is_reported_without_blocking(self):
        findings = self.lint({'extract.lua': b'return "data/generated/maps.lua"'}, self.manifest())
        self.assertEqual([(f.rule, f.severity) for f in findings], [('MK301', 'warn')])

    def test_permission_alone_does_not_exempt_cache_references(self):
        for manifest in ({}, {'permissions': ['engine_internals']},
                         {'optional_imports': self.manifest()['optional_imports']}):
            with self.subTest(manifest=manifest):
                result = self.lint({'main.lua': b'return "assets/generated/font.png"'}, manifest)
                self.assertTrue(any(f.rule == 'MK301' and f.severity == 'error' for f in result))

    def test_missing_checksum_or_size_cannot_exempt_source(self):
        for change in ({'md5': None}, {'md5': 'broken'}, {'size': None}, {'size': True}):
            manifest = self.manifest()
            manifest['optional_imports'][0].update(change)
            with self.subTest(change=change):
                self.assertFalse(modkit.declares_native_imports(manifest))

    def test_malformed_permissions_and_unsafe_imports_do_not_qualify(self):
        manifest = self.manifest()
        manifest['permissions'] = 'engine_internals'
        self.assertFalse(modkit.declares_native_imports(manifest))
        for path in ('/source.gbc', '../source.gbc', 'C:\\source.gbc', 'x//source.gbc'):
            manifest = self.manifest()
            manifest['optional_imports'][0]['file'] = path
            with self.subTest(path=path):
                self.assertFalse(modkit.declares_native_imports(manifest))

    def test_strict_mode_retains_reference_warning_as_failure(self):
        findings = self.lint({'extract.lua': b'return "data/generated/maps.lua"'}, self.manifest())
        with contextlib.redirect_stdout(io.StringIO()):
            result = modkit.report(findings, SimpleNamespace(strict=True, json=True), 'ok', 'failed')
        self.assertEqual(result, 1)

    def test_json_assets_still_cannot_point_at_generated_files(self):
        result = self.lint({'assets.json': b'{"image":"assets/generated/font.png"}'}, self.manifest())
        self.assertTrue(any(f.rule == 'MK301' and f.severity == 'error' for f in result))

    def test_shipped_generated_paths_still_fail(self):
        result = self.lint({'data/generated/maps.lua': b'return {}'}, self.manifest())
        self.assertTrue(any(f.rule == 'MK301' and f.severity == 'error' for f in result))

    def test_rom_and_audio_payloads_still_fail(self):
        result = self.lint({'source.gbc': b'fixture', 'programs.bin': b'fixture'}, self.manifest())
        self.assertEqual({f.rule for f in result if f.severity == 'error'}, {'MK303', 'MK304'})

    def test_copied_cache_assets_still_fail(self):
        body = b'authored non-ROM test fixture'
        result = self.lint({'assets/copied.png': body}, self.manifest(), {'native.png': body})
        self.assertTrue(any(f.rule == 'MK302' and f.severity == 'error' for f in result))


if __name__ == '__main__':
    unittest.main()
