"""Save through the observed story UI; never write or edit game-save data."""
# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
import time

FIELD = 'src/world/OverworldController.lua'
START = 'src/ui/Gen3StartMenu.lua'
TEXT = 'src/render/TextBox.lua'
CHOICE = 'src/ui/ChoiceBox.lua'
RS_SAVE = 'src/ui/Gen3RsSaveMenu.lua'
RS_CHOICE = 'src/ui/Gen3RsChoice.lua'


def save_via_ui(send, record, *, clock=time.monotonic, max_seconds=45):
    """Use single ordinary button receipts, then the existing checkpoint guard.

    ``send`` is the live controller's guarded queue, not an input/save shortcut.
    Unknown UI, outstanding commands and refused writes cannot create a receipt.
    """
    deadline = clock() + max_seconds
    state = send([])

    def result(reason, saved=False, **extra):
        return dict(saved=saved, reason=reason, seq=state.get('seq'), **extra)

    def idle():
        return not state.get('busy') and state.get('seq') == state.get('queuedCommands')

    def field():
        return state.get('top', {}).get('source') == FIELD and not state.get('scriptRunning')

    count = state.get('savedGameCount')
    if not idle() or not field():
        return result('Start from an idle field without queued input or a running script')
    if type(count) is not int or not 0 <= count < 0xFFFFFF:
        return result('Missing or saturated native saved-game counter')
    initial_count = count
    entered = False

    def press(button):
        # One receipt per press preserves the actual SAVE/YES boundary.
        return send([dict(op='press', button=button, wait=60)])

    state = press('start')
    for _ in range(96):
        if clock() >= deadline:
            return result('Bounded SAVE time limit; checkpoint not recorded')
        if not idle():
            state = send([])
            continue
        count = state.get('savedGameCount')
        if type(count) is not int or count not in (initial_count, initial_count + 1):
            return result('Unexpected saved-game counter; checkpoint not recorded')
        if field():
            if not (entered and count == initial_count + 1):
                return result('SAVE did not confirm one successful native write')
            # The UI may reach YES between client observations. Only the
            # driver's actual before-input receipts can prove that boundary;
            # record() rechecks those instead of trusting this polled view.
            # The saved message can close between the driver's after-input
            # receipt and this observation. Record a real no-button frame in
            # the field before asking the unchanged checkpoint guard to run.
            state = send([dict(op='wait', frames=1)])
            if not idle() or not field() or state.get('savedGameCount') != initial_count + 1:
                return result('SAVE closure did not produce an idle field receipt')
            receipt = record()
            sha = receipt.get('normalCheckpointSHA256')
            assert isinstance(sha, str) and len(sha) == 64, 'Checkpoint guard did not record save bytes'
            return result('Normal SAVE/YES completed', saved=True, sha256=sha)
        top = state.get('top', {})
        if top.get('source') == START:
            if entered:
                return result('SAVE returned to its menu; checkpoint not recorded')
            rows = top.get('rows') or []
            targets = [i for i, row in enumerate(rows, 1) if row.get('key') == 'save']
            index = top.get('index')
            if len(targets) != 1 or type(index) is not int or not 1 <= index <= len(rows):
                return result('No unambiguous native SAVE row')
            if index == targets[0]:
                entered = True
                state = press('a')
            else:
                state = press('down' if index < targets[0] else 'up')
            continue
        # Require the selected SAVE owner for every confirmation/message. This
        # cannot answer unrelated questions or a move-learning dialog.
        owners = [s for s in state.get('stack', []) if s.get('source') == START]
        if not entered or len(owners) != 1:
            return result('Unrecognized SAVE owner; operator attention required')
        owner = owners[0]
        rows, index = owner.get('rows') or [], owner.get('index')
        if type(index) is not int or not 1 <= index <= len(rows) or rows[index - 1].get('key') != 'save':
            return result('SAVE owner changed; operator attention required')
        source = top.get('source')
        native_rs = source == RS_SAVE and top.get('nativeSaveKind') == 'rs'
        native_choice = source == RS_CHOICE and top.get('nativeChoiceKind') == 'yesno'
        if native_rs and top.get('phase') == 'save_failed':
            return result('Native save write failed; checkpoint not recorded')
        if source == CHOICE or native_choice or (native_rs and top.get('phase') in ('confirm', 'overwrite')):
            if top.get('index') not in (1, 2):
                return result('Invalid YES/NO cursor')
            if top['index'] == 2:
                state = press('up')
                continue
            state = press('a')
        elif source == TEXT or (native_rs and top.get('phase') in ('saving_msg', 'saving', 'saved')):
            state = press('a')
        else:
            return result('Unexpected SAVE screen; operator attention required')
    return result('Bounded SAVE step limit; checkpoint not recorded')
