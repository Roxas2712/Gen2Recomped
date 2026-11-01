"""Portable Windows metadata/cache checks; no native execution claims."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import json,os,struct,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import pokemon_xy_runtime as R

class WindowsRuntime(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP'));self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name)
 def test_windows_manifest_and_missing_components(self):
  data={'schema':1,'bridge_protocol':1,'platform':'windows-x64','id':'a'*64}
  (self.root/'runtime.json').write_text(json.dumps(data))
  with patch.object(R.platform,'system',return_value='Windows'),patch.object(R.platform,'machine',return_value='AMD64'),patch.object(R,'FILES',R.FILES_WINDOWS):
   with self.assertRaises(ValueError):R.load(self.root)
   for relative in R.FILES.values():
    file=self.root/relative;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(b'fixture')
   self.assertEqual(R.load(self.root)[1],data)
   self.assertEqual(R.environment(self.root,self.root/'work')['CC'],str(self.root/'compiler/bin/clang.exe'))
 def test_windows_dll_completion_and_tamper(self):
  file=self.root/'game.dll';body=bytearray(128);body[:2]=b'MZ';struct.pack_into('<I',body,60,64)
  body[64:68]=b'PE\0\0';struct.pack_into('<H',body,68,0x8664);struct.pack_into('<H',body,86,0x2000)
  with patch.object(R.platform,'system',return_value='Windows'):
   for partial in [b'MZ',body[:70],b'incomplete']:
    file.write_bytes(partial)
    with self.assertRaises(ValueError):R.finish(file,'rom','sdk')
    self.assertFalse(file.with_suffix('.complete.json').exists())
   file.write_bytes(body);R.finish(file,'rom','sdk')
   self.assertTrue(R.completed(file,'rom','sdk'))
   self.assertFalse(R.completed(file,'rom','different-sdk'))
   file.write_bytes(body+b'changed');self.assertFalse(R.completed(file,'rom','sdk'))
 def test_wrong_windows_machine_cannot_be_marked_complete(self):
  file=self.root/'game.dll';body=bytearray(128);body[:2]=b'MZ';struct.pack_into('<I',body,60,64)
  body[64:68]=b'PE\0\0';struct.pack_into('<H',body,68,0x14c);struct.pack_into('<H',body,86,0x2000);file.write_bytes(body)
  with patch.object(R.platform,'system',return_value='Windows'),self.assertRaises(ValueError):R.finish(file,'rom','sdk')

if __name__=='__main__':unittest.main()
