#!/usr/bin/env python3
"""Run performance checks under shared QA storage leases and record results."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time
from qa_storage import qa_source, qa_cache, qa_profile, qa_run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--lua', default=os.environ.get('LUA', 'luajit'))
    parser.add_argument('--out', type=Path)
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--love', type=Path)
    parser.add_argument('--check', action='append', default=[])
    parser.add_argument('--matrix', action='store_true')
    parser.add_argument('--compat', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    runtime = shutil.which(args.lua)
    if not runtime:
        parser.error('LuaJIT executable not found: ' + args.lua)
    lua = str(Path(runtime).resolve())
    for path in (root, Path(lua), args.reference, args.love):
        if path:
            qa_source(path.resolve())
    out = (args.out or root / '.local/qa' / ('performance-' + str(time.time_ns()))).resolve()
    qa_cache(out)
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.pop('POKEPORT_PERF', None)
    results = []

    def fingerprint():
        paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard',
                                         '--', 'src', 'tools', 'tests', '.github', 'main.lua', 'conf.lua'], cwd=root).split(b'\0')
        digest = hashlib.sha256()
        for name in sorted(set(paths) - {b''}):
            digest.update(name + b'\0')
            path = root / os.fsdecode(name)
            digest.update(hashlib.sha256(path.read_bytes()).digest() if path.is_file() else b'deleted')
        return digest.hexdigest()

    source_hash = fingerprint()

    def run(label, cmd, spec=None, extra=None, timeout=600):
        child_env = dict(env, **(extra or {}))
        if spec is not None:
            child_env['POKEPORT_PERF'] = spec
        started = time.monotonic()
        try:
            p = qa_run(cmd, cwd=root, env=child_env, capture_output=True, text=True, timeout=timeout)
            code, log = p.returncode, p.stdout + p.stderr
        except subprocess.TimeoutExpired as exc:
            code, log = 124, 'Timed out: ' + str(exc)
        name = ('%03d-' % len(results)) + ''.join(c if c.isalnum() or c in '-_' else '_' for c in label)
        (out / (name + '.log')).write_text(log)
        results.append({'name': label, 'spec': spec, 'exit': code,
                        'wallSeconds': time.monotonic() - started,
                        'logSha256': hashlib.sha256(log.encode()).hexdigest()})
        print(('PASS ' if code == 0 else 'FAIL ') + label, flush=True)
        if code:
            print(log[-4000:], flush=True)
        return code, log

    for check in args.check:
        run(check, [lua, check])
    if args.matrix:
        code, output = run('list-switches', [lua, '-e', '''
local P=require('src.core.Performance');local t={}
for k,v in pairs(P) do if type(v)=='boolean' and k~='saver' then t[#t+1]=k end end
table.sort(t);print(table.concat(t,' '))'''])
        if not code:
            checks = shlex.split(os.environ.get('CHECKS', 'tests/engine/gate_hooks.lua tests/mod_examples_tests.lua tests/engine/performance_tiers.lua'))
            columns = [('defaults', None), ('all-on', 'all=1')]
            columns += [(s + '=0', s + '=0') for s in output.split()]
            columns += [('all-off', 'all=0')]
            for label, spec in columns:
                for check in checks:
                    run(label + ':' + check, [lua, check], spec)
    if args.compat:
        if not args.reference:
            parser.error('--compat requires --reference')
        for check in ('tests/mod_examples_tests.lua', 'tests/engine/gate_hooks.lua'):
            run(check, [lua, check])
        run('api3', [sys.executable, 'tools/api3-contract-check/check.py', '--gen1',
                     str(args.reference.resolve()), '--lua', lua, '--report', str(out / 'api3.json')])
        run('external-fixtures', [sys.executable, 'tools/check_external_mod_fixtures.py', '--reference',
                                 str(args.reference.resolve()), '--lua', lua, '--report', str(out / 'fixtures.json')])
    if args.love:
        identity = 'oasc-perf-qa-' + str(time.time_ns())
        qa_profile(Path.home() / 'Library/Application Support/LOVE' / identity)
        run('rendering-host', [str(args.love.resolve()), str(root / 'tools/performance-rendering/host')],
            extra={'POKEPORT_IDENTITY': identity, 'POKEPORT_GRAPHICS_BACKEND': 'metal',
                   'BATTLE_SOURCE_ENGINE': str(root), 'BATTLE_SOURCE_REPORT': str(out / 'gpu.json')}, timeout=90)
    stable = fingerprint() == source_hash
    report = {'passed': bool(results) and stable and all(r['exit'] == 0 for r in results),
              'sourceStable': stable, 'sourceSha256': source_hash,
              'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'results': results}
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
