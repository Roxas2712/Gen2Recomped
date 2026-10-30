#!/usr/bin/env python3
"""Reuse an exact public-fork native component, then run fresh native tests.

No component/source identity is inferred from a filename. Qualified reuse
requires a successful run. Explicit QA candidates require a successful compile
step and still have to pass every native test before final packaging.
Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse,hashlib,json,sys,zipfile
from pathlib import Path,PurePosixPath
from native_workspace import manager
ROOT=Path(__file__).resolve().parents[1]
CRITICAL=['tools/pokemon-xy-bridge','tools/pokemon_xy_source_pins.json','tools/windows_native_components.json','tools/pinball-rs-native/windows-io.patch','tools/pinball-rs-native/runtime-fixes.patch']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--artifact',type=Path,required=True);p.add_argument('--run-id',type=int,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--candidate',action='store_true');a=p.parse_args()
 qa=manager(ROOT);qa.qa_source(ROOT);qa.qa_source(a.artifact);qa.qa_copy(a.out)
 doc=json.loads(qa.qa_run(['gh','api',f'repos/Roxas2712/Gen2Recomped/actions/runs/{a.run_id}'],check=True,capture_output=True,text=True).stdout)
 if doc.get('status')!='completed' or doc.get('repository',{}).get('full_name')!='Roxas2712/Gen2Recomped':raise ValueError('Only a finished component run from this public fork can be reused')
 if a.candidate:
  jobs=json.loads(qa.qa_run(['gh','api',f'repos/Roxas2712/Gen2Recomped/actions/runs/{a.run_id}/jobs'],check=True,capture_output=True,text=True).stdout)
  if not any(step.get('name')=='Build pinned game-data-free native components'and step.get('conclusion')=='success'for job in jobs['jobs']for step in job.get('steps',[])):
   raise ValueError('The candidate compile step did not succeed; rebuild it')
 elif doc.get('conclusion')!='success':raise ValueError('Only a successful qualified run can supply a final component')
 revision=doc['head_sha']
 def tree(rev,path):return qa.qa_run(['git','rev-parse',rev+':'+path],cwd=ROOT,check=True,capture_output=True,text=True).stdout.strip()
 expected={path:tree(revision,path)for path in CRITICAL}
 if any(tree('HEAD',path)!=value for path,value in expected.items()):raise ValueError('Native sources changed; rebuild the SDK')
 reports=list(a.artifact.rglob('report.json'))
 if len(reports)>1:raise ValueError('Ambiguous native reports')
 if reports and not a.candidate:
  report=json.loads(reports[0].read_text(encoding='utf-8-sig'))
  if report.get('passed')is not True or report.get('platform')!='Windows':raise ValueError('The original native component did not pass')
 archives=list(a.artifact.rglob('windows-native-runtime.zip'))
 if len(archives)!=1:raise ValueError('Expected one original native component archive')
 if a.out.exists():raise ValueError('Use a fresh output; existing SDKs are preserved')
 with zipfile.ZipFile(archives[0])as z:
  entries={}
  for row in z.infolist():
   path=PurePosixPath(row.filename)
   if path.is_absolute()or'..'in path.parts or'\\'in row.filename or':'in row.filename:raise ValueError('Unsafe native archive')
   if row.is_dir():continue
   if path.parts[0]!='3ds-runtime'or len(path.parts)<2 or(row.external_attr>>16)&0o170000==0o120000:raise ValueError('Unexpected native archive entry')
   name=PurePosixPath(*path.parts[1:]).as_posix()
   if name in entries:raise ValueError('Duplicate native archive entry')
   entries[name]=row
  index=json.loads(z.read(entries['files.json']))
  if set(entries)!=set(index)|{'files.json'}:raise ValueError('Incomplete native component inventory')
  for name,row in entries.items():
   destination=a.out/name;destination.parent.mkdir(parents=True,exist_ok=True);h=hashlib.sha256()
   with z.open(row)as source,destination.open('wb')as target:
    while chunk:=source.read(1024**2):target.write(chunk);h.update(chunk)
   if name!='files.json'and h.hexdigest()!=index[name]:raise ValueError('Native component byte mismatch: '+name)
 source=a.out/'source.json'
 if source.exists()and json.loads(source.read_text()).get('trees')!=expected:raise ValueError('Native source provenance differs from the original run')
 source.write_text(json.dumps({'schema':1,'trees':expected},indent=2)+'\n');index['source.json']=hashlib.sha256(source.read_bytes()).hexdigest()
 (a.out/'files.json').write_text(json.dumps(index,sort_keys=True)+'\n')
 print(json.dumps({'reusedNativeRunId':a.run_id,'originalRevision':revision,'sourceTrees':expected}))
if __name__=='__main__':main()
