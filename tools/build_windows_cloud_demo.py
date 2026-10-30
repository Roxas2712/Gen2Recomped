#!/usr/bin/env python3
"""Package the qualified Windows runtime and current private demo without user data."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse, atexit, hashlib, importlib.util, io, json, os, shutil, struct, sys, zipfile
from pathlib import Path, PurePosixPath
from build_native_preview import RUNTIMES

ROOT=Path(__file__).resolve().parents[1]
VERSION='20261030.3'
TESTS=['windows_demo_profile','windows_demo_boot','cloud_outbox','cloud_setup','cloud_save_feedback']
FORBIDDEN={'.gb','.gbc','.gba','.nds','.3ds','.cia','.cxi','.sav','.srm','.state','.bak'}
def sha(path):
 with path.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def safe(name):
 path=PurePosixPath(name)
 if path.is_absolute()or '..'in path.parts or '\\'in name or ':'in name:raise ValueError('Unsafe archive path: '+name)
 return path
def pe(data):
 if data[:2]!=b'MZ'or len(data)<64:raise ValueError('Missing Windows PE binary')
 offset=struct.unpack_from('<I',data,60)[0]
 if data[offset:offset+4]!=b'PE\0\0'or struct.unpack_from('<H',data,offset+4)[0]!=0x8664:raise ValueError('Expected Windows x64 PE binary')
def audit_payload(z):
 names=z.namelist()
 if len(set(names))!=len(names):raise ValueError('Duplicate payload paths')
 for name in names:
  path=safe(name)
  if path.suffix.lower()in FORBIDDEN or 'generated'in path.parts or 'baseroms'in path.parts:raise ValueError('Private game data in payload: '+name)
  if path.name in{'options.lua','cloud_retro.lua','storage_account.lua','cloud_outbox.lua','portable.txt'}or name.startswith(('saves/','profiles/','states/')):raise ValueError('Private profile data in payload: '+name)
 for name in ['main.lua','conf.lua','src/storage/CloudOutbox.lua','src/storage/CloudSetup.lua','src/cloud/http_worker.lua','tools/windows-demo/Profile.lua','tools/windows-demo/SelfTest.lua']:
  if name not in names:raise ValueError('Missing cloud runtime file: '+name)
 if z.testzip()is not None:raise ValueError('Payload ZIP failed integrity check')
def build(a):
 import qa_storage as qa
 qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close,collect=False)
 for p in [ROOT,a.runtime,a.component.parent]:qa.qa_source(p)
 if a.payload:qa.qa_source(a.payload)
 out=a.out.resolve();qa.qa_copy(out);qa.qa_limit_output(out,1024*1024*1024)
 if out.exists():raise ValueError('Choose a new output directory; existing builds are preserved')
 if sha(a.runtime)!=RUNTIMES['windows']['sha256']:raise ValueError('Official runtime digest mismatch')
 spec=importlib.util.spec_from_file_location('windows_component',ROOT/'tools/runtime-upvalue-check/component.py')
 component=importlib.util.module_from_spec(spec);spec.loader.exec_module(component)
 revision=qa.qa_run(['git','rev-parse','HEAD'],cwd=ROOT,check=True,capture_output=True,text=True).stdout.strip()
 library,notice,manifest=component.verify(a.component,'windows',component.engine_tree(revision,ROOT))
 out.mkdir(parents=True);bundle=out/'RetroRecomped-Windows-Demo';bundle.mkdir()
 if not a.payload:
  a.payload=out/'source-engine.love'
  scratch=out/'pack-scratch';scratch.mkdir()
  qa.qa_run(['bash',str(ROOT/'scripts/pack_love.sh'),'--engine-only','--output',str(a.payload)],cwd=ROOT,
    env=dict(os.environ,TMPDIR=str(scratch)),check=True)
 with zipfile.ZipFile(a.runtime)as z:
  entries=[n for n in z.namelist()if PurePosixPath(n).name==RUNTIMES['windows']['inner']]
  if len(entries)!=1:raise ValueError('Pinned portable runtime ZIP is absent')
  inner=z.read(entries[0])
 runtime_hashes={}
 with zipfile.ZipFile(io.BytesIO(inner))as z:
  files={}
  for name in z.namelist():
   path=safe(name)
   if not name.endswith('/')and(path.suffix.lower()=='.dll'or path.name in{'love.exe','license.txt'}):
    if path.name in files:raise ValueError('Duplicate runtime filename')
    files[path.name]=z.read(name)
  if not{'love.exe','love.dll','lua51.dll','SDL3.dll'}.issubset(files):raise ValueError('Incomplete Windows runtime')
  for name,data in files.items():
   if name.endswith('.dll')or name.endswith('.exe'):pe(data)
   if name=='lua51.dll':data=library.read_bytes()
   if name!='love.exe':(bundle/name).write_bytes(data)
   runtime_hashes[name]=hashlib.sha256(data).hexdigest()
  exe=files['love.exe']
 payload=out/'RetroRecomped-Windows.love'
 with zipfile.ZipFile(a.payload)as old,zipfile.ZipFile(payload,'w',zipfile.ZIP_DEFLATED,compresslevel=6)as z:
  for name in old.namelist():
   if name in{'main.lua','conf.lua'}:continue
   z.writestr(name,old.read(name))
  for name in ['main.lua','conf.lua']:
   if not old.read(name).startswith((ROOT/name).read_bytes()):raise ValueError('Base demo engine entry is stale: '+name)
   z.writestr('tools/windows-demo/original-'+name,(ROOT/name).read_bytes())
   z.writestr(name,(ROOT/'tools/windows-demo'/name).read_bytes())
  for name in ['Profile.lua','SelfTest.lua']:z.writestr('tools/windows-demo/'+name,(ROOT/'tools/windows-demo'/name).read_bytes())
  z.writestr('tools/windows-demo/main.lua',(ROOT/'tools/windows-demo/main.lua').read_bytes())
  z.writestr('tests/love_stub.lua',(ROOT/'tests/love_stub.lua').read_bytes())
  for name in TESTS:z.writestr('tests/engine/'+name+'.lua',(ROOT/'tests/engine'/str(name+'.lua')).read_bytes())
 with zipfile.ZipFile(payload)as z:audit_payload(z)
 target=bundle/'RetroRecomped.exe'
 with target.open('wb')as f,payload.open('rb')as source:f.write(exe);shutil.copyfileobj(source,f)
 with zipfile.ZipFile(target)as z:
  audit_payload(z)
  assert z.read('main.lua')==(ROOT/'tools/windows-demo/main.lua').read_bytes()
 shutil.copy2(notice,bundle/'COPYRIGHT-LuaJIT.txt')
 shutil.copytree(a.component.parent,bundle/'runtime-qualification')
 for name in ['NOTICE.md','LICENSE-ROXAS2712.md','LICENSE','LICENSE.MD']:
  p=ROOT/name
  if p.is_file():shutil.copy2(p,bundle/name)
 diagnostic='\r\n'.join(['@echo off','setlocal','set "RETRO_WINDOWS_CLOUD_SELFTEST=1"',
  r'"%~dp0RetroRecomped.exe" > "%TEMP%\RetroRecomped-Cloud-Test.log" 2>&1','set "result=%ERRORLEVEL%"',
  r'type "%TEMP%\RetroRecomped-Cloud-Test.log"','echo.',r'echo Report/log: %TEMP%\RetroRecomped-Cloud-Test.log','pause','exit /b %result%',''])
 (bundle/'Cloud-Test.cmd').write_bytes(diagnostic.encode('ascii'))
 guide=(ROOT/'tools/windows-demo/README.txt').read_text(encoding='utf-8')
 (bundle/'LIESMICH.txt').write_text(guide,encoding='utf-8-sig')
 receipt={'schema':1,'author':'Roxas2712','build':VERSION,'sourceRevision':revision,'platform':'Windows x64',
  'runtimeArtifact':RUNTIMES['windows']['id'],'runtimeSha256':sha(a.runtime),'luaLibrarySha256':sha(library),
  'componentSha256':sha(a.component),'componentEngineTreeVerified':True,'componentEngineSource':manifest.get('engineSource'),
  'basePayloadSha256':sha(a.payload),'payloadSha256':sha(payload),'fusedExeSha256':sha(target),'runtimeFilesSha256':runtime_hashes,
  'profilePolicy':'read-only discovery; reuse chosen directory; no legacy migration or copy; portable.txt not bundled',
  'privateRomsSavesCredentialsBundled':False,'windowsDemoExecuted':False,'playerCloudUploadTested':False}
 (bundle/'build.json').write_text(json.dumps(receipt,indent=2)+'\n')
 archive=out/('RetroRecomped-Windows-Demo-'+VERSION+'-win64.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6)as z:
  for path in sorted(bundle.rglob('*')):
   if path.is_file():z.write(path,bundle.name+'/'+path.relative_to(bundle).as_posix())
 with zipfile.ZipFile(archive)as z:assert z.testzip()is None
 receipt['archiveSha256']=sha(archive)
 (out/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'archive':str(archive),'sha256':receipt['archiveSha256'],'sourceRevision':revision,'windowsDemoExecuted':False}),flush=True)
 return archive
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--runtime',type=Path,required=True);p.add_argument('--component',type=Path,required=True)
 p.add_argument('--payload',type=Path,help='Optional already packed engine; otherwise use the shared packer')
 p.add_argument('--out',type=Path,required=True)
 build(p.parse_args())
