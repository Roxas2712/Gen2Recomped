"""ROM-free CI setup regression tests. Contributions by Roxas2712."""
import io
from pathlib import Path
import socket
import ssl
import tempfile
import unittest
import urllib.error
import zipfile

from tools.ci_runtime_download import download


class RuntimeDownloadTests(unittest.TestCase):
    def fixture(self, outcomes):
        home = tempfile.TemporaryDirectory()
        self.addCleanup(home.cleanup)
        destination = Path(home.name) / "runtime.zip"
        destination.write_bytes(b"previous complete runtime")
        wire = io.BytesIO()
        with zipfile.ZipFile(wire, "w") as archive:
            archive.writestr("runtime.txt", "owned test runtime")
        self.calls, self.pauses = [], []

        def opener(url, timeout):
            self.calls.append((url, timeout))
            outcome = outcomes[len(self.calls) - 1]
            if isinstance(outcome, Exception):
                raise outcome
            return io.BytesIO(wire.getvalue() if outcome == "ok" else outcome)

        self.opener = opener
        return destination, wire.getvalue()

    def run_download(self, destination):
        return download("https://fixture.invalid/runtime.zip", destination,
                        opener=self.opener, pause=self.pauses.append)

    def assert_preserved(self, destination):
        self.assertEqual(destination.read_bytes(), b"previous complete runtime")
        self.assertEqual(list(destination.parent.glob("*.part")), [])

    def test_dns_then_success(self):
        path, expected = self.fixture([urllib.error.URLError(socket.gaierror(socket.EAI_AGAIN, "DNS")), "ok"])
        self.assertEqual(self.run_download(path), path)
        self.assertEqual(path.read_bytes(), expected)
        self.assertEqual(self.pauses, [1])
        self.assertEqual([timeout for _, timeout in self.calls], [20, 20])
        self.assertEqual(list(path.parent.glob("*.part")), [])

    def test_attempt_ceiling_preserves_old_archive(self):
        path, _ = self.fixture([TimeoutError("timeout")] * 3)
        with self.assertRaises(TimeoutError):
            self.run_download(path)
        self.assertEqual(len(self.calls), 3)
        self.assertEqual(self.pauses, [1, 2])
        self.assert_preserved(path)

    def test_bad_zip_then_valid_zip(self):
        path, expected = self.fixture([b"truncated zip", "ok"])
        self.run_download(path)
        self.assertEqual(path.read_bytes(), expected)
        self.assertEqual(len(self.calls), 2)

    def test_permanent_http_and_certificate_failures_are_not_retried(self):
        failures = [urllib.error.HTTPError("https://fixture.invalid", 404, "missing", {}, None),
                    urllib.error.URLError(ssl.SSLCertVerificationError("untrusted"))]
        for failure in failures:
            if isinstance(failure, urllib.error.HTTPError):
                self.addCleanup(failure.close)
            with self.subTest(error=type(failure).__name__):
                path, _ = self.fixture([failure])
                with self.assertRaises(type(failure)):
                    self.run_download(path)
                self.assertEqual(len(self.calls), 1)
                self.assertEqual(self.pauses, [])
                self.assert_preserved(path)

    def test_http_server_failure_can_recover(self):
        failure = urllib.error.HTTPError("https://fixture.invalid", 503, "busy", {}, None)
        self.addCleanup(failure.close)
        path, expected = self.fixture([failure, "ok"])
        self.run_download(path)
        self.assertEqual(path.read_bytes(), expected)

    def test_plaintext_url_never_opens_transport(self):
        path, _ = self.fixture([])
        with self.assertRaises(ValueError):
            download("http://fixture.invalid/runtime.zip", path, opener=self.opener)
        self.assertEqual(self.calls, [])
        self.assert_preserved(path)


if __name__ == "__main__":
    unittest.main()
