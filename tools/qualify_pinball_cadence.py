#!/usr/bin/env python3
"""Check native Pinball game/audio cadence, not just host presentation FPS.

Private USA + European ROM installations are required. No audio/ROM/save bytes
are published. Contributions by Roxas2712.
"""
import argparse
import atexit
import ctypes as c
import json
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]

def probe(locale,field):
    session=json.loads((ROOT/'.local/pinball-rs/library.json').read_text())
    if locale!='en':session.update(session['variants']['eu'])
    lib=c.CDLL(session['bridge'])
    for name,result,arguments in [('open',c.c_void_p,[c.c_char_p]*3),('close',c.c_int,[c.c_void_p]),
        ('step',c.c_int,[c.c_void_p,c.c_uint16]),('frame',c.c_uint64,[c.c_void_p]),
        ('read',c.c_uint32,[c.c_void_p,c.c_uint32,c.c_uint32]),
        ('audio',c.c_void_p,[c.c_void_p,c.POINTER(c.c_size_t),c.POINTER(c.c_uint32)])]:
        fn=getattr(lib,'ascendant_pinball_'+name);fn.restype=result;fn.argtypes=arguments
    m=lib.ascendant_pinball_open(session['rom'].encode(),session['bios'].encode(),b'');assert m
    read=lambda address,n=1:lib.ascendant_pinball_read(m,address,n)
    try:
        # Reach a fresh table using genuine guest inputs, never writing RAM.
        steady=0;start=None;deltas=[];vblanks=[];locked=0;seconds=0;rates=set()
        count=c.c_size_t();rate=c.c_uint32()
        for n in range(4000):
            main,sub=read(0x0200B0C2),read(0x0200B0C3);buttons=0
            if main==12 and sub>0 and n%12<3:buttons=1 if read(0x0202C724)==2 else 128
            elif main in (0,1) and n%45<3:buttons=1
            elif main==10 and n%45<3:
                buttons=(16 if field else 32)if read(0x02002842,2)==0 and read(0x02002840,2)!=field else 1
            playing=main==2 and sub==1 and read(0x0200B0C4)==field
            before=read(0x0200B10C,4);frame=lib.ascendant_pinball_frame(m)
            assert lib.ascendant_pinball_step(m,buttons)
            lib.ascendant_pinball_audio(m,c.byref(count),c.byref(rate))
            steady=steady+1 if playing else 0
            if steady>60:
                if start is None:start=n
                deltas.append(read(0x0200B10C,4)-before)
                vblanks.append(lib.ascendant_pinball_frame(m)-frame)
                info=read(0x03007FF0,4);locked+=read(info,4)!=0x68736D53
                rates.add(rate.value);seconds+=count.value/rate.value
                if len(deltas)==240:break
        assert len(deltas)==240,'Fresh table did not reach the cadence window'
        report={'locale':locale,'field':field,'frames':len(deltas),'measurement_start':start,
            'game_steps':sum(deltas),'missed_game_steps':deltas.count(0),
            'vblank_counts':sorted(set(vblanks)),'mixer_locked_at_boundary':locked,
            'audio_rates':sorted(rates),'audio_seconds':seconds,
            'expected_seconds':240*280896/16777216}
        report['passed']=all(d==1 for d in deltas) and all(d==1 for d in vblanks) and locked==0 and abs(seconds-report['expected_seconds'])<.002
        return report
    finally:assert lib.ascendant_pinball_close(m)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--worker',choices=('en','de'));args=p.parse_args()
    if args.worker:
        report=probe(args.worker,0 if args.worker=='en'else 1);print(json.dumps(report));return 0 if report['passed']else 1
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    work=ROOT/'.local/pinball-rs';out=ROOT/'.local/qa/pinball-cadence'
    for path in (ROOT,work,Path(sys.executable)):qa.qa_source(path)
    session=json.loads((work/'library.json').read_text())
    for variant in (session,*session.get('variants',{}).values()):
        for key in ('rom','bios','bridge'):
            if variant.get(key):qa.qa_source(Path(variant[key]))
    qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True);reports=[]
    for locale in ('en','de'):
        result=qa.qa_run([sys.executable,str(Path(__file__).resolve()),'--worker',locale],cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/(locale+'.log')).write_text(result.stdout+result.stderr)
        report=json.loads(result.stdout.strip().splitlines()[-1]);reports.append(report)
        print(json.dumps(report),flush=True)
        if result.returncode:raise RuntimeError('Native game/audio cadence failed: '+locale)
    (out/'report.json').write_text(json.dumps(reports,indent=2)+'\n')
    return 0
if __name__=='__main__':raise SystemExit(main())
