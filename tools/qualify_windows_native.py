#!/usr/bin/env python3
"""Real Windows native ABI/toolchain checks; synthetic inputs, no player ROMs."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse,ctypes,hashlib,json,os,platform,struct,sys,shutil
from pathlib import Path
from native_workspace import manager,lock_file

ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sdk',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    if os.name!='nt':p.error('Execute these binaries on Windows x64.')
    sdk=a.sdk.resolve();qa=manager(ROOT);qa.qa_source(sdk);out=a.out.resolve();qa.qa_cache(out.parent)
    work=out.parent/'native-fixtures-Ömega';work.mkdir(parents=True,exist_ok=True)
    checks=[]
    def check(ok,name):
        if not ok:raise AssertionError(name)
        checks.append({'name':name,'passed':True})
    report={'schema':1,'passed':False,'platform':platform.system(),'checks':checks,'scope':'Real native Windows ABI/compiler and synthetic input checks. No real player ROM gameplay or real save migration.'}
    try:
        bridge=ctypes.CDLL(str(sdk/'lib/ascendant_3ds_bridge.dll'))
        class Place(ctypes.Structure):_fields_=[('x',ctypes.c_float),('y',ctypes.c_float),('width',ctypes.c_float),('height',ctypes.c_float),('screen',ctypes.c_uint32)]
        bridge.ascendant_3ds_layout.argtypes=[ctypes.c_uint32]*4+[ctypes.c_bool,ctypes.c_bool,ctypes.POINTER(Place),ctypes.c_size_t]
        bridge.ascendant_3ds_layout.restype=ctypes.c_size_t
        for layout in range(6):
            places=(Place*4)();count=bridge.ascendant_3ds_layout(1280,720,layout,0,False,False,places,4)
            check(0<count<=4 and all(v.width>0 and v.height>0 for v in places[:count]),'Native 3DS layout '+str(layout))
        bridge.ascendant_3ds_open.argtypes=[ctypes.c_char_p];bridge.ascendant_3ds_open.restype=ctypes.c_void_p
        bridge.ascendant_3ds_error.restype=ctypes.c_char_p
        check(not bridge.ascendant_3ds_open(b'{}') and bool(bridge.ascendant_3ds_error()),'Malformed 3DS session is rejected without a panic')
        lock=work/'session.lock'
        request={'rom':str(work/'missing.cxi'),'library':str(work/'missing.dll'),'data':str(work/'player'),'session_lock':str(lock),
            'resolution':1,'language':1,'depth_3d':0,'stereo':'off','texture_packs':False}
        with lock.open('a')as file:
            lock_file(file)
            check(not bridge.ascendant_3ds_open(json.dumps(request).encode()) and b'Sitzung' in bridge.ascendant_3ds_error(),'Python and native 3DS session locks exclude each other')
        env=dict(os.environ,PATH=str(sdk/'compiler/bin')+os.pathsep+os.environ.get('PATH',''))
        source=work/'compiler-fixture.c';source.write_text('__declspec(dllexport) int native_sdk_answer(void) { return 42; }\n')
        library=work/'compiler-fixture.dll'
        qa.qa_run([str(sdk/'compiler/bin/clang.exe'),'-shared','-O2',str(source),'-o',str(library)],env=env,check=True)
        dll=ctypes.CDLL(str(library));dll.native_sdk_answer.restype=ctypes.c_int
        check(dll.native_sdk_answer()==42,'Bundled C compiler creates a loadable Windows DLL in a Unicode path')
        rom=work/'synthetic-gba.fixture';body=bytearray(1024);struct.pack_into('<I',body,0xC0,0xEAFFFFFE);rom.write_bytes(body)
        qa.qa_run([str(sdk/'bin/gba_recompile.exe'),'--rom',str(rom),'--entry','0x080000C0','--out',str(work/'generated'),'--max-functions','32','--codegen-shards','2'],env=env,check=True)
        check((work/'generated/dispatch_table.cpp').is_file(),'Native GBA recompiler processes synthetic guest code in a Unicode path')
        check_vulkan(sdk,check)
        check_pinball(sdk,work,qa,check)
        report['sdkManifestSha256']=hashlib.sha256((sdk/'files.json').read_bytes()).hexdigest()
        report['passed']=True
    finally:
        out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

def check_vulkan(sdk,check):
    # Force only this isolated fixture onto the shipped software ICD. The real
    # application adds it alongside the user's GPU drivers instead.
    previous=os.environ.get('VK_DRIVER_FILES');os.environ['VK_DRIVER_FILES']=str(sdk/'vulkan/vk_swiftshader_icd.json')
    class App(ctypes.Structure):_fields_=[('kind',ctypes.c_uint32),('next',ctypes.c_void_p),('name',ctypes.c_char_p),('version',ctypes.c_uint32),('engine',ctypes.c_char_p),('engine_version',ctypes.c_uint32),('api',ctypes.c_uint32)]
    class Info(ctypes.Structure):_fields_=[('kind',ctypes.c_uint32),('next',ctypes.c_void_p),('flags',ctypes.c_uint32),('app',ctypes.POINTER(App)),('layers',ctypes.c_uint32),('layer_names',ctypes.c_void_p),('extensions',ctypes.c_uint32),('extension_names',ctypes.c_void_p)]
    instance=ctypes.c_void_p()
    vk=ctypes.WinDLL(str(sdk/'vulkan/vulkan-1.dll'))
    vk.vkCreateInstance.argtypes=[ctypes.POINTER(Info),ctypes.c_void_p,ctypes.POINTER(ctypes.c_void_p)]
    vk.vkEnumeratePhysicalDevices.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint32),ctypes.c_void_p]
    vk.vkDestroyInstance.argtypes=[ctypes.c_void_p,ctypes.c_void_p]
    try:
        app=App(0,None,b'Own synthetic qualification',1,None,0,(1<<22)|(3<<12));info=Info(1,None,0,ctypes.pointer(app),0,None,0,None)
        check(vk.vkCreateInstance(ctypes.byref(info),None,ctypes.byref(instance))==0,'Packaged Vulkan loader and software ICD create a native Vulkan 1.3 instance')
        count=ctypes.c_uint32();check(vk.vkEnumeratePhysicalDevices(instance,ctypes.byref(count),None)==0 and count.value>0,'Packaged software Vulkan driver exposes a usable device')
    finally:
        if instance.value:vk.vkDestroyInstance(instance,None)
        if previous is None:os.environ.pop('VK_DRIVER_FILES',None)
        else:os.environ['VK_DRIVER_FILES']=previous

def check_pinball(sdk,work,qa,check):
    import pinball_windows
    # Self-authored ARM instructions write SRAM and loop. A separate fixture
    # source accepts exactly this hash/size, never a bypass in the shipped ABI.
    rom=work/'own-arm-code.fixture';body=bytearray(1024)
    for at,word in [(0,0xEA00002E),(0xC0,0xE59F0008),(0xC4,0xE3A01042),(0xC8,0xE5C01000),(0xCC,0xEAFFFFFE),(0xD0,0x0E000000)]:struct.pack_into('<I',body,at,word)
    rom.write_bytes(body)
    fixture=work/'test-only-source';source=fixture/'tools/pinball-rs-native';source.mkdir(parents=True,exist_ok=True)
    for name in ['presentation.h','presentation.cpp','bridge.cpp']:shutil.copy2(ROOT/'tools/pinball-rs-native'/name,source/name)
    bridge=(source/'bridge.cpp').read_text()
    assert bridge.count('9fec81ce2c5df589e0371a0bf2f92a5fe8db730b')==1
    bridge=bridge.replace('9fec81ce2c5df589e0371a0bf2f92a5fe8db730b',hashlib.sha1(body).hexdigest()).replace('rom_size=8*1024*1024','rom_size=1024')
    (source/'bridge.cpp').write_text(bridge)
    build=work/'native-synthetic-pinball';build.mkdir(exist_ok=True);dll=build/'own-fixture.dll'
    runtime=json.loads((sdk/'pinball-runtime.json').read_text())
    pinball_windows.compile_guest(fixture,sdk,runtime,rom,'usa',build,dll,qa)
    native=ctypes.CDLL(str(dll));native.ascendant_pinball_open.argtypes=[ctypes.c_char_p]*3;native.ascendant_pinball_open.restype=ctypes.c_void_p
    native.ascendant_pinball_step.argtypes=[ctypes.c_void_p,ctypes.c_uint16];native.ascendant_pinball_frame.argtypes=[ctypes.c_void_p];native.ascendant_pinball_frame.restype=ctypes.c_uint64
    native.ascendant_pinball_state.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_int];native.ascendant_pinball_close.argtypes=[ctypes.c_void_p]
    native.ascendant_pinball_error.restype=ctypes.c_char_p
    save=work/'synthetic-sram.fixture';original=b'\0'*32768;save.write_bytes(original)
    handle=native.ascendant_pinball_open(str(rom).encode(),str(sdk/runtime['bios']).encode(),str(save).encode())
    check(bool(handle),'Native Pinball stack opens the self-authored guest with an existing synthetic SRAM')
    state=work/'synthetic-quickstate.fixture'
    try:
        for _ in range(3):check(native.ascendant_pinball_step(handle,0)==1,'Native synthetic GBA frame advances: '+str(native.ascendant_pinball_error()))
        frame=native.ascendant_pinball_frame(handle)
        check(frame>=3,'Native GBA frame boundaries advance')
        check(native.ascendant_pinball_state(handle,str(state).encode(),0)==1,'Native Pinball snapshot writes through a Unicode path')
        check(native.ascendant_pinball_step(handle,0)==1 and native.ascendant_pinball_frame(handle)>frame,'Synthetic guest advances after the snapshot')
        check(native.ascendant_pinball_state(handle,str(state).encode(),1)==1 and native.ascendant_pinball_frame(handle)==frame,'Native snapshot restores the exact synthetic frame')
        check(native.ascendant_pinball_state(handle,str(state).encode(),0)==1,'Native quick states can replace an existing state')
    finally:
        check(native.ascendant_pinball_close(handle)==1,'Native Pinball session closes and commits SRAM')
    check(save.read_bytes()[0]==0x42 and save.stat().st_size==32768,'Native guest SRAM replaces the old file without truncating it')
    check(rom.read_bytes()==body,'The native guest input stays byte-identical')

if __name__=='__main__':main()
