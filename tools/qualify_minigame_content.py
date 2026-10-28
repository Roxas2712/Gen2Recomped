#!/usr/bin/env python3
"""Guarded local-content/gate/rules/profile/locale qualification; no live service."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua-library', type=Path, required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    assert args.label.replace('-', '').isalnum()
    import qa_storage as qa
    qa._storage = qa.Storage(ROOT)
    atexit.register(qa._storage.close, collect=False)
    for path in (ROOT, args.lua_library, Path(sys.executable)):
        qa.qa_source(path.resolve())
    output = ROOT / '.local/qa' / ('minigame-content-checks-' + args.label)
    qa.qa_cache(output)
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / 'tests.log'
    assert not log_path.exists(), 'Preserve prior evidence'
    env = os.environ | {'RETRO_QA_LUA_LIBRARY': str(args.lua_library.resolve())}
    suites = ['tests/engine/minigame_content.lua', 'tests/engine/minigame_enrollment.lua',
              'tests/engine/account_profiles.lua', 'tools/walker_minigames_check.lua',
              'tests/engine/walker_cloud.lua', 'tests/engine/launcher_locale.lua']
    # Isolate each suite: some older test helpers exit their VM process.
    with log_path.open('w') as log:
        syntax = [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'src/pokewalker/minigames').glob('*.lua'))]
        command = [sys.executable, 'tools/run_lua_batch.py']
        for path in syntax:
            command += ['--syntax', path]
        commands = [command] + [[sys.executable, 'tools/run_lua_batch.py', '--suite', suite] for suite in suites]
        commands += [[sys.executable, 'tools/check_launcher_locale.py']]
        for command in commands:
            print('Running ' + command[-1], flush=True)
            result = qa.qa_run(command, cwd=ROOT, env=env, capture_output=True, text=True)
            log.write('COMMAND ' + ' '.join(command) + '\n' + result.stdout + result.stderr + '\n')
            log.flush()
            print(result.stdout + result.stderr, end='', flush=True)
            if result.returncode:
                raise SystemExit(result.returncode)
    print(output, flush=True)


if __name__ == '__main__':
    main()
