#!/usr/bin/env python3
"""ROM-free X/Y import, mod and launcher checks; optional native layout ABI checks."""
import argparse
import atexit
import json
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
installed = Path.home() / '.local/lib/origami-qa-storage/active-tools'
sys.path.insert(0, str(installed if installed.is_dir() else ROOT / 'tools'))
import qa_storage as qa


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bridge', type=Path, help='Existing reviewed native bridge; never builds or starts a game.')
    args = parser.parse_args()
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close)
    qa.qa_source(ROOT)
    runtimes = [shutil.which('luajit'), shutil.which('lua5.4') or shutil.which('lua')]
    if not all(runtimes):
        parser.error('LuaJIT and Lua 5.4 (for the standalone UTF-8 keyboard check) are required.')
    for source in [sys.executable, *runtimes]:
        qa.qa_source(source)
    if args.bridge:
        args.bridge = args.bridge.resolve(strict=True)
        qa.qa_source(args.bridge)
    cache = ROOT / '.local/qa/pokemon-xy-contract'
    qa.qa_cache(cache)
    cache.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, POKEMON_X_TEST_TMP=str(cache))
    if args.bridge:
        env['POKEMON_XY_BRIDGE'] = str(args.bridge)
    suites = [('python', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'pokemon*test.py'])]
    files = list((ROOT / 'src/import').glob('*PokemonXY*.lua')) + list((ROOT / 'src/import').glob('pokemon_xy*worker.lua'))
    syntax = ';'.join('assert(loadfile(' + json.dumps(str(p)) + '))' for p in sorted(files))
    suites.append(('syntax', [runtimes[0], '-e', syntax]))
    for suite in ['launcher_sequence', 'pokemon_xy_presentation', 'pokemon_xy_language']:
        suites.append((suite, [runtimes[0], str(ROOT / 'tests/engine' / (suite + '.lua'))]))
    suites.append(('pokemon_xy_keyboard', [runtimes[1], str(ROOT / 'tests/pokemon_xy/keyboard.lua')]))
    if args.bridge:
        suites.append(('pokemon_xy_controls', [runtimes[0], str(ROOT / 'tests/pokemon_xy/controls.lua')]))
    for name, command in suites:
        result = qa.qa_run(command, cwd=ROOT, env=env, capture_output=True, text=True)
        output = result.stdout + result.stderr
        (cache / (name + '.log')).write_text(output)
        print(name + ':\n' + output, flush=True)
        if result.returncode:
            return result.returncode
    print(json.dumps({'passed': True, 'suites': len(suites), 'native_layout_checked': bool(args.bridge)}), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
