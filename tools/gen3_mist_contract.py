"""Compare native GBA Mist effects against a clean, read-only Gen1 checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference-root', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--lua', type=Path, default=shutil.which('luajit'))
parser.add_argument('--qa-tools-root', type=Path, default=ROOT / 'tools')
parser.add_argument('--edition', action='append', choices=('firered','leafgreen','ruby','sapphire','emerald'))
parser.add_argument('--mode', action='append', choices=('single','double-left','double-right'))
args = parser.parse_args()
ref = args.reference_root.resolve()
if not args.lua or not args.lua.is_file():
    parser.error('--lua must select an existing LuaJIT executable')
if args.output.exists():
    parser.error('--output must be a new directory')
worker = ROOT / 'tests/gen3_mist/worker.lua'
inputs = [Path(__file__).resolve(), worker, ROOT / 'tests/gen3_mist/cases.lua',
          ROOT / 'tests/charge_required/fixture.lua', *[ROOT / p for p in (
              'src/battle/Gen3Mist.lua', 'src/battle/Gen3Builtins.lua',
              'src/battle/BattleState.lua', 'src/battle/Gen3Secondary.lua',
              'src/battle/GbaItemSchedule.lua', 'src/battle/Gen3TrainerItems.lua',
              'src/battle/Gen3TrainerController.lua', 'src/battle/Gen3TrainerItemEffects.lua',
              'src/core/CheckpointBattle.lua')], *[ref / p for p in (
              'src/core/game3/battle/effects/screens.lua',
              'src/core/game3/battle/effects/secondary.lua',
              'src/core/game3/battle/residual_handlers.lua',
              'src/core/game3/battle/engine.lua', 'src/core/game3/battle/abilities.lua')]]
run = subprocess.run
if os.name != 'nt' and not os.getenv('GITHUB_ACTIONS'):
    sys.path.insert(0, str(args.qa_tools_root.resolve()))
    from qa_storage import qa_source, qa_cache, qa_run
    for path in [ROOT, ref, args.lua.resolve(), Path(sys.executable), args.qa_tools_root, *inputs]:
        qa_source(path)
    qa_cache(args.output)
    run = qa_run


def git(root, *argv):
    return run(['git', '-C', str(root), *argv], text=True, stdout=subprocess.PIPE,
               stderr=subprocess.PIPE, check=True).stdout.strip()


if git(ref, 'status', '--porcelain'):
    parser.error('the reference checkout must be clean and stays read-only')
args.output.mkdir(parents=True)
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
hashes = {str(path): sha(path) for path in inputs}
report = dict(status='running', inputs=hashes, source=git(ROOT, 'rev-parse', 'HEAD'),
              reference_source=git(ref, 'rev-parse', 'HEAD'), runs=[], pairs=[],
              scope='Native move resolution, registered trainer item controller/execution, '
                    'switching, Intimidate and residual scheduling. Compare Mist duration '
                    'and stat protection; no complete damage, Haze, UI or whole-mod claim.')
report_path = args.output / 'report.json'


def save():
    report_path.write_text(json.dumps(report, indent=2) + '\n')


def equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(equal(left[k], right[k]) for k in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(equal(a, b) for a, b in zip(left, right))
    return left == right


save()
env = dict(os.environ, POKEPORT_ISOLATED_TESTING='1', POKEPORT_SKIP_LEGACY_MIGRATION='1')
prefix = ['nice', '-n', '19'] if os.name != 'nt' else []
for edition in args.edition or ('firered','leafgreen','ruby','sapphire','emerald'):
    for mode in args.mode or ('single','double-left','double-right'):
        pair = []
        for backend, cwd in (('gen1', ref), ('gen2', ROOT)):
            label = edition + '-' + mode + '-' + backend
            log = args.output / (label + '.log')
            with log.open('w') as stream:
                try:
                    result = run([*prefix, str(args.lua.resolve()), str(worker), str(ROOT), backend,
                                  edition, mode], cwd=cwd, env=env, stdout=stream,
                                 stderr=subprocess.STDOUT, timeout=180)
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = 124
            output = log.read_text(errors='replace')
            markers = [line.removeprefix('GBA_MIST_CONTRACT ') for line in output.splitlines()
                       if line.startswith('GBA_MIST_CONTRACT ')]
            row = dict(label=label, exit=code, log_sha256=sha(log),
                       rows=json.loads(markers[0]) if len(markers) == 1 else None)
            report['runs'].append(row)
            pair.append(row)
            save()
            print(label, code, flush=True)
            if code:
                print(output[-3000:], flush=True)
        report['pairs'].append(dict(label=edition + '-' + mode,
                                    equal=pair[0]['rows'] is not None and equal(pair[0]['rows'], pair[1]['rows'])))
        save()
report.update(status='terminal', inputs_unchanged=all(sha(Path(p)) == h for p, h in hashes.items()),
              reference_clean=not git(ref, 'status', '--porcelain'))
report['passed'] = (report['inputs_unchanged'] and report['reference_clean']
                    and all(r['exit'] == 0 and r['rows'] for r in report['runs'])
                    and all(p['equal'] for p in report['pairs']))
save()
sys.exit(not report['passed'])
