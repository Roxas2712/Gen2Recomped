"""Compare native trainer continuation across two fresh fixture-only Lua VMs."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--lua', type=Path, default=shutil.which('luajit'))
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--qa-tools-root', type=Path, default=ROOT / 'tools')
parser.add_argument('--baseline-commit', help='Optional full SHA for the old checkpoint serializer negative control')
args = parser.parse_args()
if not args.lua or not args.lua.is_file():
    parser.error('--lua must select an existing LuaJIT executable')
if args.output.exists():
    parser.error('--output must be a new directory')
if args.baseline_commit and not re.fullmatch('[0-9a-f]{40}', args.baseline_commit):
    parser.error('--baseline-commit must be a full commit SHA')
worker = ROOT / 'tests/gen3_trainer_items/checkpoint_worker.lua'
inputs = [worker, ROOT / 'tests/checkpoint_fixture.lua', ROOT / 'src/core/Checkpoint.lua',
          ROOT / 'src/core/CheckpointBattle.lua', ROOT / 'src/battle/BattleState.lua',
          ROOT / 'src/battle/Gen3TrainerItems.lua', ROOT / 'src/battle/Gen3TrainerDecision.lua',
          ROOT / 'src/battle/Gen3TrainerController.lua', Path(__file__).resolve()]
run = subprocess.run
if os.name != 'nt' and not os.getenv('GITHUB_ACTIONS'):
    sys.path.insert(0, str(args.qa_tools_root.resolve()))
    from qa_storage import qa_source, qa_cache, qa_copy, qa_run
    for path in [ROOT, args.lua.resolve(), Path(sys.executable), args.qa_tools_root, *inputs]:
        qa_source(path)
    qa_cache(args.output)
    run = qa_run
args.output.mkdir(parents=True)
candidate = args.output / 'candidate'
if os.name != 'nt' and not os.getenv('GITHUB_ACTIONS'):
    qa_copy(candidate)
candidate.mkdir()
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
hashes = {str(path.relative_to(ROOT)): sha(path) for path in inputs}
env = dict(os.environ, POKEPORT_ISOLATED_TESTING='1', POKEPORT_SKIP_LEGACY_MIGRATION='1')
prefix = ['nice', '-n', '19'] if os.name != 'nt' else []
report = dict(status='running', inputs=hashes, pairs=[])
(args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


def command(phase, edition, api, format_, *, packet=None, baseline=None, label=''):
    argv = [*prefix, str(args.lua.resolve()), str(worker), phase, edition, str(api), format_]
    if baseline:
        argv.append(str(baseline))
    if packet is None:
        result = run(argv, cwd=ROOT, env=env, text=True,
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
    else:
        # A finite file gives the fresh VM an explicit EOF, including when
        # the local QA manager polls communicate() between budget checks.
        stdin_path = candidate / (label + '.stdin.json')
        stdin_path.write_text(packet)
        with stdin_path.open('rb') as stream:
            result = run(argv, cwd=ROOT, env=env, stdin=stream, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
    log = args.output / (label + '-' + phase + '.log')
    log.write_text(result.stdout)
    return result.returncode, result.stdout, sha(log)


def pair(edition, api, format_, *, baseline=None):
    label = edition + '-' + str(api) + '-' + format_ + ('-baseline' if baseline else '')
    code, output, producer_hash = command('produce-baseline' if baseline else 'produce',
                                         edition, api, format_, baseline=baseline, label=label)
    packets = [line.removeprefix('GBA_CHECKPOINT_PACKET ') for line in output.splitlines()
               if line.startswith('GBA_CHECKPOINT_PACKET ')]
    assert code == 0 and len(packets) == 1, output[-2000:]
    code, output, consumer_hash = command('consume', edition, api, format_, packet=packets[0], label=label)
    markers = [json.loads(line.removeprefix('GBA_CHECKPOINT_RESULT ')) for line in output.splitlines()
               if line.startswith('GBA_CHECKPOINT_RESULT ')]
    assert len(markers) == 1, output[-2000:]
    result = markers[0]
    passed = (code == 1 and result['restored'] and not result['cacheRetained']
              and not result['futureEqual'] and result['hp'] != result['expectedHp']) if baseline else (
                  code == 0 and result['cacheRetained'] and result['futureEqual'] and result['hp'] == result['expectedHp'])
    row = dict(label=label, passed=passed, expected_negative=bool(baseline), consumer_exit=code,
               result=result, producer_log_sha256=producer_hash, consumer_log_sha256=consumer_hash)
    report['pairs'].append(row)
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(label, 'PASS' if passed else 'FAIL', flush=True)
    if not passed:
        print(output[-2000:], flush=True)


for edition in ('firered', 'leafgreen', 'ruby', 'sapphire', 'emerald'):
    for api, format_ in ((1, 'native'), (2, 'native'), (2, 'unified'), (3, 'unified')):
        pair(edition, api, format_)
if args.baseline_commit:
    result = run(['git', '-C', str(ROOT), 'show', args.baseline_commit + ':src/core/CheckpointBattle.lua'],
                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    baseline = candidate / 'CheckpointBattle-baseline.lua'
    baseline.write_bytes(result.stdout)
    report['baseline_commit'] = args.baseline_commit
    report['baseline_serializer_sha256'] = sha(baseline)
    pair('emerald', 3, 'unified', baseline=baseline)
report.update(status='terminal', inputs_unchanged=all(sha(ROOT / path) == digest for path, digest in hashes.items()))
report['passed'] = report['inputs_unchanged'] and all(row['passed'] for row in report['pairs'])
(args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
sys.exit(not report['passed'])
