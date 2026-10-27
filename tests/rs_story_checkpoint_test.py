"""Guarded qualification regressions; no cartridges or player profiles used."""
from pathlib import Path
import copy,sys,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from rs_story_checkpoint import qualify

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

if __name__=='__main__':
    if '--worker'not in sys.argv:
        from qa_storage import qa_source,qa_run
        for p in(ROOT,Path(__file__),Path(sys.executable)):qa_source(p.resolve())
        raise SystemExit(qa_run([sys.executable,__file__,'--worker'],cwd=ROOT).returncode)
    sys.argv.remove('--worker');unittest.main()
