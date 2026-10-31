"""Archive validation only; does not execute a Windows binary."""
import importlib.util,io,struct,sys,unittest,zipfile,tempfile,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('windows_demo_builder',ROOT/'tools/build_windows_cloud_demo.py')
B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
class WindowsDemoPackaging(unittest.TestCase):
 def test_native_host_stack_matches_the_gba_runtime_without_reducing_larger_hosts(self):
  body=bytearray(400);body[:2]=b'MZ';struct.pack_into('<I',body,60,64);body[64:68]=b'PE\0\0';struct.pack_into('<H',body,68,0x8664)
  optional=88;struct.pack_into('<H',body,optional,0x20b);struct.pack_into('<Q',body,optional+72,1024**2);struct.pack_into('<Q',body,optional+88,123456)
  updated,reserve=B.native_host_stack(body)
  self.assertEqual(reserve,16*1024**2);self.assertEqual(struct.unpack_from('<Q',updated,optional+88)[0],123456)
  struct.pack_into('<Q',body,optional+72,32*1024**2)
  self.assertEqual(B.native_host_stack(body)[1],32*1024**2)
  with self.assertRaises(ValueError):B.native_host_stack(body[:120])
 def test_paths(self):
  for path in ['../save.lua','C:/private','/private','saves\\slot.lua']:
   with self.subTest(path=path),self.assertRaises(ValueError):B.safe(path)
 def test_machine(self):
  b=bytearray(96);b[:2]=b'MZ';struct.pack_into('<I',b,60,64);b[64:68]=b'PE\0\0';struct.pack_into('<H',b,68,0x8664);B.pe(b)
  struct.pack_into('<H',b,68,0x14c)
  with self.assertRaises(ValueError):B.pe(b)
 def test_private_content(self):
  for path in ['cartridge.gba','saves/red/slot1.lua','cloud_retro.lua','cloud_outbox.lua','storage_account.lua','data/generated/rom.lua','profiles/17/options.lua','portable.txt']:
   stream=io.BytesIO()
   with zipfile.ZipFile(stream,'w')as z:z.writestr(path,'fixture')
   stream.seek(0)
   with zipfile.ZipFile(stream)as z,self.subTest(path=path),self.assertRaises(ValueError):B.audit_payload(z)
 def test_code_fixtures_are_distinct_from_player_journals(self):
  stream=io.BytesIO()
  names=['main.lua','conf.lua','src/storage/CloudOutbox.lua','src/storage/CloudSetup.lua',
   'src/cloud/http_worker.lua','tools/windows-demo/Profile.lua','tools/windows-demo/SelfTest.lua',
   'tests/engine/fixture-cloud_outbox.lua']
  with zipfile.ZipFile(stream,'w')as z:
   for name in names:z.writestr(name,'synthetic code fixture')
  stream.seek(0)
  with zipfile.ZipFile(stream)as z:B.audit_payload(z)
 def test_native_sdk_requires_native_report_and_matching_source(self):
  with tempfile.TemporaryDirectory()as folder:
   base=Path(folder);bundle=base/'bundle';bundle.mkdir();archive=base/'sdk.zip';report=base/'report.json'
   members={'runtime.json':json.dumps({'game_data_included':False}).encode(),'source.json':json.dumps({'schema':1,'trees':{'tools/bridge':'current-tree'}}).encode(),'bin/own-fixture.exe':b'own fixture'}
   inventory=json.dumps({name:hashlib.sha256(body).hexdigest()for name,body in members.items()}).encode()
   with zipfile.ZipFile(archive,'w')as z:
    for name,body in {**members,'files.json':inventory}.items():z.writestr('3ds-runtime/'+name,body)
   result={'passed':False,'platform':'Windows','checks':[{'passed':True}],'sdkManifestSha256':hashlib.sha256(inventory).hexdigest()}
   report.write_text(json.dumps(result))
   with self.assertRaises(ValueError):B.install_native_sdk(archive,report,bundle,lambda p:'current-tree')
   result['passed']=True;report.write_text(json.dumps(result))
   with self.assertRaises(ValueError):B.install_native_sdk(archive,report,bundle,lambda p:'different-tree')
   summary=B.install_native_sdk(archive,report,bundle,lambda p:'current-tree')
   self.assertFalse(summary['realCartridgeGameplay']);self.assertEqual((bundle/'3ds-runtime/bin/own-fixture.exe').read_bytes(),b'own fixture')
 def test_native_sdk_rejects_private_game_files(self):
  with tempfile.TemporaryDirectory()as folder:
   base=Path(folder);archive=base/'sdk.zip';report=base/'report.json';bundle=base/'bundle'
   report.write_text(json.dumps({'passed':True,'platform':'Windows','checks':[{'passed':True}]}))
   with zipfile.ZipFile(archive,'w')as z:z.writestr('3ds-runtime/private.gba',b'fixture')
   with self.assertRaises(ValueError):B.install_native_sdk(archive,report,bundle,lambda p:'unused')
if __name__=='__main__':unittest.main()
