import gzip,json,os,sys,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from qa_report_storage import write_report,compress_report
from qa_transient_storage import clean_cargo,clean_previews
from qa_storage import Storage
from qa_love_storage import cache_rows


class Transients(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name).resolve();self.root=self.home/'Documents/project';self.root.mkdir(parents=True)
        self.s=Storage(self.root,home=self.home,min_free=0);self.addCleanup(lambda:self.s.close(collect=False))
        self.live=patch('qa_legacy_storage.LiveUse.busy',return_value=False);self.live.start();self.addCleanup(self.live.stop)

    def test_large_report_is_lossless_indexed_bounded_and_can_be_replaced(self):
        p=self.root/'report.json';r={'passed':True,'observations':['observed']*200}
        write_report(r,p,threshold=100)
        index=json.loads(p.read_text());self.assertTrue(index['passed'])
        with gzip.open(p.parent/index['archive'],'rt') as stream:self.assertEqual(json.load(stream),r)
        r['passed']=False;write_report(r,p,threshold=100)
        self.assertFalse(json.loads(p.read_text())['passed']);self.assertTrue(p.with_suffix('.json.previous.gz').exists())

    def test_budget_failure_keeps_previous_report(self):
        p=self.root/'report.json';p.write_text('old evidence')
        with self.assertRaises(RuntimeError):write_report({'huge':'x'*1000},p,threshold=50,max_raw=100)
        self.assertEqual(p.read_text(),'old evidence');self.assertEqual(list(self.root.glob('.qa-report-*')),[])

    def test_compressed_budget_includes_gzip_flush_and_preserves_prior_report(self):
        p=self.root/'report.json';p.write_text('old evidence')
        with self.assertRaises(RuntimeError):write_report({'data':'x'*1000},p,threshold=10,max_compressed=20)
        self.assertEqual(p.read_text(),'old evidence');self.assertFalse(p.with_suffix('.json.gz').exists())

    def test_finished_qa_profile_reclaims_meshes_but_keeps_hd_models_and_saves(self):
        profile=self.home/'Library/Application Support/LOVE/oasc-transient-qa-123'
        self.s.destination(profile)
        mesh=profile/'modstorage/VOXEL_ASCENDANT/gen2_mesh_cache/v4/cache.data'
        retained=[profile/'modstorage/VOXEL_ASCENDANT/hd-content/blobs/model.bin',profile/'profiles/guest/save.sav']
        for p in [mesh,*retained]:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'keep original bytes')
        with patch('qa_legacy_storage.LiveUse.busy',return_value=True):
            self.s.close();self.assertTrue(mesh.exists())
        owner=Storage(self.root,home=self.home,min_free=0);owner.destination(profile);owner.close()
        self.assertFalse(mesh.exists());self.assertTrue(all(p.read_bytes()==b'keep original bytes' for p in retained))

    def test_failed_profile_archive_defers_cleanup_without_masking_test_result(self):
        profile=self.home/'Library/Application Support/LOVE/oasc-transient-qa-123'
        self.s.destination(profile)
        mesh=profile/'modstorage/VOXEL_ASCENDANT/gen2_mesh_cache/v4/cache.data'
        mesh.parent.mkdir(parents=True);mesh.write_bytes(b'generated')
        with patch('qa_preserved.Vault.capture',side_effect=RuntimeError('archive unavailable')):self.s.close()
        self.assertEqual(mesh.read_bytes(),b'generated')

    def cargo(self):
        base=self.root/'.local/qa/pokemon-x-feasibility/target/release';base.mkdir(parents=True)
        installed=self.root/'.local/pokemon-x/bin/libascendant_3ds_bridge.dylib';installed.parent.mkdir(parents=True);installed.write_bytes(b'bridge')
        (base/'libascendant_3ds_bridge.dylib').write_bytes(b'bridge')
        for name in ['dep.rlib','dep.rmeta','source.rs','model.obj','save.state']:(base/name).write_bytes(name.encode())
        script=base/'source.sh';script.write_text('#!/bin/sh\ntrue\n');script.chmod(0o755)
        return base,installed

    def test_cargo_removes_intermediates_but_keeps_installed_sources_models_saves(self):
        base,installed=self.cargo();self.assertGreater(clean_cargo(self.s,self.root,min_age=0),0)
        self.assertFalse((base/'dep.rlib').exists())
        for name in ['source.rs','source.sh','model.obj','save.state','libascendant_3ds_bridge.dylib']:self.assertTrue((base/name).exists())
        self.assertEqual(installed.read_bytes(),b'bridge')

    def test_cargo_mismatch_live_lock_and_keep_marker_preserve_outputs(self):
        base,installed=self.cargo();installed.write_bytes(b'newer')
        self.assertEqual(clean_cargo(self.s,self.root,min_age=0),0);installed.write_bytes(b'bridge')
        reader=Storage(self.root,home=self.home,min_free=0)
        try:
            reader.cache(base.parent);self.assertEqual(clean_cargo(self.s,self.root,min_age=0),0)
        finally:reader.close(collect=False)
        (base.parent/'.qa-keep').touch();self.assertEqual(clean_cargo(self.s,self.root,min_age=0),0)

    def test_preview_keeps_current_metadata_and_newest_and_preserves_old_saves(self):
        runs=[]
        for stamp in ['100','200','300']:
            p=self.root/'.local/qa'/('native-qualified-preview-'+stamp)/'candidate';p.mkdir(parents=True)
            (p/'source.lua').write_bytes(b'code');(p/'model.obj').write_bytes(b'model');(p/'save.sav').write_bytes(b'save');runs.append(p)
        meta=self.root/'.local/state/native-qualified-preview-packages.json';meta.parent.mkdir();meta.write_text(json.dumps({'root':str(runs[1].parent)}))
        self.assertGreater(clean_previews(self.s,self.root,min_age=0),0)
        self.assertFalse((runs[0]/'source.lua').exists());self.assertTrue((runs[0]/'save.sav').exists())
        self.assertTrue((runs[1]/'source.lua').exists());self.assertTrue((runs[2]/'source.lua').exists())
        self.assertTrue((runs[0].parent/'qa-preserved-sources.json').exists())

    def test_mesh_scope_excludes_hd_models_and_saves(self):
        profile=self.home/'Library/Application Support/LOVE/oasc-test-qa-123'
        paths=[profile/'modstorage/VOXEL_ASCENDANT/gen2_mesh_cache/v4/cache.data',
               profile/'modstorage/VOXEL_ASCENDANT/hd-content/blobs/model.bin',
               profile/'profiles/guest/save.sav']
        for p in paths:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'data')
        self.assertEqual([p for p,_ in cache_rows(profile)],[paths[0]])

if __name__=='__main__':unittest.main()
