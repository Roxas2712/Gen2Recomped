#!/usr/bin/env python3
"""Build an isolated native-engine preview from committed source + pinned LÖVE12 artifacts."""
import argparse,hashlib,io,json,os,plistlib,re,shutil,subprocess,tarfile,tempfile,zipfile
from pathlib import Path,PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
RUNTIME_COMMIT='937eb3b21f973607ab080aa26b7ef2a6b3b2b663'
RUNTIMES={
 'windows':dict(id=12514271124,sha256='1f4c6997bd93502f986f5187d877da84247617eede89d8140bcbf570bd07ea22',inner='love-12.0-win64.zip'),
 'macos':dict(id=12513712494,sha256='f70f60d162eda6931b0b28e2b094b83b741986f0feac08d33a10be7c57e724f8',inner='love-macos.zip')}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def verify_payload(path):
 with zipfile.ZipFile(path)as z:
  for name in z.namelist():
   p=PurePosixPath(name)
   if p.is_absolute()or '..'in p.parts:raise ValueError('unsafe payload path')
   if p.suffix.lower()in ('.gb','.gbc','.gba','.sav','.srm','.bak'):raise ValueError('private ROM/save content')
   if 'generated'in p.parts or 'baseroms'in p.parts or p.name=='rom-cache.complete':raise ValueError('generated game content')
   if name.startswith('mods/')or name in ('options.lua','save.lua','cloud_clients.lua'):raise ValueError('non-preview content')
  for f in ('main.lua','conf.lua','src/preview/main.lua','src/preview/conf.lua','src/core/NativePreview.lua'):
   if f not in z.namelist():raise ValueError('missing preview entry: '+f)
def normalize_zip(path):
 temp=path.with_suffix('.normalized')
 with zipfile.ZipFile(path)as src,zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED,compresslevel=9)as dst:
  for name in sorted(src.namelist()):
   info=zipfile.ZipInfo(name,(2026,1,1,0,0,0));info.create_system=3
   info.external_attr=((0o40755 if name.endswith('/')else 0o100644)<<16)
   info.compress_type=zipfile.ZIP_DEFLATED;dst.writestr(info,src.read(name))
 temp.replace(path)
def unpack_zip(path,dest):
 with zipfile.ZipFile(path)as z:
  for name in z.namelist():
   p=PurePosixPath(name)
   if p.is_absolute()or '..'in p.parts:raise ValueError('unsafe runtime archive')
  z.extractall(dest)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--platform',choices=RUNTIMES,required=True);p.add_argument('--runtime',type=Path,required=True);p.add_argument('--source-ref',required=True);p.add_argument('--release-id',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 if not re.fullmatch(r'[0-9]{8}\.[0-9]+',a.release_id):p.error('release-id must be YYYYMMDD.N')
 runtime=RUNTIMES[a.platform]
 if sha(a.runtime)!=runtime['sha256']:p.error('runtime digest does not match the pinned official artifact')
 ref=subprocess.check_output(['git','rev-parse','--verify','--end-of-options',a.source_ref+'^{commit}'],cwd=ROOT,text=True).strip()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);identity='Gen2Recomp-NativePreview-'+a.release_id.replace('.','-')
 with tempfile.TemporaryDirectory(prefix='native-preview-')as temp:
  work=Path(temp);source=work/'source';source.mkdir()
  paths=['main.lua','conf.lua','src','assets','data','tools','scripts/pack_love.sh','scripts/switch/verify_payload.sh','scripts/macos-entitlements.plist']
  root_files=subprocess.check_output(['git','ls-tree','--name-only',ref],cwd=ROOT,text=True).splitlines()
  licenses=[name for name in root_files if name.lower()in ('license','license.md')]
  if not licenses:raise ValueError('source revision has no license')
  paths.extend(licenses)
  archive=subprocess.check_output(['git','archive',ref,*paths],cwd=ROOT)
  with tarfile.open(fileobj=io.BytesIO(archive))as t:t.extractall(source,filter='data')
  preview=source/'src/preview';preview.mkdir();(source/'main.lua').rename(preview/'main.lua');(source/'conf.lua').rename(preview/'conf.lua')
  (source/'conf.lua').write_text('local P=require("src.core.NativePreview");P.activate('+json.dumps(identity)+')\nassert(love.filesystem.load("src/preview/conf.lua"))()\nlocal configure=love.conf\nfunction love.conf(t)configure(t);t.identity=P.identity;t.window.title="Gen2Recomped Native Preview" end\n')
  (source/'main.lua').write_text('require("src.core.NativePreview").prepare()\nassert(love.getVersion()>=12,"Use the bundled LOVE12 runtime for this preview")\nassert(love.filesystem.load("src/preview/main.lua"))()\n')
  payload=out/'Gen2Recomped-NativePreview.love'
  subprocess.run(['bash',str(source/'scripts/pack_love.sh'),'--engine-only','--output',str(payload)],check=True,stdout=subprocess.DEVNULL)
  normalize_zip(payload);verify_payload(payload)
  runtime_dir=work/'runtime';unpack_zip(a.runtime,runtime_dir);inner=runtime_dir/runtime['inner']
  if a.platform=='windows':
   unpack_zip(inner,runtime_dir/'unpacked');exes=list((runtime_dir/'unpacked').rglob('love.exe'));assert len(exes)==1
   bundle=work/'Gen2Recomped-NativePreview';shutil.copytree(exes[0].parent,bundle)
   (bundle/'Gen2Recomped-NativePreview.exe').write_bytes(exes[0].read_bytes()+payload.read_bytes())
   (bundle/'love.exe').unlink();(bundle/'lovec.exe').unlink(missing_ok=True)
   (bundle/'OpenGL-Test.cmd').write_bytes(b'@echo off\r\nset "POKEPORT_GRAPHICS_BACKEND=opengl"\r\n"%~dp0Gen2Recomped-NativePreview.exe" %*\r\n')
   target=out/f'Gen2Recomped-NativePreview-{a.release_id}-windows.zip';shutil.make_archive(str(target.with_suffix('')),'zip',bundle.parent,bundle.name)
  else:
   subprocess.run(['ditto','-x','-k',str(inner),str(runtime_dir/'unpacked')],check=True)
   apps=list((runtime_dir/'unpacked').rglob('love.app'));assert len(apps)==1
   bundle=work/'Gen2Recomped-NativePreview.app';shutil.copytree(apps[0],bundle,symlinks=True)
   shutil.copy2(payload,bundle/'Contents/Resources/game.love');info=bundle/'Contents/Info.plist'
   with info.open('rb')as f:pl=plistlib.load(f)
   assert pl['CFBundleExecutable']=='love'
   for key in ('CFBundleDocumentTypes','CFBundleURLTypes','UTExportedTypeDeclarations','UTImportedTypeDeclarations'):pl.pop(key,None)
   engine_version=re.search(r'engine\s*=\s*"([^"]+)"',(source/'src/core/Version.lua').read_text()).group(1)
   pl.update(CFBundleShortVersionString=engine_version,CFBundleIdentifier='de.roxas2712.gen2recomp.native-preview',CFBundleName='Gen2Recomped Native Preview',CFBundleDisplayName='Gen2Recomped Native Preview',CFBundleVersion=a.release_id)
   with info.open('wb')as f:plistlib.dump(pl,f)
   subprocess.run(['codesign','--force','--deep','--sign','-','--entitlements',str(source/'scripts/macos-entitlements.plist'),str(bundle)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   subprocess.run(['codesign','--verify','--deep','--strict',str(bundle)],check=True)
   stage=work/'macos';stage.mkdir();shutil.move(bundle,stage/bundle.name)
   for backend in ('OpenGL','Metal'):
    cmd=stage/(backend+'-Test.command');cmd.write_text('#!/bin/sh\ncd "$(dirname "$0")"\nexport POKEPORT_GRAPHICS_BACKEND='+backend.lower()+'\nexec "./Gen2Recomped-NativePreview.app/Contents/MacOS/love" "$@"\n');cmd.chmod(0o755)
   target=out/f'Gen2Recomped-NativePreview-{a.release_id}-macos.zip';subprocess.run(['ditto','-c','-k','--keepParent',str(stage),str(target)],check=True)
  metadata=dict(sourceCommit=ref,runtimeCommit=RUNTIME_COMMIT,runtimeArtifact=runtime['id'],runtimeSha256=runtime['sha256'],platform=a.platform,previewIdentity=identity,payloadSha256=sha(payload),archiveSha256=sha(target),modsIncluded=False,legacyMigration=False,automaticInstallation=False)
  (out/'build.json').write_text(json.dumps(metadata,indent=2)+'\n');print(json.dumps(metadata))
if __name__=='__main__':main()
