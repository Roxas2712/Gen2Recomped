"""Compare native GBA faint/status/reactive phases against a clean, read-only Gen1 checkout."""
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
EDITIONS = ('firered', 'leafgreen', 'emerald', 'ruby', 'sapphire')
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--reference-root', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--lua', type=Path, default=shutil.which('luajit'))
installed = Path.home() / '.local/lib/origami-qa-storage/active-tools'
p.add_argument('--qa-tools-root', type=Path, default=installed if installed.is_dir() else ROOT / 'tools')
p.add_argument('--qa-project-root', type=Path, default=ROOT)
p.add_argument('--edition', action='append', choices=EDITIONS)
p.add_argument('--mode', action='append', choices=('single','right','right-empty-left'))
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
              scope='Native public faint event ordering, HP/status/PP snapshots, Explosion prefix and real held-item healing. Full raw RNG must agree. Fixed level-damage reactions also observe the native zero-effect R/S chance command. Nonzero/dynamic payloads retain their separate qualification. Friendship, whole-mod and gameplay acceptance are outside this component.')

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
    for mode in a.mode or ('single','right','right-empty-left'):
        pair=[]
        for backend,cwd in [('gen1',ref),('gen2',ROOT)]:
            label=edition+'-'+mode+'-'+backend
            log=a.output/(label+'.log')
            with log.open('w') as stream:
                try:
                    result=qa.qa_run(['nice','-n','19',str(a.lua),str(ROOT/'tests/gen3_faint_phases/worker.lua'),str(ROOT),backend,edition,mode],cwd=cwd,env=dict(os.environ,POKEPORT_ISOLATED_TESTING='1',POKEPORT_SKIP_LEGACY_MIGRATION='1'),stdout=stream,stderr=-2,timeout=300)
                    code=result.returncode
                except subprocess.TimeoutExpired: code=124
            text=log.read_text(errors='replace')
            values=[json.loads(line.removeprefix('GEN3_FAINT_PHASES '))for line in text.splitlines()if line.startswith('GEN3_FAINT_PHASES ')]
            row=dict(label=label,exit=code,rows=values[0]if len(values)==1 else None,log=log.name,log_sha256=sha(log))
            report['runs'].append(row);pair.append(row);save()
            print(label,code,'cases',len(row['rows']or []),flush=True)
            if code: print(text[-1800:],flush=True)
        mismatch=[]
        if all(r['exit']==0 and r['rows'] for r in pair):
            assert len(pair[0]['rows'])==len(pair[1]['rows'])
            for index,(left,right)in enumerate(zip(pair[0]['rows'],pair[1]['rows'])):
                if not same(left,right): mismatch.append(dict(index=index,profile=left['profile'],high=left['high'],fields=[k for k in left if not same(left[k],right[k])]))
        else: mismatch=[dict(worker_failure=True)]
        report['pairs'].append(dict(edition=edition,mode=mode,cases=len(pair[0]['rows']or []),mismatches=mismatch,passed=not mismatch));save()
        print('PAIR',edition,mode,'differences',len(mismatch),mismatch[:3],flush=True)
report.update(status='terminal',inputs_unchanged=all(sha(Path(p))==h for p,h in hashes.items()),source_unchanged=git(ROOT,'rev-parse','HEAD')==source and git(ROOT,'diff','--binary','HEAD')==patch,reference_clean=not git(ref,'status','--porcelain').strip())
report['passed']=report['inputs_unchanged'] and report['source_unchanged'] and report['reference_clean'] and all(p['passed']for p in report['pairs'])
save();print('FINAL',report['passed'],sum(p['cases']for p in report['pairs']),'paired cases',flush=True);sys.exit(not report['passed'])
