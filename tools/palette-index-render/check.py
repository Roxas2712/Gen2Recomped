#!/usr/bin/env python3
"""Guarded palette-index qualification, using explicit runtimes and reference."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from qa_storage import qa_source, qa_cache, qa_profile, qa_run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--love', type=Path, required=True)
    parser.add_argument('--lua', type=Path, required=True, help='LuaJIT CLI executable')
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    for path in (ROOT, args.love, args.lua, args.reference):
        qa_source(path.resolve())
    out = args.out.resolve()
    qa_cache(out)
    out.mkdir(parents=True, exist_ok=True)
    adapter = args.lua.resolve()
    env = dict(os.environ)
    watched = [ROOT / p for p in ('src/core/FrameProfile.lua', 'src/render/SpriteRenderer.lua',
               'src/render/TileRenderer.lua', 'tools/palette-index-render/host/main.lua')]
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in watched}
    results = []

    def run(name, command, extra=None, timeout=300):
        result = qa_run(command, cwd=ROOT, env=dict(env, **(extra or {})),
                        capture_output=True, text=True, timeout=timeout)
        log = result.stdout + result.stderr
        (out / (name + '.log')).write_text(log)
        row = {'name': name, 'exit': result.returncode,
               'logSha256': hashlib.sha256(log.encode()).hexdigest()}
        results.append(row)
        print(('PASS ' if result.returncode == 0 else 'FAIL ') + name, flush=True)
        return result

    run('inventory', [sys.executable, str(Path(__file__).with_name('inventory.py')), '--check'])
    for name in ('palette_bake_profile', 'gen2_display_modes', 'gen2_palette_context', 'palette_zone_cache'):
        run(name, [str(adapter), 'tests/engine/' + name + '.lua'])
    run('mod_examples', [str(adapter), 'tests/mod_examples_tests.lua'])
    run('gen3_palette_index', [str(adapter), 'tools/gen3_palette_index_check.lua'])
    run('api3', [sys.executable, 'tools/api3-contract-check/check.py', '--gen1',
                str(args.reference.resolve()), '--lua', str(adapter), '--report', str(out / 'api3.json')])
    run('external_fixtures', [sys.executable, 'tools/check_external_mod_fixtures.py',
                            '--reference', str(args.reference.resolve()), '--lua', str(adapter),
                            '--report', str(out / 'fixtures.json')])
    identity = 'oasc-palette-index-qa-' + str(time.time_ns())
    qa_profile(Path.home() / 'Library/Application Support/LOVE' / identity)
    gpu = run('palette_gpu', [str(args.love.resolve()), str(Path(__file__).parent / 'host')], {
        'PALETTE_INDEX_QA_GUARDED': '1', 'PALETTE_INDEX_QA_ROOT': str(ROOT),
        'POKEPORT_IDENTITY': identity,
    }, timeout=90)
    gpu_rows = [line.removeprefix('PALETTE_INDEX_GPU_RESULT ') for line in gpu.stdout.splitlines()
                if line.startswith('PALETTE_INDEX_GPU_RESULT ')]
    stable = all(hashlib.sha256(p.read_bytes()).hexdigest() == hashes[str(p.relative_to(ROOT))] for p in watched)
    report = {'passed': all(r['exit'] == 0 for r in results) and stable and len(gpu_rows) == 1,
              'sourceSha256': hashes, 'sourceStable': stable, 'results': results,
              'gpu': json.loads(gpu_rows[0]) if len(gpu_rows) == 1 else None,
              'realSceneAcceptance': False, 'playerProfilesUsed': False}
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
