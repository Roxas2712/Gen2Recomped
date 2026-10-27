"""Synthetic mod packages and settings; no game-derived content."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import pokemon_xy_library as lib
import pokemon_x_preflight as preflight
from pokemon_x_preflight_test import ncch

class LibraryTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP'));self.addCleanup(self.temp.cleanup)
  self.work=Path(self.temp.name);self.patch=patch.object(lib,'WORK',self.work);self.patch.start();self.addCleanup(self.patch.stop)
 def test_y_decrypted_with_stale_crypto_flag_is_accepted_by_hashes(self):
  p=self.work/'y.3ds';p.write_bytes(ncch(title=0x0004000000055E00,no_crypto=False))
  self.assertEqual(preflight.inspect(p)['status'],'headers_verified_boot_untested')
 def test_configuration_retains_upstream_tables_and_other_edition(self):
  x=lib.setting_path('x');x.parent.mkdir(parents=True);x.write_text('resolution = 2\nunknown = 17\n[keys]\na = "KeyX"\n')
  lib.configure('x',{'resolution':4,'layout':'overlay','stereo':'anaglyph'})
  text=x.read_text();self.assertIn('unknown = 17',text);self.assertIn('[keys]\na = "KeyX"',text)
  self.assertEqual(lib.settings('x')['layout'],'overlay');self.assertEqual(lib.settings('y')['resolution'],3)
 def test_configuration_rejects_invalid_type_and_range_without_writing(self):
  for change in [{'resolution':True},{'resolution':99},{'layout':'oops'},{'texture_packs':'true'},{'overlay_size':0},{'overlay_x':101},{'hide_empty_touch':1}]:
   with self.assertRaises(ValueError):lib.configure('x',change)
  self.assertFalse(lib.setting_path('x').exists())
 def test_mod_toggle_round_trip_keeps_bytes(self):
  p=lib.mod_dir('x')/'romfs/a';p.parent.mkdir(parents=True);p.write_bytes(b'original mod')
  lib.toggle_mods('x');self.assertFalse(p.exists());self.assertEqual((lib.disabled_dir('x')/'romfs/a').read_bytes(),b'original mod')
  lib.toggle_mods('x');self.assertEqual(p.read_bytes(),b'original mod')
 def test_language_reset_parks_preference_without_changing_game_save_or_other_edition(self):
  root=self.work/'player';root.mkdir();save=root/'savegame.dat';save.write_bytes(b'existing adventure')
  preference=root/'language-y.json';preference.write_text('{"version":1,"language":"german"}')
  other=root/'language-x.json';other.write_text('{"version":1,"language":"english"}')
  self.assertEqual(lib.language_preference('y'),'german');lib.reset_language('y')
  self.assertIsNone(lib.language_preference('y'));self.assertEqual(save.read_bytes(),b'existing adventure')
  self.assertEqual(lib.language_preference('x'),'english');self.assertTrue(preference.with_suffix('.json.previous').is_file())
 def package(self,rows):
  p=self.work/'package.zip'
  with zipfile.ZipFile(p,'w') as z:
   for name,data in rows:z.writestr(name,data)
  return p
 def test_zip_wrapper_import_and_collision_do_not_overwrite(self):
  p=self.package([('CoolPack/romfs/a',b'one'),('CoolPack/textures/test.png',b'two')])
  self.assertEqual(lib.install_mod('x',p),2)
  with self.assertRaises(ValueError):lib.install_mod('x',p)
  self.assertEqual((lib.mod_dir('x')/'romfs/a').read_bytes(),b'one')
  self.assertFalse(lib.mod_dir('y').exists())
 def test_romfs_bps_patch_root_is_preserved_for_backend(self):
  p=self.package([('VisibleTest/romfs_ext/a/0/7/4.bps',b'BPS1 synthetic fixture')])
  self.assertEqual(lib.install_mod('y',p),1)
  self.assertEqual((lib.mod_dir('y')/'romfs_ext/a/0/7/4.bps').read_bytes(),b'BPS1 synthetic fixture')
 def test_zip_traversal_rejected_before_any_write(self):
  for name in ['romfs/../../escape','/romfs/escape','romfs\\..\\escape']:
   p=self.package([(name,b'bad'),('romfs/good',b'data')])
   with self.assertRaises(ValueError):lib.install_mod('x',p)
   self.assertFalse(lib.mod_dir('x').exists())
 def test_source_and_destination_symlinks_rejected(self):
  source=self.work/'source';source.mkdir();(source/'romfs').mkdir();(source/'romfs/a').symlink_to(self.work/'outside')
  with self.assertRaises(ValueError):lib.install_mod('x',source)
  source2=self.work/'source2/romfs';source2.mkdir(parents=True);(source2/'a').write_bytes(b'data')
  target=lib.mod_dir('x');target.mkdir(parents=True);outside=self.work/'outside';outside.mkdir();(target/'romfs').symlink_to(outside,target_is_directory=True)
  with self.assertRaises(ValueError):lib.install_mod('x',source2.parent)
  self.assertEqual(list(outside.iterdir()),[])

if __name__=='__main__':unittest.main()

class LaunchSequenceTests(unittest.TestCase):
 def test_library_build_finishes_before_intro_then_game(self):
  from types import SimpleNamespace
  from unittest.mock import Mock
  import pokemon_x_backend as backend
  with tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP')) as folder:
   work=Path(folder)
   compiler=work/'compiler';runtime=work/'runtime';intro=work/'Recompiled Ascendant.app/Contents/MacOS/love'
   for path in [compiler,runtime,intro]:path.parent.mkdir(parents=True,exist_ok=True);path.write_text('test fixture');path.chmod(0o700)
   qa=Mock();qa.qa_run.return_value=SimpleNamespace(returncode=0)
   result={'status':'headers_verified_boot_untested','title_id':preflight.POKEMON_X_USA,'sha256':'a'*64}
   storage=SimpleNamespace(prepare=Mock(),clean_linked_objects=Mock())
   with patch.object(backend,'WORK',work),patch.object(backend.preflight,'qa_manager',return_value=qa),patch.object(backend.preflight,'inspect',return_value=result),patch.object(backend.library,'register'),patch.dict(sys.modules,{'qa_build_storage':storage}):
    self.assertEqual(backend.main(['play',str(work/'rom'),'--runtime',str(runtime),'--recompiler',str(compiler)]),0)
   self.assertEqual([Path(call.args[0][0]) for call in qa.qa_run.call_args_list],[compiler,intro,runtime])
