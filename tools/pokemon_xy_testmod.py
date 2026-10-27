#!/usr/bin/env python3
"""Build a private, reversible introductory text mod from the user's own dump.

Integration by Roxas2712. No ROM bytes are included in this source.
Container/text layout reference: kwsch/pk3DS, revision
6daaca934ca2284a73ab743bf89c848c57cd9de1, GARCReference.cs / TextFile.cs.
This independently written bounded reader only changes selected text entries.
"""
import argparse
import json
from pathlib import Path
import struct
import hashlib
import zlib

def u16(data, at): return struct.unpack_from('<H', data, at)[0]
def u32(data, at): return struct.unpack_from('<I', data, at)[0]

class RomFS:
    def __init__(self, path):
        self.file=Path(path).open('rb');self.size=self.file.seek(0,2)
        header=self.read(0,512)
        self.base=u32(header,0x120)*512 if header[0x100:0x104]==b'NCSD' else 0
        h=self.read(self.base,512)
        if h[0x100:0x104]!=b'NCCH':raise ValueError('Expected executable NCCH')
        romfs=self.base+u32(h,0x1b0)*512;ivfc=self.read(romfs,0x60)
        if ivfc[:4]!=b'IVFC':raise ValueError('Expected plaintext RomFS')
        block=1<<u32(ivfc,0x4c)
        if block>2**20:raise ValueError('Invalid IVFC block')
        self.level=romfs+((0x60+u32(ivfc,8)+block-1)//block)*block
        h=self.read(self.level,0x28)
        if u32(h,0)!=0x28:raise ValueError('Invalid level-3 header')
        self.dirs=self.read(self.level+u32(h,12),u32(h,16))
        self.files=self.read(self.level+u32(h,28),u32(h,32));self.data=self.level+u32(h,36)
    def read(self,at,n):
        if at<0 or n<0 or n>64*1024**2 or at+n>self.size:raise ValueError('Out-of-bounds ROM read')
        self.file.seek(at);b=self.file.read(n)
        if len(b)!=n:raise ValueError('Truncated ROM')
        return b
    def entries(self):
        pending=[('',0)];visited=set()
        while pending:
            parent,at=pending.pop()
            if at in visited:raise ValueError('Directory cycle')
            visited.add(at);d=self.dirs;first=u32(d,at+12);child=u32(d,at+8)
            file_seen=set()
            while first!=0xffffffff:
                if first in file_seen:raise ValueError('File sibling cycle')
                file_seen.add(first)
                f=self.files;name=f[first+32:first+32+u32(f,first+28)].decode('utf-16le')
                yield parent+name,self.data+struct.unpack_from('<Q',f,first+8)[0],struct.unpack_from('<Q',f,first+16)[0]
                first=u32(f,first+4)
            child_seen=set()
            while child!=0xffffffff:
                if child in child_seen:raise ValueError('Directory sibling cycle')
                child_seen.add(child)
                name=d[child+24:child+24+u32(d,child+20)].decode('utf-16le')
                pending.append((parent+name+'/',child));child=u32(d,child+4)
    def get(self, name):
        for path,at,n in self.entries():
            if path==name:return self.read(at,n)
        raise ValueError('RomFS file missing: '+name)

def garc_members(data):
    if data[:4]!=b'CRAG' or u16(data,10)not in (0x400,0x600):raise ValueError('Unsupported GARC')
    at=u32(data,4);fato=at;at+=u32(data,at+4);fatb=at;data_at=u32(data,16)
    if data[fato:fato+4]!=b'OTAF' or data[fatb:fatb+4]!=b'BTAF':raise ValueError('Invalid GARC tables')
    for i in range(u16(data,fato+8)):
        entry=fatb+12+u32(data,fato+12+i*4);bits=u32(data,entry);entry+=4
        for sub in range(32):
            if bits&(1<<sub):
                start,end,n=struct.unpack_from('<III',data,entry);entry+=12
                if not start<=start+n<=end or data_at+end>len(data):raise ValueError('Invalid GARC range')
                yield i,sub,data_at+start,data[data_at+start:data_at+start+n]

def decompress(data):
    if not data or data[0]not in (0x10,0x11):return data
    kind=data[0];n=int.from_bytes(data[1:4],'little');at=4
    if not n:n=u32(data,4);at=8
    if n>16*1024**2:raise ValueError('Compressed member too large')
    out=bytearray()
    while len(out)<n:
        flags=data[at];at+=1
        for bit in range(7,-1,-1):
            if len(out)>=n:break
            if not flags&(1<<bit):out.append(data[at]);at+=1;continue
            a,b=data[at:at+2];at+=2
            if kind==0x10:count=(a>>4)+3;distance=((a&15)<<8|b)+1
            elif a>>4==0:
                c=data[at];at+=1;count=((a&15)<<4|b>>4)+17;distance=((b&15)<<8|c)+1
            elif a>>4==1:
                c,d=data[at:at+2];at+=2;count=((a&15)<<12|b<<4|c>>4)+273;distance=((c&15)<<8|d)+1
            else:count=(a>>4)+1;distance=((a&15)<<8|b)+1
            if distance>len(out)or len(out)+count>n:raise ValueError('Invalid compressed backreference')
            for _ in range(count):out.append(out[-distance])
    return bytes(out)

def crypt(data, index):
    key=(0x7c89+index*0x2983)&65535;out=bytearray()
    for value, in struct.iter_unpack('<H',data):
        out+=struct.pack('<H',value^key);key=((key<<3)|(key>>13))&65535
    return bytes(out)

def text_lines(data):
    if len(data)<20 or u16(data,0)!=1 or u32(data,8)!=0 or u32(data,12)!=16:return
    if u32(data,4)+16!=len(data)or u32(data,16)!=u32(data,4):return
    for i in range(u16(data,2)):
        at=16+u32(data,20+i*8);n=u16(data,24+i*8)*2
        if at+n>len(data):raise ValueError('Invalid text range')
        clear=crypt(data[at:at+n],i);text=clear.decode('utf-16le',errors='replace').split('\0')[0]
        yield i,at,n,text

def bps_number(n):
    out=bytearray()
    while True:
        low=n&127;n>>=7
        if not n:out.append(low|128);return out
        out.append(low);n-=1

def bps_change(source,offset,replacement):
    return bps_changes(source,[(offset,replacement)])

def bps_changes(source,changes):
    target=bytearray(source)
    for offset,replacement in changes:target[offset:offset+len(replacement)]=replacement
    patch=bytearray(b'BPS1')+bps_number(len(source))+bps_number(len(target))+bps_number(0)
    cursor=0
    for offset,replacement in changes:
        if offset<cursor:raise ValueError('Overlapping changes')
        if offset>cursor:patch+=bps_number(((offset-cursor-1)<<2)|0)
        patch+=bps_number(((len(replacement)-1)<<2)|1)+replacement;cursor=offset+len(replacement)
    if cursor<len(source):patch+=bps_number(((len(source)-cursor-1)<<2)|0)
    patch+=struct.pack('<II',zlib.crc32(source),zlib.crc32(target));patch+=struct.pack('<I',zlib.crc32(patch))
    return bytes(patch),hashlib.sha256(target).hexdigest()

def build(rom,output):
    output=Path(output)
    if output.exists():raise ValueError('Destination already exists; refusing to overwrite')
    fs=RomFS(rom);records=[];pending=[]
    try:
        for path,prefix in [('a/0/7/4','Welcome to the world'),('a/0/7/7','Willkommen in der Welt')]:
            archive=fs.get(path);matches=[]
            for member,sub,base,blob in garc_members(archive):
                if member!=100 or sub:continue
                for line,at,n,text in text_lines(blob)or []:
                    if line==23 and text.startswith(prefix):matches.append((line,base+at,n))
                    if line==24 and text.startswith(('I am Augustine','Mein Name ist Platan')):matches.append((line,base+at,n))
            if len(matches)!=2:raise ValueError('Intro entries are different; no patch created: '+path)
            changes=[]
            for line,offset,n in matches:
                marker='ASCENDANT TESTMOD: AN'+('\nSichtbarer Test von Roxas2712.\x10\x01\ube01'if line==24 else '')
                clear=(marker+'\0').encode('utf-16le')
                if len(clear)>n:raise ValueError('Marker exceeds existing text capacity')
                changes.append((offset,crypt(clear+b'\0'*(n-len(clear)),line)))
            patch,target_sha=bps_changes(archive,changes);pending.append((Path('romfs_ext')/(path+'.bps'),patch))
            records.append(dict(path=path,member=100,lines=[23,24],source_sha256=hashlib.sha256(archive).hexdigest(),target_sha256=target_sha,patch_sha256=hashlib.sha256(patch).hexdigest()))
        output.mkdir(parents=True)
        for relative,patch in pending:
            dest=output/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(patch)
        report=dict(name='Ascendant visible intro test',author='Roxas2712',marker='ASCENDANT TESTMOD: AN',description='Only the professor’s first greeting, English/German. BPS source CRC guards mismatched files. No save/code/battle changes.',records=records)
        (output/'testmod.json').write_text(json.dumps(report,indent=2)+'\n');return report
    finally:fs.file.close()

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path);p.add_argument('--inspect',action='store_true');p.add_argument('--output',type=Path);a=p.parse_args()
    if a.output:print(json.dumps(build(a.rom,a.output),indent=2));return
    if not a.inspect:p.error('Choose --inspect or --output')
    fs=RomFS(a.rom)
    try:
        for path in ['a/0/7/4','a/0/7/7','a/0/8/2','a/0/8/5']:
            archive=fs.get(path);print(path,len(archive))
            for member,sub,base,blob in garc_members(archive):
                if member!=100:continue
                unpacked=decompress(blob)
                for line,at,n,text in text_lines(unpacked)or []:
                    if any(w in text.casefold()for w in ['welcome to the world','willkommen','pokémon-professor','professor sycamore']):
                        print(json.dumps(dict(path=path,member=member,sub=sub,line=line,compressed=blob!=unpacked,offset=base+at,capacity=n,text=text[:180]),ensure_ascii=False))
    finally:fs.file.close()
if __name__=='__main__':main()
