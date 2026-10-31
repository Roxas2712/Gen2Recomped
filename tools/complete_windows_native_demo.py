#!/usr/bin/env python3
"""Finish one source-bound native Windows demo build and verify its download.

This foreground QA helper exits on any failed run. It does not publish a release,
change a user's profile or merge a PR. Copyright (c) 2026 Roxas2712.
"""
import argparse,atexit,hashlib,json,re,sys,time,zipfile
from pathlib import Path
import qa_storage as qa
ROOT=Path(__file__).resolve().parents[1];REPO='Roxas2712/Gen2Recomped'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime-run',type=int,required=True);p.add_argument('--native-run',type=int,required=True)
 p.add_argument('--native-already-qualified',action='store_true');p.add_argument('--package-run',type=int);a=p.parse_args()
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False);qa.qa_source(ROOT)
 out=ROOT/'.local/qa/windows-native-demo';qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
 state={'runtimeRunId':a.runtime_run,'originalNativeRunId':a.native_run,'state':'waiting-native'}
 def save():(out/'completion.json').write_text(json.dumps(state,indent=2)+'\n')
 def run(*args):return qa.qa_run(list(args),cwd=ROOT,capture_output=True,text=True,check=True,timeout=300).stdout
 def wait(runid):
  last=None
  while True:
   doc=json.loads(run('gh','api','-H','Cache-Control: no-cache',f'repos/{REPO}/actions/runs/{runid}?read_ts={int(time.time())}'))
   label=(doc['status'],doc['conclusion'])
   if label!=last:print(json.dumps({'runId':runid,'status':label}),flush=True);last=label
   if doc['status']=='completed':
    if doc['conclusion']!='success':raise RuntimeError(f'Run {runid} failed: {doc["conclusion"]}')
    return doc
   time.sleep(30)
 def dispatch(workflow,**inputs):
  args=['gh','workflow','run',workflow,'-R',REPO,'--ref','codex/windows-cloud-demo']
  for key,value in inputs.items():args+=['-f',key+'='+str(value)]
  output=run(*args);match=re.search(r'/actions/runs/(\d+)',output)
  if not match:raise RuntimeError('Missing dispatched run URL: '+output)
  print(output,flush=True);return int(match[1])
 try:
  save();wait(a.native_run);native=a.native_run
  if not a.native_already_qualified:
   native=dispatch('pokemon-xy-contract.yml',native_windows_sdk='true',native_windows_sdk_run_id=a.native_run)
   state.update(state='waiting-native-round-trip',nativeRunId=native);save();wait(native)
  state.update(state='waiting-runtime',nativeRunId=native);save();wait(a.runtime_run)
  package=a.package_run or dispatch('runtime-upvalues.yml',windows_only='false',package_runtime_run_id=a.runtime_run,native_components_run_id=native)
  state.update(state='waiting-final-exe',packageRunId=package);save();wait(package)
  target=ROOT/'.local/qa/windows-native-demo-download/candidate'
  if target.exists():raise ValueError('Download already exists; existing demo retained')
  qa.qa_copy(target);qa.qa_limit_output(target,4*1024**3)
  run('gh','run','download',str(package),'-R',REPO,'-n','windows-cloud-demo','-D',str(target))
  run('gh','run','download',str(package),'-R',REPO,'-n','windows-cloud-demo-native-test','-D',str(target/'native-test'))
  receipt=json.loads((target/'verification.json').read_text());result=json.loads((target/'native-test/native-package-test.json').read_text(encoding='utf-8-sig'))
  archives=list(target.glob('*-win64.zip'));assert len(archives)==1
  with archives[0].open('rb')as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
  assert digest==receipt['archiveSha256'] and result['passed']is True
  assert result['exeSha256']==receipt['fusedExeSha256'] and result['sourceRevision']==receipt['sourceRevision']
  assert result['nativeCartridgeGameplayTested']is False and result['playerCloudUploadTested']is False
  with zipfile.ZipFile(archives[0])as z:
   native_report=json.loads(z.read('RetroRecomped-Windows-Demo/native-runtime-test.json'))
   assert native_report['passed']is True and native_report['sdkManifestSha256']==receipt['nativeRuntime']['manifestSha256']
  state.update(state='complete',archive=str(archives[0]),archiveSha256=digest,sourceRevision=receipt['sourceRevision'],finalExeChecks=len(result['checks']),nativeRuntimeChecks=len(native_report['checks']))
  save();print(json.dumps(state),flush=True)
 except Exception as error:state.update(state='failed',error=str(error));save();raise
if __name__=='__main__':main()
