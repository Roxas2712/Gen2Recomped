#!/usr/bin/env python3
"""Build pinned stock/extended interpreter-only iOS Lua XCFrameworks."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
PIN='a4c064539ea931274d407e1249b4bb575424a0f4'
HEADERS=('lua.h','lua.hpp','luaconf.h','lauxlib.h','lualib.h','luajit.h')
SLICES={'device-arm64':('iphoneos','arm64','arm64-apple-ios14.0'),
        'sim-arm64':('iphonesimulator','arm64','arm64-apple-ios14.0-simulator'),
        'sim-x86_64':('iphonesimulator','x86_64','x86_64-apple-ios14.0-simulator')}
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();source=a.source.resolve(strict=True);out=a.output.resolve()
 if sys.platform!='darwin':p.error('Xcode on macOS is required')
 if out.exists() or out.is_relative_to(source) or source.is_relative_to(out):p.error('Choose a new owned output separate from the source')
 if subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()!=PIN:p.error('Pinned LuaJIT source required')
 if subprocess.check_output(['git','status','--porcelain'],cwd=source,text=True).strip():p.error('LuaJIT source must be clean')
 run=subprocess.run
 if not os.getenv('GITHUB_ACTIONS'):
  sys.path.insert(0,str(ROOT/'tools'));import qa_storage as qa
  qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close)
  for path in (ROOT,source):qa.qa_source(path)
  qa.qa_cache(out.parent);qa.qa_copy(out);run=qa.qa_run
 out.mkdir(parents=True)
 def command(label,argv,cwd=None):
  with (out/(label+'.log')).open('w') as log:r=run([str(x) for x in argv],cwd=cwd,stdout=log,stderr=subprocess.STDOUT,timeout=900)
  if r.returncode:print((out/(label+'.log')).read_text()[-8000:],flush=True)
  r.check_returncode()
 timestamp=subprocess.check_output(['git','show','-s','--format=%ct',PIN],cwd=source,text=True).strip()
 source_files=subprocess.check_output(['git','ls-files','-z'],cwd=source).decode().split('\0')
 hashes={name:sha(source/name) for name in source_files if name}
 results={}
 for variant,capacity in [('stock',60),('extended',120)]:
  headers=None;libraries={}
  for label,(sdk,arch,target) in SLICES.items():
   work=out/'build'/variant/label;work.mkdir(parents=True)
   for name in hashes:
    dest=work/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/name,dest)
   (work/'.relver').write_text(timestamp+'\n')
   limit=work/'src/lj_def.h';text=limit.read_text()
   if len(re.findall(r'^#define LJ_MAX_UPVAL\s+60\s',text,re.M))!=1:raise ValueError('Stock source limit changed')
   if capacity==120:limit.write_text(re.sub(r'(^#define LJ_MAX_UPVAL\s+)60(?=\s)',r'\g<1>120',text,flags=re.M))
   sdk_path=subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],text=True).strip()
   compiler=Path(subprocess.check_output(['xcrun','--sdk',sdk,'--find','clang'],text=True).strip())
   command(variant+'-'+label,['make','-j4','BUILDMODE=static','DEFAULT_CC=clang','HOST_CC=clang',
     'CROSS='+str(compiler.parent)+'/', 'TARGET_SYS=iOS',
     'TARGET_FLAGS=-target '+target+' -isysroot '+sdk_path,
     'XCFLAGS=-DLUAJIT_DISABLE_JIT -DLUAJIT_ENABLE_LUA52COMPAT'],work)
   dest=out/'artifacts'/variant/label;dest.mkdir(parents=True)
   shutil.copy2(work/'src/libluajit.a',dest/'libluajit.a')
   for name in HEADERS:shutil.copy2(work/'src'/name,dest/name)
   shutil.copy2(source/'COPYRIGHT',dest/'COPYRIGHT')
   libraries[label]=dest/'libluajit.a';headers=dest
   results[variant+'-'+label]={'capacity':capacity,'sdk':sdk,'architecture':arch,'target':target,
     'jitEnabled':False,'librarySha256':sha(dest/'libluajit.a'),
     'headers':{name:sha(dest/name) for name in HEADERS}}
  framework=out/'artifacts'/variant/'Lua.xcframework'
  sim=out/'artifacts'/variant/'libluajit_sim.a'
  command(variant+'-lipo',['xcrun','lipo','-create',libraries['sim-arm64'],libraries['sim-x86_64'],'-output',sim])
  command(variant+'-xcframework',['xcodebuild','-create-xcframework',
    '-library',libraries['device-arm64'],'-headers',headers,
    '-library',sim,'-headers',headers,'-output',framework])
  print(variant,capacity,'IOS INTERPRETER FRAMEWORK BUILD PASS',flush=True)
 if any(sha(source/name)!=value for name,value in hashes.items()):raise RuntimeError('Pinned source changed')
 (out/'report.json').write_text(json.dumps({'platform':'ios','luaJitSource':PIN,'sourceSha256':hashes,
   'jitEnabled':False,'results':results,'buildPassed':True,'releaseSelectable':False},indent=2)+'\n')
if __name__=='__main__':main()
