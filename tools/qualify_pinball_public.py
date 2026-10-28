#!/usr/bin/env python3
"""Two native players through public ModCompass using explicit temporary QA accounts.
No account creation or cleanup is performed by this client tool. By Roxas2712.
"""
import argparse,atexit,json,os,plistlib,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--fixture',type=Path,required=True);p.add_argument('--love',type=Path,required=True);p.add_argument('--peer-library',type=Path,required=True);p.add_argument('--peer-ca',type=Path,required=True);p.add_argument('--label',required=True);p.add_argument('--peer-mode',choices=['direct','relay','switch'],default='switch');a=p.parse_args()
 assert a.label.replace('-','').isalnum()
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for v in(ROOT,ROOT/'.local/pinball-rs',a.fixture,a.love,a.peer_library,a.peer_ca,Path(sys.executable)):qa.qa_source(v.resolve())
 fixture=json.loads(a.fixture.read_text());assert fixture.get('qa_only')is True and len(fixture.get('marker',''))==32
 assert fixture['url']=='https://pokexpert.de/api/cloud/v1/play/'and len(fixture['accounts'])==2
 out=ROOT/'.local/qa'/('pinball-public-'+a.label);qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True);out.chmod(0o700)
 assert not(out/'report.json').exists(),'Preserve prior evidence'
 session=json.loads((ROOT/'.local/pinball-rs/library.json').read_text());session.update(locale='en',volume=0)
 env=os.environ|{'POKEPORT_PEER_LIBRARY':str(a.peer_library.resolve()),'POKEPORT_PEER_CA':str(a.peer_ca.resolve())};children=[];logs=[]
 try:
  for seat,account in enumerate(fixture['accounts'],1):
   identity='oasc-pinball-qa-public-'+a.label+'-'+str(seat)
   profile=Path.home()/'Library/Application Support/LOVE'/identity;qa.qa_source(profile);qa.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
   (profile/'pinball-display.json').write_text(json.dumps({'full_table':True}))
   host=ROOT/'.local/engine-parity'/('pinball-public-'+a.label+'-'+str(seat));qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
   (host/'src').symlink_to(ROOT/'src',target_is_directory=True);(host/'main.lua').write_bytes((ROOT/'tests/pinball_http_peer.lua').read_bytes())
   (host/'conf.lua').write_text('function love.conf(t)t.identity="'+identity+'";t.version="12.0";t.window.width=1000;t.window.height=720;t.window.vsync=0 end')
   private=dict(session,player=str(out/('player-'+str(seat))));Path(private['player']).mkdir(exist_ok=True)
   config=out/('client-'+str(seat)+'.json');config.write_text(json.dumps(account|{'seat':seat,'publicQualification':True,'peer_mode':a.peer_mode,'session':private,'field':0,'url':fixture['url'],'output':str(out/('result-'+str(seat)+'.json'))}));config.chmod(0o600)
   original=next(v for v in a.love.resolve().parents if v.suffix=='.app');bundle=host/'.qa-runtime.app';qa.qa_run(['cp','-cR',str(original),str(bundle)],check=True)
   metadata=bundle/'Contents/Info.plist';info=plistlib.loads(metadata.read_bytes());info['CFBundleIdentifier']='de.roxas2712.qa.public.'+a.label+'.'+str(seat);metadata.write_bytes(plistlib.dumps(info))
   qa.qa_run(['codesign','--force','--deep','--sign','-','--entitlements',str(ROOT/'scripts/macos-entitlements.plist'),str(bundle)],capture_output=True,check=True)
   log=(out/('peer-'+str(seat)+'.log')).open('w');logs.append(log)
   child=qa.qa_popen([str(bundle/'Contents/MacOS'/a.love.name),str(host)],cwd=ROOT,env=env|{'PINBALL_HTTP_CONFIG':str(config)},stdout=log,stderr=log);children.append(child)
  deadline=time.monotonic()+420
  while any(c.poll()is None for c in children):
   assert time.monotonic()<deadline,'Public native test deadline exceeded';time.sleep(.5)
  results=[json.loads((out/('result-'+str(i)+'.json')).read_text())for i in(1,2)]
  assert all(c.returncode==0 for c in children),results
  assert all(r['passed']and r['native']and r['wire_drained']and not r.get('wire_error')for r in results),results
  assert results[0]['checkpoint']==results[1]['checkpoint']and results[1]['prepared_from_missing']
  assert results[0]['duel']['localScore']==results[1]['duel']['remoteScore']and results[1]['duel']['localScore']==results[0]['duel']['remoteScore']
  assert all(r.get('peer_view')and not r['peer_view'].get('error')and r['peer_view']['received']>10 for r in results),results
  if a.peer_mode in('direct','switch'):assert all(r['peer_view']['directFrames']>10 for r in results),results
  if a.peer_mode in('relay','switch'):assert all(r['peer_view']['relayFrames']>10 for r in results),results
  if a.peer_mode=='switch':assert any(r['peer_view'].get('forcedFallback')for r in results),results
  audio_ok=all(r.get('steady_audio_restarts')==0 and r.get('steady_seconds',0)>60 for r in results)
  report={'passed':audio_ok,'gameplay_qualified':True,'production_https_exercised':True,'physical_devices':False,'browser_oauth_exercised':False,'peer_mode':a.peer_mode,'steady_audio_qualified':audio_ok,'server_final_tail_requires_operator_check':True,'results':results}
  (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':audio_ok,'gameplay_qualified':True,'peer_mode':a.peer_mode,'output':str(out)}),flush=True)
  assert audio_ok,'Public native game completed but strict audio target failed; see report.json'
 finally:
  for child in reversed(children):
   if child.poll()is None:child.terminate()
  for child in reversed(children):
   try:child.wait(timeout=15)
   except Exception:child.kill();child.wait()
  for log in logs:log.close()
if __name__=='__main__':main()
