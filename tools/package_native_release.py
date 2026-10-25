#!/usr/bin/env python3
"""Package a committed Windows/macOS intermediate release without running a game."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

from build_native_preview import RUNTIMES, RUNTIME_COMMIT, verify_payload

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release-id', required=True)
    parser.add_argument('--engine-version', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]{8}\.[0-9]+', args.release_id):
        parser.error('release-id must be YYYYMMDD.N')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', args.engine_version):
        parser.error('engine-version must be X.Y.Z')
    if sys.platform != 'darwin':
        parser.error('macOS is required to sign the macOS preview package')
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    builds = []
    payload_hash = None
    with tempfile.TemporaryDirectory(prefix='native-release-') as temporary:
        work = Path(temporary)
        for platform, runtime in RUNTIMES.items():
            archive = work / (platform + '-runtime.zip')
            url = 'https://nightly.link/love2d/love/actions/artifacts/' + str(runtime['id']) + '.zip'
            with urllib.request.urlopen(url, timeout=120) as response, archive.open('wb') as target:
                shutil.copyfileobj(response, target)
            if digest(archive) != runtime['sha256']:
                raise ValueError('Official runtime digest mismatch: ' + platform)
            package = work / platform
            subprocess.run([sys.executable, str(ROOT / 'tools/build_native_preview.py'),
                            '--platform', platform, '--runtime', str(archive),
                            '--source-ref', source, '--release-id', args.release_id,
                            '--engine-version', args.engine_version, '--out', str(package)],
                           cwd=ROOT, check=True)
            metadata = json.loads((package / 'build.json').read_text())
            if metadata['sourceCommit'] != source or metadata['runtimeCommit'] != RUNTIME_COMMIT:
                raise ValueError('Package source/runtime does not match the frozen release')
            payload = package / 'Gen2Recomped-NativePreview.love'
            verify_payload(payload, args.engine_version)
            current_hash = digest(payload)
            if current_hash != metadata['payloadSha256'] or (payload_hash and current_hash != payload_hash):
                raise ValueError('Windows and macOS must carry exactly the same engine payload')
            payload_hash = current_hash
            bundles = list(package.glob('*.zip'))
            if len(bundles) != 1 or digest(bundles[0]) != metadata['archiveSha256']:
                raise ValueError('Platform package checksum mismatch')
            shutil.copy2(bundles[0], out / bundles[0].name)
            if not (out / payload.name).exists():
                shutil.copy2(payload, out / payload.name)
            builds.append(metadata)
    manifest = dict(releaseId=args.release_id, sourceCommit=source,
                    engineVersion=args.engine_version, modApi=3, builds=builds)
    (out / 'build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    notes = f'''RetroRecomped Preview {args.release_id} · engine {args.engine_version} / mod API 3

Intermediate pre-release from main, source commit: {source}

Includes the RetroRecomped launcher and seasonal intros, cartridge artwork,
native ModCompass accounts and developer repositories, mod browsing/downloads,
cloud saves and Pokemon Bank, and save-bound mod compatibility/restore review.
The merged engine work includes native Gen2 camera/movement handoffs and the
Apple Silicon performance-tier correction.

Downloads:
- Windows ZIP: extract and start Gen2Recomped-NativePreview.exe.
- macOS ZIP: extract and open the preview app; Metal/OpenGL launchers included.
- .love: identical engine payload, requires the pinned LOVE 12 runtime.
Both ZIPs bundle official LOVE 12 revision {RUNTIME_COMMIT}.
The macOS app is ad-hoc signed, without Apple notarization.

Import your own supported ROMs and save files. No ROMs, extracted game caches,
user saves, account credentials or mod packages are included. This preview
uses a separate Gen2Recomp-NativePreview-{args.release_id.replace('.', '-')} profile;
existing profiles are preserved and are not automatically migrated.

Known limits: exact mid-battle savestates/device handoff are still in development.
Normal save progress is supported; saving progress is not an execution snapshot.
The experimental extended-upvalue LuaJIT is NOT bundled. Mods that exceed the
official runtime's capacity may still fail to load. Full-game 3D/mod compatibility
and Windows/macOS hardware acceptance are not claimed by this intermediate build.

Validation: headless launcher contracts, package content checks, identical payload
hashes and SHA256SUMS.txt. No new in-game test was run for this release.
'''
    (out / 'README-Testrelease.txt').write_text(notes)
    files = sorted(out.iterdir())
    (out / 'SHA256SUMS.txt').write_text(''.join(digest(path) + '  ' + path.name + '\n' for path in files))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
