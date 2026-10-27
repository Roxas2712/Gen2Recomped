#!/usr/bin/env python3
"""Package a committed Windows/macOS intermediate release without running a game."""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from build_native_preview import RUNTIMES, RUNTIME_COMMIT, verify_payload
from fetch_love_runtime import fetch_runtime

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release-id', required=True)
    parser.add_argument('--engine-version', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--windows-runtime-component', type=Path,
                        help='optional qualified Windows component.json')
    parser.add_argument('--macos-runtime-component', type=Path,
                        help='optional qualified universal Mac component.json')
    parser.add_argument('--macos-signing-identity', default=os.environ.get('MACOS_SIGNING_IDENTITY'))
    parser.add_argument('--macos-notary-profile', default=os.environ.get('MACOS_NOTARY_PROFILE'))
    parser.add_argument('--macos-signing-keychain', type=Path,
                        default=os.environ.get('MACOS_SIGNING_KEYCHAIN'))
    args = parser.parse_args()
    if bool(args.macos_signing_identity) != bool(args.macos_notary_profile) or (args.macos_signing_keychain and not args.macos_signing_identity):
        parser.error('Developer ID identity and notary profile must be supplied together')
    if not re.fullmatch(r'[0-9]{8}\.[0-9]+', args.release_id):
        parser.error('release-id must be YYYYMMDD.N')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', args.engine_version):
        parser.error('engine-version must be X.Y.Z')
    if sys.platform != 'darwin':
        parser.error('macOS is required to sign the macOS preview package')
    components = {'windows': args.windows_runtime_component, 'macos': args.macos_runtime_component}
    if any(components.values()) and not all(components.values()):
        parser.error('an extended-runtime release requires qualified components for both platforms')
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    builds = []
    payload_hash = None
    with tempfile.TemporaryDirectory(prefix='native-release-') as temporary:
        work = Path(temporary)
        for platform, runtime in RUNTIMES.items():
            archive = work / (platform + '-runtime.zip')
            fetch_runtime(runtime['id'], archive)
            if digest(archive) != runtime['sha256']:
                raise ValueError('Official runtime digest mismatch: ' + platform)
            package = work / platform
            command = [sys.executable, str(ROOT / 'tools/build_native_preview.py'),
                            '--platform', platform, '--runtime', str(archive),
                            '--source-ref', source, '--release-id', args.release_id,
                            '--engine-version', args.engine_version, '--out', str(package)]
            if components[platform]:
                command.extend(['--qualified-runtime', str(components[platform].resolve())])
            if platform == 'macos' and args.macos_signing_identity:
                command.extend(['--macos-signing-identity', args.macos_signing_identity,
                                '--macos-notary-profile', args.macos_notary_profile])
                if args.macos_signing_keychain:
                    command.extend(['--macos-signing-keychain', str(args.macos_signing_keychain.resolve())])
            subprocess.run(command, cwd=ROOT, check=True)
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
    runtime_notes = (
        'The experimental extended-upvalue LuaJIT is bundled on Windows x64 and both Mac\n'
        'architectures. Native closure/C API/engine and actual LOVE host/thread/FFI\n'
        'qualification receipts accompany the packages. This does not establish complete\n'
        'mod/gameplay or Windows GPU acceptance. The standalone .love needs this\n'
        'extended runtime for mods which exceed the official 60-upvalue limit.\n'
        if all(components.values()) else
        'The experimental extended-upvalue LuaJIT is NOT bundled. Mods that exceed the\n'
        'official runtime\'s capacity may still fail to load. Full-game 3D/mod compatibility\n'
        'and Windows/macOS hardware acceptance are not claimed by this intermediate build.\n')
    if all(components.values()):
        mac = next(row for row in builds if row['platform'] == 'macos')
        runtime_notes += 'The qualified Mac package requires macOS ' + mac['qualifiedRuntime']['minimumMacOS'] + ' or newer.\n'
    mac = next(row for row in builds if row['platform'] == 'macos')
    mac_notes = ('The macOS app is Developer ID signed, accepted by Apple notarization,\n'
                 'and carries a validated stapled ticket; Gatekeeper assessment passed.\n'
                 if mac['macosDistribution']['notarized'] else
                 'The macOS app is ad-hoc signed, without Apple notarization.\n'
                 'Downloaded copies may require a per-app approval in macOS Privacy & Security.\n')
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
Both ZIPs use official LOVE 12 revision {RUNTIME_COMMIT} as their base.
{mac_notes}
Import your own supported ROMs and save files. No ROMs, extracted game caches,
user saves, account credentials or mod packages are included. This preview
uses a separate Gen2Recomp-NativePreview-{args.release_id.replace('.', '-')} profile;
existing profiles are preserved and are not automatically migrated.

Known limits: exact mid-battle savestates/device handoff are still in development.
Normal save progress is supported; saving progress is not an execution snapshot.
{runtime_notes}

Validation: headless launcher contracts, package content checks, identical payload
hashes and SHA256SUMS.txt. No new in-game test was run for this release.
'''
    (out / 'README-Testrelease.txt').write_text(notes)
    files = sorted(out.iterdir())
    (out / 'SHA256SUMS.txt').write_text(''.join(digest(path) + '  ' + path.name + '\n' for path in files))
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
