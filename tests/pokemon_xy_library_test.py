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
 def test_fresh_import_validates_and_registers_without_copy_or_false_readiness(self):
  p=self.work/'own y.cxi';p.write_bytes(ncch(title=0x0004000000055E00));before=p.read_bytes()
  self.assertEqual(lib.import_rom(p),'y')
  row=lib.status()['y'];self.assertTrue(row['imported']);self.assertFalse(row['ready'])
  self.assertEqual(row['rom'],str(p));self.assertEqual(p.read_bytes(),before)
  self.assertFalse((self.work/'recompiled').exists());self.assertNotIn('x',lib.manifest())
 def test_backend_cli_accepts_the_workers_argument_order_and_reports_detected_edition(self):
  import contextlib,io
  import pokemon_x_backend as backend
  p=self.work/'own y.cxi';p.write_bytes(ncch(title=0x0004000000055E00))
  output=io.StringIO()
  with contextlib.redirect_stdout(output):
   self.assertEqual(backend.main(['import','--edition','x',str(p),'--detect-edition']),0)
  self.assertIn('"imported_edition": "y"',output.getvalue())
 def test_host_workspace_keeps_import_metadata_out_of_the_helper_source_checkout(self):
  import contextlib,io
  import pokemon_x_backend as backend
  p=self.work/'own.cxi';p.write_bytes(ncch());workspace=self.work/'app-profile'
  with patch.object(backend,'ROOT',backend.ROOT),patch.object(backend,'WORK',backend.WORK),patch.object(backend,'CACHE',backend.CACHE),patch.object(preflight,'ROOT',preflight.ROOT),patch.object(lib,'ROOT',lib.ROOT),patch.object(lib,'WORK',lib.WORK),contextlib.redirect_stdout(io.StringIO()):
   self.assertEqual(backend.main(['import',str(p),'--root',str(workspace)]),0)
  self.assertTrue((workspace/'.local/pokemon-x/library.json').is_file())
  self.assertFalse((self.work/'library.json').exists());self.assertTrue(p.exists())
 def test_wrong_edition_corruption_and_truncation_preserve_previous_import(self):
  p=self.work/'x.cxi';p.write_bytes(ncch());lib.import_rom(p,'x');manifest=(self.work/'library.json').read_bytes()
  wrong=self.work/'wrong.cxi';wrong.write_bytes(ncch(title=0x0004000000055E00))
  broken=self.work/'broken.cxi';broken.write_bytes(ncch()[:-10])
  corrupt=self.work/'corrupt.cxi';data=bytearray(ncch());data[0x600]^=255;corrupt.write_bytes(data)
  for path in [wrong,broken,corrupt]:
   with self.assertRaises(ValueError):lib.import_rom(path,'x')
   self.assertEqual((self.work/'library.json').read_bytes(),manifest)
 def test_same_file_reimport_preserves_build_and_changed_file_invalidates_it(self):
  p=self.work/'x.cxi';p.write_bytes(ncch());lib.import_rom(p,'x');row=lib.manifest()['x']
  binary=self.work/'native.dylib';binary.write_bytes(b'fixture')
  lib.register('x',p,row['sha256'],binary);lib.import_rom(p,'x')
  self.assertTrue(lib.status()['x']['ready'])
  # A different complete dump needs its own native build.
  p.write_bytes(p.read_bytes()+b'different cartridge padding');lib.import_rom(p,'x')
  self.assertFalse(lib.status()['x']['ready']);self.assertTrue(binary.exists())
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
 def test_bundled_import_prepares_a_session_and_reuses_only_a_complete_build(self):
  import contextlib,io,json,hashlib,struct
  from types import SimpleNamespace
  from unittest.mock import Mock
  import pokemon_x_backend as backend
  with tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP')) as folder:
   base=Path(folder);work=base/'profile/.local/pokemon-x';runtime=base/'My Demo.app/3ds-runtime'
   for name in backend.runtime_bundle.FILES.values():
    p=runtime/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'synthetic component');p.chmod(0o700)
   rom=base/'own x.cxi';rom.write_bytes(ncch());rom_hash=hashlib.sha256(rom.read_bytes()).hexdigest()
   metadata={'id':'b'*64,'compilation_id':'c'*64};calls=[];qa=Mock()
   def run(command,**kwargs):
    calls.append(command)
    binary=Path(command[-1])/backend.library_name(preflight.POKEMON_X_USA)
    binary.parent.mkdir(parents=True,exist_ok=True)
    binary.write_bytes(struct.pack('<IiiI',0xfeedfacf,0x100000c,0,6)+b'\0'*16+b'synthetic game library'+str(len(calls)).encode())
    return SimpleNamespace(returncode=0)
   qa.qa_run.side_effect=run
   storage=SimpleNamespace(prepare=Mock(),clean_linked_objects=Mock(),clean_compiler_duplicates=Mock())
   variables={key:getattr(backend,key) for key in ['ROOT','WORK','CACHE','RUNTIME','RUNTIME_ID','RUNTIME_RELEASE']}
   with patch.multiple(backend,**variables),patch.object(preflight,'ROOT',preflight.ROOT),patch.object(backend.library,'ROOT',backend.library.ROOT),patch.object(backend.library,'WORK',backend.library.WORK),patch.object(backend.library,'RUNTIME_ID',None),patch.object(backend.preflight,'qa_manager',return_value=qa),patch.object(backend.runtime_bundle,'load',return_value=(runtime,metadata)),patch.dict(sys.modules,{'qa_build_storage':storage}):
    argv=['import',str(rom),'--edition','x','--root',str(base/'profile'),'--runtime-root',str(runtime),'--play-after-import']
    for attempt in range(2):
     text=io.StringIO()
     with contextlib.redirect_stdout(text):self.assertEqual(backend.main(argv),0)
     messages=[json.loads(line) for line in text.getvalue().splitlines() if line.startswith('{')]
     session=next(row['native_session'] for row in messages if 'native_session' in row)
     self.assertEqual(session['bridge'],str(runtime/'lib/libascendant_3ds_bridge.dylib'))
     self.assertIn(metadata['id'],session['profile_key'])
     self.assertEqual(session['driver_manifest'],str(runtime/'vulkan/MoltenVK_icd.json'))
    self.assertEqual(len(calls),1,'complete imports reuse the compiled game')
    with contextlib.redirect_stdout(io.StringIO()):
     self.assertEqual(backend.main(['build',str(rom),'--edition','x','--root',str(base/'profile'),'--runtime-root',str(runtime)]),0)
    self.assertTrue(backend.runtime_bundle.completed(Path(session['library']),rom_hash,metadata['compilation_id']),'a forced rebuild refreshes its completion digest before cached objects are retired')
    self.assertEqual(len(calls),2)
    binary=Path(session['library']);binary.write_bytes(binary.read_bytes()+b'changed after completion')
    with contextlib.redirect_stdout(io.StringIO()):self.assertEqual(backend.main(argv),0)
    self.assertEqual(len(calls),3,'changed library bytes force preparation again')
 def test_library_build_finishes_before_intro_then_game(self):
  from types import SimpleNamespace
  from unittest.mock import Mock
  import pokemon_x_backend as backend
  with tempfile.TemporaryDirectory(dir=os.environ.get('POKEMON_X_TEST_TMP')) as folder:
   work=Path(folder)
   compiler=work/'compiler';runtime=work/'runtime';intro=work/'Recompiled Ascendant.app/Contents/MacOS/love'
   for path in [compiler,runtime,intro]:path.parent.mkdir(parents=True,exist_ok=True);path.write_text('test fixture');path.chmod(0o700)
   qa=Mock()
   def run(command,**kwargs):
    if Path(command[0])==compiler:
     binary=work/'recompiled'/('a'*64)/backend.library_name(preflight.POKEMON_X_USA)
     binary.parent.mkdir(parents=True,exist_ok=True);binary.write_bytes(b'synthetic native build output')
    return SimpleNamespace(returncode=0)
   qa.qa_run.side_effect=run
   result={'status':'headers_verified_boot_untested','title_id':preflight.POKEMON_X_USA,'sha256':'a'*64}
   storage=SimpleNamespace(prepare=Mock(),clean_linked_objects=Mock(),clean_compiler_duplicates=Mock())
   with patch.object(backend,'WORK',work),patch.object(backend.preflight,'qa_manager',return_value=qa),patch.object(backend.preflight,'inspect',return_value=result),patch.object(backend.library,'register'),patch.dict(sys.modules,{'qa_build_storage':storage}):
    self.assertEqual(backend.main(['play',str(work/'rom'),'--runtime',str(runtime),'--recompiler',str(compiler)]),0)
   self.assertEqual([Path(call.args[0][0]) for call in qa.qa_run.call_args_list],[compiler,intro,runtime])
