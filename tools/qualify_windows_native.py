#!/usr/bin/env python3
"""Real Windows native ABI/toolchain checks; synthetic inputs, no player ROMs."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse,ctypes,hashlib,json,os,platform,struct,sys
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
        report['passed']=True
    finally:
        out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
