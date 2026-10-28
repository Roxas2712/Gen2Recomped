#!/usr/bin/env python3
"""Check both interpreter variants inside actual iOS LÖVE simulator apps."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import uuid
import zipfile

ROOT=Path(__file__).resolve().parents[2]
LOVE='937eb3b21f973607ab080aa26b7ef2a6b3b2b663'
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--build',type=Path,required=True);p.add_argument('--love-source',type=Path,required=True)
 p.add_argument('--engine-root',type=Path,default=ROOT);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();build=a.build.resolve(strict=True);love=a.love_source.resolve(strict=True);engine=a.engine_root.resolve(strict=True);out=a.output.resolve()
 if sys.platform!='darwin':p.error('Xcode on macOS required')
 if out.exists() or any(out.is_relative_to(x) or x.is_relative_to(out) for x in (build,love,engine)):p.error('Choose a new owned output separate from inputs')
 if subprocess.check_output(['git','rev-parse','HEAD'],cwd=love,text=True).strip()!=LOVE:p.error('Pinned prepared LOVE source required')
 manifest=build/'report.json';report=json.loads(manifest.read_text());manifest_hash=sha(manifest)
 run=subprocess.run
 if not os.getenv('GITHUB_ACTIONS'):
  sys.path.insert(0,str(ROOT/'tools'));import qa_storage as qa
  qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close)
  for path in (ROOT,engine,build,love):qa.qa_source(path)
  qa.qa_cache(out.parent);qa.qa_copy(out);run=qa.qa_run
 out.mkdir(parents=True)
 def command(label,argv,timeout=300):
  r=run([str(x) for x in argv],capture_output=True,text=True,timeout=timeout)
  (out/(label+'.log')).write_text(r.stdout+r.stderr)
  if r.returncode:print((r.stdout+r.stderr)[-9000:],flush=True)
  r.check_returncode();return r.stdout.strip()
 def sim(label,*args,timeout=300):return command(label,['xcrun','simctl',*args],timeout)
 runtimes=json.loads(sim('runtimes','list','runtimes','-j'))['runtimes']
 runtime=next(x for x in reversed(runtimes) if x.get('isAvailable') and '.iOS-' in x['identifier'])
 types=json.loads(sim('device-types','list','devicetypes','-j'))['devicetypes']
 supported={x['identifier'] for x in runtime.get('supportedDeviceTypes',[])}
 device=next(x['identifier'] for x in reversed(types) if 'iPhone' in x['name'] and (not supported or x['identifier'] in supported))
 token=uuid.uuid4().hex
 udid=sim('create','create','Gen2-Lua-QA-'+token,device,runtime['identifier'])
 results={};arch='arm64' if platform.machine()=='arm64' else 'x86_64';lua_arch='arm64' if arch=='arm64' else 'x64'
 source=out/'host';shutil.copytree(love,source,symlinks=True,ignore=shutil.ignore_patterns('.git'))
 framework=source/'platform/xcode/ios/libraries/Lua.xcframework'
 probes={'main.lua':ROOT/'tools/mobile-runtime-check/host-main.lua','host-c-api.lua':ROOT/'tools/mobile-runtime-check/host-c-api.lua',
         'thread.lua':ROOT/'tools/runtime-upvalue-check/love-thread.lua','check.lua':ROOT/'tools/runtime-upvalue-check/check.lua','src/link/Json.lua':engine/'src/link/Json.lua'}
 probe_hashes={name:sha(path) for name,path in probes.items()}
 try:
  sim('boot','boot',udid);sim('booted','bootstatus',udid,'-b',timeout=360)
  for variant,capacity in [('stock',60),('extended',120)]:
   for label in ('device-arm64','sim-arm64','sim-x86_64'):
    entry=report['results'][variant+'-'+label]
    assert entry['capacity']==capacity and entry['jitEnabled'] is False
    assert sha(build/'artifacts'/variant/label/'libluajit.a')==entry['librarySha256']
   # Only the generated, owned host's dependency framework is replaced.
   shutil.rmtree(framework);shutil.copytree(build/'artifacts'/variant/'Lua.xcframework',framework)
   package='com.roxas2712.runtimeqa.r'+token+'.'+variant
   identity='oasc-gen2recomp-qa-ios-runtime-'+token+'-'+variant
   command(variant+'-build',['xcodebuild','-project',source/'platform/xcode/love.xcodeproj','-target','love-ios',
     '-configuration','Release','-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator',
     'SYMROOT='+str(out/'products'/variant),'OBJROOT='+str(out/'objects'/variant),
     'CODE_SIGNING_ALLOWED=NO','CODE_SIGNING_REQUIRED=NO','CODE_SIGN_IDENTITY=',
     'ONLY_ACTIVE_ARCH=YES','ARCHS='+arch,'PRODUCT_BUNDLE_IDENTIFIER='+package,
     'OTHER_LDFLAGS=$(inherited) -Wl,-export_dynamic'],timeout=1800)
   apps=list((out/'products'/variant).rglob('*.app'));assert len(apps)==1
   app=apps[0];payload=app/'game.love'
   with zipfile.ZipFile(payload,'w',zipfile.ZIP_DEFLATED) as z:
    for name,path in probes.items():z.write(path,name)
    z.writestr('config.lua',f'return {{capacity={capacity},identity="{identity}",platform="ios",arch="{lua_arch}",jit=false}}\n')
    z.writestr('conf.lua',f'function love.conf(t) t.identity="{identity}";t.version="12.0";t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.joystick=false;t.modules.physics=false end\n')
   sim(variant+'-install','install',udid,app)
   sim(variant+'-start','launch',udid,package)
   container=Path(sim(variant+'-container','get_app_container',udid,package,'data'))
   deadline=time.monotonic()+180;result=None
   while time.monotonic()<deadline:
    paths=list(container.rglob('runtime-capacity-result.json'))
    if paths:
     try:result=json.loads(paths[0].read_text())
     except json.JSONDecodeError:pass
     else:break
    time.sleep(2)
   assert result and result.get('passed') is True,result
   assert result['capacity']==capacity and result['identity']==identity and result['arch']==lua_arch
   assert result['jitActive'] is False and result['closureReport']['interpreterOnly'] is True
   for key in ('cApiPassed','ffiCallbackPassed','threadVmPassed','filesystemPassed'):assert result.get(key) is True,key
   boundary=next(x for x in result['closureReport']['cases'] if x['upvalues']==capacity)
   assert boundary['compiles'] and boundary['interpreter'] and 'jit' not in boundary
   results[variant]={'result':result,'runtimeLibrarySha256':report['results'][variant+'-sim-'+arch]['librarySha256'],
     'binarySha256':sha(app/'love'),'payloadSha256':sha(payload)}
   sim(variant+'-uninstall','uninstall',udid,package)
   print(variant,capacity,'IOS LOVE/INTERPRETER/CAPI/THREAD/FFI PASS',flush=True)
 finally:
  sim('shutdown','shutdown',udid);sim('delete','delete',udid)
 assert sha(manifest)==manifest_hash
 assert all(sha(probes[name])==h for name,h in probe_hashes.items())
 tree={name:subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=engine,text=True).strip() for name in ('main.lua','conf.lua','src','assets','data')}
 (out/'report.json').write_text(json.dumps({'platform':'ios','passed':True,'loveHostAbiQualified':True,
   'simulator':True,'architecture':arch,'physicalDevice':False,'engineTree':tree,'baseLoveCommit':LOVE,
   'runtimeBuildReportSha256':manifest_hash,'probeSha256':probe_hashes,'results':results,'releaseSelectable':False},indent=2)+'\n')
if __name__=='__main__':main()
