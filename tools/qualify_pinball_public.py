#!/usr/bin/env python3
"""Two native players through public ModCompass using explicit temporary QA accounts.
No account creation or cleanup is performed by this client tool. By Roxas2712.
"""
import argparse,atexit,json,os,plistlib,re,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read_fixture(path):
 try:fixture=json.loads(Path(path).read_text())
 except (ValueError,OSError)as error:raise ValueError('A private, configured public QA account fixture is required.')from error
 if not isinstance(fixture,dict)or fixture.get('qa_only')is not True or not re.fullmatch('[a-f0-9]{32}',str(fixture.get('marker',''))):
  raise ValueError('Replace the QA fixture placeholders and provide its 32-character hexadecimal marker.')
 if fixture.get('url')!='https://pokexpert.de/api/cloud/v1/play/'or not isinstance(fixture.get('accounts'),list)or len(fixture['accounts'])!=2:
  raise ValueError('The public qualification requires its fixed service URL and two disposable QA accounts.')
 identities=set()
 for account in fixture['accounts']:
  if not isinstance(account,dict)or not isinstance(account.get('account'),str)or not re.fullmatch('[1-9][0-9]{0,19}',account['account']):
   raise ValueError('Replace the QA account placeholders before starting the public test.')
  token=account.get('token')
  if not isinstance(token,str)or not re.fullmatch('[!-~]{20,512}',token)or any(word in token.upper()for word in('REPLACE','CHANGE_ME','PLACEHOLDER')):
   raise ValueError('Replace the private QA token placeholders before starting the public test.')
  identities.add(str(account['account']))
 if len(identities)!=2:raise ValueError('The public qualification needs two different disposable QA accounts.')
 return fixture

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--fixture',type=Path,required=True);p.add_argument('--love',type=Path,required=True);p.add_argument('--peer-library',type=Path);p.add_argument('--peer-ca',type=Path);p.add_argument('--label',required=True);p.add_argument('--peer-mode',choices=['off','direct','relay','switch'],default='switch');p.add_argument('--edition',choices=['pinballrs','pinballgbc'],default='pinballrs');p.add_argument('--field',type=int,choices=[0,1],default=0);p.add_argument('--functional-only',action='store_true',help='Report native invitation/gameplay results separately from the strict steady-audio qualification');a=p.parse_args()
 assert a.label.replace('-','').isalnum()
 try:fixture=read_fixture(a.fixture)
 except ValueError as error:p.error(str(error))
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 work=ROOT/('.local/pinball-gbc'if a.edition=='pinballgbc'else'.local/pinball-rs')
 if a.peer_mode!='off'and not(a.peer_library and a.peer_ca):p.error('Peer modes require --peer-library and --peer-ca; --peer-mode off exercises authenticated HTTPS pictures')
 original=next(v for v in a.love.resolve().parents if v.suffix=='.app')
 for v in(ROOT,work,a.fixture,a.love,original,Path(sys.executable),*[v for v in(a.peer_library,a.peer_ca)if v]):qa.qa_source(v.resolve())
 session=json.loads((work/'library.json').read_text());session.update(locale='en',volume=0)
 assert session.get('edition','pinballrs')==a.edition,'Prepared native edition differs from requested qualification'
 for name in('rom','bridge','bios'):
  if session.get(name):qa.qa_source(Path(session[name]).resolve())
 profiles=[Path.home()/'Library/Application Support/LOVE'/('oasc-pinball-qa-public-'+a.label+'-'+str(seat))for seat in(1,2)]
 for profile in profiles:qa.qa_source(profile)
 out=ROOT/'.local/qa'/('pinball-public-'+a.label);qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True);out.chmod(0o700)
 assert not(out/'report.json').exists(),'Preserve prior evidence'
 env=dict(os.environ)
 if a.peer_mode!='off':env.update(POKEPORT_PEER_LIBRARY=str(a.peer_library.resolve()),POKEPORT_PEER_CA=str(a.peer_ca.resolve()))
 children=[];logs=[]
 try:
  for seat,account in enumerate(fixture['accounts'],1):
   identity='oasc-pinball-qa-public-'+a.label+'-'+str(seat)
   profile=profiles[seat-1];qa.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
   (profile/('pinball-gbc-display.json'if a.edition=='pinballgbc'else'pinball-display.json')).write_text(json.dumps({'full_table':True}))
   host=ROOT/'.local/engine-parity'/('pinball-public-'+a.label+'-'+str(seat));qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
   (host/'src').symlink_to(ROOT/'src',target_is_directory=True);(host/'main.lua').write_bytes((ROOT/'tests/pinball_http_peer.lua').read_bytes())
   (host/'conf.lua').write_text('function love.conf(t)t.identity="'+identity+'";t.version="12.0";t.window.width=1000;t.window.height=720;t.window.vsync=0 end')
   private=dict(session,player=str(out/('player-'+str(seat))));Path(private['player']).mkdir(exist_ok=True)
   config=out/('client-'+str(seat)+'.json');config.write_text(json.dumps(account|{'seat':seat,'publicQualification':True,'peer_mode':a.peer_mode,'session':private,'field':a.field,'url':fixture['url'],'output':str(out/('result-'+str(seat)+'.json'))}));config.chmod(0o600)
   bundle=host/'.qa-runtime.app';qa.qa_run(['cp','-cR',str(original),str(bundle)],check=True)
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
  assert all(r.get('opponent_view')and not r['opponent_view'].get('error')and r['opponent_view']['received']>10 for r in results),results
  if a.peer_mode!='off':assert all(r.get('peer_view')and not r['peer_view'].get('error')and r['peer_view']['received']>10 for r in results),results
  if a.peer_mode in('direct','switch'):assert all(r['peer_view']['directFrames']>10 for r in results),results
  if a.peer_mode in('relay','switch'):assert all(r['peer_view']['relayFrames']>10 for r in results),results
  if a.peer_mode=='switch':assert any(r['peer_view'].get('forcedFallback')for r in results),results
  audio_ok=all(r.get('steady_audio_restarts')==0 and r.get('steady_seconds',0)>60 for r in results)
  report={'passed':audio_ok or a.functional_only,'edition':a.edition,'field':a.field,'functional_only':a.functional_only,'gameplay_qualified':True,'production_https_exercised':True,'physical_devices':False,'browser_oauth_exercised':False,'peer_mode':a.peer_mode,'steady_audio_qualified':audio_ok,'server_final_tail_requires_operator_check':True,'results':results}
  (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':report['passed'],'edition':a.edition,'gameplay_qualified':True,'peer_mode':a.peer_mode,'output':str(out)}),flush=True)
  assert audio_ok or a.functional_only,'Public native game completed but strict audio target failed; see report.json'
 finally:
  for child in reversed(children):
   if child.poll()is None:child.terminate()
  for child in reversed(children):
   try:child.wait(timeout=15)
   except Exception:child.kill();child.wait()
  for log in logs:log.close()
if __name__=='__main__':main()
