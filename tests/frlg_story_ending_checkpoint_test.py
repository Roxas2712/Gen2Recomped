# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import copy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
import unittest
from frlg_story_ending_checkpoint import qualify


class EndingProvenance(unittest.TestCase):
    def fixture(self):
        run = 'gen2recomp-qa-leafgreen-owned'
        v = dict(identity='oasc-edition-qa-leafgreen-owned', status='pass', exitCode=0,
                 frozenSourceUnchanged=True, externalSaveRecoveryDisabled=True,
                 allModsDisabled=True, sourceCommit='owned-source')
        def state(seq, screen, flags):
            return dict(seq=seq, frame=seq*10, top=dict(source='src/ui/Gen3TitleFRLG.lua',screenId=screen),
                        flags=flags, party=[dict(species='OWNED',level=61,moves=[dict(id='OWNED_MOVE',pp=3)])],
                        savedGameCount=143, inventory={'OWNED_ITEM':2})
        states=[state(1,'Battle',{'FLAG_G3_04BC':True}),state(2,'Gen3FrlgHallOfFame',{}),
                state(3,'Gen3FrlgCredits',{}),state(4,'TitleState',{'EVENT_BEAT_CHAMPION_RIVAL':True})]
        report=dict(status='pass',continuousFromNewGame=True,noTeleport=True,noPartyInjection=True,
                    noDirectStoryFlagEdits=True,parcelObtained=True,parcelReturned=True,
                    pokedexObtained=True,brockTmRewardObserved=True,starter={'level':5},
                    commands=[dict(seq=i,input={'op':'wait'},after=s)for i,s in enumerate(states,1)])
        ending=dict(sourceRun=run,profileIdentity=v['identity'],sourceCommit=v['sourceCommit'],
                    saveKind='native-frlg-hall-of-fame',producedThroughNormalSaveMenu=False,
                    personalSave=False,sha256='a'*64,saveRelativePath='profiles/guest/saves/leafgreen/slot1.lua',
                    snapshotAfterEnding=copy.deepcopy(states[-1]))
        return run,v,report,ending

    def test_actual_ending_type_and_idle_clock(self):
        r,v,s,e=self.fixture();e['snapshotAfterEnding']['frame']+=120
        self.assertEqual(qualify('leafgreen',r,v,s,e)['starter'],{'level':5})
        self.assertFalse(e['producedThroughNormalSaveMenu'])

    def test_gameplay_differences_never_hidden_as_idle_time(self):
        for field,value in [('party',[]),('flags',{}),('inventory',{}),('savedGameCount',0)]:
            with self.subTest(field=field):
                r,v,s,e=self.fixture();e['snapshotAfterEnding'][field]=value
                with self.assertRaises(AssertionError):qualify('leafgreen',r,v,s,e)

    def test_invalid_provenance(self):
        changes=[('verification','frozenSourceUnchanged',False),('verification','exitCode',1),
                 ('verification','allModsDisabled',False),('report','noPartyInjection',False),
                 ('report','continuousFromNewGame',False),('checkpoint','personalSave',True),
                 ('checkpoint','producedThroughNormalSaveMenu',True),('checkpoint','sourceCommit','other'),
                 ('checkpoint','saveRelativePath','../../personal.lua'),('checkpoint','sha256','wrong')]
        for target,key,value in changes:
            with self.subTest(target=target,key=key):
                r,v,s,e=self.fixture();{'verification':v,'report':s,'checkpoint':e}[target][key]=value
                with self.assertRaises(AssertionError):qualify('leafgreen',r,v,s,e)

    def test_missing_or_reordered_ceremony(self):
        for index in (0,1,2):
            with self.subTest(index=index):
                r,v,s,e=self.fixture();s['commands'][index]['after']['top']['screenId']='other'
                if index==0:s['commands'][0]['after']['flags']={}
                with self.assertRaises(AssertionError):qualify('leafgreen',r,v,s,e)

    def test_other_edition_cannot_borrow_leafgreen_proof(self):
        r,v,s,e=self.fixture()
        with self.assertRaises(AssertionError):qualify('firered',r,v,s,e)


if __name__=='__main__':unittest.main()
