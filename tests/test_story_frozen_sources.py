# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from tools.story_frozen_sources import REQUIRED, verify_frozen_sources, verify_processed_queue


class FrozenStorySourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.getenv('STORY_QA_TEST_TEMP'))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.engine = self.root/'engine'
        self.expected = {}
        for name in REQUIRED:
            target=self.engine/name;target.parent.mkdir(parents=True,exist_ok=True)
            raw=('owned frozen source '+name).encode();target.write_bytes(raw)
            self.expected[name]=hashlib.sha256(raw).hexdigest()
        self.manifest=self.root/'frozen-files.json'
        self.save_manifest()

    def save_manifest(self):
        self.manifest.write_text(json.dumps(self.expected))

    def test_exact_archived_bytes_prove_only_the_checkpoint_source(self):
        before=self.manifest.read_bytes()
        proof=verify_frozen_sources(self.engine,self.manifest)
        self.assertTrue(proof['checkpointOnly'])
        self.assertEqual(proof['verifiedFiles'],len(REQUIRED))
        self.assertEqual(proof['sourceManifestSHA256'],hashlib.sha256(before).hexdigest())
        self.assertEqual(self.manifest.read_bytes(),before)

    def test_changed_or_missing_code_is_rejected(self):
        for mode in ['changed','missing']:
            with self.subTest(mode=mode):
                path=self.engine/'main.lua';original=path.read_bytes()
                if mode=='changed':path.write_bytes(b'changed')
                else:path.unlink()
                with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)
                path.write_bytes(original)

    def test_incomplete_or_invalid_manifests_are_rejected(self):
        for wrong in [{},[],dict(self.expected,**{'main.lua':'wrong'})]:
            with self.subTest(wrong=wrong):
                self.manifest.write_text(json.dumps(wrong))
                with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)

    def test_paths_cannot_escape_or_alias_the_frozen_host(self):
        for name in ['../escape.lua','/escape.lua','./main.lua','src/../main.lua',r'src\escape.lua','C:/escape.lua']:
            with self.subTest(name=name):
                original=dict(self.expected);self.expected[name]='0'*64;self.save_manifest()
                with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)
                self.expected=original

    def test_unrecorded_lua_is_rejected_but_the_later_runtime_app_is_separate(self):
        extra=self.engine/'src/extra.lua';extra.write_text('unrecorded')
        with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)
        extra.unlink();runtime=self.engine/'.qa-runtime.app/Contents/Resources/boot.lua'
        runtime.parent.mkdir(parents=True);runtime.write_text('separately pinned runtime')
        self.assertTrue(verify_frozen_sources(self.engine,self.manifest)['checkpointOnly'])

    @unittest.skipIf(os.name=='nt','Symlink creation requires separate Windows privileges')
    def test_source_file_and_unrecorded_directory_symlinks_are_rejected(self):
        path=self.engine/'main.lua';raw=path.read_bytes();outside=self.root/'outside.lua';outside.write_bytes(raw)
        path.unlink();path.symlink_to(outside)
        with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)
        path.unlink();path.write_bytes(raw)
        link=self.engine/'foreign';link.symlink_to(self.root,target_is_directory=True)
        with self.assertRaises(AssertionError):verify_frozen_sources(self.engine,self.manifest)


class StoryQueueTests(unittest.TestCase):
    def test_complete_normal_inputs_and_acknowledged_terminal_exit(self):
        queue=[{'op':'press','button':'a'}]
        report={'commands':[{'seq':1,'input':queue[0]}],'status':'running'}
        verify_processed_queue(queue,report,{'seq':1,'busy':False})
        for terminal in ['finish','verify-continue']:
            verify_processed_queue(queue+[{'op':terminal}],dict(report,status='pass'),{'seq':2,'busy':False})

    def test_pending_or_mismatched_input_is_not_hidden_by_a_pass_marker(self):
        queue=[{'op':'press','button':'a'},{'op':'finish'}]
        rows=[{'seq':1,'input':queue[0]}]
        cases=[(queue,{'commands':rows,'status':'pass'},{'seq':1,'busy':False}),
               (queue,{'commands':rows,'status':'pass'},{'seq':2,'busy':True}),
               (queue,{'commands':rows,'status':'running'},{'seq':2,'busy':False}),
               ([queue[0],{'op':'step','dir':'up'}],{'commands':rows,'status':'pass'},{'seq':2,'busy':False}),
               (queue,{'commands':[{'seq':1,'input':{'op':'wait'}}],'status':'pass'},{'seq':2,'busy':False}),
               (queue+[{'op':'step','dir':'up'}],{'commands':rows,'status':'pass'},{'seq':3,'busy':False})]
        for inputs,report,state in cases:
            with self.subTest(inputs=inputs,report=report,state=state):
                with self.assertRaises(AssertionError):verify_processed_queue(inputs,report,state)


if __name__=='__main__':unittest.main()
