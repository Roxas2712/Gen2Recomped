"""Qualify only this task's ordinary-input Hoenn save receipts for continuation."""
import re

def first_badge_starter_proof(report):
    """Derive legacy driver lineage from its witnessed native rescue input.

    The continuous opening driver records the actual starter transition,
    rather than the earlier lab driver's two summary booleans. Never edit
    its report or accept a completed-badge claim without that transition.
    """
    edition=report.get('edition')
    if edition not in ('ruby','sapphire','emerald'):return False
    emerald=edition=='emerald'
    starter_screen='Gen3StarterSelect'if emerald else'Gen3RsStarterSelect'
    if not (report.get('continuousOpeningToFirstBadge') is True
            and report.get('newGameThroughUI') is True
            and report.get('initialPartyEmpty') is True
            and report.get('pokedexObtained') is True):
        return False
    if any(report.get(key)is False for key in('nativeStarterThroughRescueScript','naturalStarterAccepted')):
        return False
    starter=report.get('starter',{})
    if starter.get('level')!=5 or starter.get('species')not in('TREECKO','TORCHIC','MUDKIP'):
        return False
    rows=report.get('commands',[])
    first=next((i for i,row in enumerate(rows)if row.get('after',{}).get('party')),None)
    if first is None:return False
    row=rows[first];before=row.get('before',{});after=row.get('after',{})
    top=after.get('top',{})
    if any(r.get('before',{}).get('party')or r.get('after',{}).get('party')for r in rows[:first]):
        return False
    if not (before.get('party')==[] and after.get('party')==[starter]
            and before.get('top',{}).get('screenId')==starter_screen
            and before.get('top',{}).get('source')=='src/ui/'+starter_screen+'.lua'
            and (not emerald or (before['top'].get('stage')=='confirm'and before['top'].get('yes')is True))
            and row.get('input',{}).get('op')=='press'and row['input'].get('button')=='a'
            and any(p.get('key')=='a'for p in row.get('ordinaryInputs',[]))
            and before.get('map',{}).get('id')==after.get('map',{}).get('id')=='MAP_G00_N16'
            and after.get('scriptRunning') is True
            and top.get('source')=='src/battle/BattleState.lua'
            and top.get('musicKind')=='wild'
            and top.get('enemy',{}).get('species')==('ZIGZAGOON'if emerald else'POOCHYENA')
            and top['enemy'].get('level')==2
            and top.get('battler',{}).get('species')==starter['species']
            and top['battler'].get('level')==5):
        return False
    events=[e for e in report.get('events',[])if e.get('kind')=='first-party-member']
    return (len(events)==1 and events[0].get('mon')==starter
            and before.get('frame',-1)<=events[0].get('frame',-2)<=after.get('frame',-3))

def is_save_yes(state):
    top=state['top']
    choice=(top.get('source')=='src/ui/ChoiceBox.lua'or
            (top.get('source')=='src/ui/Gen3RsChoice.lua'and top.get('nativeChoiceKind')=='yesno')or
            (top.get('source')=='src/ui/Gen3RsSaveMenu.lua'and top.get('nativeSaveKind')=='rs'
             and top.get('phase')in('confirm','overwrite')))
    return choice and top.get('index')==1 and any(
        s.get('source')=='src/ui/Gen3StartMenu.lua'for s in state.get('stack',[]))

def check_saved_tail(rows, confirmed, last):
    """A receipt's final field position must still belong to its SAVE/YES."""
    assert 1 <= confirmed <= last <= len(rows)
    for row in rows[confirmed:last]:
        cmd = row['input']
        assert (cmd.get('op') in ('wait', 'shot', 'advance') or
                (cmd.get('op') == 'press' and cmd.get('button') in ('a', 'b'))), \
            'Record the save receipt before moving or reopening menus'

def _qualify(edition, name, verification, report, checkpoint, *, checkpoint_recovery=False):
    assert edition in ('ruby','sapphire','emerald')
    assert re.fullmatch('gen2recomp-qa-'+edition+r'-[0-9]+',name)
    identity='oasc-edition-qa-'+name.removeprefix('gen2recomp-qa-')
    assert verification['edition']==report['edition']==edition
    assert verification['identity']==checkpoint['profileIdentity']==identity
    assert checkpoint['sourceRun']==name
    assert all(verification[k]is True for k in('externalSaveRecoveryDisabled','allModsDisabled'))
    assert checkpoint_recovery or verification.get('frozenSourceUnchanged')is True
    completed = verification['status']=='pass'and report['status']=='pass'
    # Closing an isolated window after SAVE does not invalidate its saved
    # bytes. Recover only a clean exit whose complete trace ends at the
    # witnessed save receipt; never relabel the unfinished run as passed.
    saved_clean_exit = (
        verification['status']=='fail'and report['status']=='running'
        and verification.get('exitCode')==0
        and not verification.get('stoppedOwnChildReason')
        and verification.get('unexpectedImporterRun') is False
        and not report.get('error')
        and len(report['commands'])==checkpoint['saveMenuCommandRange'][1])
    assert completed or saved_clean_exit or checkpoint_recovery,'Run must finish or exit cleanly at its witnessed SAVE'
    assert checkpoint['personalSave']is False and checkpoint['producedThroughNormalSaveMenu']is True
    relative=checkpoint['saveRelativePath']
    assert relative=='profiles/guest/save_'+edition+'.lua'or re.fullmatch(
        'profiles/guest/saves/'+edition+r'/slot[1-9][0-9]*\.lua',relative)
    assert re.fullmatch(r'[a-f0-9]{64}',checkpoint['sha256'])
    assert all(report[k]is True for k in('continuousFromNewGame','noTeleport','noPartyInjection','noDirectStoryFlagEdits'))
    assert report['starter']['level']==5
    witnessed_first_badge=completed and first_badge_starter_proof(report)
    origin=(edition!='emerald'and report.get('continuousOpeningThroughRescueAndNormalLabSave')is True)or witnessed_first_badge
    continued=(report.get('continuedOwnNormalSave')is True and report.get('continuedThroughUI')is True
               and report.get('checkpointFullSavePreserved')is True
               and report.get('lineage',{}).get('inherited',{}).get('naturalStarterAccepted')is True)
    assert origin or continued,'Hoenn continuation must originate in a qualified natural starter run'
    rows=report['commands'];first,last=checkpoint['saveMenuCommandRange']
    assert 1<=first<=last<=len(rows)
    assert rows[first-1]['seq']==first and rows[last-1]['seq']==last
    assert rows[first-1]['before']['top']['source']=='src/ui/Gen3StartMenu.lua'
    after=rows[last-1]['after']
    assert after==checkpoint['snapshotAfterSaveCommand']
    assert after['top']['source']=='src/world/OverworldController.lua'and not after['scriptRunning']
    check_saved_tail(rows, checkpoint['saveConfirmedSeq'], last)
    def yes(state):
        return is_save_yes(state)
    if checkpoint.get('inputProofKind')=='native-per-press-state':
        index=checkpoint['saveConfirmedInputIndex'];assert 1<=index<=len(report['inputs'])
        button=report['inputs'][index-1]
        assert button['key']=='a'and first<=button['commandSeq']<=last
        assert button['commandSeq']==checkpoint['saveConfirmedSeq']and yes(button['before'])
    else:
        assert any((r['input'].get('button')=='a'or r['input'].get('op')=='advance')and yes(r['before'])
                   for r in rows[first-1:last]),'Normal SAVE needs a witnessed YES input'
    inherited={key:report[key]for key in('starter','newGameThroughUI','initialPartyEmpty')}
    for key in('nativeStarterThroughRescueScript','naturalStarterAccepted'):
        inherited[key]=report.get(key)is True or witnessed_first_badge
    assert all(inherited[key]is True for key in inherited if key!='starter')
    return inherited

def qualify(edition,name,verification,report,checkpoint):
    return _qualify(edition,name,verification,report,checkpoint)

def qualify_interrupted(edition,name,verification,report,checkpoint,queue,state,source_audit=None):
    """Admit only the last fully witnessed SAVE, retaining the failed run.

    Later unsaved actions are discarded explicitly. A new disk write, an
    unproven source, a broken input prefix or missing natural origin refuses
    recovery; verification/result and the checkpoint are never rewritten.
    """
    assert verification['status']=='fail'and verification.get('exitCode')==124
    assert verification.get('stoppedOwnChildReason')in('native QA timeout','absolute resource-slot deadline')
    assert report['status']=='running'and not report.get('error')
    if verification.get('frozenSourceUnchanged')is not True:
        assert isinstance(source_audit,dict)and source_audit.get('checkpointOnly')is True
        assert source_audit.get('method')=='restored-frozen-source-sha256'
        assert source_audit.get('driver')=='tests/rs_story_driver.lua'
        assert type(source_audit.get('verifiedFiles'))is int and source_audit['verifiedFiles']>=8
        digest=source_audit.get('sourceManifestSHA256')
        assert isinstance(digest,str)and re.fullmatch(r'[a-f0-9]{64}',digest)
    from story_frozen_sources import verify_saved_prefix
    proof=verify_saved_prefix(queue,report,state,checkpoint,save_yes=is_save_yes)
    proof=dict(proof,method='completed-normal-save-prefix-before-native-deadline')
    inherited=_qualify(edition,name,verification,report,checkpoint,checkpoint_recovery=True)
    return inherited,proof
