import json
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from qa_storage import Storage


class Ephemeral(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name).resolve();self.root=self.home/'Documents/project';self.root.mkdir(parents=True)
        self.live=patch('qa_legacy_storage.LiveUse.busy',return_value=False);self.live.start();self.addCleanup(self.live.stop)

    def manager(self):
        s=Storage(self.root,home=self.home,min_free=0);self.addCleanup(lambda:s.close(collect=False));return s

    def candidate(self,s):
        p=s.copy(self.root/'.local/qa/probe/candidate',ephemeral=True);p.mkdir(parents=True)
        (p/'main.lua').write_bytes(b'unique code');(p/'model.bin').write_bytes(b'unique model')
        (p/'saves').mkdir();(p/'saves/player.sav').write_bytes(b'player save')
        (p.parent/'result.json').write_text('report');return p

    def test_close_collects_under_budget_with_exact_sources_models_saves_and_reports(self):
        s=self.manager();p=self.candidate(s)
        with patch.object(s,'_discover_legacy',side_effect=AssertionError('No global scan at test exit')):s.close()
        self.assertFalse((p/'main.lua').exists());self.assertEqual((p/'saves/player.sav').read_bytes(),b'player save')
        self.assertEqual((p.parent/'result.json').read_text(),'report')
        proof=json.loads((p.parent/'qa-preserved-sources.json').read_text())['candidate']
        for name,data in [('main.lua',b'unique code'),('model.bin',b'unique model')]:
            self.assertEqual(subprocess.check_output(['git','--git-dir='+proof['git'],'show',proof['commit']+':snapshot/'+name]),data)

    def test_reader_pin_defers_exit_cleanup_then_background_collects(self):
        s=self.manager();p=self.candidate(s);s.close(collect=False)
        reader=self.manager();reader.source(p/'main.lua');cleaner=self.manager();cleaner.sweep()
        self.assertTrue((p/'main.lua').exists())
        reader.close(collect=False);cleaner.sweep();self.assertFalse((p/'main.lua').exists())

    def test_inherited_child_lease_outlives_parent(self):
        s=self.manager();p=self.candidate(s)
        child=s.popen([sys.executable,'-c','import sys;sys.stdin.readline()'],stdin=subprocess.PIPE)
        self.addCleanup(lambda:child.poll() is None and child.kill())
        s.close();self.assertTrue((p/'main.lua').exists())
        child.communicate(b'done\n',timeout=10);self.manager().sweep();self.assertFalse((p/'main.lua').exists())

    def test_failed_test_process_still_cleans_at_exit(self):
        tools=Path(__file__).resolve().parents[1]/'tools'
        script="""import sys,atexit
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from qa_storage import Storage
s=Storage(Path(sys.argv[2]),home=Path(sys.argv[3]),min_free=0);atexit.register(s.close)
p=s.copy(s.root/'.local/qa/failure/candidate',ephemeral=True);p.mkdir(parents=True)
(p/'main.lua').write_text('retained source')
raise RuntimeError('test assertion failed')
"""
        r=subprocess.run([sys.executable,'-c',script,str(tools),str(self.root),str(self.home)],capture_output=True,text=True)
        self.assertNotEqual(r.returncode,0)
        p=self.root/'.local/qa/failure';self.assertFalse((p/'candidate/main.lua').exists())
        self.assertIn('candidate',json.loads((p/'qa-preserved-sources.json').read_text()))

    def test_targeted_teardown_does_not_wait_for_an_unrelated_global_sweep(self):
        s=self.manager();p=self.candidate(s)
        with (s.state/'collection.lock').open('a+') as collector:
            fcntl.flock(collector,fcntl.LOCK_EX)
            s.close()
        self.assertFalse((p/'main.lua').exists())

    def test_idle_discovered_copy_can_be_explicitly_made_ephemeral(self):
        s=self.manager();p=self.candidate(s);s.close(collect=False)
        key=s._key(p);record=json.loads((s.state/(key+'.json')).read_text());record['discovered']=True
        s._write(key,record);self.manager().sweep(only={key})
        self.assertFalse((p/'main.lua').exists())

    def test_archived_host_resumes_with_exact_code_models_links_and_saved_game(self):
        s=self.manager();p=self.candidate(s)
        external=self.home/'external-model';external.write_bytes(b'original')
        (p/'external').symlink_to(external);(p/'main.lua').chmod(0o755)
        s.close();self.assertFalse((p/'main.lua').exists())
        reader=self.manager();self.assertEqual(reader.restore_copy(p),p)
        self.assertEqual((p/'main.lua').read_bytes(),b'unique code')
        self.assertTrue((p/'main.lua').stat().st_mode&0o100)
        self.assertEqual((p/'model.bin').read_bytes(),b'unique model')
        self.assertEqual(os.readlink(p/'external'),str(external))
        self.assertEqual((p/'saves/player.sav').read_bytes(),b'player save')
        other=self.manager();other.source(p/'main.lua')
        reader.close();self.assertTrue((p/'main.lua').exists())
        other.close();self.assertFalse((p/'main.lua').exists());self.assertEqual(external.read_bytes(),b'original')

    def test_restore_never_overwrites_newer_model_files(self):
        s=self.manager();p=self.candidate(s);s.close()
        (p/'model.bin').write_bytes(b'newer model')
        with self.assertRaisesRegex(ValueError,'newer host file'):self.manager().restore_copy(p)
        self.assertEqual((p/'model.bin').read_bytes(),b'newer model')
        self.assertFalse((p/'main.lua').exists())

if __name__=='__main__':unittest.main()
