#!/usr/bin/env python3
"""Build an isolated native-engine preview from committed source + pinned LÖVE12 artifacts."""
import argparse,hashlib,importlib.util,io,json,os,plistlib,re,shutil,subprocess,tarfile,tempfile,zipfile
from pathlib import Path,PurePosixPath
from macos_distribution import install_icon, sign_and_notarize
ROOT=Path(__file__).resolve().parents[1]
RUNTIME_COMMIT='937eb3b21f973607ab080aa26b7ef2a6b3b2b663'
RUNTIMES={
 'windows':dict(id=12514271124,sha256='1f4c6997bd93502f986f5187d877da84247617eede89d8140bcbf570bd07ea22',inner='love-12.0-win64.zip'),
 'macos':dict(id=12513712494,sha256='f70f60d162eda6931b0b28e2b094b83b741986f0feac08d33a10be7c57e724f8',inner='love-macos.zip')}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def qualified_runtime(path,platform,ref):
 spec=importlib.util.spec_from_file_location('preview_runtime_component',ROOT/'tools/runtime-upvalue-check/component.py')
 component=importlib.util.module_from_spec(spec);spec.loader.exec_module(component)
 library,notice,manifest=component.verify(path,platform,component.engine_tree(ref,ROOT))
 return library,notice,manifest
def raise_macos_minimum(info,minimum):
 current=info.get('LSMinimumSystemVersion','0')
 def version(value):return tuple(int(part)for part in value.split('.'))+(0,)*(3-len(value.split('.')))
 if version(current)<version(minimum):info['LSMinimumSystemVersion']=minimum
def install_qualified_runtime(checked,manifest_path,target,receipts):
 library,notice,manifest=checked
 shutil.copy2(library,target);receipts.mkdir(parents=True)
 shutil.copy2(manifest_path,receipts/'input-component.json')
 shutil.copy2(notice,receipts/notice.name)
 for row in manifest['qualifications']:
  for key in ('capacityReport','hostReport'):
   relative=Path(row[key]);destination=receipts/relative
   destination.parent.mkdir(parents=True,exist_ok=True)
   shutil.copy2(manifest_path.parent/relative,destination)
 return dict(experimental=True,luaJitSource=manifest['luaJitSource'],capacity=manifest['capacity'],
             architectures=sorted(row['architecture'] for row in manifest['qualifications']),
             componentManifestSha256=sha(manifest_path),inputLibrarySha256=sha(library),
             engineTreeVerified=True,qualifications=manifest['qualifications'])
def verify_payload(path,engine_version=None):
 with zipfile.ZipFile(path)as z:
  for name in z.namelist():
   p=PurePosixPath(name)
   if p.is_absolute()or '..'in p.parts:raise ValueError('unsafe payload path')
   if p.suffix.lower()in ('.gb','.gbc','.gba','.sav','.srm','.bak'):raise ValueError('private ROM/save content')
   if 'generated'in p.parts or 'baseroms'in p.parts or p.name=='rom-cache.complete':raise ValueError('generated game content')
   builtin=name=='mods/'or name.startswith('mods/UNI_LANGUAGE_NATIVE/')
   if name.startswith('mods/')and not builtin or name in ('options.lua','save.lua','cloud_clients.lua'):raise ValueError('non-preview content')
  for f in ('main.lua','conf.lua','src/preview/main.lua','src/preview/conf.lua','src/preview/release.json','src/core/NativePreview.lua'):
   if f not in z.namelist():raise ValueError('missing preview entry: '+f)
  if 'src/core/TouchSkin.lua' in z.namelist() and 'licenses/GEN1RECOMP-TOUCH-SKINS.md' not in z.namelist():
   raise ValueError('missing Gen1 touch-skin licence')
  if engine_version is not None:
   version=z.read('src/core/Version.lua').decode('utf-8')
   stamped=re.search(r'engine\s*=\s*"([^"]+)"',version)
   if not stamped or stamped.group(1)!=engine_version:raise ValueError('payload engine version does not match release')
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
def verify_mac_archive(path,icon_hash=None):
 with zipfile.ZipFile(path)as z:
  for name in z.namelist():
   if any(p=='__MACOSX'or p.startswith('._')for p in PurePosixPath(name).parts):
    raise ValueError('macOS archive contains host metadata')
  if icon_hash:
   infos=[name for name in z.namelist()if name.endswith('.app/Contents/Info.plist')]
   if len(infos)!=1:raise ValueError('expected one macOS application')
   values=plistlib.loads(z.read(infos[0]))
   if values.get('CFBundleIconFile')!='GameIcon.icns' or 'CFBundleIconName'in values:
    raise ValueError('macOS application icon is overridden')
   icon=infos[0].removesuffix('Info.plist')+'Resources/GameIcon.icns'
   if z.getinfo(icon).file_size>8*1024*1024 or hashlib.sha256(z.read(icon)).hexdigest()!=icon_hash:
    raise ValueError('macOS application icon digest mismatch')
def extract_preview_source(ref,source):
 paths=['main.lua','conf.lua','src','assets','data','tools','scripts/pack_love.sh','scripts/switch/verify_payload.sh','scripts/macos-entitlements.plist','icons/icon.icns']
 builtin=bool(subprocess.check_output(['git','ls-tree','--name-only',ref,'mods/UNI_LANGUAGE_NATIVE'],cwd=ROOT,text=True).strip())
 if builtin:paths.append('mods/UNI_LANGUAGE_NATIVE')
 root_files=subprocess.check_output(['git','ls-tree','--name-only',ref],cwd=ROOT,text=True).splitlines()
 if 'compat' in root_files:paths.append('compat')
 licenses=[name for name in root_files if name.lower()in ('license','license.md','license-roxas2712.md','notice.md')]
 if not licenses:raise ValueError('source revision has no license')
 paths.extend(licenses)
 skin_licence='licenses/GEN1RECOMP-TOUCH-SKINS.md'
 if subprocess.check_output(['git','ls-tree','--name-only',ref,'src/core/TouchSkin.lua'],cwd=ROOT,text=True).strip():
  if not subprocess.check_output(['git','ls-tree','--name-only',ref,skin_licence],cwd=ROOT,text=True).strip():
   raise ValueError('source revision has no Gen1 touch-skin licence')
  paths.append(skin_licence)
 archive=subprocess.check_output(['git','archive',ref,*paths],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive))as t:t.extractall(source,filter='data')
 return builtin

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--platform',choices=RUNTIMES,required=True);p.add_argument('--runtime',type=Path,required=True);p.add_argument('--source-ref',required=True);p.add_argument('--release-id',required=True);p.add_argument('--engine-version',required=True,help='Real engine release X.Y.Z, stamped identically to regular releases');p.add_argument('--out',type=Path,required=True);p.add_argument('--qualified-runtime',type=Path,help='Optional component.json with passing native engine/host gates for every platform architecture');p.add_argument('--macos-signing-identity');p.add_argument('--macos-notary-profile');p.add_argument('--macos-signing-keychain',type=Path);a=p.parse_args()
 if not re.fullmatch(r'[0-9]{8}\.[0-9]+',a.release_id):p.error('release-id must be YYYYMMDD.N')
 if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',a.engine_version):p.error('engine-version must be X.Y.Z')
 if bool(a.macos_signing_identity)!=bool(a.macos_notary_profile) or (a.macos_signing_keychain and not a.macos_signing_identity):p.error('Developer ID identity and notary profile must be supplied together')
 if a.platform!='macos' and a.macos_signing_identity:p.error('macOS distribution options require --platform macos')
 runtime=RUNTIMES[a.platform]
 if sha(a.runtime)!=runtime['sha256']:p.error('runtime digest does not match the pinned official artifact')
 ref=subprocess.check_output(['git','rev-parse','--verify','--end-of-options',a.source_ref+'^{commit}'],cwd=ROOT,text=True).strip()
 component_path=a.qualified_runtime.resolve()if a.qualified_runtime else None
 checked=qualified_runtime(component_path,a.platform,ref)if component_path else None
 runtime_override=None;macos_distribution=None
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);identity='Gen2Recomp-NativePreview-'+a.release_id.replace('.','-')
 with tempfile.TemporaryDirectory(prefix='native-preview-')as temp:
  work=Path(temp);source=work/'source';source.mkdir()
  builtin=extract_preview_source(ref,source)
  preview=source/'src/preview';preview.mkdir();(source/'main.lua').rename(preview/'main.lua');(source/'conf.lua').rename(preview/'conf.lua')
  (source/'conf.lua').write_text('local P=require("src.core.NativePreview");P.activate('+json.dumps(identity)+')\nassert(love.filesystem.load("src/preview/conf.lua"))()\nlocal configure=love.conf\nfunction love.conf(t)configure(t);t.identity=P.identity;t.window.title="Gen2Recomped Native Preview" end\n')
  (source/'main.lua').write_text('local P=require("src.core.NativePreview")\nP.checkRuntime()\nP.prepare()\nassert(love.filesystem.load("src/preview/main.lua"))()\n')
  (preview/'release.json').write_text(json.dumps(dict(sourceCommit=ref,releaseId=a.release_id,engineVersion=a.engine_version,previewIdentity=identity),sort_keys=True)+'\n')
  payload=out/'Gen2Recomped-NativePreview.love'
  subprocess.run(['bash',str(source/'scripts/pack_love.sh'),'--engine-only','--version',a.engine_version,'--output',str(payload)],check=True,stdout=subprocess.DEVNULL)
  normalize_zip(payload);verify_payload(payload,a.engine_version)
  runtime_dir=work/'runtime';unpack_zip(a.runtime,runtime_dir);inner=runtime_dir/runtime['inner']
  if a.platform=='windows':
   unpack_zip(inner,runtime_dir/'unpacked');exes=list((runtime_dir/'unpacked').rglob('love.exe'));assert len(exes)==1
   bundle=work/'Gen2Recomped-NativePreview';shutil.copytree(exes[0].parent,bundle)
   if checked:
    runtime_override=install_qualified_runtime(checked,component_path,bundle/'lua51.dll',bundle/'runtime-qualification')
    runtime_override['installedLibrarySha256']=sha(bundle/'lua51.dll')
   (bundle/'Gen2Recomped-NativePreview.exe').write_bytes(exes[0].read_bytes()+payload.read_bytes())
   (bundle/'love.exe').unlink();(bundle/'lovec.exe').unlink(missing_ok=True)
   (bundle/'OpenGL-Test.cmd').write_bytes(b'@echo off\r\nset "POKEPORT_GRAPHICS_BACKEND=opengl"\r\n"%~dp0Gen2Recomped-NativePreview.exe" %*\r\n')
   target=out/f'Gen2Recomped-NativePreview-{a.release_id}-windows.zip';shutil.make_archive(str(target.with_suffix('')),'zip',bundle.parent,bundle.name)
  else:
   subprocess.run(['unzip','-q',str(inner),'-d',str(runtime_dir/'unpacked')],check=True)
   apps=list((runtime_dir/'unpacked').rglob('love.app'));assert len(apps)==1
   bundle=work/'Gen2Recomped-NativePreview.app';shutil.copytree(apps[0],bundle,symlinks=True)
   if checked:
    target_library=bundle/'Contents/Frameworks/Lua.framework/Versions/A/Lua'
    runtime_override=install_qualified_runtime(checked,component_path,target_library,bundle/'Contents/Resources/runtime-qualification')
    subprocess.run(['install_name_tool','-id','@rpath/Lua.framework/Versions/A/Lua',str(target_library)],check=True)
   shutil.copy2(payload,bundle/'Contents/Resources/game.love');info=bundle/'Contents/Info.plist'
   with info.open('rb')as f:pl=plistlib.load(f)
   assert pl['CFBundleExecutable']=='love'
   for key in ('CFBundleDocumentTypes','CFBundleURLTypes','UTExportedTypeDeclarations','UTImportedTypeDeclarations'):pl.pop(key,None)
   engine_version=a.engine_version
   pl.update(CFBundleShortVersionString=engine_version,CFBundleIdentifier='de.roxas2712.gen2recomp.native-preview',CFBundleName='Gen2Recomped Native Preview',CFBundleDisplayName='Gen2Recomped Native Preview',CFBundleVersion=a.release_id)
   if checked:
    raise_macos_minimum(pl,checked[2]['minimumMacOS'])
    runtime_override['minimumMacOS']=pl['LSMinimumSystemVersion']
   with info.open('wb')as f:plistlib.dump(pl,f)
   icon_hash=install_icon(bundle,source/'icons/icon.icns')
   macos_distribution=sign_and_notarize(bundle,source/'scripts/macos-entitlements.plist',a.macos_signing_identity,a.macos_notary_profile,a.macos_signing_keychain)
   macos_distribution['iconSha256']=icon_hash
   if checked:runtime_override['installedLibrarySha256']=sha(target_library)
   stage=work/'macos';stage.mkdir();shutil.move(bundle,stage/bundle.name)
   for backend in ('OpenGL','Metal'):
    cmd=stage/(backend+'-Test.command');cmd.write_text('#!/bin/sh\ncd "$(dirname "$0")"\nexport POKEPORT_GRAPHICS_BACKEND='+backend.lower()+'\nexec "./Gen2Recomped-NativePreview.app/Contents/MacOS/love" "$@"\n');cmd.chmod(0o755)
   target=out/f'Gen2Recomped-NativePreview-{a.release_id}-macos.zip';subprocess.run(['ditto','-c','-k','--norsrc','--noextattr','--noacl','--keepParent',str(stage),str(target)],check=True)
   verify_mac_archive(target,icon_hash)
  metadata=dict(engineVersion=a.engine_version,sourceCommit=ref,runtimeCommit=RUNTIME_COMMIT,runtimeArtifact=runtime['id'],runtimeSha256=runtime['sha256'],platform=a.platform,previewIdentity=identity,payloadSha256=sha(payload),archiveSha256=sha(target),archive=target.name,buildVerified=True,launchVerified=False,realDeviceVerified=False,extendedUpvaluesQualified=bool(runtime_override),modsIncluded=builtin,builtinMods=['UNI_LANGUAGE_NATIVE']if builtin else [],userModsIncluded=False,modsEnabled=True,legacyMigration=False,automaticInstallation=False)
  if runtime_override:metadata['qualifiedRuntime']=runtime_override
  if macos_distribution:metadata['macosDistribution']=macos_distribution
  (out/'build.json').write_text(json.dumps(metadata,indent=2)+'\n');print(json.dumps(metadata))
if __name__=='__main__':main()
