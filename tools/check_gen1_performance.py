"""Qualify the Gen1 performance transfers without ROMs or player profiles."""
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time
import qa_storage as qa

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lua', default=shutil.which('luajit'))
parser.add_argument('--love', type=Path)
parser.add_argument('--full', action='store_true')
parser.add_argument('--out', type=Path)
args = parser.parse_args()
if not args.lua:
    parser.error('--lua must name an existing LuaJIT interpreter')
qa._storage = qa.Storage(root)
atexit.register(qa._storage.close)
for path in (root, Path(args.lua).resolve(), args.love):
    if path:
        qa.qa_source(path)
out = (args.out or root / '.local/qa' / ('gen1-performance-' + str(time.time_ns()))).resolve()
qa.qa_cache(out)
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
env.pop('POKEPORT_PERF', None)
results = []
def fingerprints():
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for directory in ('src', 'tests', 'tools')
            for p in sorted((root / directory).rglob('*'))
            if p.is_file() and p.suffix in ('.lua', '.py')}
hashes = fingerprints()
(out / 'source-hashes.json').write_text(json.dumps(hashes, sort_keys=True))

def run(name, command, extra=None, timeout=600):
    start = time.monotonic()
    log = out / (name + '.log')
    with log.open('w') as stream:
        try:
            p = qa.qa_run(command, cwd=root, env=dict(env, **(extra or {})),
                          stdout=stream, stderr=stream, timeout=timeout)
            code = p.returncode
        except Exception as exc:
            stream.write(str(exc) + '\n')
            code = 1
    results.append(dict(name=name, passed=code == 0, seconds=time.monotonic()-start,
                        log=str(log.relative_to(out))))
    print(('PASS ' if code == 0 else 'FAIL ') + name, flush=True)
    if code:
        print(log.read_text()[-4000:], flush=True)
    (out / 'result.json').write_text(json.dumps(dict(passed=all(r['passed'] for r in results), results=results), indent=2))

suites = ['tests/engine/audio_priority_prewarm.lua', 'tests/engine/gb_asset_prefetch.lua',
          'tests/engine/rs_healthbox_contract.lua', 'tests/engine/rs_battle_panel_contract.lua',
          'tools/assets_shared_decode_check.lua', 'tools/asset_resolve_cache_check.lua',
          'tools/build_worker_check.lua', 'tools/shade_recolour_check.lua',
          'tools/perf_env_check.lua', 'tests/engine/gen2_sfx_arbitration.lua',
          'tests/engine/gen3_audio_prep.lua']
for path in suites:
    run(Path(path).stem, [args.lua, path])
if args.love:
    identity = 'oasc-gen2-qa-gen1-performance-' + str(time.time_ns())
    profile = Path.home() / 'Library/Application Support/LOVE' / identity
    qa.qa_profile(profile)
    run('native-pixels-worker', [str(args.love), str(root / 'tools/gb-prefetch-check/host')],
        dict(GEN1_PERF_ROOT=str(root), GEN1_PERF_GUARDED='1', POKEPORT_IDENTITY=identity), 90)
if args.full and all(r['passed'] for r in results):
    run('all-rom-free-tiers', ['bash', 'scripts/test.sh', '--quick'], dict(LUA=args.lua), 3600)
if args.love and all(r['passed'] for r in results):
    run('native-audio-worker', [sys.executable, str(root / 'tools/check_audio_profile.py'),
        '--love', str(args.love), '--report', str(out / 'audio.json')], timeout=180)
if hashes != fingerprints():
    raise RuntimeError('Sources changed during qualification; preserve logs and rerun')
print(out / 'result.json', flush=True)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
