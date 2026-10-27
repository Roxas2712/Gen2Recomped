import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from qa_storage import Storage
from qa_love_storage import sweep


class LoveRetention(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name).resolve();self.root=self.home/'Documents/project';self.root.mkdir(parents=True)
        self.storage=Storage(self.root,home=self.home,min_free=0)
        self.addCleanup(lambda:self.storage.close(collect=False))
        self.base=self.home/'Library/Application Support/LOVE'
        self.profile=self.base/'portemon-private-0123456789abcdef'
        self.activity=patch('qa_legacy_storage.LiveUse.busy',return_value=False)
        self.activity.start();self.addCleanup(self.activity.stop)

    def put(self,path,data=b'return { generated=true }'):
        path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data);return path

    def run_gc(self,**kw):return sweep(self.storage,clock=lambda:time.time()+4000,max_age=0,**kw)

    def test_exact_archive_and_models_roms_saves_and_source_stay_in_place(self):
        cache=self.profile/'heartgold/data/generated'
        old=self.put(cache/'script/generations/abc/items.lua',b'PDC1\x00payload')
        retained=[self.put(cache/'models/paper.lua',b'model'),self.put(cache/'src/custom.lua',b'code'),
                  self.put(cache/'nested/player.state.bak',b'save'),self.put(self.profile/'saves/hero.lua',b'progress'),
                  self.put(self.profile/'heartgold/rom-source.lua',b'rom source'),self.put(self.profile/'mods/original/main.lua',b'mod'),
                  self.put(self.profile/'heartgold/baseroms/own.nds',b'ROM')]
        snapshots={p:p.read_bytes() for p in retained}
        marker=self.put(self.profile/'heartgold/rom-cache.complete')
        stats=self.run_gc();self.assertEqual(stats['files'],1);self.assertFalse(old.exists()or marker.exists())
        self.assertEqual({p:p.read_bytes() for p in retained},snapshots)
        receipt=json.loads(next((self.storage.state/'love-receipts').glob('*.json')).read_text())['archive']
        data=subprocess.check_output(['git','--git-dir='+receipt['git'],'show',receipt['commit']+':snapshot/'+str(old.relative_to(self.home))])
        self.assertEqual(data,b'PDC1\x00payload')

    def test_player_profiles_similar_names_and_symlinks_are_not_cleaned(self):
        paths=[self.put(self.base/n/'heartgold/data/generated/data.lua') for n in ('portemon','Gen2Recomp','portemon-private-almost','gen2-palette-unrelated')]
        external=self.put(self.home/'original/generated/data.lua');self.profile.mkdir(parents=True)
        (self.profile/'heartgold').symlink_to(external.parent.parent,target_is_directory=True)
        self.run_gc();self.assertTrue(all(p.exists() for p in paths+[external]))

    def test_nested_isolated_home_and_old_palette_profiles(self):
        outer=self.base/'oasc-native-display-qa-123'
        nested=outer/'isolated-home/Library/Application Support/Gen2Recomp-NativePreview-20261025-1/crystal/data/generated/a.lua'
        palette=self.base/'gen2-palette-gpu-test-firered/firered/assets/generated/a.png'
        for p in (nested,palette):self.put(p)
        self.assertEqual(self.run_gc()['files'],2)
        self.assertFalse(nested.exists()or palette.exists())

    def test_source_pin_shared_profile_lock_and_alias_are_respected(self):
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        reader=Storage(self.root,home=self.home,min_free=0);reader.source(p)
        try:self.assertEqual(self.run_gc()['files'],0);self.assertTrue(p.exists())
        finally:reader.close(collect=False)
        alias=self.root/'.local/imports/heartgold';alias.parent.mkdir(parents=True);alias.symlink_to(self.profile/'heartgold')
        self.assertEqual(self.run_gc()['files'],0);self.assertTrue(p.exists())
        alias.unlink();self.assertEqual(self.run_gc()['files'],1)

    def test_keep_fresh_and_unmanaged_live_readers_are_retained(self):
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        self.assertEqual(sweep(self.storage,limit=0)['files'],0)
        keep=self.put(self.profile/'.qa-keep');self.assertEqual(self.run_gc()['files'],0);keep.unlink()
        with patch('qa_legacy_storage.LiveUse.busy',return_value=True):self.assertEqual(self.run_gc()['files'],0)
        self.assertTrue(p.exists())

    def test_failed_archive_never_deletes_cache(self):
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        with patch('qa_preserved.Vault.capture',side_effect=OSError('archive unavailable')):
            with self.assertRaises(OSError):self.run_gc()
        self.assertTrue(p.exists())

    def test_new_reader_after_archive_prevents_deletion(self):
        from qa_preserved import Vault
        p=self.put(self.profile/'heartgold/data/generated/a.lua');capture=Vault.capture;busy=[False]
        def captured(vault,source,**options):
            proof=capture(vault,source,**options);busy[0]=True;return proof
        with patch('qa_preserved.Vault.capture',captured),patch('qa_legacy_storage.LiveUse.busy',side_effect=lambda path:busy[0]):
            self.assertEqual(self.run_gc()['files'],0)
        self.assertTrue(p.exists())

    def test_legacy_collector_cannot_remove_models_from_mixed_generated_tree(self):
        p=self.base/'ula-mixed-qa';model=self.put(p/'ruby/data/generated/models/paper.lua')
        generated=self.put(p/'ruby/data/generated/maps.lua',b'generated map')
        marker=self.put(p/'ruby/rom-cache.complete',b'complete')
        self.storage._take('imports',p,True)
        entry=dict(kind='imports',path=str(p),root=str(self.root))
        self.assertEqual(list(self.storage._files(entry)),[])
        self.storage._remove(entry)
        self.assertEqual(model.read_bytes(),b'return { generated=true }')
        self.assertEqual(generated.read_bytes(),b'generated map')
        self.assertEqual(marker.read_bytes(),b'complete')

    def test_legacy_collector_can_remove_clean_assets_beside_retained_model_data(self):
        p=self.base/'ula-mixed-qa';model=self.put(p/'ruby/data/generated/models/paper.lua')
        image=self.put(p/'ruby/assets/generated/tile.png',b'generated image')
        marker=self.put(p/'ruby/rom-cache.complete')
        entry=dict(kind='imports',path=str(p),root=str(self.root))
        self.assertEqual([file for file,_ in self.storage._files(entry)],[image])
        self.storage._remove(entry)
        self.assertTrue(model.exists());self.assertFalse(image.exists()or marker.exists())

    def test_legacy_collector_retains_source_save_and_keep_subtrees(self):
        for index,relative in enumerate(('src/custom.lua','saves/hero.lua','nested/hero.state.bak','nested/.qa-keep')):
            with self.subTest(relative=relative):
                p=self.base/('ula-mixed-qa-'+str(index));retained=self.put(p/'ruby/data/generated'/relative,b'original')
                marker=self.put(p/'ruby/rom-cache.complete',b'complete')
                entry=dict(kind='imports',path=str(p),root=str(self.root))
                self.assertEqual(list(self.storage._files(entry)),[])
                self.storage._remove(entry)
                self.assertEqual(retained.read_bytes(),b'original');self.assertEqual(marker.read_bytes(),b'complete')

    def test_exact_legacy_profile_families_share_read_locks_with_the_love_collector(self):
        for name in ('portemon-private-fedcba9876543210','gen2-palette-gpu-test-gold','ula-reader-qa'):
            with self.subTest(identity=name):
                p=self.put(self.base/name/'heartgold/data/generated/a.lua')
                reader=Storage(self.root,home=self.home,min_free=0)
                try:
                    reader.source(p)
                    self.assertIn(reader._key(self.base/name),reader.held)
                    self.assertEqual(self.run_gc()['files'],0);self.assertTrue(p.exists())
                finally:reader.close(collect=False)
                self.assertEqual(self.run_gc()['files'],1);self.assertFalse(p.exists())

    def test_read_pinning_legacy_profiles_does_not_grant_import_writer_rights(self):
        self.storage.source(self.profile)
        with self.assertRaises(ValueError):self.storage.destination(self.profile)

    def test_shared_hardlinks_are_archived_and_removed_without_losing_other_files(self):
        a=self.put(self.profile/'heartgold/data/generated/a.lua')
        b=a.with_name('b.lua');os.link(a,b)
        self.assertEqual(self.run_gc()['files'],2)

    def test_another_collector_prevents_parallel_collection(self):
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        with (self.storage.state/'collection.lock').open('a+') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX);self.assertEqual(self.run_gc()['files'],0)
        self.assertTrue(p.exists())

    def test_many_profiles_are_bounded_and_following_sweep_finishes_them(self):
        paths=[self.put(self.base/('portemon-private-'+format(i,'016x'))/'heartgold/data/generated/a.lua') for i in range(53)]
        self.assertEqual(self.run_gc()['profiles'],48)
        self.assertEqual(sum(p.exists() for p in paths),5)
        self.assertEqual(self.run_gc()['profiles'],5)
        self.assertFalse(any(p.exists() for p in paths))

    def test_targeted_cleanup_uses_profile_locks_without_waiting_for_global_scan(self):
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        other=self.put(self.base/'ula-other-qa/ruby/data/generated/b.lua')
        with (self.storage.state/'collection.lock').open('a+') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            result=self.run_gc(only={self.profile})
        self.assertEqual(result['files'],1)
        self.assertFalse(p.exists());self.assertTrue(other.exists())

    def test_direct_archive_does_not_change_source_ctimes_or_capture_unrelated_files(self):
        from qa_preserved import Vault
        p=self.put(self.profile/'heartgold/data/generated/a.lua')
        unrelated=self.put(self.home/'models/unrelated.lua',b'private model')
        before=p.stat().st_ctime_ns
        with Vault(self.home) as vault:proof=vault.capture(self.home,paths=[p])
        self.assertEqual(p.stat().st_ctime_ns,before)
        tree=subprocess.check_output(['git','--git-dir='+proof['git'],'ls-tree','-r','--name-only',proof['commit']],text=True)
        self.assertEqual(tree.strip(),'snapshot/'+str(p.relative_to(self.home)))
        self.assertEqual(unrelated.read_bytes(),b'private model')

    def test_direct_archive_refuses_paths_outside_declared_root(self):
        from qa_preserved import Vault
        p=self.put(self.home/'models/original.lua')
        with Vault(self.home) as vault:
            with self.assertRaises(ValueError):vault.capture(self.profile,paths=[p])


if __name__=='__main__':unittest.main()
