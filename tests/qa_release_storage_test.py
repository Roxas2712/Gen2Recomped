import json,os,subprocess,sys,tempfile,time,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from qa_storage import Storage
from qa_release_storage import sweep,plan


class Releases(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name).resolve();self.root=self.home/'Documents/project';self.root.mkdir(parents=True)
        self.s=Storage(self.root,home=self.home,min_free=0);self.addCleanup(lambda:self.s.close(collect=False))
        self.live=patch('qa_release_storage.legacy.LiveUse.busy',return_value=False);self.live.start();self.addCleanup(self.live.stop)

    def package(self,name,entries=None,stamp=10):
        p=self.root/'dist'/name;p.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(p,'w')as z:
            for name,data in (entries or {'main.lua':b'code','models/m.obj':b'model'}).items():z.writestr(name,data)
        os.utime(p,(stamp,stamp));return p

    def run_sweep(self):return sweep(self.s,roots=[self.root],max_age=0)

    def test_latest_each_family_and_exact_old_sources_models(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip')
        new=self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        mac=self.package('Origami-Ascendant-1.0.9-macOS.zip')
        result=self.run_sweep();self.assertEqual(result['outputs'],1)
        self.assertFalse(old.exists());self.assertTrue(new.exists());self.assertTrue(mac.exists())
        proof=json.loads(next((self.s.state/'release-receipts').glob('*.json')).read_text())['preserved']
        self.assertEqual(subprocess.check_output(['git','--git-dir='+proof['git'],'show',proof['commit']+':snapshot/models/m.obj']),b'model')

    def test_current_older_timestamp_version_is_kept_too(self):
        high=self.package('Origami-Ascendant-Gen2Recomped-gen2.19-audio.zip',stamp=10)
        copied=self.package('Origami-Ascendant-Gen2Recomped-gen2.11-dev.zip',stamp=30)
        self.run_sweep();self.assertTrue(high.exists());self.assertTrue(copied.exists())

    def test_five_edition_mod_does_not_replace_current_engine_package(self):
        engine=self.package('Origami-Ascendant-Gen2Recomped-0.8.45-development.zip')
        old=self.package('Origami-Ascendant-Gen2Recomped-five-edition-development.zip',stamp=20)
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=30)
        self.run_sweep();self.assertTrue(engine.exists());self.assertFalse(old.exists())

    def test_save_archive_unknown_package_and_keep_marker_retained(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip',{'saves/player.sav':b'save'})
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        unknown=self.package('Personal-models.zip');self.run_sweep()
        self.assertTrue(old.exists());self.assertTrue(unknown.exists())
        (self.root/'dist/.qa-keep').touch();self.assertEqual(self.run_sweep()['outputs'],0)

    def test_active_input_pin_defers_cleanup(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip')
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        self.s.source(old);self.assertEqual(self.run_sweep()['outputs'],0);self.assertTrue(old.exists())

    def test_another_runner_pin_defers_background_cleanup(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip')
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        reader=Storage(self.root,home=self.home,min_free=0)
        try:
            reader.source(old);self.assertEqual(self.run_sweep()['outputs'],0)
        finally:reader.close(collect=False)
        self.assertEqual(self.run_sweep()['outputs'],1)

    def test_fresh_outputs_and_symlink_are_not_removed(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip')
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        self.assertEqual(sweep(self.s,roots=[self.root])['outputs'],0)
        old.unlink();old.symlink_to(self.home/'external');self.assertEqual(self.run_sweep()['outputs'],0)

    def test_unpacked_copy_requires_final_package_and_preserves_save(self):
        out=self.root/'.local/release-unpacked/Origami-Ascendant-1.0.9';out.mkdir(parents=True)
        (out/'main.lua').write_bytes(b'code');(out/'models').mkdir();(out/'models/m.obj').write_bytes(b'model')
        (out/'saves').mkdir();(out/'saves/player.sav').write_bytes(b'save')
        self.assertEqual(self.run_sweep()['outputs'],0)
        self.package('Origami-Ascendant-1.0.9-macOS.zip');self.run_sweep()
        self.assertFalse((out/'main.lua').exists());self.assertEqual((out/'saves/player.sav').read_bytes(),b'save')

    def test_corrupt_archive_is_retained(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip');old.write_bytes(b'bad zip')
        self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        self.run_sweep();self.assertTrue(old.exists())

    def test_incomplete_newest_package_never_replaces_last_good_package(self):
        old=self.package('Origami-Ascendant-Gen2Recomped-gen2.17-moves.zip')
        newest=self.package('Origami-Ascendant-Gen2Recomped-gen2.18-cries.zip',stamp=20)
        newest.write_bytes(b'incomplete build');self.run_sweep();self.assertTrue(old.exists())

if __name__=='__main__':unittest.main()
