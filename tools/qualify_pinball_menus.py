#!/usr/bin/env python3
"""Drive original Pinball menus with actual guest input and private SRAM.

Contributions by Roxas2712. Does not fabricate catches, unlock bonus fields or
certify a complete playthrough / hardware link / e-Reader session.
"""
import atexit
import ctypes as c
import hashlib
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]

def main():
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    work=ROOT/'.local/pinball-rs';out=ROOT/'.local/qa/pinball-original-menus'
    for p in (ROOT,work,Path(sys.executable)):qa.qa_source(p)
    qa.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    qa.qa_profile(out/'player');(out/'player').mkdir(exist_ok=True)
    manifest=json.loads((work/'library.json').read_text());reports=[]
    for locale in ('en','de'):
        session=dict(manifest)
        if locale=='de':session.update(manifest['variants']['eu'])
        for key in ('rom','bios','bridge'):qa.qa_source(Path(session[key]))
        lib=c.CDLL(session['bridge'])
        for name,result,args in [('open',c.c_void_p,[c.c_char_p]*3),('close',c.c_int,[c.c_void_p]),('step',c.c_int,[c.c_void_p,c.c_uint16]),
            ('read',c.c_uint32,[c.c_void_p,c.c_uint32,c.c_uint32]),('view',c.c_int,[c.c_void_p,c.c_int]),
            ('picture',c.c_void_p,[c.c_void_p,c.POINTER(c.c_uint32),c.POINTER(c.c_uint32)])]:
            fn=getattr(lib,'ascendant_pinball_'+name);fn.restype=result;fn.argtypes=args
        save=out/'player'/(locale+'.sav');m=lib.ascendant_pinball_open(session['rom'].encode(),session['bios'].encode(),str(save).encode());assert m
        r=lambda a,n=1:lib.ascendant_pinball_read(m,a,n)
        state=lambda:(r(0x0200B0C2),r(0x0200B0C3))
        ticks=0;seen=set();pictures={};w,h=c.c_uint32(),c.c_uint32()
        def step(keys=0,n=1):
            nonlocal ticks
            for _ in range(n):assert lib.ascendant_pinball_step(m,keys);ticks+=1;seen.add(state()[0])
        def wait(condition,buttons=None,limit=2200):
            for _ in range(limit):
                if condition():return
                step(buttons()if buttons else 0)
            raise AssertionError('Menu transition timed out: '+str(state()))
        try:
            assert lib.ascendant_pinball_view(m,1)
            def boot():
                st=state()
                if st[0]==12 and st[1]>0 and ticks%12<3:return 1 if r(0x0202C724)==2 else 128
                return 1 if st[0]in(0,1)and ticks%45<3 else 0
            wait(lambda:state()==(1,4),boot)
            for index,target,name in ((1,5,'pokedex'),(2,4,'options'),(3,8,'high-scores')):
                wait(lambda:r(0x02002888)==index,lambda:128 if ticks%12==0 else 0,limit=100)
                step(0,2);step(1);step(0)
                wait(lambda:state()[0]==target and state()[1]>=1)
                step(0,45)
                ptr=lib.ascendant_pinball_picture(m,c.byref(w),c.byref(h));assert(w.value,h.value)==(240,160),'Original menu must retain its complete native layout'
                pixels=c.string_at(ptr,w.value*h.value*4);assert len(set(pixels[::4]))>8
                pictures[name]=hashlib.sha256(pixels).hexdigest()
                if name=='options':
                    # Sound-test select, a second track, and back to options.
                    step(1);step(0,10);step(16);step(0,10);step(2);step(0,10)
                wait(lambda:state()==(1,4),lambda:2 if ticks%12==0 else 0,limit=500)
        finally:assert lib.ascendant_pinball_close(m)
        assert save.exists()and save.stat().st_size==32768,'Options SRAM must flush when closing'
        # Reopen the same native SRAM; no guest-memory writes or fabricated data.
        m=lib.ascendant_pinball_open(session['rom'].encode(),session['bios'].encode(),str(save).encode());assert m;assert lib.ascendant_pinball_close(m)
        reports.append({'locale':locale,'states_seen':sorted(seen),'native_menu_picture_sha256':pictures,'sram_bytes':save.stat().st_size,'reopened':True})
        print(json.dumps(reports[-1]),flush=True)
    (out/'report.json').write_text(json.dumps({'passed':True,'cases':reports},indent=2)+'\n')
if __name__=='__main__':main()
