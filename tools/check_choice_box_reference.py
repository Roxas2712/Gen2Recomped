#!/usr/bin/env python3
"""Compare actual native Red choice rendering against the pinned Gen1 host."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tarfile
import time
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from qa_storage import qa_source,qa_cache,qa_copy,qa_profile,qa_run
from check_full_game_performance import BOOTSTRAP

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('love','lua','red','reference','out'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--before',required=True)
 a=p.parse_args()
 love,lua,rom,ref=(v.resolve(strict=True)for v in(a.love,a.lua,a.red,a.reference))
 for path in(ROOT,love,lua,rom,ref):qa_source(path)
 out=a.out.resolve();qa_cache(out);out.mkdir(parents=True,exist_ok=False)
 def git(root,*args):return qa_run(['git',*args],cwd=root,capture_output=True,text=True,check=True).stdout.strip()
 head=git(ROOT,'rev-parse','HEAD');before=git(ROOT,'rev-parse',a.before);reference=git(ref,'rev-parse','HEAD')
 assert reference=='535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91'
 assert not git(ROOT,'status','--porcelain','--untracked-files=normal')
 assert not git(ref,'status','--porcelain','--untracked-files=normal')
 digest=hashlib.sha1(rom.read_bytes()).hexdigest()
 qa_run([str(lua),'-e','assert(require("src.core.GameVersion").acceptsSha1("red",'+json.dumps(digest)+'))'],cwd=ROOT,check=True)
 driver=ROOT/'tools/choice_box_reference_driver.lua'
 report=dict(passed=False,romSha1=digest,playerProfilesUsed=False,hosts={},comparisons=[],
  scope='English Red YES/NO widget over an identical controlled backdrop, through native Game and final renderer; not whole-world or translated-screen parity.')
 for label,repo,revision in(('reference',ref,reference),('before',ROOT,before),('candidate',ROOT,head)):
  run=out/label;qa_cache(run);run.mkdir()
  source=run/'source';qa_copy(source);source.mkdir()
  archive=qa_run(['git','archive',revision],cwd=repo,capture_output=True,check=True).stdout
  with tarfile.open(fileobj=io.BytesIO(archive))as tar:
   for member in tar.getmembers():
    assert not member.name.startswith('/')and '..'not in Path(member.name).parts
    assert not member.issym()and not member.islnk()
   tar.extractall(source)
  (source/'main.lua').rename(source/'engine_main.lua');(source/'main.lua').write_text(BOOTSTRAP)
  (source/'tools/choice_box_reference_driver.lua').write_bytes(driver.read_bytes())
  identity='oasc-gen2recomp-qa-perf-choice-'+label+'-'+str(time.time_ns())
  qa_profile(Path.home()/'Library/Application Support/LOVE'/identity)
  env={k:v for k,v in os.environ.items()if not k.startswith(('POKEPORT_','CHOICE_','PERF_'))}
  env.update(POKEPORT_IDENTITY=identity,POKEPORT_VERSION='red',POKEPORT_NO_MODS='1',POKEPORT_NO_BOOT_REPORT='1',
   POKEPORT_NO_DISCORD='1',POKEPORT_NOTIFY_ONLY_UPDATES='1',MODKIT_LUAJIT=str(lua))
  for phase,extra in(('import',dict(POKEPORT_IMPORT_ROM=str(rom),POKEPORT_IMPORT_ONLY='1')),
   ('scene',dict(POKEPORT_DRIVER=str(source/'tools/choice_box_reference_driver.lua'),CHOICE_QA_OUT=str(run),CHOICE_QA_SOURCE=revision))):
   with(run/(phase+'.log')).open('w')as log:
    qa_run([str(love),str(source)],cwd=source,env=dict(env,**extra),stdout=log,stderr=log,timeout=600,check=True)
  data=json.loads((run/'report.json').read_text());assert data['passed']and data['inputReturnPaths']and data['drawSaveUnchanged']
  report['hosts'][label]=dict(commit=revision,frames=data['frames'],inputReturnPaths=True,drawSaveUnchanged=True)
  print('CHOICE_HOST_PASS '+label,flush=True)
 for frame in('yes','no'):
  meta=report['hosts']['reference']['frames'][frame];expected=(out/'reference'/(frame+'.rgba')).read_bytes()
  for label in('before','candidate'):
   other=report['hosts'][label]['frames'][frame]
   assert(other['width'],other['height'],other['viewport'])==(meta['width'],meta['height'],meta['viewport']), 'native viewport changed'
   actual=(out/label/(frame+'.rgba')).read_bytes();assert len(actual)==len(expected)
   changed=sum(actual[i:i+4]!=expected[i:i+4]for i in range(0,len(actual),4))
   delta=max(abs(x-y)for x,y in zip(actual,expected))if changed else 0
   report['comparisons'].append(dict(host=label,frame=frame,changedPixels=changed,maxByteDelta=delta,
    referenceSha256=hashlib.sha256(expected).hexdigest(),actualSha256=hashlib.sha256(actual).hexdigest()))
   assert(changed==0)if label=='candidate'else(changed>0)
 assert git(ROOT,'rev-parse','HEAD')==head
 report['passed']=True;report['driverSha256']=hashlib.sha256(driver.read_bytes()).hexdigest()
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print('CHOICE_REFERENCE_PASS',flush=True)
 return 0
if __name__=='__main__':sys.exit(main())
