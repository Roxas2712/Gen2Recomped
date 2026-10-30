"""Qualify real loopback HTTPS saves using disposable Laravel accounts/profiles.

This exercises the desktop curl path, not a Windows OS or native game runtime.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse, atexit, base64, http.client, http.server, json, os, socket, ssl, threading, time
from pathlib import Path
import qa_storage as qa

ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--server',type=Path,required=True);p.add_argument('--php',type=Path,required=True)
 p.add_argument('--lua-library',type=Path,required=True);a=p.parse_args()
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for source in [ROOT,a.server,a.php,a.lua_library]:qa.qa_source(source)
 out=ROOT/'.local/qa/cloud-save-ux-20261030'/('https-'+str(time.time_ns()))
 qa.qa_cache(out);out.mkdir(mode=0o700,parents=True);qa.qa_limit_output(out,512*1024*1024)
 for n in ['framework/cache/data','framework/sessions','framework/views','logs']:(out/'storage'/n).mkdir(parents=True)
 db=out/'test.sqlite';db.touch()
 env=dict(os.environ,APP_ENV='testing',APP_DEBUG='false',APP_KEY='base64:'+base64.b64encode(os.urandom(32)).decode(),DB_CONNECTION='sqlite',DB_DATABASE=str(db),DB_URL='',CACHE_STORE='file',SESSION_DRIVER='array',MAIL_MAILER='array',QUEUE_CONNECTION='sync',BCRYPT_ROUNDS='4',RETRO_CLOUD_ENABLED='true',LARAVEL_STORAGE_PATH=str(out/'storage'),APP_CONFIG_CACHE=str(out/'config.php'),APP_ROUTES_CACHE=str(out/'routes.php'),LOG_CHANNEL='stderr',PINBALL_HTTP_FIXTURE=str(out/'accounts.json'),RETRO_QA_LUA_LIBRARY=str(a.lua_library))
 with(out/'bootstrap.log').open('w')as log:
  for args in [['artisan','migrate','--force','--no-interaction'],['tests/Fixtures/pinball_http.php']]:qa.qa_run([str(a.php),*args],cwd=a.server,env=env,stdout=log,stderr=log,check=True)
 accounts=json.loads((out/'accounts.json').read_text())
 # A second session on the same fixture account represents the other device.
 seed=out/'second-device.php'
 seed.write_text("<?php require "+json.dumps(str(a.server/'vendor/autoload.php'))+"; $app=require "+json.dumps(str(a.server/'bootstrap/app.php'))+"; $app->make(Illuminate\\Contracts\\Console\\Kernel::class)->bootstrap(); $f=getenv('PINBALL_HTTP_FIXTURE'); $a=json_decode(file_get_contents($f),true); $u=App\\Models\\User::findOrFail($a[0]['account']); $t=bin2hex(random_bytes(32)); Illuminate\\Support\\Facades\\DB::table('cloud_sessions')->insert(['id'=>hash('sha256',$t),'user_id'=>$u->id,'label'=>'Other isolated device','password_stamp'=>App\\Services\\RetroCloud::passwordStamp($u),'expires_at'=>null,'created_at'=>now()]); $a[]=['account'=>(string)$u->id,'token'=>$t];file_put_contents($f,json_encode($a));")
 qa.qa_run([str(a.php),str(seed)],cwd=a.server,env=env,check=True,capture_output=True)
 accounts=json.loads((out/'accounts.json').read_text())
 with socket.socket()as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
 log=(out/'server.log').open('w');backend=None;proxy=None
 try:
  backend=qa.qa_popen([str(a.php),'-S','127.0.0.1:'+str(port),'-t','public','public/index.php'],cwd=a.server,env=env,stdout=log,stderr=log)
  for _ in range(100):
   try:
    with socket.create_connection(('127.0.0.1',port),timeout=.2):break
   except OSError:time.sleep(.1)
  qa.qa_run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost','-keyout',str(out/'key.pem'),'-out',str(out/'cert.pem')],check=True,capture_output=True)
  class Proxy(http.server.BaseHTTPRequestHandler):
   def log_message(self,*args):pass
   def forward(self):
    length=int(self.headers.get('Content-Length','0'));assert 0<=length<=2*1024*1024
    body=self.rfile.read(length)if length else None
    conn=http.client.HTTPConnection('127.0.0.1',port,timeout=30)
    conn.request(self.command,self.path,body,{k:v for k,v in self.headers.items()if k.lower()not in{'host','connection'}})
    result=conn.getresponse();data=result.read();self.send_response(result.status)
    self.send_header('Content-Type',result.getheader('Content-Type','text/plain'));self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data);conn.close()
   do_GET=forward;do_PUT=forward
  proxy=http.server.ThreadingHTTPServer(('127.0.0.1',0),Proxy)
  context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(out/'cert.pem',out/'key.pem');proxy.socket=context.wrap_socket(proxy.socket,server_side=True)
  thread=threading.Thread(target=proxy.serve_forever,daemon=True);thread.start()
  env['CURL_CA_BUNDLE']=str(out/'cert.pem')
  url='https://localhost:'+str(proxy.server_port)+'/api/cloud/v1'
  profiles=[]
  for n in ['device-a','device-b','foreign','revoked']:
   path=out/n;qa.qa_source(path);qa.qa_profile(path);(path/'saves/red').mkdir(parents=True);profiles.append(path)
  cases=[('upload',0,0,None),('restore',2,1,'HTTPS'),('partial',0,0,None),('restore',2,1,'Updated'),('foreign',1,2,None),('revoked',2,3,None)]
  for index,(mode,who,profile,expected)in enumerate(cases):
   config=out/('case-'+str(index)+'.json');config.write_text(json.dumps(accounts[who]|{'token':('0'*64 if mode=='revoked'else accounts[who]['token']),'mode':mode,'expected':expected,'profile':str(profiles[profile]),'url':url}));config.chmod(0o600)
   with(out/('case-'+str(index)+'.log')).open('w')as stream:qa.qa_run([os.sys.executable,str(ROOT/'tools/run_lua_check.py'),str(ROOT/'tests/engine/cloud_http_client.lua')],cwd=ROOT,env=env|{'CLOUD_SAVE_QA_CONFIG':str(config)},stdout=stream,stderr=stream,check=True,timeout=90)
  result={'passed':True,'checks':len(cases),'kind':'real isolated HTTPS Laravel server; desktop Lua clients; no Windows OS or native gameplay','productionQualified':False}
  (out/'report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result|{'output':str(out)}),flush=True)
 finally:
  if proxy:proxy.shutdown();proxy.server_close()
  if backend and backend.poll()is None:backend.terminate();backend.wait(timeout=10)
  log.close()
if __name__=='__main__':main()
