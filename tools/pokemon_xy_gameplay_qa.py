#!/usr/bin/env python3
"""Managed, isolated X/Y mod A/B and visible production-frontend gameplay QA.

Integration by Roxas2712. Original ROMs and player saves remain inputs only.
"""
from pathlib import Path
import argparse,ctypes,fcntl,json,os,plistlib,shutil,struct,subprocess,sys,time,zlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import pokemon_x_preflight as preflight
import pokemon_x_backend as backend
import pokemon_xy_library as library
CACHE=ROOT/'.local/qa/pokemon-xy-mod-gameplay'
STATE=Path.home()/'.cache/roxas2712-native-tests'

def status(state,detail):
    p=STATE/'xy.json';tmp=p.with_suffix('.pending')
    tmp.write_text(json.dumps(dict(owner='xy',state=state,pid=os.getpid(),time=time.time(),next=detail,etaSeconds=480 if state=='running'else 0),indent=2));tmp.replace(p)

class Bridge:
    class Picture(ctypes.Structure):_fields_=[('data',ctypes.c_void_p),('width',ctypes.c_uint32),('height',ctypes.c_uint32),('bytes',ctypes.c_size_t)]
    def __init__(self,session):
        self.lib=ctypes.CDLL(session['bridge']);l=self.lib
        l.ascendant_3ds_open.argtypes=[ctypes.c_char_p];l.ascendant_3ds_open.restype=ctypes.c_void_p
        l.ascendant_3ds_error.restype=ctypes.c_char_p
        l.ascendant_3ds_step.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.c_float,ctypes.c_float,ctypes.c_int,ctypes.c_int,ctypes.c_bool];l.ascendant_3ds_step.restype=ctypes.c_int
        l.ascendant_3ds_picture.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.POINTER(self.Picture)];l.ascendant_3ds_picture.restype=ctypes.c_bool
        l.ascendant_3ds_close.argtypes=[ctypes.c_void_p]
        self.handle=l.ascendant_3ds_open(json.dumps(session).encode());assert self.handle,l.ascendant_3ds_error()
    def step(self,buttons=0):assert self.lib.ascendant_3ds_step(self.handle,buttons,0,0,-1,-1,False)==0,self.lib.ascendant_3ds_error()
    def capture(self,path,index=0):
        p=self.Picture();assert self.lib.ascendant_3ds_picture(self.handle,index,ctypes.byref(p))
        data=ctypes.string_at(p.data,p.bytes)
        def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v))
        raw=b''.join(b'\0'+data[y*p.width*4:(y+1)*p.width*4]for y in range(p.height))
        path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',p.width,p.height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
    def close(self):self.lib.ascendant_3ds_close(self.handle)

def session(edition,data):
    row=json.loads((backend.WORK/'library.json').read_text())[edition]
    return dict(rom=row['rom'],library=row['library'],bridge=str(backend.WORK/'bin/libascendant_3ds_bridge.dylib'),data=str(data),session_lock=str(data/'session.lock'),resolution=3,language=1,depth_3d=0,stereo='off',texture_packs=True,edition=edition,settings=dict(layout='overlay',overlay_position='right',hide_empty_touch=True,display_mode='fit',filter='smooth',stereo='off',show_fps=True))

def ab_child(edition,package):
    normal=library.WORK;library.WORK=CACHE/('mod-work-'+edition)
    data=library.WORK/'player';data.mkdir(parents=True,exist_ok=True)
    try:
        if not library.disabled_dir(edition).exists() and not any(library.mod_dir(edition).rglob('*.bps')):
            library.install_mod(edition,package);library.toggle_mods(edition)
        for label in ['off-before','on','off-after']:
            if label!='off-before':library.toggle_mods(edition)
            out=CACHE/(edition+'-'+label);out.mkdir(exist_ok=True)
            profile=out/'profile';profile.mkdir(exist_ok=True)
            if library.mod_dir(edition).exists():shutil.copytree(library.mod_dir(edition),profile/'mods'/library.EDITIONS[edition],dirs_exist_ok=True)
            game=Bridge(session(edition,profile))
            try:
                # Standard button presses only, replayed from a clean profile.
                for n in range(2501):
                    button=1 if n in [150,151,300,301,1200,1201,1800,1801,2100,2101]else 0
                    game.step(button)
                    if n in [2250,2400,2500]:game.capture(out/(str(n)+'.png'))
            finally:game.close()
            print(edition,label,'completed',flush=True)
    finally:library.WORK=normal

def play(q,edition,seconds,input_script=None,resume_state=None,bridge=None,profile=False):
    host=CACHE/'candidate';app=host/'Gameplay QA.app';probe=host/'probe'
    q.qa_copy(host,ephemeral=True);probe.mkdir(parents=True,exist_ok=True)
    # Reuse the identical owned host across A/B runs. copytree cannot merge
    # framework symlinks safely over a bundle already copied by this batch.
    if not app.exists():shutil.copytree(backend.WORK/'Gen2Recomp Ascendant.app',app,symlinks=True)
    p=app/'Contents/Info.plist';info=plistlib.loads(p.read_bytes());info.update(CFBundleIdentifier='de.roxas2712.kalos-gameplay-qa',CFBundleName='Kalos Gameplay QA',CFBundleDisplayName='Kalos Gameplay QA',NSAppSleepDisabled=True);p.write_bytes(plistlib.dumps(info))
    for name in ['src/import/PokemonXYNative.lua','src/import/PokemonXYABI.lua','src/import/PokemonXYLanguage.lua','src/import/PokemonXYKeyboard.lua','src/import/pokemon_xy_native_worker.lua','src/link/Json.lua']:
        dest=probe/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/name,dest)
    shutil.copy2(ROOT/'tools/pokemon_xy_gameplay_probe.lua',probe/'main.lua')
    identity='oasc-kalos-gameplay-qa';q.qa_source_identity(identity)
    (probe/'conf.lua').write_text("function love.conf(t)t.identity='"+identity+"';t.window.width=1200;t.window.height=800;t.window.title='Recompiled Ascendant · Gameplay QA';t.window.vsync=1;t.modules.physics=false end")
    data=CACHE/('gameplay-player-'+edition);q.qa_profile(data);q.qa_limit_output(data,2*1024**3)
    out=CACHE/('play-'+edition+'-'+str(int(time.time())));out.mkdir();sp=out/'session.json';request=session(edition,data)
    if bridge:request['bridge']=str(bridge.resolve())
    sp.write_text(json.dumps(request))
    env=dict(backend.backend_environment(),KALOS_QA_SESSION=str(sp),KALOS_QA_OUTPUT=str(out),OA_QA_IDENTITY=identity)
    resume=CACHE/('resume-'+edition+'.txt')
    if resume_state:env['KALOS_RESUME_STATE']=str(resume_state.resolve())
    elif resume.exists()and Path(resume.read_text()).is_file():env['KALOS_RESUME_STATE']=resume.read_text()
    (CACHE/'active-output.txt').write_text(str(out))
    if input_script:(out/'command.json').write_text(input_script.read_text())
    with (out/'runtime.log').open('w')as log:
        with q.qa_popen([str(app/'Contents/MacOS/love'),str(probe)],cwd=ROOT,env=env,stdout=log,stderr=log)as child:
            print('VISIBLE',child.pid,out,flush=True)
            sampler=None
            if profile:
                sampler=q.qa_popen(['/usr/bin/sample',str(child.pid),str(max(1,seconds-10)),'-file',str(out/'native-sample.txt')],stdout=log,stderr=log)
            try:code=child.wait(timeout=seconds)
            except subprocess.TimeoutExpired:
                pending=out/'command.pending';pending.write_text('[{"action":"capture","name":"slot-end"},{"action":"state","name":"slot-end"}]');pending.replace(out/'command.json')
                deadline=time.monotonic()+10
                while child.poll()is None and time.monotonic()<deadline and not ((out/'slot-end.state').exists()and(out/'slot-end.png').exists()):time.sleep(.1)
                pending.write_text('[{"action":"quit"}]');pending.replace(out/'command.json')
                code=child.wait(timeout=30)
            assert code==0,('Frontend failed',code)
            if sampler:
                if sampler.poll()is None:sampler.terminate()
                sampler.wait(timeout=15)
    if (out/'slot-end.state').is_file():resume.write_text(str(out/'slot-end.state'))
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['ab','ab-child','play','ab-play','transition-ab']);p.add_argument('--edition',choices=['x','y'],default='y');p.add_argument('--package',type=Path,default=backend.WORK/'testmods/ascendant-visible-y-v2');p.add_argument('--seconds',type=int,default=480);p.add_argument('--input-script',type=Path);p.add_argument('--rebuild-bridge',action='store_true');p.add_argument('--resume-state',type=Path);p.add_argument('--bridge',type=Path);p.add_argument('--profile',action='store_true');a=p.parse_args()
    if a.action=='ab-child':ab_child(a.edition,a.package);return
    status('waiting','Prepared X/Y visible mod A/B + production-frontend gameplay; waiting for coordinated turn')
    with (STATE/'hardware.lock').open('a')as lock:
        fcntl.flock(lock,fcntl.LOCK_EX);status('running','X/Y '+a.action+' bounded package; full cleanup before release')
        q=None
        try:
            q=preflight.qa_manager(collect=False)
            for source in [ROOT,backend.WORK,Path(library.manifest()[a.edition]['rom']),a.package]:q.qa_source(source)
            if a.input_script:q.qa_source(a.input_script)
            if a.resume_state:q.qa_source(a.resume_state)
            if a.bridge:q.qa_source(a.bridge)
            q.qa_cache(CACHE);CACHE.mkdir(parents=True,exist_ok=True)
            if a.rebuild_bridge:
                with (CACHE/'bridge-diagnostics-build.log').open('w')as log:r=q.qa_run([sys.executable,str(ROOT/'tools/build_pokemon_xy_bridge.py'),'--test'],cwd=ROOT,env=backend.backend_environment(),stdout=log,stderr=log,timeout=360)
                assert r.returncode==0,'Native diagnostic bridge build failed'
            if a.action in ('ab','ab-play'):
                # The child inherits these managed leases for all writable profiles.
                q.qa_profile(CACHE/('mod-work-'+a.edition)/'player')
                for label in ['off-before','on','off-after']:
                    profile=CACHE/(a.edition+'-'+label)/'profile'
                    q.qa_profile(profile);q.qa_limit_output(profile,2*1024**3)
                with (CACHE/(a.edition+'-ab.log')).open('w')as log:r=q.qa_run([sys.executable,__file__,'ab-child','--edition',a.edition,'--package',str(a.package)],cwd=ROOT,env=backend.backend_environment(),stdout=log,stderr=log,timeout=180)
                print('A/B exit',r.returncode,flush=True);assert r.returncode==0
            if a.action in ('play','ab-play'):play(q,a.edition,a.seconds,a.input_script,a.resume_state,a.bridge,a.profile)
            if a.action=='transition-ab':
                if not(a.bridge and a.resume_state and a.input_script):raise ValueError('Transition A/B requires baseline bridge, own state and identical inputs')
                candidate=backend.WORK/'bin/libascendant_3ds_bridge.dylib'
                runs=[]
                for label,bridge in [('baseline-1',a.bridge),('candidate-1',candidate),('candidate-2',candidate),('baseline-2',a.bridge)]:
                    output=play(q,a.edition,a.seconds,a.input_script,a.resume_state,bridge)
                    runs.append(dict(label=label,output=str(output),bridge_sha256=__import__('hashlib').sha256(bridge.read_bytes()).hexdigest()))
                    (CACHE/'transition-ab-runs.json').write_text(json.dumps(runs,indent=2)+'\n')
        finally:
            if q:q._storage.close(collect=False)
            status('yielded','X/Y batch and cleanup ended; hardware free')
if __name__=='__main__':main()
