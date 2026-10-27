#!/usr/bin/env python3
"""Relocate and exercise the bundled toolchain and real Vulkan device.

This is ROM-free runtime qualification, not an X/Y gameplay certificate.
Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import argparse
import ctypes as c
import json
import os
from pathlib import Path
import shutil
import sys
import time

from qa_storage import qa_source, qa_cache, qa_copy, qa_run, qa_restore_copy
import pokemon_xy_runtime as runtime
from package_pokemon_xy_runtime import verify

ROOT=Path(__file__).resolve().parents[1]


def child(root,output):
    runtime.load(root)
    runtime.finish(output/'probe.dylib','synthetic-fixture','synthetic-runtime')
    assert runtime.completed(output/'probe.dylib','synthetic-fixture','synthetic-runtime')
    library=c.CDLL(str(output/'probe.dylib'))
    library.retro_probe.argtypes=[c.c_int];library.retro_probe.restype=c.c_int
    assert library.retro_probe(42)==49
    bridge=c.CDLL(str(root/runtime.FILES['bridge']))
    class Assessment(c.Structure):
        _fields_=[('fps',c.c_double),('p95',c.c_double),('target',c.c_double),('status',c.c_uint32),('samples',c.c_uint32)]
    bridge.ascendant_3ds_assess.argtypes=[c.POINTER(c.c_double),c.c_size_t,c.c_bool,c.c_bool,c.c_uint32,c.POINTER(Assessment)]
    bridge.ascendant_3ds_assess.restype=c.c_bool
    durations=(c.c_double*360)(*[.004]*360);assessment=Assessment()
    assert bridge.ascendant_3ds_assess(durations,360,True,True,3,c.byref(assessment))
    assert assessment.status==2 and assessment.samples==360
    os.environ['VK_DRIVER_FILES']=str(root/runtime.FILES['icd'])
    os.environ['VK_ICD_FILENAMES']=str(root/runtime.FILES['icd'])
    vulkan=c.CDLL(str(root/runtime.FILES['loader']))
    class App(c.Structure):
        _fields_=[('kind',c.c_uint32),('next',c.c_void_p),('name',c.c_char_p),('version',c.c_uint32),('engine',c.c_char_p),('engine_version',c.c_uint32),('api',c.c_uint32)]
    class Instance(c.Structure):
        _fields_=[('kind',c.c_uint32),('next',c.c_void_p),('flags',c.c_uint32),('app',c.POINTER(App)),('layers',c.c_uint32),('layer_names',c.POINTER(c.c_char_p)),('extensions',c.c_uint32),('extension_names',c.POINTER(c.c_char_p))]
    app=App(0,None,b'RetroRecomped runtime QA',1,b'RetroRecomped',1,(1<<22)|(3<<12))
    extensions=(c.c_char_p*1)(b'VK_KHR_portability_enumeration')
    info=Instance(1,None,1,c.pointer(app),0,None,1,extensions)
    instance=c.c_void_p()
    vulkan.vkCreateInstance.argtypes=[c.POINTER(Instance),c.c_void_p,c.POINTER(c.c_void_p)];vulkan.vkCreateInstance.restype=c.c_int
    result=vulkan.vkCreateInstance(c.byref(info),None,c.byref(instance))
    assert result==0,('Vulkan instance creation',result)
    try:
        vulkan.vkEnumeratePhysicalDevices.argtypes=[c.c_void_p,c.POINTER(c.c_uint32),c.POINTER(c.c_void_p)]
        vulkan.vkEnumeratePhysicalDevices.restype=c.c_int
        count=c.c_uint32()
        assert vulkan.vkEnumeratePhysicalDevices(instance,c.byref(count),None)==0 and count.value>0
        devices=(c.c_void_p*count.value)()
        assert vulkan.vkEnumeratePhysicalDevices(instance,c.byref(count),devices)==0
        properties=c.create_string_buffer(4096)
        vulkan.vkGetPhysicalDeviceProperties.argtypes=[c.c_void_p,c.c_void_p]
        vulkan.vkGetPhysicalDeviceProperties(devices[0],properties)
        gpu=properties.raw[20:276].split(b'\0',1)[0].decode()
    finally:
        vulkan.vkDestroyInstance.argtypes=[c.c_void_p,c.c_void_p]
        vulkan.vkDestroyInstance(instance,None)
    return {'python':sys.version.split()[0],'c_toolchain':True,'bridge_abi':True,'vulkan_device':gpu,'physical_gpu':True,'native_game_played':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime',type=Path,required=True)
    parser.add_argument('--resume',type=Path,help='Reuse this qualifier\'s preserved runtime copy')
    parser.add_argument('--child',action='store_true');parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.child:
        print(json.dumps(child(args.runtime,args.output)),flush=True);return
    original=args.runtime.resolve(strict=True)
    for source in [ROOT,original,Path(sys.executable)]:qa_source(source)
    verify(original)
    out=args.resume.resolve() if args.resume else ROOT/'.local/qa'/('3ds-runtime-qualified-'+str(time.time_ns()))
    if args.resume and (out.parent!=ROOT/'.local/qa' or not out.name.startswith('3ds-runtime-qualified-')):
        parser.error('Resume only an existing runtime-qualification output.')
    qa_cache(out);out.mkdir(parents=True,exist_ok=bool(args.resume))
    source=out/'source'
    if args.resume:qa_restore_copy(source)
    else:qa_copy(source,ephemeral=True)
    relocated=source/'Relocated Demo.app/Contents/Resources/3ds-runtime'
    if not args.resume:shutil.copytree(original,relocated,symlinks=True)
    assert verify(relocated)['id']==verify(original)['id'],'A resumed copy must match the selected runtime.'
    blocked=out/'no-sdk-bin';blocked.mkdir(exist_ok=True)
    for name in ('xcrun','xcode-select','clang','gcc','cc','ld'):
        path=blocked/name;path.write_text('#!/bin/sh\necho '+name+' >> "$RETRO_BLOCKED_SDK_LOG"\nexit 88\n');path.chmod(0o755)
    env=runtime.environment(relocated,out/'profile')
    env.update(PATH=str(blocked)+':/usr/bin:/bin',RETRO_BLOCKED_SDK_LOG=str(out/'unexpected-sdk.txt'),PYTHONNOUSERSITE='1')
    for key in ('SDKROOT','DEVELOPER_DIR','PYTHONHOME','PYTHONPATH','DYLD_FALLBACK_LIBRARY_PATH','VK_DRIVER_FILES','VK_ICD_FILENAMES','ZIG_LIB_DIR'):
        env.pop(key,None)
    code=out/'probe.c';code.write_text('#include <stdint.h>\n#include <math.h>\nint retro_probe(int x){return (int)sqrt((double)x*x)+7;}\n')
    result=qa_run([str(relocated/runtime.FILES['cc']),'-shared','-fPIC','-O2',str(code),'-o',str(out/'probe.dylib')],cwd=out,env=env,capture_output=True,text=True,timeout=240)
    (out/'compiler.log').write_text(result.stdout+result.stderr);result.check_returncode()
    assert not (out/'unexpected-sdk.txt').exists(),'The bundled compiler fell back to system developer tools.'
    result=qa_run([str(relocated/runtime.FILES['python']),'-B','-E','-s',str(Path(__file__).resolve()),'--child','--runtime',str(relocated),'--output',str(out)],cwd=out,env=env,capture_output=True,text=True,timeout=120)
    (out/'native.log').write_text(result.stdout+result.stderr);result.check_returncode()
    report=json.loads(result.stdout.strip().splitlines()[-1])
    result=qa_run([str(relocated/runtime.FILES['compiler']),'--help'],cwd=out,env=env,capture_output=True,text=True,timeout=30)
    (out/'recompiler.log').write_text(result.stdout+result.stderr)
    assert result.returncode in (0,2) and '3dsrecomp' in result.stdout+result.stderr,'Recompiler command entry did not return its usage.'
    verify(relocated)
    report.update(passed=True,relocated=True,system_developer_tools_used=False,runtime_id=json.loads((relocated/'runtime.json').read_text())['id'])
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('RUNTIME_QUALIFIED '+str(out),flush=True)
    print(json.dumps(report),flush=True)


if __name__=='__main__':main()
