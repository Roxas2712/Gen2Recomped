import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from qa_storage import Storage, GIB
from qa_preserved import Vault
from qa_build_storage import clean_linked_objects, prepare


class Producers(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name).resolve();self.root=self.home/'Documents/project';self.root.mkdir(parents=True)
        self.storage=Storage(self.root,home=self.home,min_free=0)
        self.addCleanup(lambda:self.storage.close(collect=False))

    def test_real_home_cannot_reduce_reserve(self):
        with patch('qa_storage.Path.home',return_value=self.home):
            s=Storage(self.root,home=self.home,min_free=8*GIB)
            self.addCleanup(lambda:s.close(collect=False))
            self.assertEqual(s.min_free,20*GIB)

    def test_output_over_budget_refuses_spawn(self):
        output=self.root/'build';output.mkdir();(output/'part.o').write_bytes(b'a'*200)
        with self.assertRaisesRegex(RuntimeError,'output budget exceeded'):
            self.storage.limit_output(output,100)
        marker=self.root/'must-not-exist'
        with self.assertRaisesRegex(RuntimeError,'output budget exceeded'):
            self.storage.run([sys.executable,'-c','open(sys.argv[1],"w").close()',str(marker)])
        self.assertFalse(marker.exists())

    def test_running_producer_stops_on_budget_without_removing_sources(self):
        output=self.root/'build';output.mkdir();source=self.root/'model.obj';source.write_bytes(b'model')
        self.storage.limit_output(output,100)
        with self.assertRaisesRegex(RuntimeError,'output budget exceeded'):
            self.storage.run([sys.executable,'-c',
                'import sys,time;open(sys.argv[1],"wb").write(b"x"*200);time.sleep(10)',str(output/'part.o')],timeout=8)
        self.assertEqual(source.read_bytes(),b'model')

    def test_archive_members_are_preserved_and_streamed_without_intermediate(self):
        archive=self.root/'baseline.tar'
        with tarfile.open(archive,'w')as tar:
            for name,data in [('main.lua',b'code'),('models/model.obj',b'model'),('saves/player.sav',b'save')]:
                member=tarfile.TarInfo(name);member.size=len(data);tar.addfile(member,io.BytesIO(data))
        with Vault(self.home)as vault:proof=vault.capture_tar(archive)
        output=self.root/'restored';self.storage.extract_archive(proof['git'],proof['commit']+':snapshot',output)
        self.assertEqual((output/'main.lua').read_bytes(),b'code')
        self.assertEqual((output/'models/model.obj').read_bytes(),b'model')
        self.assertEqual((output/'saves/player.sav').read_bytes(),b'save')
        self.assertEqual(list(output.glob('*.tar')),[])

    def test_orphan_archive_cleanup_keeps_member_bytes_and_evidence(self):
        with patch('qa_legacy_storage.LiveUse.busy',return_value=False):
            p=self.storage.copy(self.root/'.local/qa/oasc-unit-qa-123/baseline.tar',ephemeral=True)
            p.parent.mkdir(parents=True)
            with tarfile.open(p,'w')as tar:
                m=tarfile.TarInfo('model.obj');m.size=5;tar.addfile(m,io.BytesIO(b'model'))
            (p.parent/'result.json').write_text('evidence')
            self.storage.close()
        self.assertFalse(p.exists());self.assertEqual((p.parent/'result.json').read_text(),'evidence')
        proof=json.loads((p.parent/'qa-preserved-sources.json').read_text())['baseline.tar']
        self.assertEqual(subprocess.check_output(['git','--git-dir='+proof['git'],'show',proof['commit']+':snapshot/model.obj']),b'model')

    def test_unsafe_archive_is_retained(self):
        archive=self.root/'baseline.tar'
        with tarfile.open(archive,'w')as tar:
            member=tarfile.TarInfo('../model.obj');member.size=1;tar.addfile(member,io.BytesIO(b'x'))
        with Vault(self.home)as vault:
            with self.assertRaises(ValueError):vault.capture_tar(archive)
        self.assertTrue(archive.exists())

    def test_only_linked_inactive_compiler_objects_are_removed(self):
        work=self.root/'.local/pokemon-x';out=work/'recompiled'/('a'*64);out.mkdir(parents=True)
        for name in ['code001.c','code001.o','entries.c','entries.o','model.obj','save.sav','unknown.o']:
            (out/name).write_bytes(name.encode())
        with patch('qa_build_storage.LiveUse.busy',return_value=False):
            self.assertEqual(clean_linked_objects(work),0)
            (out/'0004000000055D00.dylib').write_bytes(b'final library')
            self.assertGreater(clean_linked_objects(work),0)
        self.assertFalse((out/'code001.o').exists());self.assertFalse((out/'entries.o').exists())
        for name in ['code001.c','entries.c','model.obj','save.sav','unknown.o','0004000000055D00.dylib']:
            self.assertTrue((out/name).is_file(),name)

    def test_live_build_and_keep_marker_preserve_objects(self):
        work=self.root/'.local/pokemon-x';out=work/'recompiled'/('b'*64);out.mkdir(parents=True)
        for name in ['code001.c','code001.o','0004000000055E00.dylib']:(out/name).write_bytes(b'x')
        with patch('qa_build_storage.LiveUse.busy',return_value=True):self.assertEqual(clean_linked_objects(work),0)
        (out/'.qa-keep').touch()
        with patch('qa_build_storage.LiveUse.busy',return_value=False):self.assertEqual(clean_linked_objects(work),0)
        self.assertTrue((out/'code001.o').exists())

    def test_build_budgets_do_not_register_rom_or_source_for_deletion(self):
        work=self.root/'.local/pokemon-x';work.mkdir(parents=True)
        with patch('qa_build_storage.LiveUse.busy',return_value=False):prepare(self.storage,work,'a'*64)
        self.assertEqual(self.storage.output_limits[work/'recompiled'],4*GIB)
        self.assertEqual(self.storage.output_limits[work/'recompiled'/('a'*64)],2*GIB)
        self.assertFalse(any(path==work for _,path in self.storage.lease_info.values()))


if __name__=='__main__':unittest.main()
