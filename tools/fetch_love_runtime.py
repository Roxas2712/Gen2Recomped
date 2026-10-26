#!/usr/bin/env python3
"""Fetch a pinned official LÖVE host, retaining byte verification on fallback."""
import argparse
import hashlib
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

from build_native_preview import RUNTIMES


def fetch_runtime(artifact, destination):
    runtime = next((row for row in RUNTIMES.values() if row['id'] == artifact), None)
    if runtime is None:
        raise ValueError('Unpinned LÖVE artifact')
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='love-fetch-', dir=destination.parent) as directory:
        pending = Path(directory) / 'runtime.zip'
        url = f'https://nightly.link/love2d/love/actions/artifacts/{artifact}.zip'
        provider = 'nightly.link'
        try:
            with urllib.request.urlopen(url, timeout=120) as response, pending.open('wb') as output:
                shutil.copyfileobj(response, output)
        except (urllib.error.URLError, OSError, TimeoutError):
            # gh uses the caller's existing authentication. No token is placed
            # in a URL, command argument, archive, or diagnostic output.
            provider = 'github-api'
            with pending.open('wb') as output:
                subprocess.run(['gh', 'api', f'repos/love2d/love/actions/artifacts/{artifact}/zip'],
                               stdout=output, stderr=subprocess.PIPE, check=True, timeout=120)
        with pending.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if actual != runtime['sha256']:
            raise ValueError('Official LÖVE runtime digest mismatch')
        pending.replace(destination)
    return provider


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print('Verified official LÖVE host via ' + fetch_runtime(args.artifact, args.output))


if __name__ == '__main__':
    main()
