import hashlib
import io
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import fetch_love_runtime as fetch


class OfficialHostDownload(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.target = Path(self.temporary.name) / 'host.zip'
        self.data = b'official pinned artifact fixture'
        self.pin = patch.object(fetch, 'RUNTIMES', {'test': {
            'id': 123, 'sha256': hashlib.sha256(self.data).hexdigest()}})
        self.pin.start()
        self.addCleanup(self.pin.stop)
        sleeping = patch.object(fetch.time, 'sleep')
        sleeping.start()
        self.addCleanup(sleeping.stop)

    def test_primary_requires_exact_pinned_bytes(self):
        with patch.object(fetch.urllib.request, 'urlopen', return_value=io.BytesIO(self.data)), \
             patch.object(fetch.subprocess, 'run') as fallback:
            self.assertEqual(fetch.fetch_runtime(123, self.target), 'nightly.link')
        self.assertEqual(self.target.read_bytes(), self.data)
        fallback.assert_not_called()

    def test_proxy_failure_fetches_same_official_artifact(self):
        def github(command, **kwargs):
            self.assertEqual(command, ['gh', 'api', 'repos/love2d/love/actions/artifacts/123/zip'])
            kwargs['stdout'].write(self.data)
        with patch.object(fetch.urllib.request, 'urlopen', side_effect=urllib.error.URLError('HTTP500')), \
             patch.object(fetch.subprocess, 'run', side_effect=github):
            self.assertEqual(fetch.fetch_runtime(123, self.target), 'github-api')
        self.assertEqual(self.target.read_bytes(), self.data)

    def test_corrupt_primary_is_rejected_without_silent_fallback(self):
        with patch.object(fetch.urllib.request, 'urlopen', return_value=io.BytesIO(b'corrupt')), \
             patch.object(fetch.subprocess, 'run') as fallback:
            with self.assertRaises(ValueError):
                fetch.fetch_runtime(123, self.target)
        self.assertFalse(self.target.exists())
        fallback.assert_not_called()

    def test_corrupt_fallback_does_not_replace_existing_output(self):
        self.target.write_bytes(b'previous')
        with patch.object(fetch.urllib.request, 'urlopen', side_effect=urllib.error.URLError('offline')), \
             patch.object(fetch.subprocess, 'run'):
            with self.assertRaises(ValueError):
                fetch.fetch_runtime(123, self.target)
        self.assertEqual(self.target.read_bytes(), b'previous')

    def test_failed_fallback_leaves_no_partial_output(self):
        with patch.object(fetch.urllib.request, 'urlopen', side_effect=urllib.error.URLError('offline')), \
             patch.object(fetch.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['gh'])) as fallback:
            with self.assertRaises(subprocess.CalledProcessError):
                fetch.fetch_runtime(123, self.target)
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.target.parent.iterdir()), [])
        self.assertEqual(fallback.call_count, 3)

    def test_transient_api_failure_is_retried_with_truncated_partial_bytes(self):
        calls = []
        def github(command, **kwargs):
            calls.append(command)
            if len(calls) == 1:
                kwargs['stdout'].write(b'partial response')
                raise subprocess.CalledProcessError(1, command)
            kwargs['stdout'].write(self.data)
        with patch.object(fetch.urllib.request, 'urlopen', side_effect=urllib.error.URLError('offline')), \
             patch.object(fetch.subprocess, 'run', side_effect=github):
            self.assertEqual(fetch.fetch_runtime(123, self.target), 'github-api')
        self.assertEqual(len(calls), 2)
        self.assertEqual(self.target.read_bytes(), self.data)

    def test_unpinned_artifact_is_rejected_before_network(self):
        with patch.object(fetch.urllib.request, 'urlopen') as network:
            with self.assertRaises(ValueError):
                fetch.fetch_runtime(456, self.target)
        network.assert_not_called()


if __name__ == '__main__':
    unittest.main()
