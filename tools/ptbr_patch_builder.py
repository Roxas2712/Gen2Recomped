#!/usr/bin/env python3
"""Build verified BPS deltas from private US and translated input images.

Only deltas and digest/provenance metadata go into the distributable bundle.
Never copy the input images into the bundle. No ROM is downloaded by this tool.
"""
from pathlib import Path
import argparse,hashlib,json,struct,zlib

def varint(n):
    out=bytearray()
    while True:
        byte=n&127;n>>=7
        if not n:out.append(byte|128);return bytes(out)
        out.append(byte);n-=1

def bps(source,target):
    out=bytearray(b'BPS1'+varint(len(source))+varint(len(target))+varint(0))
    # Reuse moved original spans, especially across FRLG revisions and the
    # shared Ruby/Sapphire translation. This avoids embedding unchanged game
    # resources merely because their byte offsets moved between versions.
    index={}
    for offset in range(0,len(source)-15,16):
        key=source[offset:offset+12]
        bucket=index.setdefault(key,[])
        if len(bucket)<4:bucket.append(offset)
    def match(at):
        best=(0,0)
        for offset in index.get(target[at:at+12],()):
            length=12;maximum=min(len(source)-offset,len(target)-at)
            while length+1024<=maximum and source[offset+length:offset+length+1024]==target[at+length:at+length+1024]:length+=1024
            while length<maximum and source[offset+length]==target[at+length]:length+=1
            if length>best[1]:best=(offset,length)
        return best if best[1]>=24 else (0,0)
    at=0;sourceAt=0
    while at<len(target):
        start=at
        if at<len(source) and source[at]==target[at]:
            while at<min(len(source),len(target)) and source[at]==target[at]:at+=1
            out+=varint((at-start-1)<<2)
        else:
            offset,length=match(at)
            if length:
                delta=offset-sourceAt
                out+=varint(((length-1)<<2)|2)+varint((abs(delta)<<1)|(delta<0))
                sourceAt=offset+length;at+=length;continue
            while at<len(target):
                if at<len(source) and source[at:at+8]==target[at:at+8] and at+8<=len(source):break
                if match(at)[1]:break
                at+=1
            out+=varint(((at-start-1)<<2)|1)+target[start:at]
    out+=struct.pack('<II',zlib.crc32(source),zlib.crc32(target))
    out+=struct.pack('<I',zlib.crc32(out))
    return bytes(out)

def apply_ips(source,patch):
    assert patch[:5]==b'PATCH','Not an IPS patch'
    out=bytearray(source);at=5
    while patch[at:at+3]!=b'EOF':
        assert at+5<=len(patch),'Truncated IPS record'
        offset=int.from_bytes(patch[at:at+3],'big');size=int.from_bytes(patch[at+3:at+5],'big');at+=5
        if size:
            data=patch[at:at+size];assert len(data)==size;at+=size
        else:
            assert at+3<=len(patch);length=int.from_bytes(patch[at:at+2],'big');data=bytes([patch[at+2]])*length;at+=3
        end=offset+len(data);assert end<=32*1024*1024
        if end>len(out):out+=bytes(end-len(out))
        out[offset:end]=data
    at+=3
    if at<len(patch):
        assert len(patch)-at==3;length=int.from_bytes(patch[at:],'big');assert length<=32*1024*1024
        if length>len(out):out+=bytes(length-len(out))
        else:del out[length:]
    return bytes(out)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--inputs',type=Path,required=True,help='Private JSON list of {game,base,target,expectedBaseSha1,expectedTargetSha1,provenance}')
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args();root=Path(__file__).resolve().parents[1]
    from qa_storage import qa_source
    qa_source(root);qa_source(a.inputs)
    entries=json.loads(a.inputs.read_text())
    for row in entries:
        qa_source(Path(row['base']));qa_source(Path(row['target']))
    output=a.output.resolve();assert output==root/'assets/language-patches/pt-BR','Bundle destination must be the production patch directory'
    output.mkdir(parents=True,exist_ok=True);recipes=[]
    for row in entries:
        game=row['game'];assert game in ('red','blue','yellow','gold','silver','crystal','ruby','sapphire','emerald','firered','leafgreen')
        source=Path(row['base']).read_bytes();target=Path(row['target']).read_bytes()
        sourceSha=hashlib.sha1(source).hexdigest();targetSha=hashlib.sha1(target).hexdigest()
        assert sourceSha==row['expectedBaseSha1'] and targetSha==row['expectedTargetSha1'],'Private input identity mismatch'
        patch=bps(source,target);name=game+'-'+sourceSha[:12]+'.bps'
        assert len(patch)<len(target)*0.8,'Delta unexpectedly contains most of the target image; review the source pairing'
        (output/name).write_bytes(patch)
        recipes.append(dict(game=game,path='assets/language-patches/pt-BR/'+name,patchSha256=hashlib.sha256(patch).hexdigest(),patchSize=len(patch),
            baseSha1=sourceSha,baseMd5=hashlib.md5(source).hexdigest(),baseSize=len(source),baseImportId=row.get('baseImportId',game+'_en'),
            targetSha1=targetSha,targetMd5=hashlib.md5(target).hexdigest(),targetSize=len(target),sourceId=('ruby'if game=='sapphire'else game)+'_ptbr',provenance=row['provenance']))
        print(game,len(patch),sourceSha,targetSha,flush=True)
    assert {r['game']for r in recipes}=={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','emerald','firered','leafgreen'},'Every supported edition needs a patch'
    (output/'index.json').write_text(json.dumps(dict(format='native-ptbr-bps-v1',recipes=recipes),ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
