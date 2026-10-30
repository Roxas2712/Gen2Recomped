#!/usr/bin/env python3
"""Isolated cartridge smoke test; no player saves are opened. By Roxas2712."""
import argparse
import atexit
import ctypes as C
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zlib

ROOT=Path(__file__).resolve().parents[1]

def png(path,rgba,width=160,height=144):
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    pixels=b''.join(b'\0'+rgba[y*width*4:(y+1)*width*4]for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))

def worker(args):
    lib=C.CDLL(str(args.library));ptr=C.c_void_p
    lib.pinball_gbc_open.argtypes=[C.c_char_p];lib.pinball_gbc_open.restype=ptr
    lib.pinball_gbc_error.restype=C.c_char_p
    lib.pinball_gbc_step.argtypes=[ptr,C.c_uint8,C.c_uint8]
    lib.pinball_gbc_picture.argtypes=[ptr];lib.pinball_gbc_picture.restype=ptr
    lib.pinball_gbc_audio.argtypes=[ptr,C.POINTER(C.c_size_t)];lib.pinball_gbc_audio.restype=ptr
    lib.pinball_gbc_counter.argtypes=[ptr,C.c_int];lib.pinball_gbc_counter.restype=C.c_uint64
    lib.pinball_gbc_ram.argtypes=[ptr,ptr,C.c_size_t,C.c_int]
    lib.pinball_gbc_close.argtypes=[ptr]
    lib.ascendant_pinball_step.argtypes=[ptr,C.c_uint16]
    lib.ascendant_pinball_view.argtypes=[ptr,C.c_int]
    lib.ascendant_pinball_picture.argtypes=[ptr,C.POINTER(C.c_uint32),C.POINTER(C.c_uint32)];lib.ascendant_pinball_picture.restype=ptr
    lib.ascendant_pinball_checkpoint.argtypes=[ptr];lib.ascendant_pinball_checkpoint.restype=C.c_char_p
    lib.ascendant_pinball_state.argtypes=[ptr,C.c_char_p,C.c_int]
    lib.ascendant_pinball_read.argtypes=[ptr,C.c_uint32,C.c_uint32];lib.ascendant_pinball_read.restype=C.c_uint32
    assert not lib.pinball_gbc_open(b'/nonexistent/pinball.gbc'),'Missing ROM must be rejected'
    ctx=lib.pinball_gbc_open(str(args.rom).encode())
    assert ctx,lib.pinball_gbc_error()
    baseline=lib.pinball_gbc_open(str(args.rom).encode())if args.full_table else None
    if args.full_table:assert lib.ascendant_pinball_view(ctx,1)
    transitions=[];transition_failures=[];previous_board=None;previous_transition=None;pending_stage=False;capture_until=-1
    snapshots={};states=[];expanded_seen=False;fixed_frames=0;pcm_frames=0;audible=False;start=time.perf_counter()
    try:
        for frame in range(args.frames):
            # Advance intro, title, field selection and launch; then operate
            # both flippers. Samples remain in the isolated native context.
            dpad,buttons=255,255
            if frame in range(360,365)or frame in range(600,605):buttons&=~8
            if frame in range(720,725)or frame in range(900,905):buttons&=~1
            if args.field=='blue'and frame in range(840,845):dpad&=~1
            if frame>=1000:
                if frame%30<15:buttons&=~1
                else:dpad&=~2
            if args.full_table:
                assert lib.ascendant_pinball_step(ctx,((~dpad&15)<<4)|(~buttons&15)),lib.pinball_gbc_error()
                assert lib.pinball_gbc_step(baseline,dpad,buttons)
                if frame%60==0:assert lib.ascendant_pinball_checkpoint(ctx)==lib.ascendant_pinball_checkpoint(baseline),'Presentation changed the canonical guest'
            else:assert lib.pinball_gbc_step(ctx,dpad,buttons),lib.pinball_gbc_error()
            if args.full_table:
                width,height=C.c_uint32(),C.c_uint32();lib.ascendant_pinball_picture(ctx,C.byref(width),C.byref(height))
                main=lib.ascendant_pinball_read(ctx,0xd8f1,1);stage=lib.ascendant_pinball_read(ctx,0xd4ac,1)
                standard=main==4 and stage<=5 and not(stage&2)
                if not standard:expanded_seen=False;previous_board=None;previous_transition=None;pending_stage=False
                if standard and width.value==192:expanded_seen=True
                if standard and expanded_seen:
                    assert (width.value,height.value)==(192,285),'Standard-field sequence must not zoom back into the half table'
                    fixed_frames+=1
                if args.transitions and standard and expanded_seen:
                    read=lambda a:lib.ascendant_pinball_read(ctx,a,1)
                    signature=(stage,read(0xffa3),read(0xff40)&128,read(0xd8f2))
                    picture=lib.ascendant_pinball_picture(ctx,C.byref(width),C.byref(height))
                    rgba=C.string_at(picture,width.value*height.value*4)
                    board=hashlib.sha256(rgba[:192*272*4]).hexdigest()
                    if previous_transition is not None and signature!=previous_transition:
                        transitions.append({'frame':frame+1,'from':previous_transition,'to':signature})
                        capture_until=frame+3
                    if previous_transition and signature[0]!=previous_transition[0]:pending_stage=True
                    if signature[1]and signature[2]:pending_stage=False
                    if pending_stage and signature[1]==0 and previous_board and read(0xffa6)>=134 and board!=previous_board:
                        transition_failures.append({'frame':frame+1,'stage':stage,'signature':signature,'reason':'Board pixels changed while cartridge graphics were loading'})
                        capture_until=frame+3
                    if frame<=capture_until:
                        png(args.output/('transition-'+str(frame+1)+'.png'),rgba,width.value,height.value)
                        original=C.string_at(lib.pinball_gbc_picture(ctx),160*144*4)
                        png(args.output/('transition-original-'+str(frame+1)+'.png'),original)
                    previous_board=board;previous_transition=signature
            count=C.c_size_t();samples=lib.pinball_gbc_audio(ctx,C.byref(count));pcm_frames+=count.value
            if count.value:audible=audible or any(C.string_at(samples,count.value*4))
            if frame%300==299:
                read=lambda a:lib.ascendant_pinball_read(ctx,a,1)
                states.append({'frame':frame+1,'screen':read(0xd8f1),'sub':read(0xd8f2),'stage':read(0xd4ac),'launched':read(0xd4de),'keys':read(0xd948),'score':[read(0xd46a+i)for i in range(6)]})
            if frame in {179,359,599,719,899,1199,1499,1799,2399,2999,args.frames-1}:
                width,height=C.c_uint32(),C.c_uint32()
                picture=lib.ascendant_pinball_picture(ctx,C.byref(width),C.byref(height))
                rgba=C.string_at(picture,width.value*height.value*4)
                filename='frame-'+str(frame+1)+'.png';png(args.output/filename,rgba,width.value,height.value)
                snapshots[filename]={'width':width.value,'height':height.value,'sha256':hashlib.sha256(rgba).hexdigest(),'colors':len(set(rgba[i:i+4]for i in range(0,len(rgba),4)))}
                if args.full_table and width.value==192:
                    original=C.string_at(lib.pinball_gbc_picture(ctx),160*144*4)
                    png(args.output/('original-'+filename),original)
                    read=lambda a:lib.ascendant_pinball_read(ctx,a,1)
                    stage=read(0xd4ac);sx=read(0xff43);sy=read(0xff42)
                    sx=sx if sx<128 else sx-256;sy=sy if sy<128 else sy-256
                    matched=total=0
                    for y in range(120):
                        wy=(stage%2)*136+y+sy
                        for x in range(160):
                            wx=x+sx
                            if not 0<=wx<192 or not 0<=y+sy<136:continue
                            total+=1
                            matched+=original[(y*160+x)*4:(y*160+x+1)*4]==rgba[(wy*192+wx)*4:(wy*192+wx+1)*4]
                    snapshots[filename].update(stage=stage,scroll=[sx,sy],viewport_matching_pixels=matched,viewport_pixels=total)

        checkpoint=lib.ascendant_pinball_checkpoint(ctx)
        state=str(args.output/'quick.state').encode()
        assert lib.ascendant_pinball_state(ctx,state,0)
        for _ in range(12):assert lib.pinball_gbc_step(ctx,255,255)
        assert lib.ascendant_pinball_state(ctx,state,1)
        assert lib.ascendant_pinball_checkpoint(ctx)==checkpoint,'Quick state must restore guest memory'
        # 8-KiB battery RAM is isolated, size-checked and round-trips bytewise.
        ram=(C.c_uint8*8192)();assert lib.pinball_gbc_ram(ctx,ram,8192,0)
        ram[123]^=0x5a;assert lib.pinball_gbc_ram(ctx,ram,8192,1)
        again=(C.c_uint8*8192)();assert lib.pinball_gbc_ram(ctx,again,8192,0)
        assert bytes(ram)==bytes(again)
        assert not lib.pinball_gbc_ram(ctx,again,8191,1)
        report={'library_sha256':hashlib.sha256(args.library.read_bytes()).hexdigest(),'field':args.field,'requested_frames':args.frames,'guest_frames':lib.pinball_gbc_counter(ctx,0),
            'elapsed_seconds':time.perf_counter()-start,'interpreter_instructions':lib.pinball_gbc_counter(ctx,1),
            'dispatch_fallbacks':lib.pinball_gbc_counter(ctx,2),'interpreter_cycles':lib.pinball_gbc_counter(ctx,3),
            'cpu_cycles':lib.pinball_gbc_counter(ctx,4),'pcm_frames':pcm_frames,'audible':audible,
            'transitions':transitions,'transition_pixel_failures':transition_failures,'fixed_full_table_frames':fixed_frames,'states':states,'snapshots':snapshots,'full_table':args.full_table,'presentation_isolation':bool(baseline),'composition_failures':lib.pinball_gbc_counter(ctx,6),'transition_holds':lib.pinball_gbc_counter(ctx,7),'failure_holds':lib.pinball_gbc_counter(ctx,8),
            'quick_state_roundtrip':True,'battery_roundtrip':True,'player_saves_opened':False,'boot':'HLE'}
        assert pcm_frames>0 and audible
        assert max(s['colors']for s in snapshots.values())>8,'Expected color graphics'
        if args.full_table:
            assert any(s['width']==192 and s['height']==285 for s in snapshots.values()),'Full-table composition must activate'
            assert report['composition_failures']==0,'Scratch graphics routine failed'
        report['passed']=not transition_failures
        (args.output/'result.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report))
        assert not transition_failures,'Full-table pixels must remain complete throughout stage graphics loading'
    finally:
        lib.pinball_gbc_close(ctx)
        if baseline:lib.pinball_gbc_close(baseline)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--library',type=Path,required=True);p.add_argument('--rom',type=Path,required=True)
    p.add_argument('--frames',type=int,default=1800);p.add_argument('--output',type=Path,default=ROOT/'.local/qa/pinball-gbc/qualification')
    p.add_argument('--field',choices=['red','blue'],default='red')
    p.add_argument('--full-table',action='store_true')
    p.add_argument('--transitions',action='store_true',help='Check pixels and capture stage graphics-loading boundaries')
    p.add_argument('--worker',action='store_true');args=p.parse_args()
    if args.worker:return worker(args)
    sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'))
    import qa_storage as q
    q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
    for path in [ROOT,args.library,args.rom,Path(sys.executable)]:q.qa_source(path)
    q.qa_cache(args.output);args.output.mkdir(parents=True,exist_ok=True)
    with(args.output/'run.log').open('w')as log:
        result=q.qa_run([sys.executable,str(Path(__file__).resolve()),*sys.argv[1:],'--worker'],cwd=args.output,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise SystemExit('GBC smoke test failed: '+str(args.output/'run.log'))
    print((args.output/'result.json').read_text())

if __name__=='__main__':main()
