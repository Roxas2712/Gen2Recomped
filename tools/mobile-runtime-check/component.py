#!/usr/bin/env python3
"""Stage mobile Lua components only after matching target app-host gates pass."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import argparse
import atexit
import hashlib
import json
import os
import plistlib
from pathlib import Path
import shutil
import struct
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
PIN='a4c064539ea931274d407e1249b4bb575424a0f4'
LOVE='937eb3b21f973607ab080aa26b7ef2a6b3b2b663'
ABIS={'arm64-v8a':'arm64','armeabi-v7a':'arm','x86_64':'x64'}
HEADERS=('lua.h','luaconf.h','lauxlib.h','lualib.h','luajit.h')
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def child(root,name):
 path=Path(name)
 if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:raise ValueError('unsafe component path')
 result=(root/path).resolve()
 if not result.is_relative_to(root.resolve()) or result==root.resolve():raise ValueError('component path escapes root')
 return result
def closure(result,capacity,arch,jit,interpreter_only=False):
 if not (result.get('passed') is True and result.get('capacity')==capacity and result.get('arch')==arch and result.get('jitActive') is jit):
  raise ValueError('actual host capacity/architecture/mode mismatch')
 for key in ('cApiPassed','threadVmPassed','filesystemPassed'):
  if result.get(key) is not True:raise ValueError('missing actual host gate: '+key)
 if interpreter_only:
  if not (result.get('ffiCallsPassed') is True and result.get('ffiCallbackUnavailable') is True and result.get('ffiCallbackPassed') is False):
   raise ValueError('iOS FFI calls and explicit stock callback restriction required')
 elif result.get('ffiCallbackPassed') is not True:raise ValueError('Android FFI callback gate required')
 details=result.get('closureReport',{})
 if details.get('passed') is not True or details.get('minimum')!=capacity:raise ValueError('closure report mismatch')
 boundary=next((x for x in details.get('cases',[]) if x.get('upvalues')==capacity),{})
 if not boundary.get('compiles') or not boundary.get('interpreter') or (not interpreter_only and not boundary.get('jit')):
  raise ValueError('required closure boundary was not executed')
 if interpreter_only and (not details.get('interpreterOnly') or 'jit' in boundary):raise ValueError('iOS interpreter gate required')

def android_gate(vm_path,host_path,execution_path,engine):
 vm=json.loads(vm_path.read_text());host=json.loads(host_path.read_text());execution=json.loads(execution_path.read_text())
 abi=host.get('abi')
 if abi not in ABIS or execution.get('abi')!=abi:raise ValueError('unsupported/mismatched Android ABI')
 if host.get('vmBuildReportSha256')!=sha(vm_path) or execution.get('appBuildReportSha256')!=sha(host_path):
  raise ValueError('Android qualification receipts are not linked')
 if execution.get('passed') is not True or execution.get('loveHostAbiQualified') is not True or execution.get('emulator') is not True:
  raise ValueError('actual Android app host gate required')
 source=engine/'mobile/android/love/src/jni/LuaJIT-2.1'
 if vm.get('sourceRelease')!='1700008891' or not vm.get('sourceSha256'):raise ValueError('vendored Android source pin missing')
 expected={'Makefile','COPYRIGHT'}|{str(x.relative_to(source)) for directory in ('src','dynasm') for x in (source/directory).rglob('*') if x.is_file()}
 if set(vm['sourceSha256'])!=expected:raise ValueError('incomplete Android VM source binding')
 for name,value in vm['sourceSha256'].items():
  if sha(child(source,name))!=value:raise ValueError('Android VM source differs from engine: '+name)
 if not host.get('mobileSourceSha256'):raise ValueError('Android app source binding missing')
 tracked=subprocess.check_output(['git','ls-files','-z','--','mobile/android'],cwd=engine).decode().split('\0')
 if set(host['mobileSourceSha256'])!={x for x in tracked if x}:raise ValueError('incomplete Android app source binding')
 for name,value in host['mobileSourceSha256'].items():
  if sha(child(engine,name))!=value:raise ValueError('Android app source differs from engine: '+name)
 for variant,capacity in [('stock',60),('extended',120)]:
  entry=vm['results'][variant+'-'+abi]
  if entry.get('capacityRequested')!=capacity or entry.get('buildPassed') is not True or not entry.get('cApiLinked'):
   raise ValueError('matching Android VM build/link gate required')
  if host['results'][variant]['runtimeArchiveSha256']!=entry['files']['libluajit.a']:
   raise ValueError('Android host linked a different Lua archive')
  closure(execution['results'][variant],capacity,ABIS[abi],abi=='x86_64')
 return abi,vm,host

def ios_gate(vm_path,host_path):
 vm=json.loads(vm_path.read_text());host=json.loads(host_path.read_text())
 if vm.get('luaJitSource')!=PIN or vm.get('buildPassed') is not True or vm.get('jitEnabled') is not False:
  raise ValueError('pinned interpreter-only iOS build required')
 if not (host.get('passed') is True and host.get('loveHostAbiQualified') is True and host.get('simulator') is True
         and host.get('architecture')=='arm64' and host.get('baseLoveCommit')==LOVE and host.get('runtimeBuildReportSha256')==sha(vm_path)):
  raise ValueError('actual arm64 iOS simulator host gate required')
 for variant,capacity in [('stock',60),('extended',120)]:
  closure(host['results'][variant]['result'],capacity,'arm64',False,True)
  if host['results'][variant]['runtimeLibrarySha256']!=vm['results'][variant+'-sim-arm64']['librarySha256']:
   raise ValueError('iOS host linked a different Lua archive')
  for label in ('device-arm64','sim-arm64','sim-x86_64'):
   row=vm['results'][variant+'-'+label]
   if row.get('capacity')!=capacity or row.get('jitEnabled') is not False:raise ValueError('iOS slice mode mismatch')
 return vm,host

def archive_arch(data):
 if not data.startswith(b'!<arch>\n'):raise ValueError('static archive required')
 at=8;arches=set()
 while at<len(data):
  if at+60>len(data) or data[at+58:at+60]!=b'`\n':raise ValueError('invalid archive member')
  header=data[at:at+60];length=int(header[48:58]);start=at+60;body=data[start:start+length]
  if len(body)!=length:raise ValueError('truncated archive member')
  if header[:3]==b'#1/':body=body[int(header[3:16].strip()):]
  if body[:4]==b'\xcf\xfa\xed\xfe':
   arch={0x100000c:'arm64',0x1000007:'x86_64'}.get(struct.unpack_from('<I',body,4)[0])
   if arch is None:raise ValueError('unsupported static object architecture')
   arches.add(arch)
  at=start+length+(length%2)
 if len(arches)!=1:raise ValueError('static archive must contain one known architecture')
 return arches.pop()

def archive_slices(data):
 if data.startswith(b'!<arch>\n'):return {archive_arch(data):data}
 if data[:4]!=b'\xca\xfe\xba\xbe' or len(data)<8:raise ValueError('invalid universal static library')
 count=struct.unpack_from('>I',data,4)[0]
 if count!=2 or len(data)<8+20*count:raise ValueError('two simulator library slices required')
 result={}
 for i in range(count):
  cpu,sub,offset,size,align=struct.unpack_from('>IIIII',data,8+i*20)
  arch={0x100000c:'arm64',0x1000007:'x86_64'}.get(cpu)
  if not arch or arch in result or offset<8+20*count or offset+size>len(data):raise ValueError('invalid simulator library bounds')
  value=data[offset:offset+size]
  if not value.startswith(b'!<arch>\n'):raise ValueError('simulator slice is not a static library')
  if archive_arch(value)!=arch:raise ValueError('simulator fat header and archive disagree')
  result[arch]=value
 return result

def ios_framework(base,vm):
 framework=base/'Lua.xcframework'
 info=plistlib.loads((framework/'Info.plist').read_bytes())
 rows=info.get('AvailableLibraries',[])
 if len(rows)!=2:raise ValueError('device and simulator frameworks required')
 seen=set()
 for row in rows:
  if row.get('SupportedPlatform')!='ios':raise ValueError('non-iOS framework slice')
  kind='simulator' if row.get('SupportedPlatformVariant')=='simulator' else 'device'
  if kind in seen:raise ValueError('duplicate framework platform')
  seen.add(kind)
  data=child(framework,row['LibraryIdentifier']+'/'+row['LibraryPath']).read_bytes()
  bodies=archive_slices(data)
  expected={'arm64','x86_64'} if kind=='simulator' else {'arm64'}
  if set(bodies)!=expected or set(row.get('SupportedArchitectures',[]))!=expected:raise ValueError('framework architectures disagree')
  for arch,value in bodies.items():
   label=('sim-' if kind=='simulator' else 'device-')+arch
   if hashlib.sha256(value).hexdigest()!=vm['results']['extended-'+label]['librarySha256']:
    raise ValueError('framework contains a different runtime archive')
   for name,value in vm['results']['extended-'+label]['headers'].items():
    if sha(child(framework,row['LibraryIdentifier']+'/'+row['HeadersPath']+'/'+name))!=value:
     raise ValueError('framework public headers differ from the qualified slice')

def verify(path,platform,engine):
 path=Path(path).resolve();base=path.parent;manifest=json.loads(path.read_text())
 if platform not in ('android','ios'):raise ValueError('unsupported mobile platform')
 if not (manifest.get('schema')==1 and manifest.get('platform')==platform and manifest.get('capacity')==120
         and manifest.get('experimental') is True):raise ValueError('unsupported mobile runtime component')
 if any(x.is_symlink() for x in base.rglob('*')):raise ValueError('component symlinks are not accepted')
 expected={str(x.relative_to(base)) for x in base.rglob('*') if x.is_file() and x!=path}
 if set(manifest.get('files',{}))!=expected:raise ValueError('incomplete component file checksum roster')
 for name,value in manifest['files'].items():
  target=child(base,name)
  if target.is_symlink() or sha(target)!=value:raise ValueError('mobile component checksum mismatch: '+name)
 if platform=='android':
  seen=set()
  for row in manifest['qualifications']:
   abi,vm,host=android_gate(child(base,row['vm']),child(base,row['host']),child(base,row['execution']),engine)
   if abi in seen:raise ValueError('duplicate Android ABI')
   seen.add(abi)
   for name in ('libluajit.a',*HEADERS):
    if sha(base/'libraries'/abi/name)!=vm['results']['extended-'+abi]['files'][name]:raise ValueError('selected Android bytes differ')
  if seen!=set(ABIS):raise ValueError('all shipping Android ABIs must pass')
  for name in HEADERS:
   if len({sha(base/'libraries'/abi/name) for abi in ABIS})!=1:raise ValueError('Android public headers disagree between ABIs')
 else:
  if len(manifest['qualifications'])!=1:raise ValueError('one complete iOS qualification required')
  row=manifest['qualifications'][0];vm,host=ios_gate(child(base,row['vm']),child(base,row['host']))
  ios_framework(base,vm)
  for label in ('device-arm64','sim-arm64','sim-x86_64'):
   if sha(base/'libraries'/label/'libluajit.a')!=vm['results']['extended-'+label]['librarySha256']:raise ValueError('selected iOS bytes differ')
  for name,value in host['engineTree'].items():
   observed=subprocess.check_output(['git','rev-parse','HEAD:'+name],cwd=engine,text=True).strip()
   if observed!=value:raise ValueError('iOS engine source tree mismatch')
 return manifest

def install(path,platform,engine,destination=None):
 path=Path(path).resolve();manifest=verify(path,platform,engine);base=path.parent
 if platform=='android':
  root=engine/'mobile/android/love/src/jni/LuaJIT-2.1'
  for abi in ABIS:
   for name in ('libluajit.a',*HEADERS):shutil.copyfile(base/'libraries'/abi/name,root/'android'/abi/name)
  for name in HEADERS:
   values={sha(base/'libraries'/abi/name) for abi in ABIS}
   if len(values)!=1:raise ValueError('Android public headers disagree between ABIs')
   shutil.copyfile(base/'libraries/arm64-v8a'/name,root/'src'/name)
 else:
  target=Path(destination)
  if target.name!='Lua.xcframework':raise ValueError('explicit generated Lua.xcframework target required')
  if target.exists():shutil.rmtree(target)
  shutil.copytree(base/'Lua.xcframework',target)
 return {'capacity':120,'experimental':True,'componentManifestSha256':sha(path),
   'platform':platform,'architectures':list(ABIS) if platform=='android' else ['arm64'],
   'actualHostQualification':True,'physicalDeviceVerified':False,
   'jitCompilationAvailable':platform=='android',
   'jitDefaultOn':{'arm64-v8a':False,'armeabi-v7a':False,'x86_64':True} if platform=='android' else False,
   'source':manifest['source']}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--platform',choices=['android','ios'],required=True)
 p.add_argument('--engine-root',type=Path,default=ROOT);p.add_argument('--candidate',type=Path,action='append',required=True);p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();engine=a.engine_root.resolve();out=a.output.resolve();candidates=[x.resolve() for x in a.candidate]
 if out.exists() or any(out.is_relative_to(x) or x.is_relative_to(out) for x in candidates):p.error('output must be new and separate')
 if not os.getenv('GITHUB_ACTIONS'):
  sys.path.insert(0,str(ROOT/'tools'));import qa_storage as qa
  qa._storage=qa.Storage(ROOT);atexit.register(qa._storage.close)
  for x in (ROOT,engine,*candidates):qa.qa_source(x)
  qa.qa_cache(out.parent);qa.qa_copy(out)
 out.mkdir(parents=True);qualifications=[];seen=set()
 for candidate in candidates:
  reports=[(x,json.loads(x.read_text())) for x in candidate.rglob('report.json')]
  if a.platform=='android':
   vm_path=next(x for x,r in reports if 'sourceRelease' in r)
   host_path=next(x for x,r in reports if 'mobileSourceSha256' in r)
   execution_path=next(x for x,r in reports if r.get('loveHostAbiQualified') is True)
   abi,vm,host=android_gate(vm_path,host_path,execution_path,engine)
   if abi in seen:raise ValueError('duplicate Android ABI candidate')
   seen.add(abi)
   dest=out/'libraries'/abi;dest.mkdir(parents=True)
   for name in ('libluajit.a',*HEADERS,'COPYRIGHT'):
    src=vm_path.parent/'artifacts/extended'/abi/name
    if sha(src)!=vm['results']['extended-'+abi]['files'][name]:raise ValueError('Android artifact changed')
    shutil.copyfile(src,dest/name)
   row={}
   for key,path in [('vm',vm_path),('host',host_path),('execution',execution_path)]:
    relative='reports/'+abi+'-'+key+'.json';target=out/relative;target.parent.mkdir(exist_ok=True);shutil.copyfile(path,target);row[key]=relative
   qualifications.append(row)
  else:
   vm_path=next(x for x,r in reports if r.get('platform')=='ios' and 'luaJitSource' in r)
   host_path=next(x for x,r in reports if r.get('loveHostAbiQualified') is True)
   vm,host=ios_gate(vm_path,host_path)
   shutil.copytree(vm_path.parent/'artifacts/extended/Lua.xcframework',out/'Lua.xcframework')
   for label in ('device-arm64','sim-arm64','sim-x86_64'):
    dest=out/'libraries'/label;dest.mkdir(parents=True)
    for name in ('libluajit.a','COPYRIGHT'):shutil.copyfile(vm_path.parent/'artifacts/extended'/label/name,dest/name)
   (out/'reports').mkdir();shutil.copyfile(vm_path,out/'reports/vm.json');shutil.copyfile(host_path,out/'reports/host.json')
   qualifications.append({'vm':'reports/vm.json','host':'reports/host.json'})
 if a.platform=='android' and seen!=set(ABIS):raise ValueError('all shipping Android ABIs required')
 manifest={'schema':1,'platform':a.platform,'experimental':True,'capacity':120,
   'source':'vendored Android LuaJIT 1700008891' if a.platform=='android' else PIN,
   'qualifications':qualifications,'files':{str(x.relative_to(out)):sha(x) for x in out.rglob('*') if x.is_file()}}
 path=out/'component.json';path.write_text(json.dumps(manifest,indent=2)+'\n');verify(path,a.platform,engine)
 print('QUALIFIED_MOBILE_COMPONENT',path,flush=True)
if __name__=='__main__':main()
