#!/usr/bin/env python3
"""Two native clients over a real isolated ModCompass HTTPS server. By Roxas2712.

Uses existing private imports, never production users or bundled cartridge bytes.
The second client starts unprepared, then activates its already-built private
import. This checks invitation continuation, not a second cartridge recompilation.
"""
import argparse,atexit,base64,http.server,json,os,plistlib,shutil,socket,sqlite3,ssl,sys,threading,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def port():
    with socket.socket()as sock:sock.bind(('127.0.0.1',0));return sock.getsockname()[1]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--server',type=Path,required=True);p.add_argument('--php',type=Path,required=True);p.add_argument('--love',type=Path,required=True);p.add_argument('--label',default='native-friends')
    p.add_argument('--peer-mode',choices=['off','direct','relay','switch'],default='off');p.add_argument('--peer-library',type=Path);p.add_argument('--peer-ca',type=Path);p.add_argument('--peer-key-file',type=Path);p.add_argument('--peer-relay',default='wss://retrorecomped-peer-relay.ascendant-content.workers.dev')
    a=p.parse_args();assert a.label.replace('-','').isalnum()
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    server=a.server.resolve();php=a.php.resolve();love=a.love.resolve();work=ROOT/'.local/pinball-rs'
    for source in(ROOT,server,php,love,work,Path(sys.executable)):qa.qa_source(source)
    if a.peer_mode!='off':
        assert a.peer_library and a.peer_ca and a.peer_key_file,'Peer qualification needs its private native library, CA and signing key file'
        for source in(a.peer_library,a.peer_ca,a.peer_key_file):qa.qa_source(source.resolve())
    out=ROOT/'.local/qa'/('pinball-http-'+a.label);qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    assert not(out/'test.sqlite').exists(),'Use a fresh label to preserve prior evidence'
    database=out/'test.sqlite';database.touch();os.chmod(out,0o700)
    for part in('framework/cache/data','framework/sessions','framework/views','logs'):(out/'storage'/part).mkdir(parents=True,exist_ok=True)
    env=os.environ|{'APP_ENV':'testing','APP_DEBUG':'false','APP_KEY':'base64:'+base64.b64encode(os.urandom(32)).decode(),'DB_CONNECTION':'sqlite','DB_DATABASE':str(database),'DB_URL':'','CACHE_STORE':'file','SESSION_DRIVER':'array','MAIL_MAILER':'array','QUEUE_CONNECTION':'sync','BCRYPT_ROUNDS':'4','RETRO_CLOUD_ENABLED':'true','LARAVEL_STORAGE_PATH':str(out/'storage'),'APP_CONFIG_CACHE':str(out/'config.php'),'APP_ROUTES_CACHE':str(out/'routes.php'),'LOG_CHANNEL':'stderr','PINBALL_HTTP_FIXTURE':str(out/'accounts.json')}
    if a.peer_mode!='off':
        secret=a.peer_key_file.read_text().strip();secret=secret.split('=',1)[1]if secret.startswith('PEER_SIGNING_KEY=')else secret
        env.update(RETRO_PEER_ENABLED='true',RETRO_PEER_RELAY_URL=a.peer_relay,RETRO_PEER_SIGNING_KEY=secret,POKEPORT_PEER_LIBRARY=str(a.peer_library.resolve()),POKEPORT_PEER_CA=str(a.peer_ca.resolve()))
    traffic={'wire_bytes':0,'picture_messages':0,'requests':0};traffic_lock=threading.Lock()
    with(out/'bootstrap.log').open('w')as log:
        qa.qa_run([str(php),'artisan','migrate','--force','--no-interaction'],cwd=server,env=env,stdout=log,stderr=log,check=True)
        qa.qa_run([str(php),'tests/Fixtures/pinball_http.php'],cwd=server,env=env,stdout=log,stderr=log,check=True)
        qa.qa_run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(out/'key.pem'),'-out',str(out/'cert.pem'),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost'],stdout=log,stderr=log,check=True)
    os.chmod(out/'key.pem',0o600)
    hp,tp=port(),port();children=[];streams=[];gateway=None
    class Gateway(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            body=self.rfile.read(int(self.headers.get('Content-Length','0')))
            with traffic_lock:
                traffic['requests']+=1
                if self.path.endswith('/wire'):
                    traffic['wire_bytes']+=len(body)
                    traffic['picture_messages']+=sum(json.loads(row['body']).get('kind')=='picture'for row in json.loads(body).get('messages',[]))
            request=urllib.request.Request('http://127.0.0.1:'+str(hp)+self.path,data=body,method='POST',headers={k:v for k,v in self.headers.items()if k.lower()not in('host','connection','content-length')})
            try:response=urllib.request.urlopen(request,timeout=30)
            except urllib.error.HTTPError as error:response=error
            data=response.read();self.send_response(response.status);self.send_header('Content-Type',response.headers.get('Content-Type','application/json'));self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        def log_message(self,*args):pass
    try:
        stream=(out/'server.log').open('w');streams.append(stream)
        backend=qa.qa_popen([str(php),'-d','opcache.enable_cli=1','-S','127.0.0.1:'+str(hp),'-t','public','public/index.php'],cwd=server,env=env,stdout=stream,stderr=stream);children.append(backend)
        for _ in range(100):
            try:
                with socket.create_connection(('127.0.0.1',hp),timeout=.2):break
            except OSError:time.sleep(.1)
        else:raise AssertionError('Local PHP server did not start')
        # FPM normally caches these classes. Warm the development server before
        # measuring clients, so a first autoload is not a network timeout.
        accounts=json.loads((out/'accounts.json').read_text())
        for account in accounts:
            request=urllib.request.Request('http://127.0.0.1:'+str(hp)+'/api/cloud/v1/play/presence',data=b'{"available":false}',headers={'Authorization':'Bearer '+account['token'],'Content-Type':'application/json','Accept':'application/json'})
            with urllib.request.urlopen(request,timeout=120)as response:assert response.status==200
        print('Isolated PHP application warmed; launching two native clients.',flush=True)
        gateway=http.server.ThreadingHTTPServer(('127.0.0.1',tp),Gateway);ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(out/'cert.pem',out/'key.pem');gateway.socket=ctx.wrap_socket(gateway.socket,server_side=True);threading.Thread(target=gateway.serve_forever,daemon=True).start()
        session=json.loads((work/'library.json').read_text());session['locale']='en';session['volume']=0
        accounts=json.loads((out/'accounts.json').read_text())
        for index,account in enumerate(accounts,1):
            identity='oasc-pinball-qa-http-'+a.label+'-'+str(index)
            profile=Path.home()/'Library/Application Support/LOVE'/identity;qa.qa_source(profile);qa.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
            (profile/'pinball-display.json').write_text(json.dumps({'full_table':True}))
            host=ROOT/'.local/engine-parity'/('pinball-http-'+a.label+'-'+str(index));qa.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
            (host/'src').symlink_to(ROOT/'src',target_is_directory=True)
            (host/'main.lua').write_bytes((ROOT/'tests/pinball_http_peer.lua').read_bytes())
            (host/'conf.lua').write_text('function love.conf(t) t.identity="'+identity+'";t.version="12.0";t.window.width=1000;t.window.height=720;t.window.vsync=0;t.console=true end')
            private=dict(session,player=str(out/('player-'+str(index))));Path(private['player']).mkdir(exist_ok=True)
            config=out/('client-'+str(index)+'.json');config.write_text(json.dumps(account|{'seat':index,'peer_mode':a.peer_mode,'session':private,'field':0,'url':'https://localhost:'+str(tp)+'/api/cloud/v1/play/','output':str(out/('result-'+str(index)+'.json'))}));os.chmod(config,0o600)
            stream=(out/('peer-'+str(index)+'.log')).open('w');streams.append(stream)
            executable=love
            if sys.platform=='darwin':
                original=next(parent for parent in love.parents if parent.suffix=='.app')
                bundle=host/'.qa-runtime.app';qa.qa_run(['cp','-cR',str(original),str(bundle)],check=True)
                metadata=bundle/'Contents/Info.plist';info=plistlib.loads(metadata.read_bytes());info['CFBundleIdentifier']='de.roxas2712.qa.pinball.'+a.label+'.'+str(index);info['CFBundleName']='Pinball HTTP QA '+str(index);metadata.write_bytes(plistlib.dumps(info))
                qa.qa_run(['codesign','--force','--deep','--sign','-','--entitlements',str(ROOT/'scripts/macos-entitlements.plist'),str(bundle)],capture_output=True,check=True)
                executable=bundle/'Contents/MacOS'/love.name
            peer=qa.qa_popen([str(executable),str(host)],cwd=ROOT,env=env|{'PINBALL_HTTP_CONFIG':str(config),'CURL_CA_BUNDLE':str(out/'cert.pem')},stdout=stream,stderr=stream);children.append(peer)
        deadline=time.monotonic()+420
        while any(child.poll()is None for child in children[1:]):
            assert time.monotonic()<deadline,'Native HTTPS clients exceeded their deadline'
            time.sleep(.5)
        print('Native client process exit codes:',[child.returncode for child in children[1:]],flush=True)
        results=[json.loads((out/('result-'+str(index)+'.json')).read_text())for index in(1,2)]
        assert all(child.returncode==0 for child in children[1:]),results
        assert all(result['passed']and result['native']and result['wire_drained']for result in results),results
        assert all(result.get('opponent_view')and not result['opponent_view'].get('error')and result['opponent_view']['received']>0 and not result.get('wire_error')for result in results),results
        assert results[0]['checkpoint']==results[1]['checkpoint'],'Different native initial RAM checkpoints'
        assert results[1]['prepared_from_missing'],'Missing-import invitation was not exercised'
        assert results[0]['duel']['localScore']==results[1]['duel']['remoteScore']and results[1]['duel']['localScore']==results[0]['duel']['remoteScore']
        assert sorted(result['result']for result in results)in(['loss','win'],['draw','draw'])
        with sqlite3.connect('file:'+str(database)+'?mode=ro',uri=True)as db:
            assert db.execute("select count(*) from retro_play_invites where mode='pinball' and state='finished'").fetchone()[0]==1
            assert db.execute("select count(*) from retro_play_messages where body is not null").fetchone()[0]==0,'Unacknowledged final messages remain'
        if a.peer_mode!='off':
            assert all(r.get('peer_view')and not r['peer_view'].get('error')and r['peer_view']['received']>10 for r in results),results
            if a.peer_mode in('direct','switch'):assert all(r['peer_view']['directFrames']>10 for r in results),results
            if a.peer_mode in('relay','switch'):assert all(r['peer_view']['relayFrames']>10 for r in results),results
            if a.peer_mode=='switch':assert any(r['peer_view'].get('forcedFallback')for r in results),results
            assert traffic['picture_messages']<30,'Pictures still consume the SQL-backed wire after peer setup'
        audio_ok=all(result.get('steady_audio_restarts')==0 and result.get('steady_seconds',0)>60 for result in results)
        report={'passed':audio_ok,'gameplay_qualified':True,'peer_mode':a.peer_mode,'http_traffic':traffic,'server_final_tail_drained':True,'kind':'two actual native clients over local HTTPS','production_qualified':False,'steady_audio_qualified':audio_ok,'results':results};(out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
        assert audio_ok,'Native gameplay passed, but the zero-starvation audio target failed; see report.json'
    finally:
        if gateway:gateway.shutdown();gateway.server_close()
        for child in reversed(children):
            if child.poll()is None:child.terminate()
        for child in reversed(children):
            try:child.wait(timeout=15)
            except Exception:child.kill();child.wait()
        for stream in streams:stream.close()
if __name__=='__main__':main()
