#!/usr/bin/env python3
"""Private TCG build and network qualification, by Roxas2712. Never opens player saves."""
import argparse,atexit,ctypes as C,hashlib,json,os,struct,subprocess,sys,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def png(path,rgba):
 def chunk(k,s):return struct.pack('>I',len(s))+k+s+struct.pack('>I',zlib.crc32(k+s)&0xffffffff)
 pixels=b''.join(b'\0'+rgba[y*640:(y+1)*640]for y in range(144))
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',160,144,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b''))
def native(args):
 lib=C.CDLL(str(args.library));ptr=C.c_void_p
 signatures={'open':(ptr,[C.c_char_p,C.c_int]),'close':(None,[ptr]),'step':(C.c_int,[ptr,C.c_uint8,C.c_uint8,C.c_uint8,C.c_uint8]),'picture':(ptr,[ptr,C.c_int]),'ram':(C.c_int,[ptr,C.c_int,ptr,C.c_size_t,C.c_int]),'audio':(ptr,[ptr,C.c_int,C.POINTER(C.c_size_t)]),'counter':(C.c_uint64,[ptr,C.c_int,C.c_int]),'digest':(None,[ptr,ptr]),'memory':(C.c_int,[ptr,C.c_int,C.c_int,C.c_uint32,ptr,C.c_size_t,C.c_int]),'error':(C.c_char_p,[])}
 for key,(ret,params)in signatures.items():
  fn=getattr(lib,'tcg_gbc_'+key);fn.restype=ret;fn.argtypes=params
 assert not lib.tcg_gbc_open(b'/nonexistent/tcg.gbc',1)
 handles=[];start=time.perf_counter();report={'player_saves_opened':False,'boot':'HLE','frames':args.frames}
 try:
  for seats in (1,2,2):
   h=lib.tcg_gbc_open(str(args.rom).encode(),seats);assert h,lib.tcg_gbc_error();handles.append(h)
  audio_frames=0;audible=False;snapshots={}
  for frame in range(args.frames):
   b=247 if 360<=frame<365 or 600<=frame<605 else 254 if frame>=720 and frame%60<6 else 255
   for i,h in enumerate(handles):
    assert lib.tcg_gbc_step(h,255,b,255,255),lib.tcg_gbc_error()
    if i==0:
     n=C.c_size_t();pcm=lib.tcg_gbc_audio(h,0,C.byref(n));audio_frames+=n.value
     if n.value:audible=audible or any(C.string_at(pcm,n.value*4))
   a=C.create_string_buffer(65);bhash=C.create_string_buffer(65)
   lib.tcg_gbc_digest(handles[1],a);lib.tcg_gbc_digest(handles[2],bhash);assert a.value==bhash.value,'Paired sessions diverged'
   if frame in {179,359,599,719,899,args.frames-1}:
    rgba=C.string_at(lib.tcg_gbc_picture(handles[0],0),160*144*4);name='solo-'+str(frame+1)+'.png';png(args.output/name,rgba);snapshots[name]=len(set(rgba[i:i+4]for i in range(0,len(rgba),4)))
    png(args.output/('paired-'+str(frame+1)+'.png'),C.string_at(lib.tcg_gbc_picture(handles[1],0),160*144*4))
  ram=(C.c_uint8*32768)();again=(C.c_uint8*32768)()
  assert lib.tcg_gbc_ram(handles[0],0,ram,32768,0);ram[0x123]^=0x5a
  assert lib.tcg_gbc_ram(handles[0],0,ram,32768,1);assert lib.tcg_gbc_ram(handles[0],0,again,32768,0);assert bytes(ram)==bytes(again)
  assert not lib.tcg_gbc_ram(handles[0],0,ram,32767,1)
  byte=(C.c_uint8*1)(42)
  assert lib.tcg_gbc_memory(handles[0],0,0,32767,byte,1,1)
  assert not lib.tcg_gbc_memory(handles[0],0,0,32768,byte,1,1)
  assert not lib.tcg_gbc_memory(handles[1],0,0,0,byte,1,1),'Native host must deny writes in online pairs'
  before=C.create_string_buffer(65);after=C.create_string_buffer(65);lib.tcg_gbc_digest(handles[1],before)
  assert lib.tcg_gbc_memory(handles[1],0,3,0,byte,1,0)
  lib.tcg_gbc_digest(handles[1],after);assert before.value==after.value,'Mod reads must not advance or mutate a device'
  assert audio_frames>0 and audible and max(snapshots.values())>8
  report.update(passed=True,paired_determinism=True,audio_frames=audio_frames,audible=audible,snapshots=snapshots,elapsed_seconds=time.perf_counter()-start,interpreter_instructions=lib.tcg_gbc_counter(handles[0],0,1),fallbacks=lib.tcg_gbc_counter(handles[0],0,2),battery_roundtrip=True,mod_memory_guards=True)
  (args.output/'native.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
 finally:
  for h in handles:lib.tcg_gbc_close(h)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--library',type=Path);p.add_argument('--rom',type=Path);p.add_argument('--love',type=Path);p.add_argument('--lua',type=Path);p.add_argument('--frames',type=int,default=1200);p.add_argument('--output',type=Path,default=ROOT/'.local/qa/tcg-qualification');p.add_argument('--worker',action='store_true');p.add_argument('--min-free-gib',type=float,default=20);a=p.parse_args()
 if a.worker:return native(a)
 sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'));import qa_storage as q
 q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False)
 if a.min_free_gib<2:p.error('Keep at least 2 GiB free')
 q._storage.min_free=a.min_free_gib*1024**3
 for path in (ROOT,a.library,a.rom,a.love,a.lua,Path(sys.executable)):
  if path:q.qa_source(path.resolve())
 q.qa_cache(a.output);a.output.mkdir(parents=True,exist_ok=True)
 if a.lua or a.love:
  suites=list(('tcg_net_test','tcg_launcher_test','tcg_mods_test','tcg_socket_test')if a.love else ('tcg_net_test','tcg_launcher_test','tcg_mods_test'))
  if a.love and a.library:suites.append('tcg_native_network_test')
  for name in suites:
   command=[str(a.lua),str(ROOT/'tests'/(name+'.lua'))]
   if a.love:
    identity='oasc-tcg-qa-'+name;profile=Path.home()/'Library/Application Support/LOVE'/identity;q.qa_source(profile);q.qa_profile(profile)
    host=ROOT/'.local/engine-parity'/name;q.qa_copy(host,ephemeral=True);host.mkdir(parents=True,exist_ok=True)
    for item in ('src','tests'):
     if not(host/item).exists():(host/item).symlink_to(ROOT/item,target_is_directory=True)
    (host/'conf.lua').write_text('function love.conf(t)t.identity='+repr(identity)+';t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.physics=false end')
    (host/'main.lua').write_text('local runtime=love\nfunction love.load()local ok,why=pcall(function()assert(loadfile('+repr('tests/'+name+'.lua')+'))()end);love=runtime;if not ok then print(why)end;runtime.event.quit(ok and 0 or 1)end')
    command=[str(a.love),str(host)]
   with(a.output/(name+'.log')).open('w')as log:
    env=dict(os.environ)
    if a.library:env.update(TCG_QA_LIBRARY=str(a.library.resolve()),TCG_QA_ROM=str(a.rom.resolve()))
    r=q.qa_run(command,cwd=ROOT,env=env,stdout=log,stderr=log,timeout=60)
   print((a.output/(name+'.log')).read_text());assert r.returncode==0,name
 if a.library:
  assert a.rom,'--rom required with --library'
  command=[sys.executable,__file__,'--worker','--library',str(a.library),'--rom',str(a.rom),'--frames',str(a.frames),'--output',str(a.output)]
  with(a.output/'native.log').open('w')as log:r=q.qa_run(command,cwd=ROOT,stdout=log,stderr=log,timeout=600)
  print((a.output/'native.log').read_text()[-5000:]);assert r.returncode==0,'Native qualification failed'
if __name__=='__main__':main()
