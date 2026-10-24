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
 def test_pinned_platforms_same_runtime(self):
  self.assertEqual(set(module.RUNTIMES),{'windows','macos'})
  for runtime in module.RUNTIMES.values():self.assertEqual(len(runtime['sha256']),64)
if __name__=='__main__':unittest.main()
