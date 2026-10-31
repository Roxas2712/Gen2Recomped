"""Preserve sources, models and final binaries during qualified Rust retirement."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import os,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_windows_native_runtime import retire_rust_objects

class QualifiedRetirement(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP'));self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name);self.target=self.root/'target';self.sdk=self.root/'sdk'
  for source,installed in [('release/3dsrecomp.exe','bin/3dsrecomp.exe'),('release/ascendant_3ds_bridge.dll','lib/ascendant_3ds_bridge.dll')]:
   for file in [self.target/source,self.sdk/installed]:file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(b'own final binary')
 def put(self,name):
  file=self.target/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(b'own fixture');return file
 def test_only_compiled_intermediates_are_retired(self):
  removed=[self.put(n)for n in ['release/deps/own.rlib','release/deps/own.rmeta','release/build/own/out/own.a']]
  retained=[self.put(n)for n in ['release/deps/own.rs','release/build/own/out/own.cpp','release/deps/model.bin','release/deps/models/own.rlib','release/deps/saves/own.obj','release/deps/own.dll']]
  retire_rust_objects(self.target,self.sdk)
  self.assertTrue(all(not p.exists()for p in removed));self.assertTrue(all(p.read_bytes()==b'own fixture'for p in retained))
  self.assertEqual((self.target/'release/3dsrecomp.exe').read_bytes(),b'own final binary')
  self.assertEqual((self.target/'release/ascendant_3ds_bridge.dll').read_bytes(),b'own final binary')
 def test_mismatch_keeps_every_intermediate(self):
  file=self.put('release/deps/own.rlib');(self.sdk/'lib/ascendant_3ds_bridge.dll').write_bytes(b'different')
  with self.assertRaises(ValueError):retire_rust_objects(self.target,self.sdk)
  self.assertEqual(file.read_bytes(),b'own fixture')

if __name__=='__main__':unittest.main()
