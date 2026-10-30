#!/usr/bin/env python3
"""Download a public CI runtime ZIP with bounded setup-only network retries.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse
import os
from pathlib import Path
import shutil
import socket
import ssl
import sys
import tempfile
import time
import urllib.error
import urllib.request
import zipfile


def retryable(error):
    if isinstance(error, urllib.error.HTTPError):
        return error.code == 429 or 500 <= error.code <= 599
    if isinstance(error, urllib.error.URLError):
        error = error.reason
    if isinstance(error, ssl.SSLCertVerificationError):
        return False
    return isinstance(error, (socket.gaierror, TimeoutError, ConnectionError, zipfile.BadZipFile))


def download(url, destination, *, opener=urllib.request.urlopen, pause=time.sleep):
    if not url.startswith("https://"):
        raise ValueError("CI runtime URL must use HTTPS")
    destination = Path(destination)
    for attempt in range(3):
        part = None
        try:
            with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=destination.name + ".",
                                             suffix=".part", delete=False) as stream:
                part = Path(stream.name)
                with opener(url, timeout=20) as response:
                    shutil.copyfileobj(response, stream, 65536)
            with zipfile.ZipFile(part) as archive:
                if archive.testzip() is not None:
                    raise zipfile.BadZipFile("CI runtime ZIP failed CRC validation")
            os.replace(part, destination)
            return destination
        except Exception as error:
            if attempt == 2 or not retryable(error):
                raise
            print(f"CI runtime acquisition: retry {attempt + 2}/3 after {type(error).__name__}",
                  file=sys.stderr, flush=True)
            pause(attempt + 1)
        finally:
            if part is not None and part.exists():
                part.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    download(args.url, args.destination)
