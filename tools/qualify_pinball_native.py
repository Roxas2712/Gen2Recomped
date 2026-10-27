#!/usr/bin/env python3
"""Verify cached/reference native pictures and RAM with private cartridges.

Contributions by Roxas2712. Writes hashes and timing, never cartridge bytes.
"""
import argparse
import atexit
import ctypes as c
import hashlib
import json
import os
from pathlib import Path
import statistics
import sys
import time
ROOT=Path(__file__).resolve().parents[1]

def run_child(args):
    session=json.loads((ROOT/'.local/pinball-rs/library.json').read_text())
    if args.locale!='en':session.update(session['variants']['eu'])
    if args.library_root:
        session['bridge']=str(args.library_root/('native'if args.locale=='en'else'native-eu')/Path(session['bridge']).name)
    lib=c.CDLL(session['bridge'])
    functions=[('open',c.c_void_p,[c.c_char_p]*3),('error',c.c_char_p,[]),('step',c.c_int,[c.c_void_p,c.c_uint16]),
      ('view',c.c_int,[c.c_void_p,c.c_int]),('close',c.c_int,[c.c_void_p]),('read',c.c_uint32,[c.c_void_p,c.c_uint32,c.c_uint32]),
      ('picture',c.c_void_p,[c.c_void_p,c.POINTER(c.c_uint32),c.POINTER(c.c_uint32)]),('checkpoint',c.c_char_p,[c.c_void_p]),
      ('state',c.c_int,[c.c_void_p,c.c_char_p,c.c_int]),
      ('diagnostics',c.c_int,[c.c_void_p,c.POINTER(c.c_double)]),
      ('table_stats',c.c_int,[c.c_void_p,c.POINTER(c.c_uint32),c.POINTER(c.c_uint32)])]
    for name,result,arguments in functions:
        fn=getattr(lib,'ascendant_pinball_'+name);fn.restype=result;fn.argtypes=arguments
    machines=[];pictures=[];ram=[];cost=[];reused=rendered=0;states={};max_score=[0,0]
    width,height,a,b=c.c_uint32(),c.c_uint32(),c.c_uint32(),c.c_uint32()
    timings=c.c_double*4;slow_steps=[]
    try:
        for _ in range(2):
            m=lib.ascendant_pinball_open(session['rom'].encode(),session['bios'].encode(),b'');assert m,lib.ascendant_pinball_error()
            machines.append(m);assert lib.ascendant_pinball_view(m,1)
            assert lib.ascendant_pinball_diagnostics(m,None)
        for n in range(args.frames):
            total=0;playing=False
            for seat,m in enumerate(machines):
                read=lambda address,size=1:lib.ascendant_pinball_read(m,address,size)
                main,sub=read(0x0200B0C2),read(0x0200B0C3);buttons=0
                if main==12 and args.locale=='de'and sub>0 and n%12<3:buttons=1 if read(0x0202C724)==2 else 128
                elif main in (0,1,8):buttons=1 if n%45<3 else 0
                elif main==10 and n%45<3:buttons=(16 if args.field else 32)if read(0x02002842,2)==0 and read(0x02002840,2)!=args.field else 1
                elif main in (2,3):
                    period=120 if seat==0 else 97;buttons=1 if n%period<period*.46 else 32 if n%period<period*.92 else 0
                    playing=True
                t=time.perf_counter();assert lib.ascendant_pinball_step(m,buttons),lib.ascendant_pinball_error();step_ms=(time.perf_counter()-t)*1000;total+=step_ms
                if step_ms>25 and len(slow_steps)<128:
                    values=timings();assert lib.ascendant_pinball_diagnostics(m,values)
                    slow_steps.append({'frame':n,'seat':seat,'wall_ms':step_ms,'simulation_ms':values[0]*1000,'composition_ms':values[1]*1000,'thread_cpu_ms':values[2]*1000,'interpreted':values[3]})
                key=f'{seat}:{main}:{sub}';states[key]=states.get(key,0)+1
                pointer=read(session.get('game_pointer_address',0x020314E0),4)
                if 0x02000000<=pointer<0x02040000:max_score[seat]=max(max_score[seat],read(pointer+0x44,4)+100000000*read(pointer+0x48,4))
                pixels=lib.ascendant_pinball_picture(m,c.byref(width),c.byref(height));assert pixels
                pictures.append([width.value,height.value,hashlib.sha256(c.string_at(pixels,width.value*height.value*4)).hexdigest()])
                assert lib.ascendant_pinball_table_stats(m,c.byref(a),c.byref(b));reused+=a.value;rendered+=b.value
                if n%120==0 or n==args.frames-1:ram.append(lib.ascendant_pinball_checkpoint(m).decode())
            if playing:cost.append(total)
        report={'frames_per_seat':args.frames,'pictures':pictures,'ram':ram,'max_scores':max_score,'states':states,
          'two_guest_mean_ms':statistics.mean(cost),'two_guest_p95_ms':sorted(cost)[int(len(cost)*.95)],
          'two_guest_p99_ms':sorted(cost)[int(len(cost)*.99)],'two_guest_max_ms':max(cost),'reused_rows':reused,'rendered_rows':rendered,'slow_steps':slow_steps}
        # Exercise the host layout/cache reset as well as the native snapshot.
        # Use a fully expanded board so a stale recovery gate is observable.
        m=machines[0]
        for _ in range(1200):
            ptr=lib.ascendant_pinball_picture(m,c.byref(width),c.byref(height))
            if width.value>240:break
            assert lib.ascendant_pinball_step(m,1)
        assert width.value>240,'No expanded board available for quick-state replay'
        def image():
            ptr=lib.ascendant_pinball_picture(m,c.byref(width),c.byref(height))
            return [width.value,height.value,hashlib.sha256(c.string_at(ptr,width.value*height.value*4)).hexdigest()]
        state=str(args.output.parent/'states'/(args.output.stem+'.state')).encode()
        before=image();checkpoint=lib.ascendant_pinball_checkpoint(m)
        assert lib.ascendant_pinball_state(m,state,0),lib.ascendant_pinball_error()
        def replay():
            result=[]
            for i in range(40):
                assert lib.ascendant_pinball_step(m,1 if i<20 else 32)
                result.append([image(),lib.ascendant_pinball_checkpoint(m).decode()])
            return result
        expected=replay()
        assert lib.ascendant_pinball_state(m,state,1),lib.ascendant_pinball_error()
        assert image()==before,'Quick-state load changed the current full-table picture'
        assert lib.ascendant_pinball_checkpoint(m)==checkpoint,'Quick-state load changed RAM'
        assert replay()==expected,'Quick-state replay changed pixels/RAM'
        report['quick_state_replay_frames']=40;report['quick_state_immediate_picture_equal']=True
        args.output.write_text(json.dumps(report))
    finally:
        for m in reversed(machines):assert lib.ascendant_pinball_close(m),lib.ascendant_pinball_error()

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frames',type=int,default=4200)
    parser.add_argument('--library-root',type=Path)
    parser.add_argument('--label',default='cached-reference')
    parser.add_argument('--child',action='store_true',help=argparse.SUPPRESS)
    parser.add_argument('--locale',choices=('en','de'),default='en',help=argparse.SUPPRESS)
    parser.add_argument('--field',type=int,default=0,help=argparse.SUPPRESS)
    parser.add_argument('--output',type=Path,help=argparse.SUPPRESS)
    args=parser.parse_args()
    if args.child:return run_child(args)
    if args.frames<1200 or not args.label.replace('-','').isalnum():parser.error('Use at least 1200 frames and an alphanumeric label.')
    if args.library_root:args.library_root=args.library_root.resolve(strict=True)
    helper=Path.home()/'.local/lib/origami-qa-storage/active-tools';sys.path.insert(0,str(helper if helper.is_dir()else ROOT/'tools'))
    import qa_storage as qa
    qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
    work=ROOT/'.local/pinball-rs';config=json.loads((work/'library.json').read_text())
    cache=ROOT/'.local/qa'/('pinball-native-'+args.label);profile=cache/'states'
    for path in (ROOT,work,Path(sys.executable),args.library_root,profile):
        if path:qa.qa_source(path)
    for variant in [config,*config.get('variants',{}).values()]:
        for key in ('rom','bios','bridge'):
            if variant.get(key):qa.qa_source(Path(variant[key]))
    qa.qa_cache(cache);cache.mkdir(parents=True,exist_ok=True)
    qa.qa_profile(profile);profile.mkdir(parents=True,exist_ok=True)
    aggregate={'passed':True,'cases':[]}
    for locale,field in [('en',0),('de',1)]:
        runs={}
        for mode in ('reference','cached'):
            name=f'{locale}-{field}-{mode}';output=cache/(name+'.json')
            command=[sys.executable,str(Path(__file__).resolve()),'--child','--frames',str(args.frames),'--locale',locale,'--field',str(field),'--output',str(output)]
            if args.library_root:command+=['--library-root',str(args.library_root)]
            env=dict(os.environ);env.pop('ASCENDANT_PINBALL_REFERENCE_TABLE',None)
            if mode=='reference':env['ASCENDANT_PINBALL_REFERENCE_TABLE']='1'
            print('Native '+name,flush=True)
            with(cache/(name+'.log')).open('w')as log:result=qa.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log,timeout=300)
            if result.returncode:print((cache/(name+'.log')).read_text()[-5000:]);return result.returncode
            runs[mode]=json.loads(output.read_text())
        ref,current=runs['reference'],runs['cached']
        assert ref['pictures']==current['pictures'],'Cached/reference pixels differ: '+locale
        assert ref['ram']==current['ram'],'Presentation changed guest RAM: '+locale
        case={'locale':locale,'field':field,'frames_per_seat':args.frames,'compared_images':len(ref['pictures']),
          'compared_ram_checkpoints':len(ref['ram']),'pixels_equal':True,'ram_equal':True}
        for mode,data in runs.items():case[mode]={k:v for k,v in data.items()if k not in ('pictures','ram')}
        aggregate['cases'].append(case);print(json.dumps(case),flush=True)
    (cache/'summary.json').write_text(json.dumps(aggregate,indent=2)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
