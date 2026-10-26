"""Run focused language regressions without launching or copying a game."""
import argparse
import atexit
import hashlib
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
helper = Path.home() / '.local/lib/origami-qa-storage/active-tools'
if helper.exists():
    sys.path.insert(0, str(helper))
import qa_storage
qa_storage._storage = qa_storage.Storage(ROOT)
atexit.register(qa_storage._storage.close)
from qa_storage import qa_source, qa_cache, qa_run


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--luajit', type=Path, required=True)
    p.add_argument('--mod', type=Path)
    p.add_argument('--imports', type=Path)
    p.add_argument('--focused', action='store_true', help='skip the full engine suite')
    args = p.parse_args()
    for path in (ROOT, args.luajit, args.mod, args.imports):
        if path:
            qa_source(path)
    out = ROOT / '.local/qa/language-findings'
    qa_cache(out)
    out.mkdir(parents=True, exist_ok=True)
    scripts = ['tests/engine/rom_language_pack.lua',
               'tests/engine/native_language_import_publication.lua',
               'tests/engine/native_cache_openfile.lua',
               'tests/engine/unified_move_effects.lua']
    if not args.focused:
        scripts.append('tests/run_engine.lua')
    jobs = [(s, []) for s in scripts]
    if args.mod or args.imports:
        assert args.mod and args.imports, '--mod and --imports must be supplied together'
        hashes = {'firered': '51ab6d001412cdc3d6da16fb824ab8084123b1dd',
                  'leafgreen': 'b32c63d5d1454d851cef16699f3ce757798553a2'}
        for game, sha1 in hashes.items():
            assert hashlib.sha1((args.imports / f'{game}_ptbr.gba').read_bytes()).hexdigest() == sha1
        jobs.append(('tests/drivers/native_dex_layout_sources.lua',
                     [str(args.mod.resolve()), str(args.imports.resolve())]))
    for script, extra in jobs:
        result = qa_run([str(args.luajit), script, *extra], cwd=ROOT,
                        capture_output=True, text=True, timeout=900)
        (out / (Path(script).stem + '.log')).write_text(result.stdout + result.stderr)
        print(script, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
        if result.returncode:
            print(result.stdout[-2500:] + result.stderr[-2500:])
            raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
