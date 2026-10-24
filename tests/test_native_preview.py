import importlib.util,tempfile,unittest,zipfile
from pathlib import Path
spec=importlib.util.spec_from_file_location('preview',Path(__file__).parents[1]/'tools/build_native_preview.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class Payload(unittest.TestCase):
 def archive(self,extra=()):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);p=Path(tmp.name)/'game.love'
  with zipfile.ZipFile(p,'w')as z:
   for f in ('main.lua','conf.lua','src/preview/main.lua','src/preview/conf.lua','src/core/NativePreview.lua',*extra):z.writestr(f,'test')
  return p
 def test_isolated_payload(self):module.verify_payload(self.archive())
 def test_rom_save_and_user_data_rejected(self):
  for f in ('dump.GBA','a.gb','a.gbc','a.sav','x.srm','x.bak','options.lua','save.lua','rom-cache.complete','data/generated/map.lua','mods/a/main.lua','cloud_clients.lua'):
   with self.subTest(f=f):
    with self.assertRaises(ValueError):module.verify_payload(self.archive((f,)))
 def test_traversal_rejected(self):
  for f in ('../out','/absolute'):
   with self.assertRaises(ValueError):module.verify_payload(self.archive((f,)))
 def test_payload_release_version_is_verified(self):
  p=self.archive()
  with zipfile.ZipFile(p,'a')as z:z.writestr('src/core/Version.lua','return { engine = "0.8.45", modApi = 3 }')
  module.verify_payload(p,'0.8.45')
  with self.assertRaises(ValueError):module.verify_payload(p,'0.7.6')
 def test_release_version_cannot_be_silently_absent(self):
  with self.assertRaises(KeyError):module.verify_payload(self.archive(),'0.8.45')
 def test_mac_archive_excludes_unrestorable_host_metadata(self):
  module.verify_mac_archive(self.archive())
  for f in ('macos/App.app/._Info.plist','__MACOSX/._App.app','macos/App.app/Contents/Frameworks/x.framework/._x'):
   with self.subTest(f=f):
    with self.assertRaises(ValueError):module.verify_mac_archive(self.archive((f,)))
 def test_pinned_platforms_same_runtime(self):
  self.assertEqual(set(module.RUNTIMES),{'windows','macos'})
  for runtime in module.RUNTIMES.values():self.assertEqual(len(runtime['sha256']),64)
if __name__=='__main__':unittest.main()
