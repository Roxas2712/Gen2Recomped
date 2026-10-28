#!/usr/bin/env python3
"""Package reviewed macOS peer transport with relative TLS dependencies/licenses.
Called inside the release builder's qa_storage guard. By Roxas2712.
"""
import ctypes,hashlib,importlib.metadata,json,re,shutil,sys
from pathlib import Path,PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
PIN='6b1e2e620f1e37f0eafeee702eaea0043cb305fd'
def package(build,out,ca):
 import qa_storage as qa
 build=Path(build);out=Path(out);ca=Path(ca);source=build.parent/'libdatachannel'
 for p in(build,source,ca):qa.qa_source(p)
 assert not out.exists(),'Preserve an existing peer runtime'
 def run(args):return qa.qa_run(list(map(str,args)),capture_output=True,text=True,check=True).stdout
 assert run(['git','-C',source,'rev-parse','HEAD']).strip()==PIN
 run(['git','-C',source,'diff','--quiet'])
 cache=(build/'CMakeCache.txt').read_text()
 def value(k):return Path(re.search(r'^'+re.escape(k)+r':[^=]+=([^\n]+)',cache,re.M)[1])
 native_source=value('retro_peer_SOURCE_DIR')
 assert (native_source/'bridge.cpp').read_bytes()==(ROOT/'tools/peer_native/bridge.cpp').read_bytes()
 ssl=value('OPENSSL_SSL_LIBRARY');crypto=value('OPENSSL_CRYPTO_LIBRARY')
 for p in(ssl,crypto):qa.qa_source(p)
 out.mkdir(parents=True);licenses=out/'licenses';licenses.mkdir()
 inputs={'libretro_peer.dylib':build/'libretro_peer.dylib','libssl.3.dylib':ssl,'libcrypto.3.dylib':crypto}
 for name,p in inputs.items():shutil.copy2(p,out/name)
 for name in inputs:
  path=out/name;run(['install_name_tool','-id','@loader_path/'+name,path])
  for dependency in('libssl.3.dylib','libcrypto.3.dylib'):
   if '@rpath/'+dependency in run(['otool','-L',path]):run(['install_name_tool','-change','@rpath/'+dependency,'@loader_path/'+dependency,path])
  commands=run(['otool','-l',path])
  for rpath in re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.+?) \(offset',commands):
   if not rpath.startswith('@'):run(['install_name_tool','-delete_rpath',rpath,path])
 for name in('libcrypto.3.dylib','libssl.3.dylib','libretro_peer.dylib'):run(['codesign','--force','--sign','-',out/name])
 shutil.copy2(ca,out/'ca.pem')
 for name,p in {'libdatachannel-MPL-2.0.txt':source/'LICENSE','libjuice-MIT.txt':source/'deps/libjuice/LICENSE','usrsctp-BSD.txt':source/'deps/usrsctp/LICENSE.md','plog-MIT.txt':source/'deps/plog/LICENSE','json-MIT.txt':source/'deps/json/LICENSE.MIT','OpenSSL-Apache-2.0.txt':ROOT/'tools/peer_native/third_party/OPENSSL-LICENSE.txt','Roxas2712-contributions.md':ROOT/'LICENSE-ROXAS2712.md'}.items():shutil.copy2(p,licenses/name)
 certifi=importlib.metadata.distribution('certifi');license_text=certifi.read_text('licenses/LICENSE')or certifi.read_text('LICENSE');assert license_text
 (licenses/'certifi-MPL-2.0.txt').write_text(license_text)
 provenance={'libdatachannel':{'revision':PIN,'source':'https://github.com/paullouisageneau/libdatachannel/tree/'+PIN},'OpenSSL':{'version':'3.6.2','source':'https://github.com/openssl/openssl/tree/openssl-3.6.2'},'certifi':{'version':certifi.version,'source':'https://github.com/certifi/python-certifi'},'bridge':{'source':'https://github.com/Roxas2712/Gen2Recomped/tree/codex/pinball-demo-artwork/tools/peer_native','sha256':hashlib.sha256((ROOT/'tools/peer_native/bridge.cpp').read_bytes()).hexdigest()},'submodules':run(['git','-C',source,'submodule','status']).strip().splitlines()}
 (out/'SOURCES.txt').write_text('Unmodified covered library source is available at the exact revisions below.\nClone libdatachannel recursively and check out the pinned revision. Build the original bridge with tools/peer_native/CMakeLists.txt from the linked public fork. No media codec or game data is included.\n\n'+json.dumps(provenance,indent=2)+'\n')
 files={str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest()for p in out.rglob('*')if p.is_file()}
 (out/'runtime.json').write_text(json.dumps({'schema':1,'platform':'macos-arm64','abi':1,'files':files,'sources':provenance},indent=2)+'\n')
 return verify(out)
def verify(out):
 import qa_storage as qa
 out=Path(out);manifest=json.loads((out/'runtime.json').read_text())
 assert manifest['platform']=='macos-arm64'and manifest['abi']==1
 for name,digest in manifest['files'].items():
  path=PurePosixPath(name);assert not path.is_absolute()and '..'not in path.parts
  assert (out/name).resolve().is_relative_to(out.resolve()),name
  assert hashlib.sha256((out/name).read_bytes()).hexdigest()==digest,name
 assert {str(p.relative_to(out))for p in out.rglob('*')if p.is_file()}==set(manifest['files'])|{'runtime.json'},'Unlisted peer runtime file'
 for name in('libretro_peer.dylib','libssl.3.dylib','libcrypto.3.dylib'):
  text=qa.qa_run(['otool','-L',str(out/name)],capture_output=True,text=True,check=True).stdout
  for line in text.splitlines()[1:]:
   dependency=line.strip().split(' (',1)[0]
   assert dependency.startswith(('@loader_path/','/usr/lib/','/System/Library/')),dependency
  qa.qa_run(['codesign','--verify','--strict',str(out/name)],capture_output=True,check=True)
 lib=ctypes.CDLL(str(out/'libretro_peer.dylib'));lib.rr_version.restype=ctypes.c_int;assert lib.rr_version()==manifest['abi']
 crypto=ctypes.CDLL(str(out/'libcrypto.3.dylib'));crypto.OpenSSL_version.restype=ctypes.c_char_p
 assert crypto.OpenSSL_version(0).decode().startswith('OpenSSL 3.6.2 ')
 return manifest
