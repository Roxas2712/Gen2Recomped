#!/usr/bin/env python3
"""Private USA cartridge build; integration by Roxas2712.

No cartridge, extracted assets, generated guest code or saves are distributed.
The separately licensed runtime and replacement BIOS keep their own notices.
"""
from __future__ import annotations
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
RUNTIME='e353848ca8e82e7860469a235784a000102e7781'
USA='9fec81ce2c5df589e0371a0bf2f92a5fe8db730b'
EU='b8b7881eaa9856b5ada99078ad1053d31cb79827'
BIOS_SHA256='95e6c8a6c236ed8e2629bdb60bc75791434c4f08ca69ad2305e30ca3f3c29d1b'
BIOS_URL='https://github.com/coolbho3k/emibios/releases/download/0.2.1/gba_bios.bin'

def digest(path,algorithm='sha1'):
    h=hashlib.new(algorithm)
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()

def verify(path,expected,size):
    path=path.expanduser().resolve(strict=True)
    if path.stat().st_size!=size or digest(path)!=expected:
        raise ValueError('Unsupported cartridge revision; use the matching unmodified dump.')
    return path

def atomic_json(path,data):
    pending=path.with_suffix('.pending')
    pending.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    pending.replace(path)

def install_library(source,destination):
    # Keep an already mapped library intact for a running guest. New launches
    # see the completed replacement inode, never a partially overwritten file.
    pending=destination.with_suffix(destination.suffix+'.pending')
    shutil.copy2(source,pending)
    pending.replace(destination)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['import','prepare','status'])
    p.add_argument('--rom',type=Path)
    p.add_argument('--eu-rom',type=Path)
    p.add_argument('--bios',type=Path,help='Optional verified 16-KiB replacement or personal BIOS')
    p.add_argument('--cmake',default='cmake')
    p.add_argument('--ninja',default='ninja')
    p.add_argument('--worker-protocol',action='store_true')
    args=p.parse_args()
    work=ROOT/'.local/pinball-rs'
    config=work/'library.json'
    if args.action=='status':
        data=json.loads(config.read_text()) if config.exists() else {'ready':False}
        data['ready']=bool(data.get('bridge') and Path(data['bridge']).is_file() and Path(data.get('rom','')).is_file())
        print(json.dumps(data,ensure_ascii=False));return
    if not args.rom:p.error('prepare requires --rom')
    if args.action=='import':
        selected=args.rom.expanduser().resolve(strict=True)
        sha=digest(selected)
        if (sha,selected.stat().st_size) not in ((USA,8*1024*1024),(EU,16*1024*1024)):
            raise ValueError('Unsupported cartridge revision; use the matching unmodified dump.')
        previous=json.loads(config.read_text()) if config.exists() else {}
        imports=work/'imports.json'
        pending=json.loads(imports.read_text()) if imports.exists() else {}
        pending.update({('usa' if sha==USA else 'eu'):str(selected)})
        work.mkdir(parents=True,exist_ok=True);atomic_json(imports,pending)
        usa=pending.get('usa') or previous.get('rom')
        europe=pending.get('eu') or previous.get('eu_rom')
        if not usa:
            print(json.dumps({'imported':True,'ready':False,'notice':'European cartridge imported. Add the USA cartridge to prepare the native base.'}));return
        args.rom=Path(usa);args.eu_rom=Path(europe) if europe else None
        verify(args.rom,USA,8*1024*1024)
        if args.eu_rom:verify(args.eu_rom,EU,16*1024*1024)
        code_hash=hashlib.sha256(b''.join(path.read_bytes()for path in sorted((ROOT/'tools/pinball-rs-native').glob('*'))if path.suffix in {'.cpp','.h'})).hexdigest()[:16]
        if (previous.get('ready') and '-bridge-'+code_hash+'-bios-' in previous.get('backend','')
                and Path(previous.get('bridge','')).is_file()
                and (not args.eu_rom or Path(previous.get('variants',{}).get('eu',{}).get('bridge','')).is_file())):
            previous['rom']=str(args.rom);previous['eu_rom']=str(args.eu_rom) if args.eu_rom else None
            if args.eu_rom:previous['variants']['eu']['rom']=str(args.eu_rom)
            atomic_json(config,previous);print(json.dumps(previous));return
        args.action='prepare'
    rom=verify(args.rom,USA,8*1024*1024)
    eu=verify(args.eu_rom,EU,16*1024*1024) if args.eu_rom else None
    # Serialize this installation only. Unrelated CPU checks and other games
    # need not wait for a global hardware slot.
    import fcntl
    work.mkdir(parents=True,exist_ok=True)
    lock=(work/'prepare.lock').open('a+')
    try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:raise RuntimeError('This Pinball installation is already being prepared.')
    helper=Path.home()/'.local/lib/origami-qa-storage/active-tools'
    sys.path.insert(0,str(helper if (helper/'qa_storage.py').is_file() else ROOT/'tools'))
    import qa_storage as q
    q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
    for source in [ROOT,work,rom,eu,args.bios,Path(sys.executable)]:
        if source:q.qa_source(source)
    out=ROOT/'.local/qa/pinball-rs'
    q.qa_cache(out);out.mkdir(parents=True,exist_ok=True);work.mkdir(parents=True,exist_ok=True)
    player=work/'player';q.qa_source(player);q.qa_profile(player);player.mkdir(parents=True,exist_ok=True)
    def run(name,command):
        print(name,file=sys.stderr,flush=True)
        with (out/(name+'.log')).open('w') as f:
            result=q.qa_run([str(x) for x in command],cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError(name+' failed; see the private build log.')
    source=work/'gbarecomp'
    if not source.exists():
        run('runtime-clone',['git','clone','--recursive','https://github.com/mstan/gbarecomp.git',source])
        run('runtime-pin',['git','-C',source,'checkout',RUNTIME])
        run('runtime-submodules',['git','-C',source,'submodule','update','--init','--recursive'])
    revision=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
    if revision!=RUNTIME:raise RuntimeError('Runtime revision differs from the reviewed pin; keep existing sources intact.')
    bios=args.bios.expanduser().resolve() if args.bios else work/'emibios/gba_bios.bin'
    if not bios.exists():
        # Download only the free replacement BIOS, never a Nintendo BIOS.
        run('free-bios',[sys.executable,'-c',
          'import hashlib,urllib.request;from pathlib import Path;'
          'b=urllib.request.urlopen('+repr(BIOS_URL)+',timeout=30).read();'
          'assert len(b)==16384 and hashlib.sha256(b).hexdigest()=='+repr(BIOS_SHA256)+';'
          'p=Path('+repr(str(bios))+');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)'])
    if bios.stat().st_size!=16384:raise ValueError('BIOS must be exactly 16384 bytes.')
    if not args.bios and digest(bios,'sha256')!=BIOS_SHA256:raise ValueError('Replacement BIOS hash mismatch.')
    q.qa_source(bios)
    generator=out/'framework';generated=out/'generated';native=out/'native'
    cmake=shutil.which(args.cmake) or args.cmake
    ninja=shutil.which(args.ninja) or args.ninja
    run('configure',[cmake,'-S',source,'-B',generator,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
      '-DGBARECOMP_SELFHEAL_RECOMPILE_DEFAULT=OFF','-DCMAKE_MAKE_PROGRAM='+str(ninja)])
    run('generator',[cmake,'--build',generator,'--target','gba_recompile','--parallel','2'])
    run('generate-usa',[generator/'gba_recompile','--rom',rom,'--entry','0x080000C0','--out',generated/'usa','--max-functions','8192','--codegen-shards','16'])
    run('generate-bios',[generator/'gba_recompile','--bios',bios,'--out',generated/'bios'])
    run('configure-native',[cmake,'-S',ROOT/'tools/pinball-rs-native','-B',native,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
      '-DGBARECOMP_ROOT='+str(source),'-DPINBALL_GENERATED='+str(generated/'usa'),
      '-DPINBALL_BIOS_GENERATED='+str(generated/'bios'),'-DCMAKE_MAKE_PROGRAM='+str(ninja)])
    run('native',[cmake,'--build',native,'--target','ascendant_pinball_rs','--parallel','2'])
    name='libascendant_pinball_rs.dylib' if sys.platform=='darwin' else 'libascendant_pinball_rs.so'
    installed=work/'native'/name;installed.parent.mkdir(parents=True,exist_ok=True)
    # Keep the finished runtime outside disposable build caches.
    install_library(native/name,installed)
    variants={}
    if eu:
        run('generate-eu',[generator/'gba_recompile','--rom',eu,'--entry','0x080000C0','--out',generated/'eu','--max-functions','8192','--codegen-shards','16'])
        native_eu=out/'native-eu'
        run('configure-eu',[cmake,'-S',ROOT/'tools/pinball-rs-native','-B',native_eu,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
          '-DGBARECOMP_ROOT='+str(source),'-DPINBALL_GENERATED='+str(generated/'eu'),'-DPINBALL_EU_VARIANT=ON',
          '-DPINBALL_BIOS_GENERATED='+str(generated/'bios'),'-DCMAKE_MAKE_PROGRAM='+str(ninja)])
        run('native-eu',[cmake,'--build',native_eu,'--target','ascendant_pinball_rs','--parallel','2'])
        eu_name=name.replace('pinball_rs.','pinball_rs_eu.')
        eu_installed=installed.parent/eu_name;install_library(native_eu/eu_name,eu_installed)
        variants['eu']={'rom':str(eu),'rom_sha1':EU,'bridge':str(eu_installed),
          'content':'EU-'+EU,'game_pointer_address':0x02031600}
    data={'schema':1,'ready':True,'rom':str(rom),'rom_sha1':USA,'bios':str(bios),
      'bios_sha256':digest(bios,'sha256'),'bridge':str(installed),'runtime_revision':RUNTIME,
      'player':str(player),'eu_rom':str(eu) if eu else None,
      'backend':'gbarecomp-'+RUNTIME+'-bridge-'+hashlib.sha256(b''.join(p.read_bytes()for p in sorted((ROOT/'tools/pinball-rs-native').glob('*'))if p.suffix in {'.cpp','.h'})).hexdigest()[:16]+'-bios-'+digest(bios,'sha256')[:16],'content':'USA-'+USA,
      'native_with_interpreter_fallback':True,'variants':variants}
    atomic_json(config,data)
    print(json.dumps(data,ensure_ascii=False))

if __name__=='__main__':
    result=0
    try:main()
    except (ValueError,RuntimeError,OSError,subprocess.SubprocessError) as ex:
        print(str(ex),file=sys.stderr);result=1
    if '--worker-protocol' in sys.argv:print(json.dumps({'backend_result':result}),flush=True)
    sys.exit(result)
