# Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""Recorded UI protocols: only observed SAVE/YES plus a successful write qualify."""
import copy
import unittest

from tools.story_save_operator import FIELD, START, TEXT, CHOICE, RS_SAVE, save_via_ui
from tools.rs_story_checkpoint import is_save_yes


def menu(index=5, rows=None):
    return dict(source=START, index=index, rows=rows or [dict(key=k) for k in
        ('pokedex', 'pokemon', 'bag', 'player', 'save', 'option', 'exit')])


def frame(top, *, count=4, owner=True, **extra):
    stack = ([menu()] if owner and top['source'] not in (FIELD, START) else []) + [top]
    state = dict(seq=0, queuedCommands=0, busy=False, top=top, stack=stack,
                 savedGameCount=count, scriptRunning=False)
    state.update(extra)
    return state


class Protocol:
    """A fixed expected UI trace, not a replacement save implementation."""
    def __init__(self, stages):
        self.stages = stages
        self.state = frame(dict(source=FIELD))
        self.sent = []
        self.receipts = []
        self.recorded = 0
        self.drift_before = {}
        self.receipt_after = {}
        self.wait_after = None

    def send(self, commands):
        if commands:
            assert len(commands) == 1
            cmd = commands[0]
            if cmd['op'] == 'wait' and cmd.get('frames') == 1:
                assert cmd == dict(op='wait', frames=1)
                before = copy.deepcopy(self.state)
                self.sent.append(cmd)
                self.state = copy.deepcopy(self.wait_after or self.state)
                self.state.update(seq=len(self.sent), queuedCommands=len(self.sent))
                self.receipts.append(dict(before=before, input=cmd, after=copy.deepcopy(self.state)))
                return copy.deepcopy(self.state)
            expected, after = self.stages[len(self.sent)]
            if expected == 'wait':
                assert cmd == dict(op='wait', frames=60), cmd
            else:
                assert cmd['op'] == 'press' and cmd.get('times', 1) == 1
                assert cmd['button'] == expected, (cmd, expected)
            if len(self.sent) in self.drift_before:
                self.state = copy.deepcopy(self.drift_before[len(self.sent)])
                self.state.update(seq=len(self.sent), queuedCommands=len(self.sent))
            before = copy.deepcopy(self.state)
            self.sent.append(cmd)
            self.state = copy.deepcopy(after)
            self.state.update(seq=len(self.sent), queuedCommands=len(self.sent))
            self.receipts.append(dict(before=before, input=cmd,
                after=copy.deepcopy(self.receipt_after.get(len(self.sent) - 1, self.state))))
        return copy.deepcopy(self.state)

    def record(self):
        assert self.state['top']['source'] == FIELD
        assert self.state['savedGameCount'] == 5
        assert any(r['input'].get('button') == 'a' and is_save_yes(r['before']) for r in self.receipts)
        assert self.receipts[-1]['after']['top']['source'] == FIELD
        self.recorded += 1
        return dict(normalCheckpointSHA256='a' * 64)


def generic(success=True):
    return Protocol([
        ('start', frame(menu(6))),
        ('up', frame(menu())),
        ('a', frame(dict(source=TEXT, page=['localized SAVE prompt']))),
        ('a', frame(dict(source=CHOICE, index=2))),
        ('up', frame(dict(source=CHOICE, index=1))),
        ('a', frame(dict(source=TEXT, page=['localized SAVING message']))),
        ('a', frame(dict(source=TEXT, page=['localized result']), count=5 if success else 4)),
        ('a', frame(dict(source=FIELD), count=5 if success else 4)),
    ])


class StorySaveOperatorTests(unittest.TestCase):
    def test_localized_generic_save_respects_remembered_row_and_records_yes_separately(self):
        ui = generic()
        reply = save_via_ui(ui.send, ui.record)
        self.assertTrue(reply['saved'])
        self.assertEqual(ui.recorded, 1)
        self.assertEqual(reply['sha256'], 'a' * 64)
        self.assertEqual([c['button'] for c in ui.sent if c['op'] == 'press'], ['start', 'up', 'a', 'a', 'up', 'a', 'a', 'a'])
        self.assertEqual(ui.sent[-1], dict(op='wait', frames=1))

    def test_saved_message_closes_between_receipt_and_poll_without_another_button(self):
        ui = generic()
        ui.receipt_after[7] = frame(dict(source=RS_SAVE, nativeSaveKind='rs', phase='saved'), count=5)
        self.assertTrue(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(ui.recorded, 1)
        self.assertEqual(len([c for c in ui.sent if c['op'] == 'press']), 8)
        self.assertEqual(ui.receipts[-2]['after']['top']['phase'], 'saved')
        self.assertEqual(ui.receipts[-1]['input'], dict(op='wait', frames=1))

    def test_field_receipt_refuses_counter_drift_or_new_ui(self):
        for changed in (dict(count=6), dict(scriptRunning=True), dict(busy=True),
                        dict(top=dict(source=TEXT))):
            with self.subTest(changed=changed):
                ui = generic()
                top = changed.get('top', dict(source=FIELD))
                extra = {k: v for k, v in changed.items() if k != 'top'}
                extra.setdefault('count', 5)
                ui.wait_after = frame(top, **extra)
                self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
                self.assertEqual(ui.recorded, 0)

    def test_native_rs_confirm_and_overwrite_remain_two_distinct_receipts(self):
        def native(phase, index=1, count=4):
            return frame(dict(source=RS_SAVE, nativeSaveKind='rs', phase=phase, index=index), count=count)
        ui = Protocol([
            ('start', frame(menu())), ('a', native('confirm', 2)),
            ('up', native('confirm')), ('a', native('overwrite')),
            ('a', native('saving_msg')), ('wait', native('saving')),
            ('wait', native('saved', count=5)), ('wait', frame(dict(source=FIELD), count=5)),
        ])
        self.assertTrue(save_via_ui(ui.send, ui.record)['saved'])
        phases = [r['before']['top'].get('phase') for r in ui.receipts if is_save_yes(r['before'])]
        self.assertEqual(phases, ['confirm', 'overwrite'])
        self.assertEqual(ui.recorded, 1)

    def test_native_saved_timer_cannot_queue_a_press_into_a_nearby_npc(self):
        def native(phase, count=4):
            return frame(dict(source=RS_SAVE, nativeSaveKind='rs', phase=phase, index=1), count=count)
        ui = Protocol([
            ('start', frame(menu())), ('a', native('confirm')),
            ('a', native('overwrite')), ('a', native('saved', count=5)),
            ('wait', frame(dict(source=FIELD), count=5)),
        ])
        ui.drift_before[4] = frame(dict(source=FIELD), count=5)
        self.assertTrue(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual([c.get('button') for c in ui.sent if c['op'] == 'press'], ['start', 'a', 'a', 'a'])
        self.assertEqual(ui.receipts[-2]['before']['top']['source'], FIELD)
        self.assertEqual(ui.receipts[-2]['input'], dict(op='wait', frames=60))
        self.assertEqual(ui.recorded, 1)

    def test_yes_reached_between_observations_uses_the_actual_input_receipt(self):
        ui = generic()
        ui.stages = ui.stages[:3] + [
            ('a', frame(dict(source=TEXT, page=['saving']))),
            ('a', frame(dict(source=TEXT, page=['saved']), count=5)),
            ('a', frame(dict(source=FIELD), count=5)),
        ]
        ui.drift_before[3] = frame(dict(source=CHOICE, index=1))
        self.assertTrue(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(ui.recorded, 1)

    def test_counter_increment_without_an_actual_yes_is_rejected_by_checkpoint_guard(self):
        ui = generic()
        ui.stages = ui.stages[:3] + [
            ('a', frame(dict(source=TEXT, page=['saving']))),
            ('a', frame(dict(source=TEXT, page=['saved']), count=5)),
            ('a', frame(dict(source=FIELD), count=5)),
        ]
        with self.assertRaises(AssertionError):
            save_via_ui(ui.send, ui.record)
        self.assertEqual(ui.recorded, 0)

    def test_refused_generic_write_cannot_record_the_previous_save(self):
        ui = generic(success=False)
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(ui.recorded, 0)

    def test_native_save_failure_stops_without_dismissing_its_error(self):
        ui = Protocol([
            ('start', frame(menu())),
            ('a', frame(dict(source=RS_SAVE, nativeSaveKind='rs', phase='save_failed', index=1))),
        ])
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(len(ui.sent), 2)
        self.assertEqual(ui.recorded, 0)

    def test_unexpected_subordinate_ui_is_never_confirmed(self):
        ui = Protocol([
            ('start', frame(menu())),
            ('a', frame(dict(source='src/ui/Gen3MoveLearnMenu.lua', index=1))),
        ])
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(len(ui.sent), 2)
        self.assertEqual(ui.recorded, 0)

    def test_busy_pending_script_or_non_field_state_gets_no_input(self):
        for changes in (dict(busy=True), dict(queuedCommands=1), dict(scriptRunning=True),
                        dict(top=dict(source='src/battle/BattleState.lua'))):
            with self.subTest(changes=changes):
                ui = Protocol([])
                ui.state.update(changes)
                self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
                self.assertEqual(ui.sent, [])

    def test_missing_invalid_or_saturated_counter_gets_no_input(self):
        for count in (None, -1, True, 0xFFFFFF):
            with self.subTest(count=count):
                ui = Protocol([])
                ui.state['savedGameCount'] = count
                self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
                self.assertEqual(ui.sent, [])

    def test_multiple_save_rows_are_not_guessed(self):
        ui = Protocol([('start', frame(menu(rows=[dict(key='save'), dict(key='save')], index=1)))])
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(len(ui.sent), 1)

    def test_counter_jump_is_not_accepted_as_one_write(self):
        ui = generic()
        ui.stages[-1] = ('a', frame(dict(source=FIELD), count=6))
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(ui.recorded, 0)

    def test_lost_save_owner_is_not_confirmed(self):
        ui = Protocol([
            ('start', frame(menu())),
            ('a', frame(dict(source=CHOICE, index=1), owner=False)),
        ])
        self.assertFalse(save_via_ui(ui.send, ui.record)['saved'])
        self.assertEqual(len(ui.sent), 2)

    def test_pending_command_is_observed_without_enqueuing_another_press(self):
        ui = Protocol([('start', frame(menu(), busy=True))])
        ticks = iter(range(100))
        self.assertFalse(save_via_ui(ui.send, ui.record, clock=lambda: next(ticks), max_seconds=5)['saved'])
        self.assertEqual(len(ui.sent), 1)
        self.assertEqual(ui.recorded, 0)

    def test_existing_checkpoint_guard_failure_is_not_suppressed(self):
        ui = generic()
        def reject():
            raise AssertionError('source/byte verification rejected the checkpoint')
        with self.assertRaisesRegex(AssertionError, 'source/byte'):
            save_via_ui(ui.send, reject)


if __name__ == '__main__':
    unittest.main()
