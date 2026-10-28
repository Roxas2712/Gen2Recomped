import sys
from pathlib import Path
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from rs_profile_files import persistent_files


class ProfileFiles(unittest.TestCase):
    def test_only_exact_top_level_http_replies_are_excluded(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            excluded = ['http_private_res_1793069697_1234.tmp',
                        'http_private_status_1793069697_Channel0x012d364160902_2.tmp']
            kept = ['http_private_res_bad_123.tmp', 'http_private_res_1_2.tmp.bak',
                    'profiles/guest/save_sapphire.lua', 'profiles/guest/save_sapphire.lua.tmp',
                    'sapphire/data/generated/constants.lua',
                    'profiles/http_private_status_1793069697_1234.tmp']
            for relative in excluded + kept:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'fixture')
            self.assertEqual(set(persistent_files(root)), set(kept))

    def test_persistent_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / 'real').write_bytes(b'fixture')
            (root / 'save_sapphire.lua').symlink_to(root / 'real')
            with self.assertRaises(AssertionError):
                persistent_files(root)


if __name__ == '__main__':
    unittest.main()
