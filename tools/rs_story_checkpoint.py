"""Qualify only this task's ordinary-input RS save receipts for continuation."""
import re

def is_save_yes(state):
    top=state['top']
    choice=(top.get('source')=='src/ui/ChoiceBox.lua'or
            (top.get('source')=='src/ui/Gen3RsChoice.lua'and top.get('nativeChoiceKind')=='yesno')or
            (top.get('source')=='src/ui/Gen3RsSaveMenu.lua'and top.get('nativeSaveKind')=='rs'
             and top.get('phase')in('confirm','overwrite')))
    return choice and top.get('index')==1 and any(
        s.get('source')=='src/ui/Gen3StartMenu.lua'for s in state['stack'])

def check_saved_tail(rows, confirmed, last):
    """A receipt's final field position must still belong to its SAVE/YES."""
    assert 1 <= confirmed <= last <= len(rows)
    for row in rows[confirmed:last]:
        cmd = row['input']
        assert (cmd.get('op') in ('wait', 'shot', 'advance') or
                (cmd.get('op') == 'press' and cmd.get('button') in ('a', 'b'))), \
            'Record the save receipt before moving or reopening menus'

def qualify(edition, name, verification, report, checkpoint):
    assert edition in ('ruby','sapphire')
    assert re.fullmatch('gen2recomp-qa-'+edition+r'-[0-9]+',name)
    identity='oasc-edition-qa-'+name.removeprefix('gen2recomp-qa-')
    assert verification['edition']==report['edition']==edition
    assert verification['identity']==checkpoint['profileIdentity']==identity
    assert checkpoint['sourceRun']==name
    assert all(verification[k]is True for k in('frozenSourceUnchanged','externalSaveRecoveryDisabled','allModsDisabled'))
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
    assert completed or saved_clean_exit,'Run must finish or exit cleanly at its witnessed SAVE'
    assert checkpoint['personalSave']is False and checkpoint['producedThroughNormalSaveMenu']is True
    relative=checkpoint['saveRelativePath']
    assert relative=='profiles/guest/save_'+edition+'.lua'or re.fullmatch(
        'profiles/guest/saves/'+edition+r'/slot[1-9][0-9]*\.lua',relative)
    assert re.fullmatch(r'[a-f0-9]{64}',checkpoint['sha256'])
    assert all(report[k]is True for k in('continuousFromNewGame','noTeleport','noPartyInjection','noDirectStoryFlagEdits'))
    assert report['starter']['level']==5
    origin=report.get('continuousOpeningThroughRescueAndNormalLabSave')is True
    continued=(report.get('continuedOwnNormalSave')is True and report.get('continuedThroughUI')is True
               and report.get('checkpointFullSavePreserved')is True
               and report.get('lineage',{}).get('inherited',{}).get('naturalStarterAccepted')is True)
    assert origin or continued,'RS continuation must originate in a qualified natural starter run'
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
    inherited={key:report[key]for key in('starter','newGameThroughUI','initialPartyEmpty',
        'nativeStarterThroughRescueScript','naturalStarterAccepted')}
    assert all(inherited[key]is True for key in inherited if key!='starter')
    return inherited
