#!/usr/bin/env python3
"""Bounded public HTTPS control-load test, not native played battles.
Uses 40 explicit disposable accounts, <=8 HTTP requests in flight, no video,
ROMs, saves, game winners or rewards. Operator cleans the fixture afterwards.
Contributions by Roxas2712.
"""
import argparse,atexit,concurrent.futures,hashlib,json,statistics,sys,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--fixture',type=Path,required=True);p.add_argument('--seconds',type=int,default=10);p.add_argument('--max-inflight',type=int,default=8);p.add_argument('--label',required=True);a=p.parse_args()
 assert a.label.replace('-','').isalnum()and 5<=a.seconds<=30 and 1<=a.max_inflight<=8
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for source in(ROOT,a.fixture,ROOT/'.local/pinball-rs/library.json',Path(sys.executable)):qa.qa_source(source.resolve())
 f=json.loads(a.fixture.read_text());assert f.get('qa_only')is True and len(f['accounts'])==40 and f['url']=='https://pokexpert.de/api/cloud/v1/play/'
 out=ROOT/'.local/qa'/('pinball-load-'+a.label);qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True);assert not(out/'report.json').exists()
 s=json.loads((ROOT/'.local/pinball-rs/library.json').read_text());rules={'protocol':1,'field':0,'frames':18000,'seed':0,'rom':s['rom_sha1'],'backend':s['backend'],'content':s['content'],'locale':'en'}
 fingerprint=hashlib.sha256('\n'.join(['pinball-duel-v1',rules['rom'],rules['backend'],rules['content']]).encode()).hexdigest()
 context={'edition':'pinballrs','fingerprint':fingerprint,'available':True,'pinball':{'protocol':1,'field':0,'frames':18000,'locale':'en'}}
 def request(account,path,payload):
  body=json.dumps(payload,separators=(',',':')).encode();req=urllib.request.Request(f['url']+path,data=body,headers={'Authorization':'Bearer '+account['token'],'Content-Type':'application/json','Accept':'application/json'})
  try:
   with urllib.request.urlopen(req,timeout=20)as r:doc=json.loads(r.read())
  except urllib.error.HTTPError as e:raise RuntimeError('Public load HTTP '+str(e.code)+' at '+path.rsplit('/',1)[-1])
  assert doc.get('account_id')==account['account'],'Account response scope changed';return doc,len(body)
 def setup(pair):
  left,right=pair;one,_=request(left,'presence',context);two,_=request(right,'presence',context)
  d,_=request(left,'invites',{'device':two['device'],'mode':'pinball','fingerprint':fingerprint,'rules':rules});id=d['invite']['id']
  request(right,'invites/'+id+'/respond',{'accept':True})
  for actor in pair:request(actor,'invites/'+id+'/enter',{'fingerprint':fingerprint,'rules':rules})
  return[{'account':actor,'id':id,'sent':0,'after':0}for actor in pair]
 def exchange(client,packets,close,enqueued,presence=False):
  rows=[{'sequence':client['sent']+i+1,'body':json.dumps({'type':'pinball_duel','protocol':1,'kind':'ping'},separators=(',',':'))}for i in range(packets)]
  if presence:request(client['account'],'presence',context|{'available':False})
  d,size=request(client['account'],'invites/'+client['id']+'/wire',{'battle':client['id'],'ticket':'','after':client['after'],'messages':rows,'close':close})
  assert d['sent']==client['sent']+packets;client['sent']=d['sent']
  for row in d['messages']:
   assert row['sequence']==client['after']+1 and json.loads(row['body'])['type']=='pinball_duel';client['after']=row['sequence']
  return(time.monotonic()-enqueued,size,d)
 report={'passed':False,'scope':'Synthetic public HTTPS control traffic; not native played battles or 20 media streams','max_http_inflight':a.max_inflight,'target_requests_per_client_per_second':1,'ordered_packets_per_request':2,'stages':[]};active=[]
 try:
  with concurrent.futures.ThreadPoolExecutor(max_workers=a.max_inflight)as pool:
   for count in(5,10,20):
    pairs=[f['accounts'][i:i+2]for i in range(0,count*2,2)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4)as setup_pool:active=[c for pair in setup_pool.map(setup,pairs)for c in pair]
    samples=[];bytes_sent=0;started=time.monotonic();deadline=started;iterations=0
    while time.monotonic()-started<a.seconds:
     enqueued=time.monotonic();jobs=[pool.submit(exchange,c,2,False,enqueued,iterations%5==0)for c in active]
     for job in jobs:
      latency,size,_=job.result();samples.append(latency);bytes_sent+=size
     iterations+=1;deadline+=1
     if deadline>time.monotonic():time.sleep(deadline-time.monotonic())
     assert time.monotonic()-enqueued<5,'Control queue exceeded the safety window; stopped before increasing load'
    # Both close flags and the complete receive cursors must be sent. No winner.
    for n in range(4):
     jobs=[pool.submit(exchange,c,0,True,time.monotonic())for c in active];docs=[job.result()[2]for job in jobs]
    assert all(d['peer_closed']and not d['messages']for d in docs)
    for i in range(0,len(active),2):assert active[i]['after']==active[i+1]['sent']and active[i+1]['after']==active[i]['sent']
    samples.sort();stage={'duels':count,'clients':len(active),'seconds':time.monotonic()-started,'iterations':iterations,'requests':len(samples),'wire_payload_bytes':bytes_sent,'mean_ms':statistics.mean(samples)*1000,'p95_ms':samples[int((len(samples)-1)*.95)]*1000,'max_ms':max(samples)*1000,'errors':0,'final_tail_drained':True};report['stages'].append(stage);print(json.dumps(stage),flush=True);active=[]
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
   report['passed']=True
 except BaseException as error:
  report['error']=str(error)
  if active:
   report['failed_stage']={'duels':len(active)//2,'completed_requests':len(samples),'iterations':iterations,'queue_safety_ms':5000,'max_observed_ms':max(samples)*1000 if samples else None,'p95_ms':sorted(samples)[int((len(samples)-1)*.95)]*1000 if samples else None}
  raise
 finally:
  for c in active[::2]:
   try:request(c['account'],'invites/'+c['id']+'/cancel',{})
   except Exception:pass
  (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
