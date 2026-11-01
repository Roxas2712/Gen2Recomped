"""Guarded qualification regressions; no cartridges or player profiles used."""
from pathlib import Path
import copy,sys,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from rs_story_checkpoint import qualify,qualify_interrupted,first_badge_starter_proof

class CheckpointTests(unittest.TestCase):
    def fixture(self,e='sapphire'):
        name='gen2recomp-qa-'+e+'-123456';identity='oasc-edition-qa-'+e+'-123456'
        menu={'source':'src/ui/Gen3StartMenu.lua'}
        before={'top':{'source':'src/ui/ChoiceBox.lua','index':1},'stack':[menu]}
        after={'top':{'source':'src/world/OverworldController.lua'},'scriptRunning':False}
        v=dict(edition=e,identity=identity,status='pass',frozenSourceUnchanged=True,
               externalSaveRecoveryDisabled=True,allModsDisabled=True)
        r=dict(edition=e,status='pass',continuousFromNewGame=True,noTeleport=True,noPartyInjection=True,
               noDirectStoryFlagEdits=True,starter={'level':5},continuousOpeningThroughRescueAndNormalLabSave=True,
               newGameThroughUI=True,initialPartyEmpty=True,nativeStarterThroughRescueScript=True,naturalStarterAccepted=True,
               commands=[{'seq':1,'before':{'top':menu},'after':after}],
               inputs=[{'key':'a','commandSeq':1,'before':before}])
        c=dict(sourceRun=name,profileIdentity=identity,personalSave=False,producedThroughNormalSaveMenu=True,
               saveRelativePath='profiles/guest/save_'+e+'.lua',sha256='a'*64,saveMenuCommandRange=[1,1],
               snapshotAfterSaveCommand=copy.deepcopy(after),inputProofKind='native-per-press-state',
               saveConfirmedInputIndex=1,saveConfirmedSeq=1)
        return e,name,v,r,c
    def test_both_editions(self):
        for e in('ruby','sapphire'):self.assertTrue(qualify(*self.fixture(e))['naturalStarterAccepted'])
    def test_native_yesno_is_distinct_from_multichoice(self):
        f=list(self.fixture());top=f[3]['inputs'][0]['before']['top']
        top.update(source='src/ui/Gen3RsChoice.lua',nativeChoiceKind='yesno')
        self.assertTrue(qualify(*f)['naturalStarterAccepted'])
        top['nativeChoiceKind']='multi';self.assertRaises(AssertionError,qualify,*f)
        top.pop('nativeChoiceKind');self.assertRaises(AssertionError,qualify,*f)
    def test_foreign_namespace(self):
        f=list(self.fixture());f[2]['identity']='private-player';self.assertRaises(AssertionError,qualify,*f)
    def test_native_save_confirmation_and_overwrite(self):
        for phase in('confirm','overwrite'):
            f=list(self.fixture());top=f[3]['inputs'][0]['before']['top']
            top.update(source='src/ui/Gen3RsSaveMenu.lua',nativeSaveKind='rs',phase=phase)
            self.assertTrue(qualify(*f)['naturalStarterAccepted'])
            top['index']=2;self.assertRaises(AssertionError,qualify,*f)
        for phase in('saving_msg','saving','saved','save_failed'):
            f=list(self.fixture());f[3]['inputs'][0]['before']['top'].update(
                source='src/ui/Gen3RsSaveMenu.lua',nativeSaveKind='rs',phase=phase)
            self.assertRaises(AssertionError,qualify,*f)
    def test_personal_or_wrong_edition_paths(self):
        for path in('profiles/main/save_sapphire.lua','profiles/guest/save_ruby.lua','../player.lua'):
            f=list(self.fixture());f[4]['saveRelativePath']=path;self.assertRaises(AssertionError,qualify,*f)
    def test_no_yes_or_wrong_button(self):
        for key in('b','start'):
            f=list(self.fixture());f[3]['inputs'][0]['key']=key;self.assertRaises(AssertionError,qualify,*f)
        f=list(self.fixture());f[3]['inputs'][0]['before']['stack']=[];self.assertRaises(AssertionError,qualify,*f)
    def test_failed_run_or_mutated_snapshot(self):
        f=list(self.fixture());f[2]['status']='fail';self.assertRaises(AssertionError,qualify,*f)
        f=list(self.fixture());f[4]['snapshotAfterSaveCommand']['scriptRunning']=True;self.assertRaises(AssertionError,qualify,*f)
    def clean_exit_fixture(self):
        f=list(self.fixture());f[2].update(status='fail',exitCode=0,unexpectedImporterRun=False)
        f[3]['status']='running'
        return f
    def test_clean_window_exit_preserves_witnessed_save_without_passing_run(self):
        f=self.clean_exit_fixture()
        self.assertTrue(qualify(*f)['naturalStarterAccepted'])
        self.assertEqual((f[2]['status'],f[3]['status']),('fail','running'))
    def test_clean_exit_recovery_rejects_crash_timeout_and_importer(self):
        for key,value in (('exitCode',1),('exitCode',-15),('stoppedOwnChildReason','native QA timeout'),
                          ('stoppedOwnChildReason','fatal importer error'),('unexpectedImporterRun',True)):
            f=self.clean_exit_fixture();f[2][key]=value
            self.assertRaises(AssertionError,qualify,*f)
        f=self.clean_exit_fixture();f[3]['error']='driver failed';self.assertRaises(AssertionError,qualify,*f)
    def test_clean_exit_recovery_rejects_unsaved_tail_and_invalid_proof(self):
        f=self.clean_exit_fixture();f[3]['commands'].append(copy.deepcopy(f[3]['commands'][0]))
        self.assertRaises(AssertionError,qualify,*f)
        for key in ('noPartyInjection','noDirectStoryFlagEdits','naturalStarterAccepted'):
            f=self.clean_exit_fixture();f[3][key]=False;self.assertRaises(AssertionError,qualify,*f)
        f=self.clean_exit_fixture();f[4]['snapshotAfterSaveCommand']['scriptRunning']=True
        self.assertRaises(AssertionError,qualify,*f)
    def test_injected_or_unproven_origin(self):
        f=list(self.fixture());f[3]['noPartyInjection']=False;self.assertRaises(AssertionError,qualify,*f)
        f=list(self.fixture());f[3]['continuousOpeningThroughRescueAndNormalLabSave']=False;self.assertRaises(AssertionError,qualify,*f)

    def interrupted_fixture(self,e='ruby'):
        f=list(self.fixture(e));v,r,c=f[2:]
        v.update(status='fail',exitCode=124,stoppedOwnChildReason='absolute resource-slot deadline',frozenSourceUnchanged=False)
        r.update(status='running',continuousOpeningThroughRescueAndNormalLabSave=False,
                 continuedOwnNormalSave=True,continuedThroughUI=True,checkpointFullSavePreserved=True,
                 lineage={'inherited':{'naturalStarterAccepted':True}})
        start={'source':'src/ui/Gen3StartMenu.lua'}
        yes={'source':'src/ui/Gen3RsSaveMenu.lua','nativeSaveKind':'rs','phase':'overwrite','index':1}
        saved={'seq':2,'busy':False,'savedGameCount':54,'scriptRunning':False,'top':{'source':'src/world/OverworldController.lua'}}
        queue=[{'op':'press','button':'a'},{'op':'press','button':'a'},{'op':'step','dir':'down'}]
        r['commands']=[{'seq':1,'input':copy.deepcopy(queue[0]),'before':{'top':start},'after':{}},
          {'seq':2,'input':copy.deepcopy(queue[1]),'before':{'top':yes,'stack':[start,yes]},'after':copy.deepcopy(saved)},
          {'seq':3,'input':copy.deepcopy(queue[2]),'before':copy.deepcopy(saved),'after':{}}]
        c.update(saveMenuCommandRange=[1,2],saveConfirmedSeq=2,snapshotAfterSaveCommand=copy.deepcopy(saved))
        c.pop('inputProofKind');c.pop('saveConfirmedInputIndex')
        state={'seq':3,'busy':False,'savedGameCount':54}
        audit={'method':'restored-frozen-source-sha256','checkpointOnly':True,'driver':'tests/rs_story_driver.lua',
               'verifiedFiles':8,'sourceManifestSHA256':'b'*64}
        return f+[queue,state,audit]

    def test_interrupted_hoenn_recovers_only_the_witnessed_save_without_relabelling_the_run(self):
        for edition in('ruby','sapphire','emerald'):
            f=self.interrupted_fixture(edition);before=copy.deepcopy(f)
            inherited,proof=qualify_interrupted(*f)
            self.assertTrue(inherited['naturalStarterAccepted']);self.assertTrue(proof['checkpointOnly'])
            self.assertFalse(proof['priorRunCompleted']);self.assertEqual(proof['savedThroughSeq'],2)
            self.assertEqual(proof['discardedCompletedCommands'],1);self.assertEqual(f,before)
            self.assertRaises(AssertionError,qualify,*f[:5])

    def test_interrupted_recovery_refuses_new_writes_bad_sources_and_unproven_origin(self):
        for change in('new-save','wrong-driver','no-audit','bad-audit','wrong-stop','queue','no-origin','not-save-yes'):
            f=self.interrupted_fixture('emerald')
            if change=='new-save':f[6]['savedGameCount']=55
            elif change=='wrong-driver':f[7]['driver']='tests/leafgreen_story_driver.lua'
            elif change=='no-audit':f[7]=None
            elif change=='bad-audit':f[7]['sourceManifestSHA256']='invalid'
            elif change=='wrong-stop':f[2]['stoppedOwnChildReason']='unknown'
            elif change=='queue':f[5][0]['button']='b'
            elif change=='no-origin':f[3]['lineage']['inherited']['naturalStarterAccepted']=False
            elif change=='not-save-yes':f[3]['commands'][1]['before']['top']['index']=2
            self.assertRaises(AssertionError,qualify_interrupted,*f)

    def first_badge_fixture(self,e='ruby'):
        f=list(self.fixture(e));r,c=f[3],f[4]
        for key in('continuousOpeningThroughRescueAndNormalLabSave','nativeStarterThroughRescueScript','naturalStarterAccepted'):
            r.pop(key)
        starter={'species':'TREECKO','level':5,'hp':20,'moves':[{'id':'POUND','pp':35}]}
        r.update(starter=starter,continuousOpeningToFirstBadge=True,pokedexObtained=True,
                 events=[{'kind':'first-party-member','frame':15,'mon':copy.deepcopy(starter)}])
        row={'seq':1,'input':{'op':'press','button':'a'},'ordinaryInputs':[{'key':'a'}],
             'before':{'party':[],'frame':10,'map':{'id':'MAP_G00_N16'},
                       'top':{'screenId':'Gen3RsStarterSelect','source':'src/ui/Gen3RsStarterSelect.lua'}},
             'after':{'party':[copy.deepcopy(starter)],'frame':20,'map':{'id':'MAP_G00_N16'},'scriptRunning':True,
                      'top':{'source':'src/battle/BattleState.lua','musicKind':'wild',
                             'enemy':{'species':'POOCHYENA','level':2},'battler':{'species':'TREECKO','level':5}}}}
        r['commands'].insert(0,row);r['commands'][1]['seq']=2;r['inputs'][0]['commandSeq']=2
        if e=='emerald':
            row['before']['top'].update(screenId='Gen3StarterSelect',source='src/ui/Gen3StarterSelect.lua',stage='confirm',yes=True)
            row['after']['top']['enemy']['species']='ZIGZAGOON'
        c.update(saveMenuCommandRange=[2,2],saveConfirmedSeq=2)
        return f
    def test_first_badge_uses_actual_starter_input_without_rewriting_report(self):
        for e in('ruby','sapphire','emerald'):
            f=self.first_badge_fixture(e);before=copy.deepcopy(f)
            self.assertTrue(first_badge_starter_proof(f[3]))
            self.assertTrue(qualify(*f)['naturalStarterAccepted']);self.assertEqual(f,before)
    def test_emerald_requires_its_own_rescue_opponent_and_confirmation(self):
        for change in('ruby-opponent','ruby-screen','pick-stage','no-selected','legacy-summary'):
            f=self.first_badge_fixture('emerald');r=f[3];row=r['commands'][0]
            if change=='ruby-opponent':row['after']['top']['enemy']['species']='POOCHYENA'
            elif change=='ruby-screen':row['before']['top'].update(screenId='Gen3RsStarterSelect',source='src/ui/Gen3RsStarterSelect.lua')
            elif change=='pick-stage':row['before']['top']['stage']='pick'
            elif change=='no-selected':row['before']['top']['yes']=False
            elif change=='legacy-summary':
                r['commands'].pop(0);r['continuousOpeningThroughRescueAndNormalLabSave']=True
            self.assertFalse(first_badge_starter_proof(r))
            self.assertRaises(AssertionError,qualify,*f)
    def test_first_badge_requires_native_rescue_transition(self):
        cases=[('screenId','Other'),('source','src/ui/PartyMenu.lua')]
        for key,value in cases:
            f=self.first_badge_fixture();f[3]['commands'][0]['before']['top'][key]=value
            self.assertRaises(AssertionError,qualify,*f)
        for key,value in(('source','src/ui/PartyMenu.lua'),('musicKind','trainer')):
            f=self.first_badge_fixture();f[3]['commands'][0]['after']['top'][key]=value
            self.assertRaises(AssertionError,qualify,*f)
        for key,value in(('species','ZIGZAGOON'),('level',3)):
            f=self.first_badge_fixture();f[3]['commands'][0]['after']['top']['enemy'][key]=value
            self.assertRaises(AssertionError,qualify,*f)
        for part in('before','after'):
            f=self.first_badge_fixture();f[3]['commands'][0][part]['map']['id']='MAP_G01_N04'
            self.assertRaises(AssertionError,qualify,*f)
    def test_first_badge_rejects_injection_and_missing_input_or_event(self):
        for change in('before-party','after-party','button','op','inputs','event','event-time','event-mon','extra-event'):
            f=self.first_badge_fixture();r=f[3];row=r['commands'][0]
            if change=='before-party':row['before']['party']=[r['starter']]
            elif change=='after-party':row['after']['party'][0]['level']=6
            elif change=='button':row['input']['button']='b'
            elif change=='op':row['input']['op']='inject'
            elif change=='inputs':row['ordinaryInputs']=[]
            elif change=='event':r['events']=[]
            elif change=='event-time':r['events'][0]['frame']=30
            elif change=='event-mon':r['events'][0]['mon']['species']='MUDKIP'
            elif change=='extra-event':r['events'].append(copy.deepcopy(r['events'][0]))
            with self.assertRaises(AssertionError,msg=change):qualify(*f)
        for key in('continuousOpeningToFirstBadge','newGameThroughUI','initialPartyEmpty','pokedexObtained'):
            f=self.first_badge_fixture();f[3][key]=False;self.assertRaises(AssertionError,qualify,*f)
        for key in('nativeStarterThroughRescueScript','naturalStarterAccepted'):
            f=self.first_badge_fixture();f[3][key]=False;self.assertRaises(AssertionError,qualify,*f)
        f=self.first_badge_fixture();f[3]['status']='running';self.assertRaises(AssertionError,qualify,*f)

    def emerald_fade_fixture(self):
        f=self.first_badge_fixture('emerald');r,c=f[3:]
        first=r['commands'][0]
        battle=copy.deepcopy(first['after'])
        battle['player']={'cellX':7,'cellY':15}
        battle['top'].update(phase='messages',nativeBattle={})
        first['after']['player']=copy.deepcopy(battle['player'])
        first['after']['top']={'source':'src/render/BattleTransition.lua','phase':'wipe'}
        before=copy.deepcopy(battle);before['frame']=25
        after=copy.deepcopy(battle);after['frame']=115
        r['commands'].insert(1,{'seq':2,'input':{'op':'wait','frames':90},
                              'ordinaryInputs':[],'before':before,'after':after})
        r['commands'][2]['seq']=3;r['inputs'][0]['commandSeq']=3
        c.update(saveMenuCommandRange=[3,3],saveConfirmedSeq=3)
        return f

    def test_emerald_original_battle_fade_preserves_witnessed_starter_origin(self):
        f=self.emerald_fade_fixture();original=copy.deepcopy(f)
        self.assertTrue(first_badge_starter_proof(f[3]))
        self.assertTrue(qualify(*f)['naturalStarterAccepted'])
        self.assertEqual(f,original)

    def test_emerald_fade_can_finish_during_the_recorded_wait(self):
        f=self.emerald_fade_fixture();row=f[3]['commands'][1]
        row['before']['top']={'source':'src/render/FieldFade.lua'}
        self.assertTrue(qualify(*f)['naturalStarterAccepted'])

    def test_emerald_fade_rejects_intervening_input_or_missing_wait_receipts(self):
        for change in('press','goto','injection','buttons','missing-buttons','zero','negative',
                      'long','fractional','boolean','missing-frames','missing-wait','sequence'):
            f=self.emerald_fade_fixture();row=f[3]['commands'][1]
            if change=='press':row['input']={'op':'press','button':'a'}
            elif change=='goto':row['input']={'op':'goto','x':7,'y':15}
            elif change=='injection':row['input']={'op':'inject'}
            elif change=='buttons':row['ordinaryInputs']=[{'key':'a'}]
            elif change=='missing-buttons':row.pop('ordinaryInputs')
            elif change in('zero','negative','long','fractional','boolean'):
                row['input']['frames']={'zero':0,'negative':-1,'long':601,'fractional':1.5,'boolean':True}[change]
            elif change=='missing-frames':row['input'].pop('frames')
            elif change=='missing-wait':f[3]['commands'].pop(1)
            elif change=='sequence':row['seq']=9
            with self.subTest(change=change):
                self.assertFalse(first_badge_starter_proof(f[3]))
                self.assertRaises(AssertionError,qualify,*f)

    def test_emerald_fade_rejects_party_map_script_position_or_battle_changes(self):
        for part in('before','after'):
            for change in('party','level','hp','move','map','script','position','field','trainer',
                          'opponent','enemy-level','battler','battle-level','already-fought','menu'):
                f=self.emerald_fade_fixture();s=f[3]['commands'][1][part];top=s['top']
                if change=='party':s['party'].append(copy.deepcopy(s['party'][0]))
                elif change=='level':s['party'][0]['level']=6
                elif change=='hp':s['party'][0]['hp']-=1
                elif change=='move':s['party'][0]['moves'][0]['pp']-=1
                elif change=='map':s['map']['id']='MAP_G01_N04'
                elif change=='script':s['scriptRunning']=False
                elif change=='position':s['player']['cellX']+=1
                elif change=='field':s['top']={'source':'src/world/OverworldController.lua'}
                elif change=='trainer':top['musicKind']='trainer'
                elif change=='opponent':top['enemy']['species']='POOCHYENA'
                elif change=='enemy-level':top['enemy']['level']=3
                elif change=='battler':top['battler']['species']='MUDKIP'
                elif change=='battle-level':top['battler']['level']=6
                elif change=='already-fought':top['nativeBattle']['turnCount']=1
                elif change=='menu':top['phase']='menu'
                with self.subTest(part=part,change=change):
                    self.assertFalse(first_badge_starter_proof(f[3]))
                    self.assertRaises(AssertionError,qualify,*f)

    def test_emerald_fade_proof_is_bounded_and_keeps_the_original_party_event_range(self):
        for change in('old-before','long-after','backwards','late-event','unknown-fade','ruby'):
            f=self.emerald_fade_fixture();first,wait=f[3]['commands'][:2]
            if change=='old-before':wait['before']['frame']=19
            elif change=='long-after':wait['after']['frame']=1221
            elif change=='backwards':wait['after']['frame']=24
            elif change=='late-event':f[3]['events'][0]['frame']=30
            elif change=='unknown-fade':first['after']['top']['source']='src/render/Transition.lua'
            elif change=='ruby':f[3]['edition']='ruby'
            with self.subTest(change=change):self.assertFalse(first_badge_starter_proof(f[3]))

if __name__=='__main__':
    if '--worker'not in sys.argv:
        from qa_storage import qa_source,qa_run
        for p in(ROOT,Path(__file__),Path(sys.executable)):qa_source(p.resolve())
        raise SystemExit(qa_run([sys.executable,__file__,'--worker'],cwd=ROOT).returncode)
    sys.argv.remove('--worker');unittest.main()
