#!/usr/bin/env python3
"""Private original-cartridge routine probes, requiring an explicit TCG_QA build and matching pret symbols. By Roxas2712."""
import argparse,atexit,ctypes as C,hashlib,json,subprocess,sys
from pathlib import Path
from qualify_tcg import png
ROOT=Path(__file__).resolve().parents[1]
def worker(a):
 lib=C.CDLL(str(a.library));ptr=C.c_void_p
 signatures={'open':(ptr,[C.c_char_p,C.c_int]),'close':(None,[ptr]),'step':(C.c_int,[ptr,C.c_uint8,C.c_uint8,C.c_uint8,C.c_uint8]),'picture':(ptr,[ptr,C.c_int]),'ram':(C.c_int,[ptr,C.c_int,ptr,C.c_size_t,C.c_int]),'memory':(C.c_int,[ptr,C.c_int,C.c_int,C.c_uint32,ptr,C.c_size_t,C.c_int]),'counter':(C.c_uint64,[ptr,C.c_int,C.c_int]),'error':(C.c_char_p,[]),'digest':(None,[ptr,ptr]),'qa_call':(C.c_int,[ptr,C.c_int,C.c_int,C.c_int,C.c_int]),'qa_write':(C.c_int,[ptr,C.c_int,C.c_uint16,ptr,C.c_size_t]),'qa_reg':(C.c_uint32,[ptr,C.c_int,C.c_int])}
 for key,(ret,params)in signatures.items():fn=getattr(lib,'tcg_gbc_'+key);fn.restype=ret;fn.argtypes=params
 symbols={}
 for line in a.symbols.read_text().splitlines():
  if line.startswith(';')or not line.strip():continue
  parts=line.split()
  if len(parts)==2 and ':'in parts[0]:bank,address=parts[0].split(':');symbols[parts[1]]=(int(bank,16),int(address,16))
 rom=a.rom.read_bytes();assert hashlib.sha1(rom).hexdigest()=='0f8670a583255cff3e5b7ca71b5d7454d928fc48'
 mirrors={}
 def make():
  h=lib.tcg_gbc_open(str(a.rom).encode(),2);assert h,lib.tcg_gbc_error()
  other=lib.tcg_gbc_open(str(a.rom).encode(),2);assert other;mirrors[h]=other
  for frame in range(900):
   b=247 if 360<=frame<365 else 254 if frame>=600 and frame%60<6 else 255
   for live in(h,other):assert lib.tcg_gbc_step(live,255,b,255,b),lib.tcg_gbc_error()
  return h
 def close(h):lib.tcg_gbc_close(mirrors.pop(h));lib.tcg_gbc_close(h)
 def load_ram(h,seat,data):
  for live in(h,mirrors[h]):assert lib.tcg_gbc_ram(live,seat,data,len(data),1)
 def step(h,*buttons):
  for live in(h,mirrors[h]):assert lib.tcg_gbc_step(live,*buttons),lib.tcg_gbc_error()
  hashes=[]
  for live in(h,mirrors[h]):
   out=C.create_string_buffer(65);lib.tcg_gbc_digest(live,out);hashes.append(out.value)
  assert hashes[0]==hashes[1],'Independent link sessions diverged'
  return True
 def write(h,seat,address,data):
  for live in(h,mirrors[h]):assert lib.tcg_gbc_qa_write(live,seat,address,data,len(data))
 def read(h,seat,region,offset,n):
  result=[]
  for start in range(0,n,4096):
   count=min(4096,n-start);b=C.create_string_buffer(count);assert lib.tcg_gbc_memory(h,seat,region,offset+start,b,count,0);result.append(b.raw)
  return b''.join(result)
 def call(h,seat,label,reg_a=0):
  bank,pc=symbols[label]
  for live in(h,mirrors[h]):assert lib.tcg_gbc_qa_call(live,seat,bank,pc,reg_a)
 def state(h):return[{'pc':hex(lib.tcg_gbc_qa_reg(h,i,5)),'bank':lib.tcg_gbc_qa_reg(h,i,6),'af':hex(lib.tcg_gbc_qa_reg(h,i,0)),'done':bool(lib.tcg_gbc_qa_reg(h,i,7))}for i in(0,1)]
 results={}
 h=make()
 try:
  cards=bytes([0x30,0x60,0xc9]);collection=bytearray([0x80]*256)
  for card in cards:collection[card]=2
  for seat,name in [(0,b'ALPHA'),(1,b'BETA')]:
   ram=bytearray(read(h,seat,1,0,32768));ram[0x10:0x20]=(b'\x06'+name+b'\0'*16)[:16]
   ram[0x100:0x200]=collection if seat==0 else bytes([0x80]*256)
   data=bytes(ram);load_ram(h,seat,data)
  write(h,0,symbols['wCurDeckCards'][1],cards+b'\0')
  call(h,0,'GiftCenter_SendCard.asm_af6b');call(h,1,'GiftCenter_ReceiveCard')
  transferred=False
  for frame in range(a.frames):
   # Original sender requests transfer while A is held. Receiver exits its
   # received-card display only after the real collection changes.
   receiver=read(h,1,1,0x100,256);transferred=all(receiver[c]==1 for c in cards)
   step(h,255,254,255,253 if transferred else 255)
   if transferred and all(lib.tcg_gbc_qa_reg(h,i,7)for i in(0,1)):break
  sender=read(h,0,1,0x100,256);receiver=read(h,1,1,0x100,256)
  results['gift']={'frames':frame+1,'sender_counts':[sender[c]for c in cards],'receiver_counts':[receiver[c]for c in cards],'ir_transitions':lib.tcg_gbc_counter(h,0,4),'state':state(h)}
  png(a.output/'gift-sender.png',C.string_at(lib.tcg_gbc_picture(h,0),160*144*4));png(a.output/'gift-receiver.png',C.string_at(lib.tcg_gbc_picture(h,1),160*144*4))
  assert transferred and all(sender[c]==1 for c in cards),'Original Gift Center did not transfer the selected cards: '+repr(results['gift'])
  (a.output/'gift.json').write_text(json.dumps(results['gift'],indent=2)+'\n')
 finally:close(h)
 h=make()
 try:
  bank,addr=symbols['CharmanderAndFriendsDeck'];pos=bank*0x4000+addr-0x4000;deck=[]
  while rom[pos]:count,card=rom[pos:pos+2];deck.extend([card]*count);pos+=2
  assert len(deck)==60
  for seat,name in [(0,b'ALPHA'),(1,b'BETA')]:
   ram=bytearray(read(h,seat,1,0,32768));ram[0x10:0x20]=(b'\x06'+name+b'\0'*16)[:16];ram[0x218:0x254]=bytes(deck);ram[0x1700]=0
   data=bytes(ram);load_ram(h,seat,data);call(h,seat,'_SetUpAndStartLinkDuel')
  for frame in range(a.frames):
   roles=[read(h,i,0,symbols['wSerialOp'][1]-0xc000,1)[0]for i in(0,1)]
   b0=247 if roles==[0,0]and frame%60<5 else 254 if roles!=[0,0]and frame%30<6 else 255
   b1=254 if roles!=[0,0]and frame%30<6 else 255
   step(h,255,b0,255,b1)
  peers=[read(h,i,0,symbols['wOpponentDeck'][1]-0xc000,60)==bytes(deck)for i in(0,1)]
  serial=[read(h,i,0,symbols['wSerialOp'][1]-0xc000,1)[0]for i in(0,1)]
  dueltype=[read(h,i,0,symbols['wDuelType'][1]-0xc000,1)[0]for i in(0,1)]
  results['duel']={'opponent_decks_exchanged':peers,'serial_roles':serial,'duel_types':dueltype,'serial_transfers':lib.tcg_gbc_counter(h,0,3),'state':state(h)}
  for i in(0,1):png(a.output/('link-duel-'+str(i)+'.png'),C.string_at(lib.tcg_gbc_picture(h,i),160*144*4))
  assert all(peers)and sorted(serial)==[0x12,0x29],'Original link duel setup did not exchange decks: '+repr(results['duel'])
 finally:close(h)
 results.update(passed=True,independent_link_determinism=True,player_saves_opened=False,scope='Original Gift Center routines and link-duel setup in isolated native contexts; full adventure and completed Internet duel not covered')
 (a.output/'link.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results))
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in('library','rom','symbols'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--frames',type=int,default=1800);p.add_argument('--output',type=Path,default=ROOT/'.local/qa/tcg-link');p.add_argument('--worker',action='store_true');p.add_argument('--min-free-gib',type=float,default=20);a=p.parse_args()
 if a.worker:return worker(a)
 sys.path.insert(0,str(Path.home()/'.local/lib/origami-qa-storage/active-tools'));import qa_storage as q
 q._storage=q.Storage(ROOT);atexit.register(q._storage.close,collect=False);assert a.min_free_gib>=2;q._storage.min_free=a.min_free_gib*1024**3
 for path in(ROOT,a.library,a.rom,a.symbols,Path(sys.executable)):q.qa_source(path.resolve())
 q.qa_cache(a.output);a.output.mkdir(parents=True,exist_ok=True)
 command=[sys.executable,__file__,'--worker','--library',str(a.library.resolve()),'--rom',str(a.rom),'--symbols',str(a.symbols),'--frames',str(a.frames),'--output',str(a.output)]
 with(a.output/'link.log').open('w')as log:r=q.qa_run(command,cwd=ROOT,stdout=log,stderr=log,timeout=120)
 print((a.output/'link.log').read_text()[-9000:]);assert r.returncode==0,'Original link qualification failed'
if __name__=='__main__':main()
