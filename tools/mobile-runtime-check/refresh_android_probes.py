#!/usr/bin/env python3
"""Refresh public probe bytes in owned QA APKs without rebuilding their native VMs."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();source=a.build.resolve(strict=True);out=a.output.resolve()
 if out.exists() or out.is_relative_to(source) or source.is_relative_to(out):p.error('choose a new owned output separate from the input')
 report=json.loads((source/'report.json').read_text());abi=report['abi']
 native='tools/mobile-runtime-check/host-c-api.cpp'
 if report.get('probeSha256',{}).get(native)!=sha(ROOT/native):
  raise ValueError('Native QA probe changed; build fresh app candidates instead of refreshing payloads')
 if abi not in ('arm64-v8a','armeabi-v7a','x86_64'):p.error('unsupported ABI')
 run=subprocess.run
 if not os.getenv('GITHUB_ACTIONS'):
  sys.path.insert(0,str(ROOT/'tools'));import qa_storage as qa
  qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close)
  for path in (ROOT,source):qa.qa_source(path)
  qa.qa_cache(out.parent);qa.qa_copy(out);run=qa.qa_run
 sdk=Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
 tools=sorted((sdk/'build-tools').glob('*/apksigner'),key=lambda x:[int(n) for n in re.findall(r'\d+',x.parent.name)])[-1].parent
 out.mkdir(parents=True)
 probes={'main.lua':'tools/mobile-runtime-check/host-main.lua','host-c-api.lua':'tools/mobile-runtime-check/host-c-api.lua',
         'thread.lua':'tools/runtime-upvalue-check/love-thread.lua','check.lua':'tools/runtime-upvalue-check/check.lua','src/link/Json.lua':'src/link/Json.lua'}
 report['probeSha256']={**report['probeSha256'],**{name:sha(ROOT/name) for name in probes.values()}}
 report['refreshedFromReportSha256']=sha(source/'report.json')
 shutil.copyfile(source/'report.json',out/'previous-build-report.json')
 for variant,capacity in [('stock',60),('extended',120)]:
  entry=report['results'][variant];apk=source/entry['apk']
  if apk.parent!=source or sha(apk)!=entry['apkSha256']:raise ValueError('input owned APK changed')
  if not re.fullmatch(r'com\.roxas2712\.runtimeqa\.r[0-9a-f]{32}\.'+variant,entry['package']):raise ValueError('owned QA app required')
  payload=io.BytesIO()
  with zipfile.ZipFile(payload,'w',zipfile.ZIP_DEFLATED) as z:
   for name,path in probes.items():z.write(ROOT/path,name)
   z.writestr('config.lua',f'return {{capacity={capacity},identity="{entry["identity"]}",platform="android",arch="'+{'arm64-v8a':'arm64','armeabi-v7a':'arm','x86_64':'x64'}[abi]+'",jit='+str(abi=='x86_64').lower()+'}\n')
   z.writestr('conf.lua',f'function love.conf(t)t.identity="{entry["identity"]}";t.version="11.5";t.window=false;t.modules.graphics=false;t.modules.audio=false;t.modules.joystick=false;t.modules.physics=false end\n')
  unsigned=out/(variant+'-unsigned.apk');aligned=out/(variant+'-aligned.apk');target=out/entry['apk']
  with zipfile.ZipFile(apk) as original,zipfile.ZipFile(unsigned,'w',zipfile.ZIP_DEFLATED) as dest:
   for info in original.infolist():
    if re.fullmatch(r'META-INF/(?:[^/]+\.(?:RSA|DSA|EC|SF)|MANIFEST.MF)',info.filename,re.I):continue
    data=payload.getvalue() if info.filename=='assets/game.love' else original.read(info)
    dest.writestr(info,data)
  run([str(tools/'zipalign'),'-f','4',str(unsigned),str(aligned)],check=True)
  run([str(tools/'apksigner'),'sign','--ks',str(ROOT/'mobile/android/debug.keystore'),
       '--ks-key-alias','androiddebugkey','--ks-pass','pass:android','--key-pass','pass:android',
       '--out',str(target),str(aligned)],check=True)
  with zipfile.ZipFile(target) as z:
   if hashlib.sha256(z.read('lib/'+abi+'/liblove.so')).hexdigest()!=entry['libloveSha256']:raise ValueError('refresh changed the native host')
   if z.read('assets/game.love')!=payload.getvalue():raise ValueError('probe payload changed during signing')
  entry['apkSha256']=sha(target)
 report['scope']='Updated public probe payloads only; native LÖVE/JNI and Lua archive bytes unchanged.'
 (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
 print('ANDROID_NATIVE_UNCHANGED_PROBES_REFRESHED',abi,flush=True)
if __name__=='__main__':main()
