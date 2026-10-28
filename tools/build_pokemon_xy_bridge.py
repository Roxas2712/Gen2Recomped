#!/usr/bin/env python3
"""Build the in-process 3DS bridge from the reviewed private Zakuro checkout."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import pokemon_x_preflight as preflight

ROOT=preflight.ROOT
WORK=ROOT/'.local/pokemon-x'
CACHE=ROOT/'.local/qa/pokemon-x-feasibility'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test',action='store_true')
    args=parser.parse_args()
    qa=preflight.qa_manager()
    def finish(code):
        if code==0:
            from qa_transient_storage import clean_cargo
            reclaimed=clean_cargo(qa._storage,ROOT,min_age=0)
            print('Cargo intermediates reclaimed:',reclaimed,flush=True)
        return code
    for source in [ROOT,WORK]:qa.qa_source(source)
    qa.qa_cache(CACHE)
    qa._storage.check_space()
    cargo=WORK/'cargo/bin/cargo'
    if not cargo.is_file():raise ValueError('Lokale Rust-Laufzeit fehlt.')
    env=dict(os.environ,RUSTUP_HOME=str(WORK/'rustup'),CARGO_HOME=str(WORK/'cargo'),RUSTUP_TOOLCHAIN='stable',CARGO_TARGET_DIR=str(CACHE/'target'),CARGO_BUILD_JOBS='2')
    env['PATH']=str(WORK/'cargo/bin')+os.pathsep+env['PATH']
    manifest=ROOT/'tools/pokemon-xy-bridge/Cargo.toml'
    command=[str(cargo),'build','--release','--locked','--manifest-path',str(manifest)]
    with (CACHE/'native-bridge-build.log').open('w') as log:
        result=qa.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log)
    if result.returncode:return result.returncode
    name='libascendant_3ds_bridge.dylib'
    qa._storage.check_space()
    target=WORK/'bin'/name;pending=target.with_suffix('.pending')
    shutil.copy2(CACHE/'target/release'/name,pending)
    pending.replace(target) # Existing sessions keep their original mapped code.
    print('3DS bridge installed:',target,flush=True)
    if args.test:
        command[1]='test'
        with (CACHE/'native-bridge-tests.log').open('w') as log:
            result=qa.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log)
        print('Bridge tests:',result.returncode,flush=True)
        if result.returncode:return result.returncode
        gpu_manifest=WORK/'zakuro/crates/zakuro-gpu/Cargo.toml'
        command=[str(cargo),'test','--release','--locked','--manifest-path',str(gpu_manifest),'--features','vulkan','--lib','readback_pool_tests']
        with (CACHE/'native-readback-tests.log').open('w') as log:
            result=qa.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log)
        print('Readback pool tests:',result.returncode,flush=True)
        if result.returncode==0 and '3 passed; 0 failed' not in (CACHE/'native-readback-tests.log').read_text():
            print('Readback pool tests were not discovered',file=sys.stderr);return 1
        if result.returncode:return result.returncode
        command[-1]='vertex_handoff_preserves_bits_and_input_order'
        with (CACHE/'native-handoff-tests.log').open('w') as log:
            result=qa.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log)
        print('Vertex handoff tests:',result.returncode,flush=True)
        if result.returncode==0 and '1 passed; 0 failed' not in (CACHE/'native-handoff-tests.log').read_text():
            print('Vertex handoff test was not discovered',file=sys.stderr);return 1
        return finish(result.returncode)
    return finish(0)

if __name__=='__main__':
    try:sys.exit(main())
    except (OSError,ValueError,RuntimeError,subprocess.SubprocessError) as error:
        print(error,file=sys.stderr);sys.exit(2)
