"""Compare native numeric fixed-damage commands against a clean, read-only Gen1 checkout."""
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
MODES = ('single', 'right', 'right-empty-left')
POLICIES = ('delegate', 'amount-only')
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-root', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--lua', type=Path, default=shutil.which('luajit'))
parser.add_argument('--qa-tools-root', type=Path, default=ROOT / 'tools')
parser.add_argument('--edition', action='append', choices=EDITIONS)
parser.add_argument('--mode', action='append', choices=MODES)
parser.add_argument('--policy', action='append', choices=POLICIES)
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
def source_patch():
    return run(['git', '-C', str(ROOT), 'diff', '--binary', 'HEAD'], text=True,
               stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout


source_diff = source_patch()
(args.output / 'source.patch').write_text(source_diff)
report = dict(status='running', inputs=hashes, source=git(ROOT, 'rev-parse', 'HEAD'),
              source_patch_sha256=sha(args.output / 'source.patch'),
              editions=args.edition or EDITIONS, modes=args.mode or MODES, policies=args.policy or POLICIES,
              reference_source=git(ref, 'rev-parse', 'HEAD'), runs=[], pairs=[],
              scope='Four native fixed-damage scripts selected by actual imported effect bytes, '
                    'numeric MOVE IDs, singles/right doubles/absent flank, public calculation and '
                    'damage-event boundaries, amount-only hook fallback and received-hit history. '
                    'Core comparison excludes only the full raw RNG stream, which is retained and '
                    'independently compared. R/S post-hit chance-opcode and immune Focus Band command '
                    'differences remain open; no complete battle RNG/full-ROM/whole-mod claim.')
report_path = args.output / 'report.json'


def save():
    temporary=report_path.with_suffix('.tmp')
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(report_path)


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
    for mode,policy in __import__('itertools').product(args.mode or MODES,args.policy or POLICIES):
        pair = []
        worker = ROOT / 'tests/gen3_fixed_damage/worker.lua'
        for backend, cwd in (('gen1', ref), ('gen2', ROOT)):
            label = '-'.join((edition, mode, policy, backend))
            log = args.output / (label + '.log')
            with log.open('w') as stream:
                try:
                    result = run([*prefix, str(args.lua.resolve()), str(worker), str(ROOT),
                                  backend, edition, mode, policy], cwd=cwd, env=env, stdout=stream,
                                 stderr=subprocess.STDOUT, timeout=180)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            output = log.read_text(errors='replace')
            records = [line.removeprefix('GBA_FIXED_DAMAGE ') for line in output.splitlines()
                       if line.startswith('GBA_FIXED_DAMAGE ')]
            row = dict(label=label, exit=code, log=log.name, log_sha256=sha(log),
                       rows=json.loads(records[0]) if len(records) == 1 else None)
            report['runs'].append(row)
            pair.append(row)
            save()
            if code:
                print(label, code, output[-2500:], flush=True)
        projection=lambda row: [{key:value for key,value in case.items() if key!='rng'}
                                for case in row['rows']] if row['rows'] is not None else None
        same=pair[0]['rows'] is not None and equal(projection(pair[0]),projection(pair[1]))
        raw_differences=[]
        core_differences=[]
        if pair[0]['rows'] is not None and pair[1]['rows'] is not None:
            for left,right in zip(pair[0]['rows'],pair[1]['rows']):
                if not equal(left['rng'],right['rng']): raw_differences.append(left['case'])
                if not equal({k:v for k,v in left.items()if k!='rng'},
                             {k:v for k,v in right.items()if k!='rng'}):
                    core_differences.append(left['case'])
        report['pairs'].append(dict(label='-'.join((edition,mode,policy)),equal=same,
                                    core_differences=core_differences,
                                    raw_rng_differences=raw_differences))
        save()
        print(edition,mode,policy,'core',same,'raw RNG differences',len(raw_differences),flush=True)
report.update(status='terminal', inputs_unchanged=all(sha(Path(p)) == h for p, h in hashes.items()),
              source_unchanged=git(ROOT, 'rev-parse', 'HEAD') == report['source'],
              source_diff_unchanged=source_patch() == source_diff,
              reference_clean=not git(ref, 'status', '--porcelain'),
              reference_unchanged=git(ref, 'rev-parse', 'HEAD') == report['reference_source'])
report['passed'] = (report['inputs_unchanged'] and report['source_unchanged'] and report['source_diff_unchanged']
                    and report['reference_clean'] and report['reference_unchanged']
                    and all(v['exit'] == 0 and v['rows'] for v in report['runs'])
                    and all(v['equal'] for v in report['pairs']))
save()
print('FINAL', report['passed'], flush=True)
sys.exit(not report['passed'])
