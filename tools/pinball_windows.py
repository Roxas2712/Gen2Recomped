"""Compile only the player's Pinball guest code against the bundled native SDK.

The SDK has no cartridge-derived code. ROMs and player files are never copied
into build caches or distributed. Copyright (c) 2026 Roxas2712.
"""
import concurrent.futures,hashlib,json,os,shutil,sys
from pathlib import Path
from native_workspace import manager,lock_file

def read(path):return json.loads(path.read_text(encoding='utf-8'))if path.is_file()else{}
def sha(path):
    with path.open('rb')as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def main(root,args,core):
    work=root/'.local/pinball-rs';work.mkdir(parents=True,exist_ok=True)
    sdk=args.runtime_root.resolve(strict=True);runtime=read(sdk/'pinball-runtime.json')
    if runtime.get('schema')!=1 or runtime.get('platform')!='windows-x64':raise ValueError('The Windows native Pinball SDK is missing or incompatible.')
    required=[runtime['compiler'],runtime['generator'],runtime['bios'],*runtime['libraries']]
    for rel in required:
        path=(sdk/rel).resolve()
        if not path.is_relative_to(sdk)or not path.is_file():raise ValueError('The native Pinball SDK is incomplete: '+rel)
        if runtime.get('artifacts',{}).get(rel)!=sha(path):raise ValueError('The native Pinball SDK file is damaged: '+rel)
    if sha(sdk/runtime['bios'])!=runtime['bios_sha256']:raise ValueError('The bundled replacement BIOS is damaged.')
    selected=args.rom.resolve(strict=True);rom_hash=core.digest(selected)
    if (rom_hash,selected.stat().st_size)not in{(core.USA,8*1024**2),(core.EU,16*1024**2)}:raise ValueError('Use a matching unmodified Pinball cartridge dump.')
    qa=manager(root);qa.qa_source(selected);qa.qa_source(sdk)
    qa._storage.limit_output(work/'native-builds',4*1024**3)
    config=work/'library.json';imports=work/'imports.json'
    with (work/'prepare.lock').open('a')as lock:
        try:lock_file(lock)
        except BlockingIOError:raise RuntimeError('This Pinball import is already being prepared.')
        old=read(config);known=read(imports);kind='usa'if rom_hash==core.USA else'eu'
        known[kind]=str(selected)
        if args.eu_rom:known['eu']=str(core.verify(args.eu_rom,core.EU,16*1024**2))
        if old.get('rom')and old.get('rom_sha1')==core.USA:known.setdefault('usa',old['rom'])
        if old.get('eu_rom'):known.setdefault('eu',old['eu_rom'])
        core.atomic_json(imports,known)
        if 'usa'not in known or not Path(known['usa']).is_file():
            print(json.dumps({'imported':True,'ready':False,'notice':'European cartridge imported. Add the USA cartridge to prepare the native base.'}));return
        variants={}
        for region in ['usa','eu']:
            if region not in known:continue
            if not Path(known[region]).is_file()and region!=kind:continue
            expected,size=(core.USA,8*1024**2)if region=='usa'else(core.EU,16*1024**2)
            rom=core.verify(Path(known[region]),expected,size)
            identity=hashlib.sha256((expected+core.bridge_fingerprint()+sha(sdk/'pinball-runtime.json')).encode()).hexdigest()
            build=work/'native-builds'/identity;build.mkdir(parents=True,exist_ok=True)
            qa._storage.limit_output(build,2*1024**3)
            final=build/('ascendant_pinball_rs'+('_eu'if region=='eu'else'')+'.dll')
            marker=read(final.with_suffix('.complete.json'))
            if not(final.is_file()and marker.get('sha256')==sha(final)):
                compile_guest(root,sdk,runtime,rom,region,build,final,qa)
                core.atomic_json(final.with_suffix('.complete.json'),{'schema':1,'rom':expected,'sha256':sha(final),'runtime':identity})
            variants[region]={'rom':str(rom),'rom_sha1':expected,'bridge':str(final),
                'content':('EU-'if region=='eu'else'USA-')+expected}
            if region=='eu':variants[region]['game_pointer_address']=0x02031600
        primary=variants['usa'];player=Path(old.get('player',str(work/'player')))
        if not player.is_dir():player=work/'player'
        player.mkdir(exist_ok=True)
        # Keep the existing player directory, raw SRAM, slots and exact states.
        data=dict(old);data.update(primary)
        data.update(schema=1,ready=True,bios=str(sdk/runtime['bios']),bios_sha256=runtime['bios_sha256'],
            runtime_revision=core.RUNTIME,player=str(player),eu_rom=known.get('eu'),variants={'eu':variants['eu']}if'eu'in variants else{},
            backend='gbarecomp-'+core.RUNTIME+'-bridge-'+core.bridge_fingerprint()+'-bios-'+runtime['bios_sha256'][:16],
            native_with_interpreter_fallback=True)
        core.atomic_json(config,data);print(json.dumps(data,ensure_ascii=False))

def compile_guest(root,sdk,runtime,rom,region,build,final,qa):
    env=dict(os.environ,PATH=str(sdk/'compiler/bin')+os.pathsep+os.environ.get('PATH',''))
    generated=build/'generated'
    qa.qa_run([str(sdk/runtime['generator']),'--rom',str(rom),'--entry','0x080000C0','--out',str(generated),
        '--max-functions','8192','--codegen-shards','16'],env=env,check=True)
    source=root/'tools/pinball-rs-native'
    sources=[*sorted(generated.glob('recompiled_*.cpp')),generated/'dispatch_table.cpp',source/'bridge.cpp',source/'presentation.cpp']
    if len(sources)<4:raise ValueError('The native game generator produced no guest code.')
    compiler=str(sdk/runtime['compiler']);flags=['-std=c++20','-O2','-g0','-w','-DGBARECOMP_HAVE_BIOS_RECOMP=1']
    if region=='eu':flags.append('-DPINBALL_EU_VARIANT=1')
    for path in [generated,source,*[sdk/p for p in runtime['includes']]]:flags+=['-I',str(path)]
    def compile_one(pair):
        index,file=pair;obj=build/('native-'+str(index)+'.o');log=build/('compile-'+str(index)+'.log')
        with log.open('w',encoding='utf-8')as stream:
            qa.qa_run([compiler,*flags,'-c',str(file),'-o',str(obj)],env=env,stdout=stream,stderr=stream,check=True)
        print(json.dumps({'progress':'Compiling Pinball native code','completed':index+1,'total':len(sources)}),flush=True)
        return obj
    with concurrent.futures.ThreadPoolExecutor(max_workers=2)as pool:objects=list(pool.map(compile_one,enumerate(sources)))
    pending=final.with_suffix('.pending.dll')
    command=[compiler,'-shared','-static','-Wl,--export-all-symbols','-o',str(pending),*[str(p)for p in objects],
        '-Wl,--start-group',*[str(sdk/p)for p in runtime['libraries']],'-Wl,--end-group',
        '-lws2_32','-lcomdlg32','-lole32','-luuid','-ladvapi32','-lshell32','-lwinmm']
    with (build/'link.log').open('w',encoding='utf-8')as stream:qa.qa_run(command,env=env,stdout=stream,stderr=stream,check=True)
    # The previous working library remains intact after an interrupted linker.
    with pending.open('rb')as stream:
        if stream.read(2)!=b'MZ':raise ValueError('The native linker produced no Windows DLL.')
    pending.replace(final)
    for obj in objects:
        try:obj.unlink()
        except PermissionError:pass
