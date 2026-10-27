"""A completed game retires only its byte-identical compiler-cache copies."""
import hashlib,json,os,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import qa_build_storage as storage

class CompilerCacheTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=os.getenv('POKEMON_X_TEST_TMP'));self.addCleanup(self.temp.cleanup)
  self.work=Path(self.temp.name);self.output=self.work/'recompiled'/('a'*64);self.output.mkdir(parents=True)
  self.binary=self.output/'0004000000055E00.dylib';self.binary.write_bytes(b'own synthetic linked fixture')
  self.marker=self.binary.with_suffix('.complete.json');self.marker.write_text(json.dumps({'sha256':hashlib.sha256(self.binary.read_bytes()).hexdigest()}))
  self.obj=self.output/'code001.o';self.obj.write_bytes(b'own synthetic object');(self.output/'code001.c').write_text('own C fixture')
  self.cache=self.work/'compiler-cache/local/o'/('b'*32);self.cache.mkdir(parents=True)
  self.duplicate=self.cache/self.obj.name;self.duplicate.write_bytes(self.obj.read_bytes())
  patcher=patch.object(storage.LiveUse,'busy',return_value=False);patcher.start();self.addCleanup(patcher.stop)
 def test_only_identical_owned_objects_are_retired_after_a_committed_link(self):
  foreign=self.cache/'code002.o';foreign.write_bytes(b'foreign cache entry')
  manifests=self.work/'compiler-cache/local/h';manifests.mkdir()
  content=b'preserve synthetic Zig cache metadata';manifest=manifests/('c'*32+'.txt');manifest.write_bytes(content)
  untouched=manifests/'user.txt';untouched.write_bytes(b'foreign metadata')
  self.assertGreater(storage.clean_compiler_duplicates(self.work,self.output),0)
  self.assertFalse(self.duplicate.exists());self.assertTrue(foreign.exists())
  self.assertTrue(self.obj.exists());self.assertTrue(self.binary.exists());self.assertTrue(self.obj.with_suffix('.c').exists())
  self.assertFalse(manifest.exists());self.assertTrue(untouched.exists())
  self.assertEqual((self.work/'compiler-cache/retired-manifests'/(hashlib.sha256(content).hexdigest()+'.txt')).read_bytes(),content)
 def test_manifest_redirection_preserves_objects(self):
  elsewhere=self.work/'foreign';elsewhere.mkdir();(self.work/'compiler-cache/local/h').symlink_to(elsewhere)
  with self.assertRaises(ValueError):storage.clean_compiler_duplicates(self.work,self.output)
  self.assertTrue(self.duplicate.exists())
 def test_interrupted_or_changed_final_library_preserves_the_cache(self):
  self.binary.write_bytes(b'changed final library')
  self.assertEqual(storage.clean_compiler_duplicates(self.work,self.output),0);self.assertTrue(self.duplicate.exists())
 def test_same_named_foreign_object_or_missing_c_peer_is_preserved(self):
  self.duplicate.write_bytes(b'X'*len(self.obj.read_bytes()))
  self.assertEqual(storage.clean_compiler_duplicates(self.work,self.output),0)
  self.duplicate.write_bytes(self.obj.read_bytes());self.obj.with_suffix('.c').unlink()
  self.assertEqual(storage.clean_compiler_duplicates(self.work,self.output),0);self.assertTrue(self.duplicate.exists())
 def test_symlinks_and_live_builds_are_not_retired(self):
  self.duplicate.unlink();self.duplicate.symlink_to(self.obj)
  self.assertEqual(storage.clean_compiler_duplicates(self.work,self.output),0)
  self.assertTrue(self.duplicate.is_symlink())
  self.duplicate.unlink();self.duplicate.write_bytes(self.obj.read_bytes())
  with patch.object(storage.LiveUse,'busy',return_value=True):
   self.assertEqual(storage.clean_compiler_duplicates(self.work,self.output),0)
  self.assertTrue(self.duplicate.exists())

if __name__=='__main__':unittest.main()
