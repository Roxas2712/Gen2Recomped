#!/usr/bin/env python3
"""Build the ROM-free Windows x64 3DS/Pinball native import SDK.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse,hashlib,io,json,os,re,shutil,sys,tarfile,urllib.request,zipfile
from pathlib import Path,PurePosixPath
from native_workspace import manager
from native_sources import digest,xy_sources
import pinball_rs

ROOT=Path(__file__).resolve().parents[1]
def download(url,path,expected=None):
    if path.exists() and (expected is None or digest(path)==expected):return
    path.parent.mkdir(parents=True,exist_ok=True)
    pending=path.with_suffix('.pending')
    with urllib.request.urlopen(url,timeout=120)as source,pending.open('wb')as dest:shutil.copyfileobj(source,dest)
    if expected and digest(pending)!=expected:raise ValueError('Component hash mismatch: '+path.name)
    pending.replace(path)
def extract(file,destination):
    destination.mkdir(parents=True)
    if zipfile.is_zipfile(file):
        with zipfile.ZipFile(file)as z:
            for name in z.namelist():
                p=PurePosixPath(name)
                if p.is_absolute()or'..'in p.parts or'\\'in name or':'in name:raise ValueError('Unsafe component path')
            z.extractall(destination)
    else:
        with tarfile.open(file)as t:t.extractall(destination,filter='data')
def clone(qa,url,path,revision,exclude=()):
    if not path.exists():qa.qa_run(['git','-c','core.eol=lf','-c','core.autocrlf=false','clone','--filter=blob:none','--no-checkout',url,str(path)],check=True)
    if exclude:
        qa.qa_run(['git','sparse-checkout','set','--no-cone','/*',*['!/'+item.strip('/')+'/' for item in exclude]],cwd=path,check=True)
    qa.qa_run(['git','checkout','--detach',revision],cwd=path,check=True)
    actual=qa.qa_run(['git','rev-parse','HEAD'],cwd=path,capture_output=True,text=True,check=True).stdout.strip()
    if actual!=revision:raise ValueError('Source pin mismatch')
def notices(source,target,prefix):
    for file in source.glob('LICENSE*'):
        destination=target/(prefix+'-'+file.name)
        if file.is_dir():shutil.copytree(file,destination)
        elif file.is_file():shutil.copy2(file,destination)
def retire_rust_objects(target,sdk):
    """Only compiled intermediates after copied final binaries and tests agree.

    The corresponding Rust/C/C++ sources, dependency registry, final DLL/EXE
    and all profiles/ROMs remain intact, matching the normal QA Cargo policy.
    """
    for source,installed in [(target/'release/3dsrecomp.exe',sdk/'bin/3dsrecomp.exe'),
                              (target/'release/ascendant_3ds_bridge.dll',sdk/'lib/ascendant_3ds_bridge.dll')]:
        if digest(source)!=digest(installed):raise ValueError('Retain Rust objects until final binaries match')
    removed=0
    for folder in [target/'release/deps',target/'release/build']:
        for path in folder.rglob('*'):
            if path.suffix.lower()not in {'.o','.obj','.rlib','.rmeta','.a','.lib','.pdb','.exp'}or path.is_symlink()or not path.is_file():continue
            if any(p.lower()in{'src','sources','models','saves','profiles'}for p in path.relative_to(target).parts):continue
            size=path.stat().st_size;path.unlink();removed+=size
    print(json.dumps({'retiredQualifiedRustIntermediateBytes':removed}),flush=True)
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--graphics',action='store_true');a=parser.parse_args()
    if os.name!='nt':parser.error('Build and qualify this SDK on Windows x64.')
    out=a.out.resolve()
    if out.exists():raise ValueError('Use a fresh output folder; existing SDKs are preserved')
    qa=manager(ROOT);qa.qa_source(ROOT);qa.qa_copy(out)
    work=ROOT/'.local/qa/windows-native-sdk-build';work.mkdir(parents=True,exist_ok=True);qa.qa_cache(work)
    components=json.loads((ROOT/'tools/windows_native_components.json').read_text())
    out.mkdir(parents=True)
    for name in ['compiler','python']:
        row=components[name];archive=work/(name+'.archive');download(row['url'],archive,row['sha256'])
        # Extract once into the owned candidate. Moving its top-level folder
        # avoids a second gigabyte of compiler bytes in the build workspace.
        unpack=out/('.unpack-'+name);extract(archive,unpack)
        source=next(unpack.iterdir())if name=='compiler'else unpack/'python'
        source.rename(out/name)
        try:unpack.rmdir()
        except OSError:pass
    for folder in ['bin','lib','licenses','gbarecomp-libs','vulkan']:(out/folder).mkdir()
    xy=ROOT/'.local/pokemon-x';pins=xy_sources(ROOT,xy,qa)
    env=dict(os.environ,RUSTUP_TOOLCHAIN=components['rust'],CARGO_TARGET_DIR=str(work/'cargo-target'),CARGO_BUILD_JOBS='2',CARGO_INCREMENTAL='0',CARGO_PROFILE_RELEASE_DEBUG='0')
    env['RUSTFLAGS']='--remap-path-prefix='+str(ROOT)+'=/build/RetroRecomped'
    qa.qa_run(['rustup','toolchain','install',components['rust'],'--profile','minimal'],check=True)
    for manifest in [xy/'3dsrecomp/Cargo.toml',ROOT/'tools/pokemon-xy-bridge/Cargo.toml']:
        qa.qa_run(['cargo','build','--release','--locked','--manifest-path',str(manifest)],env=env,check=True)
        qa.qa_run(['cargo','test','--release','--locked','--manifest-path',str(manifest),'--lib'],env=env,check=True)
    shutil.copy2(work/'cargo-target/release/3dsrecomp.exe',out/'bin/3dsrecomp.exe')
    shutil.copy2(work/'cargo-target/release/ascendant_3ds_bridge.dll',out/'lib/ascendant_3ds_bridge.dll')
    retire_rust_objects(work/'cargo-target',out)
    gba=work/'gbarecomp';clone(qa,'https://github.com/mstan/gbarecomp.git',gba,pinball_rs.RUNTIME)
    qa.qa_run(['git','submodule','update','--init','--recursive','external/arm-recomp-core','external/recomp-net','external/rbengine'],cwd=gba,check=True)
    pinball_rs.apply_runtime_fixes(gba,qa)
    windows_patch=ROOT/'tools/pinball-rs-native/windows-io.patch'
    qa.qa_run(['git','apply','--check',str(windows_patch)],cwd=gba,check=True)
    qa.qa_run(['git','apply',str(windows_patch)],cwd=gba,check=True)
    cc=out/'compiler/bin/clang.exe';cxx=out/'compiler/bin/clang++.exe'
    native=work/'gba-build'
    base=['cmake','-S',str(gba),'-B',str(native),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
          '-DCMAKE_C_COMPILER='+str(cc),'-DCMAKE_CXX_COMPILER='+str(cxx),'-DCMAKE_EXPORT_COMPILE_COMMANDS=ON',
          '-DCMAKE_EXE_LINKER_FLAGS=-static',
          '-DGBARECOMP_SELFHEAL_RECOMPILE_DEFAULT=OFF','-DGBARECOMP_COMPILER_CACHE=OFF']
    qa.qa_run(base,check=True)
    qa.qa_run(['cmake','--build',str(native),'--target','gba_recompile','--parallel','2'],check=True)
    generator=native/'gba_recompile.exe'
    manifest=work/'native-utf8.manifest'
    manifest.write_text('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><application xmlns="urn:schemas-microsoft-com:asm.v3"><windowsSettings><activeCodePage xmlns="http://schemas.microsoft.com/SMI/2019/WindowsSettings">UTF-8</activeCodePage></windowsSettings></application></assembly>')
    qa.qa_run(['mt.exe','-manifest',str(manifest),'-outputresource:'+str(generator)+';#1'],check=True)
    bios=out/'bios/gba_bios.bin';download(pinball_rs.BIOS_URL,bios,pinball_rs.BIOS_SHA256)
    free=work/'bios-generated'
    qa.qa_run([str(generator),'--bios',str(bios),'--out',str(free)],check=True)
    qa.qa_run(base+['-DGBARECOMP_GENERATED_BIOS_DIR='+str(free)],check=True)
    targets=['gbarecomp_runtime','gbarecomp_debug','gbarecomp_gba','gbarecomp_armv4t','gbarecomp_recompile_core','gbarecomp_heal_gate']
    qa.qa_run(['cmake','--build',str(native),'--target',*targets,'--parallel','2'],check=True)
    shutil.copy2(generator,out/'bin/gba_recompile.exe')
    libraries=[]
    for target in targets:
        matches=list(native.rglob('lib'+target+'.a'))
        if len(matches)!=1:raise ValueError('Missing generic GBA library: '+target)
        name=matches[0].name;shutil.copy2(matches[0],out/'gbarecomp-libs'/name);libraries.append('gbarecomp-libs/'+name)
    # Headers and original sources are game-data-free. Keep their licences and
    # build scripts so recipients can rebuild/relink the generic native core.
    def ignored(folder,names):
        return [n for n in names if n in {'.git','.local','target','baseroms','node_modules'}or Path(n).suffix.lower()in{'.gba','.gb','.gbc','.nds','.3ds','.cia','.sav','.state','.png','.jpg','.wav','.ogg','.mp3','.mid','.midi'}]
    shutil.copytree(gba,out/'gbarecomp',ignore=ignored)
    shutil.copytree(free,out/'free-bios-generated')
    download('https://github.com/coolbho3k/emibios/archive/refs/tags/0.2.1.tar.gz',out/'licenses/emibios-0.2.1-source.tar.gz')
    includes=set()
    for command in json.loads((native/'compile_commands.json').read_text()):
        for first,second in re.findall(r'(?:^| )-I(?:"([^"]+)"|([^ ]+))',command['command']):
            path=Path(first or second)
            try:relative=path.relative_to(gba)
            except ValueError:continue
            includes.add('gbarecomp/'+relative.as_posix())
    gba_artifacts={p:digest(out/p)for p in ['bin/gba_recompile.exe','compiler/bin/clang++.exe','bios/gba_bios.bin',*libraries]}
    (out/'pinball-runtime.json').write_text(json.dumps({'schema':1,'platform':'windows-x64','runtime_revision':pinball_rs.RUNTIME,
        'compiler':'compiler/bin/clang++.exe','generator':'bin/gba_recompile.exe','bios':'bios/gba_bios.bin',
        'libraries':libraries,'includes':sorted(includes),'artifacts':gba_artifacts,
        'windows_io_patch_sha256':digest(windows_patch),'bios_sha256':pinball_rs.BIOS_SHA256},indent=2)+'\n')
    if a.graphics:build_graphics(qa,work,out,components)
    packages=qa.qa_run(['cargo','metadata','--locked','--format-version','1','--manifest-path',str(ROOT/'tools/pokemon-xy-bridge/Cargo.toml')],env=env,capture_output=True,text=True,check=True)
    records=[]
    for package in json.loads(packages.stdout)['packages']:
        folder=Path(package['manifest_path']).parent;dest=out/'licenses/rust'/(package['name']+'-'+package['version']);dest.mkdir(parents=True,exist_ok=True)
        records.append({k:package.get(k)for k in ['name','version','license','source']})
        for pattern in ['LICENSE*','COPYING*','NOTICE*','COPYRIGHT*']:
            for file in folder.glob(pattern):
                if file.is_file()and file.stat().st_size<1024**2:shutil.copy2(file,dest/file.name)
    (out/'licenses/rust-components.json').write_text(json.dumps(records,indent=2)+'\n')
    for name in ['zakuro','3dsrecomp']:
        notices(xy/name,out/'licenses',name)
    shutil.copy2(ROOT/'LICENSE-ROXAS2712.md',out/'licenses/LICENSE-ROXAS2712.md')
    artifacts={name:digest(out/path)for name,path in {'compiler':'bin/3dsrecomp.exe','cc':'compiler/bin/clang.exe',
        'bridge':'lib/ascendant_3ds_bridge.dll','python':'python/python.exe'}.items()}
    identity=hashlib.sha256(json.dumps({'artifacts':artifacts,'sources':pins,'components':components},sort_keys=True).encode()).hexdigest()
    (out/'runtime.json').write_text(json.dumps({'schema':1,'bridge_protocol':1,'platform':'windows-x64','id':identity,
        'compilation_id':identity,'artifacts':artifacts,'sources':pins,'components':components,'game_data_included':False},indent=2)+'\n')
    provenance={p:qa.qa_run(['git','rev-parse','HEAD:'+p],cwd=ROOT,check=True,capture_output=True,text=True).stdout.strip()
        for p in ['tools/pokemon-xy-bridge','tools/pokemon_xy_source_pins.json','tools/windows_native_components.json','tools/pinball-rs-native/windows-io.patch','tools/pinball-rs-native/runtime-fixes.patch']}
    (out/'source.json').write_text(json.dumps({'schema':1,'trees':provenance},indent=2)+'\n')
    hashes={p.relative_to(out).as_posix():digest(p)for p in out.rglob('*')if p.is_file()}
    forbidden={'.gb','.gbc','.gba','.nds','.3ds','.cia','.cxi','.sav','.state'}
    if any(Path(name).suffix.lower()in forbidden for name in hashes):raise ValueError('Game/profile data cannot be distributed in the native SDK')
    (out/'files.json').write_text(json.dumps(hashes,sort_keys=True)+'\n')
    print(json.dumps({'runtime':str(out),'id':identity,'files':len(hashes),'game_data_included':False}))

def build_graphics(qa,work,out,components):
    # Optional software ICD is added to the system's drivers rather than
    # forcing capable PCs to render on the CPU.
    loader=work/'vulkan-loader';clone(qa,'https://github.com/KhronosGroup/Vulkan-Loader.git',loader,components['vulkan_loader'])
    # The loader's pinned known-good file pins its matching public headers.
    good=json.loads((loader/'scripts/known_good.json').read_text())
    header=next(row for row in good['repos']if row['name']=='Vulkan-Headers')
    headers=work/'vulkan-headers';clone(qa,header['url'],headers,components['vulkan_headers'])
    qa.qa_run(['cmake','-S',str(headers),'-B',str(work/'headers-build'),'-DCMAKE_INSTALL_PREFIX='+str(work/'headers-install')],check=True)
    qa.qa_run(['cmake','--install',str(work/'headers-build')],check=True)
    qa.qa_run(['cmake','-S',str(loader),'-B',str(work/'loader-build'),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_PREFIX_PATH='+str(work/'headers-install'),'-DBUILD_TESTS=OFF','-DUPDATE_DEPS=OFF'],check=True)
    qa.qa_run(['cmake','--build',str(work/'loader-build'),'--parallel','2'],check=True)
    dll=list((work/'loader-build').rglob('vulkan-1.dll'))
    if len(dll)!=1:raise ValueError('Native Vulkan loader is missing')
    shutil.copy2(dll[0],out/'vulkan/vulkan-1.dll')
    notices(loader,out/'licenses','vulkan-loader')
    # Lavapipe supports the push descriptors required by the 3DS renderer.
    # SwiftShader exposes Vulkan 1.3 but lacks that required extension.
    mesa=components['mesa'];archive=work/'mesa-release.7z'
    download(mesa['url'],archive,mesa['sha256'])
    qa.qa_run(['7z','e',str(archive),'x64/vulkan_lvp.dll','x64/lvp_icd.x86_64.json','-o'+str(out/'vulkan'),'-y'],check=True)
    if not (out/'vulkan/vulkan_lvp.dll').is_file():raise ValueError('Pinned Lavapipe driver is missing')
    licence=out/'licenses/mesa';licence.mkdir(parents=True)
    download(mesa['source_url'],licence/'mesa-26.2.5-source.tar.xz',mesa['source_sha256'])
    download(mesa['license_url'],licence/'Mesa-license.rst',mesa['license_sha256'])
    download(mesa['llvm_license_url'],licence/'LLVM-LICENSE.txt',mesa['llvm_license_sha256'])
    download(mesa['distribution_license_url'],licence/'distribution-LICENSE.txt',mesa['distribution_license_sha256'])

if __name__=='__main__':main()
