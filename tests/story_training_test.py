"""Safety and delayed-observation regressions for the ordinary-input client."""
import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from story_training import train_cave


def state(**changes):
    value = dict(seq=0, busy=False, queuedCommands=0, scriptRunning=False,
                 top=dict(source='src/world/OverworldController.lua'),
                 map=dict(id='MAP_G24_N14'), player=dict(cellX=26, cellY=26),
                 party=[dict(level=35, hp=89, exp=38020,
                             moves=[dict(id='CUT', pp=30), dict(id='LEAF_BLADE', pp=5)])])
    value.update(changes)
    return value


class TrainingTest(unittest.TestCase):
    def run_trace(self, trace, wins=1, clock=lambda: 0):
        states = iter(copy.deepcopy(trace))
        self.commands = []
        def send(commands):
            self.commands.append(commands)
            return next(states)
        return train_cave(send, wins, clock=clock)

    def test_never_inputs_outside_verified_corridor(self):
        for change in (dict(map=dict(id='MAP_G00_N27')), dict(player=dict(cellX=25, cellY=26))):
            self.assertEqual(self.run_trace([state(**change)])['reason'], 'outside verified training corridor')
            self.assertEqual(self.commands, [[]])

    def test_never_advances_subordinate_screens_or_evolution(self):
        for source in ('src/ui/Gen3SummaryMenu.lua', 'src/ui/EvolutionState.lua', 'src/render/TextBox.lua'):
            self.assertEqual(self.run_trace([state(top=dict(source=source))])['reason'], 'subordinate UI attention')
            self.assertEqual(self.commands, [[]])
        s = state();s['party'][0]['level'] = 36
        self.assertEqual(self.run_trace([s])['reason'], 'evolution level reached')
        self.assertEqual(self.commands, [[]])

    def test_never_automates_a_trainer_battle(self):
        s = state(top=dict(source='src/battle/BattleState.lua', phase='menu', trainer=dict(id='TEST'),
                           enemy=dict(species='NUMEL')))
        self.assertEqual(self.run_trace([s])['reason'], 'non-wild battle attention')
        self.assertEqual(self.commands, [[]])

    def test_stops_for_low_hp_or_field_status(self):
        for change in (dict(hp=34), dict(status='PSN'), dict(status='BRN')):
            s = state();s['party'][0].update(change)
            self.assertEqual(self.run_trace([s])['reason'], 'healing/status attention')
            self.assertEqual(self.commands, [[]])

    def test_late_win_counts_once_without_enqueuing_a_duplicate_attack(self):
        start = state(top=dict(source='src/battle/BattleState.lua', phase='menu', enemy=dict(species='NUMEL')))
        pending = copy.deepcopy(start);pending.update(busy=True, queuedCommands=1)
        finished = state(seq=1, queuedCommands=1);finished['party'][0]['exp'] += 201
        result = self.run_trace([start, pending, finished])
        self.assertEqual(result['reason'], 'batch complete')
        self.assertEqual(result['gains'], [dict(enemy='NUMEL', exp=201, level=35, hp=89)])
        self.assertEqual(self.commands, [[], [dict(op='battle-attack', slot=1)], []])

    def test_initial_pending_action_only_observed(self):
        s = state(busy=True, queuedCommands=1)
        end = state(seq=1, queuedCommands=1, top=dict(source='src/ui/Gen3MoveLearnMenu.lua'))
        self.assertEqual(self.run_trace([s, end])['reason'], 'subordinate UI attention')
        self.assertEqual(self.commands, [[], []])

    def test_unavailable_move_is_not_repeated(self):
        start = state(top=dict(source='src/battle/BattleState.lua', phase='menu', enemy=dict(species='NUMEL')))
        disabled = copy.deepcopy(start);disabled['top']['phase'] = 'moveSelect'
        disabled.update(seq=1, queuedCommands=1)
        self.assertEqual(self.run_trace([start, disabled])['reason'], 'move unavailable attention')
        self.assertEqual(len(self.commands), 2)

    def test_bounds_checked_before_input(self):
        for wins in (0, 6, 1.5):
            with self.assertRaises(AssertionError):
                train_cave(lambda _: self.fail('unbounded training reached the queue'), wins)


if __name__ == '__main__':
    unittest.main()
