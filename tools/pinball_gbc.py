#!/usr/bin/env python3
"""Privately recompile the original USA/Australia GBC Pinball. By Roxas2712."""
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
REVISION='743f52e73ec5cc90478b3591632406ac7764b45c'
SHA1='9402014d14969432142abfde728c6f1a10ee4dac'

def verify(path):
    path=path.expanduser().resolve(strict=True)
    if path.stat().st_size!=1048576 or hashlib.sha1(path.read_bytes()).hexdigest()!=SHA1:
        raise ValueError('Use the unmodified USA/Australia GBC Pinball cartridge (SHA-1 '+SHA1+').')
    return path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['prepare','status'])
    parser.add_argument('--rom',type=Path)
    parser.add_argument('--runtime',type=Path,help='Existing checkout at the pinned runtime revision')
    parser.add_argument('--cmake',default='cmake')
    parser.add_argument('--ninja',default='ninja')
    args=parser.parse_args()
    work=ROOT/'.local/pinball-gbc';manifest=work/'library.json'
    if args.action=='status':
        data=json.loads(manifest.read_text())if manifest.exists()else {'ready':False}
        data['ready']=bool(data.get('ready')and Path(data.get('bridge','')).is_file()and Path(data.get('rom','')).is_file())
        print(json.dumps(data));return
    if not args.rom:parser.error('prepare requires --rom')
    rom=verify(args.rom)
    if sys.platform=='win32':raise RuntimeError('The current build driver requires POSIX file locking; Windows packaging is not qualified.')
    import fcntl
    work.mkdir(parents=True,exist_ok=True)
    lock=(work/'prepare.lock').open('a+')
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    helper=Path.home()/'.local/lib/origami-qa-storage/active-tools'
    sys.path.insert(0,str(helper if(helper/'qa_storage.py').is_file()else ROOT/'tools'))
    import qa_storage as q
    q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
    runtime=args.runtime.expanduser().resolve()if args.runtime else work/'gbrecompiled'
    for source in [ROOT,work,rom,runtime,Path(sys.executable)]:q.qa_source(source)
    # Keep compiler inputs locked when an existing toolchain is itself a QA cache.
    for command in (args.cmake,args.ninja):
        resolved=shutil.which(command)or command
        if Path(resolved).exists():q.qa_source(Path(resolved).resolve().parent)
    out=ROOT/'.local/qa/pinball-gbc';q.qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    generated=work/'generated';q.qa_source(generated)
    player=work/'player';q.qa_source(player);player.mkdir(exist_ok=True)
    def run(name,command):
        print(name,flush=True,file=sys.stderr)
        with(out/(name+'.log')).open('w')as log:
            result=q.qa_run([str(x)for x in command],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        if result.returncode:raise RuntimeError(name+' failed; see '+str(out/(name+'.log')))
    if not runtime.exists():
        run('clone',['git','clone','--filter=blob:none','https://github.com/mstan/gbrecompiled.git',runtime])
        run('pin',['git','-C',runtime,'checkout',REVISION])
        run('submodules',['git','-C',runtime,'submodule','update','--init','--recursive'])
    revision=subprocess.check_output(['git','-C',str(runtime),'rev-parse','HEAD'],text=True).strip()
    if revision!=REVISION:raise RuntimeError('Runtime revision differs from the reviewed pin; existing sources preserved.')
    # Reproducibility also requires pristine runtime source bytes.
    if subprocess.check_output(['git','-C',str(runtime),'status','--porcelain','--untracked-files=no'],text=True).strip():
        raise RuntimeError('Runtime has local changes; use a clean pinned checkout.')
    compiler=out/'compiler';native=out/'native'
    common=['-G','Ninja','-DCMAKE_MAKE_PROGRAM='+str(shutil.which(args.ninja)or args.ninja),'-DCMAKE_BUILD_TYPE=Release']
    run('configure-compiler',[args.cmake,'-S',runtime,'-B',compiler,*common,'-DCMAKE_DISABLE_FIND_PACKAGE_SDL2=TRUE'])
    run('compiler',[args.cmake,'--build',compiler,'--target','gbrecomp','--parallel','2'])
    # Keep ROM-derived C private. Only the host and build recipe are versioned.
    old={p:(p.stat().st_atime_ns,p.stat().st_mtime_ns,hashlib.sha256(p.read_bytes()).digest()) for p in generated.glob('*')if p.suffix in {'.c','.h'} and p.is_file()}
    run('generate',[compiler/'bin/gbrecomp',rom,'-o',generated,'--jobs','2'])
    for path,(atime,mtime,digest)in old.items():
        if path.is_file()and hashlib.sha256(path.read_bytes()).digest()==digest:os.utime(path,ns=(atime,mtime))
    run('configure-native',[args.cmake,'-S',ROOT/'tools/pinball-gbc-native','-B',native,*common,
        '-DGBRECOMP_ROOT='+str(runtime),'-DPINBALL_GENERATED='+str(generated)])
    run('native',[args.cmake,'--build',native,'--target','ascendant_pinball_gbc','--parallel','2'])
    name='libascendant_pinball_gbc.dylib'if sys.platform=='darwin'else 'libascendant_pinball_gbc.so'
    installed=work/name;pending=installed.with_suffix(installed.suffix+'.pending')
    shutil.copy2(native/name,pending);pending.replace(installed)
    data={'schema':1,'ready':True,'rom':str(rom),'rom_sha1':SHA1,'bridge':str(installed),'player':str(player),
        'runtime_revision':REVISION,'boot':'HLE','guest':'gbc','edition':'pinballgbc','locale':'en','sram_size':8192,
        'backend':'gbrecompiled-'+REVISION+'-'+hashlib.sha256(b''.join(p.read_bytes()for p in sorted((ROOT/'tools/pinball-gbc-native').iterdir())if p.is_file())).hexdigest()[:16],
        'content':'USA-'+SHA1,'native_with_interpreter_fallback':True,
        'backend_sha256':hashlib.sha256(b''.join(p.read_bytes()for p in sorted((ROOT/'tools/pinball-gbc-native').iterdir())if p.is_file())).hexdigest()}
    pending=manifest.with_suffix('.pending');pending.write_text(json.dumps(data,indent=2)+'\n');pending.replace(manifest)
    print(json.dumps(data))

if __name__=='__main__':main()
