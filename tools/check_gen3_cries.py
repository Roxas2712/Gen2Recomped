#!/usr/bin/env python3
"""Check owned retail cries against an independent STRB/ARM decoder. No assets in report."""
import argparse,hashlib,json,struct,subprocess
from pathlib import Path
from datetime import datetime,timezone
from qa_storage import qa_source,qa_cache,qa_run

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rom',type=Path,required=True);p.add_argument('--luajit',type=Path,required=True);p.add_argument('--original-sample',type=Path);p.add_argument('--report',type=Path);a=p.parse_args()
 qa_source(a.rom);qa_source(a.luajit)
 if a.original_sample:qa_source(a.original_sample)
 b=a.rom.read_bytes();rows=[];table=None;start=0
 while True:
  at=b.find(b'\x20\x3c\x00\x00',start)
  if at<0:break
  start=at+1
  if at+388*24>len(b):continue
  if all(b[at+i*12:at+i*12+4]==b'\x20\x3c\x00\x00'and b[at+388*12+i*12:at+388*12+i*12+4]==b'\x30\x3c\x00\x00'and b[at+i*12+4:at+i*12+8]==b[at+388*12+i*12+4:at+388*12+i*12+8]for i in range(388)):
   assert table is None,'Ambiguous cry table';table=at
 assert table is not None,'No full mirrored retail cry tables'
 delta=[0,1,4,9,16,25,36,49,-64,-49,-36,-25,-16,-9,-4,-1];oracle=bytearray(struct.pack('<I',388));overflows=0;affected=0;old_mismatch=0;past=0
 for i in range(388):
  wav=struct.unpack_from('<I',b,table+i*12+4)[0]-0x08000000;typ,flags,freq,loop,size=struct.unpack_from('<HHIII',b,wav);assert typ==1 and 0<size<4*1024*1024
  pcm=bytearray();sat=bytearray();wrap_events=0
  for block in range((size+63)//64):
   offset=wav+16+block*33;acc=b[offset];signed=acc if acc<128 else acc-256;values=[acc];clamped=[acc]
   nibbles=[b[offset+1]&15]+[n for byte in b[offset+2:offset+33]for n in (byte>>4,byte&15)]
   for nib in nibbles:
    signed+=delta[nib]
    if not -128<=signed<=127:wrap_events+=1
    clamped.append(max(-128,min(127,signed))&255)
    acc=(acc+delta[nib])&255;values.append(acc)
   count=min(64,size-len(pcm));pcm.extend(values[:count]);sat.extend(clamped[:count])
  assert len(pcm)==size
  changed=sum(x!=y for x,y in zip(pcm,sat));overflows+=changed;affected+=bool(changed)
  raw=b[wav+16:wav+16+size];wrong=sum(x!=y for x,y in zip(pcm,raw));old_mismatch+=wrong
  past+=max(0,size-33*((size+63)//64))
  rows.append(dict(index=i,samples=size,rate=freq/1024,pcmSHA256=hashlib.sha256(pcm).hexdigest(),saturatingMismatch=changed,oldRawMismatch=wrong))
  oracle.extend(struct.pack('<I',size));oracle.extend(pcm)
 out=qa_cache(Path(__file__).resolve().parents[1]/'.local/qa'/('gen3-cry-cpu-'+datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S%f')));out.mkdir(parents=True)
 expected=out/'expected.pcm';expected.write_bytes(oracle)
 cmd=[str(a.luajit.resolve()),'tests/engine/gen3_cry_pcm.lua',str(a.rom.resolve()),str(table),str(expected)]
 if a.original_sample:cmd.append(str(a.original_sample.resolve()))
 result=qa_run(cmd,cwd=Path(__file__).resolve().parents[1],text=True,capture_output=True,check=True);print(result.stdout,end='')
 report=dict(status='pass',gameCode=b[0xAC:0xB0].decode(),romSHA1=hashlib.sha1(b).hexdigest(),table=table,recordings=len(rows),saturatingAffected=affected,saturatingWrongSamples=overflows,oldRawWrongSamples=old_mismatch,oldReadPastEncodedBytes=past,originalDecoderCompared=bool(a.original_sample),rows=rows)
 text=json.dumps(report,indent=2)+'\n'
 if a.report:a.report.write_text(text)
 print(json.dumps({k:v for k,v in report.items()if k!='rows'},indent=2))
if __name__=='__main__':main()
