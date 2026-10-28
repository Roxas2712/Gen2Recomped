"""Game-data-free runtime identity, interrupted builds and compiler isolation."""
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import pokemon_xy_runtime as runtime
from build_pokemon_xy_runtime import compilation_identity


class RuntimeTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP'));self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name)
 def test_runtime_fingerprint_changes_without_changing_the_rom_identity(self):
  self.assertNotEqual(runtime.fingerprint('a'*64,'b'*64),runtime.fingerprint('a'*64,'c'*64))
  self.assertEqual(runtime.fingerprint('a'*64,None),'a'*64)
 def test_game_build_identity_includes_effective_compiler_wrapper(self):
  critical={'bin/3dsrecomp':'compiler','bin/cc':'wrapper-v1','compiler/zig':'zig'}
  before=compilation_identity(critical,'abi')
  critical['bin/cc']='wrapper-v2'
  self.assertNotEqual(before,compilation_identity(critical,'abi'))
  self.assertNotEqual(compilation_identity(critical,'abi'),compilation_identity(critical,'new-abi'))
 def test_no_cache_hit_until_a_complete_library_is_committed(self):
  binary=self.root/'game.dylib'
  binary.write_bytes(struct.pack('<IiiI',0xfeedfacf,0x100000c,0,6)+b'\0'*16+b'own synthetic fixture')
  self.assertFalse(runtime.completed(binary,'rom','runtime'))
  runtime.finish(binary,'rom','runtime')
  self.assertTrue(runtime.completed(binary,'rom','runtime'))
  self.assertFalse(runtime.completed(binary,'rom','other-runtime'))
  self.assertFalse(runtime.completed(binary,'other-rom','runtime'))
  binary.write_bytes(binary.read_bytes()+b'changed')
  self.assertFalse(runtime.completed(binary,'rom','runtime'))
 def test_interrupted_or_wrong_architecture_link_does_not_create_a_marker(self):
  binary=self.root/'partial.dylib';binary.write_bytes(b'partial link')
  with self.assertRaises(ValueError):runtime.finish(binary,'rom','runtime')
  self.assertFalse(binary.with_suffix('.complete.json').exists())
 def test_bundle_manifest_rejects_missing_files_and_wrong_platform(self):
  metadata={'schema':1,'bridge_protocol':1,'platform':'macos-arm64','id':'a'*64}
  (self.root/'runtime.json').write_text(json.dumps(metadata))
  with patch.object(runtime.platform,'system',return_value='Darwin'),patch.object(runtime.platform,'machine',return_value='arm64'),patch.object(runtime.platform,'mac_ver',return_value=('15.8.1',(),'')):
   with self.assertRaises(ValueError):runtime.load(self.root)
   for name in runtime.FILES.values():
    p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'fixture')
   self.assertEqual(runtime.load(self.root)[1]['id'],metadata['id'])
  with patch.object(runtime.platform,'system',return_value='Windows'):
   with self.assertRaises(ValueError):runtime.load(self.root)
 def test_compiler_with_spaces_uses_its_own_cache_and_not_a_shell_command(self):
  root=self.root/'My Demo.app';work=self.root/'profile';env=runtime.environment(root,work)
  self.assertEqual(env['CC'],str(root/'bin/cc'))
  self.assertEqual(env['RETRO_3DS_BUILD_JOBS'],'2')
  self.assertEqual(env['ZIG_GLOBAL_CACHE_DIR'],str(work/'compiler-cache/global'))
 def test_explicit_build_parallelism_is_bounded_and_invalid_values_fall_back(self):
  for value,expected in [('4','4'),('999','8'),('-1','1'),('invalid','2')]:
   with patch.dict(os.environ,{'RETRO_3DS_BUILD_JOBS':value}):
    self.assertEqual(runtime.environment(self.root,self.root/'work')['RETRO_3DS_BUILD_JOBS'],expected)


if __name__=='__main__':unittest.main()
