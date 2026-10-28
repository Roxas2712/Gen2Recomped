#!/usr/bin/env python3
"""Native background presentation must preserve guest RAM, PCM and exact states.
Private cartridges only. Contributions by Roxas2712.
"""
import argparse,atexit,ctypes as c,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def probe(locale,out):
 s=json.loads((ROOT/'.local/pinball-rs/library.json').read_text())
 if locale=='de':s.update(s['variants']['eu'])
 lib=c.CDLL(s['bridge'])
 for name,result,args in [('open',c.c_void_p,[c.c_char_p]*3),('close',c.c_int,[c.c_void_p]),('step_present',c.c_int,[c.c_void_p,c.c_uint16,c.c_int]),('view',c.c_int,[c.c_void_p,c.c_int]),('read',c.c_uint32,[c.c_void_p,c.c_uint32,c.c_uint32]),('checkpoint',c.c_char_p,[c.c_void_p]),('picture',c.c_void_p,[c.c_void_p,c.POINTER(c.c_uint32),c.POINTER(c.c_uint32)]),('audio',c.c_void_p,[c.c_void_p,c.POINTER(c.c_size_t),c.POINTER(c.c_uint32)]),('state',c.c_int,[c.c_void_p,c.c_char_p,c.c_int])]:
  fn=getattr(lib,'ascendant_pinball_'+name);fn.restype=result;fn.argtypes=args
 machines=[];pcm=c.c_size_t();rate=c.c_uint32();w=c.c_uint32();h=c.c_uint32()
 def picture(m):
  p=lib.ascendant_pinball_picture(m,c.byref(w),c.byref(h));assert p
  return(w.value,h.value,hashlib.sha256(c.string_at(p,w.value*h.value*4)).hexdigest())
 try:
  for _ in(0,1):
   m=lib.ascendant_pinball_open(s['rom'].encode(),s['bios'].encode(),b'');assert m;machines.append(m);assert lib.ascendant_pinball_view(m,1)
  checks=0
  for n in range(1500):
   read=lambda a,k=1:lib.ascendant_pinball_read(machines[0],a,k)
   main,sub=read(0x0200B0C2),read(0x0200B0C3);buttons=0
   if main==12 and sub>0 and n%12<3:buttons=1 if read(0x0202C724)==2 else 128
   elif main in(0,1,8)and n%45<3:buttons=1
   elif main==10 and n%45<3:
    field=1 if locale=='de'else 0;buttons=(16 if field else 32)if read(0x02002842,2)==0 and read(0x02002840,2)!=field else 1
   elif main in(2,3):buttons=1 if n%120<55 else 32 if n%120<110 else 0
   audio=[]
   for seat,m in enumerate(machines):
    assert lib.ascendant_pinball_step_present(m,buttons,int(seat==0 or n%10==0))
    p=lib.ascendant_pinball_audio(m,c.byref(pcm),c.byref(rate));audio.append((rate.value,pcm.value,hashlib.sha256(c.string_at(p,pcm.value*2)).digest()))
   assert audio[0]==audio[1],'Background mode changed native PCM'
   if n%60==0 or n==1499:
    assert lib.ascendant_pinball_checkpoint(machines[0])==lib.ascendant_pinball_checkpoint(machines[1]),'Background mode changed guest RAM'
    assert picture(machines[0])==picture(machines[1]),'Explicit picture read did not recover the current complete frame';checks+=1
  m=machines[1];assert lib.ascendant_pinball_step_present(m,0,0)
  state=out/(locale+'-hidden.state');assert lib.ascendant_pinball_state(m,str(state).encode(),0)
  before=picture(m);ram=lib.ascendant_pinball_checkpoint(m)
  def replay():
   values=[]
   for i in range(40):
    assert lib.ascendant_pinball_step_present(m,1 if i<20 else 32,1);values.append((picture(m),lib.ascendant_pinball_checkpoint(m)))
   return values
  expected=replay();assert lib.ascendant_pinball_state(m,str(state).encode(),1)
  assert picture(m)==before and lib.ascendant_pinball_checkpoint(m)==ram
  assert replay()==expected
  return{'locale':locale,'frames':1500,'pcm_blocks_equal':1500,'ram_picture_checks':checks,'hidden_state_replay_frames':40,'passed':True}
 finally:
  for m in machines:assert lib.ascendant_pinball_close(m)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--worker',choices=['en','de']);p.add_argument('--output',type=Path);a=p.parse_args()
 if a.worker:print(json.dumps(probe(a.worker,a.output)));return
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for v in(ROOT,ROOT/'.local/pinball-rs',Path(sys.executable)):qa.qa_source(v)
 session=json.loads((ROOT/'.local/pinball-rs/library.json').read_text())
 for variant in(session,*session.get('variants',{}).values()):
  for key in('rom','bios','bridge'):
   if variant.get(key):qa.qa_source(Path(variant[key]))
 out=ROOT/'.local/qa/pinball-background-presentation';qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
 reports=[]
 for locale in('en','de'):
  r=qa.qa_run([sys.executable,str(Path(__file__).resolve()),'--worker',locale,'--output',str(out)],cwd=ROOT,capture_output=True,text=True,timeout=300)
  (out/(locale+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
  reports.append(json.loads(r.stdout.strip().splitlines()[-1]));print(json.dumps(reports[-1]),flush=True)
 (out/'report.json').write_text(json.dumps(reports,indent=2)+'\n')
if __name__=='__main__':main()
