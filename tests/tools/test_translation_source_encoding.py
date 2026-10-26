"""The catalog scanner tolerates legacy bytes without changing source keys."""
import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "translation_modkit", os.environ.get("MODKIT_UNDER_TEST", str(ROOT / "tools/modkit.py")))
MODKIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODKIT)


class TranslationSourceEncodingTests(unittest.TestCase):
    def source(self, body):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        path = root / "src" / "probe.lua"
        path.parent.mkdir()
        path.write_bytes(body)
        return root, path

    def test_legacy_comment_does_not_block_valid_source_key(self):
        body = b'-- Stages clamp at \xb16.\nlocal s = Strings("A valid key")\n'
        root, path = self.source(body)
        self.assertEqual(MODKIT.harvest_engine_strings(str(root)),
                         [('"A valid key"', 'src/probe.lua:2')])
        self.assertEqual(path.read_bytes(), body)

    def test_invalid_bytes_outside_harvested_literals_are_not_rewritten(self):
        body = b'local legacy = "\xff\xfe"\nlocal s = Strings.source("A template %s")\n'
        root, path = self.source(body)
        self.assertEqual(MODKIT.harvest_engine_strings(str(root)),
                         [('"A template %s"', 'src/probe.lua:2')])
        self.assertEqual(path.read_bytes(), body)

    def test_utf8_keys_and_quote_normalization_remain_exact(self):
        body = 'Strings("Grüße aus Kanto")\nStrings.source(\'ようこそ\')\n'.encode('utf-8')
        root, path = self.source(body)
        self.assertEqual(MODKIT.harvest_engine_strings(str(root)),
                         [('"Grüße aus Kanto"', 'src/probe.lua:1'),
                          ('"ようこそ"', 'src/probe.lua:2')])
        self.assertEqual(path.read_bytes(), body)

    def test_invalid_harvested_literal_has_a_source_location(self):
        body = b'-- Comment\nStrings("bad \xb1 key")\n'
        root, path = self.source(body)
        with self.assertRaisesRegex(ValueError, r'src/probe.lua:2: translation source literal is not valid UTF-8'):
            MODKIT.harvest_engine_strings(str(root))
        self.assertEqual(path.read_bytes(), body)

    def test_cli_handler_reports_bad_literal_before_writing_a_mod(self):
        root, path = self.source(b'Strings("bad \xff key")\n')
        destination = root / "output"
        args = SimpleNamespace(id='translation_probe', language='Test', dest=str(destination),
                               refresh=False, force=False, base='fixture')
        output = io.StringIO()
        with mock.patch.object(MODKIT, 'resolve_base', return_value='fixture'), \
                mock.patch.object(MODKIT, 'dump_dataset', return_value=[]), \
                contextlib.redirect_stdout(output):
            code = MODKIT.cmd_translation(args, str(root))
        self.assertEqual(code, 1)
        self.assertIn('src/probe.lua:1: translation source literal is not valid UTF-8', output.getvalue())
        self.assertFalse(destination.exists())
        self.assertEqual(path.read_bytes(), b'Strings("bad \xff key")\n')

    def test_actual_repository_harvest_preserves_legacy_source(self):
        path = ROOT / 'src/battle/MoveEffects.lua'
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        entries = MODKIT.harvest_engine_strings(str(ROOT))
        self.assertGreater(len(entries), 100)
        self.assertTrue(any(where.startswith('src/battle/MoveEffects.lua:') for _, where in entries))
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)


if __name__ == '__main__':
    unittest.main()
