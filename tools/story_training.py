"""Bounded ordinary-input training on the already traversed Fiery Path.

The native driver remains the sole input/save/RNG owner. This client only
submits existing button commands, and returns control at subordinate UI.
"""
import time


def train_cave(send, wins, *, clock=time.monotonic):
    assert type(wins) is int and 1 <= wins <= 5
    state = send([])
    gains = []
    observed_exp = state['party'][0]['exp']
    last_enemy = None
    deadline = clock() + 180

    def result(reason):
        return dict(reason=reason, seq=state['seq'], top=state['top'],
                    party=state['party'], gains=gains,
                    ordinaryInputsOnly=True, injectedSaveOrRng=False)

    def act(commands):
        nonlocal state, observed_exp, last_enemy
        last_enemy = state['top'].get('enemy', {}).get('species') or last_enemy
        state = send(commands)
        mon = state['party'][0]
        if mon['exp'] > observed_exp:
            gains.append(dict(enemy=last_enemy, exp=mon['exp'] - observed_exp,
                              level=mon['level'], hp=mon['hp']))
        observed_exp = mon['exp']

    for _ in range(160):
        if clock() >= deadline:
            return result('bounded time limit')
        # A slow observation is not permission to enqueue another action.
        if state.get('busy') or state['seq'] < state.get('queuedCommands', state['seq']):
            act([])
            continue
        mon = state['party'][0]
        if mon['level'] >= 36:
            return result('evolution level reached')
        top = state['top']
        source = top.get('source')
        field = source == 'src/world/OverworldController.lua' and not state.get('scriptRunning')
        if mon['hp'] < 35 or (field and mon.get('status')):
            return result('healing/status attention')
        if len(gains) >= wins:
            return result('batch complete')
        if field:
            pos = state['player']
            if state['map']['id'] != 'MAP_G24_N14' or pos['cellX'] != 26 or not 20 <= pos['cellY'] <= 36:
                return result('outside verified training corridor')
            act([dict(op='hold', button='down' if pos['cellY'] <= 26 else 'up', frames=100, wait=20)])
        elif source in ('src/render/Transition.lua', 'src/render/BattleTransition.lua'):
            act([dict(op='wait', frames=150)])
        elif source == 'src/battle/BattleState.lua' and top.get('phase'):
            if top.get('trainer') or not top.get('enemy'):
                return result('non-wild battle attention')
            enemy = top['enemy']['species']
            if enemy == 'TORKOAL':
                if top['phase'] != 'menu':
                    act([dict(op='press', button='b', times=3, wait=60)])
                    continue
                index = top['menuIndex']
                commands = []
                if index in (1, 2):
                    commands.append(dict(op='press', button='down'))
                if index in (1, 3):
                    commands.append(dict(op='press', button='right'))
                commands += [dict(op='press', button='a'), dict(op='wait', frames=120),
                             dict(op='press', button='b', times=3, wait=60), dict(op='wait', frames=90)]
                act(commands)
                continue
            preferred = 'LEAF_BLADE' if enemy in ('NUMEL', 'GRIMER', 'KOFFING', 'MACHOP') else 'CUT'
            moves = mon['moves']
            leaf_pp = next((m.get('pp', 0) for m in moves if m['id'] == 'LEAF_BLADE'), 0)
            if enemy == 'NUMEL' and leaf_pp <= 5:
                preferred = 'CUT'
            slot = next((i for i, m in enumerate(moves, 1) if m['id'] == preferred and m.get('pp', 0) > 0), None)
            if slot is None:
                slot = next((i for i, m in enumerate(moves, 1) if m['id'] == 'CUT' and m.get('pp', 0) > 0), None)
            if slot is None:
                return result('move PP attention')
            before_pp = moves[slot - 1]['pp']
            act([dict(op='battle-attack', slot=slot)])
            if (not state.get('busy') and state['top'].get('phase') == 'moveSelect'
                    and state['party'][0]['moves'][slot - 1]['pp'] == before_pp):
                return result('move unavailable attention')
        else:
            # In particular, never mash B through level-up, move learning,
            # naming or evolution. The operator handles these actual screens.
            return result('subordinate UI attention')
    return result('bounded step limit')
