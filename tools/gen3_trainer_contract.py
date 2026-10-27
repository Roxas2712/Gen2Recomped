"""Compare native trainer controllers against a clean, read-only Gen1 checkout."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EDITIONS = ('firered', 'leafgreen', 'ruby', 'sapphire', 'emerald')
MODES = ('single', 'double-left', 'double-right', 'two-trainer-right', 'two-trainer-right-empty-left')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-root', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--lua', type=Path, default=shutil.which('luajit'))
parser.add_argument('--qa-tools-root', type=Path, default=ROOT / 'tools')
parser.add_argument('--edition', action='append', choices=EDITIONS)
parser.add_argument('--mode', action='append', choices=MODES)
args = parser.parse_args()
ref = args.reference_root.resolve()
if not args.lua or not args.lua.is_file():
    parser.error('--lua must select an existing LuaJIT executable')
if args.output.exists():
    parser.error('--output must be a new directory')

inputs = {Path(__file__).resolve(), args.qa_tools_root / 'qa_storage.py'}
for folder in [*[ROOT / p for p in ('src', 'tests', 'data', 'examples/portable_enemy_action')],
               ref / 'src', ref / 'tests', ref / 'data']:
    inputs.update(p for p in folder.rglob('*') if p.is_file() and p.suffix in {'.lua', '.json', '.png', '.bin'})
run = subprocess.run
if os.name != 'nt' and not os.getenv('GITHUB_ACTIONS'):
    sys.path.insert(0, str(args.qa_tools_root.resolve()))
    from qa_storage import qa_source, qa_cache, qa_run
    # Pin source scopes once, while independently hashing every actual input.
    for scope in (ROOT, ref, args.lua.resolve(), Path(sys.executable), args.qa_tools_root.resolve()):
        qa_source(scope)
    qa_cache(args.output)
    run = qa_run


def git(root, *argv):
    return run(['git', '-C', str(root), *argv], text=True, stdout=subprocess.PIPE,
               stderr=subprocess.PIPE, check=True).stdout.strip()


if git(ref, 'status', '--porcelain'):
    parser.error('the reference checkout must be clean and stays read-only')
args.output.mkdir(parents=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
hashes = {str(p): sha(p) for p in sorted(inputs)}
report = dict(status='running', inputs=hashes, source=git(ROOT, 'rev-parse', 'HEAD'),
              reference_source=git(ref, 'rev-parse', 'HEAD'), runs=[], pairs=[],
              scope='Actual API3 unified native enemy controllers. Class/brain priority, error recovery, '
                    'per-mon use budgets, native slot execution and subsequent decisions. '
                    'Switch slots and PP-slot ownership are canonical projections of each engine action; '
                    'party nicknames are explicitly identical before observations. '
                    'This does not qualify default autonomous switch heuristics, full Loader rollback, '
                    'link routing, complete item presentation or whole-mod gameplay.')
report_path = args.output / 'report.json'


def save():
    report_path.write_text(json.dumps(report, indent=2) + '\n')


def equal(a, b):
    if type(a) is not type(b):
        return False
    if isinstance(a, dict):
        return a.keys() == b.keys() and all(equal(a[k], b[k]) for k in a)
    if isinstance(a, list):
        return len(a) == len(b) and all(equal(x, y) for x, y in zip(a, b))
    return a == b


save()
env = dict(os.environ, POKEPORT_ISOLATED_TESTING='1', POKEPORT_SKIP_LEGACY_MIGRATION='1')
prefix = ['nice', '-n', '19'] if os.name != 'nt' else []
for edition in args.edition or EDITIONS:
    for mode in args.mode or MODES:
        for family, filename, marker in (
            ('gates', 'worker.lua', 'GBA_TRAINER_GATES '),
            ('switch', 'switch_worker.lua', 'GBA_TRAINER_SWITCH '),
        ):
            pair = []
            worker = ROOT / 'tests/gen3_trainer_gates' / filename
            for backend, cwd in (('gen1', ref), ('gen2', ROOT)):
                label = '-'.join((edition, mode, family, backend))
                log = args.output / (label + '.log')
                with log.open('w') as stream:
                    try:
                        result = run([*prefix, str(args.lua.resolve()), str(worker), str(ROOT),
                                      backend, edition, mode], cwd=cwd, env=env, stdout=stream,
                                     stderr=subprocess.STDOUT, timeout=180)
                        code = result.returncode
                    except subprocess.TimeoutExpired:
                        code = 124
                output = log.read_text(errors='replace')
                records = [line.removeprefix(marker) for line in output.splitlines() if line.startswith(marker)]
                row = dict(label=label, exit=code, log=log.name, log_sha256=sha(log),
                           rows=json.loads(records[0]) if len(records) == 1 else None)
                report['runs'].append(row)
                pair.append(row)
                save()
                if code:
                    print(label, code, output[-2500:], flush=True)
            report['pairs'].append(dict(label='-'.join((edition, mode, family)),
                                        equal=pair[0]['rows'] is not None and equal(pair[0]['rows'], pair[1]['rows'])))
            save()
        print(edition, mode, 'complete', flush=True)
report.update(status='terminal', inputs_unchanged=all(sha(Path(p)) == h for p, h in hashes.items()),
              source_unchanged=git(ROOT, 'rev-parse', 'HEAD') == report['source'],
              reference_clean=not git(ref, 'status', '--porcelain'),
              reference_unchanged=git(ref, 'rev-parse', 'HEAD') == report['reference_source'])
report['passed'] = (report['inputs_unchanged'] and report['source_unchanged']
                    and report['reference_clean'] and report['reference_unchanged']
                    and all(v['exit'] == 0 and v['rows'] for v in report['runs'])
                    and all(v['equal'] for v in report['pairs']))
save()
print('FINAL', report['passed'], flush=True)
sys.exit(not report['passed'])
