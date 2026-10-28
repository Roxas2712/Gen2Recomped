#!/usr/bin/env python3
"""Exercise Zig compile → link → cache retirement → rebuild without ROM data.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse
import ctypes
import json
from pathlib import Path
import sys
import time

import qa_storage as qa
import pokemon_xy_runtime as runtime
from package_pokemon_xy_runtime import verify
from qa_build_storage import clean_compiler_duplicates, clean_linked_objects

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True)
    args=parser.parse_args()
    bundle=args.runtime.resolve(strict=True)
    for source in (ROOT,bundle,Path(sys.executable)):qa.qa_source(source)
    verify(bundle)
    out=ROOT/'.local/qa'/('3ds-cache-cycle-'+str(time.time_ns()))
    qa.qa_cache(out);out.mkdir(parents=True)
    work=out/'work';output=work/'recompiled'/('a'*64);output.mkdir(parents=True)
    source=output/'code001.c';source.write_text('int retro_cache_cycle(void){return 42;}\n')
    obj=source.with_suffix('.o');binary=output/'0004000000055E00.dylib'
    env=runtime.environment(bundle,work)
    commands=[['-c','-fPIC','-O2',str(source),'-o',str(obj)],['-shared',str(obj),'-o',str(binary)]]
    sizes=[]
    for cycle in range(2):
        for name,command in zip(('compile','link'),commands):
            result=qa.qa_run([str(bundle/'bin/cc'),*command],env=env,cwd=out,capture_output=True,text=True,timeout=240)
            log=result.stdout+result.stderr;(out/(str(cycle)+'-'+name+'.log')).write_text(log)
            result.check_returncode()
            assert 'error:' not in log.lower(),log
            assert obj.stat().st_size>32,'Zig returned success with an empty object'
        runtime.finish(binary,'synthetic','synthetic-runtime')
        assert runtime.completed(binary,'synthetic','synthetic-runtime')
        sizes.append(obj.stat().st_size)
        if cycle==0:
            retired=clean_compiler_duplicates(work,output)
            assert retired>0,'The real compiler cache duplicate was not retired'
            assert list((work/'compiler-cache/retired-manifests').glob('*.txt'))
            clean_linked_objects(work)
            assert not obj.exists() and source.is_file() and binary.is_file()
    loaded=ctypes.CDLL(str(binary));loaded.retro_cache_cycle.restype=ctypes.c_int
    assert loaded.retro_cache_cycle()==42
    report={'passed':True,'cycles':2,'object_bytes':sizes,'real_bundled_compiler':True,'native_function_result':42,'native_game_played':False}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'output':str(out),**report}),flush=True)


if __name__=='__main__':main()
