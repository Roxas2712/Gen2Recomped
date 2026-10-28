"""Qualify only this task's ordinary-input RS save receipts for continuation."""
import re

def first_badge_starter_proof(report):
    """Derive legacy driver lineage from its witnessed native rescue input.

    The continuous opening driver records the actual starter transition,
    rather than the earlier lab driver's two summary booleans. Never edit
    its report or accept a completed-badge claim without that transition.
    """
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
            and before.get('top',{}).get('screenId')=='Gen3RsStarterSelect'
            and before.get('top',{}).get('source')=='src/ui/Gen3RsStarterSelect.lua'
            and row.get('input',{}).get('op')=='press'and row['input'].get('button')=='a'
            and any(p.get('key')=='a'for p in row.get('ordinaryInputs',[]))
            and before.get('map',{}).get('id')==after.get('map',{}).get('id')=='MAP_G00_N16'
            and after.get('scriptRunning') is True
            and top.get('source')=='src/battle/BattleState.lua'
            and top.get('musicKind')=='wild'
            and top.get('enemy',{}).get('species')=='POOCHYENA'
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
    witnessed_first_badge=completed and first_badge_starter_proof(report)
    origin=report.get('continuousOpeningThroughRescueAndNormalLabSave')is True or witnessed_first_badge
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
    inherited={key:report[key]for key in('starter','newGameThroughUI','initialPartyEmpty')}
    for key in('nativeStarterThroughRescueScript','naturalStarterAccepted'):
        inherited[key]=report.get(key)is True or witnessed_first_badge
    assert all(inherited[key]is True for key in inherited if key!='starter')
    return inherited
