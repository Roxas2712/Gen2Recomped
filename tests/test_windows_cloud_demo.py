"""Archive validation only; does not execute a Windows binary."""
import importlib.util,io,struct,sys,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('windows_demo_builder',ROOT/'tools/build_windows_cloud_demo.py')
B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
class WindowsDemoPackaging(unittest.TestCase):
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
if __name__=='__main__':unittest.main()
