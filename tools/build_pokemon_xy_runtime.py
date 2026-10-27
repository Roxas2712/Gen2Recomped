#!/usr/bin/env python3
"""Build and assemble the game-data-free Apple Silicon 3DS sidecar.

Requires a maintainer Rust 1.95.0 toolchain and C build tools. The finished
sidecar includes Python, Zig/Clang, Vulkan and MoltenVK for end-user imports.
Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import sys
import tarfile
import urllib.request

from qa_storage import qa_source, qa_cache, qa_copy, qa_run

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def fetch_components(folder, metadata):
    folder.mkdir(parents=True, exist_ok=True)
    for name, row in metadata.items():
        archive = folder/(name+'.tar')
        if not archive.exists():
            headers = {'User-Agent': 'RetroRecomped-runtime-builder'}
            if row['url'].startswith('https://ghcr.io/'):
                headers['Authorization'] = 'Bearer QQ=='  # public Homebrew bottle
            pending = archive.with_suffix('.pending')
            with urllib.request.urlopen(urllib.request.Request(row['url'], headers=headers), timeout=120) as source, pending.open('wb') as dest:
                shutil.copyfileobj(source, dest, 1024*1024)
            if digest(pending) != row['sha256']:
                raise ValueError('Component digest mismatch: '+name)
            pending.replace(archive)
        if digest(archive) != row['sha256']:
            raise ValueError('Component digest mismatch: '+name)
        dest = folder/name
        if not dest.exists():
            dest.mkdir()
            with tarfile.open(archive) as source:
                source.extractall(dest, filter='data')


def sources(work, pins):
    for name, pin in pins.items():
        folder = work/name
        if not folder.exists():
            qa_run(['git','clone','--filter=blob:none','--no-checkout','https://github.com/fearkov/'+name+'.git',str(folder)], check=True)
            qa_run(['git','checkout','--detach',pin['revision']], cwd=folder, check=True)
        revision = qa_run(['git','rev-parse','HEAD'], cwd=folder, capture_output=True, text=True, check=True).stdout.strip()
        if revision != pin['revision']:
            raise ValueError('Wrong source revision: '+name)
        status = qa_run(['git','status','--porcelain'], cwd=folder, capture_output=True, text=True, check=True).stdout
        if not status:
            for patch, expected in pin['patches'].items():
                path = ROOT/'tools/patches'/patch
                if digest(path) != expected:
                    raise ValueError('Patch digest mismatch: '+patch)
                qa_run(['git','apply','--check',str(path)], cwd=folder, check=True)
                qa_run(['git','apply',str(path)], cwd=folder, check=True)
        changed = qa_run(['git','status','--porcelain'], cwd=folder, capture_output=True, text=True, check=True).stdout.splitlines()
        if any(line[3:] not in pin['patched_files'] for line in changed):
            raise ValueError('Unreviewed source changes in '+name+'; preserve them and use a clean checkout.')
        for path, expected in pin['patched_files'].items():
            if digest(folder/path) != expected:
                raise ValueError('Patched source digest mismatch: '+name+'/'+path)


def sign(path):
    qa_run(['codesign','--force','--sign','-',str(path)], capture_output=True, check=True)


def native_code(path):
    if path.is_symlink() or not path.is_file():
        return False
    with path.open('rb') as stream:
        data = stream.read(16)
    return len(data) == 16 and data[:4] == b'\xcf\xfa\xed\xfe' and struct.unpack('<I',data[12:16])[0] in (2,6,8)


def licenses(out, work, cargo, env):
    target = out/'licenses';target.mkdir()
    packages = qa_run([str(cargo),'metadata','--format-version','1','--locked','--manifest-path',str(ROOT/'tools/pokemon-xy-bridge/Cargo.toml')], cwd=ROOT, env=env, capture_output=True, text=True, check=True)
    records = []
    for package in json.loads(packages.stdout)['packages']:
        folder = Path(package['manifest_path']).parent
        record = {'name':package['name'],'version':package['version'],'license':package['license'],'source':package['source']}
        records.append(record)
        names = set()
        for pattern in ('LICENSE*','COPYING*','NOTICE*','COPYRIGHT*'):
            names.update(p for p in folder.glob(pattern) if p.is_file())
        if package.get('license_file'):
            names.add(folder/package['license_file'])
        dest = target/'rust'/(package['name']+'-'+package['version'])
        dest.mkdir(parents=True, exist_ok=True)
        for source in names:
            if source.is_file() and source.stat().st_size < 1024*1024:
                shutil.copy2(source, dest/source.name)
    for name in ('zakuro','3dsrecomp'):
        dest=target/name;dest.mkdir()
        for source in (work/name).glob('LICENSE*'):
            if source.is_file():shutil.copy2(source,dest/source.name)
    shutil.copy2(ROOT/'LICENSE-ROXAS2712.md',target/'LICENSE-ROXAS2712.md')
    (target/'rust-components.json').write_text(json.dumps(records,indent=2)+'\n')
    (target/'README.txt').write_text('Runtime integration: Roxas2712. Zakuro and 3dsrecomp: fearkov (MIT).\nMoltenVK and Vulkan Loader: Khronos contributors (Apache-2.0).\nPython: Python Software Foundation and contributors; see python/share.\nZig and LLVM: see compiler/LICENSE and the notices retained in compiler/lib.\nNo ROMs, generated game libraries, console keys, firmware or saves are included.\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--work',type=Path,default=ROOT/'.local/pokemon-x')
    parser.add_argument('--target',type=Path,default=ROOT/'.local/qa/3ds-runtime-native-build/target')
    parser.add_argument('--fetch-components',action='store_true')
    parser.add_argument('--build',action='store_true')
    parser.add_argument('--test',action='store_true')
    args=parser.parse_args()
    if platform.system()!='Darwin' or platform.machine()!='arm64':
        parser.error('This builder currently qualifies macOS Apple Silicon only.')
    if args.out.exists():
        parser.error('Choose a new output folder; existing runtimes are preserved.')
    work=args.work.resolve();target=args.target.resolve();out=args.out.resolve()
    for source in [ROOT,work,Path(sys.executable)]:qa_source(source)
    qa_cache(target.parent)
    components=json.loads((ROOT/'tools/pokemon_xy_components.json').read_text())['components']
    pins=json.loads((ROOT/'tools/pokemon_xy_source_pins.json').read_text())['sources']
    if args.fetch_components:fetch_components(work/'runtime-components',components)
    sources(work,pins)
    env=dict(os.environ,RUSTUP_HOME=str(work/'rustup'),CARGO_HOME=str(work/'cargo'),RUSTUP_TOOLCHAIN='1.95.0',CARGO_TARGET_DIR=str(target),CARGO_BUILD_JOBS='2',CARGO_PROFILE_RELEASE_DEBUG='0',MACOSX_DEPLOYMENT_TARGET='13.0')
    env['RUSTFLAGS']='--remap-path-prefix='+str(Path.home())+'=/build/RetroRecomped'
    env['PATH']=str(work/'cargo/bin')+os.pathsep+env.get('PATH','/usr/bin:/bin')
    cargo=work/'cargo/bin/cargo'
    manifests=[work/'3dsrecomp/Cargo.toml',ROOT/'tools/pokemon-xy-bridge/Cargo.toml']
    target.parent.mkdir(parents=True,exist_ok=True)
    if args.build:
        for name,manifest in zip(('compiler','bridge'),manifests):
            print('BUILDING '+name,flush=True)
            with (target.parent/('bundled-'+name+'.log')).open('w') as log:
                qa_run([str(cargo),'build','--release','--locked','--manifest-path',str(manifest)],cwd=ROOT,env=env,stdout=log,stderr=log,check=True)
    if args.test:
        for name,manifest in zip(('compiler','bridge'),manifests):
            with (target.parent/('bundled-'+name+'-tests.log')).open('w') as log:
                qa_run([str(cargo),'test','--release','--locked','--manifest-path',str(manifest),'--lib'],cwd=ROOT,env=env,stdout=log,stderr=log,check=True)
    qa_copy(out);out.mkdir(parents=True)
    for name in ('bin','lib','vulkan'):(out/name).mkdir()
    shutil.copy2(target/'release/3dsrecomp',out/'bin/3dsrecomp')
    shutil.copy2(target/'release/libascendant_3ds_bridge.dylib',out/'lib/libascendant_3ds_bridge.dylib')
    folder=work/'runtime-components'
    shutil.copytree(folder/'python/python',out/'python',symlinks=True)
    shutil.copytree(folder/'zig/zig-aarch64-macos-0.15.2',out/'compiler',symlinks=True)
    for name,pattern,dest in [('molten-vk','**/lib/libMoltenVK.dylib','libMoltenVK.dylib'),('vulkan-loader','**/lib/libvulkan.1.*.dylib','libvulkan.1.dylib')]:
        source=list((folder/name).glob(pattern))
        if len(source)!=1:raise ValueError('Ambiguous graphics library: '+name)
        shutil.copy2(source[0],out/'vulkan'/dest)
        qa_run(['install_name_tool','-id','@rpath/'+dest,str(out/'vulkan'/dest)],check=True,capture_output=True)
    qa_run(['install_name_tool','-id','@rpath/libascendant_3ds_bridge.dylib',str(out/'lib/libascendant_3ds_bridge.dylib')],check=True,capture_output=True)
    (out/'vulkan/MoltenVK_icd.json').write_text(json.dumps({'file_format_version':'1.0.1','ICD':{'library_path':'./libMoltenVK.dylib','api_version':'1.3.0','is_portability_driver':True}},indent=2)+'\n')
    cc=out/'bin/cc'
    cc.write_text('#!/bin/sh\nretro_cc_root=$(CDPATH= cd -- "$(dirname -- "$0")/../compiler" && pwd) || exit 1\nexec "$retro_cc_root/zig" cc -target aarch64-macos.13.0 "$@"\n')
    cc.chmod(0o755)
    licenses(out,work,cargo,env)
    for name in ('molten-vk','vulkan-loader'):
        dest=out/'licenses'/name;dest.mkdir()
        for source in (folder/name).glob('**/LICENSE*'):
            if source.is_file():shutil.copy2(source,dest/source.name)
        for source in (folder/name).glob('**/sbom.spdx.json'):
            shutil.copy2(source,dest/source.name)
    # Every embedded executable is signed before the containing app is sealed.
    for path in sorted(out.rglob('*')):
        if native_code(path):sign(path)
    hashes={str(p.relative_to(out)):digest(p) for p in sorted(out.rglob('*')) if p.is_file() and not p.is_symlink()}
    (out/'files.json').write_text(json.dumps(hashes,sort_keys=True,indent=2)+'\n')
    import pokemon_xy_runtime as runtime
    critical={p:hashes[p] for p in runtime.FILES.values()}
    critical['compiler/zig']=hashes['compiler/zig']
    metadata={'schema':1,'bridge_protocol':1,'platform':'macos-arm64','minimum_macos':'15.0','editions':['x','y'],'sources':pins,'components':components,'artifacts':critical}
    metadata['compilation_id']=hashlib.sha256(json.dumps({'compiler':critical['bin/3dsrecomp'],'zig':critical['compiler/zig'],'abi':digest(work/'3dsrecomp/abi/recomp.h'),'platform':'macos-arm64'},sort_keys=True).encode()).hexdigest()
    metadata['id']=hashlib.sha256(json.dumps(metadata,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    (out/'runtime.json').write_text(json.dumps(metadata,sort_keys=True,indent=2)+'\n')
    if any(str(Path.home()).encode() in (out/p).read_bytes() for p in ('bin/3dsrecomp','lib/libascendant_3ds_bridge.dylib')):
        raise ValueError('A native binary retained a private build path.')
    print(json.dumps({'runtime':str(out),'id':metadata['id'],'files':len(hashes),'game_data_included':False}),flush=True)


if __name__=='__main__':main()
