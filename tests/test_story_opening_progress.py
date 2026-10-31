# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from story_opening_progress import inherited_progress,stopped_at_opening_gate
class OpeningProgressTests(unittest.TestCase):
    def fresh(self):
        return dict(starter=dict(species='SQUIRTLE',level=5),newGameThroughUI=True,initialPartyEmpty=True)
    def test_complete_existing_opening_is_unchanged(self):
        report=dict(starter=dict(species='CHARMANDER',level=5),parcelObtained=True,parcelReturned=True,pokedexObtained=True)
        self.assertEqual(inherited_progress(report),report)
    def test_actual_early_failed_prefix_preserves_absent_rewards(self):
        result=inherited_progress(self.fresh(),verified_failed_tail=True)
        self.assertTrue(result['initialNewGameVerified'])
        self.assertFalse(result['parcelObtained']);self.assertFalse(result['parcelReturned']);self.assertFalse(result['pokedexObtained'])
        self.assertEqual(result['starter']['level'],5)
    def test_unverified_early_save_is_refused(self):
        for flag in (False,None,1,'true'):
            with self.subTest(flag=flag),self.assertRaises(AssertionError):inherited_progress(self.fresh(),verified_failed_tail=flag)
    def test_missing_original_intro_or_empty_party_is_refused(self):
        for key in ('newGameThroughUI','initialPartyEmpty'):
            report=self.fresh();report.pop(key)
            with self.subTest(key=key),self.assertRaises(AssertionError):inherited_progress(report,verified_failed_tail=True)
    def test_repeated_early_continue_requires_its_actual_ui_continue(self):
        report=dict(starter=dict(species='BULBASAUR',level=5),initialNewGameVerified=True,continuedThroughUI=True)
        self.assertTrue(inherited_progress(report)['initialNewGameVerified'])
        report['continuedThroughUI']=False
        with self.assertRaises(AssertionError):inherited_progress(report,verified_failed_tail=True)
    def test_partial_parcel_progress_is_not_promoted(self):
        report=self.fresh();report['parcelObtained']=True
        result=inherited_progress(report,verified_failed_tail=True)
        self.assertTrue(result['parcelObtained']);self.assertFalse(result['parcelReturned']);self.assertFalse(result['pokedexObtained'])
    def test_invalid_starter_and_fabricated_rewards_are_refused(self):
        for starter in (None,{},dict(level=6),dict(level=100)):
            report=self.fresh();report['starter']=starter
            with self.subTest(starter=starter),self.assertRaises(AssertionError):inherited_progress(report,verified_failed_tail=True)
        report=self.fresh();report['parcelReturned']=True
        with self.assertRaises(AssertionError):inherited_progress(report,verified_failed_tail=True)
        report=self.fresh();report['pokedexObtained']='true'
        with self.assertRaises(AssertionError):inherited_progress(report,verified_failed_tail=True)
class OpeningGateStopTests(unittest.TestCase):
    def test_only_the_known_post_save_driver_gate_is_eligible(self):
        v=dict(status='fail',exitCode=-15,stoppedOwnChildReason='fatal importer error',unexpectedImporterRun=False)
        log='driver error: /owned/engine/tests/leafgreen_story_driver.lua:263: Continuous parcel/Pokedex sequence incomplete\n'
        self.assertTrue(stopped_at_opening_gate(v,log))
        for key,value in (('status','pass'),('exitCode',0),('stoppedOwnChildReason','native QA timeout'),('unexpectedImporterRun',True)):
            changed=dict(v);changed[key]=value
            with self.subTest(key=key):self.assertFalse(stopped_at_opening_gate(changed,log))
        for bad in ('driver error: some other error\n',log+'later crash\n','src/import/RomImporter.lua:42: failed\n'+log):
            self.assertFalse(stopped_at_opening_gate(v,bad))
if __name__=='__main__':unittest.main()

