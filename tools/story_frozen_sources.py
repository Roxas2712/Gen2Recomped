"""Audit an archived story host without changing its failed native result.

Only checkpoint recovery may rely on this proof. A native run still needs its
own completed verification before it can count as a successful test.
"""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

REQUIRED = frozenset({
    'main.lua', 'conf.lua', 'src/core/Game.lua', 'src/core/SaveData.lua',
    'src/world/OverworldController.lua', 'tests/leafgreen_story_driver.lua',
    'tests/drivers/story_movement.lua', 'tests/drivers/story_battle.lua',
})


def verify_processed_queue(queue, report, state):
    rows=report['commands']
    assert isinstance(queue,list) and isinstance(rows,list), 'Invalid story input trace'
    assert len(rows)<=len(queue), 'Story input trace exceeds its queue'
    for i,row in enumerate(rows,1):
        assert row['seq']==i and row['input']==queue[i-1], 'Story queue and input receipt differ'
    assert state['busy'] is False and state['seq']==len(queue), 'Interrupted story has unprocessed input'
    if len(rows)==len(queue):return
    # The real driver's terminal operations publish the successful snapshot
    # and exit before the usual command-receipt append. Only that one fully
    # acknowledged terminal input may be absent from the prefix receipts.
    assert (len(queue)==len(rows)+1 and queue[-1].get('op')in('finish','verify-continue')
            and report['status']=='pass'), 'Interrupted story has unprocessed input'


def verify_saved_prefix(queue, report, state, checkpoint):
    """Recover only a completed normal SAVE before a later native crash.

    Unlike deadline recovery, a crashing command may still be pending. Its
    tail is explicitly discarded; the failed run never becomes a passing run.
    The caller must separately prove frozen sources, ownership and save bytes.
    """
    rows=report['commands']
    assert isinstance(queue,list) and isinstance(rows,list), 'Invalid story input trace'
    assert report['status']=='running', 'Crash recovery requires an unfinished native report'
    assert len(rows)<=len(queue), 'Story input trace exceeds its queue'
    for i,row in enumerate(rows,1):
        assert row['seq']==i and row['input']==queue[i-1], 'Story queue and input receipt differ'
    assert state['seq']==len(rows) and isinstance(state['busy'],bool), 'Crash state differs from completed receipts'
    first,last=checkpoint['saveMenuCommandRange']
    assert type(first)is int and type(last)is int and 1<=first<=last<=len(rows), 'Incomplete saved prefix'
    saved=checkpoint['snapshotAfterSaveCommand']
    assert rows[first-1]['before']['top']['source']=='src/ui/Gen3StartMenu.lua', 'Saved prefix did not start in SAVE menu'
    assert rows[last-1]['after']==saved, 'Checkpoint differs from completed saved receipt'
    assert saved['top']['source']=='src/world/OverworldController.lua' and saved['busy']is False, 'Checkpoint is not idle field'
    assert not saved.get('scriptRunning'), 'Checkpoint still has an active script'
    assert state['savedGameCount']==saved['savedGameCount'], 'Later unqualified SAVE cannot be discarded'
    confirmed=checkpoint['saveConfirmedSeq']
    assert type(confirmed)is int and first<=confirmed<=last, 'SAVE confirmation is outside its completed prefix'
    yes=rows[confirmed-1]
    assert (yes['input'].get('button')=='a' and yes['before']['top'].get('source')=='src/ui/ChoiceBox.lua'
            and yes['before']['top'].get('index')==1
            and any(s.get('source')=='src/ui/Gen3StartMenu.lua'for s in yes['before']['stack'])), 'Saved prefix lacks its actual SAVE YES'
    return {'method':'completed-normal-save-prefix-before-native-crash','checkpointOnly':True,
            'savedThroughSeq':last,'discardedCompletedCommands':len(rows)-last,
            'discardedPendingCommands':len(queue)-len(rows),'priorRunCompleted':False}


def verify_frozen_sources(engine, manifest):
    engine, manifest = Path(engine), Path(manifest)
    assert not engine.is_symlink() and engine.is_dir(), 'Missing original frozen host'
    assert not manifest.is_symlink(), 'Frozen source manifest is a symlink'
    raw = manifest.read_bytes()
    expected = json.loads(raw)
    assert isinstance(expected, dict) and REQUIRED <= expected.keys(), 'Incomplete frozen source manifest'
    for name, wanted in expected.items():
        assert isinstance(name, str), 'Invalid frozen source path'
        relative = PurePosixPath(name)
        assert (not relative.is_absolute() and '..' not in relative.parts
                and str(relative) == name and '\\' not in name and ':' not in name), 'Unsafe frozen source path'
        assert isinstance(wanted, str) and re.fullmatch('[0-9a-f]{64}', wanted), 'Invalid source digest'
        target = engine
        for part in relative.parts:
            target = target / part
            assert not target.is_symlink(), 'Frozen source contains a symlink'
        assert target.is_file(), 'Frozen source file is missing: ' + name
        assert hashlib.sha256(target.read_bytes()).hexdigest() == wanted, 'Frozen source changed: ' + name
    for path in engine.rglob('*'):
        name = path.relative_to(engine).as_posix()
        # The runner adds the separately pinned runtime app after the source
        # snapshot. All other Lua files must belong to that original snapshot.
        if not name.startswith('.qa-runtime.app/'):
            assert not path.is_symlink(), 'Unrecorded source symlink: ' + name
            if path.suffix=='.lua':assert name in expected, 'Unrecorded Lua source: ' + name
    return {'method': 'restored-frozen-source-sha256', 'verifiedFiles': len(expected),
            'sourceManifestSHA256': hashlib.sha256(raw).hexdigest(), 'checkpointOnly': True}
