import importlib.util,json,plistlib,sys,tempfile,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from qa_storage import qa_source
import macos_distribution as mac
qa_source(ROOT)
spec=importlib.util.spec_from_file_location('preview',Path(__file__).parents[1]/'tools/build_native_preview.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class Payload(unittest.TestCase):
 def archive(self,extra=()):
  tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);p=Path(tmp.name)/'game.love'
  with zipfile.ZipFile(p,'w')as z:
   for f in ('main.lua','conf.lua','src/preview/main.lua','src/preview/conf.lua','src/preview/release.json','src/core/NativePreview.lua',*extra):z.writestr(f,'test')
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
 def test_qualified_mac_runtime_cannot_understate_minimum_os(self):
  info={'LSMinimumSystemVersion':'10.15'}
  module.raise_macos_minimum(info,'11.0.0')
  self.assertEqual(info['LSMinimumSystemVersion'],'11.0.0')
  info={'LSMinimumSystemVersion':'14.1'}
  module.raise_macos_minimum(info,'11.0.0')
  self.assertEqual(info['LSMinimumSystemVersion'],'14.1')

class MacDistribution(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory(prefix='mac-distribution-contract-');self.addCleanup(self.temp.cleanup)
  self.root=Path(self.temp.name);qa_source(self.root)
  self.bundle=self.root/'Preview.app';resources=self.bundle/'Contents/Resources';resources.mkdir(parents=True)
  self.info=self.bundle/'Contents/Info.plist'
  self.info.write_bytes(plistlib.dumps(dict(CFBundleExecutable='love',CFBundleIconName='AppIcon',CFBundleIconFile='love.icns',CFBundleIdentifier='test.preview')))
  self.entitlements=ROOT/'scripts/macos-entitlements.plist'

 def test_real_icon_replaces_catalog_precedence_before_launch(self):
  icon=ROOT/'icons/icon.icns'
  checksum=mac.install_icon(self.bundle,icon)
  self.assertEqual(len(checksum),64)
  self.assertEqual((self.bundle/'Contents/Resources/GameIcon.icns').read_bytes(),icon.read_bytes())
  info=plistlib.loads(self.info.read_bytes())
  self.assertNotIn('CFBundleIconName',info)
  self.assertEqual(info['CFBundleIconFile'],'GameIcon.icns')
  self.assertEqual(info['CFBundleIdentifier'],'test.preview')

 def test_invalid_icon_preserves_bundle(self):
  icon=self.root/'bad.icns';icon.write_bytes(b'icns\0\0\0\x20bad')
  original=self.info.read_bytes()
  with self.assertRaisesRegex(ValueError,'ICNS'):mac.install_icon(self.bundle,icon)
  self.assertEqual(self.info.read_bytes(),original)
  self.assertFalse((self.bundle/'Contents/Resources/GameIcon.icns').exists())

 def test_nested_code_is_signed_inside_out_and_symlinks_deduplicated(self):
  framework=self.bundle/'Contents/Frameworks/Lua.framework'
  library=framework/'Versions/A/Lua';library.parent.mkdir(parents=True);library.write_bytes(bytes.fromhex('cffaedfe')+b'synthetic')
  (framework/'Lua').symlink_to('Versions/A/Lua')
  main=self.bundle/'Contents/MacOS/love';main.parent.mkdir();main.write_bytes(bytes.fromhex('cffaedfe'))
  targets=mac.signing_targets(self.bundle)
  self.assertEqual(targets,[library.resolve(),framework.resolve(),self.bundle.resolve()])
  (framework/'escape').symlink_to(self.root)
  with self.assertRaisesRegex(ValueError,'escapes'):mac.signing_targets(self.bundle)

 def fake_run(self,commands,status='Accepted',signature=True):
  def run(command):
   commands.append([str(part) for part in command])
   if command[:3]==['codesign','--display','--verbose=4']:
    return 'Authority=Developer ID Application: Test\nflags=0x10000(runtime)\nTimestamp=test\n' if signature else 'Signature=adhoc'
   if command[:3]==['xcrun','notarytool','submit']:
    return json.dumps(dict(status=status,id='12345678-1234-1234-1234-123456789abc'))
   return ''
  return run

 def test_ad_hoc_build_cannot_claim_apple_acceptance(self):
  with patch.object(mac,'run',return_value=''):
   result=mac.sign_and_notarize(self.bundle,self.entitlements)
  self.assertEqual(result,dict(signing='ad-hoc',notarized=False,ticketStapled=False,gatekeeperVerified=False))

 def test_partial_credentials_fail_before_signing(self):
  for identity,profile,keychain in [('test',None,None),(None,'test',None),(None,None,self.root)]:
   with patch.object(mac,'run') as runner:
    with self.assertRaises(ValueError):mac.sign_and_notarize(self.bundle,self.entitlements,identity,profile,keychain)
    runner.assert_not_called()

 def test_apple_rejection_is_not_published_as_success(self):
  for status in ('Invalid','In Progress',None):
   commands=[]
   with patch.object(mac,'run',side_effect=self.fake_run(commands,status)):
    with self.assertRaisesRegex(ValueError,'did not accept'):
     mac.sign_and_notarize(self.bundle,self.entitlements,'identity','profile')
   self.assertFalse(any(c[:2]==['xcrun','stapler'] for c in commands))

 def test_developer_id_timestamp_and_hardened_runtime_required(self):
  commands=[]
  with patch.object(mac,'run',side_effect=self.fake_run(commands,signature=False)):
   with self.assertRaisesRegex(ValueError,'Developer ID'):
    mac.sign_and_notarize(self.bundle,self.entitlements,'identity','profile')
  self.assertFalse(any(c[:2]==['xcrun','notarytool'] for c in commands))

 def test_acceptance_then_staple_validate_and_gatekeeper(self):
  commands=[]
  with patch.object(mac,'run',side_effect=self.fake_run(commands)):
   result=mac.sign_and_notarize(self.bundle,self.entitlements,'identity','profile',self.root/'signing.keychain-db')
  self.assertTrue(result['notarized'] and result['ticketStapled'] and result['gatekeeperVerified'])
  self.assertEqual([c[:3] for c in commands[-4:]],[
   ['xcrun','stapler','staple'],['xcrun','stapler','validate'],['codesign','--verify','--deep'],['spctl','--assess','--type']])
  for command in commands:
   if command[0]=='codesign' and '--sign' in command:
    self.assertNotIn('--deep',command);self.assertIn('--timestamp',command);self.assertIn('runtime',command)
  self.assertIn('--keychain',next(c for c in commands if c[:3]==['xcrun','notarytool','submit']))

 def test_failed_staple_or_gatekeeper_cannot_claim_success(self):
  for failure in (['xcrun','stapler','staple'],['xcrun','stapler','validate'],['spctl','--assess','--type']):
   commands=[];base=self.fake_run(commands)
   def run(command):
    if command[:3]==failure:raise RuntimeError('injected verification failure')
    return base(command)
   with patch.object(mac,'run',side_effect=run):
    with self.assertRaises(RuntimeError):mac.sign_and_notarize(self.bundle,self.entitlements,'identity','profile')
if __name__=='__main__':unittest.main()
