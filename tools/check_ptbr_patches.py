#!/usr/bin/env python3
"""Round-trip every bundled delta through the native decoder; no ROM outputs saved."""
from pathlib import Path
import argparse,hashlib,json,subprocess
from qa_storage import qa_source,qa_cache,qa_copy,qa_run

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--luajit',type=Path,required=True)
    ap.add_argument('--rom-dir',type=Path,required=True)
    ap.add_argument('--extra-base',type=Path,action='append',default=[])
    ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args();root=Path(__file__).resolve().parents[1];out=a.out.resolve()
    for p in(root,a.luajit,a.rom_dir,*a.extra_base):qa_source(p.resolve())
    index=root/'assets/language-patches/pt-BR/index.json';recipes=json.loads(index.read_text())['recipes']
    inventory={}
    for p in list(a.rom_dir.iterdir())+a.extra_base:
        if p.is_file()and p.suffix.lower()in('.gb','.gbc','.gba'):inventory[hashlib.sha1(p.read_bytes()).hexdigest()]=p.resolve()
    for r in recipes:qa_source(inventory[r['baseSha1']])
    qa_cache(out);out.mkdir(parents=True,exist_ok=True)
    source=out/'source';qa_copy(source,ephemeral=True);source.mkdir(exist_ok=True)
    (source/'Bps.lua').write_bytes((root/'src/translation/Bps.lua').read_bytes())
    lua=source/'roundtrip.lua'
    lua.write_text("local function read(p)local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b end\nlocal B=assert(loadfile(arg[1]))();io.stdout:write(B.apply(read(arg[2]),read(arg[3]),tonumber(arg[4])))\n")
    runs=[]
    for r in recipes:
        base=inventory[r['baseSha1']];patch=root/r['path'];raw=patch.read_bytes()
        assert len(raw)==r['patchSize']and hashlib.sha256(raw).hexdigest()==r['patchSha256']
        p=qa_run([str(a.luajit.resolve()),str(lua),str(source/'Bps.lua'),str(base),str(patch),str(r['targetSize'])],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=120)
        assert p.returncode==0,p.stderr.decode(errors='replace')
        target=p.stdout
        assert len(target)==r['targetSize']and hashlib.sha1(target).hexdigest()==r['targetSha1']and hashlib.md5(target).hexdigest()==r['targetMd5'],r['path']
        runs.append(dict(game=r['game'],baseSha1=r['baseSha1'],targetSha1=r['targetSha1'],patchSha256=r['patchSha256'],passed=True))
        print('PATCH PASS',r['game'],r['baseSha1'],flush=True)
    receipt=dict(passed=True,runs=runs,indexSha256=hashlib.sha256(index.read_bytes()).hexdigest(),decoderSha256=hashlib.sha256((source/'Bps.lua').read_bytes()).hexdigest())
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

if __name__=='__main__':main()
