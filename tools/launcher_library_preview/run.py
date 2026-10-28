"""Open a layout fixture or an isolated, genuinely playable launcher demo."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from qa_storage import qa_cache, qa_copy, qa_profile, qa_run, qa_source


def seed_cache(original, destination):
    """Only extracted game data; never saves, credentials, options, or mods."""
    versions = ('', 'blue', 'yellow', 'gold', 'silver', 'crystal', 'firered',
                'emerald', 'platinum', 'heartgold', 'soulsilver', 'black', 'white',
                'prism', 'polishedcrystal')
    copied = []
    for version in versions:
        source = original / version
        marker = source / 'rom-cache.complete'
        if not marker.is_file():
            continue
        target = destination / version
        target.mkdir(parents=True, exist_ok=True)
        if (target / 'rom-cache.complete').is_file() and (target / 'rom-cache.complete').read_bytes() == marker.read_bytes():
            continue
        for name in ('data', 'assets'):
            if not (source / name).is_dir():
                continue
            if sys.platform == 'darwin':
                qa_run(['cp', '-cR', str(source / name), str(target)], check=True)
            else:
                shutil.copytree(source / name, target / name, dirs_exist_ok=True)
        shutil.copy2(marker, target / marker.name)
        copied.append(version or 'red')
    return copied


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', default='love', help='Path to the LOVE executable')
    parser.add_argument('--playable', action='store_true', help='Use the actual game bootstrap and Play callback')
    parser.add_argument('--identity', default='RetroRecomped-playable-demo')
    parser.add_argument('--seed-from', type=Path, help='Existing LOVE data folder; copies extracted data only')
    parser.add_argument('--timeout', type=float, help='Stop this demo after this many seconds')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{3,80}', args.identity) or args.identity in ('Gen2Recomp', 'pokemon-love2d'):
        parser.error('Use a separate, simple demo identity.')
    here = Path(__file__).resolve().parent
    root = here.parent.parent
    qa_source(root)
    for key in ('LIBRARY_PREVIEW_CATALOGUE', 'LIBRARY_PREVIEW_THUMBNAILS', 'LIBRARY_PREVIEW_XY_FILE'):
        if os.getenv(key):
            qa_source(Path(os.environ[key]))
    executable = shutil.which(args.love)
    if executable:
        qa_source(Path(executable).resolve())
        runtime_bundle = next((p for p in Path(executable).resolve().parents if p.suffix == '.app'), None)
        if runtime_bundle:
            qa_source(runtime_bundle)
    if args.seed_from:
        qa_source(args.seed_from)
    identity = args.identity if args.playable else ('oasc-retro-launcher-qa-smoke' if os.getenv('LIBRARY_PREVIEW_SMOKE') == '1' else 'oasc-retro-launcher-qa-layout')
    if sys.platform == 'darwin':
        profile = Path.home() / 'Library/Application Support/LOVE' / identity
        qa_source(profile)
        qa_profile(profile)
    for key in ('LIBRARY_PREVIEW_OUT', 'LIBRARY_PREVIEW_FRAMES'):
        if os.getenv(key):
            qa_cache(Path(os.environ[key]))
    env = dict(os.environ, LIBRARY_PREVIEW_ROOT=str(root))
    # The shared QA manager preserves wrapper sources before collecting this
    # disposable copy. Real imports, save profiles and source checkouts stay pinned.
    source = root / '.local/qa' / ('retro-launcher-%d-%d' % (time.time_ns(), os.getpid())) / 'unit'
    qa_copy(source)
    qa_cache(source.parent)
    source.mkdir(parents=True)
    try:
        # A distributed LOVE app always prefers its embedded game.love over
        # a directory argument. Use a private runtime copy for layout QA.
        if executable and runtime_bundle and (runtime_bundle / 'Contents/Resources/game.love').is_file():
            runtime_copy = source / 'runtime/PreviewRuntime.app'
            runtime_copy.parent.mkdir()
            qa_run(['cp', '-cR', str(runtime_bundle), str(runtime_copy)], check=True)
            (runtime_copy / 'Contents/Resources/game.love').unlink()
            qa_run(['codesign', '--force', '--deep', '--sign', '-', str(runtime_copy)], check=True)
            args.love = str(runtime_copy / 'Contents/MacOS' / Path(executable).name)
        for name in ('src', 'data', 'assets', 'mods', 'tools'):
            if (root / name).exists():
                (source / name).symlink_to(root / name, target_is_directory=True)
        if args.playable:
            for key in ('POKEPORT_DRIVER', 'POKEPORT_AUTOPILOT', 'POKEPORT_IMPORT_ONLY', 'POKEPORT_IMPORT_ROM',
                        'POKEPORT_FORCE_IMPORT', 'POKEPORT_PORTABLE', 'POKEPORT_EDITOR', 'POKEPORT_DEV'):
                env.pop(key, None)
            env['POKEPORT_IDENTITY'] = args.identity
            if args.seed_from:
                if sys.platform != 'darwin':
                    parser.error('--seed-from currently supports the macOS LOVE data directory.')
                destination = Path.home() / 'Library/Application Support/LOVE' / args.identity
                if destination.resolve() == args.seed_from.resolve():
                    parser.error('The demo must not use the real game directory.')
                print('Extracted game caches copied:', ', '.join(seed_cache(args.seed_from, destination)) or 'already available', flush=True)
            shutil.copy2(root / 'conf.lua', source / 'conf.lua')
            (source / 'main.lua').write_text("""-- Demo isolation: no legacy or other-location save adoption.
require('src.core.SaveIdentity').migrateLegacy=function() return 0 end
require('src.core.SaveData').otherLocations=function() return {} end
local chunk=assert(love.filesystem.load('game-main.lua'));chunk()
""")
            shutil.copy2(root / 'main.lua', source / 'game-main.lua')
        else:
            for name in ('main.lua', 'conf.lua'):
                shutil.copy2(here / name, source / name)
        return qa_run([args.love, str(source)], cwd=root, env=env, timeout=args.timeout).returncode
    except subprocess.TimeoutExpired:
        print('Demo stopped at its requested time limit.', file=sys.stderr)
        return 124


if __name__ == '__main__':
    raise SystemExit(main())
