#!/usr/bin/env python3
"""Real Windows native ABI/toolchain checks; synthetic inputs, no player ROMs."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse,contextlib,ctypes,hashlib,json,math,os,platform,struct,sys,shutil,subprocess
from pathlib import Path
from native_workspace import manager,lock_file

ROOT=Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sdk',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    if os.name!='nt':p.error('Execute these binaries on Windows x64.')
    sdk=a.sdk.resolve();qa=manager(ROOT);qa.qa_source(sdk);out=a.out.resolve();qa.qa_cache(out.parent)
    work=out.parent/'native-fixtures-Ömega %!';work.mkdir(parents=True,exist_ok=True)
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
        with elevated_runner_driver(sdk):
            check_vulkan(sdk,check)
            check_3ds_guest(sdk,work,qa,bridge,check)
            check_pinball(sdk,work,qa,check)
        report['sdkManifestSha256']=hashlib.sha256((sdk/'files.json').read_bytes()).hexdigest()
        report['passed']=True
    finally:
        out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))

@contextlib.contextmanager
def elevated_runner_driver(sdk):
    # GitHub's disposable Windows VM runs elevated: the official loader
    # deliberately ignores VK_*_DRIVER_FILES there. Register only this fixture
    # for the duration of the native test, then restore its exact old value.
    # The shipped application never changes registry/driver installation.
    if not ctypes.windll.shell32.IsUserAnAdmin():
        yield;return
    import winreg
    name=str(sdk/'vulkan/lvp_icd.x86_64.json')
    key_path=r'SOFTWARE\Khronos\Vulkan\Drivers'
    access=winreg.KEY_QUERY_VALUE|winreg.KEY_SET_VALUE|winreg.KEY_WOW64_64KEY
    with winreg.CreateKeyEx(winreg.HKEY_LOCAL_MACHINE,key_path,0,access)as key:
        try:old=winreg.QueryValueEx(key,name)
        except FileNotFoundError:old=None
        winreg.SetValueEx(key,name,0,winreg.REG_DWORD,0)
        print('Elevated disposable QA runner: temporarily register the fixture ICD; VK_DRIVER_FILES is ignored by the official loader.',flush=True)
        try:yield
        finally:
            if old is None:winreg.DeleteValue(key,name)
            else:winreg.SetValueEx(key,name,0,old[1],old[0])

def check_vulkan(sdk,check):
    # Force only this isolated fixture onto the shipped software ICD. The real
    # application adds it alongside the user's GPU drivers instead.
    previous=os.environ.get('VK_DRIVER_FILES');os.environ['VK_DRIVER_FILES']=str(sdk/'vulkan/lvp_icd.x86_64.json')
    previous_debug=os.environ.get('VK_LOADER_DEBUG');os.environ['VK_LOADER_DEBUG']='all'
    # Resolve the real driver eagerly so missing MSVC dependencies are visible
    # as an OS error rather than a generic Vulkan incompatible-driver code.
    driver=ctypes.WinDLL(str(sdk/'vulkan/vulkan_lvp.dll'))
    class App(ctypes.Structure):_fields_=[('kind',ctypes.c_uint32),('next',ctypes.c_void_p),('name',ctypes.c_char_p),('version',ctypes.c_uint32),('engine',ctypes.c_char_p),('engine_version',ctypes.c_uint32),('api',ctypes.c_uint32)]
    class Info(ctypes.Structure):_fields_=[('kind',ctypes.c_uint32),('next',ctypes.c_void_p),('flags',ctypes.c_uint32),('app',ctypes.POINTER(App)),('layers',ctypes.c_uint32),('layer_names',ctypes.c_void_p),('extensions',ctypes.c_uint32),('extension_names',ctypes.c_void_p)]
    instance=ctypes.c_void_p()
    vk=ctypes.WinDLL(str(sdk/'vulkan/vulkan-1.dll'))
    vk.vkCreateInstance.argtypes=[ctypes.POINTER(Info),ctypes.c_void_p,ctypes.POINTER(ctypes.c_void_p)]
    vk.vkEnumeratePhysicalDevices.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint32),ctypes.c_void_p]
    vk.vkDestroyInstance.argtypes=[ctypes.c_void_p,ctypes.c_void_p]
    try:
        app=App(0,None,b'Own synthetic qualification',1,None,0,(1<<22)|(3<<12));info=Info(1,None,0,ctypes.pointer(app),0,None,0,None)
        result=vk.vkCreateInstance(ctypes.byref(info),None,ctypes.byref(instance))
        check(result==0,'Packaged Vulkan loader and software ICD create a native Vulkan 1.3 instance (VkResult '+str(result)+')')
        count=ctypes.c_uint32();check(vk.vkEnumeratePhysicalDevices(instance,ctypes.byref(count),None)==0 and count.value>0,'Packaged software Vulkan driver exposes a usable device')
    finally:
        if instance.value:vk.vkDestroyInstance(instance,None)
        if previous is None:os.environ.pop('VK_DRIVER_FILES',None)
        else:os.environ['VK_DRIVER_FILES']=previous
        if previous_debug is None:os.environ.pop('VK_LOADER_DEBUG',None)
        else:os.environ['VK_LOADER_DEBUG']=previous_debug

def check_3ds_guest(sdk,work,qa,bridge,check):
    # Self-authored NCCH container and two ARM instructions. The supported
    # title ID exercises the bridge's ordinary title guard, not Nintendo code.
    body=bytearray(0x1E00);body[0x100:0x104]=b'NCCH'
    struct.pack_into('<I',body,0x104,len(body)//512);struct.pack_into('<Q',body,0x118,0x0004000000055D00)
    struct.pack_into('<I',body,0x180,0x400);body[0x18C]=1;body[0x18D]=2;body[0x18F]=6
    struct.pack_into('<III',body,0x1A0,5,9,1)
    struct.pack_into('<III',body,0x1B0,14,1,1)
    body[0x200:0x208]=b'OwnCode\0';struct.pack_into('<III',body,0x210,0x100000,1,8);struct.pack_into('<I',body,0x21C,0x2000)
    struct.pack_into('<III',body,0x220,0x101000,0,0);struct.pack_into('<III',body,0x230,0x101000,0,0)
    struct.pack_into('<Q',body,0x400,0x0004000000055D00);body[0x40F]=32
    for at in range(0x570,0x5E0,4):struct.pack_into('<I',body,at,0xFFFFFFFF)
    body[0xA00:0xA08]=b'.code\0\0\0';struct.pack_into('<II',body,0xA08,0,0x1000)
    struct.pack_into('<II',body,0xC00,0xE2800001,0xEAFFFFFD)
    body[0xBE0:0xC00]=hashlib.sha256(body[0xC00:0x1C00]).digest();body[0x160:0x180]=hashlib.sha256(body[0x200:0x600]).digest()
    body[0x1C0:0x1E0]=hashlib.sha256(body[0xA00:0xC00]).digest()
    body[0x1E0:0x200]=hashlib.sha256(body[0x1C00:]).digest()
    rom=work/'own-arm11.fixture';rom.write_bytes(body)
    env=dict(os.environ,CC=str(sdk/'compiler/bin/clang.exe'),RETRO_3DS_BUILD_JOBS='2',PATH=os.pathsep.join([str(sdk/'compiler/bin'),str(sdk/'python'),os.environ.get('PATH','')]))
    try:
        result=qa.qa_run([str(sdk/'python/python.exe'),'-X','utf8',str(ROOT/'tools/pokemon_x_backend.py'),
            '--root',str(work/'launcher-backend'),'--runtime-root',str(sdk),'--edition','x','import',str(rom),'--play-after-import'],
            env=env,check=True,timeout=180,capture_output=True,text=True)
    except subprocess.CalledProcessError as error:
        print((error.stdout or '')[-12000:]);print((error.stderr or '')[-12000:]);raise
    documents=[json.loads(line)for line in result.stdout.splitlines()if line.startswith('{')]
    sessions=[row['native_session']for row in documents if'native_session'in row]
    check(len(sessions)==1,'The real Windows launcher helper completes import, native compilation and session preparation for the self-authored ARM11 fixture')
    request=sessions[0];check(Path(request['library']).is_file(),'The real helper commits a Windows game DLL and completion marker')
    handle=bridge.ascendant_3ds_open(json.dumps(request).encode())
    check(bool(handle),'Native 3DS core opens the recompiled synthetic guest with the packaged Vulkan backend'+(''if handle else ': '+str(bridge.ascendant_3ds_error())))
    bridge.ascendant_3ds_step.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.c_float,ctypes.c_float,ctypes.c_int,ctypes.c_int,ctypes.c_bool]
    bridge.ascendant_3ds_status.argtypes=[ctypes.c_void_p];bridge.ascendant_3ds_status.restype=ctypes.c_char_p
    bridge.ascendant_3ds_state.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_bool];bridge.ascendant_3ds_state.restype=ctypes.c_bool
    bridge.ascendant_3ds_close.argtypes=[ctypes.c_void_p]
    try:
        for _ in range(3):
            result=bridge.ascendant_3ds_step(handle,0,0,0,-1,-1,False)
            check(result==0,'Native ARM11 synthetic frame advances'+(''if result==0 else ': '+str(bridge.ascendant_3ds_error())))
        status=json.loads(bridge.ascendant_3ds_status(handle));check(status['frames']>=3 and status['recompiled']>0 and status['hardware'],'Native ARM11 execution uses the compiled guest and Vulkan backend')
        state=str(work/'arm11-snapshot.fixture').encode()
        check(bridge.ascendant_3ds_state(handle,state,False),'Native 3DS synthetic snapshot can be saved')
        check(bridge.ascendant_3ds_step(handle,0,0,0,-1,-1,False)==0 and bridge.ascendant_3ds_state(handle,state,True),'Native 3DS synthetic snapshot can be restored')
        check(json.loads(bridge.ascendant_3ds_status(handle))['frames']==status['frames'],'Native 3DS snapshot restores the exact synthetic frame')
        check(bridge.ascendant_3ds_state(handle,state,False),'Native 3DS snapshots can replace an existing state')
    finally:bridge.ascendant_3ds_close(handle)
    check(rom.read_bytes()==body,'The native ARM11 fixture input stays byte-identical')

def check_pinball(sdk,work,qa,check):
    import pinball_windows
    # Self-authored ARM instructions write SRAM and loop. A separate fixture
    # source accepts exactly this hash/size, never a bypass in the shipped ABI.
    rom=work/'own-arm-code.fixture';body=bytearray(1024);struct.pack_into('<I',body,0,0xEA00002E)
    # An original square-wave beep plus one SRAM byte; no game soundtrack.
    writes=[(0x04000084,0x80),(0x04000080,0x77),(0x04000081,0x11),(0x04000062,0x80),(0x04000063,0xF0),(0x04000064,0),(0x04000065,0x84),(0x0E000000,0x42)]
    pool=0xC0+len(writes)*12+4
    for i,(address,value)in enumerate(writes):
        at=0xC0+i*12
        struct.pack_into('<III',body,at,0xE59F0000|(pool+i*4-at-8),0xE3A01000|value,0xE5C01000)
        struct.pack_into('<I',body,pool+i*4,address)
    struct.pack_into('<I',body,pool-4,0xEAFFFFFE)
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
    native.ascendant_pinball_audio.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_size_t),ctypes.POINTER(ctypes.c_uint32)];native.ascendant_pinball_audio.restype=ctypes.POINTER(ctypes.c_int16)
    native.ascendant_pinball_diagnostics.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_double)]
    native.ascendant_pinball_error.restype=ctypes.c_char_p
    save=work/'synthetic-sram.fixture';original=b'\0'*32768;save.write_bytes(original)
    handle=native.ascendant_pinball_open(str(rom).encode(),str(sdk/runtime['bios']).encode(),str(save).encode())
    check(bool(handle),'Native Pinball stack opens the self-authored guest with an existing synthetic SRAM')
    state=work/'synthetic-quickstate.fixture'
    try:
        timings=(ctypes.c_double*4)()
        check(native.ascendant_pinball_diagnostics(handle,timings)==1,'Native Pinball diagnostic timing can be enabled')
        for _ in range(3):check(native.ascendant_pinball_step(handle,0)==1,'Native synthetic GBA frame advances: '+str(native.ascendant_pinball_error()))
        check(native.ascendant_pinball_diagnostics(handle,timings)==1 and all(math.isfinite(v)and v>=0 for v in timings)and timings[0]>0,'Native Windows thread CPU and wall-clock diagnostics return finite nonnegative timings')
        frame=native.ascendant_pinball_frame(handle)
        check(frame>=3,'Native GBA frame boundaries advance')
        count=ctypes.c_size_t();rate=ctypes.c_uint32();audio=native.ascendant_pinball_audio(handle,ctypes.byref(count),ctypes.byref(rate))
        check(bool(audio)and 0<count.value<=8192 and rate.value>=8000 and any(audio[i]!=0 for i in range(count.value)),'Native GBA audio produces non-silent PCM for a self-authored beep')
        check(native.ascendant_pinball_state(handle,str(state).encode(),0)==1,'Native Pinball snapshot writes through a Unicode path')
        check(native.ascendant_pinball_step(handle,0)==1 and native.ascendant_pinball_frame(handle)>frame,'Synthetic guest advances after the snapshot')
        check(native.ascendant_pinball_state(handle,str(state).encode(),1)==1 and native.ascendant_pinball_frame(handle)==frame,'Native snapshot restores the exact synthetic frame')
        check(native.ascendant_pinball_state(handle,str(state).encode(),0)==1,'Native quick states can replace an existing state')
    finally:
        check(native.ascendant_pinball_close(handle)==1,'Native Pinball session closes and commits SRAM')
    check(save.read_bytes()[0]==0x42 and save.stat().st_size==32768,'Native guest SRAM replaces the old file without truncating it')
    check(rom.read_bytes()==body,'The native guest input stays byte-identical')

if __name__=='__main__':main()
