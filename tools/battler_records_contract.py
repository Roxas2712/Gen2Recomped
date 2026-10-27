"""Compare API-3 battler callbacks against a clean, read-only Gen1 checkout."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EDITIONS = ('red', 'gold', 'firered', 'leafgreen', 'emerald', 'ruby', 'sapphire')
GBA = EDITIONS[2:]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference-root', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--lua', type=Path, default=shutil.which('luajit'))
installed = Path.home() / '.local/lib/origami-qa-storage/active-tools'
p.add_argument('--qa-tools-root', type=Path, default=installed if installed.is_dir() else ROOT / 'tools')
p.add_argument('--qa-project-root', type=Path, default=ROOT)
p.add_argument('--edition', action='append', choices=EDITIONS)
a = p.parse_args()
if not a.lua or not a.lua.is_file():
    p.error('--lua must select an existing LuaJIT executable')
if a.output.exists():
    p.error('--output must be a new directory')
ref = a.reference_root.resolve()
sys.path.insert(0, str(a.qa_tools_root.resolve()))
import qa_storage as qa
qa._storage = qa.Storage(a.qa_project_root.resolve())
atexit.register(qa._storage.close)
for scope in [ROOT, ref, a.lua.resolve(), Path(sys.executable), a.qa_tools_root.resolve()]:
    qa.qa_source(scope)
qa.qa_cache(a.output)
a.output.mkdir(parents=True)
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
inputs = {Path(__file__).resolve(), a.qa_tools_root / 'qa_storage.py'}
for folder in [*[ROOT / path for path in ('src', 'tests', 'data', 'examples/portable_enemy_action')],
               ref / 'src', ref / 'tests', ref / 'data']:
    inputs.update(path for path in folder.rglob('*') if path.is_file() and path.suffix in {'.lua', '.json', '.png', '.bin'})
hashes = {str(path): sha(path) for path in sorted(inputs)}

def git(root, *args):
    return qa.qa_run(['git', '-C', str(root), *args], capture_output=True, check=True).stdout

if git(ref, 'status', '--porcelain').strip():
    p.error('the reference checkout must be clean and stays read-only')
source, reference = git(ROOT, 'rev-parse', 'HEAD'), git(ref, 'rev-parse', 'HEAD')
patch = git(ROOT, 'diff', '--binary', 'HEAD')
(a.output / 'source.patch').write_bytes(patch)
report = dict(status='running', source=source.decode().strip(), reference_source=reference.decode().strip(),
              source_patch_sha256=hashlib.sha256(patch).hexdigest(), inputs=hashes, runs=[], pairs=[],
              scope='API3 field/alias reads, authored native writes, chained snapshots, failure ownership and '
                    'detached real faint notifications. GBA calculation/HP are also required to match. '
                    'GB/Gold calculation differences are retained separately, not asserted as battle parity. '
                    'GBA raw RNG is checked independently; only one exactly trailing R/S chance draw is admitted. '
                    'No complete native battle, import, whole-mod or gameplay acceptance is claimed.')

def save():
    temp = a.output / 'report.tmp'
    temp.write_text(json.dumps(report, indent=2) + '\n')
    temp.replace(a.output / 'report.json')

def same(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same(value, right[key]) for key, value in left.items())
    if isinstance(left, list):
        return len(left) == len(right) and all(same(x, y) for x, y in zip(left, right))
    return left == right

save()
for edition in a.edition or EDITIONS:
    for mode in ('single', 'right') if edition in GBA else ('single',):
        workers = []
        for backend, cwd in [('gen1', ref), ('gen2', ROOT)]:
            label = edition + '-' + mode + '-' + backend
            log = a.output / (label + '.log')
            prefix = ['nice', '-n', '19'] if os.name != 'nt' else []
            with log.open('w') as stream:
                try:
                    result = qa.qa_run(prefix + [str(a.lua), str(ROOT / 'tests/battler_records/worker.lua'),
                                                str(ROOT), backend, edition, mode], cwd=cwd,
                                       env=dict(os.environ, POKEPORT_ISOLATED_TESTING='1', POKEPORT_SKIP_LEGACY_MIGRATION='1'),
                                       stdout=stream, stderr=subprocess.STDOUT, timeout=300)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            values = [json.loads(line.removeprefix('BATTLER_RECORDS_CONTRACT '))
                      for line in log.read_text(errors='replace').splitlines() if line.startswith('BATTLER_RECORDS_CONTRACT ')]
            row = dict(label=label, exit=code, rows=values[0] if len(values) == 1 else None,
                       log=log.name, log_sha256=sha(log))
            workers.append(row)
            report['runs'].append(row)
            save()
            print(label, code, 'rows', len(row['rows'] or []), flush=True)
        pair = dict(edition=edition, mode=mode, passed=False, cases=0, callback_mismatches=[],
                    native_math_mismatches=[], raw_rng_differences=[], unclassified_gba_rng=[])
        if all(worker['exit'] == 0 and len(worker['rows'] or []) == 18 for worker in workers):
            for left, right in zip(workers[0]['rows'], workers[1]['rows']):
                pair['cases'] += 1
                if left['profile'] != right['profile']:
                    pair['callback_mismatches'].append({'profile': left['profile'], 'field': 'profile'})
                for field in ['observations', 'notifications']:
                    if not same(left[field], right[field]):
                        pair['callback_mismatches'].append({'profile': left['profile'], 'field': field})
                for field in ['userHP', 'attack', 'status', 'pp']:
                    if not same(left['after'][field], right['after'][field]):
                        pair['callback_mismatches'].append({'profile': left['profile'], 'field': field})
                if not same(left['calculations'], right['calculations']) or not same(left['after']['targetHP'], right['after']['targetHP']):
                    pair['native_math_mismatches'].append(left['profile'])
                if not same(left['rng'], right['rng']):
                    pair['raw_rng_differences'].append(left['profile'])
                    trailing = (edition in ('ruby', 'sapphire') and len(left['rng']) == len(right['rng']) + 1
                                and same(left['rng'][:-1], right['rng'])
                                and same(left['rng'][-1], {'lo': 0, 'hi': 99, 'value': 0}))
                    if edition in GBA and not trailing:
                        pair['unclassified_gba_rng'].append(left['profile'])
            pair['passed'] = (not pair['callback_mismatches'] and not pair['unclassified_gba_rng']
                              and (edition not in GBA or not pair['native_math_mismatches']))
        report['pairs'].append(pair)
        save()
        print('PAIR', edition, mode, pair['passed'], 'callback mismatches', len(pair['callback_mismatches']),
              'native math differences', len(pair['native_math_mismatches']), 'raw RNG differences', len(pair['raw_rng_differences']), flush=True)
report.update(status='terminal', inputs_unchanged=all(sha(Path(path)) == digest for path, digest in hashes.items()),
              source_unchanged=git(ROOT, 'rev-parse', 'HEAD') == source,
              source_patch_unchanged=git(ROOT, 'diff', '--binary', 'HEAD') == patch,
              reference_clean=not git(ref, 'status', '--porcelain').strip(),
              reference_unchanged=git(ref, 'rev-parse', 'HEAD') == reference)
report['passed'] = all(report[key] for key in ('inputs_unchanged', 'source_unchanged', 'source_patch_unchanged', 'reference_clean', 'reference_unchanged')) and all(pair['passed'] for pair in report['pairs'])
report['gba_full_raw_rng_equal'] = report['passed'] and all(not pair['raw_rng_differences'] for pair in report['pairs'] if pair['edition'] in GBA)
report['native_math_equal'] = report['passed'] and all(not pair['native_math_mismatches'] for pair in report['pairs'])
save()
print('FINAL callback component', report['passed'], 'GBA complete raw RNG equal', report['gba_full_raw_rng_equal'], flush=True)
sys.exit(not report['passed'])
