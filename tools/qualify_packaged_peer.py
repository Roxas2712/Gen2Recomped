#!/usr/bin/env python3
"""Real WebRTC/WSS from bundled apps with default library/CA discovery.
QA-signed relay tickets, not production accounts or a played duel. By Roxas2712.
"""
import argparse,atexit,base64,hashlib,hmac,io,json,os,plistlib,sys,time,uuid,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--love-app',type=Path,required=True);p.add_argument('--runtime',type=Path,required=True);p.add_argument('--key-file',type=Path,required=True);p.add_argument('--label',required=True);p.add_argument('--relay',default='wss://retrorecomped-peer-relay.ascendant-content.workers.dev');a=p.parse_args();assert a.label.replace('-','').isalnum()
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for source in(ROOT,a.love_app,a.runtime,a.key_file,Path(sys.executable)):qa.qa_source(source.resolve())
 from package_peer_runtime import verify
 verify(a.runtime)
 out=ROOT/'.local/qa'/('peer-bundle-'+a.label);qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True);out.chmod(0o700);assert not(out/'report.json').exists()
 secret=a.key_file.read_text().strip();key=base64.b64decode(secret.split('=',1)[1]if secret.startswith('PEER_SIGNING_KEY=')else secret)
 payload=io.BytesIO()
 with zipfile.ZipFile(payload,'w',zipfile.ZIP_DEFLATED)as z:
  z.writestr('main.lua',(ROOT/'tests/native_peer/main.lua').read_bytes())
  z.writestr('conf.lua','function love.conf(t)t.identity=os.getenv("POKEPORT_IDENTITY");t.version="12.0";t.window.visible=false;t.window.vsync=0 end')
  for name in('src/link/NativePeer.lua','src/link/PeerNet.lua','src/link/Json.lua','src/cloud/Task.lua','src/cloud/Http.lua','src/core/HostShell.lua'):z.writestr(name,(ROOT/name).read_bytes())
 children=[];results=[]
 try:
  for mode in('direct','relay','switch'):
   pair=[];prepared=[];room='play:'+str(uuid.uuid4())
   for role in('left','right'):
    identity='oasc-peer-qa-bundle-'+a.label+'-'+mode+'-'+role;profile=Path.home()/'Library/Application Support/LOVE'/identity;qa.qa_source(profile);qa.qa_profile(profile)
    host=ROOT/'.local/engine-parity'/('peer-bundle-'+a.label+'-'+mode+'-'+role);qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True)
    bundle=host/'Peer QA.app';qa.qa_run(['cp','-cR',str(a.love_app),str(bundle)],check=True);qa.qa_run(['cp','-cR',str(a.runtime),str(bundle/'Contents/Resources/peer-native')],check=True)
    (bundle/'Contents/Resources/game.love').write_bytes(payload.getvalue());metadata=bundle/'Contents/Info.plist';info=plistlib.loads(metadata.read_bytes());info['CFBundleIdentifier']='de.roxas2712.qa.'+a.label+'.'+mode+'.'+role;metadata.write_bytes(plistlib.dumps(info))
    qa.qa_run(['codesign','--force','--deep','--sign','-','--entitlements',str(ROOT/'scripts/macos-entitlements.plist'),str(bundle)],capture_output=True,check=True)
    claims={'iss':'modcompass','aud':'retro-peer-v1','room':room,'role':role,'client':hashlib.sha256(role.encode()).hexdigest(),'issued':time.time_ns()//1000,'exp':int(time.time())+75}
    enc=lambda x:base64.urlsafe_b64encode(json.dumps(x,separators=(',',':')).encode()).rstrip(b'=')
    unsigned=enc({'alg':'HS256','typ':'JWT'})+b'.'+enc(claims);ticket=(unsigned+b'.'+base64.urlsafe_b64encode(hmac.digest(key,unsigned,'sha256')).rstrip(b'=')).decode()
    result=out/(mode+'-'+role+'.json');config=out/(mode+'-'+role+'-config.json');config.write_text(json.dumps({'mode':mode,'role':role,'transport':{'schema':1,'url':a.relay+'/v1/rooms/'+room,'role':role,'ticket':ticket,'stun':'stun:stun.cloudflare.com:3478','expires_in':75},'result':str(result)}));config.chmod(0o600)
    env=dict(os.environ,POKEPORT_IDENTITY=identity,RETRO_PEER_CONFIG=str(config),DYLD_FALLBACK_LIBRARY_PATH='/usr/lib')
    for name in('POKEPORT_PEER_LIBRARY','POKEPORT_PEER_CA','DYLD_LIBRARY_PATH'):env.pop(name,None)
    prepared.append((bundle,env,result,out/(mode+'-'+role+'.log')))
   # Finish both signed hosts before starting either 12-second handshake clock.
   for bundle,env,result,logpath in prepared:
    with logpath.open('w')as log:child=qa.qa_popen([str(bundle/'Contents/MacOS/love')],cwd=ROOT,env=env,stdout=log,stderr=log)
    children.append(child);pair.append((child,result))
   deadline=time.monotonic()+45
   while any(c.poll()is None for c,_ in pair)and time.monotonic()<deadline:time.sleep(.1)
   rows=[]
   for child,result in pair:
    if child.poll()is None:child.terminate();child.wait(timeout=10)
    rows.append(json.loads(result.read_text())if result.exists()else{'ok':False,'reason':'No bundle result'})
   results.extend(rows);(out/'report.json').write_text(json.dumps({'passed':all(r['ok']for r in results),'results':results,'default_bundle_loader':True,'physical_devices':False,'scope':'QA-signed native transport fixtures; not ModCompass accounts or played games'},indent=2)+'\n');print(json.dumps(rows),flush=True)
   assert all(row['ok']for row in rows),rows
 finally:
  for child in children:
   if child.poll()is None:child.terminate();child.wait(timeout=10)
if __name__=='__main__':main()
